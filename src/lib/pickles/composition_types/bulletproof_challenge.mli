module Stable : sig
  module V1 : sig
    type 'challenge t = { prechallenge : 'challenge }

    val to_yojson :
      ('challenge -> Yojson.Safe.t) -> 'challenge t -> Yojson.Safe.t

    val of_yojson :
         (Yojson.Safe.t -> 'challenge Ppx_deriving_yojson_runtime.error_or)
      -> Yojson.Safe.t
      -> 'challenge t Ppx_deriving_yojson_runtime.error_or

    val version : int

    val __versioned__ : unit

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'challenge)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> 'challenge t

    val sexp_of_t :
         ('challenge -> Ppx_sexp_conv_lib.Sexp.t)
      -> 'challenge t
      -> Ppx_sexp_conv_lib.Sexp.t

    val compare :
      ('challenge -> 'challenge -> int) -> 'challenge t -> 'challenge t -> int

    val hash_fold_t :
         (   Ppx_hash_lib.Std.Hash.state
          -> 'challenge
          -> Ppx_hash_lib.Std.Hash.state)
      -> Ppx_hash_lib.Std.Hash.state
      -> 'challenge t
      -> Ppx_hash_lib.Std.Hash.state

    val equal :
      ('challenge -> 'challenge -> bool) -> 'challenge t -> 'challenge t -> bool

    module With_version : sig
      type 'challenge typ = 'challenge t

      val bin_shape_typ :
        Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t

      val bin_size_typ :
           'challenge Core_kernel.Bin_prot.Size.sizer
        -> 'challenge typ Core_kernel.Bin_prot.Size.sizer

      val bin_write_typ :
           'challenge Core_kernel.Bin_prot.Write.writer
        -> 'challenge typ Core_kernel.Bin_prot.Write.writer

      val bin_writer_typ :
           'a Core_kernel.Bin_prot.Type_class.writer
        -> 'a typ Core_kernel.Bin_prot.Type_class.writer

      val __bin_read_typ__ :
           'challenge Core_kernel.Bin_prot.Read.reader
        -> (int -> 'challenge typ) Core_kernel.Bin_prot.Read.reader

      val bin_read_typ :
           'challenge Core_kernel.Bin_prot.Read.reader
        -> 'challenge typ Core_kernel.Bin_prot.Read.reader

      val bin_reader_typ :
           'a Core_kernel.Bin_prot.Type_class.reader
        -> 'a typ Core_kernel.Bin_prot.Type_class.reader

      val bin_typ :
           'a Core_kernel.Bin_prot.Type_class.t
        -> 'a typ Core_kernel.Bin_prot.Type_class.t

      type 'challenge t = { version : int; t : 'challenge typ }

      val bin_shape_t :
        Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t

      val bin_size_t :
           'challenge Core_kernel.Bin_prot.Size.sizer
        -> 'challenge t Core_kernel.Bin_prot.Size.sizer

      val bin_write_t :
           'challenge Core_kernel.Bin_prot.Write.writer
        -> 'challenge t Core_kernel.Bin_prot.Write.writer

      val bin_writer_t :
           'a Core_kernel.Bin_prot.Type_class.writer
        -> 'a t Core_kernel.Bin_prot.Type_class.writer

      val __bin_read_t__ :
           'challenge Core_kernel.Bin_prot.Read.reader
        -> (int -> 'challenge t) Core_kernel.Bin_prot.Read.reader

      val bin_read_t :
           'challenge Core_kernel.Bin_prot.Read.reader
        -> 'challenge t Core_kernel.Bin_prot.Read.reader

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

type 'challenge t = 'challenge Stable.V1.t = { prechallenge : 'challenge }

val to_yojson : ('challenge -> Yojson.Safe.t) -> 'challenge t -> Yojson.Safe.t

val of_yojson :
     (Yojson.Safe.t -> 'challenge Ppx_deriving_yojson_runtime.error_or)
  -> Yojson.Safe.t
  -> 'challenge t Ppx_deriving_yojson_runtime.error_or

val t_of_sexp :
     (Ppx_sexp_conv_lib.Sexp.t -> 'challenge)
  -> Ppx_sexp_conv_lib.Sexp.t
  -> 'challenge t

val sexp_of_t :
     ('challenge -> Ppx_sexp_conv_lib.Sexp.t)
  -> 'challenge t
  -> Ppx_sexp_conv_lib.Sexp.t

val compare :
  ('challenge -> 'challenge -> int) -> 'challenge t -> 'challenge t -> int

val hash_fold_t :
     (Ppx_hash_lib.Std.Hash.state -> 'challenge -> Ppx_hash_lib.Std.Hash.state)
  -> Ppx_hash_lib.Std.Hash.state
  -> 'challenge t
  -> Ppx_hash_lib.Std.Hash.state

val equal :
  ('challenge -> 'challenge -> bool) -> 'challenge t -> 'challenge t -> bool

val pack : 'a t -> 'a

val unpack : 'a -> 'a t

val typ :
     ('a, 'b, 'c) Snarky_backendless.Typ.t
  -> ( 'a Pickles_types.Scalar_challenge.t t
     , 'b Pickles_types.Scalar_challenge.t t
     , 'c )
     Snarky_backendless.Typ.t
