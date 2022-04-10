module A = Account
module Impl = Pickles.Impls.Step

module Closed_interval : sig
  module Stable : sig
    module V1 : sig
      type 'a t = { lower : 'a; upper : 'a }

      val to_yojson : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> 'a t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val t_of_sexp :
        (Ppx_sexp_conv_lib.Sexp.t -> 'a) -> Ppx_sexp_conv_lib.Sexp.t -> 'a t

      val sexp_of_t :
        ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

      val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

      val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int

      val hash_fold_t :
           (Ppx_hash_lib.Std.Hash.state -> 'a -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> 'a t
        -> Ppx_hash_lib.Std.Hash.state

      val to_hlist : 'a t -> (unit, 'a -> 'a -> unit) H_list.t

      val of_hlist : (unit, 'a -> 'a -> unit) H_list.t -> 'a t

      module With_version : sig
        type 'a typ = 'a t

        val bin_shape_typ :
          Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t

        val bin_size_typ :
             'a Core_kernel.Bin_prot.Size.sizer
          -> 'a typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ :
             'a Core_kernel.Bin_prot.Write.writer
          -> 'a typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'a typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
             'a Core_kernel.Bin_prot.Read.reader
          -> (int -> 'a typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'a typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'a typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'a typ Core_kernel.Bin_prot.Type_class.t

        type 'a t = { version : int; t : 'a typ }

        val bin_shape_t :
          Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'a Core_kernel.Bin_prot.Size.sizer
          -> 'a t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'a Core_kernel.Bin_prot.Write.writer
          -> 'a t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'a t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ :
             'a Core_kernel.Bin_prot.Read.reader
          -> (int -> 'a t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'a t Core_kernel.Bin_prot.Read.reader

        val bin_reader_t :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'a t Core_kernel.Bin_prot.Type_class.reader

        val bin_t :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'a t Core_kernel.Bin_prot.Type_class.t

        val create : 'a typ -> 'a t
      end

      val bin_read_t :
           'a Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> 'a t

      val __bin_read_t__ :
           'a Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> int
        -> 'a t

      val bin_size_t : 'a Core_kernel.Bin_prot.Size.sizer -> 'a t -> int

      val bin_write_t :
           'a Core_kernel.Bin_prot.Write.writer
        -> Bin_prot.Common.buf
        -> pos:Bin_prot.Common.pos
        -> 'a t
        -> Bin_prot.Common.pos

      val bin_shape_t :
        Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t

      val bin_reader_t :
           'a Core_kernel.Bin_prot.Type_class.reader
        -> 'a t Core_kernel.Bin_prot.Type_class.reader

      val bin_writer_t :
           'a Core_kernel.Bin_prot.Type_class.writer
        -> 'a t Core_kernel.Bin_prot.Type_class.writer

      val bin_t :
           'a Core_kernel.Bin_prot.Type_class.t
        -> 'a t Core_kernel.Bin_prot.Type_class.t

      val __ :
        (   'a Core_kernel.Bin_prot.Read.reader
         -> Bin_prot.Common.buf
         -> pos_ref:Bin_prot.Common.pos_ref
         -> 'a t)
        * (   'b Core_kernel.Bin_prot.Read.reader
           -> Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> int
           -> 'b t)
        * ('c Core_kernel.Bin_prot.Size.sizer -> 'c t -> int)
        * (   'd Core_kernel.Bin_prot.Write.writer
           -> Bin_prot.Common.buf
           -> pos:Bin_prot.Common.pos
           -> 'd t
           -> Bin_prot.Common.pos)
        * (Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t)
        * (   'e Core_kernel.Bin_prot.Type_class.reader
           -> 'e t Core_kernel.Bin_prot.Type_class.reader)
        * (   'f Core_kernel.Bin_prot.Type_class.writer
           -> 'f t Core_kernel.Bin_prot.Type_class.writer)
        * (   'g Core_kernel.Bin_prot.Type_class.t
           -> 'g t Core_kernel.Bin_prot.Type_class.t)
    end

    module Latest = V1
  end

  type 'a t = 'a Stable.V1.t = { lower : 'a; upper : 'a }

  val to_yojson : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t

  val of_yojson :
       (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or)
    -> Yojson.Safe.t
    -> 'a t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp :
    (Ppx_sexp_conv_lib.Sexp.t -> 'a) -> Ppx_sexp_conv_lib.Sexp.t -> 'a t

  val sexp_of_t :
    ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

  val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

  val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int

  val hash_fold_t :
       (Ppx_hash_lib.Std.Hash.state -> 'a -> Ppx_hash_lib.Std.Hash.state)
    -> Ppx_hash_lib.Std.Hash.state
    -> 'a t
    -> Ppx_hash_lib.Std.Hash.state

  val to_hlist : 'a t -> (unit, 'a -> 'a -> unit) H_list.t

  val of_hlist : (unit, 'a -> 'a -> unit) H_list.t -> 'a t

  val to_input :
       'a t
    -> f:('a -> ('b, 'c) Random_oracle_input.t)
    -> ('b, 'c) Random_oracle_input.t

  val typ :
       ( 'a
       , 'b
       , Pickles__Impls.Step.Impl.Internal_Basic.field
       , ( unit
         , unit
         , Pickles__Impls.Step.Impl.Internal_Basic.field )
         Snarky_backendless__.Checked.t )
       Snarky_backendless__.Types.Typ.t
    -> ('a t, 'b t) Snark_params.Tick.Typ.t
end

val assert_ :
  bool -> string -> (unit, Core_kernel__.Error.t) Core_kernel._result

module Numeric : sig
  module Tc : sig
    type ('var, 'a) t =
      { zero : 'a
      ; max_value : 'a
      ; compare : 'a -> 'a -> int
      ; equal : 'a -> 'a -> bool
      ; typ : ('var, 'a) Snark_params.Tick.Typ.t
      ; to_input : 'a -> (Snapp_basic.F.t, bool) Random_oracle_input.t
      ; to_input_checked :
             'var
          -> ( Snark_params.Tick.Field.Var.t
             , Snark_params.Tick.Boolean.var )
             Random_oracle_input.t
      ; lte_checked : 'var -> 'var -> Snark_params.Tick.Boolean.var
      }

    val run :
         (   'a
          -> 'b
          -> ( 'c
             , Pickles.Impls.Step.prover_state )
             Pickles.Impls.Step.Internal_Basic.Checked.t)
      -> 'a
      -> 'b
      -> 'c

    val length : (Mina_numbers.Length.Checked.var, Mina_numbers.Length.t) t

    val amount : (Currency.Amount.Checked.t, Currency.Amount.Stable.Latest.t) t

    val balance : (Currency.Balance.var, Currency.Balance.Stable.Latest.t) t

    val nonce :
      (Mina_numbers.Account_nonce.Checked.var, Mina_numbers.Account_nonce.t) t

    val global_slot :
      (Mina_numbers.Global_slot.Checked.var, Mina_numbers.Global_slot.t) t

    val token_id : (Token_id.var, Token_id.t) t

    val time : (Block_time.Checked.t, Block_time.t) t
  end

  module Stable : sig
    module V1 : sig
      type 'a t = 'a Closed_interval.t Snapp_basic.Or_ignore.Stable.V1.t

      val to_yojson : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> 'a t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val t_of_sexp :
        (Ppx_sexp_conv_lib.Sexp.t -> 'a) -> Ppx_sexp_conv_lib.Sexp.t -> 'a t

      val sexp_of_t :
        ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

      val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

      val hash_fold_t :
           (Ppx_hash_lib.Std.Hash.state -> 'a -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> 'a t
        -> Ppx_hash_lib.Std.Hash.state

      val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int

      module With_version : sig
        type 'a typ = 'a t

        val bin_shape_typ :
          Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t

        val bin_size_typ :
             'a Core_kernel.Bin_prot.Size.sizer
          -> 'a typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ :
             'a Core_kernel.Bin_prot.Write.writer
          -> 'a typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'a typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
             'a Core_kernel.Bin_prot.Read.reader
          -> (int -> 'a typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'a typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'a typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'a typ Core_kernel.Bin_prot.Type_class.t

        type 'a t = { version : int; t : 'a typ }

        val bin_shape_t :
          Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'a Core_kernel.Bin_prot.Size.sizer
          -> 'a t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'a Core_kernel.Bin_prot.Write.writer
          -> 'a t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'a t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ :
             'a Core_kernel.Bin_prot.Read.reader
          -> (int -> 'a t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'a t Core_kernel.Bin_prot.Read.reader

        val bin_reader_t :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'a t Core_kernel.Bin_prot.Type_class.reader

        val bin_t :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'a t Core_kernel.Bin_prot.Type_class.t

        val create : 'a typ -> 'a t
      end

      val bin_read_t :
           'a Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> 'a t

      val __bin_read_t__ :
           'a Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> int
        -> 'a t

      val bin_size_t : 'a Core_kernel.Bin_prot.Size.sizer -> 'a t -> int

      val bin_write_t :
           'a Core_kernel.Bin_prot.Write.writer
        -> Bin_prot.Common.buf
        -> pos:Bin_prot.Common.pos
        -> 'a t
        -> Bin_prot.Common.pos

      val bin_shape_t :
        Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t

      val bin_reader_t :
           'a Core_kernel.Bin_prot.Type_class.reader
        -> 'a t Core_kernel.Bin_prot.Type_class.reader

      val bin_writer_t :
           'a Core_kernel.Bin_prot.Type_class.writer
        -> 'a t Core_kernel.Bin_prot.Type_class.writer

      val bin_t :
           'a Core_kernel.Bin_prot.Type_class.t
        -> 'a t Core_kernel.Bin_prot.Type_class.t

      val __ :
        (   'a Core_kernel.Bin_prot.Read.reader
         -> Bin_prot.Common.buf
         -> pos_ref:Bin_prot.Common.pos_ref
         -> 'a t)
        * (   'b Core_kernel.Bin_prot.Read.reader
           -> Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> int
           -> 'b t)
        * ('c Core_kernel.Bin_prot.Size.sizer -> 'c t -> int)
        * (   'd Core_kernel.Bin_prot.Write.writer
           -> Bin_prot.Common.buf
           -> pos:Bin_prot.Common.pos
           -> 'd t
           -> Bin_prot.Common.pos)
        * (Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t)
        * (   'e Core_kernel.Bin_prot.Type_class.reader
           -> 'e t Core_kernel.Bin_prot.Type_class.reader)
        * (   'f Core_kernel.Bin_prot.Type_class.writer
           -> 'f t Core_kernel.Bin_prot.Type_class.writer)
        * (   'g Core_kernel.Bin_prot.Type_class.t
           -> 'g t Core_kernel.Bin_prot.Type_class.t)
    end

    module Latest = V1
  end

  type 'a t = 'a Stable.Latest.t

  val to_yojson : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t

  val of_yojson :
       (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or)
    -> Yojson.Safe.t
    -> 'a t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp :
    (Ppx_sexp_conv_lib.Sexp.t -> 'a) -> Ppx_sexp_conv_lib.Sexp.t -> 'a t

  val sexp_of_t :
    ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

  val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

  val hash_fold_t :
       (Ppx_hash_lib.Std.Hash.state -> 'a -> Ppx_hash_lib.Std.Hash.state)
    -> Ppx_hash_lib.Std.Hash.state
    -> 'a t
    -> Ppx_hash_lib.Std.Hash.state

  val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int

  val to_input :
    ('b, 'a) Tc.t -> 'a t -> (Snapp_basic.F.t, bool) Random_oracle_input.t

  module Checked : sig
    type 'a t = 'a Closed_interval.t Snapp_basic.Or_ignore.Checked.t

    val to_input :
         ('a, 'b) Tc.t
      -> 'a t
      -> ( Snark_params.Tick.Field.Var.t
         , Snark_params.Tick.Boolean.var )
         Random_oracle_input.t

    val check : ('a, 'b) Tc.t -> 'a t -> 'a -> Snark_params.Tick.Boolean.var
  end

  val typ :
       ('a, 'b) Tc.t
    -> ( 'a Closed_interval.t Snapp_basic.Or_ignore.Checked.t
       , 'b Closed_interval.t Snapp_basic.Or_ignore.t )
       Snark_params.Tick.Typ.t

  val check :
       label:string
    -> ('b, 'a) Tc.t
    -> 'a t
    -> 'a
    -> (unit, Core_kernel__.Error.t) Core_kernel._result
end

module Eq_data : sig
  module Stable = Mina_base__Snapp_basic.Or_ignore.Stable

  type 'a t = 'a Mina_base__Snapp_basic.Or_ignore.Stable.V1.t =
    | Check of 'a
    | Ignore

  val to_yojson : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t

  val of_yojson :
       (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or)
    -> Yojson.Safe.t
    -> 'a t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp :
    (Ppx_sexp_conv_lib.Sexp.t -> 'a) -> Ppx_sexp_conv_lib.Sexp.t -> 'a t

  val sexp_of_t :
    ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

  val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

  val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int

  val hash_fold_t :
       (Ppx_hash_lib.Std.Hash.state -> 'a -> Ppx_hash_lib.Std.Hash.state)
    -> Ppx_hash_lib.Std.Hash.state
    -> 'a t
    -> Ppx_hash_lib.Std.Hash.state

  val to_option : 'a t -> 'a option

  val of_option : 'a option -> 'a t

  module Checked = Mina_base__Snapp_basic.Or_ignore.Checked

  module Tc : sig
    type ('var, 'a) t =
      { equal : 'a -> 'a -> bool
      ; equal_checked : 'var -> 'var -> Snark_params.Tick.Boolean.var
      ; default : 'a
      ; typ : ('var, 'a) Snark_params.Tick.Typ.t
      ; to_input : 'a -> (Snapp_basic.F.t, bool) Random_oracle_input.t
      ; to_input_checked :
             'var
          -> ( Snark_params.Tick.Field.Var.t
             , Snark_params.Tick.Boolean.var )
             Random_oracle_input.t
      }

    val run :
         (   'a
          -> 'b
          -> ( 'c
             , Pickles.Impls.Step.prover_state )
             Pickles.Impls.Step.Internal_Basic.Checked.t)
      -> 'a
      -> 'b
      -> 'c

    val field :
      ( Pickles__Impls.Step.Impl.Internal_Basic.Field.Var.t
      , Snark_params.Tick.Field.t )
      t

    val receipt_chain_hash :
      (Receipt.Chain_hash.var, Snark_params.Tick.Field.t) t

    val ledger_hash : (Ledger_hash.var, Snark_params.Tick.Field.t) t

    val frozen_ledger_hash :
      (Frozen_ledger_hash.var, Snark_params.Tick.Field.t) t

    val state_hash : (State_hash.var, Snark_params.Tick.Field.t) t

    val epoch_seed : (Epoch_seed.var, Snark_params.Tick.Field.t) t

    val public_key :
         unit
      -> ( Signature_lib__Public_key.Compressed.var
         , Signature_lib.Public_key.Compressed.t )
         t
  end

  val to_input :
       explicit:bool
    -> ('a, 'b) Tc.t
    -> 'b t
    -> (Snapp_basic.F.t, bool) Random_oracle_input.t

  val to_input_explicit :
    ('a, 'b) Tc.t -> 'b t -> (Snapp_basic.F.t, bool) Random_oracle_input.t

  val to_input_checked :
       ('a, 'b) Tc.t
    -> 'a Mina_base__Snapp_basic.Or_ignore.Checked.t
    -> ( Snark_params.Tick.Field.Var.t
       , Snark_params.Tick.Boolean.var )
       Random_oracle_input.t

  val check_checked :
       ('a, 'b) Tc.t
    -> 'a Mina_base__Snapp_basic.Or_ignore.Checked.t
    -> 'a
    -> Snark_params.Tick.Boolean.var

  val check :
       label:string
    -> ('b, 'a) Tc.t
    -> 'a t
    -> 'a
    -> (unit, Core_kernel__.Error.t) Core_kernel._result

  val typ_implicit :
       ('a, 'b) Tc.t
    -> ( 'a Mina_base__Snapp_basic.Or_ignore.Checked.t
       , 'b t )
       Snark_params.Tick.Typ.t

  val typ_explicit :
       ('a, 'b) Tc.t
    -> ( 'a Mina_base__Snapp_basic.Or_ignore.Checked.t
       , 'b t )
       Snark_params.Tick.Typ.t
end

module Hash : sig
  module Stable = Mina_base__Snapp_basic.Or_ignore.Stable

  type 'a t = 'a Eq_data.t = Check of 'a | Ignore

  val to_yojson : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t

  val of_yojson :
       (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or)
    -> Yojson.Safe.t
    -> 'a t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp :
    (Ppx_sexp_conv_lib.Sexp.t -> 'a) -> Ppx_sexp_conv_lib.Sexp.t -> 'a t

  val sexp_of_t :
    ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

  val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

  val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int

  val hash_fold_t :
       (Ppx_hash_lib.Std.Hash.state -> 'a -> Ppx_hash_lib.Std.Hash.state)
    -> Ppx_hash_lib.Std.Hash.state
    -> 'a t
    -> Ppx_hash_lib.Std.Hash.state

  val to_option : 'a t -> 'a option

  val of_option : 'a option -> 'a t

  module Checked = Mina_base__Snapp_basic.Or_ignore.Checked
  module Tc = Eq_data.Tc

  val to_input_explicit :
    ('a, 'b) Tc.t -> 'b t -> (Snapp_basic.F.t, bool) Random_oracle_input.t

  val to_input_checked :
       ('a, 'b) Tc.t
    -> 'a Mina_base__Snapp_basic.Or_ignore.Checked.t
    -> ( Snark_params.Tick.Field.Var.t
       , Snark_params.Tick.Boolean.var )
       Random_oracle_input.t

  val check_checked :
       ('a, 'b) Tc.t
    -> 'a Mina_base__Snapp_basic.Or_ignore.Checked.t
    -> 'a
    -> Snark_params.Tick.Boolean.var

  val check :
       label:string
    -> ('b, 'a) Tc.t
    -> 'a t
    -> 'a
    -> (unit, Core_kernel__.Error.t) Core_kernel._result

  val typ_implicit :
       ('a, 'b) Tc.t
    -> ( 'a Mina_base__Snapp_basic.Or_ignore.Checked.t
       , 'b t )
       Snark_params.Tick.Typ.t

  val typ_explicit :
       ('a, 'b) Tc.t
    -> ( 'a Mina_base__Snapp_basic.Or_ignore.Checked.t
       , 'b t )
       Snark_params.Tick.Typ.t

  val to_input :
    ('a, 'b) Tc.t -> 'b t -> (Snapp_basic.F.t, bool) Random_oracle_input.t

  val typ :
       ('a, 'b) Tc.t
    -> ( 'a Mina_base__Snapp_basic.Or_ignore.Checked.t
       , 'b t )
       Snark_params.Tick.Typ.t
end

module Leaf_typs : sig
  val public_key :
       unit
    -> ( Signature_lib.Public_key.Compressed.var Snapp_basic.Or_ignore.Checked.t
       , Signature_lib.Public_key.Compressed.t Snapp_basic.Or_ignore.t )
       Snark_params.Tick.Typ.t

  val field :
    ( Pickles__Impls.Step.Impl.Internal_Basic.Field.Var.t
      Mina_base__Snapp_basic.Or_ignore.Checked.t
    , Snark_params.Tick.Field.t Hash.t )
    Snark_params.Tick.Typ.t

  val receipt_chain_hash :
    ( Receipt.Chain_hash.var Mina_base__Snapp_basic.Or_ignore.Checked.t
    , Snark_params.Tick.Field.t Hash.t )
    Snark_params.Tick.Typ.t

  val ledger_hash :
    ( Ledger_hash.var Mina_base__Snapp_basic.Or_ignore.Checked.t
    , Snark_params.Tick.Field.t Hash.t )
    Snark_params.Tick.Typ.t

  val frozen_ledger_hash :
    ( Frozen_ledger_hash.var Mina_base__Snapp_basic.Or_ignore.Checked.t
    , Snark_params.Tick.Field.t Hash.t )
    Snark_params.Tick.Typ.t

  val state_hash :
    ( State_hash.var Mina_base__Snapp_basic.Or_ignore.Checked.t
    , Snark_params.Tick.Field.t Hash.t )
    Snark_params.Tick.Typ.t

  val length :
    ( Mina_numbers.Length.Checked.var Closed_interval.t
      Snapp_basic.Or_ignore.Checked.t
    , Mina_numbers.Length.t Closed_interval.t Snapp_basic.Or_ignore.t )
    Snark_params.Tick.Typ.t

  val time :
    ( Block_time.Checked.t Closed_interval.t Snapp_basic.Or_ignore.Checked.t
    , Block_time.t Closed_interval.t Snapp_basic.Or_ignore.t )
    Snark_params.Tick.Typ.t

  val amount :
    ( Currency.Amount.Checked.t Closed_interval.t Snapp_basic.Or_ignore.Checked.t
    , Currency.Amount.Stable.Latest.t Closed_interval.t Snapp_basic.Or_ignore.t
    )
    Snark_params.Tick.Typ.t

  val balance :
    ( Currency.Balance.var Closed_interval.t Snapp_basic.Or_ignore.Checked.t
    , Currency.Balance.Stable.Latest.t Closed_interval.t Snapp_basic.Or_ignore.t
    )
    Snark_params.Tick.Typ.t

  val nonce :
    ( Mina_numbers.Account_nonce.Checked.var Closed_interval.t
      Snapp_basic.Or_ignore.Checked.t
    , Mina_numbers.Account_nonce.t Closed_interval.t Snapp_basic.Or_ignore.t )
    Snark_params.Tick.Typ.t

  val global_slot :
    ( Mina_numbers.Global_slot.Checked.var Closed_interval.t
      Snapp_basic.Or_ignore.Checked.t
    , Mina_numbers.Global_slot.t Closed_interval.t Snapp_basic.Or_ignore.t )
    Snark_params.Tick.Typ.t

  val token_id :
    ( Token_id.var Closed_interval.t Snapp_basic.Or_ignore.Checked.t
    , Token_id.t Closed_interval.t Snapp_basic.Or_ignore.t )
    Snark_params.Tick.Typ.t
end

module Account : sig
  module Poly : sig
    module Stable : sig
      module V1 : sig
        type ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t =
          { balance : 'balance
          ; nonce : 'nonce
          ; receipt_chain_hash : 'receipt_chain_hash
          ; public_key : 'pk
          ; delegate : 'pk
          ; state : 'field Snapp_state.V.Stable.V1.t
          }

        val to_yojson :
             ('balance -> Yojson.Safe.t)
          -> ('nonce -> Yojson.Safe.t)
          -> ('receipt_chain_hash -> Yojson.Safe.t)
          -> ('pk -> Yojson.Safe.t)
          -> ('field -> Yojson.Safe.t)
          -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
          -> Yojson.Safe.t

        val of_yojson :
             (Yojson.Safe.t -> 'balance Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'nonce Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'receipt_chain_hash Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'pk Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'field Ppx_deriving_yojson_runtime.error_or)
          -> Yojson.Safe.t
          -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
             Ppx_deriving_yojson_runtime.error_or

        val version : int

        val __versioned__ : unit

        val to_hlist :
             ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
          -> ( unit
             ,    'balance
               -> 'nonce
               -> 'receipt_chain_hash
               -> 'pk
               -> 'pk
               -> 'field Snapp_state.V.Stable.V1.t
               -> unit )
             H_list.t

        val of_hlist :
             ( unit
             ,    'balance
               -> 'nonce
               -> 'receipt_chain_hash
               -> 'pk
               -> 'pk
               -> 'field Snapp_state.V.Stable.V1.t
               -> unit )
             H_list.t
          -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t

        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'balance)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'nonce)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'receipt_chain_hash)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'pk)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'field)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t

        val sexp_of_t :
             ('balance -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('nonce -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('receipt_chain_hash -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('pk -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('field -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
          -> Ppx_sexp_conv_lib.Sexp.t

        val equal :
             ('balance -> 'balance -> bool)
          -> ('nonce -> 'nonce -> bool)
          -> ('receipt_chain_hash -> 'receipt_chain_hash -> bool)
          -> ('pk -> 'pk -> bool)
          -> ('field -> 'field -> bool)
          -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
          -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
          -> bool

        val hash_fold_t :
             (   Ppx_hash_lib.Std.Hash.state
              -> 'balance
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'nonce
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'receipt_chain_hash
              -> Ppx_hash_lib.Std.Hash.state)
          -> (Ppx_hash_lib.Std.Hash.state -> 'pk -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'field
              -> Ppx_hash_lib.Std.Hash.state)
          -> Ppx_hash_lib.Std.Hash.state
          -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
          -> Ppx_hash_lib.Std.Hash.state

        val compare :
             ('balance -> 'balance -> int)
          -> ('nonce -> 'nonce -> int)
          -> ('receipt_chain_hash -> 'receipt_chain_hash -> int)
          -> ('pk -> 'pk -> int)
          -> ('field -> 'field -> int)
          -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
          -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
          -> int

        module With_version : sig
          type ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) typ =
            ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t

          val bin_shape_typ :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_typ :
               'balance Core_kernel.Bin_prot.Size.sizer
            -> 'nonce Core_kernel.Bin_prot.Size.sizer
            -> 'receipt_chain_hash Core_kernel.Bin_prot.Size.sizer
            -> 'pk Core_kernel.Bin_prot.Size.sizer
            -> 'field Core_kernel.Bin_prot.Size.sizer
            -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) typ
               Core_kernel.Bin_prot.Size.sizer

          val bin_write_typ :
               'balance Core_kernel.Bin_prot.Write.writer
            -> 'nonce Core_kernel.Bin_prot.Write.writer
            -> 'receipt_chain_hash Core_kernel.Bin_prot.Write.writer
            -> 'pk Core_kernel.Bin_prot.Write.writer
            -> 'field Core_kernel.Bin_prot.Write.writer
            -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) typ
               Core_kernel.Bin_prot.Write.writer

          val bin_writer_typ :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> 'd Core_kernel.Bin_prot.Type_class.writer
            -> 'e Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c, 'd, 'e) typ Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_typ__ :
               'balance Core_kernel.Bin_prot.Read.reader
            -> 'nonce Core_kernel.Bin_prot.Read.reader
            -> 'receipt_chain_hash Core_kernel.Bin_prot.Read.reader
            -> 'pk Core_kernel.Bin_prot.Read.reader
            -> 'field Core_kernel.Bin_prot.Read.reader
            -> (int -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) typ)
               Core_kernel.Bin_prot.Read.reader

          val bin_read_typ :
               'balance Core_kernel.Bin_prot.Read.reader
            -> 'nonce Core_kernel.Bin_prot.Read.reader
            -> 'receipt_chain_hash Core_kernel.Bin_prot.Read.reader
            -> 'pk Core_kernel.Bin_prot.Read.reader
            -> 'field Core_kernel.Bin_prot.Read.reader
            -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) typ
               Core_kernel.Bin_prot.Read.reader

          val bin_reader_typ :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> 'c Core_kernel.Bin_prot.Type_class.reader
            -> 'd Core_kernel.Bin_prot.Type_class.reader
            -> 'e Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c, 'd, 'e) typ Core_kernel.Bin_prot.Type_class.reader

          val bin_typ :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> 'd Core_kernel.Bin_prot.Type_class.t
            -> 'e Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c, 'd, 'e) typ Core_kernel.Bin_prot.Type_class.t

          type ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t =
            { version : int
            ; t : ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) typ
            }

          val bin_shape_t :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_t :
               'balance Core_kernel.Bin_prot.Size.sizer
            -> 'nonce Core_kernel.Bin_prot.Size.sizer
            -> 'receipt_chain_hash Core_kernel.Bin_prot.Size.sizer
            -> 'pk Core_kernel.Bin_prot.Size.sizer
            -> 'field Core_kernel.Bin_prot.Size.sizer
            -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
               Core_kernel.Bin_prot.Size.sizer

          val bin_write_t :
               'balance Core_kernel.Bin_prot.Write.writer
            -> 'nonce Core_kernel.Bin_prot.Write.writer
            -> 'receipt_chain_hash Core_kernel.Bin_prot.Write.writer
            -> 'pk Core_kernel.Bin_prot.Write.writer
            -> 'field Core_kernel.Bin_prot.Write.writer
            -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
               Core_kernel.Bin_prot.Write.writer

          val bin_writer_t :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> 'd Core_kernel.Bin_prot.Type_class.writer
            -> 'e Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_t__ :
               'balance Core_kernel.Bin_prot.Read.reader
            -> 'nonce Core_kernel.Bin_prot.Read.reader
            -> 'receipt_chain_hash Core_kernel.Bin_prot.Read.reader
            -> 'pk Core_kernel.Bin_prot.Read.reader
            -> 'field Core_kernel.Bin_prot.Read.reader
            -> (int -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t)
               Core_kernel.Bin_prot.Read.reader

          val bin_read_t :
               'balance Core_kernel.Bin_prot.Read.reader
            -> 'nonce Core_kernel.Bin_prot.Read.reader
            -> 'receipt_chain_hash Core_kernel.Bin_prot.Read.reader
            -> 'pk Core_kernel.Bin_prot.Read.reader
            -> 'field Core_kernel.Bin_prot.Read.reader
            -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
               Core_kernel.Bin_prot.Read.reader

          val bin_reader_t :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> 'c Core_kernel.Bin_prot.Type_class.reader
            -> 'd Core_kernel.Bin_prot.Type_class.reader
            -> 'e Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.reader

          val bin_t :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> 'd Core_kernel.Bin_prot.Type_class.t
            -> 'e Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.t

          val create : ('a, 'b, 'c, 'd, 'e) typ -> ('a, 'b, 'c, 'd, 'e) t
        end

        val bin_read_t :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'b Core_kernel.Bin_prot.Read.reader
          -> 'c Core_kernel.Bin_prot.Read.reader
          -> 'd Core_kernel.Bin_prot.Read.reader
          -> 'e Core_kernel.Bin_prot.Read.reader
          -> Bin_prot.Common.buf
          -> pos_ref:Bin_prot.Common.pos_ref
          -> ('a, 'b, 'c, 'd, 'e) t

        val __bin_read_t__ :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'b Core_kernel.Bin_prot.Read.reader
          -> 'c Core_kernel.Bin_prot.Read.reader
          -> 'd Core_kernel.Bin_prot.Read.reader
          -> 'e Core_kernel.Bin_prot.Read.reader
          -> Bin_prot.Common.buf
          -> pos_ref:Bin_prot.Common.pos_ref
          -> int
          -> ('a, 'b, 'c, 'd, 'e) t

        val bin_size_t :
             'a Core_kernel.Bin_prot.Size.sizer
          -> 'b Core_kernel.Bin_prot.Size.sizer
          -> 'c Core_kernel.Bin_prot.Size.sizer
          -> 'd Core_kernel.Bin_prot.Size.sizer
          -> 'e Core_kernel.Bin_prot.Size.sizer
          -> ('a, 'b, 'c, 'd, 'e) t
          -> int

        val bin_write_t :
             'a Core_kernel.Bin_prot.Write.writer
          -> 'b Core_kernel.Bin_prot.Write.writer
          -> 'c Core_kernel.Bin_prot.Write.writer
          -> 'd Core_kernel.Bin_prot.Write.writer
          -> 'e Core_kernel.Bin_prot.Write.writer
          -> Bin_prot.Common.buf
          -> pos:Bin_prot.Common.pos
          -> ('a, 'b, 'c, 'd, 'e) t
          -> Bin_prot.Common.pos

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_reader_t :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> 'c Core_kernel.Bin_prot.Type_class.reader
          -> 'd Core_kernel.Bin_prot.Type_class.reader
          -> 'e Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.reader

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> 'd Core_kernel.Bin_prot.Type_class.writer
          -> 'e Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.writer

        val bin_t :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> 'c Core_kernel.Bin_prot.Type_class.t
          -> 'd Core_kernel.Bin_prot.Type_class.t
          -> 'e Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.t

        val __ :
          (   'a Core_kernel.Bin_prot.Read.reader
           -> 'b Core_kernel.Bin_prot.Read.reader
           -> 'c Core_kernel.Bin_prot.Read.reader
           -> 'd Core_kernel.Bin_prot.Read.reader
           -> 'e Core_kernel.Bin_prot.Read.reader
           -> Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> ('a, 'b, 'c, 'd, 'e) t)
          * (   'f Core_kernel.Bin_prot.Read.reader
             -> 'g Core_kernel.Bin_prot.Read.reader
             -> 'h Core_kernel.Bin_prot.Read.reader
             -> 'i Core_kernel.Bin_prot.Read.reader
             -> 'j Core_kernel.Bin_prot.Read.reader
             -> Bin_prot.Common.buf
             -> pos_ref:Bin_prot.Common.pos_ref
             -> int
             -> ('f, 'g, 'h, 'i, 'j) t)
          * (   'k Core_kernel.Bin_prot.Size.sizer
             -> 'l Core_kernel.Bin_prot.Size.sizer
             -> 'm Core_kernel.Bin_prot.Size.sizer
             -> 'n Core_kernel.Bin_prot.Size.sizer
             -> 'o Core_kernel.Bin_prot.Size.sizer
             -> ('k, 'l, 'm, 'n, 'o) t
             -> int)
          * (   'p Core_kernel.Bin_prot.Write.writer
             -> 'q Core_kernel.Bin_prot.Write.writer
             -> 'r Core_kernel.Bin_prot.Write.writer
             -> 's Core_kernel.Bin_prot.Write.writer
             -> 't Core_kernel.Bin_prot.Write.writer
             -> Bin_prot.Common.buf
             -> pos:Bin_prot.Common.pos
             -> ('p, 'q, 'r, 's, 't) t
             -> Bin_prot.Common.pos)
          * (   Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t)
          * (   'u Core_kernel.Bin_prot.Type_class.reader
             -> 'v Core_kernel.Bin_prot.Type_class.reader
             -> 'w Core_kernel.Bin_prot.Type_class.reader
             -> 'x Core_kernel.Bin_prot.Type_class.reader
             -> 'y Core_kernel.Bin_prot.Type_class.reader
             -> ('u, 'v, 'w, 'x, 'y) t Core_kernel.Bin_prot.Type_class.reader)
          * (   'z Core_kernel.Bin_prot.Type_class.writer
             -> 'a1 Core_kernel.Bin_prot.Type_class.writer
             -> 'b1 Core_kernel.Bin_prot.Type_class.writer
             -> 'c1 Core_kernel.Bin_prot.Type_class.writer
             -> 'd1 Core_kernel.Bin_prot.Type_class.writer
             -> ('z, 'a1, 'b1, 'c1, 'd1) t
                Core_kernel.Bin_prot.Type_class.writer)
          * (   'e1 Core_kernel.Bin_prot.Type_class.t
             -> 'f1 Core_kernel.Bin_prot.Type_class.t
             -> 'g1 Core_kernel.Bin_prot.Type_class.t
             -> 'h1 Core_kernel.Bin_prot.Type_class.t
             -> 'i1 Core_kernel.Bin_prot.Type_class.t
             -> ('e1, 'f1, 'g1, 'h1, 'i1) t Core_kernel.Bin_prot.Type_class.t)
      end

      module Latest = V1
    end

    type ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t =
          ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) Stable.V1.t =
      { balance : 'balance
      ; nonce : 'nonce
      ; receipt_chain_hash : 'receipt_chain_hash
      ; public_key : 'pk
      ; delegate : 'pk
      ; state : 'field Snapp_state.V.t
      }

    val to_yojson :
         ('balance -> Yojson.Safe.t)
      -> ('nonce -> Yojson.Safe.t)
      -> ('receipt_chain_hash -> Yojson.Safe.t)
      -> ('pk -> Yojson.Safe.t)
      -> ('field -> Yojson.Safe.t)
      -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
      -> Yojson.Safe.t

    val of_yojson :
         (Yojson.Safe.t -> 'balance Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'nonce Ppx_deriving_yojson_runtime.error_or)
      -> (   Yojson.Safe.t
          -> 'receipt_chain_hash Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'pk Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'field Ppx_deriving_yojson_runtime.error_or)
      -> Yojson.Safe.t
      -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
         Ppx_deriving_yojson_runtime.error_or

    val to_hlist :
         ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
      -> ( unit
         ,    'balance
           -> 'nonce
           -> 'receipt_chain_hash
           -> 'pk
           -> 'pk
           -> 'field Snapp_state.V.t
           -> unit )
         H_list.t

    val of_hlist :
         ( unit
         ,    'balance
           -> 'nonce
           -> 'receipt_chain_hash
           -> 'pk
           -> 'pk
           -> 'field Snapp_state.V.t
           -> unit )
         H_list.t
      -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'balance)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'nonce)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'receipt_chain_hash)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'pk)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'field)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t

    val sexp_of_t :
         ('balance -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('nonce -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('receipt_chain_hash -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('pk -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('field -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
      -> Ppx_sexp_conv_lib.Sexp.t

    val equal :
         ('balance -> 'balance -> bool)
      -> ('nonce -> 'nonce -> bool)
      -> ('receipt_chain_hash -> 'receipt_chain_hash -> bool)
      -> ('pk -> 'pk -> bool)
      -> ('field -> 'field -> bool)
      -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
      -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
      -> bool

    val hash_fold_t :
         (Ppx_hash_lib.Std.Hash.state -> 'balance -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'nonce -> Ppx_hash_lib.Std.Hash.state)
      -> (   Ppx_hash_lib.Std.Hash.state
          -> 'receipt_chain_hash
          -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'pk -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'field -> Ppx_hash_lib.Std.Hash.state)
      -> Ppx_hash_lib.Std.Hash.state
      -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
      -> Ppx_hash_lib.Std.Hash.state

    val compare :
         ('balance -> 'balance -> int)
      -> ('nonce -> 'nonce -> int)
      -> ('receipt_chain_hash -> 'receipt_chain_hash -> int)
      -> ('pk -> 'pk -> int)
      -> ('field -> 'field -> int)
      -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
      -> ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t
      -> int
  end

  module Stable : sig
    module V1 : sig
      type t =
        ( Currency.Balance.Stable.V1.t Numeric.Stable.V1.t
        , Mina_numbers.Account_nonce.Stable.V1.t Numeric.Stable.V1.t
        , Receipt.Chain_hash.Stable.V1.t Hash.t
        , Signature_lib.Public_key.Compressed.Stable.V1.t Hash.t
        , Snapp_basic.F.Stable.V1.t Hash.t )
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

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val compare : t -> t -> int

  val accept : t

  val to_input : t -> (Snapp_basic.F.t, bool) Random_oracle_input.t

  val digest : t -> Random_oracle.Digest.t

  module Checked : sig
    type t =
      ( Currency.Balance.var Numeric.Checked.t
      , Mina_numbers.Account_nonce.Checked.t Numeric.Checked.t
      , Receipt.Chain_hash.var Mina_base__Snapp_basic.Or_ignore.Checked.t
      , Signature_lib.Public_key.Compressed.var
        Mina_base__Snapp_basic.Or_ignore.Checked.t
      , Snark_params.Tick.Field.Var.t Mina_base__Snapp_basic.Or_ignore.Checked.t
      )
      Poly.t

    val to_input :
         t
      -> ( Snark_params.Tick.Field.Var.t
         , Snark_params.Tick.Boolean.var )
         Random_oracle_input.t

    val check_nonsnapp :
      t -> Account.Checked.Unhashed.t -> Pickles.Impls.Step.Boolean.var

    val check_snapp :
      t -> Snapp_account.Checked.t -> Pickles.Impls.Step.Boolean.var

    val digest : t -> Random_oracle.Checked.Digest.t
  end

  val typ : unit -> (Checked.t, t) Snark_params.Tick.Typ.t

  val check : t -> Account.t -> unit Base__Or_error.t
end

module Protocol_state : sig
  module Epoch_data : sig
    module Poly = Epoch_data.Poly

    module Stable : sig
      module V1 : sig
        type t =
          ( ( Frozen_ledger_hash.Stable.V1.t Hash.t
            , Currency.Amount.Stable.V1.t Numeric.Stable.V1.t )
            Epoch_ledger.Poly.Stable.V1.t
          , Epoch_seed.Stable.V1.t Hash.t
          , State_hash.Stable.V1.t Hash.t
          , State_hash.Stable.V1.t Hash.t
          , Mina_numbers.Length.Stable.V1.t Numeric.Stable.V1.t )
          Epoch_data.Poly.Stable.V1.t

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
        * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t)
        )
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

    val to_input : t -> (Snapp_basic.F.t, bool) Random_oracle.Input.t

    module Checked : sig
      type t =
        ( ( Frozen_ledger_hash.var Mina_base__Snapp_basic.Or_ignore.Checked.t
          , Currency.Amount.var Numeric.Checked.t )
          Epoch_ledger.Poly.t
        , Epoch_seed.var Mina_base__Snapp_basic.Or_ignore.Checked.t
        , State_hash.var Mina_base__Snapp_basic.Or_ignore.Checked.t
        , State_hash.var Mina_base__Snapp_basic.Or_ignore.Checked.t
        , Mina_numbers.Length.Checked.t Numeric.Checked.t )
        Epoch_data.Poly.t

      val to_input :
           t
        -> ( Snark_params.Tick.Field.Var.t
           , Snark_params.Tick.Boolean.var )
           Random_oracle.Input.t
    end
  end

  module Poly : sig
    module Stable : sig
      module V1 : sig
        type ( 'snarked_ledger_hash
             , 'token_id
             , 'time
             , 'length
             , 'vrf_output
             , 'global_slot
             , 'amount
             , 'epoch_data )
             t =
          { snarked_ledger_hash : 'snarked_ledger_hash
          ; snarked_next_available_token : 'token_id
          ; timestamp : 'time
          ; blockchain_length : 'length
          ; min_window_density : 'length
          ; last_vrf_output : 'vrf_output
          ; total_currency : 'amount
          ; curr_global_slot : 'global_slot
          ; global_slot_since_genesis : 'global_slot
          ; staking_epoch_data : 'epoch_data
          ; next_epoch_data : 'epoch_data
          }

        val to_yojson :
             ('snarked_ledger_hash -> Yojson.Safe.t)
          -> ('token_id -> Yojson.Safe.t)
          -> ('time -> Yojson.Safe.t)
          -> ('length -> Yojson.Safe.t)
          -> ('vrf_output -> Yojson.Safe.t)
          -> ('global_slot -> Yojson.Safe.t)
          -> ('amount -> Yojson.Safe.t)
          -> ('epoch_data -> Yojson.Safe.t)
          -> ( 'snarked_ledger_hash
             , 'token_id
             , 'time
             , 'length
             , 'vrf_output
             , 'global_slot
             , 'amount
             , 'epoch_data )
             t
          -> Yojson.Safe.t

        val of_yojson :
             (   Yojson.Safe.t
              -> 'snarked_ledger_hash Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'token_id Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'time Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'length Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'vrf_output Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'global_slot Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'amount Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'epoch_data Ppx_deriving_yojson_runtime.error_or)
          -> Yojson.Safe.t
          -> ( 'snarked_ledger_hash
             , 'token_id
             , 'time
             , 'length
             , 'vrf_output
             , 'global_slot
             , 'amount
             , 'epoch_data )
             t
             Ppx_deriving_yojson_runtime.error_or

        val version : int

        val __versioned__ : unit

        val to_hlist :
             ( 'snarked_ledger_hash
             , 'token_id
             , 'time
             , 'length
             , 'vrf_output
             , 'global_slot
             , 'amount
             , 'epoch_data )
             t
          -> ( unit
             ,    'snarked_ledger_hash
               -> 'token_id
               -> 'time
               -> 'length
               -> 'length
               -> 'vrf_output
               -> 'amount
               -> 'global_slot
               -> 'global_slot
               -> 'epoch_data
               -> 'epoch_data
               -> unit )
             H_list.t

        val of_hlist :
             ( unit
             ,    'snarked_ledger_hash
               -> 'token_id
               -> 'time
               -> 'length
               -> 'length
               -> 'vrf_output
               -> 'amount
               -> 'global_slot
               -> 'global_slot
               -> 'epoch_data
               -> 'epoch_data
               -> unit )
             H_list.t
          -> ( 'snarked_ledger_hash
             , 'token_id
             , 'time
             , 'length
             , 'vrf_output
             , 'global_slot
             , 'amount
             , 'epoch_data )
             t

        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'snarked_ledger_hash)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'token_id)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'time)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'length)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'vrf_output)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'global_slot)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'amount)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'epoch_data)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> ( 'snarked_ledger_hash
             , 'token_id
             , 'time
             , 'length
             , 'vrf_output
             , 'global_slot
             , 'amount
             , 'epoch_data )
             t

        val sexp_of_t :
             ('snarked_ledger_hash -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('token_id -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('time -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('length -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('vrf_output -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('global_slot -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('amount -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('epoch_data -> Ppx_sexp_conv_lib.Sexp.t)
          -> ( 'snarked_ledger_hash
             , 'token_id
             , 'time
             , 'length
             , 'vrf_output
             , 'global_slot
             , 'amount
             , 'epoch_data )
             t
          -> Ppx_sexp_conv_lib.Sexp.t

        val equal :
             ('snarked_ledger_hash -> 'snarked_ledger_hash -> bool)
          -> ('token_id -> 'token_id -> bool)
          -> ('time -> 'time -> bool)
          -> ('length -> 'length -> bool)
          -> ('vrf_output -> 'vrf_output -> bool)
          -> ('global_slot -> 'global_slot -> bool)
          -> ('amount -> 'amount -> bool)
          -> ('epoch_data -> 'epoch_data -> bool)
          -> ( 'snarked_ledger_hash
             , 'token_id
             , 'time
             , 'length
             , 'vrf_output
             , 'global_slot
             , 'amount
             , 'epoch_data )
             t
          -> ( 'snarked_ledger_hash
             , 'token_id
             , 'time
             , 'length
             , 'vrf_output
             , 'global_slot
             , 'amount
             , 'epoch_data )
             t
          -> bool

        val hash_fold_t :
             (   Ppx_hash_lib.Std.Hash.state
              -> 'snarked_ledger_hash
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'token_id
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'time
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'length
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'vrf_output
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'global_slot
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'amount
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'epoch_data
              -> Ppx_hash_lib.Std.Hash.state)
          -> Ppx_hash_lib.Std.Hash.state
          -> ( 'snarked_ledger_hash
             , 'token_id
             , 'time
             , 'length
             , 'vrf_output
             , 'global_slot
             , 'amount
             , 'epoch_data )
             t
          -> Ppx_hash_lib.Std.Hash.state

        val compare :
             ('snarked_ledger_hash -> 'snarked_ledger_hash -> int)
          -> ('token_id -> 'token_id -> int)
          -> ('time -> 'time -> int)
          -> ('length -> 'length -> int)
          -> ('vrf_output -> 'vrf_output -> int)
          -> ('global_slot -> 'global_slot -> int)
          -> ('amount -> 'amount -> int)
          -> ('epoch_data -> 'epoch_data -> int)
          -> ( 'snarked_ledger_hash
             , 'token_id
             , 'time
             , 'length
             , 'vrf_output
             , 'global_slot
             , 'amount
             , 'epoch_data )
             t
          -> ( 'snarked_ledger_hash
             , 'token_id
             , 'time
             , 'length
             , 'vrf_output
             , 'global_slot
             , 'amount
             , 'epoch_data )
             t
          -> int

        val next_epoch_data : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'h

        val staking_epoch_data : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'h

        val global_slot_since_genesis : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'f

        val curr_global_slot : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'f

        val total_currency : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'g

        val last_vrf_output : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'e

        val min_window_density : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'd

        val blockchain_length : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'd

        val timestamp : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'c

        val snarked_next_available_token :
          ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'b

        val snarked_ledger_hash : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'a

        module Fields : sig
          val names : string list

          val next_epoch_data :
            ( [< `Read | `Set_and_create ]
            , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'epoch_data) t
            , 'epoch_data )
            Fieldslib.Field.t_with_perm

          val staking_epoch_data :
            ( [< `Read | `Set_and_create ]
            , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'epoch_data) t
            , 'epoch_data )
            Fieldslib.Field.t_with_perm

          val global_slot_since_genesis :
            ( [< `Read | `Set_and_create ]
            , ('a, 'b, 'c, 'd, 'e, 'global_slot, 'f, 'g) t
            , 'global_slot )
            Fieldslib.Field.t_with_perm

          val curr_global_slot :
            ( [< `Read | `Set_and_create ]
            , ('a, 'b, 'c, 'd, 'e, 'global_slot, 'f, 'g) t
            , 'global_slot )
            Fieldslib.Field.t_with_perm

          val total_currency :
            ( [< `Read | `Set_and_create ]
            , ('a, 'b, 'c, 'd, 'e, 'f, 'amount, 'g) t
            , 'amount )
            Fieldslib.Field.t_with_perm

          val last_vrf_output :
            ( [< `Read | `Set_and_create ]
            , ('a, 'b, 'c, 'd, 'vrf_output, 'e, 'f, 'g) t
            , 'vrf_output )
            Fieldslib.Field.t_with_perm

          val min_window_density :
            ( [< `Read | `Set_and_create ]
            , ('a, 'b, 'c, 'length, 'd, 'e, 'f, 'g) t
            , 'length )
            Fieldslib.Field.t_with_perm

          val blockchain_length :
            ( [< `Read | `Set_and_create ]
            , ('a, 'b, 'c, 'length, 'd, 'e, 'f, 'g) t
            , 'length )
            Fieldslib.Field.t_with_perm

          val timestamp :
            ( [< `Read | `Set_and_create ]
            , ('a, 'b, 'time, 'c, 'd, 'e, 'f, 'g) t
            , 'time )
            Fieldslib.Field.t_with_perm

          val snarked_next_available_token :
            ( [< `Read | `Set_and_create ]
            , ('a, 'token_id, 'b, 'c, 'd, 'e, 'f, 'g) t
            , 'token_id )
            Fieldslib.Field.t_with_perm

          val snarked_ledger_hash :
            ( [< `Read | `Set_and_create ]
            , ('snarked_ledger_hash, 'a, 'b, 'c, 'd, 'e, 'f, 'g) t
            , 'snarked_ledger_hash )
            Fieldslib.Field.t_with_perm

          val make_creator :
               snarked_ledger_hash:
                 (   ( [< `Read | `Set_and_create ]
                     , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                     , 'a )
                     Fieldslib.Field.t_with_perm
                  -> 'i
                  -> ('j -> 'k) * 'l)
            -> snarked_next_available_token:
                 (   ( [< `Read | `Set_and_create ]
                     , ('m, 'n, 'o, 'p, 'q, 'r, 's, 't) t
                     , 'n )
                     Fieldslib.Field.t_with_perm
                  -> 'l
                  -> ('j -> 'u) * 'v)
            -> timestamp:
                 (   ( [< `Read | `Set_and_create ]
                     , ('w, 'x, 'y, 'z, 'a1, 'b1, 'c1, 'd1) t
                     , 'y )
                     Fieldslib.Field.t_with_perm
                  -> 'v
                  -> ('j -> 'e1) * 'f1)
            -> blockchain_length:
                 (   ( [< `Read | `Set_and_create ]
                     , ('g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1) t
                     , 'j1 )
                     Fieldslib.Field.t_with_perm
                  -> 'f1
                  -> ('j -> 'o1) * 'p1)
            -> min_window_density:
                 (   ( [< `Read | `Set_and_create ]
                     , ('q1, 'r1, 's1, 't1, 'u1, 'v1, 'w1, 'x1) t
                     , 't1 )
                     Fieldslib.Field.t_with_perm
                  -> 'p1
                  -> ('j -> 'o1) * 'y1)
            -> last_vrf_output:
                 (   ( [< `Read | `Set_and_create ]
                     , ('z1, 'a2, 'b2, 'c2, 'd2, 'e2, 'f2, 'g2) t
                     , 'd2 )
                     Fieldslib.Field.t_with_perm
                  -> 'y1
                  -> ('j -> 'h2) * 'i2)
            -> total_currency:
                 (   ( [< `Read | `Set_and_create ]
                     , ('j2, 'k2, 'l2, 'm2, 'n2, 'o2, 'p2, 'q2) t
                     , 'p2 )
                     Fieldslib.Field.t_with_perm
                  -> 'i2
                  -> ('j -> 'r2) * 's2)
            -> curr_global_slot:
                 (   ( [< `Read | `Set_and_create ]
                     , ('t2, 'u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3) t
                     , 'y2 )
                     Fieldslib.Field.t_with_perm
                  -> 's2
                  -> ('j -> 'b3) * 'c3)
            -> global_slot_since_genesis:
                 (   ( [< `Read | `Set_and_create ]
                     , ('d3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3, 'k3) t
                     , 'i3 )
                     Fieldslib.Field.t_with_perm
                  -> 'c3
                  -> ('j -> 'b3) * 'l3)
            -> staking_epoch_data:
                 (   ( [< `Read | `Set_and_create ]
                     , ('m3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3) t
                     , 't3 )
                     Fieldslib.Field.t_with_perm
                  -> 'l3
                  -> ('j -> 'u3) * 'v3)
            -> next_epoch_data:
                 (   ( [< `Read | `Set_and_create ]
                     , ('w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4) t
                     , 'd4 )
                     Fieldslib.Field.t_with_perm
                  -> 'v3
                  -> ('j -> 'u3) * 'e4)
            -> 'i
            -> ('j -> ('k, 'u, 'e1, 'o1, 'h2, 'b3, 'r2, 'u3) t) * 'e4

          val create :
               snarked_ledger_hash:'a
            -> snarked_next_available_token:'b
            -> timestamp:'c
            -> blockchain_length:'d
            -> min_window_density:'d
            -> last_vrf_output:'e
            -> total_currency:'f
            -> curr_global_slot:'g
            -> global_slot_since_genesis:'g
            -> staking_epoch_data:'h
            -> next_epoch_data:'h
            -> ('a, 'b, 'c, 'd, 'e, 'g, 'f, 'h) t

          val map :
               snarked_ledger_hash:
                 (   ( [< `Read | `Set_and_create ]
                     , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                     , 'a )
                     Fieldslib.Field.t_with_perm
                  -> 'i)
            -> snarked_next_available_token:
                 (   ( [< `Read | `Set_and_create ]
                     , ('j, 'k, 'l, 'm, 'n, 'o, 'p, 'q) t
                     , 'k )
                     Fieldslib.Field.t_with_perm
                  -> 'r)
            -> timestamp:
                 (   ( [< `Read | `Set_and_create ]
                     , ('s, 't, 'u, 'v, 'w, 'x, 'y, 'z) t
                     , 'u )
                     Fieldslib.Field.t_with_perm
                  -> 'a1)
            -> blockchain_length:
                 (   ( [< `Read | `Set_and_create ]
                     , ('b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1, 'i1) t
                     , 'e1 )
                     Fieldslib.Field.t_with_perm
                  -> 'j1)
            -> min_window_density:
                 (   ( [< `Read | `Set_and_create ]
                     , ('k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1) t
                     , 'n1 )
                     Fieldslib.Field.t_with_perm
                  -> 'j1)
            -> last_vrf_output:
                 (   ( [< `Read | `Set_and_create ]
                     , ('s1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1) t
                     , 'w1 )
                     Fieldslib.Field.t_with_perm
                  -> 'a2)
            -> total_currency:
                 (   ( [< `Read | `Set_and_create ]
                     , ('b2, 'c2, 'd2, 'e2, 'f2, 'g2, 'h2, 'i2) t
                     , 'h2 )
                     Fieldslib.Field.t_with_perm
                  -> 'j2)
            -> curr_global_slot:
                 (   ( [< `Read | `Set_and_create ]
                     , ('k2, 'l2, 'm2, 'n2, 'o2, 'p2, 'q2, 'r2) t
                     , 'p2 )
                     Fieldslib.Field.t_with_perm
                  -> 's2)
            -> global_slot_since_genesis:
                 (   ( [< `Read | `Set_and_create ]
                     , ('t2, 'u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3) t
                     , 'y2 )
                     Fieldslib.Field.t_with_perm
                  -> 's2)
            -> staking_epoch_data:
                 (   ( [< `Read | `Set_and_create ]
                     , ('b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3) t
                     , 'i3 )
                     Fieldslib.Field.t_with_perm
                  -> 'j3)
            -> next_epoch_data:
                 (   ( [< `Read | `Set_and_create ]
                     , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3) t
                     , 'r3 )
                     Fieldslib.Field.t_with_perm
                  -> 'j3)
            -> ('i, 'r, 'a1, 'j1, 'a2, 's2, 'j2, 'j3) t

          val iter :
               snarked_ledger_hash:
                 (   ( [< `Read | `Set_and_create ]
                     , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                     , 'a )
                     Fieldslib.Field.t_with_perm
                  -> unit)
            -> snarked_next_available_token:
                 (   ( [< `Read | `Set_and_create ]
                     , ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t
                     , 'j )
                     Fieldslib.Field.t_with_perm
                  -> unit)
            -> timestamp:
                 (   ( [< `Read | `Set_and_create ]
                     , ('q, 'r, 's, 't, 'u, 'v, 'w, 'x) t
                     , 's )
                     Fieldslib.Field.t_with_perm
                  -> unit)
            -> blockchain_length:
                 (   ( [< `Read | `Set_and_create ]
                     , ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1) t
                     , 'b1 )
                     Fieldslib.Field.t_with_perm
                  -> unit)
            -> min_window_density:
                 (   ( [< `Read | `Set_and_create ]
                     , ('g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1) t
                     , 'j1 )
                     Fieldslib.Field.t_with_perm
                  -> unit)
            -> last_vrf_output:
                 (   ( [< `Read | `Set_and_create ]
                     , ('o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1) t
                     , 's1 )
                     Fieldslib.Field.t_with_perm
                  -> unit)
            -> total_currency:
                 (   ( [< `Read | `Set_and_create ]
                     , ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
                     , 'c2 )
                     Fieldslib.Field.t_with_perm
                  -> unit)
            -> curr_global_slot:
                 (   ( [< `Read | `Set_and_create ]
                     , ('e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2) t
                     , 'j2 )
                     Fieldslib.Field.t_with_perm
                  -> unit)
            -> global_slot_since_genesis:
                 (   ( [< `Read | `Set_and_create ]
                     , ('m2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2) t
                     , 'r2 )
                     Fieldslib.Field.t_with_perm
                  -> unit)
            -> staking_epoch_data:
                 (   ( [< `Read | `Set_and_create ]
                     , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3) t
                     , 'b3 )
                     Fieldslib.Field.t_with_perm
                  -> unit)
            -> next_epoch_data:
                 (   ( [< `Read | `Set_and_create ]
                     , ('c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                     , 'j3 )
                     Fieldslib.Field.t_with_perm
                  -> unit)
            -> unit

          val fold :
               init:'a
            -> snarked_ledger_hash:
                 (   'a
                  -> ( [< `Read | `Set_and_create ]
                     , ('b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
                     , 'b )
                     Fieldslib.Field.t_with_perm
                  -> 'j)
            -> snarked_next_available_token:
                 (   'j
                  -> ( [< `Read | `Set_and_create ]
                     , ('k, 'l, 'm, 'n, 'o, 'p, 'q, 'r) t
                     , 'l )
                     Fieldslib.Field.t_with_perm
                  -> 's)
            -> timestamp:
                 (   's
                  -> ( [< `Read | `Set_and_create ]
                     , ('t, 'u, 'v, 'w, 'x, 'y, 'z, 'a1) t
                     , 'v )
                     Fieldslib.Field.t_with_perm
                  -> 'b1)
            -> blockchain_length:
                 (   'b1
                  -> ( [< `Read | `Set_and_create ]
                     , ('c1, 'd1, 'e1, 'f1, 'g1, 'h1, 'i1, 'j1) t
                     , 'f1 )
                     Fieldslib.Field.t_with_perm
                  -> 'k1)
            -> min_window_density:
                 (   'k1
                  -> ( [< `Read | `Set_and_create ]
                     , ('l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1, 's1) t
                     , 'o1 )
                     Fieldslib.Field.t_with_perm
                  -> 't1)
            -> last_vrf_output:
                 (   't1
                  -> ( [< `Read | `Set_and_create ]
                     , ('u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2) t
                     , 'y1 )
                     Fieldslib.Field.t_with_perm
                  -> 'c2)
            -> total_currency:
                 (   'c2
                  -> ( [< `Read | `Set_and_create ]
                     , ('d2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2) t
                     , 'j2 )
                     Fieldslib.Field.t_with_perm
                  -> 'l2)
            -> curr_global_slot:
                 (   'l2
                  -> ( [< `Read | `Set_and_create ]
                     , ('m2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2) t
                     , 'r2 )
                     Fieldslib.Field.t_with_perm
                  -> 'u2)
            -> global_slot_since_genesis:
                 (   'u2
                  -> ( [< `Read | `Set_and_create ]
                     , ('v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3, 'c3) t
                     , 'a3 )
                     Fieldslib.Field.t_with_perm
                  -> 'd3)
            -> staking_epoch_data:
                 (   'd3
                  -> ( [< `Read | `Set_and_create ]
                     , ('e3, 'f3, 'g3, 'h3, 'i3, 'j3, 'k3, 'l3) t
                     , 'l3 )
                     Fieldslib.Field.t_with_perm
                  -> 'm3)
            -> next_epoch_data:
                 (   'm3
                  -> ( [< `Read | `Set_and_create ]
                     , ('n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3) t
                     , 'u3 )
                     Fieldslib.Field.t_with_perm
                  -> 'v3)
            -> 'v3

          val map_poly :
               ( [< `Read | `Set_and_create ]
               , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
               , 'i )
               Fieldslib.Field.user
            -> 'i list

          val for_all :
               snarked_ledger_hash:
                 (   ( [< `Read | `Set_and_create ]
                     , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                     , 'a )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> snarked_next_available_token:
                 (   ( [< `Read | `Set_and_create ]
                     , ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t
                     , 'j )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> timestamp:
                 (   ( [< `Read | `Set_and_create ]
                     , ('q, 'r, 's, 't, 'u, 'v, 'w, 'x) t
                     , 's )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> blockchain_length:
                 (   ( [< `Read | `Set_and_create ]
                     , ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1) t
                     , 'b1 )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> min_window_density:
                 (   ( [< `Read | `Set_and_create ]
                     , ('g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1) t
                     , 'j1 )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> last_vrf_output:
                 (   ( [< `Read | `Set_and_create ]
                     , ('o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1) t
                     , 's1 )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> total_currency:
                 (   ( [< `Read | `Set_and_create ]
                     , ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
                     , 'c2 )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> curr_global_slot:
                 (   ( [< `Read | `Set_and_create ]
                     , ('e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2) t
                     , 'j2 )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> global_slot_since_genesis:
                 (   ( [< `Read | `Set_and_create ]
                     , ('m2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2) t
                     , 'r2 )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> staking_epoch_data:
                 (   ( [< `Read | `Set_and_create ]
                     , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3) t
                     , 'b3 )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> next_epoch_data:
                 (   ( [< `Read | `Set_and_create ]
                     , ('c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                     , 'j3 )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> bool

          val exists :
               snarked_ledger_hash:
                 (   ( [< `Read | `Set_and_create ]
                     , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                     , 'a )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> snarked_next_available_token:
                 (   ( [< `Read | `Set_and_create ]
                     , ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t
                     , 'j )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> timestamp:
                 (   ( [< `Read | `Set_and_create ]
                     , ('q, 'r, 's, 't, 'u, 'v, 'w, 'x) t
                     , 's )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> blockchain_length:
                 (   ( [< `Read | `Set_and_create ]
                     , ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1) t
                     , 'b1 )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> min_window_density:
                 (   ( [< `Read | `Set_and_create ]
                     , ('g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1) t
                     , 'j1 )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> last_vrf_output:
                 (   ( [< `Read | `Set_and_create ]
                     , ('o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1) t
                     , 's1 )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> total_currency:
                 (   ( [< `Read | `Set_and_create ]
                     , ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
                     , 'c2 )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> curr_global_slot:
                 (   ( [< `Read | `Set_and_create ]
                     , ('e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2) t
                     , 'j2 )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> global_slot_since_genesis:
                 (   ( [< `Read | `Set_and_create ]
                     , ('m2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2) t
                     , 'r2 )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> staking_epoch_data:
                 (   ( [< `Read | `Set_and_create ]
                     , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3) t
                     , 'b3 )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> next_epoch_data:
                 (   ( [< `Read | `Set_and_create ]
                     , ('c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                     , 'j3 )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> bool

          val to_list :
               snarked_ledger_hash:
                 (   ( [< `Read | `Set_and_create ]
                     , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                     , 'a )
                     Fieldslib.Field.t_with_perm
                  -> 'i)
            -> snarked_next_available_token:
                 (   ( [< `Read | `Set_and_create ]
                     , ('j, 'k, 'l, 'm, 'n, 'o, 'p, 'q) t
                     , 'k )
                     Fieldslib.Field.t_with_perm
                  -> 'i)
            -> timestamp:
                 (   ( [< `Read | `Set_and_create ]
                     , ('r, 's, 't, 'u, 'v, 'w, 'x, 'y) t
                     , 't )
                     Fieldslib.Field.t_with_perm
                  -> 'i)
            -> blockchain_length:
                 (   ( [< `Read | `Set_and_create ]
                     , ('z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1) t
                     , 'c1 )
                     Fieldslib.Field.t_with_perm
                  -> 'i)
            -> min_window_density:
                 (   ( [< `Read | `Set_and_create ]
                     , ('h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1) t
                     , 'k1 )
                     Fieldslib.Field.t_with_perm
                  -> 'i)
            -> last_vrf_output:
                 (   ( [< `Read | `Set_and_create ]
                     , ('p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1, 'w1) t
                     , 't1 )
                     Fieldslib.Field.t_with_perm
                  -> 'i)
            -> total_currency:
                 (   ( [< `Read | `Set_and_create ]
                     , ('x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2, 'e2) t
                     , 'd2 )
                     Fieldslib.Field.t_with_perm
                  -> 'i)
            -> curr_global_slot:
                 (   ( [< `Read | `Set_and_create ]
                     , ('f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2) t
                     , 'k2 )
                     Fieldslib.Field.t_with_perm
                  -> 'i)
            -> global_slot_since_genesis:
                 (   ( [< `Read | `Set_and_create ]
                     , ('n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2, 'u2) t
                     , 's2 )
                     Fieldslib.Field.t_with_perm
                  -> 'i)
            -> staking_epoch_data:
                 (   ( [< `Read | `Set_and_create ]
                     , ('v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3, 'c3) t
                     , 'c3 )
                     Fieldslib.Field.t_with_perm
                  -> 'i)
            -> next_epoch_data:
                 (   ( [< `Read | `Set_and_create ]
                     , ('d3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3, 'k3) t
                     , 'k3 )
                     Fieldslib.Field.t_with_perm
                  -> 'i)
            -> 'i list

          module Direct : sig
            val iter :
                 ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
              -> snarked_ledger_hash:
                   (   ( [< `Read | `Set_and_create ]
                       , ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t
                       , 'i )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'a
                    -> unit)
              -> snarked_next_available_token:
                   (   ( [< `Read | `Set_and_create ]
                       , ('q, 'r, 's, 't, 'u, 'v, 'w, 'x) t
                       , 'r )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'b
                    -> unit)
              -> timestamp:
                   (   ( [< `Read | `Set_and_create ]
                       , ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1) t
                       , 'a1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'c
                    -> unit)
              -> blockchain_length:
                   (   ( [< `Read | `Set_and_create ]
                       , ('g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1) t
                       , 'j1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'd
                    -> unit)
              -> min_window_density:
                   (   ( [< `Read | `Set_and_create ]
                       , ('o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1) t
                       , 'r1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'd
                    -> unit)
              -> last_vrf_output:
                   (   ( [< `Read | `Set_and_create ]
                       , ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
                       , 'a2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'e
                    -> unit)
              -> total_currency:
                   (   ( [< `Read | `Set_and_create ]
                       , ('e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2) t
                       , 'k2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'g
                    -> unit)
              -> curr_global_slot:
                   (   ( [< `Read | `Set_and_create ]
                       , ('m2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2) t
                       , 'r2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'f
                    -> unit)
              -> global_slot_since_genesis:
                   (   ( [< `Read | `Set_and_create ]
                       , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3) t
                       , 'z2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'f
                    -> unit)
              -> staking_epoch_data:
                   (   ( [< `Read | `Set_and_create ]
                       , ('c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                       , 'j3 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'h
                    -> unit)
              -> next_epoch_data:
                   (   ( [< `Read | `Set_and_create ]
                       , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3) t
                       , 'r3 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'h
                    -> 's3)
              -> 's3

            val fold :
                 ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
              -> init:'i
              -> snarked_ledger_hash:
                   (   'i
                    -> ( [< `Read | `Set_and_create ]
                       , ('j, 'k, 'l, 'm, 'n, 'o, 'p, 'q) t
                       , 'j )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'a
                    -> 'r)
              -> snarked_next_available_token:
                   (   'r
                    -> ( [< `Read | `Set_and_create ]
                       , ('s, 't, 'u, 'v, 'w, 'x, 'y, 'z) t
                       , 't )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'b
                    -> 'a1)
              -> timestamp:
                   (   'a1
                    -> ( [< `Read | `Set_and_create ]
                       , ('b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1, 'i1) t
                       , 'd1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'c
                    -> 'j1)
              -> blockchain_length:
                   (   'j1
                    -> ( [< `Read | `Set_and_create ]
                       , ('k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1) t
                       , 'n1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'd
                    -> 's1)
              -> min_window_density:
                   (   's1
                    -> ( [< `Read | `Set_and_create ]
                       , ('t1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2) t
                       , 'w1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'd
                    -> 'b2)
              -> last_vrf_output:
                   (   'b2
                    -> ( [< `Read | `Set_and_create ]
                       , ('c2, 'd2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2) t
                       , 'g2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'e
                    -> 'k2)
              -> total_currency:
                   (   'k2
                    -> ( [< `Read | `Set_and_create ]
                       , ('l2, 'm2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2) t
                       , 'r2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'g
                    -> 't2)
              -> curr_global_slot:
                   (   't2
                    -> ( [< `Read | `Set_and_create ]
                       , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3) t
                       , 'z2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'f
                    -> 'c3)
              -> global_slot_since_genesis:
                   (   'c3
                    -> ( [< `Read | `Set_and_create ]
                       , ('d3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3, 'k3) t
                       , 'i3 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'f
                    -> 'l3)
              -> staking_epoch_data:
                   (   'l3
                    -> ( [< `Read | `Set_and_create ]
                       , ('m3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3) t
                       , 't3 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'h
                    -> 'u3)
              -> next_epoch_data:
                   (   'u3
                    -> ( [< `Read | `Set_and_create ]
                       , ('v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4) t
                       , 'c4 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'h
                    -> 'd4)
              -> 'd4

            val for_all :
                 ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
              -> snarked_ledger_hash:
                   (   ( [< `Read | `Set_and_create ]
                       , ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t
                       , 'i )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'a
                    -> bool)
              -> snarked_next_available_token:
                   (   ( [< `Read | `Set_and_create ]
                       , ('q, 'r, 's, 't, 'u, 'v, 'w, 'x) t
                       , 'r )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'b
                    -> bool)
              -> timestamp:
                   (   ( [< `Read | `Set_and_create ]
                       , ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1) t
                       , 'a1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'c
                    -> bool)
              -> blockchain_length:
                   (   ( [< `Read | `Set_and_create ]
                       , ('g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1) t
                       , 'j1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'd
                    -> bool)
              -> min_window_density:
                   (   ( [< `Read | `Set_and_create ]
                       , ('o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1) t
                       , 'r1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'd
                    -> bool)
              -> last_vrf_output:
                   (   ( [< `Read | `Set_and_create ]
                       , ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
                       , 'a2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'e
                    -> bool)
              -> total_currency:
                   (   ( [< `Read | `Set_and_create ]
                       , ('e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2) t
                       , 'k2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'g
                    -> bool)
              -> curr_global_slot:
                   (   ( [< `Read | `Set_and_create ]
                       , ('m2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2) t
                       , 'r2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'f
                    -> bool)
              -> global_slot_since_genesis:
                   (   ( [< `Read | `Set_and_create ]
                       , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3) t
                       , 'z2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'f
                    -> bool)
              -> staking_epoch_data:
                   (   ( [< `Read | `Set_and_create ]
                       , ('c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                       , 'j3 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'h
                    -> bool)
              -> next_epoch_data:
                   (   ( [< `Read | `Set_and_create ]
                       , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3) t
                       , 'r3 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'h
                    -> bool)
              -> bool

            val exists :
                 ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
              -> snarked_ledger_hash:
                   (   ( [< `Read | `Set_and_create ]
                       , ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t
                       , 'i )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'a
                    -> bool)
              -> snarked_next_available_token:
                   (   ( [< `Read | `Set_and_create ]
                       , ('q, 'r, 's, 't, 'u, 'v, 'w, 'x) t
                       , 'r )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'b
                    -> bool)
              -> timestamp:
                   (   ( [< `Read | `Set_and_create ]
                       , ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1) t
                       , 'a1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'c
                    -> bool)
              -> blockchain_length:
                   (   ( [< `Read | `Set_and_create ]
                       , ('g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1) t
                       , 'j1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'd
                    -> bool)
              -> min_window_density:
                   (   ( [< `Read | `Set_and_create ]
                       , ('o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1) t
                       , 'r1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'd
                    -> bool)
              -> last_vrf_output:
                   (   ( [< `Read | `Set_and_create ]
                       , ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
                       , 'a2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'e
                    -> bool)
              -> total_currency:
                   (   ( [< `Read | `Set_and_create ]
                       , ('e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2) t
                       , 'k2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'g
                    -> bool)
              -> curr_global_slot:
                   (   ( [< `Read | `Set_and_create ]
                       , ('m2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2) t
                       , 'r2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'f
                    -> bool)
              -> global_slot_since_genesis:
                   (   ( [< `Read | `Set_and_create ]
                       , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3) t
                       , 'z2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'f
                    -> bool)
              -> staking_epoch_data:
                   (   ( [< `Read | `Set_and_create ]
                       , ('c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                       , 'j3 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'h
                    -> bool)
              -> next_epoch_data:
                   (   ( [< `Read | `Set_and_create ]
                       , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3) t
                       , 'r3 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'h
                    -> bool)
              -> bool

            val to_list :
                 ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
              -> snarked_ledger_hash:
                   (   ( [< `Read | `Set_and_create ]
                       , ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t
                       , 'i )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'a
                    -> 'q)
              -> snarked_next_available_token:
                   (   ( [< `Read | `Set_and_create ]
                       , ('r, 's, 't, 'u, 'v, 'w, 'x, 'y) t
                       , 's )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'b
                    -> 'q)
              -> timestamp:
                   (   ( [< `Read | `Set_and_create ]
                       , ('z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1) t
                       , 'b1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'c
                    -> 'q)
              -> blockchain_length:
                   (   ( [< `Read | `Set_and_create ]
                       , ('h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1) t
                       , 'k1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'd
                    -> 'q)
              -> min_window_density:
                   (   ( [< `Read | `Set_and_create ]
                       , ('p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1, 'w1) t
                       , 's1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'd
                    -> 'q)
              -> last_vrf_output:
                   (   ( [< `Read | `Set_and_create ]
                       , ('x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2, 'e2) t
                       , 'b2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'e
                    -> 'q)
              -> total_currency:
                   (   ( [< `Read | `Set_and_create ]
                       , ('f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2) t
                       , 'l2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'g
                    -> 'q)
              -> curr_global_slot:
                   (   ( [< `Read | `Set_and_create ]
                       , ('n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2, 'u2) t
                       , 's2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'f
                    -> 'q)
              -> global_slot_since_genesis:
                   (   ( [< `Read | `Set_and_create ]
                       , ('v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3, 'c3) t
                       , 'a3 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'f
                    -> 'q)
              -> staking_epoch_data:
                   (   ( [< `Read | `Set_and_create ]
                       , ('d3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3, 'k3) t
                       , 'k3 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'h
                    -> 'q)
              -> next_epoch_data:
                   (   ( [< `Read | `Set_and_create ]
                       , ('l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3) t
                       , 's3 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'h
                    -> 'q)
              -> 'q list

            val map :
                 ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
              -> snarked_ledger_hash:
                   (   ( [< `Read | `Set_and_create ]
                       , ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t
                       , 'i )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'a
                    -> 'q)
              -> snarked_next_available_token:
                   (   ( [< `Read | `Set_and_create ]
                       , ('r, 's, 't, 'u, 'v, 'w, 'x, 'y) t
                       , 's )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'b
                    -> 'z)
              -> timestamp:
                   (   ( [< `Read | `Set_and_create ]
                       , ('a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1) t
                       , 'c1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'c
                    -> 'i1)
              -> blockchain_length:
                   (   ( [< `Read | `Set_and_create ]
                       , ('j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1) t
                       , 'm1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'd
                    -> 'r1)
              -> min_window_density:
                   (   ( [< `Read | `Set_and_create ]
                       , ('s1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1) t
                       , 'v1 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'd
                    -> 'r1)
              -> last_vrf_output:
                   (   ( [< `Read | `Set_and_create ]
                       , ('a2, 'b2, 'c2, 'd2, 'e2, 'f2, 'g2, 'h2) t
                       , 'e2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'e
                    -> 'i2)
              -> total_currency:
                   (   ( [< `Read | `Set_and_create ]
                       , ('j2, 'k2, 'l2, 'm2, 'n2, 'o2, 'p2, 'q2) t
                       , 'p2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'g
                    -> 'r2)
              -> curr_global_slot:
                   (   ( [< `Read | `Set_and_create ]
                       , ('s2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2, 'z2) t
                       , 'x2 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'f
                    -> 'a3)
              -> global_slot_since_genesis:
                   (   ( [< `Read | `Set_and_create ]
                       , ('b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3) t
                       , 'g3 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'f
                    -> 'a3)
              -> staking_epoch_data:
                   (   ( [< `Read | `Set_and_create ]
                       , ('j3, 'k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3) t
                       , 'q3 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'h
                    -> 'r3)
              -> next_epoch_data:
                   (   ( [< `Read | `Set_and_create ]
                       , ('s3, 't3, 'u3, 'v3, 'w3, 'x3, 'y3, 'z3) t
                       , 'z3 )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                    -> 'h
                    -> 'r3)
              -> ('q, 'z, 'i1, 'r1, 'i2, 'a3, 'r2, 'r3) t

            val set_all_mutable_fields : 'a -> unit
          end
        end

        module With_version : sig
          type ( 'snarked_ledger_hash
               , 'token_id
               , 'time
               , 'length
               , 'vrf_output
               , 'global_slot
               , 'amount
               , 'epoch_data )
               typ =
            ( 'snarked_ledger_hash
            , 'token_id
            , 'time
            , 'length
            , 'vrf_output
            , 'global_slot
            , 'amount
            , 'epoch_data )
            t

          val bin_shape_typ :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_typ :
               'snarked_ledger_hash Core_kernel.Bin_prot.Size.sizer
            -> 'token_id Core_kernel.Bin_prot.Size.sizer
            -> 'time Core_kernel.Bin_prot.Size.sizer
            -> 'length Core_kernel.Bin_prot.Size.sizer
            -> 'vrf_output Core_kernel.Bin_prot.Size.sizer
            -> 'global_slot Core_kernel.Bin_prot.Size.sizer
            -> 'amount Core_kernel.Bin_prot.Size.sizer
            -> 'epoch_data Core_kernel.Bin_prot.Size.sizer
            -> ( 'snarked_ledger_hash
               , 'token_id
               , 'time
               , 'length
               , 'vrf_output
               , 'global_slot
               , 'amount
               , 'epoch_data )
               typ
               Core_kernel.Bin_prot.Size.sizer

          val bin_write_typ :
               'snarked_ledger_hash Core_kernel.Bin_prot.Write.writer
            -> 'token_id Core_kernel.Bin_prot.Write.writer
            -> 'time Core_kernel.Bin_prot.Write.writer
            -> 'length Core_kernel.Bin_prot.Write.writer
            -> 'vrf_output Core_kernel.Bin_prot.Write.writer
            -> 'global_slot Core_kernel.Bin_prot.Write.writer
            -> 'amount Core_kernel.Bin_prot.Write.writer
            -> 'epoch_data Core_kernel.Bin_prot.Write.writer
            -> ( 'snarked_ledger_hash
               , 'token_id
               , 'time
               , 'length
               , 'vrf_output
               , 'global_slot
               , 'amount
               , 'epoch_data )
               typ
               Core_kernel.Bin_prot.Write.writer

          val bin_writer_typ :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> 'd Core_kernel.Bin_prot.Type_class.writer
            -> 'e Core_kernel.Bin_prot.Type_class.writer
            -> 'f Core_kernel.Bin_prot.Type_class.writer
            -> 'g Core_kernel.Bin_prot.Type_class.writer
            -> 'h Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) typ
               Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_typ__ :
               'snarked_ledger_hash Core_kernel.Bin_prot.Read.reader
            -> 'token_id Core_kernel.Bin_prot.Read.reader
            -> 'time Core_kernel.Bin_prot.Read.reader
            -> 'length Core_kernel.Bin_prot.Read.reader
            -> 'vrf_output Core_kernel.Bin_prot.Read.reader
            -> 'global_slot Core_kernel.Bin_prot.Read.reader
            -> 'amount Core_kernel.Bin_prot.Read.reader
            -> 'epoch_data Core_kernel.Bin_prot.Read.reader
            -> (   int
                -> ( 'snarked_ledger_hash
                   , 'token_id
                   , 'time
                   , 'length
                   , 'vrf_output
                   , 'global_slot
                   , 'amount
                   , 'epoch_data )
                   typ)
               Core_kernel.Bin_prot.Read.reader

          val bin_read_typ :
               'snarked_ledger_hash Core_kernel.Bin_prot.Read.reader
            -> 'token_id Core_kernel.Bin_prot.Read.reader
            -> 'time Core_kernel.Bin_prot.Read.reader
            -> 'length Core_kernel.Bin_prot.Read.reader
            -> 'vrf_output Core_kernel.Bin_prot.Read.reader
            -> 'global_slot Core_kernel.Bin_prot.Read.reader
            -> 'amount Core_kernel.Bin_prot.Read.reader
            -> 'epoch_data Core_kernel.Bin_prot.Read.reader
            -> ( 'snarked_ledger_hash
               , 'token_id
               , 'time
               , 'length
               , 'vrf_output
               , 'global_slot
               , 'amount
               , 'epoch_data )
               typ
               Core_kernel.Bin_prot.Read.reader

          val bin_reader_typ :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> 'c Core_kernel.Bin_prot.Type_class.reader
            -> 'd Core_kernel.Bin_prot.Type_class.reader
            -> 'e Core_kernel.Bin_prot.Type_class.reader
            -> 'f Core_kernel.Bin_prot.Type_class.reader
            -> 'g Core_kernel.Bin_prot.Type_class.reader
            -> 'h Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) typ
               Core_kernel.Bin_prot.Type_class.reader

          val bin_typ :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> 'd Core_kernel.Bin_prot.Type_class.t
            -> 'e Core_kernel.Bin_prot.Type_class.t
            -> 'f Core_kernel.Bin_prot.Type_class.t
            -> 'g Core_kernel.Bin_prot.Type_class.t
            -> 'h Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) typ
               Core_kernel.Bin_prot.Type_class.t

          type ( 'snarked_ledger_hash
               , 'token_id
               , 'time
               , 'length
               , 'vrf_output
               , 'global_slot
               , 'amount
               , 'epoch_data )
               t =
            { version : int
            ; t :
                ( 'snarked_ledger_hash
                , 'token_id
                , 'time
                , 'length
                , 'vrf_output
                , 'global_slot
                , 'amount
                , 'epoch_data )
                typ
            }

          val bin_shape_t :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_t :
               'snarked_ledger_hash Core_kernel.Bin_prot.Size.sizer
            -> 'token_id Core_kernel.Bin_prot.Size.sizer
            -> 'time Core_kernel.Bin_prot.Size.sizer
            -> 'length Core_kernel.Bin_prot.Size.sizer
            -> 'vrf_output Core_kernel.Bin_prot.Size.sizer
            -> 'global_slot Core_kernel.Bin_prot.Size.sizer
            -> 'amount Core_kernel.Bin_prot.Size.sizer
            -> 'epoch_data Core_kernel.Bin_prot.Size.sizer
            -> ( 'snarked_ledger_hash
               , 'token_id
               , 'time
               , 'length
               , 'vrf_output
               , 'global_slot
               , 'amount
               , 'epoch_data )
               t
               Core_kernel.Bin_prot.Size.sizer

          val bin_write_t :
               'snarked_ledger_hash Core_kernel.Bin_prot.Write.writer
            -> 'token_id Core_kernel.Bin_prot.Write.writer
            -> 'time Core_kernel.Bin_prot.Write.writer
            -> 'length Core_kernel.Bin_prot.Write.writer
            -> 'vrf_output Core_kernel.Bin_prot.Write.writer
            -> 'global_slot Core_kernel.Bin_prot.Write.writer
            -> 'amount Core_kernel.Bin_prot.Write.writer
            -> 'epoch_data Core_kernel.Bin_prot.Write.writer
            -> ( 'snarked_ledger_hash
               , 'token_id
               , 'time
               , 'length
               , 'vrf_output
               , 'global_slot
               , 'amount
               , 'epoch_data )
               t
               Core_kernel.Bin_prot.Write.writer

          val bin_writer_t :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> 'd Core_kernel.Bin_prot.Type_class.writer
            -> 'e Core_kernel.Bin_prot.Type_class.writer
            -> 'f Core_kernel.Bin_prot.Type_class.writer
            -> 'g Core_kernel.Bin_prot.Type_class.writer
            -> 'h Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
               Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_t__ :
               'snarked_ledger_hash Core_kernel.Bin_prot.Read.reader
            -> 'token_id Core_kernel.Bin_prot.Read.reader
            -> 'time Core_kernel.Bin_prot.Read.reader
            -> 'length Core_kernel.Bin_prot.Read.reader
            -> 'vrf_output Core_kernel.Bin_prot.Read.reader
            -> 'global_slot Core_kernel.Bin_prot.Read.reader
            -> 'amount Core_kernel.Bin_prot.Read.reader
            -> 'epoch_data Core_kernel.Bin_prot.Read.reader
            -> (   int
                -> ( 'snarked_ledger_hash
                   , 'token_id
                   , 'time
                   , 'length
                   , 'vrf_output
                   , 'global_slot
                   , 'amount
                   , 'epoch_data )
                   t)
               Core_kernel.Bin_prot.Read.reader

          val bin_read_t :
               'snarked_ledger_hash Core_kernel.Bin_prot.Read.reader
            -> 'token_id Core_kernel.Bin_prot.Read.reader
            -> 'time Core_kernel.Bin_prot.Read.reader
            -> 'length Core_kernel.Bin_prot.Read.reader
            -> 'vrf_output Core_kernel.Bin_prot.Read.reader
            -> 'global_slot Core_kernel.Bin_prot.Read.reader
            -> 'amount Core_kernel.Bin_prot.Read.reader
            -> 'epoch_data Core_kernel.Bin_prot.Read.reader
            -> ( 'snarked_ledger_hash
               , 'token_id
               , 'time
               , 'length
               , 'vrf_output
               , 'global_slot
               , 'amount
               , 'epoch_data )
               t
               Core_kernel.Bin_prot.Read.reader

          val bin_reader_t :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> 'c Core_kernel.Bin_prot.Type_class.reader
            -> 'd Core_kernel.Bin_prot.Type_class.reader
            -> 'e Core_kernel.Bin_prot.Type_class.reader
            -> 'f Core_kernel.Bin_prot.Type_class.reader
            -> 'g Core_kernel.Bin_prot.Type_class.reader
            -> 'h Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
               Core_kernel.Bin_prot.Type_class.reader

          val bin_t :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> 'd Core_kernel.Bin_prot.Type_class.t
            -> 'e Core_kernel.Bin_prot.Type_class.t
            -> 'f Core_kernel.Bin_prot.Type_class.t
            -> 'g Core_kernel.Bin_prot.Type_class.t
            -> 'h Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
               Core_kernel.Bin_prot.Type_class.t

          val create :
               ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) typ
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
        end

        val bin_read_t :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'b Core_kernel.Bin_prot.Read.reader
          -> 'c Core_kernel.Bin_prot.Read.reader
          -> 'd Core_kernel.Bin_prot.Read.reader
          -> 'e Core_kernel.Bin_prot.Read.reader
          -> 'f Core_kernel.Bin_prot.Read.reader
          -> 'g Core_kernel.Bin_prot.Read.reader
          -> 'h Core_kernel.Bin_prot.Read.reader
          -> Bin_prot.Common.buf
          -> pos_ref:Bin_prot.Common.pos_ref
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t

        val __bin_read_t__ :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'b Core_kernel.Bin_prot.Read.reader
          -> 'c Core_kernel.Bin_prot.Read.reader
          -> 'd Core_kernel.Bin_prot.Read.reader
          -> 'e Core_kernel.Bin_prot.Read.reader
          -> 'f Core_kernel.Bin_prot.Read.reader
          -> 'g Core_kernel.Bin_prot.Read.reader
          -> 'h Core_kernel.Bin_prot.Read.reader
          -> Bin_prot.Common.buf
          -> pos_ref:Bin_prot.Common.pos_ref
          -> int
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t

        val bin_size_t :
             'a Core_kernel.Bin_prot.Size.sizer
          -> 'b Core_kernel.Bin_prot.Size.sizer
          -> 'c Core_kernel.Bin_prot.Size.sizer
          -> 'd Core_kernel.Bin_prot.Size.sizer
          -> 'e Core_kernel.Bin_prot.Size.sizer
          -> 'f Core_kernel.Bin_prot.Size.sizer
          -> 'g Core_kernel.Bin_prot.Size.sizer
          -> 'h Core_kernel.Bin_prot.Size.sizer
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
          -> int

        val bin_write_t :
             'a Core_kernel.Bin_prot.Write.writer
          -> 'b Core_kernel.Bin_prot.Write.writer
          -> 'c Core_kernel.Bin_prot.Write.writer
          -> 'd Core_kernel.Bin_prot.Write.writer
          -> 'e Core_kernel.Bin_prot.Write.writer
          -> 'f Core_kernel.Bin_prot.Write.writer
          -> 'g Core_kernel.Bin_prot.Write.writer
          -> 'h Core_kernel.Bin_prot.Write.writer
          -> Bin_prot.Common.buf
          -> pos:Bin_prot.Common.pos
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
          -> Bin_prot.Common.pos

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_reader_t :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> 'c Core_kernel.Bin_prot.Type_class.reader
          -> 'd Core_kernel.Bin_prot.Type_class.reader
          -> 'e Core_kernel.Bin_prot.Type_class.reader
          -> 'f Core_kernel.Bin_prot.Type_class.reader
          -> 'g Core_kernel.Bin_prot.Type_class.reader
          -> 'h Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
             Core_kernel.Bin_prot.Type_class.reader

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> 'd Core_kernel.Bin_prot.Type_class.writer
          -> 'e Core_kernel.Bin_prot.Type_class.writer
          -> 'f Core_kernel.Bin_prot.Type_class.writer
          -> 'g Core_kernel.Bin_prot.Type_class.writer
          -> 'h Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
             Core_kernel.Bin_prot.Type_class.writer

        val bin_t :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> 'c Core_kernel.Bin_prot.Type_class.t
          -> 'd Core_kernel.Bin_prot.Type_class.t
          -> 'e Core_kernel.Bin_prot.Type_class.t
          -> 'f Core_kernel.Bin_prot.Type_class.t
          -> 'g Core_kernel.Bin_prot.Type_class.t
          -> 'h Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
             Core_kernel.Bin_prot.Type_class.t

        val __ :
          (   'a Core_kernel.Bin_prot.Read.reader
           -> 'b Core_kernel.Bin_prot.Read.reader
           -> 'c Core_kernel.Bin_prot.Read.reader
           -> 'd Core_kernel.Bin_prot.Read.reader
           -> 'e Core_kernel.Bin_prot.Read.reader
           -> 'f Core_kernel.Bin_prot.Read.reader
           -> 'g Core_kernel.Bin_prot.Read.reader
           -> 'h Core_kernel.Bin_prot.Read.reader
           -> Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t)
          * (   'i Core_kernel.Bin_prot.Read.reader
             -> 'j Core_kernel.Bin_prot.Read.reader
             -> 'k Core_kernel.Bin_prot.Read.reader
             -> 'l Core_kernel.Bin_prot.Read.reader
             -> 'm Core_kernel.Bin_prot.Read.reader
             -> 'n Core_kernel.Bin_prot.Read.reader
             -> 'o Core_kernel.Bin_prot.Read.reader
             -> 'p Core_kernel.Bin_prot.Read.reader
             -> Bin_prot.Common.buf
             -> pos_ref:Bin_prot.Common.pos_ref
             -> int
             -> ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t)
          * (   'q Core_kernel.Bin_prot.Size.sizer
             -> 'r Core_kernel.Bin_prot.Size.sizer
             -> 's Core_kernel.Bin_prot.Size.sizer
             -> 't Core_kernel.Bin_prot.Size.sizer
             -> 'u Core_kernel.Bin_prot.Size.sizer
             -> 'v Core_kernel.Bin_prot.Size.sizer
             -> 'w Core_kernel.Bin_prot.Size.sizer
             -> 'x Core_kernel.Bin_prot.Size.sizer
             -> ('q, 'r, 's, 't, 'u, 'v, 'w, 'x) t
             -> int)
          * (   'y Core_kernel.Bin_prot.Write.writer
             -> 'z Core_kernel.Bin_prot.Write.writer
             -> 'a1 Core_kernel.Bin_prot.Write.writer
             -> 'b1 Core_kernel.Bin_prot.Write.writer
             -> 'c1 Core_kernel.Bin_prot.Write.writer
             -> 'd1 Core_kernel.Bin_prot.Write.writer
             -> 'e1 Core_kernel.Bin_prot.Write.writer
             -> 'f1 Core_kernel.Bin_prot.Write.writer
             -> Bin_prot.Common.buf
             -> pos:Bin_prot.Common.pos
             -> ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1) t
             -> Bin_prot.Common.pos)
          * (   Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t)
          * (   'g1 Core_kernel.Bin_prot.Type_class.reader
             -> 'h1 Core_kernel.Bin_prot.Type_class.reader
             -> 'i1 Core_kernel.Bin_prot.Type_class.reader
             -> 'j1 Core_kernel.Bin_prot.Type_class.reader
             -> 'k1 Core_kernel.Bin_prot.Type_class.reader
             -> 'l1 Core_kernel.Bin_prot.Type_class.reader
             -> 'm1 Core_kernel.Bin_prot.Type_class.reader
             -> 'n1 Core_kernel.Bin_prot.Type_class.reader
             -> ('g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1) t
                Core_kernel.Bin_prot.Type_class.reader)
          * (   'o1 Core_kernel.Bin_prot.Type_class.writer
             -> 'p1 Core_kernel.Bin_prot.Type_class.writer
             -> 'q1 Core_kernel.Bin_prot.Type_class.writer
             -> 'r1 Core_kernel.Bin_prot.Type_class.writer
             -> 's1 Core_kernel.Bin_prot.Type_class.writer
             -> 't1 Core_kernel.Bin_prot.Type_class.writer
             -> 'u1 Core_kernel.Bin_prot.Type_class.writer
             -> 'v1 Core_kernel.Bin_prot.Type_class.writer
             -> ('o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1) t
                Core_kernel.Bin_prot.Type_class.writer)
          * (   'w1 Core_kernel.Bin_prot.Type_class.t
             -> 'x1 Core_kernel.Bin_prot.Type_class.t
             -> 'y1 Core_kernel.Bin_prot.Type_class.t
             -> 'z1 Core_kernel.Bin_prot.Type_class.t
             -> 'a2 Core_kernel.Bin_prot.Type_class.t
             -> 'b2 Core_kernel.Bin_prot.Type_class.t
             -> 'c2 Core_kernel.Bin_prot.Type_class.t
             -> 'd2 Core_kernel.Bin_prot.Type_class.t
             -> ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
                Core_kernel.Bin_prot.Type_class.t)
      end

      module Latest = V1
    end

    type ( 'snarked_ledger_hash
         , 'token_id
         , 'time
         , 'length
         , 'vrf_output
         , 'global_slot
         , 'amount
         , 'epoch_data )
         t =
          ( 'snarked_ledger_hash
          , 'token_id
          , 'time
          , 'length
          , 'vrf_output
          , 'global_slot
          , 'amount
          , 'epoch_data )
          Stable.V1.t =
      { snarked_ledger_hash : 'snarked_ledger_hash
      ; snarked_next_available_token : 'token_id
      ; timestamp : 'time
      ; blockchain_length : 'length
      ; min_window_density : 'length
      ; last_vrf_output : 'vrf_output
      ; total_currency : 'amount
      ; curr_global_slot : 'global_slot
      ; global_slot_since_genesis : 'global_slot
      ; staking_epoch_data : 'epoch_data
      ; next_epoch_data : 'epoch_data
      }

    val to_yojson :
         ('snarked_ledger_hash -> Yojson.Safe.t)
      -> ('token_id -> Yojson.Safe.t)
      -> ('time -> Yojson.Safe.t)
      -> ('length -> Yojson.Safe.t)
      -> ('vrf_output -> Yojson.Safe.t)
      -> ('global_slot -> Yojson.Safe.t)
      -> ('amount -> Yojson.Safe.t)
      -> ('epoch_data -> Yojson.Safe.t)
      -> ( 'snarked_ledger_hash
         , 'token_id
         , 'time
         , 'length
         , 'vrf_output
         , 'global_slot
         , 'amount
         , 'epoch_data )
         t
      -> Yojson.Safe.t

    val of_yojson :
         (   Yojson.Safe.t
          -> 'snarked_ledger_hash Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'token_id Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'time Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'length Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'vrf_output Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'global_slot Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'amount Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'epoch_data Ppx_deriving_yojson_runtime.error_or)
      -> Yojson.Safe.t
      -> ( 'snarked_ledger_hash
         , 'token_id
         , 'time
         , 'length
         , 'vrf_output
         , 'global_slot
         , 'amount
         , 'epoch_data )
         t
         Ppx_deriving_yojson_runtime.error_or

    val to_hlist :
         ( 'snarked_ledger_hash
         , 'token_id
         , 'time
         , 'length
         , 'vrf_output
         , 'global_slot
         , 'amount
         , 'epoch_data )
         t
      -> ( unit
         ,    'snarked_ledger_hash
           -> 'token_id
           -> 'time
           -> 'length
           -> 'length
           -> 'vrf_output
           -> 'amount
           -> 'global_slot
           -> 'global_slot
           -> 'epoch_data
           -> 'epoch_data
           -> unit )
         H_list.t

    val of_hlist :
         ( unit
         ,    'snarked_ledger_hash
           -> 'token_id
           -> 'time
           -> 'length
           -> 'length
           -> 'vrf_output
           -> 'amount
           -> 'global_slot
           -> 'global_slot
           -> 'epoch_data
           -> 'epoch_data
           -> unit )
         H_list.t
      -> ( 'snarked_ledger_hash
         , 'token_id
         , 'time
         , 'length
         , 'vrf_output
         , 'global_slot
         , 'amount
         , 'epoch_data )
         t

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'snarked_ledger_hash)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'token_id)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'time)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'length)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'vrf_output)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'global_slot)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'amount)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'epoch_data)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> ( 'snarked_ledger_hash
         , 'token_id
         , 'time
         , 'length
         , 'vrf_output
         , 'global_slot
         , 'amount
         , 'epoch_data )
         t

    val sexp_of_t :
         ('snarked_ledger_hash -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('token_id -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('time -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('length -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('vrf_output -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('global_slot -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('amount -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('epoch_data -> Ppx_sexp_conv_lib.Sexp.t)
      -> ( 'snarked_ledger_hash
         , 'token_id
         , 'time
         , 'length
         , 'vrf_output
         , 'global_slot
         , 'amount
         , 'epoch_data )
         t
      -> Ppx_sexp_conv_lib.Sexp.t

    val equal :
         ('snarked_ledger_hash -> 'snarked_ledger_hash -> bool)
      -> ('token_id -> 'token_id -> bool)
      -> ('time -> 'time -> bool)
      -> ('length -> 'length -> bool)
      -> ('vrf_output -> 'vrf_output -> bool)
      -> ('global_slot -> 'global_slot -> bool)
      -> ('amount -> 'amount -> bool)
      -> ('epoch_data -> 'epoch_data -> bool)
      -> ( 'snarked_ledger_hash
         , 'token_id
         , 'time
         , 'length
         , 'vrf_output
         , 'global_slot
         , 'amount
         , 'epoch_data )
         t
      -> ( 'snarked_ledger_hash
         , 'token_id
         , 'time
         , 'length
         , 'vrf_output
         , 'global_slot
         , 'amount
         , 'epoch_data )
         t
      -> bool

    val hash_fold_t :
         (   Ppx_hash_lib.Std.Hash.state
          -> 'snarked_ledger_hash
          -> Ppx_hash_lib.Std.Hash.state)
      -> (   Ppx_hash_lib.Std.Hash.state
          -> 'token_id
          -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'time -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'length -> Ppx_hash_lib.Std.Hash.state)
      -> (   Ppx_hash_lib.Std.Hash.state
          -> 'vrf_output
          -> Ppx_hash_lib.Std.Hash.state)
      -> (   Ppx_hash_lib.Std.Hash.state
          -> 'global_slot
          -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'amount -> Ppx_hash_lib.Std.Hash.state)
      -> (   Ppx_hash_lib.Std.Hash.state
          -> 'epoch_data
          -> Ppx_hash_lib.Std.Hash.state)
      -> Ppx_hash_lib.Std.Hash.state
      -> ( 'snarked_ledger_hash
         , 'token_id
         , 'time
         , 'length
         , 'vrf_output
         , 'global_slot
         , 'amount
         , 'epoch_data )
         t
      -> Ppx_hash_lib.Std.Hash.state

    val compare :
         ('snarked_ledger_hash -> 'snarked_ledger_hash -> int)
      -> ('token_id -> 'token_id -> int)
      -> ('time -> 'time -> int)
      -> ('length -> 'length -> int)
      -> ('vrf_output -> 'vrf_output -> int)
      -> ('global_slot -> 'global_slot -> int)
      -> ('amount -> 'amount -> int)
      -> ('epoch_data -> 'epoch_data -> int)
      -> ( 'snarked_ledger_hash
         , 'token_id
         , 'time
         , 'length
         , 'vrf_output
         , 'global_slot
         , 'amount
         , 'epoch_data )
         t
      -> ( 'snarked_ledger_hash
         , 'token_id
         , 'time
         , 'length
         , 'vrf_output
         , 'global_slot
         , 'amount
         , 'epoch_data )
         t
      -> int

    val next_epoch_data : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'h

    val staking_epoch_data : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'h

    val global_slot_since_genesis : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'f

    val curr_global_slot : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'f

    val total_currency : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'g

    val last_vrf_output : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'e

    val min_window_density : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'd

    val blockchain_length : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'd

    val timestamp : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'c

    val snarked_next_available_token : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'b

    val snarked_ledger_hash : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t -> 'a

    module Fields : sig
      val names : string list

      val next_epoch_data :
        ( [< `Read | `Set_and_create ]
        , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'epoch_data) t
        , 'epoch_data )
        Fieldslib.Field.t_with_perm

      val staking_epoch_data :
        ( [< `Read | `Set_and_create ]
        , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'epoch_data) t
        , 'epoch_data )
        Fieldslib.Field.t_with_perm

      val global_slot_since_genesis :
        ( [< `Read | `Set_and_create ]
        , ('a, 'b, 'c, 'd, 'e, 'global_slot, 'f, 'g) t
        , 'global_slot )
        Fieldslib.Field.t_with_perm

      val curr_global_slot :
        ( [< `Read | `Set_and_create ]
        , ('a, 'b, 'c, 'd, 'e, 'global_slot, 'f, 'g) t
        , 'global_slot )
        Fieldslib.Field.t_with_perm

      val total_currency :
        ( [< `Read | `Set_and_create ]
        , ('a, 'b, 'c, 'd, 'e, 'f, 'amount, 'g) t
        , 'amount )
        Fieldslib.Field.t_with_perm

      val last_vrf_output :
        ( [< `Read | `Set_and_create ]
        , ('a, 'b, 'c, 'd, 'vrf_output, 'e, 'f, 'g) t
        , 'vrf_output )
        Fieldslib.Field.t_with_perm

      val min_window_density :
        ( [< `Read | `Set_and_create ]
        , ('a, 'b, 'c, 'length, 'd, 'e, 'f, 'g) t
        , 'length )
        Fieldslib.Field.t_with_perm

      val blockchain_length :
        ( [< `Read | `Set_and_create ]
        , ('a, 'b, 'c, 'length, 'd, 'e, 'f, 'g) t
        , 'length )
        Fieldslib.Field.t_with_perm

      val timestamp :
        ( [< `Read | `Set_and_create ]
        , ('a, 'b, 'time, 'c, 'd, 'e, 'f, 'g) t
        , 'time )
        Fieldslib.Field.t_with_perm

      val snarked_next_available_token :
        ( [< `Read | `Set_and_create ]
        , ('a, 'token_id, 'b, 'c, 'd, 'e, 'f, 'g) t
        , 'token_id )
        Fieldslib.Field.t_with_perm

      val snarked_ledger_hash :
        ( [< `Read | `Set_and_create ]
        , ('snarked_ledger_hash, 'a, 'b, 'c, 'd, 'e, 'f, 'g) t
        , 'snarked_ledger_hash )
        Fieldslib.Field.t_with_perm

      val make_creator :
           snarked_ledger_hash:
             (   ( [< `Read | `Set_and_create ]
                 , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> 'i
              -> ('j -> 'k) * 'l)
        -> snarked_next_available_token:
             (   ( [< `Read | `Set_and_create ]
                 , ('m, 'n, 'o, 'p, 'q, 'r, 's, 't) t
                 , 'n )
                 Fieldslib.Field.t_with_perm
              -> 'l
              -> ('j -> 'u) * 'v)
        -> timestamp:
             (   ( [< `Read | `Set_and_create ]
                 , ('w, 'x, 'y, 'z, 'a1, 'b1, 'c1, 'd1) t
                 , 'y )
                 Fieldslib.Field.t_with_perm
              -> 'v
              -> ('j -> 'e1) * 'f1)
        -> blockchain_length:
             (   ( [< `Read | `Set_and_create ]
                 , ('g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1) t
                 , 'j1 )
                 Fieldslib.Field.t_with_perm
              -> 'f1
              -> ('j -> 'o1) * 'p1)
        -> min_window_density:
             (   ( [< `Read | `Set_and_create ]
                 , ('q1, 'r1, 's1, 't1, 'u1, 'v1, 'w1, 'x1) t
                 , 't1 )
                 Fieldslib.Field.t_with_perm
              -> 'p1
              -> ('j -> 'o1) * 'y1)
        -> last_vrf_output:
             (   ( [< `Read | `Set_and_create ]
                 , ('z1, 'a2, 'b2, 'c2, 'd2, 'e2, 'f2, 'g2) t
                 , 'd2 )
                 Fieldslib.Field.t_with_perm
              -> 'y1
              -> ('j -> 'h2) * 'i2)
        -> total_currency:
             (   ( [< `Read | `Set_and_create ]
                 , ('j2, 'k2, 'l2, 'm2, 'n2, 'o2, 'p2, 'q2) t
                 , 'p2 )
                 Fieldslib.Field.t_with_perm
              -> 'i2
              -> ('j -> 'r2) * 's2)
        -> curr_global_slot:
             (   ( [< `Read | `Set_and_create ]
                 , ('t2, 'u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3) t
                 , 'y2 )
                 Fieldslib.Field.t_with_perm
              -> 's2
              -> ('j -> 'b3) * 'c3)
        -> global_slot_since_genesis:
             (   ( [< `Read | `Set_and_create ]
                 , ('d3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3, 'k3) t
                 , 'i3 )
                 Fieldslib.Field.t_with_perm
              -> 'c3
              -> ('j -> 'b3) * 'l3)
        -> staking_epoch_data:
             (   ( [< `Read | `Set_and_create ]
                 , ('m3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3) t
                 , 't3 )
                 Fieldslib.Field.t_with_perm
              -> 'l3
              -> ('j -> 'u3) * 'v3)
        -> next_epoch_data:
             (   ( [< `Read | `Set_and_create ]
                 , ('w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4) t
                 , 'd4 )
                 Fieldslib.Field.t_with_perm
              -> 'v3
              -> ('j -> 'u3) * 'e4)
        -> 'i
        -> ('j -> ('k, 'u, 'e1, 'o1, 'h2, 'b3, 'r2, 'u3) t) * 'e4

      val create :
           snarked_ledger_hash:'a
        -> snarked_next_available_token:'b
        -> timestamp:'c
        -> blockchain_length:'d
        -> min_window_density:'d
        -> last_vrf_output:'e
        -> total_currency:'f
        -> curr_global_slot:'g
        -> global_slot_since_genesis:'g
        -> staking_epoch_data:'h
        -> next_epoch_data:'h
        -> ('a, 'b, 'c, 'd, 'e, 'g, 'f, 'h) t

      val map :
           snarked_ledger_hash:
             (   ( [< `Read | `Set_and_create ]
                 , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> 'i)
        -> snarked_next_available_token:
             (   ( [< `Read | `Set_and_create ]
                 , ('j, 'k, 'l, 'm, 'n, 'o, 'p, 'q) t
                 , 'k )
                 Fieldslib.Field.t_with_perm
              -> 'r)
        -> timestamp:
             (   ( [< `Read | `Set_and_create ]
                 , ('s, 't, 'u, 'v, 'w, 'x, 'y, 'z) t
                 , 'u )
                 Fieldslib.Field.t_with_perm
              -> 'a1)
        -> blockchain_length:
             (   ( [< `Read | `Set_and_create ]
                 , ('b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1, 'i1) t
                 , 'e1 )
                 Fieldslib.Field.t_with_perm
              -> 'j1)
        -> min_window_density:
             (   ( [< `Read | `Set_and_create ]
                 , ('k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1) t
                 , 'n1 )
                 Fieldslib.Field.t_with_perm
              -> 'j1)
        -> last_vrf_output:
             (   ( [< `Read | `Set_and_create ]
                 , ('s1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1) t
                 , 'w1 )
                 Fieldslib.Field.t_with_perm
              -> 'a2)
        -> total_currency:
             (   ( [< `Read | `Set_and_create ]
                 , ('b2, 'c2, 'd2, 'e2, 'f2, 'g2, 'h2, 'i2) t
                 , 'h2 )
                 Fieldslib.Field.t_with_perm
              -> 'j2)
        -> curr_global_slot:
             (   ( [< `Read | `Set_and_create ]
                 , ('k2, 'l2, 'm2, 'n2, 'o2, 'p2, 'q2, 'r2) t
                 , 'p2 )
                 Fieldslib.Field.t_with_perm
              -> 's2)
        -> global_slot_since_genesis:
             (   ( [< `Read | `Set_and_create ]
                 , ('t2, 'u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3) t
                 , 'y2 )
                 Fieldslib.Field.t_with_perm
              -> 's2)
        -> staking_epoch_data:
             (   ( [< `Read | `Set_and_create ]
                 , ('b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3) t
                 , 'i3 )
                 Fieldslib.Field.t_with_perm
              -> 'j3)
        -> next_epoch_data:
             (   ( [< `Read | `Set_and_create ]
                 , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3) t
                 , 'r3 )
                 Fieldslib.Field.t_with_perm
              -> 'j3)
        -> ('i, 'r, 'a1, 'j1, 'a2, 's2, 'j2, 'j3) t

      val iter :
           snarked_ledger_hash:
             (   ( [< `Read | `Set_and_create ]
                 , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> snarked_next_available_token:
             (   ( [< `Read | `Set_and_create ]
                 , ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t
                 , 'j )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> timestamp:
             (   ( [< `Read | `Set_and_create ]
                 , ('q, 'r, 's, 't, 'u, 'v, 'w, 'x) t
                 , 's )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> blockchain_length:
             (   ( [< `Read | `Set_and_create ]
                 , ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1) t
                 , 'b1 )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> min_window_density:
             (   ( [< `Read | `Set_and_create ]
                 , ('g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1) t
                 , 'j1 )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> last_vrf_output:
             (   ( [< `Read | `Set_and_create ]
                 , ('o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1) t
                 , 's1 )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> total_currency:
             (   ( [< `Read | `Set_and_create ]
                 , ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
                 , 'c2 )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> curr_global_slot:
             (   ( [< `Read | `Set_and_create ]
                 , ('e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2) t
                 , 'j2 )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> global_slot_since_genesis:
             (   ( [< `Read | `Set_and_create ]
                 , ('m2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2) t
                 , 'r2 )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> staking_epoch_data:
             (   ( [< `Read | `Set_and_create ]
                 , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3) t
                 , 'b3 )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> next_epoch_data:
             (   ( [< `Read | `Set_and_create ]
                 , ('c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                 , 'j3 )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> unit

      val fold :
           init:'a
        -> snarked_ledger_hash:
             (   'a
              -> ( [< `Read | `Set_and_create ]
                 , ('b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
                 , 'b )
                 Fieldslib.Field.t_with_perm
              -> 'j)
        -> snarked_next_available_token:
             (   'j
              -> ( [< `Read | `Set_and_create ]
                 , ('k, 'l, 'm, 'n, 'o, 'p, 'q, 'r) t
                 , 'l )
                 Fieldslib.Field.t_with_perm
              -> 's)
        -> timestamp:
             (   's
              -> ( [< `Read | `Set_and_create ]
                 , ('t, 'u, 'v, 'w, 'x, 'y, 'z, 'a1) t
                 , 'v )
                 Fieldslib.Field.t_with_perm
              -> 'b1)
        -> blockchain_length:
             (   'b1
              -> ( [< `Read | `Set_and_create ]
                 , ('c1, 'd1, 'e1, 'f1, 'g1, 'h1, 'i1, 'j1) t
                 , 'f1 )
                 Fieldslib.Field.t_with_perm
              -> 'k1)
        -> min_window_density:
             (   'k1
              -> ( [< `Read | `Set_and_create ]
                 , ('l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1, 's1) t
                 , 'o1 )
                 Fieldslib.Field.t_with_perm
              -> 't1)
        -> last_vrf_output:
             (   't1
              -> ( [< `Read | `Set_and_create ]
                 , ('u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2) t
                 , 'y1 )
                 Fieldslib.Field.t_with_perm
              -> 'c2)
        -> total_currency:
             (   'c2
              -> ( [< `Read | `Set_and_create ]
                 , ('d2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2) t
                 , 'j2 )
                 Fieldslib.Field.t_with_perm
              -> 'l2)
        -> curr_global_slot:
             (   'l2
              -> ( [< `Read | `Set_and_create ]
                 , ('m2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2) t
                 , 'r2 )
                 Fieldslib.Field.t_with_perm
              -> 'u2)
        -> global_slot_since_genesis:
             (   'u2
              -> ( [< `Read | `Set_and_create ]
                 , ('v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3, 'c3) t
                 , 'a3 )
                 Fieldslib.Field.t_with_perm
              -> 'd3)
        -> staking_epoch_data:
             (   'd3
              -> ( [< `Read | `Set_and_create ]
                 , ('e3, 'f3, 'g3, 'h3, 'i3, 'j3, 'k3, 'l3) t
                 , 'l3 )
                 Fieldslib.Field.t_with_perm
              -> 'm3)
        -> next_epoch_data:
             (   'm3
              -> ( [< `Read | `Set_and_create ]
                 , ('n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3) t
                 , 'u3 )
                 Fieldslib.Field.t_with_perm
              -> 'v3)
        -> 'v3

      val map_poly :
           ( [< `Read | `Set_and_create ]
           , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
           , 'i )
           Fieldslib.Field.user
        -> 'i list

      val for_all :
           snarked_ledger_hash:
             (   ( [< `Read | `Set_and_create ]
                 , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> snarked_next_available_token:
             (   ( [< `Read | `Set_and_create ]
                 , ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t
                 , 'j )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> timestamp:
             (   ( [< `Read | `Set_and_create ]
                 , ('q, 'r, 's, 't, 'u, 'v, 'w, 'x) t
                 , 's )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> blockchain_length:
             (   ( [< `Read | `Set_and_create ]
                 , ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1) t
                 , 'b1 )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> min_window_density:
             (   ( [< `Read | `Set_and_create ]
                 , ('g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1) t
                 , 'j1 )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> last_vrf_output:
             (   ( [< `Read | `Set_and_create ]
                 , ('o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1) t
                 , 's1 )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> total_currency:
             (   ( [< `Read | `Set_and_create ]
                 , ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
                 , 'c2 )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> curr_global_slot:
             (   ( [< `Read | `Set_and_create ]
                 , ('e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2) t
                 , 'j2 )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> global_slot_since_genesis:
             (   ( [< `Read | `Set_and_create ]
                 , ('m2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2) t
                 , 'r2 )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> staking_epoch_data:
             (   ( [< `Read | `Set_and_create ]
                 , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3) t
                 , 'b3 )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> next_epoch_data:
             (   ( [< `Read | `Set_and_create ]
                 , ('c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                 , 'j3 )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val exists :
           snarked_ledger_hash:
             (   ( [< `Read | `Set_and_create ]
                 , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> snarked_next_available_token:
             (   ( [< `Read | `Set_and_create ]
                 , ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t
                 , 'j )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> timestamp:
             (   ( [< `Read | `Set_and_create ]
                 , ('q, 'r, 's, 't, 'u, 'v, 'w, 'x) t
                 , 's )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> blockchain_length:
             (   ( [< `Read | `Set_and_create ]
                 , ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1) t
                 , 'b1 )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> min_window_density:
             (   ( [< `Read | `Set_and_create ]
                 , ('g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1) t
                 , 'j1 )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> last_vrf_output:
             (   ( [< `Read | `Set_and_create ]
                 , ('o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1) t
                 , 's1 )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> total_currency:
             (   ( [< `Read | `Set_and_create ]
                 , ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
                 , 'c2 )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> curr_global_slot:
             (   ( [< `Read | `Set_and_create ]
                 , ('e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2) t
                 , 'j2 )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> global_slot_since_genesis:
             (   ( [< `Read | `Set_and_create ]
                 , ('m2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2) t
                 , 'r2 )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> staking_epoch_data:
             (   ( [< `Read | `Set_and_create ]
                 , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3) t
                 , 'b3 )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> next_epoch_data:
             (   ( [< `Read | `Set_and_create ]
                 , ('c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                 , 'j3 )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val to_list :
           snarked_ledger_hash:
             (   ( [< `Read | `Set_and_create ]
                 , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> 'i)
        -> snarked_next_available_token:
             (   ( [< `Read | `Set_and_create ]
                 , ('j, 'k, 'l, 'm, 'n, 'o, 'p, 'q) t
                 , 'k )
                 Fieldslib.Field.t_with_perm
              -> 'i)
        -> timestamp:
             (   ( [< `Read | `Set_and_create ]
                 , ('r, 's, 't, 'u, 'v, 'w, 'x, 'y) t
                 , 't )
                 Fieldslib.Field.t_with_perm
              -> 'i)
        -> blockchain_length:
             (   ( [< `Read | `Set_and_create ]
                 , ('z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1) t
                 , 'c1 )
                 Fieldslib.Field.t_with_perm
              -> 'i)
        -> min_window_density:
             (   ( [< `Read | `Set_and_create ]
                 , ('h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1) t
                 , 'k1 )
                 Fieldslib.Field.t_with_perm
              -> 'i)
        -> last_vrf_output:
             (   ( [< `Read | `Set_and_create ]
                 , ('p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1, 'w1) t
                 , 't1 )
                 Fieldslib.Field.t_with_perm
              -> 'i)
        -> total_currency:
             (   ( [< `Read | `Set_and_create ]
                 , ('x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2, 'e2) t
                 , 'd2 )
                 Fieldslib.Field.t_with_perm
              -> 'i)
        -> curr_global_slot:
             (   ( [< `Read | `Set_and_create ]
                 , ('f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2) t
                 , 'k2 )
                 Fieldslib.Field.t_with_perm
              -> 'i)
        -> global_slot_since_genesis:
             (   ( [< `Read | `Set_and_create ]
                 , ('n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2, 'u2) t
                 , 's2 )
                 Fieldslib.Field.t_with_perm
              -> 'i)
        -> staking_epoch_data:
             (   ( [< `Read | `Set_and_create ]
                 , ('v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3, 'c3) t
                 , 'c3 )
                 Fieldslib.Field.t_with_perm
              -> 'i)
        -> next_epoch_data:
             (   ( [< `Read | `Set_and_create ]
                 , ('d3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3, 'k3) t
                 , 'k3 )
                 Fieldslib.Field.t_with_perm
              -> 'i)
        -> 'i list

      module Direct : sig
        val iter :
             ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
          -> snarked_ledger_hash:
               (   ( [< `Read | `Set_and_create ]
                   , ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t
                   , 'i )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'a
                -> unit)
          -> snarked_next_available_token:
               (   ( [< `Read | `Set_and_create ]
                   , ('q, 'r, 's, 't, 'u, 'v, 'w, 'x) t
                   , 'r )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'b
                -> unit)
          -> timestamp:
               (   ( [< `Read | `Set_and_create ]
                   , ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1) t
                   , 'a1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'c
                -> unit)
          -> blockchain_length:
               (   ( [< `Read | `Set_and_create ]
                   , ('g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1) t
                   , 'j1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'd
                -> unit)
          -> min_window_density:
               (   ( [< `Read | `Set_and_create ]
                   , ('o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1) t
                   , 'r1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'd
                -> unit)
          -> last_vrf_output:
               (   ( [< `Read | `Set_and_create ]
                   , ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
                   , 'a2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'e
                -> unit)
          -> total_currency:
               (   ( [< `Read | `Set_and_create ]
                   , ('e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2) t
                   , 'k2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'g
                -> unit)
          -> curr_global_slot:
               (   ( [< `Read | `Set_and_create ]
                   , ('m2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2) t
                   , 'r2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'f
                -> unit)
          -> global_slot_since_genesis:
               (   ( [< `Read | `Set_and_create ]
                   , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3) t
                   , 'z2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'f
                -> unit)
          -> staking_epoch_data:
               (   ( [< `Read | `Set_and_create ]
                   , ('c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                   , 'j3 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'h
                -> unit)
          -> next_epoch_data:
               (   ( [< `Read | `Set_and_create ]
                   , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3) t
                   , 'r3 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'h
                -> 's3)
          -> 's3

        val fold :
             ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
          -> init:'i
          -> snarked_ledger_hash:
               (   'i
                -> ( [< `Read | `Set_and_create ]
                   , ('j, 'k, 'l, 'm, 'n, 'o, 'p, 'q) t
                   , 'j )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'a
                -> 'r)
          -> snarked_next_available_token:
               (   'r
                -> ( [< `Read | `Set_and_create ]
                   , ('s, 't, 'u, 'v, 'w, 'x, 'y, 'z) t
                   , 't )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'b
                -> 'a1)
          -> timestamp:
               (   'a1
                -> ( [< `Read | `Set_and_create ]
                   , ('b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1, 'i1) t
                   , 'd1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'c
                -> 'j1)
          -> blockchain_length:
               (   'j1
                -> ( [< `Read | `Set_and_create ]
                   , ('k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1) t
                   , 'n1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'd
                -> 's1)
          -> min_window_density:
               (   's1
                -> ( [< `Read | `Set_and_create ]
                   , ('t1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2) t
                   , 'w1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'd
                -> 'b2)
          -> last_vrf_output:
               (   'b2
                -> ( [< `Read | `Set_and_create ]
                   , ('c2, 'd2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2) t
                   , 'g2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'e
                -> 'k2)
          -> total_currency:
               (   'k2
                -> ( [< `Read | `Set_and_create ]
                   , ('l2, 'm2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2) t
                   , 'r2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'g
                -> 't2)
          -> curr_global_slot:
               (   't2
                -> ( [< `Read | `Set_and_create ]
                   , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3) t
                   , 'z2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'f
                -> 'c3)
          -> global_slot_since_genesis:
               (   'c3
                -> ( [< `Read | `Set_and_create ]
                   , ('d3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3, 'k3) t
                   , 'i3 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'f
                -> 'l3)
          -> staking_epoch_data:
               (   'l3
                -> ( [< `Read | `Set_and_create ]
                   , ('m3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3) t
                   , 't3 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'h
                -> 'u3)
          -> next_epoch_data:
               (   'u3
                -> ( [< `Read | `Set_and_create ]
                   , ('v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4) t
                   , 'c4 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'h
                -> 'd4)
          -> 'd4

        val for_all :
             ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
          -> snarked_ledger_hash:
               (   ( [< `Read | `Set_and_create ]
                   , ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t
                   , 'i )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'a
                -> bool)
          -> snarked_next_available_token:
               (   ( [< `Read | `Set_and_create ]
                   , ('q, 'r, 's, 't, 'u, 'v, 'w, 'x) t
                   , 'r )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'b
                -> bool)
          -> timestamp:
               (   ( [< `Read | `Set_and_create ]
                   , ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1) t
                   , 'a1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'c
                -> bool)
          -> blockchain_length:
               (   ( [< `Read | `Set_and_create ]
                   , ('g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1) t
                   , 'j1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'd
                -> bool)
          -> min_window_density:
               (   ( [< `Read | `Set_and_create ]
                   , ('o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1) t
                   , 'r1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'd
                -> bool)
          -> last_vrf_output:
               (   ( [< `Read | `Set_and_create ]
                   , ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
                   , 'a2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'e
                -> bool)
          -> total_currency:
               (   ( [< `Read | `Set_and_create ]
                   , ('e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2) t
                   , 'k2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'g
                -> bool)
          -> curr_global_slot:
               (   ( [< `Read | `Set_and_create ]
                   , ('m2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2) t
                   , 'r2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'f
                -> bool)
          -> global_slot_since_genesis:
               (   ( [< `Read | `Set_and_create ]
                   , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3) t
                   , 'z2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'f
                -> bool)
          -> staking_epoch_data:
               (   ( [< `Read | `Set_and_create ]
                   , ('c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                   , 'j3 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'h
                -> bool)
          -> next_epoch_data:
               (   ( [< `Read | `Set_and_create ]
                   , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3) t
                   , 'r3 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'h
                -> bool)
          -> bool

        val exists :
             ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
          -> snarked_ledger_hash:
               (   ( [< `Read | `Set_and_create ]
                   , ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t
                   , 'i )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'a
                -> bool)
          -> snarked_next_available_token:
               (   ( [< `Read | `Set_and_create ]
                   , ('q, 'r, 's, 't, 'u, 'v, 'w, 'x) t
                   , 'r )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'b
                -> bool)
          -> timestamp:
               (   ( [< `Read | `Set_and_create ]
                   , ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1) t
                   , 'a1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'c
                -> bool)
          -> blockchain_length:
               (   ( [< `Read | `Set_and_create ]
                   , ('g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1) t
                   , 'j1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'd
                -> bool)
          -> min_window_density:
               (   ( [< `Read | `Set_and_create ]
                   , ('o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1) t
                   , 'r1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'd
                -> bool)
          -> last_vrf_output:
               (   ( [< `Read | `Set_and_create ]
                   , ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
                   , 'a2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'e
                -> bool)
          -> total_currency:
               (   ( [< `Read | `Set_and_create ]
                   , ('e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2) t
                   , 'k2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'g
                -> bool)
          -> curr_global_slot:
               (   ( [< `Read | `Set_and_create ]
                   , ('m2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2) t
                   , 'r2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'f
                -> bool)
          -> global_slot_since_genesis:
               (   ( [< `Read | `Set_and_create ]
                   , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3) t
                   , 'z2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'f
                -> bool)
          -> staking_epoch_data:
               (   ( [< `Read | `Set_and_create ]
                   , ('c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                   , 'j3 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'h
                -> bool)
          -> next_epoch_data:
               (   ( [< `Read | `Set_and_create ]
                   , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3) t
                   , 'r3 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'h
                -> bool)
          -> bool

        val to_list :
             ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
          -> snarked_ledger_hash:
               (   ( [< `Read | `Set_and_create ]
                   , ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t
                   , 'i )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'a
                -> 'q)
          -> snarked_next_available_token:
               (   ( [< `Read | `Set_and_create ]
                   , ('r, 's, 't, 'u, 'v, 'w, 'x, 'y) t
                   , 's )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'b
                -> 'q)
          -> timestamp:
               (   ( [< `Read | `Set_and_create ]
                   , ('z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1) t
                   , 'b1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'c
                -> 'q)
          -> blockchain_length:
               (   ( [< `Read | `Set_and_create ]
                   , ('h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1) t
                   , 'k1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'd
                -> 'q)
          -> min_window_density:
               (   ( [< `Read | `Set_and_create ]
                   , ('p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1, 'w1) t
                   , 's1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'd
                -> 'q)
          -> last_vrf_output:
               (   ( [< `Read | `Set_and_create ]
                   , ('x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2, 'e2) t
                   , 'b2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'e
                -> 'q)
          -> total_currency:
               (   ( [< `Read | `Set_and_create ]
                   , ('f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2) t
                   , 'l2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'g
                -> 'q)
          -> curr_global_slot:
               (   ( [< `Read | `Set_and_create ]
                   , ('n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2, 'u2) t
                   , 's2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'f
                -> 'q)
          -> global_slot_since_genesis:
               (   ( [< `Read | `Set_and_create ]
                   , ('v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3, 'c3) t
                   , 'a3 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'f
                -> 'q)
          -> staking_epoch_data:
               (   ( [< `Read | `Set_and_create ]
                   , ('d3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3, 'k3) t
                   , 'k3 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'h
                -> 'q)
          -> next_epoch_data:
               (   ( [< `Read | `Set_and_create ]
                   , ('l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3) t
                   , 's3 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'h
                -> 'q)
          -> 'q list

        val map :
             ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
          -> snarked_ledger_hash:
               (   ( [< `Read | `Set_and_create ]
                   , ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t
                   , 'i )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'a
                -> 'q)
          -> snarked_next_available_token:
               (   ( [< `Read | `Set_and_create ]
                   , ('r, 's, 't, 'u, 'v, 'w, 'x, 'y) t
                   , 's )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'b
                -> 'z)
          -> timestamp:
               (   ( [< `Read | `Set_and_create ]
                   , ('a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1) t
                   , 'c1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'c
                -> 'i1)
          -> blockchain_length:
               (   ( [< `Read | `Set_and_create ]
                   , ('j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1) t
                   , 'm1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'd
                -> 'r1)
          -> min_window_density:
               (   ( [< `Read | `Set_and_create ]
                   , ('s1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1) t
                   , 'v1 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'd
                -> 'r1)
          -> last_vrf_output:
               (   ( [< `Read | `Set_and_create ]
                   , ('a2, 'b2, 'c2, 'd2, 'e2, 'f2, 'g2, 'h2) t
                   , 'e2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'e
                -> 'i2)
          -> total_currency:
               (   ( [< `Read | `Set_and_create ]
                   , ('j2, 'k2, 'l2, 'm2, 'n2, 'o2, 'p2, 'q2) t
                   , 'p2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'g
                -> 'r2)
          -> curr_global_slot:
               (   ( [< `Read | `Set_and_create ]
                   , ('s2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2, 'z2) t
                   , 'x2 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'f
                -> 'a3)
          -> global_slot_since_genesis:
               (   ( [< `Read | `Set_and_create ]
                   , ('b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3) t
                   , 'g3 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'f
                -> 'a3)
          -> staking_epoch_data:
               (   ( [< `Read | `Set_and_create ]
                   , ('j3, 'k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3) t
                   , 'q3 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'h
                -> 'r3)
          -> next_epoch_data:
               (   ( [< `Read | `Set_and_create ]
                   , ('s3, 't3, 'u3, 'v3, 'w3, 'x3, 'y3, 'z3) t
                   , 'z3 )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
                -> 'h
                -> 'r3)
          -> ('q, 'z, 'i1, 'r1, 'i2, 'a3, 'r2, 'r3) t

        val set_all_mutable_fields : 'a -> unit
      end
    end
  end

  module Stable : sig
    module V1 : sig
      type t =
        ( Frozen_ledger_hash.Stable.V1.t Hash.t
        , Token_id.Stable.V1.t Numeric.Stable.V1.t
        , Block_time.Stable.V1.t Numeric.Stable.V1.t
        , Mina_numbers.Length.Stable.V1.t Numeric.Stable.V1.t
        , unit
        , Mina_numbers.Global_slot.Stable.V1.t Numeric.Stable.V1.t
        , Currency.Amount.Stable.V1.t Numeric.Stable.V1.t
        , Epoch_data.Stable.V1.t )
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

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val compare : t -> t -> int

  val to_input : t -> (Snapp_basic.F.t, bool) Random_oracle.Input.t

  val digest : t -> Random_oracle.Digest.t

  module View : sig
    module Stable : sig
      module V1 : sig
        type t =
          ( Frozen_ledger_hash.Stable.V1.t
          , Token_id.Stable.V1.t
          , Block_time.Stable.V1.t
          , Mina_numbers.Length.Stable.V1.t
          , unit
          , Mina_numbers.Global_slot.Stable.V1.t
          , Currency.Amount.Stable.V1.t
          , ( ( Frozen_ledger_hash.Stable.V1.t
              , Currency.Amount.Stable.V1.t )
              Epoch_ledger.Poly.Stable.V1.t
            , Epoch_seed.Stable.V1.t
            , State_hash.Stable.V1.t
            , State_hash.Stable.V1.t
            , Mina_numbers.Length.Stable.V1.t )
            Epoch_data.Poly.Stable.V1.t )
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
        * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t)
        )
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

    module Checked : sig
      type t =
        ( Frozen_ledger_hash.var
        , Token_id.var
        , Block_time.Unpacked.var
        , Mina_numbers.Length.Checked.t
        , unit
        , Mina_numbers.Global_slot.Checked.t
        , Currency.Amount.var
        , ( (Frozen_ledger_hash.var, Currency.Amount.var) Epoch_ledger.Poly.t
          , Epoch_seed.var
          , State_hash.var
          , State_hash.var
          , Mina_numbers.Length.Checked.t )
          Epoch_data.Poly.t )
        Poly.t
    end
  end

  module Checked : sig
    type t =
      ( Frozen_ledger_hash.var Mina_base__Snapp_basic.Or_ignore.Checked.t
      , Token_id.var Numeric.Checked.t
      , Block_time.Unpacked.var Numeric.Checked.t
      , Mina_numbers.Length.Checked.t Numeric.Checked.t
      , unit
      , Mina_numbers.Global_slot.Checked.t Numeric.Checked.t
      , Currency.Amount.var Numeric.Checked.t
      , Epoch_data.Checked.t )
      Poly.t

    val to_input :
         t
      -> ( Snark_params.Tick.Field.Var.t
         , Snark_params.Tick.Boolean.var )
         Random_oracle.Input.t

    val digest : t -> Random_oracle.Checked.Digest.t

    val check : t -> View.Checked.t -> Pickles.Impls.Step.Boolean.var
  end

  val typ : (Checked.t, t) Snark_params.Tick.Typ.t

  val accept : t

  val check : t -> View.t -> unit Base__Or_error.t
end

module Account_type : sig
  module Stable : sig
    module V1 : sig
      type t = User | Snapp | None | Any

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

  type t = Stable.V1.t = User | Snapp | None | Any

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val equal : t -> t -> bool

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val compare : t -> t -> int

  val check :
    t -> A.t option -> (unit, Core_kernel__.Error.t) Core_kernel._result

  val to_bits : t -> bool list

  val of_bits : bool list -> t

  val to_input : t -> ('a, bool) Random_oracle_input.t

  module Checked : sig
    type t =
      { user : Snark_params.Tick.Boolean.var
      ; snapp : Snark_params.Tick.Boolean.var
      }

    val to_hlist :
         t
      -> ( unit
         ,    Snark_params.Tick.Boolean.var
           -> Snark_params.Tick.Boolean.var
           -> unit )
         H_list.t

    val of_hlist :
         ( unit
         ,    Snark_params.Tick.Boolean.var
           -> Snark_params.Tick.Boolean.var
           -> unit )
         H_list.t
      -> t

    val to_input :
      t -> ('a, Snark_params.Tick.Boolean.var) Random_oracle_input.t

    val constant : Stable.V1.t -> t

    val snapp_allowed : t -> Snark_params.Tick.Boolean.var

    val user_allowed : t -> Snark_params.Tick.Boolean.var
  end

  val typ : (Checked.t, t) Snark_params.Tick.Typ.t
end

module Other : sig
  module Poly : sig
    module Stable : sig
      module V1 : sig
        type ('account, 'account_transition, 'vk) t =
          { predicate : 'account
          ; account_transition : 'account_transition
          ; account_vk : 'vk
          }

        val to_yojson :
             ('account -> Yojson.Safe.t)
          -> ('account_transition -> Yojson.Safe.t)
          -> ('vk -> Yojson.Safe.t)
          -> ('account, 'account_transition, 'vk) t
          -> Yojson.Safe.t

        val of_yojson :
             (Yojson.Safe.t -> 'account Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'account_transition Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'vk Ppx_deriving_yojson_runtime.error_or)
          -> Yojson.Safe.t
          -> ('account, 'account_transition, 'vk) t
             Ppx_deriving_yojson_runtime.error_or

        val version : int

        val __versioned__ : unit

        val to_hlist :
             ('account, 'account_transition, 'vk) t
          -> (unit, 'account -> 'account_transition -> 'vk -> unit) H_list.t

        val of_hlist :
             (unit, 'account -> 'account_transition -> 'vk -> unit) H_list.t
          -> ('account, 'account_transition, 'vk) t

        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'account)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'account_transition)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'vk)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> ('account, 'account_transition, 'vk) t

        val sexp_of_t :
             ('account -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('account_transition -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('vk -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('account, 'account_transition, 'vk) t
          -> Ppx_sexp_conv_lib.Sexp.t

        val equal :
             ('account -> 'account -> bool)
          -> ('account_transition -> 'account_transition -> bool)
          -> ('vk -> 'vk -> bool)
          -> ('account, 'account_transition, 'vk) t
          -> ('account, 'account_transition, 'vk) t
          -> bool

        val hash_fold_t :
             (   Ppx_hash_lib.Std.Hash.state
              -> 'account
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'account_transition
              -> Ppx_hash_lib.Std.Hash.state)
          -> (Ppx_hash_lib.Std.Hash.state -> 'vk -> Ppx_hash_lib.Std.Hash.state)
          -> Ppx_hash_lib.Std.Hash.state
          -> ('account, 'account_transition, 'vk) t
          -> Ppx_hash_lib.Std.Hash.state

        val compare :
             ('account -> 'account -> int)
          -> ('account_transition -> 'account_transition -> int)
          -> ('vk -> 'vk -> int)
          -> ('account, 'account_transition, 'vk) t
          -> ('account, 'account_transition, 'vk) t
          -> int

        module With_version : sig
          type ('account, 'account_transition, 'vk) typ =
            ('account, 'account_transition, 'vk) t

          val bin_shape_typ :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_typ :
               'account Core_kernel.Bin_prot.Size.sizer
            -> 'account_transition Core_kernel.Bin_prot.Size.sizer
            -> 'vk Core_kernel.Bin_prot.Size.sizer
            -> ('account, 'account_transition, 'vk) typ
               Core_kernel.Bin_prot.Size.sizer

          val bin_write_typ :
               'account Core_kernel.Bin_prot.Write.writer
            -> 'account_transition Core_kernel.Bin_prot.Write.writer
            -> 'vk Core_kernel.Bin_prot.Write.writer
            -> ('account, 'account_transition, 'vk) typ
               Core_kernel.Bin_prot.Write.writer

          val bin_writer_typ :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c) typ Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_typ__ :
               'account Core_kernel.Bin_prot.Read.reader
            -> 'account_transition Core_kernel.Bin_prot.Read.reader
            -> 'vk Core_kernel.Bin_prot.Read.reader
            -> (int -> ('account, 'account_transition, 'vk) typ)
               Core_kernel.Bin_prot.Read.reader

          val bin_read_typ :
               'account Core_kernel.Bin_prot.Read.reader
            -> 'account_transition Core_kernel.Bin_prot.Read.reader
            -> 'vk Core_kernel.Bin_prot.Read.reader
            -> ('account, 'account_transition, 'vk) typ
               Core_kernel.Bin_prot.Read.reader

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

          type ('account, 'account_transition, 'vk) t =
            { version : int; t : ('account, 'account_transition, 'vk) typ }

          val bin_shape_t :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_t :
               'account Core_kernel.Bin_prot.Size.sizer
            -> 'account_transition Core_kernel.Bin_prot.Size.sizer
            -> 'vk Core_kernel.Bin_prot.Size.sizer
            -> ('account, 'account_transition, 'vk) t
               Core_kernel.Bin_prot.Size.sizer

          val bin_write_t :
               'account Core_kernel.Bin_prot.Write.writer
            -> 'account_transition Core_kernel.Bin_prot.Write.writer
            -> 'vk Core_kernel.Bin_prot.Write.writer
            -> ('account, 'account_transition, 'vk) t
               Core_kernel.Bin_prot.Write.writer

          val bin_writer_t :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_t__ :
               'account Core_kernel.Bin_prot.Read.reader
            -> 'account_transition Core_kernel.Bin_prot.Read.reader
            -> 'vk Core_kernel.Bin_prot.Read.reader
            -> (int -> ('account, 'account_transition, 'vk) t)
               Core_kernel.Bin_prot.Read.reader

          val bin_read_t :
               'account Core_kernel.Bin_prot.Read.reader
            -> 'account_transition Core_kernel.Bin_prot.Read.reader
            -> 'vk Core_kernel.Bin_prot.Read.reader
            -> ('account, 'account_transition, 'vk) t
               Core_kernel.Bin_prot.Read.reader

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

    type ('account, 'account_transition, 'vk) t =
          ('account, 'account_transition, 'vk) Stable.V1.t =
      { predicate : 'account
      ; account_transition : 'account_transition
      ; account_vk : 'vk
      }

    val to_yojson :
         ('account -> Yojson.Safe.t)
      -> ('account_transition -> Yojson.Safe.t)
      -> ('vk -> Yojson.Safe.t)
      -> ('account, 'account_transition, 'vk) t
      -> Yojson.Safe.t

    val of_yojson :
         (Yojson.Safe.t -> 'account Ppx_deriving_yojson_runtime.error_or)
      -> (   Yojson.Safe.t
          -> 'account_transition Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'vk Ppx_deriving_yojson_runtime.error_or)
      -> Yojson.Safe.t
      -> ('account, 'account_transition, 'vk) t
         Ppx_deriving_yojson_runtime.error_or

    val to_hlist :
         ('account, 'account_transition, 'vk) t
      -> (unit, 'account -> 'account_transition -> 'vk -> unit) H_list.t

    val of_hlist :
         (unit, 'account -> 'account_transition -> 'vk -> unit) H_list.t
      -> ('account, 'account_transition, 'vk) t

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'account)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'account_transition)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'vk)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> ('account, 'account_transition, 'vk) t

    val sexp_of_t :
         ('account -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('account_transition -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('vk -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('account, 'account_transition, 'vk) t
      -> Ppx_sexp_conv_lib.Sexp.t

    val equal :
         ('account -> 'account -> bool)
      -> ('account_transition -> 'account_transition -> bool)
      -> ('vk -> 'vk -> bool)
      -> ('account, 'account_transition, 'vk) t
      -> ('account, 'account_transition, 'vk) t
      -> bool

    val hash_fold_t :
         (Ppx_hash_lib.Std.Hash.state -> 'account -> Ppx_hash_lib.Std.Hash.state)
      -> (   Ppx_hash_lib.Std.Hash.state
          -> 'account_transition
          -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'vk -> Ppx_hash_lib.Std.Hash.state)
      -> Ppx_hash_lib.Std.Hash.state
      -> ('account, 'account_transition, 'vk) t
      -> Ppx_hash_lib.Std.Hash.state

    val compare :
         ('account -> 'account -> int)
      -> ('account_transition -> 'account_transition -> int)
      -> ('vk -> 'vk -> int)
      -> ('account, 'account_transition, 'vk) t
      -> ('account, 'account_transition, 'vk) t
      -> int
  end

  module Stable : sig
    module V1 : sig
      type t =
        ( Account.Stable.V1.t
        , Snapp_basic.Account_state.Stable.V1.t
          Snapp_basic.Transition.Stable.V1.t
        , Snapp_basic.F.Stable.V1.t Hash.t )
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

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val compare : t -> t -> int

  module Checked : sig
    type t =
      ( Account.Checked.t
      , Snapp_basic.Account_state.Checked.t Snapp_basic.Transition.t
      , Snark_params.Tick.Field.Var.t Snapp_basic.Or_ignore.Checked.t )
      Poly.t

    val to_input :
         t
      -> ( Snark_params.Tick.Field.Var.t
         , Snark_params.Tick.Boolean.var )
         Random_oracle_input.t
  end

  val to_input : t -> (Snapp_basic.F.t, bool) Random_oracle_input.t

  val typ :
       unit
    -> ( ( Account.Checked.t
         , Snapp_basic.Account_state.Checked.t Snapp_basic.Transition.t
         , Pickles__Impls.Step.Impl.Internal_Basic.Field.Var.t
           Mina_base__Snapp_basic.Or_ignore.Checked.t )
         Poly.t
       , ( Account.t
         , Snapp_basic.Account_state.t Snapp_basic.Transition.t
         , Snark_params.Tick.Field.t Hash.t )
         Poly.t )
       Snark_params.Tick.Typ.t

  val accept : t
end

module Poly : sig
  module Stable : sig
    module V1 : sig
      type ('account, 'protocol_state, 'other, 'pk) t =
        { self_predicate : 'account
        ; other : 'other
        ; fee_payer : 'pk
        ; protocol_state_predicate : 'protocol_state
        }

      val to_yojson :
           ('account -> Yojson.Safe.t)
        -> ('protocol_state -> Yojson.Safe.t)
        -> ('other -> Yojson.Safe.t)
        -> ('pk -> Yojson.Safe.t)
        -> ('account, 'protocol_state, 'other, 'pk) t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'account Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'protocol_state Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'other Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'pk Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ('account, 'protocol_state, 'other, 'pk) t
           Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val to_hlist :
           ('account, 'protocol_state, 'other, 'pk) t
        -> (unit, 'account -> 'other -> 'pk -> 'protocol_state -> unit) H_list.t

      val of_hlist :
           (unit, 'account -> 'other -> 'pk -> 'protocol_state -> unit) H_list.t
        -> ('account, 'protocol_state, 'other, 'pk) t

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'account)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'protocol_state)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'other)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'pk)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('account, 'protocol_state, 'other, 'pk) t

      val sexp_of_t :
           ('account -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('protocol_state -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('other -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('pk -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('account, 'protocol_state, 'other, 'pk) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val equal :
           ('account -> 'account -> bool)
        -> ('protocol_state -> 'protocol_state -> bool)
        -> ('other -> 'other -> bool)
        -> ('pk -> 'pk -> bool)
        -> ('account, 'protocol_state, 'other, 'pk) t
        -> ('account, 'protocol_state, 'other, 'pk) t
        -> bool

      val hash_fold_t :
           (   Ppx_hash_lib.Std.Hash.state
            -> 'account
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'protocol_state
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'other
            -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'pk -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('account, 'protocol_state, 'other, 'pk) t
        -> Ppx_hash_lib.Std.Hash.state

      val compare :
           ('account -> 'account -> int)
        -> ('protocol_state -> 'protocol_state -> int)
        -> ('other -> 'other -> int)
        -> ('pk -> 'pk -> int)
        -> ('account, 'protocol_state, 'other, 'pk) t
        -> ('account, 'protocol_state, 'other, 'pk) t
        -> int

      val to_latest : 'a -> 'a

      module With_version : sig
        type ('account, 'protocol_state, 'other, 'pk) typ =
          ('account, 'protocol_state, 'other, 'pk) t

        val bin_shape_typ :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_typ :
             'account Core_kernel.Bin_prot.Size.sizer
          -> 'protocol_state Core_kernel.Bin_prot.Size.sizer
          -> 'other Core_kernel.Bin_prot.Size.sizer
          -> 'pk Core_kernel.Bin_prot.Size.sizer
          -> ('account, 'protocol_state, 'other, 'pk) typ
             Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ :
             'account Core_kernel.Bin_prot.Write.writer
          -> 'protocol_state Core_kernel.Bin_prot.Write.writer
          -> 'other Core_kernel.Bin_prot.Write.writer
          -> 'pk Core_kernel.Bin_prot.Write.writer
          -> ('account, 'protocol_state, 'other, 'pk) typ
             Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> 'd Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c, 'd) typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
             'account Core_kernel.Bin_prot.Read.reader
          -> 'protocol_state Core_kernel.Bin_prot.Read.reader
          -> 'other Core_kernel.Bin_prot.Read.reader
          -> 'pk Core_kernel.Bin_prot.Read.reader
          -> (int -> ('account, 'protocol_state, 'other, 'pk) typ)
             Core_kernel.Bin_prot.Read.reader

        val bin_read_typ :
             'account Core_kernel.Bin_prot.Read.reader
          -> 'protocol_state Core_kernel.Bin_prot.Read.reader
          -> 'other Core_kernel.Bin_prot.Read.reader
          -> 'pk Core_kernel.Bin_prot.Read.reader
          -> ('account, 'protocol_state, 'other, 'pk) typ
             Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> 'c Core_kernel.Bin_prot.Type_class.reader
          -> 'd Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b, 'c, 'd) typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> 'c Core_kernel.Bin_prot.Type_class.t
          -> 'd Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b, 'c, 'd) typ Core_kernel.Bin_prot.Type_class.t

        type ('account, 'protocol_state, 'other, 'pk) t =
          { version : int; t : ('account, 'protocol_state, 'other, 'pk) typ }

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'account Core_kernel.Bin_prot.Size.sizer
          -> 'protocol_state Core_kernel.Bin_prot.Size.sizer
          -> 'other Core_kernel.Bin_prot.Size.sizer
          -> 'pk Core_kernel.Bin_prot.Size.sizer
          -> ('account, 'protocol_state, 'other, 'pk) t
             Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'account Core_kernel.Bin_prot.Write.writer
          -> 'protocol_state Core_kernel.Bin_prot.Write.writer
          -> 'other Core_kernel.Bin_prot.Write.writer
          -> 'pk Core_kernel.Bin_prot.Write.writer
          -> ('account, 'protocol_state, 'other, 'pk) t
             Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> 'd Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c, 'd) t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ :
             'account Core_kernel.Bin_prot.Read.reader
          -> 'protocol_state Core_kernel.Bin_prot.Read.reader
          -> 'other Core_kernel.Bin_prot.Read.reader
          -> 'pk Core_kernel.Bin_prot.Read.reader
          -> (int -> ('account, 'protocol_state, 'other, 'pk) t)
             Core_kernel.Bin_prot.Read.reader

        val bin_read_t :
             'account Core_kernel.Bin_prot.Read.reader
          -> 'protocol_state Core_kernel.Bin_prot.Read.reader
          -> 'other Core_kernel.Bin_prot.Read.reader
          -> 'pk Core_kernel.Bin_prot.Read.reader
          -> ('account, 'protocol_state, 'other, 'pk) t
             Core_kernel.Bin_prot.Read.reader

        val bin_reader_t :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> 'c Core_kernel.Bin_prot.Type_class.reader
          -> 'd Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b, 'c, 'd) t Core_kernel.Bin_prot.Type_class.reader

        val bin_t :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> 'c Core_kernel.Bin_prot.Type_class.t
          -> 'd Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b, 'c, 'd) t Core_kernel.Bin_prot.Type_class.t

        val create : ('a, 'b, 'c, 'd) typ -> ('a, 'b, 'c, 'd) t
      end

      val bin_read_t :
           'a Core_kernel.Bin_prot.Read.reader
        -> 'b Core_kernel.Bin_prot.Read.reader
        -> 'c Core_kernel.Bin_prot.Read.reader
        -> 'd Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> ('a, 'b, 'c, 'd) t

      val __bin_read_t__ :
           'a Core_kernel.Bin_prot.Read.reader
        -> 'b Core_kernel.Bin_prot.Read.reader
        -> 'c Core_kernel.Bin_prot.Read.reader
        -> 'd Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> int
        -> ('a, 'b, 'c, 'd) t

      val bin_size_t :
           'a Core_kernel.Bin_prot.Size.sizer
        -> 'b Core_kernel.Bin_prot.Size.sizer
        -> 'c Core_kernel.Bin_prot.Size.sizer
        -> 'd Core_kernel.Bin_prot.Size.sizer
        -> ('a, 'b, 'c, 'd) t
        -> int

      val bin_write_t :
           'a Core_kernel.Bin_prot.Write.writer
        -> 'b Core_kernel.Bin_prot.Write.writer
        -> 'c Core_kernel.Bin_prot.Write.writer
        -> 'd Core_kernel.Bin_prot.Write.writer
        -> Bin_prot.Common.buf
        -> pos:Bin_prot.Common.pos
        -> ('a, 'b, 'c, 'd) t
        -> Bin_prot.Common.pos

      val bin_shape_t :
           Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t

      val bin_reader_t :
           'a Core_kernel.Bin_prot.Type_class.reader
        -> 'b Core_kernel.Bin_prot.Type_class.reader
        -> 'c Core_kernel.Bin_prot.Type_class.reader
        -> 'd Core_kernel.Bin_prot.Type_class.reader
        -> ('a, 'b, 'c, 'd) t Core_kernel.Bin_prot.Type_class.reader

      val bin_writer_t :
           'a Core_kernel.Bin_prot.Type_class.writer
        -> 'b Core_kernel.Bin_prot.Type_class.writer
        -> 'c Core_kernel.Bin_prot.Type_class.writer
        -> 'd Core_kernel.Bin_prot.Type_class.writer
        -> ('a, 'b, 'c, 'd) t Core_kernel.Bin_prot.Type_class.writer

      val bin_t :
           'a Core_kernel.Bin_prot.Type_class.t
        -> 'b Core_kernel.Bin_prot.Type_class.t
        -> 'c Core_kernel.Bin_prot.Type_class.t
        -> 'd Core_kernel.Bin_prot.Type_class.t
        -> ('a, 'b, 'c, 'd) t Core_kernel.Bin_prot.Type_class.t

      val __ :
        (   'a Core_kernel.Bin_prot.Read.reader
         -> 'b Core_kernel.Bin_prot.Read.reader
         -> 'c Core_kernel.Bin_prot.Read.reader
         -> 'd Core_kernel.Bin_prot.Read.reader
         -> Bin_prot.Common.buf
         -> pos_ref:Bin_prot.Common.pos_ref
         -> ('a, 'b, 'c, 'd) t)
        * (   'e Core_kernel.Bin_prot.Read.reader
           -> 'f Core_kernel.Bin_prot.Read.reader
           -> 'g Core_kernel.Bin_prot.Read.reader
           -> 'h Core_kernel.Bin_prot.Read.reader
           -> Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> int
           -> ('e, 'f, 'g, 'h) t)
        * (   'i Core_kernel.Bin_prot.Size.sizer
           -> 'j Core_kernel.Bin_prot.Size.sizer
           -> 'k Core_kernel.Bin_prot.Size.sizer
           -> 'l Core_kernel.Bin_prot.Size.sizer
           -> ('i, 'j, 'k, 'l) t
           -> int)
        * (   'm Core_kernel.Bin_prot.Write.writer
           -> 'n Core_kernel.Bin_prot.Write.writer
           -> 'o Core_kernel.Bin_prot.Write.writer
           -> 'p Core_kernel.Bin_prot.Write.writer
           -> Bin_prot.Common.buf
           -> pos:Bin_prot.Common.pos
           -> ('m, 'n, 'o, 'p) t
           -> Bin_prot.Common.pos)
        * (   Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t)
        * (   'q Core_kernel.Bin_prot.Type_class.reader
           -> 'r Core_kernel.Bin_prot.Type_class.reader
           -> 's Core_kernel.Bin_prot.Type_class.reader
           -> 't Core_kernel.Bin_prot.Type_class.reader
           -> ('q, 'r, 's, 't) t Core_kernel.Bin_prot.Type_class.reader)
        * (   'u Core_kernel.Bin_prot.Type_class.writer
           -> 'v Core_kernel.Bin_prot.Type_class.writer
           -> 'w Core_kernel.Bin_prot.Type_class.writer
           -> 'x Core_kernel.Bin_prot.Type_class.writer
           -> ('u, 'v, 'w, 'x) t Core_kernel.Bin_prot.Type_class.writer)
        * (   'y Core_kernel.Bin_prot.Type_class.t
           -> 'z Core_kernel.Bin_prot.Type_class.t
           -> 'a1 Core_kernel.Bin_prot.Type_class.t
           -> 'b1 Core_kernel.Bin_prot.Type_class.t
           -> ('y, 'z, 'a1, 'b1) t Core_kernel.Bin_prot.Type_class.t)
    end

    module Latest = V1
  end

  type ('account, 'protocol_state, 'other, 'pk) t =
        ('account, 'protocol_state, 'other, 'pk) Stable.V1.t =
    { self_predicate : 'account
    ; other : 'other
    ; fee_payer : 'pk
    ; protocol_state_predicate : 'protocol_state
    }

  val to_yojson :
       ('account -> Yojson.Safe.t)
    -> ('protocol_state -> Yojson.Safe.t)
    -> ('other -> Yojson.Safe.t)
    -> ('pk -> Yojson.Safe.t)
    -> ('account, 'protocol_state, 'other, 'pk) t
    -> Yojson.Safe.t

  val of_yojson :
       (Yojson.Safe.t -> 'account Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'protocol_state Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'other Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'pk Ppx_deriving_yojson_runtime.error_or)
    -> Yojson.Safe.t
    -> ('account, 'protocol_state, 'other, 'pk) t
       Ppx_deriving_yojson_runtime.error_or

  val to_hlist :
       ('account, 'protocol_state, 'other, 'pk) t
    -> (unit, 'account -> 'other -> 'pk -> 'protocol_state -> unit) H_list.t

  val of_hlist :
       (unit, 'account -> 'other -> 'pk -> 'protocol_state -> unit) H_list.t
    -> ('account, 'protocol_state, 'other, 'pk) t

  val t_of_sexp :
       (Ppx_sexp_conv_lib.Sexp.t -> 'account)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'protocol_state)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'other)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'pk)
    -> Ppx_sexp_conv_lib.Sexp.t
    -> ('account, 'protocol_state, 'other, 'pk) t

  val sexp_of_t :
       ('account -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('protocol_state -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('other -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('pk -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('account, 'protocol_state, 'other, 'pk) t
    -> Ppx_sexp_conv_lib.Sexp.t

  val equal :
       ('account -> 'account -> bool)
    -> ('protocol_state -> 'protocol_state -> bool)
    -> ('other -> 'other -> bool)
    -> ('pk -> 'pk -> bool)
    -> ('account, 'protocol_state, 'other, 'pk) t
    -> ('account, 'protocol_state, 'other, 'pk) t
    -> bool

  val hash_fold_t :
       (Ppx_hash_lib.Std.Hash.state -> 'account -> Ppx_hash_lib.Std.Hash.state)
    -> (   Ppx_hash_lib.Std.Hash.state
        -> 'protocol_state
        -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'other -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'pk -> Ppx_hash_lib.Std.Hash.state)
    -> Ppx_hash_lib.Std.Hash.state
    -> ('account, 'protocol_state, 'other, 'pk) t
    -> Ppx_hash_lib.Std.Hash.state

  val compare :
       ('account -> 'account -> int)
    -> ('protocol_state -> 'protocol_state -> int)
    -> ('other -> 'other -> int)
    -> ('pk -> 'pk -> int)
    -> ('account, 'protocol_state, 'other, 'pk) t
    -> ('account, 'protocol_state, 'other, 'pk) t
    -> int

  val typ :
       ( unit
       , unit
       , 'a -> 'b -> 'c -> 'd -> unit
       , 'e -> 'f -> 'g -> 'h -> unit )
       Pickles__Impls.Step.Impl.Internal_Basic.Data_spec.t
    -> (('a, 'd, 'b, 'c) t, ('e, 'h, 'f, 'g) t) Snark_params.Tick.Typ.t
end

module Stable : sig
  module V1 : sig
    type t =
      ( Account.Stable.V1.t
      , Protocol_state.Stable.V1.t
      , Other.Stable.V1.t
      , Signature_lib.Public_key.Compressed.Stable.V1.t Hash.t )
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

module Digested = Snapp_basic.F

val to_input : t -> (Snapp_basic.F.t, bool) Random_oracle.Input.t

val digest : t -> Random_oracle.Digest.t

val check :
     t
  -> state_view:Protocol_state.View.t
  -> self:A.t
  -> other_prev:A.t option
  -> other_next:unit option
  -> fee_payer_pk:Signature_lib.Public_key.Compressed.t
  -> unit Base__Or_error.t

val accept : t

module Checked : sig
  type t =
    ( Account.Checked.t
    , Protocol_state.Checked.t
    , Other.Checked.t
    , Signature_lib.Public_key.Compressed.var Snapp_basic.Or_ignore.Checked.t
    )
    Poly.t

  val to_input :
       t
    -> ( Snark_params.Tick.Field.Var.t
       , Snark_params.Tick.Boolean.var )
       Random_oracle.Input.t

  val digest : t -> Random_oracle.Checked.Digest.t
end

val typ : unit -> (Checked.t, t) Snark_params.Tick.Typ.t
