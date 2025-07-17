#!/bin/bash

# Simple cleanup script for the poly-eval pipeline
# This script removes all generated files to simulate a fresh clone state

set -euo pipefail

# Colors for output
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
readonly CONVERTED_DIR="$BLOBSTREAM_DIR/poly_eval_converted"

# Cleanup function
cleanup_generated_files() {
    log_info "Cleaning up generated files..."
    
    # Remove Rust build artifacts
    if [[ -d "$SCRIPT_DIR/target" ]]; then
        log_info "Removing Rust build artifacts..."
        rm -rf "$SCRIPT_DIR/target"
    fi
    
    # Remove generated files from poly_eval benchmark
    local generated_files=("proof.json" "public.json" "vk.json" "circuit_final.zkey" "circuit_0000.zkey" "witness.wtns" "circuit.sym" "circuit.r1cs" "circuit_js" "circuit_cpp" "pot*_final.ptau" "*.wasm")
    if [[ -d "$BENCHMARK_DIR" ]]; then
        cd "$BENCHMARK_DIR"
        for file in "${generated_files[@]}"; do
            if [[ -e "$file" ]]; then
                log_info "Removing $file"
                rm -rf "$file"
            fi
        done
        cd - > /dev/null
    fi
    
    # Remove converted files
    if [[ -d "$CONVERTED_DIR" ]]; then
        log_info "Removing converted files..."
        rm -rf "$CONVERTED_DIR"/*
    fi
    
    # Remove blobstream build artifacts
    if [[ -d "$BLOBSTREAM_DIR/contracts/build" ]]; then
        log_info "Removing blobstream build artifacts..."
        rm -rf "$BLOBSTREAM_DIR/contracts/build"
    fi
    
    if [[ -d "$BLOBSTREAM_DIR/contracts/node_modules" ]]; then
        log_info "Removing blobstream node_modules..."
        rm -rf "$BLOBSTREAM_DIR/contracts/node_modules"
    fi
    
    # Remove blobstream work directories and files
    log_info "Cleaning up blobstream work directories..."
    if [[ -d "$BLOBSTREAM_DIR/scripts" ]]; then
        cd "$BLOBSTREAM_DIR/scripts"
        
        # Remove work directories (poly_eval, etc.)
        for dir in */; do
            if [[ -d "$dir" && "$dir" != "blobstream_example/" && "$dir" != "risc_zero_example/" ]]; then
                log_info "Removing work directory: $dir"
                rm -rf "$dir"
            fi
        done
        
        # Remove specific files (but preserve important env files)
        local blobstream_files=("mlo.json" "aux_wtns.json")
        for file in "${blobstream_files[@]}"; do
            if [[ -f "$file" ]]; then
                log_info "Removing $file"
                rm -f "$file"
            fi
        done
        
        cd - > /dev/null
    fi
    
    # Remove any remaining generated files in blobstream
    if [[ -d "$BLOBSTREAM_DIR" ]]; then
        cd "$BLOBSTREAM_DIR"
        
        # Remove any generated proof directories
        find . -name "proofs" -type d -exec rm -rf {} + 2>/dev/null || true
        find . -name "vks" -type d -exec rm -rf {} + 2>/dev/null || true
        find . -name "cache" -type d -exec rm -rf {} + 2>/dev/null || true
        
        # Remove any generated files (but preserve env files)
        find . -name "mlo.json" -type f -delete 2>/dev/null || true
        find . -name "aux_wtns.json" -type f -delete 2>/dev/null || true
        
        cd - > /dev/null
    fi
    
    # Remove any temporary files in the root
    log_info "Cleaning up temporary files..."
    cd "$SCRIPT_DIR"
    
    # Remove any temporary files that might have been created
    local temp_files=("*.tmp" "*.log" "*.cache")
    for pattern in "${temp_files[@]}"; do
        for file in $pattern; do
            if [[ -f "$file" ]]; then
                log_info "Removing temporary file: $file"
                rm -f "$file"
            fi
        done
    done
    
    log_success "Cleanup completed!"
    echo ""
    echo "📋 Cleaned up:"
    echo "   - Rust build artifacts (target/)"
    echo "   - Generated circuit files (proof.json, public.json, vk.json, etc.)"
    echo "   - Circuit generation artifacts (circuit_js/, circuit_cpp/, *.wasm)"
    echo "   - Temporary circuit files (circuit_0000.zkey, pot*_final.ptau)"
    echo "   - Converted files (poly_eval_converted/)"
    echo "   - Blobstream build artifacts (build/, node_modules/)"
    echo "   - Blobstream work directories and files (mlo.json, aux_wtns.json, etc.)"
    echo "   - All generated proof directories (proofs/, vks/, cache/)"
    echo "   - Generated environment files (env.generated*)"
    echo "   - Temporary files (*.tmp, *.log, *.cache)"
    echo "   - package-lock.json (preserved for dependency consistency)"
    echo ""
    echo "🎉 Repository is now in a completely fresh state!"
}

# Main execution
main() {
    log_info "Starting repository cleanup..."
    cleanup_generated_files
}

# Run main function
main "$@" 