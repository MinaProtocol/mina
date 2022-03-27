module Poly : sig
  module Stable : sig
    module V1 : sig
      type ('slot, 'balance, 'amount) t =
        | Untimed
        | Timed of
            { initial_minimum_balance : 'balance
            ; cliff_time : 'slot
            ; cliff_amount : 'amount
            ; vesting_period : 'slot
            ; vesting_increment : 'amount
            }

      val to_yojson :
           ('slot -> Yojson.Safe.t)
        -> ('balance -> Yojson.Safe.t)
        -> ('amount -> Yojson.Safe.t)
        -> ('slot, 'balance, 'amount) t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'slot Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'balance Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'amount Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ('slot, 'balance, 'amount) t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'slot)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'balance)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'amount)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('slot, 'balance, 'amount) t

      val sexp_of_t :
           ('slot -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('balance -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('amount -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('slot, 'balance, 'amount) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val equal :
           ('slot -> 'slot -> bool)
        -> ('balance -> 'balance -> bool)
        -> ('amount -> 'amount -> bool)
        -> ('slot, 'balance, 'amount) t
        -> ('slot, 'balance, 'amount) t
        -> bool

      val hash_fold_t :
           (Ppx_hash_lib.Std.Hash.state -> 'slot -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'balance
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'amount
            -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('slot, 'balance, 'amount) t
        -> Ppx_hash_lib.Std.Hash.state

      val compare :
           ('slot -> 'slot -> int)
        -> ('balance -> 'balance -> int)
        -> ('amount -> 'amount -> int)
        -> ('slot, 'balance, 'amount) t
        -> ('slot, 'balance, 'amount) t
        -> int

      module With_version : sig
        type ('slot, 'balance, 'amount) typ = ('slot, 'balance, 'amount) t

        val bin_shape_typ :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_typ :
             'slot Core_kernel.Bin_prot.Size.sizer
          -> 'balance Core_kernel.Bin_prot.Size.sizer
          -> 'amount Core_kernel.Bin_prot.Size.sizer
          -> ('slot, 'balance, 'amount) typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ :
             'slot Core_kernel.Bin_prot.Write.writer
          -> 'balance Core_kernel.Bin_prot.Write.writer
          -> 'amount Core_kernel.Bin_prot.Write.writer
          -> ('slot, 'balance, 'amount) typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c) typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
             'slot Core_kernel.Bin_prot.Read.reader
          -> 'balance Core_kernel.Bin_prot.Read.reader
          -> 'amount Core_kernel.Bin_prot.Read.reader
          -> (int -> ('slot, 'balance, 'amount) typ)
             Core_kernel.Bin_prot.Read.reader

        val bin_read_typ :
             'slot Core_kernel.Bin_prot.Read.reader
          -> 'balance Core_kernel.Bin_prot.Read.reader
          -> 'amount Core_kernel.Bin_prot.Read.reader
          -> ('slot, 'balance, 'amount) typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> 'c Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b, 'c) typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> 'c Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b, 'c) typ Core_kernel.Bin_prot.Type_class.t

        type ('slot, 'balance, 'amount) t =
          { version : int; t : ('slot, 'balance, 'amount) typ }

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'slot Core_kernel.Bin_prot.Size.sizer
          -> 'balance Core_kernel.Bin_prot.Size.sizer
          -> 'amount Core_kernel.Bin_prot.Size.sizer
          -> ('slot, 'balance, 'amount) t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'slot Core_kernel.Bin_prot.Write.writer
          -> 'balance Core_kernel.Bin_prot.Write.writer
          -> 'amount Core_kernel.Bin_prot.Write.writer
          -> ('slot, 'balance, 'amount) t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ :
             'slot Core_kernel.Bin_prot.Read.reader
          -> 'balance Core_kernel.Bin_prot.Read.reader
          -> 'amount Core_kernel.Bin_prot.Read.reader
          -> (int -> ('slot, 'balance, 'amount) t)
             Core_kernel.Bin_prot.Read.reader

        val bin_read_t :
             'slot Core_kernel.Bin_prot.Read.reader
          -> 'balance Core_kernel.Bin_prot.Read.reader
          -> 'amount Core_kernel.Bin_prot.Read.reader
          -> ('slot, 'balance, 'amount) t Core_kernel.Bin_prot.Read.reader

        val bin_reader_t :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> 'c Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.reader

        val bin_t :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> 'c Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.t

        val create : ('a, 'b, 'c) typ -> ('a, 'b, 'c) t
      end

      val bin_read_t :
           'a Core_kernel.Bin_prot.Read.reader
        -> 'b Core_kernel.Bin_prot.Read.reader
        -> 'c Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> ('a, 'b, 'c) t

      val __bin_read_t__ :
           'a Core_kernel.Bin_prot.Read.reader
        -> 'b Core_kernel.Bin_prot.Read.reader
        -> 'c Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> int
        -> ('a, 'b, 'c) t

      val bin_size_t :
           'a Core_kernel.Bin_prot.Size.sizer
        -> 'b Core_kernel.Bin_prot.Size.sizer
        -> 'c Core_kernel.Bin_prot.Size.sizer
        -> ('a, 'b, 'c) t
        -> int

      val bin_write_t :
           'a Core_kernel.Bin_prot.Write.writer
        -> 'b Core_kernel.Bin_prot.Write.writer
        -> 'c Core_kernel.Bin_prot.Write.writer
        -> Bin_prot.Common.buf
        -> pos:Bin_prot.Common.pos
        -> ('a, 'b, 'c) t
        -> Bin_prot.Common.pos

      val bin_shape_t :
           Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t

      val bin_reader_t :
           'a Core_kernel.Bin_prot.Type_class.reader
        -> 'b Core_kernel.Bin_prot.Type_class.reader
        -> 'c Core_kernel.Bin_prot.Type_class.reader
        -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.reader

      val bin_writer_t :
           'a Core_kernel.Bin_prot.Type_class.writer
        -> 'b Core_kernel.Bin_prot.Type_class.writer
        -> 'c Core_kernel.Bin_prot.Type_class.writer
        -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.writer

      val bin_t :
           'a Core_kernel.Bin_prot.Type_class.t
        -> 'b Core_kernel.Bin_prot.Type_class.t
        -> 'c Core_kernel.Bin_prot.Type_class.t
        -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.t

      val __ :
        (   'a Core_kernel.Bin_prot.Read.reader
         -> 'b Core_kernel.Bin_prot.Read.reader
         -> 'c Core_kernel.Bin_prot.Read.reader
         -> Bin_prot.Common.buf
         -> pos_ref:Bin_prot.Common.pos_ref
         -> ('a, 'b, 'c) t)
        * (   'd Core_kernel.Bin_prot.Read.reader
           -> 'e Core_kernel.Bin_prot.Read.reader
           -> 'f Core_kernel.Bin_prot.Read.reader
           -> Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> int
           -> ('d, 'e, 'f) t)
        * (   'g Core_kernel.Bin_prot.Size.sizer
           -> 'h Core_kernel.Bin_prot.Size.sizer
           -> 'i Core_kernel.Bin_prot.Size.sizer
           -> ('g, 'h, 'i) t
           -> int)
        * (   'j Core_kernel.Bin_prot.Write.writer
           -> 'k Core_kernel.Bin_prot.Write.writer
           -> 'l Core_kernel.Bin_prot.Write.writer
           -> Bin_prot.Common.buf
           -> pos:Bin_prot.Common.pos
           -> ('j, 'k, 'l) t
           -> Bin_prot.Common.pos)
        * (   Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t)
        * (   'm Core_kernel.Bin_prot.Type_class.reader
           -> 'n Core_kernel.Bin_prot.Type_class.reader
           -> 'o Core_kernel.Bin_prot.Type_class.reader
           -> ('m, 'n, 'o) t Core_kernel.Bin_prot.Type_class.reader)
        * (   'p Core_kernel.Bin_prot.Type_class.writer
           -> 'q Core_kernel.Bin_prot.Type_class.writer
           -> 'r Core_kernel.Bin_prot.Type_class.writer
           -> ('p, 'q, 'r) t Core_kernel.Bin_prot.Type_class.writer)
        * (   's Core_kernel.Bin_prot.Type_class.t
           -> 't Core_kernel.Bin_prot.Type_class.t
           -> 'u Core_kernel.Bin_prot.Type_class.t
           -> ('s, 't, 'u) t Core_kernel.Bin_prot.Type_class.t)
    end

    module Latest = V1
  end

  type ('slot, 'balance, 'amount) t = ('slot, 'balance, 'amount) Stable.V1.t =
    | Untimed
    | Timed of
        { initial_minimum_balance : 'balance
        ; cliff_time : 'slot
        ; cliff_amount : 'amount
        ; vesting_period : 'slot
        ; vesting_increment : 'amount
        }

  val to_yojson :
       ('slot -> Yojson.Safe.t)
    -> ('balance -> Yojson.Safe.t)
    -> ('amount -> Yojson.Safe.t)
    -> ('slot, 'balance, 'amount) t
    -> Yojson.Safe.t

  val of_yojson :
       (Yojson.Safe.t -> 'slot Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'balance Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'amount Ppx_deriving_yojson_runtime.error_or)
    -> Yojson.Safe.t
    -> ('slot, 'balance, 'amount) t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp :
       (Ppx_sexp_conv_lib.Sexp.t -> 'slot)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'balance)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'amount)
    -> Ppx_sexp_conv_lib.Sexp.t
    -> ('slot, 'balance, 'amount) t

  val sexp_of_t :
       ('slot -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('balance -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('amount -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('slot, 'balance, 'amount) t
    -> Ppx_sexp_conv_lib.Sexp.t

  val equal :
       ('slot -> 'slot -> bool)
    -> ('balance -> 'balance -> bool)
    -> ('amount -> 'amount -> bool)
    -> ('slot, 'balance, 'amount) t
    -> ('slot, 'balance, 'amount) t
    -> bool

  val hash_fold_t :
       (Ppx_hash_lib.Std.Hash.state -> 'slot -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'balance -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'amount -> Ppx_hash_lib.Std.Hash.state)
    -> Ppx_hash_lib.Std.Hash.state
    -> ('slot, 'balance, 'amount) t
    -> Ppx_hash_lib.Std.Hash.state

  val compare :
       ('slot -> 'slot -> int)
    -> ('balance -> 'balance -> int)
    -> ('amount -> 'amount -> int)
    -> ('slot, 'balance, 'amount) t
    -> ('slot, 'balance, 'amount) t
    -> int
end

module Stable : sig
  module V1 : sig
    type t =
      ( Mina_numbers.Global_slot.Stable.V1.t
      , Currency.Balance.Stable.V1.t
      , Currency.Amount.Stable.V1.t )
      Poly.t

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val version : int

    val __versioned__ : unit

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

    val equal : t -> t -> bool

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

    val compare : t -> t -> int

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

val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

val equal : t -> t -> bool

val hash_fold_t :
  Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

val compare : t -> t -> int

type ('slot, 'balance, 'amount) tt = ('slot, 'balance, 'amount) Poly.t =
  | Untimed
  | Timed of
      { initial_minimum_balance : 'balance
      ; cliff_time : 'slot
      ; cliff_amount : 'amount
      ; vesting_period : 'slot
      ; vesting_increment : 'amount
      }

val tt_to_yojson :
     ('slot -> Yojson.Safe.t)
  -> ('balance -> Yojson.Safe.t)
  -> ('amount -> Yojson.Safe.t)
  -> ('slot, 'balance, 'amount) tt
  -> Yojson.Safe.t

val tt_of_yojson :
     (Yojson.Safe.t -> 'slot Ppx_deriving_yojson_runtime.error_or)
  -> (Yojson.Safe.t -> 'balance Ppx_deriving_yojson_runtime.error_or)
  -> (Yojson.Safe.t -> 'amount Ppx_deriving_yojson_runtime.error_or)
  -> Yojson.Safe.t
  -> ('slot, 'balance, 'amount) tt Ppx_deriving_yojson_runtime.error_or

val tt_of_sexp :
     (Ppx_sexp_conv_lib.Sexp.t -> 'slot)
  -> (Ppx_sexp_conv_lib.Sexp.t -> 'balance)
  -> (Ppx_sexp_conv_lib.Sexp.t -> 'amount)
  -> Ppx_sexp_conv_lib.Sexp.t
  -> ('slot, 'balance, 'amount) tt

val sexp_of_tt :
     ('slot -> Ppx_sexp_conv_lib.Sexp.t)
  -> ('balance -> Ppx_sexp_conv_lib.Sexp.t)
  -> ('amount -> Ppx_sexp_conv_lib.Sexp.t)
  -> ('slot, 'balance, 'amount) tt
  -> Ppx_sexp_conv_lib.Sexp.t

val equal_tt :
     ('slot -> 'slot -> bool)
  -> ('balance -> 'balance -> bool)
  -> ('amount -> 'amount -> bool)
  -> ('slot, 'balance, 'amount) tt
  -> ('slot, 'balance, 'amount) tt
  -> bool

val hash_fold_tt :
     (Ppx_hash_lib.Std.Hash.state -> 'slot -> Ppx_hash_lib.Std.Hash.state)
  -> (Ppx_hash_lib.Std.Hash.state -> 'balance -> Ppx_hash_lib.Std.Hash.state)
  -> (Ppx_hash_lib.Std.Hash.state -> 'amount -> Ppx_hash_lib.Std.Hash.state)
  -> Ppx_hash_lib.Std.Hash.state
  -> ('slot, 'balance, 'amount) tt
  -> Ppx_hash_lib.Std.Hash.state

val compare_tt :
     ('slot -> 'slot -> int)
  -> ('balance -> 'balance -> int)
  -> ('amount -> 'amount -> int)
  -> ('slot, 'balance, 'amount) tt
  -> ('slot, 'balance, 'amount) tt
  -> int

module As_record : sig
  type ('bool, 'slot, 'balance, 'amount) t =
    { is_timed : 'bool
    ; initial_minimum_balance : 'balance
    ; cliff_time : 'slot
    ; cliff_amount : 'amount
    ; vesting_period : 'slot
    ; vesting_increment : 'amount
    }

  val to_hlist :
       ('bool, 'slot, 'balance, 'amount) t
    -> ( unit
       , 'bool -> 'balance -> 'slot -> 'amount -> 'slot -> 'amount -> unit )
       H_list.t

  val of_hlist :
       ( unit
       , 'bool -> 'balance -> 'slot -> 'amount -> 'slot -> 'amount -> unit )
       H_list.t
    -> ('bool, 'slot, 'balance, 'amount) t
end

val to_record :
     ( Mina_numbers.Global_slot.t
     , Currency.Balance.Stable.Latest.t
     , Currency.Amount.Stable.Latest.t )
     tt
  -> ( bool
     , Mina_numbers.Global_slot.t
     , Currency.Balance.Stable.Latest.t
     , Currency.Amount.Stable.Latest.t )
     As_record.t

val to_bits :
     ( Mina_numbers.Global_slot.t
     , Currency.Balance.Stable.Latest.t
     , Currency.Amount.Stable.Latest.t )
     tt
  -> bool list

type var =
  ( Snark_params.Tick.Boolean.var
  , Mina_numbers.Global_slot.Checked.var
  , Currency.Balance.var
  , Currency.Amount.var )
  As_record.t

val var_to_bits :
     ( Snark_params.Tick.Boolean.var
     , Mina_numbers.Global_slot.Checked.t
     , Currency.Balance.var
     , Currency.Amount.var )
     As_record.t
  -> Snark_params.Tick.Boolean.var Bitstring_lib.Bitstring.Lsb_first.t

val var_of_t : t -> var

val untimed_var : var

val typ : (var, t) Snark_params.Tick.Typ.t

val if_ :
     Snark_params.Tick.Boolean.var
  -> then_:var
  -> else_:var
  -> ( ( Snark_params.Tick.Boolean.var
       , Mina_numbers.Global_slot.Checked.t
       , Currency.Balance.var
       , Currency.Amount.var )
       As_record.t
     , 'a )
     Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
