const fs = require('fs');
const path = require('path');

// This script converts icicle-snark/snarkjs Groth16 format to o1js-blobstream format:
// - Proof: pi_a/pi_b/pi_c → negA/B/C format (negates pi_a.y coordinate)
// - VK: Flattens nested arrays, converts IC points to ic0, ic1, ic2, ... format
// - Converts public inputs to pi1, pi2, pi3, ... format for o1js-blobstream
// - Handles variable number of public inputs dynamically
//
// USAGE:
//   node convert_icicle_to_o1js_groth16.js
//   
// INPUT: Reads from ../example_circuit/ (hardcoded)
// OUTPUT: Writes to ./converted_circuit/ (hardcoded)
//
// PIPELINE:
//   1. Convert files: node convert_icicle_to_o1js_groth16.js
//   2. Set up env file: node contracts/build/src/groth/proof_to_env.js [paths] [name]
//   3. Generate aux witness: ./scripts/get_aux_witness_groth16.sh scripts/env.[name]
//   4. Run full pipeline: ./scripts/groth16_tree.sh scripts/env.[name]

console.log('Converting circuit to o1js-blobstream format...\n');

// Load original files
const originalVK = JSON.parse(fs.readFileSync('../example_circuit/verification_key.json', 'utf8'));
const originalProof = JSON.parse(fs.readFileSync('../example_circuit/proof.json', 'utf8'));
const originalPublic = JSON.parse(fs.readFileSync('../example_circuit/public.json', 'utf8'));

console.log('Original files loaded:');
console.log(`  - VK: ${originalVK.IC.length} IC points, nPublic: ${originalVK.nPublic}`);
console.log(`  - Proof: pi_a, pi_b, pi_c`);
console.log(`  - Public: ${originalPublic.length} inputs\n`);

// Validate compatibility
if (originalVK.nPublic !== originalPublic.length) {
    throw new Error(`VK nPublic (${originalVK.nPublic}) doesn't match public inputs (${originalPublic.length})`);
}

if (originalVK.IC.length !== originalPublic.length + 1) {
    throw new Error(`VK IC points (${originalVK.IC.length}) should be ${originalPublic.length + 1}`);
}

console.log('Validation passed\n');

// BN254 prime for coordinate negation
const p = BigInt('21888242871839275222246405745257275088548364400416034343698204186575808495617');

// Convert proof
function convertProof() {
    console.log('🔄 Converting proof...');
    
    // Convert pi_a to negA (negate y coordinate)
    const negA = {
        x: originalProof.pi_a[0],
        y: (p - BigInt(originalProof.pi_a[1])).toString()
    };
    
    // Convert pi_b to B (flatten G2 point)
    const B = {
        x_c0: originalProof.pi_b[0][0],
        x_c1: originalProof.pi_b[0][1], 
        y_c0: originalProof.pi_b[1][0],
        y_c1: originalProof.pi_b[1][1]
    };
    
    // Convert pi_c to C (keep as is)
    const C = {
        x: originalProof.pi_c[0],
        y: originalProof.pi_c[1]
    };
    
    // Use actual public inputs - convert to pi1, pi2, ... format for o1js-blobstream
    const piFields = {};
    originalPublic.forEach((val, idx) => {
        piFields[`pi${idx + 1}`] = val;
    });
    
    const convertedProof = { negA, B, C, ...piFields };
    
    console.log(`negA: (${negA.x.slice(0,20)}..., ${negA.y.slice(0,20)}...)`);
    console.log(`B: G2 point with 4 coordinates`);
    console.log(`C: (${C.x.slice(0,20)}..., ${C.y.slice(0,20)}...)`);
    console.log(`pi1-pi${originalPublic.length}: ${originalPublic.length} public inputs\n`);
    
    return convertedProof;
}

// Convert VK (without alpha_beta - we add it later)
function convertVK() {
    console.log('🔄 Converting verification key...');
    
    const alpha = {
        x: originalVK.vk_alpha_1[0],
        y: originalVK.vk_alpha_1[1]
    };
    
    const beta = {
        x_c0: originalVK.vk_beta_2[0][0],
        x_c1: originalVK.vk_beta_2[0][1],
        y_c0: originalVK.vk_beta_2[1][0], 
        y_c1: originalVK.vk_beta_2[1][1]
    };
    
    const gamma = {
        x_c0: originalVK.vk_gamma_2[0][0],
        x_c1: originalVK.vk_gamma_2[0][1],
        y_c0: originalVK.vk_gamma_2[1][0],
        y_c1: originalVK.vk_gamma_2[1][1]
    };
    
    const delta = {
        x_c0: originalVK.vk_delta_2[0][0],
        x_c1: originalVK.vk_delta_2[0][1],
        y_c0: originalVK.vk_delta_2[1][0],
        y_c1: originalVK.vk_delta_2[1][1]
    };
    
    // Convert IC points to ic0, ic1, ic2, ... format for o1js-blobstream
    const icFields = {};
    originalVK.IC.forEach((point, idx) => {
        icFields[`ic${idx}`] = {
            x: point[0],
            y: point[1]
        };
    });
    
    // Convert alpha_beta from original VK's vk_alphabeta_12 format
    function flattenFp12(alphabeta12) {
        const [[g0, g1, g2], [h0, h1, h2]] = alphabeta12;
        return {
            g00: g0[0], g01: g0[1],
            g10: g1[0], g11: g1[1], 
            g20: g2[0], g21: g2[1],
            h00: h0[0], h01: h0[1],
            h10: h1[0], h11: h1[1],
            h20: h2[0], h21: h2[1]
        };
    }
    
    const alpha_beta = flattenFp12(originalVK.vk_alphabeta_12);
    
    // todo: update w27 (currently it's default value - same as `../contracts/src/groth/example_jsons/vk.json`)
    const w27 = {
        g00: "0", g01: "0", g10: "0", g11: "0",
        g20: "8204864362109909869166472767738877274689483185363591877943943203703805152849",
        g21: "17912368812864921115467448876996876278487602260484145953989158612875588124088",
        h00: "0", h01: "0", h10: "0", h11: "0", h20: "0", h21: "0"
    };
    
    const convertedVK = { alpha, beta, gamma, delta, ...icFields, alpha_beta, w27 };
    
    console.log(`alpha: (${alpha.x.slice(0,20)}..., ${alpha.y.slice(0,20)}...)`);
    console.log(`beta: G2 point`);
    console.log(`gamma: G2 point`);
    console.log(`delta: G2 point`);
    console.log(`ic0-ic${originalVK.IC.length - 1}: ${originalVK.IC.length} points`);
    console.log(`alpha_beta: Fp12 from original VK`);
    console.log(`w27: Default value\n`);
    
    return convertedVK;
}

// Output directory
const outputDir = 'converted_circuit';
if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
}

// Perform conversions
const convertedProof = convertProof();
const convertedVK = convertVK();

// Save files
fs.writeFileSync(path.join(outputDir, 'proof.json'), JSON.stringify(convertedProof, null, 2));
fs.writeFileSync(path.join(outputDir, 'vk.json'), JSON.stringify(convertedVK, null, 2));

console.log('Files saved:');
console.log(`  - ${outputDir}/proof.json`);
console.log(`  - ${outputDir}/vk.json\n`);


