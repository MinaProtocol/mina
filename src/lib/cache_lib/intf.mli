type 'a final_state = [ `Failed | `Success of 'a ] Async_kernel.Ivar.t

module Constant : sig
  module type S = sig
    type t

    val t : t
  end
end

module Registry : sig
  module type S = sig
    type element

    val element_added : element -> unit

    val element_removed :
      [ `Consumed | `Failure | `Unconsumed ] -> element -> unit
  end
end

module Cached : sig
  module type S = sig
    type ('t, 'cache_t) t

    val pure : 't -> ('t, 'a) t

    val is_pure : ('a, 'b) t -> bool

    val original : ('a, 'b) t -> 'b

    val peek : ('t, 'a) t -> 't

    val final_state : ('t1, 't2) t -> 't2 final_state

    val invalidate_with_failure : ('t, 'a) t -> 't

    val invalidate_with_success : ('t, 'a) t -> 't

    val was_consumed : ('a, 'b) t -> bool

    val transform : ('t0, 'cache_t) t -> f:('t0 -> 't1) -> ('t1, 'cache_t) t

    val sequence_deferred :
         ('t Async_kernel.Deferred.t, 'cache_t) t
      -> ('t, 'cache_t) t Async_kernel.Deferred.t

    val sequence_result :
         (('t, 'e) Core_kernel.Result.t, 'cache_t) t
      -> (('t, 'cache_t) t, 'e) Core_kernel.Result.t
  end
end

module Cache : sig
  module type S = sig
    type ('t, 'cache_t) cached

    type 'elt t

    val name : 'a t -> string

    val create :
         name:string
      -> logger:Logger.t
      -> on_add:('elt -> unit)
      -> on_remove:([ `Consumed | `Failure | `Unconsumed ] -> 'elt -> unit)
      -> (module Core_kernel.Hashtbl.Key_plain with type t = 'elt)
      -> 'elt t

    val register_exn : 'elt t -> 'elt -> ('elt, 'elt) cached

    val mem : 'elt t -> 'elt -> bool

    val final_state : 'elt t -> 'elt -> 'elt final_state Core_kernel.Option.t

    val to_list : 'elt t -> 'elt list
  end
end

module Transmuter : sig
  module type S = sig
    module Source : sig
      type t
    end

    module Target : Core_kernel.Hash_set.Elt_plain

    val transmute : Source.t -> Target.t
  end
end

module Transmuter_cache : sig
  module type S = sig
    module Cached : Cached.S

    module Cache : sig
      type 'elt t

      val name : 'a t -> string

      val create :
           name:string
        -> logger:Logger.t
        -> on_add:('elt -> unit)
        -> on_remove:([ `Consumed | `Failure | `Unconsumed ] -> 'elt -> unit)
        -> (module Core_kernel.Hashtbl.Key_plain with type t = 'elt)
        -> 'elt t

      val register_exn : 'elt t -> 'elt -> ('elt, 'elt) Cached.t

      val mem : 'elt t -> 'elt -> bool

      val final_state : 'elt t -> 'elt -> 'elt final_state Core_kernel.Option.t

      val to_list : 'elt t -> 'elt list
    end

    type target

    type source

    type t = target Cache.t

    val create : logger:Logger.t -> t

    val register_exn : t -> source -> (source, target) Cached.t

    val final_state : t -> source -> target final_state Core_kernel.Option.t

    val mem : t -> source -> bool
  end

  module type F = sig
    module Cached : Cached.S

    module Cache : sig
      type 'elt t

      val name : 'a t -> string

      val create :
           name:string
        -> logger:Logger.t
        -> on_add:('elt -> unit)
        -> on_remove:([ `Consumed | `Failure | `Unconsumed ] -> 'elt -> unit)
        -> (module Core_kernel.Hashtbl.Key_plain with type t = 'elt)
        -> 'elt t

      val register_exn : 'elt t -> 'elt -> ('elt, 'elt) Cached.t

      val mem : 'elt t -> 'elt -> bool

      val final_state : 'elt t -> 'elt -> 'elt final_state Core_kernel.Option.t

      val to_list : 'elt t -> 'elt list
    end

    module Make : functor
      (Transmuter : Transmuter.S)
      (Registry : sig
         val element_added : Transmuter.Target.t -> unit

         val element_removed :
           [ `Consumed | `Failure | `Unconsumed ] -> Transmuter.Target.t -> unit
       end)
      (Name : sig
         val t : string
       end)
      -> sig
      type target = Transmuter.Target.t

      type source = Transmuter.Source.t

      type t = target Cache.t

      val create : logger:Logger.t -> t

      val register_exn : t -> source -> (source, target) Cached.t

      val final_state : t -> source -> target final_state Core_kernel.Option.t

      val mem : t -> source -> bool
    end
  end
end

module Main : sig
  module type S = sig
    module Cached : Cached.S

    module Cache : sig
      type 'elt t

      val name : 'a t -> string

      val create :
           name:string
        -> logger:Logger.t
        -> on_add:('elt -> unit)
        -> on_remove:([ `Consumed | `Failure | `Unconsumed ] -> 'elt -> unit)
        -> (module Core_kernel.Hashtbl.Key_plain with type t = 'elt)
        -> 'elt t

      val register_exn : 'elt t -> 'elt -> ('elt, 'elt) Cached.t

      val mem : 'elt t -> 'elt -> bool

      val final_state : 'elt t -> 'elt -> 'elt final_state Core_kernel.Option.t

      val to_list : 'elt t -> 'elt list
    end

    module Transmuter_cache : sig
      module Make : functor
        (Transmuter : Transmuter.S)
        (Registry : sig
           val element_added : Transmuter.Target.t -> unit

           val element_removed :
                [ `Consumed | `Failure | `Unconsumed ]
             -> Transmuter.Target.t
             -> unit
         end)
        (Name : sig
           val t : string
         end)
        -> sig
        type target = Transmuter.Target.t

        type source = Transmuter.Source.t

        type t = target Cache.t

        val create : logger:Logger.t -> t

        val register_exn : t -> source -> (source, target) Cached.t

        val final_state : t -> source -> target final_state Core_kernel.Option.t

        val mem : t -> source -> bool
      end
    end
  end
end
