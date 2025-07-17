#!/bin/bash

# Poly-eval pipeline: icicle-snark -> o1js-blobstream conversion -> proof verification
# This script demonstrates the complete flow from icicle-snark to generating proofs using o1js-blobstream and verifying in a simple zkApp.

set -euo pipefail  # Exit on error, undefined vars, pipe failures
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ICICLE_DIR="$SCRIPT_DIR/icicle-snark"
readonly BLOBSTREAM_DIR="$SCRIPT_DIR/o1js-blobstream"
readonly BENCHMARK_DIR="$ICICLE_DIR/benchmark/poly_eval"
readonly EXAMPLES_DIR="$ICICLE_DIR/examples/rust"
readonly CONVERTED_DIR="$BLOBSTREAM_DIR/poly_eval_converted"

# File paths
readonly CIRCUIT_FILE="$BENCHMARK_DIR/circuit.circom"
readonly INPUT_FILE="$BENCHMARK_DIR/input.json"
readonly PROOF_FILE="$BENCHMARK_DIR/proof.json"
readonly PUBLIC_FILE="$BENCHMARK_DIR/public.json"
readonly VK_FILE="$BENCHMARK_DIR/vk.json"
readonly CONVERTED_PROOF="$CONVERTED_DIR/proof.json"
readonly CONVERTED_VK="$CONVERTED_DIR/vk.json"

# Usage function
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --cleanup    Clean up all generated files before running pipeline"
    echo "  --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run the full pipeline"
    echo "  $0 --cleanup          # Clean up first, then run pipeline"
    echo "  $0 --help             # Show this help"
}

# Error handling
trap 'log_error "Error on line $LINENO"' ERR

# Validation functions
check_file_exists() {
    local file="$1"
    local description="$2"
    if [[ ! -f "$file" ]]; then
        log_error "$description not found: $file"
        exit 1
    fi
}

check_directory_exists() {
    local dir="$1"
    local description="$2"
    if [[ ! -d "$dir" ]]; then
        log_error "$description not found: $dir"
        exit 1
    fi
}

# Cleanup function - calls the dedicated clean script
cleanup_generated_files() {
    log_info "Running cleanup script..."
    "$SCRIPT_DIR/clean.sh"
}

# Parse command line arguments
CLEANUP_FIRST=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --cleanup)
            CLEANUP_FIRST=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log_info "Starting poly-eval pipeline..."
    
    # Cleanup if requested
    if [[ "$CLEANUP_FIRST" == true ]]; then
        cleanup_generated_files
    fi
    
    # Validate required directories exist
    check_directory_exists "$ICICLE_DIR" "icicle-snark directory"
    check_directory_exists "$BLOBSTREAM_DIR" "o1js-blobstream directory"
    
    # Step 1: Setup permissions
    log_info "Setting up script permissions..."
    chmod +x "$ICICLE_DIR/scripts/setup.sh"
    chmod +x "$BLOBSTREAM_DIR/scripts/"*.sh
    
    # Step 2: Validate input files
    log_info "Validating input files..."
    check_file_exists "$CIRCUIT_FILE" "Circuit file"
    check_file_exists "$INPUT_FILE" "Input file"
    log_success "Found poly_eval circuit files"
    
    # Step 3: Generate circuit files
    log_info "Generating circuit files..."
    cd "$BENCHMARK_DIR"
    ../../scripts/setup.sh
    
    # Verify generated files
    local required_files=("circuit_final.zkey" "witness.wtns" "verification_key.json")
    for file in "${required_files[@]}"; do
        check_file_exists "$file" "Generated circuit file"
    done
    log_success "Generated circuit files"
    
    # Step 4: Generate proof
    log_info "Generating proof..."
    cd "$EXAMPLES_DIR"
    cargo run --release
    
    # Verify proof files
    cd "$BENCHMARK_DIR"
    check_file_exists "$PROOF_FILE" "Proof file"
    check_file_exists "$PUBLIC_FILE" "Public file"
    
    # Rename verification key for consistency
    log_info "Renaming verification_key.json to vk.json..."
    mv verification_key.json vk.json
    log_success "Generated all required files"
    
    # Step 5: Build conversion tool
    log_info "Building format conversion tool..."
    cd "$SCRIPT_DIR"
    cargo build --release
    
    # Create output directory
    mkdir -p "$CONVERTED_DIR/flow"
    
    # Step 6: Convert format
    log_info "Converting snarkjs files to o1js-blobstream format..."
    ./target/release/snarkjs_to_o1jsblobstream \
        "$PROOF_FILE" \
        "$PUBLIC_FILE" \
        "$VK_FILE" \
        "$CONVERTED_PROOF" \
        "$CONVERTED_VK"
    log_success "Format conversion completed"
    
    # Step 7: Setup blobstream environment
    log_info "Setting up o1js-blobstream environment..."
    cd "$BLOBSTREAM_DIR"
    
    # Source environment file
    if [[ -f "scripts/env.poly_eval" ]]; then
        source scripts/env.poly_eval
    else
        log_warning "Environment file not found: scripts/env.poly_eval"
    fi
    
    # Verify converted files
    check_file_exists "$CONVERTED_PROOF" "Converted proof file"
    check_file_exists "$CONVERTED_VK" "Converted VK file"
    log_success "Found converted files"
    
    # Step 8: Build contracts if needed
    log_info "Building contracts..."
    if [[ ! -d "contracts/build" ]]; then
        cd contracts
        npm install
        npm run build
        cd ..
    else
        log_info "Contracts already built"
    fi
    
    # Step 9a: Get aux witness
    log_info "Getting aux witness..."
    ./scripts/get_aux_witness_groth16.sh scripts/env.poly_eval
    
    # Step 9b: Run groth16_tree for recursion
    log_info "Running groth16_tree for recursion..."
    ./scripts/groth16_tree.sh scripts/env.poly_eval
    
    # Step 10: Run verification
    log_info "Running zkApp verification..."
    cd contracts
    node build/src/poly_eval_zkapp/run.js
    cd ..
    
    # Final success message
    log_success "Pipeline completed successfully!"
    echo ""
    echo "📁 Output files:"
    echo "   - Converted proof: $CONVERTED_PROOF"
    echo "   - Converted VK: $CONVERTED_VK"
    if [[ -n "${WORK_DIR:-}" ]]; then
        echo "   - Generated proofs in: $WORK_DIR"
    fi
    echo ""
    echo "You can now verify the proofs!"
}

<<<<<<< HEAD
# Run main function
main "$@"
=======
# Step 4a: Get aux witness
echo "🔍 Step 4a: Getting aux witness..."
./scripts/get_aux_witness_groth16.sh scripts/env.poly_eval

# Step 4b: Run groth16_tree for recursion
echo "🌳 Step 4b: Running groth16_tree..."
./scripts/groth16_tree.sh scripts/env.poly_eval

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
>>>>>>> c4086fafce6339087dce5f78698687e44482c176
