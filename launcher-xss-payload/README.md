# Web Payload

Replace the "Update firmware" functionality of launcher.keychron.com with the custom firmware.

```bash
./clone-site-locally.sh
cp ../custom-firmware.bin launcher.keychron.com/firmware.bin # Make sure the path matches the one in inject.js
./start-local-site.sh
```
