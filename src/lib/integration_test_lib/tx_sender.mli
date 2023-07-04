open Async

type t


val from_string: endpoint:string -> logger:Logger.t -> t

val from_uri: uri:Uri.t -> logger:Logger.t -> t

val send_delegation: t -> spec:Command_spec.delegation ->  Graphql_requests.signed_command_result Deferred.Or_error.t

val send_signed_payment: t -> spec:Command_spec.signed_tx -> Graphql_requests.signed_command_result  Deferred.Or_error.t

val send_online_payment: t -> spec:Command_spec.tx -> Graphql_requests.signed_command_result  Deferred.Or_error.t

val send_zkapp_batch: t -> zkapp_commands:Mina_base.Zkapp_command.t list -> string list Deferred.Or_error.t

val send_zkapp: t -> zkapp_command:Mina_base.Zkapp_command.t -> string Deferred.Or_error.t

val send_invalid_zkapp: t -> zkapp_command:Mina_base.Zkapp_command.t -> substring:string -> unit Malleable_error.t

val send_invalid_payment: 
   t 
    -> spec:Command_spec.signed_tx
    -> expected_failure:string
    -> unit Malleable_error.t