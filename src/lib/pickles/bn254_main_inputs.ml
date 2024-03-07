module Impl = Impls.Bn254

open Impl

(* Debug helper to convert step circuit field element to a hex string *)
let read_step_circuit_field_element_as_hex fe =
  let prover_fe = As_prover.read Field.typ fe in
  Kimchi_backend.Bn254.Bn254_based_plonk.(
    Bigint.to_hex (Field.to_bigint prover_fe))

module Sponge = struct
  module Permutation =
    Sponge_inputs.Make
      (Impl)
      (struct
        include Bn254_field_sponge.Inputs

        let params = Bn254_field_sponge.params
      end)

  module S = Sponge.Make_debug_sponge (struct
    include Permutation
    module Circuit = Impls.Bn254

    (* Optional sponge name used in debug mode *)
    let sponge_name = "step"

    (* To enable debug mode, set environment variable [sponge_name] to "t", "1" or "true". *)
    let debug_helper_fn = read_step_circuit_field_element_as_hex
  end)

  include S

  let squeeze_field t = squeeze t

  let squeeze t = squeeze t

  let absorb t input =
    match input with
    | `Field x ->
        absorb t x
    | `Bits bs ->
        absorb t (Field.pack bs)
end

let%test_unit "sponge" =
  let module T = Make_sponge.Test (Impl) (Bn254_field_sponge.Field) (Sponge.S) in
  T.test Bn254_field_sponge.params
