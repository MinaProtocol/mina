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
    let ledger = best_ledger coda in
    let keys =
      Inputs.Ledger.fold_until ledger ~init:(0, [])
        ~finish:(fun (_, pks) -> pks)
        ~f:(fun (count, pks) account ->
          if count >= max_keys then Stop pks
          else Continue (count + 1, Account.public_key account :: pks) )
    in
    get_lite_chain_exn coda keys
end

module Make_broadcaster
    (Config : Web_client_pipe.Config_intf)
    (Program : Coda_intf)
    (Put_request : Web_client_pipe.Put_request_intf) =
struct
  module Web_pipe =
    Web_client_pipe.Make (Chain (Program)) (Config) (Storage.Disk)
      (Put_request)

  let run coda =
    let%bind web_client_pipe = Web_pipe.create () in
    Linear_pipe.iter (Program.strongest_ledgers coda) ~f:(fun _ ->
        Web_pipe.store web_client_pipe coda )
end

let get_service () =
  Unix.getenv "CODA_WEB_CLIENT_SERVICE"
  |> Option.value_map ~default:`None ~f:(function "S3" -> `S3 | _ -> `None)

let run_service (type t) (module Program : Coda_intf with type t = t) coda
    ~conf_dir ~log = function
  | `None ->
      Logger.trace log "Not running a web client pipe" ;
      don't_wait_for (Linear_pipe.drain (Program.strongest_ledgers coda)) ;
      Deferred.unit
  | `S3 ->
      Logger.trace log "Running S3 web client pipe" ;
      let module Web_config = struct
        let conf_dir = conf_dir

        let log = log
      end in
      let module Broadcaster =
        Make_broadcaster (Web_config) (Program)
          (Web_client_pipe.S3_put_request) in
      Broadcaster.run coda
