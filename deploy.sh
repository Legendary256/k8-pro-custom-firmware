#!/usr/bin/env bash

set -e

echo "🚀 Deploying Keychron Launcher with Custom Firmware"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Ensure we have the latest site assets
echo "📥 Downloading latest site assets..."
./clone-site.sh

echo "🚀 Starting services..."
docker-compose up -d --build

# Wait for service to be ready
echo "⏳ Waiting for service to be ready..."
sleep 10

# Check if service is running
if docker-compose ps | grep -q "Up"; then
    echo "✅ Service is running successfully!"
    echo "🌐 Website is available at:"
    echo "   - http://localhost (if running locally)"
    echo "   - http://your-ec2-ip (if running on EC2)"
    echo ""
    echo "📁 Available endpoints:"
    echo "   - / (Main Keychron Launcher interface)"
    echo "   - /firmware/ (Custom firmware files)"
    echo "   - /via_json/ (VIA configuration files)"
    echo ""
    echo "🔧 To view logs: docker-compose logs -f"
    echo "🛑 To stop: docker-compose down"
else
    echo "❌ Service failed to start. Check logs with: docker-compose logs"
    exit 1
fi 