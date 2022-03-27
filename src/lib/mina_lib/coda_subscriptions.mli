type 'a reader_and_writer =
  'a Async_kernel.Pipe.Reader.t * 'a Async_kernel.Pipe.Writer.t

module Optional_public_key : sig
  module T : sig
    type t = Signature_lib.Public_key.Compressed.t option

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

    val compare : t -> t -> int

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
  end

  val compare : T.t -> T.t -> Core_kernel__.Import.int

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> T.t -> Ppx_hash_lib.Std.Hash.state

  val hash : T.t -> Ppx_hash_lib.Std.Hash.hash_value

  val hashable : T.t Core_kernel__.Hashtbl.Hashable.t

  module Table : sig
    type key = T.t

    type ('a, 'b) hashtbl = ('a, 'b) Core_kernel__.Hashtbl.t

    type 'b t = (key, 'b) hashtbl

    val sexp_of_t :
      ('b -> Ppx_sexp_conv_lib.Sexp.t) -> 'b t -> Ppx_sexp_conv_lib.Sexp.t

    type ('a, 'b) t_ = 'b t

    type 'a key_ = key

    val hashable : key Core_kernel__.Hashtbl_intf.Hashable.t

    val invariant :
      'a Base__.Invariant_intf.inv -> 'a t Base__.Invariant_intf.inv

    val create :
      ( key
      , 'b
      , unit -> 'b t )
      Core_kernel__.Hashtbl_intf.create_options_without_hashable

    val of_alist :
      ( key
      , 'b
      , (key * 'b) list -> [ `Duplicate_key of key | `Ok of 'b t ] )
      Core_kernel__.Hashtbl_intf.create_options_without_hashable

    val of_alist_report_all_dups :
      ( key
      , 'b
      , (key * 'b) list -> [ `Duplicate_keys of key list | `Ok of 'b t ] )
      Core_kernel__.Hashtbl_intf.create_options_without_hashable

    val of_alist_or_error :
      ( key
      , 'b
      , (key * 'b) list -> 'b t Base__.Or_error.t )
      Core_kernel__.Hashtbl_intf.create_options_without_hashable

    val of_alist_exn :
      ( key
      , 'b
      , (key * 'b) list -> 'b t )
      Core_kernel__.Hashtbl_intf.create_options_without_hashable

    val of_alist_multi :
      ( key
      , 'b list
      , (key * 'b) list -> 'b list t )
      Core_kernel__.Hashtbl_intf.create_options_without_hashable

    val create_mapped :
      ( key
      , 'b
      ,    get_key:('r -> key)
        -> get_data:('r -> 'b)
        -> 'r list
        -> [ `Duplicate_keys of key list | `Ok of 'b t ] )
      Core_kernel__.Hashtbl_intf.create_options_without_hashable

    val create_with_key :
      ( key
      , 'r
      ,    get_key:('r -> key)
        -> 'r list
        -> [ `Duplicate_keys of key list | `Ok of 'r t ] )
      Core_kernel__.Hashtbl_intf.create_options_without_hashable

    val create_with_key_or_error :
      ( key
      , 'r
      , get_key:('r -> key) -> 'r list -> 'r t Base__.Or_error.t )
      Core_kernel__.Hashtbl_intf.create_options_without_hashable

    val create_with_key_exn :
      ( key
      , 'r
      , get_key:('r -> key) -> 'r list -> 'r t )
      Core_kernel__.Hashtbl_intf.create_options_without_hashable

    val group :
      ( key
      , 'b
      ,    get_key:('r -> key)
        -> get_data:('r -> 'b)
        -> combine:('b -> 'b -> 'b)
        -> 'r list
        -> 'b t )
      Core_kernel__.Hashtbl_intf.create_options_without_hashable

    val sexp_of_key : 'a t -> key -> Base__.Sexp.t

    val clear : 'a t -> unit

    val copy : 'b t -> 'b t

    val fold : 'b t -> init:'c -> f:(key:key -> data:'b -> 'c -> 'c) -> 'c

    val iter_keys : 'a t -> f:(key -> unit) -> unit

    val iter : 'b t -> f:('b -> unit) -> unit

    val iteri : 'b t -> f:(key:key -> data:'b -> unit) -> unit

    val existsi : 'b t -> f:(key:key -> data:'b -> bool) -> bool

    val exists : 'b t -> f:('b -> bool) -> bool

    val for_alli : 'b t -> f:(key:key -> data:'b -> bool) -> bool

    val for_all : 'b t -> f:('b -> bool) -> bool

    val counti : 'b t -> f:(key:key -> data:'b -> bool) -> int

    val count : 'b t -> f:('b -> bool) -> int

    val length : 'a t -> int

    val is_empty : 'a t -> bool

    val mem : 'a t -> key -> bool

    val remove : 'a t -> key -> unit

    val choose : 'b t -> (key * 'b) option

    val choose_exn : 'b t -> key * 'b

    val set : 'b t -> key:key -> data:'b -> unit

    val add : 'b t -> key:key -> data:'b -> [ `Duplicate | `Ok ]

    val add_exn : 'b t -> key:key -> data:'b -> unit

    val change : 'b t -> key -> f:('b option -> 'b option) -> unit

    val update : 'b t -> key -> f:('b option -> 'b) -> unit

    val map : 'b t -> f:('b -> 'c) -> 'c t

    val mapi : 'b t -> f:(key:key -> data:'b -> 'c) -> 'c t

    val filter_map : 'b t -> f:('b -> 'c option) -> 'c t

    val filter_mapi : 'b t -> f:(key:key -> data:'b -> 'c option) -> 'c t

    val filter_keys : 'b t -> f:(key -> bool) -> 'b t

    val filter : 'b t -> f:('b -> bool) -> 'b t

    val filteri : 'b t -> f:(key:key -> data:'b -> bool) -> 'b t

    val partition_map :
      'b t -> f:('b -> [ `Fst of 'c | `Snd of 'd ]) -> 'c t * 'd t

    val partition_mapi :
         'b t
      -> f:(key:key -> data:'b -> [ `Fst of 'c | `Snd of 'd ])
      -> 'c t * 'd t

    val partition_tf : 'b t -> f:('b -> bool) -> 'b t * 'b t

    val partitioni_tf : 'b t -> f:(key:key -> data:'b -> bool) -> 'b t * 'b t

    val find_or_add : 'b t -> key -> default:(unit -> 'b) -> 'b

    val findi_or_add : 'b t -> key -> default:(key -> 'b) -> 'b

    val find : 'b t -> key -> 'b option

    val find_exn : 'b t -> key -> 'b

    val find_and_call :
      'b t -> key -> if_found:('b -> 'c) -> if_not_found:(key -> 'c) -> 'c

    val findi_and_call :
         'b t
      -> key
      -> if_found:(key:key -> data:'b -> 'c)
      -> if_not_found:(key -> 'c)
      -> 'c

    val find_and_remove : 'b t -> key -> 'b option

    val merge :
         'a t
      -> 'b t
      -> f:
           (   key:key
            -> [ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
            -> 'c option)
      -> 'c t

    type 'a merge_into_action =
          'a Core_kernel__Hashable.Make(T).Table.merge_into_action =
      | Remove
      | Set_to of 'a

    val merge_into :
         src:'a t
      -> dst:'b t
      -> f:(key:key -> 'a -> 'b option -> 'b merge_into_action)
      -> unit

    val keys : 'a t -> key list

    val data : 'b t -> 'b list

    val filter_keys_inplace : 'a t -> f:(key -> bool) -> unit

    val filter_inplace : 'b t -> f:('b -> bool) -> unit

    val filteri_inplace : 'b t -> f:(key:key -> data:'b -> bool) -> unit

    val map_inplace : 'b t -> f:('b -> 'b) -> unit

    val mapi_inplace : 'b t -> f:(key:key -> data:'b -> 'b) -> unit

    val filter_map_inplace : 'b t -> f:('b -> 'b option) -> unit

    val filter_mapi_inplace :
      'b t -> f:(key:key -> data:'b -> 'b option) -> unit

    val equal : 'b t -> 'b t -> ('b -> 'b -> bool) -> bool

    val similar : 'b1 t -> 'b2 t -> ('b1 -> 'b2 -> bool) -> bool

    val to_alist : 'b t -> (key * 'b) list

    val validate :
         name:(key -> string)
      -> 'b Base__.Validate.check
      -> 'b t Base__.Validate.check

    val incr : ?by:int -> ?remove_if_zero:bool -> int t -> key -> unit

    val decr : ?by:int -> ?remove_if_zero:bool -> int t -> key -> unit

    val add_multi : 'b list t -> key:key -> data:'b -> unit

    val remove_multi : 'a list t -> key -> unit

    val find_multi : 'b list t -> key -> 'b list

    module Provide_of_sexp : functor
      (Key : sig
         val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> key
       end)
      -> sig
      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__001_)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> 'v_x__001_ t
    end

    module Provide_bin_io : functor
      (Key : sig
         val bin_size_t : key Bin_prot.Size.sizer

         val bin_write_t : key Bin_prot.Write.writer

         val bin_read_t : key Bin_prot.Read.reader

         val __bin_read_t__ : (int -> key) Bin_prot.Read.reader

         val bin_shape_t : Bin_prot.Shape.t

         val bin_writer_t : key Bin_prot.Type_class.writer

         val bin_reader_t : key Bin_prot.Type_class.reader

         val bin_t : key Bin_prot.Type_class.t
       end)
      -> sig
      val bin_shape_t : Bin_prot.Shape.t -> Bin_prot.Shape.t

      val bin_size_t : ('a, 'a t) Bin_prot.Size.sizer1

      val bin_write_t : ('a, 'a t) Bin_prot.Write.writer1

      val bin_read_t : ('a, 'a t) Bin_prot.Read.reader1

      val __bin_read_t__ : ('a, int -> 'a t) Bin_prot.Read.reader1

      val bin_writer_t : ('a, 'a t) Bin_prot.Type_class.S1.writer

      val bin_reader_t : ('a, 'a t) Bin_prot.Type_class.S1.reader

      val bin_t : ('a, 'a t) Bin_prot.Type_class.S1.t
    end

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> 'v_x__002_ t
  end

  module Hash_set : sig
    type elt = Table.key

    type t = elt Core_kernel__.Hash_set.t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

    type 'a t_ = t

    type 'a elt_ = elt

    val create :
      ( 'a
      , unit -> t )
      Core_kernel__.Hash_set_intf.create_options_without_first_class_module

    val of_list :
      ( 'a
      , elt list -> t )
      Core_kernel__.Hash_set_intf.create_options_without_first_class_module

    module Provide_of_sexp : functor
      (X : sig
         val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> elt
       end)
      -> sig
      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
    end

    module Provide_bin_io : functor
      (X : sig
         val bin_size_t : elt Bin_prot.Size.sizer

         val bin_write_t : elt Bin_prot.Write.writer

         val bin_read_t : elt Bin_prot.Read.reader

         val __bin_read_t__ : (int -> elt) Bin_prot.Read.reader

         val bin_shape_t : Bin_prot.Shape.t

         val bin_writer_t : elt Bin_prot.Type_class.writer

         val bin_reader_t : elt Bin_prot.Type_class.reader

         val bin_t : elt Bin_prot.Type_class.t
       end)
      -> sig
      val bin_size_t : t Bin_prot.Size.sizer

      val bin_write_t : t Bin_prot.Write.writer

      val bin_read_t : t Bin_prot.Read.reader

      val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

      val bin_shape_t : Bin_prot.Shape.t

      val bin_writer_t : t Bin_prot.Type_class.writer

      val bin_reader_t : t Bin_prot.Type_class.reader

      val bin_t : t Bin_prot.Type_class.t
    end

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
  end

  module Hash_queue : sig
    type key = Table.key

    val length : ('a, 'b) Core_kernel__.Hash_queue.t -> int

    val is_empty : ('a, 'b) Core_kernel__.Hash_queue.t -> bool

    val iter : ('b, 'a) Core_kernel__.Hash_queue.t -> f:('a -> unit) -> unit

    val fold :
         ('b, 'a) Core_kernel__.Hash_queue.t
      -> init:'accum
      -> f:('accum -> 'a -> 'accum)
      -> 'accum

    val fold_result :
         ('b, 'a) Core_kernel__.Hash_queue.t
      -> init:'accum
      -> f:('accum -> 'a -> ('accum, 'e) Base__.Result.t)
      -> ('accum, 'e) Base__.Result.t

    val fold_until :
         ('b, 'a) Core_kernel__.Hash_queue.t
      -> init:'accum
      -> f:
           (   'accum
            -> 'a
            -> ('accum, 'final) Base__.Container_intf.Continue_or_stop.t)
      -> finish:('accum -> 'final)
      -> 'final

    val exists : ('b, 'a) Core_kernel__.Hash_queue.t -> f:('a -> bool) -> bool

    val for_all : ('b, 'a) Core_kernel__.Hash_queue.t -> f:('a -> bool) -> bool

    val count : ('b, 'a) Core_kernel__.Hash_queue.t -> f:('a -> bool) -> int

    val sum :
         (module Base__.Container_intf.Summable with type t = 'sum)
      -> ('b, 'a) Core_kernel__.Hash_queue.t
      -> f:('a -> 'sum)
      -> 'sum

    val find :
      ('b, 'a) Core_kernel__.Hash_queue.t -> f:('a -> bool) -> 'a option

    val find_map :
      ('c, 'a) Core_kernel__.Hash_queue.t -> f:('a -> 'b option) -> 'b option

    val to_list : ('b, 'a) Core_kernel__.Hash_queue.t -> 'a list

    val to_array : ('b, 'a) Core_kernel__.Hash_queue.t -> 'a array

    val min_elt :
         ('b, 'a) Core_kernel__.Hash_queue.t
      -> compare:('a -> 'a -> int)
      -> 'a option

    val max_elt :
         ('b, 'a) Core_kernel__.Hash_queue.t
      -> compare:('a -> 'a -> int)
      -> 'a option

    val invariant :
      ('key, 'data) Core_kernel__.Hash_queue.t -> Core_kernel__.Import.unit

    val create :
         ?growth_allowed:Core_kernel__.Import.bool
      -> ?size:Core_kernel__.Import.int
      -> Core_kernel__.Import.unit
      -> (key, 'data) Core_kernel__.Hash_queue.t

    val clear :
      ('key, 'data) Core_kernel__.Hash_queue.t -> Core_kernel__.Import.unit

    val mem :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> 'key
      -> Core_kernel__.Import.bool

    val lookup :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> 'key
      -> 'data Core_kernel__.Import.option

    val lookup_exn : ('key, 'data) Core_kernel__.Hash_queue.t -> 'key -> 'data

    val enqueue :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> [ `back | `front ]
      -> 'key
      -> 'data
      -> [ `Key_already_present | `Ok ]

    val enqueue_exn :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> [ `back | `front ]
      -> 'key
      -> 'data
      -> Core_kernel__.Import.unit

    val enqueue_back :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> 'key
      -> 'data
      -> [ `Key_already_present | `Ok ]

    val enqueue_back_exn :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> 'key
      -> 'data
      -> Core_kernel__.Import.unit

    val enqueue_front :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> 'key
      -> 'data
      -> [ `Key_already_present | `Ok ]

    val enqueue_front_exn :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> 'key
      -> 'data
      -> Core_kernel__.Import.unit

    val lookup_and_move_to_back :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> 'key
      -> 'data Core_kernel__.Import.option

    val lookup_and_move_to_back_exn :
      ('key, 'data) Core_kernel__.Hash_queue.t -> 'key -> 'data

    val lookup_and_move_to_front :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> 'key
      -> 'data Core_kernel__.Import.option

    val lookup_and_move_to_front_exn :
      ('key, 'data) Core_kernel__.Hash_queue.t -> 'key -> 'data

    val first :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> 'data Core_kernel__.Import.option

    val first_with_key :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> ('key * 'data) Core_kernel__.Import.option

    val keys :
      ('key, 'data) Core_kernel__.Hash_queue.t -> 'key Core_kernel__.Import.list

    val dequeue :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> [ `back | `front ]
      -> 'data Core_kernel__.Import.option

    val dequeue_exn :
      ('key, 'data) Core_kernel__.Hash_queue.t -> [ `back | `front ] -> 'data

    val dequeue_back :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> 'data Core_kernel__.Import.option

    val dequeue_back_exn : ('key, 'data) Core_kernel__.Hash_queue.t -> 'data

    val dequeue_front :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> 'data Core_kernel__.Import.option

    val dequeue_front_exn : ('key, 'data) Core_kernel__.Hash_queue.t -> 'data

    val dequeue_with_key :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> [ `back | `front ]
      -> ('key * 'data) Core_kernel__.Import.option

    val dequeue_with_key_exn :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> [ `back | `front ]
      -> 'key * 'data

    val dequeue_back_with_key :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> ('key * 'data) Core_kernel__.Import.option

    val dequeue_back_with_key_exn :
      ('key, 'data) Core_kernel__.Hash_queue.t -> 'key * 'data

    val dequeue_front_with_key :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> ('key * 'data) Core_kernel__.Import.option

    val dequeue_front_with_key_exn :
      ('key, 'data) Core_kernel__.Hash_queue.t -> 'key * 'data

    val dequeue_all :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> f:('data -> Core_kernel__.Import.unit)
      -> Core_kernel__.Import.unit

    val remove :
      ('key, 'data) Core_kernel__.Hash_queue.t -> 'key -> [ `No_such_key | `Ok ]

    val remove_exn :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> 'key
      -> Core_kernel__.Import.unit

    val replace :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> 'key
      -> 'data
      -> [ `No_such_key | `Ok ]

    val replace_exn :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> 'key
      -> 'data
      -> Core_kernel__.Import.unit

    val drop :
         ?n:Core_kernel__.Import.int
      -> ('key, 'data) Core_kernel__.Hash_queue.t
      -> [ `back | `front ]
      -> Core_kernel__.Import.unit

    val drop_front :
         ?n:Core_kernel__.Import.int
      -> ('key, 'data) Core_kernel__.Hash_queue.t
      -> Core_kernel__.Import.unit

    val drop_back :
         ?n:Core_kernel__.Import.int
      -> ('key, 'data) Core_kernel__.Hash_queue.t
      -> Core_kernel__.Import.unit

    val iteri :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> f:(key:'key -> data:'data -> Core_kernel__.Import.unit)
      -> Core_kernel__.Import.unit

    val foldi :
         ('key, 'data) Core_kernel__.Hash_queue.t
      -> init:'b
      -> f:('b -> key:'key -> data:'data -> 'b)
      -> 'b

    type 'data t = (key, 'data) Core_kernel__.Hash_queue.t

    val sexp_of_t :
      ('data -> Ppx_sexp_conv_lib.Sexp.t) -> 'data t -> Ppx_sexp_conv_lib.Sexp.t
  end
end

type t =
  { subscribed_payment_users :
      Mina_base.Signed_command.t reader_and_writer
      Signature_lib.Public_key.Compressed.Table.t
  ; subscribed_block_users :
      (Filtered_external_transition.t, Mina_base.State_hash.t) With_hash.t
      reader_and_writer
      list
      Optional_public_key.Table.t
  ; mutable reorganization_subscription : [ `Changed ] reader_and_writer list
  }

val add_new_subscription : t -> pk:Signature_lib.Public_key.Compressed.t -> unit

val create :
     logger:Logger.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> wallets:Secrets.Wallets.t
  -> new_blocks:
       Mina_transition.External_transition.Validated.t
       Pipe_lib.Strict_pipe.Reader.t
  -> transition_frontier:
       Transition_frontier.t option Pipe_lib.Broadcast_pipe.Reader.t
  -> is_storing_all:bool
  -> time_controller:Block_time.Controller.t
  -> upload_blocks_to_gcloud:bool
  -> precomputed_block_writer:
       ([< `Path of Base.string ] option * 'a option) Core_kernel.ref
  -> t

val add_block_subscriber :
     t
  -> Optional_public_key.Table.key Core_kernel.Hashtbl.key
  -> (Filtered_external_transition.t, Mina_base.State_hash.t) With_hash.t
     Async_kernel.Pipe.Reader.t

val add_payment_subscriber :
     t
  -> Signature_lib.Public_key.Compressed.Table.key Core_kernel.Hashtbl.key
  -> Mina_base.Signed_command.t Async_kernel.Pipe.Reader.t

val add_reorganization_subscriber : t -> [ `Changed ] Async_kernel.Pipe.Reader.t
