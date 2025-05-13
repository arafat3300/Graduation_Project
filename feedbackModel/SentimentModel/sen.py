from fastapi import FastAPI, Request
from transformers import pipeline, AutoTokenizer, AutoModelForSequenceClassification
import warnings

# Suppress warnings
warnings.filterwarnings("ignore", category=FutureWarning)


app = FastAPI()


token = "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"

tokenizer = AutoTokenizer.from_pretrained("distilbert-base-uncased-finetuned-sst-2-english", use_auth_token=token)
model = AutoModelForSequenceClassification.from_pretrained("distilbert-base-uncased-finetuned-sst-2-english", use_auth_token=token)


sentiment_pipeline = pipeline("sentiment-analysis", model=model, tokenizer=tokenizer)

@app.post("/analyze-sentiment")
async def analyze_sentiment(request: Request):

    data = await request.json()
    tag_texts = data.get("tag_texts", {})
    sentiment_results = {}


    for tag, tag_text in tag_texts.items():
        if not tag_text.strip():  
            sentiment_results[f"{tag}_sentiment"] = "Neutral"
            sentiment_results[f"{tag}_confidence"] = 1.0  
        else:
            result = sentiment_pipeline(tag_text[:512])[0]  
            sentiment_results[f"{tag}_sentiment"] = result["label"].capitalize()
            sentiment_results[f"{tag}_confidence"] = float(result["score"])

    # Return the sentiment analysis results
    return sentiment_results

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)
