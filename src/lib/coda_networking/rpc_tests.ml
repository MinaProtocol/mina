(* rpc_tests.ml -- deserialization tests for RPC types *)

(* TODO : uncomment unit tests below when Coda_networking, Rpcs are defunctored so we can
   run unit tests here
*)

let serialization_in_buffer serialization =
  let len = String.length serialization in
  let buff = Bin_prot.Common.create_buf len in
  Bin_prot.Common.blit_string_buf serialization buff ~len ;
  buff

(* Get_staged_ledger_aux_and_pending_coinbases_at_hash *)

(* let%test "Get_staged_ledger_aux_and_pending_coinbases_at_hash V1 \
                deserialize query" =
        (* serialization should fail if the query type has changed *)
        let known_good_serialization =
          "\x01\x28\x61\x68\xB6\x65\x95\x11\x82\x15\xAC\x9D\x8B\x24\x6F\x5D\x85\xE0\x3B\xE6\x5A\x27\x3C\x2930\x04\x6E\xE9\xBE\xE4\x04\xFA\xFB\x44\xF6\x00\x00\x00\x00\x00\x00\x00\x00\x01\x01\x01\x09\x31\x32\x37\x2E\x30\x2E\x30\x2E\x31\xFE\xDB\x59\xFE\xDA\x59"
        in
        let buff = serialization_in_buffer known_good_serialization in
        let pos_ref = ref 0 in
        let _ : query = V1.bin_read_query buff ~pos_ref in
        true
*)

(* Answer_sync_ledger_query *)

(*
  let%test "Answer_sync_ledger_query V1 deserialize response" =
  (* serialization should fail if the response type has changed *)
  let known_good_serialization = "\x00\x01\x02\x12\x01\x28\xC7\xBC\x6A\x07\xC9\x22\x93\xFD\xA4\x57\x7D\xE2\xF0\x3E\xDC\xB4\x56\x6A\xCB\xF8\x6E\x94\xCD\xC2\x61\x72\x9A\xA5\x8E\xAD\x5D\xFD\x00\x00\x00\x00\x00\x00\x00\x00" in
  let buff = serialization_in_buffer known_good_serialization in
  let pos_ref = ref 0 in
  let _ : response = V1.bin_read_response buff ~pos_ref in
  true
 *)

(* Get_ancestry *)

(* Message *)
