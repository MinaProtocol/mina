open Async
open Core

include Monad.S

val lift : 'a Deferred.Or_error.t -> 'a t

val exec : ?cqlsh:string -> keyspace:string -> 'a t -> 'a Deferred.Or_error.t

val query : string -> Submission.JSON.raw list t
