open Core
open Async
open Coda_base

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

    module Consensus_mechanism : sig
      module External_transition : sig
        type t
      end
    end
  end

  val get_lite_chain :
    (t -> Signature_lib.Public_key.Compressed.t list -> Web_client_pipe.chain)
    option

  val best_ledger : t -> Inputs.Ledger.t

  val strongest_ledgers :
    t -> Inputs.Consensus_mechanism.External_transition.t Linear_pipe.Reader.t
end

module Chain (Program : Coda_intf) :
  Web_client_pipe.Chain_intf with type data = Program.t =
struct
  open Program

  type data = t

  let max_keys = 500

  let create coda =
    let open Base in
    let get_lite_chain_exn = get_lite_chain |> Option.value_exn in
    (* HACK: we are just passing in the proposer path for this demo *)
    let keys = [Coda_base.Genesis_ledger.high_balance_pk] in
    get_lite_chain_exn coda keys
end

let to_base64 m x = B64.encode (Binable.to_string m x)

module Storage (Bin : Binable.S) = struct
  let store location data =
    Writer.save location ~contents:(to_base64 (module Bin) data)
end

module Make_broadcaster
    (Config : Web_client_pipe.Config_intf)
    (Program : Coda_intf)
    (Put_request : Web_client_pipe.Put_request_intf) =
struct
  module Web_pipe =
    Web_client_pipe.Make (Chain (Program)) (Config)
      (Storage (Lite_base.Lite_chain))
      (Put_request)

  let run coda =
    let%bind web_client_pipe = Web_pipe.create () in
    Linear_pipe.iter (Program.strongest_ledgers coda) ~f:(fun _ ->
        Web_pipe.store web_client_pipe coda )
end

let get_service () =
  Unix.getenv "CODA_WEB_CLIENT_SERVICE"
  |> Option.value_map ~default:`None ~f:(function "S3" -> `S3 | _ -> `None)

module Verification_request (Input : sig
  val log : Logger.t
end)
(Request : Web_client_pipe.Put_request_intf) =
struct
  let file_exists filename =
    match%map Sys.file_exists filename with
    | `Yes -> Ok ()
    | `No -> Or_error.errorf "Could not find file: %s" filename
    | `Unknown ->
        Or_error.errorf "There was an error finding file: %s" filename

  let put request path =
    match%map Request.put request path with
    | Ok () ->
        Logger.trace Input.log "Successfully sent verification keys from %s"
          path
    | Error e ->
        Logger.error Input.log
          !"Failed to send varification keys: %s"
          (Error.to_string_hum e)

  let store_verification_keys () =
    let open Web_client_pipe in
    let client_key = "client_verification_key" in
    let manual_path = Cache_dir.manual_install_path ^/ client_key in
    let autogen_path = Cache_dir.autogen_path ^/ client_key in
    Deferred.Or_error.bind (Request.create ()) ~f:(fun request ->
        match%bind
          Deferred.both (file_exists manual_path) (file_exists autogen_path)
        with
        | Ok (), Ok () ->
            let%bind manual_contents, autogen_contents =
              Deferred.both
                (Reader.file_contents manual_path)
                (Reader.file_contents autogen_path)
            in
            if String.equal manual_contents autogen_contents then
              Request.put request manual_path
            else
              Deferred.Or_error.errorf
                !"IO ERROR: there was a mismatch between autogen verification \
                  keys (%s) and manual verification keys (%s). \n\
                  Verification keys will not be sent"
                autogen_path manual_path
        | Ok (), Error _ -> Request.put request manual_path
        | Error _, Ok () -> Request.put request autogen_path
        | Error e1, Error e2 ->
            Deferred.Or_error.errorf
              !"IO ERROR: Could not find verification keys.\n\
                You should probably turn off snarks \n\
                Autogen verification keys (%s): %s \n\
                Manual verification keys (%s): %s \n"
              manual_path (Error.to_string_hum e1) autogen_path
              (Error.to_string_hum e2) )
end

let run_service (type t) (module Program : Coda_intf with type t = t) coda
    ~conf_dir ~log = function
  | `None ->
      Logger.info log "Not running a web client pipe" ;
      don't_wait_for (Linear_pipe.drain (Program.strongest_ledgers coda))
  | `S3 ->
      Logger.info log "Running S3 web client pipe" ;
      let module Web_config = struct
        let conf_dir = conf_dir

        let log = log
      end in
      let module Broadcaster =
        Make_broadcaster (Web_config) (Program)
          (Web_client_pipe.S3_put_request) in
      Broadcaster.run coda |> don't_wait_for ;
      Logger.info log "Attempting to send verification keys to s3 client" ;
      let module S3_Request =
        Verification_request (Web_config) (Web_client_pipe.S3_put_request) in
      ( match%map S3_Request.store_verification_keys () with
      | Ok () -> Logger.info log "Successfully sent verification keys"
      | Error e ->
          Logger.error log
            !"Could not send verification keys: %s"
            (Error.to_string_hum e) )
      |> don't_wait_for
