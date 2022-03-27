module T = Data_hash_lib.State_hash

type t = Snark_params.Tick.Field.t

val to_yojson : t -> Yojson.Safe.t

val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

val t_of_sexp : Sexplib0.Sexp.t -> t

val sexp_of_t : t -> Sexplib0.Sexp.t

val gen : t Core_kernel.Quickcheck.Generator.t

type var = Data_hash_lib__State_hash.var

val var_to_hash_packed : var -> Random_oracle.Checked.Digest.t

val var_to_input :
     var
  -> ( Snark_params.Tick.Field.Var.t
     , Snark_params.Tick.Boolean.var )
     Random_oracle.Input.t

val var_to_bits :
  var -> (Snark_params.Tick.Boolean.var list, 'a) Snark_params.Tick.Checked.t

val typ : (var, t) Snark_params.Tick.Typ.t

val assert_equal : var -> var -> (unit, 'a) Snark_params.Tick.Checked.t

val equal_var :
  var -> var -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

val var_of_t : t -> var

val fold : t -> bool Fold_lib.Fold.t

val size_in_bits : int

val iter : t -> f:(bool -> unit) -> unit

val to_bits : t -> bool list

val to_input : t -> (t, bool) Random_oracle.Input.t

val ( >= ) : t -> t -> bool

val ( <= ) : t -> t -> bool

val ( = ) : t -> t -> bool

val ( > ) : t -> t -> bool

val ( < ) : t -> t -> bool

val ( <> ) : t -> t -> bool

val equal : t -> t -> bool

val min : t -> t -> t

val max : t -> t -> t

val ascending : t -> t -> int

val descending : t -> t -> int

val between : t -> low:t -> high:t -> bool

val clamp_exn : t -> min:t -> max:t -> t

val clamp : t -> min:t -> max:t -> t Base__.Or_error.t

type comparator_witness = Data_hash_lib__State_hash.comparator_witness

val comparator : (t, comparator_witness) Base__.Comparator.comparator

val validate_lbound : min:t Base__.Maybe_bound.t -> t Base__.Validate.check

val validate_ubound : max:t Base__.Maybe_bound.t -> t Base__.Validate.check

val validate_bound :
     min:t Base__.Maybe_bound.t
  -> max:t Base__.Maybe_bound.t
  -> t Base__.Validate.check

module Replace_polymorphic_compare =
  Data_hash_lib__State_hash.Replace_polymorphic_compare
module Map = Data_hash_lib__State_hash.Map
module Set = Data_hash_lib__State_hash.Set

val compare : t -> t -> Core_kernel__.Import.int

val hash_fold_t :
  Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

val hashable : t Core_kernel__.Hashtbl.Hashable.t

module Table = Data_hash_lib__State_hash.Table
module Hash_set = Data_hash_lib__State_hash.Hash_set
module Hash_queue = Data_hash_lib__State_hash.Hash_queue

val if_ :
     Snark_params.Tick.Boolean.var
  -> then_:var
  -> else_:var
  -> (var, 'a) Snark_params.Tick.Checked.t

val var_of_hash_packed : Random_oracle.Checked.Digest.t -> var

val of_hash : t -> t

val to_base58_check : t -> string

val of_base58_check : string -> t Base.Or_error.t

val of_base58_check_exn : string -> t

val raw_hash_bytes : t -> string

val to_bytes : [ `Use_to_base58_check_or_raw_hash_bytes ]

val dummy : t

val zero : t

val to_decimal_string : t -> string

module Stable = Data_hash_lib__State_hash.Stable

module State_hashes : sig
  module Stable : sig
    module V1 : sig
      type t =
        { mutable state_body_hash : State_body_hash.Stable.V1.t option
        ; state_hash : Data_hash_lib.State_hash.Stable.V1.t
        }

      val to_yojson : t -> Yojson.Safe.t

      val version : int

      val __versioned__ : unit

      val equal : t -> t -> bool

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

  type t = Stable.V1.t =
    { mutable state_body_hash : State_body_hash.t option
    ; state_hash : Data_hash_lib.State_hash.t
    }

  val to_yojson : t -> Yojson.Safe.t

  val equal : t -> t -> bool

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val state_hash : t -> Data_hash_lib.State_hash.t

  val state_body_hash : t -> compute_hashes:(unit -> t) -> State_body_hash.t
end

module With_state_hashes : sig
  module Stable : sig
    module V1 : sig
      type 'a t = ('a, State_hashes.t) With_hash.Stable.V1.t

      val to_yojson : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t

      val version : int

      val __versioned__ : unit

      val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

      val t_of_sexp :
        (Ppx_sexp_conv_lib.Sexp.t -> 'a) -> Ppx_sexp_conv_lib.Sexp.t -> 'a t

      val sexp_of_t :
        ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

      val to_latest : 'a -> 'a

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

  val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

  val t_of_sexp :
    (Ppx_sexp_conv_lib.Sexp.t -> 'a) -> Ppx_sexp_conv_lib.Sexp.t -> 'a t

  val sexp_of_t :
    ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

  val data : ('a, 'b) With_hash.t -> 'a

  val hashes : ('a, 'b) With_hash.t -> 'b

  val state_hash :
    ('a, State_hashes.t) With_hash.t -> Data_hash_lib.State_hash.Stable.V1.t

  val state_body_hash :
       ('a, State_hashes.t) With_hash.t
    -> compute_hashes:('a -> State_hashes.t)
    -> State_body_hash.t
end
