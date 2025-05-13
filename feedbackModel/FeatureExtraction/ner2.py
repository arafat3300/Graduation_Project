from fastapi import FastAPI
from pydantic import BaseModel
import openai
import json
import logging
import os
import time

openai.api_key = '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'

logging.basicConfig(level=logging.INFO)

app = FastAPI()

class ProcessedReviewData(BaseModel):
    preprocessed_review: str

def extract_entities_with_chatgpt(preprocessed_text: str, delay: int = 2):
    """
    Extract entities using OpenAI GPT with continuous retry logic until a valid response is received.

    :param preprocessed_text: Text to process
    :param delay: Delay (in seconds) between retries
    :return: Extracted entities as a dictionary
    """
    prompt = f"""
    Extract the following real estate entities from the text and label them:

    Entities: size, price, location, cleanliness, maintenance, amenities

    Text: "{preprocessed_text}"

    only respond in JSON format:
    {{
        "size": "",
        "price": "",
        "location": "",
        "cleanliness": "",
        "maintenance": "",
        "amenities":""
    }}
    """

    attempt = 1
    while True:
        try:
            response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": "You are an NER assistant for real estate."},
                    {"role": "user", "content": prompt}
                ]
            )

            content = response['choices'][0]['message']['content']
            logging.info(f"GPT Raw Response (Attempt {attempt}): {content}")

            # Try to parse the JSON response
            return json.loads(content)
        except json.JSONDecodeError as e:
            logging.error(f"Invalid JSON format on attempt {attempt}: {e}")
        except openai.error.OpenAIError as e:
            logging.error(f"OpenAI API error on attempt {attempt}: {e}")
        except Exception as e:
            logging.error(f"Unexpected error on attempt {attempt}: {e}")

        logging.info(f"Retrying in {delay} seconds...")
        time.sleep(delay)
        attempt += 1

@app.post("/extract")
async def extract_features(data: ProcessedReviewData):
    try:
        extracted_entities = extract_entities_with_chatgpt(data.preprocessed_review)
        return extracted_entities
    except Exception as e:
        logging.error(f"Unexpected error: {e}")
        return {"error": "Unexpected error occurred", "details": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
