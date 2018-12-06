open Async_kernel
open Core_kernel

exception Overflow

exception Multiple_reads_attempted

type crash = Overflow_behavior_crash

type drop_head = Overflow_behavior_drop_head

type _ overflow_behavior =
  | Crash : crash overflow_behavior
  | Drop_head : drop_head overflow_behavior

type synchronous = Type_synchronous

type _ buffered = Type_buffered

type (_, _) type_ =
  | Synchronous : (synchronous, unit Deferred.t) type_
  | Buffered :
      [`Capacity of int] * [`Overflow of 'b overflow_behavior]
      -> ('b buffered, unit) type_

module Reader = struct
  type 't t = {reader: 't Pipe.Reader.t; mutable has_reader: bool}

  let assert_not_read reader =
    if reader.has_reader then raise Multiple_reads_attempted

  let wrap_reader reader = {reader; has_reader= false}

  let enforce_single_reader reader deferred =
    assert_not_read reader ;
    reader.has_reader <- true ;
    let%map result = deferred in
    reader.has_reader <- false ;
    result

  let fold ?consumer reader ~init ~f =
    enforce_single_reader reader (Pipe.fold reader.reader ?consumer ~init ~f)

  let iter ?consumer ?continue_on_error reader ~f =
    enforce_single_reader reader
      (Pipe.iter_without_pushback reader.reader ?consumer ?continue_on_error ~f)

  let map reader ~f =
    assert_not_read reader ;
    reader.has_reader <- true ;
    wrap_reader (Pipe.map reader.reader ~f)

  let filter_map reader ~f =
    assert_not_read reader ;
    reader.has_reader <- true ;
    wrap_reader (Pipe.filter_map reader.reader ~f)

  module Merge = struct
    let iter readers ~f =
      let not_empty r = Pipe.is_empty r.reader in
      let rec read_deferred () =
        let%bind ready_reader =
          match List.find readers ~f:not_empty with
          | Some reader -> Deferred.return reader
          | None ->
              let%map () =
                Deferred.choose
                  (List.map readers ~f:(fun r ->
                       Deferred.choice (Pipe.values_available r.reader)
                         (fun _ -> () ) ))
              in
              List.find_exn readers ~f:not_empty
        in
        match Pipe.read_now ready_reader.reader with
        | `Nothing_available -> failwith "impossible"
        | `Eof -> Deferred.return ()
        | `Ok value -> Deferred.bind (f value) ~f:read_deferred
      in
      List.iter readers ~f:assert_not_read ;
      read_deferred ()

    let iter_sync readers ~f = iter readers ~f:(fun x -> f x ; Deferred.unit)
  end

  module Fork = struct
    let n reader count =
      let pipes = List.init count ~f:(fun _ -> Pipe.create ()) in
      let readers, writers = List.unzip pipes in
      (* This one place we _do_ want iter with pushback which we want to trigger
       * when all reads have pushed back downstream
       *
       * Since future reads will resolve via the iter_without_pushback, we
       * should still get the behavior we want. *)
      don't_wait_for
        (Pipe.iter reader.reader ~f:(fun x ->
             Deferred.List.iter writers ~f:(fun writer ->
                 if not (Pipe.is_closed writer) then Pipe.write writer x
                 else return () ) )) ;
      don't_wait_for
        (let%map () = Deferred.List.iter readers ~f:Pipe.closed in
         Pipe.close_read reader.reader) ;
      List.map readers ~f:wrap_reader

    let two reader =
      match n reader 2 with [a; b] -> (a, b) | _ -> failwith "unexpected"
  end
end

module Writer = struct
  type ('t, 'type_, 'write_return) t =
    { type_: ('type_, 'write_return) type_
    ; reader: 't Pipe.Reader.t
    ; writer: 't Pipe.Writer.t }

  let handle_overflow : type b.
      ('t, b buffered, unit) t -> 't -> b overflow_behavior -> unit =
   fun writer data overflow_behavior ->
    match overflow_behavior with
    | Crash -> raise Overflow
    | Drop_head ->
        ignore (Pipe.read_now writer.reader) ;
        Pipe.write_without_pushback writer.writer data

  let write : type type_ return. ('t, type_, return) t -> 't -> return =
   fun writer data ->
    match writer.type_ with
    | Synchronous -> Pipe.write writer.writer data
    | Buffered (`Capacity capacity, `Overflow overflow) ->
        if Pipe.length writer.reader > capacity then
          handle_overflow writer data overflow
        else Pipe.write_without_pushback writer.writer data
end

let create type_ =
  let reader, writer = Pipe.create () in
  let reader, writer =
    (Reader.{reader; has_reader= false}, Writer.{type_; reader; writer})
  in
  (reader, writer)

let transfer reader {Writer.writer; _} ~f =
  Reader.enforce_single_reader reader (Pipe.transfer reader.reader writer ~f)
