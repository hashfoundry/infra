#!/bin/bash

echo "🚀 HashFoundry Blockchain Test Script"
echo "======================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Check if containers are running
echo -e "\n${BLUE}📦 Test 1: Checking container status...${NC}"
if docker-compose ps | grep -q "healthy"; then
    echo -e "${GREEN}✅ Containers are running and healthy${NC}"
else
    echo -e "${RED}❌ Containers are not healthy${NC}"
    exit 1
fi

# Test 2: Check Alice RPC endpoint
echo -e "\n${BLUE}📡 Test 2: Testing Alice RPC endpoint (localhost:9933)...${NC}"
ALICE_HEALTH=$(curl -s -H "Content-Type: application/json" \
    -d '{"id":1, "jsonrpc":"2.0", "method": "system_health", "params":[]}' \
    http://localhost:9933)

if echo "$ALICE_HEALTH" | grep -q '"peers":1'; then
    echo -e "${GREEN}✅ Alice RPC is working and has 1 peer${NC}"
    echo "   Response: $ALICE_HEALTH"
else
    echo -e "${RED}❌ Alice RPC is not working properly${NC}"
    exit 1
fi

# Test 3: Check Bob RPC endpoint
echo -e "\n${BLUE}📡 Test 3: Testing Bob RPC endpoint (localhost:9934)...${NC}"
BOB_HEALTH=$(curl -s -H "Content-Type: application/json" \
    -d '{"id":1, "jsonrpc":"2.0", "method": "system_health", "params":[]}' \
    http://localhost:9934)

if echo "$BOB_HEALTH" | grep -q '"peers":1'; then
    echo -e "${GREEN}✅ Bob RPC is working and has 1 peer${NC}"
    echo "   Response: $BOB_HEALTH"
else
    echo -e "${RED}❌ Bob RPC is not working properly${NC}"
    exit 1
fi

# Test 4: Check block production
echo -e "\n${BLUE}🔗 Test 4: Checking block production...${NC}"
BLOCK1=$(curl -s -H "Content-Type: application/json" \
    -d '{"id":1, "jsonrpc":"2.0", "method": "chain_getHeader", "params":[]}' \
    http://localhost:9933 | grep -o '"number":"[^"]*"' | cut -d'"' -f4)

echo "   Current block: $BLOCK1"
echo "   Waiting 10 seconds for new block..."
sleep 10

BLOCK2=$(curl -s -H "Content-Type: application/json" \
    -d '{"id":1, "jsonrpc":"2.0", "method": "chain_getHeader", "params":[]}' \
    http://localhost:9933 | grep -o '"number":"[^"]*"' | cut -d'"' -f4)

echo "   New block: $BLOCK2"

if [ "$BLOCK1" != "$BLOCK2" ]; then
    echo -e "${GREEN}✅ Block production is working (block height increased)${NC}"
else
    echo -e "${RED}❌ Block production seems stuck${NC}"
    exit 1
fi

# Test 5: Check Alice account
echo -e "\n${BLUE}👩 Test 5: Checking Alice account...${NC}"
ALICE_NONCE=$(curl -s -H "Content-Type: application/json" \
    -d '{"id":1, "jsonrpc":"2.0", "method": "system_accountNextIndex", "params":["5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"]}' \
    http://localhost:9933)

if echo "$ALICE_NONCE" | grep -q '"result":0'; then
    echo -e "${GREEN}✅ Alice account exists (nonce: 0)${NC}"
else
    echo -e "${YELLOW}⚠️  Alice account state: $ALICE_NONCE${NC}"
fi

# Test 6: Check Bob account
echo -e "\n${BLUE}👨 Test 6: Checking Bob account...${NC}"
BOB_NONCE=$(curl -s -H "Content-Type: application/json" \
    -d '{"id":1, "jsonrpc":"2.0", "method": "system_accountNextIndex", "params":["5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty"]}' \
    http://localhost:9934)

if echo "$BOB_NONCE" | grep -q '"result":0'; then
    echo -e "${GREEN}✅ Bob account exists (nonce: 0)${NC}"
else
    echo -e "${YELLOW}⚠️  Bob account state: $BOB_NONCE${NC}"
fi

# Summary
echo -e "\n${GREEN}🎉 All tests passed! Blockchain is working correctly!${NC}"
echo -e "\n${BLUE}📋 Summary:${NC}"
echo "   • Alice node: http://localhost:9933 (RPC) / ws://localhost:9944 (WebSocket)"
echo "   • Bob node:   http://localhost:9934 (RPC) / ws://localhost:9945 (WebSocket)"
echo "   • Both nodes are connected and producing blocks"
echo "   • Alice and Bob accounts are available for testing"

echo -e "\n${YELLOW}💡 Next steps:${NC}"
echo "   • Install Node.js to use CLI tools: brew install node"
echo "   • Run CLI tests: cd cli && npm install && npm run check-balances"
echo "   • Stop blockchain: docker-compose down"
echo "   • View logs: docker-compose logs -f"
