open Core
open Async

let request_service_name = "CODA_WEB_CLIENT_SERVICE"

module type Coda_intf = sig
  type t

  val get_lite_chain :
    (t -> Signature_lib.Public_key.Compressed.t list -> Web_client_pipe.chain)
    option
end

module Chain (Program : Coda_intf) :
  Web_client_pipe.Chain_intf with type data = Program.t =
struct
  type data = Program.t

  let create coda =
    let get_lite_chain = Program.get_lite_chain |> Option.value_exn in
    (* TODO: populate sparse ledger with public keys for webclient *)
    get_lite_chain coda []
end

let make (type t) (module Program : Coda_intf with type t = t) ~conf_dir ~log =
  function
  | "S3" ->
      let module Web_config = struct
        let conf_dir = conf_dir

        let log = log
      end in
      let module Web_client =
        Web_client_pipe.Make (Chain (Program)) (Web_config) (Storage.Disk)
          (Web_client_pipe.S3_put_request) in
      (module Web_client : Web_client_pipe.S with type data = t)
  | _ ->
      let module Web_client_pipe_stub = struct
        type data = t

        type t = unit

        let create () = Deferred.unit

        let store _ _ = Deferred.unit
      end in
      (module Web_client_pipe_stub : Web_client_pipe.S with type data = t)
