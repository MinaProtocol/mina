open Async

val dump : db_path:string -> text_file:string -> unit -> unit Deferred.t

val restore : db_path:string -> text_file:string -> unit -> unit Deferred.t
