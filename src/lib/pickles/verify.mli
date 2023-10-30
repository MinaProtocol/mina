open Core_kernel

module Instance : sig
  type chunking_data = { num_chunks : int; domain_size : int; zk_rows : int }

  type t =
    | T :
        (module Pickles_types.Nat.Intf with type n = 'n)
        * (module Intf.Statement_value with type t = 'a)
        * chunking_data option
        * Verification_key.t
        * 'a
        * ('n, 'n) Proof.t
        -> t
end

val verify :
     ?chunking_data:Instance.chunking_data
  -> (module Pickles_types.Nat.Intf with type n = 'n)
  -> (module Intf.Statement_value with type t = 'a)
  -> Verification_key.t
  -> ('a * ('n, 'n) Proof.t) list
  -> unit Or_error.t Promise.t

val verify_heterogenous : Instance.t list -> unit Or_error.t Promise.t
