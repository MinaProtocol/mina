open Core_kernel
open Async
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
    -> parent_log:Logger.t
    -> initial:Blockchain.t
    -> transactions:Transaction.t Linear_pipe.Reader.t
    -> ledger:Ledger.t
    -> body:Block.Body.t
    -> Update.t Linear_pipe.Reader.t
    -> Blockchain.t Linear_pipe.Reader.t
end

module Pedersen = Tick.Pedersen

module Cpu = struct
  module Hashing_result : sig
    type t

    val create : Blockchain.State.t -> Block.Body.t -> t

    val result : t -> [ `Ok of Nonce.t | `Cancelled ] Deferred.t

    val cancel : t -> unit
  end = struct
    type t =
      { cancelled : bool ref
      ; result : [ `Ok of Nonce.t | `Cancelled ] Deferred.t
      }

    let result t = t.result

    let cancel t = t.cancelled := true

    let find_block (previous : Blockchain.State.t) (body : Block.Body.t)
      : Nonce.t option =
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
          then Some nonce
          else go (Nonce.succ nonce) (i + 1)
      in
      go nonce0 0
    ;;

    let create previous body =
      let cancelled = ref false in
      let rec go () =
        if !cancelled
        then return `Cancelled
        else begin
          match find_block previous body with
          | None ->
            let%bind () = after (sec 0.01) in
            go ()
          | Some nonce ->
            return (`Ok nonce)
        end
      in
      { cancelled; result = go () }
  end

  module Bundle_result : sig
    type t

    val result : t -> (Transaction_snark.t * Transaction.t list) option Deferred.t

    val cancel : t -> unit

    val create : Transaction_pool.t -> Ledger.t -> t
  end = struct
    type t =
      { bundle : Bundle.t
      ; transactions : Transaction.t list
      }

    let cancel t = Bundle.cancel t.bundle

    let result t =
      Deferred.Option.map (Bundle.snark t.bundle)
        ~f:(fun snark -> (snark, t.transactions))

    let transactions_per_snark = 10

    let create pool ledger =
      let transactions =
        let rec go i ts pool =
          if i = 0
          then ts
          else
            match Transaction_pool.pop pool with
            | Some (t, pool) ->
              go (i - 1) (t :: ts) pool
            | None -> ts
        in
        go transactions_per_snark [] pool
      in
      let bundle = Bundle.create transactions in
      { bundle; transactions }
  end

  module Mining_result : sig
    type t

    val cancel : t -> unit

    val create
      : transaction_pool:Transaction_pool.t
      -> ledger:Ledger.t
      -> blockchain_state:Blockchain_state.t
      -> t
  end = struct
    type t =
      { hashing_result : Hashing_result.t
      ; bundle_result : Bundle_result.t
      }

    let create ~transaction_pool ~ledger ~blockchain_state =
      { bundle_result = Bundle_result.create transaction_pool ledger
      ; hashing_result =
          Hashing_result.create
            blockchain_state
      }
      
  end

  module Mode = struct
    type t =
      | Mining of
          { transaction_bundle : Transaction_snark.t Deferred.t
          ; target_hash : Ledger_hash.t
          }
  end

  module State = struct
    type t =
      { mutable previous     : Blockchain.t
      ; mutable body         : Block.Body.t
      ; mutable id           : int
      ; mutable transactions : Transaction_pool.t
      ; ledger               : Ledger.t
      }
  end

  let mine
        ~(prover : Prover.t)
        ~(parent_log : Logger.t)
        ~(initial : Blockchain.t)
        ~(ledger : Ledger.t)
        ~(transactions : Transaction.t Linear_pipe.Reader.t)
        ~body
        (updates : Update.t Linear_pipe.Reader.t)
    =
    let pool = ref Transaction_pool.empty in
    don't_wait_for
      (Linear_pipe.iter transactions ~f:(fun t ->
        pool := Transaction_pool.add !pool t;
        Deferred.unit));
    (* TODO: Transactions get one shot to make it in... *)
    Deferred.any
  ;;

  let mine
        ~(prover : Prover.t)
        ~(parent_log : Logger.t)
        ~(initial : Blockchain.t)
        ~(ledger : Ledger.t)
        ~(transactions : Transaction.t Linear_pipe.Reader.t)
        ~body
        (updates : Update.t Linear_pipe.Reader.t)
    =
    let log = Logger.child parent_log "miner" in
    let state =
      { State.previous = initial
      ; body
      ; id = 0
      ; transactions = Transaction_pool.empty
      ; ledger
      }
    in
    let mined_blocks_reader, mined_blocks_writer = Linear_pipe.create () in
    let rec go () =
      let%bind () = after (sec 0.01) in
      let id = state.id in
      let previous = state.previous in
      match%bind schedule' (fun () -> return (find_block previous.state state.body)) with
      | None -> go ()
      | Some (block, header_hash) ->
        if id = state.id
        then begin
          (* Soon: Make this poll instead of waiting so that a miner waiting on
             can be pre-empted by a new block coming in off the network. Or come up
             with some other way for this to get interrupted.
          *)
          match%bind Prover.extend_blockchain prover previous block with
          | Ok chain ->
            let%bind () = Pipe.write mined_blocks_writer chain in
            state.previous <- chain;
            state.id <- state.id + 1;
            go ()
          | Error e ->
            Logger.error log "%s" Error.(to_string_hum (tag e ~tag:"Blockchain extend error"));
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
