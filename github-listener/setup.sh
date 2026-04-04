#!/bin/bash

# Setup script for GitHub webhook listener
# Run this once after cloning: ./github-listener/setup.sh
# One-time setup on a new computer:
# 1. Install ngrok: brew install ngrok/ngrok/ngrok
# 2. Create or sign in to ngrok: https://dashboard.ngrok.com/signup
# 3. Add your auth token: ngrok config add-authtoken <token>
#    Or run this script with NGROK_AUTHTOKEN set.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
NGROK_BIN="$(command -v ngrok || true)"

if [ -z "$NGROK_BIN" ] && [ -x /opt/homebrew/bin/ngrok ]; then
    NGROK_BIN=/opt/homebrew/bin/ngrok
elif [ -z "$NGROK_BIN" ] && [ -x /usr/local/bin/ngrok ]; then
    NGROK_BIN=/usr/local/bin/ngrok
fi

echo "=== GitHub Webhook Listener Setup ==="

if [ -z "$NGROK_BIN" ]; then
    echo "ERROR: ngrok is not installed or not on PATH."
    echo "Install it, then run this script again:"
    echo "  brew install ngrok/ngrok/ngrok"
    echo "After install, create/sign in to ngrok and add your auth token:"
    echo "  https://dashboard.ngrok.com/signup"
    echo "  ngrok config add-authtoken <your-token>"
    exit 1
fi

if [ -n "$NGROK_AUTHTOKEN" ]; then
    echo "Configuring ngrok authtoken from NGROK_AUTHTOKEN..."
    "$NGROK_BIN" config add-authtoken "$NGROK_AUTHTOKEN" >/dev/null
fi

NGROK_POOLING_ENABLED="${NGROK_POOLING_ENABLED:-1}"

# Install node dependencies
echo "Installing Node dependencies..."
cd "$SCRIPT_DIR"
npm install

# Create ngrok launch agent
echo "Setting up ngrok auto-start..."
cat > "$LAUNCH_AGENT_DIR/com.ngrok.webhook.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ngrok.webhook</string>
    <key>ProgramArguments</key>
    <array>
        <string>${NGROK_BIN}</string>
        <string>http</string>
        <string>8765</string>
        <string>--pooling-enabled</string>
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
LISTENER_PID=""
EXISTING_LISTENER_PID="$(lsof -tiTCP:8765 -sTCP:LISTEN 2>/dev/null | head -n 1 || true)"

if [ -n "$EXISTING_LISTENER_PID" ]; then
    LISTENER_HEALTH="$(curl -fsS http://localhost:8765/ 2>/dev/null || true)"
    if echo "$LISTENER_HEALTH" | grep -q "GitHub Listener running"; then
        echo "Webhook listener already running on port 8765 (PID $EXISTING_LISTENER_PID)."
    else
        echo "ERROR: Port 8765 is already in use by PID $EXISTING_LISTENER_PID."
        echo "Stop that process or change the listener port, then run setup again."
        exit 1
    fi
else
    node "$SCRIPT_DIR/server.js" &
    LISTENER_PID=$!
fi

# Start ngrok
echo "Starting ngrok tunnel..."
if [ "$NGROK_POOLING_ENABLED" = "1" ]; then
    "$NGROK_BIN" http 8765 --pooling-enabled >/tmp/github-listener-ngrok.log 2>&1 &
else
    "$NGROK_BIN" http 8765 >/tmp/github-listener-ngrok.log 2>&1 &
fi
NGROK_PID=$!

# Wait for ngrok to start and get URL
echo "Waiting for ngrok to start..."
NGROK_URL=""

for attempt in {1..15}; do
    sleep 1

    if ! kill -0 "$NGROK_PID" 2>/dev/null; then
        break
    fi

    NGROK_URL=$(curl -s localhost:4040/api/tunnels | node -e 'let data=""; process.stdin.on("data", chunk => data += chunk); process.stdin.on("end", () => { try { const parsed = JSON.parse(data); const tunnels = parsed.tunnels || []; const tunnel = tunnels.find(item => typeof item.public_url === "string" && item.public_url.startsWith("https://")) || tunnels[0]; process.stdout.write(tunnel?.public_url || ""); } catch { process.stdout.write(""); } });' 2>/dev/null || true)

    if [ -n "$NGROK_URL" ]; then
        break
    fi
done

if [ -z "$NGROK_URL" ]; then
    if grep -q "ERR_NGROK_4018\|authtoken" /tmp/github-listener-ngrok.log 2>/dev/null; then
        echo "ERROR: ngrok is installed, but not authenticated."
        echo "Create/sign in to ngrok: https://dashboard.ngrok.com/signup"
        echo "Get your token: https://dashboard.ngrok.com/get-started/your-authtoken"
        echo "Then run either:"
        echo "  ngrok config add-authtoken <your-token>"
        echo "or:"
        echo "  NGROK_AUTHTOKEN=<your-token> ./setup.sh"
    elif grep -q "ERR_NGROK_334\|already online" /tmp/github-listener-ngrok.log 2>/dev/null; then
        echo "ERROR: This ngrok endpoint is already online on another machine or session."
        echo "This script now starts ngrok with pooling enabled by default for multi-computer setup."
        echo "If another machine is still using the old non-pooled setup, stop that tunnel and run setup again there too."
        echo "You can disable pooling with: NGROK_POOLING_ENABLED=0 ./setup.sh"
    else
        echo "ERROR: Could not get ngrok URL. Check ngrok is installed and authenticated."
    fi
    echo "ngrok log: /tmp/github-listener-ngrok.log"
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
