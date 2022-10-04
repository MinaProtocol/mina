(* Undocumented *)

(** *)
module VerificationKey :
  Graphql_basic_scalars.Json_intf
    with type t = Pickles.Side_loaded.Verification_key.t

(** *)
module VerificationKeyHash :
  Graphql_basic_scalars.Json_intf with type t = Pickles.Backend.Tick.Field.t
