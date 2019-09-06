open Core

(* copy paste from base58_check.ml *)
let coda_alphabet =
  B58.make_alphabet
    "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

let () =
  Command.run
  @@ Command.basic
       ~summary:"Remove the version bytes and checksums from base58check data"
  @@
  let open Command.Let_syntax in
  let%map_open input = anon ("in-data" %: string) in
  fun () ->
    let input_bytes = Bytes.of_string input in
    let decoded_bytes = B58.decode coda_alphabet input_bytes in
    (* A base58check string is a single version byte, the payload, then 4 bytes
       of hash. *)
    let payload_len = Bytes.length decoded_bytes - 4 - 1 in
    let output_bytes = Bytes.create payload_len in
    Bytes.blit ~src:decoded_bytes ~src_pos:1 ~dst:output_bytes ~dst_pos:0
      ~len:payload_len ;
    print_endline @@ Bytes.to_string @@ B58.encode coda_alphabet output_bytes
