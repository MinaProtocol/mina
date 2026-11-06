(* recovery.ml -- restore blocks one by one: download a missing parent, write
   it to the archive and ask the auditor for the next one. A failure is an
   [Error] with the reason, for the caller to report. *)

open Core
open Async

(* Downloads the file of [parent] from the bucket and returns its name. The
   bucket answered at start, so a failure here is about the file: the error
   shows how its URL was built. *)
let download ~logger (blocks : Config.blocks) (parent : Auditor.missing_parent)
    =
  let file =
    Bucket.block_file ~network:blocks.network ~height:parent.height
      ~state_hash:parent.hash
  in
  let url = Bucket.block_url ~url:blocks.url ~file in
  [%log info] "Downloading block $file from $url"
    ~metadata:[ ("file", `String file); ("url", `String url) ] ;
  match%map Download.fetch ~url ~file with
  | Ok () ->
      Ok file
  | Error err ->
      Error
        (sprintf
           "Could not download the block at height %d with state hash %s: %s. \
            Its URL %s is <bucket URL>/<network>-<height>-<state hash>.json, \
            with the bucket URL %s from --precomputed-blocks-url or \
            PRECOMPUTED_BLOCKS_URL and the network %s from --network or \
            MINA_NETWORK. The bucket answered at start, so check the network \
            name and whether the block is in the bucket."
           parent.height parent.hash (Error.to_string_hum err) url blocks.url
           blocks.network )

let remove file =
  match%map Monitor.try_with_or_error (fun () -> Unix.unlink file) with
  | Ok () ->
      Ok ()
  | Error err ->
      Error (sprintf "Could not remove %s: %s" file (Error.to_string_hum err))

(* Writes [file] to the archive with [add_block] and removes it, also after a
   failure. *)
let populate ~logger ~add_block file =
  match%bind add_block file with
  | Ok () ->
      [%log info] "Populated the database with $file"
        ~metadata:[ ("file", `String file) ] ;
      remove file
  | Error reason -> (
      match%map remove file with
      | Ok () ->
          Error reason
      | Error not_removed ->
          Error (reason ^ " " ^ not_removed) )

(* Imports [parent] from the bucket, then each next missing parent that the
   auditor reports, until it reports none. Stops when an import changes
   nothing, so that one bad block file cannot keep it busy forever. *)
let rec restore ~logger ~add_block (archive : Config.archive)
    (blocks : Config.blocks) (parent : Auditor.missing_parent) =
  let open Deferred.Result.Let_syntax in
  let%bind file = download ~logger blocks parent in
  let%bind () = populate ~logger ~add_block file in
  match%bind
    Auditor.check ~logger ~prog:archive.auditor ~archive_uri:archive.uri
  with
  | None ->
      return ()
  | Some next when Auditor.equal_missing_parent next parent ->
      Deferred.return
        (Error
           (sprintf
              "Added %s, but the archive still lacks block %s at height %d. \
               The database remains unhealthy."
              file parent.hash parent.height ) )
  | Some next ->
      restore ~logger ~add_block archive blocks next
