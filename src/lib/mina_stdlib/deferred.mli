open Core_kernel
open Async_kernel

include module type of Deferred with module Result := Deferred.Result

module List : sig
  include module type of Deferred.List
end

module Result : sig
  include module type of Deferred.Result

  module List : sig
    val fold :
         'a list
      -> init:'b
      -> f:('b -> 'a -> ('b, 'e) Deferred.Result.t)
      -> ('b, 'e) Deferred.Result.t

    val map :
         'a list
      -> f:('a -> ('b, 'e) Deferred.Result.t)
      -> ('b list, 'e) Deferred.Result.t

    val iter :
         'a list
      -> f:('a -> (unit, 'e) Deferred.Result.t)
      -> (unit, 'e) Deferred.Result.t
  end
end
