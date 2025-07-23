const { ApiPromise, WsProvider } = require('@polkadot/api');

async function checkBalances() {
  console.log('🔍 Checking Alice and Bob balances...\n');

  let aliceApi = null;
  let bobApi = null;

  try {
    // Alice node connection with timeout
    console.log('📡 Connecting to Alice node (localhost:9933)...');
    const aliceProvider = new WsProvider('ws://localhost:9933', 1000, {}, 10000); // 10s timeout
    aliceApi = await Promise.race([
      ApiPromise.create({ provider: aliceProvider }),
      new Promise((_, reject) => setTimeout(() => reject(new Error('Alice connection timeout')), 15000))
    ]);
    console.log('✅ Connected to Alice node');
    
    // Alice balance
    console.log('🔍 Querying Alice balance...');
    const aliceAccount = await aliceApi.query.system.account('5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY');
    console.log(`👩 Alice Balance: ${aliceAccount.data.free.toHuman()}`);
    console.log(`   Free: ${aliceAccount.data.free.toString()}`);
    console.log(`   Reserved: ${aliceAccount.data.reserved.toString()}`);
    console.log(`   Nonce: ${aliceAccount.nonce.toString()}`);

    // Bob node connection with timeout
    console.log('\n📡 Connecting to Bob node (localhost:9934)...');
    const bobProvider = new WsProvider('ws://localhost:9934', 1000, {}, 10000); // 10s timeout
    bobApi = await Promise.race([
      ApiPromise.create({ provider: bobProvider }),
      new Promise((_, reject) => setTimeout(() => reject(new Error('Bob connection timeout')), 15000))
    ]);
    console.log('✅ Connected to Bob node');
    
    // Bob balance  
    console.log('🔍 Querying Bob balance...');
    const bobAccount = await bobApi.query.system.account('5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty');
    console.log(`👨 Bob Balance: ${bobAccount.data.free.toHuman()}`);
    console.log(`   Free: ${bobAccount.data.free.toString()}`);
    console.log(`   Reserved: ${bobAccount.data.reserved.toString()}`);
    console.log(`   Nonce: ${bobAccount.nonce.toString()}`);

    // Get chain info
    console.log('\n🔗 Chain information:');
    const chainName = await aliceApi.rpc.system.chain();
    const chainVersion = await aliceApi.rpc.system.version();
    const blockNumber = await aliceApi.rpc.chain.getHeader();
    
    console.log(`   Chain: ${chainName}`);
    console.log(`   Version: ${chainVersion}`);
    console.log(`   Current Block: #${blockNumber.number.toNumber()}`);

    console.log('\n✅ Balance check completed successfully!');
    
  } catch (error) {
    console.error('❌ Error checking balances:', error.message);
    console.error('💡 Make sure blockchain nodes are running: docker-compose up -d');
    
    if (error.message.includes('timeout')) {
      console.error('💡 WebSocket connection timed out. This might be normal for the first connection.');
      console.error('💡 Try running the command again or use: npm run simple-check');
    }
    
    process.exit(1);
  } finally {
    // Cleanup connections
    if (aliceApi) {
      try {
        await aliceApi.disconnect();
        console.log('🔌 Disconnected from Alice node');
      } catch (e) {
        console.log('⚠️  Error disconnecting from Alice:', e.message);
      }
    }
    
    if (bobApi) {
      try {
        await bobApi.disconnect();
        console.log('🔌 Disconnected from Bob node');
      } catch (e) {
        console.log('⚠️  Error disconnecting from Bob:', e.message);
      }
    }
  }
}

checkBalances().then(() => process.exit(0));
