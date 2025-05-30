(* Cache interfaces*)

module Step : sig
  module Key : sig
    module Proving : sig
      type t =
        Core_kernel.Type_equal.Id.Uid.t
        * Snark_keys_header.t
        * int
        * Backend.Tick.R1CS_constraint_system.t

      val to_string : t -> string
    end

    module Verification : sig
      (** id * header * index * hash *)
      type t =
        Core_kernel.Type_equal.Id.Uid.t
        * Snark_keys_header.t
        * int
        * Core_kernel.Md5.t

      val to_string : t -> string
    end
  end

  type storable =
    (Key.Proving.t, Backend.Tick.Keypair.t) Key_cache.Sync.Disk_storable.t

  type vk_storable =
    ( Key.Verification.t
    , Kimchi_bindings.Protocol.VerifierIndex.Fp.t )
    Key_cache.Sync.Disk_storable.t

  val storable : storable

  val vk_storable : vk_storable

  val read_or_generate :
       prev_challenges:int
    -> Key_cache.Spec.t list
    -> ?s_p:storable
    -> ?s_v:vk_storable
    -> ?lazy_mode:bool
    -> Key.Proving.t Promise.t Lazy.t
    -> Key.Verification.t Promise.t Lazy.t
    -> ( Impls.Step.Proving_key.t
       * ([> `Cache_hit | `Generated_something | `Locally_generated ] as 'e) )
       Promise.t
       Lazy.t
       * ( Kimchi_bindings.Protocol.VerifierIndex.Fp.t
         * ([> `Cache_hit | `Generated_something | `Locally_generated ] as 'e)
         )
         Promise.t
         Lazy.t
end

module Wrap : sig
  module Key : sig
    module Proving : sig
      type t =
        Core_kernel.Type_equal.Id.Uid.t
        * Snark_keys_header.t
        * Backend.Tock.R1CS_constraint_system.t

      val to_string : t -> string
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

  type storable =
    (Key.Proving.t, Backend.Tock.Keypair.t) Key_cache.Sync.Disk_storable.t

  type vk_storable =
    (Key.Verification.t, Verification_key.t) Key_cache.Sync.Disk_storable.t

  val storable : storable

  val vk_storable : vk_storable

  val read_or_generate :
       prev_challenges:Core_kernel.Int.t
    -> Key_cache.Spec.t list
    -> ?s_p:storable
    -> ?s_v:vk_storable
    -> ?lazy_mode:bool
    -> Key.Proving.t Promise.t Lazy.t
    -> Key.Verification.t Promise.t Lazy.t
    -> ( Impls.Wrap.Proving_key.t
       * [> `Cache_hit | `Generated_something | `Locally_generated ] )
       Promise.t
       Lazy.t
       * ( Verification_key.Stable.V2.t
         * [> `Cache_hit | `Generated_something | `Locally_generated ] )
         Promise.t
         Lazy.t
end
