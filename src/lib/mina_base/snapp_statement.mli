module Predicate = Snapp_predicate

module Poly : sig
  module Stable : sig
    module V1 : sig
      type ('predicate, 'body) t =
        { predicate : 'predicate; body1 : 'body; body2 : 'body }

      val version : int

      val __versioned__ : unit

      val to_hlist :
           ('predicate, 'body) t
        -> (unit, 'predicate -> 'body -> 'body -> unit) H_list.t

      val of_hlist :
           (unit, 'predicate -> 'body -> 'body -> unit) H_list.t
        -> ('predicate, 'body) t

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'predicate)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'body)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('predicate, 'body) t

      val sexp_of_t :
           ('predicate -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('body -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('predicate, 'body) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val to_latest : 'a -> 'a

      module With_version : sig
        type ('predicate, 'body) typ = ('predicate, 'body) t

        val bin_shape_typ :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_typ :
             'predicate Core_kernel.Bin_prot.Size.sizer
          -> 'body Core_kernel.Bin_prot.Size.sizer
          -> ('predicate, 'body) typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ :
             'predicate Core_kernel.Bin_prot.Write.writer
          -> 'body Core_kernel.Bin_prot.Write.writer
          -> ('predicate, 'body) typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
             'predicate Core_kernel.Bin_prot.Read.reader
          -> 'body Core_kernel.Bin_prot.Read.reader
          -> (int -> ('predicate, 'body) typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ :
             'predicate Core_kernel.Bin_prot.Read.reader
          -> 'body Core_kernel.Bin_prot.Read.reader
          -> ('predicate, 'body) typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.t

        type ('predicate, 'body) t =
          { version : int; t : ('predicate, 'body) typ }

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'predicate Core_kernel.Bin_prot.Size.sizer
          -> 'body Core_kernel.Bin_prot.Size.sizer
          -> ('predicate, 'body) t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'predicate Core_kernel.Bin_prot.Write.writer
          -> 'body Core_kernel.Bin_prot.Write.writer
          -> ('predicate, 'body) t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ :
             'predicate Core_kernel.Bin_prot.Read.reader
          -> 'body Core_kernel.Bin_prot.Read.reader
          -> (int -> ('predicate, 'body) t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t :
             'predicate Core_kernel.Bin_prot.Read.reader
          -> 'body Core_kernel.Bin_prot.Read.reader
          -> ('predicate, 'body) t Core_kernel.Bin_prot.Read.reader

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

  type ('predicate, 'body) t = ('predicate, 'body) Stable.V1.t =
    { predicate : 'predicate; body1 : 'body; body2 : 'body }

  val to_hlist :
       ('predicate, 'body) t
    -> (unit, 'predicate -> 'body -> 'body -> unit) H_list.t

  val of_hlist :
       (unit, 'predicate -> 'body -> 'body -> unit) H_list.t
    -> ('predicate, 'body) t

  val t_of_sexp :
       (Ppx_sexp_conv_lib.Sexp.t -> 'predicate)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'body)
    -> Ppx_sexp_conv_lib.Sexp.t
    -> ('predicate, 'body) t

  val sexp_of_t :
       ('predicate -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('body -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('predicate, 'body) t
    -> Ppx_sexp_conv_lib.Sexp.t

  val typ :
       ( unit
       , unit
       , 'a -> 'b -> 'b -> unit
       , 'c -> 'd -> 'd -> unit )
       Pickles__Impls.Step.Impl.Internal_Basic.Data_spec.t
    -> (('a, 'b) t, ('c, 'd) t) Snark_params.Tick.Typ.t
end

module Stable : sig
  module V1 : sig
    type t =
      (Snapp_predicate.Stable.V1.t, Snapp_command.Party.Body.Stable.V1.t) Poly.t

    val version : int

    val __versioned__ : unit

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

val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

module Checked : sig
  type t =
    ( ( Snapp_predicate.Checked.t
      , Pickles.Impls.Step.Field.t Core_kernel.Set_once.t )
      With_hash.t
    , ( Snapp_command.Party.Body.Checked.t
      , Pickles.Impls.Step.Field.t Core_kernel.Set_once.t )
      With_hash.t )
    Poly.t

  val to_field_elements : t -> Pickles.Impls.Step.Field.t array
end

val to_field_elements : t -> Snark_params.Tick.Field.t array

val typ : (Checked.t, t) Snark_params.Tick.Typ.t

module Complement : sig
  module One_proved : sig
    module Poly : sig
      type ('bool, 'token_id, 'fee_payer_opt, 'nonce) t =
        { second_starts_empty : 'bool
        ; second_ends_empty : 'bool
        ; token_id : 'token_id
        ; account2_nonce : 'nonce
        ; other_fee_payer_opt : 'fee_payer_opt
        }

      val to_yojson :
           ('bool -> Yojson.Safe.t)
        -> ('token_id -> Yojson.Safe.t)
        -> ('fee_payer_opt -> Yojson.Safe.t)
        -> ('nonce -> Yojson.Safe.t)
        -> ('bool, 'token_id, 'fee_payer_opt, 'nonce) t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'bool Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'token_id Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'fee_payer_opt Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'nonce Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ('bool, 'token_id, 'fee_payer_opt, 'nonce) t
           Ppx_deriving_yojson_runtime.error_or

      val to_hlist :
           ('bool, 'token_id, 'fee_payer_opt, 'nonce) t
        -> ( unit
           , 'bool -> 'bool -> 'token_id -> 'nonce -> 'fee_payer_opt -> unit )
           H_list.t

      val of_hlist :
           ( unit
           , 'bool -> 'bool -> 'token_id -> 'nonce -> 'fee_payer_opt -> unit )
           H_list.t
        -> ('bool, 'token_id, 'fee_payer_opt, 'nonce) t

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'bool)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'token_id)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'fee_payer_opt)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'nonce)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('bool, 'token_id, 'fee_payer_opt, 'nonce) t

      val sexp_of_t :
           ('bool -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('token_id -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('fee_payer_opt -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('nonce -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('bool, 'token_id, 'fee_payer_opt, 'nonce) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val equal :
           ('bool -> 'bool -> bool)
        -> ('token_id -> 'token_id -> bool)
        -> ('fee_payer_opt -> 'fee_payer_opt -> bool)
        -> ('nonce -> 'nonce -> bool)
        -> ('bool, 'token_id, 'fee_payer_opt, 'nonce) t
        -> ('bool, 'token_id, 'fee_payer_opt, 'nonce) t
        -> bool

      val hash_fold_t :
           (Ppx_hash_lib.Std.Hash.state -> 'bool -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'token_id
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'fee_payer_opt
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'nonce
            -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('bool, 'token_id, 'fee_payer_opt, 'nonce) t
        -> Ppx_hash_lib.Std.Hash.state

      val compare :
           ('bool -> 'bool -> int)
        -> ('token_id -> 'token_id -> int)
        -> ('fee_payer_opt -> 'fee_payer_opt -> int)
        -> ('nonce -> 'nonce -> int)
        -> ('bool, 'token_id, 'fee_payer_opt, 'nonce) t
        -> ('bool, 'token_id, 'fee_payer_opt, 'nonce) t
        -> int
    end

    module Checked : sig
      type t =
        ( Snark_params.Tick.Boolean.var
        , Token_id.Checked.t
        , ( Snark_params.Tick.Boolean.var
          , Other_fee_payer.Payload.Checked.t )
          Snapp_basic.Flagged_option.t
        , Mina_numbers.Account_nonce.Checked.t )
        Poly.t

      val complete :
           t
        -> one:Checked.t
        -> Snapp_command.Payload.One_proved.Digested.Checked.t
    end

    type t =
      ( bool
      , Token_id.t
      , Other_fee_payer.Payload.t option
      , Mina_numbers.Account_nonce.t )
      Poly.t

    val typ : (Checked.t, t) Snark_params.Tick.Typ.t

    val create : Snapp_command.Payload.One_proved.t -> t

    val complete :
      t -> one:Stable.Latest.t -> Snapp_command.Payload.One_proved.t
  end

  module Two_proved : sig
    module Poly : sig
      type ('token_id, 'fee_payer_opt) t =
        { token_id : 'token_id; other_fee_payer_opt : 'fee_payer_opt }

      val to_yojson :
           ('token_id -> Yojson.Safe.t)
        -> ('fee_payer_opt -> Yojson.Safe.t)
        -> ('token_id, 'fee_payer_opt) t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'token_id Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'fee_payer_opt Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ('token_id, 'fee_payer_opt) t Ppx_deriving_yojson_runtime.error_or

      val to_hlist :
           ('token_id, 'fee_payer_opt) t
        -> (unit, 'token_id -> 'fee_payer_opt -> unit) H_list.t

      val of_hlist :
           (unit, 'token_id -> 'fee_payer_opt -> unit) H_list.t
        -> ('token_id, 'fee_payer_opt) t

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'token_id)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'fee_payer_opt)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('token_id, 'fee_payer_opt) t

      val sexp_of_t :
           ('token_id -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('fee_payer_opt -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('token_id, 'fee_payer_opt) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val equal :
           ('token_id -> 'token_id -> bool)
        -> ('fee_payer_opt -> 'fee_payer_opt -> bool)
        -> ('token_id, 'fee_payer_opt) t
        -> ('token_id, 'fee_payer_opt) t
        -> bool

      val hash_fold_t :
           (   Ppx_hash_lib.Std.Hash.state
            -> 'token_id
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'fee_payer_opt
            -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('token_id, 'fee_payer_opt) t
        -> Ppx_hash_lib.Std.Hash.state

      val compare :
           ('token_id -> 'token_id -> int)
        -> ('fee_payer_opt -> 'fee_payer_opt -> int)
        -> ('token_id, 'fee_payer_opt) t
        -> ('token_id, 'fee_payer_opt) t
        -> int
    end

    type t = (Token_id.t, Other_fee_payer.Payload.t option) Poly.t

    val create : Snapp_command.Payload.Two_proved.t -> t

    module Checked : sig
      type t =
        ( Token_id.Checked.t
        , ( Snark_params.Tick.Boolean.var
          , Other_fee_payer.Payload.Checked.t )
          Snapp_basic.Flagged_option.t )
        Poly.t

      val complete :
           t
        -> one:Checked.t
        -> two:Checked.t
        -> Snapp_command.Payload.Two_proved.Digested.Checked.t
    end

    val typ : (Checked.t, t) Snark_params.Tick.Typ.t

    val complete :
         t
      -> one:Stable.Latest.t
      -> two:Stable.Latest.t
      -> Snapp_command.Payload.Two_proved.t
  end
end
