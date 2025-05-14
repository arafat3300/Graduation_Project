from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor
from collections import Counter
from pinecone import Pinecone, ServerlessSpec
from transformers import AutoTokenizer, AutoModel
import torch
import logging
import time
import os

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

PINECONE_API_KEY = "pcsk_jYZNX_CBuDa8RW6TNRDvVHCDfsqJKgMAKwiViNJG3Dt61yH8BfNof8V8DXcW84jRYEHcj"
INDEX_NAME = "recommendation-index"

try:
    pc = Pinecone(api_key=PINECONE_API_KEY)
    logging.info("✅ Pinecone initialized successfully.")
except Exception as e:
    logging.error(f"❌ Failed to initialize Pinecone: {e}", exc_info=True)
    raise

try:
    pc.create_index(
        name=INDEX_NAME,
        dimension=768,
        metric="cosine",
        spec=ServerlessSpec(cloud="aws", region="us-east-1")
    )
    logging.info(f"✅ Index '{INDEX_NAME}' created.")
except Exception as e:
    logging.warning(f"⚠️ Index already exists or creation failed: {e}")

while not pc.describe_index(INDEX_NAME).status["ready"]:
    logging.info("⌛ Waiting for Pinecone index to be ready...")
    time.sleep(1)

index = pc.Index(INDEX_NAME)
logging.info(f"✅ Connected to Pinecone index '{INDEX_NAME}'.")

# ---------------------- Embedding Model Initialization ----------------------

EMBEDDING_MODEL_NAME = "distilbert-base-uncased"
embedding_tokenizer = AutoTokenizer.from_pretrained(EMBEDDING_MODEL_NAME)
embedding_model = AutoModel.from_pretrained(EMBEDDING_MODEL_NAME)

def generate_embeddings(review_text: str):
    inputs = embedding_tokenizer(review_text, return_tensors="pt", truncation=True, padding=True, max_length=512)
    with torch.no_grad():
        outputs = embedding_model(**inputs)
        embeddings = outputs.last_hidden_state.mean(dim=1).squeeze().tolist()
    return embeddings

# ---------------------- Pydantic Model ----------------------

class PropertyReview(BaseModel):
    property_id: int
    review_number: int
    review_text: str
    overall_sentiment: str
    size_text: str
    size_sentiment: str
    size_confidence: float
    price_text: str
    price_sentiment: str
    price_confidence: float
    location_text: str
    location_sentiment: str
    location_confidence: float
    cleanliness_text: str
    cleanliness_sentiment: str
    cleanliness_confidence: float
    amenities_text: str
    amenities_sentiment: str
    amenities_confidence: float
    maintenance_text: str
    maintenance_sentiment: str
    maintenance_confidence: float
    price: int
    size: int
    city: str
    sale_rent: str
    payment_type: str

# ---------------------- Helper Functions ----------------------

def calculate_majority(sentiments):
    filtered_sentiments = [s for s in sentiments if s != 'Neutral']
    sentiment_counts = Counter(filtered_sentiments or sentiments)
    if sentiment_counts:
        most_common_sentiment, count = sentiment_counts.most_common(1)[0]
        if list(sentiment_counts.values()).count(count) > 1:
            return "Neutral"
        return most_common_sentiment
    return "Neutral"

def clean_metadata(metadata_dict):
    return {k: (v if v is not None else "Neutral") for k, v in metadata_dict.items()}

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

# ---------------------- API Endpoint ----------------------

@app.post("/insert-review")
async def insert_review(review: PropertyReview):
    try:
        # Ensure valid database connection
        ensure_db_connection()
        
        # 1. Insert into PostgreSQL (excluding non-schema fields)
        review_data = review.dict()

        # Convert property_id to string to match database column type
        review_data['property_id'] = str(review_data['property_id'])

        filtered_data = {k: v for k, v in review_data.items() if k not in ["price", "size", "city", "sale_rent", "payment_type"]}

        # Build SQL query dynamically
        columns = ", ".join(filtered_data.keys())
        placeholders = ", ".join(["%s"] * len(filtered_data))
        values = tuple(filtered_data.values())

        with db_conn.cursor() as cursor:
            try:
                # Log the query for debugging
                query = f"INSERT INTO property_reviews ({columns}) VALUES ({placeholders})"
                logging.info(f"Executing query: {query}")
                logging.info(f"With values: {values}")
                
                # Use the proper table name with prefix
                cursor.execute(query, values)
                db_conn.commit()
                logging.info("✅ Insert successful")
            except Exception as e:
                db_conn.rollback()  # Important: Roll back transaction on failure
                logging.error(f"❌ SQL Error: {e}")
                raise

        # 2. Fetch existing reviews to calculate majority
        with db_conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute(
                "SELECT size_sentiment, price_sentiment, location_sentiment, cleanliness_sentiment, amenities_sentiment, maintenance_sentiment " +
                "FROM property_reviews WHERE property_id = %s::text",
                (review.property_id,)
            )
            all_feedbacks = cursor.fetchall()

        size_sentiments = [fb.get('size_sentiment', "Neutral") for fb in all_feedbacks]
        price_sentiments = [fb.get('price_sentiment', "Neutral") for fb in all_feedbacks]
        location_sentiments = [fb.get('location_sentiment', "Neutral") for fb in all_feedbacks]
        cleanliness_sentiments = [fb.get('cleanliness_sentiment', "Neutral") for fb in all_feedbacks]
        amenities_sentiments = [fb.get('amenities_sentiment', "Neutral") for fb in all_feedbacks]
        maintenance_sentiments = [fb.get('maintenance_sentiment', "Neutral") for fb in all_feedbacks]

        majority_sentiments = {
            "size_sentiment": calculate_majority(size_sentiments),
            "price_sentiment": calculate_majority(price_sentiments),
            "location_sentiment": calculate_majority(location_sentiments),
            "cleanliness_sentiment": calculate_majority(cleanliness_sentiments),
            "maintenance_sentiment": calculate_majority(maintenance_sentiments),
            "amenities_sentiment": calculate_majority(amenities_sentiments)
        }

        # 3. Prepare metadata for Pinecone
        metadata = clean_metadata({
            "property_id": str(review.property_id),
            **majority_sentiments,
            "price": review.price,
            "size": review.size,
            "city": review.city,
            "sale_rent": review.sale_rent,
            "payment_type": review.payment_type
        })

        # 4. Fetch record from Pinecone
        search_result = index.fetch(ids=[str(review.property_id)])
        existing_record = search_result.vectors.get(str(review.property_id)) if search_result and search_result.vectors else None

        if existing_record:
            # 5. Update metadata and embeddings
            updated_metadata = existing_record.metadata or {}
            updated_metadata.update(metadata)

            old_embeddings = existing_record.values or []
            new_embeddings = generate_embeddings(review.review_text)
            merged_embeddings = [(old + new) / 2 for old, new in zip(old_embeddings, new_embeddings)]

            index.upsert([{
                "id": str(review.property_id),
                "values": merged_embeddings,
                "metadata": updated_metadata
            }])

            return {
                "message": "✅ Review inserted, Pinecone metadata and embeddings updated.",
                "updated_metadata": updated_metadata
            }

        # 6. Insert new record
        embeddings = generate_embeddings(review.review_text)
        index.upsert([{
            "id": str(review.property_id),
            "values": embeddings,
            "metadata": metadata
        }])

        return {
            "message": "✅ Review inserted, new Pinecone record created.",
            "metadata": metadata
        }

    except Exception as e:
        logging.error(f"❌ Error processing review: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error processing request: {e}")

@app.get("/")
async def root():
    return {"message": "✅ PostgreSQL & Pinecone FastAPI service is running!"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8004, reload=True)
