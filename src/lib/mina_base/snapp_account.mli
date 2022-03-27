module Poly : sig
  module Stable : sig
    module V1 : sig
      type ('app_state, 'vk) t =
        { app_state : 'app_state; verification_key : 'vk }

      val to_yojson :
           ('app_state -> Yojson.Safe.t)
        -> ('vk -> Yojson.Safe.t)
        -> ('app_state, 'vk) t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'app_state Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'vk Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ('app_state, 'vk) t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'app_state)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'vk)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('app_state, 'vk) t

      val sexp_of_t :
           ('app_state -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('vk -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('app_state, 'vk) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val equal :
           ('app_state -> 'app_state -> bool)
        -> ('vk -> 'vk -> bool)
        -> ('app_state, 'vk) t
        -> ('app_state, 'vk) t
        -> bool

      val compare :
           ('app_state -> 'app_state -> int)
        -> ('vk -> 'vk -> int)
        -> ('app_state, 'vk) t
        -> ('app_state, 'vk) t
        -> int

      val hash_fold_t :
           (   Ppx_hash_lib.Std.Hash.state
            -> 'app_state
            -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'vk -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('app_state, 'vk) t
        -> Ppx_hash_lib.Std.Hash.state

      val to_hlist :
        ('app_state, 'vk) t -> (unit, 'app_state -> 'vk -> unit) H_list.t

      val of_hlist :
        (unit, 'app_state -> 'vk -> unit) H_list.t -> ('app_state, 'vk) t

      val verification_key : ('a, 'b) t -> 'b

      val app_state : ('a, 'b) t -> 'a

      module Fields : sig
        val names : string list

        val verification_key :
          ( [< `Read | `Set_and_create ]
          , ('a, 'vk) t
          , 'vk )
          Fieldslib.Field.t_with_perm

        val app_state :
          ( [< `Read | `Set_and_create ]
          , ('app_state, 'a) t
          , 'app_state )
          Fieldslib.Field.t_with_perm

        val make_creator :
             app_state:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> 'c
                -> ('d -> 'e) * 'f)
          -> verification_key:
               (   ( [< `Read | `Set_and_create ]
                   , ('g, 'h) t
                   , 'h )
                   Fieldslib.Field.t_with_perm
                -> 'f
                -> ('d -> 'i) * 'j)
          -> 'c
          -> ('d -> ('e, 'i) t) * 'j

        val create : app_state:'a -> verification_key:'b -> ('a, 'b) t

        val map :
             app_state:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> 'c)
          -> verification_key:
               (   ( [< `Read | `Set_and_create ]
                   , ('d, 'e) t
                   , 'e )
                   Fieldslib.Field.t_with_perm
                -> 'f)
          -> ('c, 'f) t

        val iter :
             app_state:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> verification_key:
               (   ( [< `Read | `Set_and_create ]
                   , ('c, 'd) t
                   , 'd )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> unit

        val fold :
             init:'a
          -> app_state:
               (   'a
                -> ( [< `Read | `Set_and_create ]
                   , ('b, 'c) t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> 'd)
          -> verification_key:
               (   'd
                -> ( [< `Read | `Set_and_create ]
                   , ('e, 'f) t
                   , 'f )
                   Fieldslib.Field.t_with_perm
                -> 'g)
          -> 'g

        val map_poly :
             ([< `Read | `Set_and_create ], ('a, 'b) t, 'c) Fieldslib.Field.user
          -> 'c list

        val for_all :
             app_state:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> verification_key:
               (   ( [< `Read | `Set_and_create ]
                   , ('c, 'd) t
                   , 'd )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> bool

        val exists :
             app_state:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> verification_key:
               (   ( [< `Read | `Set_and_create ]
                   , ('c, 'd) t
                   , 'd )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> bool

        val to_list :
             app_state:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> 'c)
          -> verification_key:
               (   ( [< `Read | `Set_and_create ]
                   , ('d, 'e) t
                   , 'e )
                   Fieldslib.Field.t_with_perm
                -> 'c)
          -> 'c list

        module Direct : sig
          val iter :
               ('a, 'b) t
            -> app_state:
                 (   ( [< `Read | `Set_and_create ]
                     , ('c, 'd) t
                     , 'c )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'a
                  -> unit)
            -> verification_key:
                 (   ( [< `Read | `Set_and_create ]
                     , ('e, 'f) t
                     , 'f )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'b
                  -> 'g)
            -> 'g

          val fold :
               ('a, 'b) t
            -> init:'c
            -> app_state:
                 (   'c
                  -> ( [< `Read | `Set_and_create ]
                     , ('d, 'e) t
                     , 'd )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'a
                  -> 'f)
            -> verification_key:
                 (   'f
                  -> ( [< `Read | `Set_and_create ]
                     , ('g, 'h) t
                     , 'h )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'b
                  -> 'i)
            -> 'i

          val for_all :
               ('a, 'b) t
            -> app_state:
                 (   ( [< `Read | `Set_and_create ]
                     , ('c, 'd) t
                     , 'c )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'a
                  -> bool)
            -> verification_key:
                 (   ( [< `Read | `Set_and_create ]
                     , ('e, 'f) t
                     , 'f )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'b
                  -> bool)
            -> bool

          val exists :
               ('a, 'b) t
            -> app_state:
                 (   ( [< `Read | `Set_and_create ]
                     , ('c, 'd) t
                     , 'c )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'a
                  -> bool)
            -> verification_key:
                 (   ( [< `Read | `Set_and_create ]
                     , ('e, 'f) t
                     , 'f )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'b
                  -> bool)
            -> bool

          val to_list :
               ('a, 'b) t
            -> app_state:
                 (   ( [< `Read | `Set_and_create ]
                     , ('c, 'd) t
                     , 'c )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'a
                  -> 'e)
            -> verification_key:
                 (   ( [< `Read | `Set_and_create ]
                     , ('f, 'g) t
                     , 'g )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'b
                  -> 'e)
            -> 'e list

          val map :
               ('a, 'b) t
            -> app_state:
                 (   ( [< `Read | `Set_and_create ]
                     , ('c, 'd) t
                     , 'c )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'a
                  -> 'e)
            -> verification_key:
                 (   ( [< `Read | `Set_and_create ]
                     , ('f, 'g) t
                     , 'g )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'b
                  -> 'h)
            -> ('e, 'h) t

          val set_all_mutable_fields : 'a -> unit
        end
      end

      module With_version : sig
        type ('app_state, 'vk) typ = ('app_state, 'vk) t

        val bin_shape_typ :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_typ :
             'app_state Core_kernel.Bin_prot.Size.sizer
          -> 'vk Core_kernel.Bin_prot.Size.sizer
          -> ('app_state, 'vk) typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ :
             'app_state Core_kernel.Bin_prot.Write.writer
          -> 'vk Core_kernel.Bin_prot.Write.writer
          -> ('app_state, 'vk) typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
             'app_state Core_kernel.Bin_prot.Read.reader
          -> 'vk Core_kernel.Bin_prot.Read.reader
          -> (int -> ('app_state, 'vk) typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ :
             'app_state Core_kernel.Bin_prot.Read.reader
          -> 'vk Core_kernel.Bin_prot.Read.reader
          -> ('app_state, 'vk) typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.t

        type ('app_state, 'vk) t = { version : int; t : ('app_state, 'vk) typ }

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'app_state Core_kernel.Bin_prot.Size.sizer
          -> 'vk Core_kernel.Bin_prot.Size.sizer
          -> ('app_state, 'vk) t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'app_state Core_kernel.Bin_prot.Write.writer
          -> 'vk Core_kernel.Bin_prot.Write.writer
          -> ('app_state, 'vk) t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ :
             'app_state Core_kernel.Bin_prot.Read.reader
          -> 'vk Core_kernel.Bin_prot.Read.reader
          -> (int -> ('app_state, 'vk) t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t :
             'app_state Core_kernel.Bin_prot.Read.reader
          -> 'vk Core_kernel.Bin_prot.Read.reader
          -> ('app_state, 'vk) t Core_kernel.Bin_prot.Read.reader

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

  type ('app_state, 'vk) t = ('app_state, 'vk) Stable.V1.t =
    { app_state : 'app_state; verification_key : 'vk }

  val to_yojson :
       ('app_state -> Yojson.Safe.t)
    -> ('vk -> Yojson.Safe.t)
    -> ('app_state, 'vk) t
    -> Yojson.Safe.t

  val of_yojson :
       (Yojson.Safe.t -> 'app_state Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'vk Ppx_deriving_yojson_runtime.error_or)
    -> Yojson.Safe.t
    -> ('app_state, 'vk) t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp :
       (Ppx_sexp_conv_lib.Sexp.t -> 'app_state)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'vk)
    -> Ppx_sexp_conv_lib.Sexp.t
    -> ('app_state, 'vk) t

  val sexp_of_t :
       ('app_state -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('vk -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('app_state, 'vk) t
    -> Ppx_sexp_conv_lib.Sexp.t

  val equal :
       ('app_state -> 'app_state -> bool)
    -> ('vk -> 'vk -> bool)
    -> ('app_state, 'vk) t
    -> ('app_state, 'vk) t
    -> bool

  val compare :
       ('app_state -> 'app_state -> int)
    -> ('vk -> 'vk -> int)
    -> ('app_state, 'vk) t
    -> ('app_state, 'vk) t
    -> int

  val hash_fold_t :
       (Ppx_hash_lib.Std.Hash.state -> 'app_state -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'vk -> Ppx_hash_lib.Std.Hash.state)
    -> Ppx_hash_lib.Std.Hash.state
    -> ('app_state, 'vk) t
    -> Ppx_hash_lib.Std.Hash.state

  val to_hlist :
    ('app_state, 'vk) t -> (unit, 'app_state -> 'vk -> unit) H_list.t

  val of_hlist :
    (unit, 'app_state -> 'vk -> unit) H_list.t -> ('app_state, 'vk) t

  val verification_key : ('a, 'b) t -> 'b

  val app_state : ('a, 'b) t -> 'a

  module Fields : sig
    val names : string list

    val verification_key :
      ( [< `Read | `Set_and_create ]
      , ('a, 'vk) t
      , 'vk )
      Fieldslib.Field.t_with_perm

    val app_state :
      ( [< `Read | `Set_and_create ]
      , ('app_state, 'a) t
      , 'app_state )
      Fieldslib.Field.t_with_perm

    val make_creator :
         app_state:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'c
            -> ('d -> 'e) * 'f)
      -> verification_key:
           (   ( [< `Read | `Set_and_create ]
               , ('g, 'h) t
               , 'h )
               Fieldslib.Field.t_with_perm
            -> 'f
            -> ('d -> 'i) * 'j)
      -> 'c
      -> ('d -> ('e, 'i) t) * 'j

    val create : app_state:'a -> verification_key:'b -> ('a, 'b) t

    val map :
         app_state:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> verification_key:
           (   ( [< `Read | `Set_and_create ]
               , ('d, 'e) t
               , 'e )
               Fieldslib.Field.t_with_perm
            -> 'f)
      -> ('c, 'f) t

    val iter :
         app_state:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> verification_key:
           (   ( [< `Read | `Set_and_create ]
               , ('c, 'd) t
               , 'd )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> unit

    val fold :
         init:'a
      -> app_state:
           (   'a
            -> ( [< `Read | `Set_and_create ]
               , ('b, 'c) t
               , 'b )
               Fieldslib.Field.t_with_perm
            -> 'd)
      -> verification_key:
           (   'd
            -> ( [< `Read | `Set_and_create ]
               , ('e, 'f) t
               , 'f )
               Fieldslib.Field.t_with_perm
            -> 'g)
      -> 'g

    val map_poly :
         ([< `Read | `Set_and_create ], ('a, 'b) t, 'c) Fieldslib.Field.user
      -> 'c list

    val for_all :
         app_state:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> verification_key:
           (   ( [< `Read | `Set_and_create ]
               , ('c, 'd) t
               , 'd )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val exists :
         app_state:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> verification_key:
           (   ( [< `Read | `Set_and_create ]
               , ('c, 'd) t
               , 'd )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val to_list :
         app_state:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> verification_key:
           (   ( [< `Read | `Set_and_create ]
               , ('d, 'e) t
               , 'e )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> 'c list

    module Direct : sig
      val iter :
           ('a, 'b) t
        -> app_state:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , 'c )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> unit)
        -> verification_key:
             (   ( [< `Read | `Set_and_create ]
                 , ('e, 'f) t
                 , 'f )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'b
              -> 'g)
        -> 'g

      val fold :
           ('a, 'b) t
        -> init:'c
        -> app_state:
             (   'c
              -> ( [< `Read | `Set_and_create ]
                 , ('d, 'e) t
                 , 'd )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> 'f)
        -> verification_key:
             (   'f
              -> ( [< `Read | `Set_and_create ]
                 , ('g, 'h) t
                 , 'h )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'b
              -> 'i)
        -> 'i

      val for_all :
           ('a, 'b) t
        -> app_state:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , 'c )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> bool)
        -> verification_key:
             (   ( [< `Read | `Set_and_create ]
                 , ('e, 'f) t
                 , 'f )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'b
              -> bool)
        -> bool

      val exists :
           ('a, 'b) t
        -> app_state:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , 'c )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> bool)
        -> verification_key:
             (   ( [< `Read | `Set_and_create ]
                 , ('e, 'f) t
                 , 'f )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'b
              -> bool)
        -> bool

      val to_list :
           ('a, 'b) t
        -> app_state:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , 'c )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> 'e)
        -> verification_key:
             (   ( [< `Read | `Set_and_create ]
                 , ('f, 'g) t
                 , 'g )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'b
              -> 'e)
        -> 'e list

      val map :
           ('a, 'b) t
        -> app_state:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , 'c )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> 'e)
        -> verification_key:
             (   ( [< `Read | `Set_and_create ]
                 , ('f, 'g) t
                 , 'g )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'b
              -> 'h)
        -> ('e, 'h) t

      val set_all_mutable_fields : 'a -> unit
    end
  end
end

type ('app_state, 'vk) t_ = ('app_state, 'vk) Poly.t =
  { app_state : 'app_state; verification_key : 'vk }

module Stable : sig
  module V1 : sig
    type t =
      ( Snapp_state.Value.Stable.V1.t
      , ( Side_loaded_verification_key.Stable.V1.t
        , Snapp_basic.F.Stable.V1.t )
        With_hash.Stable.V1.t
        option )
      t_

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val version : int

    val __versioned__ : unit

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

    val equal : t -> t -> bool

    val compare : t -> t -> int

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

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

val compare : t -> t -> int

val hash_fold_t :
  Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

val digest_vk : Side_loaded_verification_key.t -> Random_oracle.Digest.t

module Checked : sig
  type t =
    ( Pickles.Impls.Step.Field.t Snapp_state.V.t
    , ( Pickles.Side_loaded.Verification_key.Checked.t
      , Pickles.Impls.Step.Field.t Core_kernel.Lazy.t )
      With_hash.t )
    t_

  val to_input' :
    (('a, 'b) Pickles_types.Vector.t, 'a) t_ -> ('a, 'c) Random_oracle.Input.t

  val to_input : t -> (Pickles.Impls.Step.Field.t, 'a) Random_oracle.Input.t

  val digest_vk :
       Pickles.Side_loaded.Verification_key.Checked.t
    -> Random_oracle.Checked.Digest.t

  val digest : t -> Random_oracle.Checked.Digest.t

  val digest' :
       ( ( Pickles.Impls.Step.Internal_Basic.Field.Var.t
         , 'a )
         Pickles_types.Vector.t
       , Pickles.Impls.Step.Internal_Basic.Field.Var.t )
       t_
    -> Random_oracle.Checked.Digest.t
end

val typ : (Checked.t, t) Snark_params.Tick.Typ.t

val dummy_vk_hash :
  (Core_kernel__.Import.unit, Random_oracle.Digest.t) Core_kernel.Memo.fn

val to_input : t -> (Snapp_basic.F.Stable.V1.t, 'a) Random_oracle.Input.t

val default :
  ( ( Snapp_basic.F.t
    , Pickles_types__Nat.z Pickles_types__Nat.N7.plus_n Pickles_types__Nat.s )
    Pickles_types.Vector.t
  , 'a option )
  t_

val digest : t -> Random_oracle.Digest.t

val default_digest : Random_oracle.Digest.t lazy_t
