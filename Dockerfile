# RomaSub.AI Backend Dockerfile
# Multi-stage build for optimized image size

# Stage 1: Build stage
FROM python:3.11-slim as builder

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    make \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Stage 2: Runtime stage
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Create directories that back the persistent named volumes (see
# docker-compose.yml): media uploads at /app/uploads/media and runtime JSON
# state at /app/var/state (STATE_DIR). Both are mounted as volumes so their
# contents survive container redeploys. The loanword/names dictionaries ship
# inside the image at /app/app/data (via COPY app/) and are intentionally NOT
# volume-mounted, so rebuilds pick up dictionary edits with no volume recreate.
RUN mkdir -p /app/uploads/media && \
    mkdir -p /app/var/state

# Copy application code
COPY app/ /app/app/
COPY demo/ /app/demo/

# Create .env file placeholder (will be overridden by docker-compose)
RUN touch /app/.env

# Expose port
EXPOSE 8000

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health', timeout=5)"

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
