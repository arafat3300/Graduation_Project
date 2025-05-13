# Use an official Python base image
FROM python:3.9

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file and install dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Download necessary NLTK data
RUN python -m nltk.downloader stopwords
RUN python -m nltk.downloader wordnet

# Copy the application code to the working directory
COPY . .

# Expose the port the app will run on
EXPOSE 8000

# Run the FastAPI app using Uvicorn
CMD ["uvicorn", "reviewpreprocessing:app", "--host", "0.0.0.0", "--port", "8000"]
