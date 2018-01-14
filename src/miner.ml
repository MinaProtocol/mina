open Core_kernel
open Async_kernel

module Update = struct
  type t =
    | Change_previous of Blockchain.t
    | Change_body of Block.Body.t
end

module type S = sig
  val mine
    : previous:Blockchain.t
    -> body:Block.Body.t
    -> Update.t Linear_pipe.Reader.t
    -> Blockchain.t Linear_pipe.Reader.t
end

module Cpu = struct
  let find_block (previous : Pedersen.Main.Digest.t) (body : Block.Body.t)
    : (Blockchain.t * Pedersen.Main.Digest.t) option Deferred.t =
    failwith "TODO"
  ;;

  module State = struct
    type t =
      { mutable previous_block_hash : Pedersen.Main.Digest.t
      ; mutable body                 : Block.Body.t
      ; mutable id                   : int
      }
  end

  let mine ~(previous : Blockchain.t) ~body (updates : Update.t Linear_pipe.Reader.t) =
    let state =
      { State.previous_block_hash = Block.hash previous.block
      ; body
      ; id = 0
      }
    in
    let mined_blocks_reader, mined_blocks_writer = Linear_pipe.create () in
    let rec go () =
      let id = state.id in
      match%bind find_block state.previous_block_hash state.body with
      | None -> go ()
      | Some (block, header_hash) ->
        if id = state.id
        then begin
          let%bind () = Pipe.write mined_blocks_writer block in
          state.previous_block_hash <- header_hash;
          state.id <- state.id + 1;
          go ()
        end else
          go ()
    in
    don't_wait_for (go ());
    don't_wait_for begin
      Linear_pipe.iter updates ~f:(fun u ->
        state.id <- state.id + 1;
        begin match u with
        | Change_previous b ->
          state.previous_block_hash <- Block.hash b.block
        | Change_body body ->
          state.body <- body
        end;
        Deferred.unit)
    end;
    mined_blocks_reader
end
