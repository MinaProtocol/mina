(**
Module to run missing_block_guardian app which should fill any gaps in given archive database
*)

open Core
open Async
open Integration_test_lib

module Config = struct
  type t =
    { sender_sk : String.t
    ; receiver_address : String.t
    ; graphql_url : string option
    ; nonce : Int.t option
    }

  let to_args t =
    [ t.sender_sk
    ; t.receiver_address
    ; Option.value ~default:"" t.graphql_url
    ; Option.value ~default:"0" (Option.map t.nonce ~f:Int.to_string)
    ]
end

let repo_path = "scripts/tests/mina-signer/test-signer.js"

let official_name = "mina-test-signer"

let run config =
  let open Deferred.Let_syntax in
  let logger = Logger.create () in
  match%bind Sys.file_exists repo_path with
  | `Yes ->
      [%log info] "Running command node %s"
        (String.concat ~sep:" " (repo_path :: Config.to_args config)) ;
      Util.run_cmd_or_error "." "node" ([ repo_path ] @ Config.to_args config)
  | _ -> (
      let%bind which = Util.run_cmd_exn "." "which" [ official_name ] in
      match String.strip which with
      | "" ->
          Deferred.Or_error.error_string
            "Could not find js_signer executable on PATH"
      | path ->
          [%log info] "Running command %s %s" path
            (String.concat ~sep:" " (Config.to_args config)) ;
          Util.run_cmd_or_error "" path (Config.to_args config) )
