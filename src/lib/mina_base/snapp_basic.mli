val int_to_bits : length:int -> int -> bool list

val int_of_bits : bool list -> int

module Transition : sig
  module Stable : sig
    module V1 : sig
      type 'a t = { prev : 'a; next : 'a }

      val to_yojson : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> 'a t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val to_hlist : 'a t -> (unit, 'a -> 'a -> unit) H_list.t

      val of_hlist : (unit, 'a -> 'a -> unit) H_list.t -> 'a t

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

  type 'a t = 'a Stable.V1.t = { prev : 'a; next : 'a }

  val to_yojson : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t

  val of_yojson :
       (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or)
    -> Yojson.Safe.t
    -> 'a t Ppx_deriving_yojson_runtime.error_or

  val to_hlist : 'a t -> (unit, 'a -> 'a -> unit) H_list.t

  val of_hlist : (unit, 'a -> 'a -> unit) H_list.t -> 'a t

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

module Flagged_data : sig
  type ('flag, 'a) t = { flag : 'flag; data : 'a }

  val to_hlist : ('flag, 'a) t -> (unit, 'flag -> 'a -> unit) H_list.t

  val of_hlist : (unit, 'flag -> 'a -> unit) H_list.t -> ('flag, 'a) t

  val data : ('a, 'b) t -> 'b

  val flag : ('a, 'b) t -> 'a

  module Fields : sig
    val names : string list

    val data :
      ([< `Read | `Set_and_create ], ('b, 'a) t, 'a) Fieldslib.Field.t_with_perm

    val flag :
      ( [< `Read | `Set_and_create ]
      , ('flag, 'a) t
      , 'flag )
      Fieldslib.Field.t_with_perm

    val make_creator :
         flag:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'c
            -> ('d -> 'e) * 'f)
      -> data:
           (   ( [< `Read | `Set_and_create ]
               , ('g, 'h) t
               , 'h )
               Fieldslib.Field.t_with_perm
            -> 'f
            -> ('d -> 'i) * 'j)
      -> 'c
      -> ('d -> ('e, 'i) t) * 'j

    val create : flag:'a -> data:'b -> ('a, 'b) t

    val map :
         flag:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> data:
           (   ( [< `Read | `Set_and_create ]
               , ('d, 'e) t
               , 'e )
               Fieldslib.Field.t_with_perm
            -> 'f)
      -> ('c, 'f) t

    val iter :
         flag:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> data:
           (   ( [< `Read | `Set_and_create ]
               , ('c, 'd) t
               , 'd )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> unit

    val fold :
         init:'a
      -> flag:
           (   'a
            -> ( [< `Read | `Set_and_create ]
               , ('b, 'c) t
               , 'b )
               Fieldslib.Field.t_with_perm
            -> 'd)
      -> data:
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
         flag:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> data:
           (   ( [< `Read | `Set_and_create ]
               , ('c, 'd) t
               , 'd )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val exists :
         flag:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> data:
           (   ( [< `Read | `Set_and_create ]
               , ('c, 'd) t
               , 'd )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val to_list :
         flag:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> data:
           (   ( [< `Read | `Set_and_create ]
               , ('d, 'e) t
               , 'e )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> 'c list

    module Direct : sig
      val iter :
           ('a, 'b) t
        -> flag:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , 'c )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> unit)
        -> data:
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
        -> flag:
             (   'c
              -> ( [< `Read | `Set_and_create ]
                 , ('d, 'e) t
                 , 'd )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> 'f)
        -> data:
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
        -> flag:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , 'c )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> bool)
        -> data:
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
        -> flag:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , 'c )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> bool)
        -> data:
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
        -> flag:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , 'c )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> 'e)
        -> data:
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
        -> flag:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , 'c )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> 'e)
        -> data:
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

  val typ :
       ( 'a
       , 'b
       , Pickles__Impls.Step.Impl.Internal_Basic.field
       , ( unit
         , unit
         , Pickles__Impls.Step.Impl.Internal_Basic.field )
         Snarky_backendless__.Checked.t )
       Snarky_backendless__.Types.Typ.t
    -> ( 'c
       , 'd
       , Pickles__Impls.Step.Impl.Internal_Basic.field
       , ( unit
         , unit
         , Pickles__Impls.Step.Impl.Internal_Basic.field )
         Snarky_backendless__.Checked.t )
       Snarky_backendless__.Types.Typ.t
    -> (('a, 'c) t, ('b, 'd) t) Snark_params.Tick.Typ.t

  val to_input' :
       ('a, 'b) t
    -> flag:('a -> ('c, 'd) Random_oracle_input.t)
    -> data:('b -> ('c, 'd) Random_oracle_input.t)
    -> ('c, 'd) Random_oracle_input.t
end

module Flagged_option : sig
  type ('bool, 'a) t = { is_some : 'bool; data : 'a }

  val to_hlist : ('bool, 'a) t -> (unit, 'bool -> 'a -> unit) H_list.t

  val of_hlist : (unit, 'bool -> 'a -> unit) H_list.t -> ('bool, 'a) t

  val data : ('a, 'b) t -> 'b

  val is_some : ('a, 'b) t -> 'a

  module Fields : sig
    val names : string list

    val data :
      ([< `Read | `Set_and_create ], ('b, 'a) t, 'a) Fieldslib.Field.t_with_perm

    val is_some :
      ( [< `Read | `Set_and_create ]
      , ('bool, 'a) t
      , 'bool )
      Fieldslib.Field.t_with_perm

    val make_creator :
         is_some:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'c
            -> ('d -> 'e) * 'f)
      -> data:
           (   ( [< `Read | `Set_and_create ]
               , ('g, 'h) t
               , 'h )
               Fieldslib.Field.t_with_perm
            -> 'f
            -> ('d -> 'i) * 'j)
      -> 'c
      -> ('d -> ('e, 'i) t) * 'j

    val create : is_some:'a -> data:'b -> ('a, 'b) t

    val map :
         is_some:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> data:
           (   ( [< `Read | `Set_and_create ]
               , ('d, 'e) t
               , 'e )
               Fieldslib.Field.t_with_perm
            -> 'f)
      -> ('c, 'f) t

    val iter :
         is_some:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> data:
           (   ( [< `Read | `Set_and_create ]
               , ('c, 'd) t
               , 'd )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> unit

    val fold :
         init:'a
      -> is_some:
           (   'a
            -> ( [< `Read | `Set_and_create ]
               , ('b, 'c) t
               , 'b )
               Fieldslib.Field.t_with_perm
            -> 'd)
      -> data:
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
         is_some:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> data:
           (   ( [< `Read | `Set_and_create ]
               , ('c, 'd) t
               , 'd )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val exists :
         is_some:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> data:
           (   ( [< `Read | `Set_and_create ]
               , ('c, 'd) t
               , 'd )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val to_list :
         is_some:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> data:
           (   ( [< `Read | `Set_and_create ]
               , ('d, 'e) t
               , 'e )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> 'c list

    module Direct : sig
      val iter :
           ('a, 'b) t
        -> is_some:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , 'c )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> unit)
        -> data:
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
        -> is_some:
             (   'c
              -> ( [< `Read | `Set_and_create ]
                 , ('d, 'e) t
                 , 'd )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> 'f)
        -> data:
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
        -> is_some:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , 'c )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> bool)
        -> data:
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
        -> is_some:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , 'c )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> bool)
        -> data:
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
        -> is_some:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , 'c )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> 'e)
        -> data:
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
        -> is_some:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , 'c )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> 'e)
        -> data:
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

  val to_input' :
       ('a, 'b) t
    -> f:('b -> ('c, 'a) Random_oracle_input.t)
    -> ('c, 'a) Random_oracle_input.t

  val to_input :
       (bool, 'a) t
    -> default:'a
    -> f:('a -> ('b, bool) Random_oracle_input.t)
    -> ('b, bool) Random_oracle_input.t

  val of_option : 'a option -> default:'a -> (bool, 'a) t

  val to_option : (bool, 'a) t -> 'a option

  val typ :
       ( 'a
       , 'b
       , Pickles__Impls.Step.Impl.Internal_Basic.field
       , ( unit
         , unit
         , Pickles__Impls.Step.Impl.Internal_Basic.field )
         Snarky_backendless__.Checked.t )
       Snarky_backendless__.Types.Typ.t
    -> ( (Snark_params.Tick.Boolean.var, 'a) t
       , (Snark_params.Tick.Boolean.value, 'b) t )
       Snark_params.Tick.Typ.t

  val option_typ :
       default:'a
    -> ( 'b
       , 'a
       , Pickles__Impls.Step.Impl.Internal_Basic.field
       , ( unit
         , unit
         , Pickles__Impls.Step.Impl.Internal_Basic.field )
         Snarky_backendless__.Checked.t )
       Snarky_backendless__.Types.Typ.t
    -> ( (Snark_params.Tick.Boolean.var, 'b) t
       , 'a option )
       Snark_params.Tick.Typ.t
end

module Set_or_keep : sig
  module Stable : sig
    module V1 : sig
      type 'a t = Set of 'a | Keep

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

  type 'a t = 'a Stable.V1.t = Set of 'a | Keep

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

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val to_option : 'a t -> 'a option

  val of_option : 'a option -> 'a t

  val set_or_keep : 'a t -> 'a -> 'a

  val is_set : 'a t -> bool

  val is_keep : 'a t -> bool

  module Checked : sig
    type 'a t

    val is_keep : 'a t -> Snark_params.Tick.Boolean.var

    val is_set : 'a t -> Snark_params.Tick.Boolean.var

    val set_or_keep :
         if_:(Snark_params.Tick.Boolean.var -> then_:'a -> else_:'a -> 'a)
      -> 'a t
      -> 'a
      -> 'a

    val data : 'a t -> 'a

    val typ :
         dummy:'a
      -> ('a_var, 'a) Snark_params.Tick.Typ.t
      -> ('a_var t, 'a Stable.V1.t) Snark_params.Tick.Typ.t

    val to_input :
         'a t
      -> f:('a -> ('f, Snark_params.Tick.Boolean.var) Random_oracle_input.t)
      -> ('f, Snark_params.Tick.Boolean.var) Random_oracle_input.t
  end

  val typ :
       dummy:'a
    -> ('b, 'a) Snark_params.Tick.Typ.t
    -> ('b Checked.t, 'a t) Snark_params.Tick.Typ.t

  val to_input :
       'a t
    -> dummy:'a
    -> f:('a -> ('b, bool) Random_oracle_input.t)
    -> ('b, bool) Random_oracle_input.t
end

module Or_ignore : sig
  module Stable : sig
    module V1 : sig
      type 'a t = Check of 'a | Ignore

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

  type 'a t = 'a Stable.V1.t = Check of 'a | Ignore

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

  module Checked : sig
    type 'a t

    val typ_implicit :
         equal:('a -> 'a -> bool)
      -> ignore:'a
      -> ('a_var, 'a) Snark_params.Tick.Typ.t
      -> ('a_var t, 'a Stable.V1.t) Snark_params.Tick.Typ.t

    val typ_explicit :
         ignore:'a
      -> ('a_var, 'a) Snark_params.Tick.Typ.t
      -> ('a_var t, 'a Stable.V1.t) Snark_params.Tick.Typ.t

    val to_input :
         'a t
      -> f:('a -> ('f, Snark_params.Tick.Boolean.var) Random_oracle_input.t)
      -> ('f, Snark_params.Tick.Boolean.var) Random_oracle_input.t

    val check :
         'a t
      -> f:('a -> Snark_params.Tick.Boolean.var)
      -> Snark_params.Tick.Boolean.var
  end

  val typ_implicit :
       equal:('a -> 'a -> bool)
    -> ignore:'a
    -> ('b, 'a) Snark_params.Tick.Typ.t
    -> ('b Checked.t, 'a t) Snark_params.Tick.Typ.t

  val typ_explicit :
       ignore:'a
    -> ('b, 'a) Snark_params.Tick.Typ.t
    -> ('b Checked.t, 'a t) Snark_params.Tick.Typ.t
end

module Account_state : sig
  module Stable : sig
    module V1 : sig
      type t = Empty | Non_empty | Any

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val min : int

      val max : int

      val to_enum : t -> int

      val of_enum : int -> t option

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

  type t = Stable.V1.t = Empty | Non_empty | Any

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val min : int

  val max : int

  val to_enum : t -> int

  val of_enum : int -> t option

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val equal : t -> t -> bool

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val compare : t -> t -> int

  module Encoding : sig
    type 'b t = { any : 'b; empty : 'b }

    val to_hlist : 'b t -> (unit, 'b -> 'b -> unit) H_list.t

    val of_hlist : (unit, 'b -> 'b -> unit) H_list.t -> 'b t

    val to_input : 'a t -> ('b, 'a) Random_oracle_input.t
  end

  val encode : t -> bool Encoding.t

  val decode : bool Encoding.t -> t

  val to_input : t -> ('a, bool) Random_oracle_input.t

  val check :
       t
    -> [ `Empty | `Non_empty ]
    -> (unit, Core_kernel__.Error.t) Core_kernel._result

  module Checked : sig
    type t = Pickles.Impls.Step.Boolean.var Encoding.t

    val to_input :
      t -> ('a, Pickles.Impls.Step.Boolean.var) Random_oracle_input.t

    val check :
         t
      -> is_empty:Pickles.Impls.Step.Boolean.var
      -> Pickles.Impls.Step.Boolean.var
  end

  val typ : (Checked.t, t) Snark_params.Tick.Typ.t
end

module F = Pickles.Backend.Tick.Field

val invalid_public_key :
  Signature_lib.Public_key.Compressed.t Core_kernel.Lazy.t
