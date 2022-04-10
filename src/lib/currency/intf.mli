type uint64 = Unsigned.uint64

module type Basic = sig
  type t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp : Sexplib0.Sexp.t -> t

  val sexp_of_t : t -> Sexplib0.Sexp.t

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  type magnitude = t

  val sexp_of_magnitude : t -> Ppx_sexp_conv_lib.Sexp.t

  val magnitude_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val compare_magnitude : t -> t -> int

  val dhall_type : Ppx_dhall_type.Dhall_type.t

  val max_int : t

  val length_in_bits : int

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

  type comparator_witness

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
      type t = magnitude

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t

      type comparator_witness_ := comparator_witness

      type comparator_witness = comparator_witness_

      val comparator :
        (t, comparator_witness) Core_kernel__.Comparator.comparator
    end

    module Tree : sig
      type 'a t =
        (magnitude, 'a, comparator_witness) Core_kernel__.Map_intf.Tree.t

      val empty : 'a t

      val singleton : magnitude -> 'a -> 'a t

      val of_alist :
        (magnitude * 'a) list -> [ `Duplicate_key of magnitude | `Ok of 'a t ]

      val of_alist_or_error : (magnitude * 'a) list -> 'a t Base__.Or_error.t

      val of_alist_exn : (magnitude * 'a) list -> 'a t

      val of_alist_multi : (magnitude * 'a) list -> 'a list t

      val of_alist_fold :
        (magnitude * 'a) list -> init:'b -> f:('b -> 'a -> 'b) -> 'b t

      val of_alist_reduce : (magnitude * 'a) list -> f:('a -> 'a -> 'a) -> 'a t

      val of_sorted_array : (magnitude * 'a) array -> 'a t Base__.Or_error.t

      val of_sorted_array_unchecked : (magnitude * 'a) array -> 'a t

      val of_increasing_iterator_unchecked :
        len:int -> f:(int -> magnitude * 'a) -> 'a t

      val of_increasing_sequence :
        (magnitude * 'a) Base__.Sequence.t -> 'a t Base__.Or_error.t

      val of_sequence :
           (magnitude * 'a) Base__.Sequence.t
        -> [ `Duplicate_key of magnitude | `Ok of 'a t ]

      val of_sequence_or_error :
        (magnitude * 'a) Base__.Sequence.t -> 'a t Base__.Or_error.t

      val of_sequence_exn : (magnitude * 'a) Base__.Sequence.t -> 'a t

      val of_sequence_multi : (magnitude * 'a) Base__.Sequence.t -> 'a list t

      val of_sequence_fold :
           (magnitude * 'a) Base__.Sequence.t
        -> init:'b
        -> f:('b -> 'a -> 'b)
        -> 'b t

      val of_sequence_reduce :
        (magnitude * 'a) Base__.Sequence.t -> f:('a -> 'a -> 'a) -> 'a t

      val of_iteri :
           iteri:(f:(key:magnitude -> data:'v -> unit) -> unit)
        -> [ `Duplicate_key of magnitude | `Ok of 'v t ]

      val of_tree : 'a t -> 'a t

      val of_hashtbl_exn : (magnitude, 'a) Core_kernel__.Hashtbl.t -> 'a t

      val of_key_set :
           (magnitude, comparator_witness) Base.Set.t
        -> f:(magnitude -> 'v)
        -> 'v t

      val quickcheck_generator :
           magnitude Core_kernel__.Quickcheck.Generator.t
        -> 'a Core_kernel__.Quickcheck.Generator.t
        -> 'a t Core_kernel__.Quickcheck.Generator.t

      val invariants : 'a t -> bool

      val is_empty : 'a t -> bool

      val length : 'a t -> int

      val add :
        'a t -> key:magnitude -> data:'a -> 'a t Base__.Map_intf.Or_duplicate.t

      val add_exn : 'a t -> key:magnitude -> data:'a -> 'a t

      val set : 'a t -> key:magnitude -> data:'a -> 'a t

      val add_multi : 'a list t -> key:magnitude -> data:'a -> 'a list t

      val remove_multi : 'a list t -> magnitude -> 'a list t

      val find_multi : 'a list t -> magnitude -> 'a list

      val change : 'a t -> magnitude -> f:('a option -> 'a option) -> 'a t

      val update : 'a t -> magnitude -> f:('a option -> 'a) -> 'a t

      val find : 'a t -> magnitude -> 'a option

      val find_exn : 'a t -> magnitude -> 'a

      val remove : 'a t -> magnitude -> 'a t

      val mem : 'a t -> magnitude -> bool

      val iter_keys : 'a t -> f:(magnitude -> unit) -> unit

      val iter : 'a t -> f:('a -> unit) -> unit

      val iteri : 'a t -> f:(key:magnitude -> data:'a -> unit) -> unit

      val iteri_until :
           'a t
        -> f:(key:magnitude -> data:'a -> Base__.Map_intf.Continue_or_stop.t)
        -> Base__.Map_intf.Finished_or_unfinished.t

      val iter2 :
           'a t
        -> 'b t
        -> f:
             (   key:magnitude
              -> data:[ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
              -> unit)
        -> unit

      val map : 'a t -> f:('a -> 'b) -> 'b t

      val mapi : 'a t -> f:(key:magnitude -> data:'a -> 'b) -> 'b t

      val fold :
        'a t -> init:'b -> f:(key:magnitude -> data:'a -> 'b -> 'b) -> 'b

      val fold_right :
        'a t -> init:'b -> f:(key:magnitude -> data:'a -> 'b -> 'b) -> 'b

      val fold2 :
           'a t
        -> 'b t
        -> init:'c
        -> f:
             (   key:magnitude
              -> data:[ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
              -> 'c
              -> 'c)
        -> 'c

      val filter_keys : 'a t -> f:(magnitude -> bool) -> 'a t

      val filter : 'a t -> f:('a -> bool) -> 'a t

      val filteri : 'a t -> f:(key:magnitude -> data:'a -> bool) -> 'a t

      val filter_map : 'a t -> f:('a -> 'b option) -> 'b t

      val filter_mapi :
        'a t -> f:(key:magnitude -> data:'a -> 'b option) -> 'b t

      val partition_mapi :
           'a t
        -> f:(key:magnitude -> data:'a -> [ `Fst of 'b | `Snd of 'c ])
        -> 'b t * 'c t

      val partition_map :
        'a t -> f:('a -> [ `Fst of 'b | `Snd of 'c ]) -> 'b t * 'c t

      val partitioni_tf :
        'a t -> f:(key:magnitude -> data:'a -> bool) -> 'a t * 'a t

      val partition_tf : 'a t -> f:('a -> bool) -> 'a t * 'a t

      val compare_direct : ('a -> 'a -> int) -> 'a t -> 'a t -> int

      val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

      val keys : 'a t -> magnitude list

      val data : 'a t -> 'a list

      val to_alist :
           ?key_order:[ `Decreasing | `Increasing ]
        -> 'a t
        -> (magnitude * 'a) list

      val validate :
           name:(magnitude -> string)
        -> 'a Base__.Validate.check
        -> 'a t Base__.Validate.check

      val merge :
           'a t
        -> 'b t
        -> f:
             (   key:magnitude
              -> [ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
              -> 'c option)
        -> 'c t

      val symmetric_diff :
           'a t
        -> 'a t
        -> data_equal:('a -> 'a -> bool)
        -> (magnitude, 'a) Base__.Map_intf.Symmetric_diff_element.t
           Base__.Sequence.t

      val fold_symmetric_diff :
           'a t
        -> 'a t
        -> data_equal:('a -> 'a -> bool)
        -> init:'c
        -> f:
             (   'c
              -> (magnitude, 'a) Base__.Map_intf.Symmetric_diff_element.t
              -> 'c)
        -> 'c

      val min_elt : 'a t -> (magnitude * 'a) option

      val min_elt_exn : 'a t -> magnitude * 'a

      val max_elt : 'a t -> (magnitude * 'a) option

      val max_elt_exn : 'a t -> magnitude * 'a

      val for_all : 'a t -> f:('a -> bool) -> bool

      val for_alli : 'a t -> f:(key:magnitude -> data:'a -> bool) -> bool

      val exists : 'a t -> f:('a -> bool) -> bool

      val existsi : 'a t -> f:(key:magnitude -> data:'a -> bool) -> bool

      val count : 'a t -> f:('a -> bool) -> int

      val counti : 'a t -> f:(key:magnitude -> data:'a -> bool) -> int

      val split : 'a t -> magnitude -> 'a t * (magnitude * 'a) option * 'a t

      val append :
           lower_part:'a t
        -> upper_part:'a t
        -> [ `Ok of 'a t | `Overlapping_key_ranges ]

      val subrange :
           'a t
        -> lower_bound:magnitude Base__.Maybe_bound.t
        -> upper_bound:magnitude Base__.Maybe_bound.t
        -> 'a t

      val fold_range_inclusive :
           'a t
        -> min:magnitude
        -> max:magnitude
        -> init:'b
        -> f:(key:magnitude -> data:'a -> 'b -> 'b)
        -> 'b

      val range_to_alist :
        'a t -> min:magnitude -> max:magnitude -> (magnitude * 'a) list

      val closest_key :
           'a t
        -> [ `Greater_or_equal_to
           | `Greater_than
           | `Less_or_equal_to
           | `Less_than ]
        -> magnitude
        -> (magnitude * 'a) option

      val nth : 'a t -> int -> (magnitude * 'a) option

      val nth_exn : 'a t -> int -> magnitude * 'a

      val rank : 'a t -> magnitude -> int option

      val to_tree : 'a t -> 'a t

      val to_sequence :
           ?order:[ `Decreasing_key | `Increasing_key ]
        -> ?keys_greater_or_equal_to:magnitude
        -> ?keys_less_or_equal_to:magnitude
        -> 'a t
        -> (magnitude * 'a) Base__.Sequence.t

      val binary_search :
           'a t
        -> compare:(key:magnitude -> data:'a -> 'key -> int)
        -> [ `First_equal_to
           | `First_greater_than_or_equal_to
           | `First_strictly_greater_than
           | `Last_equal_to
           | `Last_less_than_or_equal_to
           | `Last_strictly_less_than ]
        -> 'key
        -> (magnitude * 'a) option

      val binary_search_segmented :
           'a t
        -> segment_of:(key:magnitude -> data:'a -> [ `Left | `Right ])
        -> [ `First_on_right | `Last_on_left ]
        -> (magnitude * 'a) option

      val key_set : 'a t -> (magnitude, comparator_witness) Base.Set.t

      val quickcheck_observer :
           magnitude Core_kernel__.Quickcheck.Observer.t
        -> 'v Core_kernel__.Quickcheck.Observer.t
        -> 'v t Core_kernel__.Quickcheck.Observer.t

      val quickcheck_shrinker :
           magnitude Core_kernel__.Quickcheck.Shrinker.t
        -> 'v Core_kernel__.Quickcheck.Shrinker.t
        -> 'v t Core_kernel__.Quickcheck.Shrinker.t

      module Provide_of_sexp : functor
        (K : sig
           val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> magnitude
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

    type 'a t = (magnitude, 'a, comparator_witness) Core_kernel__.Map_intf.Map.t

    val compare :
         ('a -> 'a -> Core_kernel__.Import.int)
      -> 'a t
      -> 'a t
      -> Core_kernel__.Import.int

    val empty : 'a t

    val singleton : magnitude -> 'a -> 'a t

    val of_alist :
      (magnitude * 'a) list -> [ `Duplicate_key of magnitude | `Ok of 'a t ]

    val of_alist_or_error : (magnitude * 'a) list -> 'a t Base__.Or_error.t

    val of_alist_exn : (magnitude * 'a) list -> 'a t

    val of_alist_multi : (magnitude * 'a) list -> 'a list t

    val of_alist_fold :
      (magnitude * 'a) list -> init:'b -> f:('b -> 'a -> 'b) -> 'b t

    val of_alist_reduce : (magnitude * 'a) list -> f:('a -> 'a -> 'a) -> 'a t

    val of_sorted_array : (magnitude * 'a) array -> 'a t Base__.Or_error.t

    val of_sorted_array_unchecked : (magnitude * 'a) array -> 'a t

    val of_increasing_iterator_unchecked :
      len:int -> f:(int -> magnitude * 'a) -> 'a t

    val of_increasing_sequence :
      (magnitude * 'a) Base__.Sequence.t -> 'a t Base__.Or_error.t

    val of_sequence :
         (magnitude * 'a) Base__.Sequence.t
      -> [ `Duplicate_key of magnitude | `Ok of 'a t ]

    val of_sequence_or_error :
      (magnitude * 'a) Base__.Sequence.t -> 'a t Base__.Or_error.t

    val of_sequence_exn : (magnitude * 'a) Base__.Sequence.t -> 'a t

    val of_sequence_multi : (magnitude * 'a) Base__.Sequence.t -> 'a list t

    val of_sequence_fold :
         (magnitude * 'a) Base__.Sequence.t
      -> init:'b
      -> f:('b -> 'a -> 'b)
      -> 'b t

    val of_sequence_reduce :
      (magnitude * 'a) Base__.Sequence.t -> f:('a -> 'a -> 'a) -> 'a t

    val of_iteri :
         iteri:(f:(key:magnitude -> data:'v -> unit) -> unit)
      -> [ `Duplicate_key of magnitude | `Ok of 'v t ]

    val of_tree : 'a Tree.t -> 'a t

    val of_hashtbl_exn : (magnitude, 'a) Core_kernel__.Hashtbl.t -> 'a t

    val of_key_set :
      (magnitude, comparator_witness) Base.Set.t -> f:(magnitude -> 'v) -> 'v t

    val quickcheck_generator :
         magnitude Core_kernel__.Quickcheck.Generator.t
      -> 'a Core_kernel__.Quickcheck.Generator.t
      -> 'a t Core_kernel__.Quickcheck.Generator.t

    val invariants : 'a t -> bool

    val is_empty : 'a t -> bool

    val length : 'a t -> int

    val add :
      'a t -> key:magnitude -> data:'a -> 'a t Base__.Map_intf.Or_duplicate.t

    val add_exn : 'a t -> key:magnitude -> data:'a -> 'a t

    val set : 'a t -> key:magnitude -> data:'a -> 'a t

    val add_multi : 'a list t -> key:magnitude -> data:'a -> 'a list t

    val remove_multi : 'a list t -> magnitude -> 'a list t

    val find_multi : 'a list t -> magnitude -> 'a list

    val change : 'a t -> magnitude -> f:('a option -> 'a option) -> 'a t

    val update : 'a t -> magnitude -> f:('a option -> 'a) -> 'a t

    val find : 'a t -> magnitude -> 'a option

    val find_exn : 'a t -> magnitude -> 'a

    val remove : 'a t -> magnitude -> 'a t

    val mem : 'a t -> magnitude -> bool

    val iter_keys : 'a t -> f:(magnitude -> unit) -> unit

    val iter : 'a t -> f:('a -> unit) -> unit

    val iteri : 'a t -> f:(key:magnitude -> data:'a -> unit) -> unit

    val iteri_until :
         'a t
      -> f:(key:magnitude -> data:'a -> Base__.Map_intf.Continue_or_stop.t)
      -> Base__.Map_intf.Finished_or_unfinished.t

    val iter2 :
         'a t
      -> 'b t
      -> f:
           (   key:magnitude
            -> data:[ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
            -> unit)
      -> unit

    val map : 'a t -> f:('a -> 'b) -> 'b t

    val mapi : 'a t -> f:(key:magnitude -> data:'a -> 'b) -> 'b t

    val fold : 'a t -> init:'b -> f:(key:magnitude -> data:'a -> 'b -> 'b) -> 'b

    val fold_right :
      'a t -> init:'b -> f:(key:magnitude -> data:'a -> 'b -> 'b) -> 'b

    val fold2 :
         'a t
      -> 'b t
      -> init:'c
      -> f:
           (   key:magnitude
            -> data:[ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
            -> 'c
            -> 'c)
      -> 'c

    val filter_keys : 'a t -> f:(magnitude -> bool) -> 'a t

    val filter : 'a t -> f:('a -> bool) -> 'a t

    val filteri : 'a t -> f:(key:magnitude -> data:'a -> bool) -> 'a t

    val filter_map : 'a t -> f:('a -> 'b option) -> 'b t

    val filter_mapi : 'a t -> f:(key:magnitude -> data:'a -> 'b option) -> 'b t

    val partition_mapi :
         'a t
      -> f:(key:magnitude -> data:'a -> [ `Fst of 'b | `Snd of 'c ])
      -> 'b t * 'c t

    val partition_map :
      'a t -> f:('a -> [ `Fst of 'b | `Snd of 'c ]) -> 'b t * 'c t

    val partitioni_tf :
      'a t -> f:(key:magnitude -> data:'a -> bool) -> 'a t * 'a t

    val partition_tf : 'a t -> f:('a -> bool) -> 'a t * 'a t

    val compare_direct : ('a -> 'a -> int) -> 'a t -> 'a t -> int

    val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

    val keys : 'a t -> magnitude list

    val data : 'a t -> 'a list

    val to_alist :
      ?key_order:[ `Decreasing | `Increasing ] -> 'a t -> (magnitude * 'a) list

    val validate :
         name:(magnitude -> string)
      -> 'a Base__.Validate.check
      -> 'a t Base__.Validate.check

    val merge :
         'a t
      -> 'b t
      -> f:
           (   key:magnitude
            -> [ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
            -> 'c option)
      -> 'c t

    val symmetric_diff :
         'a t
      -> 'a t
      -> data_equal:('a -> 'a -> bool)
      -> (magnitude, 'a) Base__.Map_intf.Symmetric_diff_element.t
         Base__.Sequence.t

    val fold_symmetric_diff :
         'a t
      -> 'a t
      -> data_equal:('a -> 'a -> bool)
      -> init:'c
      -> f:
           (   'c
            -> (magnitude, 'a) Base__.Map_intf.Symmetric_diff_element.t
            -> 'c)
      -> 'c

    val min_elt : 'a t -> (magnitude * 'a) option

    val min_elt_exn : 'a t -> magnitude * 'a

    val max_elt : 'a t -> (magnitude * 'a) option

    val max_elt_exn : 'a t -> magnitude * 'a

    val for_all : 'a t -> f:('a -> bool) -> bool

    val for_alli : 'a t -> f:(key:magnitude -> data:'a -> bool) -> bool

    val exists : 'a t -> f:('a -> bool) -> bool

    val existsi : 'a t -> f:(key:magnitude -> data:'a -> bool) -> bool

    val count : 'a t -> f:('a -> bool) -> int

    val counti : 'a t -> f:(key:magnitude -> data:'a -> bool) -> int

    val split : 'a t -> magnitude -> 'a t * (magnitude * 'a) option * 'a t

    val append :
         lower_part:'a t
      -> upper_part:'a t
      -> [ `Ok of 'a t | `Overlapping_key_ranges ]

    val subrange :
         'a t
      -> lower_bound:magnitude Base__.Maybe_bound.t
      -> upper_bound:magnitude Base__.Maybe_bound.t
      -> 'a t

    val fold_range_inclusive :
         'a t
      -> min:magnitude
      -> max:magnitude
      -> init:'b
      -> f:(key:magnitude -> data:'a -> 'b -> 'b)
      -> 'b

    val range_to_alist :
      'a t -> min:magnitude -> max:magnitude -> (magnitude * 'a) list

    val closest_key :
         'a t
      -> [ `Greater_or_equal_to
         | `Greater_than
         | `Less_or_equal_to
         | `Less_than ]
      -> magnitude
      -> (magnitude * 'a) option

    val nth : 'a t -> int -> (magnitude * 'a) option

    val nth_exn : 'a t -> int -> magnitude * 'a

    val rank : 'a t -> magnitude -> int option

    val to_tree : 'a t -> 'a Tree.t

    val to_sequence :
         ?order:[ `Decreasing_key | `Increasing_key ]
      -> ?keys_greater_or_equal_to:magnitude
      -> ?keys_less_or_equal_to:magnitude
      -> 'a t
      -> (magnitude * 'a) Base__.Sequence.t

    val binary_search :
         'a t
      -> compare:(key:magnitude -> data:'a -> 'key -> int)
      -> [ `First_equal_to
         | `First_greater_than_or_equal_to
         | `First_strictly_greater_than
         | `Last_equal_to
         | `Last_less_than_or_equal_to
         | `Last_strictly_less_than ]
      -> 'key
      -> (magnitude * 'a) option

    val binary_search_segmented :
         'a t
      -> segment_of:(key:magnitude -> data:'a -> [ `Left | `Right ])
      -> [ `First_on_right | `Last_on_left ]
      -> (magnitude * 'a) option

    val key_set : 'a t -> (magnitude, comparator_witness) Base.Set.t

    val quickcheck_observer :
         magnitude Core_kernel__.Quickcheck.Observer.t
      -> 'v Core_kernel__.Quickcheck.Observer.t
      -> 'v t Core_kernel__.Quickcheck.Observer.t

    val quickcheck_shrinker :
         magnitude Core_kernel__.Quickcheck.Shrinker.t
      -> 'v Core_kernel__.Quickcheck.Shrinker.t
      -> 'v t Core_kernel__.Quickcheck.Shrinker.t

    module Provide_of_sexp : functor
      (Key : sig
         val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> magnitude
       end)
      -> sig
      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> 'v_x__002_ t
    end

    module Provide_bin_io : functor
      (Key : sig
         val bin_size_t : magnitude Bin_prot.Size.sizer

         val bin_write_t : magnitude Bin_prot.Write.writer

         val bin_read_t : magnitude Bin_prot.Read.reader

         val __bin_read_t__ : (int -> magnitude) Bin_prot.Read.reader

         val bin_shape_t : Bin_prot.Shape.t

         val bin_writer_t : magnitude Bin_prot.Type_class.writer

         val bin_reader_t : magnitude Bin_prot.Type_class.reader

         val bin_t : magnitude Bin_prot.Type_class.t
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
         val hash_fold_t : Base__.Hash.state -> magnitude -> Base__.Hash.state
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
      type t = magnitude

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t

      type comparator_witness = Map.Key.comparator_witness

      val comparator :
        (t, comparator_witness) Core_kernel__.Comparator.comparator
    end

    module Tree : sig
      type t = (magnitude, comparator_witness) Core_kernel__.Set_intf.Tree.t

      val compare : t -> t -> Core_kernel__.Import.int

      type named =
        (magnitude, comparator_witness) Core_kernel__.Set_intf.Tree.Named.t

      val length : t -> int

      val is_empty : t -> bool

      val iter : t -> f:(magnitude -> unit) -> unit

      val fold : t -> init:'accum -> f:('accum -> magnitude -> 'accum) -> 'accum

      val fold_result :
           t
        -> init:'accum
        -> f:('accum -> magnitude -> ('accum, 'e) Base__.Result.t)
        -> ('accum, 'e) Base__.Result.t

      val exists : t -> f:(magnitude -> bool) -> bool

      val for_all : t -> f:(magnitude -> bool) -> bool

      val count : t -> f:(magnitude -> bool) -> int

      val sum :
           (module Base__.Container_intf.Summable with type t = 'sum)
        -> t
        -> f:(magnitude -> 'sum)
        -> 'sum

      val find : t -> f:(magnitude -> bool) -> magnitude option

      val find_map : t -> f:(magnitude -> 'a option) -> 'a option

      val to_list : t -> magnitude list

      val to_array : t -> magnitude array

      val invariants : t -> bool

      val mem : t -> magnitude -> bool

      val add : t -> magnitude -> t

      val remove : t -> magnitude -> t

      val union : t -> t -> t

      val inter : t -> t -> t

      val diff : t -> t -> t

      val symmetric_diff :
        t -> t -> (magnitude, magnitude) Base__.Either.t Base__.Sequence.t

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
        -> f:
             (   'b
              -> magnitude
              -> ('b, 'final) Base__.Set_intf.Continue_or_stop.t)
        -> finish:('b -> 'final)
        -> 'final

      val fold_right : t -> init:'b -> f:(magnitude -> 'b -> 'b) -> 'b

      val iter2 :
           t
        -> t
        -> f:
             (   [ `Both of magnitude * magnitude
                 | `Left of magnitude
                 | `Right of magnitude ]
              -> unit)
        -> unit

      val filter : t -> f:(magnitude -> bool) -> t

      val partition_tf : t -> f:(magnitude -> bool) -> t * t

      val elements : t -> magnitude list

      val min_elt : t -> magnitude option

      val min_elt_exn : t -> magnitude

      val max_elt : t -> magnitude option

      val max_elt_exn : t -> magnitude

      val choose : t -> magnitude option

      val choose_exn : t -> magnitude

      val split : t -> magnitude -> t * magnitude option * t

      val group_by : t -> equiv:(magnitude -> magnitude -> bool) -> t list

      val find_exn : t -> f:(magnitude -> bool) -> magnitude

      val nth : t -> int -> magnitude option

      val remove_index : t -> int -> t

      val to_tree : t -> t

      val to_sequence :
           ?order:[ `Decreasing | `Increasing ]
        -> ?greater_or_equal_to:magnitude
        -> ?less_or_equal_to:magnitude
        -> t
        -> magnitude Base__.Sequence.t

      val binary_search :
           t
        -> compare:(magnitude -> 'key -> int)
        -> [ `First_equal_to
           | `First_greater_than_or_equal_to
           | `First_strictly_greater_than
           | `Last_equal_to
           | `Last_less_than_or_equal_to
           | `Last_strictly_less_than ]
        -> 'key
        -> magnitude option

      val binary_search_segmented :
           t
        -> segment_of:(magnitude -> [ `Left | `Right ])
        -> [ `First_on_right | `Last_on_left ]
        -> magnitude option

      val merge_to_sequence :
           ?order:[ `Decreasing | `Increasing ]
        -> ?greater_or_equal_to:magnitude
        -> ?less_or_equal_to:magnitude
        -> t
        -> t
        -> (magnitude, magnitude) Base__.Set_intf.Merge_to_sequence_element.t
           Base__.Sequence.t

      val to_map :
           t
        -> f:(magnitude -> 'data)
        -> (magnitude, 'data, comparator_witness) Base.Map.t

      val quickcheck_observer :
           magnitude Core_kernel__.Quickcheck.Observer.t
        -> t Core_kernel__.Quickcheck.Observer.t

      val quickcheck_shrinker :
           magnitude Core_kernel__.Quickcheck.Shrinker.t
        -> t Core_kernel__.Quickcheck.Shrinker.t

      val empty : t

      val singleton : magnitude -> t

      val union_list : t list -> t

      val of_list : magnitude list -> t

      val of_array : magnitude array -> t

      val of_sorted_array : magnitude array -> t Base__.Or_error.t

      val of_sorted_array_unchecked : magnitude array -> t

      val of_increasing_iterator_unchecked :
        len:int -> f:(int -> magnitude) -> t

      val stable_dedup_list : magnitude list -> magnitude list

      val map :
        ('a, 'b) Core_kernel__.Set_intf.Tree.t -> f:('a -> magnitude) -> t

      val filter_map :
           ('a, 'b) Core_kernel__.Set_intf.Tree.t
        -> f:('a -> magnitude option)
        -> t

      val of_tree : t -> t

      val of_hash_set : magnitude Core_kernel__.Hash_set.t -> t

      val of_hashtbl_keys : (magnitude, 'a) Core_kernel__.Hashtbl.t -> t

      val of_map_keys : (magnitude, 'a, comparator_witness) Base.Map.t -> t

      val quickcheck_generator :
           magnitude Core_kernel__.Quickcheck.Generator.t
        -> t Core_kernel__.Quickcheck.Generator.t

      module Provide_of_sexp : functor
        (Elt : sig
           val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> magnitude
         end)
        -> sig
        val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
      end

      val t_of_sexp : Base__.Sexp.t -> t

      val sexp_of_t : t -> Base__.Sexp.t
    end

    type t = (magnitude, comparator_witness) Base.Set.t

    val compare : t -> t -> Core_kernel__.Import.int

    type named = (magnitude, comparator_witness) Core_kernel__.Set_intf.Named.t

    val length : t -> int

    val is_empty : t -> bool

    val iter : t -> f:(magnitude -> unit) -> unit

    val fold : t -> init:'accum -> f:('accum -> magnitude -> 'accum) -> 'accum

    val fold_result :
         t
      -> init:'accum
      -> f:('accum -> magnitude -> ('accum, 'e) Base__.Result.t)
      -> ('accum, 'e) Base__.Result.t

    val exists : t -> f:(magnitude -> bool) -> bool

    val for_all : t -> f:(magnitude -> bool) -> bool

    val count : t -> f:(magnitude -> bool) -> int

    val sum :
         (module Base__.Container_intf.Summable with type t = 'sum)
      -> t
      -> f:(magnitude -> 'sum)
      -> 'sum

    val find : t -> f:(magnitude -> bool) -> magnitude option

    val find_map : t -> f:(magnitude -> 'a option) -> 'a option

    val to_list : t -> magnitude list

    val to_array : t -> magnitude array

    val invariants : t -> bool

    val mem : t -> magnitude -> bool

    val add : t -> magnitude -> t

    val remove : t -> magnitude -> t

    val union : t -> t -> t

    val inter : t -> t -> t

    val diff : t -> t -> t

    val symmetric_diff :
      t -> t -> (magnitude, magnitude) Base__.Either.t Base__.Sequence.t

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
      -> f:('b -> magnitude -> ('b, 'final) Base__.Set_intf.Continue_or_stop.t)
      -> finish:('b -> 'final)
      -> 'final

    val fold_right : t -> init:'b -> f:(magnitude -> 'b -> 'b) -> 'b

    val iter2 :
         t
      -> t
      -> f:
           (   [ `Both of magnitude * magnitude
               | `Left of magnitude
               | `Right of magnitude ]
            -> unit)
      -> unit

    val filter : t -> f:(magnitude -> bool) -> t

    val partition_tf : t -> f:(magnitude -> bool) -> t * t

    val elements : t -> magnitude list

    val min_elt : t -> magnitude option

    val min_elt_exn : t -> magnitude

    val max_elt : t -> magnitude option

    val max_elt_exn : t -> magnitude

    val choose : t -> magnitude option

    val choose_exn : t -> magnitude

    val split : t -> magnitude -> t * magnitude option * t

    val group_by : t -> equiv:(magnitude -> magnitude -> bool) -> t list

    val find_exn : t -> f:(magnitude -> bool) -> magnitude

    val nth : t -> int -> magnitude option

    val remove_index : t -> int -> t

    val to_tree : t -> Tree.t

    val to_sequence :
         ?order:[ `Decreasing | `Increasing ]
      -> ?greater_or_equal_to:magnitude
      -> ?less_or_equal_to:magnitude
      -> t
      -> magnitude Base__.Sequence.t

    val binary_search :
         t
      -> compare:(magnitude -> 'key -> int)
      -> [ `First_equal_to
         | `First_greater_than_or_equal_to
         | `First_strictly_greater_than
         | `Last_equal_to
         | `Last_less_than_or_equal_to
         | `Last_strictly_less_than ]
      -> 'key
      -> magnitude option

    val binary_search_segmented :
         t
      -> segment_of:(magnitude -> [ `Left | `Right ])
      -> [ `First_on_right | `Last_on_left ]
      -> magnitude option

    val merge_to_sequence :
         ?order:[ `Decreasing | `Increasing ]
      -> ?greater_or_equal_to:magnitude
      -> ?less_or_equal_to:magnitude
      -> t
      -> t
      -> (magnitude, magnitude) Base__.Set_intf.Merge_to_sequence_element.t
         Base__.Sequence.t

    val to_map :
         t
      -> f:(magnitude -> 'data)
      -> (magnitude, 'data, comparator_witness) Base.Map.t

    val quickcheck_observer :
         magnitude Core_kernel__.Quickcheck.Observer.t
      -> t Core_kernel__.Quickcheck.Observer.t

    val quickcheck_shrinker :
         magnitude Core_kernel__.Quickcheck.Shrinker.t
      -> t Core_kernel__.Quickcheck.Shrinker.t

    val empty : t

    val singleton : magnitude -> t

    val union_list : t list -> t

    val of_list : magnitude list -> t

    val of_array : magnitude array -> t

    val of_sorted_array : magnitude array -> t Base__.Or_error.t

    val of_sorted_array_unchecked : magnitude array -> t

    val of_increasing_iterator_unchecked : len:int -> f:(int -> magnitude) -> t

    val stable_dedup_list : magnitude list -> magnitude list

    val map : ('a, 'b) Base.Set.t -> f:('a -> magnitude) -> t

    val filter_map : ('a, 'b) Base.Set.t -> f:('a -> magnitude option) -> t

    val of_tree : Tree.t -> t

    val of_hash_set : magnitude Core_kernel__.Hash_set.t -> t

    val of_hashtbl_keys : (magnitude, 'a) Core_kernel__.Hashtbl.t -> t

    val of_map_keys : (magnitude, 'a, comparator_witness) Base.Map.t -> t

    val quickcheck_generator :
         magnitude Core_kernel__.Quickcheck.Generator.t
      -> t Core_kernel__.Quickcheck.Generator.t

    module Provide_of_sexp : functor
      (Elt : sig
         val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> magnitude
       end)
      -> sig
      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
    end

    module Provide_bin_io : functor
      (Elt : sig
         val bin_size_t : magnitude Bin_prot.Size.sizer

         val bin_write_t : magnitude Bin_prot.Write.writer

         val bin_read_t : magnitude Bin_prot.Read.reader

         val __bin_read_t__ : (int -> magnitude) Bin_prot.Read.reader

         val bin_shape_t : Bin_prot.Shape.t

         val bin_writer_t : magnitude Bin_prot.Type_class.writer

         val bin_reader_t : magnitude Bin_prot.Type_class.reader

         val bin_t : magnitude Bin_prot.Type_class.t
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
         val hash_fold_t : Base__.Hash.state -> magnitude -> Base__.Hash.state
       end)
      -> sig
      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value
    end

    val t_of_sexp : Base__.Sexp.t -> t

    val sexp_of_t : t -> Base__.Sexp.t
  end

  val gen_incl : t -> t -> t Core_kernel.Quickcheck.Generator.t

  val gen : t Core_kernel.Quickcheck.Generator.t

  val fold : t -> bool Fold_lib.Fold.t

  val size_in_bits : int

  val iter : t -> f:(bool -> unit) -> unit

  val to_bits : t -> bool list

  val of_bits : bool list -> t

  val to_input : t -> ('a, bool) Random_oracle.Input.t

  val zero : t

  val one : t

  val of_string : string -> t

  val to_string : t -> string

  val of_formatted_string : string -> t

  val to_formatted_string : t -> string

  val of_int : int -> t

  val to_int : t -> int

  val to_uint64 : t -> uint64

  val of_uint64 : uint64 -> t

  type var

  val typ : (var, t) Snark_params.Tick.Typ.t

  val var_of_t : t -> var

  val var_to_number : var -> Snark_params.Tick.Number.t

  val var_to_bits :
    var -> Snark_params.Tick.Boolean.var Bitstring_lib.Bitstring.Lsb_first.t

  val var_to_input :
    var -> ('a, Snark_params.Tick.Boolean.var) Random_oracle.Input.t

  val equal_var :
       var
    -> var
    -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t
end

module type Arithmetic_intf = sig
  type t

  val add : t -> t -> t option

  val sub : t -> t -> t option

  val ( + ) : t -> t -> t option

  val ( - ) : t -> t -> t option

  val scale : t -> int -> t option
end

module type Signed_intf = sig
  type magnitude

  type magnitude_var

  type t = (magnitude, Sgn.t) Signed_poly.t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp : Sexplib0.Sexp.t -> t

  val sexp_of_t : t -> Sexplib0.Sexp.t

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val compare : t -> t -> int

  val equal : t -> t -> bool

  val gen : t Core_kernel.Quickcheck.Generator.t

  val create :
    magnitude:'magnitude -> sgn:'sgn -> ('magnitude, 'sgn) Signed_poly.t

  val sgn : t -> Sgn.t

  val magnitude : t -> magnitude

  val zero : t

  val is_zero : t -> bool

  val is_positive : t -> bool

  val is_negative : t -> bool

  val to_input : t -> ('a, bool) Random_oracle.Input.t

  val add : t -> t -> t option

  val ( + ) : t -> t -> t option

  val negate : t -> t

  val of_unsigned : magnitude -> t

  type var = (magnitude_var, Sgn.var) Signed_poly.t

  val typ : (var, t) Snark_params.Tick.Typ.t

  module Checked : sig
    val constant : t -> var

    val of_unsigned : magnitude_var -> var

    val negate : var -> var

    val if_ :
         Snark_params.Tick.Boolean.var
      -> then_:var
      -> else_:var
      -> (var, 'a) Snark_params.Tick.Checked.t

    val to_input :
      var -> ('a, Snark_params.Tick.Boolean.var) Random_oracle.Input.t

    val add : var -> var -> (var, 'a) Snark_params.Tick.Checked.t

    val assert_equal : var -> var -> (unit, 'a) Snark_params.Tick.Checked.t

    val equal :
         var
      -> var
      -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

    val ( + ) : var -> var -> (var, 'a) Snark_params.Tick.Checked.t

    val to_field_var :
      var -> (Snark_params.Tick.Field.Var.t, 'a) Snark_params.Tick.Checked.t

    val scale :
         Snark_params.Tick.Field.Var.t
      -> var
      -> (var, 'a) Snark_params.Tick.Checked.t

    val cswap :
         Snark_params.Tick.Boolean.var
      -> (magnitude_var, Sgn.t) Signed_poly.t
         * (magnitude_var, Sgn.t) Signed_poly.t
      -> (var * var, 'a) Snark_params.Tick.Checked.t

    type t = var
  end
end

module type Checked_arithmetic_intf = sig
  type value

  type var

  type t = var

  type signed_var

  val if_ :
       Snark_params.Tick.Boolean.var
    -> then_:var
    -> else_:var
    -> (var, 'a) Snark_params.Tick.Checked.t

  val if_value :
    Snark_params.Tick.Boolean.var -> then_:value -> else_:value -> var

  val add : var -> var -> (var, 'a) Snark_params.Tick.Checked.t

  val sub : var -> var -> (var, 'a) Snark_params.Tick.Checked.t

  val sub_flagged :
       var
    -> var
    -> ( var * [ `Underflow of Snark_params.Tick.Boolean.var ]
       , 'a )
       Snark_params.Tick.Checked.t

  val add_flagged :
       var
    -> var
    -> ( var * [ `Overflow of Snark_params.Tick.Boolean.var ]
       , 'a )
       Snark_params.Tick.Checked.t

  val ( + ) : var -> var -> (var, 'a) Snark_params.Tick.Checked.t

  val ( - ) : var -> var -> (var, 'a) Snark_params.Tick.Checked.t

  val add_signed : var -> signed_var -> (var, 'a) Snark_params.Tick.Checked.t

  val add_signed_flagged :
       var
    -> signed_var
    -> ( var * [ `Overflow of Snark_params.Tick.Boolean.var ]
       , 'a )
       Snark_params.Tick.Checked.t

  val assert_equal : var -> var -> (unit, 'a) Snark_params.Tick.Checked.t

  val equal :
       var
    -> var
    -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

  val ( = ) :
       var
    -> var
    -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

  val ( < ) :
       var
    -> var
    -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

  val ( > ) :
       var
    -> var
    -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

  val ( <= ) :
       var
    -> var
    -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

  val ( >= ) :
       var
    -> var
    -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

  val scale :
       Snark_params.Tick.Field.Var.t
    -> var
    -> (var, 'a) Snark_params.Tick.Checked.t
end

module type S = sig
  type t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp : Sexplib0.Sexp.t -> t

  val sexp_of_t : t -> Sexplib0.Sexp.t

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  type magnitude = t

  val sexp_of_magnitude : t -> Ppx_sexp_conv_lib.Sexp.t

  val magnitude_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val compare_magnitude : t -> t -> int

  val dhall_type : Ppx_dhall_type.Dhall_type.t

  val max_int : t

  val length_in_bits : int

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

  type comparator_witness

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
      type t = magnitude

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t

      type comparator_witness_ := comparator_witness

      type comparator_witness = comparator_witness_

      val comparator :
        (t, comparator_witness) Core_kernel__.Comparator.comparator
    end

    module Tree : sig
      type 'a t =
        (magnitude, 'a, comparator_witness) Core_kernel__.Map_intf.Tree.t

      val empty : 'a t

      val singleton : magnitude -> 'a -> 'a t

      val of_alist :
        (magnitude * 'a) list -> [ `Duplicate_key of magnitude | `Ok of 'a t ]

      val of_alist_or_error : (magnitude * 'a) list -> 'a t Base__.Or_error.t

      val of_alist_exn : (magnitude * 'a) list -> 'a t

      val of_alist_multi : (magnitude * 'a) list -> 'a list t

      val of_alist_fold :
        (magnitude * 'a) list -> init:'b -> f:('b -> 'a -> 'b) -> 'b t

      val of_alist_reduce : (magnitude * 'a) list -> f:('a -> 'a -> 'a) -> 'a t

      val of_sorted_array : (magnitude * 'a) array -> 'a t Base__.Or_error.t

      val of_sorted_array_unchecked : (magnitude * 'a) array -> 'a t

      val of_increasing_iterator_unchecked :
        len:int -> f:(int -> magnitude * 'a) -> 'a t

      val of_increasing_sequence :
        (magnitude * 'a) Base__.Sequence.t -> 'a t Base__.Or_error.t

      val of_sequence :
           (magnitude * 'a) Base__.Sequence.t
        -> [ `Duplicate_key of magnitude | `Ok of 'a t ]

      val of_sequence_or_error :
        (magnitude * 'a) Base__.Sequence.t -> 'a t Base__.Or_error.t

      val of_sequence_exn : (magnitude * 'a) Base__.Sequence.t -> 'a t

      val of_sequence_multi : (magnitude * 'a) Base__.Sequence.t -> 'a list t

      val of_sequence_fold :
           (magnitude * 'a) Base__.Sequence.t
        -> init:'b
        -> f:('b -> 'a -> 'b)
        -> 'b t

      val of_sequence_reduce :
        (magnitude * 'a) Base__.Sequence.t -> f:('a -> 'a -> 'a) -> 'a t

      val of_iteri :
           iteri:(f:(key:magnitude -> data:'v -> unit) -> unit)
        -> [ `Duplicate_key of magnitude | `Ok of 'v t ]

      val of_tree : 'a t -> 'a t

      val of_hashtbl_exn : (magnitude, 'a) Core_kernel__.Hashtbl.t -> 'a t

      val of_key_set :
           (magnitude, comparator_witness) Base.Set.t
        -> f:(magnitude -> 'v)
        -> 'v t

      val quickcheck_generator :
           magnitude Core_kernel__.Quickcheck.Generator.t
        -> 'a Core_kernel__.Quickcheck.Generator.t
        -> 'a t Core_kernel__.Quickcheck.Generator.t

      val invariants : 'a t -> bool

      val is_empty : 'a t -> bool

      val length : 'a t -> int

      val add :
        'a t -> key:magnitude -> data:'a -> 'a t Base__.Map_intf.Or_duplicate.t

      val add_exn : 'a t -> key:magnitude -> data:'a -> 'a t

      val set : 'a t -> key:magnitude -> data:'a -> 'a t

      val add_multi : 'a list t -> key:magnitude -> data:'a -> 'a list t

      val remove_multi : 'a list t -> magnitude -> 'a list t

      val find_multi : 'a list t -> magnitude -> 'a list

      val change : 'a t -> magnitude -> f:('a option -> 'a option) -> 'a t

      val update : 'a t -> magnitude -> f:('a option -> 'a) -> 'a t

      val find : 'a t -> magnitude -> 'a option

      val find_exn : 'a t -> magnitude -> 'a

      val remove : 'a t -> magnitude -> 'a t

      val mem : 'a t -> magnitude -> bool

      val iter_keys : 'a t -> f:(magnitude -> unit) -> unit

      val iter : 'a t -> f:('a -> unit) -> unit

      val iteri : 'a t -> f:(key:magnitude -> data:'a -> unit) -> unit

      val iteri_until :
           'a t
        -> f:(key:magnitude -> data:'a -> Base__.Map_intf.Continue_or_stop.t)
        -> Base__.Map_intf.Finished_or_unfinished.t

      val iter2 :
           'a t
        -> 'b t
        -> f:
             (   key:magnitude
              -> data:[ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
              -> unit)
        -> unit

      val map : 'a t -> f:('a -> 'b) -> 'b t

      val mapi : 'a t -> f:(key:magnitude -> data:'a -> 'b) -> 'b t

      val fold :
        'a t -> init:'b -> f:(key:magnitude -> data:'a -> 'b -> 'b) -> 'b

      val fold_right :
        'a t -> init:'b -> f:(key:magnitude -> data:'a -> 'b -> 'b) -> 'b

      val fold2 :
           'a t
        -> 'b t
        -> init:'c
        -> f:
             (   key:magnitude
              -> data:[ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
              -> 'c
              -> 'c)
        -> 'c

      val filter_keys : 'a t -> f:(magnitude -> bool) -> 'a t

      val filter : 'a t -> f:('a -> bool) -> 'a t

      val filteri : 'a t -> f:(key:magnitude -> data:'a -> bool) -> 'a t

      val filter_map : 'a t -> f:('a -> 'b option) -> 'b t

      val filter_mapi :
        'a t -> f:(key:magnitude -> data:'a -> 'b option) -> 'b t

      val partition_mapi :
           'a t
        -> f:(key:magnitude -> data:'a -> [ `Fst of 'b | `Snd of 'c ])
        -> 'b t * 'c t

      val partition_map :
        'a t -> f:('a -> [ `Fst of 'b | `Snd of 'c ]) -> 'b t * 'c t

      val partitioni_tf :
        'a t -> f:(key:magnitude -> data:'a -> bool) -> 'a t * 'a t

      val partition_tf : 'a t -> f:('a -> bool) -> 'a t * 'a t

      val compare_direct : ('a -> 'a -> int) -> 'a t -> 'a t -> int

      val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

      val keys : 'a t -> magnitude list

      val data : 'a t -> 'a list

      val to_alist :
           ?key_order:[ `Decreasing | `Increasing ]
        -> 'a t
        -> (magnitude * 'a) list

      val validate :
           name:(magnitude -> string)
        -> 'a Base__.Validate.check
        -> 'a t Base__.Validate.check

      val merge :
           'a t
        -> 'b t
        -> f:
             (   key:magnitude
              -> [ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
              -> 'c option)
        -> 'c t

      val symmetric_diff :
           'a t
        -> 'a t
        -> data_equal:('a -> 'a -> bool)
        -> (magnitude, 'a) Base__.Map_intf.Symmetric_diff_element.t
           Base__.Sequence.t

      val fold_symmetric_diff :
           'a t
        -> 'a t
        -> data_equal:('a -> 'a -> bool)
        -> init:'c
        -> f:
             (   'c
              -> (magnitude, 'a) Base__.Map_intf.Symmetric_diff_element.t
              -> 'c)
        -> 'c

      val min_elt : 'a t -> (magnitude * 'a) option

      val min_elt_exn : 'a t -> magnitude * 'a

      val max_elt : 'a t -> (magnitude * 'a) option

      val max_elt_exn : 'a t -> magnitude * 'a

      val for_all : 'a t -> f:('a -> bool) -> bool

      val for_alli : 'a t -> f:(key:magnitude -> data:'a -> bool) -> bool

      val exists : 'a t -> f:('a -> bool) -> bool

      val existsi : 'a t -> f:(key:magnitude -> data:'a -> bool) -> bool

      val count : 'a t -> f:('a -> bool) -> int

      val counti : 'a t -> f:(key:magnitude -> data:'a -> bool) -> int

      val split : 'a t -> magnitude -> 'a t * (magnitude * 'a) option * 'a t

      val append :
           lower_part:'a t
        -> upper_part:'a t
        -> [ `Ok of 'a t | `Overlapping_key_ranges ]

      val subrange :
           'a t
        -> lower_bound:magnitude Base__.Maybe_bound.t
        -> upper_bound:magnitude Base__.Maybe_bound.t
        -> 'a t

      val fold_range_inclusive :
           'a t
        -> min:magnitude
        -> max:magnitude
        -> init:'b
        -> f:(key:magnitude -> data:'a -> 'b -> 'b)
        -> 'b

      val range_to_alist :
        'a t -> min:magnitude -> max:magnitude -> (magnitude * 'a) list

      val closest_key :
           'a t
        -> [ `Greater_or_equal_to
           | `Greater_than
           | `Less_or_equal_to
           | `Less_than ]
        -> magnitude
        -> (magnitude * 'a) option

      val nth : 'a t -> int -> (magnitude * 'a) option

      val nth_exn : 'a t -> int -> magnitude * 'a

      val rank : 'a t -> magnitude -> int option

      val to_tree : 'a t -> 'a t

      val to_sequence :
           ?order:[ `Decreasing_key | `Increasing_key ]
        -> ?keys_greater_or_equal_to:magnitude
        -> ?keys_less_or_equal_to:magnitude
        -> 'a t
        -> (magnitude * 'a) Base__.Sequence.t

      val binary_search :
           'a t
        -> compare:(key:magnitude -> data:'a -> 'key -> int)
        -> [ `First_equal_to
           | `First_greater_than_or_equal_to
           | `First_strictly_greater_than
           | `Last_equal_to
           | `Last_less_than_or_equal_to
           | `Last_strictly_less_than ]
        -> 'key
        -> (magnitude * 'a) option

      val binary_search_segmented :
           'a t
        -> segment_of:(key:magnitude -> data:'a -> [ `Left | `Right ])
        -> [ `First_on_right | `Last_on_left ]
        -> (magnitude * 'a) option

      val key_set : 'a t -> (magnitude, comparator_witness) Base.Set.t

      val quickcheck_observer :
           magnitude Core_kernel__.Quickcheck.Observer.t
        -> 'v Core_kernel__.Quickcheck.Observer.t
        -> 'v t Core_kernel__.Quickcheck.Observer.t

      val quickcheck_shrinker :
           magnitude Core_kernel__.Quickcheck.Shrinker.t
        -> 'v Core_kernel__.Quickcheck.Shrinker.t
        -> 'v t Core_kernel__.Quickcheck.Shrinker.t

      module Provide_of_sexp : functor
        (K : sig
           val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> magnitude
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

    type 'a t = (magnitude, 'a, comparator_witness) Core_kernel__.Map_intf.Map.t

    val compare :
         ('a -> 'a -> Core_kernel__.Import.int)
      -> 'a t
      -> 'a t
      -> Core_kernel__.Import.int

    val empty : 'a t

    val singleton : magnitude -> 'a -> 'a t

    val of_alist :
      (magnitude * 'a) list -> [ `Duplicate_key of magnitude | `Ok of 'a t ]

    val of_alist_or_error : (magnitude * 'a) list -> 'a t Base__.Or_error.t

    val of_alist_exn : (magnitude * 'a) list -> 'a t

    val of_alist_multi : (magnitude * 'a) list -> 'a list t

    val of_alist_fold :
      (magnitude * 'a) list -> init:'b -> f:('b -> 'a -> 'b) -> 'b t

    val of_alist_reduce : (magnitude * 'a) list -> f:('a -> 'a -> 'a) -> 'a t

    val of_sorted_array : (magnitude * 'a) array -> 'a t Base__.Or_error.t

    val of_sorted_array_unchecked : (magnitude * 'a) array -> 'a t

    val of_increasing_iterator_unchecked :
      len:int -> f:(int -> magnitude * 'a) -> 'a t

    val of_increasing_sequence :
      (magnitude * 'a) Base__.Sequence.t -> 'a t Base__.Or_error.t

    val of_sequence :
         (magnitude * 'a) Base__.Sequence.t
      -> [ `Duplicate_key of magnitude | `Ok of 'a t ]

    val of_sequence_or_error :
      (magnitude * 'a) Base__.Sequence.t -> 'a t Base__.Or_error.t

    val of_sequence_exn : (magnitude * 'a) Base__.Sequence.t -> 'a t

    val of_sequence_multi : (magnitude * 'a) Base__.Sequence.t -> 'a list t

    val of_sequence_fold :
         (magnitude * 'a) Base__.Sequence.t
      -> init:'b
      -> f:('b -> 'a -> 'b)
      -> 'b t

    val of_sequence_reduce :
      (magnitude * 'a) Base__.Sequence.t -> f:('a -> 'a -> 'a) -> 'a t

    val of_iteri :
         iteri:(f:(key:magnitude -> data:'v -> unit) -> unit)
      -> [ `Duplicate_key of magnitude | `Ok of 'v t ]

    val of_tree : 'a Tree.t -> 'a t

    val of_hashtbl_exn : (magnitude, 'a) Core_kernel__.Hashtbl.t -> 'a t

    val of_key_set :
      (magnitude, comparator_witness) Base.Set.t -> f:(magnitude -> 'v) -> 'v t

    val quickcheck_generator :
         magnitude Core_kernel__.Quickcheck.Generator.t
      -> 'a Core_kernel__.Quickcheck.Generator.t
      -> 'a t Core_kernel__.Quickcheck.Generator.t

    val invariants : 'a t -> bool

    val is_empty : 'a t -> bool

    val length : 'a t -> int

    val add :
      'a t -> key:magnitude -> data:'a -> 'a t Base__.Map_intf.Or_duplicate.t

    val add_exn : 'a t -> key:magnitude -> data:'a -> 'a t

    val set : 'a t -> key:magnitude -> data:'a -> 'a t

    val add_multi : 'a list t -> key:magnitude -> data:'a -> 'a list t

    val remove_multi : 'a list t -> magnitude -> 'a list t

    val find_multi : 'a list t -> magnitude -> 'a list

    val change : 'a t -> magnitude -> f:('a option -> 'a option) -> 'a t

    val update : 'a t -> magnitude -> f:('a option -> 'a) -> 'a t

    val find : 'a t -> magnitude -> 'a option

    val find_exn : 'a t -> magnitude -> 'a

    val remove : 'a t -> magnitude -> 'a t

    val mem : 'a t -> magnitude -> bool

    val iter_keys : 'a t -> f:(magnitude -> unit) -> unit

    val iter : 'a t -> f:('a -> unit) -> unit

    val iteri : 'a t -> f:(key:magnitude -> data:'a -> unit) -> unit

    val iteri_until :
         'a t
      -> f:(key:magnitude -> data:'a -> Base__.Map_intf.Continue_or_stop.t)
      -> Base__.Map_intf.Finished_or_unfinished.t

    val iter2 :
         'a t
      -> 'b t
      -> f:
           (   key:magnitude
            -> data:[ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
            -> unit)
      -> unit

    val map : 'a t -> f:('a -> 'b) -> 'b t

    val mapi : 'a t -> f:(key:magnitude -> data:'a -> 'b) -> 'b t

    val fold : 'a t -> init:'b -> f:(key:magnitude -> data:'a -> 'b -> 'b) -> 'b

    val fold_right :
      'a t -> init:'b -> f:(key:magnitude -> data:'a -> 'b -> 'b) -> 'b

    val fold2 :
         'a t
      -> 'b t
      -> init:'c
      -> f:
           (   key:magnitude
            -> data:[ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
            -> 'c
            -> 'c)
      -> 'c

    val filter_keys : 'a t -> f:(magnitude -> bool) -> 'a t

    val filter : 'a t -> f:('a -> bool) -> 'a t

    val filteri : 'a t -> f:(key:magnitude -> data:'a -> bool) -> 'a t

    val filter_map : 'a t -> f:('a -> 'b option) -> 'b t

    val filter_mapi : 'a t -> f:(key:magnitude -> data:'a -> 'b option) -> 'b t

    val partition_mapi :
         'a t
      -> f:(key:magnitude -> data:'a -> [ `Fst of 'b | `Snd of 'c ])
      -> 'b t * 'c t

    val partition_map :
      'a t -> f:('a -> [ `Fst of 'b | `Snd of 'c ]) -> 'b t * 'c t

    val partitioni_tf :
      'a t -> f:(key:magnitude -> data:'a -> bool) -> 'a t * 'a t

    val partition_tf : 'a t -> f:('a -> bool) -> 'a t * 'a t

    val compare_direct : ('a -> 'a -> int) -> 'a t -> 'a t -> int

    val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

    val keys : 'a t -> magnitude list

    val data : 'a t -> 'a list

    val to_alist :
      ?key_order:[ `Decreasing | `Increasing ] -> 'a t -> (magnitude * 'a) list

    val validate :
         name:(magnitude -> string)
      -> 'a Base__.Validate.check
      -> 'a t Base__.Validate.check

    val merge :
         'a t
      -> 'b t
      -> f:
           (   key:magnitude
            -> [ `Both of 'a * 'b | `Left of 'a | `Right of 'b ]
            -> 'c option)
      -> 'c t

    val symmetric_diff :
         'a t
      -> 'a t
      -> data_equal:('a -> 'a -> bool)
      -> (magnitude, 'a) Base__.Map_intf.Symmetric_diff_element.t
         Base__.Sequence.t

    val fold_symmetric_diff :
         'a t
      -> 'a t
      -> data_equal:('a -> 'a -> bool)
      -> init:'c
      -> f:
           (   'c
            -> (magnitude, 'a) Base__.Map_intf.Symmetric_diff_element.t
            -> 'c)
      -> 'c

    val min_elt : 'a t -> (magnitude * 'a) option

    val min_elt_exn : 'a t -> magnitude * 'a

    val max_elt : 'a t -> (magnitude * 'a) option

    val max_elt_exn : 'a t -> magnitude * 'a

    val for_all : 'a t -> f:('a -> bool) -> bool

    val for_alli : 'a t -> f:(key:magnitude -> data:'a -> bool) -> bool

    val exists : 'a t -> f:('a -> bool) -> bool

    val existsi : 'a t -> f:(key:magnitude -> data:'a -> bool) -> bool

    val count : 'a t -> f:('a -> bool) -> int

    val counti : 'a t -> f:(key:magnitude -> data:'a -> bool) -> int

    val split : 'a t -> magnitude -> 'a t * (magnitude * 'a) option * 'a t

    val append :
         lower_part:'a t
      -> upper_part:'a t
      -> [ `Ok of 'a t | `Overlapping_key_ranges ]

    val subrange :
         'a t
      -> lower_bound:magnitude Base__.Maybe_bound.t
      -> upper_bound:magnitude Base__.Maybe_bound.t
      -> 'a t

    val fold_range_inclusive :
         'a t
      -> min:magnitude
      -> max:magnitude
      -> init:'b
      -> f:(key:magnitude -> data:'a -> 'b -> 'b)
      -> 'b

    val range_to_alist :
      'a t -> min:magnitude -> max:magnitude -> (magnitude * 'a) list

    val closest_key :
         'a t
      -> [ `Greater_or_equal_to
         | `Greater_than
         | `Less_or_equal_to
         | `Less_than ]
      -> magnitude
      -> (magnitude * 'a) option

    val nth : 'a t -> int -> (magnitude * 'a) option

    val nth_exn : 'a t -> int -> magnitude * 'a

    val rank : 'a t -> magnitude -> int option

    val to_tree : 'a t -> 'a Tree.t

    val to_sequence :
         ?order:[ `Decreasing_key | `Increasing_key ]
      -> ?keys_greater_or_equal_to:magnitude
      -> ?keys_less_or_equal_to:magnitude
      -> 'a t
      -> (magnitude * 'a) Base__.Sequence.t

    val binary_search :
         'a t
      -> compare:(key:magnitude -> data:'a -> 'key -> int)
      -> [ `First_equal_to
         | `First_greater_than_or_equal_to
         | `First_strictly_greater_than
         | `Last_equal_to
         | `Last_less_than_or_equal_to
         | `Last_strictly_less_than ]
      -> 'key
      -> (magnitude * 'a) option

    val binary_search_segmented :
         'a t
      -> segment_of:(key:magnitude -> data:'a -> [ `Left | `Right ])
      -> [ `First_on_right | `Last_on_left ]
      -> (magnitude * 'a) option

    val key_set : 'a t -> (magnitude, comparator_witness) Base.Set.t

    val quickcheck_observer :
         magnitude Core_kernel__.Quickcheck.Observer.t
      -> 'v Core_kernel__.Quickcheck.Observer.t
      -> 'v t Core_kernel__.Quickcheck.Observer.t

    val quickcheck_shrinker :
         magnitude Core_kernel__.Quickcheck.Shrinker.t
      -> 'v Core_kernel__.Quickcheck.Shrinker.t
      -> 'v t Core_kernel__.Quickcheck.Shrinker.t

    module Provide_of_sexp : functor
      (Key : sig
         val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> magnitude
       end)
      -> sig
      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'v_x__002_)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> 'v_x__002_ t
    end

    module Provide_bin_io : functor
      (Key : sig
         val bin_size_t : magnitude Bin_prot.Size.sizer

         val bin_write_t : magnitude Bin_prot.Write.writer

         val bin_read_t : magnitude Bin_prot.Read.reader

         val __bin_read_t__ : (int -> magnitude) Bin_prot.Read.reader

         val bin_shape_t : Bin_prot.Shape.t

         val bin_writer_t : magnitude Bin_prot.Type_class.writer

         val bin_reader_t : magnitude Bin_prot.Type_class.reader

         val bin_t : magnitude Bin_prot.Type_class.t
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
         val hash_fold_t : Base__.Hash.state -> magnitude -> Base__.Hash.state
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
      type t = magnitude

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t

      type comparator_witness = Map.Key.comparator_witness

      val comparator :
        (t, comparator_witness) Core_kernel__.Comparator.comparator
    end

    module Tree : sig
      type t = (magnitude, comparator_witness) Core_kernel__.Set_intf.Tree.t

      val compare : t -> t -> Core_kernel__.Import.int

      type named =
        (magnitude, comparator_witness) Core_kernel__.Set_intf.Tree.Named.t

      val length : t -> int

      val is_empty : t -> bool

      val iter : t -> f:(magnitude -> unit) -> unit

      val fold : t -> init:'accum -> f:('accum -> magnitude -> 'accum) -> 'accum

      val fold_result :
           t
        -> init:'accum
        -> f:('accum -> magnitude -> ('accum, 'e) Base__.Result.t)
        -> ('accum, 'e) Base__.Result.t

      val exists : t -> f:(magnitude -> bool) -> bool

      val for_all : t -> f:(magnitude -> bool) -> bool

      val count : t -> f:(magnitude -> bool) -> int

      val sum :
           (module Base__.Container_intf.Summable with type t = 'sum)
        -> t
        -> f:(magnitude -> 'sum)
        -> 'sum

      val find : t -> f:(magnitude -> bool) -> magnitude option

      val find_map : t -> f:(magnitude -> 'a option) -> 'a option

      val to_list : t -> magnitude list

      val to_array : t -> magnitude array

      val invariants : t -> bool

      val mem : t -> magnitude -> bool

      val add : t -> magnitude -> t

      val remove : t -> magnitude -> t

      val union : t -> t -> t

      val inter : t -> t -> t

      val diff : t -> t -> t

      val symmetric_diff :
        t -> t -> (magnitude, magnitude) Base__.Either.t Base__.Sequence.t

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
        -> f:
             (   'b
              -> magnitude
              -> ('b, 'final) Base__.Set_intf.Continue_or_stop.t)
        -> finish:('b -> 'final)
        -> 'final

      val fold_right : t -> init:'b -> f:(magnitude -> 'b -> 'b) -> 'b

      val iter2 :
           t
        -> t
        -> f:
             (   [ `Both of magnitude * magnitude
                 | `Left of magnitude
                 | `Right of magnitude ]
              -> unit)
        -> unit

      val filter : t -> f:(magnitude -> bool) -> t

      val partition_tf : t -> f:(magnitude -> bool) -> t * t

      val elements : t -> magnitude list

      val min_elt : t -> magnitude option

      val min_elt_exn : t -> magnitude

      val max_elt : t -> magnitude option

      val max_elt_exn : t -> magnitude

      val choose : t -> magnitude option

      val choose_exn : t -> magnitude

      val split : t -> magnitude -> t * magnitude option * t

      val group_by : t -> equiv:(magnitude -> magnitude -> bool) -> t list

      val find_exn : t -> f:(magnitude -> bool) -> magnitude

      val nth : t -> int -> magnitude option

      val remove_index : t -> int -> t

      val to_tree : t -> t

      val to_sequence :
           ?order:[ `Decreasing | `Increasing ]
        -> ?greater_or_equal_to:magnitude
        -> ?less_or_equal_to:magnitude
        -> t
        -> magnitude Base__.Sequence.t

      val binary_search :
           t
        -> compare:(magnitude -> 'key -> int)
        -> [ `First_equal_to
           | `First_greater_than_or_equal_to
           | `First_strictly_greater_than
           | `Last_equal_to
           | `Last_less_than_or_equal_to
           | `Last_strictly_less_than ]
        -> 'key
        -> magnitude option

      val binary_search_segmented :
           t
        -> segment_of:(magnitude -> [ `Left | `Right ])
        -> [ `First_on_right | `Last_on_left ]
        -> magnitude option

      val merge_to_sequence :
           ?order:[ `Decreasing | `Increasing ]
        -> ?greater_or_equal_to:magnitude
        -> ?less_or_equal_to:magnitude
        -> t
        -> t
        -> (magnitude, magnitude) Base__.Set_intf.Merge_to_sequence_element.t
           Base__.Sequence.t

      val to_map :
           t
        -> f:(magnitude -> 'data)
        -> (magnitude, 'data, comparator_witness) Base.Map.t

      val quickcheck_observer :
           magnitude Core_kernel__.Quickcheck.Observer.t
        -> t Core_kernel__.Quickcheck.Observer.t

      val quickcheck_shrinker :
           magnitude Core_kernel__.Quickcheck.Shrinker.t
        -> t Core_kernel__.Quickcheck.Shrinker.t

      val empty : t

      val singleton : magnitude -> t

      val union_list : t list -> t

      val of_list : magnitude list -> t

      val of_array : magnitude array -> t

      val of_sorted_array : magnitude array -> t Base__.Or_error.t

      val of_sorted_array_unchecked : magnitude array -> t

      val of_increasing_iterator_unchecked :
        len:int -> f:(int -> magnitude) -> t

      val stable_dedup_list : magnitude list -> magnitude list

      val map :
        ('a, 'b) Core_kernel__.Set_intf.Tree.t -> f:('a -> magnitude) -> t

      val filter_map :
           ('a, 'b) Core_kernel__.Set_intf.Tree.t
        -> f:('a -> magnitude option)
        -> t

      val of_tree : t -> t

      val of_hash_set : magnitude Core_kernel__.Hash_set.t -> t

      val of_hashtbl_keys : (magnitude, 'a) Core_kernel__.Hashtbl.t -> t

      val of_map_keys : (magnitude, 'a, comparator_witness) Base.Map.t -> t

      val quickcheck_generator :
           magnitude Core_kernel__.Quickcheck.Generator.t
        -> t Core_kernel__.Quickcheck.Generator.t

      module Provide_of_sexp : functor
        (Elt : sig
           val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> magnitude
         end)
        -> sig
        val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
      end

      val t_of_sexp : Base__.Sexp.t -> t

      val sexp_of_t : t -> Base__.Sexp.t
    end

    type t = (magnitude, comparator_witness) Base.Set.t

    val compare : t -> t -> Core_kernel__.Import.int

    type named = (magnitude, comparator_witness) Core_kernel__.Set_intf.Named.t

    val length : t -> int

    val is_empty : t -> bool

    val iter : t -> f:(magnitude -> unit) -> unit

    val fold : t -> init:'accum -> f:('accum -> magnitude -> 'accum) -> 'accum

    val fold_result :
         t
      -> init:'accum
      -> f:('accum -> magnitude -> ('accum, 'e) Base__.Result.t)
      -> ('accum, 'e) Base__.Result.t

    val exists : t -> f:(magnitude -> bool) -> bool

    val for_all : t -> f:(magnitude -> bool) -> bool

    val count : t -> f:(magnitude -> bool) -> int

    val sum :
         (module Base__.Container_intf.Summable with type t = 'sum)
      -> t
      -> f:(magnitude -> 'sum)
      -> 'sum

    val find : t -> f:(magnitude -> bool) -> magnitude option

    val find_map : t -> f:(magnitude -> 'a option) -> 'a option

    val to_list : t -> magnitude list

    val to_array : t -> magnitude array

    val invariants : t -> bool

    val mem : t -> magnitude -> bool

    val add : t -> magnitude -> t

    val remove : t -> magnitude -> t

    val union : t -> t -> t

    val inter : t -> t -> t

    val diff : t -> t -> t

    val symmetric_diff :
      t -> t -> (magnitude, magnitude) Base__.Either.t Base__.Sequence.t

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
      -> f:('b -> magnitude -> ('b, 'final) Base__.Set_intf.Continue_or_stop.t)
      -> finish:('b -> 'final)
      -> 'final

    val fold_right : t -> init:'b -> f:(magnitude -> 'b -> 'b) -> 'b

    val iter2 :
         t
      -> t
      -> f:
           (   [ `Both of magnitude * magnitude
               | `Left of magnitude
               | `Right of magnitude ]
            -> unit)
      -> unit

    val filter : t -> f:(magnitude -> bool) -> t

    val partition_tf : t -> f:(magnitude -> bool) -> t * t

    val elements : t -> magnitude list

    val min_elt : t -> magnitude option

    val min_elt_exn : t -> magnitude

    val max_elt : t -> magnitude option

    val max_elt_exn : t -> magnitude

    val choose : t -> magnitude option

    val choose_exn : t -> magnitude

    val split : t -> magnitude -> t * magnitude option * t

    val group_by : t -> equiv:(magnitude -> magnitude -> bool) -> t list

    val find_exn : t -> f:(magnitude -> bool) -> magnitude

    val nth : t -> int -> magnitude option

    val remove_index : t -> int -> t

    val to_tree : t -> Tree.t

    val to_sequence :
         ?order:[ `Decreasing | `Increasing ]
      -> ?greater_or_equal_to:magnitude
      -> ?less_or_equal_to:magnitude
      -> t
      -> magnitude Base__.Sequence.t

    val binary_search :
         t
      -> compare:(magnitude -> 'key -> int)
      -> [ `First_equal_to
         | `First_greater_than_or_equal_to
         | `First_strictly_greater_than
         | `Last_equal_to
         | `Last_less_than_or_equal_to
         | `Last_strictly_less_than ]
      -> 'key
      -> magnitude option

    val binary_search_segmented :
         t
      -> segment_of:(magnitude -> [ `Left | `Right ])
      -> [ `First_on_right | `Last_on_left ]
      -> magnitude option

    val merge_to_sequence :
         ?order:[ `Decreasing | `Increasing ]
      -> ?greater_or_equal_to:magnitude
      -> ?less_or_equal_to:magnitude
      -> t
      -> t
      -> (magnitude, magnitude) Base__.Set_intf.Merge_to_sequence_element.t
         Base__.Sequence.t

    val to_map :
         t
      -> f:(magnitude -> 'data)
      -> (magnitude, 'data, comparator_witness) Base.Map.t

    val quickcheck_observer :
         magnitude Core_kernel__.Quickcheck.Observer.t
      -> t Core_kernel__.Quickcheck.Observer.t

    val quickcheck_shrinker :
         magnitude Core_kernel__.Quickcheck.Shrinker.t
      -> t Core_kernel__.Quickcheck.Shrinker.t

    val empty : t

    val singleton : magnitude -> t

    val union_list : t list -> t

    val of_list : magnitude list -> t

    val of_array : magnitude array -> t

    val of_sorted_array : magnitude array -> t Base__.Or_error.t

    val of_sorted_array_unchecked : magnitude array -> t

    val of_increasing_iterator_unchecked : len:int -> f:(int -> magnitude) -> t

    val stable_dedup_list : magnitude list -> magnitude list

    val map : ('a, 'b) Base.Set.t -> f:('a -> magnitude) -> t

    val filter_map : ('a, 'b) Base.Set.t -> f:('a -> magnitude option) -> t

    val of_tree : Tree.t -> t

    val of_hash_set : magnitude Core_kernel__.Hash_set.t -> t

    val of_hashtbl_keys : (magnitude, 'a) Core_kernel__.Hashtbl.t -> t

    val of_map_keys : (magnitude, 'a, comparator_witness) Base.Map.t -> t

    val quickcheck_generator :
         magnitude Core_kernel__.Quickcheck.Generator.t
      -> t Core_kernel__.Quickcheck.Generator.t

    module Provide_of_sexp : functor
      (Elt : sig
         val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> magnitude
       end)
      -> sig
      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t
    end

    module Provide_bin_io : functor
      (Elt : sig
         val bin_size_t : magnitude Bin_prot.Size.sizer

         val bin_write_t : magnitude Bin_prot.Write.writer

         val bin_read_t : magnitude Bin_prot.Read.reader

         val __bin_read_t__ : (int -> magnitude) Bin_prot.Read.reader

         val bin_shape_t : Bin_prot.Shape.t

         val bin_writer_t : magnitude Bin_prot.Type_class.writer

         val bin_reader_t : magnitude Bin_prot.Type_class.reader

         val bin_t : magnitude Bin_prot.Type_class.t
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
         val hash_fold_t : Base__.Hash.state -> magnitude -> Base__.Hash.state
       end)
      -> sig
      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value
    end

    val t_of_sexp : Base__.Sexp.t -> t

    val sexp_of_t : t -> Base__.Sexp.t
  end

  val gen_incl : t -> t -> t Core_kernel.Quickcheck.Generator.t

  val gen : t Core_kernel.Quickcheck.Generator.t

  val fold : t -> bool Fold_lib.Fold.t

  val size_in_bits : int

  val iter : t -> f:(bool -> unit) -> unit

  val to_bits : t -> bool list

  val of_bits : bool list -> t

  val to_input : t -> ('a, bool) Random_oracle.Input.t

  val zero : t

  val one : t

  val of_string : string -> t

  val to_string : t -> string

  val of_formatted_string : string -> t

  val to_formatted_string : t -> string

  val of_int : int -> t

  val to_int : t -> int

  val to_uint64 : t -> uint64

  val of_uint64 : uint64 -> t

  type var

  val typ : (var, t) Snark_params.Tick.Typ.t

  val var_of_t : t -> var

  val var_to_number : var -> Snark_params.Tick.Number.t

  val var_to_bits :
    var -> Snark_params.Tick.Boolean.var Bitstring_lib.Bitstring.Lsb_first.t

  val var_to_input :
    var -> ('a, Snark_params.Tick.Boolean.var) Random_oracle.Input.t

  val equal_var :
       var
    -> var
    -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

  val add : t -> t -> t option

  val sub : t -> t -> t option

  val ( + ) : t -> t -> t option

  val ( - ) : t -> t -> t option

  val scale : t -> int -> t option

  module Signed : sig
    type t = (magnitude, Sgn.t) Signed_poly.t

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

    val compare : t -> t -> int

    val equal : t -> t -> bool

    val gen : t Core_kernel.Quickcheck.Generator.t

    val create :
      magnitude:'magnitude -> sgn:'sgn -> ('magnitude, 'sgn) Signed_poly.t

    val sgn : t -> Sgn.t

    val magnitude : t -> magnitude

    val zero : t

    val is_zero : t -> bool

    val is_positive : t -> bool

    val is_negative : t -> bool

    val to_input : t -> ('a, bool) Random_oracle.Input.t

    val add : t -> t -> t option

    val ( + ) : t -> t -> t option

    val negate : t -> t

    val of_unsigned : magnitude -> t

    type var__ := var

    type var_ := var

    type var = (var_, Sgn.var) Signed_poly.t

    val typ : (var, t) Snark_params.Tick.Typ.t

    module Checked : sig
      val constant : t -> var

      val of_unsigned : var__ -> var

      val negate : var -> var

      val if_ :
           Snark_params.Tick.Boolean.var
        -> then_:var
        -> else_:var
        -> (var, 'a) Snark_params.Tick.Checked.t

      val to_input :
        var -> ('a, Snark_params.Tick.Boolean.var) Random_oracle.Input.t

      val add : var -> var -> (var, 'a) Snark_params.Tick.Checked.t

      val assert_equal : var -> var -> (unit, 'a) Snark_params.Tick.Checked.t

      val equal :
           var
        -> var
        -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

      val ( + ) : var -> var -> (var, 'a) Snark_params.Tick.Checked.t

      val to_field_var :
        var -> (Snark_params.Tick.Field.Var.t, 'a) Snark_params.Tick.Checked.t

      val scale :
           Snark_params.Tick.Field.Var.t
        -> var
        -> (var, 'a) Snark_params.Tick.Checked.t

      type t = var

      val cswap :
           Snark_params.Tick.Boolean.var
        -> (var__, Sgn.t) Signed_poly.t * (var__, Sgn.t) Signed_poly.t
        -> (t * t, 'a) Snark_params.Tick.Checked.t
    end
  end

  module Checked : sig
    type t = var

    val if_ :
         Snark_params.Tick.Boolean.var
      -> then_:var
      -> else_:var
      -> (var, 'a) Snark_params.Tick.Checked.t

    val if_value :
      Snark_params.Tick.Boolean.var -> then_:magnitude -> else_:magnitude -> var

    val add : var -> var -> (var, 'a) Snark_params.Tick.Checked.t

    val sub : var -> var -> (var, 'a) Snark_params.Tick.Checked.t

    val sub_flagged :
         var
      -> var
      -> ( var * [ `Underflow of Snark_params.Tick.Boolean.var ]
         , 'a )
         Snark_params.Tick.Checked.t

    val add_flagged :
         var
      -> var
      -> ( var * [ `Overflow of Snark_params.Tick.Boolean.var ]
         , 'a )
         Snark_params.Tick.Checked.t

    val ( + ) : var -> var -> (var, 'a) Snark_params.Tick.Checked.t

    val ( - ) : var -> var -> (var, 'a) Snark_params.Tick.Checked.t

    val add_signed : var -> Signed.var -> (var, 'a) Snark_params.Tick.Checked.t

    val add_signed_flagged :
         var
      -> Signed.var
      -> ( var * [ `Overflow of Snark_params.Tick.Boolean.var ]
         , 'a )
         Snark_params.Tick.Checked.t

    val assert_equal : var -> var -> (unit, 'a) Snark_params.Tick.Checked.t

    val equal :
         var
      -> var
      -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

    val ( = ) :
         var
      -> var
      -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

    val ( < ) :
         var
      -> var
      -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

    val ( > ) :
         var
      -> var
      -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

    val ( <= ) :
         var
      -> var
      -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

    val ( >= ) :
         var
      -> var
      -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

    val scale :
         Snark_params.Tick.Field.Var.t
      -> var
      -> (var, 'a) Snark_params.Tick.Checked.t
  end
end
