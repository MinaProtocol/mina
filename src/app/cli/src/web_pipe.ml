open Core
open Async
open Coda_base
open Signature_lib
open Pipe_lib

let request_service_name = "CODA_WEB_CLIENT_SERVICE"

module type Coda_intf = sig
  type t

  module Inputs : sig
    module Ledger : sig
      type t

      val fold_until :
           t
        -> init:'accum
        -> f:('accum -> Account.t -> ('accum, 'stop) Base.Continue_or_stop.t)
        -> finish:('accum -> 'stop)
        -> 'stop
    end

    module External_transition : sig
      type t
    end
  end

  val get_lite_chain :
    (t -> Signature_lib.Public_key.Compressed.t list -> Lite_base.Lite_chain.t)
    option

  val best_ledger : t -> Inputs.Ledger.t

  val strongest_ledgers :
    t -> Inputs.External_transition.t Linear_pipe.Reader.t
end

let to_base64 m x = B64.encode (Binable.to_string m x)

module Storage (Bin : Binable.S) = struct
  let store location data =
    Writer.save location ~contents:(to_base64 (module Bin) data)
end

module Make_broadcaster
    (Program : Coda_intf)
    (Put_request : Web_request.Intf.S) =
struct
  let get_proposer_chain coda =
    let open Base in
    let open Keypair in
    let get_lite_chain_exn = Program.get_lite_chain |> Option.value_exn in
    (* HACK: we are just passing in the proposer path for this demo *)
    let keypair = Genesis_ledger.largest_account_keypair_exn () in
    let keys = [Public_key.compress keypair.public_key] in
    get_lite_chain_exn coda keys

  module Web_pipe =
    Web_client_pipe.Make
      (Lite_base.Lite_chain)
      (Storage (Lite_base.Lite_chain))
      (Put_request)

  let run ~filename ~log coda =
    let%bind web_client_pipe = Web_pipe.create ~filename ~log in
    Linear_pipe.iter (Program.strongest_ledgers coda) ~f:(fun _ ->
        let chain = get_proposer_chain coda in
        Web_pipe.store web_client_pipe chain )
end

let get_service () =
  Unix.getenv request_service_name
  |> Option.value_map ~default:`None ~f:(function
       | "S3" -> `S3
       | path -> `Local path )

let verification_key_basename = "client_verification_key"

let verification_key_location () =
  let autogen = Cache_dir.autogen_path ^/ verification_key_basename in
  let manual = Cache_dir.manual_install_path ^/ verification_key_basename in
  match%bind Sys.file_exists manual with
  | `Yes -> return (Ok manual)
  | `No | `Unknown -> (
      match%map Sys.file_exists autogen with
      | `Yes -> Ok autogen
      | `No | `Unknown ->
          Or_error.errorf
            !"IO ERROR: Verification key does not exist\n\
             \        You should probably turn off snarks" )

let send_file_to_s3 log filename =
  let open Deferred.Or_error.Let_syntax in
  Logger.trace log "Copying %s to s3 client" filename ;
  let%bind request = Web_request.S3_put_request.create () in
  Web_request.S3_put_request.put request filename

let store_file ~send ~log filename object_name =
  let open Deferred.Let_syntax in
  match%map send log filename with
  | Ok () -> Logger.trace log !"Successfully sent %s" object_name
  | Error e ->
      Logger.error log !"Could not send %s: %s" object_name
        (Error.to_string_hum e)

let store_verification_keys ~send ~log =
  match%bind verification_key_location () with
  | Ok verification_key_location ->
      store_file ~send ~log verification_key_location "verification keys"
  | Error e ->
      Logger.error log
        !"Verification key Lookup Error: %s"
        (Error.to_string_hum e) ;
      Deferred.unit

let copy ~src ~dst =
  Reader.file_contents src >>= fun contents -> Writer.save dst ~contents

let project_directory = "CODA_PROJECT_DIR"

let run_service (type t) (module Program : Coda_intf with type t = t) coda
    ~conf_dir ~log =
  O1trace.trace_task "web pipe" (fun () -> function
    | `None ->
        Logger.info log "Not running a web client pipe" ;
        don't_wait_for (Linear_pipe.drain (Program.strongest_ledgers coda))
    | `Local path ->
        let open Keypair in
        Logger.trace log "Saving chain locally at path %s" path ;
        store_verification_keys ~log ~send:(fun _log vk_location ->
            copy ~src:vk_location ~dst:(path ^/ verification_key_basename)
            >>| Or_error.return )
        |> don't_wait_for ;
        let get_lite_chain = Option.value_exn Program.get_lite_chain in
        let keypair = Genesis_ledger.largest_account_keypair_exn () in
        Linear_pipe.iter (Program.strongest_ledgers coda) ~f:(fun _ ->
            Writer.save (path ^/ "chain")
              ~contents:
                (B64.encode
                   (Binable.to_string
                      (module Lite_base.Lite_chain)
                      (get_lite_chain coda
                         [Public_key.compress keypair.public_key]))) )
        |> don't_wait_for
    | `S3 ->
        Logger.info log "Running S3 web client pipe" ;
        let module Broadcaster =
          Make_broadcaster
            (Program)
            (struct
              include Web_request.S3_put_request

              let put = put ~options:["--cache-control"; "max-age=0,no-store"]
            end)
        in
        don't_wait_for
          (let location = conf_dir ^/ "snarkette-data" in
           let%bind () = Unix.mkdir location ~p:() in
           Broadcaster.run ~log ~filename:(location ^/ "chain") coda) ;
        let js_file_storage_work =
          Unix.getenv project_directory
          |> Option.value_map ~default:Deferred.unit ~f:(fun file_dir ->
                 match%bind Sys.is_directory file_dir with
                 | `Yes ->
                     Deferred.all_unit
                       [ store_file
                           (file_dir ^/ "verifier_main.bc.js")
                           "Verifier Main" ~log ~send:send_file_to_s3
                       ; store_file (file_dir ^/ "main.bc.js") "Main" ~log
                           ~send:send_file_to_s3 ]
                 | `No | `Unknown ->
                     Logger.error log
                       !"Js file directory %s does not exists"
                       file_dir ;
                     Deferred.unit )
        in
        let work =
          Deferred.all_unit
            [ store_verification_keys ~send:send_file_to_s3 ~log
            ; js_file_storage_work ]
        in
        don't_wait_for work )
