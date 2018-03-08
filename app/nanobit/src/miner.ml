open Core_kernel
open Async
open Nanobit_base
open Snark_params

module Update = struct
  type t =
    | Change_previous of Blockchain.t
    | Change_body of Block.Body.t
end

module Mined_block_metadata = struct
  type t = {
    hash_attempts: int
  }
end

module type S = sig
  val mine
    : prover:Prover.t
    -> parent_log:Logger.t
    -> initial:Blockchain.t
    -> body:Block.Body.t
    -> Update.t Linear_pipe.Reader.t
    -> (Blockchain.t * Mined_block_metadata.t) Linear_pipe.Reader.t
end

module Pedersen = Tick.Pedersen

module Cpu = struct
  let find_block (previous : Blockchain.State.t) (body : Block.Body.t)
    : (Block.t * Pedersen.Digest.t) option * int =
    let iterations = 10 in
    let target = previous.target in
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
      then (None, i)
      else
        let block : Block.t =
          { block0 with header = { header0 with nonce } }
        in
        let hash = Block.hash block in
        if Target.meets_target_unchecked target ~hash
        then (Some (block, hash), i)
        else go (Nonce.succ nonce) (i + 1)
    in
    go nonce0 0
  ;;

  let%test "expected_hashes" = 
    let nonce = Nonce.random () in
    let header0 : Block.Header.t =
      { previous_block_hash = Block.hash Block.genesis 
      ; time = Block_time.of_time (Time.now ())
      ; nonce
      }
    in
    let target = Target.max in
    let block0 : Block.t = { header = header0; body = Int64.of_int_exn 40 } in
    let times = 
      List.init 30 ~f:(fun _ -> 
        let rec go i = 
          let nonce = Nonce.random () in
          let block : Block.t =
            { block0 with header = { header0 with nonce } }
          in
          let hash = Block.hash block in
          if Target.meets_target_unchecked target ~hash
          then (i + 1)
          else go (i + 1)
        in
        go 0)
    in
    let avg = (Float.of_int (List.reduce_exn times ~f:(+))) /. (Float.of_int (List.length times)) in
    let expected_hash_attempts = Bignum.Bigint.to_float (Nanobit_base.Target.expected_hash_attempts target) in
    let percent_diff = Float.max (expected_hash_attempts /. avg) (expected_hash_attempts /. avg) in
    percent_diff < 1.05
  ;;

  module State = struct
    type t =
      { mutable previous : Blockchain.t
      ; mutable body     : Block.Body.t
      ; mutable id       : int
      }
  end

  let mine
        ~(prover : Prover.t)
        ~(parent_log : Logger.t)
        ~(initial : Blockchain.t)
        ~body
        (updates : Update.t Linear_pipe.Reader.t)
    =
    let log = Logger.child parent_log "miner" in
    let state =
      { State.previous = initial
      ; body
      ; id = 0
      }
    in
    let mined_blocks_reader, mined_blocks_writer = Linear_pipe.create () in
    let rec go iters =
      let%bind () = after (sec 0.01) in
      let id = state.id in
      let previous = state.previous in
      match%bind schedule' (fun () -> return (find_block previous.state state.body)) with
      | (None, i) -> go (i + iters)
      | (Some (block, header_hash), i) ->
        if id = state.id
        then begin
          (* Soon: Make this poll instead of waiting so that a miner waiting on
             can be pre-empted by a new block coming in off the network. Or come up
             with some other way for this to get interrupted.
          *)
          match%bind Prover.extend_blockchain prover previous block with
          | Ok chain ->
            Logger.info log ~attrs:[ ("hash_attempts", [%sexp_of: int] (i + iters) ) ]
              "mined_block";
            let%bind () = Pipe.write mined_blocks_writer (chain, { Mined_block_metadata.hash_attempts = (i + iters) }) in
            state.previous <- chain;
            state.id <- state.id + 1;
            go 0
          | Error e ->
            Logger.error log "%s" Error.(to_string_hum (tag e ~tag:"Blockchain extend error"));
            go 0
        end else
          go 0
    in
    don't_wait_for (go 0);
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
