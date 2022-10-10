(* Undocumented *)

module Instance : sig
  type t =
    | T :
        (module Pickles_types.Nat.Intf with type n = 'n)
        * (module Intf.Statement_value with type t = 'a)
        * Verification_key.t
        * 'a
        * ('n, 'n) Proof.t
        -> t
end

val verify :
     (module Pickles_types.Nat.Intf with type n = 'n)
  -> (module Intf.Statement_value with type t = 'a)
  -> Verification_key.t
  -> ('a * ('n, 'n) Proof.t) list
  -> bool Promise.t

val verify_heterogenous : Instance.t list -> bool Promise.t
