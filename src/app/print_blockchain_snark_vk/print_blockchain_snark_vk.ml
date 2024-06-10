open Core_kernel

module Config = struct
  let constraint_constants = Genesis_constants.Constraint_constants.compiled

  let proof_level = Genesis_constants.Proof_level.Full
end

let () = Format.eprintf "Generating transaction snark circuit..@."

let before = Time.now ()

module Transaction_snark_instance = Transaction_snark.Make (Config)

let after = Time.now ()

let () =
  Format.eprintf "Generated transaction snark circuit in %s.@."
    (Time.Span.to_string_hum (Time.diff after before))

let () = Format.eprintf "Generating blockchain snark circuit..@."

let before = Time.now ()

module Blockchain_snark_instance =
Blockchain_snark.Blockchain_snark_state.Make (struct
  let tag = Transaction_snark_instance.tag

  include Config
end)

let after = Time.now ()

let () =
  Format.eprintf "Generated blockchain snark circuit in %s.@."
    (Time.Span.to_string_hum (Time.diff after before))

let () =
  Lazy.force Blockchain_snark_instance.Proof.verification_key
  |> Pickles.Verification_key.to_yojson |> Yojson.Safe.to_string
  |> Format.print_string
