module Poly : sig
  module Stable : sig
    module V1 : sig
      type ('ledger_hash, 'amount) t =
        { hash : 'ledger_hash; total_currency : 'amount }

      val to_yojson :
           ('ledger_hash -> Yojson.Safe.t)
        -> ('amount -> Yojson.Safe.t)
        -> ('ledger_hash, 'amount) t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'ledger_hash Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'amount Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ('ledger_hash, 'amount) t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'ledger_hash)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'amount)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('ledger_hash, 'amount) t

      val sexp_of_t :
           ('ledger_hash -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('amount -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('ledger_hash, 'amount) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val equal :
           ('ledger_hash -> 'ledger_hash -> bool)
        -> ('amount -> 'amount -> bool)
        -> ('ledger_hash, 'amount) t
        -> ('ledger_hash, 'amount) t
        -> bool

      val compare :
           ('ledger_hash -> 'ledger_hash -> int)
        -> ('amount -> 'amount -> int)
        -> ('ledger_hash, 'amount) t
        -> ('ledger_hash, 'amount) t
        -> int

      val hash_fold_t :
           (   Ppx_hash_lib.Std.Hash.state
            -> 'ledger_hash
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'amount
            -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('ledger_hash, 'amount) t
        -> Ppx_hash_lib.Std.Hash.state

      val to_hlist :
           ('ledger_hash, 'amount) t
        -> (unit, 'ledger_hash -> 'amount -> unit) H_list.t

      val of_hlist :
           (unit, 'ledger_hash -> 'amount -> unit) H_list.t
        -> ('ledger_hash, 'amount) t

      module With_version : sig
        type ('ledger_hash, 'amount) typ = ('ledger_hash, 'amount) t

        val bin_shape_typ :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_typ :
             'ledger_hash Core_kernel.Bin_prot.Size.sizer
          -> 'amount Core_kernel.Bin_prot.Size.sizer
          -> ('ledger_hash, 'amount) typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ :
             'ledger_hash Core_kernel.Bin_prot.Write.writer
          -> 'amount Core_kernel.Bin_prot.Write.writer
          -> ('ledger_hash, 'amount) typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
             'ledger_hash Core_kernel.Bin_prot.Read.reader
          -> 'amount Core_kernel.Bin_prot.Read.reader
          -> (int -> ('ledger_hash, 'amount) typ)
             Core_kernel.Bin_prot.Read.reader

        val bin_read_typ :
             'ledger_hash Core_kernel.Bin_prot.Read.reader
          -> 'amount Core_kernel.Bin_prot.Read.reader
          -> ('ledger_hash, 'amount) typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.t

        type ('ledger_hash, 'amount) t =
          { version : int; t : ('ledger_hash, 'amount) typ }

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'ledger_hash Core_kernel.Bin_prot.Size.sizer
          -> 'amount Core_kernel.Bin_prot.Size.sizer
          -> ('ledger_hash, 'amount) t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'ledger_hash Core_kernel.Bin_prot.Write.writer
          -> 'amount Core_kernel.Bin_prot.Write.writer
          -> ('ledger_hash, 'amount) t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ :
             'ledger_hash Core_kernel.Bin_prot.Read.reader
          -> 'amount Core_kernel.Bin_prot.Read.reader
          -> (int -> ('ledger_hash, 'amount) t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t :
             'ledger_hash Core_kernel.Bin_prot.Read.reader
          -> 'amount Core_kernel.Bin_prot.Read.reader
          -> ('ledger_hash, 'amount) t Core_kernel.Bin_prot.Read.reader

        val bin_reader_t :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.reader

        val bin_t :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.t

        val create : ('a, 'b) typ -> ('a, 'b) t
      end

      val bin_read_t :
           'a Core_kernel.Bin_prot.Read.reader
        -> 'b Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> ('a, 'b) t

      val __bin_read_t__ :
           'a Core_kernel.Bin_prot.Read.reader
        -> 'b Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> int
        -> ('a, 'b) t

      val bin_size_t :
           'a Core_kernel.Bin_prot.Size.sizer
        -> 'b Core_kernel.Bin_prot.Size.sizer
        -> ('a, 'b) t
        -> int

      val bin_write_t :
           'a Core_kernel.Bin_prot.Write.writer
        -> 'b Core_kernel.Bin_prot.Write.writer
        -> Bin_prot.Common.buf
        -> pos:Bin_prot.Common.pos
        -> ('a, 'b) t
        -> Bin_prot.Common.pos

      val bin_shape_t :
           Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t

      val bin_reader_t :
           'a Core_kernel.Bin_prot.Type_class.reader
        -> 'b Core_kernel.Bin_prot.Type_class.reader
        -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.reader

      val bin_writer_t :
           'a Core_kernel.Bin_prot.Type_class.writer
        -> 'b Core_kernel.Bin_prot.Type_class.writer
        -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.writer

      val bin_t :
           'a Core_kernel.Bin_prot.Type_class.t
        -> 'b Core_kernel.Bin_prot.Type_class.t
        -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.t

      val __ :
        (   'a Core_kernel.Bin_prot.Read.reader
         -> 'b Core_kernel.Bin_prot.Read.reader
         -> Bin_prot.Common.buf
         -> pos_ref:Bin_prot.Common.pos_ref
         -> ('a, 'b) t)
        * (   'c Core_kernel.Bin_prot.Read.reader
           -> 'd Core_kernel.Bin_prot.Read.reader
           -> Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> int
           -> ('c, 'd) t)
        * (   'e Core_kernel.Bin_prot.Size.sizer
           -> 'f Core_kernel.Bin_prot.Size.sizer
           -> ('e, 'f) t
           -> int)
        * (   'g Core_kernel.Bin_prot.Write.writer
           -> 'h Core_kernel.Bin_prot.Write.writer
           -> Bin_prot.Common.buf
           -> pos:Bin_prot.Common.pos
           -> ('g, 'h) t
           -> Bin_prot.Common.pos)
        * (   Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t)
        * (   'i Core_kernel.Bin_prot.Type_class.reader
           -> 'j Core_kernel.Bin_prot.Type_class.reader
           -> ('i, 'j) t Core_kernel.Bin_prot.Type_class.reader)
        * (   'k Core_kernel.Bin_prot.Type_class.writer
           -> 'l Core_kernel.Bin_prot.Type_class.writer
           -> ('k, 'l) t Core_kernel.Bin_prot.Type_class.writer)
        * (   'm Core_kernel.Bin_prot.Type_class.t
           -> 'n Core_kernel.Bin_prot.Type_class.t
           -> ('m, 'n) t Core_kernel.Bin_prot.Type_class.t)
    end

    module Latest = V1
  end

  type ('ledger_hash, 'amount) t = ('ledger_hash, 'amount) Stable.V1.t =
    { hash : 'ledger_hash; total_currency : 'amount }

  val to_yojson :
       ('ledger_hash -> Yojson.Safe.t)
    -> ('amount -> Yojson.Safe.t)
    -> ('ledger_hash, 'amount) t
    -> Yojson.Safe.t

  val of_yojson :
       (Yojson.Safe.t -> 'ledger_hash Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'amount Ppx_deriving_yojson_runtime.error_or)
    -> Yojson.Safe.t
    -> ('ledger_hash, 'amount) t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp :
       (Ppx_sexp_conv_lib.Sexp.t -> 'ledger_hash)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'amount)
    -> Ppx_sexp_conv_lib.Sexp.t
    -> ('ledger_hash, 'amount) t

  val sexp_of_t :
       ('ledger_hash -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('amount -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('ledger_hash, 'amount) t
    -> Ppx_sexp_conv_lib.Sexp.t

  val equal :
       ('ledger_hash -> 'ledger_hash -> bool)
    -> ('amount -> 'amount -> bool)
    -> ('ledger_hash, 'amount) t
    -> ('ledger_hash, 'amount) t
    -> bool

  val compare :
       ('ledger_hash -> 'ledger_hash -> int)
    -> ('amount -> 'amount -> int)
    -> ('ledger_hash, 'amount) t
    -> ('ledger_hash, 'amount) t
    -> int

  val hash_fold_t :
       (   Ppx_hash_lib.Std.Hash.state
        -> 'ledger_hash
        -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'amount -> Ppx_hash_lib.Std.Hash.state)
    -> Ppx_hash_lib.Std.Hash.state
    -> ('ledger_hash, 'amount) t
    -> Ppx_hash_lib.Std.Hash.state

  val to_hlist :
       ('ledger_hash, 'amount) t
    -> (unit, 'ledger_hash -> 'amount -> unit) H_list.t

  val of_hlist :
       (unit, 'ledger_hash -> 'amount -> unit) H_list.t
    -> ('ledger_hash, 'amount) t
end

module Value : sig
  module Stable : sig
    module V1 : sig
      type t =
        (Frozen_ledger_hash0.Stable.V1.t, Currency.Amount.Stable.V1.t) Poly.t

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val equal : t -> t -> bool

      val compare : t -> t -> int

      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

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

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val equal : t -> t -> bool

  val compare : t -> t -> int

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value
end

val to_input :
  Value.t -> (Snark_params.Tick.Field.t, bool) Random_oracle.Input.t

type var = (Frozen_ledger_hash0.var, Currency.Amount.var) Poly.t

val data_spec :
  ( 'a
  , 'b
  , Frozen_ledger_hash0.var -> Currency.Amount.var -> 'a
  , Frozen_ledger_hash0.t -> Currency.Amount.Stable.Latest.t -> 'b
  , Pickles__Impls.Step.Impl.Internal_Basic.Field.t
  , (unit, unit) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t )
  Snark_params.Tick.Data_spec.data_spec

val typ : (var, Value.t) Snark_params.Tick.Typ.t

val var_to_input :
     var
  -> ( Random_oracle.Checked.Digest.t
     , Snark_params.Tick.Boolean.var )
     Random_oracle.Input.t

val if_ :
     Snark_params.Tick.Boolean.var
  -> then_:(Frozen_ledger_hash0.var, Currency.Amount.var) Poly.t
  -> else_:(Frozen_ledger_hash0.var, Currency.Amount.var) Poly.t
  -> ( (Frozen_ledger_hash0.var, Currency.Amount.var) Poly.t
     , 'a )
     Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
