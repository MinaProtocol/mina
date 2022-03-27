module Limbs = Pickles_types.Nat.N4

module Constant : sig
  module A : sig
    type 'a t = ('a, Pickles_types.Nat.N4.n) Pickles_types__Vector.vec

    val compare :
         ('a -> 'a -> int)
      -> ('a, 'b) Pickles_types__Vector.t
      -> ('a, 'c) Pickles_types__Vector.t
      -> int

    val hash_fold_t :
         (   Base__.Ppx_hash_lib.Std.Hash.state
          -> 'a
          -> Base__.Ppx_hash_lib.Std.Hash.state)
      -> Base__.Ppx_hash_lib.Std.Hash.state
      -> ('a, 'b) Pickles_types__Vector.t
      -> Base__.Ppx_hash_lib.Std.Hash.state

    val equal :
         ('a -> 'a -> bool)
      -> ('a, 'b) Pickles_types__Vector.t
      -> ('a, 'c) Pickles_types__Vector.t
      -> bool

    val to_yojson :
         ('a -> Yojson.Safe.t)
      -> ('a, Pickles_types.Nat.N4.n) Pickles_types__Vector.t
      -> Yojson.Safe.t

    val of_yojson :
         (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or)
      -> Yojson.Safe.t
      -> ('a, Pickles_types.Nat.N4.n) Pickles_types__Vector.t
         Ppx_deriving_yojson_runtime.error_or

    val t_of_sexp :
         (Base__.Sexp.t -> 'a)
      -> Base__.Sexp.t
      -> ('a, Pickles_types.Nat.N4.n) Pickles_types__Vector.t

    val sexp_of_t :
         ('a -> Base__.Sexp.t)
      -> ('a, Pickles_types.Nat.N4.n) Pickles_types__Vector.t
      -> Base__.Sexp.t

    val map :
         'a t
      -> f:('a -> 'b)
      -> ('b, Pickles_types.Nat.N4.n) Pickles_types__Vector.t

    val of_list_exn : 'a list -> 'a t

    val to_list : 'a t -> 'a list
  end

  val length : int

  type t = Limb_vector__Constant.Hex64.t A.t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val compare : t -> t -> int

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val equal : t -> t -> bool

  val to_bits : (Core_kernel.Int64.t, 'a) Pickles_types.Vector.t -> bool list

  val of_bits :
       bool list
    -> (Core_kernel.Int64.t, Pickles_types.Nat.N4.n) Pickles_types.Vector.t

  val of_tock_field :
       Backend.Tock.Field.t
    -> (Core_kernel.Int64.t, Pickles_types.Nat.N4.n) Pickles_types.Vector.t

  val dummy : t

  module Stable : sig
    module V1 : sig
      type t =
        Limb_vector.Constant.Hex64.Stable.V1.t
        Pickles_types.Vector.Vector_4.Stable.V1.t

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val compare : t -> t -> int

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

      val equal : t -> t -> bool

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

  val to_tick_field :
    (Core_kernel.Int64.t, 'a) Pickles_types.Vector.t -> Backend.Tick.Field.t

  val to_tock_field :
    (Core_kernel.Int64.t, 'a) Pickles_types.Vector.t -> Backend.Tock.Field.t

  val of_tick_field :
       Backend.Tick.Field.t
    -> (Core_kernel.Int64.t, Pickles_types.Nat.N4.n) Pickles_types.Vector.t
end

module Make : functor (Impl : Snarky_backendless.Snark_intf.Run) -> sig
  type t = Impl.Field.t

  val to_bits : t -> Impl.Boolean.var list

  module Unsafe : sig
    val to_bits_unboolean : t -> Impl.Boolean.var list
  end

  module Constant : sig
    module A = Constant.A

    val length : int

    type t = Limb_vector__Constant.Hex64.t A.t

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

    val compare : t -> t -> int

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

    val equal : t -> t -> bool

    val of_bits :
         bool list
      -> (Core_kernel.Int64.t, Pickles_types.Nat.N4.n) Pickles_types.Vector.t

    val of_tock_field :
         Backend.Tock.Field.t
      -> (Core_kernel.Int64.t, Pickles_types.Nat.N4.n) Pickles_types.Vector.t

    val dummy : t

    module Stable = Constant.Stable

    val to_tick_field :
      (Core_kernel.Int64.t, 'a) Pickles_types.Vector.t -> Backend.Tick.Field.t

    val to_tock_field :
      (Core_kernel.Int64.t, 'a) Pickles_types.Vector.t -> Backend.Tock.Field.t

    val of_tick_field :
         Backend.Tick.Field.t
      -> (Core_kernel.Int64.t, Pickles_types.Nat.N4.n) Pickles_types.Vector.t

    val to_bits : (Core_kernel.Int64.t, 'a) Pickles_types.Vector.t -> bool list
  end

  val typ :
    ( t
    , (Core_kernel.Int64.t, Pickles_types.Nat.N4.n) Pickles_types.Vector.t )
    Impl.Typ.t
end
