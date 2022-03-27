module T = Mina_numbers.Length
module Poly = Genesis_constants.Protocol.Poly

module Value : sig
  module Stable : sig
    module V1 : sig
      type t =
        ( Mina_numbers.Length.Stable.V1.t
        , Mina_numbers.Length.Stable.V1.t
        , Block_time.Stable.V1.t )
        Genesis_constants.Protocol.Poly.Stable.V1.t

      val compare : t -> t -> Ppx_deriving_runtime.int

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val equal : t -> t -> bool

      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

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
      ( int
      * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t) )
      array

    val bin_read_to_latest_opt :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> Latest.t option

    val __ :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> Latest.t option
  end

  type t = Stable.Latest.t

  val compare : t -> t -> Ppx_deriving_runtime.int

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val equal : t -> t -> bool

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val gen : t Core_kernel.Quickcheck.Generator.t
end

type value = Value.t

val value_of_t : Genesis_constants.Protocol.t -> value

val t_of_value : value -> Genesis_constants.Protocol.t

val to_input : value -> ('a, bool) Random_oracle.Input.t

type var =
  ( Mina_numbers.Length.Checked.t
  , Mina_numbers.Length.Checked.t
  , Block_time.Unpacked.var )
  Genesis_constants.Protocol.Poly.t

val data_spec :
  ( 'a
  , 'b
  ,    Mina_numbers.Length.Checked.t
    -> Mina_numbers.Length.Checked.t
    -> Mina_numbers.Length.Checked.t
    -> Mina_numbers.Length.Checked.t
    -> Block_time.Unpacked.var
    -> 'a
  ,    Mina_numbers__Length.t
    -> Mina_numbers__Length.t
    -> Mina_numbers__Length.t
    -> Mina_numbers__Length.t
    -> Block_time.Unpacked.value
    -> 'b
  , Pickles__Impls.Step.Impl.Internal_Basic.Field.t
  , (unit, unit) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t )
  Snark_params.Tick.Data_spec.data_spec

val typ :
  ( ( Mina_numbers.Length.Checked.t
    , Mina_numbers.Length.Checked.t
    , Block_time.Unpacked.var )
    Genesis_constants.Protocol.Poly.t
  , ( Mina_numbers__Length.t
    , Mina_numbers__Length.t
    , Block_time.Unpacked.value )
    Genesis_constants.Protocol.Poly.t )
  Snark_params.Tick.Typ.t

val var_to_input :
     var
  -> ( ('a, Snark_params.Tick.Boolean.var) Random_oracle.Input.t
     , 'b )
     Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
