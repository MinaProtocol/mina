open Core
open Signature_lib

module Location : Merkle_ledger.Location_intf.S

module Db :
  Merkle_ledger.Database_intf.S
    with module Location = Location
    with module Addr = Location.Addr
    with type root_hash := Ledger_hash.t
     and type hash := Ledger_hash.t
     and type account := Account.t
     and type key := Public_key.Compressed.t

module Mask :
  Merkle_mask.Masking_merkle_tree_intf.S
  with module Location = Location
  with module Addr = Location.Addr
   and module Attached.Addr = Location.Addr
  with type account := Account.t
   and type key := Public_key.Compressed.t
   and type hash := Ledger_hash.t
   and type location := Location.t
   and type parent := Db.t

module Maskable :
  Merkle_mask.Maskable_merkle_tree_intf.S
  with module Location = Location
  with module Addr = Location.Addr
  with type account := Account.t
   and type key := Public_key.Compressed.t
   and type hash := Ledger_hash.t
   and type root_hash := Ledger_hash.t
   and type unattached_mask := Mask.t
   and type attached_mask := Mask.Attached.t
   and type t := Db.t

module Any_ledger :
sig
  module type Base_intf =
    sig
      type index = int
      type t
      module Addr :
        sig
          type t = Location_at_depth.Addr.t
          val equal : t -> t -> bool
          val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
          val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
          val bin_t : t Bin_prot.Type_class.t
          val bin_read_t : t Bin_prot.Read.reader
          val __bin_read_t__ : (index -> t) Bin_prot.Read.reader
          val bin_reader_t : t Bin_prot.Type_class.reader
          val bin_size_t : t Bin_prot.Size.sizer
          val bin_write_t : t Bin_prot.Write.writer
          val bin_writer_t : t Bin_prot.Type_class.writer
          val bin_shape_t : Bin_prot.Shape.t
          module Stable :
            sig
              module V1 :
                sig
                  type nonrec t = t
                  val equal : t -> t -> bool
                  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
                  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
                  val bin_t : t Bin_prot.Type_class.t
                  val bin_read_t : t Bin_prot.Read.reader
                  val __bin_read_t__ : (index -> t) Bin_prot.Read.reader
                  val bin_reader_t : t Bin_prot.Type_class.reader
                  val bin_size_t : t Bin_prot.Size.sizer
                  val bin_write_t : t Bin_prot.Write.writer
                  val bin_writer_t : t Bin_prot.Type_class.writer
                  val bin_shape_t : Bin_prot.Shape.t
                  val hash_fold_t : Base.Hash.state -> t -> Base.Hash.state
                  val hash : t -> index
                  val compare : t -> t -> index
                end
            end
          val compare : t -> t -> index
          val hash_fold_t : Base.Hash.state -> t -> Base.Hash.state
          val hash : t -> index
          val hashable : t Hashtbl_intf.Hashable.t
          module Table :
            sig
              type key = t
              type ('a, 'b) hashtbl = ('a, 'b) Hashtbl_intf.Hashtbl.t
              type 'b t = (key, 'b) hashtbl
              val sexp_of_t :
                ('b -> Ppx_sexp_conv_lib.Sexp.t) ->
                'b t -> Ppx_sexp_conv_lib.Sexp.t
              type ('a, 'b) t_ = 'b t
              type 'a key_ = key
              val hashable : key Hashtbl_intf.Hashable.t
              val invariant :
                'a Base__Invariant_intf.t -> 'a t Base__Invariant_intf.t
              val create :
                (key, 'b, unit -> 'b t)
                Hashtbl_intf.create_options_without_hashable
              val of_alist :
                (key, 'b,
                 (key * 'b) sexp_list ->
                 [ `Duplicate_key of key | `Ok of 'b t ])
                Hashtbl_intf.create_options_without_hashable
              val of_alist_report_all_dups :
                (key, 'b,
                 (key * 'b) sexp_list ->
                 [ `Duplicate_keys of key sexp_list | `Ok of 'b t ])
                Hashtbl_intf.create_options_without_hashable
              val of_alist_or_error :
                (key, 'b, (key * 'b) sexp_list -> 'b t Base.Or_error.t)
                Hashtbl_intf.create_options_without_hashable
              val of_alist_exn :
                (key, 'b, (key * 'b) sexp_list -> 'b t)
                Hashtbl_intf.create_options_without_hashable
              val of_alist_multi :
                (key, 'b sexp_list, (key * 'b) sexp_list -> 'b sexp_list t)
                Hashtbl_intf.create_options_without_hashable
              val create_mapped :
                (key, 'b,
                 get_key:('r -> key) ->
                 get_data:('r -> 'b) ->
                 'r sexp_list ->
                 [ `Duplicate_keys of key sexp_list | `Ok of 'b t ])
                Hashtbl_intf.create_options_without_hashable
              val create_with_key :
                (key, 'r,
                 get_key:('r -> key) ->
                 'r sexp_list ->
                 [ `Duplicate_keys of key sexp_list | `Ok of 'r t ])
                Hashtbl_intf.create_options_without_hashable
              val create_with_key_or_error :
                (key, 'r,
                 get_key:('r -> key) -> 'r sexp_list -> 'r t Base.Or_error.t)
                Hashtbl_intf.create_options_without_hashable
              val create_with_key_exn :
                (key, 'r, get_key:('r -> key) -> 'r sexp_list -> 'r t)
                Hashtbl_intf.create_options_without_hashable
              val group :
                (key, 'b,
                 get_key:('r -> key) ->
                 get_data:('r -> 'b) ->
                 combine:('b -> 'b -> 'b) -> 'r sexp_list -> 'b t)
                Hashtbl_intf.create_options_without_hashable
              val sexp_of_key : 'a t -> key -> Ppx_sexp_conv_lib.Sexp.t
              val clear : 'a t -> unit
              val copy : 'b t -> 'b t
              val fold :
                'b t -> init:'c -> f:(key:key -> data:'b -> 'c -> 'c) -> 'c
              val iter_keys : 'a t -> f:(key -> unit) -> unit
              val iter : 'b t -> f:('b -> unit) -> unit
              val iteri : 'b t -> f:(key:key -> data:'b -> unit) -> unit
              val existsi : 'b t -> f:(key:key -> data:'b -> bool) -> bool
              val exists : 'b t -> f:('b -> bool) -> bool
              val for_alli : 'b t -> f:(key:key -> data:'b -> bool) -> bool
              val for_all : 'b t -> f:('b -> bool) -> bool
              val counti : 'b t -> f:(key:key -> data:'b -> bool) -> index
              val count : 'b t -> f:('b -> bool) -> index
              val length : 'a t -> index
              val is_empty : 'a t -> bool
              val mem : 'a t -> key -> bool
              val remove : 'a t -> key -> unit
              val set : 'b t -> key:key -> data:'b -> unit
              val add : 'b t -> key:key -> data:'b -> [ `Duplicate | `Ok ]
              val add_exn : 'b t -> key:key -> data:'b -> unit
              val change :
                'b t -> key -> f:('b sexp_option -> 'b sexp_option) -> unit
              val update : 'b t -> key -> f:('b sexp_option -> 'b) -> unit
              val map : 'b t -> f:('b -> 'c) -> 'c t
              val mapi : 'b t -> f:(key:key -> data:'b -> 'c) -> 'c t
              val filter_map : 'b t -> f:('b -> 'c sexp_option) -> 'c t
              val filter_mapi :
                'b t -> f:(key:key -> data:'b -> 'c sexp_option) -> 'c t
              val filter_keys : 'b t -> f:(key -> bool) -> 'b t
              val filter : 'b t -> f:('b -> bool) -> 'b t
              val filteri : 'b t -> f:(key:key -> data:'b -> bool) -> 'b t
              val partition_map :
                'b t -> f:('b -> [ `Fst of 'c | `Snd of 'd ]) -> 'c t * 'd t
              val partition_mapi :
                'b t ->
                f:(key:key -> data:'b -> [ `Fst of 'c | `Snd of 'd ]) ->
                'c t * 'd t
              val partition_tf : 'b t -> f:('b -> bool) -> 'b t * 'b t
              val partitioni_tf :
                'b t -> f:(key:key -> data:'b -> bool) -> 'b t * 'b t
              val find_or_add : 'b t -> key -> default:(unit -> 'b) -> 'b
              val findi_or_add : 'b t -> key -> default:(key -> 'b) -> 'b
              val find : 'b t -> key -> 'b sexp_option
              val find_exn : 'b t -> key -> 'b
              val find_and_call :
                'b t ->
                key -> if_found:('b -> 'c) -> if_not_found:(key -> 'c) -> 'c
              val findi_and_call :
                'b t ->
                key ->
                if_found:(key:key -> data:'b -> 'c) ->
                if_not_found:(key -> 'c) -> 'c
              val find_and_remove : 'b t -> key -> 'b sexp_option
              val merge :
                'a t ->
                'b t ->
                f:(key:key ->
                   [ `Both of 'a * 'b | `Left of 'a | `Right of 'b ] ->
                   'c sexp_option) ->
                'c t
              type 'a merge_into_action =
                'a Location_at_depth.Addr.Table.merge_into_action =
                  Remove
                | Set_to of 'a
              val merge_into :
                src:'a t ->
                dst:'b t ->
                f:(key:key -> 'a -> 'b sexp_option -> 'b merge_into_action) ->
                unit
              val keys : 'a t -> key sexp_list
              val data : 'b t -> 'b sexp_list
              val filter_keys_inplace : 'a t -> f:(key -> bool) -> unit
              val filter_inplace : 'b t -> f:('b -> bool) -> unit
              val filteri_inplace :
                'b t -> f:(key:key -> data:'b -> bool) -> unit
              val map_inplace : 'b t -> f:('b -> 'b) -> unit
              val mapi_inplace : 'b t -> f:(key:key -> data:'b -> 'b) -> unit
              val filter_map_inplace :
                'b t -> f:('b -> 'b sexp_option) -> unit
              val filter_mapi_inplace :
                'b t -> f:(key:key -> data:'b -> 'b sexp_option) -> unit
              val equal : 'b t -> 'b t -> ('b -> 'b -> bool) -> bool
              val similar : 'b1 t -> 'b2 t -> ('b1 -> 'b2 -> bool) -> bool
              val to_alist : 'b t -> (key * 'b) sexp_list
              val validate :
                name:(key -> string) ->
                'b Validate.check -> 'b t Validate.check
              val incr :
                ?by:index -> ?remove_if_zero:bool -> index t -> key -> unit
              val decr :
                ?by:index -> ?remove_if_zero:bool -> index t -> key -> unit
              val add_multi : 'b sexp_list t -> key:key -> data:'b -> unit
              val remove_multi : 'a sexp_list t -> key -> unit
              val find_multi : 'b sexp_list t -> key -> 'b sexp_list
              module Provide_of_sexp :
                functor
                  (Key : sig
                           val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> key
                         end) ->
                  sig
                    val t_of_sexp :
                      (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__001_) ->
                      Ppx_sexp_conv_lib.Sexp.t -> 'v_x__001_ t
                  end
              module Provide_bin_io :
                functor
                  (Key : sig
                           val bin_t : key Bin_prot.Type_class.t
                           val bin_read_t : key Bin_prot.Read.reader
                           val __bin_read_t__ :
                             (index -> key) Bin_prot.Read.reader
                           val bin_reader_t : key Bin_prot.Type_class.reader
                           val bin_size_t : key Bin_prot.Size.sizer
                           val bin_write_t : key Bin_prot.Write.writer
                           val bin_writer_t : key Bin_prot.Type_class.writer
                           val bin_shape_t : Bin_prot.Shape.t
                         end) ->
                  sig
                    val bin_t :
                      'a Bin_prot.Type_class.t -> 'a t Bin_prot.Type_class.t
                    val bin_read_t :
                      'a Bin_prot.Read.reader -> 'a t Bin_prot.Read.reader
                    val __bin_read_t__ :
                      'a Bin_prot.Read.reader ->
                      (index -> 'a t) Bin_prot.Read.reader
                    val bin_reader_t :
                      'a Bin_prot.Type_class.reader ->
                      'a t Bin_prot.Type_class.reader
                    val bin_size_t :
                      'a Bin_prot.Size.sizer -> 'a t Bin_prot.Size.sizer
                    val bin_write_t :
                      'a Bin_prot.Write.writer -> 'a t Bin_prot.Write.writer
                    val bin_writer_t :
                      'a Bin_prot.Type_class.writer ->
                      'a t Bin_prot.Type_class.writer
                    val bin_shape_t : Bin_prot.Shape.t -> Bin_prot.Shape.t
                  end
              val t_of_sexp :
                (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_) ->
                Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_ t
            end
          module Hash_set :
            sig
              type elt = t
              type t = elt Hash_set.t
              val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
              type 'a t_ = t
              type 'a elt_ = elt
              val create :
                ('a, unit -> t)
                Base.Hash_set.create_options_without_first_class_module
              val of_list :
                ('a, elt sexp_list -> t)
                Base.Hash_set.create_options_without_first_class_module
              module Provide_of_sexp :
                functor
                  (X : sig
                         val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> elt
                       end) ->
                  sig val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t end
              module Provide_bin_io :
                functor
                  (X : sig
                         val bin_t : elt Bin_prot.Type_class.t
                         val bin_read_t : elt Bin_prot.Read.reader
                         val __bin_read_t__ :
                           (index -> elt) Bin_prot.Read.reader
                         val bin_reader_t : elt Bin_prot.Type_class.reader
                         val bin_size_t : elt Bin_prot.Size.sizer
                         val bin_write_t : elt Bin_prot.Write.writer
                         val bin_writer_t : elt Bin_prot.Type_class.writer
                         val bin_shape_t : Bin_prot.Shape.t
                       end) ->
                  sig
                    val bin_t : t Bin_prot.Type_class.t
                    val bin_read_t : t Bin_prot.Read.reader
                    val __bin_read_t__ : (index -> t) Bin_prot.Read.reader
                    val bin_reader_t : t Bin_prot.Type_class.reader
                    val bin_size_t : t Bin_prot.Size.sizer
                    val bin_write_t : t Bin_prot.Write.writer
                    val bin_writer_t : t Bin_prot.Type_class.writer
                    val bin_shape_t : Bin_prot.Shape.t
                  end
              val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
            end
          module Hash_queue :
            sig
              module Key :
                sig
                  type t = Hash_set.elt
                  val compare : t -> t -> index
                  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
                  val hash : t -> index
                end
              type 'a t = 'a Location_at_depth.Addr.Hash_queue.t
              val sexp_of_t :
                ('a -> Ppx_sexp_conv_lib.Sexp.t) ->
                'a t -> Ppx_sexp_conv_lib.Sexp.t
              val length : 'a t -> index
              val is_empty : 'a t -> bool
              val iter : 'a t -> f:('a -> unit) -> unit
              val fold :
                'a t -> init:'accum -> f:('accum -> 'a -> 'accum) -> 'accum
              val fold_result :
                'a t ->
                init:'accum ->
                f:('accum -> 'a -> ('accum, 'e) result) ->
                ('accum, 'e) result
              val fold_until :
                'a t ->
                init:'accum ->
                f:('accum -> 'a -> ('accum, 'final) Base.Continue_or_stop.t) ->
                finish:('accum -> 'final) -> 'final
              val exists : 'a t -> f:('a -> bool) -> bool
              val for_all : 'a t -> f:('a -> bool) -> bool
              val count : 'a t -> f:('a -> bool) -> index
              val sum :
                (module Commutative_group.S with type t = 'sum) ->
                'a t -> f:('a -> 'sum) -> 'sum
              val find : 'a t -> f:('a -> bool) -> 'a sexp_option
              val find_map :
                'a t -> f:('a -> 'b sexp_option) -> 'b sexp_option
              val to_list : 'a t -> 'a sexp_list
              val to_array : 'a t -> 'a array
              val min_elt :
                'a t -> compare:('a -> 'a -> index) -> 'a sexp_option
              val max_elt :
                'a t -> compare:('a -> 'a -> index) -> 'a sexp_option
              val invariant : 'a t -> unit
              val create :
                ?growth_allowed:sexp_bool -> ?size:index -> unit -> 'a t
              val clear : 'a t -> unit
              val mem : 'a t -> Key.t -> sexp_bool
              val lookup : 'a t -> Key.t -> 'a sexp_option
              val lookup_exn : 'a t -> Key.t -> 'a
              val enqueue :
                'a t -> Key.t -> 'a -> [ `Key_already_present | `Ok ]
              val enqueue_exn : 'a t -> Key.t -> 'a -> unit
              val lookup_and_move_to_back : 'a t -> Key.t -> 'a sexp_option
              val lookup_and_move_to_back_exn : 'a t -> Key.t -> 'a
              val first : 'a t -> 'a sexp_option
              val first_with_key : 'a t -> (Key.t * 'a) sexp_option
              val keys : 'a t -> Key.t sexp_list
              val dequeue : 'a t -> 'a sexp_option
              val dequeue_exn : 'a t -> 'a
              val dequeue_with_key : 'a t -> (Key.t * 'a) sexp_option
              val dequeue_with_key_exn : 'a t -> Key.t * 'a
              val dequeue_all : 'a t -> f:('a -> unit) -> unit
              val remove : 'a t -> Key.t -> [ `No_such_key | `Ok ]
              val remove_exn : 'a t -> Key.t -> unit
              val replace : 'a t -> Key.t -> 'a -> [ `No_such_key | `Ok ]
              val replace_exn : 'a t -> Key.t -> 'a -> unit
              val iteri : 'a t -> f:(key:Key.t -> data:'a -> unit) -> unit
              val foldi :
                'a t -> init:'b -> f:('b -> key:Key.t -> data:'a -> 'b) -> 'b
            end
          val of_byte_string : string -> t
          val of_directions : Direction.t sexp_list -> t
          val root : unit -> t
          val slice : t -> index -> index -> t
          val get : t -> index -> index
          val copy : t -> t
          val parent : t -> t Or_error.t
          val child : t -> Direction.t -> t Or_error.t
          val child_exn : t -> Direction.t -> t
          val parent_exn : t -> t
          val dirs_from_root : t -> Direction.t sexp_list
          val sibling : t -> t
          val next : t -> t sexp_option
          val is_parent_of : t -> maybe_child:t -> bool
          val serialize : t -> Bigstring.t
          val to_string : t -> string
          val pp : Format.formatter -> t -> unit
          module Range :
            sig
              type nonrec t = t * t
              val fold :
                ?stop:[ `Exclusive | `Inclusive ] ->
                t -> init:'a -> f:(Hash_set.elt -> 'a -> 'a) -> 'a
              val subtree_range : Hash_set.elt -> t
            end
          val depth : t -> index
          val height : t -> index
          val to_int : t -> index
          val of_int_exn : index -> t
        end
      module Path :
        sig
          type elem = [ `Left of Ledger_hash.t | `Right of Ledger_hash.t ]
          val elem_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> elem
          val __elem_of_sexp__ : Ppx_sexp_conv_lib.Sexp.t -> elem
          val sexp_of_elem : elem -> Ppx_sexp_conv_lib.Sexp.t
          val elem_hash : elem -> Ledger_hash.t
          type t = elem sexp_list
          val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
          val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
          val implied_root : t -> Ledger_hash.t -> Ledger_hash.t
          val check_path : t -> Ledger_hash.t -> Ledger_hash.t -> bool
        end
      module Location :
        sig
          module Addr :
            sig
              type t = Addr.t
              val equal : t -> t -> bool
              val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
              val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
              val bin_t : t Bin_prot.Type_class.t
              val bin_read_t : t Bin_prot.Read.reader
              val __bin_read_t__ : (index -> t) Bin_prot.Read.reader
              val bin_reader_t : t Bin_prot.Type_class.reader
              val bin_size_t : t Bin_prot.Size.sizer
              val bin_write_t : t Bin_prot.Write.writer
              val bin_writer_t : t Bin_prot.Type_class.writer
              val bin_shape_t : Bin_prot.Shape.t
              module Stable :
                sig
                  module V1 :
                    sig
                      type nonrec t = t
                      val equal : t -> t -> bool
                      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
                      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
                      val bin_t : t Bin_prot.Type_class.t
                      val bin_read_t : t Bin_prot.Read.reader
                      val __bin_read_t__ : (index -> t) Bin_prot.Read.reader
                      val bin_reader_t : t Bin_prot.Type_class.reader
                      val bin_size_t : t Bin_prot.Size.sizer
                      val bin_write_t : t Bin_prot.Write.writer
                      val bin_writer_t : t Bin_prot.Type_class.writer
                      val bin_shape_t : Bin_prot.Shape.t
                      val hash_fold_t :
                        Base.Hash.state -> t -> Base.Hash.state
                      val hash : t -> index
                      val compare : t -> t -> index
                    end
                end
              val compare : t -> t -> index
              val hash_fold_t : Base.Hash.state -> t -> Base.Hash.state
              val hash : t -> index
              val hashable : t Hashtbl_intf.Hashable.t
              module Table :
                sig
                  type key = t
                  type ('a, 'b) hashtbl = ('a, 'b) Hashtbl_intf.Hashtbl.t
                  type 'b t = (key, 'b) hashtbl
                  val sexp_of_t :
                    ('b -> Ppx_sexp_conv_lib.Sexp.t) ->
                    'b t -> Ppx_sexp_conv_lib.Sexp.t
                  type ('a, 'b) t_ = 'b t
                  type 'a key_ = key
                  val hashable : key Hashtbl_intf.Hashable.t
                  val invariant :
                    'a Base__Invariant_intf.t -> 'a t Base__Invariant_intf.t
                  val create :
                    (key, 'b, unit -> 'b t)
                    Hashtbl_intf.create_options_without_hashable
                  val of_alist :
                    (key, 'b,
                     (key * 'b) sexp_list ->
                     [ `Duplicate_key of key | `Ok of 'b t ])
                    Hashtbl_intf.create_options_without_hashable
                  val of_alist_report_all_dups :
                    (key, 'b,
                     (key * 'b) sexp_list ->
                     [ `Duplicate_keys of key sexp_list | `Ok of 'b t ])
                    Hashtbl_intf.create_options_without_hashable
                  val of_alist_or_error :
                    (key, 'b, (key * 'b) sexp_list -> 'b t Base.Or_error.t)
                    Hashtbl_intf.create_options_without_hashable
                  val of_alist_exn :
                    (key, 'b, (key * 'b) sexp_list -> 'b t)
                    Hashtbl_intf.create_options_without_hashable
                  val of_alist_multi :
                    (key, 'b sexp_list,
                     (key * 'b) sexp_list -> 'b sexp_list t)
                    Hashtbl_intf.create_options_without_hashable
                  val create_mapped :
                    (key, 'b,
                     get_key:('r -> key) ->
                     get_data:('r -> 'b) ->
                     'r sexp_list ->
                     [ `Duplicate_keys of key sexp_list | `Ok of 'b t ])
                    Hashtbl_intf.create_options_without_hashable
                  val create_with_key :
                    (key, 'r,
                     get_key:('r -> key) ->
                     'r sexp_list ->
                     [ `Duplicate_keys of key sexp_list | `Ok of 'r t ])
                    Hashtbl_intf.create_options_without_hashable
                  val create_with_key_or_error :
                    (key, 'r,
                     get_key:('r -> key) ->
                     'r sexp_list -> 'r t Base.Or_error.t)
                    Hashtbl_intf.create_options_without_hashable
                  val create_with_key_exn :
                    (key, 'r, get_key:('r -> key) -> 'r sexp_list -> 'r t)
                    Hashtbl_intf.create_options_without_hashable
                  val group :
                    (key, 'b,
                     get_key:('r -> key) ->
                     get_data:('r -> 'b) ->
                     combine:('b -> 'b -> 'b) -> 'r sexp_list -> 'b t)
                    Hashtbl_intf.create_options_without_hashable
                  val sexp_of_key : 'a t -> key -> Ppx_sexp_conv_lib.Sexp.t
                  val clear : 'a t -> unit
                  val copy : 'b t -> 'b t
                  val fold :
                    'b t ->
                    init:'c -> f:(key:key -> data:'b -> 'c -> 'c) -> 'c
                  val iter_keys : 'a t -> f:(key -> unit) -> unit
                  val iter : 'b t -> f:('b -> unit) -> unit
                  val iteri : 'b t -> f:(key:key -> data:'b -> unit) -> unit
                  val existsi :
                    'b t -> f:(key:key -> data:'b -> bool) -> bool
                  val exists : 'b t -> f:('b -> bool) -> bool
                  val for_alli :
                    'b t -> f:(key:key -> data:'b -> bool) -> bool
                  val for_all : 'b t -> f:('b -> bool) -> bool
                  val counti :
                    'b t -> f:(key:key -> data:'b -> bool) -> index
                  val count : 'b t -> f:('b -> bool) -> index
                  val length : 'a t -> index
                  val is_empty : 'a t -> bool
                  val mem : 'a t -> key -> bool
                  val remove : 'a t -> key -> unit
                  val set : 'b t -> key:key -> data:'b -> unit
                  val add :
                    'b t -> key:key -> data:'b -> [ `Duplicate | `Ok ]
                  val add_exn : 'b t -> key:key -> data:'b -> unit
                  val change :
                    'b t ->
                    key -> f:('b sexp_option -> 'b sexp_option) -> unit
                  val update :
                    'b t -> key -> f:('b sexp_option -> 'b) -> unit
                  val map : 'b t -> f:('b -> 'c) -> 'c t
                  val mapi : 'b t -> f:(key:key -> data:'b -> 'c) -> 'c t
                  val filter_map : 'b t -> f:('b -> 'c sexp_option) -> 'c t
                  val filter_mapi :
                    'b t -> f:(key:key -> data:'b -> 'c sexp_option) -> 'c t
                  val filter_keys : 'b t -> f:(key -> bool) -> 'b t
                  val filter : 'b t -> f:('b -> bool) -> 'b t
                  val filteri :
                    'b t -> f:(key:key -> data:'b -> bool) -> 'b t
                  val partition_map :
                    'b t ->
                    f:('b -> [ `Fst of 'c | `Snd of 'd ]) -> 'c t * 'd t
                  val partition_mapi :
                    'b t ->
                    f:(key:key -> data:'b -> [ `Fst of 'c | `Snd of 'd ]) ->
                    'c t * 'd t
                  val partition_tf : 'b t -> f:('b -> bool) -> 'b t * 'b t
                  val partitioni_tf :
                    'b t -> f:(key:key -> data:'b -> bool) -> 'b t * 'b t
                  val find_or_add : 'b t -> key -> default:(unit -> 'b) -> 'b
                  val findi_or_add : 'b t -> key -> default:(key -> 'b) -> 'b
                  val find : 'b t -> key -> 'b sexp_option
                  val find_exn : 'b t -> key -> 'b
                  val find_and_call :
                    'b t ->
                    key ->
                    if_found:('b -> 'c) -> if_not_found:(key -> 'c) -> 'c
                  val findi_and_call :
                    'b t ->
                    key ->
                    if_found:(key:key -> data:'b -> 'c) ->
                    if_not_found:(key -> 'c) -> 'c
                  val find_and_remove : 'b t -> key -> 'b sexp_option
                  val merge :
                    'a t ->
                    'b t ->
                    f:(key:key ->
                       [ `Both of 'a * 'b | `Left of 'a | `Right of 'b ] ->
                       'c sexp_option) ->
                    'c t
                  type 'a merge_into_action =
                    'a Addr.Table.merge_into_action =
                      Remove
                    | Set_to of 'a
                  val merge_into :
                    src:'a t ->
                    dst:'b t ->
                    f:(key:key ->
                       'a -> 'b sexp_option -> 'b merge_into_action) ->
                    unit
                  val keys : 'a t -> key sexp_list
                  val data : 'b t -> 'b sexp_list
                  val filter_keys_inplace : 'a t -> f:(key -> bool) -> unit
                  val filter_inplace : 'b t -> f:('b -> bool) -> unit
                  val filteri_inplace :
                    'b t -> f:(key:key -> data:'b -> bool) -> unit
                  val map_inplace : 'b t -> f:('b -> 'b) -> unit
                  val mapi_inplace :
                    'b t -> f:(key:key -> data:'b -> 'b) -> unit
                  val filter_map_inplace :
                    'b t -> f:('b -> 'b sexp_option) -> unit
                  val filter_mapi_inplace :
                    'b t -> f:(key:key -> data:'b -> 'b sexp_option) -> unit
                  val equal : 'b t -> 'b t -> ('b -> 'b -> bool) -> bool
                  val similar :
                    'b1 t -> 'b2 t -> ('b1 -> 'b2 -> bool) -> bool
                  val to_alist : 'b t -> (key * 'b) sexp_list
                  val validate :
                    name:(key -> string) ->
                    'b Validate.check -> 'b t Validate.check
                  val incr :
                    ?by:index ->
                    ?remove_if_zero:bool -> index t -> key -> unit
                  val decr :
                    ?by:index ->
                    ?remove_if_zero:bool -> index t -> key -> unit
                  val add_multi :
                    'b sexp_list t -> key:key -> data:'b -> unit
                  val remove_multi : 'a sexp_list t -> key -> unit
                  val find_multi : 'b sexp_list t -> key -> 'b sexp_list
                  module Provide_of_sexp :
                    functor
                      (Key : sig
                               val t_of_sexp :
                                 Ppx_sexp_conv_lib.Sexp.t -> key
                             end) ->
                      sig
                        val t_of_sexp :
                          (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__001_) ->
                          Ppx_sexp_conv_lib.Sexp.t -> 'v_x__001_ t
                      end
                  module Provide_bin_io :
                    functor
                      (Key : sig
                               val bin_t : key Bin_prot.Type_class.t
                               val bin_read_t : key Bin_prot.Read.reader
                               val __bin_read_t__ :
                                 (index -> key) Bin_prot.Read.reader
                               val bin_reader_t :
                                 key Bin_prot.Type_class.reader
                               val bin_size_t : key Bin_prot.Size.sizer
                               val bin_write_t : key Bin_prot.Write.writer
                               val bin_writer_t :
                                 key Bin_prot.Type_class.writer
                               val bin_shape_t : Bin_prot.Shape.t
                             end) ->
                      sig
                        val bin_t :
                          'a Bin_prot.Type_class.t ->
                          'a t Bin_prot.Type_class.t
                        val bin_read_t :
                          'a Bin_prot.Read.reader ->
                          'a t Bin_prot.Read.reader
                        val __bin_read_t__ :
                          'a Bin_prot.Read.reader ->
                          (index -> 'a t) Bin_prot.Read.reader
                        val bin_reader_t :
                          'a Bin_prot.Type_class.reader ->
                          'a t Bin_prot.Type_class.reader
                        val bin_size_t :
                          'a Bin_prot.Size.sizer -> 'a t Bin_prot.Size.sizer
                        val bin_write_t :
                          'a Bin_prot.Write.writer ->
                          'a t Bin_prot.Write.writer
                        val bin_writer_t :
                          'a Bin_prot.Type_class.writer ->
                          'a t Bin_prot.Type_class.writer
                        val bin_shape_t :
                          Bin_prot.Shape.t -> Bin_prot.Shape.t
                      end
                  val t_of_sexp :
                    (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_) ->
                    Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_ t
                end
              module Hash_set :
                sig
                  type elt = t
                  type t = elt Hash_set.t
                  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
                  type 'a t_ = t
                  type 'a elt_ = elt
                  val create :
                    ('a, unit -> t)
                    Base.Hash_set.create_options_without_first_class_module
                  val of_list :
                    ('a, elt sexp_list -> t)
                    Base.Hash_set.create_options_without_first_class_module
                  module Provide_of_sexp :
                    functor
                      (X : sig
                             val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> elt
                           end) ->
                      sig val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t end
                  module Provide_bin_io :
                    functor
                      (X : sig
                             val bin_t : elt Bin_prot.Type_class.t
                             val bin_read_t : elt Bin_prot.Read.reader
                             val __bin_read_t__ :
                               (index -> elt) Bin_prot.Read.reader
                             val bin_reader_t :
                               elt Bin_prot.Type_class.reader
                             val bin_size_t : elt Bin_prot.Size.sizer
                             val bin_write_t : elt Bin_prot.Write.writer
                             val bin_writer_t :
                               elt Bin_prot.Type_class.writer
                             val bin_shape_t : Bin_prot.Shape.t
                           end) ->
                      sig
                        val bin_t : t Bin_prot.Type_class.t
                        val bin_read_t : t Bin_prot.Read.reader
                        val __bin_read_t__ :
                          (index -> t) Bin_prot.Read.reader
                        val bin_reader_t : t Bin_prot.Type_class.reader
                        val bin_size_t : t Bin_prot.Size.sizer
                        val bin_write_t : t Bin_prot.Write.writer
                        val bin_writer_t : t Bin_prot.Type_class.writer
                        val bin_shape_t : Bin_prot.Shape.t
                      end
                  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
                end
              module Hash_queue :
                sig
                  module Key :
                    sig
                      type t = Hash_set.elt
                      val compare : t -> t -> index
                      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
                      val hash : t -> index
                    end
                  type 'a t = 'a Addr.Hash_queue.t
                  val sexp_of_t :
                    ('a -> Ppx_sexp_conv_lib.Sexp.t) ->
                    'a t -> Ppx_sexp_conv_lib.Sexp.t
                  val length : 'a t -> index
                  val is_empty : 'a t -> bool
                  val iter : 'a t -> f:('a -> unit) -> unit
                  val fold :
                    'a t ->
                    init:'accum -> f:('accum -> 'a -> 'accum) -> 'accum
                  val fold_result :
                    'a t ->
                    init:'accum ->
                    f:('accum -> 'a -> ('accum, 'e) result) ->
                    ('accum, 'e) result
                  val fold_until :
                    'a t ->
                    init:'accum ->
                    f:('accum ->
                       'a -> ('accum, 'final) Base.Continue_or_stop.t) ->
                    finish:('accum -> 'final) -> 'final
                  val exists : 'a t -> f:('a -> bool) -> bool
                  val for_all : 'a t -> f:('a -> bool) -> bool
                  val count : 'a t -> f:('a -> bool) -> index
                  val sum :
                    (module Commutative_group.S with type t = 'sum) ->
                    'a t -> f:('a -> 'sum) -> 'sum
                  val find : 'a t -> f:('a -> bool) -> 'a sexp_option
                  val find_map :
                    'a t -> f:('a -> 'b sexp_option) -> 'b sexp_option
                  val to_list : 'a t -> 'a sexp_list
                  val to_array : 'a t -> 'a array
                  val min_elt :
                    'a t -> compare:('a -> 'a -> index) -> 'a sexp_option
                  val max_elt :
                    'a t -> compare:('a -> 'a -> index) -> 'a sexp_option
                  val invariant : 'a t -> unit
                  val create :
                    ?growth_allowed:sexp_bool -> ?size:index -> unit -> 'a t
                  val clear : 'a t -> unit
                  val mem : 'a t -> Key.t -> sexp_bool
                  val lookup : 'a t -> Key.t -> 'a sexp_option
                  val lookup_exn : 'a t -> Key.t -> 'a
                  val enqueue :
                    'a t -> Key.t -> 'a -> [ `Key_already_present | `Ok ]
                  val enqueue_exn : 'a t -> Key.t -> 'a -> unit
                  val lookup_and_move_to_back :
                    'a t -> Key.t -> 'a sexp_option
                  val lookup_and_move_to_back_exn : 'a t -> Key.t -> 'a
                  val first : 'a t -> 'a sexp_option
                  val first_with_key : 'a t -> (Key.t * 'a) sexp_option
                  val keys : 'a t -> Key.t sexp_list
                  val dequeue : 'a t -> 'a sexp_option
                  val dequeue_exn : 'a t -> 'a
                  val dequeue_with_key : 'a t -> (Key.t * 'a) sexp_option
                  val dequeue_with_key_exn : 'a t -> Key.t * 'a
                  val dequeue_all : 'a t -> f:('a -> unit) -> unit
                  val remove : 'a t -> Key.t -> [ `No_such_key | `Ok ]
                  val remove_exn : 'a t -> Key.t -> unit
                  val replace : 'a t -> Key.t -> 'a -> [ `No_such_key | `Ok ]
                  val replace_exn : 'a t -> Key.t -> 'a -> unit
                  val iteri :
                    'a t -> f:(key:Key.t -> data:'a -> unit) -> unit
                  val foldi :
                    'a t ->
                    init:'b -> f:('b -> key:Key.t -> data:'a -> 'b) -> 'b
                end
              val of_byte_string : string -> t
              val of_directions : Direction.t sexp_list -> t
              val root : unit -> t
              val slice : t -> index -> index -> t
              val get : t -> index -> index
              val copy : t -> t
              val parent : t -> t Or_error.t
              val child : t -> Direction.t -> t Or_error.t
              val child_exn : t -> Direction.t -> t
              val parent_exn : t -> t
              val dirs_from_root : t -> Direction.t sexp_list
              val sibling : t -> t
              val next : t -> t sexp_option
              val is_parent_of : t -> maybe_child:t -> bool
              val serialize : t -> Bigstring.t
              val to_string : t -> string
              val pp : Format.formatter -> t -> unit
              module Range :
                sig
                  type nonrec t = t * t
                  val fold :
                    ?stop:[ `Exclusive | `Inclusive ] ->
                    t -> init:'a -> f:(Hash_set.elt -> 'a -> 'a) -> 'a
                  val subtree_range : Hash_set.elt -> t
                end
              val depth : t -> index
              val height : t -> index
              val to_int : t -> index
              val of_int_exn : index -> t
            end
          module Prefix :
            sig
              val generic : Unsigned.UInt8.t
              val account : Unsigned.UInt8.t
              val hash : index -> Unsigned.UInt8.t
            end
          type t =
            Location_at_depth.t =
              Generic of Bigstring.t
            | Account of Addr.t
            | Hash of Addr.t
          val equal : t -> t -> bool
          val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
          val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
          val bin_t : t Bin_prot.Type_class.t
          val bin_read_t : t Bin_prot.Read.reader
          val __bin_read_t__ : (index -> t) Bin_prot.Read.reader
          val bin_reader_t : t Bin_prot.Type_class.reader
          val bin_size_t : t Bin_prot.Size.sizer
          val bin_write_t : t Bin_prot.Write.writer
          val bin_writer_t : t Bin_prot.Type_class.writer
          val bin_shape_t : Bin_prot.Shape.t
          val compare : t -> t -> index
          val hash_fold_t : Base.Hash.state -> t -> Base.Hash.state
          val hash : t -> index
          val hashable : t Hashtbl_intf.Hashable.t
          module Table :
            sig
              type key = t
              type ('a, 'b) hashtbl = ('a, 'b) Hashtbl_intf.Hashtbl.t
              type 'b t = (key, 'b) hashtbl
              val sexp_of_t :
                ('b -> Ppx_sexp_conv_lib.Sexp.t) ->
                'b t -> Ppx_sexp_conv_lib.Sexp.t
              type ('a, 'b) t_ = 'b t
              type 'a key_ = key
              val hashable : key Hashtbl_intf.Hashable.t
              val invariant :
                'a Base__Invariant_intf.t -> 'a t Base__Invariant_intf.t
              val create :
                (key, 'b, unit -> 'b t)
                Hashtbl_intf.create_options_without_hashable
              val of_alist :
                (key, 'b,
                 (key * 'b) sexp_list ->
                 [ `Duplicate_key of key | `Ok of 'b t ])
                Hashtbl_intf.create_options_without_hashable
              val of_alist_report_all_dups :
                (key, 'b,
                 (key * 'b) sexp_list ->
                 [ `Duplicate_keys of key sexp_list | `Ok of 'b t ])
                Hashtbl_intf.create_options_without_hashable
              val of_alist_or_error :
                (key, 'b, (key * 'b) sexp_list -> 'b t Base.Or_error.t)
                Hashtbl_intf.create_options_without_hashable
              val of_alist_exn :
                (key, 'b, (key * 'b) sexp_list -> 'b t)
                Hashtbl_intf.create_options_without_hashable
              val of_alist_multi :
                (key, 'b sexp_list, (key * 'b) sexp_list -> 'b sexp_list t)
                Hashtbl_intf.create_options_without_hashable
              val create_mapped :
                (key, 'b,
                 get_key:('r -> key) ->
                 get_data:('r -> 'b) ->
                 'r sexp_list ->
                 [ `Duplicate_keys of key sexp_list | `Ok of 'b t ])
                Hashtbl_intf.create_options_without_hashable
              val create_with_key :
                (key, 'r,
                 get_key:('r -> key) ->
                 'r sexp_list ->
                 [ `Duplicate_keys of key sexp_list | `Ok of 'r t ])
                Hashtbl_intf.create_options_without_hashable
              val create_with_key_or_error :
                (key, 'r,
                 get_key:('r -> key) -> 'r sexp_list -> 'r t Base.Or_error.t)
                Hashtbl_intf.create_options_without_hashable
              val create_with_key_exn :
                (key, 'r, get_key:('r -> key) -> 'r sexp_list -> 'r t)
                Hashtbl_intf.create_options_without_hashable
              val group :
                (key, 'b,
                 get_key:('r -> key) ->
                 get_data:('r -> 'b) ->
                 combine:('b -> 'b -> 'b) -> 'r sexp_list -> 'b t)
                Hashtbl_intf.create_options_without_hashable
              val sexp_of_key : 'a t -> key -> Ppx_sexp_conv_lib.Sexp.t
              val clear : 'a t -> unit
              val copy : 'b t -> 'b t
              val fold :
                'b t -> init:'c -> f:(key:key -> data:'b -> 'c -> 'c) -> 'c
              val iter_keys : 'a t -> f:(key -> unit) -> unit
              val iter : 'b t -> f:('b -> unit) -> unit
              val iteri : 'b t -> f:(key:key -> data:'b -> unit) -> unit
              val existsi : 'b t -> f:(key:key -> data:'b -> bool) -> bool
              val exists : 'b t -> f:('b -> bool) -> bool
              val for_alli : 'b t -> f:(key:key -> data:'b -> bool) -> bool
              val for_all : 'b t -> f:('b -> bool) -> bool
              val counti : 'b t -> f:(key:key -> data:'b -> bool) -> index
              val count : 'b t -> f:('b -> bool) -> index
              val length : 'a t -> index
              val is_empty : 'a t -> bool
              val mem : 'a t -> key -> bool
              val remove : 'a t -> key -> unit
              val set : 'b t -> key:key -> data:'b -> unit
              val add : 'b t -> key:key -> data:'b -> [ `Duplicate | `Ok ]
              val add_exn : 'b t -> key:key -> data:'b -> unit
              val change :
                'b t -> key -> f:('b sexp_option -> 'b sexp_option) -> unit
              val update : 'b t -> key -> f:('b sexp_option -> 'b) -> unit
              val map : 'b t -> f:('b -> 'c) -> 'c t
              val mapi : 'b t -> f:(key:key -> data:'b -> 'c) -> 'c t
              val filter_map : 'b t -> f:('b -> 'c sexp_option) -> 'c t
              val filter_mapi :
                'b t -> f:(key:key -> data:'b -> 'c sexp_option) -> 'c t
              val filter_keys : 'b t -> f:(key -> bool) -> 'b t
              val filter : 'b t -> f:('b -> bool) -> 'b t
              val filteri : 'b t -> f:(key:key -> data:'b -> bool) -> 'b t
              val partition_map :
                'b t -> f:('b -> [ `Fst of 'c | `Snd of 'd ]) -> 'c t * 'd t
              val partition_mapi :
                'b t ->
                f:(key:key -> data:'b -> [ `Fst of 'c | `Snd of 'd ]) ->
                'c t * 'd t
              val partition_tf : 'b t -> f:('b -> bool) -> 'b t * 'b t
              val partitioni_tf :
                'b t -> f:(key:key -> data:'b -> bool) -> 'b t * 'b t
              val find_or_add : 'b t -> key -> default:(unit -> 'b) -> 'b
              val findi_or_add : 'b t -> key -> default:(key -> 'b) -> 'b
              val find : 'b t -> key -> 'b sexp_option
              val find_exn : 'b t -> key -> 'b
              val find_and_call :
                'b t ->
                key -> if_found:('b -> 'c) -> if_not_found:(key -> 'c) -> 'c
              val findi_and_call :
                'b t ->
                key ->
                if_found:(key:key -> data:'b -> 'c) ->
                if_not_found:(key -> 'c) -> 'c
              val find_and_remove : 'b t -> key -> 'b sexp_option
              val merge :
                'a t ->
                'b t ->
                f:(key:key ->
                   [ `Both of 'a * 'b | `Left of 'a | `Right of 'b ] ->
                   'c sexp_option) ->
                'c t
              type 'a merge_into_action =
                'a Location_at_depth.Table.merge_into_action =
                  Remove
                | Set_to of 'a
              val merge_into :
                src:'a t ->
                dst:'b t ->
                f:(key:key -> 'a -> 'b sexp_option -> 'b merge_into_action) ->
                unit
              val keys : 'a t -> key sexp_list
              val data : 'b t -> 'b sexp_list
              val filter_keys_inplace : 'a t -> f:(key -> bool) -> unit
              val filter_inplace : 'b t -> f:('b -> bool) -> unit
              val filteri_inplace :
                'b t -> f:(key:key -> data:'b -> bool) -> unit
              val map_inplace : 'b t -> f:('b -> 'b) -> unit
              val mapi_inplace : 'b t -> f:(key:key -> data:'b -> 'b) -> unit
              val filter_map_inplace :
                'b t -> f:('b -> 'b sexp_option) -> unit
              val filter_mapi_inplace :
                'b t -> f:(key:key -> data:'b -> 'b sexp_option) -> unit
              val equal : 'b t -> 'b t -> ('b -> 'b -> bool) -> bool
              val similar : 'b1 t -> 'b2 t -> ('b1 -> 'b2 -> bool) -> bool
              val to_alist : 'b t -> (key * 'b) sexp_list
              val validate :
                name:(key -> string) ->
                'b Validate.check -> 'b t Validate.check
              val incr :
                ?by:index -> ?remove_if_zero:bool -> index t -> key -> unit
              val decr :
                ?by:index -> ?remove_if_zero:bool -> index t -> key -> unit
              val add_multi : 'b sexp_list t -> key:key -> data:'b -> unit
              val remove_multi : 'a sexp_list t -> key -> unit
              val find_multi : 'b sexp_list t -> key -> 'b sexp_list
              module Provide_of_sexp :
                functor
                  (Key : sig
                           val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> key
                         end) ->
                  sig
                    val t_of_sexp :
                      (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__001_) ->
                      Ppx_sexp_conv_lib.Sexp.t -> 'v_x__001_ t
                  end
              module Provide_bin_io :
                functor
                  (Key : sig
                           val bin_t : key Bin_prot.Type_class.t
                           val bin_read_t : key Bin_prot.Read.reader
                           val __bin_read_t__ :
                             (index -> key) Bin_prot.Read.reader
                           val bin_reader_t : key Bin_prot.Type_class.reader
                           val bin_size_t : key Bin_prot.Size.sizer
                           val bin_write_t : key Bin_prot.Write.writer
                           val bin_writer_t : key Bin_prot.Type_class.writer
                           val bin_shape_t : Bin_prot.Shape.t
                         end) ->
                  sig
                    val bin_t :
                      'a Bin_prot.Type_class.t -> 'a t Bin_prot.Type_class.t
                    val bin_read_t :
                      'a Bin_prot.Read.reader -> 'a t Bin_prot.Read.reader
                    val __bin_read_t__ :
                      'a Bin_prot.Read.reader ->
                      (index -> 'a t) Bin_prot.Read.reader
                    val bin_reader_t :
                      'a Bin_prot.Type_class.reader ->
                      'a t Bin_prot.Type_class.reader
                    val bin_size_t :
                      'a Bin_prot.Size.sizer -> 'a t Bin_prot.Size.sizer
                    val bin_write_t :
                      'a Bin_prot.Write.writer -> 'a t Bin_prot.Write.writer
                    val bin_writer_t :
                      'a Bin_prot.Type_class.writer ->
                      'a t Bin_prot.Type_class.writer
                    val bin_shape_t : Bin_prot.Shape.t -> Bin_prot.Shape.t
                  end
              val t_of_sexp :
                (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_) ->
                Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_ t
            end
          module Hash_set :
            sig
              type elt = t
              type t = elt Hash_set.t
              val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
              type 'a t_ = t
              type 'a elt_ = elt
              val create :
                ('a, unit -> t)
                Base.Hash_set.create_options_without_first_class_module
              val of_list :
                ('a, elt sexp_list -> t)
                Base.Hash_set.create_options_without_first_class_module
              module Provide_of_sexp :
                functor
                  (X : sig
                         val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> elt
                       end) ->
                  sig val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t end
              module Provide_bin_io :
                functor
                  (X : sig
                         val bin_t : elt Bin_prot.Type_class.t
                         val bin_read_t : elt Bin_prot.Read.reader
                         val __bin_read_t__ :
                           (index -> elt) Bin_prot.Read.reader
                         val bin_reader_t : elt Bin_prot.Type_class.reader
                         val bin_size_t : elt Bin_prot.Size.sizer
                         val bin_write_t : elt Bin_prot.Write.writer
                         val bin_writer_t : elt Bin_prot.Type_class.writer
                         val bin_shape_t : Bin_prot.Shape.t
                       end) ->
                  sig
                    val bin_t : t Bin_prot.Type_class.t
                    val bin_read_t : t Bin_prot.Read.reader
                    val __bin_read_t__ : (index -> t) Bin_prot.Read.reader
                    val bin_reader_t : t Bin_prot.Type_class.reader
                    val bin_size_t : t Bin_prot.Size.sizer
                    val bin_write_t : t Bin_prot.Write.writer
                    val bin_writer_t : t Bin_prot.Type_class.writer
                    val bin_shape_t : Bin_prot.Shape.t
                  end
              val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
            end
          module Hash_queue :
            sig
              module Key :
                sig
                  type t = Location_at_depth.t
                  val compare : t -> t -> index
                  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
                  val hash : t -> index
                end
              type 'a t = 'a Location_at_depth.Hash_queue.t
              val sexp_of_t :
                ('a -> Ppx_sexp_conv_lib.Sexp.t) ->
                'a t -> Ppx_sexp_conv_lib.Sexp.t
              val length : 'a t -> index
              val is_empty : 'a t -> bool
              val iter : 'a t -> f:('a -> unit) -> unit
              val fold :
                'a t -> init:'accum -> f:('accum -> 'a -> 'accum) -> 'accum
              val fold_result :
                'a t ->
                init:'accum ->
                f:('accum -> 'a -> ('accum, 'e) result) ->
                ('accum, 'e) result
              val fold_until :
                'a t ->
                init:'accum ->
                f:('accum -> 'a -> ('accum, 'final) Base.Continue_or_stop.t) ->
                finish:('accum -> 'final) -> 'final
              val exists : 'a t -> f:('a -> bool) -> bool
              val for_all : 'a t -> f:('a -> bool) -> bool
              val count : 'a t -> f:('a -> bool) -> index
              val sum :
                (module Commutative_group.S with type t = 'sum) ->
                'a t -> f:('a -> 'sum) -> 'sum
              val find : 'a t -> f:('a -> bool) -> 'a sexp_option
              val find_map :
                'a t -> f:('a -> 'b sexp_option) -> 'b sexp_option
              val to_list : 'a t -> 'a sexp_list
              val to_array : 'a t -> 'a array
              val min_elt :
                'a t -> compare:('a -> 'a -> index) -> 'a sexp_option
              val max_elt :
                'a t -> compare:('a -> 'a -> index) -> 'a sexp_option
              val invariant : 'a t -> unit
              val create :
                ?growth_allowed:sexp_bool -> ?size:index -> unit -> 'a t
              val clear : 'a t -> unit
              val mem : 'a t -> Location_at_depth.t -> sexp_bool
              val lookup : 'a t -> Location_at_depth.t -> 'a sexp_option
              val lookup_exn : 'a t -> Location_at_depth.t -> 'a
              val enqueue :
                'a t ->
                Location_at_depth.t -> 'a -> [ `Key_already_present | `Ok ]
              val enqueue_exn : 'a t -> Location_at_depth.t -> 'a -> unit
              val lookup_and_move_to_back :
                'a t -> Location_at_depth.t -> 'a sexp_option
              val lookup_and_move_to_back_exn :
                'a t -> Location_at_depth.t -> 'a
              val first : 'a t -> 'a sexp_option
              val first_with_key :
                'a t -> (Location_at_depth.t * 'a) sexp_option
              val keys : 'a t -> Location_at_depth.t sexp_list
              val dequeue : 'a t -> 'a sexp_option
              val dequeue_exn : 'a t -> 'a
              val dequeue_with_key :
                'a t -> (Location_at_depth.t * 'a) sexp_option
              val dequeue_with_key_exn : 'a t -> Location_at_depth.t * 'a
              val dequeue_all : 'a t -> f:('a -> unit) -> unit
              val remove :
                'a t -> Location_at_depth.t -> [ `No_such_key | `Ok ]
              val remove_exn : 'a t -> Location_at_depth.t -> unit
              val replace :
                'a t -> Location_at_depth.t -> 'a -> [ `No_such_key | `Ok ]
              val replace_exn : 'a t -> Location_at_depth.t -> 'a -> unit
              val iteri :
                'a t ->
                f:(key:Location_at_depth.t -> data:'a -> unit) -> unit
              val foldi :
                'a t ->
                init:'b ->
                f:('b -> key:Location_at_depth.t -> data:'a -> 'b) -> 'b
            end
          val is_generic : t -> bool
          val is_account : t -> bool
          val is_hash : t -> bool
          val height : t -> index
          val root_hash : t
          val last_direction : Addr.t -> Direction.t
          val build_generic : Bigstring.t -> t
          val parse : Bigstring.t -> (t, unit) result
          val prefix_bigstring :
            Unsigned.UInt8.t -> Bigstring.t -> Bigstring.t
          val to_path_exn : t -> Addr.t
          val serialize : t -> Bigstring.t
          val parent : t -> t
          val next : t -> t sexp_option
          val sibling : t -> t
          val order_siblings : t -> 'a -> 'a -> 'a * 'a
        end
      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
      type path = Path.t
      val depth : index
      val num_accounts : t -> index
      val merkle_path_at_addr_exn : t -> Addr.t -> path
      val get_inner_hash_at_addr_exn : t -> Addr.t -> Ledger_hash.t
      val set_inner_hash_at_addr_exn : t -> Addr.t -> Ledger_hash.t -> unit
      val set_all_accounts_rooted_at_exn :
        t -> Addr.t -> Account.t sexp_list -> unit
      val get_all_accounts_rooted_at_exn : t -> Addr.t -> Account.t sexp_list
      val make_space_for : t -> index -> unit
      val to_list : t -> Account.t sexp_list
      val foldi :
        t ->
        init:'accum -> f:(Addr.t -> 'accum -> Account.t -> 'accum) -> 'accum
      val fold_until :
        t ->
        init:'accum ->
        f:('accum -> Account.t -> ('accum, 'stop) Base.Continue_or_stop.t) ->
        finish:('accum -> 'stop) -> 'stop
      val location_of_key : t -> Key.t -> Location_at_depth.t sexp_option
      val get_or_create_account :
        t ->
        Key.t ->
        Account.t -> ([ `Added | `Existed ] * Location_at_depth.t) Or_error.t
      val get_or_create_account_exn :
        t ->
        Key.t -> Account.t -> [ `Added | `Existed ] * Location_at_depth.t
      val destroy : t -> unit
      val get_uuid : t -> Uuid.t
      val get : t -> Location_at_depth.t -> Account.t sexp_option
      val set : t -> Location_at_depth.t -> Account.t -> unit
      val set_batch :
        t -> (Location_at_depth.t * Account.t) sexp_list -> unit
      val get_at_index_exn : t -> index -> Account.t
      val set_at_index_exn : t -> index -> Account.t -> unit
      val index_of_key_exn : t -> Key.t -> index
      val merkle_root : t -> Ledger_hash.t
      val merkle_path : t -> Location_at_depth.t -> path
      val merkle_path_at_index_exn : t -> index -> path
      val remove_accounts_exn : t -> Key.t sexp_list -> unit
    end
  type witness =
    Any_base.witness =
      T : (module Base_intf with type t = 't) * 't -> witness
  val sexp_of_witness : witness -> Ppx_sexp_conv_lib.Sexp.t
  val witness_of_sexp : witness -> 'a
  module M :
    sig
      type index = int
      type t = witness
      module Addr :
        sig
          type t = Location_at_depth.Addr.t
          val equal : t -> t -> bool
          val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
          val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
          val bin_t : t Bin_prot.Type_class.t
          val bin_read_t : t Bin_prot.Read.reader
          val __bin_read_t__ : (index -> t) Bin_prot.Read.reader
          val bin_reader_t : t Bin_prot.Type_class.reader
          val bin_size_t : t Bin_prot.Size.sizer
          val bin_write_t : t Bin_prot.Write.writer
          val bin_writer_t : t Bin_prot.Type_class.writer
          val bin_shape_t : Bin_prot.Shape.t
          module Stable :
            sig
              module V1 :
                sig
                  type nonrec t = t
                  val equal : t -> t -> bool
                  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
                  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
                  val bin_t : t Bin_prot.Type_class.t
                  val bin_read_t : t Bin_prot.Read.reader
                  val __bin_read_t__ : (index -> t) Bin_prot.Read.reader
                  val bin_reader_t : t Bin_prot.Type_class.reader
                  val bin_size_t : t Bin_prot.Size.sizer
                  val bin_write_t : t Bin_prot.Write.writer
                  val bin_writer_t : t Bin_prot.Type_class.writer
                  val bin_shape_t : Bin_prot.Shape.t
                  val hash_fold_t : Base.Hash.state -> t -> Base.Hash.state
                  val hash : t -> index
                  val compare : t -> t -> index
                end
            end
          val compare : t -> t -> index
          val hash_fold_t : Base.Hash.state -> t -> Base.Hash.state
          val hash : t -> index
          val hashable : t Hashtbl_intf.Hashable.t
          module Table :
            sig
              type key = t
              type ('a, 'b) hashtbl = ('a, 'b) Hashtbl_intf.Hashtbl.t
              type 'b t = (key, 'b) hashtbl
              val sexp_of_t :
                ('b -> Ppx_sexp_conv_lib.Sexp.t) ->
                'b t -> Ppx_sexp_conv_lib.Sexp.t
              type ('a, 'b) t_ = 'b t
              type 'a key_ = key
              val hashable : key Hashtbl_intf.Hashable.t
              val invariant :
                'a Base__Invariant_intf.t -> 'a t Base__Invariant_intf.t
              val create :
                (key, 'b, unit -> 'b t)
                Hashtbl_intf.create_options_without_hashable
              val of_alist :
                (key, 'b,
                 (key * 'b) sexp_list ->
                 [ `Duplicate_key of key | `Ok of 'b t ])
                Hashtbl_intf.create_options_without_hashable
              val of_alist_report_all_dups :
                (key, 'b,
                 (key * 'b) sexp_list ->
                 [ `Duplicate_keys of key sexp_list | `Ok of 'b t ])
                Hashtbl_intf.create_options_without_hashable
              val of_alist_or_error :
                (key, 'b, (key * 'b) sexp_list -> 'b t Base.Or_error.t)
                Hashtbl_intf.create_options_without_hashable
              val of_alist_exn :
                (key, 'b, (key * 'b) sexp_list -> 'b t)
                Hashtbl_intf.create_options_without_hashable
              val of_alist_multi :
                (key, 'b sexp_list, (key * 'b) sexp_list -> 'b sexp_list t)
                Hashtbl_intf.create_options_without_hashable
              val create_mapped :
                (key, 'b,
                 get_key:('r -> key) ->
                 get_data:('r -> 'b) ->
                 'r sexp_list ->
                 [ `Duplicate_keys of key sexp_list | `Ok of 'b t ])
                Hashtbl_intf.create_options_without_hashable
              val create_with_key :
                (key, 'r,
                 get_key:('r -> key) ->
                 'r sexp_list ->
                 [ `Duplicate_keys of key sexp_list | `Ok of 'r t ])
                Hashtbl_intf.create_options_without_hashable
              val create_with_key_or_error :
                (key, 'r,
                 get_key:('r -> key) -> 'r sexp_list -> 'r t Base.Or_error.t)
                Hashtbl_intf.create_options_without_hashable
              val create_with_key_exn :
                (key, 'r, get_key:('r -> key) -> 'r sexp_list -> 'r t)
                Hashtbl_intf.create_options_without_hashable
              val group :
                (key, 'b,
                 get_key:('r -> key) ->
                 get_data:('r -> 'b) ->
                 combine:('b -> 'b -> 'b) -> 'r sexp_list -> 'b t)
                Hashtbl_intf.create_options_without_hashable
              val sexp_of_key : 'a t -> key -> Ppx_sexp_conv_lib.Sexp.t
              val clear : 'a t -> unit
              val copy : 'b t -> 'b t
              val fold :
                'b t -> init:'c -> f:(key:key -> data:'b -> 'c -> 'c) -> 'c
              val iter_keys : 'a t -> f:(key -> unit) -> unit
              val iter : 'b t -> f:('b -> unit) -> unit
              val iteri : 'b t -> f:(key:key -> data:'b -> unit) -> unit
              val existsi : 'b t -> f:(key:key -> data:'b -> bool) -> bool
              val exists : 'b t -> f:('b -> bool) -> bool
              val for_alli : 'b t -> f:(key:key -> data:'b -> bool) -> bool
              val for_all : 'b t -> f:('b -> bool) -> bool
              val counti : 'b t -> f:(key:key -> data:'b -> bool) -> index
              val count : 'b t -> f:('b -> bool) -> index
              val length : 'a t -> index
              val is_empty : 'a t -> bool
              val mem : 'a t -> key -> bool
              val remove : 'a t -> key -> unit
              val set : 'b t -> key:key -> data:'b -> unit
              val add : 'b t -> key:key -> data:'b -> [ `Duplicate | `Ok ]
              val add_exn : 'b t -> key:key -> data:'b -> unit
              val change :
                'b t -> key -> f:('b sexp_option -> 'b sexp_option) -> unit
              val update : 'b t -> key -> f:('b sexp_option -> 'b) -> unit
              val map : 'b t -> f:('b -> 'c) -> 'c t
              val mapi : 'b t -> f:(key:key -> data:'b -> 'c) -> 'c t
              val filter_map : 'b t -> f:('b -> 'c sexp_option) -> 'c t
              val filter_mapi :
                'b t -> f:(key:key -> data:'b -> 'c sexp_option) -> 'c t
              val filter_keys : 'b t -> f:(key -> bool) -> 'b t
              val filter : 'b t -> f:('b -> bool) -> 'b t
              val filteri : 'b t -> f:(key:key -> data:'b -> bool) -> 'b t
              val partition_map :
                'b t -> f:('b -> [ `Fst of 'c | `Snd of 'd ]) -> 'c t * 'd t
              val partition_mapi :
                'b t ->
                f:(key:key -> data:'b -> [ `Fst of 'c | `Snd of 'd ]) ->
                'c t * 'd t
              val partition_tf : 'b t -> f:('b -> bool) -> 'b t * 'b t
              val partitioni_tf :
                'b t -> f:(key:key -> data:'b -> bool) -> 'b t * 'b t
              val find_or_add : 'b t -> key -> default:(unit -> 'b) -> 'b
              val findi_or_add : 'b t -> key -> default:(key -> 'b) -> 'b
              val find : 'b t -> key -> 'b sexp_option
              val find_exn : 'b t -> key -> 'b
              val find_and_call :
                'b t ->
                key -> if_found:('b -> 'c) -> if_not_found:(key -> 'c) -> 'c
              val findi_and_call :
                'b t ->
                key ->
                if_found:(key:key -> data:'b -> 'c) ->
                if_not_found:(key -> 'c) -> 'c
              val find_and_remove : 'b t -> key -> 'b sexp_option
              val merge :
                'a t ->
                'b t ->
                f:(key:key ->
                   [ `Both of 'a * 'b | `Left of 'a | `Right of 'b ] ->
                   'c sexp_option) ->
                'c t
              type 'a merge_into_action =
                'a Location_at_depth.Addr.Table.merge_into_action =
                  Remove
                | Set_to of 'a
              val merge_into :
                src:'a t ->
                dst:'b t ->
                f:(key:key -> 'a -> 'b sexp_option -> 'b merge_into_action) ->
                unit
              val keys : 'a t -> key sexp_list
              val data : 'b t -> 'b sexp_list
              val filter_keys_inplace : 'a t -> f:(key -> bool) -> unit
              val filter_inplace : 'b t -> f:('b -> bool) -> unit
              val filteri_inplace :
                'b t -> f:(key:key -> data:'b -> bool) -> unit
              val map_inplace : 'b t -> f:('b -> 'b) -> unit
              val mapi_inplace : 'b t -> f:(key:key -> data:'b -> 'b) -> unit
              val filter_map_inplace :
                'b t -> f:('b -> 'b sexp_option) -> unit
              val filter_mapi_inplace :
                'b t -> f:(key:key -> data:'b -> 'b sexp_option) -> unit
              val equal : 'b t -> 'b t -> ('b -> 'b -> bool) -> bool
              val similar : 'b1 t -> 'b2 t -> ('b1 -> 'b2 -> bool) -> bool
              val to_alist : 'b t -> (key * 'b) sexp_list
              val validate :
                name:(key -> string) ->
                'b Validate.check -> 'b t Validate.check
              val incr :
                ?by:index -> ?remove_if_zero:bool -> index t -> key -> unit
              val decr :
                ?by:index -> ?remove_if_zero:bool -> index t -> key -> unit
              val add_multi : 'b sexp_list t -> key:key -> data:'b -> unit
              val remove_multi : 'a sexp_list t -> key -> unit
              val find_multi : 'b sexp_list t -> key -> 'b sexp_list
              module Provide_of_sexp :
                functor
                  (Key : sig
                           val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> key
                         end) ->
                  sig
                    val t_of_sexp :
                      (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__001_) ->
                      Ppx_sexp_conv_lib.Sexp.t -> 'v_x__001_ t
                  end
              module Provide_bin_io :
                functor
                  (Key : sig
                           val bin_t : key Bin_prot.Type_class.t
                           val bin_read_t : key Bin_prot.Read.reader
                           val __bin_read_t__ :
                             (index -> key) Bin_prot.Read.reader
                           val bin_reader_t : key Bin_prot.Type_class.reader
                           val bin_size_t : key Bin_prot.Size.sizer
                           val bin_write_t : key Bin_prot.Write.writer
                           val bin_writer_t : key Bin_prot.Type_class.writer
                           val bin_shape_t : Bin_prot.Shape.t
                         end) ->
                  sig
                    val bin_t :
                      'a Bin_prot.Type_class.t -> 'a t Bin_prot.Type_class.t
                    val bin_read_t :
                      'a Bin_prot.Read.reader -> 'a t Bin_prot.Read.reader
                    val __bin_read_t__ :
                      'a Bin_prot.Read.reader ->
                      (index -> 'a t) Bin_prot.Read.reader
                    val bin_reader_t :
                      'a Bin_prot.Type_class.reader ->
                      'a t Bin_prot.Type_class.reader
                    val bin_size_t :
                      'a Bin_prot.Size.sizer -> 'a t Bin_prot.Size.sizer
                    val bin_write_t :
                      'a Bin_prot.Write.writer -> 'a t Bin_prot.Write.writer
                    val bin_writer_t :
                      'a Bin_prot.Type_class.writer ->
                      'a t Bin_prot.Type_class.writer
                    val bin_shape_t : Bin_prot.Shape.t -> Bin_prot.Shape.t
                  end
              val t_of_sexp :
                (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_) ->
                Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_ t
            end
          module Hash_set :
            sig
              type elt = t
              type t = elt Hash_set.t
              val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
              type 'a t_ = t
              type 'a elt_ = elt
              val create :
                ('a, unit -> t)
                Base.Hash_set.create_options_without_first_class_module
              val of_list :
                ('a, elt sexp_list -> t)
                Base.Hash_set.create_options_without_first_class_module
              module Provide_of_sexp :
                functor
                  (X : sig
                         val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> elt
                       end) ->
                  sig val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t end
              module Provide_bin_io :
                functor
                  (X : sig
                         val bin_t : elt Bin_prot.Type_class.t
                         val bin_read_t : elt Bin_prot.Read.reader
                         val __bin_read_t__ :
                           (index -> elt) Bin_prot.Read.reader
                         val bin_reader_t : elt Bin_prot.Type_class.reader
                         val bin_size_t : elt Bin_prot.Size.sizer
                         val bin_write_t : elt Bin_prot.Write.writer
                         val bin_writer_t : elt Bin_prot.Type_class.writer
                         val bin_shape_t : Bin_prot.Shape.t
                       end) ->
                  sig
                    val bin_t : t Bin_prot.Type_class.t
                    val bin_read_t : t Bin_prot.Read.reader
                    val __bin_read_t__ : (index -> t) Bin_prot.Read.reader
                    val bin_reader_t : t Bin_prot.Type_class.reader
                    val bin_size_t : t Bin_prot.Size.sizer
                    val bin_write_t : t Bin_prot.Write.writer
                    val bin_writer_t : t Bin_prot.Type_class.writer
                    val bin_shape_t : Bin_prot.Shape.t
                  end
              val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
            end
          module Hash_queue :
            sig
              module Key :
                sig
                  type t = Hash_set.elt
                  val compare : t -> t -> index
                  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
                  val hash : t -> index
                end
              type 'a t = 'a Location_at_depth.Addr.Hash_queue.t
              val sexp_of_t :
                ('a -> Ppx_sexp_conv_lib.Sexp.t) ->
                'a t -> Ppx_sexp_conv_lib.Sexp.t
              val length : 'a t -> index
              val is_empty : 'a t -> bool
              val iter : 'a t -> f:('a -> unit) -> unit
              val fold :
                'a t -> init:'accum -> f:('accum -> 'a -> 'accum) -> 'accum
              val fold_result :
                'a t ->
                init:'accum ->
                f:('accum -> 'a -> ('accum, 'e) result) ->
                ('accum, 'e) result
              val fold_until :
                'a t ->
                init:'accum ->
                f:('accum -> 'a -> ('accum, 'final) Base.Continue_or_stop.t) ->
                finish:('accum -> 'final) -> 'final
              val exists : 'a t -> f:('a -> bool) -> bool
              val for_all : 'a t -> f:('a -> bool) -> bool
              val count : 'a t -> f:('a -> bool) -> index
              val sum :
                (module Commutative_group.S with type t = 'sum) ->
                'a t -> f:('a -> 'sum) -> 'sum
              val find : 'a t -> f:('a -> bool) -> 'a sexp_option
              val find_map :
                'a t -> f:('a -> 'b sexp_option) -> 'b sexp_option
              val to_list : 'a t -> 'a sexp_list
              val to_array : 'a t -> 'a array
              val min_elt :
                'a t -> compare:('a -> 'a -> index) -> 'a sexp_option
              val max_elt :
                'a t -> compare:('a -> 'a -> index) -> 'a sexp_option
              val invariant : 'a t -> unit
              val create :
                ?growth_allowed:sexp_bool -> ?size:index -> unit -> 'a t
              val clear : 'a t -> unit
              val mem : 'a t -> Key.t -> sexp_bool
              val lookup : 'a t -> Key.t -> 'a sexp_option
              val lookup_exn : 'a t -> Key.t -> 'a
              val enqueue :
                'a t -> Key.t -> 'a -> [ `Key_already_present | `Ok ]
              val enqueue_exn : 'a t -> Key.t -> 'a -> unit
              val lookup_and_move_to_back : 'a t -> Key.t -> 'a sexp_option
              val lookup_and_move_to_back_exn : 'a t -> Key.t -> 'a
              val first : 'a t -> 'a sexp_option
              val first_with_key : 'a t -> (Key.t * 'a) sexp_option
              val keys : 'a t -> Key.t sexp_list
              val dequeue : 'a t -> 'a sexp_option
              val dequeue_exn : 'a t -> 'a
              val dequeue_with_key : 'a t -> (Key.t * 'a) sexp_option
              val dequeue_with_key_exn : 'a t -> Key.t * 'a
              val dequeue_all : 'a t -> f:('a -> unit) -> unit
              val remove : 'a t -> Key.t -> [ `No_such_key | `Ok ]
              val remove_exn : 'a t -> Key.t -> unit
              val replace : 'a t -> Key.t -> 'a -> [ `No_such_key | `Ok ]
              val replace_exn : 'a t -> Key.t -> 'a -> unit
              val iteri : 'a t -> f:(key:Key.t -> data:'a -> unit) -> unit
              val foldi :
                'a t -> init:'b -> f:('b -> key:Key.t -> data:'a -> 'b) -> 'b
            end
          val of_byte_string : string -> t
          val of_directions : Direction.t sexp_list -> t
          val root : unit -> t
          val slice : t -> index -> index -> t
          val get : t -> index -> index
          val copy : t -> t
          val parent : t -> t Or_error.t
          val child : t -> Direction.t -> t Or_error.t
          val child_exn : t -> Direction.t -> t
          val parent_exn : t -> t
          val dirs_from_root : t -> Direction.t sexp_list
          val sibling : t -> t
          val next : t -> t sexp_option
          val is_parent_of : t -> maybe_child:t -> bool
          val serialize : t -> Bigstring.t
          val to_string : t -> string
          val pp : Format.formatter -> t -> unit
          module Range :
            sig
              type nonrec t = t * t
              val fold :
                ?stop:[ `Exclusive | `Inclusive ] ->
                t -> init:'a -> f:(Hash_set.elt -> 'a -> 'a) -> 'a
              val subtree_range : Hash_set.elt -> t
            end
          val depth : t -> index
          val height : t -> index
          val to_int : t -> index
          val of_int_exn : index -> t
        end
      module Path :
        sig
          type elem = [ `Left of Ledger_hash.t | `Right of Ledger_hash.t ]
          val elem_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> elem
          val __elem_of_sexp__ : Ppx_sexp_conv_lib.Sexp.t -> elem
          val sexp_of_elem : elem -> Ppx_sexp_conv_lib.Sexp.t
          val elem_hash : elem -> Ledger_hash.t
          type t = elem sexp_list
          val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
          val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
          val implied_root : t -> Ledger_hash.t -> Ledger_hash.t
          val check_path : t -> Ledger_hash.t -> Ledger_hash.t -> bool
        end
      module Location :
        sig
          module Addr :
            sig
              type t = Addr.t
              val equal : t -> t -> bool
              val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
              val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
              val bin_t : t Bin_prot.Type_class.t
              val bin_read_t : t Bin_prot.Read.reader
              val __bin_read_t__ : (index -> t) Bin_prot.Read.reader
              val bin_reader_t : t Bin_prot.Type_class.reader
              val bin_size_t : t Bin_prot.Size.sizer
              val bin_write_t : t Bin_prot.Write.writer
              val bin_writer_t : t Bin_prot.Type_class.writer
              val bin_shape_t : Bin_prot.Shape.t
              module Stable :
                sig
                  module V1 :
                    sig
                      type nonrec t = t
                      val equal : t -> t -> bool
                      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
                      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
                      val bin_t : t Bin_prot.Type_class.t
                      val bin_read_t : t Bin_prot.Read.reader
                      val __bin_read_t__ : (index -> t) Bin_prot.Read.reader
                      val bin_reader_t : t Bin_prot.Type_class.reader
                      val bin_size_t : t Bin_prot.Size.sizer
                      val bin_write_t : t Bin_prot.Write.writer
                      val bin_writer_t : t Bin_prot.Type_class.writer
                      val bin_shape_t : Bin_prot.Shape.t
                      val hash_fold_t :
                        Base.Hash.state -> t -> Base.Hash.state
                      val hash : t -> index
                      val compare : t -> t -> index
                    end
                end
              val compare : t -> t -> index
              val hash_fold_t : Base.Hash.state -> t -> Base.Hash.state
              val hash : t -> index
              val hashable : t Hashtbl_intf.Hashable.t
              module Table :
                sig
                  type key = t
                  type ('a, 'b) hashtbl = ('a, 'b) Hashtbl_intf.Hashtbl.t
                  type 'b t = (key, 'b) hashtbl
                  val sexp_of_t :
                    ('b -> Ppx_sexp_conv_lib.Sexp.t) ->
                    'b t -> Ppx_sexp_conv_lib.Sexp.t
                  type ('a, 'b) t_ = 'b t
                  type 'a key_ = key
                  val hashable : key Hashtbl_intf.Hashable.t
                  val invariant :
                    'a Base__Invariant_intf.t -> 'a t Base__Invariant_intf.t
                  val create :
                    (key, 'b, unit -> 'b t)
                    Hashtbl_intf.create_options_without_hashable
                  val of_alist :
                    (key, 'b,
                     (key * 'b) sexp_list ->
                     [ `Duplicate_key of key | `Ok of 'b t ])
                    Hashtbl_intf.create_options_without_hashable
                  val of_alist_report_all_dups :
                    (key, 'b,
                     (key * 'b) sexp_list ->
                     [ `Duplicate_keys of key sexp_list | `Ok of 'b t ])
                    Hashtbl_intf.create_options_without_hashable
                  val of_alist_or_error :
                    (key, 'b, (key * 'b) sexp_list -> 'b t Base.Or_error.t)
                    Hashtbl_intf.create_options_without_hashable
                  val of_alist_exn :
                    (key, 'b, (key * 'b) sexp_list -> 'b t)
                    Hashtbl_intf.create_options_without_hashable
                  val of_alist_multi :
                    (key, 'b sexp_list,
                     (key * 'b) sexp_list -> 'b sexp_list t)
                    Hashtbl_intf.create_options_without_hashable
                  val create_mapped :
                    (key, 'b,
                     get_key:('r -> key) ->
                     get_data:('r -> 'b) ->
                     'r sexp_list ->
                     [ `Duplicate_keys of key sexp_list | `Ok of 'b t ])
                    Hashtbl_intf.create_options_without_hashable
                  val create_with_key :
                    (key, 'r,
                     get_key:('r -> key) ->
                     'r sexp_list ->
                     [ `Duplicate_keys of key sexp_list | `Ok of 'r t ])
                    Hashtbl_intf.create_options_without_hashable
                  val create_with_key_or_error :
                    (key, 'r,
                     get_key:('r -> key) ->
                     'r sexp_list -> 'r t Base.Or_error.t)
                    Hashtbl_intf.create_options_without_hashable
                  val create_with_key_exn :
                    (key, 'r, get_key:('r -> key) -> 'r sexp_list -> 'r t)
                    Hashtbl_intf.create_options_without_hashable
                  val group :
                    (key, 'b,
                     get_key:('r -> key) ->
                     get_data:('r -> 'b) ->
                     combine:('b -> 'b -> 'b) -> 'r sexp_list -> 'b t)
                    Hashtbl_intf.create_options_without_hashable
                  val sexp_of_key : 'a t -> key -> Ppx_sexp_conv_lib.Sexp.t
                  val clear : 'a t -> unit
                  val copy : 'b t -> 'b t
                  val fold :
                    'b t ->
                    init:'c -> f:(key:key -> data:'b -> 'c -> 'c) -> 'c
                  val iter_keys : 'a t -> f:(key -> unit) -> unit
                  val iter : 'b t -> f:('b -> unit) -> unit
                  val iteri : 'b t -> f:(key:key -> data:'b -> unit) -> unit
                  val existsi :
                    'b t -> f:(key:key -> data:'b -> bool) -> bool
                  val exists : 'b t -> f:('b -> bool) -> bool
                  val for_alli :
                    'b t -> f:(key:key -> data:'b -> bool) -> bool
                  val for_all : 'b t -> f:('b -> bool) -> bool
                  val counti :
                    'b t -> f:(key:key -> data:'b -> bool) -> index
                  val count : 'b t -> f:('b -> bool) -> index
                  val length : 'a t -> index
                  val is_empty : 'a t -> bool
                  val mem : 'a t -> key -> bool
                  val remove : 'a t -> key -> unit
                  val set : 'b t -> key:key -> data:'b -> unit
                  val add :
                    'b t -> key:key -> data:'b -> [ `Duplicate | `Ok ]
                  val add_exn : 'b t -> key:key -> data:'b -> unit
                  val change :
                    'b t ->
                    key -> f:('b sexp_option -> 'b sexp_option) -> unit
                  val update :
                    'b t -> key -> f:('b sexp_option -> 'b) -> unit
                  val map : 'b t -> f:('b -> 'c) -> 'c t
                  val mapi : 'b t -> f:(key:key -> data:'b -> 'c) -> 'c t
                  val filter_map : 'b t -> f:('b -> 'c sexp_option) -> 'c t
                  val filter_mapi :
                    'b t -> f:(key:key -> data:'b -> 'c sexp_option) -> 'c t
                  val filter_keys : 'b t -> f:(key -> bool) -> 'b t
                  val filter : 'b t -> f:('b -> bool) -> 'b t
                  val filteri :
                    'b t -> f:(key:key -> data:'b -> bool) -> 'b t
                  val partition_map :
                    'b t ->
                    f:('b -> [ `Fst of 'c | `Snd of 'd ]) -> 'c t * 'd t
                  val partition_mapi :
                    'b t ->
                    f:(key:key -> data:'b -> [ `Fst of 'c | `Snd of 'd ]) ->
                    'c t * 'd t
                  val partition_tf : 'b t -> f:('b -> bool) -> 'b t * 'b t
                  val partitioni_tf :
                    'b t -> f:(key:key -> data:'b -> bool) -> 'b t * 'b t
                  val find_or_add : 'b t -> key -> default:(unit -> 'b) -> 'b
                  val findi_or_add : 'b t -> key -> default:(key -> 'b) -> 'b
                  val find : 'b t -> key -> 'b sexp_option
                  val find_exn : 'b t -> key -> 'b
                  val find_and_call :
                    'b t ->
                    key ->
                    if_found:('b -> 'c) -> if_not_found:(key -> 'c) -> 'c
                  val findi_and_call :
                    'b t ->
                    key ->
                    if_found:(key:key -> data:'b -> 'c) ->
                    if_not_found:(key -> 'c) -> 'c
                  val find_and_remove : 'b t -> key -> 'b sexp_option
                  val merge :
                    'a t ->
                    'b t ->
                    f:(key:key ->
                       [ `Both of 'a * 'b | `Left of 'a | `Right of 'b ] ->
                       'c sexp_option) ->
                    'c t
                  type 'a merge_into_action =
                    'a Addr.Table.merge_into_action =
                      Remove
                    | Set_to of 'a
                  val merge_into :
                    src:'a t ->
                    dst:'b t ->
                    f:(key:key ->
                       'a -> 'b sexp_option -> 'b merge_into_action) ->
                    unit
                  val keys : 'a t -> key sexp_list
                  val data : 'b t -> 'b sexp_list
                  val filter_keys_inplace : 'a t -> f:(key -> bool) -> unit
                  val filter_inplace : 'b t -> f:('b -> bool) -> unit
                  val filteri_inplace :
                    'b t -> f:(key:key -> data:'b -> bool) -> unit
                  val map_inplace : 'b t -> f:('b -> 'b) -> unit
                  val mapi_inplace :
                    'b t -> f:(key:key -> data:'b -> 'b) -> unit
                  val filter_map_inplace :
                    'b t -> f:('b -> 'b sexp_option) -> unit
                  val filter_mapi_inplace :
                    'b t -> f:(key:key -> data:'b -> 'b sexp_option) -> unit
                  val equal : 'b t -> 'b t -> ('b -> 'b -> bool) -> bool
                  val similar :
                    'b1 t -> 'b2 t -> ('b1 -> 'b2 -> bool) -> bool
                  val to_alist : 'b t -> (key * 'b) sexp_list
                  val validate :
                    name:(key -> string) ->
                    'b Validate.check -> 'b t Validate.check
                  val incr :
                    ?by:index ->
                    ?remove_if_zero:bool -> index t -> key -> unit
                  val decr :
                    ?by:index ->
                    ?remove_if_zero:bool -> index t -> key -> unit
                  val add_multi :
                    'b sexp_list t -> key:key -> data:'b -> unit
                  val remove_multi : 'a sexp_list t -> key -> unit
                  val find_multi : 'b sexp_list t -> key -> 'b sexp_list
                  module Provide_of_sexp :
                    functor
                      (Key : sig
                               val t_of_sexp :
                                 Ppx_sexp_conv_lib.Sexp.t -> key
                             end) ->
                      sig
                        val t_of_sexp :
                          (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__001_) ->
                          Ppx_sexp_conv_lib.Sexp.t -> 'v_x__001_ t
                      end
                  module Provide_bin_io :
                    functor
                      (Key : sig
                               val bin_t : key Bin_prot.Type_class.t
                               val bin_read_t : key Bin_prot.Read.reader
                               val __bin_read_t__ :
                                 (index -> key) Bin_prot.Read.reader
                               val bin_reader_t :
                                 key Bin_prot.Type_class.reader
                               val bin_size_t : key Bin_prot.Size.sizer
                               val bin_write_t : key Bin_prot.Write.writer
                               val bin_writer_t :
                                 key Bin_prot.Type_class.writer
                               val bin_shape_t : Bin_prot.Shape.t
                             end) ->
                      sig
                        val bin_t :
                          'a Bin_prot.Type_class.t ->
                          'a t Bin_prot.Type_class.t
                        val bin_read_t :
                          'a Bin_prot.Read.reader ->
                          'a t Bin_prot.Read.reader
                        val __bin_read_t__ :
                          'a Bin_prot.Read.reader ->
                          (index -> 'a t) Bin_prot.Read.reader
                        val bin_reader_t :
                          'a Bin_prot.Type_class.reader ->
                          'a t Bin_prot.Type_class.reader
                        val bin_size_t :
                          'a Bin_prot.Size.sizer -> 'a t Bin_prot.Size.sizer
                        val bin_write_t :
                          'a Bin_prot.Write.writer ->
                          'a t Bin_prot.Write.writer
                        val bin_writer_t :
                          'a Bin_prot.Type_class.writer ->
                          'a t Bin_prot.Type_class.writer
                        val bin_shape_t :
                          Bin_prot.Shape.t -> Bin_prot.Shape.t
                      end
                  val t_of_sexp :
                    (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_) ->
                    Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_ t
                end
              module Hash_set :
                sig
                  type elt = t
                  type t = elt Hash_set.t
                  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
                  type 'a t_ = t
                  type 'a elt_ = elt
                  val create :
                    ('a, unit -> t)
                    Base.Hash_set.create_options_without_first_class_module
                  val of_list :
                    ('a, elt sexp_list -> t)
                    Base.Hash_set.create_options_without_first_class_module
                  module Provide_of_sexp :
                    functor
                      (X : sig
                             val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> elt
                           end) ->
                      sig val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t end
                  module Provide_bin_io :
                    functor
                      (X : sig
                             val bin_t : elt Bin_prot.Type_class.t
                             val bin_read_t : elt Bin_prot.Read.reader
                             val __bin_read_t__ :
                               (index -> elt) Bin_prot.Read.reader
                             val bin_reader_t :
                               elt Bin_prot.Type_class.reader
                             val bin_size_t : elt Bin_prot.Size.sizer
                             val bin_write_t : elt Bin_prot.Write.writer
                             val bin_writer_t :
                               elt Bin_prot.Type_class.writer
                             val bin_shape_t : Bin_prot.Shape.t
                           end) ->
                      sig
                        val bin_t : t Bin_prot.Type_class.t
                        val bin_read_t : t Bin_prot.Read.reader
                        val __bin_read_t__ :
                          (index -> t) Bin_prot.Read.reader
                        val bin_reader_t : t Bin_prot.Type_class.reader
                        val bin_size_t : t Bin_prot.Size.sizer
                        val bin_write_t : t Bin_prot.Write.writer
                        val bin_writer_t : t Bin_prot.Type_class.writer
                        val bin_shape_t : Bin_prot.Shape.t
                      end
                  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
                end
              module Hash_queue :
                sig
                  module Key :
                    sig
                      type t = Hash_set.elt
                      val compare : t -> t -> index
                      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
                      val hash : t -> index
                    end
                  type 'a t = 'a Addr.Hash_queue.t
                  val sexp_of_t :
                    ('a -> Ppx_sexp_conv_lib.Sexp.t) ->
                    'a t -> Ppx_sexp_conv_lib.Sexp.t
                  val length : 'a t -> index
                  val is_empty : 'a t -> bool
                  val iter : 'a t -> f:('a -> unit) -> unit
                  val fold :
                    'a t ->
                    init:'accum -> f:('accum -> 'a -> 'accum) -> 'accum
                  val fold_result :
                    'a t ->
                    init:'accum ->
                    f:('accum -> 'a -> ('accum, 'e) result) ->
                    ('accum, 'e) result
                  val fold_until :
                    'a t ->
                    init:'accum ->
                    f:('accum ->
                       'a -> ('accum, 'final) Base.Continue_or_stop.t) ->
                    finish:('accum -> 'final) -> 'final
                  val exists : 'a t -> f:('a -> bool) -> bool
                  val for_all : 'a t -> f:('a -> bool) -> bool
                  val count : 'a t -> f:('a -> bool) -> index
                  val sum :
                    (module Commutative_group.S with type t = 'sum) ->
                    'a t -> f:('a -> 'sum) -> 'sum
                  val find : 'a t -> f:('a -> bool) -> 'a sexp_option
                  val find_map :
                    'a t -> f:('a -> 'b sexp_option) -> 'b sexp_option
                  val to_list : 'a t -> 'a sexp_list
                  val to_array : 'a t -> 'a array
                  val min_elt :
                    'a t -> compare:('a -> 'a -> index) -> 'a sexp_option
                  val max_elt :
                    'a t -> compare:('a -> 'a -> index) -> 'a sexp_option
                  val invariant : 'a t -> unit
                  val create :
                    ?growth_allowed:sexp_bool -> ?size:index -> unit -> 'a t
                  val clear : 'a t -> unit
                  val mem : 'a t -> Key.t -> sexp_bool
                  val lookup : 'a t -> Key.t -> 'a sexp_option
                  val lookup_exn : 'a t -> Key.t -> 'a
                  val enqueue :
                    'a t -> Key.t -> 'a -> [ `Key_already_present | `Ok ]
                  val enqueue_exn : 'a t -> Key.t -> 'a -> unit
                  val lookup_and_move_to_back :
                    'a t -> Key.t -> 'a sexp_option
                  val lookup_and_move_to_back_exn : 'a t -> Key.t -> 'a
                  val first : 'a t -> 'a sexp_option
                  val first_with_key : 'a t -> (Key.t * 'a) sexp_option
                  val keys : 'a t -> Key.t sexp_list
                  val dequeue : 'a t -> 'a sexp_option
                  val dequeue_exn : 'a t -> 'a
                  val dequeue_with_key : 'a t -> (Key.t * 'a) sexp_option
                  val dequeue_with_key_exn : 'a t -> Key.t * 'a
                  val dequeue_all : 'a t -> f:('a -> unit) -> unit
                  val remove : 'a t -> Key.t -> [ `No_such_key | `Ok ]
                  val remove_exn : 'a t -> Key.t -> unit
                  val replace : 'a t -> Key.t -> 'a -> [ `No_such_key | `Ok ]
                  val replace_exn : 'a t -> Key.t -> 'a -> unit
                  val iteri :
                    'a t -> f:(key:Key.t -> data:'a -> unit) -> unit
                  val foldi :
                    'a t ->
                    init:'b -> f:('b -> key:Key.t -> data:'a -> 'b) -> 'b
                end
              val of_byte_string : string -> t
              val of_directions : Direction.t sexp_list -> t
              val root : unit -> t
              val slice : t -> index -> index -> t
              val get : t -> index -> index
              val copy : t -> t
              val parent : t -> t Or_error.t
              val child : t -> Direction.t -> t Or_error.t
              val child_exn : t -> Direction.t -> t
              val parent_exn : t -> t
              val dirs_from_root : t -> Direction.t sexp_list
              val sibling : t -> t
              val next : t -> t sexp_option
              val is_parent_of : t -> maybe_child:t -> bool
              val serialize : t -> Bigstring.t
              val to_string : t -> string
              val pp : Format.formatter -> t -> unit
              module Range :
                sig
                  type nonrec t = t * t
                  val fold :
                    ?stop:[ `Exclusive | `Inclusive ] ->
                    t -> init:'a -> f:(Hash_set.elt -> 'a -> 'a) -> 'a
                  val subtree_range : Hash_set.elt -> t
                end
              val depth : t -> index
              val height : t -> index
              val to_int : t -> index
              val of_int_exn : index -> t
            end
          module Prefix :
            sig
              val generic : Unsigned.UInt8.t
              val account : Unsigned.UInt8.t
              val hash : index -> Unsigned.UInt8.t
            end
          type t =
            Location_at_depth.t =
              Generic of Bigstring.t
            | Account of Addr.t
            | Hash of Addr.t
          val equal : t -> t -> bool
          val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
          val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
          val bin_t : t Bin_prot.Type_class.t
          val bin_read_t : t Bin_prot.Read.reader
          val __bin_read_t__ : (index -> t) Bin_prot.Read.reader
          val bin_reader_t : t Bin_prot.Type_class.reader
          val bin_size_t : t Bin_prot.Size.sizer
          val bin_write_t : t Bin_prot.Write.writer
          val bin_writer_t : t Bin_prot.Type_class.writer
          val bin_shape_t : Bin_prot.Shape.t
          val compare : t -> t -> index
          val hash_fold_t : Base.Hash.state -> t -> Base.Hash.state
          val hash : t -> index
          val hashable : t Hashtbl_intf.Hashable.t
          module Table :
            sig
              type key = t
              type ('a, 'b) hashtbl = ('a, 'b) Hashtbl_intf.Hashtbl.t
              type 'b t = (key, 'b) hashtbl
              val sexp_of_t :
                ('b -> Ppx_sexp_conv_lib.Sexp.t) ->
                'b t -> Ppx_sexp_conv_lib.Sexp.t
              type ('a, 'b) t_ = 'b t
              type 'a key_ = key
              val hashable : key Hashtbl_intf.Hashable.t
              val invariant :
                'a Base__Invariant_intf.t -> 'a t Base__Invariant_intf.t
              val create :
                (key, 'b, unit -> 'b t)
                Hashtbl_intf.create_options_without_hashable
              val of_alist :
                (key, 'b,
                 (key * 'b) sexp_list ->
                 [ `Duplicate_key of key | `Ok of 'b t ])
                Hashtbl_intf.create_options_without_hashable
              val of_alist_report_all_dups :
                (key, 'b,
                 (key * 'b) sexp_list ->
                 [ `Duplicate_keys of key sexp_list | `Ok of 'b t ])
                Hashtbl_intf.create_options_without_hashable
              val of_alist_or_error :
                (key, 'b, (key * 'b) sexp_list -> 'b t Base.Or_error.t)
                Hashtbl_intf.create_options_without_hashable
              val of_alist_exn :
                (key, 'b, (key * 'b) sexp_list -> 'b t)
                Hashtbl_intf.create_options_without_hashable
              val of_alist_multi :
                (key, 'b sexp_list, (key * 'b) sexp_list -> 'b sexp_list t)
                Hashtbl_intf.create_options_without_hashable
              val create_mapped :
                (key, 'b,
                 get_key:('r -> key) ->
                 get_data:('r -> 'b) ->
                 'r sexp_list ->
                 [ `Duplicate_keys of key sexp_list | `Ok of 'b t ])
                Hashtbl_intf.create_options_without_hashable
              val create_with_key :
                (key, 'r,
                 get_key:('r -> key) ->
                 'r sexp_list ->
                 [ `Duplicate_keys of key sexp_list | `Ok of 'r t ])
                Hashtbl_intf.create_options_without_hashable
              val create_with_key_or_error :
                (key, 'r,
                 get_key:('r -> key) -> 'r sexp_list -> 'r t Base.Or_error.t)
                Hashtbl_intf.create_options_without_hashable
              val create_with_key_exn :
                (key, 'r, get_key:('r -> key) -> 'r sexp_list -> 'r t)
                Hashtbl_intf.create_options_without_hashable
              val group :
                (key, 'b,
                 get_key:('r -> key) ->
                 get_data:('r -> 'b) ->
                 combine:('b -> 'b -> 'b) -> 'r sexp_list -> 'b t)
                Hashtbl_intf.create_options_without_hashable
              val sexp_of_key : 'a t -> key -> Ppx_sexp_conv_lib.Sexp.t
              val clear : 'a t -> unit
              val copy : 'b t -> 'b t
              val fold :
                'b t -> init:'c -> f:(key:key -> data:'b -> 'c -> 'c) -> 'c
              val iter_keys : 'a t -> f:(key -> unit) -> unit
              val iter : 'b t -> f:('b -> unit) -> unit
              val iteri : 'b t -> f:(key:key -> data:'b -> unit) -> unit
              val existsi : 'b t -> f:(key:key -> data:'b -> bool) -> bool
              val exists : 'b t -> f:('b -> bool) -> bool
              val for_alli : 'b t -> f:(key:key -> data:'b -> bool) -> bool
              val for_all : 'b t -> f:('b -> bool) -> bool
              val counti : 'b t -> f:(key:key -> data:'b -> bool) -> index
              val count : 'b t -> f:('b -> bool) -> index
              val length : 'a t -> index
              val is_empty : 'a t -> bool
              val mem : 'a t -> key -> bool
              val remove : 'a t -> key -> unit
              val set : 'b t -> key:key -> data:'b -> unit
              val add : 'b t -> key:key -> data:'b -> [ `Duplicate | `Ok ]
              val add_exn : 'b t -> key:key -> data:'b -> unit
              val change :
                'b t -> key -> f:('b sexp_option -> 'b sexp_option) -> unit
              val update : 'b t -> key -> f:('b sexp_option -> 'b) -> unit
              val map : 'b t -> f:('b -> 'c) -> 'c t
              val mapi : 'b t -> f:(key:key -> data:'b -> 'c) -> 'c t
              val filter_map : 'b t -> f:('b -> 'c sexp_option) -> 'c t
              val filter_mapi :
                'b t -> f:(key:key -> data:'b -> 'c sexp_option) -> 'c t
              val filter_keys : 'b t -> f:(key -> bool) -> 'b t
              val filter : 'b t -> f:('b -> bool) -> 'b t
              val filteri : 'b t -> f:(key:key -> data:'b -> bool) -> 'b t
              val partition_map :
                'b t -> f:('b -> [ `Fst of 'c | `Snd of 'd ]) -> 'c t * 'd t
              val partition_mapi :
                'b t ->
                f:(key:key -> data:'b -> [ `Fst of 'c | `Snd of 'd ]) ->
                'c t * 'd t
              val partition_tf : 'b t -> f:('b -> bool) -> 'b t * 'b t
              val partitioni_tf :
                'b t -> f:(key:key -> data:'b -> bool) -> 'b t * 'b t
              val find_or_add : 'b t -> key -> default:(unit -> 'b) -> 'b
              val findi_or_add : 'b t -> key -> default:(key -> 'b) -> 'b
              val find : 'b t -> key -> 'b sexp_option
              val find_exn : 'b t -> key -> 'b
              val find_and_call :
                'b t ->
                key -> if_found:('b -> 'c) -> if_not_found:(key -> 'c) -> 'c
              val findi_and_call :
                'b t ->
                key ->
                if_found:(key:key -> data:'b -> 'c) ->
                if_not_found:(key -> 'c) -> 'c
              val find_and_remove : 'b t -> key -> 'b sexp_option
              val merge :
                'a t ->
                'b t ->
                f:(key:key ->
                   [ `Both of 'a * 'b | `Left of 'a | `Right of 'b ] ->
                   'c sexp_option) ->
                'c t
              type 'a merge_into_action =
                'a Location_at_depth.Table.merge_into_action =
                  Remove
                | Set_to of 'a
              val merge_into :
                src:'a t ->
                dst:'b t ->
                f:(key:key -> 'a -> 'b sexp_option -> 'b merge_into_action) ->
                unit
              val keys : 'a t -> key sexp_list
              val data : 'b t -> 'b sexp_list
              val filter_keys_inplace : 'a t -> f:(key -> bool) -> unit
              val filter_inplace : 'b t -> f:('b -> bool) -> unit
              val filteri_inplace :
                'b t -> f:(key:key -> data:'b -> bool) -> unit
              val map_inplace : 'b t -> f:('b -> 'b) -> unit
              val mapi_inplace : 'b t -> f:(key:key -> data:'b -> 'b) -> unit
              val filter_map_inplace :
                'b t -> f:('b -> 'b sexp_option) -> unit
              val filter_mapi_inplace :
                'b t -> f:(key:key -> data:'b -> 'b sexp_option) -> unit
              val equal : 'b t -> 'b t -> ('b -> 'b -> bool) -> bool
              val similar : 'b1 t -> 'b2 t -> ('b1 -> 'b2 -> bool) -> bool
              val to_alist : 'b t -> (key * 'b) sexp_list
              val validate :
                name:(key -> string) ->
                'b Validate.check -> 'b t Validate.check
              val incr :
                ?by:index -> ?remove_if_zero:bool -> index t -> key -> unit
              val decr :
                ?by:index -> ?remove_if_zero:bool -> index t -> key -> unit
              val add_multi : 'b sexp_list t -> key:key -> data:'b -> unit
              val remove_multi : 'a sexp_list t -> key -> unit
              val find_multi : 'b sexp_list t -> key -> 'b sexp_list
              module Provide_of_sexp :
                functor
                  (Key : sig
                           val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> key
                         end) ->
                  sig
                    val t_of_sexp :
                      (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__001_) ->
                      Ppx_sexp_conv_lib.Sexp.t -> 'v_x__001_ t
                  end
              module Provide_bin_io :
                functor
                  (Key : sig
                           val bin_t : key Bin_prot.Type_class.t
                           val bin_read_t : key Bin_prot.Read.reader
                           val __bin_read_t__ :
                             (index -> key) Bin_prot.Read.reader
                           val bin_reader_t : key Bin_prot.Type_class.reader
                           val bin_size_t : key Bin_prot.Size.sizer
                           val bin_write_t : key Bin_prot.Write.writer
                           val bin_writer_t : key Bin_prot.Type_class.writer
                           val bin_shape_t : Bin_prot.Shape.t
                         end) ->
                  sig
                    val bin_t :
                      'a Bin_prot.Type_class.t -> 'a t Bin_prot.Type_class.t
                    val bin_read_t :
                      'a Bin_prot.Read.reader -> 'a t Bin_prot.Read.reader
                    val __bin_read_t__ :
                      'a Bin_prot.Read.reader ->
                      (index -> 'a t) Bin_prot.Read.reader
                    val bin_reader_t :
                      'a Bin_prot.Type_class.reader ->
                      'a t Bin_prot.Type_class.reader
                    val bin_size_t :
                      'a Bin_prot.Size.sizer -> 'a t Bin_prot.Size.sizer
                    val bin_write_t :
                      'a Bin_prot.Write.writer -> 'a t Bin_prot.Write.writer
                    val bin_writer_t :
                      'a Bin_prot.Type_class.writer ->
                      'a t Bin_prot.Type_class.writer
                    val bin_shape_t : Bin_prot.Shape.t -> Bin_prot.Shape.t
                  end
              val t_of_sexp :
                (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_) ->
                Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_ t
            end
          module Hash_set :
            sig
              type elt = t
              type t = elt Hash_set.t
              val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
              type 'a t_ = t
              type 'a elt_ = elt
              val create :
                ('a, unit -> t)
                Base.Hash_set.create_options_without_first_class_module
              val of_list :
                ('a, elt sexp_list -> t)
                Base.Hash_set.create_options_without_first_class_module
              module Provide_of_sexp :
                functor
                  (X : sig
                         val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> elt
                       end) ->
                  sig val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t end
              module Provide_bin_io :
                functor
                  (X : sig
                         val bin_t : elt Bin_prot.Type_class.t
                         val bin_read_t : elt Bin_prot.Read.reader
                         val __bin_read_t__ :
                           (index -> elt) Bin_prot.Read.reader
                         val bin_reader_t : elt Bin_prot.Type_class.reader
                         val bin_size_t : elt Bin_prot.Size.sizer
                         val bin_write_t : elt Bin_prot.Write.writer
                         val bin_writer_t : elt Bin_prot.Type_class.writer
                         val bin_shape_t : Bin_prot.Shape.t
                       end) ->
                  sig
                    val bin_t : t Bin_prot.Type_class.t
                    val bin_read_t : t Bin_prot.Read.reader
                    val __bin_read_t__ : (index -> t) Bin_prot.Read.reader
                    val bin_reader_t : t Bin_prot.Type_class.reader
                    val bin_size_t : t Bin_prot.Size.sizer
                    val bin_write_t : t Bin_prot.Write.writer
                    val bin_writer_t : t Bin_prot.Type_class.writer
                    val bin_shape_t : Bin_prot.Shape.t
                  end
              val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
            end
          module Hash_queue :
            sig
              module Key :
                sig
                  type t = Location_at_depth.t
                  val compare : t -> t -> index
                  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
                  val hash : t -> index
                end
              type 'a t = 'a Location_at_depth.Hash_queue.t
              val sexp_of_t :
                ('a -> Ppx_sexp_conv_lib.Sexp.t) ->
                'a t -> Ppx_sexp_conv_lib.Sexp.t
              val length : 'a t -> index
              val is_empty : 'a t -> bool
              val iter : 'a t -> f:('a -> unit) -> unit
              val fold :
                'a t -> init:'accum -> f:('accum -> 'a -> 'accum) -> 'accum
              val fold_result :
                'a t ->
                init:'accum ->
                f:('accum -> 'a -> ('accum, 'e) result) ->
                ('accum, 'e) result
              val fold_until :
                'a t ->
                init:'accum ->
                f:('accum -> 'a -> ('accum, 'final) Base.Continue_or_stop.t) ->
                finish:('accum -> 'final) -> 'final
              val exists : 'a t -> f:('a -> bool) -> bool
              val for_all : 'a t -> f:('a -> bool) -> bool
              val count : 'a t -> f:('a -> bool) -> index
              val sum :
                (module Commutative_group.S with type t = 'sum) ->
                'a t -> f:('a -> 'sum) -> 'sum
              val find : 'a t -> f:('a -> bool) -> 'a sexp_option
              val find_map :
                'a t -> f:('a -> 'b sexp_option) -> 'b sexp_option
              val to_list : 'a t -> 'a sexp_list
              val to_array : 'a t -> 'a array
              val min_elt :
                'a t -> compare:('a -> 'a -> index) -> 'a sexp_option
              val max_elt :
                'a t -> compare:('a -> 'a -> index) -> 'a sexp_option
              val invariant : 'a t -> unit
              val create :
                ?growth_allowed:sexp_bool -> ?size:index -> unit -> 'a t
              val clear : 'a t -> unit
              val mem : 'a t -> Location_at_depth.t -> sexp_bool
              val lookup : 'a t -> Location_at_depth.t -> 'a sexp_option
              val lookup_exn : 'a t -> Location_at_depth.t -> 'a
              val enqueue :
                'a t ->
                Location_at_depth.t -> 'a -> [ `Key_already_present | `Ok ]
              val enqueue_exn : 'a t -> Location_at_depth.t -> 'a -> unit
              val lookup_and_move_to_back :
                'a t -> Location_at_depth.t -> 'a sexp_option
              val lookup_and_move_to_back_exn :
                'a t -> Location_at_depth.t -> 'a
              val first : 'a t -> 'a sexp_option
              val first_with_key :
                'a t -> (Location_at_depth.t * 'a) sexp_option
              val keys : 'a t -> Location_at_depth.t sexp_list
              val dequeue : 'a t -> 'a sexp_option
              val dequeue_exn : 'a t -> 'a
              val dequeue_with_key :
                'a t -> (Location_at_depth.t * 'a) sexp_option
              val dequeue_with_key_exn : 'a t -> Location_at_depth.t * 'a
              val dequeue_all : 'a t -> f:('a -> unit) -> unit
              val remove :
                'a t -> Location_at_depth.t -> [ `No_such_key | `Ok ]
              val remove_exn : 'a t -> Location_at_depth.t -> unit
              val replace :
                'a t -> Location_at_depth.t -> 'a -> [ `No_such_key | `Ok ]
              val replace_exn : 'a t -> Location_at_depth.t -> 'a -> unit
              val iteri :
                'a t ->
                f:(key:Location_at_depth.t -> data:'a -> unit) -> unit
              val foldi :
                'a t ->
                init:'b ->
                f:('b -> key:Location_at_depth.t -> data:'a -> 'b) -> 'b
            end
          val is_generic : t -> bool
          val is_account : t -> bool
          val is_hash : t -> bool
          val height : t -> index
          val root_hash : t
          val last_direction : Addr.t -> Direction.t
          val build_generic : Bigstring.t -> t
          val parse : Bigstring.t -> (t, unit) result
          val prefix_bigstring :
            Unsigned.UInt8.t -> Bigstring.t -> Bigstring.t
          val to_path_exn : t -> Addr.t
          val serialize : t -> Bigstring.t
          val parent : t -> t
          val next : t -> t sexp_option
          val sibling : t -> t
          val order_siblings : t -> 'a -> 'a -> 'a * 'a
        end
      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
      type path = Path.t
      val depth : index
      val num_accounts : t -> index
      val merkle_path_at_addr_exn : t -> Addr.t -> path
      val get_inner_hash_at_addr_exn : t -> Addr.t -> Ledger_hash.t
      val set_inner_hash_at_addr_exn : t -> Addr.t -> Ledger_hash.t -> unit
      val set_all_accounts_rooted_at_exn :
        t -> Addr.t -> Account.t sexp_list -> unit
      val get_all_accounts_rooted_at_exn : t -> Addr.t -> Account.t sexp_list
      val make_space_for : t -> index -> unit
      val to_list : t -> Account.t sexp_list
      val foldi :
        t ->
        init:'accum -> f:(Addr.t -> 'accum -> Account.t -> 'accum) -> 'accum
      val fold_until :
        t ->
        init:'accum ->
        f:('accum -> Account.t -> ('accum, 'stop) Base.Continue_or_stop.t) ->
        finish:('accum -> 'stop) -> 'stop
      val location_of_key : t -> Key.t -> Location_at_depth.t sexp_option
      val get_or_create_account :
        t ->
        Key.t ->
        Account.t -> ([ `Added | `Existed ] * Location_at_depth.t) Or_error.t
      val get_or_create_account_exn :
        t ->
        Key.t -> Account.t -> [ `Added | `Existed ] * Location_at_depth.t
      val destroy : t -> unit
      val get_uuid : t -> Uuid.t
      val get : t -> Location_at_depth.t -> Account.t sexp_option
      val set : t -> Location_at_depth.t -> Account.t -> unit
      val set_batch :
        t -> (Location_at_depth.t * Account.t) sexp_list -> unit
      val get_at_index_exn : t -> index -> Account.t
      val set_at_index_exn : t -> index -> Account.t -> unit
      val index_of_key_exn : t -> Key.t -> index
      val merkle_root : t -> Ledger_hash.t
      val merkle_path : t -> Location_at_depth.t -> path
      val merkle_path_at_index_exn : t -> index -> path
      val remove_accounts_exn : t -> Key.t sexp_list -> unit
    end
end

include
  Merkle_ledger.Base_ledger_intf.S
  with module Location := Location
  with type root_hash := Ledger_hash.t
   and type hash := Ledger_hash.t
   and type account := Account.t
   and type key := Public_key.Compressed.t

val with_ledger : f:(t -> 'a) -> 'a

val create : ?directory_name:string -> unit -> t

(** This is not _really_ copy, merely a stop-gap until we remove usages of copy in our codebase. What this actually does is creates a new empty mask on top of the current ledger *)
val copy : t -> t

val register_mask : t -> Mask.t -> Mask.Attached.t
  
module Undo : sig
  module User_command : sig
    module Common : sig
      type t =
        { user_command: User_command.t
        ; previous_receipt_chain_hash: Receipt.Chain_hash.t }
    end

    module Body : sig
      type t =
        | Payment of {previous_empty_accounts: Public_key.Compressed.t list}
        | Stake_delegation of {previous_delegate: Public_key.Compressed.t}
    end

    type t = {common: Common.t; body: Body.t} [@@deriving sexp, bin_io]
  end

  type fee_transfer =
    { fee_transfer: Fee_transfer.t
    ; previous_empty_accounts: Public_key.Compressed.t list }
  [@@deriving sexp, bin_io]

  type coinbase =
    { coinbase: Coinbase.t
    ; previous_empty_accounts: Public_key.Compressed.t list }
  [@@deriving sexp, bin_io]

  type varying =
    | User_command of User_command.t
    | Fee_transfer of fee_transfer
    | Coinbase of coinbase
  [@@deriving sexp, bin_io]

  type t = {previous_hash: Ledger_hash.t; varying: varying}
  [@@deriving sexp, bin_io]

  val transaction : t -> Transaction.t Or_error.t
end

val create_new_account_exn : t -> Public_key.Compressed.t -> Account.t -> unit

val apply_user_command :
  t -> User_command.With_valid_signature.t -> Undo.User_command.t Or_error.t

val apply_transaction : t -> Transaction.t -> Undo.t Or_error.t

val undo : t -> Undo.t -> unit Or_error.t

val merkle_root_after_user_command_exn :
  t -> User_command.With_valid_signature.t -> Ledger_hash.t

val create_empty : t -> Public_key.Compressed.t -> Path.t * Account.t

val num_accounts : t -> int
