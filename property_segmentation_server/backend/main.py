from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import asyncpg
import pandas as pd
import numpy as np
from typing import List, Dict, Optional, Tuple
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
DB_NAME = os.getenv("DB_NAME", "user_segmentation_test")

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

async def update_user_clusters(conn, user_segments: List[Dict]):
    """Update cluster assignments for all users"""
    try:
        logger.info(f"Starting user cluster updates for {len(user_segments)} users")
        
        # First, set all cluster_ids to NULL
        await conn.execute("UPDATE users_users SET cluster_id = NULL")
        logger.info("Reset all user cluster assignments to NULL")
        
        # Prepare the update query
        update_query = """
        UPDATE users_users
        SET cluster_id = $1
        WHERE id = $2
        """
        
        # Update each user's cluster
        updated_count = 0
        for segment in user_segments:
            try:
                await conn.execute(update_query, segment['cluster'], segment['id'])
                updated_count += 1
                if updated_count % 100 == 0:  # Log progress every 100 users
                    logger.info(f"Updated {updated_count} user cluster assignments")
            except Exception as e:
                logger.error(f"Error updating cluster for user {segment['id']}: {e}")
                continue
        
        logger.info(f"Successfully updated cluster assignments for {updated_count} users")
        
    except Exception as e:
        logger.error(f"Error in update_user_clusters: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error updating user clusters: {str(e)}")

async def update_property_clusters(conn, properties: List[Dict]):
    """Update cluster assignments and scores for all properties"""
    try:
        logger.info(f"Starting property cluster updates for {len(properties)} properties")
        
        # First, set all cluster_ids and cluster_scores to NULL
        await conn.execute("UPDATE real_estate_property SET cluster_id = NULL, cluster_score = NULL")
        logger.info("Reset all property cluster assignments to NULL")
        
        # Prepare the update query
        update_query = """
        UPDATE real_estate_property
        SET cluster_id = $1, cluster_score = $2
        WHERE id = $3
        """
        
        # Update each property's cluster and score
        updated_count = 0
        for prop in properties:
            try:
                await conn.execute(update_query, prop['cluster_id'], prop['cluster_score'], prop['id'])
                updated_count += 1
                if updated_count % 100 == 0:  # Log progress every 100 properties
                    logger.info(f"Updated {updated_count} property cluster assignments")
            except Exception as e:
                logger.error(f"Error updating cluster for property {prop['id']}: {e}")
                continue
        
        logger.info(f"Successfully updated cluster assignments for {updated_count} properties")
        
    except Exception as e:
        logger.error(f"Error in update_property_clusters: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error updating property clusters: {str(e)}")

async def get_user_cluster(user_id: int, host: str, find_optimal_clusters: bool = False) -> Dict:
    """Get user's cluster information from user segmentation service"""
    try:
        logger.info(f"Fetching cluster information for user {user_id} with find_optimal_clusters={find_optimal_clusters}")
        async with httpx.AsyncClient(timeout=None) as client:
            
            # Get user segments with the specified parameters
            request_data = {
                "host": host,
                "find_optimal_clusters": find_optimal_clusters
            }
            logger.info(f"Request data: {json.dumps(request_data)}")
            
            response = await client.post(
                f"http://{host}:{USER_SEGMENTATION_PORT}/user-segments/",
                json=request_data
            )
            
            if response.status_code != 200:
                logger.error(f"User segmentation service returned status code {response.status_code}")
                logger.error(f"Response content: {response.text}")
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"User segmentation service error: {response.text}"
                )
            
            data = response.json()
            logger.info(f"Received {len(data.get('user_segments', []))} user segments")
            
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
            
            return cluster_insight, data["user_segments"]
            
    except httpx.HTTPError as e:
        logger.error(f"HTTP error calling user segmentation service: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error calling user segmentation service: {str(e)}")
    except Exception as e:
        logger.error(f"Unexpected error in get_user_cluster: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

async def find_matching_properties(conn, cluster_insight: Dict, limit: int) -> List[Dict]:
    """Find properties matching the cluster characteristics"""
    try:
        logger.info(f"Finding matching properties for cluster {cluster_insight['name']}")
        logger.info(f"Cluster characteristics: {json.dumps(cluster_insight, indent=2)}")
        
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
        
        logger.info(f"Query parameters: {json.dumps(params, indent=2)}")
        
        # Execute query
        results = await conn.fetch(query, *params)
        properties = [dict(row) for row in results]
        
        # Add cluster_id and cluster_score to each property
        for prop in properties:
            prop['cluster_id'] = cluster_insight['cluster_id']
            prop['cluster_score'] = prop['similarity_score']
        
        logger.info(f"Found {len(properties)} matching properties")
        if properties:
            logger.info(f"Top property similarity score: {properties[0]['similarity_score']:.4f}")
            logger.info(f"Bottom property similarity score: {properties[-1]['similarity_score']:.4f}")
        
        return properties
        
    except Exception as e:
        logger.error(f"Error in find_matching_properties: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error finding matching properties: {str(e)}")

async def find_top_properties_for_cluster(conn, cluster_insight: Dict, limit: int = 10) -> List[Dict]:
    """Find top matching properties for a specific cluster"""
    try:
        logger.info(f"Finding top {limit} properties for cluster {cluster_insight['name']}")
        
        # Build the query based on cluster characteristics
        query = """
        WITH property_scores AS (
            SELECT 
                p.*,
                -- Calculate similarity scores for each property with more flexible matching
                CASE 
                    WHEN LOWER(p.type) LIKE LOWER($1) || '%' THEN 1 
                    WHEN LOWER($1) LIKE LOWER(p.type) || '%' THEN 1
                    WHEN p.type IS NULL THEN 0.3
                    ELSE 0 
                END as type_score,
                
                CASE 
                    WHEN LOWER(p.city) LIKE LOWER($2) || '%' THEN 1
                    WHEN LOWER($2) LIKE LOWER(p.city) || '%' THEN 1
                    WHEN p.city IS NULL THEN 0.3
                    ELSE 0 
                END as city_score,
                
                CASE 
                    WHEN LOWER(p.sale_rent) LIKE LOWER($3) || '%' THEN 1
                    WHEN LOWER($3) LIKE LOWER(p.sale_rent) || '%' THEN 1
                    WHEN p.sale_rent IS NULL THEN 0.3
                    ELSE 0 
                END as sale_rent_score,
                
                CASE 
                    WHEN LOWER(p.finishing) LIKE LOWER($4) || '%' THEN 1
                    WHEN LOWER($4) LIKE LOWER(p.finishing) || '%' THEN 1
                    WHEN p.finishing IS NULL THEN 0.3
                    ELSE 0 
                END as finishing_score,
                
                -- Price similarity (normalized with more flexible range)
                CASE 
                    WHEN p.price IS NULL THEN 0.3
                    WHEN p.price BETWEEN $5 * 0.7 AND $5 * 1.3 THEN 1
                    WHEN p.price BETWEEN $5 * 0.5 AND $5 * 1.5 THEN 0.65
                    WHEN p.price BETWEEN $5 * 0.3 AND $5 * 1.7 THEN 0.45
                    ELSE 0.4
                END as price_score,
                
                -- Area similarity (normalized with more flexible range)
                CASE 
                    WHEN p.area IS NULL THEN 0.3
                    WHEN p.area BETWEEN $6 * 0.7 AND $6 * 1.3 THEN 1
                    WHEN p.area BETWEEN $6 * 0.5 AND $6 * 1.5 THEN 0.8
                    WHEN p.area BETWEEN $6 * 0.3 AND $6 * 1.7 THEN 0.6
                    ELSE 0.4
                END as area_score,
                
                -- Bedrooms similarity (normalized with more flexible range)
                CASE 
                    WHEN p.bedrooms IS NULL THEN 0.3
                    WHEN p.bedrooms BETWEEN FLOOR($7 * 0.8) AND CEIL($7 * 1.2) THEN 1
                    WHEN p.bedrooms BETWEEN FLOOR($7 * 0.6) AND CEIL($7 * 1.4) THEN 0.8
                    WHEN p.bedrooms BETWEEN FLOOR($7 * 0.4) AND CEIL($7 * 1.6) THEN 0.6
                    ELSE 0.4
                END as bedrooms_score,
                
                -- Installment years similarity (normalized with more flexible range)
                CASE 
                    WHEN p.installment_years IS NULL THEN 0.3
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
                    type_score * 0.20 +
                    city_score * 0.20 +
                    sale_rent_score * 0.05 +
                    finishing_score * 0.05 +
                    price_score * 0.20 +
                    area_score * 0.15 +
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
        
        # Add cluster_id and cluster_score to each property
        for prop in properties:
            prop['cluster_id'] = cluster_insight['cluster_id']
            prop['cluster_score'] = prop['similarity_score']
        
        logger.info(f"Found {len(properties)} top properties for cluster {cluster_insight['name']}")
        if properties:
            logger.info(f"Top property similarity score: {properties[0]['similarity_score']:.4f}")
            logger.info(f"Bottom property similarity score: {properties[-1]['similarity_score']:.4f}")
        
        return properties
        
    except Exception as e:
        logger.error(f"Error finding top properties for cluster: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error finding top properties: {str(e)}")

async def get_all_clusters(host: str, find_optimal_clusters: bool = False) -> Tuple[List[Dict], List[Dict]]:
    """Get all cluster information from user segmentation service"""
    try:
        logger.info(f"Fetching all cluster information with find_optimal_clusters={find_optimal_clusters}")
        async with httpx.AsyncClient(timeout=None) as client:
            # Get all segments with the specified parameters
            request_data = {
                "host": host,
                "find_optimal_clusters": find_optimal_clusters
            }
            logger.info(f"Request data: {json.dumps(request_data)}")
            
            response = await client.post(
                f"http://{host}:{USER_SEGMENTATION_PORT}/user-segments/",
                json=request_data
            )
            
            if response.status_code != 200:
                logger.error(f"User segmentation service returned status code {response.status_code}")
                logger.error(f"Response content: {response.text}")
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"User segmentation service error: {response.text}"
                )
            
            data = response.json()
            logger.info(f"Received {len(data.get('user_segments', []))} user segments")
            logger.info(f"Received {len(data.get('cluster_insights', []))} cluster insights")
            
            return data["cluster_insights"], data["user_segments"]
            
    except httpx.HTTPError as e:
        logger.error(f"HTTP error calling user segmentation service: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error calling user segmentation service: {str(e)}")
    except Exception as e:
        logger.error(f"Unexpected error in get_all_clusters: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

async def update_all_cluster_assignments(conn, cluster_insights: List[Dict], user_segments: List[Dict], properties_per_cluster: int = 10):
    """Update cluster assignments for all users and properties"""
    try:
        logger.info("Starting cluster assignment updates")
        logger.info(f"Processing {len(cluster_insights)} clusters")
        
        # Reset all assignments
        await conn.execute("UPDATE users_users SET cluster_id = NULL")
        await conn.execute("UPDATE real_estate_property SET cluster_id = NULL, cluster_score = NULL")
        logger.info("Reset all cluster assignments to NULL")
        
        # Update user cluster assignments
        update_user_query = """
        UPDATE users_users
        SET cluster_id = $1
        WHERE id = $2
        """
        
        updated_users = 0
        for segment in user_segments:
            try:
                await conn.execute(update_user_query, segment['cluster'], segment['id'])
                updated_users += 1
                if updated_users % 100 == 0:
                    logger.info(f"Updated {updated_users} user cluster assignments")
            except Exception as e:
                logger.error(f"Error updating cluster for user {segment['id']}: {e}")
                continue
        
        logger.info(f"Successfully updated cluster assignments for {updated_users} users")
        
        # Find and update top properties for each cluster
        all_properties = []
        cluster_properties = {}  # To track properties per cluster
        
        for cluster in cluster_insights:
            try:
                logger.info(f"Finding top properties for cluster {cluster['name']} (ID: {cluster['cluster_id']})")
                properties = await find_top_properties_for_cluster(conn, cluster, properties_per_cluster)
                all_properties.extend(properties)
                cluster_properties[cluster['cluster_id']] = properties
                logger.info(f"Found {len(properties)} top properties for cluster {cluster['name']}")
            except Exception as e:
                logger.error(f"Error finding properties for cluster {cluster['name']}: {e}")
                continue
        
        # Update property cluster assignments
        update_property_query = """
        UPDATE real_estate_property
        SET cluster_id = $1, cluster_score = $2
        WHERE id = $3
        """
        
        updated_properties = 0
        for prop in all_properties:
            try:
                await conn.execute(update_property_query, prop['cluster_id'], prop['cluster_score'], prop['id'])
                updated_properties += 1
                if updated_properties % 100 == 0:
                    logger.info(f"Updated {updated_properties} property cluster assignments")
            except Exception as e:
                logger.error(f"Error updating cluster for property {prop['id']}: {e}")
                continue
        
        logger.info(f"Successfully updated cluster assignments for {updated_properties} properties")
        
        # Prepare cluster statistics
        cluster_stats = []
        for cluster in cluster_insights:
            cluster_id = cluster['cluster_id']
            properties = cluster_properties.get(cluster_id, [])
            cluster_stats.append({
                "cluster_id": cluster_id,
                "cluster_name": cluster['name'],
                "properties_count": len(properties),
                "top_property_score": properties[0]['cluster_score'] if properties else None,
                "bottom_property_score": properties[-1]['cluster_score'] if properties else None
            })
        
        return {
            "updated_users": updated_users,
            "updated_properties": updated_properties,
            "properties_per_cluster": properties_per_cluster,
            "cluster_statistics": cluster_stats
        }
        
    except Exception as e:
        logger.error(f"Error in update_all_cluster_assignments: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error updating cluster assignments: {str(e)}")

@app.post("/property-segmentation/")
async def get_property_recommendations(request: PropertyRecommendationRequest):
    """Get property recommendations for a user based on their cluster"""
    try:
        logger.info(f"Received property recommendation request for user {request.user_id}")
        logger.info(f"Request parameters: {json.dumps(request.dict(), indent=2)}")
        
        # Connect to database
        POSTGRES_URL = f"postgresql://{DB_USERNAME}:{DB_PASSWORD}@{request.host}:{DB_PORT}/{DB_NAME}"
        logger.info(f"Connecting to database at {request.host}:{DB_PORT}/{DB_NAME}")
        conn = await asyncpg.connect(POSTGRES_URL)
        logger.info("Database connection established")
        
        # Get all cluster information and user segments
        cluster_insights, user_segments = await get_all_clusters(
            request.host,
            request.find_optimal_clusters
        )
        
        # Find the user's cluster
        user_segment = next(
            (segment for segment in user_segments if segment["id"] == request.user_id),
            None
        )
        
        if not user_segment:
            logger.error(f"User {request.user_id} not found in segments")
            raise HTTPException(status_code=404, detail=f"User {request.user_id} not found in segments")
        
        # Get the cluster insight for this user
        user_cluster_insight = next(
            (insight for insight in cluster_insights 
             if insight["cluster_id"] == user_segment["cluster"]),
            None
        )
        
        if not user_cluster_insight:
            logger.error(f"Cluster insights not found for user's cluster {user_segment['cluster']}")
            raise HTTPException(status_code=500, detail="Cluster insights not found")
        
        # Update all cluster assignments
        update_results = await update_all_cluster_assignments(
            conn, 
            cluster_insights,  # Pass all cluster insights
            user_segments,
            request.limit
        )
        
        # Find matching properties for the specific user
        properties = await find_matching_properties(conn, user_cluster_insight, request.limit)
        
        await conn.close()
        logger.info("Database connection closed")
        
        response = {
            "user_id": request.user_id,
            "cluster_name": user_cluster_insight["name"],
            "cluster_description": user_cluster_insight["description"],
            "recommended_properties": properties,
            "update_results": update_results
        }
        logger.info(f"Returning {len(properties)} property recommendations for user {request.user_id}")
        return response
        
    except Exception as e:
        logger.error(f"Error in property recommendations: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    logger.info("Starting property segmentation service")
    uvicorn.run(app, host="0.0.0.0", port=8082) 