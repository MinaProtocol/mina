(* Cache interfaces*)

module Step : sig
  module Key : sig
    module Proving : sig
      type t =
        Core_kernel.Type_equal.Id.Uid.t
        * Snark_keys_header.t
        * int
        * Backend.Tick.R1CS_constraint_system.t
    end

    module Verification : sig
      (** id * header * index * hash *)
      type t =
        Core_kernel.Type_equal.Id.Uid.t
        * Snark_keys_header.t
        * int
        * Core_kernel.Md5.t
    end
  end

  val read_or_generate :
       prev_challenges:int
    -> Key_cache.Spec.t list
    -> Key.Proving.t lazy_t
    -> Key.Verification.t lazy_t
    -> ('a, 'b) Impls.Step.Typ.t
    -> ('c, 'd) Impls.Step.Typ.t
    -> ('a -> unit -> 'c)
    -> ( Impls.Step.Keypair.t
       * [> `Cache_hit | `Generated_something | `Locally_generated ] )
       lazy_t
       * ( Kimchi_bindings.Protocol.VerifierIndex.Fp.t
         * [> `Cache_hit | `Generated_something | `Locally_generated ] )
         lazy_t
end

module Wrap : sig
  module Key : sig
    module Proving : sig
      type t =
        Core_kernel.Type_equal.Id.Uid.t
        * Snark_keys_header.t
        * Backend.Tock.R1CS_constraint_system.t
    end

    module Verification : sig
      (** id * header * hash *)
      type t =
        Core_kernel.Type_equal.Id.Uid.t
        * Snark_keys_header.t
        * Core_kernel.Md5.t
      [@@deriving sexp]

      val to_string : t -> string

      val equal : t -> t -> bool
    end
  end

  val read_or_generate :
       prev_challenges:Core_kernel.Int.t
    -> Key_cache.Spec.t list
    -> Key.Proving.t Core_kernel.Lazy.t
    -> Key.Verification.t Core_kernel.Lazy.t
    -> ('a, 'b) Impls.Wrap.Typ.t
    -> ('c, 'd) Impls.Wrap.Typ.t
    -> ('a -> unit -> 'c)
    -> ( Impls.Wrap.Keypair.t
       * [> `Cache_hit | `Generated_something | `Locally_generated ] )
       lazy_t
       * ( Verification_key.Stable.V2.t
         * [> `Cache_hit | `Generated_something | `Locally_generated ] )
         lazy_t
end
