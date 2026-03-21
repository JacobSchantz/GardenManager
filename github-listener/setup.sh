#!/bin/bash

# Setup script for GitHub webhook listener
# Run this once after cloning: ./github-listener/setup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"

echo "=== GitHub Webhook Listener Setup ==="

# Install node dependencies
echo "Installing Node dependencies..."
cd "$SCRIPT_DIR"
npm install

# Create ngrok launch agent
echo "Setting up ngrok auto-start..."
cat > "$LAUNCH_AGENT_DIR/com.ngrok.webhook.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ngrok.webhook</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/ngrok</string>
        <string>http</string>
        <string>8765</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

# Start the webhook listener
echo "Starting GitHub webhook listener..."
node "$SCRIPT_DIR/server.js" &
LISTENER_PID=$!

# Start ngrok
echo "Starting ngrok tunnel..."
ngrok http 8765 &
NGROK_PID=$!

# Wait for ngrok to start and get URL
echo "Waiting for ngrok to start..."
sleep 3

# Get the ngrok URL
NGROK_URL=$(curl -s localhost:4040/api/tunnels | jq -r '.tunnels[].public_url' 2>/dev/null || echo "")

if [ -z "$NGROK_URL" ]; then
    echo "ERROR: Could not get ngrok URL. Check ngrok is installed."
    exit 1
fi

WEBHOOK_URL="${NGROK_URL}/webhook"

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Webhook URL: $WEBHOOK_URL"
echo ""
echo "Add this URL to your GitHub repo settings:"
echo "  1. Go to repo → Settings → Webhooks"
echo "  2. Add webhook with URL: $WEBHOOK_URL"
echo "  3. Set content type: application/json"
echo "  4. Select events: Pushes"
echo ""
echo "To check status:"
echo "  - Listener logs: tail -f $SCRIPT_DIR/launch.log"
echo "  - Ngrok status: curl localhost:4040/api/tunnels"
echo ""
echo "The webhook listener is running!"
