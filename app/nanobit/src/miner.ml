open Core_kernel
open Async
open Nanobit_base
open Snark_params

module Update = struct
  type t =
    | Received_block of Block.Body.t
    | Found_block of Block.Body.t
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

    val create : Blockchain.State.t -> target_hash:Ledger_hash.t -> t

    val result : t -> [ `Ok of Nonce.t | `Cancelled ] Deferred.t

    val cancel : t -> unit
  end = struct
    type t =
      { cancelled : bool ref
      ; result : [ `Ok of Nonce.t | `Cancelled ] Deferred.t
      }

    let result t = t.result

    let cancel t = t.cancelled := true

    let find_block (previous : Blockchain.State.t) ~(target_hash : Ledger_hash.t)
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
      let body : Block.Body.t = { target_hash; proof = Tock.Proof.dummy } in
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

    let create previous ~target_hash =
      let cancelled = ref false in
      let rec go () =
        if !cancelled
        then return `Cancelled
        else begin
          match find_block previous ~target_hash with
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

    val transactions : t -> Transaction.t list 

    val target_hash : t -> Ledger_hash.t

    val result : t -> (Transaction_snark.t * Transaction.t list) option Deferred.t

    val cancel : t -> unit

    val create : Transaction.t list -> Ledger.t -> t
  end = struct
    type t =
      { bundle : Bundle.t
      ; transactions : Transaction.t list
      }
    [@@deriving fields]

    let target_hash t = Bundle.target_hash t.bundle

    let cancel t = Bundle.cancel t.bundle

    let result t =
      Deferred.Option.map (Bundle.snark t.bundle)
        ~f:(fun snark -> (snark, t.transactions))

    let create transactions ledger =
      let bundle = Bundle.create ledger transactions in
      { bundle; transactions }
  end

  module Mining_result : sig
    type t

    val cancel : t -> unit

    val create
      : transactions:Transaction.t list
      -> ledger:Ledger.t
      -> blockchain_state:Blockchain_state.t
      -> t

    val result : t -> (Nonce.t * Transaction_snark.t * Transaction.t list) Deferred.Or_error.t
  end = struct
    type t =
      { hashing_result : Hashing_result.t
      ; bundle_result : Bundle_result.t
      ; cancellation : unit Ivar.t
      ; result : (Nonce.t * Transaction_snark.t * Transaction.t list) Deferred.Or_error.t
      }
    [@@deriving fields]

    let cancel t =
      Hashing_result.cancel t.hashing_result;
      Bundle_result.cancel t.bundle_result;
      Ivar.fill_if_empty t.cancellation ()
    ;;

    let create ~transactions ~ledger ~blockchain_state =
      let bundle_result = Bundle_result.create transactions ledger in
      let target_hash = Bundle_result.target_hash bundle_result in
      let hashing_result = Hashing_result.create blockchain_state ~target_hash in
      let cancellation = Ivar.create () in
      (* Someday: If bundle finishes first you can stuff more transactions in the bundle *)
      let result =
        let result =
          let%map hashing_result = Hashing_result.result hashing_result
          and bundle_result = Bundle_result.result bundle_result
          in
          match hashing_result, bundle_result with
          | `Ok nonce, Some (snark, ts) -> Ok (nonce, snark, ts)
          | `Cancelled, _          -> Or_error.error_string "Mining cancelled"
          | _, None                -> Or_error.error_string "Transaction bundling failed"
        in
        Deferred.any
          [ (Ivar.read cancellation >>| fun () -> Or_error.error_string "Mining cancelled")
          ; result
          ]
      in
      { bundle_result
      ; hashing_result
      ; result
      ; cancellation
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
      { mutable previous : Blockchain.t
      ; mutable id       : int
      ; transaction_pool : Transaction_pool.t
      ; mutable staged   : Transaction.t list
      ; mutable result   : Mining_result.t
      ; ledger           : Ledger.t
      }

    (*
       state transition events:

       - found block
       - someone else found block
    *)

    let transactions_per_snark = 10

    let stage_transactions state =
      let transactions =
        let rec go i ts =
          if i = 0
          then ts
          else
            match Transaction_pool.pop state.transaction_pool with
            | Some t -> go (i - 1) (t :: ts)
            | None -> ts
        in
        go transactions_per_snark []
      in
      state.staged <- transactions
  end

  let mine
        ~(prover : Prover.t)
        ~(parent_log : Logger.t)
        ~(initial : Blockchain.t)
        ~(ledger : Ledger.t)
        ~(transactions : Transaction.t Linear_pipe.Reader.t)
        (received_blocks : Block.With_transactions.t Linear_pipe.Reader.t)
    =
    let staged = [] in
    let transaction_pool = Transaction_pool.create () in
    let result =
      Mining_result.create
        ~transactions:staged
        ~ledger ~blockchain_state:initial.state
    in
    let state =
      { State.previous = initial
      ; id = 0
      ; transaction_pool
      ; staged
      ; ledger
      ; result
      }
    in
    (* TODO: Transactions have to be removed once they make it in *)
    don't_wait_for
      (Linear_pipe.iter transactions ~f:(fun tx ->
         Transaction_pool.add state.transaction_pool tx;
         Deferred.unit));
    let found_blocks_r, found_blocks_w = Linear_pipe.create () in
    let updates =
      Linear_pipe.merge_unordered
        [ Linear_pipe.map received_blocks ~f:(fun b -> `Received b)
        ; Linear_pipe.map found_blocks_r ~f:(fun b -> `Found b)
        ]
    in
    Linear_pipe.iter updates ~f:(fun u ->
      match u with
      | `Received b ->
        Blockchain_state.update_exn 
        Mining_result.cancel state.result;
        (* TODO: Transactions get one shot to make it in in case of forks... *)

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
