FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY flask_server.py .

# Expose port
EXPOSE 5000

# Set environment variables
ENV FLASK_APP=flask_server.py
ENV FLASK_ENV=production

# Run the Flask server
CMD ["python", "flask_server.py", "--host", "0.0.0.0", "--port", "5000"] 