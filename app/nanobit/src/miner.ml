open Core_kernel
open Async_kernel
open Nanobit_base
open Snark_params

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

module Pedersen = Tick.Pedersen

module Cpu = struct
  let find_block (previous : Blockchain.State.t) (body : Block.Body.t)
    : (Block.t * Pedersen.Digest.t) option Deferred.t =
    let iterations = 10 in
    let target = Blockchain.State.compute_target previous in
    let nonce0 = Nonce.random () in
    let header0 : Block.Header.t =
      { previous_block_hash = previous.block_hash
      ; time = Block_time.of_time (Time.now ())
      ; nonce = nonce0
      }
    in
    let block0 : Block.t = { header = header0; body } in
    let rec go nonce i =
      if i = iterations
      then None
      else
        let block : Block.t = { block0 with header = { header0 with nonce } } in
        let hash = Block.hash block in
        if Target.meets_target target ~hash
        then Some (block, hash)
        else go (Nonce.succ nonce) (i + 1)
    in
    schedule' (fun () -> return (go nonce0 0))
  ;;

  module State = struct
    type t =
      { mutable previous : Blockchain.t
      ; mutable body     : Block.Body.t
      ; mutable id       : int
      }
  end

  let mine ~(previous : Blockchain.t) ~body (updates : Update.t Linear_pipe.Reader.t) =
    let state =
      { State.previous
      ; body
      ; id = 0
      }
    in
    let mined_blocks_reader, mined_blocks_writer = Linear_pipe.create () in
    let rec go () =
      let id = state.id in
      match%bind find_block state.previous.state state.body with
      | None -> go ()
      | Some (block, header_hash) ->
        if id = state.id
        then begin
          let chain = Blockchain.extend_exn previous block in
          let%bind () = Pipe.write mined_blocks_writer chain in
          state.previous <- chain;
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
          state.previous <- b
        | Change_body body ->
          state.body <- body
        end;
        Deferred.unit)
    end;
    mined_blocks_reader
end
