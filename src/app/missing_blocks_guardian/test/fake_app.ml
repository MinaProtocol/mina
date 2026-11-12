(* Fake child programs: shell scripts in a temporary directory that write
   fixed log lines and end in a fixed way. *)

open Core
open Async

(* One line of the JSON log of a Mina program. *)
let message ~level ~text ~metadata =
  sprintf
    {|{"timestamp":"2026-11-02 10:00:00.000000Z","level":"%s","source":{"module":"x","location":"y"},"message":"%s","metadata":%s}|}
    level text metadata

let parent_lacking ~height ~hash =
  message ~level:"Info" ~text:"Block has no parent in archive db"
    ~metadata:(sprintf {|{"parent_hash":"%s","parent_height":%d}|} hash height)

let info_line = message ~level:"Info" ~text:"Done" ~metadata:"{}"

let error_line =
  message ~level:"Error" ~text:"Error getting missing blocks"
    ~metadata:{|{"error":"Failed to connect"}|}

let with_dir f =
  Thread_safe.block_on_async_exn (fun () ->
      let%bind dir = Unix.mkdtemp "/tmp/missing_blocks_guardian_test" in
      f ~dir )

let write_program ~dir ~name script =
  let path = dir ^/ name in
  let%map () =
    Writer.save path ~perm:0o755 ~contents:("#!/bin/sh\n" ^ script ^ "\n")
  in
  path

(* A program that writes [lines] to stdout, then runs [ending]. *)
let printing ~dir ~name ~lines ~ending =
  let log = dir ^/ name ^ ".log" in
  let%bind () =
    Writer.save log ~contents:(String.concat ~sep:"\n" lines ^ "\n")
  in
  write_program ~dir ~name (sprintf "cat %s\n%s" log ending)

(* A program that writes the entries of [runs] to stdout, one entry at each
   run. *)
let printing_in_turn ~dir ~name ~runs =
  let%bind () =
    Deferred.List.iteri runs ~f:(fun index lines ->
        Writer.save
          (dir ^/ sprintf "%s.%d.log" name index)
          ~contents:(String.concat ~sep:"\n" lines ^ "\n") )
  in
  let count = dir ^/ name ^ ".count" in
  write_program ~dir ~name
    (sprintf
       "run=$(cat %s 2>/dev/null || echo 0)\n\
        echo $((run + 1)) > %s\n\
        cat %s/%s.$run.log" count count dir name )
