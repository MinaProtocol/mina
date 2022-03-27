val generate_keypair : Async.Command.t

val validate_keypair : Async.Command.t

val validate_transaction : Async.Command.t

module Vrf : sig
  val generate_witness : Async.Command.t

  val batch_generate_witness : Async.Command.t

  val batch_check_witness : Async.Command.t

  val command_group : Async.Command.t
end
