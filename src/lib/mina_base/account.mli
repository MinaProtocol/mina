module Index : sig
  module Stable : sig
    module V1 : sig
      module T : sig
        type t = int

        val to_yojson : t -> Yojson.Safe.t

        val bin_shape_t : Core_kernel.Bin_prot.Shape.t

        val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t : t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ : (t -> t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t : t Core_kernel.Bin_prot.Read.reader

        val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

        val bin_t : t Core_kernel.Bin_prot.Type_class.t

        val version : t

        val __ : t

        val __versioned__ : unit

        val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

        val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

        val hash_fold_t :
          Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

        val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

        val compare : t -> t -> t
      end

      type t = T.t

      val to_yojson : t -> Yojson.Safe.t

      val version : t

      val __versioned__ : unit

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val compare : t -> t -> t

      val to_latest : 'a -> 'a

      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

      val hashable : t Core_kernel__.Hashtbl.Hashable.t

      module Table : sig
        type key = t

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

        val counti : 'b t -> f:(key:key -> data:'b -> bool) -> key

        val count : 'b t -> f:('b -> bool) -> key

        val length : 'a t -> key

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

        val partitioni_tf :
          'b t -> f:(key:key -> data:'b -> bool) -> 'b t * 'b t

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
              'a Core_kernel__Hashable.Make_binable(T).Table.merge_into_action =
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

        val incr : ?by:key -> ?remove_if_zero:bool -> key t -> key -> unit

        val decr : ?by:key -> ?remove_if_zero:bool -> key t -> key -> unit

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

             val __bin_read_t__ : (key -> key) Bin_prot.Read.reader

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

          val __bin_read_t__ : ('a, key -> 'a t) Bin_prot.Read.reader1

          val bin_writer_t : ('a, 'a t) Bin_prot.Type_class.S1.writer

          val bin_reader_t : ('a, 'a t) Bin_prot.Type_class.S1.reader

          val bin_t : ('a, 'a t) Bin_prot.Type_class.S1.t
        end

        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> 'v_x__002_ t

        val bin_shape_t : Bin_prot.Shape.t -> Bin_prot.Shape.t

        val bin_size_t : ('a, 'a t) Bin_prot.Size.sizer1

        val bin_write_t : ('a, 'a t) Bin_prot.Write.writer1

        val bin_read_t : ('a, 'a t) Bin_prot.Read.reader1

        val __bin_read_t__ : ('a, key -> 'a t) Bin_prot.Read.reader1

        val bin_writer_t : ('a, 'a t) Bin_prot.Type_class.S1.writer

        val bin_reader_t : ('a, 'a t) Bin_prot.Type_class.S1.reader

        val bin_t : ('a, 'a t) Bin_prot.Type_class.S1.t
      end

      module Hash_set : sig
        type elt = t

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

             val __bin_read_t__ : (elt -> elt) Bin_prot.Read.reader

             val bin_shape_t : Bin_prot.Shape.t

             val bin_writer_t : elt Bin_prot.Type_class.writer

             val bin_reader_t : elt Bin_prot.Type_class.reader

             val bin_t : elt Bin_prot.Type_class.t
           end)
          -> sig
          val bin_size_t : t Bin_prot.Size.sizer

          val bin_write_t : t Bin_prot.Write.writer

          val bin_read_t : t Bin_prot.Read.reader

          val __bin_read_t__ : (elt -> t) Bin_prot.Read.reader

          val bin_shape_t : Bin_prot.Shape.t

          val bin_writer_t : t Bin_prot.Type_class.writer

          val bin_reader_t : t Bin_prot.Type_class.reader

          val bin_t : t Bin_prot.Type_class.t
        end

        val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

        val bin_size_t : t Bin_prot.Size.sizer

        val bin_write_t : t Bin_prot.Write.writer

        val bin_read_t : t Bin_prot.Read.reader

        val __bin_read_t__ : (elt -> t) Bin_prot.Read.reader

        val bin_shape_t : Bin_prot.Shape.t

        val bin_writer_t : t Bin_prot.Type_class.writer

        val bin_reader_t : t Bin_prot.Type_class.reader

        val bin_t : t Bin_prot.Type_class.t
      end

      module Hash_queue : sig
        type key = t

        val length : ('a, 'b) Core_kernel__.Hash_queue.t -> t

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

        val exists :
          ('b, 'a) Core_kernel__.Hash_queue.t -> f:('a -> bool) -> bool

        val for_all :
          ('b, 'a) Core_kernel__.Hash_queue.t -> f:('a -> bool) -> bool

        val count : ('b, 'a) Core_kernel__.Hash_queue.t -> f:('a -> bool) -> t

        val sum :
             (module Base__.Container_intf.Summable with type t = 'sum)
          -> ('b, 'a) Core_kernel__.Hash_queue.t
          -> f:('a -> 'sum)
          -> 'sum

        val find :
          ('b, 'a) Core_kernel__.Hash_queue.t -> f:('a -> bool) -> 'a option

        val find_map :
             ('c, 'a) Core_kernel__.Hash_queue.t
          -> f:('a -> 'b option)
          -> 'b option

        val to_list : ('b, 'a) Core_kernel__.Hash_queue.t -> 'a list

        val to_array : ('b, 'a) Core_kernel__.Hash_queue.t -> 'a array

        val min_elt :
             ('b, 'a) Core_kernel__.Hash_queue.t
          -> compare:('a -> 'a -> t)
          -> 'a option

        val max_elt :
             ('b, 'a) Core_kernel__.Hash_queue.t
          -> compare:('a -> 'a -> t)
          -> 'a option

        val invariant :
          ('key, 'data) Core_kernel__.Hash_queue.t -> Core_kernel__.Import.unit

        val create :
             ?growth_allowed:Core_kernel__.Import.bool
          -> ?size:Core_kernel__.Import.int
          -> Core_kernel__.Import.unit
          -> (t, 'data) Core_kernel__.Hash_queue.t

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

        val lookup_exn :
          ('key, 'data) Core_kernel__.Hash_queue.t -> 'key -> 'data

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
             ('key, 'data) Core_kernel__.Hash_queue.t
          -> 'key Core_kernel__.Import.list

        val dequeue :
             ('key, 'data) Core_kernel__.Hash_queue.t
          -> [ `back | `front ]
          -> 'data Core_kernel__.Import.option

        val dequeue_exn :
             ('key, 'data) Core_kernel__.Hash_queue.t
          -> [ `back | `front ]
          -> 'data

        val dequeue_back :
             ('key, 'data) Core_kernel__.Hash_queue.t
          -> 'data Core_kernel__.Import.option

        val dequeue_back_exn : ('key, 'data) Core_kernel__.Hash_queue.t -> 'data

        val dequeue_front :
             ('key, 'data) Core_kernel__.Hash_queue.t
          -> 'data Core_kernel__.Import.option

        val dequeue_front_exn :
          ('key, 'data) Core_kernel__.Hash_queue.t -> 'data

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
             ('key, 'data) Core_kernel__.Hash_queue.t
          -> 'key
          -> [ `No_such_key | `Ok ]

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
             ('data -> Ppx_sexp_conv_lib.Sexp.t)
          -> 'data t
          -> Ppx_sexp_conv_lib.Sexp.t
      end

      module With_version : sig
        type typ = t

        val bin_shape_typ : Core_kernel.Bin_prot.Shape.t

        val bin_size_typ : typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ : typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ : typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ : (typ -> typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ : typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ : typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ : typ Core_kernel.Bin_prot.Type_class.t

        type t = { version : typ; t : typ }

        val bin_shape_t : Core_kernel.Bin_prot.Shape.t

        val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t : t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ : (typ -> t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t : t Core_kernel.Bin_prot.Read.reader

        val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

        val bin_t : t Core_kernel.Bin_prot.Type_class.t

        val create : typ -> t
      end

      val bin_read_t :
        Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t

      val __bin_read_t__ :
        Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t -> t

      val bin_size_t : t -> t

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
        * (Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t -> t)
        * (t -> t)
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
      (V1.t * (Core_kernel.Bigstring.t -> pos_ref:V1.t Core_kernel.ref -> V1.t))
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

  type t = Stable.V1.t

  val to_yojson : t -> Yojson.Safe.t

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val compare : t -> t -> t

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val hashable : t Core_kernel__.Hashtbl.Hashable.t

  module Table : sig
    type key = t

    type ('a, 'b) hashtbl = ('a, 'b) Stable.V1.Table.hashtbl

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

    val counti : 'b t -> f:(key:key -> data:'b -> bool) -> key

    val count : 'b t -> f:('b -> bool) -> key

    val length : 'a t -> key

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
          'a
          Core_kernel__Hashable.Make_binable(Stable.V1).Table.merge_into_action =
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

    val incr : ?by:key -> ?remove_if_zero:bool -> key t -> key -> unit

    val decr : ?by:key -> ?remove_if_zero:bool -> key t -> key -> unit

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

         val __bin_read_t__ : (key -> key) Bin_prot.Read.reader

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

      val __bin_read_t__ : ('a, key -> 'a t) Bin_prot.Read.reader1

      val bin_writer_t : ('a, 'a t) Bin_prot.Type_class.S1.writer

      val bin_reader_t : ('a, 'a t) Bin_prot.Type_class.S1.reader

      val bin_t : ('a, 'a t) Bin_prot.Type_class.S1.t
    end

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> 'v_x__002_ t

    val bin_shape_t : Bin_prot.Shape.t -> Bin_prot.Shape.t

    val bin_size_t : ('a, 'a t) Bin_prot.Size.sizer1

    val bin_write_t : ('a, 'a t) Bin_prot.Write.writer1

    val bin_read_t : ('a, 'a t) Bin_prot.Read.reader1

    val __bin_read_t__ : ('a, key -> 'a t) Bin_prot.Read.reader1

    val bin_writer_t : ('a, 'a t) Bin_prot.Type_class.S1.writer

    val bin_reader_t : ('a, 'a t) Bin_prot.Type_class.S1.reader

    val bin_t : ('a, 'a t) Bin_prot.Type_class.S1.t
  end

  module Hash_set : sig
    type elt = t

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

         val __bin_read_t__ : (elt -> elt) Bin_prot.Read.reader

         val bin_shape_t : Bin_prot.Shape.t

         val bin_writer_t : elt Bin_prot.Type_class.writer

         val bin_reader_t : elt Bin_prot.Type_class.reader

         val bin_t : elt Bin_prot.Type_class.t
       end)
      -> sig
      val bin_size_t : t Bin_prot.Size.sizer

      val bin_write_t : t Bin_prot.Write.writer

      val bin_read_t : t Bin_prot.Read.reader

      val __bin_read_t__ : (elt -> t) Bin_prot.Read.reader

      val bin_shape_t : Bin_prot.Shape.t

      val bin_writer_t : t Bin_prot.Type_class.writer

      val bin_reader_t : t Bin_prot.Type_class.reader

      val bin_t : t Bin_prot.Type_class.t
    end

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val bin_size_t : t Bin_prot.Size.sizer

    val bin_write_t : t Bin_prot.Write.writer

    val bin_read_t : t Bin_prot.Read.reader

    val __bin_read_t__ : (elt -> t) Bin_prot.Read.reader

    val bin_shape_t : Bin_prot.Shape.t

    val bin_writer_t : t Bin_prot.Type_class.writer

    val bin_reader_t : t Bin_prot.Type_class.reader

    val bin_t : t Bin_prot.Type_class.t
  end

  module Hash_queue : sig
    type key = t

    val length : ('a, 'b) Core_kernel__.Hash_queue.t -> t

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

    val count : ('b, 'a) Core_kernel__.Hash_queue.t -> f:('a -> bool) -> t

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
      -> compare:('a -> 'a -> t)
      -> 'a option

    val max_elt :
         ('b, 'a) Core_kernel__.Hash_queue.t
      -> compare:('a -> 'a -> t)
      -> 'a option

    val invariant :
      ('key, 'data) Core_kernel__.Hash_queue.t -> Core_kernel__.Import.unit

    val create :
         ?growth_allowed:Core_kernel__.Import.bool
      -> ?size:Core_kernel__.Import.int
      -> Core_kernel__.Import.unit
      -> (t, 'data) Core_kernel__.Hash_queue.t

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

  val to_int : Core_kernel.Int.t -> t

  val gen : ledger_depth:t -> Core_kernel.Int.t Base_quickcheck.Generator.t

  module Vector : sig
    type t = Table.key

    val of_float : float -> t

    val to_float : t -> float

    val of_int_exn : t -> t

    val to_int_exn : t -> t

    type comparator_witness = Core_kernel__Int.comparator_witness

    val validate_positive : t Base__.Validate.check

    val validate_non_negative : t Base__.Validate.check

    val validate_negative : t Base__.Validate.check

    val validate_non_positive : t Base__.Validate.check

    val is_positive : t -> bool

    val is_non_negative : t -> bool

    val is_negative : t -> bool

    val is_non_positive : t -> bool

    val sign : t -> Base__.Sign0.t

    val to_string_hum : ?delimiter:char -> t -> string

    val zero : t

    val one : t

    val minus_one : t

    val ( + ) : t -> t -> t

    val ( - ) : t -> t -> t

    val ( * ) : t -> t -> t

    val ( ** ) : t -> t -> t

    val neg : t -> t

    val ( ~- ) : t -> t

    val ( /% ) : t -> t -> t

    val ( % ) : t -> t -> t

    val ( / ) : t -> t -> t

    val rem : t -> t -> t

    val ( // ) : t -> t -> float

    val ( land ) : t -> t -> t

    val ( lor ) : t -> t -> t

    val ( lxor ) : t -> t -> t

    val lnot : t -> t

    val ( lsl ) : t -> t -> t

    val ( asr ) : t -> t -> t

    val round :
      ?dir:[ `Down | `Nearest | `Up | `Zero ] -> t -> to_multiple_of:t -> t

    val round_towards_zero : t -> to_multiple_of:t -> t

    val round_down : t -> to_multiple_of:t -> t

    val round_up : t -> to_multiple_of:t -> t

    val round_nearest : t -> to_multiple_of:t -> t

    val abs : t -> t

    val succ : t -> t

    val pred : t -> t

    val pow : t -> t -> t

    val bit_and : t -> t -> t

    val bit_or : t -> t -> t

    val bit_xor : t -> t -> t

    val bit_not : t -> t

    val popcount : t -> t

    val shift_left : t -> t -> t

    val shift_right : t -> t -> t

    val decr : t Base__.Import.ref -> unit

    val incr : t Base__.Import.ref -> unit

    val of_int32_exn : int32 -> t

    val to_int32_exn : t -> int32

    val of_int64_exn : int64 -> t

    val to_int64 : t -> int64

    val of_nativeint_exn : nativeint -> t

    val to_nativeint_exn : t -> nativeint

    val of_float_unchecked : float -> t

    val num_bits : t

    val max_value : t

    val min_value : t

    val ( lsr ) : t -> t -> t

    val shift_right_logical : t -> t -> t

    val ceil_pow2 : t -> t

    val floor_pow2 : t -> t

    val ceil_log2 : t -> t

    val floor_log2 : t -> t

    val is_pow2 : t -> bool

    module O = Core_kernel__Int.O

    val max_value_30_bits : t

    val of_int : t -> t

    val to_int : t -> t

    val of_int32 : int32 -> t option

    val to_int32 : t -> int32 option

    val of_int64 : int64 -> t option

    val of_nativeint : nativeint -> t option

    val to_nativeint : t -> nativeint

    val of_int32_trunc : int32 -> t

    val to_int32_trunc : t -> int32

    val of_int64_trunc : int64 -> t

    val of_nativeint_trunc : nativeint -> t

    module Private = Core_kernel__Int.Private

    val typerep_of_t : t Typerep_lib.Std_internal.Typerep.t

    val typename_of_t : t Typerep_lib.Typename.t

    module Hex = Core_kernel__Int.Hex

    val bin_size_t : t Bin_prot.Size.sizer

    val bin_write_t : t Bin_prot.Write.writer

    val bin_read_t : t Bin_prot.Read.reader

    val __bin_read_t__ : (t -> t) Bin_prot.Read.reader

    val bin_shape_t : Bin_prot.Shape.t

    val bin_writer_t : t Bin_prot.Type_class.writer

    val bin_reader_t : t Bin_prot.Type_class.reader

    val bin_t : t Bin_prot.Type_class.t

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

    val of_string : string -> t

    val to_string : t -> string

    val pp : Base__.Formatter.t -> t -> unit

    val ( >= ) : t -> t -> bool

    val ( <= ) : t -> t -> bool

    val ( = ) : t -> t -> bool

    val ( > ) : t -> t -> bool

    val ( < ) : t -> t -> bool

    val ( <> ) : t -> t -> bool

    val equal : t -> t -> bool

    val compare : t -> t -> t

    val min : t -> t -> t

    val max : t -> t -> t

    val ascending : t -> t -> t

    val descending : t -> t -> t

    val between : t -> low:t -> high:t -> bool

    val clamp_exn : t -> min:t -> max:t -> t

    val clamp : t -> min:t -> max:t -> t Base__.Or_error.t

    val validate_lbound : min:t Base__.Maybe_bound.t -> t Base__.Validate.check

    val validate_ubound : max:t Base__.Maybe_bound.t -> t Base__.Validate.check

    val validate_bound :
         min:t Base__.Maybe_bound.t
      -> max:t Base__.Maybe_bound.t
      -> t Base__.Validate.check

    module Replace_polymorphic_compare =
      Core_kernel__Int.Replace_polymorphic_compare

    val comparator : (t, comparator_witness) Core_kernel__.Comparator.comparator

    module Map = Core_kernel__Int.Map
    module Set = Core_kernel__Int.Set

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

    val hashable : t Core_kernel__.Hashtbl.Hashable.t

    module Table = Core_kernel__Int.Table
    module Hash_set = Core_kernel__Int.Hash_set
    module Hash_queue = Core_kernel__Int.Hash_queue

    val quickcheck_generator : t Base_quickcheck.Generator.t

    val quickcheck_observer : t Base_quickcheck.Observer.t

    val quickcheck_shrinker : t Base_quickcheck.Shrinker.t

    val gen_incl : t -> t -> t Base_quickcheck.Generator.t

    val gen_uniform_incl : t -> t -> t Base_quickcheck.Generator.t

    val gen_log_uniform_incl : t -> t -> t Base_quickcheck.Generator.t

    val gen_log_incl : t -> t -> t Base_quickcheck.Generator.t

    module Stable = Core_kernel__Int.Stable

    val empty : t

    val get : t -> t -> bool

    val set : t -> t -> bool -> t
  end

  val to_bits : ledger_depth:t -> t -> bool list

  val of_bits : bool list -> t

  val fold_bits : ledger_depth:Core_kernel__Int.t -> t -> bool Fold_lib.Fold.t

  val fold :
    ledger_depth:Core_kernel__Int.t -> t -> (bool * bool * bool) Fold_lib.Fold.t

  module Unpacked : sig
    type var = Snark_params.Tick.Boolean.var list

    type value = t

    val typ : ledger_depth:value -> (var, value) Snark_params.Tick.Typ.t
  end
end

module Nonce = Mina_numbers.Account_nonce

module Poly : sig
  module Stable : sig
    module V1 : sig
      type ( 'pk
           , 'tid
           , 'token_permissions
           , 'amount
           , 'nonce
           , 'receipt_chain_hash
           , 'delegate
           , 'state_hash
           , 'timing
           , 'permissions
           , 'snapp_opt )
           t =
        { public_key : 'pk
        ; token_id : 'tid
        ; token_permissions : 'token_permissions
        ; balance : 'amount
        ; nonce : 'nonce
        ; receipt_chain_hash : 'receipt_chain_hash
        ; delegate : 'delegate
        ; voting_for : 'state_hash
        ; timing : 'timing
        ; permissions : 'permissions
        ; snapp : 'snapp_opt
        }

      val to_yojson :
           ('pk -> Yojson.Safe.t)
        -> ('tid -> Yojson.Safe.t)
        -> ('token_permissions -> Yojson.Safe.t)
        -> ('amount -> Yojson.Safe.t)
        -> ('nonce -> Yojson.Safe.t)
        -> ('receipt_chain_hash -> Yojson.Safe.t)
        -> ('delegate -> Yojson.Safe.t)
        -> ('state_hash -> Yojson.Safe.t)
        -> ('timing -> Yojson.Safe.t)
        -> ('permissions -> Yojson.Safe.t)
        -> ('snapp_opt -> Yojson.Safe.t)
        -> ( 'pk
           , 'tid
           , 'token_permissions
           , 'amount
           , 'nonce
           , 'receipt_chain_hash
           , 'delegate
           , 'state_hash
           , 'timing
           , 'permissions
           , 'snapp_opt )
           t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'pk Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'tid Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'token_permissions Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'amount Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'nonce Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'receipt_chain_hash Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'delegate Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'state_hash Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'timing Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'permissions Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'snapp_opt Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ( 'pk
           , 'tid
           , 'token_permissions
           , 'amount
           , 'nonce
           , 'receipt_chain_hash
           , 'delegate
           , 'state_hash
           , 'timing
           , 'permissions
           , 'snapp_opt )
           t
           Ppx_deriving_yojson_runtime.error_or

      val version : Index.t

      val __versioned__ : unit

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'pk)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'tid)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'token_permissions)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'amount)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'nonce)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'receipt_chain_hash)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'delegate)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'state_hash)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'timing)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'permissions)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'snapp_opt)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ( 'pk
           , 'tid
           , 'token_permissions
           , 'amount
           , 'nonce
           , 'receipt_chain_hash
           , 'delegate
           , 'state_hash
           , 'timing
           , 'permissions
           , 'snapp_opt )
           t

      val sexp_of_t :
           ('pk -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('tid -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('token_permissions -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('amount -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('nonce -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('receipt_chain_hash -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('delegate -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('state_hash -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('timing -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('permissions -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('snapp_opt -> Ppx_sexp_conv_lib.Sexp.t)
        -> ( 'pk
           , 'tid
           , 'token_permissions
           , 'amount
           , 'nonce
           , 'receipt_chain_hash
           , 'delegate
           , 'state_hash
           , 'timing
           , 'permissions
           , 'snapp_opt )
           t
        -> Ppx_sexp_conv_lib.Sexp.t

      val equal :
           ('pk -> 'pk -> bool)
        -> ('tid -> 'tid -> bool)
        -> ('token_permissions -> 'token_permissions -> bool)
        -> ('amount -> 'amount -> bool)
        -> ('nonce -> 'nonce -> bool)
        -> ('receipt_chain_hash -> 'receipt_chain_hash -> bool)
        -> ('delegate -> 'delegate -> bool)
        -> ('state_hash -> 'state_hash -> bool)
        -> ('timing -> 'timing -> bool)
        -> ('permissions -> 'permissions -> bool)
        -> ('snapp_opt -> 'snapp_opt -> bool)
        -> ( 'pk
           , 'tid
           , 'token_permissions
           , 'amount
           , 'nonce
           , 'receipt_chain_hash
           , 'delegate
           , 'state_hash
           , 'timing
           , 'permissions
           , 'snapp_opt )
           t
        -> ( 'pk
           , 'tid
           , 'token_permissions
           , 'amount
           , 'nonce
           , 'receipt_chain_hash
           , 'delegate
           , 'state_hash
           , 'timing
           , 'permissions
           , 'snapp_opt )
           t
        -> bool

      val compare :
           ('pk -> 'pk -> Index.t)
        -> ('tid -> 'tid -> Index.t)
        -> ('token_permissions -> 'token_permissions -> Index.t)
        -> ('amount -> 'amount -> Index.t)
        -> ('nonce -> 'nonce -> Index.t)
        -> ('receipt_chain_hash -> 'receipt_chain_hash -> Index.t)
        -> ('delegate -> 'delegate -> Index.t)
        -> ('state_hash -> 'state_hash -> Index.t)
        -> ('timing -> 'timing -> Index.t)
        -> ('permissions -> 'permissions -> Index.t)
        -> ('snapp_opt -> 'snapp_opt -> Index.t)
        -> ( 'pk
           , 'tid
           , 'token_permissions
           , 'amount
           , 'nonce
           , 'receipt_chain_hash
           , 'delegate
           , 'state_hash
           , 'timing
           , 'permissions
           , 'snapp_opt )
           t
        -> ( 'pk
           , 'tid
           , 'token_permissions
           , 'amount
           , 'nonce
           , 'receipt_chain_hash
           , 'delegate
           , 'state_hash
           , 'timing
           , 'permissions
           , 'snapp_opt )
           t
        -> Index.t

      val hash_fold_t :
           (Ppx_hash_lib.Std.Hash.state -> 'pk -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'tid -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'token_permissions
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'amount
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'nonce
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'receipt_chain_hash
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'delegate
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'state_hash
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'timing
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'permissions
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'snapp_opt
            -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ( 'pk
           , 'tid
           , 'token_permissions
           , 'amount
           , 'nonce
           , 'receipt_chain_hash
           , 'delegate
           , 'state_hash
           , 'timing
           , 'permissions
           , 'snapp_opt )
           t
        -> Ppx_hash_lib.Std.Hash.state

      val snapp : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'k

      val permissions : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'j

      val timing : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'i

      val voting_for : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'h

      val delegate : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'g

      val receipt_chain_hash :
        ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'f

      val nonce : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'e

      val balance : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'd

      val token_permissions :
        ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'c

      val token_id : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'b

      val public_key : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'a

      module Fields : sig
        val names : string list

        val snapp :
          ( [< `Read | `Set_and_create ]
          , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'snapp_opt) t
          , 'snapp_opt )
          Fieldslib.Field.t_with_perm

        val permissions :
          ( [< `Read | `Set_and_create ]
          , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'permissions, 'j) t
          , 'permissions )
          Fieldslib.Field.t_with_perm

        val timing :
          ( [< `Read | `Set_and_create ]
          , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'timing, 'i, 'j) t
          , 'timing )
          Fieldslib.Field.t_with_perm

        val voting_for :
          ( [< `Read | `Set_and_create ]
          , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'state_hash, 'h, 'i, 'j) t
          , 'state_hash )
          Fieldslib.Field.t_with_perm

        val delegate :
          ( [< `Read | `Set_and_create ]
          , ('a, 'b, 'c, 'd, 'e, 'f, 'delegate, 'g, 'h, 'i, 'j) t
          , 'delegate )
          Fieldslib.Field.t_with_perm

        val receipt_chain_hash :
          ( [< `Read | `Set_and_create ]
          , ('a, 'b, 'c, 'd, 'e, 'receipt_chain_hash, 'f, 'g, 'h, 'i, 'j) t
          , 'receipt_chain_hash )
          Fieldslib.Field.t_with_perm

        val nonce :
          ( [< `Read | `Set_and_create ]
          , ('a, 'b, 'c, 'd, 'nonce, 'e, 'f, 'g, 'h, 'i, 'j) t
          , 'nonce )
          Fieldslib.Field.t_with_perm

        val balance :
          ( [< `Read | `Set_and_create ]
          , ('a, 'b, 'c, 'amount, 'd, 'e, 'f, 'g, 'h, 'i, 'j) t
          , 'amount )
          Fieldslib.Field.t_with_perm

        val token_permissions :
          ( [< `Read | `Set_and_create ]
          , ('a, 'b, 'token_permissions, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j) t
          , 'token_permissions )
          Fieldslib.Field.t_with_perm

        val token_id :
          ( [< `Read | `Set_and_create ]
          , ('a, 'tid, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j) t
          , 'tid )
          Fieldslib.Field.t_with_perm

        val public_key :
          ( [< `Read | `Set_and_create ]
          , ('pk, 'a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j) t
          , 'pk )
          Fieldslib.Field.t_with_perm

        val make_creator :
             public_key:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> 'l
                -> ('m -> 'n) * 'o)
          -> token_id:
               (   ( [< `Read | `Set_and_create ]
                   , ('p, 'q, 'r, 's, 't, 'u, 'v, 'w, 'x, 'y, 'z) t
                   , 'q )
                   Fieldslib.Field.t_with_perm
                -> 'o
                -> ('m -> 'a1) * 'b1)
          -> token_permissions:
               (   ( [< `Read | `Set_and_create ]
                   , ('c1, 'd1, 'e1, 'f1, 'g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1) t
                   , 'e1 )
                   Fieldslib.Field.t_with_perm
                -> 'b1
                -> ('m -> 'n1) * 'o1)
          -> balance:
               (   ( [< `Read | `Set_and_create ]
                   , ('p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1) t
                   , 's1 )
                   Fieldslib.Field.t_with_perm
                -> 'o1
                -> ('m -> 'a2) * 'b2)
          -> nonce:
               (   ( [< `Read | `Set_and_create ]
                   , ('c2, 'd2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2) t
                   , 'g2 )
                   Fieldslib.Field.t_with_perm
                -> 'b2
                -> ('m -> 'n2) * 'o2)
          -> receipt_chain_hash:
               (   ( [< `Read | `Set_and_create ]
                   , ('p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2, 'z2) t
                   , 'u2 )
                   Fieldslib.Field.t_with_perm
                -> 'o2
                -> ('m -> 'a3) * 'b3)
          -> delegate:
               (   ( [< `Read | `Set_and_create ]
                   , ('c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3, 'k3, 'l3, 'm3) t
                   , 'i3 )
                   Fieldslib.Field.t_with_perm
                -> 'b3
                -> ('m -> 'n3) * 'o3)
          -> voting_for:
               (   ( [< `Read | `Set_and_create ]
                   , ('p3, 'q3, 'r3, 's3, 't3, 'u3, 'v3, 'w3, 'x3, 'y3, 'z3) t
                   , 'w3 )
                   Fieldslib.Field.t_with_perm
                -> 'o3
                -> ('m -> 'a4) * 'b4)
          -> timing:
               (   ( [< `Read | `Set_and_create ]
                   , ('c4, 'd4, 'e4, 'f4, 'g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4) t
                   , 'k4 )
                   Fieldslib.Field.t_with_perm
                -> 'b4
                -> ('m -> 'n4) * 'o4)
          -> permissions:
               (   ( [< `Read | `Set_and_create ]
                   , ('p4, 'q4, 'r4, 's4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4) t
                   , 'y4 )
                   Fieldslib.Field.t_with_perm
                -> 'o4
                -> ('m -> 'a5) * 'b5)
          -> snapp:
               (   ( [< `Read | `Set_and_create ]
                   , ('c5, 'd5, 'e5, 'f5, 'g5, 'h5, 'i5, 'j5, 'k5, 'l5, 'm5) t
                   , 'm5 )
                   Fieldslib.Field.t_with_perm
                -> 'b5
                -> ('m -> 'n5) * 'o5)
          -> 'l
          -> ('m -> ('n, 'a1, 'n1, 'a2, 'n2, 'a3, 'n3, 'a4, 'n4, 'a5, 'n5) t)
             * 'o5

        val create :
             public_key:'a
          -> token_id:'b
          -> token_permissions:'c
          -> balance:'d
          -> nonce:'e
          -> receipt_chain_hash:'f
          -> delegate:'g
          -> voting_for:'h
          -> timing:'i
          -> permissions:'j
          -> snapp:'k
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t

        val map :
             public_key:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> 'l)
          -> token_id:
               (   ( [< `Read | `Set_and_create ]
                   , ('m, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v, 'w) t
                   , 'n )
                   Fieldslib.Field.t_with_perm
                -> 'x)
          -> token_permissions:
               (   ( [< `Read | `Set_and_create ]
                   , ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1, 'i1) t
                   , 'a1 )
                   Fieldslib.Field.t_with_perm
                -> 'j1)
          -> balance:
               (   ( [< `Read | `Set_and_create ]
                   , ('k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1) t
                   , 'n1 )
                   Fieldslib.Field.t_with_perm
                -> 'v1)
          -> nonce:
               (   ( [< `Read | `Set_and_create ]
                   , ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2, 'e2, 'f2, 'g2) t
                   , 'a2 )
                   Fieldslib.Field.t_with_perm
                -> 'h2)
          -> receipt_chain_hash:
               (   ( [< `Read | `Set_and_create ]
                   , ('i2, 'j2, 'k2, 'l2, 'm2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2) t
                   , 'n2 )
                   Fieldslib.Field.t_with_perm
                -> 't2)
          -> delegate:
               (   ( [< `Read | `Set_and_create ]
                   , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3, 'c3, 'd3, 'e3) t
                   , 'a3 )
                   Fieldslib.Field.t_with_perm
                -> 'f3)
          -> voting_for:
               (   ( [< `Read | `Set_and_create ]
                   , ('g3, 'h3, 'i3, 'j3, 'k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3) t
                   , 'n3 )
                   Fieldslib.Field.t_with_perm
                -> 'r3)
          -> timing:
               (   ( [< `Read | `Set_and_create ]
                   , ('s3, 't3, 'u3, 'v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4) t
                   , 'a4 )
                   Fieldslib.Field.t_with_perm
                -> 'd4)
          -> permissions:
               (   ( [< `Read | `Set_and_create ]
                   , ('e4, 'f4, 'g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4) t
                   , 'n4 )
                   Fieldslib.Field.t_with_perm
                -> 'p4)
          -> snapp:
               (   ( [< `Read | `Set_and_create ]
                   , ('q4, 'r4, 's4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4, 'a5) t
                   , 'a5 )
                   Fieldslib.Field.t_with_perm
                -> 'b5)
          -> ('l, 'x, 'j1, 'v1, 'h2, 't2, 'f3, 'r3, 'd4, 'p4, 'b5) t

        val iter :
             public_key:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> token_id:
               (   ( [< `Read | `Set_and_create ]
                   , ('l, 'm, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v) t
                   , 'm )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> token_permissions:
               (   ( [< `Read | `Set_and_create ]
                   , ('w, 'x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1) t
                   , 'y )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> balance:
               (   ( [< `Read | `Set_and_create ]
                   , ('h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1) t
                   , 'k1 )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> nonce:
               (   ( [< `Read | `Set_and_create ]
                   , ('s1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2) t
                   , 'w1 )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> receipt_chain_hash:
               (   ( [< `Read | `Set_and_create ]
                   , ('d2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2) t
                   , 'i2 )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> delegate:
               (   ( [< `Read | `Set_and_create ]
                   , ('o2, 'p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2) t
                   , 'u2 )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> voting_for:
               (   ( [< `Read | `Set_and_create ]
                   , ('z2, 'a3, 'b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                   , 'g3 )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> timing:
               (   ( [< `Read | `Set_and_create ]
                   , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3) t
                   , 's3 )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> permissions:
               (   ( [< `Read | `Set_and_create ]
                   , ('v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4, 'e4, 'f4) t
                   , 'e4 )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> snapp:
               (   ( [< `Read | `Set_and_create ]
                   , ('g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4, 'q4) t
                   , 'q4 )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> unit

        val fold :
             init:'a
          -> public_key:
               (   'a
                -> ( [< `Read | `Set_and_create ]
                   , ('b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k, 'l) t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> 'm)
          -> token_id:
               (   'm
                -> ( [< `Read | `Set_and_create ]
                   , ('n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v, 'w, 'x) t
                   , 'o )
                   Fieldslib.Field.t_with_perm
                -> 'y)
          -> token_permissions:
               (   'y
                -> ( [< `Read | `Set_and_create ]
                   , ('z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1, 'i1, 'j1) t
                   , 'b1 )
                   Fieldslib.Field.t_with_perm
                -> 'k1)
          -> balance:
               (   'k1
                -> ( [< `Read | `Set_and_create ]
                   , ('l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1) t
                   , 'o1 )
                   Fieldslib.Field.t_with_perm
                -> 'w1)
          -> nonce:
               (   'w1
                -> ( [< `Read | `Set_and_create ]
                   , ('x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2, 'e2, 'f2, 'g2, 'h2) t
                   , 'b2 )
                   Fieldslib.Field.t_with_perm
                -> 'i2)
          -> receipt_chain_hash:
               (   'i2
                -> ( [< `Read | `Set_and_create ]
                   , ('j2, 'k2, 'l2, 'm2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2) t
                   , 'o2 )
                   Fieldslib.Field.t_with_perm
                -> 'u2)
          -> delegate:
               (   'u2
                -> ( [< `Read | `Set_and_create ]
                   , ('v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3, 'c3, 'd3, 'e3, 'f3) t
                   , 'b3 )
                   Fieldslib.Field.t_with_perm
                -> 'g3)
          -> voting_for:
               (   'g3
                -> ( [< `Read | `Set_and_create ]
                   , ('h3, 'i3, 'j3, 'k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3) t
                   , 'o3 )
                   Fieldslib.Field.t_with_perm
                -> 's3)
          -> timing:
               (   's3
                -> ( [< `Read | `Set_and_create ]
                   , ('t3, 'u3, 'v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4) t
                   , 'b4 )
                   Fieldslib.Field.t_with_perm
                -> 'e4)
          -> permissions:
               (   'e4
                -> ( [< `Read | `Set_and_create ]
                   , ('f4, 'g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4) t
                   , 'o4 )
                   Fieldslib.Field.t_with_perm
                -> 'q4)
          -> snapp:
               (   'q4
                -> ( [< `Read | `Set_and_create ]
                   , ('r4, 's4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4, 'a5, 'b5) t
                   , 'b5 )
                   Fieldslib.Field.t_with_perm
                -> 'c5)
          -> 'c5

        val map_poly :
             ( [< `Read | `Set_and_create ]
             , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
             , 'l )
             Fieldslib.Field.user
          -> 'l list

        val for_all :
             public_key:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> token_id:
               (   ( [< `Read | `Set_and_create ]
                   , ('l, 'm, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v) t
                   , 'm )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> token_permissions:
               (   ( [< `Read | `Set_and_create ]
                   , ('w, 'x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1) t
                   , 'y )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> balance:
               (   ( [< `Read | `Set_and_create ]
                   , ('h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1) t
                   , 'k1 )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> nonce:
               (   ( [< `Read | `Set_and_create ]
                   , ('s1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2) t
                   , 'w1 )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> receipt_chain_hash:
               (   ( [< `Read | `Set_and_create ]
                   , ('d2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2) t
                   , 'i2 )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> delegate:
               (   ( [< `Read | `Set_and_create ]
                   , ('o2, 'p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2) t
                   , 'u2 )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> voting_for:
               (   ( [< `Read | `Set_and_create ]
                   , ('z2, 'a3, 'b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                   , 'g3 )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> timing:
               (   ( [< `Read | `Set_and_create ]
                   , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3) t
                   , 's3 )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> permissions:
               (   ( [< `Read | `Set_and_create ]
                   , ('v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4, 'e4, 'f4) t
                   , 'e4 )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> snapp:
               (   ( [< `Read | `Set_and_create ]
                   , ('g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4, 'q4) t
                   , 'q4 )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> bool

        val exists :
             public_key:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> token_id:
               (   ( [< `Read | `Set_and_create ]
                   , ('l, 'm, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v) t
                   , 'm )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> token_permissions:
               (   ( [< `Read | `Set_and_create ]
                   , ('w, 'x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1) t
                   , 'y )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> balance:
               (   ( [< `Read | `Set_and_create ]
                   , ('h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1) t
                   , 'k1 )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> nonce:
               (   ( [< `Read | `Set_and_create ]
                   , ('s1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2) t
                   , 'w1 )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> receipt_chain_hash:
               (   ( [< `Read | `Set_and_create ]
                   , ('d2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2) t
                   , 'i2 )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> delegate:
               (   ( [< `Read | `Set_and_create ]
                   , ('o2, 'p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2) t
                   , 'u2 )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> voting_for:
               (   ( [< `Read | `Set_and_create ]
                   , ('z2, 'a3, 'b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                   , 'g3 )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> timing:
               (   ( [< `Read | `Set_and_create ]
                   , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3) t
                   , 's3 )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> permissions:
               (   ( [< `Read | `Set_and_create ]
                   , ('v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4, 'e4, 'f4) t
                   , 'e4 )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> snapp:
               (   ( [< `Read | `Set_and_create ]
                   , ('g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4, 'q4) t
                   , 'q4 )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> bool

        val to_list :
             public_key:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> 'l)
          -> token_id:
               (   ( [< `Read | `Set_and_create ]
                   , ('m, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v, 'w) t
                   , 'n )
                   Fieldslib.Field.t_with_perm
                -> 'l)
          -> token_permissions:
               (   ( [< `Read | `Set_and_create ]
                   , ('x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1) t
                   , 'z )
                   Fieldslib.Field.t_with_perm
                -> 'l)
          -> balance:
               (   ( [< `Read | `Set_and_create ]
                   , ('i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1, 's1) t
                   , 'l1 )
                   Fieldslib.Field.t_with_perm
                -> 'l)
          -> nonce:
               (   ( [< `Read | `Set_and_create ]
                   , ('t1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
                   , 'x1 )
                   Fieldslib.Field.t_with_perm
                -> 'l)
          -> receipt_chain_hash:
               (   ( [< `Read | `Set_and_create ]
                   , ('e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2, 'o2) t
                   , 'j2 )
                   Fieldslib.Field.t_with_perm
                -> 'l)
          -> delegate:
               (   ( [< `Read | `Set_and_create ]
                   , ('p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2, 'z2) t
                   , 'v2 )
                   Fieldslib.Field.t_with_perm
                -> 'l)
          -> voting_for:
               (   ( [< `Read | `Set_and_create ]
                   , ('a3, 'b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3, 'k3) t
                   , 'h3 )
                   Fieldslib.Field.t_with_perm
                -> 'l)
          -> timing:
               (   ( [< `Read | `Set_and_create ]
                   , ('l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3, 'v3) t
                   , 't3 )
                   Fieldslib.Field.t_with_perm
                -> 'l)
          -> permissions:
               (   ( [< `Read | `Set_and_create ]
                   , ('w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4, 'e4, 'f4, 'g4) t
                   , 'f4 )
                   Fieldslib.Field.t_with_perm
                -> 'l)
          -> snapp:
               (   ( [< `Read | `Set_and_create ]
                   , ('h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4, 'q4, 'r4) t
                   , 'r4 )
                   Fieldslib.Field.t_with_perm
                -> 'l)
          -> 'l list

        module Direct : sig
          val iter :
               ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
            -> public_key:
                 (   ( [< `Read | `Set_and_create ]
                     , ('l, 'm, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v) t
                     , 'l )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'a
                  -> unit)
            -> token_id:
                 (   ( [< `Read | `Set_and_create ]
                     , ('w, 'x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1) t
                     , 'x )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'b
                  -> unit)
            -> token_permissions:
                 (   ( [< `Read | `Set_and_create ]
                     , ('h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1) t
                     , 'j1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'c
                  -> unit)
            -> balance:
                 (   ( [< `Read | `Set_and_create ]
                     , ('s1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2) t
                     , 'v1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'd
                  -> unit)
            -> nonce:
                 (   ( [< `Read | `Set_and_create ]
                     , ('d2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2) t
                     , 'h2 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'e
                  -> unit)
            -> receipt_chain_hash:
                 (   ( [< `Read | `Set_and_create ]
                     , ('o2, 'p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2) t
                     , 't2 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'f
                  -> unit)
            -> delegate:
                 (   ( [< `Read | `Set_and_create ]
                     , ('z2, 'a3, 'b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                     , 'f3 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'g
                  -> unit)
            -> voting_for:
                 (   ( [< `Read | `Set_and_create ]
                     , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3) t
                     , 'r3 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'h
                  -> unit)
            -> timing:
                 (   ( [< `Read | `Set_and_create ]
                     , ('v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4, 'e4, 'f4) t
                     , 'd4 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'i
                  -> unit)
            -> permissions:
                 (   ( [< `Read | `Set_and_create ]
                     , ('g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4, 'q4) t
                     , 'p4 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'j
                  -> unit)
            -> snapp:
                 (   ( [< `Read | `Set_and_create ]
                     , ('r4, 's4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4, 'a5, 'b5) t
                     , 'b5 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'k
                  -> 'c5)
            -> 'c5

          val fold :
               ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
            -> init:'l
            -> public_key:
                 (   'l
                  -> ( [< `Read | `Set_and_create ]
                     , ('m, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v, 'w) t
                     , 'm )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'a
                  -> 'x)
            -> token_id:
                 (   'x
                  -> ( [< `Read | `Set_and_create ]
                     , ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1, 'i1) t
                     , 'z )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'b
                  -> 'j1)
            -> token_permissions:
                 (   'j1
                  -> ( [< `Read | `Set_and_create ]
                     , ('k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1) t
                     , 'm1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'c
                  -> 'v1)
            -> balance:
                 (   'v1
                  -> ( [< `Read | `Set_and_create ]
                     , ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2, 'e2, 'f2, 'g2) t
                     , 'z1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'd
                  -> 'h2)
            -> nonce:
                 (   'h2
                  -> ( [< `Read | `Set_and_create ]
                     , ('i2, 'j2, 'k2, 'l2, 'm2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2) t
                     , 'm2 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'e
                  -> 't2)
            -> receipt_chain_hash:
                 (   't2
                  -> ( [< `Read | `Set_and_create ]
                     , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3, 'c3, 'd3, 'e3) t
                     , 'z2 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'f
                  -> 'f3)
            -> delegate:
                 (   'f3
                  -> ( [< `Read | `Set_and_create ]
                     , ('g3, 'h3, 'i3, 'j3, 'k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3) t
                     , 'm3 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'g
                  -> 'r3)
            -> voting_for:
                 (   'r3
                  -> ( [< `Read | `Set_and_create ]
                     , ('s3, 't3, 'u3, 'v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4) t
                     , 'z3 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'h
                  -> 'd4)
            -> timing:
                 (   'd4
                  -> ( [< `Read | `Set_and_create ]
                     , ('e4, 'f4, 'g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4) t
                     , 'm4 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'i
                  -> 'p4)
            -> permissions:
                 (   'p4
                  -> ( [< `Read | `Set_and_create ]
                     , ('q4, 'r4, 's4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4, 'a5) t
                     , 'z4 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'j
                  -> 'b5)
            -> snapp:
                 (   'b5
                  -> ( [< `Read | `Set_and_create ]
                     , ('c5, 'd5, 'e5, 'f5, 'g5, 'h5, 'i5, 'j5, 'k5, 'l5, 'm5) t
                     , 'm5 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'k
                  -> 'n5)
            -> 'n5

          val for_all :
               ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
            -> public_key:
                 (   ( [< `Read | `Set_and_create ]
                     , ('l, 'm, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v) t
                     , 'l )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'a
                  -> bool)
            -> token_id:
                 (   ( [< `Read | `Set_and_create ]
                     , ('w, 'x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1) t
                     , 'x )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'b
                  -> bool)
            -> token_permissions:
                 (   ( [< `Read | `Set_and_create ]
                     , ('h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1) t
                     , 'j1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'c
                  -> bool)
            -> balance:
                 (   ( [< `Read | `Set_and_create ]
                     , ('s1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2) t
                     , 'v1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'd
                  -> bool)
            -> nonce:
                 (   ( [< `Read | `Set_and_create ]
                     , ('d2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2) t
                     , 'h2 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'e
                  -> bool)
            -> receipt_chain_hash:
                 (   ( [< `Read | `Set_and_create ]
                     , ('o2, 'p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2) t
                     , 't2 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'f
                  -> bool)
            -> delegate:
                 (   ( [< `Read | `Set_and_create ]
                     , ('z2, 'a3, 'b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                     , 'f3 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'g
                  -> bool)
            -> voting_for:
                 (   ( [< `Read | `Set_and_create ]
                     , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3) t
                     , 'r3 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'h
                  -> bool)
            -> timing:
                 (   ( [< `Read | `Set_and_create ]
                     , ('v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4, 'e4, 'f4) t
                     , 'd4 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'i
                  -> bool)
            -> permissions:
                 (   ( [< `Read | `Set_and_create ]
                     , ('g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4, 'q4) t
                     , 'p4 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'j
                  -> bool)
            -> snapp:
                 (   ( [< `Read | `Set_and_create ]
                     , ('r4, 's4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4, 'a5, 'b5) t
                     , 'b5 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'k
                  -> bool)
            -> bool

          val exists :
               ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
            -> public_key:
                 (   ( [< `Read | `Set_and_create ]
                     , ('l, 'm, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v) t
                     , 'l )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'a
                  -> bool)
            -> token_id:
                 (   ( [< `Read | `Set_and_create ]
                     , ('w, 'x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1) t
                     , 'x )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'b
                  -> bool)
            -> token_permissions:
                 (   ( [< `Read | `Set_and_create ]
                     , ('h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1) t
                     , 'j1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'c
                  -> bool)
            -> balance:
                 (   ( [< `Read | `Set_and_create ]
                     , ('s1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2) t
                     , 'v1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'd
                  -> bool)
            -> nonce:
                 (   ( [< `Read | `Set_and_create ]
                     , ('d2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2) t
                     , 'h2 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'e
                  -> bool)
            -> receipt_chain_hash:
                 (   ( [< `Read | `Set_and_create ]
                     , ('o2, 'p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2) t
                     , 't2 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'f
                  -> bool)
            -> delegate:
                 (   ( [< `Read | `Set_and_create ]
                     , ('z2, 'a3, 'b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                     , 'f3 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'g
                  -> bool)
            -> voting_for:
                 (   ( [< `Read | `Set_and_create ]
                     , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3) t
                     , 'r3 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'h
                  -> bool)
            -> timing:
                 (   ( [< `Read | `Set_and_create ]
                     , ('v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4, 'e4, 'f4) t
                     , 'd4 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'i
                  -> bool)
            -> permissions:
                 (   ( [< `Read | `Set_and_create ]
                     , ('g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4, 'q4) t
                     , 'p4 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'j
                  -> bool)
            -> snapp:
                 (   ( [< `Read | `Set_and_create ]
                     , ('r4, 's4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4, 'a5, 'b5) t
                     , 'b5 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'k
                  -> bool)
            -> bool

          val to_list :
               ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
            -> public_key:
                 (   ( [< `Read | `Set_and_create ]
                     , ('l, 'm, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v) t
                     , 'l )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'a
                  -> 'w)
            -> token_id:
                 (   ( [< `Read | `Set_and_create ]
                     , ('x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1) t
                     , 'y )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'b
                  -> 'w)
            -> token_permissions:
                 (   ( [< `Read | `Set_and_create ]
                     , ('i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1, 's1) t
                     , 'k1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'c
                  -> 'w)
            -> balance:
                 (   ( [< `Read | `Set_and_create ]
                     , ('t1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
                     , 'w1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'd
                  -> 'w)
            -> nonce:
                 (   ( [< `Read | `Set_and_create ]
                     , ('e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2, 'o2) t
                     , 'i2 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'e
                  -> 'w)
            -> receipt_chain_hash:
                 (   ( [< `Read | `Set_and_create ]
                     , ('p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2, 'z2) t
                     , 'u2 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'f
                  -> 'w)
            -> delegate:
                 (   ( [< `Read | `Set_and_create ]
                     , ('a3, 'b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3, 'k3) t
                     , 'g3 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'g
                  -> 'w)
            -> voting_for:
                 (   ( [< `Read | `Set_and_create ]
                     , ('l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3, 'v3) t
                     , 's3 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'h
                  -> 'w)
            -> timing:
                 (   ( [< `Read | `Set_and_create ]
                     , ('w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4, 'e4, 'f4, 'g4) t
                     , 'e4 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'i
                  -> 'w)
            -> permissions:
                 (   ( [< `Read | `Set_and_create ]
                     , ('h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4, 'q4, 'r4) t
                     , 'q4 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'j
                  -> 'w)
            -> snapp:
                 (   ( [< `Read | `Set_and_create ]
                     , ('s4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4, 'a5, 'b5, 'c5) t
                     , 'c5 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'k
                  -> 'w)
            -> 'w list

          val map :
               ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
            -> public_key:
                 (   ( [< `Read | `Set_and_create ]
                     , ('l, 'm, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v) t
                     , 'l )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'a
                  -> 'w)
            -> token_id:
                 (   ( [< `Read | `Set_and_create ]
                     , ('x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1) t
                     , 'y )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'b
                  -> 'i1)
            -> token_permissions:
                 (   ( [< `Read | `Set_and_create ]
                     , ('j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1, 's1, 't1) t
                     , 'l1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'c
                  -> 'u1)
            -> balance:
                 (   ( [< `Read | `Set_and_create ]
                     , ('v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2, 'e2, 'f2) t
                     , 'y1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'd
                  -> 'g2)
            -> nonce:
                 (   ( [< `Read | `Set_and_create ]
                     , ('h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2, 'o2, 'p2, 'q2, 'r2) t
                     , 'l2 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'e
                  -> 's2)
            -> receipt_chain_hash:
                 (   ( [< `Read | `Set_and_create ]
                     , ('t2, 'u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3, 'c3, 'd3) t
                     , 'y2 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'f
                  -> 'e3)
            -> delegate:
                 (   ( [< `Read | `Set_and_create ]
                     , ('f3, 'g3, 'h3, 'i3, 'j3, 'k3, 'l3, 'm3, 'n3, 'o3, 'p3) t
                     , 'l3 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'g
                  -> 'q3)
            -> voting_for:
                 (   ( [< `Read | `Set_and_create ]
                     , ('r3, 's3, 't3, 'u3, 'v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4) t
                     , 'y3 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'h
                  -> 'c4)
            -> timing:
                 (   ( [< `Read | `Set_and_create ]
                     , ('d4, 'e4, 'f4, 'g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4) t
                     , 'l4 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'i
                  -> 'o4)
            -> permissions:
                 (   ( [< `Read | `Set_and_create ]
                     , ('p4, 'q4, 'r4, 's4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4) t
                     , 'y4 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'j
                  -> 'a5)
            -> snapp:
                 (   ( [< `Read | `Set_and_create ]
                     , ('b5, 'c5, 'd5, 'e5, 'f5, 'g5, 'h5, 'i5, 'j5, 'k5, 'l5) t
                     , 'l5 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
                  -> 'k
                  -> 'm5)
            -> ('w, 'i1, 'u1, 'g2, 's2, 'e3, 'q3, 'c4, 'o4, 'a5, 'm5) t

          val set_all_mutable_fields : 'a -> unit
        end
      end

      val to_hlist :
           ( 'pk
           , 'tid
           , 'token_permissions
           , 'amount
           , 'nonce
           , 'receipt_chain_hash
           , 'delegate
           , 'state_hash
           , 'timing
           , 'permissions
           , 'snapp_opt )
           t
        -> ( unit
           ,    'pk
             -> 'tid
             -> 'token_permissions
             -> 'amount
             -> 'nonce
             -> 'receipt_chain_hash
             -> 'delegate
             -> 'state_hash
             -> 'timing
             -> 'permissions
             -> 'snapp_opt
             -> unit )
           H_list.t

      val of_hlist :
           ( unit
           ,    'pk
             -> 'tid
             -> 'token_permissions
             -> 'amount
             -> 'nonce
             -> 'receipt_chain_hash
             -> 'delegate
             -> 'state_hash
             -> 'timing
             -> 'permissions
             -> 'snapp_opt
             -> unit )
           H_list.t
        -> ( 'pk
           , 'tid
           , 'token_permissions
           , 'amount
           , 'nonce
           , 'receipt_chain_hash
           , 'delegate
           , 'state_hash
           , 'timing
           , 'permissions
           , 'snapp_opt )
           t

      module With_version : sig
        type ( 'pk
             , 'tid
             , 'token_permissions
             , 'amount
             , 'nonce
             , 'receipt_chain_hash
             , 'delegate
             , 'state_hash
             , 'timing
             , 'permissions
             , 'snapp_opt )
             typ =
          ( 'pk
          , 'tid
          , 'token_permissions
          , 'amount
          , 'nonce
          , 'receipt_chain_hash
          , 'delegate
          , 'state_hash
          , 'timing
          , 'permissions
          , 'snapp_opt )
          t

        val bin_shape_typ :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_typ :
             'pk Core_kernel.Bin_prot.Size.sizer
          -> 'tid Core_kernel.Bin_prot.Size.sizer
          -> 'token_permissions Core_kernel.Bin_prot.Size.sizer
          -> 'amount Core_kernel.Bin_prot.Size.sizer
          -> 'nonce Core_kernel.Bin_prot.Size.sizer
          -> 'receipt_chain_hash Core_kernel.Bin_prot.Size.sizer
          -> 'delegate Core_kernel.Bin_prot.Size.sizer
          -> 'state_hash Core_kernel.Bin_prot.Size.sizer
          -> 'timing Core_kernel.Bin_prot.Size.sizer
          -> 'permissions Core_kernel.Bin_prot.Size.sizer
          -> 'snapp_opt Core_kernel.Bin_prot.Size.sizer
          -> ( 'pk
             , 'tid
             , 'token_permissions
             , 'amount
             , 'nonce
             , 'receipt_chain_hash
             , 'delegate
             , 'state_hash
             , 'timing
             , 'permissions
             , 'snapp_opt )
             typ
             Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ :
             'pk Core_kernel.Bin_prot.Write.writer
          -> 'tid Core_kernel.Bin_prot.Write.writer
          -> 'token_permissions Core_kernel.Bin_prot.Write.writer
          -> 'amount Core_kernel.Bin_prot.Write.writer
          -> 'nonce Core_kernel.Bin_prot.Write.writer
          -> 'receipt_chain_hash Core_kernel.Bin_prot.Write.writer
          -> 'delegate Core_kernel.Bin_prot.Write.writer
          -> 'state_hash Core_kernel.Bin_prot.Write.writer
          -> 'timing Core_kernel.Bin_prot.Write.writer
          -> 'permissions Core_kernel.Bin_prot.Write.writer
          -> 'snapp_opt Core_kernel.Bin_prot.Write.writer
          -> ( 'pk
             , 'tid
             , 'token_permissions
             , 'amount
             , 'nonce
             , 'receipt_chain_hash
             , 'delegate
             , 'state_hash
             , 'timing
             , 'permissions
             , 'snapp_opt )
             typ
             Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> 'd Core_kernel.Bin_prot.Type_class.writer
          -> 'e Core_kernel.Bin_prot.Type_class.writer
          -> 'f Core_kernel.Bin_prot.Type_class.writer
          -> 'g Core_kernel.Bin_prot.Type_class.writer
          -> 'h Core_kernel.Bin_prot.Type_class.writer
          -> 'i Core_kernel.Bin_prot.Type_class.writer
          -> 'j Core_kernel.Bin_prot.Type_class.writer
          -> 'k Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) typ
             Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
             'pk Core_kernel.Bin_prot.Read.reader
          -> 'tid Core_kernel.Bin_prot.Read.reader
          -> 'token_permissions Core_kernel.Bin_prot.Read.reader
          -> 'amount Core_kernel.Bin_prot.Read.reader
          -> 'nonce Core_kernel.Bin_prot.Read.reader
          -> 'receipt_chain_hash Core_kernel.Bin_prot.Read.reader
          -> 'delegate Core_kernel.Bin_prot.Read.reader
          -> 'state_hash Core_kernel.Bin_prot.Read.reader
          -> 'timing Core_kernel.Bin_prot.Read.reader
          -> 'permissions Core_kernel.Bin_prot.Read.reader
          -> 'snapp_opt Core_kernel.Bin_prot.Read.reader
          -> (   Index.t
              -> ( 'pk
                 , 'tid
                 , 'token_permissions
                 , 'amount
                 , 'nonce
                 , 'receipt_chain_hash
                 , 'delegate
                 , 'state_hash
                 , 'timing
                 , 'permissions
                 , 'snapp_opt )
                 typ)
             Core_kernel.Bin_prot.Read.reader

        val bin_read_typ :
             'pk Core_kernel.Bin_prot.Read.reader
          -> 'tid Core_kernel.Bin_prot.Read.reader
          -> 'token_permissions Core_kernel.Bin_prot.Read.reader
          -> 'amount Core_kernel.Bin_prot.Read.reader
          -> 'nonce Core_kernel.Bin_prot.Read.reader
          -> 'receipt_chain_hash Core_kernel.Bin_prot.Read.reader
          -> 'delegate Core_kernel.Bin_prot.Read.reader
          -> 'state_hash Core_kernel.Bin_prot.Read.reader
          -> 'timing Core_kernel.Bin_prot.Read.reader
          -> 'permissions Core_kernel.Bin_prot.Read.reader
          -> 'snapp_opt Core_kernel.Bin_prot.Read.reader
          -> ( 'pk
             , 'tid
             , 'token_permissions
             , 'amount
             , 'nonce
             , 'receipt_chain_hash
             , 'delegate
             , 'state_hash
             , 'timing
             , 'permissions
             , 'snapp_opt )
             typ
             Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> 'c Core_kernel.Bin_prot.Type_class.reader
          -> 'd Core_kernel.Bin_prot.Type_class.reader
          -> 'e Core_kernel.Bin_prot.Type_class.reader
          -> 'f Core_kernel.Bin_prot.Type_class.reader
          -> 'g Core_kernel.Bin_prot.Type_class.reader
          -> 'h Core_kernel.Bin_prot.Type_class.reader
          -> 'i Core_kernel.Bin_prot.Type_class.reader
          -> 'j Core_kernel.Bin_prot.Type_class.reader
          -> 'k Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) typ
             Core_kernel.Bin_prot.Type_class.reader

        val bin_typ :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> 'c Core_kernel.Bin_prot.Type_class.t
          -> 'd Core_kernel.Bin_prot.Type_class.t
          -> 'e Core_kernel.Bin_prot.Type_class.t
          -> 'f Core_kernel.Bin_prot.Type_class.t
          -> 'g Core_kernel.Bin_prot.Type_class.t
          -> 'h Core_kernel.Bin_prot.Type_class.t
          -> 'i Core_kernel.Bin_prot.Type_class.t
          -> 'j Core_kernel.Bin_prot.Type_class.t
          -> 'k Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) typ
             Core_kernel.Bin_prot.Type_class.t

        type ( 'pk
             , 'tid
             , 'token_permissions
             , 'amount
             , 'nonce
             , 'receipt_chain_hash
             , 'delegate
             , 'state_hash
             , 'timing
             , 'permissions
             , 'snapp_opt )
             t =
          { version : Index.t
          ; t :
              ( 'pk
              , 'tid
              , 'token_permissions
              , 'amount
              , 'nonce
              , 'receipt_chain_hash
              , 'delegate
              , 'state_hash
              , 'timing
              , 'permissions
              , 'snapp_opt )
              typ
          }

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'pk Core_kernel.Bin_prot.Size.sizer
          -> 'tid Core_kernel.Bin_prot.Size.sizer
          -> 'token_permissions Core_kernel.Bin_prot.Size.sizer
          -> 'amount Core_kernel.Bin_prot.Size.sizer
          -> 'nonce Core_kernel.Bin_prot.Size.sizer
          -> 'receipt_chain_hash Core_kernel.Bin_prot.Size.sizer
          -> 'delegate Core_kernel.Bin_prot.Size.sizer
          -> 'state_hash Core_kernel.Bin_prot.Size.sizer
          -> 'timing Core_kernel.Bin_prot.Size.sizer
          -> 'permissions Core_kernel.Bin_prot.Size.sizer
          -> 'snapp_opt Core_kernel.Bin_prot.Size.sizer
          -> ( 'pk
             , 'tid
             , 'token_permissions
             , 'amount
             , 'nonce
             , 'receipt_chain_hash
             , 'delegate
             , 'state_hash
             , 'timing
             , 'permissions
             , 'snapp_opt )
             t
             Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'pk Core_kernel.Bin_prot.Write.writer
          -> 'tid Core_kernel.Bin_prot.Write.writer
          -> 'token_permissions Core_kernel.Bin_prot.Write.writer
          -> 'amount Core_kernel.Bin_prot.Write.writer
          -> 'nonce Core_kernel.Bin_prot.Write.writer
          -> 'receipt_chain_hash Core_kernel.Bin_prot.Write.writer
          -> 'delegate Core_kernel.Bin_prot.Write.writer
          -> 'state_hash Core_kernel.Bin_prot.Write.writer
          -> 'timing Core_kernel.Bin_prot.Write.writer
          -> 'permissions Core_kernel.Bin_prot.Write.writer
          -> 'snapp_opt Core_kernel.Bin_prot.Write.writer
          -> ( 'pk
             , 'tid
             , 'token_permissions
             , 'amount
             , 'nonce
             , 'receipt_chain_hash
             , 'delegate
             , 'state_hash
             , 'timing
             , 'permissions
             , 'snapp_opt )
             t
             Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> 'd Core_kernel.Bin_prot.Type_class.writer
          -> 'e Core_kernel.Bin_prot.Type_class.writer
          -> 'f Core_kernel.Bin_prot.Type_class.writer
          -> 'g Core_kernel.Bin_prot.Type_class.writer
          -> 'h Core_kernel.Bin_prot.Type_class.writer
          -> 'i Core_kernel.Bin_prot.Type_class.writer
          -> 'j Core_kernel.Bin_prot.Type_class.writer
          -> 'k Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
             Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ :
             'pk Core_kernel.Bin_prot.Read.reader
          -> 'tid Core_kernel.Bin_prot.Read.reader
          -> 'token_permissions Core_kernel.Bin_prot.Read.reader
          -> 'amount Core_kernel.Bin_prot.Read.reader
          -> 'nonce Core_kernel.Bin_prot.Read.reader
          -> 'receipt_chain_hash Core_kernel.Bin_prot.Read.reader
          -> 'delegate Core_kernel.Bin_prot.Read.reader
          -> 'state_hash Core_kernel.Bin_prot.Read.reader
          -> 'timing Core_kernel.Bin_prot.Read.reader
          -> 'permissions Core_kernel.Bin_prot.Read.reader
          -> 'snapp_opt Core_kernel.Bin_prot.Read.reader
          -> (   Index.t
              -> ( 'pk
                 , 'tid
                 , 'token_permissions
                 , 'amount
                 , 'nonce
                 , 'receipt_chain_hash
                 , 'delegate
                 , 'state_hash
                 , 'timing
                 , 'permissions
                 , 'snapp_opt )
                 t)
             Core_kernel.Bin_prot.Read.reader

        val bin_read_t :
             'pk Core_kernel.Bin_prot.Read.reader
          -> 'tid Core_kernel.Bin_prot.Read.reader
          -> 'token_permissions Core_kernel.Bin_prot.Read.reader
          -> 'amount Core_kernel.Bin_prot.Read.reader
          -> 'nonce Core_kernel.Bin_prot.Read.reader
          -> 'receipt_chain_hash Core_kernel.Bin_prot.Read.reader
          -> 'delegate Core_kernel.Bin_prot.Read.reader
          -> 'state_hash Core_kernel.Bin_prot.Read.reader
          -> 'timing Core_kernel.Bin_prot.Read.reader
          -> 'permissions Core_kernel.Bin_prot.Read.reader
          -> 'snapp_opt Core_kernel.Bin_prot.Read.reader
          -> ( 'pk
             , 'tid
             , 'token_permissions
             , 'amount
             , 'nonce
             , 'receipt_chain_hash
             , 'delegate
             , 'state_hash
             , 'timing
             , 'permissions
             , 'snapp_opt )
             t
             Core_kernel.Bin_prot.Read.reader

        val bin_reader_t :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> 'c Core_kernel.Bin_prot.Type_class.reader
          -> 'd Core_kernel.Bin_prot.Type_class.reader
          -> 'e Core_kernel.Bin_prot.Type_class.reader
          -> 'f Core_kernel.Bin_prot.Type_class.reader
          -> 'g Core_kernel.Bin_prot.Type_class.reader
          -> 'h Core_kernel.Bin_prot.Type_class.reader
          -> 'i Core_kernel.Bin_prot.Type_class.reader
          -> 'j Core_kernel.Bin_prot.Type_class.reader
          -> 'k Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
             Core_kernel.Bin_prot.Type_class.reader

        val bin_t :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> 'c Core_kernel.Bin_prot.Type_class.t
          -> 'd Core_kernel.Bin_prot.Type_class.t
          -> 'e Core_kernel.Bin_prot.Type_class.t
          -> 'f Core_kernel.Bin_prot.Type_class.t
          -> 'g Core_kernel.Bin_prot.Type_class.t
          -> 'h Core_kernel.Bin_prot.Type_class.t
          -> 'i Core_kernel.Bin_prot.Type_class.t
          -> 'j Core_kernel.Bin_prot.Type_class.t
          -> 'k Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
             Core_kernel.Bin_prot.Type_class.t

        val create :
             ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) typ
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
      end

      val bin_read_t :
           'a Core_kernel.Bin_prot.Read.reader
        -> 'b Core_kernel.Bin_prot.Read.reader
        -> 'c Core_kernel.Bin_prot.Read.reader
        -> 'd Core_kernel.Bin_prot.Read.reader
        -> 'e Core_kernel.Bin_prot.Read.reader
        -> 'f Core_kernel.Bin_prot.Read.reader
        -> 'g Core_kernel.Bin_prot.Read.reader
        -> 'h Core_kernel.Bin_prot.Read.reader
        -> 'i Core_kernel.Bin_prot.Read.reader
        -> 'j Core_kernel.Bin_prot.Read.reader
        -> 'k Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t

      val __bin_read_t__ :
           'a Core_kernel.Bin_prot.Read.reader
        -> 'b Core_kernel.Bin_prot.Read.reader
        -> 'c Core_kernel.Bin_prot.Read.reader
        -> 'd Core_kernel.Bin_prot.Read.reader
        -> 'e Core_kernel.Bin_prot.Read.reader
        -> 'f Core_kernel.Bin_prot.Read.reader
        -> 'g Core_kernel.Bin_prot.Read.reader
        -> 'h Core_kernel.Bin_prot.Read.reader
        -> 'i Core_kernel.Bin_prot.Read.reader
        -> 'j Core_kernel.Bin_prot.Read.reader
        -> 'k Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> Index.t
        -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t

      val bin_size_t :
           'a Core_kernel.Bin_prot.Size.sizer
        -> 'b Core_kernel.Bin_prot.Size.sizer
        -> 'c Core_kernel.Bin_prot.Size.sizer
        -> 'd Core_kernel.Bin_prot.Size.sizer
        -> 'e Core_kernel.Bin_prot.Size.sizer
        -> 'f Core_kernel.Bin_prot.Size.sizer
        -> 'g Core_kernel.Bin_prot.Size.sizer
        -> 'h Core_kernel.Bin_prot.Size.sizer
        -> 'i Core_kernel.Bin_prot.Size.sizer
        -> 'j Core_kernel.Bin_prot.Size.sizer
        -> 'k Core_kernel.Bin_prot.Size.sizer
        -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
        -> Index.t

      val bin_write_t :
           'a Core_kernel.Bin_prot.Write.writer
        -> 'b Core_kernel.Bin_prot.Write.writer
        -> 'c Core_kernel.Bin_prot.Write.writer
        -> 'd Core_kernel.Bin_prot.Write.writer
        -> 'e Core_kernel.Bin_prot.Write.writer
        -> 'f Core_kernel.Bin_prot.Write.writer
        -> 'g Core_kernel.Bin_prot.Write.writer
        -> 'h Core_kernel.Bin_prot.Write.writer
        -> 'i Core_kernel.Bin_prot.Write.writer
        -> 'j Core_kernel.Bin_prot.Write.writer
        -> 'k Core_kernel.Bin_prot.Write.writer
        -> Bin_prot.Common.buf
        -> pos:Bin_prot.Common.pos
        -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
        -> Bin_prot.Common.pos

      val bin_shape_t :
           Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t

      val bin_reader_t :
           'a Core_kernel.Bin_prot.Type_class.reader
        -> 'b Core_kernel.Bin_prot.Type_class.reader
        -> 'c Core_kernel.Bin_prot.Type_class.reader
        -> 'd Core_kernel.Bin_prot.Type_class.reader
        -> 'e Core_kernel.Bin_prot.Type_class.reader
        -> 'f Core_kernel.Bin_prot.Type_class.reader
        -> 'g Core_kernel.Bin_prot.Type_class.reader
        -> 'h Core_kernel.Bin_prot.Type_class.reader
        -> 'i Core_kernel.Bin_prot.Type_class.reader
        -> 'j Core_kernel.Bin_prot.Type_class.reader
        -> 'k Core_kernel.Bin_prot.Type_class.reader
        -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
           Core_kernel.Bin_prot.Type_class.reader

      val bin_writer_t :
           'a Core_kernel.Bin_prot.Type_class.writer
        -> 'b Core_kernel.Bin_prot.Type_class.writer
        -> 'c Core_kernel.Bin_prot.Type_class.writer
        -> 'd Core_kernel.Bin_prot.Type_class.writer
        -> 'e Core_kernel.Bin_prot.Type_class.writer
        -> 'f Core_kernel.Bin_prot.Type_class.writer
        -> 'g Core_kernel.Bin_prot.Type_class.writer
        -> 'h Core_kernel.Bin_prot.Type_class.writer
        -> 'i Core_kernel.Bin_prot.Type_class.writer
        -> 'j Core_kernel.Bin_prot.Type_class.writer
        -> 'k Core_kernel.Bin_prot.Type_class.writer
        -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
           Core_kernel.Bin_prot.Type_class.writer

      val bin_t :
           'a Core_kernel.Bin_prot.Type_class.t
        -> 'b Core_kernel.Bin_prot.Type_class.t
        -> 'c Core_kernel.Bin_prot.Type_class.t
        -> 'd Core_kernel.Bin_prot.Type_class.t
        -> 'e Core_kernel.Bin_prot.Type_class.t
        -> 'f Core_kernel.Bin_prot.Type_class.t
        -> 'g Core_kernel.Bin_prot.Type_class.t
        -> 'h Core_kernel.Bin_prot.Type_class.t
        -> 'i Core_kernel.Bin_prot.Type_class.t
        -> 'j Core_kernel.Bin_prot.Type_class.t
        -> 'k Core_kernel.Bin_prot.Type_class.t
        -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
           Core_kernel.Bin_prot.Type_class.t

      val __ :
        (   'a Core_kernel.Bin_prot.Read.reader
         -> 'b Core_kernel.Bin_prot.Read.reader
         -> 'c Core_kernel.Bin_prot.Read.reader
         -> 'd Core_kernel.Bin_prot.Read.reader
         -> 'e Core_kernel.Bin_prot.Read.reader
         -> 'f Core_kernel.Bin_prot.Read.reader
         -> 'g Core_kernel.Bin_prot.Read.reader
         -> 'h Core_kernel.Bin_prot.Read.reader
         -> 'i Core_kernel.Bin_prot.Read.reader
         -> 'j Core_kernel.Bin_prot.Read.reader
         -> 'k Core_kernel.Bin_prot.Read.reader
         -> Bin_prot.Common.buf
         -> pos_ref:Bin_prot.Common.pos_ref
         -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t)
        * (   'l Core_kernel.Bin_prot.Read.reader
           -> 'm Core_kernel.Bin_prot.Read.reader
           -> 'n Core_kernel.Bin_prot.Read.reader
           -> 'o Core_kernel.Bin_prot.Read.reader
           -> 'p Core_kernel.Bin_prot.Read.reader
           -> 'q Core_kernel.Bin_prot.Read.reader
           -> 'r Core_kernel.Bin_prot.Read.reader
           -> 's Core_kernel.Bin_prot.Read.reader
           -> 't Core_kernel.Bin_prot.Read.reader
           -> 'u Core_kernel.Bin_prot.Read.reader
           -> 'v Core_kernel.Bin_prot.Read.reader
           -> Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> Index.t
           -> ('l, 'm, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v) t)
        * (   'w Core_kernel.Bin_prot.Size.sizer
           -> 'x Core_kernel.Bin_prot.Size.sizer
           -> 'y Core_kernel.Bin_prot.Size.sizer
           -> 'z Core_kernel.Bin_prot.Size.sizer
           -> 'a1 Core_kernel.Bin_prot.Size.sizer
           -> 'b1 Core_kernel.Bin_prot.Size.sizer
           -> 'c1 Core_kernel.Bin_prot.Size.sizer
           -> 'd1 Core_kernel.Bin_prot.Size.sizer
           -> 'e1 Core_kernel.Bin_prot.Size.sizer
           -> 'f1 Core_kernel.Bin_prot.Size.sizer
           -> 'g1 Core_kernel.Bin_prot.Size.sizer
           -> ('w, 'x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1) t
           -> Index.t)
        * (   'h1 Core_kernel.Bin_prot.Write.writer
           -> 'i1 Core_kernel.Bin_prot.Write.writer
           -> 'j1 Core_kernel.Bin_prot.Write.writer
           -> 'k1 Core_kernel.Bin_prot.Write.writer
           -> 'l1 Core_kernel.Bin_prot.Write.writer
           -> 'm1 Core_kernel.Bin_prot.Write.writer
           -> 'n1 Core_kernel.Bin_prot.Write.writer
           -> 'o1 Core_kernel.Bin_prot.Write.writer
           -> 'p1 Core_kernel.Bin_prot.Write.writer
           -> 'q1 Core_kernel.Bin_prot.Write.writer
           -> 'r1 Core_kernel.Bin_prot.Write.writer
           -> Bin_prot.Common.buf
           -> pos:Bin_prot.Common.pos
           -> ('h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1) t
           -> Bin_prot.Common.pos)
        * (   Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t)
        * (   's1 Core_kernel.Bin_prot.Type_class.reader
           -> 't1 Core_kernel.Bin_prot.Type_class.reader
           -> 'u1 Core_kernel.Bin_prot.Type_class.reader
           -> 'v1 Core_kernel.Bin_prot.Type_class.reader
           -> 'w1 Core_kernel.Bin_prot.Type_class.reader
           -> 'x1 Core_kernel.Bin_prot.Type_class.reader
           -> 'y1 Core_kernel.Bin_prot.Type_class.reader
           -> 'z1 Core_kernel.Bin_prot.Type_class.reader
           -> 'a2 Core_kernel.Bin_prot.Type_class.reader
           -> 'b2 Core_kernel.Bin_prot.Type_class.reader
           -> 'c2 Core_kernel.Bin_prot.Type_class.reader
           -> ('s1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2) t
              Core_kernel.Bin_prot.Type_class.reader)
        * (   'd2 Core_kernel.Bin_prot.Type_class.writer
           -> 'e2 Core_kernel.Bin_prot.Type_class.writer
           -> 'f2 Core_kernel.Bin_prot.Type_class.writer
           -> 'g2 Core_kernel.Bin_prot.Type_class.writer
           -> 'h2 Core_kernel.Bin_prot.Type_class.writer
           -> 'i2 Core_kernel.Bin_prot.Type_class.writer
           -> 'j2 Core_kernel.Bin_prot.Type_class.writer
           -> 'k2 Core_kernel.Bin_prot.Type_class.writer
           -> 'l2 Core_kernel.Bin_prot.Type_class.writer
           -> 'm2 Core_kernel.Bin_prot.Type_class.writer
           -> 'n2 Core_kernel.Bin_prot.Type_class.writer
           -> ('d2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2) t
              Core_kernel.Bin_prot.Type_class.writer)
        * (   'o2 Core_kernel.Bin_prot.Type_class.t
           -> 'p2 Core_kernel.Bin_prot.Type_class.t
           -> 'q2 Core_kernel.Bin_prot.Type_class.t
           -> 'r2 Core_kernel.Bin_prot.Type_class.t
           -> 's2 Core_kernel.Bin_prot.Type_class.t
           -> 't2 Core_kernel.Bin_prot.Type_class.t
           -> 'u2 Core_kernel.Bin_prot.Type_class.t
           -> 'v2 Core_kernel.Bin_prot.Type_class.t
           -> 'w2 Core_kernel.Bin_prot.Type_class.t
           -> 'x2 Core_kernel.Bin_prot.Type_class.t
           -> 'y2 Core_kernel.Bin_prot.Type_class.t
           -> ('o2, 'p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2) t
              Core_kernel.Bin_prot.Type_class.t)
    end

    module Latest = V1
  end

  type ( 'pk
       , 'tid
       , 'token_permissions
       , 'amount
       , 'nonce
       , 'receipt_chain_hash
       , 'delegate
       , 'state_hash
       , 'timing
       , 'permissions
       , 'snapp_opt )
       t =
        ( 'pk
        , 'tid
        , 'token_permissions
        , 'amount
        , 'nonce
        , 'receipt_chain_hash
        , 'delegate
        , 'state_hash
        , 'timing
        , 'permissions
        , 'snapp_opt )
        Stable.V1.t =
    { public_key : 'pk
    ; token_id : 'tid
    ; token_permissions : 'token_permissions
    ; balance : 'amount
    ; nonce : 'nonce
    ; receipt_chain_hash : 'receipt_chain_hash
    ; delegate : 'delegate
    ; voting_for : 'state_hash
    ; timing : 'timing
    ; permissions : 'permissions
    ; snapp : 'snapp_opt
    }

  val to_yojson :
       ('pk -> Yojson.Safe.t)
    -> ('tid -> Yojson.Safe.t)
    -> ('token_permissions -> Yojson.Safe.t)
    -> ('amount -> Yojson.Safe.t)
    -> ('nonce -> Yojson.Safe.t)
    -> ('receipt_chain_hash -> Yojson.Safe.t)
    -> ('delegate -> Yojson.Safe.t)
    -> ('state_hash -> Yojson.Safe.t)
    -> ('timing -> Yojson.Safe.t)
    -> ('permissions -> Yojson.Safe.t)
    -> ('snapp_opt -> Yojson.Safe.t)
    -> ( 'pk
       , 'tid
       , 'token_permissions
       , 'amount
       , 'nonce
       , 'receipt_chain_hash
       , 'delegate
       , 'state_hash
       , 'timing
       , 'permissions
       , 'snapp_opt )
       t
    -> Yojson.Safe.t

  val of_yojson :
       (Yojson.Safe.t -> 'pk Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'tid Ppx_deriving_yojson_runtime.error_or)
    -> (   Yojson.Safe.t
        -> 'token_permissions Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'amount Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'nonce Ppx_deriving_yojson_runtime.error_or)
    -> (   Yojson.Safe.t
        -> 'receipt_chain_hash Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'delegate Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'state_hash Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'timing Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'permissions Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'snapp_opt Ppx_deriving_yojson_runtime.error_or)
    -> Yojson.Safe.t
    -> ( 'pk
       , 'tid
       , 'token_permissions
       , 'amount
       , 'nonce
       , 'receipt_chain_hash
       , 'delegate
       , 'state_hash
       , 'timing
       , 'permissions
       , 'snapp_opt )
       t
       Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp :
       (Ppx_sexp_conv_lib.Sexp.t -> 'pk)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'tid)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'token_permissions)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'amount)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'nonce)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'receipt_chain_hash)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'delegate)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'state_hash)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'timing)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'permissions)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'snapp_opt)
    -> Ppx_sexp_conv_lib.Sexp.t
    -> ( 'pk
       , 'tid
       , 'token_permissions
       , 'amount
       , 'nonce
       , 'receipt_chain_hash
       , 'delegate
       , 'state_hash
       , 'timing
       , 'permissions
       , 'snapp_opt )
       t

  val sexp_of_t :
       ('pk -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('tid -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('token_permissions -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('amount -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('nonce -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('receipt_chain_hash -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('delegate -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('state_hash -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('timing -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('permissions -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('snapp_opt -> Ppx_sexp_conv_lib.Sexp.t)
    -> ( 'pk
       , 'tid
       , 'token_permissions
       , 'amount
       , 'nonce
       , 'receipt_chain_hash
       , 'delegate
       , 'state_hash
       , 'timing
       , 'permissions
       , 'snapp_opt )
       t
    -> Ppx_sexp_conv_lib.Sexp.t

  val equal :
       ('pk -> 'pk -> bool)
    -> ('tid -> 'tid -> bool)
    -> ('token_permissions -> 'token_permissions -> bool)
    -> ('amount -> 'amount -> bool)
    -> ('nonce -> 'nonce -> bool)
    -> ('receipt_chain_hash -> 'receipt_chain_hash -> bool)
    -> ('delegate -> 'delegate -> bool)
    -> ('state_hash -> 'state_hash -> bool)
    -> ('timing -> 'timing -> bool)
    -> ('permissions -> 'permissions -> bool)
    -> ('snapp_opt -> 'snapp_opt -> bool)
    -> ( 'pk
       , 'tid
       , 'token_permissions
       , 'amount
       , 'nonce
       , 'receipt_chain_hash
       , 'delegate
       , 'state_hash
       , 'timing
       , 'permissions
       , 'snapp_opt )
       t
    -> ( 'pk
       , 'tid
       , 'token_permissions
       , 'amount
       , 'nonce
       , 'receipt_chain_hash
       , 'delegate
       , 'state_hash
       , 'timing
       , 'permissions
       , 'snapp_opt )
       t
    -> bool

  val compare :
       ('pk -> 'pk -> Index.t)
    -> ('tid -> 'tid -> Index.t)
    -> ('token_permissions -> 'token_permissions -> Index.t)
    -> ('amount -> 'amount -> Index.t)
    -> ('nonce -> 'nonce -> Index.t)
    -> ('receipt_chain_hash -> 'receipt_chain_hash -> Index.t)
    -> ('delegate -> 'delegate -> Index.t)
    -> ('state_hash -> 'state_hash -> Index.t)
    -> ('timing -> 'timing -> Index.t)
    -> ('permissions -> 'permissions -> Index.t)
    -> ('snapp_opt -> 'snapp_opt -> Index.t)
    -> ( 'pk
       , 'tid
       , 'token_permissions
       , 'amount
       , 'nonce
       , 'receipt_chain_hash
       , 'delegate
       , 'state_hash
       , 'timing
       , 'permissions
       , 'snapp_opt )
       t
    -> ( 'pk
       , 'tid
       , 'token_permissions
       , 'amount
       , 'nonce
       , 'receipt_chain_hash
       , 'delegate
       , 'state_hash
       , 'timing
       , 'permissions
       , 'snapp_opt )
       t
    -> Index.t

  val hash_fold_t :
       (Ppx_hash_lib.Std.Hash.state -> 'pk -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'tid -> Ppx_hash_lib.Std.Hash.state)
    -> (   Ppx_hash_lib.Std.Hash.state
        -> 'token_permissions
        -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'amount -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'nonce -> Ppx_hash_lib.Std.Hash.state)
    -> (   Ppx_hash_lib.Std.Hash.state
        -> 'receipt_chain_hash
        -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'delegate -> Ppx_hash_lib.Std.Hash.state)
    -> (   Ppx_hash_lib.Std.Hash.state
        -> 'state_hash
        -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'timing -> Ppx_hash_lib.Std.Hash.state)
    -> (   Ppx_hash_lib.Std.Hash.state
        -> 'permissions
        -> Ppx_hash_lib.Std.Hash.state)
    -> (   Ppx_hash_lib.Std.Hash.state
        -> 'snapp_opt
        -> Ppx_hash_lib.Std.Hash.state)
    -> Ppx_hash_lib.Std.Hash.state
    -> ( 'pk
       , 'tid
       , 'token_permissions
       , 'amount
       , 'nonce
       , 'receipt_chain_hash
       , 'delegate
       , 'state_hash
       , 'timing
       , 'permissions
       , 'snapp_opt )
       t
    -> Ppx_hash_lib.Std.Hash.state

  val snapp : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'k

  val permissions : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'j

  val timing : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'i

  val voting_for : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'h

  val delegate : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'g

  val receipt_chain_hash : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'f

  val nonce : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'e

  val balance : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'd

  val token_permissions : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'c

  val token_id : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'b

  val public_key : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t -> 'a

  module Fields : sig
    val names : string list

    val snapp :
      ( [< `Read | `Set_and_create ]
      , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'snapp_opt) t
      , 'snapp_opt )
      Fieldslib.Field.t_with_perm

    val permissions :
      ( [< `Read | `Set_and_create ]
      , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'permissions, 'j) t
      , 'permissions )
      Fieldslib.Field.t_with_perm

    val timing :
      ( [< `Read | `Set_and_create ]
      , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'timing, 'i, 'j) t
      , 'timing )
      Fieldslib.Field.t_with_perm

    val voting_for :
      ( [< `Read | `Set_and_create ]
      , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'state_hash, 'h, 'i, 'j) t
      , 'state_hash )
      Fieldslib.Field.t_with_perm

    val delegate :
      ( [< `Read | `Set_and_create ]
      , ('a, 'b, 'c, 'd, 'e, 'f, 'delegate, 'g, 'h, 'i, 'j) t
      , 'delegate )
      Fieldslib.Field.t_with_perm

    val receipt_chain_hash :
      ( [< `Read | `Set_and_create ]
      , ('a, 'b, 'c, 'd, 'e, 'receipt_chain_hash, 'f, 'g, 'h, 'i, 'j) t
      , 'receipt_chain_hash )
      Fieldslib.Field.t_with_perm

    val nonce :
      ( [< `Read | `Set_and_create ]
      , ('a, 'b, 'c, 'd, 'nonce, 'e, 'f, 'g, 'h, 'i, 'j) t
      , 'nonce )
      Fieldslib.Field.t_with_perm

    val balance :
      ( [< `Read | `Set_and_create ]
      , ('a, 'b, 'c, 'amount, 'd, 'e, 'f, 'g, 'h, 'i, 'j) t
      , 'amount )
      Fieldslib.Field.t_with_perm

    val token_permissions :
      ( [< `Read | `Set_and_create ]
      , ('a, 'b, 'token_permissions, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j) t
      , 'token_permissions )
      Fieldslib.Field.t_with_perm

    val token_id :
      ( [< `Read | `Set_and_create ]
      , ('a, 'tid, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j) t
      , 'tid )
      Fieldslib.Field.t_with_perm

    val public_key :
      ( [< `Read | `Set_and_create ]
      , ('pk, 'a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j) t
      , 'pk )
      Fieldslib.Field.t_with_perm

    val make_creator :
         public_key:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'l
            -> ('m -> 'n) * 'o)
      -> token_id:
           (   ( [< `Read | `Set_and_create ]
               , ('p, 'q, 'r, 's, 't, 'u, 'v, 'w, 'x, 'y, 'z) t
               , 'q )
               Fieldslib.Field.t_with_perm
            -> 'o
            -> ('m -> 'a1) * 'b1)
      -> token_permissions:
           (   ( [< `Read | `Set_and_create ]
               , ('c1, 'd1, 'e1, 'f1, 'g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1) t
               , 'e1 )
               Fieldslib.Field.t_with_perm
            -> 'b1
            -> ('m -> 'n1) * 'o1)
      -> balance:
           (   ( [< `Read | `Set_and_create ]
               , ('p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1) t
               , 's1 )
               Fieldslib.Field.t_with_perm
            -> 'o1
            -> ('m -> 'a2) * 'b2)
      -> nonce:
           (   ( [< `Read | `Set_and_create ]
               , ('c2, 'd2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2) t
               , 'g2 )
               Fieldslib.Field.t_with_perm
            -> 'b2
            -> ('m -> 'n2) * 'o2)
      -> receipt_chain_hash:
           (   ( [< `Read | `Set_and_create ]
               , ('p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2, 'z2) t
               , 'u2 )
               Fieldslib.Field.t_with_perm
            -> 'o2
            -> ('m -> 'a3) * 'b3)
      -> delegate:
           (   ( [< `Read | `Set_and_create ]
               , ('c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3, 'k3, 'l3, 'm3) t
               , 'i3 )
               Fieldslib.Field.t_with_perm
            -> 'b3
            -> ('m -> 'n3) * 'o3)
      -> voting_for:
           (   ( [< `Read | `Set_and_create ]
               , ('p3, 'q3, 'r3, 's3, 't3, 'u3, 'v3, 'w3, 'x3, 'y3, 'z3) t
               , 'w3 )
               Fieldslib.Field.t_with_perm
            -> 'o3
            -> ('m -> 'a4) * 'b4)
      -> timing:
           (   ( [< `Read | `Set_and_create ]
               , ('c4, 'd4, 'e4, 'f4, 'g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4) t
               , 'k4 )
               Fieldslib.Field.t_with_perm
            -> 'b4
            -> ('m -> 'n4) * 'o4)
      -> permissions:
           (   ( [< `Read | `Set_and_create ]
               , ('p4, 'q4, 'r4, 's4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4) t
               , 'y4 )
               Fieldslib.Field.t_with_perm
            -> 'o4
            -> ('m -> 'a5) * 'b5)
      -> snapp:
           (   ( [< `Read | `Set_and_create ]
               , ('c5, 'd5, 'e5, 'f5, 'g5, 'h5, 'i5, 'j5, 'k5, 'l5, 'm5) t
               , 'm5 )
               Fieldslib.Field.t_with_perm
            -> 'b5
            -> ('m -> 'n5) * 'o5)
      -> 'l
      -> ('m -> ('n, 'a1, 'n1, 'a2, 'n2, 'a3, 'n3, 'a4, 'n4, 'a5, 'n5) t) * 'o5

    val create :
         public_key:'a
      -> token_id:'b
      -> token_permissions:'c
      -> balance:'d
      -> nonce:'e
      -> receipt_chain_hash:'f
      -> delegate:'g
      -> voting_for:'h
      -> timing:'i
      -> permissions:'j
      -> snapp:'k
      -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t

    val map :
         public_key:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'l)
      -> token_id:
           (   ( [< `Read | `Set_and_create ]
               , ('m, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v, 'w) t
               , 'n )
               Fieldslib.Field.t_with_perm
            -> 'x)
      -> token_permissions:
           (   ( [< `Read | `Set_and_create ]
               , ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1, 'i1) t
               , 'a1 )
               Fieldslib.Field.t_with_perm
            -> 'j1)
      -> balance:
           (   ( [< `Read | `Set_and_create ]
               , ('k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1) t
               , 'n1 )
               Fieldslib.Field.t_with_perm
            -> 'v1)
      -> nonce:
           (   ( [< `Read | `Set_and_create ]
               , ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2, 'e2, 'f2, 'g2) t
               , 'a2 )
               Fieldslib.Field.t_with_perm
            -> 'h2)
      -> receipt_chain_hash:
           (   ( [< `Read | `Set_and_create ]
               , ('i2, 'j2, 'k2, 'l2, 'm2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2) t
               , 'n2 )
               Fieldslib.Field.t_with_perm
            -> 't2)
      -> delegate:
           (   ( [< `Read | `Set_and_create ]
               , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3, 'c3, 'd3, 'e3) t
               , 'a3 )
               Fieldslib.Field.t_with_perm
            -> 'f3)
      -> voting_for:
           (   ( [< `Read | `Set_and_create ]
               , ('g3, 'h3, 'i3, 'j3, 'k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3) t
               , 'n3 )
               Fieldslib.Field.t_with_perm
            -> 'r3)
      -> timing:
           (   ( [< `Read | `Set_and_create ]
               , ('s3, 't3, 'u3, 'v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4) t
               , 'a4 )
               Fieldslib.Field.t_with_perm
            -> 'd4)
      -> permissions:
           (   ( [< `Read | `Set_and_create ]
               , ('e4, 'f4, 'g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4) t
               , 'n4 )
               Fieldslib.Field.t_with_perm
            -> 'p4)
      -> snapp:
           (   ( [< `Read | `Set_and_create ]
               , ('q4, 'r4, 's4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4, 'a5) t
               , 'a5 )
               Fieldslib.Field.t_with_perm
            -> 'b5)
      -> ('l, 'x, 'j1, 'v1, 'h2, 't2, 'f3, 'r3, 'd4, 'p4, 'b5) t

    val iter :
         public_key:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> token_id:
           (   ( [< `Read | `Set_and_create ]
               , ('l, 'm, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v) t
               , 'm )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> token_permissions:
           (   ( [< `Read | `Set_and_create ]
               , ('w, 'x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1) t
               , 'y )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> balance:
           (   ( [< `Read | `Set_and_create ]
               , ('h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1) t
               , 'k1 )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> nonce:
           (   ( [< `Read | `Set_and_create ]
               , ('s1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2) t
               , 'w1 )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> receipt_chain_hash:
           (   ( [< `Read | `Set_and_create ]
               , ('d2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2) t
               , 'i2 )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> delegate:
           (   ( [< `Read | `Set_and_create ]
               , ('o2, 'p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2) t
               , 'u2 )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> voting_for:
           (   ( [< `Read | `Set_and_create ]
               , ('z2, 'a3, 'b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
               , 'g3 )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> timing:
           (   ( [< `Read | `Set_and_create ]
               , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3) t
               , 's3 )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> permissions:
           (   ( [< `Read | `Set_and_create ]
               , ('v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4, 'e4, 'f4) t
               , 'e4 )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> snapp:
           (   ( [< `Read | `Set_and_create ]
               , ('g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4, 'q4) t
               , 'q4 )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> unit

    val fold :
         init:'a
      -> public_key:
           (   'a
            -> ( [< `Read | `Set_and_create ]
               , ('b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k, 'l) t
               , 'b )
               Fieldslib.Field.t_with_perm
            -> 'm)
      -> token_id:
           (   'm
            -> ( [< `Read | `Set_and_create ]
               , ('n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v, 'w, 'x) t
               , 'o )
               Fieldslib.Field.t_with_perm
            -> 'y)
      -> token_permissions:
           (   'y
            -> ( [< `Read | `Set_and_create ]
               , ('z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1, 'i1, 'j1) t
               , 'b1 )
               Fieldslib.Field.t_with_perm
            -> 'k1)
      -> balance:
           (   'k1
            -> ( [< `Read | `Set_and_create ]
               , ('l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1) t
               , 'o1 )
               Fieldslib.Field.t_with_perm
            -> 'w1)
      -> nonce:
           (   'w1
            -> ( [< `Read | `Set_and_create ]
               , ('x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2, 'e2, 'f2, 'g2, 'h2) t
               , 'b2 )
               Fieldslib.Field.t_with_perm
            -> 'i2)
      -> receipt_chain_hash:
           (   'i2
            -> ( [< `Read | `Set_and_create ]
               , ('j2, 'k2, 'l2, 'm2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2, 't2) t
               , 'o2 )
               Fieldslib.Field.t_with_perm
            -> 'u2)
      -> delegate:
           (   'u2
            -> ( [< `Read | `Set_and_create ]
               , ('v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3, 'c3, 'd3, 'e3, 'f3) t
               , 'b3 )
               Fieldslib.Field.t_with_perm
            -> 'g3)
      -> voting_for:
           (   'g3
            -> ( [< `Read | `Set_and_create ]
               , ('h3, 'i3, 'j3, 'k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3) t
               , 'o3 )
               Fieldslib.Field.t_with_perm
            -> 's3)
      -> timing:
           (   's3
            -> ( [< `Read | `Set_and_create ]
               , ('t3, 'u3, 'v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4) t
               , 'b4 )
               Fieldslib.Field.t_with_perm
            -> 'e4)
      -> permissions:
           (   'e4
            -> ( [< `Read | `Set_and_create ]
               , ('f4, 'g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4) t
               , 'o4 )
               Fieldslib.Field.t_with_perm
            -> 'q4)
      -> snapp:
           (   'q4
            -> ( [< `Read | `Set_and_create ]
               , ('r4, 's4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4, 'a5, 'b5) t
               , 'b5 )
               Fieldslib.Field.t_with_perm
            -> 'c5)
      -> 'c5

    val map_poly :
         ( [< `Read | `Set_and_create ]
         , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
         , 'l )
         Fieldslib.Field.user
      -> 'l list

    val for_all :
         public_key:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> token_id:
           (   ( [< `Read | `Set_and_create ]
               , ('l, 'm, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v) t
               , 'm )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> token_permissions:
           (   ( [< `Read | `Set_and_create ]
               , ('w, 'x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1) t
               , 'y )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> balance:
           (   ( [< `Read | `Set_and_create ]
               , ('h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1) t
               , 'k1 )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> nonce:
           (   ( [< `Read | `Set_and_create ]
               , ('s1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2) t
               , 'w1 )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> receipt_chain_hash:
           (   ( [< `Read | `Set_and_create ]
               , ('d2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2) t
               , 'i2 )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> delegate:
           (   ( [< `Read | `Set_and_create ]
               , ('o2, 'p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2) t
               , 'u2 )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> voting_for:
           (   ( [< `Read | `Set_and_create ]
               , ('z2, 'a3, 'b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
               , 'g3 )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> timing:
           (   ( [< `Read | `Set_and_create ]
               , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3) t
               , 's3 )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> permissions:
           (   ( [< `Read | `Set_and_create ]
               , ('v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4, 'e4, 'f4) t
               , 'e4 )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> snapp:
           (   ( [< `Read | `Set_and_create ]
               , ('g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4, 'q4) t
               , 'q4 )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val exists :
         public_key:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> token_id:
           (   ( [< `Read | `Set_and_create ]
               , ('l, 'm, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v) t
               , 'm )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> token_permissions:
           (   ( [< `Read | `Set_and_create ]
               , ('w, 'x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1) t
               , 'y )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> balance:
           (   ( [< `Read | `Set_and_create ]
               , ('h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1) t
               , 'k1 )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> nonce:
           (   ( [< `Read | `Set_and_create ]
               , ('s1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2) t
               , 'w1 )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> receipt_chain_hash:
           (   ( [< `Read | `Set_and_create ]
               , ('d2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2) t
               , 'i2 )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> delegate:
           (   ( [< `Read | `Set_and_create ]
               , ('o2, 'p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2) t
               , 'u2 )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> voting_for:
           (   ( [< `Read | `Set_and_create ]
               , ('z2, 'a3, 'b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
               , 'g3 )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> timing:
           (   ( [< `Read | `Set_and_create ]
               , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3) t
               , 's3 )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> permissions:
           (   ( [< `Read | `Set_and_create ]
               , ('v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4, 'e4, 'f4) t
               , 'e4 )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> snapp:
           (   ( [< `Read | `Set_and_create ]
               , ('g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4, 'q4) t
               , 'q4 )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val to_list :
         public_key:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'l)
      -> token_id:
           (   ( [< `Read | `Set_and_create ]
               , ('m, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v, 'w) t
               , 'n )
               Fieldslib.Field.t_with_perm
            -> 'l)
      -> token_permissions:
           (   ( [< `Read | `Set_and_create ]
               , ('x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1) t
               , 'z )
               Fieldslib.Field.t_with_perm
            -> 'l)
      -> balance:
           (   ( [< `Read | `Set_and_create ]
               , ('i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1, 's1) t
               , 'l1 )
               Fieldslib.Field.t_with_perm
            -> 'l)
      -> nonce:
           (   ( [< `Read | `Set_and_create ]
               , ('t1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
               , 'x1 )
               Fieldslib.Field.t_with_perm
            -> 'l)
      -> receipt_chain_hash:
           (   ( [< `Read | `Set_and_create ]
               , ('e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2, 'o2) t
               , 'j2 )
               Fieldslib.Field.t_with_perm
            -> 'l)
      -> delegate:
           (   ( [< `Read | `Set_and_create ]
               , ('p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2, 'z2) t
               , 'v2 )
               Fieldslib.Field.t_with_perm
            -> 'l)
      -> voting_for:
           (   ( [< `Read | `Set_and_create ]
               , ('a3, 'b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3, 'k3) t
               , 'h3 )
               Fieldslib.Field.t_with_perm
            -> 'l)
      -> timing:
           (   ( [< `Read | `Set_and_create ]
               , ('l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3, 'v3) t
               , 't3 )
               Fieldslib.Field.t_with_perm
            -> 'l)
      -> permissions:
           (   ( [< `Read | `Set_and_create ]
               , ('w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4, 'e4, 'f4, 'g4) t
               , 'f4 )
               Fieldslib.Field.t_with_perm
            -> 'l)
      -> snapp:
           (   ( [< `Read | `Set_and_create ]
               , ('h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4, 'q4, 'r4) t
               , 'r4 )
               Fieldslib.Field.t_with_perm
            -> 'l)
      -> 'l list

    module Direct : sig
      val iter :
           ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
        -> public_key:
             (   ( [< `Read | `Set_and_create ]
                 , ('l, 'm, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v) t
                 , 'l )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'a
              -> unit)
        -> token_id:
             (   ( [< `Read | `Set_and_create ]
                 , ('w, 'x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1) t
                 , 'x )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'b
              -> unit)
        -> token_permissions:
             (   ( [< `Read | `Set_and_create ]
                 , ('h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1) t
                 , 'j1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'c
              -> unit)
        -> balance:
             (   ( [< `Read | `Set_and_create ]
                 , ('s1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2) t
                 , 'v1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'd
              -> unit)
        -> nonce:
             (   ( [< `Read | `Set_and_create ]
                 , ('d2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2) t
                 , 'h2 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'e
              -> unit)
        -> receipt_chain_hash:
             (   ( [< `Read | `Set_and_create ]
                 , ('o2, 'p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2) t
                 , 't2 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'f
              -> unit)
        -> delegate:
             (   ( [< `Read | `Set_and_create ]
                 , ('z2, 'a3, 'b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                 , 'f3 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'g
              -> unit)
        -> voting_for:
             (   ( [< `Read | `Set_and_create ]
                 , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3) t
                 , 'r3 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'h
              -> unit)
        -> timing:
             (   ( [< `Read | `Set_and_create ]
                 , ('v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4, 'e4, 'f4) t
                 , 'd4 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'i
              -> unit)
        -> permissions:
             (   ( [< `Read | `Set_and_create ]
                 , ('g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4, 'q4) t
                 , 'p4 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'j
              -> unit)
        -> snapp:
             (   ( [< `Read | `Set_and_create ]
                 , ('r4, 's4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4, 'a5, 'b5) t
                 , 'b5 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'k
              -> 'c5)
        -> 'c5

      val fold :
           ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
        -> init:'l
        -> public_key:
             (   'l
              -> ( [< `Read | `Set_and_create ]
                 , ('m, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v, 'w) t
                 , 'm )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'a
              -> 'x)
        -> token_id:
             (   'x
              -> ( [< `Read | `Set_and_create ]
                 , ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1, 'i1) t
                 , 'z )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'b
              -> 'j1)
        -> token_permissions:
             (   'j1
              -> ( [< `Read | `Set_and_create ]
                 , ('k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1) t
                 , 'm1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'c
              -> 'v1)
        -> balance:
             (   'v1
              -> ( [< `Read | `Set_and_create ]
                 , ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2, 'e2, 'f2, 'g2) t
                 , 'z1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'd
              -> 'h2)
        -> nonce:
             (   'h2
              -> ( [< `Read | `Set_and_create ]
                 , ('i2, 'j2, 'k2, 'l2, 'm2, 'n2, 'o2, 'p2, 'q2, 'r2, 's2) t
                 , 'm2 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'e
              -> 't2)
        -> receipt_chain_hash:
             (   't2
              -> ( [< `Read | `Set_and_create ]
                 , ('u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3, 'c3, 'd3, 'e3) t
                 , 'z2 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'f
              -> 'f3)
        -> delegate:
             (   'f3
              -> ( [< `Read | `Set_and_create ]
                 , ('g3, 'h3, 'i3, 'j3, 'k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3) t
                 , 'm3 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'g
              -> 'r3)
        -> voting_for:
             (   'r3
              -> ( [< `Read | `Set_and_create ]
                 , ('s3, 't3, 'u3, 'v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4) t
                 , 'z3 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'h
              -> 'd4)
        -> timing:
             (   'd4
              -> ( [< `Read | `Set_and_create ]
                 , ('e4, 'f4, 'g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4) t
                 , 'm4 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'i
              -> 'p4)
        -> permissions:
             (   'p4
              -> ( [< `Read | `Set_and_create ]
                 , ('q4, 'r4, 's4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4, 'a5) t
                 , 'z4 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'j
              -> 'b5)
        -> snapp:
             (   'b5
              -> ( [< `Read | `Set_and_create ]
                 , ('c5, 'd5, 'e5, 'f5, 'g5, 'h5, 'i5, 'j5, 'k5, 'l5, 'm5) t
                 , 'm5 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'k
              -> 'n5)
        -> 'n5

      val for_all :
           ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
        -> public_key:
             (   ( [< `Read | `Set_and_create ]
                 , ('l, 'm, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v) t
                 , 'l )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'a
              -> bool)
        -> token_id:
             (   ( [< `Read | `Set_and_create ]
                 , ('w, 'x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1) t
                 , 'x )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'b
              -> bool)
        -> token_permissions:
             (   ( [< `Read | `Set_and_create ]
                 , ('h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1) t
                 , 'j1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'c
              -> bool)
        -> balance:
             (   ( [< `Read | `Set_and_create ]
                 , ('s1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2) t
                 , 'v1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'd
              -> bool)
        -> nonce:
             (   ( [< `Read | `Set_and_create ]
                 , ('d2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2) t
                 , 'h2 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'e
              -> bool)
        -> receipt_chain_hash:
             (   ( [< `Read | `Set_and_create ]
                 , ('o2, 'p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2) t
                 , 't2 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'f
              -> bool)
        -> delegate:
             (   ( [< `Read | `Set_and_create ]
                 , ('z2, 'a3, 'b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                 , 'f3 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'g
              -> bool)
        -> voting_for:
             (   ( [< `Read | `Set_and_create ]
                 , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3) t
                 , 'r3 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'h
              -> bool)
        -> timing:
             (   ( [< `Read | `Set_and_create ]
                 , ('v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4, 'e4, 'f4) t
                 , 'd4 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'i
              -> bool)
        -> permissions:
             (   ( [< `Read | `Set_and_create ]
                 , ('g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4, 'q4) t
                 , 'p4 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'j
              -> bool)
        -> snapp:
             (   ( [< `Read | `Set_and_create ]
                 , ('r4, 's4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4, 'a5, 'b5) t
                 , 'b5 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'k
              -> bool)
        -> bool

      val exists :
           ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
        -> public_key:
             (   ( [< `Read | `Set_and_create ]
                 , ('l, 'm, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v) t
                 , 'l )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'a
              -> bool)
        -> token_id:
             (   ( [< `Read | `Set_and_create ]
                 , ('w, 'x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1) t
                 , 'x )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'b
              -> bool)
        -> token_permissions:
             (   ( [< `Read | `Set_and_create ]
                 , ('h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1) t
                 , 'j1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'c
              -> bool)
        -> balance:
             (   ( [< `Read | `Set_and_create ]
                 , ('s1, 't1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2) t
                 , 'v1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'd
              -> bool)
        -> nonce:
             (   ( [< `Read | `Set_and_create ]
                 , ('d2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2) t
                 , 'h2 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'e
              -> bool)
        -> receipt_chain_hash:
             (   ( [< `Read | `Set_and_create ]
                 , ('o2, 'p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2) t
                 , 't2 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'f
              -> bool)
        -> delegate:
             (   ( [< `Read | `Set_and_create ]
                 , ('z2, 'a3, 'b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3) t
                 , 'f3 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'g
              -> bool)
        -> voting_for:
             (   ( [< `Read | `Set_and_create ]
                 , ('k3, 'l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3) t
                 , 'r3 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'h
              -> bool)
        -> timing:
             (   ( [< `Read | `Set_and_create ]
                 , ('v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4, 'e4, 'f4) t
                 , 'd4 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'i
              -> bool)
        -> permissions:
             (   ( [< `Read | `Set_and_create ]
                 , ('g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4, 'q4) t
                 , 'p4 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'j
              -> bool)
        -> snapp:
             (   ( [< `Read | `Set_and_create ]
                 , ('r4, 's4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4, 'a5, 'b5) t
                 , 'b5 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'k
              -> bool)
        -> bool

      val to_list :
           ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
        -> public_key:
             (   ( [< `Read | `Set_and_create ]
                 , ('l, 'm, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v) t
                 , 'l )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'a
              -> 'w)
        -> token_id:
             (   ( [< `Read | `Set_and_create ]
                 , ('x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1) t
                 , 'y )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'b
              -> 'w)
        -> token_permissions:
             (   ( [< `Read | `Set_and_create ]
                 , ('i1, 'j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1, 's1) t
                 , 'k1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'c
              -> 'w)
        -> balance:
             (   ( [< `Read | `Set_and_create ]
                 , ('t1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
                 , 'w1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'd
              -> 'w)
        -> nonce:
             (   ( [< `Read | `Set_and_create ]
                 , ('e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2, 'o2) t
                 , 'i2 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'e
              -> 'w)
        -> receipt_chain_hash:
             (   ( [< `Read | `Set_and_create ]
                 , ('p2, 'q2, 'r2, 's2, 't2, 'u2, 'v2, 'w2, 'x2, 'y2, 'z2) t
                 , 'u2 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'f
              -> 'w)
        -> delegate:
             (   ( [< `Read | `Set_and_create ]
                 , ('a3, 'b3, 'c3, 'd3, 'e3, 'f3, 'g3, 'h3, 'i3, 'j3, 'k3) t
                 , 'g3 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'g
              -> 'w)
        -> voting_for:
             (   ( [< `Read | `Set_and_create ]
                 , ('l3, 'm3, 'n3, 'o3, 'p3, 'q3, 'r3, 's3, 't3, 'u3, 'v3) t
                 , 's3 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'h
              -> 'w)
        -> timing:
             (   ( [< `Read | `Set_and_create ]
                 , ('w3, 'x3, 'y3, 'z3, 'a4, 'b4, 'c4, 'd4, 'e4, 'f4, 'g4) t
                 , 'e4 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'i
              -> 'w)
        -> permissions:
             (   ( [< `Read | `Set_and_create ]
                 , ('h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4, 'o4, 'p4, 'q4, 'r4) t
                 , 'q4 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'j
              -> 'w)
        -> snapp:
             (   ( [< `Read | `Set_and_create ]
                 , ('s4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4, 'a5, 'b5, 'c5) t
                 , 'c5 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'k
              -> 'w)
        -> 'w list

      val map :
           ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
        -> public_key:
             (   ( [< `Read | `Set_and_create ]
                 , ('l, 'm, 'n, 'o, 'p, 'q, 'r, 's, 't, 'u, 'v) t
                 , 'l )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'a
              -> 'w)
        -> token_id:
             (   ( [< `Read | `Set_and_create ]
                 , ('x, 'y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1) t
                 , 'y )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'b
              -> 'i1)
        -> token_permissions:
             (   ( [< `Read | `Set_and_create ]
                 , ('j1, 'k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1, 's1, 't1) t
                 , 'l1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'c
              -> 'u1)
        -> balance:
             (   ( [< `Read | `Set_and_create ]
                 , ('v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2, 'e2, 'f2) t
                 , 'y1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'd
              -> 'g2)
        -> nonce:
             (   ( [< `Read | `Set_and_create ]
                 , ('h2, 'i2, 'j2, 'k2, 'l2, 'm2, 'n2, 'o2, 'p2, 'q2, 'r2) t
                 , 'l2 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'e
              -> 's2)
        -> receipt_chain_hash:
             (   ( [< `Read | `Set_and_create ]
                 , ('t2, 'u2, 'v2, 'w2, 'x2, 'y2, 'z2, 'a3, 'b3, 'c3, 'd3) t
                 , 'y2 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'f
              -> 'e3)
        -> delegate:
             (   ( [< `Read | `Set_and_create ]
                 , ('f3, 'g3, 'h3, 'i3, 'j3, 'k3, 'l3, 'm3, 'n3, 'o3, 'p3) t
                 , 'l3 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'g
              -> 'q3)
        -> voting_for:
             (   ( [< `Read | `Set_and_create ]
                 , ('r3, 's3, 't3, 'u3, 'v3, 'w3, 'x3, 'y3, 'z3, 'a4, 'b4) t
                 , 'y3 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'h
              -> 'c4)
        -> timing:
             (   ( [< `Read | `Set_and_create ]
                 , ('d4, 'e4, 'f4, 'g4, 'h4, 'i4, 'j4, 'k4, 'l4, 'm4, 'n4) t
                 , 'l4 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'i
              -> 'o4)
        -> permissions:
             (   ( [< `Read | `Set_and_create ]
                 , ('p4, 'q4, 'r4, 's4, 't4, 'u4, 'v4, 'w4, 'x4, 'y4, 'z4) t
                 , 'y4 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'j
              -> 'a5)
        -> snapp:
             (   ( [< `Read | `Set_and_create ]
                 , ('b5, 'c5, 'd5, 'e5, 'f5, 'g5, 'h5, 'i5, 'j5, 'k5, 'l5) t
                 , 'l5 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) t
              -> 'k
              -> 'm5)
        -> ('w, 'i1, 'u1, 'g2, 's2, 'e3, 'q3, 'c4, 'o4, 'a5, 'm5) t

      val set_all_mutable_fields : 'a -> unit
    end
  end

  val to_hlist :
       ( 'pk
       , 'tid
       , 'token_permissions
       , 'amount
       , 'nonce
       , 'receipt_chain_hash
       , 'delegate
       , 'state_hash
       , 'timing
       , 'permissions
       , 'snapp_opt )
       t
    -> ( unit
       ,    'pk
         -> 'tid
         -> 'token_permissions
         -> 'amount
         -> 'nonce
         -> 'receipt_chain_hash
         -> 'delegate
         -> 'state_hash
         -> 'timing
         -> 'permissions
         -> 'snapp_opt
         -> unit )
       H_list.t

  val of_hlist :
       ( unit
       ,    'pk
         -> 'tid
         -> 'token_permissions
         -> 'amount
         -> 'nonce
         -> 'receipt_chain_hash
         -> 'delegate
         -> 'state_hash
         -> 'timing
         -> 'permissions
         -> 'snapp_opt
         -> unit )
       H_list.t
    -> ( 'pk
       , 'tid
       , 'token_permissions
       , 'amount
       , 'nonce
       , 'receipt_chain_hash
       , 'delegate
       , 'state_hash
       , 'timing
       , 'permissions
       , 'snapp_opt )
       t
end

module Key : sig
  module Stable : sig
    module V1 : sig
      type t = Import.Public_key.Compressed.Stable.V1.t

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val version : Index.t

      val __versioned__ : unit

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val equal : t -> t -> bool

      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

      val compare : t -> t -> Index.t

      val to_latest : 'a -> 'a

      module With_version : sig
        type typ = t

        val bin_shape_typ : Core_kernel.Bin_prot.Shape.t

        val bin_size_typ : typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ : typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ : typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ : (Index.t -> typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ : typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ : typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ : typ Core_kernel.Bin_prot.Type_class.t

        type t = { version : Index.t; t : typ }

        val bin_shape_t : Core_kernel.Bin_prot.Shape.t

        val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t : t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ : (Index.t -> t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t : t Core_kernel.Bin_prot.Read.reader

        val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

        val bin_t : t Core_kernel.Bin_prot.Type_class.t

        val create : typ -> t
      end

      val bin_read_t :
        Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t

      val __bin_read_t__ :
        Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> Index.t -> t

      val bin_size_t : t -> Index.t

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
        * (   Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> Index.t
           -> t)
        * (t -> Index.t)
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
      ( Index.t
      * (Core_kernel.Bigstring.t -> pos_ref:Index.t Core_kernel.ref -> V1.t) )
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

  type t = Stable.V1.t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val equal : t -> t -> bool

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val compare : t -> t -> Index.t
end

module Identifier = Account_id

type key = Key.t

val key_to_yojson : key -> Yojson.Safe.t

val key_of_yojson : Yojson.Safe.t -> key Ppx_deriving_yojson_runtime.error_or

val key_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> key

val sexp_of_key : key -> Ppx_sexp_conv_lib.Sexp.t

val equal_key : key -> key -> bool

val hash_fold_key :
  Ppx_hash_lib.Std.Hash.state -> key -> Ppx_hash_lib.Std.Hash.state

val hash_key : key -> Ppx_hash_lib.Std.Hash.hash_value

val compare_key : key -> key -> Index.t

module Timing = Account_timing

module Binable_arg : sig
  module Stable : sig
    module V1 : sig
      type t =
        ( key
        , Token_id.Stable.V1.t
        , Token_permissions.Stable.V1.t
        , Currency.Balance.Stable.V1.t
        , Mina_numbers.Account_nonce.Stable.V1.t
        , Receipt.Chain_hash.Stable.V1.t
        , key option
        , State_hash.Stable.V1.t
        , Account_timing.Stable.V1.t
        , Permissions.Stable.V1.t
        , Snapp_account.Stable.V1.t option )
        Poly.t

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val version : Index.t

      val __versioned__ : unit

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val equal : t -> t -> bool

      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

      val compare : t -> t -> Index.t

      val to_latest : 'a -> 'a

      val public_key : t -> key

      module With_version : sig
        type typ = t

        val bin_shape_typ : Core_kernel.Bin_prot.Shape.t

        val bin_size_typ : typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ : typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ : typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ : (Index.t -> typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ : typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ : typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ : typ Core_kernel.Bin_prot.Type_class.t

        type t = { version : Index.t; t : typ }

        val bin_shape_t : Core_kernel.Bin_prot.Shape.t

        val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t : t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ : (Index.t -> t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t : t Core_kernel.Bin_prot.Read.reader

        val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

        val bin_t : t Core_kernel.Bin_prot.Type_class.t

        val create : typ -> t
      end

      val bin_read_t :
        Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t

      val __bin_read_t__ :
        Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> Index.t -> t

      val bin_size_t : t -> Index.t

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
        * (   Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> Index.t
           -> t)
        * (t -> Index.t)
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
      ( Index.t
      * (Core_kernel.Bigstring.t -> pos_ref:Index.t Core_kernel.ref -> Latest.t)
      )
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

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val compare : t -> t -> Index.t
end

val check : 'a -> 'a

module Stable : sig
  module V1 : sig
    type t = Binable_arg.Stable.V1.t

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val version : Index.t

    val __versioned__ : unit

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

    val equal : t -> t -> bool

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

    val compare : t -> t -> Index.t

    val to_latest : 'a -> 'a

    val public_key : t -> key

    module With_version : sig
      type typ = t

      val bin_shape_typ : Core_kernel.Bin_prot.Shape.t

      val bin_size_typ : typ Core_kernel.Bin_prot.Size.sizer

      val bin_write_typ : typ Core_kernel.Bin_prot.Write.writer

      val bin_writer_typ : typ Core_kernel.Bin_prot.Type_class.writer

      val __bin_read_typ__ : (Index.t -> typ) Core_kernel.Bin_prot.Read.reader

      val bin_read_typ : typ Core_kernel.Bin_prot.Read.reader

      val bin_reader_typ : typ Core_kernel.Bin_prot.Type_class.reader

      val bin_typ : typ Core_kernel.Bin_prot.Type_class.t

      type t = { version : Index.t; t : typ }

      val bin_shape_t : Core_kernel.Bin_prot.Shape.t

      val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

      val bin_write_t : t Core_kernel.Bin_prot.Write.writer

      val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

      val __bin_read_t__ : (Index.t -> t) Core_kernel.Bin_prot.Read.reader

      val bin_read_t : t Core_kernel.Bin_prot.Read.reader

      val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

      val bin_t : t Core_kernel.Bin_prot.Type_class.t

      val create : typ -> t
    end

    val bin_read_t : Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t

    val __bin_read_t__ :
      Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> Index.t -> t

    val bin_size_t : t -> Index.t

    val bin_write_t :
      Bin_prot.Common.buf -> pos:Bin_prot.Common.pos -> t -> Bin_prot.Common.pos

    val bin_shape_t : Core_kernel.Bin_prot.Shape.t

    val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

    val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

    val bin_t : t Core_kernel.Bin_prot.Type_class.t

    val __ :
      (Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t)
      * (Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> Index.t -> t)
      * (t -> Index.t)
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
    ( Index.t
    * (Core_kernel.Bigstring.t -> pos_ref:Index.t Core_kernel.ref -> V1.t) )
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

type t = Stable.V1.t

val to_yojson : t -> Yojson.Safe.t

val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

val equal : t -> t -> bool

val hash_fold_t :
  Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

val compare : t -> t -> Index.t

val public_key : t -> key

val token : ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) Poly.t -> 'b

val identifier : t -> Account_id.t

type value =
  ( Import.Public_key.Compressed.t
  , Token_id.t
  , Token_permissions.t
  , Currency.Balance.t
  , Mina_numbers.Account_nonce.t
  , Receipt.Chain_hash.t
  , Import.Public_key.Compressed.t option
  , State_hash.t
  , Account_timing.t
  , Permissions.t
  , Snapp_account.t option )
  Poly.t

val value_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> value

val sexp_of_value : value -> Ppx_sexp_conv_lib.Sexp.t

val key_gen : Import.Public_key.Compressed.t Core_kernel.Quickcheck.Generator.t

val initialize : Account_id.t -> t

val hash_snapp_account_opt : Snapp_account.t option -> Random_oracle.Digest.t

val delegate_opt :
  Import.Public_key.Compressed.t option -> Import.Public_key.Compressed.t

val to_input : t -> (Snark_params.Tick.Field.t, bool) Random_oracle.Input.t

val crypto_hash_prefix : Snark_params.Tick.Field.t Random_oracle.State.t

val crypto_hash : t -> Random_oracle.Digest.t

type var =
  ( Import.Public_key.Compressed.var
  , Token_id.var
  , Token_permissions.var
  , Currency.Balance.var
  , Mina_numbers.Account_nonce.Checked.t
  , Receipt.Chain_hash.var
  , Import.Public_key.Compressed.var
  , State_hash.var
  , Account_timing.var
  , Permissions.Checked.t
  , Snark_params.Tick.Field.Var.t
    * Snapp_account.t option Snark_params.Tick.As_prover.Ref.t )
  Poly.t

val identifier_of_var : var -> Mina_base__Account_id.var

val typ : (var, value) Snark_params.Tick.Typ.t

val var_of_t :
     value
  -> ( Import.Public_key.Compressed.var
     , Token_id.var
     , Token_permissions.var
     , Currency.Balance.var
     , Mina_numbers.Account_nonce.Checked.var
     , Receipt.Chain_hash.var
     , Import.Public_key.Compressed.var
     , State_hash.var
     , Account_timing.var
     , Permissions.Checked.t
     , Snark_params.Tick.Field.Var.t )
     Poly.t

module Checked : sig
  module Unhashed : sig
    type t =
      ( Import.Public_key.Compressed.var
      , Token_id.var
      , Token_permissions.var
      , Currency.Balance.var
      , Mina_numbers.Account_nonce.Checked.t
      , Receipt.Chain_hash.var
      , Import.Public_key.Compressed.var
      , State_hash.var
      , Account_timing.var
      , Permissions.Checked.t
      , Snapp_account.Checked.t )
      Poly.t
  end

  val to_input :
       var
    -> ( ( Snark_params.Tick.Field.Var.t
         , Snark_params.Tick.Boolean.var )
         Random_oracle.Input.t
       , 'a )
       Snark_params.Tick.Checked.t

  val digest :
    var -> (Random_oracle.Checked.Digest.t, 'a) Snark_params.Tick.Checked.t

  val min_balance_at_slot :
       global_slot:Mina_numbers.Global_slot.Checked.t
    -> cliff_time:Mina_numbers.Global_slot.Checked.t
    -> cliff_amount:Currency.Amount.var
    -> vesting_period:Mina_numbers.Global_slot.Checked.t
    -> vesting_increment:Currency.Amount.var
    -> initial_minimum_balance:Currency.Balance.var
    -> ( Snark_params.Tick.Run.field Snarky_integer.Integer.t
       , 'a )
       Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val has_locked_tokens :
       global_slot:Mina_numbers.Global_slot.Checked.t
    -> var
    -> ( Snark_params.Tick.Boolean.var
       , 'a )
       Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
end

val digest : t -> Random_oracle.Digest.t

val empty :
  ( Import.Public_key.Compressed.t
  , Token_id.t
  , Token_permissions.t
  , Currency.Balance.Stable.Latest.t
  , Mina_numbers.Account_nonce.t
  , Receipt.Chain_hash.t
  , 'a option
  , State_hash.t
  , ('b, 'c, 'd) Account_timing.tt
  , Permissions.t
  , 'e option )
  Poly.t

val empty_digest : Random_oracle.Digest.t

val create :
     Account_id.t
  -> 'a
  -> ( Import.Public_key.Compressed.t
     , Token_id.t
     , Token_permissions.t
     , 'a
     , Mina_numbers.Account_nonce.t
     , Receipt.Chain_hash.t
     , Import.Public_key.Compressed.t option
     , State_hash.t
     , ('b, 'c, 'd) Account_timing.tt
     , Permissions.t
     , 'e option )
     Poly.t

val create_timed :
     Account_id.t
  -> 'a
  -> initial_minimum_balance:'b
  -> cliff_time:Mina_numbers.Global_slot.t
  -> cliff_amount:'c
  -> vesting_period:Mina_numbers.Global_slot.t
  -> vesting_increment:'c
  -> ( Import.Public_key.Compressed.t
     , Token_id.t
     , Token_permissions.t
     , 'a
     , Mina_numbers.Account_nonce.t
     , Receipt.Chain_hash.t
     , Import.Public_key.Compressed.t option
     , State_hash.t
     , (Mina_numbers.Global_slot.t, 'b, 'c) Account_timing.tt
     , Permissions.t
     , 'd option )
     Poly.t
     Core_kernel.Or_error.t

val create_time_locked :
     Account_id.t
  -> 'a
  -> initial_minimum_balance:'b
  -> cliff_time:Mina_numbers.Global_slot.t
  -> cliff_amount:'b
  -> ( Import.Public_key.Compressed.t
     , Token_id.t
     , Token_permissions.t
     , 'a
     , Mina_numbers.Account_nonce.t
     , Receipt.Chain_hash.t
     , Import.Public_key.Compressed.t option
     , State_hash.t
     , (Mina_numbers.Global_slot.t, 'b, 'b) Account_timing.tt
     , Permissions.t
     , 'c option )
     Poly.t
     Core_kernel.Or_error.t

val min_balance_at_slot :
     global_slot:Mina_numbers.Global_slot.t
  -> cliff_time:Mina_numbers.Global_slot.t
  -> cliff_amount:Currency.Amount.t
  -> vesting_period:Mina_numbers.Global_slot.t
  -> vesting_increment:Currency.Amount.Stable.Latest.t
  -> initial_minimum_balance:Currency.Balance.Stable.Latest.t
  -> Currency.Balance.Stable.Latest.t

val incremental_balance_between_slots :
     start_slot:Mina_numbers.Global_slot.t
  -> end_slot:Mina_numbers.Global_slot.t
  -> cliff_time:Mina_numbers.Global_slot.t
  -> cliff_amount:Currency.Amount.t
  -> vesting_period:Mina_numbers.Global_slot.t
  -> vesting_increment:Currency.Amount.Stable.Latest.t
  -> initial_minimum_balance:Currency.Balance.Stable.Latest.t
  -> Unsigned.UInt64.t

val has_locked_tokens : global_slot:Mina_numbers.Global_slot.t -> t -> bool

val gen :
  ( Import.Public_key.Compressed.t
  , Token_id.t
  , Token_permissions.t
  , Currency.Balance.Stable.Latest.t
  , Mina_numbers.Account_nonce.t
  , Receipt.Chain_hash.t
  , Import.Public_key.Compressed.t option
  , State_hash.t
  , ('a, 'b, 'c) Account_timing.tt
  , Permissions.t
  , 'd option )
  Poly.t
  Core_kernel__Quickcheck.Generator.t

val gen_timed :
  ( Import.Public_key.Compressed.t
  , Token_id.t
  , Token_permissions.t
  , Currency.Balance.Stable.Latest.t
  , Mina_numbers.Account_nonce.t
  , Receipt.Chain_hash.t
  , Import.Public_key.Compressed.t option
  , State_hash.t
  , ( Mina_numbers.Global_slot.t
    , Currency.Balance.Stable.Latest.t
    , Currency.Amount.Stable.Latest.t )
    Account_timing.tt
  , Permissions.t
  , 'a option )
  Poly.t
  Core_kernel.Or_error.t
  Core_kernel__Quickcheck.Generator.t
