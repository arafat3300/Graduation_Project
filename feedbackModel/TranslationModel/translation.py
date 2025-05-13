from fastapi import FastAPI
from pydantic import BaseModel
import openai
import json
import logging
import time
import re

# Set OpenAI API Key
openai.api_key = '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'

# Configure Logging
logging.basicConfig(level=logging.INFO)

# Initialize FastAPI app
app = FastAPI()

# Define the request model
class FeedbackData(BaseModel):
    egyptian_arabic_feedback: str

# Function to remove emojis from text
def remove_emojis(text: str) -> str:
    emoji_pattern = re.compile("[\U0001F600-\U0001F64F\U0001F300-\U0001F5FF\U0001F680-\U0001F6FF\U0001F1E0-\U0001F1FF]+", flags=re.UNICODE)
    return emoji_pattern.sub(r'', text)

# Function to translate Egyptian Arabic to English
def translate_egyptian_arabic(feedback_text: str, delay: int = 2):
    """
    Use OpenAI GPT to translate Egyptian Arabic real estate feedback into English.

    :param feedback_text: Egyptian Arabic feedback text
    :param delay: Delay (in seconds) between retries in case of API errors
    :return: Translated text as a dictionary
    """
    # Remove emojis from input text
    cleaned_feedback = remove_emojis(feedback_text)

    prompt = f"""
    Translate the following Egyptian Arabic real estate feedback into English. The feedback might include opinions about property size, price, location, cleanliness, maintenance, or amenities.

    Feedback: "{cleaned_feedback}"

    Respond in JSON format:
    {{
        "translated_feedback": ""
    }}
    """

    attempt = 1
    while True:
        try:
            response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": "You are a translation assistant specialized in Egyptian Arabic real estate feedback."},
                    {"role": "user", "content": prompt}
                ]
            )

            content = response['choices'][0]['message']['content']
            logging.info(f"GPT Raw Response (Attempt {attempt}): {content}")

            # Parse the JSON response
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

# Define the API endpoint
@app.post("/translate")
async def translate_feedback(data: FeedbackData):
    try:
        translated_text = translate_egyptian_arabic(data.egyptian_arabic_feedback)
        return translated_text
    except Exception as e:
        logging.error(f"Unexpected error: {e}")
        return {"error": "Unexpected error occurred", "details": str(e)}

# Run the app
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8005)
