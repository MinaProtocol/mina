open Core_kernel
open Async_kernel

module Update = struct
  type t =
    | Change_previous of Block.t
    | Change_body of Block.Body.t
end

module type S = sig
  val mine
    : previous:Block.t
    -> body:Block.Body.t
    -> Update.t Pipe.Reader.t
    -> Block.t Pipe.Reader.t
end

module Cpu = struct
  let find_block (previous : Pedersen.Digest.t) (body : Block.Body.t)
    : (Block.t * Pedersen.Digest.t) option Deferred.t =
    failwith "TODO"
  ;;

  module State = struct
    type t =
      { mutable previous_header_hash : Pedersen.Digest.t
      ; mutable body                 : Block.Body.t
      ; mutable id                   : int
      }
  end

  let hash_header header =
    let buf = Bigstring.create (Block.Header.bin_size_t header) in
    ignore (Block.Header.bin_write_t buf ~pos:0 header);
    let s = Pedersen.State.create () in
    Pedersen.State.update s buf;
    Pedersen.State.digest s
  ;;

  let mine ~previous ~body (updates : Update.t Pipe.Reader.t) =
    let state =
      { State.previous_header_hash = hash_header previous.Block.header
      ; body
      ; id = 0
      }
    in
    let mined_blocks_reader, mined_blocks_writer = Pipe.create () in
    let rec go () =
      let id = state.id in
      match%bind find_block state.previous_header_hash state.body with
      | None -> go ()
      | Some (block, header_hash) ->
        if id = state.id
        then begin
          let%bind () = Pipe.write mined_blocks_writer block in
          state.previous_header_hash <- header_hash;
          state.id <- state.id + 1;
          go ()
        end else
          go ()
    in
    don't_wait_for (go ());
    don't_wait_for begin
      Pipe.iter' updates ~f:(fun q ->
        state.id <- state.id + 1;
        Queue.iter q ~f:(fun u ->
          begin match u with
          | Change_previous b ->
            state.previous_header_hash <- hash_header b.header
          | Change_body body ->
            state.body <- body
          end);
        Deferred.unit)
    end;
    mined_blocks_reader
end
