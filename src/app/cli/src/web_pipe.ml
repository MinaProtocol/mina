open Core
open Async
open Coda_base
open Signature_lib

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
    (t -> Signature_lib.Public_key.Compressed.t list -> Lite_base.Lite_chain.t)
    option

  val best_ledger : t -> Inputs.Ledger.t

  val strongest_ledgers :
    t -> Inputs.Consensus_mechanism.External_transition.t Linear_pipe.Reader.t
end

module Chain (Program : Coda_intf) :
  Web_client_pipe.Chain_intf with type data = Program.t = struct
  open Program

  type data = t

  let max_keys = 500

  let create coda =
    let open Base in
    let open Keypair in
    let get_lite_chain_exn = get_lite_chain |> Option.value_exn in
    (* HACK: we are just passing in the proposer path for this demo *)
    let keypair = Genesis_ledger.largest_account_keypair_exn () in
    let keys = [Public_key.compress keypair.public_key] in
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
    Web_client_pipe.Make
      (Chain (Program)) (Config)
      (Storage (Lite_base.Lite_chain))
      (Put_request)

  let run coda =
    let%bind web_client_pipe = Web_pipe.create () in
    Linear_pipe.iter (Program.strongest_ledgers coda) ~f:(fun _ ->
        Web_pipe.store web_client_pipe coda )
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

let store_verification_keys log store =
  let res =
    let open Deferred.Or_error.Let_syntax in
    let%bind verification_key_location = verification_key_location () in
    store verification_key_location
  in
  upon res (function
    | Ok () -> Logger.trace log "Successfully sent verification keys"
    | Error e ->
        Logger.error log
          !"Could not send verification keys: %s"
          (Error.to_string_hum e) )

let copy ~src ~dst =
  Reader.file_contents src >>= fun contents -> Writer.save dst ~contents

let run_service (type t) (module Program : Coda_intf with type t = t) coda
    ~conf_dir ~log = function
  | `None ->
      Logger.info log "Not running a web client pipe" ;
      don't_wait_for (Linear_pipe.drain (Program.strongest_ledgers coda))
  | `Local path ->
      let open Keypair in
      Logger.trace log "Saving chain locally at path %s" path ;
      store_verification_keys log (fun vk_location ->
          copy ~src:vk_location ~dst:(path ^/ verification_key_basename)
          >>| Or_error.return ) ;
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
      let module Web_config = struct
        let conf_dir = conf_dir

        let log = log
      end in
      let module Broadcaster =
        Make_broadcaster (Web_config) (Program)
          (Web_client_pipe.S3_put_request)
      in
      Broadcaster.run coda |> don't_wait_for ;
      store_verification_keys log (fun vk_location ->
          let open Deferred.Or_error.Let_syntax in
          Logger.trace log "Copying verification keys %s to s3 client"
            vk_location ;
          let%bind verification_request =
            Web_client_pipe.S3_put_request.create ()
          in
          Web_client_pipe.S3_put_request.put verification_request vk_location
      )
