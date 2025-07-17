#!/bin/bash

# Poly-eval pipeline: icicle-snark -> o1js-blobstream conversion -> proof verification
# This script demonstrates the complete flow from icicle-snark to generating proofs using o1js-blobstream and verifying in a simple zkApp.

set -e

echo "Starting poly-eval pipeline..."

# Ensure required scripts have execute permissions
echo "🔧 Setting up script permissions..."
chmod +x icicle-snark/scripts/setup.sh
chmod +x o1js-blobstream/scripts/*.sh

# Step 1a: Set up poly_eval benchmark and generate necessary files
echo "📦 Step 1a: Setting up poly_eval benchmark..."
cd icicle-snark/benchmark/poly_eval

# Check if input files exist
if [ ! -f "circuit.circom" ] || [ ! -f "input.json" ]; then
    echo "❌ Error: circuit.circom or input.json not found in poly_eval directory"
    exit 1
fi

echo "✅ Found poly_eval circuit files"

# Run setup script to generate circuit files
echo "🔧 Running setup script to generate circuit files..."
../../scripts/setup.sh

# Verify that circuit files were generated
if [ ! -f "circuit_final.zkey" ] || [ ! -f "witness.wtns" ] || [ ! -f "verification_key.json" ]; then
    echo "❌ Error: setup script failed to generate required circuit files"
    exit 1
fi

echo "✅ Generated circuit files: circuit_final.zkey, witness.wtns, verification_key.json"

# Step 1b: Build icicle-snark and generate proof using the Rust example (examples/rust/src/main.rs)
echo "🔐 Step 1b: Building icicle-snark and generating proof..."

# Run the proof generation using cargo run
echo "🔄 Generating proof..."
cd ../../examples/rust
cargo run --release

# Verify proof was generated
cd ../../benchmark/poly_eval
if [ ! -f "proof.json" ] || [ ! -f "public.json" ]; then
    echo "❌ Error: Rust example failed to generate proof.json and public.json"
    exit 1
fi

# Rename verification_key.json to vk.json for consistency
echo "🔄 Renaming verification_key.json to vk.json..."
mv verification_key.json vk.json

echo "✅ Generated all required files: proof.json, public.json, vk.json"

# Step 2: Build and run the format conversion tool
echo "🦀 Step 2: Building and running the format conversion tool..."
cd ../../..

# Build the format conversion tool
echo "🔨 Building the format conversion tool..."
cargo build --release

# Create output directory if it doesn't exist
mkdir -p o1js-blobstream/poly_eval_converted/flow

# Run the conversion
echo "🔄 Converting snarkjs files to o1js-blobstream format..."
./target/release/snarkjs_to_o1jsblobstream \
    icicle-snark/benchmark/poly_eval/proof.json \
    icicle-snark/benchmark/poly_eval/public.json \
    icicle-snark/benchmark/poly_eval/vk.json \
    o1js-blobstream/poly_eval_converted/proof.json \
    o1js-blobstream/poly_eval_converted/vk.json
echo "✅ Format conversion completed"

# Step 3: Set up environment and run o1js-blobstream pipeline
echo "🔧 Step 3: Setting up o1js-blobstream environment..."
cd o1js-blobstream

# Source the environment file
source scripts/env.poly_eval

# Verify converted files exist (check relative to o1js-blobstream directory)
if [ ! -f "poly_eval_converted/proof.json" ] || [ ! -f "poly_eval_converted/vk.json" ]; then
    echo "❌ Error: Converted proof or VK files not found"
    exit 1
fi

echo "✅ Found converted files:"
echo "   Proof: poly_eval_converted/proof.json"
echo "   VK: poly_eval_converted/vk.json"

# Step 4: Run the o1js-blobstream pipeline
echo "🎯 Step 4: Running o1js-blobstream pipeline..."

# Build the contracts if needed
if [ ! -d "contracts/build" ]; then
    echo "📦 Building contracts..."
    cd contracts
    npm install
    npm run build
    cd ..
fi

# # Step 4a: Get aux witness
# echo "🔍 Step 4a: Getting aux witness..."
# ./scripts/get_aux_witness_groth16.sh scripts/env.poly_eval

# # Step 4b: Run groth16_tree for recursion
# echo "🌳 Step 4b: Running groth16_tree..."
# ./scripts/groth16_tree.sh scripts/env.poly_eval

echo "🛡️  Step 5: Running zkApp verification..."
cd contracts
node build/src/poly_eval_zkapp/run.js
cd ..

echo "🎉 Pipeline completed successfully!"
echo ""
echo "📁 Output files:"
echo "   - Converted proof: $PROOF_PATH"
echo "   - Converted VK: $VK_PATH"
echo "   - Generated proofs in: $WORK_DIR"
echo ""
echo "You can now verify the proofs!"