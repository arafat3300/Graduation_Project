from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from supabase import create_client
from sklearn.preprocessing import MinMaxScaler, OneHotEncoder
from sklearn.metrics.pairwise import cosine_similarity
import pandas as pd
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ContentBasedLogger")

# Initialize FastAPI app
app = FastAPI()

# Supabase configuration
SUPABASE_URL = "https://zodbnolhtcemthbjttab.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvZGJub2xodGNlbXRoYmp0dGFiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQ5NzE4MjMsImV4cCI6MjA1MDU0NzgyM30.bkW3OpxY1_IwU01GwybxHfrQQ9t3yFgLZVi406WvgVI"  
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# Input model for user ID
class UserIdPayload(BaseModel):
    user_id: int

@app.post("/recommendations/")
async def get_recommendations(payload: UserIdPayload):
    user_id = payload.user_id
    logger.info(f"Fetching recommendations for user_id: {user_id}")

    try:
        # Fetch properties from Supabase
        properties_response = supabase.table("properties").select("*").execute()
        properties_df = pd.DataFrame(properties_response.data).drop_duplicates(subset=["id"])
        properties_df["id"] = properties_df["id"].astype(int)
        properties_df["level"] = properties_df["level"].fillna(0)

        # Fetch user favorites from Supabase
        favorites_response = supabase.table("user_favorites").select("*").eq("user_id", user_id).execute()
        user_favorites_df = pd.DataFrame(favorites_response.data).drop_duplicates(subset=["property_id"])
        favorite_property_ids = user_favorites_df["property_id"].tolist()

        if not favorite_property_ids:
            raise HTTPException(status_code=404, detail="No favorite properties found for the user.")

        # Normalize and encode properties data
        numerical_columns = ["price", "area", "bedrooms", "bathrooms", "level"]
        scaler = MinMaxScaler()
        normalized_features = scaler.fit_transform(properties_df[numerical_columns])
        normalized_df = pd.DataFrame(normalized_features, columns=[f"{col}_scaled" for col in numerical_columns])

        categorical_columns = ["type", "city", "payment_option", "compound"]
        encoder = OneHotEncoder()
        encoded_features = encoder.fit_transform(properties_df[categorical_columns]).toarray()
        encoded_df = pd.DataFrame(encoded_features, columns=encoder.get_feature_names_out(categorical_columns))

        # Prepare item profiles
        properties_df["furnished_numeric"] = properties_df["furnished"].map({"Yes": 1, "No": 0}).fillna(0.5)
        item_profiles = pd.concat([normalized_df, encoded_df, properties_df[["id", "furnished_numeric"]]], axis=1)

        # User profile computation
        favorite_profiles = item_profiles[item_profiles["id"].isin(favorite_property_ids)].drop(columns=["id"])
        user_profile = favorite_profiles.mean(axis=0)

        # Recommendation calculation
        non_favorite_profiles = item_profiles[~item_profiles["id"].isin(favorite_property_ids)].copy()
        similarity_scores = cosine_similarity([user_profile], non_favorite_profiles.drop(columns=["id"]))[0]
        non_favorite_profiles["similarity_score"] = similarity_scores

        recommended_properties = non_favorite_profiles.sort_values(by="similarity_score", ascending=False).head(5)
        recommendations = recommended_properties[["id", "similarity_score"]].to_dict(orient="records")

        return {"user_id": user_id, "recommendations": recommendations}
    except Exception as e:
        logger.error(f"Error generating recommendations: {e}")
        raise HTTPException(status_code=500, detail="An error occurred while generating recommendations.")

