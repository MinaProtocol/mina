(**
Module to download precomputed blocks from o1labs official gcloud bucket.
*)

open Async

let bucket_name = "mina-archive-dumps"

let dump_name ~prefix ~date =
  Printf.sprintf "%s-archive-dump-%s_0000.sql.tar.gz" prefix date

(** [sql_name ~prefix ~date] is the file the dump archive extracts to. *)
let sql_name ~prefix ~date =
  Printf.sprintf "%s-archive-dump-%s_0000.sql" prefix date

let public_url ~prefix ~date =
  Printf.sprintf "https://storage.googleapis.com/%s/%s" bucket_name
    (dump_name ~prefix ~date)

(** [find_latest_date ~prefix ~max_age_days] is the date (YYYY-MM-DD, UTC) of
    the newest midnight dump no older than [max_age_days], if any. *)
let find_latest_date ~prefix ~max_age_days =
  let open Core in
  let today = Date.today ~zone:Time.Zone.utc in
  Deferred.List.find_map
    (List.range 0 (max_age_days + 1))
    ~f:(fun days_back ->
      let date = Date.add_days today (-days_back) |> Date.to_string in
      match%map
        Monitor.try_with ~rest:`Log (fun () ->
            Cohttp_async.Client.head (Uri.of_string (public_url ~prefix ~date)) )
      with
      | Ok response
        when Cohttp.Code.is_success
               (Cohttp.Code.code_of_status (Cohttp.Response.status response)) ->
          Some date
      | _ ->
          None )

let download_via_public_url ~prefix ~date ~target =
  let open Deferred.Let_syntax in
  let dump_name = dump_name ~prefix ~date in
  let archive = Filename.concat target dump_name in
  let%bind _ = Utils.wget ~url:(public_url ~prefix ~date) ~target:archive in
  Deferred.return archive
