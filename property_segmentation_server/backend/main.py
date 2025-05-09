from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import asyncpg
import pandas as pd
import numpy as np
from typing import List, Dict, Optional
import httpx
import logging
from dotenv import load_dotenv
import os
import json

# Load environment variables
load_dotenv()

# Configure logging
logger = logging.getLogger("PropertySegmentationLogger")
logger.setLevel(logging.INFO)
ch = logging.StreamHandler()
ch.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(message)s"))
logger.addHandler(ch)

# PostgreSQL configuration from environment variables
DB_USERNAME = os.getenv("DB_USERNAME", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "odoo18v3")

app = FastAPI()

class PropertyRecommendationRequest(BaseModel):
    user_id: int
    host: str = "192.168.1.12"
    limit: int = 10  # Number of properties to recommend
    n_clusters: int = 3
    find_optimal_clusters: bool = False

# User segmentation service configuration
default_host = PropertyRecommendationRequest.model_fields['host'].default
USER_SEGMENTATION_HOST = os.getenv("USER_SEGMENTATION_HOST", default_host)
USER_SEGMENTATION_PORT = os.getenv("USER_SEGMENTATION_PORT", "8081")

async def get_user_cluster(user_id: int, host: str, find_optimal_clusters: bool = False) -> Dict:
    """Get user's cluster information from user segmentation service"""
    try:
        logger.info(f"Fetching cluster information for user {user_id} with find_optimal_clusters={find_optimal_clusters}")
        async with httpx.AsyncClient(timeout=None) as client:
            
            # Get user segments with the specified parameters
            logger.info(f"Calling user segmentation service at {host}:{USER_SEGMENTATION_PORT}")
            response = await client.post(
                f"http://{host}:{USER_SEGMENTATION_PORT}/user-segments/",
                json={
                    "host": host,
                    "find_optimal_clusters": find_optimal_clusters
                }
            )
            response.raise_for_status()
            data = response.json()
            logger.info(f"Received response from user segmentation service: {len(data.get('user_segments', []))} segments found")
            
            # Find the user's cluster
            user_segment = next(
                (segment for segment in data["user_segments"] if segment["id"] == user_id),
                None
            )
            
            if not user_segment:
                logger.error(f"User {user_id} not found in segments")
                raise HTTPException(status_code=404, detail=f"User {user_id} not found in segments")
            
            logger.info(f"Found user {user_id} in cluster {user_segment['cluster']}")
            
            # Get the cluster insights for this user's cluster
            cluster_insight = next(
                (insight for insight in data["cluster_insights"] 
                 if insight["cluster_id"] == user_segment["cluster"]),
                None
            )
            
            if cluster_insight:
                logger.info(f"Retrieved cluster insights for cluster {user_segment['cluster']}: {cluster_insight['name']}")
            else:
                logger.error(f"Cluster insights not found for cluster {user_segment['cluster']}")
                raise HTTPException(status_code=500, detail="Cluster insights not found")
            
            return cluster_insight
            
    except httpx.HTTPError as e:
        logger.error(f"Error calling user segmentation service: {e}")
        raise HTTPException(status_code=500, detail="Error getting user cluster information")

async def find_matching_properties(conn, cluster_insight: Dict, limit: int) -> List[Dict]:
    """Find properties matching the cluster characteristics"""
    try:
        logger.info(f"Finding matching properties for cluster {cluster_insight['name']} with limit {limit}")
        
        # First, check if there are any properties at all
        count_query = "SELECT COUNT(*) FROM real_estate_property"
        total_count = await conn.fetchval(count_query)
        logger.info(f"Total properties in database: {total_count}")
        
        if total_count == 0:
            logger.error("No properties found in the database")
            return []
        
        # Build the query based on cluster characteristics
        query = """
        WITH property_scores AS (
            SELECT 
                p.*,
                -- Calculate similarity scores for each property with more flexible matching
                CASE 
                    WHEN LOWER(p.type) LIKE LOWER($1) || '%' THEN 1 
                    WHEN LOWER($1) LIKE LOWER(p.type) || '%' THEN 1
                    WHEN p.type IS NULL THEN 0.5
                    ELSE 0 
                END as type_score,
                
                CASE 
                    WHEN LOWER(p.city) LIKE LOWER($2) || '%' THEN 1
                    WHEN LOWER($2) LIKE LOWER(p.city) || '%' THEN 1
                    WHEN p.city IS NULL THEN 0.5
                    ELSE 0 
                END as city_score,
                
                CASE 
                    WHEN LOWER(p.sale_rent) LIKE LOWER($3) || '%' THEN 1
                    WHEN LOWER($3) LIKE LOWER(p.sale_rent) || '%' THEN 1
                    WHEN p.sale_rent IS NULL THEN 0.5
                    ELSE 0 
                END as sale_rent_score,
                
                CASE 
                    WHEN LOWER(p.finishing) LIKE LOWER($4) || '%' THEN 1
                    WHEN LOWER($4) LIKE LOWER(p.finishing) || '%' THEN 1
                    WHEN p.finishing IS NULL THEN 0.5
                    ELSE 0 
                END as finishing_score,
                
                -- Price similarity (normalized with more flexible range)
                CASE 
                    WHEN p.price IS NULL THEN 0.5
                    WHEN p.price BETWEEN $5 * 0.7 AND $5 * 1.3 THEN 1
                    WHEN p.price BETWEEN $5 * 0.5 AND $5 * 1.5 THEN 0.8
                    WHEN p.price BETWEEN $5 * 0.3 AND $5 * 1.7 THEN 0.6
                    ELSE 0.4
                END as price_score,
                
                -- Area similarity (normalized with more flexible range)
                CASE 
                    WHEN p.area IS NULL THEN 0.5
                    WHEN p.area BETWEEN $6 * 0.7 AND $6 * 1.3 THEN 1
                    WHEN p.area BETWEEN $6 * 0.5 AND $6 * 1.5 THEN 0.8
                    WHEN p.area BETWEEN $6 * 0.3 AND $6 * 1.7 THEN 0.6
                    ELSE 0.4
                END as area_score,
                
                -- Bedrooms similarity (normalized with more flexible range)
                CASE 
                    WHEN p.bedrooms IS NULL THEN 0.5
                    WHEN p.bedrooms BETWEEN FLOOR($7 * 0.8) AND CEIL($7 * 1.2) THEN 1
                    WHEN p.bedrooms BETWEEN FLOOR($7 * 0.6) AND CEIL($7 * 1.4) THEN 0.8
                    WHEN p.bedrooms BETWEEN FLOOR($7 * 0.4) AND CEIL($7 * 1.6) THEN 0.6
                    ELSE 0.4
                END as bedrooms_score,
                
                -- Installment years similarity (normalized with more flexible range)
                CASE 
                    WHEN p.installment_years IS NULL THEN 0.5
                    WHEN LOWER(p.sale_rent) = 'sale' THEN 
                        CASE 
                            WHEN p.installment_years BETWEEN $8 * 0.7 AND $8 * 1.3 THEN 1
                            WHEN p.installment_years BETWEEN $8 * 0.5 AND $8 * 1.5 THEN 0.8
                            WHEN p.installment_years BETWEEN $8 * 0.3 AND $8 * 1.7 THEN 0.6
                            ELSE 0.4
                        END
                    ELSE 0.5
                END as installment_score,
                
                -- Delivery time similarity (normalized with more flexible range)
                CASE 
                    WHEN p.delivery_in IS NULL THEN 0.5
                    WHEN LOWER(p.sale_rent) = 'sale' THEN 
                        CASE 
                            WHEN p.delivery_in BETWEEN $9 * 0.7 AND $9 * 1.3 THEN 1
                            WHEN p.delivery_in BETWEEN $9 * 0.5 AND $9 * 1.5 THEN 0.8
                            WHEN p.delivery_in BETWEEN $9 * 0.3 AND $9 * 1.7 THEN 0.6
                            ELSE 0.4
                        END
                    ELSE 0.5
                END as delivery_score
            FROM real_estate_property p
            WHERE p.status = 'approved'
        ),
        scored_properties AS (
            SELECT 
                id,
                price,
                bedrooms,
                bathrooms,
                type,
                furnished,
                compound,
                payment_option,
                city,
                sale_rent,
                area,
                down_payment,
                installment_years,
                delivery_in,
                finishing,
                status,
                -- Calculate total similarity score with adjusted weights
                (
                    type_score * 0.15 +
                    city_score * 0.15 +
                    sale_rent_score * 0.15 +
                    finishing_score * 0.15 +
                    price_score * 0.15 +
                    area_score * 0.1 +
                    bedrooms_score * 0.1 +
                    installment_score * 0.025 +
                    delivery_score * 0.025
                ) as similarity_score,
                -- Include individual scores for debugging
                type_score,
                city_score,
                sale_rent_score,
                finishing_score,
                price_score,
                area_score,
                bedrooms_score,
                installment_score,
                delivery_score
            FROM property_scores
        )
        SELECT * FROM scored_properties
        WHERE similarity_score > 0.2
        ORDER BY similarity_score DESC
        LIMIT $10
        """
        
        # Prepare parameters for the query
        params = [
            cluster_insight['favorite_property_type'],
            cluster_insight['favorite_city'],
            cluster_insight['favorite_sale_rent'],
            cluster_insight['preferred_finishing'],
            float(cluster_insight['avg_favorited_price']),
            float(cluster_insight['avg_favorited_area']),
            float(cluster_insight['avg_favorited_bedrooms']),
            float(cluster_insight['avg_installment_years']),
            float(cluster_insight['avg_delivery_time']),
            limit
        ]
        
        # Execute query
        results = await conn.fetch(query, *params)
        properties = [dict(row) for row in results]
        logger.info(f"Found {len(properties)} matching properties")
        
        return properties
        
    except Exception as e:
        logger.error(f"Error finding matching properties: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/property-segmentation/")
async def get_property_recommendations(request: PropertyRecommendationRequest):
    """Get property recommendations for a user based on their cluster"""
    try:
        logger.info(f"Received property recommendation request for user {request.user_id}")
        logger.info(f"Request parameters: host={request.host}, limit={request.limit}, find_optimal_clusters={request.find_optimal_clusters}")
        
        # Connect to database
        POSTGRES_URL = f"postgresql://{DB_USERNAME}:{DB_PASSWORD}@{request.host}:{DB_PORT}/{DB_NAME}"
        logger.info(f"Connecting to database at {request.host}:{DB_PORT}/{DB_NAME}")
        conn = await asyncpg.connect(POSTGRES_URL)
        
        # Get user's cluster information
        cluster_insight = await get_user_cluster(
            request.user_id, 
            request.host,
            request.find_optimal_clusters
        )
        
        # Find matching properties
        properties = await find_matching_properties(conn, cluster_insight, request.limit)
        
        await conn.close()
        logger.info("Database connection closed")
        
        response = {
            "user_id": request.user_id,
            "cluster_name": cluster_insight["name"],
            "cluster_description": cluster_insight["description"],
            "recommended_properties": properties
        }
        logger.info(f"Returning {len(properties)} property recommendations for user {request.user_id}")
        return response
        
    except Exception as e:
        logger.error(f"Error in property recommendations: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    logger.info("Starting property segmentation service")
    uvicorn.run(app, host="0.0.0.0", port=8082) 