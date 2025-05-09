from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import asyncpg
import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler, OneHotEncoder, KBinsDiscretizer, MinMaxScaler, RobustScaler
from sklearn.cluster import KMeans, DBSCAN, AgglomerativeClustering
from sklearn.mixture import GaussianMixture
from sklearn.neighbors import NearestNeighbors
from datetime import datetime
import logging
import google.generativeai as genai
from typing import List, Dict, Tuple
import json
import os
from dotenv import load_dotenv
from sklearn.metrics import silhouette_score, calinski_harabasz_score, davies_bouldin_score
import matplotlib.pyplot as plt


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
    logger.error("GOOGLE_API_KEY environment variable is not set")
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
        logger.info(f"Fetching user data from database at {host}")
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
        #left join to preserve users table as it is

        results = await conn.fetch(users_query)
        user_data = pd.DataFrame([dict(row) for row in results])
        logger.info(f"Fetched data for {len(user_data)} users")

        # Calculate age from dob
        user_data['age'] = user_data['dob'].apply(calculate_age)
        logger.info("Calculated ages for users")

        return user_data

    except Exception as e:
        logger.error(f"Error fetching user data: {e}")
        raise HTTPException(status_code=500, detail=str(e))

def create_derived_features(df: pd.DataFrame) -> pd.DataFrame:
    """Create derived features for better clustering"""
    try:
        logger.info("Creating derived features")
        
        # Convert all numeric columns to float and handle NaN
        numeric_columns = [
            'avg_favorited_price', 
            'avg_favorited_area', 
            'avg_favorited_bedrooms',
            'furnished_preference_ratio',
            'sale_preference_ratio',
            'avg_installment_years',
            'avg_delivery_time',
            'total_favorites',
            'age'
        ]
        
        for col in numeric_columns:
            if col in df.columns:
                df[col] = pd.to_numeric(df[col], errors='coerce')
                df[col] = df[col].fillna(df[col].median())
                df[col] = df[col].astype(float)
        
        # Enhanced price-related features
        df['price_per_sqm'] = df['avg_favorited_price'] / df['avg_favorited_area'].replace(0, np.nan)
        df['price_per_sqm'] = df['price_per_sqm'].fillna(df['price_per_sqm'].median())
        
        # Price elasticity (normalized)
        df['price_elasticity'] = (df['avg_favorited_price'] / df['avg_favorited_area'].replace(0, np.nan)) / df['avg_favorited_price'].mean()
        df['price_elasticity'] = df['price_elasticity'].fillna(df['price_elasticity'].median())
        
        # Enhanced property preference features
        df['property_type_strength'] = df.groupby('favorite_property_type')['favorite_property_type'].transform('count')
        df['property_type_strength'] = (df['property_type_strength'] - df['property_type_strength'].min()) / (df['property_type_strength'].max() - df['property_type_strength'].min())
        df['property_type_strength'] = df['property_type_strength'].fillna(0)
        
        # Enhanced location preference
        df['location_strength'] = df.groupby('favorite_city')['favorite_city'].transform('count')
        df['location_strength'] = (df['location_strength'] - df['location_strength'].min()) / (df['location_strength'].max() - df['location_strength'].min())
        df['location_strength'] = df['location_strength'].fillna(0)
        
        # Enhanced payment preference
        df['payment_preference_ratio'] = df.groupby('favorite_payment_option')['favorite_payment_option'].transform('count')
        df['payment_preference_ratio'] = (df['payment_preference_ratio'] - df['payment_preference_ratio'].min()) / (df['payment_preference_ratio'].max() - df['payment_preference_ratio'].min())
        df['payment_preference_ratio'] = df['payment_preference_ratio'].fillna(0)
        
        # New sophisticated features
        # Investment sophistication score
        df['investment_sophistication'] = (
            df['price_per_sqm'] * 
            df['location_strength'] * 
            (1 + df['sale_preference_ratio'])
        )
        df['investment_sophistication'] = (df['investment_sophistication'] - df['investment_sophistication'].min()) / (df['investment_sophistication'].max() - df['investment_sophistication'].min())
        
        # Property complexity score
        df['property_complexity'] = (
            df['avg_favorited_bedrooms'] * 
            df['avg_favorited_area'] * 
            (1 + df['furnished_preference_ratio'])
        )
        df['property_complexity'] = (df['property_complexity'] - df['property_complexity'].min()) / (df['property_complexity'].max() - df['property_complexity'].min())
        
        # Financial capacity indicator
        df['financial_capacity'] = (
            df['avg_favorited_price'] * 
            (1 + df['sale_preference_ratio']) * 
            (1 + df['payment_preference_ratio'])
        )
        df['financial_capacity'] = (df['financial_capacity'] - df['financial_capacity'].min()) / (df['financial_capacity'].max() - df['financial_capacity'].min())
        
        # Lifestyle preference score
        df['lifestyle_score'] = (
            df['furnished_preference_ratio'] * 
            df['property_complexity'] * 
            (1 + df['location_strength'])
        )
        df['lifestyle_score'] = (df['lifestyle_score'] - df['lifestyle_score'].min()) / (df['lifestyle_score'].max() - df['lifestyle_score'].min())
        
        # User engagement score
        df['engagement_score'] = (
            df['total_favorites'] * 
            (1 + df['property_type_strength']) * 
            (1 + df['location_strength'])
        )
        df['engagement_score'] = (df['engagement_score'] - df['engagement_score'].min()) / (df['engagement_score'].max() - df['engagement_score'].min())
        
        # Fill NaN values with 0 for all derived features
        derived_features = [
            'price_per_sqm', 'price_elasticity', 'property_type_strength',
            'location_strength', 'payment_preference_ratio', 'investment_sophistication',
            'property_complexity', 'financial_capacity', 'lifestyle_score',
            'engagement_score'
        ]
        
        for feature in derived_features:
            df[feature] = pd.to_numeric(df[feature], errors='coerce').fillna(0).astype(float)
        
        logger.info("Created enhanced derived features successfully")
        return df
    except Exception as e:
        logger.error(f"Error creating derived features: {e}")
        raise

def handle_outliers(df: pd.DataFrame, columns: List[str], method: str = 'iqr') -> pd.DataFrame:
    """Handle outliers in numerical features"""
    try:
        logger.info(f"Handling outliers using {method} method")
        df_clean = df.copy()
        
        for col in columns:
            if col not in df.columns:
                continue
                
            if method == 'iqr':
                # IQR method
                Q1 = df[col].quantile(0.25)
                Q3 = df[col].quantile(0.75)
                IQR = Q3 - Q1
                lower_bound = Q1 - 1.5 * IQR
                upper_bound = Q3 + 1.5 * IQR
                
                # Replace outliers with bounds
                df_clean[col] = df_clean[col].clip(lower=lower_bound, upper=upper_bound)
                
            elif method == 'zscore':
                # Z-score method
                mean = df[col].mean()
                std = df[col].std()
                z_scores = np.abs((df[col] - mean) / std)
                df_clean[col] = df[col].mask(z_scores > 3, mean)
                
            elif method == 'percentile':
                # Percentile method
                lower_bound = df[col].quantile(0.01)
                upper_bound = df[col].quantile(0.99)
                df_clean[col] = df_clean[col].clip(lower=lower_bound, upper=upper_bound)
        
        logger.info("Outlier handling completed")
        return df_clean
    except Exception as e:
        logger.error(f"Error handling outliers: {e}")
        raise

def prepare_features(df):
    """Prepare features for clustering with weighted importance"""
    try:
        logger.info("Preparing features for clustering")
        
        # Create derived features
        df = create_derived_features(df)
        
        # Updated feature weights based on importance
        feature_weights = {
            'price_per_sqm': 1.8,  # Increased weight
            'price_elasticity': 1.6,
            'property_type_strength': 1.4,
            'location_strength': 1.7,
            'payment_preference_ratio': 1.3,
            'investment_sophistication': 2.0,  # Highest weight
            'property_complexity': 1.5,
            'financial_capacity': 1.9,
            'lifestyle_score': 1.4,
            'engagement_score': 1.6
        }
        
        # Select most important features
        numerical_features = list(feature_weights.keys())
        
        # Convert all numerical features to float
        for feature in numerical_features:
            if feature in df.columns:
                df[feature] = pd.to_numeric(df[feature], errors='coerce').fillna(0).astype(float)
        
        # Enhanced outlier handling
        df = handle_outliers(df, numerical_features, method='iqr')
        df = handle_outliers(df, numerical_features, method='percentile')
        
        # Robust scaling with outlier handling
        robust_scaler = RobustScaler(quantile_range=(1, 99))  # More robust to outliers
        numerical_data = df[numerical_features].fillna(df[numerical_features].median())
        robust_scaled = robust_scaler.fit_transform(numerical_data)
        
        # MinMax scaling after robust scaling
        minmax_scaler = MinMaxScaler()
        scaled_numerical = minmax_scaler.fit_transform(robust_scaled)
        
        # Apply weights to numerical features
        for i, feature in enumerate(numerical_features):
            if feature in feature_weights:
                scaled_numerical[:, i] *= feature_weights[feature]
        
        # Handle categorical features
        categorical_features = [
            'favorite_property_type',
            'favorite_city', 
            'favorite_payment_option',
            'favorite_sale_rent',
            'preferred_finishing'
        ]
        
        encoder = OneHotEncoder(sparse_output=False, handle_unknown='ignore')
        categorical_data = df[categorical_features].fillna('unknown')
        encoded_categorical = encoder.fit_transform(categorical_data)
        
        # Combine features
        feature_matrix = np.hstack([scaled_numerical, encoded_categorical])
        logger.info(f"Created enhanced feature matrix with shape {feature_matrix.shape}")
        
        return feature_matrix, numerical_features, categorical_features, encoder.get_feature_names_out(categorical_features)
    except Exception as e:
        logger.error(f"Error preparing features: {e}")
        raise

def get_cluster_description(cluster_data: Dict) -> Dict[str, str]:
    """Get cluster description from Gemini"""
    try:
        logger.info("Generating cluster description using Gemini")
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
        
        response = model.generate_content(prompt)
        text = response.text
        
        # Split the response into name and description
        name_part = text.split("Name:")[1].split("Description:")[0].strip()
        desc_part = text.split("Description:")[1].strip()
        
        # Clean up special characters and formatting from name
        name = name_part.replace("\n", "").replace("**", "").replace("_", "").replace("-", " ").replace(":", "").replace(";", "").replace(",", "").replace(".", "").replace("!", "").replace("?", "").replace("'", "").replace('"', "").strip()
        
        # Clean up special characters from description
        description = desc_part.replace("\n", " ").replace("**", "").strip()
        
        logger.info(f"Generated cluster name: {name}")
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
    

def calculate_clustering_metrics(feature_matrix: np.ndarray, max_clusters: int = 10) -> Dict[str, Dict[str, float]]:
    """Calculate clustering metrics for different numbers of clusters"""
    try:
        logger.info(f"Calculating clustering metrics for 2 to {max_clusters} clusters")
        metrics = {}
        
        for n_clusters in range(2, max_clusters + 1):
            logger.info(f"Calculating metrics for {n_clusters} clusters")
            kmeans = KMeans(
                n_clusters=n_clusters, 
                random_state=42, 
                n_init=50,  # Increased from 20
                max_iter=500,  # Increased from 300
                algorithm='elkan'  # More efficient algorithm
            )
            cluster_labels = kmeans.fit_predict(feature_matrix)
            
            metrics[str(n_clusters)] = {
                'silhouette': silhouette_score(feature_matrix, cluster_labels),
                'calinski_harabasz': calinski_harabasz_score(feature_matrix, cluster_labels),
                'davies_bouldin': davies_bouldin_score(feature_matrix, cluster_labels),
                'inertia': kmeans.inertia_
            }
            
            logger.info(f"Metrics for {n_clusters} clusters:")
            logger.info(f"Silhouette: {metrics[str(n_clusters)]['silhouette']:.4f}")
            logger.info(f"Calinski-Harabasz: {metrics[str(n_clusters)]['calinski_harabasz']:.4f}")
            logger.info(f"Davies-Bouldin: {metrics[str(n_clusters)]['davies_bouldin']:.4f}")
            logger.info(f"Inertia: {metrics[str(n_clusters)]['inertia']:.4f}")
        
        return metrics
    except Exception as e:
        logger.error(f"Error calculating clustering metrics: {e}")
        raise

def find_optimal_clusters(metrics: Dict[str, Dict[str, float]]) -> Dict[str, int]:
    """Find optimal number of clusters based on different metrics"""
    try:
        optimal_clusters = {}
        
        # Extract metrics for each method
        silhouette_scores = {k: v['silhouette'] for k, v in metrics.items()}
        calinski_scores = {k: v['calinski_harabasz'] for k, v in metrics.items()}
        davies_scores = {k: v['davies_bouldin'] for k, v in metrics.items()}
        inertia_values = {k: v['inertia'] for k, v in metrics.items()}
        
        # Silhouette: higher is better
        optimal_clusters['silhouette'] = int(max(silhouette_scores.items(), key=lambda x: x[1])[0])
        
        # Calinski-Harabasz: higher is better
        optimal_clusters['calinski_harabasz'] = int(max(calinski_scores.items(), key=lambda x: x[1])[0])
        
        # Davies-Bouldin: lower is better
        optimal_clusters['davies_bouldin'] = int(min(davies_scores.items(), key=lambda x: x[1])[0])
        
        # Inertia: find elbow point
        inertia_values_list = list(inertia_values.values())
        n_clusters = list(inertia_values.keys())
        
        # Calculate the rate of change of inertia
        inertia_changes = np.diff(inertia_values_list)
        # Find the point where the rate of change starts to level off
        elbow_point = np.argmax(np.abs(np.diff(inertia_changes))) + 2
        optimal_clusters['inertia'] = int(n_clusters[elbow_point])
        
        logger.info(f"Optimal clusters found: {optimal_clusters}")
        return optimal_clusters
    except Exception as e:
        logger.error(f"Error finding optimal clusters: {e}")
        raise

def try_different_clustering_methods(feature_matrix: np.ndarray, n_clusters: int) -> Dict[str, Dict[str, float]]:
    """Calculate clustering metrics for K-means"""
    try:
        logger.info("Calculating K-means clustering metrics")
        metrics = {}
        
        # K-means with improved parameters
        kmeans = KMeans(
            n_clusters=n_clusters, 
            random_state=42, 
            n_init=50,
            max_iter=500,
            algorithm='elkan'
        )
        kmeans_labels = kmeans.fit_predict(feature_matrix)
        metrics['kmeans'] = {
            'silhouette': silhouette_score(feature_matrix, kmeans_labels),
            'calinski_harabasz': calinski_harabasz_score(feature_matrix, kmeans_labels),
            'davies_bouldin': davies_bouldin_score(feature_matrix, kmeans_labels),
            'inertia': kmeans.inertia_
        }
        
        logger.info(f"K-means metrics: silhouette={metrics['kmeans']['silhouette']:.4f}, "
                   f"calinski_harabasz={metrics['kmeans']['calinski_harabasz']:.4f}, "
                   f"davies_bouldin={metrics['kmeans']['davies_bouldin']:.4f}")
        
        return metrics
    except Exception as e:
        logger.error(f"Error calculating clustering metrics: {e}")
        raise

async def save_cluster_insights(conn, cluster_insights: List[Dict]):
    """Save cluster insights to the database"""
    try:
        logger.info("Saving cluster insights to database")
        
        # First, delete all existing records
        await conn.execute("DELETE FROM real_estate_clusters")
        logger.info("Deleted existing cluster records")
        
        # Prepare the insert query
        insert_query = """
        INSERT INTO real_estate_clusters (
            cluster_id, size, avg_age, avg_favorites, avg_favorited_area,
            avg_favorited_bedrooms, common_job, common_country, avg_favorited_price,
            favorite_property_type, favorite_city, favorite_sale_rent,
            furnished_preference, sale_preference, avg_installment_years,
            avg_delivery_time, preferred_finishing, name, description
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)
        """
        
        # Insert each cluster insight
        for insight in cluster_insights:
            # Round numeric values to 2 decimal places
            await conn.execute(
                insert_query,
                insight['cluster_id'],  # Integer, no rounding needed
                insight['size'],  # Integer, no rounding needed
                round(float(insight['avg_age']), 2),
                round(float(insight['avg_favorites']), 2),
                round(float(insight['avg_favorited_area']), 2),
                round(float(insight['avg_favorited_bedrooms']), 2),
                insight['common_job'],  # Text, no rounding needed
                insight['common_country'],  # Text, no rounding needed
                round(float(insight['avg_favorited_price']), 2),
                insight['favorite_property_type'],  # Text, no rounding needed
                insight['favorite_city'],  # Text, no rounding needed
                insight['favorite_sale_rent'],  # Text, no rounding needed
                round(float(insight['furnished_preference']), 2),
                round(float(insight['sale_preference']), 2),
                round(float(insight['avg_installment_years']), 2),
                round(float(insight['avg_delivery_time']), 2),
                insight['preferred_finishing'],  # Text, no rounding needed
                insight['name'],  # Text, no rounding needed
                insight['description']  # Text, no rounding needed
            )
        
        logger.info(f"Successfully saved {len(cluster_insights)} cluster insights to database")
        
    except Exception as e:
        logger.error(f"Error saving cluster insights to database: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/user-segments/")
async def create_user_segments(payload: HostPayload):
    """Create user segments and get descriptions"""
    try:
        logger.info(f"Starting segmentation with parameters: host={payload.host}, n_clusters={payload.n_clusters}, find_optimal_clusters={payload.find_optimal_clusters}")
        
        # Connect to database
        POSTGRES_URL = f"postgresql://{DB_USERNAME}:{DB_PASSWORD}@{payload.host}:{DB_PORT}/{DB_NAME}"
        logger.info(f"Connecting to database at {payload.host}:{DB_PORT}/{DB_NAME}")
        conn = await asyncpg.connect(POSTGRES_URL)
        
        # Fetch and prepare data
        user_data = await fetch_user_data(conn, payload.host)
        feature_matrix, num_features, cat_features, encoded_features = prepare_features(user_data)
        
        # If find_optimal_clusters is True, calculate all metrics
        if payload.find_optimal_clusters:
            logger.info("Finding optimal number of clusters")
            metrics = calculate_clustering_metrics(feature_matrix)
            optimal_clusters = find_optimal_clusters(metrics)
            
            # Use the most common optimal cluster number
            optimal_n = max(set(optimal_clusters.values()), key=list(optimal_clusters.values()).count)
            logger.info(f"Optimal number of clusters: {optimal_n}")
            payload.n_clusters = optimal_n
        
        # Perform K-means clustering
        logger.info(f"Performing K-means clustering with {payload.n_clusters} clusters")
        kmeans = KMeans(
            n_clusters=payload.n_clusters,
            random_state=42,
            n_init=50,
            max_iter=500,
            algorithm='elkan'
        )
        clusters = kmeans.fit_predict(feature_matrix)
        user_data['cluster'] = clusters
        
        # Analyze clusters
        logger.info("Analyzing clusters and generating descriptions")
        cluster_insights = []
        for cluster_id in range(payload.n_clusters):
            logger.info(f"Processing cluster {cluster_id}")
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
            logger.info(f"Completed processing cluster {cluster_id}: {description_dict['name']}")
        
        # Save cluster insights to database
        await save_cluster_insights(conn, cluster_insights)
        
        await conn.close()
        logger.info("Database connection closed")
        
        response = {
            "total_users": len(user_data),
            "n_clusters": payload.n_clusters,
            "clustering_metrics": metrics if payload.find_optimal_clusters else None,
            "cluster_insights": cluster_insights,
            "user_segments": user_data[['id', 'cluster']].to_dict(orient='records')
        }
        
        if payload.find_optimal_clusters:
            response["optimal_clusters"] = optimal_clusters
        
        logger.info(f"Segmentation complete. Found {len(cluster_insights)} clusters with {len(user_data)} total users")
        return response
        
    except Exception as e:
        logger.error(f"Error in user segmentation: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    logger.info("Starting user segmentation service")
    uvicorn.run(app, host="0.0.0.0", port=8081) 