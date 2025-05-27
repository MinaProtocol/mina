open Core_kernel
open Async_kernel

(* NOTE: Data flow:
      long_live_writer
   -external-producer-> long_live_reader
   -actor-> tmp_swapped_writer
   -external-consumer-> tmp_swapped_reader (tracked out of this structure)
*)

type ('data_in_pipe, 'pipe_kind, 'write_return) t =
  { name : string
  ; long_live_writer :
      ('data_in_pipe, 'pipe_kind, 'write_return) Strict_pipe.Writer.t
  ; long_live_reader : 'data_in_pipe Strict_pipe.Reader.t
  ; mutable should_terminate : bool
  ; mutable reader_request :
      (string * 'data_in_pipe Strict_pipe.Reader.t Ivar.t) option
  ; mutable tmp_swapped_writer :
      ( 'data_in_pipe
      , Strict_pipe.synchronous
      , unit Deferred.t )
      Strict_pipe.Writer.t
      option
  }

let run (t : _ t) =
  let process_reader_request () =
    let%map.Option tmp_pipe_name, response = t.reader_request in
    let tmp_reader, new_tmp_writer =
      Strict_pipe.create ~name:tmp_pipe_name Strict_pipe.Synchronous
    in
    Option.iter ~f:Strict_pipe.Writer.kill t.tmp_swapped_writer ;
    t.tmp_swapped_writer <- Some new_tmp_writer ;
    Ivar.fill response tmp_reader ;
    t.reader_request <- None ;
    `Worked
  in
  let process_write () =
    match t.tmp_swapped_writer with
    | None ->
        Deferred.return None
    | Some tmp_swapped_writer -> (
        match%bind Strict_pipe.Reader.read t.long_live_reader with
        | `Ok data ->
            let%map () = Strict_pipe.Writer.write tmp_swapped_writer data in
            Some `Worked
        | `Eof ->
            t.should_terminate <- true ;
            Deferred.return (Some `Worked) )
  in
  let step t =
    if t.should_terminate then (
      Strict_pipe.Writer.kill t.long_live_writer ;
      Option.iter ~f:Strict_pipe.Writer.kill t.tmp_swapped_writer ;
      Deferred.return (`Finished ()) )
    else
      match process_reader_request () with
      | Some `Worked ->
          let%map _ = process_write () in
          `Repeat t
      | None -> (
          match%bind process_write () with
          | Some `Worked ->
              Deferred.return (`Repeat t)
          | None ->
              let%map () = Async_kernel_scheduler.yield () in
              `Repeat t )
  in
  Deferred.repeat_until_finished t step

let create ?warn_on_drop ~name type_ =
  let long_live_reader, long_live_writer =
    Strict_pipe.create ~name ?warn_on_drop type_
  in
  let actor =
    { name
    ; long_live_writer
    ; long_live_reader
    ; should_terminate = false
    ; reader_request = None
    ; tmp_swapped_writer = None
    }
  in
  don't_wait_for (run actor) ;
  actor

let write { long_live_writer; _ } = Strict_pipe.Writer.write long_live_writer

let request_reader ~reader_name t :
    'data_in_pipe Strict_pipe.Reader.t Deferred.t =
  let response = Ivar.create () in
  t.reader_request <- Some (reader_name, response) ;
  Ivar.read response

let kill t = t.should_terminate <- true
