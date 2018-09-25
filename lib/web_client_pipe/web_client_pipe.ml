open Core
open Async

module Config = struct
  type t = {conf_dir: string; log: Logger.t}
end

module type S = sig
  type t

  type data

  val create : Config.t -> t Deferred.t

  val store : t -> data -> unit Deferred.t
end

module type Put_request_intf = sig
  type t

  val create : unit -> t Deferred.Or_error.t

  val put : t -> string list -> unit Deferred.Or_error.t
end

module Make (Chain : sig
  type data [@@deriving bin_io]

  val create : data -> Lite_base.Lite_chain.t
end)
(Store : Storage.With_checksum_intf)
(Request : Put_request_intf) :
  S with type data := Chain.data =
struct
  open Lite_base

  type t =
    { location: string
    ; ledger_storage: Lite_lib.Sparse_ledger.t Store.Controller.t
    ; proof_storage: Proof.t Store.Controller.t
    ; protocol_state_storage: Protocol_state.t Store.Controller.t
    ; reader: Chain.data Linear_pipe.Reader.t
    ; writer: Chain.data Linear_pipe.Writer.t }

  let write_to_storage
      {location; ledger_storage; proof_storage; protocol_state_storage; _}
      request data =
    let {Lite_chain.protocol_state; proof; ledger} = Chain.create data in
    let proof_file = location ^/ "proof" in
    let protocol_state_file = location ^/ "protocol-state" in
    let accounts, account_file_names =
      Sparse_ledger_lib.Sparse_ledger.(split ledger)
      |> List.mapi ~f:(fun index account ->
             let account_file = location ^/ sprintf "account%d" index in
             (Store.store ledger_storage account_file account, account_file) )
      |> List.unzip
    in
    let%bind () =
      Deferred.all_unit
        ( [ Store.store proof_storage proof_file proof
          ; Store.store protocol_state_storage protocol_state_file
              protocol_state ]
        @ accounts )
    in
    Request.put request ([proof_file; protocol_state_file] @ account_file_names)

  let create {Config.conf_dir; log} =
    let location = conf_dir ^/ "snarkette-data" in
    let%bind () = Unix.mkdir location ~p:() in
    let parent_log = log in
    let ledger_storage =
      Store.Controller.create ~parent_log Lite_lib.Sparse_ledger.bin_t
    in
    let proof_storage = Store.Controller.create ~parent_log Proof.bin_t in
    let protocol_state_storage =
      Store.Controller.create ~parent_log Protocol_state.bin_t
    in
    let reader, writer = Linear_pipe.create () in
    let t =
      { location
      ; ledger_storage
      ; proof_storage
      ; protocol_state_storage
      ; reader
      ; writer }
    in
    let%map () =
      match%map Request.create () with
      | Ok request ->
          don't_wait_for
            (Linear_pipe.iter reader ~f:(fun data ->
                 match%map write_to_storage t request data with
                 | Ok () -> ()
                 | Error e ->
                     Logger.error log
                       !"Writing data IO_error: %s"
                       (Error.to_string_hum e) ))
      | Error e ->
          Logger.error log
            !"Unable to create request: %s"
            (Error.to_string_hum e)
    in
    t

  let store {reader; writer; _} data =
    Linear_pipe.force_write_maybe_drop_head ~capacity:1 writer reader data ;
    Deferred.unit
end
