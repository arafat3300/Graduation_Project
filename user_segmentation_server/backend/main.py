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
from sklearn.metrics import silhouette_score


#adjust the default host & no.of clusters
#adjust the db name


# Load environment variables
load_dotenv()

# Configure logging
logger = logging.getLogger("UserSegmentationLogger")
logger.setLevel(logging.INFO)
ch = logging.StreamHandler()
ch.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(message)s"))
logger.addHandler(ch)


# PostgreSQL configuration from environment variables
DB_USERNAME = os.getenv("DB_USERNAME", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "user_segmentation_test")

# Gemini API configuration
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY","AIzaSyDXLCM-4lzUKUGBEVtbFPQbCGa6uXXI8lU")
if not GOOGLE_API_KEY:
    raise ValueError("GOOGLE_API_KEY environment variable is not set")
genai.configure(api_key=GOOGLE_API_KEY)

app = FastAPI()

class HostPayload(BaseModel):
    host: str = "192.168.1.12"
    n_clusters: int = 5  # default number of clusters
    find_optimal_clusters: bool = False  # flag to find optimal number of clusters

def calculate_age(dob):
    if pd.isna(dob):
        return None
    today = datetime.now()
    return today.year - pd.to_datetime(dob).year

async def fetch_user_data(conn, host):
    """Fetch and prepare user data for segmentation (favorites 70% + recommendations 30%)"""
    try:
        users_query = """
        WITH weighted_properties AS (
            -- Favorites (weight = 1.0)
            SELECT 
                uf.user_id AS uid, 
                rp.id, rp.price, rp.type, rp.city, rp.area, rp.bedrooms, rp.payment_option,
                rp.sale_rent, rp.furnished, rp.installment_years, rp.delivery_in, rp.finishing,
                1.0 AS weight
            FROM real_estate_user_favorites uf
            JOIN real_estate_property rp ON uf.property_id = rp.id

            UNION ALL

            -- Recommendations (weight = 0.43)
            SELECT 
                r.user_id AS uid, 
                rp.id, rp.price, rp.type, rp.city, rp.area, rp.bedrooms, rp.payment_option,
                rp.sale_rent, rp.furnished, rp.installment_years, rp.delivery_in, rp.finishing,
                0.43 AS weight
            FROM real_estate_recommendedproperties r
            JOIN real_estate_recommendedpropertiesdetails d ON r.id = d.recommendation_id
            JOIN real_estate_property rp ON d.property_id = rp.id
        ),
        user_weighted_stats AS (
            SELECT 
                wp.uid AS user_id,
                COUNT(*) FILTER (WHERE weight = 1.0) as total_favorites,
                SUM(weight * price) / NULLIF(SUM(weight), 0) as avg_favorited_price,
                MODE() WITHIN GROUP (ORDER BY type) as favorite_property_type,
                MODE() WITHIN GROUP (ORDER BY city) as favorite_city,
                SUM(weight * area) / NULLIF(SUM(weight), 0) as avg_favorited_area,
                SUM(weight * bedrooms) / NULLIF(SUM(weight), 0) as avg_favorited_bedrooms,
                MODE() WITHIN GROUP (ORDER BY payment_option) as favorite_payment_option,
                MODE() WITHIN GROUP (ORDER BY sale_rent) as favorite_sale_rent,
                SUM(weight * CASE WHEN furnished = 'yes' THEN 1 ELSE 0 END)::float / NULLIF(SUM(weight), 0) as furnished_preference_ratio,
                -- Sale-specific preferences
                SUM(weight * CASE WHEN sale_rent = 'sale' THEN installment_years ELSE NULL END) 
                    / NULLIF(SUM(CASE WHEN sale_rent = 'sale' THEN weight ELSE 0 END), 0) as avg_installment_years,
                SUM(weight * CASE WHEN sale_rent = 'sale' THEN delivery_in ELSE NULL END) 
                    / NULLIF(SUM(CASE WHEN sale_rent = 'sale' THEN weight ELSE 0 END), 0) as avg_delivery_time,
                MODE() WITHIN GROUP (ORDER BY 
                    CASE WHEN sale_rent = 'sale' THEN finishing END
                ) as preferred_finishing,
                SUM(CASE WHEN sale_rent = 'sale' THEN weight ELSE 0 END) / NULLIF(SUM(weight), 0) as sale_preference_ratio
            FROM weighted_properties wp
            GROUP BY wp.uid
        )
        SELECT 
            u.id,
            u.job,
            u.country,
            u.dob,
            COALESCE(ws.total_favorites, 0) as total_favorites,
            ws.avg_favorited_price,
            ws.favorite_property_type,
            ws.favorite_city,
            ws.avg_favorited_area,
            ws.avg_favorited_bedrooms,
            ws.favorite_payment_option,
            ws.favorite_sale_rent,
            ws.furnished_preference_ratio,
            ws.avg_installment_years,
            ws.avg_delivery_time,
            ws.preferred_finishing,
            ws.sale_preference_ratio
        FROM 
            users_users u
            LEFT JOIN user_weighted_stats ws ON u.id = ws.user_id
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
    encoder = OneHotEncoder(sparse_output=False, handle_unknown='ignore')
    categorical_data = df[categorical_features].fillna('unknown')
    encoded_categorical = encoder.fit_transform(categorical_data)
    
    # Combine features
    feature_matrix = np.hstack([scaled_numerical, encoded_categorical])
    
    
    
    return feature_matrix, numerical_features, categorical_features, encoder.get_feature_names_out(categorical_features)

def get_cluster_description(cluster_data: Dict) -> Dict[str, str]:
    """Get cluster description from Gemini"""
    model = genai.GenerativeModel(model_name="models/gemini-2.0-flash")

    
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
    Name: [A unique formal 1-3 word segment name but yet simple english]
    Description: [2-3 detailed sentences describing what makes this segment unique, their key 
    preferences, and their typical behavior patterns]
    """
    
    try:
        response = model.generate_content(prompt)
        text = response.text
        
        # Split the response into name and description
        name_part = text.split("Name:")[1].split("Description:")[0].strip()
        desc_part = text.split("Description:")[1].strip()
        
        # Clean up special characters and formatting from name
        name = name_part.replace("\n", "").replace("**", "").replace("_", "").replace("-", " ").replace(":", "").replace(";", "").replace(",", "").replace(".", "").replace("!", "").replace("?", "").replace("'", "").replace('"', "").strip()
        
        # Clean up special characters from description
        description = desc_part.replace("\n", " ").replace("**", "").strip()
        
        return {
            "name": name,
            "description": description
        }
    except Exception as e:
        logger.error(f"Error getting cluster description: {e}")
        return {
            "name": "Unnamed Cluster",
            "description": "Cluster Description Unavailable"
        }
    

def calculate_silhouette_scores(feature_matrix: np.ndarray, max_clusters: int = 10) -> Dict[str, float]:
    """
    Calculate silhouette scores for different numbers of clusters to find the optimal number.
    
    Parameters:
    -----------
    feature_matrix : np.ndarray
        The feature matrix used for clustering
    max_clusters : int
        Maximum number of clusters to try
        
    Returns:
    --------
    Dict[str, float]
        Dictionary containing cluster numbers and their corresponding silhouette scores
    """
    silhouette_scores = {}
    
    # Try different numbers of clusters
    for n_clusters in range(2, max_clusters + 1):
        kmeans = KMeans(n_clusters=n_clusters, random_state=42)
        cluster_labels = kmeans.fit_predict(feature_matrix)
        
        # Calculate silhouette score
        score = silhouette_score(feature_matrix, cluster_labels)
        silhouette_scores[str(n_clusters)] = float(score)
        
    return silhouette_scores

@app.post("/user-segments/")
async def create_user_segments(payload: HostPayload):
    """Create user segments and get descriptions"""
    try:
        # Connect to database
        POSTGRES_URL = f"postgresql://{DB_USERNAME}:{DB_PASSWORD}@{payload.host}:{DB_PORT}/{DB_NAME}"
        conn = await asyncpg.connect(POSTGRES_URL)
        logger.info(f"\nStarting segmentation for host={payload.host} clusters={payload.n_clusters} find the optimal clusters:{payload.find_optimal_clusters} ")
        
        # Fetch and prepare data
        user_data = await fetch_user_data(conn, payload.host)
        feature_matrix, num_features, cat_features, encoded_features = prepare_features(user_data)
        
        # If find_optimal_clusters is True, calculate silhouette scores
        if payload.find_optimal_clusters:
            silhouette_scores = calculate_silhouette_scores(feature_matrix)
            # Find the optimal number of clusters (highest silhouette score)
            optimal_clusters = max(silhouette_scores.items(), key=lambda x: x[1])[0]
            logger.info(f"Optimal number of clusters: {optimal_clusters}")
            payload.n_clusters = int(optimal_clusters)
        
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
                "avg_favorited_area": float(cluster_users["avg_favorited_area"].mean()),
                "avg_favorited_bedrooms": float(cluster_users["avg_favorited_bedrooms"].mean()),
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
            description_dict = get_cluster_description(cluster_stats)
            cluster_stats.update(description_dict)
            cluster_insights.append(cluster_stats)
        
        await conn.close()
        
        response = {
            "total_users": len(user_data),
            "n_clusters": payload.n_clusters,
            "cluster_insights": cluster_insights,
            "user_segments": user_data[['id', 'cluster']].to_dict(orient='records')
        }
        
        # Add silhouette scores to response if optimal clusters were calculated
        if payload.find_optimal_clusters:
            response["silhouette_scores"] = silhouette_scores
            response["optimal_clusters"] = payload.n_clusters
        
        return response
        
    except Exception as e:
        logger.error(f"Error in user segmentation: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8081) 