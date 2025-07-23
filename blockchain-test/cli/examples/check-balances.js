const { ApiPromise, WsProvider } = require('@polkadot/api');

async function checkBalances() {
  console.log('🔍 Checking Alice and Bob balances...\n');

  try {
    // Alice node connection
    console.log('📡 Connecting to Alice node (localhost:9944)...');
    const aliceProvider = new WsProvider('ws://localhost:9944');
    const aliceApi = await ApiPromise.create({ provider: aliceProvider });
    
    // Alice balance
    const aliceAccount = await aliceApi.query.system.account('5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY');
    console.log(`👩 Alice Balance: ${aliceAccount.data.free.toHuman()}`);

    // Bob node connection
    console.log('📡 Connecting to Bob node (localhost:9945)...');
    const bobProvider = new WsProvider('ws://localhost:9945');
    const bobApi = await ApiPromise.create({ provider: bobProvider });
    
    // Bob balance  
    const bobAccount = await bobApi.query.system.account('5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty');
    console.log(`👨 Bob Balance: ${bobAccount.data.free.toHuman()}`);

    await aliceApi.disconnect();
    await bobApi.disconnect();
    
    console.log('\n✅ Balance check completed successfully!');
    
  } catch (error) {
    console.error('❌ Error checking balances:', error.message);
    console.error('💡 Make sure blockchain nodes are running: docker-compose up -d');
    process.exit(1);
  }
}

checkBalances().then(() => process.exit(0));
