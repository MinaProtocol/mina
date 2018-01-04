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
  let find_block (previous : Pedersen.Main.Digest.t) (body : Block.Body.t) (nonce: Nonce.t)
    : (Block.t * Pedersen.Main.Digest.t) option Deferred.t =
      let target : Target.t = failwith "TODO" in
      let bigger : Pedersen.Main.Digest.t -> Target.t -> bool = failwith "TODO" in

      let block : Block.t =
        { header =
            { previous_header_hash = previous
            ; body_hash = Block.Body.hash body
            ; time = Block_time.of_time (Time.now ())
            ; target
            ; nonce
            ; strength = Strength.zero (* TODO: What is strength *)
            }
        ; body = body
        }
      in
      (* TODO: Assuming this is the slow bit we want to make deferred *)
      let%map block_hash =
        Deferred.create (fun ivar ->
          (* TODO: How to schedule this in the background *)
          let hash = Block.Body.hash body in
          Ivar.fill ivar hash;
        )
      in

      Option.some_if
        (bigger block_hash target)
        (block, block_hash)
  ;;

  module State = struct
    type t =
      { mutable previous_header_hash : Pedersen.Main.Digest.t
      ; mutable body                 : Block.Body.t
      ; mutable id                   : int
      }
  end

  let mine ~previous ~body (updates : Update.t Pipe.Reader.t) =
    let state =
      { State.previous_header_hash = Block.Header.hash previous.Block.header
      ; body
      ; id = 0
      }
    in
    let mined_blocks_reader, mined_blocks_writer = Pipe.create () in
    let rec go nonce =
      let id = state.id in
      match%bind find_block state.previous_header_hash state.body nonce with
      | None -> go (Nonce.increment nonce)
      | Some (block, header_hash) ->
        if id = state.id
        then begin
          let%bind () = Pipe.write mined_blocks_writer block in
          state.previous_header_hash <- header_hash;
          state.id <- state.id + 1;
          go Nonce.zero
        end else
          go Nonce.zero
    in
    don't_wait_for (go Nonce.zero);
    don't_wait_for begin
      Pipe.iter' updates ~f:(fun q ->
        Queue.iter q ~f:(fun u ->
          state.id <- state.id + 1;
          begin match u with
          | Change_previous b ->
            state.previous_header_hash <- Block.Header.hash b.header
          | Change_body body ->
            state.body <- body
          end);
        Deferred.unit)
    end;
    mined_blocks_reader
end
