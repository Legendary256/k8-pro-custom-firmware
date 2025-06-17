#!/usr/bin/env bash

# Copy site assets locally
wget -m launcher.keychron.com

# A few assets wget doesn't hit
mkdir launcher.keychron.com/assets
mkdir launcher.keychron.com/assets/menu
mkdir launcher.keychron.com/assets/outline
mkdir launcher.keychron.com/assets/sound

assets=(
    "590.53d8624929d1e66a.js"
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
)

# Fetch each asset
for API_PATH in "${assets[@]}"; do
  WHOLE_PATH="launcher.keychron.com/${API_PATH}"
  curl -sSf "$WHOLE_PATH" -o "$WHOLE_PATH" || echo "Failed to fetch $WHOLE_PATH"
done

# Inject script
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' -e 's|</noscript>|</noscript>\
    <script src="inject.js"><\/script>|g' launcher.keychron.com/index.html
else
    sed -i -e 's|</noscript>|</noscript>\
    <script src="inject.js"><\/script>|g' launcher.keychron.com/index.html
fi

cp inject.js launcher.keychron.com
