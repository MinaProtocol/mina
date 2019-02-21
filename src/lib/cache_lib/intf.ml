open Async_kernel
open Core_kernel

module Constant = struct
  module type S = sig
    type t

    val t : t
  end
end

module Cached = struct
  module type S = sig
    type ('t, 'cache_t) t

    val phantom : 't -> ('t, _) t

    val peek : ('t, _) t -> 't

    val invalidate : ('t, _) t -> 't Or_error.t

    val was_consumed : (_, _) t -> bool

    val transform : ('t0, 'cache_t) t -> f:('t0 -> 't1) -> ('t1, 'cache_t) t
    (** [transform] maps a [Cached.t], consuming the original in the process *)

    val lift_deferred :
      ('t Deferred.t, 'cache_t) t -> ('t, 'cache_t) t Deferred.t

    val lift_result :
      (('t, 'e) Result.t, 'cache_t) t -> (('t, 'cache_t) t, 'e) Result.t
  end
end

module Cache = struct
  module type S = sig
    module Cached : Cached.S

    type 'elt t

    val name : _ t -> string

    val create :
         name:string
      -> logger:Logger.t
      -> (module Hash_set.Elt_plain with type t = 'elt)
      -> 'elt t

    val register : 'elt t -> 'elt -> ('elt, 'elt) Cached.t Or_error.t

    val mem : 'elt t -> 'elt -> bool
  end
end

module Transmuter = struct
  module type S = sig
    module Source : sig
      type t
    end

    module Target : Hash_set.Elt_plain

    val transmute : Source.t -> Target.t
  end
end

module Transmuter_cache = struct
  module type S = sig
    module Cached : Cached.S

    module Cache : Cache.S with module Cached := Cached

    type target

    type source

    type t = target Cache.t

    val create : logger:Logger.t -> t

    val register : t -> source -> (source, target) Cached.t Or_error.t

    val mem : t -> source -> bool
  end

  module type F = sig
    module Cached : Cached.S

    module Cache : Cache.S with module Cached := Cached

    module Make
        (Transmuter : Transmuter.S)
        (Name : Constant.S with type t := string) :
      S
      with module Cached := Cached
       and module Cache := Cache
       and type source = Transmuter.Source.t
       and type target = Transmuter.Target.t
  end
end

module Main = struct
  module type S = sig
    module Cached : Cached.S

    module Cache : Cache.S with module Cached := Cached

    module Transmuter_cache :
      Transmuter_cache.F with module Cached := Cached and module Cache := Cache
  end
end
