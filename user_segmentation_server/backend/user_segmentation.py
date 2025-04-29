from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import asyncpg
import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.cluster import KMeans
from datetime import datetime
import logging
import google.generativeai as genai
from typing import List, Dict
import json
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("UserSegmentationLogger")

# PostgreSQL configuration from environment variables
DB_USERNAME = os.getenv("DB_USERNAME", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "odoo18v3")

# Gemini API configuration
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
if not GOOGLE_API_KEY:
    raise ValueError("GOOGLE_API_KEY environment variable is not set")
genai.configure(api_key=GOOGLE_API_KEY)

app = FastAPI()

class HostPayload(BaseModel):
    host: str
    n_clusters: int = 5  # default number of clusters

def calculate_age(dob):
    if pd.isna(dob):
        return None
    today = datetime.now()
    return today.year - pd.to_datetime(dob).year

async def fetch_user_data(conn, host):
    """Fetch and prepare user data for segmentation"""
    try:
        # Fetch user information with favorites analysis
        users_query = """
        WITH user_favorites_stats AS (
            SELECT 
                uf.user_id,
                COUNT(DISTINCT uf.property_id) as total_favorites,
                AVG(rp.price) as avg_favorited_price,
                MODE() WITHIN GROUP (ORDER BY rp.type) as favorite_property_type,
                MODE() WITHIN GROUP (ORDER BY rp.city) as favorite_city,
                AVG(rp.area) as avg_favorited_area,
                AVG(rp.bedrooms) as avg_favorited_bedrooms,
                MODE() WITHIN GROUP (ORDER BY rp.payment_option) as favorite_payment_option,
                MODE() WITHIN GROUP (ORDER BY rp.sale_rent) as favorite_sale_rent,
                COUNT(CASE WHEN rp.furnished = 'yes' THEN 1 END)::float / 
                    NULLIF(COUNT(*), 0) as furnished_preference_ratio,
                -- Sale-specific preferences
                AVG(CASE WHEN rp.sale_rent = 'sale' THEN rp.installment_years END) as avg_installment_years,
                AVG(CASE WHEN rp.sale_rent = 'sale' THEN rp.delivery_in END) as avg_delivery_time,
                MODE() WITHIN GROUP (ORDER BY 
                    CASE WHEN rp.sale_rent = 'sale' THEN rp.finishing END
                ) as preferred_finishing,
                COUNT(CASE WHEN rp.sale_rent = 'sale' THEN 1 END)::float / 
                    NULLIF(COUNT(*), 0) as sale_preference_ratio
            FROM 
                real_estate_user_favorites uf
                JOIN real_estate_property rp ON uf.property_id = rp.id
            GROUP BY 
                uf.user_id
        )
        SELECT 
            u.id,
            u.job,
            u.country,
            u.dob,
            COALESCE(fs.total_favorites, 0) as total_favorites,
            fs.avg_favorited_price,
            fs.favorite_property_type,
            fs.favorite_city,
            fs.avg_favorited_area,
            fs.avg_favorited_bedrooms,
            fs.favorite_payment_option,
            fs.favorite_sale_rent,
            fs.furnished_preference_ratio,
            fs.avg_installment_years,
            fs.avg_delivery_time,
            fs.preferred_finishing,
            fs.sale_preference_ratio
        FROM 
            users_users u
            LEFT JOIN user_favorites_stats fs ON u.id = fs.user_id
        """
        
        results = await conn.fetch(users_query)
        user_data = pd.DataFrame([dict(row) for row in results])
        
        # Calculate age from dob
        user_data['age'] = user_data['dob'].apply(calculate_age)
        
        return user_data
    
    except Exception as e:
        logger.error(f"Error fetching user data: {e}")
        raise HTTPException(status_code=500, detail=str(e))

def prepare_features(df):
    """Prepare features for clustering"""
    # Numerical features
    numerical_features = [
        'age', 
        'total_favorites',
        'avg_favorited_price', 
        'avg_favorited_area', 
        'avg_favorited_bedrooms',
        'furnished_preference_ratio',
        'avg_installment_years',
        'avg_delivery_time',
        'sale_preference_ratio'
    ]
    
    # Categorical features
    categorical_features = [
        'job', 
        'country', 
        'favorite_property_type',
        'favorite_city', 
        'favorite_payment_option',
        'favorite_sale_rent',
        'preferred_finishing'
    ]
    
    # Handle numerical features
    scaler = StandardScaler()
    numerical_data = df[numerical_features].fillna(df[numerical_features].mean())
    scaled_numerical = scaler.fit_transform(numerical_data)
    
    # Handle categorical features
    encoder = OneHotEncoder(sparse=False, handle_unknown='ignore')
    categorical_data = df[categorical_features].fillna('unknown')
    encoded_categorical = encoder.fit_transform(categorical_data)
    
    # Combine features
    feature_matrix = np.hstack([scaled_numerical, encoded_categorical])
    
    return feature_matrix, numerical_features, categorical_features, encoder.get_feature_names_out(categorical_features)

async def get_cluster_description(cluster_data: Dict) -> str:
    """Get cluster description from Gemini"""
    model = genai.GenerativeModel('gemini-pro')
    
    prompt = f"""
    As a real estate market expert, analyze this user cluster data and provide a creative, 
    meaningful name and detailed description for this segment of users. Consider all aspects 
    of their behavior and preferences:

    Cluster Statistics:
    {json.dumps(cluster_data, indent=2)}
    
    Based on these statistics, create a unique, insightful segment name and description that 
    captures the essence of this user group. Consider their:
    - Demographics (age, job, country)
    - Property preferences (type, size, location)
    - Financial behavior (price ranges, payment preferences)
    - For sale properties: their preferences about installments, delivery time, and finishing
    - Overall behavior patterns in favoriting properties

    Please provide the response in the following format:
    Name: [A unique, creative 1-3 word segment name]
    Description: [2-3 detailed sentences describing what makes this segment unique, their key 
    preferences, and their typical behavior patterns]
    """
    
    try:
        response = await model.generate_content(prompt)
        return response.text
    except Exception as e:
        logger.error(f"Error getting cluster description: {e}")
        return "Cluster Description Unavailable"

@app.post("/user-segments/")
async def create_user_segments(payload: HostPayload):
    """Create user segments and get descriptions"""
    try:
        # Connect to database
        POSTGRES_URL = f"postgresql://{DB_USERNAME}:{DB_PASSWORD}@{payload.host}:{DB_PORT}/{DB_NAME}"
        conn = await asyncpg.connect(POSTGRES_URL)
        
        # Fetch and prepare data
        user_data = await fetch_user_data(conn, payload.host)
        feature_matrix, num_features, cat_features, encoded_features = prepare_features(user_data)
        
        # Perform clustering
        kmeans = KMeans(n_clusters=payload.n_clusters, random_state=42)
        clusters = kmeans.fit_predict(feature_matrix)
        user_data['cluster'] = clusters
        
        # Analyze clusters
        cluster_insights = []
        for cluster_id in range(payload.n_clusters):
            cluster_mask = clusters == cluster_id
            cluster_users = user_data[cluster_mask]
            
            # Calculate cluster statistics
            cluster_stats = {
                'cluster_id': int(cluster_id),
                'size': int(cluster_mask.sum()),
                'avg_age': float(cluster_users['age'].mean()),
                'avg_favorites': float(cluster_users['total_favorites'].mean()),
                'common_job': str(cluster_users['job'].mode().iloc[0]),
                'common_country': str(cluster_users['country'].mode().iloc[0]),
                'avg_favorited_price': float(cluster_users['avg_favorited_price'].mean()),
                'favorite_property_type': str(cluster_users['favorite_property_type'].mode().iloc[0]),
                'favorite_city': str(cluster_users['favorite_city'].mode().iloc[0]),
                'favorite_sale_rent': str(cluster_users['favorite_sale_rent'].mode().iloc[0]),
                'furnished_preference': float(cluster_users['furnished_preference_ratio'].mean()),
                'sale_preference': float(cluster_users['sale_preference_ratio'].mean()),
                'avg_installment_years': float(cluster_users['avg_installment_years'].mean()),
                'avg_delivery_time': float(cluster_users['avg_delivery_time'].mean()),
                'preferred_finishing': str(cluster_users['preferred_finishing'].mode().iloc[0])
            }
            
            # Get cluster description from Gemini
            description = await get_cluster_description(cluster_stats)
            cluster_stats['description'] = description
            cluster_insights.append(cluster_stats)
        
        await conn.close()
        
        return {
            "total_users": len(user_data),
            "n_clusters": payload.n_clusters,
            "cluster_insights": cluster_insights,
            "user_segments": user_data[['id', 'cluster']].to_dict(orient='records')
        }
        
    except Exception as e:
        logger.error(f"Error in user segmentation: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8081) 