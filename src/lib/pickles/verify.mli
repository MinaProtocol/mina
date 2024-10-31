open Core_kernel

(** This module aims to define a simple type alias for passing heteregenous
    statements and proofs to a verification routine *)
module Instance : sig
  (** Chunking related information, see
  [RFC-0002](https://github.com/o1-labs/rfcs/blob/main/0002-chunking.md) *)
  type chunking_data = { num_chunks : int; domain_size : int; zk_rows : int }

  (** Type wrapper to embed different type of proofs in a heterogenous list *)
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

(** [verify ?chunking_data N ST_V vk proofs] verifies a list of homogeneous (i.e.
    same form) proofs given in the list [proofs] with their corresponding
    statement.

    The two type parameters of the type proof are the width and the height,
    which are constrained by the parameter [N] (type-level natural) to be the
    same.
*)
val verify :
     ?chunking_data:Instance.chunking_data
  -> (module Pickles_types.Nat.Intf with type n = 'n)
  -> (module Intf.Statement_value with type t = 'a)
  -> Verification_key.t
     (* The verification key to be used for this list of statements *)
  -> ('a * ('n, 'n) Proof.t) list
     (* proofs with their corresponding statement of type 'a *)
  -> unit Or_error.t Promise.t

(** [verify_heterogenous instances] verifies a list of proofs that can be
    related to different circuits/statements.

    A verification consists of the following:
    - verifies the chunking configuration given in parameter repects the one
      used while making the proofs.
    - feature flags (saved in the deffered values of the proof state) are
      consistent with the given evaluations.
    - the domain size are consistent
    - [...]
*)
val verify_heterogenous : Instance.t list -> unit Or_error.t Promise.t
