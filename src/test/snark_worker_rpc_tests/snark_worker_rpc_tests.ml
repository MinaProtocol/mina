module Mock_coordinator = Mock_coordinator
module Dumped_work_spec = Dumped_work_spec
open Core_kernel
open Mina_base
module Sok_message_Key = Comparable.Make (Mina_base.Sok_message)

let start_mock_coordinators ~path_dump_snark_work_spec ~reassignment_timeout
    ~port ~rpc_handshake_timeout ~rpc_heartbeat_send_every
    ~rpc_heartbeat_timeout =
  let read_dumped_spec entry =
    let file_path = Filename.concat path_dump_snark_work_spec entry in
    let work =
      Yojson.Safe.from_file ~fname:file_path file_path
      |> Dumped_work_spec.of_yojson |> Result.ok_or_failwith
    in
    let sok_msg = Sok_message.create ~fee:work.fee ~prover:work.prover in
    (sok_msg, work.spec)
  in
  let entries = Sys.readdir path_dump_snark_work_spec in
  let logger = Logger.create () in
  let works =
    entries |> Array.to_list
    |> List.map ~f:read_dumped_spec
    |> Sok_message_Key.Map.of_alist_multi
  in
  Sok_message_Key.Map.iteri works ~f:(fun ~key ~data ->
      let Sok_message.{ fee = snark_work_fee; prover } = key in
      let predefined_specs = Queue.of_list data in
      let partitioner = Work_partitioner.create ~reassignment_timeout ~logger in

      let thread_tag =
        Printf.sprintf "mock_coordinator-%s-%s"
          (Currency.Fee.to_string snark_work_fee)
          (Signature_lib.Public_key.Compressed.to_string prover)
      in
      O1trace.background_thread thread_tag (fun () ->
          Mock_coordinator.start ~prover ~predefined_specs ~partitioner
            ~snark_work_fee ~logger ~port ~rpc_handshake_timeout
            ~rpc_heartbeat_send_every ~rpc_heartbeat_timeout ) )
