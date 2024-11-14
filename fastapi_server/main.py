from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from starlette.middleware.cors import CORSMiddleware
import logging

app = FastAPI()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("FeedbackLogger")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
class Feedback(BaseModel):
    feedback_text: str

@app.post("/feedback")
async def receive_feedback(feedback: Feedback):
    logger.info(f"Received feedback: {feedback.dict()}")
    return {"status": "success", "message": "Feedback received"}

@app.get("/")
async def root():
    return {"message": "Welcome to the Feedback API"}
