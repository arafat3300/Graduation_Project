from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, validator
import textwrap
import requests
import uvicorn
import logging
import sys
from typing import List
from datetime import datetime
from contextlib import asynccontextmanager
import re
import os
import torch
from transformers import AutoTokenizer, AutoModel
from pinecone import Pinecone, ServerlessSpec
import time
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# === FastAPI App Setup ===
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(f'app_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log')
    ]
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting up FastAPI application")
    yield
    logger.info("Shutting down FastAPI application")

app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# === Ollama Client ===
class OllamaClient:
    def __init__(self, base_url: str = "http://localhost:11434", model: str = "llama3.2:latest"):
        self.base_url = base_url.rstrip("/")
        self.model = model
        logger.info(f"Initialized OllamaClient with base_url={base_url}, model={model}")
        try:
            response = requests.get(f"{self.base_url}/api/tags", timeout=5)
            response.raise_for_status()
            logger.info("Successfully connected to Ollama server")
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to connect to Ollama server: {str(e)}")
            raise

    def generate(self, prompt: str, max_tokens: int = 300) -> str:
        logger.info(f"Generating response with model {self.model}, max_tokens={max_tokens}")
        payload = {
            "model": self.model,
            "prompt": prompt,
            "stream": False,
            "options": {"max_tokens": max_tokens},
        }
        try:
            resp = requests.post(f"{self.base_url}/api/generate", json=payload, timeout=60)
            resp.raise_for_status()
            response = resp.json()["response"]
            logger.info("Successfully generated response from Ollama")
            return response
        except requests.exceptions.RequestException as e:
            logger.error(f"Error calling Ollama API: {str(e)}")
            raise HTTPException(status_code=503, detail=f"Ollama service error: {str(e)}")
        except Exception as e:
            logger.error(f"Unexpected error in generate: {str(e)}", exc_info=True)
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

ollama = OllamaClient()

# === Pinecone Setup ===
INDEX_NAME = os.getenv("PINECONE_INDEX", "recommendationn-index")

pc = Pinecone(api_key=PINECONE_API_KEY)
try:
    pc.create_index(
        name=INDEX_NAME,
        dimension=768,
        metric="cosine",
        spec=ServerlessSpec(cloud="aws", region="us-east-1")
    )
except Exception as e:
    logger.warning(f"Index creation skipped or already exists: {e}")

while not pc.describe_index(INDEX_NAME).status["ready"]:
    logger.info("⌛ Waiting for Pinecone index to be ready...")
    time.sleep(1)

index = pc.Index(INDEX_NAME)
logger.info(f"✅ Connected to Pinecone index '{INDEX_NAME}'.")

# === Embedding Model ===
EMBEDDING_MODEL_NAME = "distilbert-base-uncased"
tokenizer = AutoTokenizer.from_pretrained(EMBEDDING_MODEL_NAME)
model = AutoModel.from_pretrained(EMBEDDING_MODEL_NAME)

def generate_embeddings(text: str):
    inputs = tokenizer(text, return_tensors="pt", truncation=True, padding=True, max_length=512)
    with torch.no_grad():
        outputs = model(**inputs)
        embeddings = outputs.last_hidden_state.mean(dim=1).squeeze().tolist()
    return embeddings

# === Input Models ===
class TranscriptInput(BaseModel):
    transcript: str

class PropertySearch(BaseModel):
    min_price: float | None = 0
    max_price: float | None = float('inf')
    min_area: float | None = 0
    max_area: float | None = float('inf')
    type: str | None = None
    bedrooms: int | None = None
    payment_option: str | None = None
    city: str | None = None
    features: List[str] = []
    min_installment_years: float | None = None
    max_installment_years: float | None = None
    min_delivery_in: float | None = None
    max_delivery_in: float | None = None
    min_down_payment: float | None = None
    max_down_payment: float | None = None
    bathrooms: int | None = None

    @validator('min_price', 'max_price', 'min_area', 'max_area', 
               'min_installment_years', 'max_installment_years',
               'min_delivery_in', 'max_delivery_in',
               'min_down_payment', 'max_down_payment')
    def validate_numeric_fields(cls, v):
        if v is None:
            return v
        if v < 0:
            raise ValueError('Value cannot be negative')
        return v

    @validator('type', 'payment_option', 'city')
    def validate_string_fields(cls, v):
        if v is None:
            return v
        if not v.strip():
            return None
        return v.strip().lower()

    @validator('bedrooms', 'bathrooms')
    def validate_room_counts(cls, v):
        if v is None:
            return v
        if v < 0:
            raise ValueError('Number of rooms cannot be negative')
        return v

    @validator('features')
    def validate_features(cls, v):
        if not v:
            return []
        return [f.strip().capitalize() for f in v if f.strip()]

# === Prompt Builder ===
def build_prompt(transcript: str) -> str:
    template = """
    The following is a transcription of a phone call. Answer the twelve questions at the end **in English** using only information found in the transcript. If any information is not mentioned in the transcript, answer "not specified".
    --- Transcription ---
    {transcript}
    --- End of Transcription ---

    Questions:
    1. What type of property does the client want?
    2. How many rooms are preferred?
    3. What is the client's maximum budget?
    4. Does the client prefer installment plans?
    5. What amenities does the client require?
    6. When does the client want to get the property in years?
    7. Which location does the client prefer?
    8. What is the type of the unit?
    9. Was a meeting scheduled if yes what is the date and time?
    10. What is the down payment percentage or amount mentioned?
    11. How many bathrooms are required?
    12. What type of finishing is preferred?
    """
    return textwrap.dedent(template.format(transcript=transcript.strip()))

# === Utility Functions ===
def fallback_area():
    return 0, float('inf')

def calculate_range(value: float, percentage: float = 25) -> tuple:
    if value is None:
        return 0, float('inf')
    min_value = value * (1 - percentage/100)
    max_value = value * (1 + percentage/100)
    return min_value, max_value

# === Property Search ===
def search_properties_vector(query_text: str, search_params: PropertySearch, top_k: int = 5):
    try:
        # Check index statistics
        index_stats = index.describe_index_stats()
        logger.info(f"Index statistics: {index_stats}")
        
        # Generate embedding for the query
        query_embedding = generate_embeddings(query_text)
        logger.info(f"Generated embedding with dimension: {len(query_embedding)}")
        
        # Prepare filter conditions - with flexible matching
        filter_conditions = {}
        
        # Price range - this already has 25% flexibility from calculate_range
        if search_params.min_price and search_params.min_price > 0:
            filter_conditions["price"] = {"$gte": search_params.min_price}
        if search_params.max_price and search_params.max_price < float('inf'):
            filter_conditions.setdefault("price", {})["$lte"] = search_params.max_price
        
        # Area range - this already has 25% flexibility from calculate_range
        if search_params.min_area and search_params.min_area > 0:
            filter_conditions["area"] = {"$gte": search_params.min_area}
        if search_params.max_area and search_params.max_area < float('inf'):
            filter_conditions.setdefault("area", {})["$lte"] = search_params.max_area
        
        # Type can be fuzzy matched - first try exact, then fallback to no filter
        if search_params.type:
            filter_conditions["type"] = search_params.type
        
        # Bedrooms can be flexible (+/- 1)
        if search_params.bedrooms:
            min_bedrooms = max(1, search_params.bedrooms - 1)
            max_bedrooms = search_params.bedrooms + 1
            filter_conditions["bedrooms"] = {"$gte": min_bedrooms, "$lte": max_bedrooms}
        
        # Bathrooms can be flexible (+/- 1)
        if search_params.bathrooms:
            min_bathrooms = max(1, search_params.bathrooms - 1)
            max_bathrooms = search_params.bathrooms + 1
            filter_conditions["bathrooms"] = {"$gte": min_bathrooms, "$lte": max_bathrooms}
        
        # Payment option and city should match if specified
        if search_params.payment_option:
            filter_conditions["payment_option"] = search_params.payment_option
        
        if search_params.city:
            filter_conditions["city"] = search_params.city
        
        # Installment years range
        if search_params.min_installment_years:
            filter_conditions.setdefault("installment_years", {})["$gte"] = search_params.min_installment_years
        if search_params.max_installment_years:
            filter_conditions.setdefault("installment_years", {})["$lte"] = search_params.max_installment_years
        
        # Delivery timeline range
        if search_params.min_delivery_in:
            filter_conditions.setdefault("delivery_in", {})["$gte"] = search_params.min_delivery_in
        if search_params.max_delivery_in:
            filter_conditions.setdefault("delivery_in", {})["$lte"] = search_params.max_delivery_in
        
        # Down payment range
        if search_params.min_down_payment:
            filter_conditions.setdefault("down_payment", {})["$gte"] = search_params.min_down_payment
        if search_params.max_down_payment:
            filter_conditions.setdefault("down_payment", {})["$lte"] = search_params.max_down_payment
        
        # Features - instead of requiring all features, only require at least one match
        if search_params.features:
            formatted_features = [feature.capitalize() for feature in search_params.features]
            if formatted_features:
                filter_conditions["amenities"] = {"$in": formatted_features}

        logger.info(f"Search parameters: {search_params}")
        logger.info(f"Filter conditions: {filter_conditions}")

        # First try with all filters
        results = index.query(
            vector=query_embedding,
            top_k=top_k,
            filter=filter_conditions,
            include_metadata=True,
            include_values=False
        )
        
        logger.info(f"Raw search results: {results}")
        
        # If no results, progressively relax constraints
        if not results.matches and filter_conditions:
            logger.info("No matches found with initial filters, relaxing constraints...")
            
            # Remove type constraint if present
            relaxed_filters = filter_conditions.copy()
            if "type" in relaxed_filters:
                del relaxed_filters["type"]
                
                logger.info(f"Relaxed filters (removed type): {relaxed_filters}")
                results = index.query(
                    vector=query_embedding,
                    top_k=top_k,
                    filter=relaxed_filters,
                    include_metadata=True,
                    include_values=False
                )
            
            # If still no results, try removing city constraint
            if not results.matches and "city" in relaxed_filters:
                del relaxed_filters["city"]
                
                logger.info(f"Relaxed filters (removed city): {relaxed_filters}")
                results = index.query(
                    vector=query_embedding,
                    top_k=top_k,
                    filter=relaxed_filters,
                    include_metadata=True,
                    include_values=False
                )
            
            # If still no results, just use price range
            if not results.matches:
                minimal_filters = {}
                if "price" in filter_conditions:
                    minimal_filters["price"] = filter_conditions["price"]
                
                logger.info(f"Using minimal filters (price only): {minimal_filters}")
                results = index.query(
                    vector=query_embedding,
                    top_k=top_k,
                    filter=minimal_filters,
                    include_metadata=True,
                    include_values=False
                )
            
            # Last resort: no filters, just vector similarity
            if not results.matches:
                logger.info("Using no filters, just vector similarity")
                results = index.query(
                    vector=query_embedding,
                    top_k=top_k,
                    filter={},
                    include_metadata=True,
                    include_values=False
                )

        # Sort results by score and add score to metadata
        sorted_results = []
        for match in results.matches:
            metadata = match.metadata
            metadata['similarity_score'] = match.score
            sorted_results.append(metadata)
            logger.info(f"Found property: {metadata}")

        logger.info(f"Found {len(sorted_results)} matching properties")
        return sorted_results
    except Exception as e:
        logger.error(f"Vector search error: {str(e)}", exc_info=True)
        return []

def normalize_answers(answers):
    def parse_price(price_str):
        price_str = price_str.lower().replace("egp", "").replace(",", "").strip()
        match = re.search(r"(\d+(\.\d+)?)(\s*million)?", price_str)
        if match:
            value = float(match.group(1))
            return int(value * 1_000_000) if "million" in price_str else int(value)
        return None

    def parse_rooms(room_str):
        match = re.search(r"\d+", room_str)
        return int(match.group()) if match else None
    
    def parse_area(area_str):
        match = re.search(r"(\d+(\.\d+)?)", area_str)
        if match:
            return float(match.group(1))
        return None

    def parse_installments(text):
        return "installment" if "yes" in text.lower() else "cash"

    def parse_features(features_str):
        features = []
        for feature in re.split(r"[;,]", features_str):
            feature = feature.strip().lower()
            if feature:
                feature_map = {
                    "gym": "Gym",
                    "security": "Security",
                    "parking": "Parking",
                    "pool": "Pool",
                    "fireplace": "Fireplace",
                    "dishwasher": "Dishwasher",
                    "hardwood": "Hardwood",
                    "elevator": "Elevator",
                    "balcony": "Balcony",
                    "garden": "Garden"
                }
                features.append(feature_map.get(feature, feature.capitalize()))
        return features

    def parse_years(text):
        match = re.search(r"(\d+(\.\d+)?)", text)
        return float(match.group(1)) if match else None

    if len(answers) < 12:
        logger.warning(f"Not enough answers provided: {len(answers)}")
        answers = answers + ["not specified"] * (12 - len(answers))

    # Try to extract area from various answers
    area = None
    for ans in answers:
        area_match = re.search(r"(\d+)\s*(?:sqm|m2|square meter|sq\.?\s*m\.?)", ans, re.IGNORECASE)
        if area_match:
            area = float(area_match.group(1))
            break

    # Extract delivery timeline and installment years
    delivery_in = parse_years(answers[5])  # Timeline answer
    installment_years = None
    if "installment" in answers[3].lower():
        installment_years = parse_years(answers[3])  # Try to extract years from installment answer

    return {
        "property_type": answers[0].strip().lower() if not "not specified" in answers[0].lower() else None,
        "rooms": parse_rooms(answers[1]),
        "max_budget": parse_price(answers[2]),
        "payment_type": parse_installments(answers[3]),
        "features": parse_features(answers[4]),
        "area": area,
        "location": answers[6].strip().lower() if not "not specified" in answers[6].lower() else None,
        "down_payment": parse_price(answers[9]) if len(answers) > 9 else None,
        "bathrooms": parse_rooms(answers[10]) if len(answers) > 10 else None,
        "finishing": answers[11].capitalize() if len(answers) > 11 and not "not specified" in answers[11].lower() else None,
        "installment_years": installment_years,
        "delivery_in": delivery_in
    }

@app.post("/qa")
def extract_answers(input: TranscriptInput):
    logger.info("Received QA request")
    try:
        if not input.transcript:
            raise HTTPException(status_code=400, detail="Transcript cannot be empty")
            
        logger.debug(f"Input transcript: {input.transcript[:100]}...")
        
        # STEP 1: Extract answers from transcript using Llama
        qa_prompt = build_prompt(input.transcript)
        logger.debug("Built QA prompt")
        
        qa_response = ollama.generate(qa_prompt)
        logger.debug(f"Raw QA response: {qa_response[:100]}...")
        
        # Split into individual lines and clean
        raw_answers = [line.strip() for line in qa_response.strip().split("\n") if line.strip()]
        if len(raw_answers) < 12:
            logger.warning(f"Received only {len(raw_answers)} answers, expected 12")
            
        logger.info(f"Successfully processed response into {len(raw_answers)} answers")
        
        # Clean and format answers
        cleaned_answers = []
        for answer in raw_answers:
            # Remove any numbering and clean the text
            cleaned = re.sub(r'^\d+\.\s*', '', answer).strip()
            # Remove any extra punctuation
            cleaned = re.sub(r'[.,]$', '', cleaned)
            cleaned_answers.append(cleaned)
        
        # STEP 2: Normalize answers using Llama
        normalization_prompt = build_normalization_prompt(cleaned_answers)
        logger.debug("Built normalization prompt")
        
        norm_response = ollama.generate(normalization_prompt)
        logger.debug(f"Raw normalization response: {norm_response[:100]}...")
        
        # Extract JSON from response
        try:
            # Find JSON content between curly braces
            json_match = re.search(r'\{.*\}', norm_response, re.DOTALL)
            if json_match:
                json_str = json_match.group(0)
                import json
                normalized = json.loads(json_str)
                logger.info(f"Successfully parsed normalized answers: {normalized}")
            else:
                # If no JSON found, use our existing normalizer as fallback
                logger.warning("No JSON found in LLM response, using fallback normalizer")
                normalized = normalize_answers(cleaned_answers)
        except Exception as e:
            logger.error(f"Error parsing LLM JSON response: {str(e)}")
            # Fallback to our existing normalizer
            normalized = normalize_answers(cleaned_answers)
        
        # STEP 3: Search in Pinecone with normalized answers
        # Calculate price and area ranges with 25% flexibility
        price = normalized.get('max_budget')
        min_price, max_price = calculate_range(price)
        
        area = normalized.get('area')
        if area is None:
            min_area, max_area = fallback_area()
        else:
            min_area, max_area = calculate_range(area)
        
        logger.info(f"Price range: {min_price} - {max_price}")
        logger.info(f"Area range: {min_area} - {max_area}")
        
        # Create search parameters from normalized answers
        search_params = PropertySearch(
            min_price=min_price,
            max_price=max_price,
            min_area=min_area,
            max_area=max_area,
            type=normalized.get('property_type'),
            bedrooms=normalized.get('rooms'),
            payment_option=normalized.get('payment_type'),
            city=normalized.get('location'),
            features=normalized.get('features', []),
            min_installment_years=normalized.get('installment_years'),
            max_installment_years=normalized.get('installment_years'),
            min_delivery_in=normalized.get('delivery_in'),
            max_delivery_in=normalized.get('delivery_in'),
            min_down_payment=normalized.get('down_payment'),
            max_down_payment=normalized.get('down_payment'),
            bathrooms=normalized.get('bathrooms')
        )
        
        # Create a search query from cleaned answers for embedding
        search_query = " ".join(cleaned_answers)
        
        # Get results from vector search
        matching_properties = search_properties_vector(search_query, search_params)
        logger.info(f"Found {len(matching_properties)} matching properties")

        response = {
            "qa_answers": cleaned_answers,
            "normalized_answers": normalized,
            "matching_properties": matching_properties
        }
        logger.info(f"Final response: {response}")
        return response
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in extract_answers: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.get("/")
def root():
    return {"message": "✅ LLaMA + Pinecone QA recommendation service running."}

class DirectAnswersInput(BaseModel):
    answers: List[str]

def build_normalization_prompt(answers: List[str]) -> str:
    template = """
    I need you to normalize the following answers about a property search to make them suitable for database querying.
    
    Raw answers:
    1. Property type: {property_type}
    2. Number of rooms: {rooms}
    3. Maximum budget: {budget}
    4. Installment preference: {installment}
    5. Required amenities: {amenities}
    6. Property delivery timeline: {timeline}
    7. Preferred location: {location}
    8. Unit type: {unit_type}
    9. Meeting scheduled: {meeting}
    10. Down payment: {down_payment}
    11. Number of bathrooms: {bathrooms}
    12. Finishing type: {finishing}
    
    Please normalize these values into a JSON format with the following fields:
    - property_type: Normalized property type (apartment, villa, etc.)
    - rooms: Number of bedrooms as an integer
    - max_budget: Budget amount in EGP as an integer (convert 'million' to actual numbers)
    - payment_type: Either "cash" or "installment"
    - features: List of amenities as properly capitalized strings (Pool, Gym, Security, etc.)
    - location: Normalized location name
    - area: Area in square meters as a number if mentioned anywhere in the answers
    - down_payment: Down payment amount as an integer if specified
    - bathrooms: Number of bathrooms as an integer if specified
    - finishing: Type of finishing (Super Lux, Finished, etc.)
    - installment_years: Number of years for installment payment if specified
    - delivery_in: year date of delivery if specified
    
    Here's an example of properly normalized output:
    ```json
    {{
        "property_type": "villa",
        "rooms": 4,
        "max_budget": 5000000,
        "payment_type": "installment",
        "features": ["Pool", "Gym", "Security", "Parking"],
        "location": "new cairo",
        "area": 250,
        "down_payment": 1000000,
        "bathrooms": 3,
        "finishing": "Super Lux",
        "installment_years": 10,
        "delivery_in": 2027
    }}
    ```
    
    Return ONLY the JSON object without explanations.
    """
    
    # Map the answers to the template
    answers_padded = answers + ["not specified"] * (12 - len(answers)) if len(answers) < 12 else answers
    
    return textwrap.dedent(template.format(
        property_type=answers_padded[0],
        rooms=answers_padded[1],
        budget=answers_padded[2],
        installment=answers_padded[3],
        amenities=answers_padded[4],
        timeline=answers_padded[5],
        location=answers_padded[6],
        unit_type=answers_padded[7],
        meeting=answers_padded[8],
        down_payment=answers_padded[9],
        bathrooms=answers_padded[10],
        finishing=answers_padded[11]
    ))

@app.post("/normalize")
def normalize_answers_with_llm(input: DirectAnswersInput):
    logger.info("Received direct normalization request")
    try:
        if not input.answers:
            raise HTTPException(status_code=400, detail="Answers list cannot be empty")
            
        # Clean the answers
        cleaned_answers = []
        for answer in input.answers:
            # Remove any numbering and clean the text
            cleaned = re.sub(r'^\d+\.\s*', '', answer).strip()
            # Remove any extra punctuation
            cleaned = re.sub(r'[.,]$', '', cleaned)
            cleaned_answers.append(cleaned)
        
        prompt = build_normalization_prompt(cleaned_answers)
        logger.debug("Built normalization prompt")
        
        # Get normalized answers from Llama
        raw_response = ollama.generate(prompt)
        logger.debug(f"Raw normalization response: {raw_response[:100]}...")
        
        # Extract JSON from response
        try:
            # Find JSON content between curly braces
            json_match = re.search(r'\{.*\}', raw_response, re.DOTALL)
            if json_match:
                json_str = json_match.group(0)
                import json
                normalized = json.loads(json_str)
                logger.info(f"Successfully parsed normalized answers: {normalized}")
            else:
                # If no JSON found, use our existing normalizer as fallback
                logger.warning("No JSON found in LLM response, using fallback normalizer")
                normalized = normalize_answers(cleaned_answers)
        except Exception as e:
            logger.error(f"Error parsing LLM JSON response: {str(e)}")
            # Fallback to our existing normalizer
            normalized = normalize_answers(cleaned_answers)
        
        # Create search parameters from normalized answers
        price = normalized.get('max_budget')
        min_price, max_price = calculate_range(price)
        
        area = normalized.get('area')
        if area is None:
            min_area, max_area = fallback_area()
        else:
            min_area, max_area = calculate_range(area)
        
        logger.info(f"Price range: {min_price} - {max_price}")
        logger.info(f"Area range: {min_area} - {max_area}")
        
        # Create search parameters
        search_params = PropertySearch(
            min_price=min_price,
            max_price=max_price,
            min_area=min_area,
            max_area=max_area,
            type=normalized.get('property_type'),
            bedrooms=normalized.get('rooms'),
            payment_option=normalized.get('payment_type'),
            city=normalized.get('location'),
            features=normalized.get('features', []),
            min_installment_years=normalized.get('installment_years'),
            max_installment_years=normalized.get('installment_years'),
            min_delivery_in=normalized.get('delivery_in'),
            max_delivery_in=normalized.get('delivery_in'),
            min_down_payment=normalized.get('down_payment'),
            max_down_payment=normalized.get('down_payment'),
            bathrooms=normalized.get('bathrooms')
        )
        
        # Create a search query from original answers for embedding
        search_query = " ".join(cleaned_answers)
        
        # Get results from vector search
        matching_properties = search_properties_vector(search_query, search_params)
        logger.info(f"Found {len(matching_properties)} matching properties")

        response = {
            "original_answers": cleaned_answers,
            "normalized_answers": normalized,
            "matching_properties": matching_properties
        }
        logger.info(f"Final response: {response}")
        return response
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in normalize_answers_with_llm: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

if __name__ == "__main__":
    uvicorn.run("test:app", host="0.0.0.0", port=8002, reload=True)
