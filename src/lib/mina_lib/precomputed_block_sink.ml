(** Where a daemon writes the precomputed blocks it sees, and the background job
    that does the writing.

    The write happens off the block-processing path. Until now the daemon
    appended each block from inside the new-block handler, so the Async
    scheduler stopped for as long as the write took. A precomputed block reaches
    several megabytes, and the stall landed on every block. Blocks now go to a
    bounded queue that one background job drains.

    [dir] is the sink to prefer. It writes one file for each block, named the
    way the precomputed-block bucket names its objects
    ([<network>-<height>-<state hash>.json]), so the directory can be uploaded
    to that bucket unchanged, and anything that already reads the bucket can
    read the directory. Each block is written under a temporary name in the same
    directory and then renamed into place, so a reader never sees a block that
    is only half written.

    [file] appends each block as one JSON line to a single file. It is
    deprecated: the file grows without limit, nothing rotates it, and to find
    one block you must read the file. It stays because it ships today. *)

open Core_kernel
open Async
open Pipe_lib

type t =
  { file : string option
        (** Deprecated. Append one JSON line for each block to this file. *)
  ; dir : string option  (** Write one file for each block in this directory. *)
  ; log : bool  (** Include each block in the daemon log. *)
  }

(** The name the precomputed-block bucket gives this block. Keep it identical to
    the name [upload_blocks_to_gcloud] uses, because the point of [dir] is that
    the two are interchangeable. *)
let block_filename ~network ~height ~state_hash =
  sprintf "%s-%s-%s.json" network height state_hash

(* One write that is queued but not yet on disk. *)
type request =
  | Append of { path : string; json : string }
  | Dump of { path : string; json : string }

let request_path = function Append { path; _ } | Dump { path; _ } -> path

(* Deep enough to ride out a slow disk, shallow enough that the queue never
   holds more than a few blocks of memory. A block arrives once per block
   window, which is minutes, so a queue this deep only fills when the writer has
   stopped making progress rather than merely fallen behind. *)
let queue_capacity = 16

type writer =
  ( request
  , Strict_pipe.drop_head Strict_pipe.buffered
  , unit )
  Strict_pipe.Writer.t

(** Write [json] to [path] so that no reader ever sees a partial block: write a
    temporary file in the same directory, then rename it into place. The rename
    is atomic because both names are on one filesystem. *)
let dump_atomically ~path ~json =
  let tmp = path ^ ".tmp" in
  let%bind () = Writer.save tmp ~contents:json in
  Unix.rename ~src:tmp ~dst:path

let perform ~logger request =
  match%map
    Monitor.try_with ~here:[%here] ~rest:`Log (fun () ->
        match request with
        | Dump { path; json } ->
            dump_atomically ~path ~json
        | Append { path; json } ->
            Writer.with_file ~append:true path ~f:(fun w ->
                Writer.write_line w json ; Writer.flushed w ) )
  with
  | Ok () ->
      ()
  | Error exn ->
      (* A block the daemon could not write is a block missing from whatever
         reads this directory, so say which one, and keep serving blocks. *)
      [%log error] "Could not write precomputed block to $path: $error"
        ~metadata:
          [ ("path", `String (request_path request))
          ; ("error", `String (Exn.to_string exn))
          ]

(** Start the background job. Returns the queue to hand blocks to. *)
let start_writer ~logger : writer =
  let reader, writer =
    Strict_pipe.create ~name:"precomputed_block_sink"
      (Strict_pipe.Buffered
         ( `Capacity queue_capacity
         , `Overflow
             (Strict_pipe.Drop_head
                (fun request ->
                  [%log error]
                    "Dropping precomputed block $path: the block writer is \
                     more than $capacity blocks behind. This block will be \
                     missing from the dump."
                    ~metadata:
                      [ ("path", `String (request_path request))
                      ; ("capacity", `Int queue_capacity)
                      ] ) ) ) )
  in
  O1trace.background_thread "write_precomputed_blocks" (fun () ->
      Strict_pipe.Reader.iter reader ~f:(perform ~logger) ) ;
  writer

(** Queue every write this block calls for. [json] is forced at most once, and
    only when there is somewhere to write it. *)
let write t writer ~network ~height ~state_hash ~json =
  Option.iter t.file ~f:(fun path ->
      Strict_pipe.Writer.write writer (Append { path; json = Lazy.force json }) ) ;
  Option.iter t.dir ~f:(fun dir ->
      let path =
        Filename.concat dir (block_filename ~network ~height ~state_hash)
      in
      Strict_pipe.Writer.write writer (Dump { path; json = Lazy.force json }) )
