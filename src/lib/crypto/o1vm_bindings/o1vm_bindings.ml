type proof

external create_proof : unit -> proof = "create_proof"

external verify_proof : proof -> bool = "verify_proof"

let proof = create_proof ()

let is_valid = verify_proof proof
