open Core_kernel

module Instance : sig
  type chunking_data = { num_chunks : int; domain_size : int; zk_rows : int }

  type gate_overrides = { override_ffadd : Backend.Tick.Field.t Kimchi_types.Expr.t array option }

  type t =
    | T :
        (module Pickles_types.Nat.Intf with type n = 'n)
        * (module Intf.Statement_value with type t = 'a)
        * chunking_data option
        * gate_overrides
        * Verification_key.t
        * 'a
        * ('n, 'n) Proof.t
        -> t
end

val verify :
     ?chunking_data:Instance.chunking_data
  -> ?override_ffadd:Backend.Tick.Field.t Kimchi_types.Expr.t array
  -> (module Pickles_types.Nat.Intf with type n = 'n)
  -> (module Intf.Statement_value with type t = 'a)
  -> Verification_key.t
  -> ('a * ('n, 'n) Proof.t) list
  -> unit Or_error.t Promise.t

val verify_heterogenous : Instance.t list -> unit Or_error.t Promise.t
