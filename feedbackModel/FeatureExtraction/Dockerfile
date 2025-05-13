# Use an official Python base image
FROM python:3.9

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file and install dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy all files in the extraction_model directory to the working directory
COPY . .

# Expose the port the app will run on
EXPOSE 8001

# Run the FastAPI app using Uvicorn
CMD ["uvicorn", "ner2:app", "--host", "0.0.0.0", "--port", "8001"]