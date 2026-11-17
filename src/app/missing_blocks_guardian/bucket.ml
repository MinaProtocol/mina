(* bucket.ml -- the names and the URLs of the block files in a bucket *)

open Core

let block_file ~network ~height ~state_hash =
  sprintf "%s-%d-%s.json" network height state_hash

let block_url ~url ~file = url ^ "/" ^ file

(* The request that lists the block files of a network. *)
type listing =
  { uri : Uri.t
  ; key_prefix : string  (** the start of the names of the files *)
  ; url_is_bucket : bool  (** the URL has no path past the bucket *)
  }

(* The listing of the block files of [network] under [url]. The first path
   segment of [url] is the bucket, as in
   https://storage.googleapis.com/<bucket>, and the other segments are part
   of the file names: a bucket has no directories, so only the bucket itself
   can list them. *)
let listing ~url ~network =
  let url = Uri.of_string url in
  let bucket_path, key_path =
    match
      String.split (Uri.path url) ~on:'/'
      |> List.filter ~f:(Fn.non String.is_empty)
    with
    | [] ->
        ("/", [])
    | bucket :: key_path ->
        ("/" ^ bucket ^ "/", key_path)
  in
  let key_prefix = String.concat ~sep:"/" (key_path @ [ network ^ "-" ]) in
  { uri =
      Uri.with_query'
        (Uri.with_path url bucket_path)
        [ ("prefix", key_prefix); ("max-keys", "1") ]
  ; key_prefix
  ; url_is_bucket = List.is_empty key_path
  }
