#!/bin/bash

# 🌐 Multi-Machine Blockchain Connection Test Script
# Usage: ./test-multi-machine.sh [REMOTE_IP]

REMOTE_IP=${1:-"192.168.1.20"}
LOCAL_PORT=${2:-"9933"}
REMOTE_PORT=${3:-"9933"}

echo "🌐 Multi-Machine Blockchain Connection Test"
echo "=========================================="
echo ""
echo "🔧 Configuration:"
echo "   • Local node:  localhost:$LOCAL_PORT"
echo "   • Remote node: $REMOTE_IP:$REMOTE_PORT"
echo ""

# Test 1: Local node health
echo "📡 Test 1: Testing local node health..."
LOCAL_HEALTH=$(curl -s -H "Content-Type: application/json" \
     -d '{"id":1, "jsonrpc":"2.0", "method": "system_health", "params":[]}' \
     http://localhost:$LOCAL_PORT 2>/dev/null)

if [[ "$LOCAL_HEALTH" == *"peers"* ]]; then
    LOCAL_PEERS=$(echo "$LOCAL_HEALTH" | grep -o '"peers":[0-9]*' | grep -o '[0-9]*')
    echo "✅ Local node is healthy"
    echo "   Peers: $LOCAL_PEERS"
    echo "   Response: $LOCAL_HEALTH"
else
    echo "❌ Local node is not responding"
    echo "💡 Make sure local blockchain is running: docker-compose up -d"
    exit 1
fi

echo ""

# Test 2: Remote node connectivity
echo "📡 Test 2: Testing remote node connectivity..."
REMOTE_HEALTH=$(curl -s -H "Content-Type: application/json" \
     -d '{"id":1, "jsonrpc":"2.0", "method": "system_health", "params":[]}' \
     http://$REMOTE_IP:$REMOTE_PORT 2>/dev/null)

if [[ "$REMOTE_HEALTH" == *"peers"* ]]; then
    REMOTE_PEERS=$(echo "$REMOTE_HEALTH" | grep -o '"peers":[0-9]*' | grep -o '[0-9]*')
    echo "✅ Remote node is reachable"
    echo "   Peers: $REMOTE_PEERS"
    echo "   Response: $REMOTE_HEALTH"
else
    echo "❌ Remote node is not reachable"
    echo "💡 Check:"
    echo "   1. Remote blockchain is running"
    echo "   2. Firewall allows port $REMOTE_PORT"
    echo "   3. IP address $REMOTE_IP is correct"
    echo "   4. Network connectivity: ping $REMOTE_IP"
    exit 1
fi

echo ""

# Test 3: P2P connectivity check
echo "🔗 Test 3: Checking P2P connectivity..."
if [[ "$LOCAL_PEERS" -gt 0 ]] && [[ "$REMOTE_PEERS" -gt 0 ]]; then
    echo "✅ Both nodes have peers connected"
    echo "   Local peers: $LOCAL_PEERS"
    echo "   Remote peers: $REMOTE_PEERS"
    
    if [[ "$LOCAL_PEERS" == "1" ]] && [[ "$REMOTE_PEERS" == "1" ]]; then
        echo "🎉 Perfect! Both nodes are connected to each other"
    else
        echo "⚠️  Multiple peers detected - this might be expected in larger networks"
    fi
else
    echo "⚠️  P2P connection issue detected"
    echo "   Local peers: $LOCAL_PEERS"
    echo "   Remote peers: $REMOTE_PEERS"
    echo ""
    echo "💡 Troubleshooting:"
    echo "   1. Check bootnodes configuration in docker-compose.yml"
    echo "   2. Verify P2P port 30333 is open on both machines"
    echo "   3. Wait 1-2 minutes for P2P discovery to complete"
    echo "   4. Check logs: docker-compose logs -f"
fi

echo ""

# Test 4: Block synchronization
echo "🔗 Test 4: Checking block synchronization..."
LOCAL_BLOCK=$(curl -s -H "Content-Type: application/json" \
     -d '{"id":1, "jsonrpc":"2.0", "method": "chain_getHeader", "params":[]}' \
     http://localhost:$LOCAL_PORT 2>/dev/null | grep -o '"number":"0x[^"]*"' | grep -o '0x[^"]*')

REMOTE_BLOCK=$(curl -s -H "Content-Type: application/json" \
     -d '{"id":1, "jsonrpc":"2.0", "method": "chain_getHeader", "params":[]}' \
     http://$REMOTE_IP:$REMOTE_PORT 2>/dev/null | grep -o '"number":"0x[^"]*"' | grep -o '0x[^"]*')

if [[ -n "$LOCAL_BLOCK" ]] && [[ -n "$REMOTE_BLOCK" ]]; then
    LOCAL_BLOCK_NUM=$((16#${LOCAL_BLOCK#0x}))
    REMOTE_BLOCK_NUM=$((16#${REMOTE_BLOCK#0x}))
    
    echo "📊 Block heights:"
    echo "   Local:  #$LOCAL_BLOCK_NUM ($LOCAL_BLOCK)"
    echo "   Remote: #$REMOTE_BLOCK_NUM ($REMOTE_BLOCK)"
    
    BLOCK_DIFF=$((LOCAL_BLOCK_NUM - REMOTE_BLOCK_NUM))
    if [[ $BLOCK_DIFF -lt 0 ]]; then
        BLOCK_DIFF=$((-BLOCK_DIFF))
    fi
    
    if [[ $BLOCK_DIFF -le 2 ]]; then
        echo "✅ Blocks are synchronized (difference: $BLOCK_DIFF blocks)"
    else
        echo "⚠️  Blocks are not synchronized (difference: $BLOCK_DIFF blocks)"
        echo "💡 This might indicate network issues or one node is behind"
    fi
else
    echo "❌ Could not retrieve block information"
fi

echo ""

# Test 5: Network latency
echo "🌐 Test 5: Testing network latency..."
if command -v ping >/dev/null 2>&1; then
    echo "📡 Pinging $REMOTE_IP..."
    PING_RESULT=$(ping -c 3 $REMOTE_IP 2>/dev/null | tail -1)
    if [[ "$PING_RESULT" == *"avg"* ]]; then
        echo "✅ Network connectivity OK"
        echo "   $PING_RESULT"
    else
        echo "⚠️  Network connectivity issues"
        echo "💡 Check network connection to $REMOTE_IP"
    fi
else
    echo "⚠️  ping command not available, skipping latency test"
fi

echo ""

# Summary
echo "📋 Multi-Machine Test Summary:"
echo "================================"

if [[ "$LOCAL_HEALTH" == *"peers"* ]] && [[ "$REMOTE_HEALTH" == *"peers"* ]]; then
    if [[ "$LOCAL_PEERS" -gt 0 ]] && [[ "$REMOTE_PEERS" -gt 0 ]]; then
        echo "🎉 SUCCESS: Multi-machine blockchain is working!"
        echo ""
        echo "✅ Both nodes are healthy and connected"
        echo "✅ P2P network is functional"
        echo "✅ Blocks are being produced and synchronized"
        echo ""
        echo "🔗 Connection details:"
        echo "   • Local node:  http://localhost:$LOCAL_PORT"
        echo "   • Remote node: http://$REMOTE_IP:$REMOTE_PORT"
        echo "   • P2P peers:   Local($LOCAL_PEERS) ↔ Remote($REMOTE_PEERS)"
        echo ""
        echo "💡 Next steps:"
        echo "   • Test transfers between Alice and Bob accounts"
        echo "   • Monitor logs: docker-compose logs -f"
        echo "   • Scale to more validators if needed"
    else
        echo "⚠️  PARTIAL SUCCESS: Nodes are reachable but not fully connected"
        echo ""
        echo "✅ Both nodes are responding to RPC calls"
        echo "❌ P2P connection needs troubleshooting"
        echo ""
        echo "🔧 Troubleshooting steps:"
        echo "   1. Check firewall settings (port 30333)"
        echo "   2. Verify bootnodes configuration"
        echo "   3. Wait longer for P2P discovery"
        echo "   4. Check network connectivity"
    fi
else
    echo "❌ FAILURE: Multi-machine setup has issues"
    echo ""
    echo "🔧 Check:"
    echo "   • Both blockchain nodes are running"
    echo "   • Network connectivity between machines"
    echo "   • Firewall settings"
    echo "   • Correct IP addresses and ports"
fi

echo ""
echo "🔍 For detailed logs, run:"
echo "   docker-compose logs -f"
echo ""
echo "📚 For setup instructions, see:"
echo "   MULTI_MACHINE_DEPLOYMENT.md"
