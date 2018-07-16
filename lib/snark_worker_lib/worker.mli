open Core
open Async

module State : sig
  type t

  val create : unit -> t Deferred.t
end

val command : Command.t

val command_name : string

val arguments :
     public_key:Nanobit_base.Public_key.Compressed.t
  -> daemon_port:int
  -> string list
