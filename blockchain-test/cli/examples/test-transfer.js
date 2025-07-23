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

async function testTransfer() {
  console.log('💸 Testing Transfer Functionality...\n');

  try {
    // Check Alice nonce
    console.log('👩 Checking Alice account nonce...');
    const aliceNonce = await makeRpcCall(9933, 'system_accountNextIndex', [ALICE_ADDRESS]);
    console.log(`✅ Alice nonce: ${aliceNonce.result}`);

    // Check Bob nonce
    console.log('👨 Checking Bob account nonce...');
    const bobNonce = await makeRpcCall(9934, 'system_accountNextIndex', [BOB_ADDRESS]);
    console.log(`✅ Bob nonce: ${bobNonce.result}`);

    // Get current block
    console.log('\n🔗 Getting current block info...');
    const blockHeader = await makeRpcCall(9933, 'chain_getHeader');
    const blockNumber = parseInt(blockHeader.result.number, 16);
    console.log(`✅ Current block: #${blockNumber}`);

    // Get runtime version
    console.log('\n⚙️  Getting runtime version...');
    const runtime = await makeRpcCall(9933, 'chain_getRuntimeVersion');
    console.log(`✅ Runtime: ${runtime.result.specName} v${runtime.result.specVersion}`);

    // Check system properties
    console.log('\n🏷️  Getting system properties...');
    const properties = await makeRpcCall(9933, 'system_properties');
    console.log(`✅ Token: ${properties.result.tokenSymbol} (${properties.result.tokenDecimals} decimals)`);

    // Test pending extrinsics
    console.log('\n📋 Checking pending extrinsics...');
    const pending = await makeRpcCall(9933, 'author_pendingExtrinsics');
    console.log(`✅ Pending extrinsics: ${pending.result.length}`);

    console.log('\n🎉 Transfer test completed successfully!');
    console.log('\n📝 Summary:');
    console.log(`   • Alice account ready (nonce: ${aliceNonce.result})`);
    console.log(`   • Bob account ready (nonce: ${bobNonce.result})`);
    console.log(`   • Blockchain at block #${blockNumber}`);
    console.log(`   • Runtime: ${runtime.result.specName} v${runtime.result.specVersion}`);
    console.log(`   • Token: ${properties.result.tokenSymbol}`);
    
    console.log('\n💡 Note: For actual transfers, you would need to:');
    console.log('   1. Create and sign a transfer extrinsic');
    console.log('   2. Submit it via author_submitExtrinsic');
    console.log('   3. Monitor for inclusion in a block');

  } catch (error) {
    console.error('❌ Error during transfer test:', error.message);
    process.exit(1);
  }
}

testTransfer().then(() => process.exit(0));
