module Stable : sig
  module V1 : sig
    type ('magnitude, 'sgn) t = { magnitude : 'magnitude; sgn : 'sgn }

    val to_yojson :
         ('magnitude -> Yojson.Safe.t)
      -> ('sgn -> Yojson.Safe.t)
      -> ('magnitude, 'sgn) t
      -> Yojson.Safe.t

    val of_yojson :
         (Yojson.Safe.t -> 'magnitude Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'sgn Ppx_deriving_yojson_runtime.error_or)
      -> Yojson.Safe.t
      -> ('magnitude, 'sgn) t Ppx_deriving_yojson_runtime.error_or

    val version : int

    val __versioned__ : unit

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'magnitude)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'sgn)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> ('magnitude, 'sgn) t

    val sexp_of_t :
         ('magnitude -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('sgn -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('magnitude, 'sgn) t
      -> Ppx_sexp_conv_lib.Sexp.t

    val hash_fold_t :
         (   Ppx_hash_lib.Std.Hash.state
          -> 'magnitude
          -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'sgn -> Ppx_hash_lib.Std.Hash.state)
      -> Ppx_hash_lib.Std.Hash.state
      -> ('magnitude, 'sgn) t
      -> Ppx_hash_lib.Std.Hash.state

    val compare :
         ('magnitude -> 'magnitude -> int)
      -> ('sgn -> 'sgn -> int)
      -> ('magnitude, 'sgn) t
      -> ('magnitude, 'sgn) t
      -> int

    val equal :
         ('magnitude -> 'magnitude -> bool)
      -> ('sgn -> 'sgn -> bool)
      -> ('magnitude, 'sgn) t
      -> ('magnitude, 'sgn) t
      -> bool

    module With_version : sig
      type ('magnitude, 'sgn) typ = ('magnitude, 'sgn) t

      val bin_shape_typ :
           Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t

      val bin_size_typ :
           'magnitude Core_kernel.Bin_prot.Size.sizer
        -> 'sgn Core_kernel.Bin_prot.Size.sizer
        -> ('magnitude, 'sgn) typ Core_kernel.Bin_prot.Size.sizer

      val bin_write_typ :
           'magnitude Core_kernel.Bin_prot.Write.writer
        -> 'sgn Core_kernel.Bin_prot.Write.writer
        -> ('magnitude, 'sgn) typ Core_kernel.Bin_prot.Write.writer

      val bin_writer_typ :
           'a Core_kernel.Bin_prot.Type_class.writer
        -> 'b Core_kernel.Bin_prot.Type_class.writer
        -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.writer

      val __bin_read_typ__ :
           'magnitude Core_kernel.Bin_prot.Read.reader
        -> 'sgn Core_kernel.Bin_prot.Read.reader
        -> (int -> ('magnitude, 'sgn) typ) Core_kernel.Bin_prot.Read.reader

      val bin_read_typ :
           'magnitude Core_kernel.Bin_prot.Read.reader
        -> 'sgn Core_kernel.Bin_prot.Read.reader
        -> ('magnitude, 'sgn) typ Core_kernel.Bin_prot.Read.reader

      val bin_reader_typ :
           'a Core_kernel.Bin_prot.Type_class.reader
        -> 'b Core_kernel.Bin_prot.Type_class.reader
        -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.reader

      val bin_typ :
           'a Core_kernel.Bin_prot.Type_class.t
        -> 'b Core_kernel.Bin_prot.Type_class.t
        -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.t

      type ('magnitude, 'sgn) t = { version : int; t : ('magnitude, 'sgn) typ }

      val bin_shape_t :
           Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t

      val bin_size_t :
           'magnitude Core_kernel.Bin_prot.Size.sizer
        -> 'sgn Core_kernel.Bin_prot.Size.sizer
        -> ('magnitude, 'sgn) t Core_kernel.Bin_prot.Size.sizer

      val bin_write_t :
           'magnitude Core_kernel.Bin_prot.Write.writer
        -> 'sgn Core_kernel.Bin_prot.Write.writer
        -> ('magnitude, 'sgn) t Core_kernel.Bin_prot.Write.writer

      val bin_writer_t :
           'a Core_kernel.Bin_prot.Type_class.writer
        -> 'b Core_kernel.Bin_prot.Type_class.writer
        -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.writer

      val __bin_read_t__ :
           'magnitude Core_kernel.Bin_prot.Read.reader
        -> 'sgn Core_kernel.Bin_prot.Read.reader
        -> (int -> ('magnitude, 'sgn) t) Core_kernel.Bin_prot.Read.reader

      val bin_read_t :
           'magnitude Core_kernel.Bin_prot.Read.reader
        -> 'sgn Core_kernel.Bin_prot.Read.reader
        -> ('magnitude, 'sgn) t Core_kernel.Bin_prot.Read.reader

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

type ('magnitude, 'sgn) t = ('magnitude, 'sgn) Stable.V1.t =
  { magnitude : 'magnitude; sgn : 'sgn }

val to_yojson :
     ('magnitude -> Yojson.Safe.t)
  -> ('sgn -> Yojson.Safe.t)
  -> ('magnitude, 'sgn) t
  -> Yojson.Safe.t

val of_yojson :
     (Yojson.Safe.t -> 'magnitude Ppx_deriving_yojson_runtime.error_or)
  -> (Yojson.Safe.t -> 'sgn Ppx_deriving_yojson_runtime.error_or)
  -> Yojson.Safe.t
  -> ('magnitude, 'sgn) t Ppx_deriving_yojson_runtime.error_or

val t_of_sexp :
     (Ppx_sexp_conv_lib.Sexp.t -> 'magnitude)
  -> (Ppx_sexp_conv_lib.Sexp.t -> 'sgn)
  -> Ppx_sexp_conv_lib.Sexp.t
  -> ('magnitude, 'sgn) t

val sexp_of_t :
     ('magnitude -> Ppx_sexp_conv_lib.Sexp.t)
  -> ('sgn -> Ppx_sexp_conv_lib.Sexp.t)
  -> ('magnitude, 'sgn) t
  -> Ppx_sexp_conv_lib.Sexp.t

val hash_fold_t :
     (Ppx_hash_lib.Std.Hash.state -> 'magnitude -> Ppx_hash_lib.Std.Hash.state)
  -> (Ppx_hash_lib.Std.Hash.state -> 'sgn -> Ppx_hash_lib.Std.Hash.state)
  -> Ppx_hash_lib.Std.Hash.state
  -> ('magnitude, 'sgn) t
  -> Ppx_hash_lib.Std.Hash.state

val compare :
     ('magnitude -> 'magnitude -> int)
  -> ('sgn -> 'sgn -> int)
  -> ('magnitude, 'sgn) t
  -> ('magnitude, 'sgn) t
  -> int

val equal :
     ('magnitude -> 'magnitude -> bool)
  -> ('sgn -> 'sgn -> bool)
  -> ('magnitude, 'sgn) t
  -> ('magnitude, 'sgn) t
  -> bool

val map : f:('a -> 'b) -> ('a, 'c) t -> ('b, 'c) t
