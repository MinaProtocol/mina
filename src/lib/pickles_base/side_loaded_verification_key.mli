module Ds = Domains

val bits : len:int -> int -> bool list

val max_log2_degree : int

module Width : sig
  module Stable : sig
    module V1 : sig
      type t

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val bin_size_t : t Bin_prot.Size.sizer

      val bin_write_t : t Bin_prot.Write.writer

      val bin_read_t : t Bin_prot.Read.reader

      val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

      val bin_shape_t : Bin_prot.Shape.t

      val bin_writer_t : t Bin_prot.Type_class.writer

      val bin_reader_t : t Bin_prot.Type_class.reader

      val bin_t : t Bin_prot.Type_class.t

      val __versioned__ : unit

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t

      val equal : t -> t -> bool

      val compare : t -> t -> int

      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value
    end

    module Latest = V1

    val versions :
      (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t))
      array

    val bin_read_to_latest_opt :
         Core_kernel.Bin_prot.Common.buf
      -> pos_ref:int Core_kernel.ref
      -> V1.t option
  end

  type t = Stable.V1.t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp : Sexplib0.Sexp.t -> t

  val sexp_of_t : t -> Sexplib0.Sexp.t

  val equal : t -> t -> bool

  val compare : t -> t -> int

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val of_int_exn : int -> t

  val to_int : t -> int

  val to_bits : t -> bool list

  val zero : t

  module Max : Pickles_types.Nat.Add.Intf_transparent

  module Max_vector : Pickles_types.Vector.With_version(Max).S

  module Max_at_most : sig
    module Stable : sig
      module V1 : sig
        type 'a t = ('a, Max.n) Pickles_types.At_most.t

        val to_yojson : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t

        val of_yojson :
             (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or)
          -> Yojson.Safe.t
          -> 'a t Ppx_deriving_yojson_runtime.error_or

        val bin_shape_t : Bin_prot.Shape.t -> Bin_prot.Shape.t

        val bin_size_t : ('a, 'a t) Bin_prot.Size.sizer1

        val bin_write_t : ('a, 'a t) Bin_prot.Write.writer1

        val bin_read_t : ('a, 'a t) Bin_prot.Read.reader1

        val __bin_read_t__ : ('a, int -> 'a t) Bin_prot.Read.reader1

        val bin_writer_t : ('a, 'a t) Bin_prot.Type_class.S1.writer

        val bin_reader_t : ('a, 'a t) Bin_prot.Type_class.S1.reader

        val bin_t : ('a, 'a t) Bin_prot.Type_class.S1.t

        val __versioned__ : unit

        val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int

        val t_of_sexp : (Sexplib0.Sexp.t -> 'a) -> Sexplib0.Sexp.t -> 'a t

        val sexp_of_t : ('a -> Sexplib0.Sexp.t) -> 'a t -> Sexplib0.Sexp.t

        val hash_fold_t :
             (Ppx_hash_lib.Std.Hash.state -> 'a -> Ppx_hash_lib.Std.Hash.state)
          -> Ppx_hash_lib.Std.Hash.state
          -> 'a t
          -> Ppx_hash_lib.Std.Hash.state

        val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool
      end

      module Latest = V1
    end

    type 'a t = 'a Stable.Latest.t

    val to_yojson : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t

    val of_yojson :
         (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or)
      -> Yojson.Safe.t
      -> 'a t Ppx_deriving_yojson_runtime.error_or

    val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int

    val t_of_sexp : (Sexplib0.Sexp.t -> 'a) -> Sexplib0.Sexp.t -> 'a t

    val sexp_of_t : ('a -> Sexplib0.Sexp.t) -> 'a t -> Sexplib0.Sexp.t

    val hash_fold_t :
         (Ppx_hash_lib.Std.Hash.state -> 'a -> Ppx_hash_lib.Std.Hash.state)
      -> Ppx_hash_lib.Std.Hash.state
      -> 'a t
      -> Ppx_hash_lib.Std.Hash.state

    val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool
  end

  module Length : Pickles_types.Nat.Add.Intf_transparent
end

module Max_branches : sig
  type 'a plus_n = 'a Pickles_types__Nat.N7.plus_n Pickles_types__Nat.s

  type n = Pickles_types__Nat.z plus_n

  val n :
    Pickles_types__Nat.z Pickles_types__Nat.N7.plus_n Pickles_types__Nat.s
    Pickles_types__Nat.t

  val add :
       'a Pickles_types__Nat.nat
    -> 'a Pickles_types__Nat.N7.plus_n Pickles_types__Nat.s Pickles_types__Nat.t
       * ( Pickles_types__Nat.z Pickles_types__Nat.N7.plus_n Pickles_types__Nat.s
         , 'a
         , 'a Pickles_types__Nat.N7.plus_n Pickles_types__Nat.s )
         Pickles_types__Nat.Adds.t

  val eq : ('a, 'a) Core_kernel.Type_equal.t

  module Log2 = Pickles_types.Nat.N3
end

module Max_branches_vec : sig
  module Stable : sig
    module V1 : sig
      type 'a t = 'a Pickles_types.At_most.At_most_8.Stable.V1.t

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

  type 'a t = 'a Stable.V1.t

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
end

module Domains : sig
  module Stable : sig
    module V1 : sig
      type 'a t = { h : 'a }

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

      val to_hlist : 'a t -> (unit, 'a -> unit) H_list.t

      val of_hlist : (unit, 'a -> unit) H_list.t -> 'a t

      val h : 'a t -> 'a

      module Fields : sig
        val names : string list

        val h :
          ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm

        val make_creator :
             h:
               (   ( [< `Read | `Set_and_create ]
                   , 'a t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> 'b
                -> ('c -> 'd) * 'e)
          -> 'b
          -> ('c -> 'd t) * 'e

        val create : h:'a -> 'a t

        val map :
             h:
               (   ( [< `Read | `Set_and_create ]
                   , 'a t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> 'b)
          -> 'b t

        val iter :
             h:
               (   ( [< `Read | `Set_and_create ]
                   , 'a t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> unit

        val fold :
             init:'a
          -> h:
               (   'a
                -> ( [< `Read | `Set_and_create ]
                   , 'b t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> 'c)
          -> 'c

        val map_poly :
             ([< `Read | `Set_and_create ], 'a t, 'b) Fieldslib.Field.user
          -> 'b list

        val for_all :
             h:
               (   ( [< `Read | `Set_and_create ]
                   , 'a t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> bool

        val exists :
             h:
               (   ( [< `Read | `Set_and_create ]
                   , 'a t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> bool

        val to_list :
             h:
               (   ( [< `Read | `Set_and_create ]
                   , 'a t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> 'b)
          -> 'b list

        module Direct : sig
          val iter :
               'a t
            -> h:
                 (   ( [< `Read | `Set_and_create ]
                     , 'b t
                     , 'b )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> 'c)
            -> 'c

          val fold :
               'a t
            -> init:'b
            -> h:
                 (   'b
                  -> ( [< `Read | `Set_and_create ]
                     , 'c t
                     , 'c )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> 'd)
            -> 'd

          val for_all :
               'a t
            -> h:
                 (   ( [< `Read | `Set_and_create ]
                     , 'b t
                     , 'b )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> bool)
            -> bool

          val exists :
               'a t
            -> h:
                 (   ( [< `Read | `Set_and_create ]
                     , 'b t
                     , 'b )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> bool)
            -> bool

          val to_list :
               'a t
            -> h:
                 (   ( [< `Read | `Set_and_create ]
                     , 'b t
                     , 'b )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> 'c)
            -> 'c list

          val map :
               'a t
            -> h:
                 (   ( [< `Read | `Set_and_create ]
                     , 'b t
                     , 'b )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> 'c)
            -> 'c t

          val set_all_mutable_fields : 'a -> unit
        end
      end

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

  type 'a t = 'a Stable.V1.t = { h : 'a }

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

  val to_hlist : 'a t -> (unit, 'a -> unit) H_list.t

  val of_hlist : (unit, 'a -> unit) H_list.t -> 'a t

  val h : 'a t -> 'a

  module Fields : sig
    val names : string list

    val h : ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm

    val make_creator :
         h:
           (   ( [< `Read | `Set_and_create ]
               , 'a t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'b
            -> ('c -> 'd) * 'e)
      -> 'b
      -> ('c -> 'd t) * 'e

    val create : h:'a -> 'a t

    val map :
         h:
           (   ( [< `Read | `Set_and_create ]
               , 'a t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'b)
      -> 'b t

    val iter :
         h:
           (   ( [< `Read | `Set_and_create ]
               , 'a t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> unit

    val fold :
         init:'a
      -> h:
           (   'a
            -> ( [< `Read | `Set_and_create ]
               , 'b t
               , 'b )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> 'c

    val map_poly :
      ([< `Read | `Set_and_create ], 'a t, 'b) Fieldslib.Field.user -> 'b list

    val for_all :
         h:
           (   ( [< `Read | `Set_and_create ]
               , 'a t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val exists :
         h:
           (   ( [< `Read | `Set_and_create ]
               , 'a t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val to_list :
         h:
           (   ( [< `Read | `Set_and_create ]
               , 'a t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'b)
      -> 'b list

    module Direct : sig
      val iter :
           'a t
        -> h:
             (   ( [< `Read | `Set_and_create ]
                 , 'b t
                 , 'b )
                 Fieldslib.Field.t_with_perm
              -> 'a t
              -> 'a
              -> 'c)
        -> 'c

      val fold :
           'a t
        -> init:'b
        -> h:
             (   'b
              -> ( [< `Read | `Set_and_create ]
                 , 'c t
                 , 'c )
                 Fieldslib.Field.t_with_perm
              -> 'a t
              -> 'a
              -> 'd)
        -> 'd

      val for_all :
           'a t
        -> h:
             (   ( [< `Read | `Set_and_create ]
                 , 'b t
                 , 'b )
                 Fieldslib.Field.t_with_perm
              -> 'a t
              -> 'a
              -> bool)
        -> bool

      val exists :
           'a t
        -> h:
             (   ( [< `Read | `Set_and_create ]
                 , 'b t
                 , 'b )
                 Fieldslib.Field.t_with_perm
              -> 'a t
              -> 'a
              -> bool)
        -> bool

      val to_list :
           'a t
        -> h:
             (   ( [< `Read | `Set_and_create ]
                 , 'b t
                 , 'b )
                 Fieldslib.Field.t_with_perm
              -> 'a t
              -> 'a
              -> 'c)
        -> 'c list

      val map :
           'a t
        -> h:
             (   ( [< `Read | `Set_and_create ]
                 , 'b t
                 , 'b )
                 Fieldslib.Field.t_with_perm
              -> 'a t
              -> 'a
              -> 'c)
        -> 'c t

      val set_all_mutable_fields : 'a -> unit
    end
  end

  val iter : 'a t -> f:('a -> 'b) -> 'b

  val map : 'a t -> f:('a -> 'b) -> 'b t
end

module Repr : sig
  module Stable : sig
    module V1 : sig
      type 'g t =
        { step_data :
            (Domain.Stable.V1.t Domains.t * Width.t) Max_branches_vec.t
        ; max_width : Width.t
        ; wrap_index :
            'g list Pickles_types.Plonk_verification_key_evals.Stable.V1.t
        }

      val version : int

      val __versioned__ : unit

      val to_latest : 'a -> 'a

      module With_version : sig
        type 'g typ = 'g t

        val bin_shape_typ :
          Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t

        val bin_size_typ :
             'g Core_kernel.Bin_prot.Size.sizer
          -> 'g typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ :
             'g Core_kernel.Bin_prot.Write.writer
          -> 'g typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'a typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
             'g Core_kernel.Bin_prot.Read.reader
          -> (int -> 'g typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ :
             'g Core_kernel.Bin_prot.Read.reader
          -> 'g typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'a typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'a typ Core_kernel.Bin_prot.Type_class.t

        type 'g t = { version : int; t : 'g typ }

        val bin_shape_t :
          Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'g Core_kernel.Bin_prot.Size.sizer
          -> 'g t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'g Core_kernel.Bin_prot.Write.writer
          -> 'g t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'a t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ :
             'g Core_kernel.Bin_prot.Read.reader
          -> (int -> 'g t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t :
             'g Core_kernel.Bin_prot.Read.reader
          -> 'g t Core_kernel.Bin_prot.Read.reader

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

  type 'g t = 'g Stable.V1.t =
    { step_data : (Domain.t Domains.t * Width.t) Max_branches_vec.t
    ; max_width : Width.t
    ; wrap_index : 'g list Pickles_types.Plonk_verification_key_evals.t
    }
end

module Poly : sig
  module Stable : sig
    module V1 : sig
      type ('g, 'vk) t =
        { step_data :
            (Domain.Stable.V1.t Domains.t * Width.t) Max_branches_vec.t
        ; max_width : Width.t
        ; wrap_index :
            'g list Pickles_types.Plonk_verification_key_evals.Stable.V1.t
        ; wrap_vk : 'vk option
        }

      val to_yojson :
           ('g -> Yojson.Safe.t)
        -> ('vk -> Yojson.Safe.t)
        -> ('g, 'vk) t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'g Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'vk Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ('g, 'vk) t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'g)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'vk)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('g, 'vk) t

      val sexp_of_t :
           ('g -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('vk -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('g, 'vk) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val equal :
           ('g -> 'g -> Core_kernel__.Import.bool)
        -> ('vk -> 'vk -> Core_kernel__.Import.bool)
        -> ('g, 'vk) t
        -> ('g, 'vk) t
        -> bool

      val compare :
           ('g -> 'g -> Core_kernel__.Import.int)
        -> ('vk -> 'vk -> Core_kernel__.Import.int)
        -> ('g, 'vk) t
        -> ('g, 'vk) t
        -> Core_kernel__.Import.int

      val hash_fold_t :
           (Ppx_hash_lib.Std.Hash.state -> 'g -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'vk -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('g, 'vk) t
        -> Ppx_hash_lib.Std.Hash.state

      module With_version : sig
        type ('g, 'vk) typ = ('g, 'vk) t

        val bin_shape_typ :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_typ :
             'g Core_kernel.Bin_prot.Size.sizer
          -> 'vk Core_kernel.Bin_prot.Size.sizer
          -> ('g, 'vk) typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ :
             'g Core_kernel.Bin_prot.Write.writer
          -> 'vk Core_kernel.Bin_prot.Write.writer
          -> ('g, 'vk) typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
             'g Core_kernel.Bin_prot.Read.reader
          -> 'vk Core_kernel.Bin_prot.Read.reader
          -> (int -> ('g, 'vk) typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ :
             'g Core_kernel.Bin_prot.Read.reader
          -> 'vk Core_kernel.Bin_prot.Read.reader
          -> ('g, 'vk) typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.t

        type ('g, 'vk) t = { version : int; t : ('g, 'vk) typ }

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'g Core_kernel.Bin_prot.Size.sizer
          -> 'vk Core_kernel.Bin_prot.Size.sizer
          -> ('g, 'vk) t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'g Core_kernel.Bin_prot.Write.writer
          -> 'vk Core_kernel.Bin_prot.Write.writer
          -> ('g, 'vk) t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ :
             'g Core_kernel.Bin_prot.Read.reader
          -> 'vk Core_kernel.Bin_prot.Read.reader
          -> (int -> ('g, 'vk) t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t :
             'g Core_kernel.Bin_prot.Read.reader
          -> 'vk Core_kernel.Bin_prot.Read.reader
          -> ('g, 'vk) t Core_kernel.Bin_prot.Read.reader

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

  type ('g, 'vk) t = ('g, 'vk) Stable.V1.t =
    { step_data : (Domain.t Domains.t * Width.t) Max_branches_vec.t
    ; max_width : Width.t
    ; wrap_index : 'g list Pickles_types.Plonk_verification_key_evals.t
    ; wrap_vk : 'vk option
    }

  val to_yojson :
       ('g -> Yojson.Safe.t)
    -> ('vk -> Yojson.Safe.t)
    -> ('g, 'vk) t
    -> Yojson.Safe.t

  val of_yojson :
       (Yojson.Safe.t -> 'g Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'vk Ppx_deriving_yojson_runtime.error_or)
    -> Yojson.Safe.t
    -> ('g, 'vk) t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp :
       (Ppx_sexp_conv_lib.Sexp.t -> 'g)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'vk)
    -> Ppx_sexp_conv_lib.Sexp.t
    -> ('g, 'vk) t

  val sexp_of_t :
       ('g -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('vk -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('g, 'vk) t
    -> Ppx_sexp_conv_lib.Sexp.t

  val equal :
       ('g -> 'g -> Core_kernel__.Import.bool)
    -> ('vk -> 'vk -> Core_kernel__.Import.bool)
    -> ('g, 'vk) t
    -> ('g, 'vk) t
    -> bool

  val compare :
       ('g -> 'g -> Core_kernel__.Import.int)
    -> ('vk -> 'vk -> Core_kernel__.Import.int)
    -> ('g, 'vk) t
    -> ('g, 'vk) t
    -> Core_kernel__.Import.int

  val hash_fold_t :
       (Ppx_hash_lib.Std.Hash.state -> 'g -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'vk -> Ppx_hash_lib.Std.Hash.state)
    -> Ppx_hash_lib.Std.Hash.state
    -> ('g, 'vk) t
    -> Ppx_hash_lib.Std.Hash.state
end

val dummy_domains : Domain.t Domains.t

val dummy_width : Width.t

val wrap_index_to_input :
     ('gs -> 'f array)
  -> 'gs Pickles_types.Plonk_verification_key_evals.t
  -> ('f, 'a) Random_oracle_input.t

val to_input : ('a * 'a, 'b) Poly.t -> ('a, bool) Random_oracle_input.t
