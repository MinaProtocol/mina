type proof

external create_proof_vesta : unit -> proof = "create_proof_vesta"

external verify_proof_vesta : proof -> bool = "verify_proof_vesta"

let proof = create_proof_vesta ()

let is_valid = verify_proof_vesta proof
