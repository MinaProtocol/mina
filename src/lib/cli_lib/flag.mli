open Core

val json : bool Command.Spec.param

val performance : bool Command.Spec.param

val privkey_write_path : string Command.Spec.param

val privkey_read_path : string Command.Spec.param

val conf_dir : string option Command.Spec.param

module Types : sig
  type 'a with_name = {name: string; value: 'a}

  type 'a with_name_and_displayed_default =
    {name: string; value: 'a option; default: 'a}
end

module Host_and_port : sig
  module Client : sig
    val daemon : Host_and_port.t Types.with_name Command.Spec.param
  end

  module Daemon : sig
    val archive : Host_and_port.t Types.with_name option Command.Spec.param
  end
end

module Uri : sig
  val is_localhost : Uri.t -> bool

  module Client : sig
    val rest_graphql : Uri.t Types.with_name Command.Spec.param
  end

  module Archive : sig
    val postgres : Uri.t Types.with_name Command.Spec.param
  end
end

module Port : sig
  module Daemon : sig
    val external_ :
      int Types.with_name_and_displayed_default Command.Spec.param

    val client : int Types.with_name_and_displayed_default Command.Spec.param

    val rest_server :
      int Types.with_name_and_displayed_default Command.Spec.param
  end

  module Archive : sig
    val server : int Types.with_name_and_displayed_default Command.Spec.param
  end
end

module Log : sig
  val json : bool Command.Spec.param

  val level : Logger.Level.t Command.Spec.param
end

type user_command_common =
  { sender: Signature_lib.Public_key.Compressed.t
  ; fee: Currency.Fee.t
  ; nonce: Coda_base.Account.Nonce.t option
  ; memo: string option }

val user_command_common : user_command_common Command.Param.t
