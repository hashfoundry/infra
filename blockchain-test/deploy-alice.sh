#!/bin/bash

# 🚀 Deploy Alice Validator Script
# Usage: ./deploy-alice.sh [BOB_IP]

BOB_IP=${1:-"192.168.1.20"}
ALICE_PEER_ID="12D3KooWAMacdttUqjZbBG2WzK7j6uZ8xfuv77eKzDKzKi6w3Jm8"
BOB_PEER_ID="12D3KooWCypfENuYs2G13wp2pJ9LaukfCcRHT4tAxEyE1XCGwVVN"

echo "🚀 Deploying Alice validator for multi-machine setup..."
echo "📡 Bob IP: $BOB_IP"
echo "🔑 Alice Peer ID: $ALICE_PEER_ID"
echo "🔑 Bob Peer ID: $BOB_PEER_ID"
echo ""

# Create docker-compose.yml for Alice
cat > docker-compose.yml << EOF
services:
  blockchain-alice:
    image: parity/substrate:latest
    container_name: blockchain-alice
    command:
      - --chain=local
      - --validator
      - --alice
      - --tmp
      - --rpc-external
      - --rpc-port=9933
      - --rpc-cors=all
      - --rpc-methods=unsafe
      - --name=alice-node
      - --bootnodes=/ip4/$BOB_IP/tcp/30333/p2p/$BOB_PEER_ID
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

echo "📝 Created docker-compose.yml for Alice"

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose down 2>/dev/null || true

# Start Alice validator
echo "🚀 Starting Alice validator..."
docker-compose up -d

# Wait for startup
echo "⏳ Waiting for Alice to start..."
sleep 10

# Check status
echo "🔍 Checking Alice status..."
if docker-compose ps | grep -q "Up"; then
    echo "✅ Alice validator is running!"
    
    # Test RPC endpoint
    echo "📡 Testing RPC endpoint..."
    sleep 5
    
    HEALTH_RESPONSE=$(curl -s -H "Content-Type: application/json" \
         -d '{"id":1, "jsonrpc":"2.0", "method": "system_health", "params":[]}' \
         http://localhost:9933 2>/dev/null || echo "failed")
    
    if [[ "$HEALTH_RESPONSE" != "failed" ]]; then
        echo "✅ Alice RPC is responding"
        echo "📊 Health: $HEALTH_RESPONSE"
    else
        echo "⚠️  Alice RPC not yet ready (this is normal, wait a bit more)"
    fi
    
    echo ""
    echo "🎉 Alice validator deployment complete!"
    echo ""
    echo "📋 Connection details:"
    echo "   • RPC HTTP:     http://localhost:9933"
    echo "   • RPC WebSocket: ws://localhost:9944"
    echo "   • P2P Port:     30333"
    echo "   • Peer ID:      $ALICE_PEER_ID"
    echo ""
    echo "📡 Waiting for connection to Bob at $BOB_IP:30333"
    echo ""
    echo "💡 Next steps:"
    echo "   1. Deploy Bob validator on machine $BOB_IP"
    echo "   2. Check connection: docker-compose logs -f"
    echo "   3. Test health: curl -H 'Content-Type: application/json' -d '{\"id\":1, \"jsonrpc\":\"2.0\", \"method\": \"system_health\", \"params\":[]}' http://localhost:9933"
    
else
    echo "❌ Failed to start Alice validator"
    echo "🔍 Check logs: docker-compose logs"
    exit 1
fi
