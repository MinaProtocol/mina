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
      type t =
        Core_kernel.Type_equal.Id.Uid.t
        * Snark_keys_header.t
        * int
        * Core_kernel.Md5.t

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val to_string : t -> string
    end
  end

  val storable :
    (Key.Proving.t, Backend.Tick.Keypair.t) Key_cache.Sync.Disk_storable.t

  val vk_storable :
    ( Key.Verification.t
    , Marlin_plonk_bindings.Pasta_fp_verifier_index.t )
    Key_cache.Sync.Disk_storable.t

  val read_or_generate :
       Key_cache.Spec.t list
    -> Key.Proving.t Core_kernel.Lazy.t
    -> Key.Verification.t Core_kernel.Lazy.t
    -> ( 'a
       , 'b
       , Pickles__Impls.Step.Impl.field
       , ( unit
         , unit
         , Pickles__Impls.Step.Impl.field )
         Snarky_backendless__.Checked.t )
       Snarky_backendless__.Types.Typ.t
    -> ('a -> unit -> 'c)
    -> ( Impls.Step.Keypair.t
       * [> `Cache_hit | `Generated_something | `Locally_generated ] )
       lazy_t
       * ( Marlin_plonk_bindings.Pasta_fp_verifier_index.t
         * [> `Cache_hit | `Generated_something | `Locally_generated ] )
         lazy_t
end

module Wrap : sig
  module Key : sig
    module Verification : sig
      type t =
        Core_kernel.Type_equal.Id.Uid.t
        * Snark_keys_header.t
        * Core_kernel.Md5.t

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val equal : t -> t -> bool

      val to_string : t -> string
    end

    module Proving : sig
      type t =
        Core_kernel.Type_equal.Id.Uid.t
        * Snark_keys_header.t
        * Backend.Tock.R1CS_constraint_system.t

      val to_string : t -> string
    end
  end

  val storable :
    (Key.Proving.t, Backend.Tock.Keypair.t) Key_cache.Sync.Disk_storable.t

  val read_or_generate :
       Import.Domains.t array
    -> Key_cache.Spec.t list
    -> Key.Proving.t Core_kernel.Lazy.t
    -> Key.Verification.t Core_kernel.Lazy.t
    -> ( 'a
       , 'b
       , Pickles__Impls.Wrap_impl.field
       , ( unit
         , unit
         , Pickles__Impls.Wrap_impl.field )
         Snarky_backendless__.Checked.t )
       Snarky_backendless__.Types.Typ.t
    -> ('a -> unit -> 'c)
    -> ( Impls.Wrap.Keypair.t
       * [> `Cache_hit | `Generated_something | `Locally_generated ] )
       lazy_t
       * ( Verification_key.Stable.V1.t
         * [> `Cache_hit | `Generated_something | `Locally_generated ] )
         lazy_t
end
