module Stable : sig
  module V1 : sig
    type t = { h : Domain.Stable.V1.t; x : Domain.Stable.V1.t }

    val version : int

    val __versioned__ : unit

    val x : t -> Domain.Stable.V1.t

    val h : t -> Domain.Stable.V1.t

    module Fields : sig
      val names : string list

      val x :
        ( [< `Read | `Set_and_create ]
        , t
        , Domain.Stable.V1.t )
        Fieldslib.Field.t_with_perm

      val h :
        ( [< `Read | `Set_and_create ]
        , t
        , Domain.Stable.V1.t )
        Fieldslib.Field.t_with_perm

      val make_creator :
           h:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Domain.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> 'a
              -> ('b -> Domain.Stable.V1.t) * 'c)
        -> x:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Domain.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> 'c
              -> ('b -> Domain.Stable.V1.t) * 'd)
        -> 'a
        -> ('b -> t) * 'd

      val create : h:Domain.Stable.V1.t -> x:Domain.Stable.V1.t -> t

      val map :
           h:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Domain.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> Domain.Stable.V1.t)
        -> x:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Domain.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> Domain.Stable.V1.t)
        -> t

      val iter :
           h:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Domain.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> x:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Domain.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> unit

      val fold :
           init:'a
        -> h:
             (   'a
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Domain.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> 'b)
        -> x:
             (   'b
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Domain.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> 'c)
        -> 'c

      val map_poly :
        ([< `Read | `Set_and_create ], t, 'a) Fieldslib.Field.user -> 'a list

      val for_all :
           h:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Domain.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> x:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Domain.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val exists :
           h:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Domain.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> x:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Domain.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val to_list :
           h:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Domain.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> x:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Domain.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> 'a list

      module Direct : sig
        val iter :
             t
          -> h:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Domain.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Domain.Stable.V1.t
                -> 'a)
          -> x:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Domain.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Domain.Stable.V1.t
                -> 'b)
          -> 'b

        val fold :
             t
          -> init:'a
          -> h:
               (   'a
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , Domain.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Domain.Stable.V1.t
                -> 'b)
          -> x:
               (   'b
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , Domain.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Domain.Stable.V1.t
                -> 'c)
          -> 'c

        val for_all :
             t
          -> h:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Domain.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Domain.Stable.V1.t
                -> bool)
          -> x:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Domain.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Domain.Stable.V1.t
                -> bool)
          -> bool

        val exists :
             t
          -> h:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Domain.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Domain.Stable.V1.t
                -> bool)
          -> x:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Domain.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Domain.Stable.V1.t
                -> bool)
          -> bool

        val to_list :
             t
          -> h:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Domain.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Domain.Stable.V1.t
                -> 'a)
          -> x:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Domain.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Domain.Stable.V1.t
                -> 'a)
          -> 'a list

        val map :
             t
          -> h:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Domain.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Domain.Stable.V1.t
                -> Domain.Stable.V1.t)
          -> x:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Domain.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Domain.Stable.V1.t
                -> Domain.Stable.V1.t)
          -> t

        val set_all_mutable_fields : 'a -> unit
      end
    end

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

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

type t = Stable.V1.t = { h : Domain.t; x : Domain.t }

val x : t -> Domain.t

val h : t -> Domain.t

module Fields : sig
  val names : string list

  val x :
    ([< `Read | `Set_and_create ], t, Domain.t) Fieldslib.Field.t_with_perm

  val h :
    ([< `Read | `Set_and_create ], t, Domain.t) Fieldslib.Field.t_with_perm

  val make_creator :
       h:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Domain.t )
             Fieldslib.Field.t_with_perm
          -> 'a
          -> ('b -> Domain.t) * 'c)
    -> x:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Domain.t )
             Fieldslib.Field.t_with_perm
          -> 'c
          -> ('b -> Domain.t) * 'd)
    -> 'a
    -> ('b -> t) * 'd

  val create : h:Domain.t -> x:Domain.t -> t

  val map :
       h:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Domain.t )
             Fieldslib.Field.t_with_perm
          -> Domain.t)
    -> x:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Domain.t )
             Fieldslib.Field.t_with_perm
          -> Domain.t)
    -> t

  val iter :
       h:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Domain.t )
             Fieldslib.Field.t_with_perm
          -> unit)
    -> x:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Domain.t )
             Fieldslib.Field.t_with_perm
          -> unit)
    -> unit

  val fold :
       init:'a
    -> h:
         (   'a
          -> ( [< `Read | `Set_and_create ]
             , t
             , Domain.t )
             Fieldslib.Field.t_with_perm
          -> 'b)
    -> x:
         (   'b
          -> ( [< `Read | `Set_and_create ]
             , t
             , Domain.t )
             Fieldslib.Field.t_with_perm
          -> 'c)
    -> 'c

  val map_poly :
    ([< `Read | `Set_and_create ], t, 'a) Fieldslib.Field.user -> 'a list

  val for_all :
       h:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Domain.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> x:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Domain.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> bool

  val exists :
       h:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Domain.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> x:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Domain.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> bool

  val to_list :
       h:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Domain.t )
             Fieldslib.Field.t_with_perm
          -> 'a)
    -> x:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Domain.t )
             Fieldslib.Field.t_with_perm
          -> 'a)
    -> 'a list

  module Direct : sig
    val iter :
         t
      -> h:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Domain.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Domain.t
            -> 'a)
      -> x:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Domain.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Domain.t
            -> 'b)
      -> 'b

    val fold :
         t
      -> init:'a
      -> h:
           (   'a
            -> ( [< `Read | `Set_and_create ]
               , t
               , Domain.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Domain.t
            -> 'b)
      -> x:
           (   'b
            -> ( [< `Read | `Set_and_create ]
               , t
               , Domain.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Domain.t
            -> 'c)
      -> 'c

    val for_all :
         t
      -> h:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Domain.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Domain.t
            -> bool)
      -> x:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Domain.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Domain.t
            -> bool)
      -> bool

    val exists :
         t
      -> h:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Domain.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Domain.t
            -> bool)
      -> x:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Domain.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Domain.t
            -> bool)
      -> bool

    val to_list :
         t
      -> h:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Domain.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Domain.t
            -> 'a)
      -> x:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Domain.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Domain.t
            -> 'a)
      -> 'a list

    val map :
         t
      -> h:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Domain.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Domain.t
            -> Domain.t)
      -> x:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Domain.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Domain.t
            -> Domain.t)
      -> t

    val set_all_mutable_fields : 'a -> unit
  end
end

val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

val compare : t -> t -> int
