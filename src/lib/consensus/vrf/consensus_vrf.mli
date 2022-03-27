module Scalar : sig
  type t = Snark_params.Tick.Inner_curve.Scalar.t

  type value = t

  type var = Snark_params.Tick.Inner_curve.Scalar.var

  val to_string : value -> string

  val of_string : string -> value

  val to_yojson : value -> [> `String of string ]

  val of_yojson : [> `String of string ] -> (value, string) Core_kernel.Result.t

  val typ : (var, value) Snark_params.Tick.Typ.t
end

module Group : sig
  type t = Snark_params.Tick.Inner_curve.t

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson :
       Yojson.Safe.t
    -> (Marlin_plonk_bindings.Pasta_pallas.t, string) Core_kernel.Result.t

  val to_string_list_exn : t -> string list

  val of_string_list_exn : string list -> Marlin_plonk_bindings.Pasta_pallas.t

  type value = t

  type var = Snark_params.Tick.Inner_curve.var

  val scale : value -> Pasta__Basic.Fq.t -> value

  val typ :
    ( Snark_params.Tick.Inner_curve.Checked.t
    , Crypto_params.Tick.Inner_curve.t )
    Snark_params.Tick.Fq.Impl.Typ.t

  val generator : value

  val add : value -> value -> value

  val negate : value -> value

  val to_affine_exn :
       Marlin_plonk_bindings.Pasta_pallas.t
    -> Pasta__Basic.Fp.t * Pasta__Basic.Fp.t

  val of_affine :
       Pasta__Basic.Fp.t * Pasta__Basic.Fp.t
    -> Marlin_plonk_bindings.Pasta_pallas.t

  module Checked : sig
    type t = Snark_params.Tick.Fq.t * Snark_params.Tick.Fq.t

    val typ :
      (t, Crypto_params.Tick.Inner_curve.t) Snark_params.Tick.Fq.Impl.Typ.t

    module Shifted = Snark_params.Tick.Inner_curve.Checked.Shifted

    val negate : t -> t

    val constant : Crypto_params.Tick.Inner_curve.t -> t

    val add_unsafe :
         t
      -> t
      -> ( [ `I_thought_about_this_very_carefully of t ]
         , 'a )
         Snark_params.Tick.Fq.Impl.Checked.t

    val if_ :
         Snark_params.Tick.Fq.Impl.Boolean.var
      -> then_:t
      -> else_:t
      -> (t, 'a) Snark_params.Tick.Fq.Impl.Checked.t

    val double : t -> (t, 'a) Snark_params.Tick.Fq.Impl.Checked.t

    val if_value :
         Snark_params.Tick.Fq.Impl.Boolean.var
      -> then_:Crypto_params.Tick.Inner_curve.t
      -> else_:Crypto_params.Tick.Inner_curve.t
      -> t

    val scale :
         's Snark_params.Tick.Inner_curve.Checked.Shifted.m
      -> t
      -> Snark_params.Tick.Fq.Impl.Boolean.var
         Bitstring_lib.Bitstring.Lsb_first.t
      -> init:'s
      -> ('s, 'a) Snark_params.Tick.Fq.Impl.Checked.t

    val scale_known :
         's Snark_params.Tick.Inner_curve.Checked.Shifted.m
      -> Crypto_params.Tick.Inner_curve.t
      -> Snark_params.Tick.Fq.Impl.Boolean.var
         Bitstring_lib.Bitstring.Lsb_first.t
      -> init:'s
      -> ('s, 'a) Snark_params.Tick.Fq.Impl.Checked.t

    val sum :
         's Snark_params.Tick.Inner_curve.Checked.Shifted.m
      -> t list
      -> init:'s
      -> ('s, 'a) Snark_params.Tick.Fq.Impl.Checked.t

    module Assert = Snark_params.Tick.Inner_curve.Checked.Assert

    val add_known_unsafe :
         t
      -> Crypto_params.Tick.Inner_curve.t
      -> ( [ `I_thought_about_this_very_carefully of t ]
         , 'a )
         Snark_params.Tick.Fq.Impl.Checked.t

    val scale_generator :
         'a Snark_params.Tick.Inner_curve.Checked.Shifted.m
      -> Snark_params.Tick.Fq.Impl.Boolean.var
         Bitstring_lib.Bitstring.Lsb_first.t
      -> init:'a
      -> ('a, 'b) Snark_params.Tick.Fq.Impl.Checked.t
  end
end

module Message : sig
  module Global_slot = Mina_numbers.Global_slot

  type ('global_slot, 'epoch_seed, 'delegator) t =
    { global_slot : 'global_slot; seed : 'epoch_seed; delegator : 'delegator }

  val t_of_sexp :
       (Ppx_sexp_conv_lib.Sexp.t -> 'global_slot)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'epoch_seed)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'delegator)
    -> Ppx_sexp_conv_lib.Sexp.t
    -> ('global_slot, 'epoch_seed, 'delegator) t

  val sexp_of_t :
       ('global_slot -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('epoch_seed -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('delegator -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('global_slot, 'epoch_seed, 'delegator) t
    -> Ppx_sexp_conv_lib.Sexp.t

  val to_hlist :
       ('global_slot, 'epoch_seed, 'delegator) t
    -> (unit, 'global_slot -> 'epoch_seed -> 'delegator -> unit) H_list.t

  val of_hlist :
       (unit, 'global_slot -> 'epoch_seed -> 'delegator -> unit) H_list.t
    -> ('global_slot, 'epoch_seed, 'delegator) t

  type value =
    ( Mina_numbers.Global_slot.t
    , Mina_base.Epoch_seed.t
    , Mina_base.Account.Index.t )
    t

  val value_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> value

  val sexp_of_value : value -> Ppx_sexp_conv_lib.Sexp.t

  type var =
    ( Mina_numbers.Global_slot.Checked.t
    , Mina_base.Epoch_seed.var
    , Mina_base.Account.Index.Unpacked.var )
    t

  val to_input :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> value
    -> (Snark_params.Tick.field, bool) Random_oracle.Input.t

  val data_spec :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> ( 'a
       , 'b
       ,    Mina_numbers.Global_slot.Checked.t
         -> Mina_base.Epoch_seed.var
         -> Mina_base.Account.Index.Unpacked.var
         -> 'a
       ,    Mina_numbers.Global_slot.t
         -> Mina_base.Epoch_seed.t
         -> Mina_base.Account.Index.Unpacked.value
         -> 'b
       , Pickles__Impls.Step.Impl.Internal_Basic.Field.t
       , (unit, unit) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t )
       Snark_params.Tick.Data_spec.data_spec

  val typ :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> (var, value) Snark_params.Tick.Typ.t

  val hash_to_group :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> value
    -> Marlin_plonk_bindings.Pasta_pallas.t

  module Checked : sig
    val to_input :
         var
      -> ( ( Random_oracle.Checked.Digest.t
           , Snark_params.Tick.Boolean.var )
           Random_oracle.Input.t
         , 'a )
         Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

    val hash_to_group :
         var
      -> ( Snark_params.Tick.Run.field Snarky_backendless.Cvar.t
           * Snark_params.Tick.Run.field Snarky_backendless.Cvar.t
         , 'a )
         Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
  end

  val gen :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> (Mina_numbers.Global_slot.t, Mina_base.Epoch_seed.t, Core_kernel.Int.t) t
       Core_kernel__Quickcheck.Generator.t
end

val c : [> `Two_to_the of int ]

val c_bias : 'a list -> 'a list

module Output : sig
  module Truncated : sig
    module Stable : sig
      module V1 : sig
        type t = string

        val version : int

        val __versioned__ : unit

        val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

        val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

        val equal : t -> t -> bool

        val compare : t -> t -> int

        val hash_fold_t :
          Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

        val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

        val to_yojson : t -> [> `String of t ]

        val of_yojson : [> `String of t ] -> (t, t) Core_kernel.Result.t

        val to_latest : 'a -> 'a

        module With_version : sig
          type typ = t

          val bin_shape_typ : Core_kernel.Bin_prot.Shape.t

          val bin_size_typ : typ Core_kernel.Bin_prot.Size.sizer

          val bin_write_typ : typ Core_kernel.Bin_prot.Write.writer

          val bin_writer_typ : typ Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_typ__ : (int -> typ) Core_kernel.Bin_prot.Read.reader

          val bin_read_typ : typ Core_kernel.Bin_prot.Read.reader

          val bin_reader_typ : typ Core_kernel.Bin_prot.Type_class.reader

          val bin_typ : typ Core_kernel.Bin_prot.Type_class.t

          type t = { version : int; t : typ }

          val bin_shape_t : Core_kernel.Bin_prot.Shape.t

          val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

          val bin_write_t : t Core_kernel.Bin_prot.Write.writer

          val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_t__ : (int -> t) Core_kernel.Bin_prot.Read.reader

          val bin_read_t : t Core_kernel.Bin_prot.Read.reader

          val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

          val bin_t : t Core_kernel.Bin_prot.Type_class.t

          val create : typ -> t
        end

        val bin_read_t :
          Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t

        val __bin_read_t__ :
          Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> int -> t

        val bin_size_t : t -> int

        val bin_write_t :
             Bin_prot.Common.buf
          -> pos:Bin_prot.Common.pos
          -> t
          -> Bin_prot.Common.pos

        val bin_shape_t : Core_kernel.Bin_prot.Shape.t

        val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

        val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

        val bin_t : t Core_kernel.Bin_prot.Type_class.t

        val __ :
          (Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t)
          * (Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> int -> t)
          * (t -> int)
          * (   Bin_prot.Common.buf
             -> pos:Bin_prot.Common.pos
             -> t
             -> Bin_prot.Common.pos)
          * Core_kernel.Bin_prot.Shape.t
          * t Core_kernel.Bin_prot.Type_class.reader
          * t Core_kernel.Bin_prot.Type_class.writer
          * t Core_kernel.Bin_prot.Type_class.t
      end

      module Latest = V1

      val versions :
        (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t))
        array

      val bin_read_to_latest_opt :
           Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
        -> V1.t option

      val __ :
           Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
        -> V1.t option
    end

    type t = Stable.V1.t

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

    val equal : t -> t -> bool

    val compare : t -> t -> int

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

    module Base58_check : sig
      val encode : t -> t

      val decode_exn : t -> t

      val decode : t -> t Core_kernel.Or_error.t
    end

    val to_base58_check : t -> t

    val of_base58_check : t -> t Base__Or_error.t

    val of_base58_check_exn : t -> t

    val to_yojson : t -> [> `String of t ]

    val of_yojson : Yojson.Safe.t -> (t, t) Core_kernel.Result.t

    val length_in_bits : Core_kernel.Int.t

    type var = Snark_params.Tick.Boolean.var array

    val typ : (var, t) Snark_params.Tick.Typ.t

    val dummy : t

    val to_bits : t -> bool list

    val to_fraction : t -> Bignum.t
  end

  val typ :
    ( Snark_params.Tick.Field.Var.t
    , Snark_params.Tick.Field.t )
    Pickles__Impls.Step.Impl.Internal_Basic.Typ.t

  val gen : Snark_params.Tick.Field.t Core_kernel.Quickcheck.Generator.t

  val truncate : Random_oracle.Digest.t -> Truncated.t

  val hash :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> Message.value
    -> Marlin_plonk_bindings.Pasta_pallas.t
    -> Random_oracle.Digest.t

  module Checked : sig
    val truncate :
         Random_oracle.Checked.Digest.t
      -> ( Pickles.Impls.Step.Internal_Basic.Boolean.var Core_kernel.Array.t
         , 'a )
         Snark_params.Tick.Checked.t

    val hash :
         Message.var
      -> Random_oracle.Checked.Digest.t * Random_oracle.Checked.Digest.t
      -> ( Random_oracle.Checked.Digest.t
         , 'a )
         Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
  end
end

module Threshold : sig
  val f : Bignum.t

  val base : Bignum.t

  val params : Snarky_taylor.Params.t

  val bigint_of_uint64 : Unsigned.UInt64.t -> Bigint.t

  val is_satisfied :
       my_stake:Currency.Balance.Stable.Latest.t
    -> total_stake:Currency.Amount.Stable.Latest.t
    -> Output.Truncated.t
    -> bool

  module Checked : sig
    val is_satisfied :
         my_stake:Currency.Balance.var
      -> total_stake:Currency.Amount.var
      -> Output.Truncated.var
      -> ( Snark_params.Tick.Run.field Snarky_backendless.Cvar.t
           Snarky_backendless.Boolean.t
         , 'a )
         Snark_params.Tick.Checked.t
  end
end

module Evaluation_hash : sig
  val hash_for_proof :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> Message.value
    -> Marlin_plonk_bindings.Pasta_pallas.t
    -> Marlin_plonk_bindings.Pasta_pallas.t
    -> Marlin_plonk_bindings.Pasta_pallas.t
    -> Scalar.value

  module Checked : sig
    val hash_for_proof :
         Message.var
      -> Random_oracle.Checked.Digest.t * Random_oracle.Checked.Digest.t
      -> Random_oracle.Checked.Digest.t * Random_oracle.Checked.Digest.t
      -> Random_oracle.Checked.Digest.t * Random_oracle.Checked.Digest.t
      -> ( Pickles__Impls.Step.Impl.Internal_Basic.Boolean.var
           Bitstring_lib.Bitstring.Lsb_first.t
         , 'a )
         Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
  end
end

module Output_hash : sig
  module Stable : sig
    module V1 : sig
      module T : sig
        type t = Snark_params.Tick.Field.t

        val bin_shape_t : Core_kernel.Bin_prot.Shape.t

        val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t : t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ : (int -> t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t : t Core_kernel.Bin_prot.Read.reader

        val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

        val bin_t : t Core_kernel.Bin_prot.Type_class.t

        val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

        val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

        val compare : t -> t -> int

        val hash_fold_t :
          Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

        val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

        val version : int

        val __ : int

        val __versioned__ : unit
      end

      type t = T.t

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val compare : t -> t -> int

      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

      val version : int

      val __versioned__ : unit

      val to_latest : 'a -> 'a

      module With_version : sig
        type typ = t

        val bin_shape_typ : Core_kernel.Bin_prot.Shape.t

        val bin_size_typ : typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ : typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ : typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ : (int -> typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ : typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ : typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ : typ Core_kernel.Bin_prot.Type_class.t

        type t = { version : int; t : typ }

        val bin_shape_t : Core_kernel.Bin_prot.Shape.t

        val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t : t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ : (int -> t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t : t Core_kernel.Bin_prot.Read.reader

        val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

        val bin_t : t Core_kernel.Bin_prot.Type_class.t

        val create : typ -> t
      end

      val bin_read_t :
        Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t

      val __bin_read_t__ :
        Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> int -> t

      val bin_size_t : t -> int

      val bin_write_t :
           Bin_prot.Common.buf
        -> pos:Bin_prot.Common.pos
        -> t
        -> Bin_prot.Common.pos

      val bin_shape_t : Core_kernel.Bin_prot.Shape.t

      val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

      val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

      val bin_t : t Core_kernel.Bin_prot.Type_class.t

      val __ :
        (Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t)
        * (Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> int -> t)
        * (t -> int)
        * (   Bin_prot.Common.buf
           -> pos:Bin_prot.Common.pos
           -> t
           -> Bin_prot.Common.pos)
        * Core_kernel.Bin_prot.Shape.t
        * t Core_kernel.Bin_prot.Type_class.reader
        * t Core_kernel.Bin_prot.Type_class.writer
        * t Core_kernel.Bin_prot.Type_class.t
    end

    module Latest = V1

    val versions :
      (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t))
      array

    val bin_read_to_latest_opt :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> V1.t option

    val __ :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> V1.t option
  end

  type t = Stable.V1.t

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val compare : t -> t -> int

  type var = Random_oracle.Checked.Digest.t

  val hash :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> Message.value
    -> Marlin_plonk_bindings.Pasta_pallas.t
    -> Random_oracle.Digest.t

  module Checked : sig
    val hash :
         Message.var
      -> var * var
      -> (var, 'a) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
  end
end

module Integrated : sig
  val eval :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> private_key:Scalar.value
    -> Message.value
    -> Output_hash.t

  module Checked : sig
    val eval :
         'shifted Snark_params.Tick.Inner_curve.Checked.Shifted.m
      -> private_key:Scalar.var
      -> Message.var
      -> (Output_hash.var, 'a) Snark_params.Tick.Checked.t

    val eval_and_check_public_key :
         'shifted Snark_params.Tick.Inner_curve.Checked.Shifted.m
      -> private_key:Scalar.var
      -> public_key:Group.var
      -> Message.var
      -> (Output_hash.var, 'a) Snark_params.Tick.Checked.t
  end
end

module Standalone : functor
  (Constraint_constants : sig
     val constraint_constants : Genesis_constants.Constraint_constants.t
   end)
  -> sig
  module Public_key : sig
    type t = Group.value

    type var = Group.var
  end

  module Private_key : sig
    type t = Scalar.value

    type var = Scalar.var
  end

  module Context : sig
    type t =
      ( ( Unsigned_extended.UInt32.t
        , Mina_base.Epoch_seed.t
        , Mina_base.Account.Index.t )
        Message.t
      , Public_key.t )
      Vrf_lib__Standalone.Context.t

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    type var =
      ( ( Mina_numbers__Global_slot.Checked.var
        , Mina_base.Epoch_seed.var
        , Mina_base.Account.Index.Unpacked.var )
        Message.t
      , Public_key.var )
      Vrf_lib__Standalone.Context.t

    val typ : (var, t) Snark_params.Tick.Typ.t
  end

  module Evaluation : sig
    type t =
      ( Public_key.t
      , Scalar.value Vrf_lib__Standalone.Evaluation.Discrete_log_equality.Poly.t
      )
      Vrf_lib__Standalone.Evaluation.Poly.t

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    type var

    val typ : (var, t) Snark_params.Tick.Typ.t

    val create :
         Scalar.value
      -> ( Unsigned_extended.UInt32.t
         , Mina_base.Epoch_seed.t
         , Mina_base.Account.Index.t )
         Message.t
      -> t

    val verified_output : t -> Context.t -> Output_hash.t option

    module Checked : sig
      val verified_output :
           (module Group.Checked.Shifted.S with type t = 'shifted)
        -> var
        -> Context.var
        -> (Output_hash.var, 'a) Snark_params.Tick.Checked.t
    end
  end
end

type evaluation =
  ( Marlin_plonk_bindings_pasta_pallas.t
  , Marlin_plonk_bindings_pasta_fq.t
    Vrf_lib.Standalone.Evaluation.Discrete_log_equality.Poly.t )
  Vrf_lib.Standalone.Evaluation.Poly.t

type context =
  ( (Unsigned.uint32, Marlin_plonk_bindings_pasta_fp.t, int) Message.t
  , Marlin_plonk_bindings_pasta_pallas.t )
  Vrf_lib.Standalone.Context.t

module Layout : sig
  module Message : sig
    type t =
      { global_slot : Mina_numbers.Global_slot.t
      ; epoch_seed : Mina_base.Epoch_seed.t
      ; delegator_index : int
      }

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val to_message : t -> Message.value

    val of_message : Message.value -> t
  end

  module Threshold : sig
    type t =
      { delegated_stake : Currency.Balance.t; total_stake : Currency.Amount.t }

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val is_satisfied : Output.Truncated.t -> t -> bool
  end

  module Evaluation : sig
    type t =
      { message : Message.t
      ; public_key : Signature_lib.Public_key.t
      ; c : Scalar.value
      ; s : Scalar.value
      ; scaled_message_hash : Group.value
      ; vrf_threshold : Threshold.t option
      ; vrf_output : Output.Truncated.t option
      ; vrf_output_fractional : float option
      ; threshold_met : bool option
      }

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val to_evaluation_and_context : t -> evaluation * context

    val of_evaluation_and_context : evaluation * context -> t

    val of_message_and_sk :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> Message.t
      -> Signature_lib.Private_key.t
      -> t

    val to_vrf :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> t
      -> Output_hash.t option

    val compute_vrf :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> ?delegated_stake:Currency.Balance.t
      -> ?total_stake:Currency.Amount.t
      -> t
      -> t
  end
end
