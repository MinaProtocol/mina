module T : sig
  type 'a t = [ `Active of 'a | `Bootstrapping ]

  val return : 'a -> [> `Active of 'a ]

  val bind : [< `Active of 'a | `Bootstrapping ] -> f:('a -> 'b t) -> 'b t

  val map : [> `Define_using_bind ]
end

type 'a t = [ `Active of 'a | `Bootstrapping ]

val ( >>= ) : 'a T.t -> ('a -> 'b T.t) -> 'b T.t

val ( >>| ) : 'a T.t -> ('a -> 'b) -> 'b T.t

module Monad_infix : sig
  val ( >>= ) : 'a T.t -> ('a -> 'b T.t) -> 'b T.t

  val ( >>| ) : 'a T.t -> ('a -> 'b) -> 'b T.t
end

val bind : 'a T.t -> f:('a -> 'b T.t) -> 'b T.t

val return : 'a -> 'a T.t

val map : 'a T.t -> f:('a -> 'b) -> 'b T.t

val join : 'a T.t T.t -> 'a T.t

val ignore_m : 'a T.t -> unit T.t

val all : 'a T.t list -> 'a list T.t

val all_unit : unit T.t list -> unit T.t

module Let_syntax : sig
  val return : 'a -> 'a T.t

  val ( >>= ) : 'a T.t -> ('a -> 'b T.t) -> 'b T.t

  val ( >>| ) : 'a T.t -> ('a -> 'b) -> 'b T.t

  module Let_syntax : sig
    val return : 'a -> 'a T.t

    val bind : 'a T.t -> f:('a -> 'b T.t) -> 'b T.t

    val map : 'a T.t -> f:('a -> 'b) -> 'b T.t

    val both : 'a T.t -> 'b T.t -> ('a * 'b) T.t

    module Open_on_rhs : sig end
  end
end

module Option : sig
  module T : sig
    type 'a t = 'a option T.t

    val return : 'a -> [> `Active of 'a option ]

    val bind :
         [< `Active of 'a option | `Bootstrapping ]
      -> f:('a -> ([> `Active of 'c option | `Bootstrapping ] as 'b))
      -> 'b

    val map : [> `Define_using_bind ]
  end

  val ( >>= ) : 'a T.t -> ('a -> 'b T.t) -> 'b T.t

  val ( >>| ) : 'a T.t -> ('a -> 'b) -> 'b T.t

  module Monad_infix : sig
    val ( >>= ) : 'a T.t -> ('a -> 'b T.t) -> 'b T.t

    val ( >>| ) : 'a T.t -> ('a -> 'b) -> 'b T.t
  end

  val bind : 'a T.t -> f:('a -> 'b T.t) -> 'b T.t

  val return : 'a -> 'a T.t

  val map : 'a T.t -> f:('a -> 'b) -> 'b T.t

  val join : 'a T.t T.t -> 'a T.t

  val ignore_m : 'a T.t -> unit T.t

  val all : 'a T.t list -> 'a list T.t

  val all_unit : unit T.t list -> unit T.t

  module Let_syntax : sig
    val return : 'a -> 'a T.t

    val ( >>= ) : 'a T.t -> ('a -> 'b T.t) -> 'b T.t

    val ( >>| ) : 'a T.t -> ('a -> 'b) -> 'b T.t

    module Let_syntax : sig
      val return : 'a -> 'a T.t

      val bind : 'a T.t -> f:('a -> 'b T.t) -> 'b T.t

      val map : 'a T.t -> f:('a -> 'b) -> 'b T.t

      val both : 'a T.t -> 'b T.t -> ('a * 'b) T.t

      module Open_on_rhs : sig end
    end
  end
end

val active : [< `Active of 'a | `Bootstrapping ] -> 'a option

val bootstrap_err_msg : string

val active_exn : [< `Active of 'a | `Bootstrapping ] -> 'a

val active_error :
     [< `Active of 'a | `Bootstrapping ]
  -> ('a, Core_kernel__.Error.t) Core_kernel._result

val to_deferred_or_error :
  'a Async_kernel.Deferred.t t -> 'a Async_kernel.Deferred.Or_error.t

val sequence : 'a T.t Core_kernel.List.t -> 'a Core_kernel.List.t T.t
