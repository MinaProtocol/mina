open Async

let bucket_name = "mina-archive-dumps"

let download_via_public_url ~prefix ~date ~target =
  let open Deferred.Let_syntax in
  let dump_name =
    Printf.sprintf "%s-archive-dump-%s_0000.sql.tar.gz" prefix date
  in
  let archive = Filename.concat target dump_name in
  let%bind _ =
    Utils.wget
      ~url:
        (Printf.sprintf "https://storage.googleapis.com/%s/%s" bucket_name
           dump_name )
      ~target:archive
  in
  Deferred.return archive
