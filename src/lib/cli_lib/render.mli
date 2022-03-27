module type Printable_intf = sig
  type t

  val to_yojson : t -> Yojson.Safe.t

  val to_text : t -> string
end

val print :
     (module Printable_intf with type t = 't)
  -> error_ctx:string
  -> bool
  -> ('t, Core_kernel.Error.t) Core_kernel._result
  -> Base.unit

module String_list_formatter : sig
  type t = string list

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val log10 : int -> int

  val to_text : string list -> string
end

module Prove_receipt : sig
  type t = Mina_base.Receipt.Chain_hash.t * Mina_base.User_command.t list

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val to_text : t -> string
end

module Public_key_with_details : sig
  module Pretty_account : sig
    type t = string * int * int

    val to_yojson :
         'a * 'b * 'b
      -> [> `Assoc of ('a * [> `Assoc of (string * [> `Int of 'b ]) list ]) list
         ]
  end

  type t = Pretty_account.t list

  type format = { accounts : t }

  val format_to_yojson : format -> Yojson.Safe.t

  val accounts : format -> t

  module Fields_of_format : sig
    val names : string list

    val accounts :
      ([< `Read | `Set_and_create ], format, t) Fieldslib.Field.t_with_perm

    val make_creator :
         accounts:
           (   ( [< `Read | `Set_and_create ]
               , format
               , t )
               Fieldslib.Field.t_with_perm
            -> 'a
            -> ('b -> t) * 'c)
      -> 'a
      -> ('b -> format) * 'c

    val create : accounts:t -> format

    val map :
         accounts:
           (   ( [< `Read | `Set_and_create ]
               , format
               , t )
               Fieldslib.Field.t_with_perm
            -> t)
      -> format

    val iter :
         accounts:
           (   ( [< `Read | `Set_and_create ]
               , format
               , t )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> unit

    val fold :
         init:'a
      -> accounts:
           (   'a
            -> ( [< `Read | `Set_and_create ]
               , format
               , t )
               Fieldslib.Field.t_with_perm
            -> 'b)
      -> 'b

    val map_poly :
      ([< `Read | `Set_and_create ], format, 'a) Fieldslib.Field.user -> 'a list

    val for_all :
         accounts:
           (   ( [< `Read | `Set_and_create ]
               , format
               , t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val exists :
         accounts:
           (   ( [< `Read | `Set_and_create ]
               , format
               , t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val to_list :
         accounts:
           (   ( [< `Read | `Set_and_create ]
               , format
               , t )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> 'a list

    module Direct : sig
      val iter :
           format
        -> accounts:
             (   ( [< `Read | `Set_and_create ]
                 , format
                 , t )
                 Fieldslib.Field.t_with_perm
              -> format
              -> t
              -> 'a)
        -> 'a

      val fold :
           format
        -> init:'a
        -> accounts:
             (   'a
              -> ( [< `Read | `Set_and_create ]
                 , format
                 , t )
                 Fieldslib.Field.t_with_perm
              -> format
              -> t
              -> 'b)
        -> 'b

      val for_all :
           format
        -> accounts:
             (   ( [< `Read | `Set_and_create ]
                 , format
                 , t )
                 Fieldslib.Field.t_with_perm
              -> format
              -> t
              -> bool)
        -> bool

      val exists :
           format
        -> accounts:
             (   ( [< `Read | `Set_and_create ]
                 , format
                 , t )
                 Fieldslib.Field.t_with_perm
              -> format
              -> t
              -> bool)
        -> bool

      val to_list :
           format
        -> accounts:
             (   ( [< `Read | `Set_and_create ]
                 , format
                 , t )
                 Fieldslib.Field.t_with_perm
              -> format
              -> t
              -> 'a)
        -> 'a list

      val map :
           format
        -> accounts:
             (   ( [< `Read | `Set_and_create ]
                 , format
                 , t )
                 Fieldslib.Field.t_with_perm
              -> format
              -> t
              -> t)
        -> format

      val set_all_mutable_fields : 'a -> unit
    end
  end

  val to_yojson : t -> Yojson.Safe.t

  val to_text : (string * int * int) list -> string
end
