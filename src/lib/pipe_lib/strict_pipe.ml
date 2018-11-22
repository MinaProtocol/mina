open Async_kernel

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

  let enforce_single_reader reader deferred =
    if reader.has_reader then raise Multiple_reads_attempted
    else (
      reader.has_reader <- true ;
      let%map result = deferred in
      reader.has_reader <- false ;
      result )

  let fold ?consumer reader ~init ~f =
    enforce_single_reader reader (Pipe.fold reader.reader ?consumer ~init ~f)

  let iter ?consumer ?continue_on_error reader ~f =
    enforce_single_reader reader
      (Pipe.iter reader.reader ?consumer ?continue_on_error ~f)
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
