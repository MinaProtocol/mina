(** Implement a Sponge for the field Bn254 *)

include module type of Make_sponge.Make (Backend.Bn254.Field)

(** Parameters for the permutation. It can be generated using the {{
    https://github.com/o1-labs/proof-systems/tree/master/poseidon } SAGE
    script} *)
val params : Backend.Bn254.Field.t Sponge.Params.t
