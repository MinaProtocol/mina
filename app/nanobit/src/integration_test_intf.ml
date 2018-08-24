open Core

module type S = sig
  val name : string

  val command : Command.t
end
