# Example Circuit Files

This directory contains example Groth16 proof files from the icicle-snark benchmark (sum_check circuit).

## Files

- `circuit.circom` - The sum_check Circom circuit
- `proof.json` - Groth16 proof in icicle-snark/snarkjs format
- `verification_key.json` - Verification key in icicle-snark format
- `public.json` - Public inputs (5 inputs that sum to 100)

## Circuit Description

The sum_check circuit validates that 5 public inputs sum to exactly 100:
- Inputs: `a = 20, b = 25, c = 15, d = 30, e = 10`
- Constraint: `a + b + c + d + e === 100`
- Public inputs: 5 (all input values)
- Private inputs: 0
- Constraints: 3 (sum calculation + 2 dummy constraints)

-----

## Usage with Conversion Script

To convert these files to o1js-blobstream format:

```bash
cd o1js-blobstream
node convert_icicle_to_o1js_groth16.js
```

The conversion script will:
1. Read the files from `../example_circuit/`
2. Convert them to o1js-blobstream format (pi1-pi5, ic0-ic5)
3. Output converted files to `converted_circuit/`

## Generated Files

After conversion, you'll have:
- `converted_circuit/proof.json` - o1js-blobstream format proof with pi1-pi5 fields
- `converted_circuit/vk.json` - o1js-blobstream format verification key with ic0-ic5 fields