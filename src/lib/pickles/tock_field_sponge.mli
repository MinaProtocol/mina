(** Implement a Sponge for the field Tock *)

include module type of Make_sponge.Make (Backend.Tock.Field)

(** Parameters for the permutation. It can be generated using the {{
    https://github.com/o1-labs/proof-systems/tree/master/poseidon } SAGE
    script} *)
val params : Backend.Tock.Field.t Sponge.Params.t
