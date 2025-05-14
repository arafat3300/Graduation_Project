import re
import nltk
from nltk.corpus import stopwords
from nltk.stem import WordNetLemmatizer
from langdetect import detect
import requests
import json
from fastapi import FastAPI, HTTPException
import uvicorn
from pydantic import BaseModel
import logging
import psycopg2
import time
import os
import httpx
from psycopg2.extras import RealDictCursor

# Logging configuration

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Initialize NLTK resources
try:
    nltk.data.find('corpora/stopwords')
    nltk.data.find('corpora/wordnet')
except LookupError:
    nltk.download('stopwords')
    nltk.download('wordnet')

# Initialize stopwords and lemmatizer
stop_words = set()
lemmatizer = WordNetLemmatizer()

# Real estate-specific profanity detection
class ProfanityDetector:
    def __init__(self):
        # Basic list of profanity words (censored here for documentation)
        self.profanity_words = {
            'f***': ['fuck', 'fucking', 'fucked', 'fucker'],
            's***': ['shit', 'shitty', 'shitting'],
            'a**': ['ass', 'asshole'],
            'b****': ['bitch', 'bitches'],
            'd***': ['damn', 'dick', 'dumb'],
            'c***': ['crap', 'cock']
        }
        
        # Real estate terminology that might trigger false positives
        self.real_estate_exceptions = [
            'basement', 'cockroach', 'screw', 'hole', 'crack', 'slope', 'dump',
            'butt joint', 'stud', 'caulk', 'shaft', 'exposed'
        ]
        
        # Compile regex patterns for efficiency
        self._compile_patterns()
    
    def _compile_patterns(self):
        # Create regex patterns for profanity detection
        pattern_parts = []
        for words in self.profanity_words.values():
            for word in words:
                # Match whole words only with word boundaries
                pattern_parts.append(r'\b' + re.escape(word) + r'\b')
        
        self.pattern = re.compile('|'.join(pattern_parts), re.IGNORECASE)
        
        # Pattern for real estate exceptions
        self.exceptions_pattern = re.compile(
            r'\b(' + '|'.join(map(re.escape, self.real_estate_exceptions)) + r')\b', 
            re.IGNORECASE
        )
    
    def contains_profanity(self, text):
        """Check if text contains profanity words"""
        if not text:
            return False
        
        # First check for profanity
        return bool(self.pattern.search(text))
    
    def get_profanity_level(self, text):
        """
        Determine the level of profanity in the text
        Returns: "none", "low", "medium", or "high"
        """
        if not text:
            return "none"
        
        words = text.lower().split()
        total_words = len(words)
        
        if total_words == 0:
            return "none"
        
        profanity_count = 0
        for word in words:
            if any(prof_word in word for prof_words in self.profanity_words.values() for prof_word in prof_words):
                profanity_count += 1
        
        ratio = profanity_count / total_words
        
        if profanity_count == 0:
            return "none"
        elif ratio < 0.03:  # Less than 3% of words are profanity
            return "low"
        elif ratio < 0.08:  # Less than 8% of words are profanity
            return "medium"
        else:
            return "high"
    
    def filter_text(self, text, preserve_real_estate_terms=True):
        """
        Filter profanity from text
        Args:
            text: The text to filter
            preserve_real_estate_terms: Whether to preserve real estate terminology
        Returns:
            Filtered text
        """
        if not text:
            return ""
        
        words = text.split()
        filtered_words = []
        
        for word in words:
            # Check if it's a real estate term to preserve
            if preserve_real_estate_terms and self.exceptions_pattern.match(word):
                filtered_words.append(word)
                continue
            
            # Check and censor profanity
            censored_word = word
            for censor, profanities in self.profanity_words.items():
                for profanity in profanities:
                    if re.match(r'\b' + re.escape(profanity) + r'\b', word.lower()):
                        censored_word = censor
                        break
                if censored_word != word:
                    break
            
            filtered_words.append(censored_word)
        
        return ' '.join(filtered_words)

# Initialize global profanity detector
profanity_detector = ProfanityDetector()
db_conn = None

@app.on_event("startup")
async def startup_event():
    global db_conn, stop_words
    try:
        nltk.download('stopwords')
        nltk.download('wordnet')
        stop_words = set(stopwords.words('english'))
        
        # PostgreSQL
        db_conn = psycopg2.connect(
            host=os.getenv("DB_HOST"),
            port=os.getenv("DB_PORT"),
            dbname=os.getenv("DB_NAME"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD")
        )
        logging.info("PostgreSQL and NLTK initialized successfully in startup.")
    except Exception as e:
        logging.error(f"Startup failed: {e}")
        raise

@app.on_event("shutdown")
async def shutdown_event():
    global db_conn
    if db_conn:
        db_conn.close()
        logging.info("PostgreSQL connection closed.")

def ensure_db_connection():
    global db_conn
    try:
        if db_conn is None or db_conn.closed:
            logging.warning("⚠️ Reconnecting to PostgreSQL...")
            db_conn = psycopg2.connect(
                host=os.getenv("DB_HOST"),
                port=os.getenv("DB_PORT"),
                dbname=os.getenv("DB_NAME"),
                user=os.getenv("DB_USER"),
                password=os.getenv("DB_PASSWORD")
            )
            logging.info("✅ PostgreSQL reconnected successfully!")
    except Exception as e:
        logging.error(f"❌ Error reconnecting to PostgreSQL: {e}")
        raise

class ReviewData(BaseModel):
    review: str
    property_id: int
    user_id: str
    review_number: int

# Add a new model for profanity checking
class ProfanityCheckRequest(BaseModel):
    text: str
    preserve_real_estate_terms: bool = True

class ProfanityCheckResponse(BaseModel):
    original_text: str
    filtered_text: str
    contains_profanity: bool
    profanity_level: str

def preprocess_review(review: str) -> str:
    # Check for profanity and log if found
    if profanity_detector.contains_profanity(review):
        level = profanity_detector.get_profanity_level(review)
        logging.warning(f"⚠️ Profanity detected in review (level: {level})")
        # Optionally filter the review here if needed
        
    review = re.sub(r'[^a-zA-Z\s]', '', review).lower().strip()
    tokens = [lemmatizer.lemmatize(word) for word in review.split() if word not in stop_words]
    return ' '.join(tokens)

async def translate_if_arabic(review: str) -> dict:
    try:
        language = detect(review)
        if language == 'ar':
            logging.info("Arabic detected, translating...")
            async with httpx.AsyncClient(timeout=20.0) as client:
                response = await client.post(
                    "http://translation_service:8005/translate",
                    json={"egyptian_arabic_feedback": review}
                )
                response.raise_for_status()
                translated = response.json().get('translated_feedback', review)
                return {"review": translated, "language": "ar"}
        else:
            return {"review": review, "language": "en"}
    except Exception as e:
        logging.error(f"Translation error: {e}")
        raise HTTPException(status_code=500, detail="Translation or detection failed.")

@app.post("/check-profanity", response_model=ProfanityCheckResponse)
async def check_profanity(request: ProfanityCheckRequest):
    """
    Check and filter profanity in text, with special handling for real estate terminology
    """
    text = request.text
    contains_profanity = profanity_detector.contains_profanity(text)
    profanity_level = profanity_detector.get_profanity_level(text)
    filtered_text = profanity_detector.filter_text(text, request.preserve_real_estate_terms)
    
    return {
        "original_text": text,
        "filtered_text": filtered_text,
        "contains_profanity": contains_profanity,
        "profanity_level": profanity_level
    }

@app.post("/predict")
async def predict_sentiment(data: ReviewData):
    try:
        ensure_db_connection()
        
        # Check for profanity in review
        if profanity_detector.contains_profanity(data.review):
            level = profanity_detector.get_profanity_level(data.review)
            logging.warning(f"⚠️ Profanity detected in review ID {data.review_number} (level: {level})")
        
        translation_result = await translate_if_arabic(data.review)
        translated_review = translation_result["review"]
        detected_language = translation_result["language"]
        processed_review = preprocess_review(translated_review)
        logging.info(f"Processed: {processed_review}")

        with db_conn.cursor(cursor_factory=RealDictCursor) as cursor:
            try:
                cursor.execute(
                    "SELECT id, city, payment_option, price, area, sale_rent FROM real_estate_property WHERE id = %s",
                    (data.property_id,)
                )
                prop_details = cursor.fetchone()
            except Exception as e:
                logging.error(f"Database query error: {e}")
                db_conn.rollback()
                raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

        if not prop_details:
            raise HTTPException(status_code=404, detail="Property not found.")

        # Extraction
        async with httpx.AsyncClient(timeout=20.0) as client:
            extraction_response = await client.post(
                "http://feature-extractor:8001/extract",
                json={"preprocessed_review": processed_review}
            )
        extraction_response.raise_for_status()
        extracted = extraction_response.json()

        # Sentiment
        sentiment_payload = {
            "tag_texts": {
                "full_review": processed_review,
                **extracted
            }
        }

        async with httpx.AsyncClient(timeout=20.0) as client:
            sentiment_response = await client.post(
                "http://sentiment-analyzer:8002/analyze-sentiment",
                json=sentiment_payload
            )
        sentiment_response.raise_for_status()
        sentiments = sentiment_response.json()

        # Majority payload
        size_value = extracted.get("size")
        majority_payload = {
            "property_id": data.property_id,
            "review_number": data.review_number,
            "review_text": translated_review if detected_language == 'ar' else data.review,
            "original_review": data.review if detected_language == 'ar' else "",
            "overall_sentiment": sentiments.get("full_review_sentiment", "Neutral"),
            "size_text": size_value.split(",")[0].strip() if size_value else "N/A",
            "size_sentiment": sentiments.get("size_sentiment", "Neutral"),
            "size_confidence": sentiments.get("size_confidence", 0.0),
            "price_text": str(extracted.get("price") or "N/A"),
            "price_sentiment": str(sentiments.get("price_sentiment", "Neutral")),
            "price_confidence": sentiments.get("price_confidence", 0.0),
            "location_text": str(extracted.get("location") or "N/A"),
            "location_sentiment": str(sentiments.get("location_sentiment", "Neutral")),
            "location_confidence": sentiments.get("location_confidence", 0.0),
            "cleanliness_text": str(extracted.get("cleanliness") or "N/A"),
            "cleanliness_sentiment": str(sentiments.get("cleanliness_sentiment", "Neutral")),
            "cleanliness_confidence": sentiments.get("cleanliness_confidence", 0.0),
            "amenities_text": str(extracted.get("amenities") or "N/A"),
            "amenities_sentiment": str(sentiments.get("amenities_sentiment", "Neutral")),
            "amenities_confidence": sentiments.get("amenities_confidence", 0.0),
            "maintenance_text": str(extracted.get("maintenance") or "N/A"),
            "maintenance_sentiment": str(sentiments.get("maintenance_sentiment", "Neutral")),
            "maintenance_confidence": sentiments.get("maintenance_confidence", 0.0),
            "price": prop_details.get('price') or 0,
            "size": prop_details.get('area') or 0,
            "city": prop_details.get('city') or "Unknown City",
            "sale_rent": prop_details.get('sale_rent') or "Unknown",
            "payment_type": prop_details.get('payment_option') or "Unknown"
        }

        logging.info(f"Final majority payload: {majority_payload}")

        async with httpx.AsyncClient(timeout=20.0) as client:
            majority_response = await client.post(
                "http://majority-model:8003/insert-review",
                json=majority_payload
            )
        majority_response.raise_for_status()
        majority_results = majority_response.json()

        recommendation_payload = {
            **majority_payload,
            "user_id": data.user_id
        }

        async with httpx.AsyncClient(timeout=20.0) as client:
            recommendation_response = await client.post(
                "http://recommendation-model:8004/query-recommendations",
                json=recommendation_payload
            )
        recommendation_response.raise_for_status()
        recommendation_results = recommendation_response.json()

        # Include profanity detection in the response
        contains_profanity = profanity_detector.contains_profanity(data.review)
        profanity_level = profanity_detector.get_profanity_level(data.review)

        return {
            "original_review": data.review if detected_language == 'ar' else "",
            "translated_review": translated_review if detected_language == 'ar' else "",
            "processed_review": processed_review,
            "extracted_entities": extracted,
            "sentiment_analysis": sentiments,
            "majority_sentiment": majority_results,
            "recommendations": recommendation_results,
            "profanity_info": {
                "contains_profanity": contains_profanity,
                "profanity_level": profanity_level
            } if contains_profanity else None
        }

    except httpx.RequestError as exc:
        logging.error(f"HTTP request error: {exc}")
        raise HTTPException(status_code=502, detail="Service communication failed.")
    except Exception as exc:
        logging.error(f"Unexpected error: {exc}")
        raise HTTPException(status_code=500, detail="Unexpected error occurred.")

@app.get("/")
async def root():
    return {"message": "Welcome to the Prediction API"}
