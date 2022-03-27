module Make : functor
  (Elem : sig
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

     module Params : sig
       type t0 = t

       type t

       val buckets : t -> int

       val create : ?min:t0 -> ?max:t0 -> ?buckets:int -> unit -> t
     end

     val bucket :
       params:Params.t -> t -> [ `Index of int | `Overflow | `Underflow ]

     val interval_of_bucket : params:Params.t -> int -> t * t
   end)
  -> sig
  type t =
    { buckets : int Core_kernel.Array.t
    ; intervals : (Elem.t * Elem.t) Core_kernel.List.t
    ; mutable underflow : int
    ; mutable overflow : int
    ; params : Elem.Params.t
    }

  val create : ?buckets:int -> ?min:Elem.t -> ?max:Elem.t -> unit -> t

  val clear : t -> unit

  module Pretty : sig
    type t =
      { values : int list
      ; intervals : (Elem.t * Elem.t) list
      ; underflow : int
      ; overflow : int
      }

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val bin_shape_t : Core_kernel.Bin_prot.Shape.t

    val __bin_read_t__ : (int -> t) Core_kernel.Bin_prot.Read.reader

    val bin_read_t : t Core_kernel.Bin_prot.Read.reader

    val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

    val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

    val bin_write_t : t Core_kernel.Bin_prot.Write.writer

    val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

    val bin_t : t Core_kernel.Bin_prot.Type_class.t

    val overflow : t -> int

    val underflow : t -> int

    val intervals : t -> (Elem.t * Elem.t) list

    val values : t -> int list

    module Fields : sig
      val names : string list

      val overflow :
        ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm

      val underflow :
        ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm

      val intervals :
        ( [< `Read | `Set_and_create ]
        , t
        , (Elem.t * Elem.t) list )
        Fieldslib.Field.t_with_perm

      val values :
        ([< `Read | `Set_and_create ], t, int list) Fieldslib.Field.t_with_perm

      val make_creator :
           values:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int list )
                 Fieldslib.Field.t_with_perm
              -> 'a
              -> ('b -> int list) * 'c)
        -> intervals:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , (Elem.t * Elem.t) list )
                 Fieldslib.Field.t_with_perm
              -> 'c
              -> ('b -> (Elem.t * Elem.t) list) * 'd)
        -> underflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> 'd
              -> ('b -> int) * 'e)
        -> overflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> 'e
              -> ('b -> int) * 'f)
        -> 'a
        -> ('b -> t) * 'f

      val create :
           values:int list
        -> intervals:(Elem.t * Elem.t) list
        -> underflow:int
        -> overflow:int
        -> t

      val map :
           values:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int list )
                 Fieldslib.Field.t_with_perm
              -> int list)
        -> intervals:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , (Elem.t * Elem.t) list )
                 Fieldslib.Field.t_with_perm
              -> (Elem.t * Elem.t) list)
        -> underflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> int)
        -> overflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> int)
        -> t

      val iter :
           values:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int list )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> intervals:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , (Elem.t * Elem.t) list )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> underflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> overflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> unit

      val fold :
           init:'a
        -> values:
             (   'a
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , int list )
                 Fieldslib.Field.t_with_perm
              -> 'b)
        -> intervals:
             (   'b
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , (Elem.t * Elem.t) list )
                 Fieldslib.Field.t_with_perm
              -> 'c)
        -> underflow:
             (   'c
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> 'd)
        -> overflow:
             (   'd
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> 'e)
        -> 'e

      val map_poly :
        ([< `Read | `Set_and_create ], t, 'a) Fieldslib.Field.user -> 'a list

      val for_all :
           values:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int list )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> intervals:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , (Elem.t * Elem.t) list )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> underflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> overflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val exists :
           values:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int list )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> intervals:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , (Elem.t * Elem.t) list )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> underflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> overflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val to_list :
           values:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int list )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> intervals:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , (Elem.t * Elem.t) list )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> underflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> overflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> 'a list

      module Direct : sig
        val iter :
             t
          -> values:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int list
                -> unit)
          -> intervals:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , (Elem.t * Elem.t) list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> (Elem.t * Elem.t) list
                -> unit)
          -> underflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> unit)
          -> overflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> 'a)
          -> 'a

        val fold :
             t
          -> init:'a
          -> values:
               (   'a
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , int list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int list
                -> 'b)
          -> intervals:
               (   'b
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , (Elem.t * Elem.t) list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> (Elem.t * Elem.t) list
                -> 'c)
          -> underflow:
               (   'c
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> 'd)
          -> overflow:
               (   'd
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> 'e)
          -> 'e

        val for_all :
             t
          -> values:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int list
                -> bool)
          -> intervals:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , (Elem.t * Elem.t) list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> (Elem.t * Elem.t) list
                -> bool)
          -> underflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> bool)
          -> overflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> bool)
          -> bool

        val exists :
             t
          -> values:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int list
                -> bool)
          -> intervals:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , (Elem.t * Elem.t) list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> (Elem.t * Elem.t) list
                -> bool)
          -> underflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> bool)
          -> overflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> bool)
          -> bool

        val to_list :
             t
          -> values:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int list
                -> 'a)
          -> intervals:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , (Elem.t * Elem.t) list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> (Elem.t * Elem.t) list
                -> 'a)
          -> underflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> 'a)
          -> overflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> 'a)
          -> 'a list

        val map :
             t
          -> values:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int list
                -> int list)
          -> intervals:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , (Elem.t * Elem.t) list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> (Elem.t * Elem.t) list
                -> (Elem.t * Elem.t) list)
          -> underflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> int)
          -> overflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> int)
          -> t

        val set_all_mutable_fields : 'a -> unit
      end
    end
  end

  val report : t -> Pretty.t

  val add : t -> Elem.t -> unit
end

module Exp_time_spans : sig
  type t

  val create :
       ?buckets:int
    -> ?min:Core_kernel.Time.Span.t
    -> ?max:Core_kernel.Time.Span.t
    -> unit
    -> t

  val clear : t -> unit

  module Pretty : sig
    type t =
      { values : int list
      ; intervals : (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list
      ; underflow : int
      ; overflow : int
      }

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val bin_shape_t : Core_kernel.Bin_prot.Shape.t

    val __bin_read_t__ : (int -> t) Core_kernel.Bin_prot.Read.reader

    val bin_read_t : t Core_kernel.Bin_prot.Read.reader

    val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

    val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

    val bin_write_t : t Core_kernel.Bin_prot.Write.writer

    val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

    val bin_t : t Core_kernel.Bin_prot.Type_class.t

    val overflow : t -> int

    val underflow : t -> int

    val intervals :
      t -> (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list

    val values : t -> int list

    module Fields : sig
      val names : string list

      val overflow :
        ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm

      val underflow :
        ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm

      val intervals :
        ( [< `Read | `Set_and_create ]
        , t
        , (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list )
        Fieldslib.Field.t_with_perm

      val values :
        ([< `Read | `Set_and_create ], t, int list) Fieldslib.Field.t_with_perm

      val make_creator :
           values:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int list )
                 Fieldslib.Field.t_with_perm
              -> 'a
              -> ('b -> int list) * 'c)
        -> intervals:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list )
                 Fieldslib.Field.t_with_perm
              -> 'c
              -> (   'b
                  -> (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list)
                 * 'd)
        -> underflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> 'd
              -> ('b -> int) * 'e)
        -> overflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> 'e
              -> ('b -> int) * 'f)
        -> 'a
        -> ('b -> t) * 'f

      val create :
           values:int list
        -> intervals:(Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list
        -> underflow:int
        -> overflow:int
        -> t

      val map :
           values:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int list )
                 Fieldslib.Field.t_with_perm
              -> int list)
        -> intervals:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list )
                 Fieldslib.Field.t_with_perm
              -> (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list)
        -> underflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> int)
        -> overflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> int)
        -> t

      val iter :
           values:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int list )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> intervals:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> underflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> overflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> unit

      val fold :
           init:'a
        -> values:
             (   'a
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , int list )
                 Fieldslib.Field.t_with_perm
              -> 'b)
        -> intervals:
             (   'b
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list )
                 Fieldslib.Field.t_with_perm
              -> 'c)
        -> underflow:
             (   'c
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> 'd)
        -> overflow:
             (   'd
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> 'e)
        -> 'e

      val map_poly :
        ([< `Read | `Set_and_create ], t, 'a) Fieldslib.Field.user -> 'a list

      val for_all :
           values:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int list )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> intervals:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> underflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> overflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val exists :
           values:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int list )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> intervals:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> underflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> overflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val to_list :
           values:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int list )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> intervals:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> underflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> overflow:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> 'a list

      module Direct : sig
        val iter :
             t
          -> values:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int list
                -> unit)
          -> intervals:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list
                   )
                   Fieldslib.Field.t_with_perm
                -> t
                -> (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list
                -> unit)
          -> underflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> unit)
          -> overflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> 'a)
          -> 'a

        val fold :
             t
          -> init:'a
          -> values:
               (   'a
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , int list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int list
                -> 'b)
          -> intervals:
               (   'b
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list
                   )
                   Fieldslib.Field.t_with_perm
                -> t
                -> (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list
                -> 'c)
          -> underflow:
               (   'c
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> 'd)
          -> overflow:
               (   'd
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> 'e)
          -> 'e

        val for_all :
             t
          -> values:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int list
                -> bool)
          -> intervals:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list
                   )
                   Fieldslib.Field.t_with_perm
                -> t
                -> (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list
                -> bool)
          -> underflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> bool)
          -> overflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> bool)
          -> bool

        val exists :
             t
          -> values:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int list
                -> bool)
          -> intervals:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list
                   )
                   Fieldslib.Field.t_with_perm
                -> t
                -> (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list
                -> bool)
          -> underflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> bool)
          -> overflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> bool)
          -> bool

        val to_list :
             t
          -> values:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int list
                -> 'a)
          -> intervals:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list
                   )
                   Fieldslib.Field.t_with_perm
                -> t
                -> (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list
                -> 'a)
          -> underflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> 'a)
          -> overflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> 'a)
          -> 'a list

        val map :
             t
          -> values:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int list )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int list
                -> int list)
          -> intervals:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list
                   )
                   Fieldslib.Field.t_with_perm
                -> t
                -> (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list
                -> (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) list)
          -> underflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> int)
          -> overflow:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> t
                -> int
                -> int)
          -> t

        val set_all_mutable_fields : 'a -> unit
      end
    end
  end

  val report : t -> Pretty.t

  val add : t -> Core_kernel.Time.Span.t -> unit
end
