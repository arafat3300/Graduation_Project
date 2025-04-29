# User Segmentation Service

A FastAPI-based service that performs dynamic user segmentation based on property preferences and behaviors, using K-means clustering and Google's Gemini AI for segment labeling.

## Features

- Dynamic user segmentation based on property preferences
- AI-powered segment naming and description using Gemini
- Behavioral analysis based on user favorites
- Sale-specific preference analysis (installments, delivery, finishing)
- RESTful API endpoints

## Setup

1. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up environment variables:
Create a `.env` file with:
```
DB_USERNAME=postgres
DB_PASSWORD=postgres
DB_PORT=5432
DB_NAME=odoo18v3
GOOGLE_API_KEY=your_gemini_api_key
```

## Running the Service

1. Activate the virtual environment:
```bash
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Start the server:
```bash
uvicorn backend.main:app --host 0.0.0.0 --port 8081 --reload
```

## API Endpoints

### POST /user-segments/
Creates user segments based on property preferences and behaviors.

Request body:
```json
{
    "host": "database_host",
    "n_clusters": 5
}
```

Response:
```json
{
    "total_users": 100,
    "n_clusters": 5,
    "cluster_insights": [...],
    "user_segments": [...]
}
```

## Directory Structure

```
user_segmentation_server/
├── backend/
│   ├── __init__.py
│   ├── main.py
│   └── user_segmentation.py
├── venv/
├── .env
├── requirements.txt
└── README.md
``` 