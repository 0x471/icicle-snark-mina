import {
  Field,
  SmartContract,
  State,
  VerificationKey,
  method,
  state,
  ZkProgram,
  Struct,
} from 'o1js';
import { NodeProofLeft } from '../structs.js';
import fs from 'fs';

class PolyEvalPublicData extends Struct({
  publicOutput0: Field,
  publicOutput1: Field,
  publicOutput2: Field,
}) {}

const polyEvalVerifier = ZkProgram({
  name: 'PolyEvalVerifier',
  publicOutput: PolyEvalPublicData,
  methods: {
    verify: {
      privateInputs: [NodeProofLeft],
      async method(proof: NodeProofLeft) {
        const workDir = process.env.POLY_EVAL_WORK_DIR as string;
        const nodeVk = VerificationKey.fromJSON(
          JSON.parse(fs.readFileSync(`${workDir}/vks/nodeVk.json`, 'utf8'))
        );

        // Verify the recursive proof
        proof.verify(nodeVk);

        // Some other circuit logic here
        //...

        const publicData = new PolyEvalPublicData({
          publicOutput0: proof.publicOutput.leftIn,
          publicOutput1: proof.publicOutput.rightOut,
          publicOutput2: proof.publicOutput.subtreeVkDigest,
        });

        return publicData;
      },
    },
  },
});

const PolyEvalVerifierProof = ZkProgram.Proof(polyEvalVerifier);
class PolyEvalProofType extends PolyEvalVerifierProof {}

export class PolyEvalZkApp extends SmartContract {
  @state(Field) publicOutput0 = State<Field>();
  @state(Field) publicOutput1 = State<Field>();
  @state(Field) publicOutput2 = State<Field>();
  @state(Field) expectedVkHash = State<Field>();

  @method async init() {
    super.init();
    this.publicOutput0.set(Field(0));
    this.publicOutput1.set(Field(0));
    this.publicOutput2.set(Field(0));
    // Hardcoded expected verification key hash
    this.expectedVkHash.set(
      Field(
        19915821410253800393664912356335253231697181137100231330905514873944871934730n
      )
    );
  }

  @method async verifyProof(proof: PolyEvalProofType, vk: VerificationKey) {
    const storedVkHash = this.expectedVkHash.getAndRequireEquals();

    vk.hash.assertEquals(storedVkHash);
    proof.verify();

    const publicData = proof.publicOutput;
    this.publicOutput0.set(publicData.publicOutput0);
    this.publicOutput1.set(publicData.publicOutput1);
    this.publicOutput2.set(publicData.publicOutput2);
  }
}

export { polyEvalVerifier, PolyEvalVerifierProof, PolyEvalPublicData };
