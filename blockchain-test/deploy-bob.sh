#!/bin/bash

# 🚀 Deploy Bob Validator Script
# Usage: ./deploy-bob.sh [ALICE_IP]

ALICE_IP=${1:-"192.168.1.10"}
ALICE_PEER_ID="12D3KooWAMacdttUqjZbBG2WzK7j6uZ8xfuv77eKzDKzKi6w3Jm8"
BOB_PEER_ID="12D3KooWCypfENuYs2G13wp2pJ9LaukfCcRHT4tAxEyE1XCGwVVN"

echo "🚀 Deploying Bob validator for multi-machine setup..."
echo "📡 Alice IP: $ALICE_IP"
echo "🔑 Alice Peer ID: $ALICE_PEER_ID"
echo "🔑 Bob Peer ID: $BOB_PEER_ID"
echo ""

# Create docker-compose.yml for Bob
cat > docker-compose.yml << EOF
services:
  blockchain-bob:
    image: parity/substrate:latest
    container_name: blockchain-bob
    command:
      - --chain=local
      - --validator
      - --bob
      - --tmp
      - --rpc-external
      - --rpc-port=9933
      - --rpc-cors=all
      - --rpc-methods=unsafe
      - --name=bob-node
      - --bootnodes=/ip4/$ALICE_IP/tcp/30333/p2p/$ALICE_PEER_ID
    ports:
      - "9933:9933"   # RPC HTTP
      - "9944:9944"   # RPC WebSocket  
      - "30333:30333" # P2P
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-H", "Content-Type: application/json", "-d", "{\"id\":1, \"jsonrpc\":\"2.0\", \"method\": \"system_health\", \"params\":[]}", "http://localhost:9933"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

networks:
  default:
    driver: bridge
EOF

echo "📝 Created docker-compose.yml for Bob"

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose down 2>/dev/null || true

# Start Bob validator
echo "🚀 Starting Bob validator..."
docker-compose up -d

# Wait for startup
echo "⏳ Waiting for Bob to start..."
sleep 10

# Check status
echo "🔍 Checking Bob status..."
if docker-compose ps | grep -q "Up"; then
    echo "✅ Bob validator is running!"
    
    # Test RPC endpoint
    echo "📡 Testing RPC endpoint..."
    sleep 5
    
    HEALTH_RESPONSE=$(curl -s -H "Content-Type: application/json" \
         -d '{"id":1, "jsonrpc":"2.0", "method": "system_health", "params":[]}' \
         http://localhost:9933 2>/dev/null || echo "failed")
    
    if [[ "$HEALTH_RESPONSE" != "failed" ]]; then
        echo "✅ Bob RPC is responding"
        echo "📊 Health: $HEALTH_RESPONSE"
        
        # Check for peers
        if echo "$HEALTH_RESPONSE" | grep -q '"peers":1'; then
            echo "🎉 Bob is connected to Alice!"
        elif echo "$HEALTH_RESPONSE" | grep -q '"peers":0'; then
            echo "⏳ Bob is not yet connected to Alice (this is normal, may take a minute)"
        fi
    else
        echo "⚠️  Bob RPC not yet ready (this is normal, wait a bit more)"
    fi
    
    echo ""
    echo "🎉 Bob validator deployment complete!"
    echo ""
    echo "📋 Connection details:"
    echo "   • RPC HTTP:     http://localhost:9933"
    echo "   • RPC WebSocket: ws://localhost:9944"
    echo "   • P2P Port:     30333"
    echo "   • Peer ID:      $BOB_PEER_ID"
    echo ""
    echo "📡 Connecting to Alice at $ALICE_IP:30333"
    echo ""
    echo "💡 Next steps:"
    echo "   1. Wait 1-2 minutes for P2P connection to establish"
    echo "   2. Check connection: docker-compose logs -f"
    echo "   3. Test health: curl -H 'Content-Type: application/json' -d '{\"id\":1, \"jsonrpc\":\"2.0\", \"method\": \"system_health\", \"params\":[]}' http://localhost:9933"
    echo "   4. Expected result: \"peers\": 1 (connected to Alice)"
    
else
    echo "❌ Failed to start Bob validator"
    echo "🔍 Check logs: docker-compose logs"
    exit 1
fi
