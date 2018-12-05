open Core

module Rollback : sig
  type t = Do_nothing | Call of (unit -> unit)
end

type 'a result = {result: 'a Or_error.t; rollback: Rollback.t}

type 'a t = 'a result

include Monad.S with type 'a t := 'a t

val run : 'a t -> 'a Or_error.t

val error : Error.t -> 'a t

val of_or_error : 'a Or_error.t -> 'a t

val with_no_rollback : 'a Or_error.t -> 'a t
