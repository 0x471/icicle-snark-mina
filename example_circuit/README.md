# Example Circuit Files

This directory contains example Groth16 proof files from the icicle-snark benchmark (100k circuit).

## Files

- `circuit.circom` - The original Circom circuit (100k constraints)
- `proof.json` - Groth16 proof in icicle-snark/snarkjs format
- `verification_key.json` - Verification key in icicle-snark format
- `public.json` - Public inputs (1 input: the circuit output)

## Circuit Description

The 100k circuit computes `c = 3^(2^100000)` where:
- Input: `a = 3`
- Output: `c = 3^(2^100000)`
- Public inputs: 1 (just the output value)
- Constraints: ~100,000

-----

## Usage with Conversion Script

To convert these files to o1js-blobstream format:

```bash
cd o1js-blobstream
node convert_icicle_to_o1js_groth16.js
```

The conversion script will:
1. Read the files from `../example_circuit/`
2. Convert them to o1js-blobstream format
3. Output converted files to `converted_circuit/`

## Generated Files

After conversion, you'll have:
- `converted_circuit/proof.json` - o1js-blobstream format proof
- `converted_circuit/vk.json` - o1js-blobstream format verification key