module Stable : sig
  module V1 : sig
    type 'proof t =
      { proof : 'proof; fee : Mina_base.Fee_with_prover.Stable.V1.t }

    val to_yojson : ('proof -> Yojson.Safe.t) -> 'proof t -> Yojson.Safe.t

    val of_yojson :
         (Yojson.Safe.t -> 'proof Ppx_deriving_yojson_runtime.error_or)
      -> Yojson.Safe.t
      -> 'proof t Ppx_deriving_yojson_runtime.error_or

    val version : int

    val __versioned__ : unit

    val compare : ('proof -> 'proof -> int) -> 'proof t -> 'proof t -> int

    val fee : 'a t -> Mina_base.Fee_with_prover.Stable.V1.t

    val proof : 'a t -> 'a

    module Fields : sig
      val names : string list

      val fee :
        ( [< `Read | `Set_and_create ]
        , 'a t
        , Mina_base.Fee_with_prover.Stable.V1.t )
        Fieldslib.Field.t_with_perm

      val proof :
        ( [< `Read | `Set_and_create ]
        , 'proof t
        , 'proof )
        Fieldslib.Field.t_with_perm

      val make_creator :
           proof:
             (   ( [< `Read | `Set_and_create ]
                 , 'a t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> 'b
              -> ('c -> 'd) * 'e)
        -> fee:
             (   ( [< `Read | `Set_and_create ]
                 , 'f t
                 , Mina_base.Fee_with_prover.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> 'e
              -> ('c -> Mina_base.Fee_with_prover.Stable.V1.t) * 'g)
        -> 'b
        -> ('c -> 'd t) * 'g

      val create : proof:'a -> fee:Mina_base.Fee_with_prover.Stable.V1.t -> 'a t

      val map :
           proof:
             (   ( [< `Read | `Set_and_create ]
                 , 'a t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> 'b)
        -> fee:
             (   ( [< `Read | `Set_and_create ]
                 , 'c t
                 , Mina_base.Fee_with_prover.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> Mina_base.Fee_with_prover.Stable.V1.t)
        -> 'b t

      val iter :
           proof:
             (   ( [< `Read | `Set_and_create ]
                 , 'a t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> fee:
             (   ( [< `Read | `Set_and_create ]
                 , 'b t
                 , Mina_base.Fee_with_prover.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> unit

      val fold :
           init:'a
        -> proof:
             (   'a
              -> ( [< `Read | `Set_and_create ]
                 , 'b t
                 , 'b )
                 Fieldslib.Field.t_with_perm
              -> 'c)
        -> fee:
             (   'c
              -> ( [< `Read | `Set_and_create ]
                 , 'd t
                 , Mina_base.Fee_with_prover.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> 'e)
        -> 'e

      val map_poly :
        ([< `Read | `Set_and_create ], 'a t, 'b) Fieldslib.Field.user -> 'b list

      val for_all :
           proof:
             (   ( [< `Read | `Set_and_create ]
                 , 'a t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> fee:
             (   ( [< `Read | `Set_and_create ]
                 , 'b t
                 , Mina_base.Fee_with_prover.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val exists :
           proof:
             (   ( [< `Read | `Set_and_create ]
                 , 'a t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> fee:
             (   ( [< `Read | `Set_and_create ]
                 , 'b t
                 , Mina_base.Fee_with_prover.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val to_list :
           proof:
             (   ( [< `Read | `Set_and_create ]
                 , 'a t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> 'b)
        -> fee:
             (   ( [< `Read | `Set_and_create ]
                 , 'c t
                 , Mina_base.Fee_with_prover.Stable.V1.t )
                 Fieldslib.Field.t_with_perm
              -> 'b)
        -> 'b list

      module Direct : sig
        val iter :
             'a t
          -> proof:
               (   ( [< `Read | `Set_and_create ]
                   , 'b t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> 'a
                -> unit)
          -> fee:
               (   ( [< `Read | `Set_and_create ]
                   , 'c t
                   , Mina_base.Fee_with_prover.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> Mina_base.Fee_with_prover.Stable.V1.t
                -> 'd)
          -> 'd

        val fold :
             'a t
          -> init:'b
          -> proof:
               (   'b
                -> ( [< `Read | `Set_and_create ]
                   , 'c t
                   , 'c )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> 'a
                -> 'd)
          -> fee:
               (   'd
                -> ( [< `Read | `Set_and_create ]
                   , 'e t
                   , Mina_base.Fee_with_prover.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> Mina_base.Fee_with_prover.Stable.V1.t
                -> 'f)
          -> 'f

        val for_all :
             'a t
          -> proof:
               (   ( [< `Read | `Set_and_create ]
                   , 'b t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> 'a
                -> bool)
          -> fee:
               (   ( [< `Read | `Set_and_create ]
                   , 'c t
                   , Mina_base.Fee_with_prover.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> Mina_base.Fee_with_prover.Stable.V1.t
                -> bool)
          -> bool

        val exists :
             'a t
          -> proof:
               (   ( [< `Read | `Set_and_create ]
                   , 'b t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> 'a
                -> bool)
          -> fee:
               (   ( [< `Read | `Set_and_create ]
                   , 'c t
                   , Mina_base.Fee_with_prover.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> Mina_base.Fee_with_prover.Stable.V1.t
                -> bool)
          -> bool

        val to_list :
             'a t
          -> proof:
               (   ( [< `Read | `Set_and_create ]
                   , 'b t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> 'a
                -> 'c)
          -> fee:
               (   ( [< `Read | `Set_and_create ]
                   , 'd t
                   , Mina_base.Fee_with_prover.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> Mina_base.Fee_with_prover.Stable.V1.t
                -> 'c)
          -> 'c list

        val map :
             'a t
          -> proof:
               (   ( [< `Read | `Set_and_create ]
                   , 'b t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> 'a
                -> 'c)
          -> fee:
               (   ( [< `Read | `Set_and_create ]
                   , 'd t
                   , Mina_base.Fee_with_prover.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> 'a t
                -> Mina_base.Fee_with_prover.Stable.V1.t
                -> Mina_base.Fee_with_prover.Stable.V1.t)
          -> 'c t

        val set_all_mutable_fields : 'a -> unit
      end
    end

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'proof)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> 'proof t

    val sexp_of_t :
         ('proof -> Ppx_sexp_conv_lib.Sexp.t)
      -> 'proof t
      -> Ppx_sexp_conv_lib.Sexp.t

    val hash_fold_t :
         (Ppx_hash_lib.Std.Hash.state -> 'proof -> Ppx_hash_lib.Std.Hash.state)
      -> Ppx_hash_lib.Std.Hash.state
      -> 'proof t
      -> Ppx_hash_lib.Std.Hash.state

    module With_version : sig
      type 'proof typ = 'proof t

      val bin_shape_typ :
        Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t

      val bin_size_typ :
           'proof Core_kernel.Bin_prot.Size.sizer
        -> 'proof typ Core_kernel.Bin_prot.Size.sizer

      val bin_write_typ :
           'proof Core_kernel.Bin_prot.Write.writer
        -> 'proof typ Core_kernel.Bin_prot.Write.writer

      val bin_writer_typ :
           'a Core_kernel.Bin_prot.Type_class.writer
        -> 'a typ Core_kernel.Bin_prot.Type_class.writer

      val __bin_read_typ__ :
           'proof Core_kernel.Bin_prot.Read.reader
        -> (int -> 'proof typ) Core_kernel.Bin_prot.Read.reader

      val bin_read_typ :
           'proof Core_kernel.Bin_prot.Read.reader
        -> 'proof typ Core_kernel.Bin_prot.Read.reader

      val bin_reader_typ :
           'a Core_kernel.Bin_prot.Type_class.reader
        -> 'a typ Core_kernel.Bin_prot.Type_class.reader

      val bin_typ :
           'a Core_kernel.Bin_prot.Type_class.t
        -> 'a typ Core_kernel.Bin_prot.Type_class.t

      type 'proof t = { version : int; t : 'proof typ }

      val bin_shape_t :
        Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t

      val bin_size_t :
           'proof Core_kernel.Bin_prot.Size.sizer
        -> 'proof t Core_kernel.Bin_prot.Size.sizer

      val bin_write_t :
           'proof Core_kernel.Bin_prot.Write.writer
        -> 'proof t Core_kernel.Bin_prot.Write.writer

      val bin_writer_t :
           'a Core_kernel.Bin_prot.Type_class.writer
        -> 'a t Core_kernel.Bin_prot.Type_class.writer

      val __bin_read_t__ :
           'proof Core_kernel.Bin_prot.Read.reader
        -> (int -> 'proof t) Core_kernel.Bin_prot.Read.reader

      val bin_read_t :
           'proof Core_kernel.Bin_prot.Read.reader
        -> 'proof t Core_kernel.Bin_prot.Read.reader

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

type 'proof t = 'proof Stable.V1.t =
  { proof : 'proof; fee : Mina_base.Fee_with_prover.t }

val to_yojson : ('proof -> Yojson.Safe.t) -> 'proof t -> Yojson.Safe.t

val of_yojson :
     (Yojson.Safe.t -> 'proof Ppx_deriving_yojson_runtime.error_or)
  -> Yojson.Safe.t
  -> 'proof t Ppx_deriving_yojson_runtime.error_or

val compare : ('proof -> 'proof -> int) -> 'proof t -> 'proof t -> int

val fee : 'a t -> Mina_base.Fee_with_prover.t

val proof : 'a t -> 'a

module Fields : sig
  val names : string list

  val fee :
    ( [< `Read | `Set_and_create ]
    , 'a t
    , Mina_base.Fee_with_prover.t )
    Fieldslib.Field.t_with_perm

  val proof :
    ([< `Read | `Set_and_create ], 'proof t, 'proof) Fieldslib.Field.t_with_perm

  val make_creator :
       proof:
         (   ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm
          -> 'b
          -> ('c -> 'd) * 'e)
    -> fee:
         (   ( [< `Read | `Set_and_create ]
             , 'f t
             , Mina_base.Fee_with_prover.t )
             Fieldslib.Field.t_with_perm
          -> 'e
          -> ('c -> Mina_base.Fee_with_prover.t) * 'g)
    -> 'b
    -> ('c -> 'd t) * 'g

  val create : proof:'a -> fee:Mina_base.Fee_with_prover.t -> 'a t

  val map :
       proof:
         (   ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm
          -> 'b)
    -> fee:
         (   ( [< `Read | `Set_and_create ]
             , 'c t
             , Mina_base.Fee_with_prover.t )
             Fieldslib.Field.t_with_perm
          -> Mina_base.Fee_with_prover.t)
    -> 'b t

  val iter :
       proof:
         (   ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm
          -> unit)
    -> fee:
         (   ( [< `Read | `Set_and_create ]
             , 'b t
             , Mina_base.Fee_with_prover.t )
             Fieldslib.Field.t_with_perm
          -> unit)
    -> unit

  val fold :
       init:'a
    -> proof:
         (   'a
          -> ( [< `Read | `Set_and_create ]
             , 'b t
             , 'b )
             Fieldslib.Field.t_with_perm
          -> 'c)
    -> fee:
         (   'c
          -> ( [< `Read | `Set_and_create ]
             , 'd t
             , Mina_base.Fee_with_prover.t )
             Fieldslib.Field.t_with_perm
          -> 'e)
    -> 'e

  val map_poly :
    ([< `Read | `Set_and_create ], 'a t, 'b) Fieldslib.Field.user -> 'b list

  val for_all :
       proof:
         (   ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm
          -> bool)
    -> fee:
         (   ( [< `Read | `Set_and_create ]
             , 'b t
             , Mina_base.Fee_with_prover.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> bool

  val exists :
       proof:
         (   ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm
          -> bool)
    -> fee:
         (   ( [< `Read | `Set_and_create ]
             , 'b t
             , Mina_base.Fee_with_prover.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> bool

  val to_list :
       proof:
         (   ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm
          -> 'b)
    -> fee:
         (   ( [< `Read | `Set_and_create ]
             , 'c t
             , Mina_base.Fee_with_prover.t )
             Fieldslib.Field.t_with_perm
          -> 'b)
    -> 'b list

  module Direct : sig
    val iter :
         'a t
      -> proof:
           (   ( [< `Read | `Set_and_create ]
               , 'b t
               , 'b )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> 'a
            -> unit)
      -> fee:
           (   ( [< `Read | `Set_and_create ]
               , 'c t
               , Mina_base.Fee_with_prover.t )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> Mina_base.Fee_with_prover.t
            -> 'd)
      -> 'd

    val fold :
         'a t
      -> init:'b
      -> proof:
           (   'b
            -> ( [< `Read | `Set_and_create ]
               , 'c t
               , 'c )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> 'a
            -> 'd)
      -> fee:
           (   'd
            -> ( [< `Read | `Set_and_create ]
               , 'e t
               , Mina_base.Fee_with_prover.t )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> Mina_base.Fee_with_prover.t
            -> 'f)
      -> 'f

    val for_all :
         'a t
      -> proof:
           (   ( [< `Read | `Set_and_create ]
               , 'b t
               , 'b )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> 'a
            -> bool)
      -> fee:
           (   ( [< `Read | `Set_and_create ]
               , 'c t
               , Mina_base.Fee_with_prover.t )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> Mina_base.Fee_with_prover.t
            -> bool)
      -> bool

    val exists :
         'a t
      -> proof:
           (   ( [< `Read | `Set_and_create ]
               , 'b t
               , 'b )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> 'a
            -> bool)
      -> fee:
           (   ( [< `Read | `Set_and_create ]
               , 'c t
               , Mina_base.Fee_with_prover.t )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> Mina_base.Fee_with_prover.t
            -> bool)
      -> bool

    val to_list :
         'a t
      -> proof:
           (   ( [< `Read | `Set_and_create ]
               , 'b t
               , 'b )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> 'a
            -> 'c)
      -> fee:
           (   ( [< `Read | `Set_and_create ]
               , 'd t
               , Mina_base.Fee_with_prover.t )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> Mina_base.Fee_with_prover.t
            -> 'c)
      -> 'c list

    val map :
         'a t
      -> proof:
           (   ( [< `Read | `Set_and_create ]
               , 'b t
               , 'b )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> 'a
            -> 'c)
      -> fee:
           (   ( [< `Read | `Set_and_create ]
               , 'd t
               , Mina_base.Fee_with_prover.t )
               Fieldslib.Field.t_with_perm
            -> 'a t
            -> Mina_base.Fee_with_prover.t
            -> Mina_base.Fee_with_prover.t)
      -> 'c t

    val set_all_mutable_fields : 'a -> unit
  end
end

val t_of_sexp :
  (Ppx_sexp_conv_lib.Sexp.t -> 'proof) -> Ppx_sexp_conv_lib.Sexp.t -> 'proof t

val sexp_of_t :
  ('proof -> Ppx_sexp_conv_lib.Sexp.t) -> 'proof t -> Ppx_sexp_conv_lib.Sexp.t

val hash_fold_t :
     (Ppx_hash_lib.Std.Hash.state -> 'proof -> Ppx_hash_lib.Std.Hash.state)
  -> Ppx_hash_lib.Std.Hash.state
  -> 'proof t
  -> Ppx_hash_lib.Std.Hash.state
