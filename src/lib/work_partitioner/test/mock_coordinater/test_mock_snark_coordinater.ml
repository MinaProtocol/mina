open Core
open Mina_base

module Dumped_work_spec = struct
  type t =
    { prover : Signature_lib.Public_key.Compressed.Stable.V1.t
    ; spec :
        Snark_work_lib.Selector.Single.Spec.Stable.Latest.t
        One_or_two.Stable.V1.t
    ; fee : Currency.Fee.Stable.V1.t
    }
  [@@deriving of_yojson]
end

let () =
  let path_dump_snark_work_spec = Sys.getenv_exn "PATH_DUMP_SNARK_WORK_SPEC" in

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
  let works = entries |> Array.to_list |> List.map ~f:read_dumped_spec in
  printf "Read %d specs" (List.length works)
