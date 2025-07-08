use std::env;
use std::fs;
use serde::{Deserialize, Serialize};
use serde_json;
use num_bigint::BigUint;

#[derive(Deserialize, Debug)]
struct SnarkjsProof {
    pi_a: Vec<String>,
    pi_b: Vec<Vec<String>>,
    pi_c: Vec<String>,
}

#[derive(Deserialize, Debug)]
struct SnarkjsVK {
    #[serde(rename = "nPublic")]
    n_public: usize,
    vk_alpha_1: Vec<String>,
    vk_beta_2: Vec<Vec<String>>,
    vk_gamma_2: Vec<Vec<String>>,
    vk_delta_2: Vec<Vec<String>>,
    vk_alphabeta_12: Vec<Vec<Vec<String>>>,
    #[serde(rename = "IC")]
    ic: Vec<Vec<String>>,
}

#[derive(Serialize, Debug)]
struct O1jsProof {
    #[serde(rename = "negA")]
    neg_a: G1Point,
    #[serde(rename = "B")]
    b: G2Point,
    #[serde(rename = "C")]
    c: G1Point,
    pi1: String,
    pi2: String,
    pi3: String,
    pi4: String,
    pi5: String,
}

#[derive(Serialize, Debug)]
struct G1Point {
    x: String,
    y: String,
}

#[derive(Serialize, Debug)]
struct G2Point {
    x_c0: String,
    x_c1: String,
    y_c0: String,
    y_c1: String,
}

#[derive(Serialize, Debug)]
struct Fp12Element {
    g00: String, g01: String, g10: String, g11: String, g20: String, g21: String,
    h00: String, h01: String, h10: String, h11: String, h20: String, h21: String,
}

#[derive(Serialize, Debug)]
struct O1jsVK {
    alpha: G1Point,
    beta: G2Point,
    gamma: G2Point,
    delta: G2Point,
    alpha_beta: Fp12Element,
    w27: Fp12Element,
    ic0: G1Point,
    ic1: G1Point,
    ic2: G1Point,
    ic3: G1Point,
    ic4: G1Point,
    ic5: G1Point,
}

// BN254 prime for coordinate negation
const BN254_PRIME: &str = "21888242871839275222246405745257275088548364400416034343698204186575808495617";

fn negate_g1_point(point: &[String]) -> G1Point {
    let x = point[0].clone();
    let y = &point[1];
    
    // Negate the y coordinate: p - y
    let p = BigUint::parse_bytes(BN254_PRIME.as_bytes(), 10).unwrap();
    let y_val = BigUint::parse_bytes(y.as_bytes(), 10).unwrap();
    let y_negated = &p - &y_val;
    
    G1Point {
        x,
        y: y_negated.to_str_radix(10),
    }
}

fn convert_g1_point(point: &[String]) -> G1Point {
    G1Point {
        x: point[0].clone(),
        y: point[1].clone(),
    }
}

fn convert_g2_point(point: &[Vec<String>]) -> G2Point {
    G2Point {
        x_c0: point[0][0].clone(),
        x_c1: point[0][1].clone(),
        y_c0: point[1][0].clone(),
        y_c1: point[1][1].clone(),
    }
}

fn flatten_fp12(alphabeta12: &[Vec<Vec<String>>]) -> Fp12Element {
    let g = &alphabeta12[0];
    let h = &alphabeta12[1];
    
    Fp12Element {
        g00: g[0][0].clone(), g01: g[0][1].clone(),
        g10: g[1][0].clone(), g11: g[1][1].clone(),
        g20: g[2][0].clone(), g21: g[2][1].clone(),
        h00: h[0][0].clone(), h01: h[0][1].clone(),
        h10: h[1][0].clone(), h11: h[1][1].clone(),
        h20: h[2][0].clone(), h21: h[2][1].clone(),
    }
}

fn create_default_w27() -> Fp12Element {
    Fp12Element {
        g00: "0".to_string(), g01: "0".to_string(),
        g10: "0".to_string(), g11: "0".to_string(),
        g20: "8204864362109909869166472767738877274689483185363591877943943203703805152849".to_string(),
        g21: "17912368812864921115467448876996876278487602260484145953989158612875588124088".to_string(),
        h00: "0".to_string(), h01: "0".to_string(),
        h10: "0".to_string(), h11: "0".to_string(),
        h20: "0".to_string(), h21: "0".to_string(),
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    
    if args.len() != 6 {
        eprintln!("Usage: {} <proof.json> <public.json> <vk.json> <output_proof.json> <output_vk.json>", args[0]);
        eprintln!("Example: {} proof.json public.json verification_key.json ../o1js-blobstream/converted_circuit/proof.json ../o1js-blobstream/converted_circuit/vk.json", args[0]);
        std::process::exit(1);
    }
    
    let proof_path = &args[1];
    let public_path = &args[2];
    let vk_path = &args[3];
    let output_proof_path = &args[4];
    let output_vk_path = &args[5];
    
    // Read proof.json
    let proof_content = fs::read_to_string(proof_path)?;
    let snarkjs_proof: SnarkjsProof = serde_json::from_str(&proof_content)?;
    
    // Read public.json
    let public_content = fs::read_to_string(public_path)?;
    let public_inputs: Vec<String> = serde_json::from_str(&public_content)?;
    
    // Read verification_key.json
    let vk_content = fs::read_to_string(vk_path)?;
    let snarkjs_vk: SnarkjsVK = serde_json::from_str(&vk_content)?;
    
    // Validation (like JS script)
    if snarkjs_vk.n_public != public_inputs.len() {
        eprintln!("❌ VK nPublic ({}) doesn't match public inputs ({})", 
                 snarkjs_vk.n_public, public_inputs.len());
        std::process::exit(1);
    }
    
    if snarkjs_vk.ic.len() != public_inputs.len() + 1 {
        eprintln!("❌ VK IC points ({}) should be {}", 
                 snarkjs_vk.ic.len(), public_inputs.len() + 1);
        std::process::exit(1);
    }
    
    // Convert proof to o1js format
    let o1js_proof = O1jsProof {
        neg_a: negate_g1_point(&snarkjs_proof.pi_a),  // Negate pi_a here!
        b: convert_g2_point(&snarkjs_proof.pi_b),
        c: convert_g1_point(&snarkjs_proof.pi_c),
        pi1: public_inputs.get(0).unwrap_or(&"0".to_string()).clone(),
        pi2: public_inputs.get(1).unwrap_or(&"0".to_string()).clone(),
        pi3: public_inputs.get(2).unwrap_or(&"0".to_string()).clone(),
        pi4: public_inputs.get(3).unwrap_or(&"0".to_string()).clone(),
        pi5: public_inputs.get(4).unwrap_or(&"0".to_string()).clone(),
    };
    
    // Convert VK to o1js format
    let o1js_vk = O1jsVK {
        alpha: convert_g1_point(&snarkjs_vk.vk_alpha_1),
        beta: convert_g2_point(&snarkjs_vk.vk_beta_2),
        gamma: convert_g2_point(&snarkjs_vk.vk_gamma_2),
        delta: convert_g2_point(&snarkjs_vk.vk_delta_2),
        alpha_beta: flatten_fp12(&snarkjs_vk.vk_alphabeta_12),
        w27: create_default_w27(),
        ic0: convert_g1_point(&snarkjs_vk.ic[0]),
        ic1: convert_g1_point(&snarkjs_vk.ic[1]),
        ic2: convert_g1_point(&snarkjs_vk.ic[2]),
        ic3: convert_g1_point(&snarkjs_vk.ic[3]),
        ic4: convert_g1_point(&snarkjs_vk.ic[4]),
        ic5: convert_g1_point(&snarkjs_vk.ic[5]),
    };
    
    // Write outputs
    let proof_json = serde_json::to_string_pretty(&o1js_proof)?;
    let vk_json = serde_json::to_string_pretty(&o1js_vk)?;
    
    fs::write(output_proof_path, proof_json)?;
    fs::write(output_vk_path, vk_json)?;
    
    println!("✅ Successfully converted to o1js format:");
    println!("📁 Input proof: {}", proof_path);
    println!("📁 Input public: {}", public_path);
    println!("📁 Input VK: {}", vk_path);
    println!("📁 Output proof: {}", output_proof_path);
    println!("📁 Output VK: {}", output_vk_path);
    println!("🔧 Applied negation to pi_a");
    println!("🔧 Converted {} public inputs to pi1-pi5 format", public_inputs.len());
    println!("🔧 Converted {} IC points to ic0-ic5 format", snarkjs_vk.ic.len());
    
    Ok(())
} 