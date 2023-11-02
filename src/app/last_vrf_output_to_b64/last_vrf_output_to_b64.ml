open Core_kernel

let () =
  let s = Stdlib.read_line () in
  let b64_check () =
    match Base64.decode ~alphabet:Base64.uri_safe_alphabet s with
    | Ok _ ->
        (* already base64 *)
        s
    | Error _ ->
        failwith "Bad Base64 encoding"
  in
  let b64 =
    (* try unhexing first, because hex chars are also base64 chars *)
    try
      match Hex.Safe.of_hex s with
      | Some unhexed ->
          Base64.encode_exn ~alphabet:Base64.uri_safe_alphabet unhexed
      | None ->
          b64_check ()
    with _ -> b64_check ()
  in
  Format.printf "%s@." b64
