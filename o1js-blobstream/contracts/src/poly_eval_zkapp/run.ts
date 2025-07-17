import { AccountUpdate, Mina, PrivateKey, Cache, verify } from 'o1js';
import { PolyEvalZkApp, polyEvalVerifier } from './poly_eval_verifier.js';
import { NodeProofLeft } from '../structs.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

async function main() {
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = path.dirname(__filename);
  const workDir = path.resolve(__dirname, '../../poly_eval_converted/flow');
  process.env.POLY_EVAL_WORK_DIR = workDir;

  console.log('🔧 Compiling polyEvalVerifier ZkProgram...');
  const vk = (
    await polyEvalVerifier.compile({ cache: Cache.FileSystemDefault })
  ).verificationKey;

  console.log('🔑 Verification Key Hash:', vk.hash.toString());

  console.log('🔧 Compiling PolyEvalZkApp...');
  await PolyEvalZkApp.compile();

  console.log('🚀 Setting up local blockchain...');
  // proofsEnabled = true
  const LOCAL = await Mina.LocalBlockchain({ proofsEnabled: true });
  Mina.setActiveInstance(LOCAL);

  const deployerAccount = LOCAL.testAccounts[0];
  const senderAccount = LOCAL.testAccounts[1];
  const deployerKey = deployerAccount.key;
  const senderKey = senderAccount.key;

  const zkAppPrivateKey = PrivateKey.random();
  const zkAppAddress = zkAppPrivateKey.toPublicKey();
  const zkApp = new PolyEvalZkApp(zkAppAddress);

  console.log('📦 Deploying PolyEvalZkApp...');
  console.log('zkApp address:', zkAppAddress.toBase58());

  const txn = await Mina.transaction(
    { sender: deployerAccount, fee: 2e9 },
    async () => {
      AccountUpdate.fundNewAccount(deployerAccount, 1);
      await zkApp.deploy();
    }
  );

  await txn.prove();
  await txn.sign([deployerKey, zkAppPrivateKey]).send();

  console.log('✅ PolyEvalZkApp deployed successfully!');

  console.log('\n📊 Initial zkApp state:');
  console.log(
    '   - publicOutput0:',
    (await zkApp.publicOutput0.get()).toString()
  );
  console.log(
    '   - publicOutput1:',
    (await zkApp.publicOutput1.get()).toString()
  );
  console.log(
    '   - publicOutput2:',
    (await zkApp.publicOutput2.get()).toString()
  );

  console.log('\n📄 Loading proof from layer4 p0.json...');
  const proofPath = path.resolve(workDir, 'proofs/layer4/p0.json');

  if (!fs.existsSync(proofPath)) {
    console.log('❌ Proof file not found. Available files in proofs/layer4/:');
    const layer4Dir = path.resolve(workDir, 'proofs/layer4');
    if (fs.existsSync(layer4Dir)) {
      const files = fs.readdirSync(layer4Dir);
      files.forEach((file) => console.log(`   - ${file}`));
    }
    return;
  }

  const rawProof = await NodeProofLeft.fromJSON(
    JSON.parse(fs.readFileSync(proofPath, 'utf8'))
  );

  console.log('✅ Proof loaded successfully!');
  console.log('   Raw proof public outputs:');
  console.log('   - leftIn:', rawProof.publicOutput.leftIn.toString());
  console.log('   - rightOut:', rawProof.publicOutput.rightOut.toString());
  console.log(
    '   - subtreeVkDigest:',
    rawProof.publicOutput.subtreeVkDigest.toString()
  );

  console.log('\n🔐 Computing proof using polyEvalVerifier...');
  const proof = await polyEvalVerifier.verify(rawProof);

  console.log('✅ Proof computed successfully!');
  console.log('   Processed public outputs:');
  console.log(
    '   - publicOutput0:',
    proof.publicOutput.publicOutput0.toString()
  );
  console.log(
    '   - publicOutput1:',
    proof.publicOutput.publicOutput1.toString()
  );
  console.log(
    '   - publicOutput2:',
    proof.publicOutput.publicOutput2.toString()
  );

  // For testing
  console.log('\n🔍 Verifying proof manually...');
  const valid = await verify(proof, vk);
  console.log('✅ Proof verified manually:', valid);

  console.log('\n📝 Updating zkApp state...');
  const txn1 = await Mina.transaction(senderAccount, async () => {
    await zkApp.verifyProof(proof, vk);
  });
  await txn1.prove();
  await txn1.sign([senderKey]).send();

  console.log('✅ zkApp state updated successfully!');

  console.log('\n📊 Final zkApp state:');
  console.log(
    '   - publicOutput0:',
    (await zkApp.publicOutput0.get()).toString()
  );
  console.log(
    '   - publicOutput1:',
    (await zkApp.publicOutput1.get()).toString()
  );
  console.log(
    '   - publicOutput2:',
    (await zkApp.publicOutput2.get()).toString()
  );

  console.log('\n🎉 zkApp verification completed successfully!');
}

main().catch(console.error);
