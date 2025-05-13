# Stage 1: Build layer (installs packages efficiently)
FROM python:3.9-slim as builder

WORKDIR /app

# System dependencies (minimal)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install pip dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Stage 2: Runtime-only layer (slim & clean)
FROM python:3.9-slim

WORKDIR /app

# Copy only what you need
COPY --from=builder /usr/local /usr/local
COPY sen.py .

# Expose correct port
EXPOSE 8002

CMD ["uvicorn", "sen:app", "--host", "0.0.0.0", "--port", "8002"]
