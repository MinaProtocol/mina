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
  end

  val get_lite_chain :
    (t -> Signature_lib.Public_key.Compressed.t list -> Web_client_pipe.chain)
    option

  val best_ledger : t -> Inputs.Ledger.t
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

let make_web_request_module () =
  Unix.getenv request_service_name
  |> Option.bind ~f:(function
       | "S3" ->
           Some
             ( module Web_client_pipe.S3_put_request
             : Web_client_pipe.Put_request_intf )
       | _ -> None )

let make (type t) (module Program : Coda_intf with type t = t) conf_dir log =
  function
  | None ->
      Logger.trace log "Creating web pipe stub" ;
      let module Web_client_pipe_stub = struct
        type data = t

        type t = unit

        let create () = Deferred.unit

        let store _ _ = Deferred.unit
      end in
      (module Web_client_pipe_stub : Web_client_pipe.S with type data = t)
  | Some (module Request : Web_client_pipe.Put_request_intf) ->
      let module Web_config = struct
        let conf_dir = conf_dir

        let log = log
      end in
      Logger.trace log "Creating web pipe with put request service" ;
      let module Web_client =
        Web_client_pipe.Make (Chain (Program)) (Web_config) (Storage.Disk)
          (Request) in
      (module Web_client : Web_client_pipe.S with type data = t)
