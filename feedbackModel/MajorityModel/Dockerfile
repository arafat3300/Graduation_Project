# Use official Python image from the Docker Hub
FROM python:3.9-slim

# Set the working directory inside the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Install dependencies from requirements.txt
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Expose the port FastAPI app will run on
EXPOSE 8004

# Run the FastAPI app with Uvicorn
CMD ["uvicorn", "Majority:app", "--host", "0.0.0.0", "--port", "8004"]
