open Core
open Async
open Signature_lib
open Pipe_lib

let request_service_name = "CODA_WEB_CLIENT_SERVICE"

module Base58_check = Base58_check.Make (struct
  let description = "CODA_WEB_CLIENT_SERVICE"

  let version_byte = Base58_check.Version_bytes.web_pipe
end)

let to_base58 m x = Base58_check.encode (Binable.to_string m x)

module Storage (Bin : Binable.S) = struct
  let store location data =
    Writer.save location ~contents:(to_base58 (module Bin) data)
end

module Make_broadcaster (Put_request : Web_request.Intf.S) = struct
  let get_proposer_chain coda =
    let open Base in
    let open Keypair in
    let get_lite_chain_exn = Option.value_exn Coda_run.get_lite_chain in
    (* HACK: we are just passing in the proposer path for this demo *)
    let keypair = Genesis_ledger.largest_account_keypair_exn () in
    let keys = [Public_key.compress keypair.public_key] in
    get_lite_chain_exn coda keys

  module Web_pipe =
    Web_client_pipe.Make
      (Lite_base.Lite_chain)
      (Storage (Lite_base.Lite_chain))
      (Put_request)

  let run ~filename ~logger coda =
    let%bind web_client_pipe = Web_pipe.create ~filename ~logger in
    Strict_pipe.Reader.iter (Coda_lib.validated_transitions coda) ~f:(fun _ ->
        let chain = get_proposer_chain coda in
        Web_pipe.store web_client_pipe chain )
end

let get_service () =
  Unix.getenv request_service_name
  |> Option.value_map ~default:`None ~f:(function
       | "S3" ->
           `S3
       | path ->
           `Local path )

let verification_key_basename = "client_verification_key"

let verification_key_location () =
  let autogen = Cache_dir.autogen_path ^/ verification_key_basename in
  let manual = Cache_dir.manual_install_path ^/ verification_key_basename in
  let brew = Cache_dir.brew_install_path ^/ verification_key_basename in
  match%bind Sys.file_exists manual with
  | `Yes ->
      return (Ok manual)
  | `No | `Unknown -> (
      match%bind Sys.file_exists brew with
      | `Yes ->
          return (Ok brew)
      | `No | `Unknown -> (
          match%map Sys.file_exists autogen with
          | `Yes ->
              Ok autogen
          | `No | `Unknown ->
              Or_error.errorf
                !"IO ERROR: Verification key does not exist\n\
                 \        You should probably turn off snarks" ) )

let send_file_to_s3 logger filename =
  let open Deferred.Or_error.Let_syntax in
  Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
    "Copying %s to s3 client" filename ;
  let%bind request = Web_request.S3_put_request.create () in
  Web_request.S3_put_request.put request filename

let store_file ~send ~logger filename object_name =
  let open Deferred.Let_syntax in
  match%map send logger filename with
  | Ok () ->
      Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
        "Successfully sent %s" object_name
  | Error e ->
      Logger.error logger ~module_:__MODULE__ ~location:__LOC__
        "Could not send %s: %s" object_name (Error.to_string_hum e)

let store_verification_keys ~send ~logger =
  match%bind verification_key_location () with
  | Ok verification_key_location ->
      store_file ~send ~logger verification_key_location "verification keys"
  | Error e ->
      Logger.error logger ~module_:__MODULE__ ~location:__LOC__
        "Error getting verification key location: $error"
        ~metadata:[("error", `String (Error.to_string_hum e))] ;
      Deferred.unit

let copy ~src ~dst =
  Reader.file_contents src >>= fun contents -> Writer.save dst ~contents

let project_directory = "CODA_PROJECT_DIR"

let run_service coda ~conf_dir ~logger =
  O1trace.trace_task "web pipe" (fun () -> function
    | `None ->
        Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
          "Not running a web client pipe" ;
        don't_wait_for
          (Strict_pipe.Reader.iter_without_pushback
             (Coda_lib.validated_transitions coda)
             ~f:ignore)
    | `Local path ->
        let open Keypair in
        Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
          "Saving chain locally at path %s" path ;
        store_verification_keys ~logger ~send:(fun _log vk_location ->
            copy ~src:vk_location ~dst:(path ^/ verification_key_basename)
            >>| Or_error.return )
        |> don't_wait_for ;
        let get_lite_chain = Option.value_exn Coda_run.get_lite_chain in
        let keypair = Genesis_ledger.largest_account_keypair_exn () in
        Strict_pipe.Reader.iter (Coda_lib.validated_transitions coda)
          ~f:(fun _ ->
            Writer.save (path ^/ "chain")
              ~contents:
                (to_base58
                   (module Lite_base.Lite_chain)
                   (get_lite_chain coda [Public_key.compress keypair.public_key]))
        )
        |> don't_wait_for
    | `S3 ->
        Logger.info logger ~module_:__MODULE__ ~location:__LOC__
          "Running S3 web client pipe" ;
        let module Broadcaster = Make_broadcaster (struct
          include Web_request.S3_put_request

          let put = put ~options:["--cache-control"; "max-age=0,no-store"]
        end) in
        don't_wait_for
          (let location = conf_dir ^/ "snarkette-data" in
           let%bind () = Unix.mkdir location ~p:() in
           Broadcaster.run ~logger ~filename:(location ^/ "chain") coda) ;
        let js_file_storage_work =
          Unix.getenv project_directory
          |> Option.value_map ~default:Deferred.unit ~f:(fun file_dir ->
                 match%bind Sys.is_directory file_dir with
                 | `Yes ->
                     Deferred.all_unit
                       [ store_file
                           (file_dir ^/ "verifier_main.bc.js")
                           "Verifier Main" ~logger ~send:send_file_to_s3
                       ; store_file (file_dir ^/ "main.bc.js") "Main" ~logger
                           ~send:send_file_to_s3 ]
                 | `No | `Unknown ->
                     Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                       "Javascript directory $file_dir does not exist, or is \
                        a file other than a directory"
                       ~metadata:[("file_dir", `String file_dir)] ;
                     Deferred.unit )
        in
        let work =
          Deferred.all_unit
            [ store_verification_keys ~send:send_file_to_s3 ~logger
            ; js_file_storage_work ]
        in
        don't_wait_for work )
