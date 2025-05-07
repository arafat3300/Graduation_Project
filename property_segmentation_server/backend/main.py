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
        
        available_count_query = "SELECT COUNT(*) FROM real_estate_property WHERE status = 'available'"
        available_count = await conn.fetchval(available_count_query)
        logger.info(f"Available properties in database: {available_count}")
        
        # Get sample of properties to understand the data
        sample_query = """
        SELECT type, city, sale_rent, finishing, price, area, bedrooms
        FROM real_estate_property 
        WHERE status = 'available'
        LIMIT 5
        """
        sample_results = await conn.fetch(sample_query)
        logger.info("Sample of available properties:")
        for row in sample_results:
            logger.info(f"Property: Type={row['type']}, City={row['city']}, "
                       f"Sale/Rent={row['sale_rent']}, Finishing={row['finishing']}, "
                       f"Price={row['price']}, Area={row['area']}, Bedrooms={row['bedrooms']}")
        
        # Build the query based on cluster characteristics with more flexible matching
        query = """
        WITH property_scores AS (
            SELECT 
                p.*,
                -- Calculate similarity scores for each property with more flexible matching
                CASE 
                    WHEN LOWER(p.type) LIKE LOWER($1) || '%' THEN 1 
                    WHEN LOWER($1) LIKE LOWER(p.type) || '%' THEN 1
                    ELSE 0 
                END as type_score,
                
                CASE 
                    WHEN LOWER(p.city) LIKE LOWER($2) || '%' THEN 1
                    WHEN LOWER($2) LIKE LOWER(p.city) || '%' THEN 1
                    ELSE 0 
                END as city_score,
                
                CASE 
                    WHEN LOWER(p.sale_rent) LIKE LOWER($3) || '%' THEN 1
                    WHEN LOWER($3) LIKE LOWER(p.sale_rent) || '%' THEN 1
                    ELSE 0 
                END as sale_rent_score,
                
                CASE 
                    WHEN LOWER(p.finishing) LIKE LOWER($4) || '%' THEN 1
                    WHEN LOWER($4) LIKE LOWER(p.finishing) || '%' THEN 1
                    ELSE 0 
                END as finishing_score,
                
                -- Price similarity (normalized with more flexible range)
                CASE 
                    WHEN p.price BETWEEN $5 * 0.7 AND $5 * 1.3 THEN 1
                    WHEN p.price BETWEEN $5 * 0.5 AND $5 * 1.5 THEN 0.8
                    WHEN p.price BETWEEN $5 * 0.3 AND $5 * 1.7 THEN 0.6
                    ELSE 0.4
                END as price_score,
                
                -- Area similarity (normalized with more flexible range)
                CASE 
                    WHEN p.area BETWEEN $6 * 0.7 AND $6 * 1.3 THEN 1
                    WHEN p.area BETWEEN $6 * 0.5 AND $6 * 1.5 THEN 0.8
                    WHEN p.area BETWEEN $6 * 0.3 AND $6 * 1.7 THEN 0.6
                    ELSE 0.4
                END as area_score,
                
                -- Bedrooms similarity (normalized with more flexible range)
                CASE 
                    WHEN p.bedrooms BETWEEN FLOOR($7 * 0.8) AND CEIL($7 * 1.2) THEN 1
                    WHEN p.bedrooms BETWEEN FLOOR($7 * 0.6) AND CEIL($7 * 1.4) THEN 0.8
                    WHEN p.bedrooms BETWEEN FLOOR($7 * 0.4) AND CEIL($7 * 1.6) THEN 0.6
                    ELSE 0.4
                END as bedrooms_score,
                
                -- Installment years similarity (normalized with more flexible range)
                CASE 
                    WHEN LOWER(p.sale_rent) = 'sale' THEN 
                        CASE 
                            WHEN p.installment_years BETWEEN $8 * 0.7 AND $8 * 1.3 THEN 1
                            WHEN p.installment_years BETWEEN $8 * 0.5 AND $8 * 1.5 THEN 0.8
                            WHEN p.installment_years BETWEEN $8 * 0.3 AND $8 * 1.7 THEN 0.6
                            ELSE 0.4
                        END
                    ELSE 0
                END as installment_score,
                
                -- Delivery time similarity (normalized with more flexible range)
                CASE 
                    WHEN LOWER(p.sale_rent) = 'sale' THEN 
                        CASE 
                            WHEN p.delivery_in BETWEEN $9 * 0.7 AND $9 * 1.3 THEN 1
                            WHEN p.delivery_in BETWEEN $9 * 0.5 AND $9 * 1.5 THEN 0.8
                            WHEN p.delivery_in BETWEEN $9 * 0.3 AND $9 * 1.7 THEN 0.6
                            ELSE 0.4
                        END
                    ELSE 0
                END as delivery_score
            FROM real_estate_property p
            WHERE p.status = 'available'
        )
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
        WHERE similarity_score > 0.3  -- Only return properties with some similarity
        ORDER BY similarity_score DESC
        LIMIT $10
        """
        
        # Execute query with cluster characteristics
        logger.info("Executing property matching query with cluster characteristics")
        
        # Prepare parameters for logging
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
        
        # Log parameters in a readable format
        param_names = [
            'property_type', 'city', 'sale_rent', 'finishing',
            'avg_price', 'avg_area', 'avg_bedrooms',
            'avg_installment_years', 'avg_delivery_time', 'limit'
        ]
        logger.info(f"Query parameters: {json.dumps(dict(zip(param_names, params)), indent=2)}")
        
        results = await conn.fetch(query, *params)
        
        properties = [dict(row) for row in results]
        logger.info(f"Found {len(properties)} matching properties")
        
        if len(properties) > 0:
            # Log details of the first property for debugging
            first_prop = properties[0]
            logger.info("First matching property details:")
            logger.info(f"Type: {first_prop['type']} (score: {first_prop['type_score']})")
            logger.info(f"City: {first_prop['city']} (score: {first_prop['city_score']})")
            logger.info(f"Sale/Rent: {first_prop['sale_rent']} (score: {first_prop['sale_rent_score']})")
            logger.info(f"Finishing: {first_prop['finishing']} (score: {first_prop['finishing_score']})")
            logger.info(f"Price: {first_prop['price']} (score: {first_prop['price_score']})")
            logger.info(f"Area: {first_prop['area']} (score: {first_prop['area_score']})")
            logger.info(f"Bedrooms: {first_prop['bedrooms']} (score: {first_prop['bedrooms_score']})")
            logger.info(f"Total similarity score: {first_prop['similarity_score']}")
        else:
            logger.warning("No properties found with similarity score > 0.3. This might indicate:")
            logger.warning("1. No properties in the database")
            logger.warning("2. No properties marked as 'available'")
            logger.warning("3. Properties exist but don't match the cluster characteristics")
            
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
