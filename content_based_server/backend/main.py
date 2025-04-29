from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import asyncpg
import pandas as pd
import logging
from sklearn.preprocessing import MinMaxScaler, OneHotEncoder
from sklearn.metrics.pairwise import cosine_similarity
from contextlib import asynccontextmanager

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ContentBasedLogger")

# PostgreSQL configuration
DB_USERNAME = "postgres"
DB_PASSWORD = "postgres"
DB_PORT = "5432"
DB_NAME = "odoo18v3"

@asynccontextmanager
async def lifespan(app: FastAPI):
    yield

app = FastAPI(lifespan=lifespan)

class UserIdPayload(BaseModel):
    user_id: int
    host: str

@app.post("/recommendations/")
async def get_recommendations(payload: UserIdPayload):
    user_id = payload.user_id
    host = payload.host

    logger.info(f"Fetching recommendations for user_id: {user_id} from host: {host}")

    POSTGRES_URL = f"postgresql://{DB_USERNAME}:{DB_PASSWORD}@{host}:{DB_PORT}/{DB_NAME}"
    logger.debug(f"Connecting to PostgreSQL at: {POSTGRES_URL}")

    try:
        conn = await asyncpg.connect(POSTGRES_URL)
        logger.info("Successfully connected to the database.")

        # Fetch properties
        properties_response = await conn.fetch("SELECT * FROM public.real_estate_property")
        properties_df = pd.DataFrame([dict(row) for row in properties_response])
        logger.debug(f"Property DataFrame columns: {properties_df.columns}")
        properties_df = properties_df.drop_duplicates(subset=["id"])
        properties_df["id"] = properties_df["id"].astype(int)
        properties_df["level"] = properties_df["level"].fillna(0)

        # Fetch user favorites
        favorites_response = await conn.fetch(
            "SELECT * FROM public.real_estate_user_favorites WHERE user_id = $1", user_id
        )
        user_favorites_df = pd.DataFrame([dict(row) for row in favorites_response])
        logger.debug(f"Favorites DataFrame columns: {user_favorites_df.columns}")
        user_favorites_df = user_favorites_df.drop_duplicates(subset=["property_id"])
        favorite_property_ids = user_favorites_df["property_id"].tolist()
        logger.info(f"Favorite property IDs: {favorite_property_ids}")

        if not favorite_property_ids:
            raise HTTPException(status_code=404, detail="No favorite properties found for the user.")

        # Feature weights
        weights = {
            'type': 1.2,
            'city': 1.1,
            'compound': 1.1,
            'price': 1.3,
            'area': 1.1,
            'bedrooms': 0.7,
            'bathrooms': 0.3,
            'level': 0.6
        }

        # Normalize numeric features
        numerical_columns = ["price", "area", "bedrooms", "bathrooms", "level"]
        scaler = MinMaxScaler()
        normalized_features = scaler.fit_transform(properties_df[numerical_columns])
        normalized_df = pd.DataFrame(
            normalized_features, columns=[f"{col}_scaled" for col in numerical_columns]
        )
        for col in numerical_columns:
            normalized_df[f"{col}_scaled"] *= weights[col]
        logger.debug("Normalized and weighted numerical features")

        # Handle categorical features
        categorical_columns = ["type", "city", "payment_option", "compound"]
        for col in categorical_columns:
            properties_df[col] = properties_df[col].fillna("unknown").str.lower().str.strip()

        encoder = OneHotEncoder(sparse_output=False, handle_unknown='ignore')
        encoded_features = encoder.fit_transform(properties_df[categorical_columns])
        encoded_df = pd.DataFrame(encoded_features, columns=encoder.get_feature_names_out(categorical_columns))

        for col in categorical_columns:
            encoded_df.loc[:, encoded_df.columns.str.startswith(col)] *= weights.get(col, 1)

        logger.debug("Encoded and weighted categorical features")

        # Handle 'furnished' values
        properties_df["furnished"] = (
            properties_df["furnished"]
            .fillna("unknown")
            .astype(str)
            .str.lower()
            .str.strip()
        )

        furnished_map = {"yes": 1.0, "no": 0.0, "unknown": 0.5}
        properties_df["furnished_numeric"] = properties_df["furnished"].map(furnished_map).fillna(0.5)

        logger.debug(f"Furnished value counts: {properties_df['furnished'].value_counts()}")

        # Combine all features
        item_profiles = pd.concat([
            normalized_df,
            encoded_df,
            properties_df[["id", "furnished_numeric"]]
        ], axis=1)
        logger.debug(f"Final item_profiles columns: {item_profiles.columns}")

        # Compute user profile
        favorite_profiles = item_profiles[item_profiles["id"].isin(favorite_property_ids)].drop(columns=["id"])
        user_profile = favorite_profiles.mean(axis=0)

        # Compute similarity
        non_favorite_profiles = item_profiles[~item_profiles["id"].isin(favorite_property_ids)].copy()
        similarity_scores = cosine_similarity([user_profile], non_favorite_profiles.drop(columns=["id"]))[0]
        non_favorite_profiles["similarity_score"] = similarity_scores

        recommended_properties = non_favorite_profiles.sort_values(by="similarity_score", ascending=False).head(5)
        recommendations = recommended_properties[["id", "similarity_score"]].to_dict(orient="records")

        logger.info(f"Recommendations generated: {recommendations}")

        # Save recommendations to database
        try:
            # 1. Fetch the latest recommendation for the user
            old_recommendation = await conn.fetchrow(
                '''
                SELECT id FROM public.real_estate_recommendedproperties
                WHERE user_id = $1
                ORDER BY created_at DESC
                LIMIT 1
                ''',
                user_id
            )
            old_property_ids = set()
            if old_recommendation:
                old_recommendation_id = old_recommendation['id']
                old_details = await conn.fetch(
                    '''
                    SELECT property_id FROM public.real_estate_recommendedpropertiesdetails
                    WHERE recommendation_id = $1
                    ''',
                    old_recommendation_id
                )
                old_property_ids = set([row['property_id'] for row in old_details])

            new_property_ids = set([rec['id'] for rec in recommendations])

            # If the recommendations are the same, skip saving
            if old_property_ids == new_property_ids and old_recommendation:
                logger.info(f"Duplicate recommendations detected for user_id: {user_id}. Skipping save.")
                await conn.close()
                logger.info("Database connection closed.")
                return {"user_id": user_id, "recommendations": recommendations}

            # 2. If different, delete old recommendations
            if old_property_ids != new_property_ids and old_recommendation:
                await conn.execute(
                    '''
                    DELETE FROM public.real_estate_recommendedpropertiesdetails
                    WHERE recommendation_id = $1
                    ''',
                    old_recommendation_id
                )
                await conn.execute(
                    '''
                    DELETE FROM public.real_estate_recommendedproperties
                    WHERE id = $1
                    ''',
                    old_recommendation_id
                )
                logger.info(f"Deleted old recommendations for user_id: {user_id}")

            # 3. Insert new recommendations
            recommendation_id = await conn.fetchval(
                """
                INSERT INTO public.real_estate_recommendedproperties 
                (user_id, recommendation_type) 
                VALUES ($1, $2) 
                RETURNING id
                """,
                user_id, 'interactions'
            )
            
            for rec in recommendations:
                await conn.execute(
                    """
                    INSERT INTO public.real_estate_recommendedpropertiesdetails 
                    (recommendation_id, property_id, score) 
                    VALUES ($1, $2, $3)
                    """,
                     recommendation_id, rec['id'], round(float(rec['similarity_score']), 2)
                )
            
            logger.info(f"Saved recommendations to database with recommendation_id: {recommendation_id}")
        except Exception as e:
            logger.error(f"Error saving recommendations to database: {e}")
            # Continue execution even if saving fails

        await conn.close()
        logger.info("Database connection closed.")
        return {"user_id": user_id, "recommendations": recommendations}

    except Exception as e:
        logger.error(f"Error generating recommendations: {e}")
        raise HTTPException(status_code=500, detail="An error occurred while generating recommendations.")
