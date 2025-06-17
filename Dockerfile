FROM caddy:2.7-alpine

# Copy the website files
COPY launcher-xss-payload/ /usr/share/caddy/
COPY custom_firmware/firmware/ /usr/share/caddy/firmware/
COPY custom_firmware/via_json/ /usr/share/caddy/via_json/

# Copy Caddyfile
COPY Caddyfile /etc/caddy/Caddyfile

# Expose port 80 and 443
EXPOSE 80 443