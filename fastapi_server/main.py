from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from starlette.middleware.cors import CORSMiddleware
import logging
import httpx
import uvicorn

app = FastAPI()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("FeedbackLogger")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class Feedback(BaseModel):
    feedback_text: str
    property_id: int
    user_id: str = 'anonymous'  # Optional, default is 'anonymous'

# Endpoint to receive feedback
@app.post("/feedback")
async def receive_feedback(feedback: Feedback):
    try:
        # Log received feedback
        logger.info(f"Received feedback: {feedback.dict()}")

        # Prepare data to send to the sentiment/prediction service
        review_data = {
            "review": feedback.feedback_text,
            "property_id": str(feedback.property_id),  # Ensure the property_id is a string
            "user_id": feedback.user_id,
        }

        # Call the sentiment and recommendation service
        async with httpx.AsyncClient() as client:
            # Ensure the correct address for preprocess_service container
           prediction_response = await client.post(
    "http://localhost:8000/predict",  # Docker container name, not localhost
    json=review_data
)

        
        # Handle response from prediction service
        prediction_response.raise_for_status()  # Raise an error if the response is not 200
        prediction_data = prediction_response.json()

        # Log and return the result
        logger.info(f"Prediction result: {prediction_data}")
        return {"status": "success", "message": "Feedback processed successfully", "result": prediction_data}

    except httpx.RequestError as e:
        logger.error(f"Error communicating with prediction service: {e}")
        raise HTTPException(status_code=502, detail="Failed to communicate with prediction service.")
    except Exception as e:
        logger.error(f"Error processing feedback: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@app.get("/")
async def root():
    return {"message": "Welcome to the Feedback API"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8009)
