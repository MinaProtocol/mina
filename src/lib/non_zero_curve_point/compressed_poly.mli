module Poly : sig
  module Stable : sig
    module V1 : sig
      type ('field, 'boolean) t = { x : 'field; is_odd : 'boolean }

      val version : int

      val __versioned__ : unit

      val compare :
           ('field -> 'field -> int)
        -> ('boolean -> 'boolean -> int)
        -> ('field, 'boolean) t
        -> ('field, 'boolean) t
        -> int

      val equal :
           ('field -> 'field -> bool)
        -> ('boolean -> 'boolean -> bool)
        -> ('field, 'boolean) t
        -> ('field, 'boolean) t
        -> bool

      val hash_fold_t :
           (Ppx_hash_lib.Std.Hash.state -> 'field -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'boolean
            -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('field, 'boolean) t
        -> Ppx_hash_lib.Std.Hash.state

      val to_hlist :
        ('field, 'boolean) t -> (unit, 'field -> 'boolean -> unit) H_list.t

      val of_hlist :
        (unit, 'field -> 'boolean -> unit) H_list.t -> ('field, 'boolean) t

      module With_version : sig
        type ('field, 'boolean) typ = ('field, 'boolean) t

        val bin_shape_typ :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_typ :
             'field Core_kernel.Bin_prot.Size.sizer
          -> 'boolean Core_kernel.Bin_prot.Size.sizer
          -> ('field, 'boolean) typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ :
             'field Core_kernel.Bin_prot.Write.writer
          -> 'boolean Core_kernel.Bin_prot.Write.writer
          -> ('field, 'boolean) typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
             'field Core_kernel.Bin_prot.Read.reader
          -> 'boolean Core_kernel.Bin_prot.Read.reader
          -> (int -> ('field, 'boolean) typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ :
             'field Core_kernel.Bin_prot.Read.reader
          -> 'boolean Core_kernel.Bin_prot.Read.reader
          -> ('field, 'boolean) typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.t

        type ('field, 'boolean) t =
          { version : int; t : ('field, 'boolean) typ }

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'field Core_kernel.Bin_prot.Size.sizer
          -> 'boolean Core_kernel.Bin_prot.Size.sizer
          -> ('field, 'boolean) t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'field Core_kernel.Bin_prot.Write.writer
          -> 'boolean Core_kernel.Bin_prot.Write.writer
          -> ('field, 'boolean) t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ :
             'field Core_kernel.Bin_prot.Read.reader
          -> 'boolean Core_kernel.Bin_prot.Read.reader
          -> (int -> ('field, 'boolean) t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t :
             'field Core_kernel.Bin_prot.Read.reader
          -> 'boolean Core_kernel.Bin_prot.Read.reader
          -> ('field, 'boolean) t Core_kernel.Bin_prot.Read.reader

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

  type ('field, 'boolean) t = ('field, 'boolean) Stable.V1.t =
    { x : 'field; is_odd : 'boolean }

  val compare :
       ('field -> 'field -> int)
    -> ('boolean -> 'boolean -> int)
    -> ('field, 'boolean) t
    -> ('field, 'boolean) t
    -> int

  val equal :
       ('field -> 'field -> bool)
    -> ('boolean -> 'boolean -> bool)
    -> ('field, 'boolean) t
    -> ('field, 'boolean) t
    -> bool

  val hash_fold_t :
       (Ppx_hash_lib.Std.Hash.state -> 'field -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'boolean -> Ppx_hash_lib.Std.Hash.state)
    -> Ppx_hash_lib.Std.Hash.state
    -> ('field, 'boolean) t
    -> Ppx_hash_lib.Std.Hash.state

  val to_hlist :
    ('field, 'boolean) t -> (unit, 'field -> 'boolean -> unit) H_list.t

  val of_hlist :
    (unit, 'field -> 'boolean -> unit) H_list.t -> ('field, 'boolean) t
end
