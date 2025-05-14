from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pinecone import Pinecone
from transformers import AutoTokenizer, AutoModel
import psycopg2
from psycopg2.extras import RealDictCursor
import torch
import os
import logging
import time

# ---------------------- Logging and FastAPI Initialization ----------------------

logging.basicConfig(level=logging.INFO)
app = FastAPI()

# ---------------------- PostgreSQL Initialization ----------------------

DB_HOST = os.getenv("DB_HOST", "host.docker.internal")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "ODOO-GRAD")
DB_USER = os.getenv("DB_USER", "wagih")
DB_PASSWORD = os.getenv("DB_PASSWORD", "Iwagih")

try:
    db_conn = psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )
    logging.info("✅ PostgreSQL initialized successfully!")
except Exception as e:
    logging.error(f"❌ Error initializing PostgreSQL: {e}")
    raise

@app.on_event("shutdown")
async def shutdown_event():
    if db_conn:
        db_conn.close()
        logging.info("PostgreSQL connection closed.")

# ---------------------- Pinecone Initialization ----------------------

PINECONE_API_KEY = os.getenv("PINECONE_API_KEY", "pcsk_jYZNX_CBuDa8RW6TNRDvVHCDfsqJKgMAKwiViNJG3Dt61yH8BfNof8V8DXcW84jRYEHcj")
INDEX_NAME = "recommendation-index"

try:
    pc = Pinecone(api_key=PINECONE_API_KEY)
    logging.info("✅ Pinecone initialized successfully.")
except Exception as e:
    logging.error(f"❌ Failed to initialize Pinecone: {e}", exc_info=True)
    raise

if INDEX_NAME not in [i.name for i in pc.list_indexes()]:
    raise RuntimeError(f"❌ Index '{INDEX_NAME}' does not exist.")
else:
    logging.info(f"✅ Index '{INDEX_NAME}' exists.")

while not pc.describe_index(INDEX_NAME).status["ready"]:
    logging.info("⌛ Waiting for Pinecone index to be ready...")
    time.sleep(1)

try:
    index = pc.Index(INDEX_NAME)
    logging.info(f"✅ Connected to Pinecone index '{INDEX_NAME}'.")
except Exception as e:
    logging.error(f"❌ Error accessing Pinecone index: {e}", exc_info=True)
    raise

# ---------------------- Embedding Model Initialization (DistilBERT) ----------------------

EMBEDDING_MODEL_NAME = "distilbert-base-uncased"
embedding_tokenizer = AutoTokenizer.from_pretrained(EMBEDDING_MODEL_NAME)
embedding_model = AutoModel.from_pretrained(EMBEDDING_MODEL_NAME)

def generate_embeddings(review_text: str):
    inputs = embedding_tokenizer(review_text, return_tensors="pt", truncation=True, padding=True, max_length=512)
    with torch.no_grad():
        outputs = embedding_model(**inputs)
        embeddings = outputs.last_hidden_state.mean(dim=1).squeeze().tolist()
    return embeddings

# ---------------------- Pydantic Model for Review ----------------------

class PropertyReview(BaseModel):
    user_id: int
    property_id: int
    review_number: int
    review_text: str
    overall_sentiment: str
    size_text: str
    size_sentiment: str
    price_text: str
    price_sentiment: str
    location_text: str
    location_sentiment: str
    cleanliness_text: str
    cleanliness_sentiment: str
    amenities_text: str
    amenities_sentiment: str
    maintenance_text: str
    maintenance_sentiment: str
    price: float  
    size: float   
    city: str
    sale_rent: str
    payment_type: str

# ---------------------- Helper Functions ----------------------

def ensure_db_connection():
    global db_conn
    try:
        # Check if connection is closed or in error state
        if db_conn is None or db_conn.closed:
            logging.warning("⚠️ Reconnecting to PostgreSQL...")
            db_conn = psycopg2.connect(
                host=DB_HOST,
                port=DB_PORT,
                dbname=DB_NAME,
                user=DB_USER,
                password=DB_PASSWORD
            )
            logging.info("✅ PostgreSQL reconnected successfully!")
    except Exception as e:
        logging.error(f"❌ Error reconnecting to PostgreSQL: {e}")
        raise

# ---------------------- Query Recommendations and Save to PostgreSQL ----------------------

@app.post("/query-recommendations")
def query_recommendations(review: PropertyReview, recommended_by: str = "System", top_k: int = 5):
    try:
        # Ensure valid database connection
        ensure_db_connection()
        
        query_vector = generate_embeddings(review.review_text)

        metadata_filter = {}

        if review.price_sentiment.lower() == "negative":
            metadata_filter["price"] = {"$lte": review.price * 0.75}
        else:
            metadata_filter["price"] = {"$gte": review.price * 0.75, "$lte": review.price * 1.25}

        if review.size_sentiment.lower() == "negative":
            metadata_filter["size"] = {"$lte": review.size * 1.25}
        else:
            metadata_filter["size"] = {"$gte": review.size * 0.75, "$lte": review.size * 1.25}

        for tag in ["location", "cleanliness", "maintenance", "amenities", "price", "size"]:
            sentiment_attr = getattr(review, f"{tag}_sentiment").lower()
            if sentiment_attr == "negative":
                metadata_filter[f"{tag}_sentiment"] = "Positive"
            elif sentiment_attr == "positive":
                metadata_filter[f"{tag}_sentiment"] = "Positive"

        results = index.query(
            vector=query_vector,
            top_k=top_k,
            filter=metadata_filter,
            include_metadata=True
        )

        recommendations = [
            {
                "property_id": match['id'],
                "similarity_score": match['score'],
                "price": match['metadata'].get('price'),
                "size": match['metadata'].get('size'),
                "city": match['metadata'].get('city'),
                "sale_rent": match['metadata'].get('sale_rent'),
                "payment_type": match['metadata'].get('payment_type')
            }
            for match in results.get("matches", [])
        ]

        if recommendations:
            # Insert into PostgreSQL instead of Supabase
            with db_conn.cursor(cursor_factory=RealDictCursor) as cursor:
                try:
                    # First check if a recommendation already exists for this user
                    cursor.execute(
                        "SELECT id FROM real_estate_recommendedproperties WHERE user_id = %s ORDER BY id DESC LIMIT 1",
                        (review.user_id,)
                    )
                    existing_recommendation = cursor.fetchone()
                    
                    if existing_recommendation:
                        # Use existing recommendation
                        recommendation_id = existing_recommendation['id']
                        logging.info(f"Using existing recommendation ID: {recommendation_id}")
                        
                        # Delete any existing details for this recommendation
                        cursor.execute(
                            "DELETE FROM real_estate_recommendedpropertiesdetails WHERE recommendation_id = %s",
                            (recommendation_id,)
                        )
                    else:
                        # Find the next available ID manually to avoid sequence issues
                        try:
                            # Get the highest existing ID
                            cursor.execute("SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM real_estate_recommendedproperties")
                            next_id = cursor.fetchone()['next_id']
                            logging.info(f"Using next available ID: {next_id}")
                            
                            # Insert with explicit ID to avoid sequence issues
                            cursor.execute(
                                "INSERT INTO real_estate_recommendedproperties (id, user_id) VALUES (%s, %s) RETURNING id",
                                (next_id, review.user_id)
                            )
                            recommendation_result = cursor.fetchone()
                            recommendation_id = recommendation_result['id']
                            logging.info(f"Created new recommendation ID: {recommendation_id}")
                        except Exception as e:
                            db_conn.rollback()
                            logging.error(f"Failed to insert recommendation: {e}")
                            raise

                    # Insert recommendation details
                    for rec in recommendations:
                        try:
                            # Get next available ID for details table
                            cursor.execute("SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM real_estate_recommendedpropertiesdetails")
                            next_detail_id = cursor.fetchone()['next_id']
                            
                            # Insert with explicit ID to avoid sequence issues
                            cursor.execute(
                                "INSERT INTO real_estate_recommendedpropertiesdetails (id, recommendation_id, property_id) VALUES (%s, %s, %s)",
                                (next_detail_id, recommendation_id, str(rec["property_id"]))
                            )
                        except Exception as detail_error:
                            logging.error(f"Error inserting detail: {detail_error}")
                            raise
                    
                    # Commit the entire transaction
                    db_conn.commit()
                    logging.info(f"✅ Successfully inserted recommendation ID {recommendation_id} with {len(recommendations)} properties")
                except Exception as e:
                    db_conn.rollback()
                    logging.error(f"❌ Database error: {e}")
                    raise

        return {
            "submitted_feedback": review.dict(),
            "recommendations": recommendations if recommendations else "No recommendations found."
        }

    except Exception as e:
        logging.error(f"Error querying recommendations: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to query recommendations: {e}")

# ---------------------- Health Check Endpoint ----------------------
@app.get("/")
async def root():
    return {"message": "✅ Recommendation Engine API is running on port 8003"}

# ---------------------- Running the FastAPI Server ----------------------
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8003)
