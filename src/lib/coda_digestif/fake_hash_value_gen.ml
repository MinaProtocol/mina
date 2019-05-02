[%%import
"../../config.mlh"]

[%%inject
"fake_hash", fake_hash_value]

open Core

let () =
  Out_channel.with_channel Sys.argv.(1) ~f:(fun ch ->
      Out_channel.output_string ch fake_hash )
