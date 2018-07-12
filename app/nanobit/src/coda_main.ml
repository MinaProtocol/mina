open Core
open Async
open Nanobit_base
open Blockchain_snark

module type Init_intf = sig
  type proof [@@deriving bin_io]

  val conf_dir : string

  val prover : Prover.t

  val genesis_proof : proof

  (* Public key to allocate fees to *)

  val fee_public_key : Public_key.Compressed.t
end

module Transaction_snark_statement = struct
  type t = 
    { source : Nanobit_base.Ledger_hash.Stable.V1.t
    ; target : Nanobit_base.Ledger_hash.Stable.V1.t
    ; fee_excess : Currency.Fee.Signed.Stable.V1.t
    ; proof_type : [`Merge | `Base]
    }
  [@@deriving sexp, bin_io]
end

module Make_inputs0
    (Init : Init_intf)
    (Ledger_proof : sig
       type t [@@deriving sexp, bin_io]
       val verify
         : t
         -> Transaction_snark_statement.t
         -> message:(Currency.Fee.t * Public_key.Compressed.t)
         -> bool Deferred.t
     end)
    (State_proof : Protocols.Coda_pow.Proof_intf with type input := State.t)
    (Difficulty : module type of Difficulty)
=
struct
  open Protocols.Coda_pow

  module Time : Time_intf with type t = Block_time.t = Block_time

  module Time_close_validator = struct
    let limit =
      Block_time.Span.of_time_span (Core.Time.Span.of_sec 15.)

    let validate t =
      let now = Block_time.now () in
      (* t should be at most [limit] greater than now *)
      Block_time.Span.(<) (Block_time.diff t now) limit
  end

  module Public_key = Public_key

  module State_hash = State_hash.Stable.V1

  module Strength = Strength

  module Block_nonce = Block.Nonce

  module Ledger_builder_hash = Ledger_builder_hash.Stable.V1

  module Ledger_hash = Ledger_hash.Stable.V1

  module Pow = Proof_of_work

  module Fee = struct
    module Unsigned = struct
      include Currency.Fee
      include (Currency.Fee.Stable.V1 : module type of Currency.Fee.Stable.V1 with type t := t)
    end

    module Signed = struct
      include Currency.Fee.Signed
      include (Currency.Fee.Signed.Stable.V1 :
                 module type of Currency.Fee.Signed.Stable.V1
               with type t := t
                and type ('a, 'b) t_ := ('a, 'b) t_)
    end
  end

  module State = struct
      include State
      module Proof = struct
        include State_proof
        type input = State.t
      end
    end

  module Transaction = struct
    include (Transaction : module type of Transaction with module With_valid_signature := Transaction.With_valid_signature)

    let fee (t : t) = t.payload.Transaction.Payload.fee

    let seed = Secure_random.string ()

    let compare t1 t2 = Transaction.Stable.V1.compare ~seed t1 t2

    module With_valid_signature = struct
      include Transaction.With_valid_signature
      let compare t1 t2 = Transaction.With_valid_signature.compare ~seed t1 t2
    end
  end

  module Fee_transfer = Nanobit_base.Fee_transfer

  module Super_transaction = struct
    module T = struct
      type t = Transaction_snark.Transition.t =
        | Transaction of Transaction.With_valid_signature.t
        | Fee_transfer of Fee_transfer.t
      [@@deriving compare, eq]

      let fee_excess = function
        | Transaction t -> Ok (Transaction.fee (t :> Transaction.t))
        | Fee_transfer t -> Fee_transfer.fee_excess t
    end
    include T
    include (Transaction_snark.Transition : module type of Transaction_snark.Transition with type t := t)
  end

  module Ledger : Ledger_intf
    with type valid_transaction := Transaction.With_valid_signature.t
     and type super_transaction := Super_transaction.t
     and type ledger_hash := Ledger_hash.t
  = struct
    include Ledger

    let apply_super_transaction l = function
      | Super_transaction.Transaction t -> apply_transaction l t
      | Fee_transfer t -> apply_fee_transfer l t

    let undo_super_transaction l = function
      | Super_transaction.Transaction t -> undo_transaction l (t :> Transaction.t)
      | Fee_transfer t -> undo_fee_transfer l t
  end

  module Transaction_snark = struct
    module Statement = Transaction_snark_statement

    include Ledger_proof
  end

  module Completed_work : Completed_work_intf
    with type fee := Fee.Unsigned.t
     and type proof := Transaction_snark.t
     and type statement := Transaction_snark.Statement.t
     and type public_key := Public_key.Compressed.t
  = struct
    let proofs_length = 2

    module Statement = struct
      type t = Transaction_snark.Statement.t list
      [@@deriving bin_io, sexp]
    end

    type t =
      { fee: Fee.Unsigned.t
      ; proofs: Transaction_snark.t list
      ; prover: Public_key.Compressed.t }
    [@@deriving sexp, bin_io]
  end

  module Difficulty = Difficulty

  module Ledger_proof = struct
    include Ledger_proof
    type input = Transaction_snark.Statement.t
  end

  module Ledger_builder_diff = struct
    type t =
      { prev_hash: Ledger_builder_hash.t
      ; completed_works: Completed_work.t list
      ; transactions: Transaction.With_valid_signature.t list
      ; creator: Public_key.Compressed.t }
    [@@deriving sexp, bin_io]
  end

  module Ledger_builder = Ledger_builder.Make(struct
    module Fee = Fee
    module Public_key = Public_key.Compressed
    module Transaction = Transaction
    module Fee_transfer = Fee_transfer
    module Super_transaction = Super_transaction
    module Ledger = Ledger
    module Transaction_snark = Transaction_snark
    module Ledger_hash = Ledger_hash
    module Ledger_builder_hash = Ledger_builder_hash
    module Ledger_builder_diff = Ledger_builder_diff
    module Completed_work = Completed_work
  end)

  module Ledger_builder_transition = struct
    type t = {old: Ledger_builder.t; diff: Ledger_builder_diff.t}
  end

  module Transition = struct
    type t =
      { ledger_hash: Ledger_hash.t
      ; ledger_proof: Transaction_snark.t
      ; ledger_builder_transition : Ledger_builder_transition.t
      ; timestamp: Time.t
      ; nonce: Block_nonce.t }
    [@@deriving fields]
  end

end

(*
module Make_inputs
    (Init : Init_intf)
    (Ledger_proof : Protocols.Minibit_pow.Proof_intf) (State_proof : sig
        type t = Init.proof [@@deriving bin_io]

        include Protocols.Minibit_pow.Proof_intf
                with type input = State.t
                 and type t := t
    end) (Difficulty : module type of Difficulty)
    (Store : Storage.With_checksum_intf)
    (Bundle : Bundle.S0 with type proof := Ledger_proof.t) =
struct
  module Inputs0 =
    Make_inputs0 (Init) (Ledger_proof) (State_proof) (Difficulty)
  include Inputs0

  module Net = Minibit_networking.Make (struct
    module State_with_witness = State_with_witness
    module Ledger_hash = Ledger_hash
    module Ledger = Ledger
    module State = State
  end)

  module Ledger_fetcher_io = Net.Ledger_fetcher_io
  module State_io = Net.State_io

  module Bundle = struct
    include Bundle

    let create ledger ts =
      create ledger ~conf_dir:Init.conf_dir ts Init.fee_public_key
  end

  module Transaction_pool = Transaction_pool.Make (Transaction) (Ledger)

  module Genesis = struct
    let state : State.t = State.zero

    let proof = Init.genesis_proof
  end

  module Ledger_fetcher = Ledger_fetcher.Make (struct
    include Inputs0
    module Net = Net
    module Store = Store
    module Genesis = Genesis
    module Genesis_ledger = Genesis_ledger
  end)

  module Miner = Minibit_miner.Make (struct
    include Inputs0
    module Bundle = Bundle
  end)
end

module Main_without_snark (Init : Init_intf) = struct
  module Init = struct
    type proof = () [@@deriving bin_io]

    let conf_dir = Init.conf_dir

    let prover = Init.prover

    let fee_public_key = Init.fee_public_key

    let genesis_proof = ()
  end

  module Ledger_proof = Ledger_proof.Debug
  module State_proof = State_proof.Make_debug (Init)

  module Bundle = struct
    type t = Ledger_hash.t

    let create ~conf_dir ledger ts _fee_pk =
      Ledger.merkle_root_after_transactions ledger ts

    let cancel (t: t) : unit = ()

    let target_hash t = t

    let result (t: t) =
      (* I need this local variable to convince the type checker *)
      let p : Ledger_proof.t = () in
      Deferred.Option.return p
  end

  module Inputs =
    Make_inputs (Init) (Ledger_proof) (State_proof) (Difficulty) (Storage.Disk)
      (Bundle)

  module Main =
    Minibit.Make (Inputs)
      (struct
        module Witness = struct
          type t =
            { old_state: Inputs.State.t
            ; old_proof: Inputs.State.Proof.t
            ; transition: Inputs.Transition.t }
        end

        let prove_zk_state_valid _ ~new_state:_ = return Inputs.Genesis.proof
      end)
end

module Main_with_snark
    (Storage : Storage.With_checksum_intf)
    (Init : Init_intf with type proof = Proof.t) =
struct
  module Ledger_proof = Ledger_proof.Make_prod (Init)
  module State_proof = State_proof.Make_prod (Init)

  module Bundle = struct
    include Bundle

    let result t = Deferred.Option.(result t >>| Transaction_snark.proof)
  end

  module Inputs =
    Make_inputs (Init) (Ledger_proof) (State_proof) (Difficulty) (Storage)
      (Bundle)

  module Main =
    Minibit.Make (Inputs)
      (struct
        module Witness = struct
          type t =
            { old_state: Inputs.State.t
            ; old_proof: Inputs.State.Proof.t
            ; transition: Inputs.Transition.t }
        end

        let prove_zk_state_valid
            ({old_state; old_proof; transition}: Witness.t) ~new_state:_ =
          Prover.extend_blockchain Init.prover
            {state= State.to_blockchain_state old_state; proof= old_proof}
            { header= {time= transition.timestamp; nonce= transition.nonce}
            ; body=
                { target_hash= transition.ledger_hash
                ; proof= transition.ledger_proof } }
          >>| Or_error.ok_exn >>| Blockchain.proof
      end)
end

module type Main_intf = sig
  module Inputs : sig
    module Ledger_fetcher : sig
      type t

      val best_ledger : t -> Ledger.t
    end

    module Transaction_pool : sig
      type t

      val add : t -> Transaction.With_valid_signature.t -> t
    end

    module Net : sig
      open Kademlia

      module Gossip_net : sig
        module Params : sig
          type t =
            {timeout: Time.Span.t; target_peer_count: int; address: Peer.t}
        end
      end

      module Config : sig
        type t =
          { parent_log: Logger.t
          ; gossip_net_params: Gossip_net.Params.t
          ; initial_peers: Peer.t list
          ; me: Peer.t
          ; remap_addr_port: Peer.t -> Peer.t }
      end
    end
  end

  module Main : sig
    module Config : sig
      type t =
        { log: Logger.t
        ; net_config: Inputs.Net.Config.t
        ; ledger_disk_location: string
        ; pool_disk_location: string }
    end

    type t

    val ledger_fetcher : t -> Inputs.Ledger_fetcher.t

    val modify_transaction_pool :
      t -> f:(Inputs.Transaction_pool.t -> Inputs.Transaction_pool.t) -> unit

    val create : Config.t -> t Deferred.t

    val run : t -> unit
  end
end

module Run (Program : Main_intf) = struct
  open Program

  let get_balance t (addr: Public_key.Compressed.t) =
    let ledger = Inputs.Ledger_fetcher.best_ledger (Main.ledger_fetcher t) in
    let maybe_balance =
      Option.map (Ledger.get ledger addr) ~f:(fun account ->
          account.Account.balance )
    in
    return maybe_balance

  let send_txn log t txn =
    let ledger = Inputs.Ledger_fetcher.best_ledger (Main.ledger_fetcher t) in
    match Transaction.check txn with
    | Some txn ->
        let ledger' = Ledger.copy ledger in
        let () = Ledger.apply_transaction ledger' txn |> Or_error.ok_exn in
        Main.modify_transaction_pool t ~f:(fun pool ->
            Inputs.Transaction_pool.add pool txn ) ;
        Logger.info log
          !"Added transaction %{sexp: Transaction.With_valid_signature.t} to \
            pool successfully"
          txn ;
        return (Some ())
    | None -> return None

  let get_nonce t (addr: Public_key.Compressed.t) =
    let ledger = Inputs.Ledger_fetcher.best_ledger (Main.ledger_fetcher t) in
    let maybe_nonce =
      Option.map (Ledger.get ledger addr) ~f:(fun account ->
          account.Account.nonce )
    in
    return maybe_nonce

  let setup_client_server ~minibit ~log ~client_port =
    (* Setup RPC server for client interactions *)
    let module Client_server = Client.Rpc_server (struct
      type t = Main.t

      let get_balance = get_balance

      let get_nonce = get_nonce

      let send_txn = send_txn log
    end) in
    Client_server.init_server ~parent_log:log ~minibit ~port:client_port

  let run ~minibit ~log =
    Logger.debug log "Created minibit\n%!" ;
    Main.run minibit ;
    Logger.debug log "Ran minibit\n%!"
   end *)
