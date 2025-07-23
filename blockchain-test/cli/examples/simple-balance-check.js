const https = require('https');
const http = require('http');

// Alice and Bob addresses
const ALICE_ADDRESS = '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY';
const BOB_ADDRESS = '5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty';

function makeRpcCall(port, method, params = []) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      id: 1,
      jsonrpc: '2.0',
      method: method,
      params: params
    });

    const options = {
      hostname: 'localhost',
      port: port,
      path: '/',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length
      }
    };

    const req = http.request(options, (res) => {
      let responseData = '';
      
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      
      res.on('end', () => {
        try {
          const result = JSON.parse(responseData);
          resolve(result);
        } catch (error) {
          reject(error);
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.write(data);
    req.end();
  });
}

async function checkSimpleBalances() {
  console.log('🔍 Simple Balance Check via HTTP RPC...\n');

  try {
    // Test Alice node connectivity
    console.log('📡 Testing Alice node (localhost:9933)...');
    const aliceHealth = await makeRpcCall(9933, 'system_health');
    console.log(`✅ Alice health: ${JSON.stringify(aliceHealth.result)}`);

    // Test Bob node connectivity  
    console.log('📡 Testing Bob node (localhost:9934)...');
    const bobHealth = await makeRpcCall(9934, 'system_health');
    console.log(`✅ Bob health: ${JSON.stringify(bobHealth.result)}`);

    // Get Alice account info
    console.log('\n👩 Checking Alice account...');
    try {
      const aliceAccount = await makeRpcCall(9933, 'system_account', [ALICE_ADDRESS]);
      if (aliceAccount.result) {
        console.log(`✅ Alice account found: ${JSON.stringify(aliceAccount.result)}`);
      } else {
        console.log(`⚠️  Alice account response: ${JSON.stringify(aliceAccount)}`);
      }
    } catch (error) {
      console.log(`⚠️  Alice account check failed: ${error.message}`);
    }

    // Get Bob account info
    console.log('\n👨 Checking Bob account...');
    try {
      const bobAccount = await makeRpcCall(9934, 'system_account', [BOB_ADDRESS]);
      if (bobAccount.result) {
        console.log(`✅ Bob account found: ${JSON.stringify(bobAccount.result)}`);
      } else {
        console.log(`⚠️  Bob account response: ${JSON.stringify(bobAccount)}`);
      }
    } catch (error) {
      console.log(`⚠️  Bob account check failed: ${error.message}`);
    }

    // Get current block info
    console.log('\n🔗 Checking current block...');
    const blockHeader = await makeRpcCall(9933, 'chain_getHeader');
    console.log(`✅ Current block: #${parseInt(blockHeader.result.number, 16)}`);

    console.log('\n✅ Simple balance check completed!');

  } catch (error) {
    console.error('❌ Error during balance check:', error.message);
    process.exit(1);
  }
}

checkSimpleBalances().then(() => process.exit(0));
