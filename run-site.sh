#!/usr/bin/env bash

# Change to the directory containing the cloned site
pushd launcher-xss-payload

# Start a local HTTP server
echo "Starting local HTTP server on http://localhost:8000"
echo "Press Ctrl+C to stop the server"
python3 -m http.server 8000

# Return to the original directory when done
popd