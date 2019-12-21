open Core

let extract_kv_str markdown =
  let open Option.Let_syntax in
  let%bind tl = String.chop_prefix markdown ~prefix:"---\n" in
  let%map i = String.substr_index tl "\n---" in
  String.sub ~pos:0 ~len:i tl

let split_kv s =
  match String.index s ':' with
  | None ->
      None
  | Some i ->
      let n = String.length s in
      Some
        (String.sub s ~pos:0 ~len:i, String.sub s ~pos:(i + 1) ~len:(n - i - 1))
