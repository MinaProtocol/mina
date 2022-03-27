module Stable : sig
  module V1 : sig
    type t =
      { fee : Currency.Fee.Stable.V1.t
      ; prover : Signature_lib.Public_key.Compressed.Stable.V1.t
      }

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val version : int

    val __versioned__ : unit

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

    val to_latest : 'a -> 'a

    module T : sig
      type typ = t

      val typ_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> typ

      val sexp_of_typ : typ -> Ppx_sexp_conv_lib.Sexp.t

      type t = typ

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> typ

      val sexp_of_t : typ -> Ppx_sexp_conv_lib.Sexp.t

      val compare : typ -> typ -> int
    end

    val ( >= ) : t -> t -> bool

    val ( <= ) : t -> t -> bool

    val ( = ) : t -> t -> bool

    val ( > ) : t -> t -> bool

    val ( < ) : t -> t -> bool

    val ( <> ) : t -> t -> bool

    val equal : t -> t -> bool

    val compare : t -> t -> int

    val min : t -> t -> t

    val max : t -> t -> t

    val ascending : t -> t -> int

    val descending : t -> t -> int

    val between : t -> low:t -> high:t -> bool

    val clamp_exn : t -> min:t -> max:t -> t

    val clamp : t -> min:t -> max:t -> t Base__.Or_error.t

    type comparator_witness = Core_kernel__Comparable.Make(T).comparator_witness

    val comparator : (t, comparator_witness) Base__.Comparator.comparator

    val validate_lbound : min:t Base__.Maybe_bound.t -> t Base__.Validate.check

    val validate_ubound : max:t Base__.Maybe_bound.t -> t Base__.Validate.check

    val validate_bound :
         min:t Base__.Maybe_bound.t
      -> max:t Base__.Maybe_bound.t
      -> t Base__.Validate.check

    module Replace_polymorphic_compare : sig
      val ( >= ) : t -> t -> bool

      val ( <= ) : t -> t -> bool

      val ( = ) : t -> t -> bool

      val ( > ) : t -> t -> bool

      val ( < ) : t -> t -> bool

      val ( <> ) : t -> t -> bool

      val equal : t -> t -> bool

      val compare : t -> t -> int

      val min : t -> t -> t

      val max : t -> t -> t
    end

    module Map : sig
      module Key : sig
        type t = T.typ

        val t_of_sexp : Sexplib0.Sexp.t -> t

        val sexp_of_t : t -> Sexplib0.Sexp.t

        type comparator_witness =
          Core_kernel__Comparable.Make(T).comparator_witness

        val comparator :
          (t, comparator_witness) Core_kernel__.Comparator.comparator
      end

      module Tree : sig
        type 'a t =
          (T.typ, 'a, comparator_witness) Core_kernel__.Map_intf.Tree.t

        val empty : 'a t

        val singleton : T.typ -> 'a -> 'a t

        val of_alist :
          (T.typ * 'a) list -> [ `Duplicate_key of T.typ | `Ok of 'a t ]

        val of_alist_or_error : (T.typ * 'a) list -> 'a t Base__.Or_error.t

        val of_alist_exn : (T.typ * 'a) list -> 'a t

        val of_alist_multi : (T.typ * 'a) list -> 'a list t

        val of_alist_fold :
          (T.typ * 'a) list -> init:'b -> f:('b -> 'a -> 'b) -> 'b t

        val of_alist_reduce : (T.typ * 'a) list -> f:('a -> 'a -> 'a) -> 'a t

        val of_sorted_array : (T.typ * 'a) array -> 'a t Base__.Or_error.t

        val of_sorted_array_unchecked : (T.typ * 'a) array -> 'a t

        val of_increasing_iterator_unchecked :
          len:int -> f:(int -> T.typ * 'a) -> 'a t

        val of_increasing_sequence :
          (T.typ * 'a) Base__.Sequence.t -> 'a t Base__.Or_error.t

        val of_sequence :
             (T.typ * 'a) Base__.Sequence.t
          -> [ `Duplicate_key of T.typ | `Ok of 'a t ]

        val of_sequence_or_error :
          (T.typ * 'a) Base__.Sequence.t -> 'a t Base__.Or_error.t

        val of_sequence_exn : (T.typ * 'a) Base__.Sequence.t -> 'a t

        val of_sequence_multi : (T.typ * 'a) Base__.Sequence.t -> 'a list t

        val of_sequence_fold :
             (T.typ * 'a) Base__.Sequence.t
          -> init:'b
          -> f:('b -> 'a -> 'b)
          -> 'b t

        val of_sequence_reduce :
          (T.typ * 'a) Base__.Sequence.t -> f:('a -> 'a -> 'a) -> 'a t

        val of_iteri :
             iteri:(f:(key:T.typ -> data:'v -> unit) -> unit)
          -> [ `Duplicate_key of T.typ | `Ok of 'v t ]

        val of_tree : 'a t -> 'a t

        val of_hashtbl_exn : (T.typ, 'a) Core_kernel__.Hashtbl.t -> 'a t

        val of_key_set :
          (T.typ, comparator_witness) Base.Set.t -> f:(T.typ -> 'v) -> 'v t

        val quickcheck_generator :
             T.typ Core_kernel__.Quickcheck.Generator.t
          -> 'a Core_kernel__.Quickcheck.Generator.t
          -> 'a t Core_kernel__.Quickcheck.Generator.t

        val invariants : 'a t -> bool

        val is_empty : 'a t -> bool

        val length : 'a t -> int

        val add :
          'a t -> key:T.typ -> data:'a -> 'a t Base__.Map_intf.Or_duplicate.t

        val add_exn : 'a t -> key:T.typ -> data:'a -> 'a t

        val set : 'a t -> key:T.typ -> data:'a -> 'a t

        val add_multi : 'a list t -> key:T.typ -> data:'a -> 'a list t

        val remove_multi : 'a list t -> T.typ -> 'a list t

        val find_multi : 'a list t -> T.typ -> 'a list

        val change : 'a t -> T.typ -> f:('a option -> 'a option) -> 'a t

        val update : 'a t -> T.typ -> f:('a option -> 'a) -> 'a t

        val find : 'a t -> T.typ -> 'a option

        val find_exn : 'a t -> T.typ -> 'a

        val remove : 'a t -> T.typ -> 'a t

        val mem : 'a t -> T.typ -> bool

        val iter_keys : 'a t -> f:(T.typ -> unit) -> unit

        val iter : 'a t -> f:('a -> unit) -> unit

        val iteri : 'a t -> f:(key:T.typ -> data:'a -> unit) -> unit

        val iteri_until :
             'a t
          -> f:(key:T.typ -> data:'a -> Base__.Map_intf.Continue_or_stop.t)
          -> Base__.Map_intf.Finished_or_unfinished.t

        val iter2 :
             'a t
          -> 'b t
          -> f:
               (   key:T.typ
                -> data:[ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
                -> unit)
          -> unit

        val map : 'a t -> f:('a -> 'b) -> 'b t

        val mapi : 'a t -> f:(key:T.typ -> data:'a -> 'b) -> 'b t

        val fold : 'a t -> init:'b -> f:(key:T.typ -> data:'a -> 'b -> 'b) -> 'b

        val fold_right :
          'a t -> init:'b -> f:(key:T.typ -> data:'a -> 'b -> 'b) -> 'b

        val fold2 :
             'a t
          -> 'b t
          -> init:'c
          -> f:
               (   key:T.typ
                -> data:[ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
                -> 'c
                -> 'c)
          -> 'c

        val filter_keys : 'a t -> f:(T.typ -> bool) -> 'a t

        val filter : 'a t -> f:('a -> bool) -> 'a t

        val filteri : 'a t -> f:(key:T.typ -> data:'a -> bool) -> 'a t

        val filter_map : 'a t -> f:('a -> 'b option) -> 'b t

        val filter_mapi : 'a t -> f:(key:T.typ -> data:'a -> 'b option) -> 'b t

        val partition_mapi :
             'a t
          -> f:(key:T.typ -> data:'a -> [ `Fst of 'b | `Snd of 'c ])
          -> 'b t * 'c t

        val partition_map :
          'a t -> f:('a -> [ `Fst of 'b | `Snd of 'c ]) -> 'b t * 'c t

        val partitioni_tf :
          'a t -> f:(key:T.typ -> data:'a -> bool) -> 'a t * 'a t

        val partition_tf : 'a t -> f:('a -> bool) -> 'a t * 'a t

        val compare_direct : ('a -> 'a -> int) -> 'a t -> 'a t -> int

        val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

        val keys : 'a t -> T.typ list

        val data : 'a t -> 'a list

        val to_alist :
          ?key_order:[ `Decreasing | `Increasing ] -> 'a t -> (T.typ * 'a) list

        val validate :
             name:(T.typ -> string)
          -> 'a Base__.Validate.check
          -> 'a t Base__.Validate.check

        val merge :
             'a t
          -> 'b t
          -> f:
               (   key:T.typ
                -> [ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
                -> 'c option)
          -> 'c t

        val symmetric_diff :
             'a t
          -> 'a t
          -> data_equal:('a -> 'a -> bool)
          -> (T.typ, 'a) Base__.Map_intf.Symmetric_diff_element.t
             Base__.Sequence.t

        val fold_symmetric_diff :
             'a t
          -> 'a t
          -> data_equal:('a -> 'a -> bool)
          -> init:'c
          -> f:
               (   'c
                -> (T.typ, 'a) Base__.Map_intf.Symmetric_diff_element.t
                -> 'c)
          -> 'c

        val min_elt : 'a t -> (T.typ * 'a) option

        val min_elt_exn : 'a t -> T.typ * 'a

        val max_elt : 'a t -> (T.typ * 'a) option

        val max_elt_exn : 'a t -> T.typ * 'a

        val for_all : 'a t -> f:('a -> bool) -> bool

        val for_alli : 'a t -> f:(key:T.typ -> data:'a -> bool) -> bool

        val exists : 'a t -> f:('a -> bool) -> bool

        val existsi : 'a t -> f:(key:T.typ -> data:'a -> bool) -> bool

        val count : 'a t -> f:('a -> bool) -> int

        val counti : 'a t -> f:(key:T.typ -> data:'a -> bool) -> int

        val split : 'a t -> T.typ -> 'a t * (T.typ * 'a) option * 'a t

        val append :
             lower_part:'a t
          -> upper_part:'a t
          -> [ `Ok of 'a t | `Overlapping_key_ranges ]

        val subrange :
             'a t
          -> lower_bound:T.typ Base__.Maybe_bound.t
          -> upper_bound:T.typ Base__.Maybe_bound.t
          -> 'a t

        val fold_range_inclusive :
             'a t
          -> min:T.typ
          -> max:T.typ
          -> init:'b
          -> f:(key:T.typ -> data:'a -> 'b -> 'b)
          -> 'b

        val range_to_alist : 'a t -> min:T.typ -> max:T.typ -> (T.typ * 'a) list

        val closest_key :
             'a t
          -> [ `Greater_or_equal_to
             | `Greater_than
             | `Less_or_equal_to
             | `Less_than ]
          -> T.typ
          -> (T.typ * 'a) option

        val nth : 'a t -> int -> (T.typ * 'a) option

        val nth_exn : 'a t -> int -> T.typ * 'a

        val rank : 'a t -> T.typ -> int option

        val to_tree : 'a t -> 'a t

        val to_sequence :
             ?order:[ `Decreasing_key | `Increasing_key ]
          -> ?keys_greater_or_equal_to:T.typ
          -> ?keys_less_or_equal_to:T.typ
          -> 'a t
          -> (T.typ * 'a) Base__.Sequence.t

        val binary_search :
             'a t
          -> compare:(key:T.typ -> data:'a -> 'key -> int)
          -> [ `First_equal_to
             | `First_greater_than_or_equal_to
             | `First_strictly_greater_than
             | `Last_equal_to
             | `Last_less_than_or_equal_to
             | `Last_strictly_less_than ]
          -> 'key
          -> (T.typ * 'a) option

        val binary_search_segmented :
             'a t
          -> segment_of:(key:T.typ -> data:'a -> [ `Left | `Right ])
          -> [ `First_on_right | `Last_on_left ]
          -> (T.typ * 'a) option

        val key_set : 'a t -> (T.typ, comparator_witness) Base.Set.t

        val quickcheck_observer :
             T.typ Core_kernel__.Quickcheck.Observer.t
          -> 'v Core_kernel__.Quickcheck.Observer.t
          -> 'v t Core_kernel__.Quickcheck.Observer.t

        val quickcheck_shrinker :
             T.typ Core_kernel__.Quickcheck.Shrinker.t
          -> 'v Core_kernel__.Quickcheck.Shrinker.t
          -> 'v t Core_kernel__.Quickcheck.Shrinker.t

        module Provide_of_sexp : functor
          (K : sig
             val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> T.typ
           end)
          -> sig
          val t_of_sexp :
               (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__001_)
            -> Ppx_sexp_conv_lib.Sexp.t
            -> 'v_x__001_ t
        end

        val t_of_sexp : (Base__.Sexp.t -> 'a) -> Base__.Sexp.t -> 'a t

        val sexp_of_t : ('a -> Base__.Sexp.t) -> 'a t -> Base__.Sexp.t
      end

      type 'a t = (T.typ, 'a, comparator_witness) Core_kernel__.Map_intf.Map.t

      val compare :
           ('a -> 'a -> Core_kernel__.Import.int)
        -> 'a t
        -> 'a t
        -> Core_kernel__.Import.int

      val empty : 'a t

      val singleton : T.typ -> 'a -> 'a t

      val of_alist :
        (T.typ * 'a) list -> [ `Duplicate_key of T.typ | `Ok of 'a t ]

      val of_alist_or_error : (T.typ * 'a) list -> 'a t Base__.Or_error.t

      val of_alist_exn : (T.typ * 'a) list -> 'a t

      val of_alist_multi : (T.typ * 'a) list -> 'a list t

      val of_alist_fold :
        (T.typ * 'a) list -> init:'b -> f:('b -> 'a -> 'b) -> 'b t

      val of_alist_reduce : (T.typ * 'a) list -> f:('a -> 'a -> 'a) -> 'a t

      val of_sorted_array : (T.typ * 'a) array -> 'a t Base__.Or_error.t

      val of_sorted_array_unchecked : (T.typ * 'a) array -> 'a t

      val of_increasing_iterator_unchecked :
        len:int -> f:(int -> T.typ * 'a) -> 'a t

      val of_increasing_sequence :
        (T.typ * 'a) Base__.Sequence.t -> 'a t Base__.Or_error.t

      val of_sequence :
           (T.typ * 'a) Base__.Sequence.t
        -> [ `Duplicate_key of T.typ | `Ok of 'a t ]

      val of_sequence_or_error :
        (T.typ * 'a) Base__.Sequence.t -> 'a t Base__.Or_error.t

      val of_sequence_exn : (T.typ * 'a) Base__.Sequence.t -> 'a t

      val of_sequence_multi : (T.typ * 'a) Base__.Sequence.t -> 'a list t

      val of_sequence_fold :
        (T.typ * 'a) Base__.Sequence.t -> init:'b -> f:('b -> 'a -> 'b) -> 'b t

      val of_sequence_reduce :
        (T.typ * 'a) Base__.Sequence.t -> f:('a -> 'a -> 'a) -> 'a t

      val of_iteri :
           iteri:(f:(key:T.typ -> data:'v -> unit) -> unit)
        -> [ `Duplicate_key of T.typ | `Ok of 'v t ]

      val of_tree : 'a Tree.t -> 'a t

      val of_hashtbl_exn : (T.typ, 'a) Core_kernel__.Hashtbl.t -> 'a t

      val of_key_set :
        (T.typ, comparator_witness) Base.Set.t -> f:(T.typ -> 'v) -> 'v t

      val quickcheck_generator :
           T.typ Core_kernel__.Quickcheck.Generator.t
        -> 'a Core_kernel__.Quickcheck.Generator.t
        -> 'a t Core_kernel__.Quickcheck.Generator.t

      val invariants : 'a t -> bool

      val is_empty : 'a t -> bool

      val length : 'a t -> int

      val add :
        'a t -> key:T.typ -> data:'a -> 'a t Base__.Map_intf.Or_duplicate.t

      val add_exn : 'a t -> key:T.typ -> data:'a -> 'a t

      val set : 'a t -> key:T.typ -> data:'a -> 'a t

      val add_multi : 'a list t -> key:T.typ -> data:'a -> 'a list t

      val remove_multi : 'a list t -> T.typ -> 'a list t

      val find_multi : 'a list t -> T.typ -> 'a list

      val change : 'a t -> T.typ -> f:('a option -> 'a option) -> 'a t

      val update : 'a t -> T.typ -> f:('a option -> 'a) -> 'a t

      val find : 'a t -> T.typ -> 'a option

      val find_exn : 'a t -> T.typ -> 'a

      val remove : 'a t -> T.typ -> 'a t

      val mem : 'a t -> T.typ -> bool

      val iter_keys : 'a t -> f:(T.typ -> unit) -> unit

      val iter : 'a t -> f:('a -> unit) -> unit

      val iteri : 'a t -> f:(key:T.typ -> data:'a -> unit) -> unit

      val iteri_until :
           'a t
        -> f:(key:T.typ -> data:'a -> Base__.Map_intf.Continue_or_stop.t)
        -> Base__.Map_intf.Finished_or_unfinished.t

      val iter2 :
           'a t
        -> 'b t
        -> f:
             (   key:T.typ
              -> data:[ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
              -> unit)
        -> unit

      val map : 'a t -> f:('a -> 'b) -> 'b t

      val mapi : 'a t -> f:(key:T.typ -> data:'a -> 'b) -> 'b t

      val fold : 'a t -> init:'b -> f:(key:T.typ -> data:'a -> 'b -> 'b) -> 'b

      val fold_right :
        'a t -> init:'b -> f:(key:T.typ -> data:'a -> 'b -> 'b) -> 'b

      val fold2 :
           'a t
        -> 'b t
        -> init:'c
        -> f:
             (   key:T.typ
              -> data:[ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
              -> 'c
              -> 'c)
        -> 'c

      val filter_keys : 'a t -> f:(T.typ -> bool) -> 'a t

      val filter : 'a t -> f:('a -> bool) -> 'a t

      val filteri : 'a t -> f:(key:T.typ -> data:'a -> bool) -> 'a t

      val filter_map : 'a t -> f:('a -> 'b option) -> 'b t

      val filter_mapi : 'a t -> f:(key:T.typ -> data:'a -> 'b option) -> 'b t

      val partition_mapi :
           'a t
        -> f:(key:T.typ -> data:'a -> [ `Fst of 'b | `Snd of 'c ])
        -> 'b t * 'c t

      val partition_map :
        'a t -> f:('a -> [ `Fst of 'b | `Snd of 'c ]) -> 'b t * 'c t

      val partitioni_tf :
        'a t -> f:(key:T.typ -> data:'a -> bool) -> 'a t * 'a t

      val partition_tf : 'a t -> f:('a -> bool) -> 'a t * 'a t

      val compare_direct : ('a -> 'a -> int) -> 'a t -> 'a t -> int

      val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

      val keys : 'a t -> T.typ list

      val data : 'a t -> 'a list

      val to_alist :
        ?key_order:[ `Decreasing | `Increasing ] -> 'a t -> (T.typ * 'a) list

      val validate :
           name:(T.typ -> string)
        -> 'a Base__.Validate.check
        -> 'a t Base__.Validate.check

      val merge :
           'a t
        -> 'b t
        -> f:
             (   key:T.typ
              -> [ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
              -> 'c option)
        -> 'c t

      val symmetric_diff :
           'a t
        -> 'a t
        -> data_equal:('a -> 'a -> bool)
        -> (T.typ, 'a) Base__.Map_intf.Symmetric_diff_element.t
           Base__.Sequence.t

      val fold_symmetric_diff :
           'a t
        -> 'a t
        -> data_equal:('a -> 'a -> bool)
        -> init:'c
        -> f:('c -> (T.typ, 'a) Base__.Map_intf.Symmetric_diff_element.t -> 'c)
        -> 'c

      val min_elt : 'a t -> (T.typ * 'a) option

      val min_elt_exn : 'a t -> T.typ * 'a

      val max_elt : 'a t -> (T.typ * 'a) option

      val max_elt_exn : 'a t -> T.typ * 'a

      val for_all : 'a t -> f:('a -> bool) -> bool

      val for_alli : 'a t -> f:(key:T.typ -> data:'a -> bool) -> bool

      val exists : 'a t -> f:('a -> bool) -> bool

      val existsi : 'a t -> f:(key:T.typ -> data:'a -> bool) -> bool

      val count : 'a t -> f:('a -> bool) -> int

      val counti : 'a t -> f:(key:T.typ -> data:'a -> bool) -> int

      val split : 'a t -> T.typ -> 'a t * (T.typ * 'a) option * 'a t

      val append :
           lower_part:'a t
        -> upper_part:'a t
        -> [ `Ok of 'a t | `Overlapping_key_ranges ]

      val subrange :
           'a t
        -> lower_bound:T.typ Base__.Maybe_bound.t
        -> upper_bound:T.typ Base__.Maybe_bound.t
        -> 'a t

      val fold_range_inclusive :
           'a t
        -> min:T.typ
        -> max:T.typ
        -> init:'b
        -> f:(key:T.typ -> data:'a -> 'b -> 'b)
        -> 'b

      val range_to_alist : 'a t -> min:T.typ -> max:T.typ -> (T.typ * 'a) list

      val closest_key :
           'a t
        -> [ `Greater_or_equal_to
           | `Greater_than
           | `Less_or_equal_to
           | `Less_than ]
        -> T.typ
        -> (T.typ * 'a) option

      val nth : 'a t -> int -> (T.typ * 'a) option

      val nth_exn : 'a t -> int -> T.typ * 'a

      val rank : 'a t -> T.typ -> int option

      val to_tree : 'a t -> 'a Tree.t

      val to_sequence :
           ?order:[ `Decreasing_key | `Increasing_key ]
        -> ?keys_greater_or_equal_to:T.typ
        -> ?keys_less_or_equal_to:T.typ
        -> 'a t
        -> (T.typ * 'a) Base__.Sequence.t

      val binary_search :
           'a t
        -> compare:(key:T.typ -> data:'a -> 'key -> int)
        -> [ `First_equal_to
           | `First_greater_than_or_equal_to
           | `First_strictly_greater_than
           | `Last_equal_to
           | `Last_less_than_or_equal_to
           | `Last_strictly_less_than ]
        -> 'key
        -> (T.typ * 'a) option

      val binary_search_segmented :
           'a t
        -> segment_of:(key:T.typ -> data:'a -> [ `Left | `Right ])
        -> [ `First_on_right | `Last_on_left ]
        -> (T.typ * 'a) option

      val key_set : 'a t -> (T.typ, comparator_witness) Base.Set.t

      val quickcheck_observer :
           T.typ Core_kernel__.Quickcheck.Observer.t
        -> 'v Core_kernel__.Quickcheck.Observer.t
        -> 'v t Core_kernel__.Quickcheck.Observer.t

      val quickcheck_shrinker :
           T.typ Core_kernel__.Quickcheck.Shrinker.t
        -> 'v Core_kernel__.Quickcheck.Shrinker.t
        -> 'v t Core_kernel__.Quickcheck.Shrinker.t

      module Provide_of_sexp : functor
        (Key : sig
           val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> T.typ
         end)
        -> sig
        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> 'v_x__002_ t
      end

      module Provide_bin_io : functor
        (Key : sig
           val bin_size_t : T.typ Bin_prot.Size.sizer

           val bin_write_t : T.typ Bin_prot.Write.writer

           val bin_read_t : T.typ Bin_prot.Read.reader

           val __bin_read_t__ : (int -> T.typ) Bin_prot.Read.reader

           val bin_shape_t : Bin_prot.Shape.t

           val bin_writer_t : T.typ Bin_prot.Type_class.writer

           val bin_reader_t : T.typ Bin_prot.Type_class.reader

           val bin_t : T.typ Bin_prot.Type_class.t
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

      module Provide_hash : functor
        (Key : sig
           val hash_fold_t : Base__.Hash.state -> T.typ -> Base__.Hash.state
         end)
        -> sig
        val hash_fold_t :
             (Ppx_hash_lib.Std.Hash.state -> 'a -> Ppx_hash_lib.Std.Hash.state)
          -> Ppx_hash_lib.Std.Hash.state
          -> 'a t
          -> Ppx_hash_lib.Std.Hash.state
      end

      val t_of_sexp : (Base__.Sexp.t -> 'a) -> Base__.Sexp.t -> 'a t

      val sexp_of_t : ('a -> Base__.Sexp.t) -> 'a t -> Base__.Sexp.t
    end

    module Set : sig
      module Elt : sig
        type t = T.typ

        val t_of_sexp : Sexplib0.Sexp.t -> t

        val sexp_of_t : t -> Sexplib0.Sexp.t

        type comparator_witness = Map.Key.comparator_witness

        val comparator :
          (t, comparator_witness) Core_kernel__.Comparator.comparator
      end

      module Tree : sig
        type t = (T.typ, comparator_witness) Core_kernel__.Set_intf.Tree.t

        val compare : t -> t -> Core_kernel__.Import.int

        type named =
          (T.typ, comparator_witness) Core_kernel__.Set_intf.Tree.Named.t

        val length : t -> int

        val is_empty : t -> bool

        val iter : t -> f:(T.typ -> unit) -> unit

        val fold : t -> init:'accum -> f:('accum -> T.typ -> 'accum) -> 'accum

        val fold_result :
             t
          -> init:'accum
          -> f:('accum -> T.typ -> ('accum, 'e) Base__.Result.t)
          -> ('accum, 'e) Base__.Result.t

        val exists : t -> f:(T.typ -> bool) -> bool

        val for_all : t -> f:(T.typ -> bool) -> bool

        val count : t -> f:(T.typ -> bool) -> int

        val sum :
             (module Base__.Container_intf.Summable with type t = 'sum)
          -> t
          -> f:(T.typ -> 'sum)
          -> 'sum

        val find : t -> f:(T.typ -> bool) -> T.typ option

        val find_map : t -> f:(T.typ -> 'a option) -> 'a option

        val to_list : t -> T.typ list

        val to_array : t -> T.typ array

        val invariants : t -> bool

        val mem : t -> T.typ -> bool

        val add : t -> T.typ -> t

        val remove : t -> T.typ -> t

        val union : t -> t -> t

        val inter : t -> t -> t

        val diff : t -> t -> t

        val symmetric_diff :
          t -> t -> (T.typ, T.typ) Base__.Either.t Base__.Sequence.t

        val compare_direct : t -> t -> int

        val equal : t -> t -> bool

        val is_subset : t -> of_:t -> bool

        module Named : sig
          val is_subset : named -> of_:named -> unit Base__.Or_error.t

          val equal : named -> named -> unit Base__.Or_error.t
        end

        val fold_until :
             t
          -> init:'b
          -> f:('b -> T.typ -> ('b, 'final) Base__.Set_intf.Continue_or_stop.t)
          -> finish:('b -> 'final)
          -> 'final

        val fold_right : t -> init:'b -> f:(T.typ -> 'b -> 'b) -> 'b

        val iter2 :
             t
          -> t
          -> f:
               (   [ `Both of T.typ * T.typ | `Left of T.typ | `Right of T.typ ]
                -> unit)
          -> unit

        val filter : t -> f:(T.typ -> bool) -> t

        val partition_tf : t -> f:(T.typ -> bool) -> t * t

        val elements : t -> T.typ list

        val min_elt : t -> T.typ option

        val min_elt_exn : t -> T.typ

        val max_elt : t -> T.typ option

        val max_elt_exn : t -> T.typ

        val choose : t -> T.typ option

        val choose_exn : t -> T.typ

        val split : t -> T.typ -> t * T.typ option * t

        val group_by : t -> equiv:(T.typ -> T.typ -> bool) -> t list

        val find_exn : t -> f:(T.typ -> bool) -> T.typ

        val nth : t -> int -> T.typ option

        val remove_index : t -> int -> t

        val to_tree : t -> t

        val to_sequence :
             ?order:[ `Decreasing | `Increasing ]
          -> ?greater_or_equal_to:T.typ
          -> ?less_or_equal_to:T.typ
          -> t
          -> T.typ Base__.Sequence.t

        val binary_search :
             t
          -> compare:(T.typ -> 'key -> int)
          -> [ `First_equal_to
             | `First_greater_than_or_equal_to
             | `First_strictly_greater_than
             | `Last_equal_to
             | `Last_less_than_or_equal_to
             | `Last_strictly_less_than ]
          -> 'key
          -> T.typ option

        val binary_search_segmented :
             t
          -> segment_of:(T.typ -> [ `Left | `Right ])
          -> [ `First_on_right | `Last_on_left ]
          -> T.typ option

        val merge_to_sequence :
             ?order:[ `Decreasing | `Increasing ]
          -> ?greater_or_equal_to:T.typ
          -> ?less_or_equal_to:T.typ
          -> t
          -> t
          -> (T.typ, T.typ) Base__.Set_intf.Merge_to_sequence_element.t
             Base__.Sequence.t

        val to_map :
             t
          -> f:(T.typ -> 'data)
          -> (T.typ, 'data, comparator_witness) Base.Map.t

        val quickcheck_observer :
             T.typ Core_kernel__.Quickcheck.Observer.t
          -> t Core_kernel__.Quickcheck.Observer.t

        val quickcheck_shrinker :
             T.typ Core_kernel__.Quickcheck.Shrinker.t
          -> t Core_kernel__.Quickcheck.Shrinker.t

        val empty : t

        val singleton : T.typ -> t

        val union_list : t list -> t

        val of_list : T.typ list -> t

        val of_array : T.typ array -> t

        val of_sorted_array : T.typ array -> t Base__.Or_error.t

        val of_sorted_array_unchecked : T.typ array -> t

        val of_increasing_iterator_unchecked : len:int -> f:(int -> T.typ) -> t

        val stable_dedup_list : T.typ list -> T.typ list

        val map : ('a, 'b) Core_kernel__.Set_intf.Tree.t -> f:('a -> T.typ) -> t

        val filter_map :
          ('a, 'b) Core_kernel__.Set_intf.Tree.t -> f:('a -> T.typ option) -> t

        val of_tree : t -> t

        val of_hash_set : T.typ Core_kernel__.Hash_set.t -> t

        val of_hashtbl_keys : (T.typ, 'a) Core_kernel__.Hashtbl.t -> t

        val of_map_keys : (T.typ, 'a, comparator_witness) Base.Map.t -> t

        val quickcheck_generator :
             T.typ Core_kernel__.Quickcheck.Generator.t
          -> t Core_kernel__.Quickcheck.Generator.t

        module Provide_of_sexp : functor
          (Elt : sig
             val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> T.typ
           end)
          -> sig
          val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
        end

        val t_of_sexp : Base__.Sexp.t -> t

        val sexp_of_t : t -> Base__.Sexp.t
      end

      type t = (T.typ, comparator_witness) Base.Set.t

      val compare : t -> t -> Core_kernel__.Import.int

      type named = (T.typ, comparator_witness) Core_kernel__.Set_intf.Named.t

      val length : t -> int

      val is_empty : t -> bool

      val iter : t -> f:(T.typ -> unit) -> unit

      val fold : t -> init:'accum -> f:('accum -> T.typ -> 'accum) -> 'accum

      val fold_result :
           t
        -> init:'accum
        -> f:('accum -> T.typ -> ('accum, 'e) Base__.Result.t)
        -> ('accum, 'e) Base__.Result.t

      val exists : t -> f:(T.typ -> bool) -> bool

      val for_all : t -> f:(T.typ -> bool) -> bool

      val count : t -> f:(T.typ -> bool) -> int

      val sum :
           (module Base__.Container_intf.Summable with type t = 'sum)
        -> t
        -> f:(T.typ -> 'sum)
        -> 'sum

      val find : t -> f:(T.typ -> bool) -> T.typ option

      val find_map : t -> f:(T.typ -> 'a option) -> 'a option

      val to_list : t -> T.typ list

      val to_array : t -> T.typ array

      val invariants : t -> bool

      val mem : t -> T.typ -> bool

      val add : t -> T.typ -> t

      val remove : t -> T.typ -> t

      val union : t -> t -> t

      val inter : t -> t -> t

      val diff : t -> t -> t

      val symmetric_diff :
        t -> t -> (T.typ, T.typ) Base__.Either.t Base__.Sequence.t

      val compare_direct : t -> t -> int

      val equal : t -> t -> bool

      val is_subset : t -> of_:t -> bool

      module Named : sig
        val is_subset : named -> of_:named -> unit Base__.Or_error.t

        val equal : named -> named -> unit Base__.Or_error.t
      end

      val fold_until :
           t
        -> init:'b
        -> f:('b -> T.typ -> ('b, 'final) Base__.Set_intf.Continue_or_stop.t)
        -> finish:('b -> 'final)
        -> 'final

      val fold_right : t -> init:'b -> f:(T.typ -> 'b -> 'b) -> 'b

      val iter2 :
           t
        -> t
        -> f:
             (   [ `Both of T.typ * T.typ | `Left of T.typ | `Right of T.typ ]
              -> unit)
        -> unit

      val filter : t -> f:(T.typ -> bool) -> t

      val partition_tf : t -> f:(T.typ -> bool) -> t * t

      val elements : t -> T.typ list

      val min_elt : t -> T.typ option

      val min_elt_exn : t -> T.typ

      val max_elt : t -> T.typ option

      val max_elt_exn : t -> T.typ

      val choose : t -> T.typ option

      val choose_exn : t -> T.typ

      val split : t -> T.typ -> t * T.typ option * t

      val group_by : t -> equiv:(T.typ -> T.typ -> bool) -> t list

      val find_exn : t -> f:(T.typ -> bool) -> T.typ

      val nth : t -> int -> T.typ option

      val remove_index : t -> int -> t

      val to_tree : t -> Tree.t

      val to_sequence :
           ?order:[ `Decreasing | `Increasing ]
        -> ?greater_or_equal_to:T.typ
        -> ?less_or_equal_to:T.typ
        -> t
        -> T.typ Base__.Sequence.t

      val binary_search :
           t
        -> compare:(T.typ -> 'key -> int)
        -> [ `First_equal_to
           | `First_greater_than_or_equal_to
           | `First_strictly_greater_than
           | `Last_equal_to
           | `Last_less_than_or_equal_to
           | `Last_strictly_less_than ]
        -> 'key
        -> T.typ option

      val binary_search_segmented :
           t
        -> segment_of:(T.typ -> [ `Left | `Right ])
        -> [ `First_on_right | `Last_on_left ]
        -> T.typ option

      val merge_to_sequence :
           ?order:[ `Decreasing | `Increasing ]
        -> ?greater_or_equal_to:T.typ
        -> ?less_or_equal_to:T.typ
        -> t
        -> t
        -> (T.typ, T.typ) Base__.Set_intf.Merge_to_sequence_element.t
           Base__.Sequence.t

      val to_map :
        t -> f:(T.typ -> 'data) -> (T.typ, 'data, comparator_witness) Base.Map.t

      val quickcheck_observer :
           T.typ Core_kernel__.Quickcheck.Observer.t
        -> t Core_kernel__.Quickcheck.Observer.t

      val quickcheck_shrinker :
           T.typ Core_kernel__.Quickcheck.Shrinker.t
        -> t Core_kernel__.Quickcheck.Shrinker.t

      val empty : t

      val singleton : T.typ -> t

      val union_list : t list -> t

      val of_list : T.typ list -> t

      val of_array : T.typ array -> t

      val of_sorted_array : T.typ array -> t Base__.Or_error.t

      val of_sorted_array_unchecked : T.typ array -> t

      val of_increasing_iterator_unchecked : len:int -> f:(int -> T.typ) -> t

      val stable_dedup_list : T.typ list -> T.typ list

      val map : ('a, 'b) Base.Set.t -> f:('a -> T.typ) -> t

      val filter_map : ('a, 'b) Base.Set.t -> f:('a -> T.typ option) -> t

      val of_tree : Tree.t -> t

      val of_hash_set : T.typ Core_kernel__.Hash_set.t -> t

      val of_hashtbl_keys : (T.typ, 'a) Core_kernel__.Hashtbl.t -> t

      val of_map_keys : (T.typ, 'a, comparator_witness) Base.Map.t -> t

      val quickcheck_generator :
           T.typ Core_kernel__.Quickcheck.Generator.t
        -> t Core_kernel__.Quickcheck.Generator.t

      module Provide_of_sexp : functor
        (Elt : sig
           val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> T.typ
         end)
        -> sig
        val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
      end

      module Provide_bin_io : functor
        (Elt : sig
           val bin_size_t : T.typ Bin_prot.Size.sizer

           val bin_write_t : T.typ Bin_prot.Write.writer

           val bin_read_t : T.typ Bin_prot.Read.reader

           val __bin_read_t__ : (int -> T.typ) Bin_prot.Read.reader

           val bin_shape_t : Bin_prot.Shape.t

           val bin_writer_t : T.typ Bin_prot.Type_class.writer

           val bin_reader_t : T.typ Bin_prot.Type_class.reader

           val bin_t : T.typ Bin_prot.Type_class.t
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

      module Provide_hash : functor
        (Elt : sig
           val hash_fold_t : Base__.Hash.state -> T.typ -> Base__.Hash.state
         end)
        -> sig
        val hash_fold_t :
          Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

        val hash : t -> Ppx_hash_lib.Std.Hash.hash_value
      end

      val t_of_sexp : Base__.Sexp.t -> t

      val sexp_of_t : t -> Base__.Sexp.t
    end

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

type t = Stable.V1.t =
  { fee : Currency.Fee.t; prover : Signature_lib.Public_key.Compressed.t }

val to_yojson : t -> Yojson.Safe.t

val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

val hash_fold_t :
  Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

val ( >= ) : t -> t -> bool

val ( <= ) : t -> t -> bool

val ( = ) : t -> t -> bool

val ( > ) : t -> t -> bool

val ( < ) : t -> t -> bool

val ( <> ) : t -> t -> bool

val equal : t -> t -> bool

val compare : t -> t -> int

val min : t -> t -> t

val max : t -> t -> t

val ascending : t -> t -> int

val descending : t -> t -> int

val between : t -> low:t -> high:t -> bool

val clamp_exn : t -> min:t -> max:t -> t

val clamp : t -> min:t -> max:t -> t Base__.Or_error.t

type comparator_witness = Stable.V1.comparator_witness

val comparator : (t, comparator_witness) Base__.Comparator.comparator

val validate_lbound : min:t Base__.Maybe_bound.t -> t Base__.Validate.check

val validate_ubound : max:t Base__.Maybe_bound.t -> t Base__.Validate.check

val validate_bound :
     min:t Base__.Maybe_bound.t
  -> max:t Base__.Maybe_bound.t
  -> t Base__.Validate.check

module Replace_polymorphic_compare : sig
  val ( >= ) : t -> t -> bool

  val ( <= ) : t -> t -> bool

  val ( = ) : t -> t -> bool

  val ( > ) : t -> t -> bool

  val ( < ) : t -> t -> bool

  val ( <> ) : t -> t -> bool

  val equal : t -> t -> bool

  val compare : t -> t -> int

  val min : t -> t -> t

  val max : t -> t -> t
end

module Map : sig
  module Key : sig
    type t = Stable.V1.t

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    type comparator_witness = Stable.V1.comparator_witness

    val comparator : (t, comparator_witness) Core_kernel__.Comparator.comparator
  end

  module Tree : sig
    type 'a t = (Key.t, 'a, comparator_witness) Core_kernel__.Map_intf.Tree.t

    val empty : 'a t

    val singleton : Key.t -> 'a -> 'a t

    val of_alist : (Key.t * 'a) list -> [ `Duplicate_key of Key.t | `Ok of 'a t ]

    val of_alist_or_error : (Key.t * 'a) list -> 'a t Base__.Or_error.t

    val of_alist_exn : (Key.t * 'a) list -> 'a t

    val of_alist_multi : (Key.t * 'a) list -> 'a list t

    val of_alist_fold :
      (Key.t * 'a) list -> init:'b -> f:('b -> 'a -> 'b) -> 'b t

    val of_alist_reduce : (Key.t * 'a) list -> f:('a -> 'a -> 'a) -> 'a t

    val of_sorted_array : (Key.t * 'a) array -> 'a t Base__.Or_error.t

    val of_sorted_array_unchecked : (Key.t * 'a) array -> 'a t

    val of_increasing_iterator_unchecked :
      len:int -> f:(int -> Key.t * 'a) -> 'a t

    val of_increasing_sequence :
      (Key.t * 'a) Base__.Sequence.t -> 'a t Base__.Or_error.t

    val of_sequence :
      (Key.t * 'a) Base__.Sequence.t -> [ `Duplicate_key of Key.t | `Ok of 'a t ]

    val of_sequence_or_error :
      (Key.t * 'a) Base__.Sequence.t -> 'a t Base__.Or_error.t

    val of_sequence_exn : (Key.t * 'a) Base__.Sequence.t -> 'a t

    val of_sequence_multi : (Key.t * 'a) Base__.Sequence.t -> 'a list t

    val of_sequence_fold :
      (Key.t * 'a) Base__.Sequence.t -> init:'b -> f:('b -> 'a -> 'b) -> 'b t

    val of_sequence_reduce :
      (Key.t * 'a) Base__.Sequence.t -> f:('a -> 'a -> 'a) -> 'a t

    val of_iteri :
         iteri:(f:(key:Key.t -> data:'v -> unit) -> unit)
      -> [ `Duplicate_key of Key.t | `Ok of 'v t ]

    val of_tree : 'a t -> 'a t

    val of_hashtbl_exn : (Key.t, 'a) Core_kernel__.Hashtbl.t -> 'a t

    val of_key_set :
      (Key.t, comparator_witness) Base.Set.t -> f:(Key.t -> 'v) -> 'v t

    val quickcheck_generator :
         Key.t Core_kernel__.Quickcheck.Generator.t
      -> 'a Core_kernel__.Quickcheck.Generator.t
      -> 'a t Core_kernel__.Quickcheck.Generator.t

    val invariants : 'a t -> bool

    val is_empty : 'a t -> bool

    val length : 'a t -> int

    val add :
      'a t -> key:Key.t -> data:'a -> 'a t Base__.Map_intf.Or_duplicate.t

    val add_exn : 'a t -> key:Key.t -> data:'a -> 'a t

    val set : 'a t -> key:Key.t -> data:'a -> 'a t

    val add_multi : 'a list t -> key:Key.t -> data:'a -> 'a list t

    val remove_multi : 'a list t -> Key.t -> 'a list t

    val find_multi : 'a list t -> Key.t -> 'a list

    val change : 'a t -> Key.t -> f:('a option -> 'a option) -> 'a t

    val update : 'a t -> Key.t -> f:('a option -> 'a) -> 'a t

    val find : 'a t -> Key.t -> 'a option

    val find_exn : 'a t -> Key.t -> 'a

    val remove : 'a t -> Key.t -> 'a t

    val mem : 'a t -> Key.t -> bool

    val iter_keys : 'a t -> f:(Key.t -> unit) -> unit

    val iter : 'a t -> f:('a -> unit) -> unit

    val iteri : 'a t -> f:(key:Key.t -> data:'a -> unit) -> unit

    val iteri_until :
         'a t
      -> f:(key:Key.t -> data:'a -> Base__.Map_intf.Continue_or_stop.t)
      -> Base__.Map_intf.Finished_or_unfinished.t

    val iter2 :
         'a t
      -> 'b t
      -> f:
           (   key:Key.t
            -> data:[ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
            -> unit)
      -> unit

    val map : 'a t -> f:('a -> 'b) -> 'b t

    val mapi : 'a t -> f:(key:Key.t -> data:'a -> 'b) -> 'b t

    val fold : 'a t -> init:'b -> f:(key:Key.t -> data:'a -> 'b -> 'b) -> 'b

    val fold_right :
      'a t -> init:'b -> f:(key:Key.t -> data:'a -> 'b -> 'b) -> 'b

    val fold2 :
         'a t
      -> 'b t
      -> init:'c
      -> f:
           (   key:Key.t
            -> data:[ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
            -> 'c
            -> 'c)
      -> 'c

    val filter_keys : 'a t -> f:(Key.t -> bool) -> 'a t

    val filter : 'a t -> f:('a -> bool) -> 'a t

    val filteri : 'a t -> f:(key:Key.t -> data:'a -> bool) -> 'a t

    val filter_map : 'a t -> f:('a -> 'b option) -> 'b t

    val filter_mapi : 'a t -> f:(key:Key.t -> data:'a -> 'b option) -> 'b t

    val partition_mapi :
         'a t
      -> f:(key:Key.t -> data:'a -> [ `Fst of 'b | `Snd of 'c ])
      -> 'b t * 'c t

    val partition_map :
      'a t -> f:('a -> [ `Fst of 'b | `Snd of 'c ]) -> 'b t * 'c t

    val partitioni_tf : 'a t -> f:(key:Key.t -> data:'a -> bool) -> 'a t * 'a t

    val partition_tf : 'a t -> f:('a -> bool) -> 'a t * 'a t

    val compare_direct : ('a -> 'a -> int) -> 'a t -> 'a t -> int

    val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

    val keys : 'a t -> Key.t list

    val data : 'a t -> 'a list

    val to_alist :
      ?key_order:[ `Decreasing | `Increasing ] -> 'a t -> (Key.t * 'a) list

    val validate :
         name:(Key.t -> string)
      -> 'a Base__.Validate.check
      -> 'a t Base__.Validate.check

    val merge :
         'a t
      -> 'b t
      -> f:
           (   key:Key.t
            -> [ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
            -> 'c option)
      -> 'c t

    val symmetric_diff :
         'a t
      -> 'a t
      -> data_equal:('a -> 'a -> bool)
      -> (Key.t, 'a) Base__.Map_intf.Symmetric_diff_element.t Base__.Sequence.t

    val fold_symmetric_diff :
         'a t
      -> 'a t
      -> data_equal:('a -> 'a -> bool)
      -> init:'c
      -> f:('c -> (Key.t, 'a) Base__.Map_intf.Symmetric_diff_element.t -> 'c)
      -> 'c

    val min_elt : 'a t -> (Key.t * 'a) option

    val min_elt_exn : 'a t -> Key.t * 'a

    val max_elt : 'a t -> (Key.t * 'a) option

    val max_elt_exn : 'a t -> Key.t * 'a

    val for_all : 'a t -> f:('a -> bool) -> bool

    val for_alli : 'a t -> f:(key:Key.t -> data:'a -> bool) -> bool

    val exists : 'a t -> f:('a -> bool) -> bool

    val existsi : 'a t -> f:(key:Key.t -> data:'a -> bool) -> bool

    val count : 'a t -> f:('a -> bool) -> int

    val counti : 'a t -> f:(key:Key.t -> data:'a -> bool) -> int

    val split : 'a t -> Key.t -> 'a t * (Key.t * 'a) option * 'a t

    val append :
         lower_part:'a t
      -> upper_part:'a t
      -> [ `Ok of 'a t | `Overlapping_key_ranges ]

    val subrange :
         'a t
      -> lower_bound:Key.t Base__.Maybe_bound.t
      -> upper_bound:Key.t Base__.Maybe_bound.t
      -> 'a t

    val fold_range_inclusive :
         'a t
      -> min:Key.t
      -> max:Key.t
      -> init:'b
      -> f:(key:Key.t -> data:'a -> 'b -> 'b)
      -> 'b

    val range_to_alist : 'a t -> min:Key.t -> max:Key.t -> (Key.t * 'a) list

    val closest_key :
         'a t
      -> [ `Greater_or_equal_to
         | `Greater_than
         | `Less_or_equal_to
         | `Less_than ]
      -> Key.t
      -> (Key.t * 'a) option

    val nth : 'a t -> int -> (Key.t * 'a) option

    val nth_exn : 'a t -> int -> Key.t * 'a

    val rank : 'a t -> Key.t -> int option

    val to_tree : 'a t -> 'a t

    val to_sequence :
         ?order:[ `Decreasing_key | `Increasing_key ]
      -> ?keys_greater_or_equal_to:Key.t
      -> ?keys_less_or_equal_to:Key.t
      -> 'a t
      -> (Key.t * 'a) Base__.Sequence.t

    val binary_search :
         'a t
      -> compare:(key:Key.t -> data:'a -> 'key -> int)
      -> [ `First_equal_to
         | `First_greater_than_or_equal_to
         | `First_strictly_greater_than
         | `Last_equal_to
         | `Last_less_than_or_equal_to
         | `Last_strictly_less_than ]
      -> 'key
      -> (Key.t * 'a) option

    val binary_search_segmented :
         'a t
      -> segment_of:(key:Key.t -> data:'a -> [ `Left | `Right ])
      -> [ `First_on_right | `Last_on_left ]
      -> (Key.t * 'a) option

    val key_set : 'a t -> (Key.t, comparator_witness) Base.Set.t

    val quickcheck_observer :
         Key.t Core_kernel__.Quickcheck.Observer.t
      -> 'v Core_kernel__.Quickcheck.Observer.t
      -> 'v t Core_kernel__.Quickcheck.Observer.t

    val quickcheck_shrinker :
         Key.t Core_kernel__.Quickcheck.Shrinker.t
      -> 'v Core_kernel__.Quickcheck.Shrinker.t
      -> 'v t Core_kernel__.Quickcheck.Shrinker.t

    module Provide_of_sexp : functor
      (K : sig
         val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> Key.t
       end)
      -> sig
      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__001_)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> 'v_x__001_ t
    end

    val t_of_sexp : (Base__.Sexp.t -> 'a) -> Base__.Sexp.t -> 'a t

    val sexp_of_t : ('a -> Base__.Sexp.t) -> 'a t -> Base__.Sexp.t
  end

  type 'a t = (Key.t, 'a, comparator_witness) Core_kernel__.Map_intf.Map.t

  val compare :
       ('a -> 'a -> Core_kernel__.Import.int)
    -> 'a t
    -> 'a t
    -> Core_kernel__.Import.int

  val empty : 'a t

  val singleton : Key.t -> 'a -> 'a t

  val of_alist : (Key.t * 'a) list -> [ `Duplicate_key of Key.t | `Ok of 'a t ]

  val of_alist_or_error : (Key.t * 'a) list -> 'a t Base__.Or_error.t

  val of_alist_exn : (Key.t * 'a) list -> 'a t

  val of_alist_multi : (Key.t * 'a) list -> 'a list t

  val of_alist_fold : (Key.t * 'a) list -> init:'b -> f:('b -> 'a -> 'b) -> 'b t

  val of_alist_reduce : (Key.t * 'a) list -> f:('a -> 'a -> 'a) -> 'a t

  val of_sorted_array : (Key.t * 'a) array -> 'a t Base__.Or_error.t

  val of_sorted_array_unchecked : (Key.t * 'a) array -> 'a t

  val of_increasing_iterator_unchecked :
    len:int -> f:(int -> Key.t * 'a) -> 'a t

  val of_increasing_sequence :
    (Key.t * 'a) Base__.Sequence.t -> 'a t Base__.Or_error.t

  val of_sequence :
    (Key.t * 'a) Base__.Sequence.t -> [ `Duplicate_key of Key.t | `Ok of 'a t ]

  val of_sequence_or_error :
    (Key.t * 'a) Base__.Sequence.t -> 'a t Base__.Or_error.t

  val of_sequence_exn : (Key.t * 'a) Base__.Sequence.t -> 'a t

  val of_sequence_multi : (Key.t * 'a) Base__.Sequence.t -> 'a list t

  val of_sequence_fold :
    (Key.t * 'a) Base__.Sequence.t -> init:'b -> f:('b -> 'a -> 'b) -> 'b t

  val of_sequence_reduce :
    (Key.t * 'a) Base__.Sequence.t -> f:('a -> 'a -> 'a) -> 'a t

  val of_iteri :
       iteri:(f:(key:Key.t -> data:'v -> unit) -> unit)
    -> [ `Duplicate_key of Key.t | `Ok of 'v t ]

  val of_tree : 'a Tree.t -> 'a t

  val of_hashtbl_exn : (Key.t, 'a) Core_kernel__.Hashtbl.t -> 'a t

  val of_key_set :
    (Key.t, comparator_witness) Base.Set.t -> f:(Key.t -> 'v) -> 'v t

  val quickcheck_generator :
       Key.t Core_kernel__.Quickcheck.Generator.t
    -> 'a Core_kernel__.Quickcheck.Generator.t
    -> 'a t Core_kernel__.Quickcheck.Generator.t

  val invariants : 'a t -> bool

  val is_empty : 'a t -> bool

  val length : 'a t -> int

  val add : 'a t -> key:Key.t -> data:'a -> 'a t Base__.Map_intf.Or_duplicate.t

  val add_exn : 'a t -> key:Key.t -> data:'a -> 'a t

  val set : 'a t -> key:Key.t -> data:'a -> 'a t

  val add_multi : 'a list t -> key:Key.t -> data:'a -> 'a list t

  val remove_multi : 'a list t -> Key.t -> 'a list t

  val find_multi : 'a list t -> Key.t -> 'a list

  val change : 'a t -> Key.t -> f:('a option -> 'a option) -> 'a t

  val update : 'a t -> Key.t -> f:('a option -> 'a) -> 'a t

  val find : 'a t -> Key.t -> 'a option

  val find_exn : 'a t -> Key.t -> 'a

  val remove : 'a t -> Key.t -> 'a t

  val mem : 'a t -> Key.t -> bool

  val iter_keys : 'a t -> f:(Key.t -> unit) -> unit

  val iter : 'a t -> f:('a -> unit) -> unit

  val iteri : 'a t -> f:(key:Key.t -> data:'a -> unit) -> unit

  val iteri_until :
       'a t
    -> f:(key:Key.t -> data:'a -> Base__.Map_intf.Continue_or_stop.t)
    -> Base__.Map_intf.Finished_or_unfinished.t

  val iter2 :
       'a t
    -> 'b t
    -> f:
         (   key:Key.t
          -> data:[ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
          -> unit)
    -> unit

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val mapi : 'a t -> f:(key:Key.t -> data:'a -> 'b) -> 'b t

  val fold : 'a t -> init:'b -> f:(key:Key.t -> data:'a -> 'b -> 'b) -> 'b

  val fold_right : 'a t -> init:'b -> f:(key:Key.t -> data:'a -> 'b -> 'b) -> 'b

  val fold2 :
       'a t
    -> 'b t
    -> init:'c
    -> f:
         (   key:Key.t
          -> data:[ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
          -> 'c
          -> 'c)
    -> 'c

  val filter_keys : 'a t -> f:(Key.t -> bool) -> 'a t

  val filter : 'a t -> f:('a -> bool) -> 'a t

  val filteri : 'a t -> f:(key:Key.t -> data:'a -> bool) -> 'a t

  val filter_map : 'a t -> f:('a -> 'b option) -> 'b t

  val filter_mapi : 'a t -> f:(key:Key.t -> data:'a -> 'b option) -> 'b t

  val partition_mapi :
       'a t
    -> f:(key:Key.t -> data:'a -> [ `Fst of 'b | `Snd of 'c ])
    -> 'b t * 'c t

  val partition_map :
    'a t -> f:('a -> [ `Fst of 'b | `Snd of 'c ]) -> 'b t * 'c t

  val partitioni_tf : 'a t -> f:(key:Key.t -> data:'a -> bool) -> 'a t * 'a t

  val partition_tf : 'a t -> f:('a -> bool) -> 'a t * 'a t

  val compare_direct : ('a -> 'a -> int) -> 'a t -> 'a t -> int

  val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

  val keys : 'a t -> Key.t list

  val data : 'a t -> 'a list

  val to_alist :
    ?key_order:[ `Decreasing | `Increasing ] -> 'a t -> (Key.t * 'a) list

  val validate :
       name:(Key.t -> string)
    -> 'a Base__.Validate.check
    -> 'a t Base__.Validate.check

  val merge :
       'a t
    -> 'b t
    -> f:
         (   key:Key.t
          -> [ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
          -> 'c option)
    -> 'c t

  val symmetric_diff :
       'a t
    -> 'a t
    -> data_equal:('a -> 'a -> bool)
    -> (Key.t, 'a) Base__.Map_intf.Symmetric_diff_element.t Base__.Sequence.t

  val fold_symmetric_diff :
       'a t
    -> 'a t
    -> data_equal:('a -> 'a -> bool)
    -> init:'c
    -> f:('c -> (Key.t, 'a) Base__.Map_intf.Symmetric_diff_element.t -> 'c)
    -> 'c

  val min_elt : 'a t -> (Key.t * 'a) option

  val min_elt_exn : 'a t -> Key.t * 'a

  val max_elt : 'a t -> (Key.t * 'a) option

  val max_elt_exn : 'a t -> Key.t * 'a

  val for_all : 'a t -> f:('a -> bool) -> bool

  val for_alli : 'a t -> f:(key:Key.t -> data:'a -> bool) -> bool

  val exists : 'a t -> f:('a -> bool) -> bool

  val existsi : 'a t -> f:(key:Key.t -> data:'a -> bool) -> bool

  val count : 'a t -> f:('a -> bool) -> int

  val counti : 'a t -> f:(key:Key.t -> data:'a -> bool) -> int

  val split : 'a t -> Key.t -> 'a t * (Key.t * 'a) option * 'a t

  val append :
       lower_part:'a t
    -> upper_part:'a t
    -> [ `Ok of 'a t | `Overlapping_key_ranges ]

  val subrange :
       'a t
    -> lower_bound:Key.t Base__.Maybe_bound.t
    -> upper_bound:Key.t Base__.Maybe_bound.t
    -> 'a t

  val fold_range_inclusive :
       'a t
    -> min:Key.t
    -> max:Key.t
    -> init:'b
    -> f:(key:Key.t -> data:'a -> 'b -> 'b)
    -> 'b

  val range_to_alist : 'a t -> min:Key.t -> max:Key.t -> (Key.t * 'a) list

  val closest_key :
       'a t
    -> [ `Greater_or_equal_to | `Greater_than | `Less_or_equal_to | `Less_than ]
    -> Key.t
    -> (Key.t * 'a) option

  val nth : 'a t -> int -> (Key.t * 'a) option

  val nth_exn : 'a t -> int -> Key.t * 'a

  val rank : 'a t -> Key.t -> int option

  val to_tree : 'a t -> 'a Tree.t

  val to_sequence :
       ?order:[ `Decreasing_key | `Increasing_key ]
    -> ?keys_greater_or_equal_to:Key.t
    -> ?keys_less_or_equal_to:Key.t
    -> 'a t
    -> (Key.t * 'a) Base__.Sequence.t

  val binary_search :
       'a t
    -> compare:(key:Key.t -> data:'a -> 'key -> int)
    -> [ `First_equal_to
       | `First_greater_than_or_equal_to
       | `First_strictly_greater_than
       | `Last_equal_to
       | `Last_less_than_or_equal_to
       | `Last_strictly_less_than ]
    -> 'key
    -> (Key.t * 'a) option

  val binary_search_segmented :
       'a t
    -> segment_of:(key:Key.t -> data:'a -> [ `Left | `Right ])
    -> [ `First_on_right | `Last_on_left ]
    -> (Key.t * 'a) option

  val key_set : 'a t -> (Key.t, comparator_witness) Base.Set.t

  val quickcheck_observer :
       Key.t Core_kernel__.Quickcheck.Observer.t
    -> 'v Core_kernel__.Quickcheck.Observer.t
    -> 'v t Core_kernel__.Quickcheck.Observer.t

  val quickcheck_shrinker :
       Key.t Core_kernel__.Quickcheck.Shrinker.t
    -> 'v Core_kernel__.Quickcheck.Shrinker.t
    -> 'v t Core_kernel__.Quickcheck.Shrinker.t

  module Provide_of_sexp : functor
    (Key : sig
       val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> Key.t
     end)
    -> sig
    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> 'v_x__002_ t
  end

  module Provide_bin_io : functor
    (Key : sig
       val bin_size_t : Key.t Bin_prot.Size.sizer

       val bin_write_t : Key.t Bin_prot.Write.writer

       val bin_read_t : Key.t Bin_prot.Read.reader

       val __bin_read_t__ : (int -> Key.t) Bin_prot.Read.reader

       val bin_shape_t : Bin_prot.Shape.t

       val bin_writer_t : Key.t Bin_prot.Type_class.writer

       val bin_reader_t : Key.t Bin_prot.Type_class.reader

       val bin_t : Key.t Bin_prot.Type_class.t
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

  module Provide_hash : functor
    (Key : sig
       val hash_fold_t : Base__.Hash.state -> Key.t -> Base__.Hash.state
     end)
    -> sig
    val hash_fold_t :
         (Ppx_hash_lib.Std.Hash.state -> 'a -> Ppx_hash_lib.Std.Hash.state)
      -> Ppx_hash_lib.Std.Hash.state
      -> 'a t
      -> Ppx_hash_lib.Std.Hash.state
  end

  val t_of_sexp : (Base__.Sexp.t -> 'a) -> Base__.Sexp.t -> 'a t

  val sexp_of_t : ('a -> Base__.Sexp.t) -> 'a t -> Base__.Sexp.t
end

module Set : sig
  module Elt : sig
    type t = Stable.V1.t

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    type comparator_witness = Stable.V1.comparator_witness

    val comparator : (t, comparator_witness) Core_kernel__.Comparator.comparator
  end

  module Tree : sig
    type t = (Elt.t, comparator_witness) Core_kernel__.Set_intf.Tree.t

    val compare : t -> t -> Core_kernel__.Import.int

    type named = (Elt.t, comparator_witness) Core_kernel__.Set_intf.Tree.Named.t

    val length : t -> int

    val is_empty : t -> bool

    val iter : t -> f:(Elt.t -> unit) -> unit

    val fold : t -> init:'accum -> f:('accum -> Elt.t -> 'accum) -> 'accum

    val fold_result :
         t
      -> init:'accum
      -> f:('accum -> Elt.t -> ('accum, 'e) Base__.Result.t)
      -> ('accum, 'e) Base__.Result.t

    val exists : t -> f:(Elt.t -> bool) -> bool

    val for_all : t -> f:(Elt.t -> bool) -> bool

    val count : t -> f:(Elt.t -> bool) -> int

    val sum :
         (module Base__.Container_intf.Summable with type t = 'sum)
      -> t
      -> f:(Elt.t -> 'sum)
      -> 'sum

    val find : t -> f:(Elt.t -> bool) -> Elt.t option

    val find_map : t -> f:(Elt.t -> 'a option) -> 'a option

    val to_list : t -> Elt.t list

    val to_array : t -> Elt.t array

    val invariants : t -> bool

    val mem : t -> Elt.t -> bool

    val add : t -> Elt.t -> t

    val remove : t -> Elt.t -> t

    val union : t -> t -> t

    val inter : t -> t -> t

    val diff : t -> t -> t

    val symmetric_diff :
      t -> t -> (Elt.t, Elt.t) Base__.Either.t Base__.Sequence.t

    val compare_direct : t -> t -> int

    val equal : t -> t -> bool

    val is_subset : t -> of_:t -> bool

    module Named : sig
      val is_subset : named -> of_:named -> unit Base__.Or_error.t

      val equal : named -> named -> unit Base__.Or_error.t
    end

    val fold_until :
         t
      -> init:'b
      -> f:('b -> Elt.t -> ('b, 'final) Base__.Set_intf.Continue_or_stop.t)
      -> finish:('b -> 'final)
      -> 'final

    val fold_right : t -> init:'b -> f:(Elt.t -> 'b -> 'b) -> 'b

    val iter2 :
         t
      -> t
      -> f:
           (   [ `Both of Elt.t * Elt.t | `Left of Elt.t | `Right of Elt.t ]
            -> unit)
      -> unit

    val filter : t -> f:(Elt.t -> bool) -> t

    val partition_tf : t -> f:(Elt.t -> bool) -> t * t

    val elements : t -> Elt.t list

    val min_elt : t -> Elt.t option

    val min_elt_exn : t -> Elt.t

    val max_elt : t -> Elt.t option

    val max_elt_exn : t -> Elt.t

    val choose : t -> Elt.t option

    val choose_exn : t -> Elt.t

    val split : t -> Elt.t -> t * Elt.t option * t

    val group_by : t -> equiv:(Elt.t -> Elt.t -> bool) -> t list

    val find_exn : t -> f:(Elt.t -> bool) -> Elt.t

    val nth : t -> int -> Elt.t option

    val remove_index : t -> int -> t

    val to_tree : t -> t

    val to_sequence :
         ?order:[ `Decreasing | `Increasing ]
      -> ?greater_or_equal_to:Elt.t
      -> ?less_or_equal_to:Elt.t
      -> t
      -> Elt.t Base__.Sequence.t

    val binary_search :
         t
      -> compare:(Elt.t -> 'key -> int)
      -> [ `First_equal_to
         | `First_greater_than_or_equal_to
         | `First_strictly_greater_than
         | `Last_equal_to
         | `Last_less_than_or_equal_to
         | `Last_strictly_less_than ]
      -> 'key
      -> Elt.t option

    val binary_search_segmented :
         t
      -> segment_of:(Elt.t -> [ `Left | `Right ])
      -> [ `First_on_right | `Last_on_left ]
      -> Elt.t option

    val merge_to_sequence :
         ?order:[ `Decreasing | `Increasing ]
      -> ?greater_or_equal_to:Elt.t
      -> ?less_or_equal_to:Elt.t
      -> t
      -> t
      -> (Elt.t, Elt.t) Base__.Set_intf.Merge_to_sequence_element.t
         Base__.Sequence.t

    val to_map :
      t -> f:(Elt.t -> 'data) -> (Elt.t, 'data, comparator_witness) Base.Map.t

    val quickcheck_observer :
         Elt.t Core_kernel__.Quickcheck.Observer.t
      -> t Core_kernel__.Quickcheck.Observer.t

    val quickcheck_shrinker :
         Elt.t Core_kernel__.Quickcheck.Shrinker.t
      -> t Core_kernel__.Quickcheck.Shrinker.t

    val empty : t

    val singleton : Elt.t -> t

    val union_list : t list -> t

    val of_list : Elt.t list -> t

    val of_array : Elt.t array -> t

    val of_sorted_array : Elt.t array -> t Base__.Or_error.t

    val of_sorted_array_unchecked : Elt.t array -> t

    val of_increasing_iterator_unchecked : len:int -> f:(int -> Elt.t) -> t

    val stable_dedup_list : Elt.t list -> Elt.t list

    val map : ('a, 'b) Core_kernel__.Set_intf.Tree.t -> f:('a -> Elt.t) -> t

    val filter_map :
      ('a, 'b) Core_kernel__.Set_intf.Tree.t -> f:('a -> Elt.t option) -> t

    val of_tree : t -> t

    val of_hash_set : Elt.t Core_kernel__.Hash_set.t -> t

    val of_hashtbl_keys : (Elt.t, 'a) Core_kernel__.Hashtbl.t -> t

    val of_map_keys : (Elt.t, 'a, comparator_witness) Base.Map.t -> t

    val quickcheck_generator :
         Elt.t Core_kernel__.Quickcheck.Generator.t
      -> t Core_kernel__.Quickcheck.Generator.t

    module Provide_of_sexp : functor
      (Elt : sig
         val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> Elt.t
       end)
      -> sig
      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
    end

    val t_of_sexp : Base__.Sexp.t -> t

    val sexp_of_t : t -> Base__.Sexp.t
  end

  type t = (Elt.t, comparator_witness) Base.Set.t

  val compare : t -> t -> Core_kernel__.Import.int

  type named = (Elt.t, comparator_witness) Core_kernel__.Set_intf.Named.t

  val length : t -> int

  val is_empty : t -> bool

  val iter : t -> f:(Elt.t -> unit) -> unit

  val fold : t -> init:'accum -> f:('accum -> Elt.t -> 'accum) -> 'accum

  val fold_result :
       t
    -> init:'accum
    -> f:('accum -> Elt.t -> ('accum, 'e) Base__.Result.t)
    -> ('accum, 'e) Base__.Result.t

  val exists : t -> f:(Elt.t -> bool) -> bool

  val for_all : t -> f:(Elt.t -> bool) -> bool

  val count : t -> f:(Elt.t -> bool) -> int

  val sum :
       (module Base__.Container_intf.Summable with type t = 'sum)
    -> t
    -> f:(Elt.t -> 'sum)
    -> 'sum

  val find : t -> f:(Elt.t -> bool) -> Elt.t option

  val find_map : t -> f:(Elt.t -> 'a option) -> 'a option

  val to_list : t -> Elt.t list

  val to_array : t -> Elt.t array

  val invariants : t -> bool

  val mem : t -> Elt.t -> bool

  val add : t -> Elt.t -> t

  val remove : t -> Elt.t -> t

  val union : t -> t -> t

  val inter : t -> t -> t

  val diff : t -> t -> t

  val symmetric_diff :
    t -> t -> (Elt.t, Elt.t) Base__.Either.t Base__.Sequence.t

  val compare_direct : t -> t -> int

  val equal : t -> t -> bool

  val is_subset : t -> of_:t -> bool

  module Named : sig
    val is_subset : named -> of_:named -> unit Base__.Or_error.t

    val equal : named -> named -> unit Base__.Or_error.t
  end

  val fold_until :
       t
    -> init:'b
    -> f:('b -> Elt.t -> ('b, 'final) Base__.Set_intf.Continue_or_stop.t)
    -> finish:('b -> 'final)
    -> 'final

  val fold_right : t -> init:'b -> f:(Elt.t -> 'b -> 'b) -> 'b

  val iter2 :
       t
    -> t
    -> f:([ `Both of Elt.t * Elt.t | `Left of Elt.t | `Right of Elt.t ] -> unit)
    -> unit

  val filter : t -> f:(Elt.t -> bool) -> t

  val partition_tf : t -> f:(Elt.t -> bool) -> t * t

  val elements : t -> Elt.t list

  val min_elt : t -> Elt.t option

  val min_elt_exn : t -> Elt.t

  val max_elt : t -> Elt.t option

  val max_elt_exn : t -> Elt.t

  val choose : t -> Elt.t option

  val choose_exn : t -> Elt.t

  val split : t -> Elt.t -> t * Elt.t option * t

  val group_by : t -> equiv:(Elt.t -> Elt.t -> bool) -> t list

  val find_exn : t -> f:(Elt.t -> bool) -> Elt.t

  val nth : t -> int -> Elt.t option

  val remove_index : t -> int -> t

  val to_tree : t -> Tree.t

  val to_sequence :
       ?order:[ `Decreasing | `Increasing ]
    -> ?greater_or_equal_to:Elt.t
    -> ?less_or_equal_to:Elt.t
    -> t
    -> Elt.t Base__.Sequence.t

  val binary_search :
       t
    -> compare:(Elt.t -> 'key -> int)
    -> [ `First_equal_to
       | `First_greater_than_or_equal_to
       | `First_strictly_greater_than
       | `Last_equal_to
       | `Last_less_than_or_equal_to
       | `Last_strictly_less_than ]
    -> 'key
    -> Elt.t option

  val binary_search_segmented :
       t
    -> segment_of:(Elt.t -> [ `Left | `Right ])
    -> [ `First_on_right | `Last_on_left ]
    -> Elt.t option

  val merge_to_sequence :
       ?order:[ `Decreasing | `Increasing ]
    -> ?greater_or_equal_to:Elt.t
    -> ?less_or_equal_to:Elt.t
    -> t
    -> t
    -> (Elt.t, Elt.t) Base__.Set_intf.Merge_to_sequence_element.t
       Base__.Sequence.t

  val to_map :
    t -> f:(Elt.t -> 'data) -> (Elt.t, 'data, comparator_witness) Base.Map.t

  val quickcheck_observer :
       Elt.t Core_kernel__.Quickcheck.Observer.t
    -> t Core_kernel__.Quickcheck.Observer.t

  val quickcheck_shrinker :
       Elt.t Core_kernel__.Quickcheck.Shrinker.t
    -> t Core_kernel__.Quickcheck.Shrinker.t

  val empty : t

  val singleton : Elt.t -> t

  val union_list : t list -> t

  val of_list : Elt.t list -> t

  val of_array : Elt.t array -> t

  val of_sorted_array : Elt.t array -> t Base__.Or_error.t

  val of_sorted_array_unchecked : Elt.t array -> t

  val of_increasing_iterator_unchecked : len:int -> f:(int -> Elt.t) -> t

  val stable_dedup_list : Elt.t list -> Elt.t list

  val map : ('a, 'b) Base.Set.t -> f:('a -> Elt.t) -> t

  val filter_map : ('a, 'b) Base.Set.t -> f:('a -> Elt.t option) -> t

  val of_tree : Tree.t -> t

  val of_hash_set : Elt.t Core_kernel__.Hash_set.t -> t

  val of_hashtbl_keys : (Elt.t, 'a) Core_kernel__.Hashtbl.t -> t

  val of_map_keys : (Elt.t, 'a, comparator_witness) Base.Map.t -> t

  val quickcheck_generator :
       Elt.t Core_kernel__.Quickcheck.Generator.t
    -> t Core_kernel__.Quickcheck.Generator.t

  module Provide_of_sexp : functor
    (Elt : sig
       val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> Elt.t
     end)
    -> sig
    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
  end

  module Provide_bin_io : functor
    (Elt : sig
       val bin_size_t : Elt.t Bin_prot.Size.sizer

       val bin_write_t : Elt.t Bin_prot.Write.writer

       val bin_read_t : Elt.t Bin_prot.Read.reader

       val __bin_read_t__ : (int -> Elt.t) Bin_prot.Read.reader

       val bin_shape_t : Bin_prot.Shape.t

       val bin_writer_t : Elt.t Bin_prot.Type_class.writer

       val bin_reader_t : Elt.t Bin_prot.Type_class.reader

       val bin_t : Elt.t Bin_prot.Type_class.t
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

  module Provide_hash : functor
    (Elt : sig
       val hash_fold_t : Base__.Hash.state -> Elt.t -> Base__.Hash.state
     end)
    -> sig
    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value
  end

  val t_of_sexp : Base__.Sexp.t -> t

  val sexp_of_t : t -> Base__.Sexp.t
end

val gen : t Core_kernel.Quickcheck.Generator.t
