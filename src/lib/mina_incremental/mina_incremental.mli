module Make : functor
  (Incremental : Incremental.S)
  (Name : sig
     val t : string
   end)
  -> sig
  type 'a t = 'a Incremental.t

  val sexp_of_t :
    ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

  val invariant : 'a Base__.Invariant_intf.inv -> 'a t Base__.Invariant_intf.inv

  val is_const : 'a t -> bool

  val is_valid : 'a t -> bool

  val is_necessary : 'a t -> bool

  val const : 'a -> 'a t

  val return : 'a -> 'a t

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

  val map2 : 'a1 t -> 'a2 t -> f:('a1 -> 'a2 -> 'b) -> 'b t

  val map3 : 'a1 t -> 'a2 t -> 'a3 t -> f:('a1 -> 'a2 -> 'a3 -> 'b) -> 'b t

  val map4 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'b)
    -> 'b t

  val map5 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'b)
    -> 'b t

  val map6 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'a6 -> 'b)
    -> 'b t

  val map7 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'a6 -> 'a7 -> 'b)
    -> 'b t

  val map8 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'a6 -> 'a7 -> 'a8 -> 'b)
    -> 'b t

  val map9 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'a6 -> 'a7 -> 'a8 -> 'a9 -> 'b)
    -> 'b t

  val map10 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'b)
    -> 'b t

  val map11 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> 'a11 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'a11
          -> 'b)
    -> 'b t

  val map12 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> 'a11 t
    -> 'a12 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'a11
          -> 'a12
          -> 'b)
    -> 'b t

  val map13 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> 'a11 t
    -> 'a12 t
    -> 'a13 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'a11
          -> 'a12
          -> 'a13
          -> 'b)
    -> 'b t

  val map14 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> 'a11 t
    -> 'a12 t
    -> 'a13 t
    -> 'a14 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'a11
          -> 'a12
          -> 'a13
          -> 'a14
          -> 'b)
    -> 'b t

  val map15 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> 'a11 t
    -> 'a12 t
    -> 'a13 t
    -> 'a14 t
    -> 'a15 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'a11
          -> 'a12
          -> 'a13
          -> 'a14
          -> 'a15
          -> 'b)
    -> 'b t

  val bind : 'a t -> f:('a -> 'b t) -> 'b t

  val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t

  val bind2 : 'a1 t -> 'a2 t -> f:('a1 -> 'a2 -> 'b t) -> 'b t

  val bind3 : 'a1 t -> 'a2 t -> 'a3 t -> f:('a1 -> 'a2 -> 'a3 -> 'b t) -> 'b t

  val bind4 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'b t)
    -> 'b t

  module Infix : sig
    val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

    val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t
  end

  val join : 'a t t -> 'a t

  val if_ : bool t -> then_:'a t -> else_:'a t -> 'a t

  val freeze : ?when_:('a -> bool) -> 'a t -> 'a t

  val depend_on : 'a t -> depend_on:'b t -> 'a t

  val necessary_if_alive : 'a t -> 'a t

  val for_all : bool t array -> bool t

  val exists : bool t array -> bool t

  val all : 'a t list -> 'a list t

  val both : 'a t -> 'b t -> ('a * 'b) t

  val array_fold : 'a t array -> init:'b -> f:('b -> 'a -> 'b) -> 'b t

  val reduce_balanced :
    'a t array -> f:('a -> 'b) -> reduce:('b -> 'b -> 'b) -> 'b t option

  module Unordered_array_fold_update : sig
    type ('a, 'b) t = ('a, 'b) Incremental.Unordered_array_fold_update.t =
      | F_inverse of ('b -> 'a -> 'b)
      | Update of ('b -> old_value:'a -> new_value:'a -> 'b)
  end

  val unordered_array_fold :
       ?full_compute_every_n_changes:int
    -> 'a t array
    -> init:'b
    -> f:('b -> 'a -> 'b)
    -> update:('a, 'b) Unordered_array_fold_update.t
    -> 'b t

  val opt_unordered_array_fold :
       ?full_compute_every_n_changes:int
    -> 'a option t array
    -> init:'b
    -> f:('b -> 'a -> 'b)
    -> f_inverse:('b -> 'a -> 'b)
    -> 'b option t

  val sum :
       ?full_compute_every_n_changes:int
    -> 'a t array
    -> zero:'a
    -> add:('a -> 'a -> 'a)
    -> sub:('a -> 'a -> 'a)
    -> 'a t

  val opt_sum :
       ?full_compute_every_n_changes:int
    -> 'a option t array
    -> zero:'a
    -> add:('a -> 'a -> 'a)
    -> sub:('a -> 'a -> 'a)
    -> 'a option t

  val sum_int : int t array -> int t

  val sum_float : float t array -> float t

  module Var : sig
    type 'a t = 'a Incremental.Var.t

    val sexp_of_t :
      ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

    val create : ?use_current_scope:bool -> 'a -> 'a t

    val set : 'a t -> 'a -> unit

    val watch : 'a t -> 'a Incremental.t

    val value : 'a t -> 'a

    val latest_value : 'a t -> 'a
  end

  module Observer : sig
    type 'a t = 'a Incremental.Observer.t

    val sexp_of_t :
      ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

    val invariant :
      'a Base__.Invariant_intf.inv -> 'a t Base__.Invariant_intf.inv

    val observing : 'a t -> 'a Incremental.t

    val use_is_allowed : 'a t -> bool

    val value : 'a t -> 'a Core_kernel.Or_error.t

    val value_exn : 'a t -> 'a

    module Update : sig
      type 'a t = 'a Incremental.Observer.Update.t =
        | Initialized of 'a
        | Changed of 'a * 'a
        | Invalidated

      val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int

      val sexp_of_t :
        ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t
    end

    val on_update_exn : 'a t -> f:('a Update.t -> unit) -> unit

    val disallow_future_use : 'a t -> unit
  end

  val observe : ?should_finalize:bool -> 'a t -> 'a Observer.t

  module Update : sig
    type 'a t = 'a Incremental.Update.t =
      | Necessary of 'a
      | Changed of 'a * 'a
      | Invalidated
      | Unnecessary

    val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int

    val sexp_of_t :
      ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t
  end

  val on_update : 'a t -> f:('a Update.t -> unit) -> unit

  val stabilize : unit -> unit

  val am_stabilizing : unit -> bool

  module Cutoff : sig
    type 'a t = 'a Incremental.Cutoff.t

    val sexp_of_t :
      ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

    val invariant :
      'a Base__.Invariant_intf.inv -> 'a t Base__.Invariant_intf.inv

    val create : (old_value:'a -> new_value:'a -> bool) -> 'a t

    val of_compare : ('a -> 'a -> int) -> 'a t

    val of_equal : ('a -> 'a -> bool) -> 'a t

    val always : 'a t

    val never : 'a t

    val phys_equal : 'a t

    val poly_equal : 'a t

    val should_cutoff : 'a t -> old_value:'a -> new_value:'a -> bool

    val equal : 'a t -> 'a t -> bool
  end

  val set_cutoff : 'a t -> 'a Cutoff.t -> unit

  val get_cutoff : 'a t -> 'a Cutoff.t

  module Scope : sig
    type t = Incremental.Scope.t

    val top : t

    val current : unit -> t

    val within : t -> f:(unit -> 'a) -> 'a
  end

  val lazy_from_fun : (unit -> 'a) -> 'a Core_kernel.Lazy.t

  val default_hash_table_initial_size : int

  val memoize_fun :
       ?initial_size:int
    -> 'a Base.Hashtbl.Key.t
    -> ('a -> 'b)
    -> ('a -> 'b) Core_kernel.Staged.t

  val memoize_fun_by_key :
       ?initial_size:int
    -> 'key Base.Hashtbl.Key.t
    -> ('a -> 'key)
    -> ('a -> 'b)
    -> ('a -> 'b) Core_kernel.Staged.t

  val user_info : 'a t -> Core_kernel.Info.t option

  val set_user_info : 'a t -> Core_kernel.Info.t option -> unit

  module Expert : sig
    module Dependency : sig
      type 'a t = 'a Incremental.Expert.Dependency.t

      val sexp_of_t :
        ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

      val create : ?on_change:('a -> unit) -> 'a Incremental.t -> 'a t

      val value : 'a t -> 'a
    end

    module Node : sig
      type 'a t = 'a Incremental.Expert.Node.t

      val sexp_of_t :
        ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

      val create :
           ?on_observability_change:(is_now_observable:bool -> unit)
        -> (unit -> 'a)
        -> 'a t

      val watch : 'a t -> 'a Incremental.t

      val make_stale : 'a t -> unit

      val invalidate : 'a t -> unit

      val add_dependency : 'a t -> 'b Dependency.t -> unit

      val remove_dependency : 'a t -> 'b Dependency.t -> unit
    end
  end

  module State : sig
    type t = Incremental.State.t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

    val invariant : t Base__.Invariant_intf.inv

    val t : t

    val max_height_allowed : t -> int

    val set_max_height_allowed : t -> int -> unit

    val num_active_observers : t -> int

    val max_height_seen : t -> int

    val num_nodes_became_necessary : t -> int

    val num_nodes_became_unnecessary : t -> int

    val num_nodes_changed : t -> int

    val num_nodes_created : t -> int

    val num_nodes_invalidated : t -> int

    val num_nodes_recomputed : t -> int

    val num_nodes_recomputed_directly_because_one_child : t -> int

    val num_nodes_recomputed_directly_because_min_height : t -> int

    val num_stabilizes : t -> int

    val num_var_sets : t -> int

    module Stats : sig
      type t = Incremental.State.Stats.t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
    end

    val stats : t -> Stats.t
  end

  module Packed : sig
    type t = Incremental.Packed.t

    val save_dot : string -> t list -> unit
  end

  val pack : 'a t -> Packed.t

  val save_dot : string -> unit

  val keep_node_creation_backtrace : bool Core_kernel.ref

  module Let_syntax : sig
    val return : 'a -> 'a t

    val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

    val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t

    module Let_syntax : sig
      val bind : 'a t -> f:('a -> 'b t) -> 'b t

      val map : 'a t -> f:('a -> 'b) -> 'b t

      val both : 'a t -> 'b t -> ('a * 'b) t

      module Open_on_rhs : sig
        val watch : 'a Var.t -> 'a t
      end
    end
  end

  module Before_or_after : sig
    type t = Incremental.Before_or_after.t = Before | After

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
  end

  module Step_function = Incremental__.Import.Step_function

  module Clock : sig
    type t = Incremental.Clock.t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

    val default_timing_wheel_config : Timing_wheel.Config.t

    val create :
         ?timing_wheel_config:Timing_wheel.Config.t
      -> start:Incremental__.Import.Time_ns.t
      -> unit
      -> t

    val alarm_precision : t -> Incremental__.Import.Time_ns.Span.t

    val timing_wheel_length : t -> int

    val now : t -> Incremental__.Import.Time_ns.t

    val watch_now : t -> Incremental__.Import.Time_ns.t Incremental.t

    val advance_clock : t -> to_:Incremental__.Import.Time_ns.t -> unit

    val advance_clock_by : t -> Incremental__.Import.Time_ns.Span.t -> unit

    val at :
      t -> Incremental__.Import.Time_ns.t -> Before_or_after.t Incremental.t

    val after :
         t
      -> Incremental__.Import.Time_ns.Span.t
      -> Before_or_after.t Incremental.t

    val at_intervals :
      t -> Incremental__.Import.Time_ns.Span.t -> unit Incremental.t

    val step_function :
         t
      -> init:'a
      -> (Incremental__.Import.Time_ns.t * 'a) list
      -> 'a Incremental.t

    val incremental_step_function :
         t
      -> 'a Incremental__.Import.Step_function.t Incremental.t
      -> 'a Incremental.t

    val snapshot :
         t
      -> 'a Incremental.t
      -> at:Incremental__.Import.Time_ns.t
      -> before:'a
      -> 'a Incremental.t Core_kernel.Or_error.t
  end

  val weak_memoize_fun :
       ?initial_size:int
    -> 'a Base.Hashtbl.Key.t
    -> ('a -> 'b Core_kernel.Heap_block.t)
    -> ('a -> 'b Core_kernel.Heap_block.t) Core_kernel.Staged.t

  val weak_memoize_fun_by_key :
       ?initial_size:int
    -> 'key Base.Hashtbl.Key.t
    -> ('a -> 'key)
    -> ('a -> 'b Core_kernel.Heap_block.t)
    -> ('a -> 'b Core_kernel.Heap_block.t) Core_kernel.Staged.t

  val to_pipe : 'a Observer.t -> 'a Async_kernel.Pipe.Reader.t

  val of_broadcast_pipe : 'a Pipe_lib.Broadcast_pipe.Reader.t -> 'a Var.t

  val of_deferred : unit Async_kernel.Deferred.t -> [> `Empty | `Filled ] Var.t

  val of_ivar : unit Async_kernel.Ivar.t -> [> `Empty | `Filled ] Var.t
end

module New_transition : sig
  type 'a t

  val sexp_of_t :
    ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

  val invariant : 'a Base__.Invariant_intf.inv -> 'a t Base__.Invariant_intf.inv

  val is_const : 'a t -> bool

  val is_valid : 'a t -> bool

  val is_necessary : 'a t -> bool

  val const : 'a -> 'a t

  val return : 'a -> 'a t

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

  val map2 : 'a1 t -> 'a2 t -> f:('a1 -> 'a2 -> 'b) -> 'b t

  val map3 : 'a1 t -> 'a2 t -> 'a3 t -> f:('a1 -> 'a2 -> 'a3 -> 'b) -> 'b t

  val map4 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'b)
    -> 'b t

  val map5 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'b)
    -> 'b t

  val map6 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'a6 -> 'b)
    -> 'b t

  val map7 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'a6 -> 'a7 -> 'b)
    -> 'b t

  val map8 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'a6 -> 'a7 -> 'a8 -> 'b)
    -> 'b t

  val map9 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'a6 -> 'a7 -> 'a8 -> 'a9 -> 'b)
    -> 'b t

  val map10 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'b)
    -> 'b t

  val map11 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> 'a11 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'a11
          -> 'b)
    -> 'b t

  val map12 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> 'a11 t
    -> 'a12 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'a11
          -> 'a12
          -> 'b)
    -> 'b t

  val map13 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> 'a11 t
    -> 'a12 t
    -> 'a13 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'a11
          -> 'a12
          -> 'a13
          -> 'b)
    -> 'b t

  val map14 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> 'a11 t
    -> 'a12 t
    -> 'a13 t
    -> 'a14 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'a11
          -> 'a12
          -> 'a13
          -> 'a14
          -> 'b)
    -> 'b t

  val map15 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> 'a11 t
    -> 'a12 t
    -> 'a13 t
    -> 'a14 t
    -> 'a15 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'a11
          -> 'a12
          -> 'a13
          -> 'a14
          -> 'a15
          -> 'b)
    -> 'b t

  val bind : 'a t -> f:('a -> 'b t) -> 'b t

  val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t

  val bind2 : 'a1 t -> 'a2 t -> f:('a1 -> 'a2 -> 'b t) -> 'b t

  val bind3 : 'a1 t -> 'a2 t -> 'a3 t -> f:('a1 -> 'a2 -> 'a3 -> 'b t) -> 'b t

  val bind4 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'b t)
    -> 'b t

  module Infix : sig
    val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

    val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t
  end

  val join : 'a t t -> 'a t

  val if_ : bool t -> then_:'a t -> else_:'a t -> 'a t

  val freeze : ?when_:('a -> bool) -> 'a t -> 'a t

  val depend_on : 'a t -> depend_on:'b t -> 'a t

  val necessary_if_alive : 'a t -> 'a t

  val for_all : bool t array -> bool t

  val exists : bool t array -> bool t

  val all : 'a t list -> 'a list t

  val both : 'a t -> 'b t -> ('a * 'b) t

  val array_fold : 'a t array -> init:'b -> f:('b -> 'a -> 'b) -> 'b t

  val reduce_balanced :
    'a t array -> f:('a -> 'b) -> reduce:('b -> 'b -> 'b) -> 'b t option

  module Unordered_array_fold_update : sig
    type ('a, 'b) t =
      | F_inverse of ('b -> 'a -> 'b)
      | Update of ('b -> old_value:'a -> new_value:'a -> 'b)
  end

  val unordered_array_fold :
       ?full_compute_every_n_changes:int
    -> 'a t array
    -> init:'b
    -> f:('b -> 'a -> 'b)
    -> update:('a, 'b) Unordered_array_fold_update.t
    -> 'b t

  val opt_unordered_array_fold :
       ?full_compute_every_n_changes:int
    -> 'a option t array
    -> init:'b
    -> f:('b -> 'a -> 'b)
    -> f_inverse:('b -> 'a -> 'b)
    -> 'b option t

  val sum :
       ?full_compute_every_n_changes:int
    -> 'a t array
    -> zero:'a
    -> add:('a -> 'a -> 'a)
    -> sub:('a -> 'a -> 'a)
    -> 'a t

  val opt_sum :
       ?full_compute_every_n_changes:int
    -> 'a option t array
    -> zero:'a
    -> add:('a -> 'a -> 'a)
    -> sub:('a -> 'a -> 'a)
    -> 'a option t

  val sum_int : int t array -> int t

  val sum_float : float t array -> float t

  module Var : sig
    type 'a t_ := 'a t

    type 'a t

    val sexp_of_t :
      ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

    val create : ?use_current_scope:bool -> 'a -> 'a t

    val set : 'a t -> 'a -> unit

    val watch : 'a t -> 'a t_

    val value : 'a t -> 'a

    val latest_value : 'a t -> 'a
  end

  module Observer : sig
    type 'a t_ := 'a t

    type 'a t

    val sexp_of_t :
      ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

    val invariant :
      'a Base__.Invariant_intf.inv -> 'a t Base__.Invariant_intf.inv

    val observing : 'a t -> 'a t_

    val use_is_allowed : 'a t -> bool

    val value : 'a t -> 'a Core_kernel.Or_error.t

    val value_exn : 'a t -> 'a

    module Update : sig
      type 'a t = Initialized of 'a | Changed of 'a * 'a | Invalidated

      val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int

      val sexp_of_t :
        ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t
    end

    val on_update_exn : 'a t -> f:('a Update.t -> unit) -> unit

    val disallow_future_use : 'a t -> unit
  end

  val observe : ?should_finalize:bool -> 'a t -> 'a Observer.t

  module Update : sig
    type 'a t =
      | Necessary of 'a
      | Changed of 'a * 'a
      | Invalidated
      | Unnecessary

    val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int

    val sexp_of_t :
      ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t
  end

  val on_update : 'a t -> f:('a Update.t -> unit) -> unit

  val stabilize : unit -> unit

  val am_stabilizing : unit -> bool

  module Cutoff : sig
    type 'a t

    val sexp_of_t :
      ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

    val invariant :
      'a Base__.Invariant_intf.inv -> 'a t Base__.Invariant_intf.inv

    val create : (old_value:'a -> new_value:'a -> bool) -> 'a t

    val of_compare : ('a -> 'a -> int) -> 'a t

    val of_equal : ('a -> 'a -> bool) -> 'a t

    val always : 'a t

    val never : 'a t

    val phys_equal : 'a t

    val poly_equal : 'a t

    val should_cutoff : 'a t -> old_value:'a -> new_value:'a -> bool

    val equal : 'a t -> 'a t -> bool
  end

  val set_cutoff : 'a t -> 'a Cutoff.t -> unit

  val get_cutoff : 'a t -> 'a Cutoff.t

  module Scope : sig
    type t

    val top : t

    val current : unit -> t

    val within : t -> f:(unit -> 'a) -> 'a
  end

  val lazy_from_fun : (unit -> 'a) -> 'a Core_kernel.Lazy.t

  val default_hash_table_initial_size : int

  val memoize_fun :
       ?initial_size:int
    -> 'a Base.Hashtbl.Key.t
    -> ('a -> 'b)
    -> ('a -> 'b) Core_kernel.Staged.t

  val memoize_fun_by_key :
       ?initial_size:int
    -> 'key Base.Hashtbl.Key.t
    -> ('a -> 'key)
    -> ('a -> 'b)
    -> ('a -> 'b) Core_kernel.Staged.t

  val user_info : 'a t -> Core_kernel.Info.t option

  val set_user_info : 'a t -> Core_kernel.Info.t option -> unit

  module Expert : sig
    module Dependency : sig
      type 'a t_ := 'a t

      type 'a t

      val sexp_of_t :
        ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

      val create : ?on_change:('a -> unit) -> 'a t_ -> 'a t

      val value : 'a t -> 'a
    end

    module Node : sig
      type 'a t_ := 'a t

      type 'a t

      val sexp_of_t :
        ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

      val create :
           ?on_observability_change:(is_now_observable:bool -> unit)
        -> (unit -> 'a)
        -> 'a t

      val watch : 'a t -> 'a t_

      val make_stale : 'a t -> unit

      val invalidate : 'a t -> unit

      val add_dependency : 'a t -> 'b Dependency.t -> unit

      val remove_dependency : 'a t -> 'b Dependency.t -> unit
    end
  end

  module State : sig
    type t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

    val invariant : t Base__.Invariant_intf.inv

    val t : t

    val max_height_allowed : t -> int

    val set_max_height_allowed : t -> int -> unit

    val num_active_observers : t -> int

    val max_height_seen : t -> int

    val num_nodes_became_necessary : t -> int

    val num_nodes_became_unnecessary : t -> int

    val num_nodes_changed : t -> int

    val num_nodes_created : t -> int

    val num_nodes_invalidated : t -> int

    val num_nodes_recomputed : t -> int

    val num_nodes_recomputed_directly_because_one_child : t -> int

    val num_nodes_recomputed_directly_because_min_height : t -> int

    val num_stabilizes : t -> int

    val num_var_sets : t -> int

    module Stats : sig
      type t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
    end

    val stats : t -> Stats.t
  end

  module Packed : sig
    type t

    val save_dot : string -> t list -> unit
  end

  val pack : 'a t -> Packed.t

  val save_dot : string -> unit

  val keep_node_creation_backtrace : bool Core_kernel.ref

  module Let_syntax : sig
    val return : 'a -> 'a t

    val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

    val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t

    module Let_syntax : sig
      val bind : 'a t -> f:('a -> 'b t) -> 'b t

      val map : 'a t -> f:('a -> 'b) -> 'b t

      val both : 'a t -> 'b t -> ('a * 'b) t

      module Open_on_rhs : sig
        val watch : 'a Var.t -> 'a t
      end
    end
  end

  module Before_or_after : sig
    type t = Before | After

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
  end

  module Step_function = Incremental__.Import.Step_function

  module Clock : sig
    type 'a t_ := 'a t

    type t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

    val default_timing_wheel_config : Timing_wheel.Config.t

    val create :
         ?timing_wheel_config:Timing_wheel.Config.t
      -> start:Incremental__.Import.Time_ns.t
      -> unit
      -> t

    val alarm_precision : t -> Incremental__.Import.Time_ns.Span.t

    val timing_wheel_length : t -> int

    val now : t -> Incremental__.Import.Time_ns.t

    val watch_now : t -> Incremental__.Import.Time_ns.t t_

    val advance_clock : t -> to_:Incremental__.Import.Time_ns.t -> unit

    val advance_clock_by : t -> Incremental__.Import.Time_ns.Span.t -> unit

    val at : t -> Incremental__.Import.Time_ns.t -> Before_or_after.t t_

    val after : t -> Incremental__.Import.Time_ns.Span.t -> Before_or_after.t t_

    val at_intervals : t -> Incremental__.Import.Time_ns.Span.t -> unit t_

    val step_function :
      t -> init:'a -> (Incremental__.Import.Time_ns.t * 'a) list -> 'a t_

    val incremental_step_function :
      t -> 'a Incremental__.Import.Step_function.t t_ -> 'a t_

    val snapshot :
         t
      -> 'a t_
      -> at:Incremental__.Import.Time_ns.t
      -> before:'a
      -> 'a t_ Core_kernel.Or_error.t
  end

  val weak_memoize_fun :
       ?initial_size:int
    -> 'a Base.Hashtbl.Key.t
    -> ('a -> 'b Core_kernel.Heap_block.t)
    -> ('a -> 'b Core_kernel.Heap_block.t) Core_kernel.Staged.t

  val weak_memoize_fun_by_key :
       ?initial_size:int
    -> 'key Base.Hashtbl.Key.t
    -> ('a -> 'key)
    -> ('a -> 'b Core_kernel.Heap_block.t)
    -> ('a -> 'b Core_kernel.Heap_block.t) Core_kernel.Staged.t

  val to_pipe : 'a Observer.t -> 'a Async_kernel.Pipe.Reader.t

  val of_broadcast_pipe : 'a Pipe_lib.Broadcast_pipe.Reader.t -> 'a Var.t

  val of_deferred : unit Async_kernel.Deferred.t -> [> `Empty | `Filled ] Var.t

  val of_ivar : unit Async_kernel.Ivar.t -> [> `Empty | `Filled ] Var.t
end

module Status : sig
  type 'a t

  val sexp_of_t :
    ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

  val invariant : 'a Base__.Invariant_intf.inv -> 'a t Base__.Invariant_intf.inv

  val is_const : 'a t -> bool

  val is_valid : 'a t -> bool

  val is_necessary : 'a t -> bool

  val const : 'a -> 'a t

  val return : 'a -> 'a t

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

  val map2 : 'a1 t -> 'a2 t -> f:('a1 -> 'a2 -> 'b) -> 'b t

  val map3 : 'a1 t -> 'a2 t -> 'a3 t -> f:('a1 -> 'a2 -> 'a3 -> 'b) -> 'b t

  val map4 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'b)
    -> 'b t

  val map5 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'b)
    -> 'b t

  val map6 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'a6 -> 'b)
    -> 'b t

  val map7 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'a6 -> 'a7 -> 'b)
    -> 'b t

  val map8 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'a6 -> 'a7 -> 'a8 -> 'b)
    -> 'b t

  val map9 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'a6 -> 'a7 -> 'a8 -> 'a9 -> 'b)
    -> 'b t

  val map10 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'b)
    -> 'b t

  val map11 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> 'a11 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'a11
          -> 'b)
    -> 'b t

  val map12 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> 'a11 t
    -> 'a12 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'a11
          -> 'a12
          -> 'b)
    -> 'b t

  val map13 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> 'a11 t
    -> 'a12 t
    -> 'a13 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'a11
          -> 'a12
          -> 'a13
          -> 'b)
    -> 'b t

  val map14 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> 'a11 t
    -> 'a12 t
    -> 'a13 t
    -> 'a14 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'a11
          -> 'a12
          -> 'a13
          -> 'a14
          -> 'b)
    -> 'b t

  val map15 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> 'a5 t
    -> 'a6 t
    -> 'a7 t
    -> 'a8 t
    -> 'a9 t
    -> 'a10 t
    -> 'a11 t
    -> 'a12 t
    -> 'a13 t
    -> 'a14 t
    -> 'a15 t
    -> f:
         (   'a1
          -> 'a2
          -> 'a3
          -> 'a4
          -> 'a5
          -> 'a6
          -> 'a7
          -> 'a8
          -> 'a9
          -> 'a10
          -> 'a11
          -> 'a12
          -> 'a13
          -> 'a14
          -> 'a15
          -> 'b)
    -> 'b t

  val bind : 'a t -> f:('a -> 'b t) -> 'b t

  val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t

  val bind2 : 'a1 t -> 'a2 t -> f:('a1 -> 'a2 -> 'b t) -> 'b t

  val bind3 : 'a1 t -> 'a2 t -> 'a3 t -> f:('a1 -> 'a2 -> 'a3 -> 'b t) -> 'b t

  val bind4 :
       'a1 t
    -> 'a2 t
    -> 'a3 t
    -> 'a4 t
    -> f:('a1 -> 'a2 -> 'a3 -> 'a4 -> 'b t)
    -> 'b t

  module Infix : sig
    val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

    val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t
  end

  val join : 'a t t -> 'a t

  val if_ : bool t -> then_:'a t -> else_:'a t -> 'a t

  val freeze : ?when_:('a -> bool) -> 'a t -> 'a t

  val depend_on : 'a t -> depend_on:'b t -> 'a t

  val necessary_if_alive : 'a t -> 'a t

  val for_all : bool t array -> bool t

  val exists : bool t array -> bool t

  val all : 'a t list -> 'a list t

  val both : 'a t -> 'b t -> ('a * 'b) t

  val array_fold : 'a t array -> init:'b -> f:('b -> 'a -> 'b) -> 'b t

  val reduce_balanced :
    'a t array -> f:('a -> 'b) -> reduce:('b -> 'b -> 'b) -> 'b t option

  module Unordered_array_fold_update : sig
    type ('a, 'b) t =
      | F_inverse of ('b -> 'a -> 'b)
      | Update of ('b -> old_value:'a -> new_value:'a -> 'b)
  end

  val unordered_array_fold :
       ?full_compute_every_n_changes:int
    -> 'a t array
    -> init:'b
    -> f:('b -> 'a -> 'b)
    -> update:('a, 'b) Unordered_array_fold_update.t
    -> 'b t

  val opt_unordered_array_fold :
       ?full_compute_every_n_changes:int
    -> 'a option t array
    -> init:'b
    -> f:('b -> 'a -> 'b)
    -> f_inverse:('b -> 'a -> 'b)
    -> 'b option t

  val sum :
       ?full_compute_every_n_changes:int
    -> 'a t array
    -> zero:'a
    -> add:('a -> 'a -> 'a)
    -> sub:('a -> 'a -> 'a)
    -> 'a t

  val opt_sum :
       ?full_compute_every_n_changes:int
    -> 'a option t array
    -> zero:'a
    -> add:('a -> 'a -> 'a)
    -> sub:('a -> 'a -> 'a)
    -> 'a option t

  val sum_int : int t array -> int t

  val sum_float : float t array -> float t

  module Var : sig
    type 'a t_ := 'a t

    type 'a t

    val sexp_of_t :
      ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

    val create : ?use_current_scope:bool -> 'a -> 'a t

    val set : 'a t -> 'a -> unit

    val watch : 'a t -> 'a t_

    val value : 'a t -> 'a

    val latest_value : 'a t -> 'a
  end

  module Observer : sig
    type 'a t_ := 'a t

    type 'a t

    val sexp_of_t :
      ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

    val invariant :
      'a Base__.Invariant_intf.inv -> 'a t Base__.Invariant_intf.inv

    val observing : 'a t -> 'a t_

    val use_is_allowed : 'a t -> bool

    val value : 'a t -> 'a Core_kernel.Or_error.t

    val value_exn : 'a t -> 'a

    module Update : sig
      type 'a t = Initialized of 'a | Changed of 'a * 'a | Invalidated

      val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int

      val sexp_of_t :
        ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t
    end

    val on_update_exn : 'a t -> f:('a Update.t -> unit) -> unit

    val disallow_future_use : 'a t -> unit
  end

  val observe : ?should_finalize:bool -> 'a t -> 'a Observer.t

  module Update : sig
    type 'a t =
      | Necessary of 'a
      | Changed of 'a * 'a
      | Invalidated
      | Unnecessary

    val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int

    val sexp_of_t :
      ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t
  end

  val on_update : 'a t -> f:('a Update.t -> unit) -> unit

  val stabilize : unit -> unit

  val am_stabilizing : unit -> bool

  module Cutoff : sig
    type 'a t

    val sexp_of_t :
      ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

    val invariant :
      'a Base__.Invariant_intf.inv -> 'a t Base__.Invariant_intf.inv

    val create : (old_value:'a -> new_value:'a -> bool) -> 'a t

    val of_compare : ('a -> 'a -> int) -> 'a t

    val of_equal : ('a -> 'a -> bool) -> 'a t

    val always : 'a t

    val never : 'a t

    val phys_equal : 'a t

    val poly_equal : 'a t

    val should_cutoff : 'a t -> old_value:'a -> new_value:'a -> bool

    val equal : 'a t -> 'a t -> bool
  end

  val set_cutoff : 'a t -> 'a Cutoff.t -> unit

  val get_cutoff : 'a t -> 'a Cutoff.t

  module Scope : sig
    type t

    val top : t

    val current : unit -> t

    val within : t -> f:(unit -> 'a) -> 'a
  end

  val lazy_from_fun : (unit -> 'a) -> 'a Core_kernel.Lazy.t

  val default_hash_table_initial_size : int

  val memoize_fun :
       ?initial_size:int
    -> 'a Base.Hashtbl.Key.t
    -> ('a -> 'b)
    -> ('a -> 'b) Core_kernel.Staged.t

  val memoize_fun_by_key :
       ?initial_size:int
    -> 'key Base.Hashtbl.Key.t
    -> ('a -> 'key)
    -> ('a -> 'b)
    -> ('a -> 'b) Core_kernel.Staged.t

  val user_info : 'a t -> Core_kernel.Info.t option

  val set_user_info : 'a t -> Core_kernel.Info.t option -> unit

  module Expert : sig
    module Dependency : sig
      type 'a t_ := 'a t

      type 'a t

      val sexp_of_t :
        ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

      val create : ?on_change:('a -> unit) -> 'a t_ -> 'a t

      val value : 'a t -> 'a
    end

    module Node : sig
      type 'a t_ := 'a t

      type 'a t

      val sexp_of_t :
        ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

      val create :
           ?on_observability_change:(is_now_observable:bool -> unit)
        -> (unit -> 'a)
        -> 'a t

      val watch : 'a t -> 'a t_

      val make_stale : 'a t -> unit

      val invalidate : 'a t -> unit

      val add_dependency : 'a t -> 'b Dependency.t -> unit

      val remove_dependency : 'a t -> 'b Dependency.t -> unit
    end
  end

  module State : sig
    type t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

    val invariant : t Base__.Invariant_intf.inv

    val t : t

    val max_height_allowed : t -> int

    val set_max_height_allowed : t -> int -> unit

    val num_active_observers : t -> int

    val max_height_seen : t -> int

    val num_nodes_became_necessary : t -> int

    val num_nodes_became_unnecessary : t -> int

    val num_nodes_changed : t -> int

    val num_nodes_created : t -> int

    val num_nodes_invalidated : t -> int

    val num_nodes_recomputed : t -> int

    val num_nodes_recomputed_directly_because_one_child : t -> int

    val num_nodes_recomputed_directly_because_min_height : t -> int

    val num_stabilizes : t -> int

    val num_var_sets : t -> int

    module Stats : sig
      type t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
    end

    val stats : t -> Stats.t
  end

  module Packed : sig
    type t

    val save_dot : string -> t list -> unit
  end

  val pack : 'a t -> Packed.t

  val save_dot : string -> unit

  val keep_node_creation_backtrace : bool Core_kernel.ref

  module Let_syntax : sig
    val return : 'a -> 'a t

    val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

    val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t

    module Let_syntax : sig
      val bind : 'a t -> f:('a -> 'b t) -> 'b t

      val map : 'a t -> f:('a -> 'b) -> 'b t

      val both : 'a t -> 'b t -> ('a * 'b) t

      module Open_on_rhs : sig
        val watch : 'a Var.t -> 'a t
      end
    end
  end

  module Before_or_after : sig
    type t = Before | After

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
  end

  module Step_function = Incremental__.Import.Step_function

  module Clock : sig
    type 'a t_ := 'a t

    type t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

    val default_timing_wheel_config : Timing_wheel.Config.t

    val create :
         ?timing_wheel_config:Timing_wheel.Config.t
      -> start:Incremental__.Import.Time_ns.t
      -> unit
      -> t

    val alarm_precision : t -> Incremental__.Import.Time_ns.Span.t

    val timing_wheel_length : t -> int

    val now : t -> Incremental__.Import.Time_ns.t

    val watch_now : t -> Incremental__.Import.Time_ns.t t_

    val advance_clock : t -> to_:Incremental__.Import.Time_ns.t -> unit

    val advance_clock_by : t -> Incremental__.Import.Time_ns.Span.t -> unit

    val at : t -> Incremental__.Import.Time_ns.t -> Before_or_after.t t_

    val after : t -> Incremental__.Import.Time_ns.Span.t -> Before_or_after.t t_

    val at_intervals : t -> Incremental__.Import.Time_ns.Span.t -> unit t_

    val step_function :
      t -> init:'a -> (Incremental__.Import.Time_ns.t * 'a) list -> 'a t_

    val incremental_step_function :
      t -> 'a Incremental__.Import.Step_function.t t_ -> 'a t_

    val snapshot :
         t
      -> 'a t_
      -> at:Incremental__.Import.Time_ns.t
      -> before:'a
      -> 'a t_ Core_kernel.Or_error.t
  end

  val weak_memoize_fun :
       ?initial_size:int
    -> 'a Base.Hashtbl.Key.t
    -> ('a -> 'b Core_kernel.Heap_block.t)
    -> ('a -> 'b Core_kernel.Heap_block.t) Core_kernel.Staged.t

  val weak_memoize_fun_by_key :
       ?initial_size:int
    -> 'key Base.Hashtbl.Key.t
    -> ('a -> 'key)
    -> ('a -> 'b Core_kernel.Heap_block.t)
    -> ('a -> 'b Core_kernel.Heap_block.t) Core_kernel.Staged.t

  val to_pipe : 'a Observer.t -> 'a Async_kernel.Pipe.Reader.t

  val of_broadcast_pipe : 'a Pipe_lib.Broadcast_pipe.Reader.t -> 'a Var.t

  val of_deferred : unit Async_kernel.Deferred.t -> [> `Empty | `Filled ] Var.t

  val of_ivar : unit Async_kernel.Ivar.t -> [> `Empty | `Filled ] Var.t
end
