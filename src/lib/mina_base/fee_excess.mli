module Poly : sig
  module Stable : sig
    module V1 : sig
      type ('token, 'fee) t =
        { fee_token_l : 'token
        ; fee_excess_l : 'fee
        ; fee_token_r : 'token
        ; fee_excess_r : 'fee
        }

      val version : int

      val __versioned__ : unit

      val compare :
           ('token -> 'token -> int)
        -> ('fee -> 'fee -> int)
        -> ('token, 'fee) t
        -> ('token, 'fee) t
        -> int

      val equal :
           ('token -> 'token -> bool)
        -> ('fee -> 'fee -> bool)
        -> ('token, 'fee) t
        -> ('token, 'fee) t
        -> bool

      val hash_fold_t :
           (Ppx_hash_lib.Std.Hash.state -> 'token -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'fee -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('token, 'fee) t
        -> Ppx_hash_lib.Std.Hash.state

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'token)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'fee)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('token, 'fee) t

      val sexp_of_t :
           ('token -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('fee -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('token, 'fee) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val to_hlist :
           ('token, 'fee) t
        -> (unit, 'token -> 'fee -> 'token -> 'fee -> unit) H_list.t

      val of_hlist :
           (unit, 'token -> 'fee -> 'token -> 'fee -> unit) H_list.t
        -> ('token, 'fee) t

      val to_yojson :
           ('a -> 'b)
        -> ('c -> 'b)
        -> ('a, 'c) t
        -> [> `List of [> `Assoc of (string * 'b) list ] list ]

      val of_yojson :
           ('a -> ('b, string) Core_kernel__Result.t)
        -> ('a -> ('c, string) Core_kernel__Result.t)
        -> [> `List of [> `Assoc of (string * 'a) list ] list ]
        -> (('b, 'c) t, string) Core_kernel__Result.t

      module With_version : sig
        type ('token, 'fee) typ = ('token, 'fee) t

        val bin_shape_typ :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_typ :
             'token Core_kernel.Bin_prot.Size.sizer
          -> 'fee Core_kernel.Bin_prot.Size.sizer
          -> ('token, 'fee) typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ :
             'token Core_kernel.Bin_prot.Write.writer
          -> 'fee Core_kernel.Bin_prot.Write.writer
          -> ('token, 'fee) typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
             'token Core_kernel.Bin_prot.Read.reader
          -> 'fee Core_kernel.Bin_prot.Read.reader
          -> (int -> ('token, 'fee) typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ :
             'token Core_kernel.Bin_prot.Read.reader
          -> 'fee Core_kernel.Bin_prot.Read.reader
          -> ('token, 'fee) typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.t

        type ('token, 'fee) t = { version : int; t : ('token, 'fee) typ }

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'token Core_kernel.Bin_prot.Size.sizer
          -> 'fee Core_kernel.Bin_prot.Size.sizer
          -> ('token, 'fee) t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'token Core_kernel.Bin_prot.Write.writer
          -> 'fee Core_kernel.Bin_prot.Write.writer
          -> ('token, 'fee) t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ :
             'token Core_kernel.Bin_prot.Read.reader
          -> 'fee Core_kernel.Bin_prot.Read.reader
          -> (int -> ('token, 'fee) t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t :
             'token Core_kernel.Bin_prot.Read.reader
          -> 'fee Core_kernel.Bin_prot.Read.reader
          -> ('token, 'fee) t Core_kernel.Bin_prot.Read.reader

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

  type ('token, 'fee) t = ('token, 'fee) Stable.V1.t =
    { fee_token_l : 'token
    ; fee_excess_l : 'fee
    ; fee_token_r : 'token
    ; fee_excess_r : 'fee
    }

  val compare :
       ('token -> 'token -> int)
    -> ('fee -> 'fee -> int)
    -> ('token, 'fee) t
    -> ('token, 'fee) t
    -> int

  val equal :
       ('token -> 'token -> bool)
    -> ('fee -> 'fee -> bool)
    -> ('token, 'fee) t
    -> ('token, 'fee) t
    -> bool

  val hash_fold_t :
       (Ppx_hash_lib.Std.Hash.state -> 'token -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'fee -> Ppx_hash_lib.Std.Hash.state)
    -> Ppx_hash_lib.Std.Hash.state
    -> ('token, 'fee) t
    -> Ppx_hash_lib.Std.Hash.state

  val t_of_sexp :
       (Ppx_sexp_conv_lib.Sexp.t -> 'token)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'fee)
    -> Ppx_sexp_conv_lib.Sexp.t
    -> ('token, 'fee) t

  val sexp_of_t :
       ('token -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('fee -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('token, 'fee) t
    -> Ppx_sexp_conv_lib.Sexp.t

  val to_hlist :
       ('token, 'fee) t
    -> (unit, 'token -> 'fee -> 'token -> 'fee -> unit) H_list.t

  val of_hlist :
       (unit, 'token -> 'fee -> 'token -> 'fee -> unit) H_list.t
    -> ('token, 'fee) t

  val to_yojson :
       ('a -> 'b)
    -> ('c -> 'b)
    -> ('a, 'c) t
    -> [> `List of [> `Assoc of (string * 'b) list ] list ]

  val of_yojson :
       ('a -> ('b, string) Core_kernel__Result.t)
    -> ('a -> ('c, string) Core_kernel__Result.t)
    -> [> `List of [> `Assoc of (string * 'a) list ] list ]
    -> (('b, 'c) t, string) Core_kernel__Result.t

  val typ :
       ('token_var, 'token) Snark_params.Tick.Typ.t
    -> ('fee_var, 'fee) Snark_params.Tick.Typ.t
    -> (('token_var, 'fee_var) t, ('token, 'fee) t) Snark_params.Tick.Typ.t
end

module Stable : sig
  module V1 : sig
    type t =
      ( Token_id.Stable.V1.t
      , ( Currency.Fee.Stable.V1.t
        , Sgn.Stable.V1.t )
        Currency.Signed_poly.Stable.V1.t )
      Poly.t

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val version : int

    val __versioned__ : unit

    val compare : t -> t -> int

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

    val bin_read_t : Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t

    val __bin_read_t__ :
      Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> int -> t

    val bin_size_t : t -> int

    val bin_write_t :
      Bin_prot.Common.buf -> pos:Bin_prot.Common.pos -> t -> Bin_prot.Common.pos

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
    (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t))
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

val compare : t -> t -> int

val equal : t -> t -> bool

val hash_fold_t :
  Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

type ('token, 'fee) poly = ('token, 'fee) Poly.t =
  { fee_token_l : 'token
  ; fee_excess_l : 'fee
  ; fee_token_r : 'token
  ; fee_excess_r : 'fee
  }

val compare_poly :
     ('token -> 'token -> int)
  -> ('fee -> 'fee -> int)
  -> ('token, 'fee) poly
  -> ('token, 'fee) poly
  -> int

val equal_poly :
     ('token -> 'token -> bool)
  -> ('fee -> 'fee -> bool)
  -> ('token, 'fee) poly
  -> ('token, 'fee) poly
  -> bool

val hash_fold_poly :
     (Ppx_hash_lib.Std.Hash.state -> 'token -> Ppx_hash_lib.Std.Hash.state)
  -> (Ppx_hash_lib.Std.Hash.state -> 'fee -> Ppx_hash_lib.Std.Hash.state)
  -> Ppx_hash_lib.Std.Hash.state
  -> ('token, 'fee) poly
  -> Ppx_hash_lib.Std.Hash.state

val poly_of_sexp :
     (Ppx_sexp_conv_lib.Sexp.t -> 'token)
  -> (Ppx_sexp_conv_lib.Sexp.t -> 'fee)
  -> Ppx_sexp_conv_lib.Sexp.t
  -> ('token, 'fee) poly

val sexp_of_poly :
     ('token -> Ppx_sexp_conv_lib.Sexp.t)
  -> ('fee -> Ppx_sexp_conv_lib.Sexp.t)
  -> ('token, 'fee) poly
  -> Ppx_sexp_conv_lib.Sexp.t

val poly_to_yojson :
     ('a -> 'b)
  -> ('c -> 'b)
  -> ('a, 'c) poly
  -> [> `List of [> `Assoc of (string * 'b) list ] list ]

val poly_of_yojson :
     ('a -> ('b, string) Core_kernel__Result.t)
  -> ('a -> ('c, string) Core_kernel__Result.t)
  -> [> `List of [> `Assoc of (string * 'a) list ] list ]
  -> (('b, 'c) poly, string) Core_kernel__Result.t

type var = (Token_id.var, Currency.Fee.Signed.var) poly

val typ : (var, t) Snark_params.Tick.Typ.t

val var_of_t : t -> var

val to_input :
     (Token_id.t, Currency.Fee.Signed.t) poly
  -> (Snark_params.Tick.Field.t, bool) Random_oracle.Input.t

val to_input_checked :
     (Mina_base__Token_id.var, Currency.Fee.Signed.var) poly
  -> ( ( Snark_params.Tick.Field.Var.t
       , Snark_params.Tick.Boolean.var )
       Random_oracle.Input.t
     , 'a )
     Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

val assert_equal_checked : var -> var -> (unit, 'a) Snark_params.Tick.Checked.t

val eliminate_fee_excess :
     Token_id.t * (Currency.Fee.Stable.Latest.t, Sgn.t) Currency.Signed_poly.t
  -> Token_id.t * Currency.Fee.Signed.t
  -> Token_id.t * (Currency.Fee.Stable.Latest.t, Sgn.t) Currency.Signed_poly.t
  -> ( (Token_id.t * Currency.Fee.Signed.t)
     * ( Token_id.t
       * (Currency.Fee.Stable.Latest.t, Sgn.t) Currency.Signed_poly.t ) )
     Base__Or_error.t

val eliminate_fee_excess_checked :
     Mina_base__Token_id.var
     * Pickles__Impls.Step.Impl.Internal_Basic.Field.Var.t
  -> Mina_base__Token_id.var
     * Pickles__Impls.Step.Impl.Internal_Basic.Field.Var.t
  -> Mina_base__Token_id.var
     * Pickles__Impls.Step.Impl.Internal_Basic.Field.Var.t
  -> ( (Mina_base__Token_id.var * Snark_params.Tick.Field.Var.t)
       * (Mina_base__Token_id.var * Snark_params.Tick.Field.Var.t)
     , 'a
     , Pickles__Impls.Step.Impl.Internal_Basic.Field.t
       Snarky_backendless.Checked.field )
     Snarky_backendless.Checked.Types.Checked.t

val rebalance : t -> (Token_id.t, Currency.Fee.Signed.t) poly Base__Or_error.t

val rebalance_checked :
     ( Mina_base__Token_id.var
     , Pickles__Impls.Step.Impl.Internal_Basic.Field.Var.t )
     poly
  -> ( (Mina_base__Token_id.var, Snark_params.Tick.Field.Var.t) poly
     , 'a )
     Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

val combine :
     ( Token_id.t
     , (Currency.Fee.Stable.Latest.t, Sgn.t) Currency.Signed_poly.t )
     poly
  -> ( Token_id.t
     , (Currency.Fee.Stable.Latest.t, Sgn.t) Currency.Signed_poly.t )
     poly
  -> (Token_id.t, Currency.Fee.Signed.t) poly Base__Or_error.t

val combine_checked :
     (Mina_base__Token_id.var, Currency.Fee.Signed.var) poly
  -> (Mina_base__Token_id.var, Currency.Fee.Signed.var) poly
  -> ( (Mina_base__Token_id.var, Currency.Fee.Signed.var) poly
     , 'a
     , Pickles__Impls.Step.Impl.Internal_Basic.Field.t
       Snarky_backendless.Checked.field )
     Snarky_backendless.Checked.Types.Checked.t

val empty : (Token_id.t, Currency.Fee.Signed.t) poly

val is_empty : (Token_id.t, Currency.Fee.Signed.t) poly -> bool

val zero : (Token_id.t, Currency.Fee.Signed.t) poly

val is_zero : (Token_id.t, Currency.Fee.Signed.t) poly -> bool

val of_single :
     Token_id.Stable.V1.t
     * (Currency.Fee.t, Sgn.Stable.V1.t) Currency.Signed_poly.Stable.V1.t
  -> (Token_id.t, Currency.Fee.Signed.t) poly

val of_one_or_two :
     [< `One of Token_id.t * Currency.Fee.Signed.t
     | `Two of
       (Token_id.t * Currency.Fee.Signed.t)
       * (Token_id.t * Currency.Fee.Signed.t) ]
  -> (Token_id.t, Currency.Fee.Signed.t) poly Base__Or_error.t

val to_one_or_two :
     t
  -> [> `One of
        Token_id.Stable.V1.t
        * ( Currency.Fee.Stable.V1.t
          , Sgn.Stable.V1.t )
          Currency.Signed_poly.Stable.V1.t
     | `Two of
       ( Token_id.Stable.V1.t
       * ( Currency.Fee.Stable.V1.t
         , Sgn.Stable.V1.t )
         Currency.Signed_poly.Stable.V1.t )
       * ( Token_id.Stable.V1.t
         * ( Currency.Fee.Stable.V1.t
           , Sgn.Stable.V1.t )
           Currency.Signed_poly.Stable.V1.t ) ]

val gen :
  (Token_id.t, Currency.Fee.Signed.t) poly Core_kernel__Quickcheck.Generator.t
