(* Fallback values and environment-variable names shared by every
   Rosetta CLI.  See [defaults.mli]. *)

open Core

let uri_env_var = "MINA_ROSETTA_URI"

let blockchain_env_var = "MINA_ROSETTA_BLOCKCHAIN"

let network_env_var = "MINA_ROSETTA_NETWORK"

let base_uri = "http://localhost:3087"

let blockchain = "mina"

let network = "testnet"

(* Seconds allowed for one request/response exchange with the Rosetta
   server, measured from sending the request to reading the last byte of
   the response body. *)
let http_timeout = 5.0

(* A variable that is declared but blank -- [MINA_ROSETTA_URI=], or a
   Kubernetes [env:] entry with an empty [value:] -- means "not
   configured", not "configure this to the empty string".  Taking it
   literally would build a request against an empty base URI, or send an
   empty network_identifier.network that every server rejects. *)
let env_value value ~default =
  match value with
  | Some value when not (String.is_empty (String.strip value)) ->
      value
  | _ ->
      default

let%test_unit "a blank environment variable falls back to the default" =
  let check value = [%test_eq: string] (env_value value ~default:"d") "d" in
  check None ;
  check (Some "") ;
  check (Some "   ") ;
  [%test_eq: string] (env_value (Some "v") ~default:"d") "v"

(* [Stdlib.Sys] rather than [Core_kernel.Sys]: the latter's [getenv]
   raises on an unset variable, and an unset variable is the normal case
   here. *)
let from_env var ~default = env_value (Stdlib.Sys.getenv_opt var) ~default

let base_uri_from_env () = from_env uri_env_var ~default:base_uri

let blockchain_from_env () = from_env blockchain_env_var ~default:blockchain

let network_from_env () = from_env network_env_var ~default:network
