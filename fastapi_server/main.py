from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import logging

app = FastAPI()

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("FeedbackLogger")

# Define feedback data structure
class Feedback(BaseModel):
    feedback_text: str

@app.post("/feedback")
async def receive_feedback(feedback: Feedback):
    logger.info(f"Received feedback: {feedback.dict()}")
    return {"status": "success", "message": "Feedback received"}

@app.get("/")
async def root():
    return {"message": "Welcome to the Feedback API"}
