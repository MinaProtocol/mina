open Async
open Rosetta_lib

(**
 * @brief Routes incoming HTTP requests to the appropriate Rosetta API handler.
 *
 * This function serves as the main entry point for processing Rosetta API requests.
 * It parses the incoming URI path and dispatches the request to dedicated handlers
 * for different Rosetta endpoints (e.g., /network, /account, /block, /construction).
 * It manages database connections, GraphQL client interactions, and error handling.
 *
 * @param signature_kind Specifies the type of signature to expect (e.g., mainnet, testnet).
 * @param graphql_uri The URI for the Mina Daemon's GraphQL endpoint.
 * @param minimum_user_command_fee Global configuration for the minimum user command fee.
 * @param account_creation_fee Global configuration for the account creation fee.
 * @param pool A lazily initialized database connection pool to the Mina archive node.
 * @param logger An Async logger instance for logging.
 * @param safe_mode A boolean flag to restrict access to certain sensitive endpoints.
 * @param route A list of strings representing the parsed URI path segments of the request.
 * @param body The JSON body of the HTTP request.
 * @return A deferred result containing the JSON response or an Errors.t if an error occurred.
 *)
val router :
     signature_kind:Mina_signature_kind.t
  -> graphql_uri:Uri.t option
  -> minimum_user_command_fee:Currency.Fee.t
  -> account_creation_fee:Currency.Fee.t
  -> pool:
       ( ( Caqti_async.connection
         , [ `App of Errors.t
           | `Connect_failed of Caqti_error.connection_error
           | `Connect_rejected of Caqti_error.connection_error
           | `Post_connect of Caqti_error.call_or_retrieve ] )
         Mina_caqti.Pool.t
       , [ `App of Errors.t ] )
       Deferred.Result.t
       lazy_t
  -> logger:Logger.t
  -> safe_mode:bool
  -> string list
  -> Yojson.Safe.t
  -> ( Yojson.Safe.t
     , [ `App of Errors.t | `Page_not_found | `Exception of exn ] )
     Deferred.Result.t

(**
 * @brief Command-line interface definition and server startup for the Rosetta API.
 *
 * This function defines the command-line arguments and their parsing for the
 * Rosetta server. It initializes necessary components like logging, the database
 * pool, and then starts the Cohttp_async HTTP server to listen for incoming requests.
 *
 * @param signature_kind Optional, specifies the signature kind if not provided via CLI flag.
 * @param minimum_user_command_fee The minimum fee for user commands.
 * @param account_creation_fee The fee for account creation.
 * @return A Command.Param.t function (unit -> unit Deferred.t) that can be executed to start the Rosetta server.
 *)
val command :
     ?signature_kind:Mina_signature_kind.t
  -> minimum_user_command_fee:Currency.Fee.t
  -> account_creation_fee:Currency.Fee.t
  -> unit
  -> (unit -> unit Deferred.t) Command.Param.t

