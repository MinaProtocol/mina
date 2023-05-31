open Core

val json : bool Command.Param.t

val plaintext : bool Command.Param.t

val performance : bool Command.Param.t

val privkey_write_path : string Command.Param.t

val privkey_read_path : string Command.Param.t

val conf_dir : string option Command.Param.t

module Types : sig
  type 'a with_name = { name : string; value : 'a }

  type 'a with_name_and_displayed_default =
    { name : string; value : 'a option; default : 'a }
end

module Host_and_port : sig
  module Client : sig
    val daemon : Host_and_port.t Types.with_name Command.Param.t
  end

  module Daemon : sig
    val archive : Host_and_port.t Types.with_name option Command.Param.t
  end
end

module Uri : sig
  val is_localhost : Uri.t -> bool

  module Client : sig
    val rest_graphql : Uri.t Types.with_name Command.Param.t

    val rest_graphql_opt : Uri.t Types.with_name option Command.Param.t

    val name : string

    val default : Uri.t
  end

  module Archive : sig
    val postgres : Uri.t Types.with_name Command.Param.t
  end
end

module Port : sig
  val default_client : int

  val default_libp2p : int

  module Daemon : sig
    val external_ : int Types.with_name_and_displayed_default Command.Param.t

    val client : int Types.with_name_and_displayed_default Command.Param.t

    val rest_server : int Types.with_name_and_displayed_default Command.Param.t

    val limited_graphql_server : int option Types.with_name Command.Param.t
  end

  module Archive : sig
    val server : int Types.with_name_and_displayed_default Command.Param.t
  end
end

module Log : sig
  val json : bool Command.Param.t

  val level : Logger.Level.t Command.Param.t

  val file_log_level : Logger.Level.t Command.Param.t

  val file_log_rotations : int Command.Param.t
end

type signed_command_common =
  { sender : Signature_lib.Public_key.Compressed.t
  ; fee : Currency.Fee.t
  ; nonce : Mina_base.Account.Nonce.t option
  ; memo : string option
  }

val signed_command_common : signed_command_common Command.Param.t

module Signed_command : sig
  val hd_index : Mina_numbers.Hd_index.t Command.Param.t

  val receiver_pk : Signature_lib.Public_key.Compressed.t Command.Param.t

  val amount : Currency.Amount.t Command.Param.t

  val fee : Currency.Fee.t option Command.Param.t

  val valid_until : Mina_numbers.Global_slot.t option Command.Param.t

  val nonce : Mina_numbers.Account_nonce.t option Command.Param.t

  val memo : string option Command.Param.t
end
