module Stable : sig
  module V1 : sig
    type 'a t = { data : 'a; status : Transaction_status.Stable.V1.t }

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

    val status : 'a t -> Transaction_status.Stable.V1.t

    val data : 'a t -> 'a

    module Fields : sig
      val names : string list

      val status :
        ( [< `Read | `Set_and_create ]
        , 'a t
        , Transaction_status.Stable.V1.t )
        Fieldslib.Field.t_with_perm

      val data :
        ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm

      val make_creator :
           data:
             (   ( [< `Read | `Set_and_create ]
                 , 'a t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> 'b
              -> ('c -> 'd) * 'e)
        -> status:
             (   ( [< `Read | `Set_and_create ]
                 , 'f t
                 , Transaction_status.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> 'e
              -> ('c -> Transaction_status.Stable.V1.t) * 'g)
        -> 'b
        -> ('c -> 'd t) * 'g

      val create : data:'a -> status:Transaction_status.Stable.V1.t -> 'a t

      val map :
           data:
             (   ( [< `Read | `Set_and_create ]
                 , 'a t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> 'b)
        -> status:
             (   ( [< `Read | `Set_and_create ]
                 , 'c t
                 , Transaction_status.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> Transaction_status.Stable.V1.t)
        -> 'b t

      val iter :
           data:
             (   ( [< `Read | `Set_and_create ]
                 , 'a t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> status:
             (   ( [< `Read | `Set_and_create ]
                 , 'b t
                 , Transaction_status.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> unit

      val fold :
           init:'a
        -> data:
             (   'a
              -> ( [< `Read | `Set_and_create ]
                 , 'b t
                 , 'b )
                 Fieldslib.Field.t_with_perm
              -> 'c)
        -> status:
             (   'c
              -> ( [< `Read | `Set_and_create ]
                 , 'd t
                 , Transaction_status.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> 'e)
        -> 'e

      val map_poly :
        ([< `Read | `Set_and_create ], 'a t, 'b) Fieldslib.Field.user -> 'b list

      val for_all :
           data:
             (   ( [< `Read | `Set_and_create ]
                 , 'a t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> status:
             (   ( [< `Read | `Set_and_create ]
                 , 'b t
                 , Transaction_status.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val exists :
           data:
             (   ( [< `Read | `Set_and_create ]
                 , 'a t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> status:
             (   ( [< `Read | `Set_and_create ]
                 , 'b t
                 , Transaction_status.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val to_list :
           data:
             (   ( [< `Read | `Set_and_create ]
                 , 'a t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> 'b)
        -> status:
             (   ( [< `Read | `Set_and_create ]
                 , 'c t
                 , Transaction_status.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> 'b)
        -> 'b list

      module Direct : sig
        val iter :
             'a t
          -> data:
               (   ( [< `Read | `Set_and_create ]
                   , 'b t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> 'a
                -> unit)
          -> status:
               (   ( [< `Read | `Set_and_create ]
                   , 'c t
                   , Transaction_status.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> Transaction_status.Stable.V1.t
                -> 'd)
          -> 'd

        val fold :
             'a t
          -> init:'b
          -> data:
               (   'b
                -> ( [< `Read | `Set_and_create ]
                   , 'c t
                   , 'c )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> 'a
                -> 'd)
          -> status:
               (   'd
                -> ( [< `Read | `Set_and_create ]
                   , 'e t
                   , Transaction_status.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> Transaction_status.Stable.V1.t
                -> 'f)
          -> 'f

        val for_all :
             'a t
          -> data:
               (   ( [< `Read | `Set_and_create ]
                   , 'b t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> 'a
                -> bool)
          -> status:
               (   ( [< `Read | `Set_and_create ]
                   , 'c t
                   , Transaction_status.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> Transaction_status.Stable.V1.t
                -> bool)
          -> bool

        val exists :
             'a t
          -> data:
               (   ( [< `Read | `Set_and_create ]
                   , 'b t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> 'a
                -> bool)
          -> status:
               (   ( [< `Read | `Set_and_create ]
                   , 'c t
                   , Transaction_status.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> Transaction_status.Stable.V1.t
                -> bool)
          -> bool

        val to_list :
             'a t
          -> data:
               (   ( [< `Read | `Set_and_create ]
                   , 'b t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> 'a
                -> 'c)
          -> status:
               (   ( [< `Read | `Set_and_create ]
                   , 'd t
                   , Transaction_status.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> Transaction_status.Stable.V1.t
                -> 'c)
          -> 'c list

        val map :
             'a t
          -> data:
               (   ( [< `Read | `Set_and_create ]
                   , 'b t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> 'a
                -> 'c)
          -> status:
               (   ( [< `Read | `Set_and_create ]
                   , 'd t
                   , Transaction_status.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> Transaction_status.Stable.V1.t
                -> Transaction_status.Stable.V1.t)
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

type 'a t = 'a Stable.V1.t = { data : 'a; status : Transaction_status.t }

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

val status : 'a t -> Transaction_status.t

val data : 'a t -> 'a

module Fields : sig
  val names : string list

  val status :
    ( [< `Read | `Set_and_create ]
    , 'a t
    , Transaction_status.t )
    Fieldslib.Field.t_with_perm

  val data :
    ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm

  val make_creator :
       data:
         (   ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm
          -> 'b
          -> ('c -> 'd) * 'e)
    -> status:
         (   ( [< `Read | `Set_and_create ]
             , 'f t
             , Transaction_status.t )
             Fieldslib.Field.t_with_perm
          -> 'e
          -> ('c -> Transaction_status.t) * 'g)
    -> 'b
    -> ('c -> 'd t) * 'g

  val create : data:'a -> status:Transaction_status.t -> 'a t

  val map :
       data:
         (   ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm
          -> 'b)
    -> status:
         (   ( [< `Read | `Set_and_create ]
             , 'c t
             , Transaction_status.t )
             Fieldslib.Field.t_with_perm
          -> Transaction_status.t)
    -> 'b t

  val iter :
       data:
         (   ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm
          -> unit)
    -> status:
         (   ( [< `Read | `Set_and_create ]
             , 'b t
             , Transaction_status.t )
             Fieldslib.Field.t_with_perm
          -> unit)
    -> unit

  val fold :
       init:'a
    -> data:
         (   'a
          -> ( [< `Read | `Set_and_create ]
             , 'b t
             , 'b )
             Fieldslib.Field.t_with_perm
          -> 'c)
    -> status:
         (   'c
          -> ( [< `Read | `Set_and_create ]
             , 'd t
             , Transaction_status.t )
             Fieldslib.Field.t_with_perm
          -> 'e)
    -> 'e

  val map_poly :
    ([< `Read | `Set_and_create ], 'a t, 'b) Fieldslib.Field.user -> 'b list

  val for_all :
       data:
         (   ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm
          -> bool)
    -> status:
         (   ( [< `Read | `Set_and_create ]
             , 'b t
             , Transaction_status.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> bool

  val exists :
       data:
         (   ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm
          -> bool)
    -> status:
         (   ( [< `Read | `Set_and_create ]
             , 'b t
             , Transaction_status.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> bool

  val to_list :
       data:
         (   ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm
          -> 'b)
    -> status:
         (   ( [< `Read | `Set_and_create ]
             , 'c t
             , Transaction_status.t )
             Fieldslib.Field.t_with_perm
          -> 'b)
    -> 'b list

  module Direct : sig
    val iter :
         'a t
      -> data:
           (   ( [< `Read | `Set_and_create ]
               , 'b t
               , 'b )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> 'a
            -> unit)
      -> status:
           (   ( [< `Read | `Set_and_create ]
               , 'c t
               , Transaction_status.t )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> Transaction_status.t
            -> 'd)
      -> 'd

    val fold :
         'a t
      -> init:'b
      -> data:
           (   'b
            -> ( [< `Read | `Set_and_create ]
               , 'c t
               , 'c )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> 'a
            -> 'd)
      -> status:
           (   'd
            -> ( [< `Read | `Set_and_create ]
               , 'e t
               , Transaction_status.t )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> Transaction_status.t
            -> 'f)
      -> 'f

    val for_all :
         'a t
      -> data:
           (   ( [< `Read | `Set_and_create ]
               , 'b t
               , 'b )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> 'a
            -> bool)
      -> status:
           (   ( [< `Read | `Set_and_create ]
               , 'c t
               , Transaction_status.t )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> Transaction_status.t
            -> bool)
      -> bool

    val exists :
         'a t
      -> data:
           (   ( [< `Read | `Set_and_create ]
               , 'b t
               , 'b )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> 'a
            -> bool)
      -> status:
           (   ( [< `Read | `Set_and_create ]
               , 'c t
               , Transaction_status.t )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> Transaction_status.t
            -> bool)
      -> bool

    val to_list :
         'a t
      -> data:
           (   ( [< `Read | `Set_and_create ]
               , 'b t
               , 'b )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> 'a
            -> 'c)
      -> status:
           (   ( [< `Read | `Set_and_create ]
               , 'd t
               , Transaction_status.t )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> Transaction_status.t
            -> 'c)
      -> 'c list

    val map :
         'a t
      -> data:
           (   ( [< `Read | `Set_and_create ]
               , 'b t
               , 'b )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> 'a
            -> 'c)
      -> status:
           (   ( [< `Read | `Set_and_create ]
               , 'd t
               , Transaction_status.t )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> Transaction_status.t
            -> Transaction_status.t)
      -> 'c t

    val set_all_mutable_fields : 'a -> unit
  end
end

val map : f:('a -> 'b) -> 'a t -> 'b t

val map_opt : f:('a -> 'b option) -> 'a t -> 'b t option

val map_result :
     f:('a -> ('b, 'c) Core_kernel.Result.t)
  -> 'a t
  -> ('b t, 'c) Core_kernel.Result.t
