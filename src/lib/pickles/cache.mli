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

  type 'header storable =
    ('header, Backend.Tick.Keypair.t) Key_cache.Sync.Disk_storable.t

  type 'header vk_storable =
    ( 'header
    , Kimchi_bindings.Protocol.VerifierIndex.Fp.t )
    Key_cache.Sync.Disk_storable.t

  val storable : Key.Proving.t storable

  val vk_storable : Key.Verification.t vk_storable

  val read_or_generate :
       prev_challenges:int
    -> Key_cache.Spec.t list
    -> 'pk_header lazy_t * 'pk_header storable
    -> 'vk_header lazy_t * 'vk_header vk_storable
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

  type 'header storable =
    ('header, Backend.Tock.Keypair.t) Key_cache.Sync.Disk_storable.t

  type 'header vk_storable =
    ('header, Verification_key.t) Key_cache.Sync.Disk_storable.t

  val storable : Key.Proving.t storable

  val vk_storable : Key.Verification.t vk_storable

  val read_or_generate :
       prev_challenges:Core_kernel.Int.t
    -> Key_cache.Spec.t list
    -> 'pk_header lazy_t * 'pk_header storable
    -> 'vk_header lazy_t * 'vk_header vk_storable
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

module Spec : sig
  type ('step_pk_header, 'step_vk_header, 'wrap_pk_header, 'wrap_vk_header) t =
    { cache : Key_cache.Spec.t list
    ; step_storable : 'step_pk_header Step.storable
    ; step_vk_storable : 'step_vk_header Step.vk_storable
    ; wrap_storable : 'wrap_pk_header Wrap.storable
    ; wrap_vk_storable : 'wrap_vk_header Wrap.vk_storable
    }

  val default :
    ( Step.Key.Proving.t
    , Step.Key.Verification.t
    , Wrap.Key.Proving.t
    , Wrap.Key.Verification.t )
    t
end