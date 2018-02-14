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
    : prover:Prover.t
    -> initial:Blockchain.t
    -> body:Block.Body.t
    -> Update.t Linear_pipe.Reader.t
    -> Blockchain.t Linear_pipe.Reader.t
end

module Pedersen = Tick.Pedersen

module Cpu = struct
  let find_block (previous : Blockchain.State.t) (body : Block.Body.t)
    : (Block.t * Pedersen.Digest.t) option =
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
      then None
      else
        let block : Block.t =
          { block0 with header = { header0 with nonce } }
        in
        let hash = Block.hash block in
        if Target.meets_target_unchecked target ~hash
        then Some (block, hash)
        else go (Nonce.succ nonce) (i + 1)
    in
    go nonce0 0
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
        ~(initial : Blockchain.t)
        ~body
        (updates : Update.t Linear_pipe.Reader.t)
    =
    let state =
      { State.previous = initial
      ; body
      ; id = 0
      }
    in
    let mined_blocks_reader, mined_blocks_writer = Linear_pipe.create () in
    let rec go () =
      let id = state.id in
      let%bind () = after (Time_ns.Span.of_sec 0.1) in
      let previous = state.previous in
      match%bind schedule' (fun () -> return (find_block previous.state state.body)) with
      | None -> go ()
      | Some (block, header_hash) ->
        printf !"found block: id: %d\nstate:\n%{sexp:Blockchain_state.t}\n%!" state.id state.previous.state;
        if id = state.id
        then begin
          (* Soon: Make this poll instead of waiting so that a miner waiting on
             can be pre-empted by a new block coming in off the network. Or come up
             with some other way for this to get interrupted.
          *)
          printf !"calling_prover-id: %d\ncalling_prover-state:\n%{sexp:Blockchain_state.t}\n%!"
            id previous.state;
          match%bind Prover.extend_blockchain prover previous block with
          | Ok chain ->
            printf !"Prover returned a chain with state:\n%{sexp:Blockchain_state.t}\n%!" chain.state;
            let%bind () = Pipe.write mined_blocks_writer chain in
            state.previous <- chain;
            state.id <- state.id + 1;
            go ()
          | Error e ->
            eprintf "%s\n%!" Error.(to_string_hum (tag e ~tag:"Blockchain extend error"));
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
