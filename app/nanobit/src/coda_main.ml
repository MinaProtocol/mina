open Core
open Async
open Nanobit_base
open Signature_lib
open Blockchain_snark
open Coda_numbers
module Fee = Protocols.Coda_pow.Fee

module Ledger_builder_aux_hash = struct
  include Ledger_builder_hash.Aux_hash.Stable.V1

  let of_bytes = Ledger_builder_hash.Aux_hash.of_bytes
end

module Ledger_builder_hash = struct
  include Ledger_builder_hash.Stable.V1

  let ledger_hash = Ledger_builder_hash.ledger_hash

  let of_aux_and_ledger_hash = Ledger_builder_hash.of_aux_and_ledger_hash
end

module Ledger_hash = struct
  include Ledger_hash.Stable.V1

  let to_bytes = Ledger_hash.to_bytes
end

module type Ledger_proof_intf =
  Protocols.Coda_pow.Ledger_proof_intf
  with type sok_digest := Sok_message.Digest.t
   and type ledger_hash := Ledger_hash.t
   and type proof := Proof.t
   and type statement = Transaction_snark.Statement.t

module type Ledger_proof_verifier_intf = sig
  type ledger_proof

  val verify :
       ledger_proof
    -> Transaction_snark.Statement.t
    -> message:Sok_message.t
    -> bool Deferred.t
end

module Transaction = struct
  include (
    Transaction :
      module type of Transaction
      with module With_valid_signature := Transaction.With_valid_signature )

  let fee (t: t) = t.payload.Transaction.Payload.fee

  let receiver (t: t) = t.payload.receiver

  let sender (t: t) = Public_key.compress t.sender

  let seed = Secure_random.string ()

  let compare t1 t2 = Transaction.Stable.V1.compare ~seed t1 t2

  module With_valid_signature = struct
    module T = struct
      include Transaction.With_valid_signature

      let compare t1 t2 = Transaction.With_valid_signature.compare ~seed t1 t2
    end

    include T
    include Comparable.Make (T)
  end
end

module Ledger_proof_statement = Transaction_snark.Statement

module type Kernel_intf = sig
  module Ledger_proof : Ledger_proof_intf

  module Completed_work :
    Protocols.Coda_pow.Completed_work_intf
    with type public_key := Public_key.Compressed.t
     and type statement := Transaction_snark.Statement.t
     and type proof := Ledger_proof.t

  module Ledger_builder_diff :
    Protocols.Coda_pow.Ledger_builder_diff_intf
    with type completed_work_checked := Completed_work.Checked.t
     and type completed_work := Completed_work.t
     and type public_key := Public_key.Compressed.t
     and type ledger_builder_hash := Ledger_builder_hash.t
     and type transaction := Transaction.t
     and type transaction_with_valid_signature :=
                Transaction.With_valid_signature.t

  module Consensus_mechanism :
    Consensus.Mechanism.S
    with type Internal_transition.Ledger_builder_diff.t = Ledger_builder_diff.t
     and type External_transition.Ledger_builder_diff.t = Ledger_builder_diff.t

  module Blockchain :
    Blockchain.S with module Consensus_mechanism = Consensus_mechanism

  module Prover :
    Prover.S
    with module Consensus_mechanism = Consensus_mechanism
     and module Blockchain = Blockchain

  module Verifier : Verifier.S with type blockchain := Blockchain.t
end

module Make_kernel
    (Ledger_proof : Ledger_proof_intf)
      (Make_consensus_mechanism : functor (Ledger_builder_diff :sig
                                                                  
                                                                  type t
                                                                  [@@deriving
                                                                    sexp
                                                                    , bin_io]
      end) -> Consensus.Mechanism.S
              with type Internal_transition.Ledger_builder_diff.t =
                          Ledger_builder_diff.t
               and type External_transition.Ledger_builder_diff.t =
                          Ledger_builder_diff.t) :
  Kernel_intf with type Ledger_proof.t = Ledger_proof.t =
struct
  module Ledger_proof = Ledger_proof
  module Completed_work =
    Ledger_builder.Make_completed_work (Public_key.Compressed) (Ledger_proof)
      (Ledger_proof_statement)

  module Ledger_builder_diff = Ledger_builder.Make_diff (struct
    module Ledger_proof = Ledger_proof
    module Ledger_hash = Ledger_hash
    module Ledger_builder_hash = Ledger_builder_hash
    module Ledger_builder_aux_hash = Ledger_builder_aux_hash
    module Compressed_public_key = Public_key.Compressed
    module Transaction = Transaction
    module Completed_work = Completed_work
  end)

  module Consensus_mechanism = Make_consensus_mechanism (Ledger_builder_diff)
  module Blockchain = Blockchain.Make (Consensus_mechanism)
  module Prover = Prover.Make (Consensus_mechanism) (Blockchain)
  module Verifier = Verifier.Make (Consensus_mechanism) (Blockchain)
end

module type Config_intf = sig
  val logger : Logger.t

  val conf_dir : string

  val lbc_tree_max_depth : [`Infinity | `Finite of int]

  val transition_interval : Time.Span.t

  (* Public key to allocate fees to *)

  val fee_public_key : Public_key.Compressed.t

  val genesis_proof : Snark_params.Tock.Proof.t
end

module type Init_intf = sig
  include Config_intf

  include Kernel_intf

  val prover : Prover.t

  val verifier : Verifier.t

  val genesis_proof : Proof.t
end

let make_init (type ledger_proof) (module Config : Config_intf) (module Kernel
    : Kernel_intf with type Ledger_proof.t = ledger_proof) :
    (module Init_intf with type Ledger_proof.t = ledger_proof) Deferred.t =
  let open Config in
  let open Kernel in
  let%bind prover = Prover.create ~conf_dir in
  let%map verifier = Verifier.create ~conf_dir in
  let module Init = struct
    include Kernel
    include Config

    let prover = prover

    let verifier = verifier
  end in
  (module Init : Init_intf with type Ledger_proof.t = ledger_proof)

module type State_proof_intf = sig
  module Consensus_mechanism : Consensus.Mechanism.S

  type t [@@deriving bin_io, sexp]

  include Protocols.Coda_pow.Proof_intf
          with type input := Consensus_mechanism.Protocol_state.value
           and type t := t
end

module Make_inputs0
    (Init : Init_intf)
    (Ledger_proof_verifier : Ledger_proof_verifier_intf
                             with type ledger_proof := Init.Ledger_proof.t) =
struct
  open Protocols.Coda_pow
  open Init
  module Consensus_mechanism = Consensus_mechanism
  module Protocol_state = Consensus_mechanism.Protocol_state
  module Protocol_state_hash = State_hash.Stable.V1

  module Time : Time_intf with type t = Block_time.t = Block_time

  module Time_close_validator = struct
    let limit = Block_time.Span.of_time_span (Core.Time.Span.of_sec 15.)

    let validate t =
      let now = Block_time.now () in
      (* t should be at most [limit] greater than now *)
      Block_time.Span.( < ) (Block_time.diff t now) limit
  end

  module Sok_message = Sok_message

  module Amount = struct
    module Signed = struct
      include Currency.Amount.Signed

      include (
        Currency.Amount.Signed.Stable.V1 :
          module type of Currency.Amount.Signed.Stable.V1
          with type t := t
           and type ('a, 'b) t_ := ('a, 'b) t_ )
    end
  end

  module Protocol_state_proof = struct
    include Proof.Stable.V1

    type input = Protocol_state.value

    let verify state_proof state =
      match%map
        Init.Verifier.verify_blockchain Init.verifier
          {proof= state_proof; state}
      with
      | Ok b -> b
      | Error e ->
          Logger.error Init.logger
            !"Could not connect to verifier: %{sexp:Error.t}"
            e ;
          false
  end

  module Fee_transfer = Nanobit_base.Fee_transfer
  module Coinbase = Nanobit_base.Coinbase

  module Super_transaction = struct
    module T = struct
      type t = Transaction_snark.Transition.t =
        | Transaction of Transaction.With_valid_signature.t
        | Fee_transfer of Fee_transfer.t
        | Coinbase of Coinbase.t
      [@@deriving compare, eq]
    end

    let fee_excess = Super_transaction.fee_excess

    let supply_increase = Super_transaction.supply_increase

    include T

    include (
      Transaction_snark.Transition :
        module type of Transaction_snark.Transition with type t := t )
  end

  module Ledger = Ledger

  module Transaction_snark = struct
    module Statement = Transaction_snark.Statement
    include Ledger_proof
    include Ledger_proof_verifier
  end

  module Proof = Nanobit_base.Proof.Stable.V1
  module Ledger_proof = Ledger_proof
  module Sparse_ledger = Nanobit_base.Sparse_ledger

  module Completed_work_proof = struct
    type t = Ledger_proof.t list [@@deriving sexp, bin_io]
  end

  module Ledger_builder = struct
    module Inputs = struct
      module Sok_message = Sok_message
      module Proof = Proof
      module Sparse_ledger = Sparse_ledger
      module Amount = Amount
      module Completed_work = Completed_work
      module Compressed_public_key = Public_key.Compressed
      module Transaction = Transaction
      module Fee_transfer = Fee_transfer
      module Coinbase = Coinbase
      module Super_transaction = Super_transaction
      module Ledger = Ledger
      module Ledger_proof = Ledger_proof
      module Ledger_proof_verifier = Ledger_proof_verifier
      module Ledger_proof_statement = Ledger_proof_statement
      module Ledger_hash = Ledger_hash
      module Ledger_builder_diff = Ledger_builder_diff
      module Ledger_builder_hash = Ledger_builder_hash
      module Ledger_builder_aux_hash = Ledger_builder_aux_hash
      module Config = Protocol_constants

      let check (Completed_work.({fee; prover; proofs}) as t) stmts =
        let message = Sok_message.create ~fee ~prover in
        match List.zip proofs stmts with
        | None -> return None
        | Some ps ->
            let%map good =
              Deferred.List.for_all ps ~f:(fun (proof, stmt) ->
                  Transaction_snark.verify ~message proof stmt )
            in
            Option.some_if good (Completed_work.Checked.create_unsafe t)
    end

    include Ledger_builder.Make (Inputs)
  end

  module Ledger_builder_aux = Ledger_builder.Aux

  module Ledger_builder_transition = struct
    type t = {old: Ledger_builder.t; diff: Ledger_builder_diff.t}
    [@@deriving sexp, bin_io]

    module With_valid_signatures_and_proofs = struct
      type t =
        { old: Ledger_builder.t
        ; diff: Ledger_builder_diff.With_valid_signatures_and_proofs.t }
      [@@deriving sexp]
    end

    let forget {With_valid_signatures_and_proofs.old; diff} =
      {old; diff= Ledger_builder_diff.forget diff}
  end

  module External_transition = Consensus_mechanism.External_transition
  module Internal_transition = Consensus_mechanism.Internal_transition

  module Transaction_pool = struct
    module Pool = Transaction_pool.Make (Transaction)
    include Network_pool.Make (Pool) (Pool.Diff)

    type pool_diff = Pool.Diff.t [@@deriving bin_io]

    (* TODO *)
    let load ~disk_location:_ ~incoming_diffs = return (create ~incoming_diffs)

    let transactions t = Pool.transactions (pool t)

    (* TODO: This causes the signature to get checked twice as it is checked
   below before feeding it to add *)
    let add t txn = apply_and_broadcast t [txn]
  end

  module Transaction_pool_diff = Transaction_pool.Pool.Diff

  module Tip = struct
    type t =
      { protocol_state: Protocol_state.value
      ; proof: Protocol_state_proof.t
      ; ledger_builder: Ledger_builder.t }
    [@@deriving sexp]

    let of_transition_and_lb transition ledger_builder =
      { protocol_state=
          Consensus_mechanism.External_transition.protocol_state transition
      ; proof=
          Consensus_mechanism.External_transition.protocol_state_proof
            transition
      ; ledger_builder }
  end

  let fee_public_key = Init.fee_public_key
end

module Make_inputs
    (Init : Init_intf)
    (Ledger_proof_verifier : Ledger_proof_verifier_intf
                             with type ledger_proof := Init.Ledger_proof.t)
    (Store : Storage.With_checksum_intf)
    () =
struct
  open Init
  module Inputs0 = Make_inputs0 (Init) (Ledger_proof_verifier)
  include Inputs0
  module Blockchain_state = Nanobit_base.Blockchain_state
  module Ledger_builder_diff = Ledger_builder_diff
  module Completed_work = Completed_work
  module Ledger_builder_hash = Ledger_builder_hash
  module Ledger_builder_aux_hash = Ledger_builder_aux_hash
  module Ledger_proof_verifier = Ledger_proof_verifier
  module Ledger_hash = Ledger_hash
  module Transaction = Transaction
  module Public_key = Public_key
  module Compressed_public_key = Public_key.Compressed
  module Private_key = Private_key

  module Proof_carrying_state = struct
    type t =
      ( Protocol_state.value
      , Protocol_state_proof.t )
      Protocols.Coda_pow.Proof_carrying_data.t
    [@@deriving sexp, bin_io]
  end

  module State_with_witness = struct
    type t =
      { ledger_builder_transition:
          Ledger_builder_transition.With_valid_signatures_and_proofs.t
      ; state: Proof_carrying_state.t }
    [@@deriving sexp]

    module Stripped = struct
      type t =
        { ledger_builder_transition: Ledger_builder_transition.t
        ; state: Proof_carrying_state.t }
      [@@deriving bin_io]
    end

    let strip {ledger_builder_transition; state} =
      { Stripped.ledger_builder_transition=
          Ledger_builder_transition.forget ledger_builder_transition
      ; state }

    let forget_witness {ledger_builder_transition; state} = state

    (* TODO: How do we check this *)
    let add_witness ledger_builder_transition state =
      Or_error.return {ledger_builder_transition; state}

    let add_witness_exn l s = add_witness l s |> Or_error.ok_exn
  end

  module Genesis = struct
    let state = Consensus_mechanism.genesis_protocol_state

    let ledger = Genesis_ledger.ledger

    let proof = Init.genesis_proof
  end

  module Snark_pool = struct
    module Work = Completed_work.Statement
    module Proof = Completed_work_proof

    module Fee = struct
      module T = struct
        type t = {fee: Fee.Unsigned.t; prover: Public_key.Compressed.t}
        [@@deriving bin_io, sexp]

        (* TODO: Compare in a better way than with public key, like in transaction pool *)
        let compare t1 t2 =
          let r = compare t1.fee t2.fee in
          if Int.( <> ) r 0 then r
          else Public_key.Compressed.compare t1.prover t2.prover
      end

      include T
      include Comparable.Make (T)

      let gen =
        (* This isn't really a valid public key, but good enough for testing *)
        let pk =
          let open Snark_params.Tick in
          let open Quickcheck.Generator.Let_syntax in
          let%map x = Bignum_bigint.(gen_incl zero (Field.size - one))
          and is_odd = Bool.gen in
          let x = Bigint.(to_field (of_bignum_bigint x)) in
          {Public_key.Compressed.x; is_odd}
        in
        Quickcheck.Generator.map2 Fee.Unsigned.gen pk ~f:(fun fee prover ->
            {fee; prover} )
    end

    module Pool = Snark_pool.Make (Proof) (Fee) (Work)
    module Diff = Network_pool.Snark_pool_diff.Make (Proof) (Fee) (Work) (Pool)

    type pool_diff = Diff.t

    include Network_pool.Make (Pool) (Diff)

    let get_completed_work t statement =
      Option.map
        (Pool.request_proof (pool t) statement)
        ~f:(fun {proof; fee= {fee; prover}} ->
          Completed_work.Checked.create_unsafe
            {Completed_work.fee; proofs= proof; prover} )

    let load ~disk_location ~incoming_diffs =
      match%map Reader.load_bin_prot disk_location Pool.bin_reader_t with
      | Ok pool -> of_pool_and_diffs pool ~incoming_diffs
      | Error _e -> create ~incoming_diffs

    open Snark_work_lib.Work

    let add_completed_work t
        (res: (('a, 'b, 'c, 'd) Single.Spec.t Spec.t, Ledger_proof.t) Result.t) =
      apply_and_broadcast t
        (Add_solved_work
           ( List.map res.spec.instances ~f:Single.Spec.statement
           , {proof= res.proofs; fee= {fee= res.spec.fee; prover= res.prover}}
           ))
  end

  module type S_tmp =
    Coda.Network_intf
    with type state_with_witness := State_with_witness.t
     and type ledger_builder := Ledger_builder.t
     and type protocol_state := Protocol_state.value
     and type ledger_builder_hash := Ledger_builder_hash.t

  module Sync_ledger =
    Syncable_ledger.Make (Ledger.Addr) (Account)
      (struct
        include Merkle_hash

        let hash_account = Fn.compose Merkle_hash.of_digest Account.digest

        let empty = Merkle_hash.empty_hash
      end)
      (struct
        include Ledger_hash

        let to_hash (h: t) =
          Merkle_hash.of_digest (h :> Snark_params.Tick.Pedersen.Digest.t)
      end)
      (struct
        include Ledger

        type path = Path.t

        let f = Account.hash
      end)
      (struct
        let subtree_height = 3
      end)

  module Net = Minibit_networking.Make (struct
    include Inputs0
    module Snark_pool = Snark_pool
    module Snark_pool_diff = Snark_pool.Diff
    module Sync_ledger = Sync_ledger
    module Ledger_builder_hash = Ledger_builder_hash
    module Ledger_hash = Ledger_hash
    module Ledger_builder_aux_hash = Ledger_builder_aux_hash
  end)

  module Ledger_builder_controller = struct
    module Inputs = struct
      module Security = struct
        let max_depth = Init.lbc_tree_max_depth
      end

      module Tip = Tip
      module Store = Store
      module Snark_pool = Snark_pool

      module Net = struct
        type net = Net.t

        include Net.Ledger_builder_io
      end

      module Ledger_hash = Ledger_hash
      module Ledger_builder_hash = Ledger_builder_hash
      module Ledger = Ledger
      module Ledger_builder_diff = Ledger_builder_diff
      module Ledger_builder_aux_hash = Ledger_builder_aux_hash

      module Ledger_builder = struct
        include Ledger_builder

        type proof = Ledger_proof.t

        let create ledger = create ~ledger ~self:Init.fee_public_key

        let apply t diff =
          Deferred.Or_error.map
            (Ledger_builder.apply t diff)
            ~f:
              (Option.map ~f:(fun proof ->
                   ((Ledger_proof.statement proof).target, proof) ))

        let of_aux_and_ledger =
          of_aux_and_ledger ~public_key:Init.fee_public_key
      end

      module Consensus_mechanism = Consensus_mechanism
      module Protocol_state = Protocol_state
      module Blockchain_state = Nanobit_base.Blockchain_state
      module Protocol_state_proof = Protocol_state_proof
      module State_hash = State_hash
      module Valid_transaction = Transaction.With_valid_signature
      module Sync_ledger = Sync_ledger
      module External_transition = External_transition
      module Internal_transition = Internal_transition

      let verify_blockchain proof state =
        Init.Verifier.verify_blockchain Init.verifier {proof; state}
    end

    include Ledger_builder_controller.Make (Inputs)
  end

  module Transition_tree = Ledger_builder_controller.Transition_tree

  module Proposer = Proposer.Make (struct
    include Inputs0
    module Ledger_builder_diff = Ledger_builder_diff
    module Ledger_proof_verifier = Ledger_proof_verifier
    module Completed_work = Completed_work
    module Ledger_builder_hash = Ledger_builder_hash
    module Ledger_builder_aux_hash = Ledger_builder_aux_hash
    module Ledger_proof_statement = Ledger_proof_statement
    module Ledger_hash = Ledger_hash
    module Transaction = Transaction
    module Public_key = Public_key
    module Private_key = Private_key
    module Blockchain_state = Nanobit_base.Blockchain_state
    module Compressed_public_key = Public_key.Compressed

    module Prover = struct
      let prove ~prev_state ~prev_state_proof ~next_state
          (transition: Init.Consensus_mechanism.Internal_transition.t) =
        let open Deferred.Or_error.Let_syntax in
        Init.Prover.extend_blockchain Init.prover
          (Init.Blockchain.create ~proof:prev_state_proof ~state:prev_state)
          next_state
          (Init.Consensus_mechanism.Internal_transition.snark_transition
             transition)
        >>| fun {Init.Blockchain.proof; _} -> proof
    end

    module Proposal_interval = struct
      let t = Time.Span.of_time_span Init.transition_interval
    end
  end)

  let request_work ~best_ledger_builder
      ~(seen_jobs:
         'a -> Ledger_proof_statement.Set.t * Ledger_proof_statement.t option)
      ~(set_seen_jobs:
            'a
         -> Ledger_proof_statement.Set.t * Ledger_proof_statement.t option
         -> unit) (t: 'a) =
    let lb = best_ledger_builder t in
    let maybe_instances, seen_jobs =
      Ledger_builder.random_work_spec_chunk lb (seen_jobs t)
    in
    set_seen_jobs t seen_jobs ;
    Option.map maybe_instances ~f:(fun instances ->
        {Snark_work_lib.Work.Spec.instances; fee= Fee.Unsigned.zero} )
end

module Coda_with_snark
    (Store : Storage.With_checksum_intf)
    (Init : Init_intf with type Ledger_proof.t = Transaction_snark.t)
    () =
struct
  module Ledger_proof_verifier = struct
    let verify t stmt ~message =
      if
        not
          (Int.( = )
             (Transaction_snark.Statement.compare
                (Init.Ledger_proof.statement t)
                stmt)
             0)
      then Deferred.return false
      else
        match%map
          Init.Verifier.verify_transaction_snark Init.verifier t ~message
        with
        | Ok b -> b
        | Error e ->
            Logger.warn Init.logger
              !"Bad transaction snark: %{sexp: Error.t}"
              e ;
            false
  end

  module Inputs = struct
    include Make_inputs (Init) (Ledger_proof_verifier) (Store) ()

    module Ledger_proof_statement = Ledger_proof_statement
    module Snark_worker = Snark_worker_lib.Prod.Worker
  end

  module Consensus_mechanism = Init.Consensus_mechanism
  module Blockchain = Init.Blockchain
  module Prover = Init.Prover
  include Coda.Make (Inputs)

  let snark_worker_command_name = Snark_worker_lib.Prod.command_name

  let request_work =
    Inputs.request_work ~best_ledger_builder ~seen_jobs ~set_seen_jobs
end

module Coda_without_snark
    (Init : Init_intf with module Ledger_proof = Ledger_proof.Debug)
    () =
struct
  module Store = Storage.Memory

  module Ledger_proof_verifier = struct
    let verify _ _ ~message:_ = return true
  end

  module Inputs = struct
    include Make_inputs (Init) (Ledger_proof_verifier) (Store) ()

    module Ledger_proof_statement = Ledger_proof_statement
    module Snark_worker = Snark_worker_lib.Debug.Worker
  end

  module Consensus_mechanism = Init.Consensus_mechanism
  module Blockchain = Init.Blockchain
  module Prover = Init.Prover
  include Coda.Make (Inputs)

  let request_work =
    Inputs.request_work ~best_ledger_builder ~seen_jobs ~set_seen_jobs

  let snark_worker_command_name = Snark_worker_lib.Debug.command_name
end

module type Main_intf = sig
  module Inputs : sig
    module Time : Protocols.Coda_pow.Time_intf

    module Ledger : sig
      type t [@@deriving sexp]

      val copy : t -> t

      val location_of_key :
        t -> Public_key.Compressed.t -> Ledger.Location.t option

      val get : t -> Ledger.Location.t -> Account.t option

      val num_accounts : t -> int
    end

    module Ledger_builder_diff : sig
      type t [@@deriving sexp, bin_io]
    end

    module Consensus_mechanism :
      Consensus.Mechanism.S
      with type Internal_transition.Ledger_builder_diff.t =
                  Ledger_builder_diff.t
       and type External_transition.Ledger_builder_diff.t =
                  Ledger_builder_diff.t

    module Net : sig
      type t

      module Peer : sig
        type t = Host_and_port.Stable.V1.t * int
        [@@deriving bin_io, sexp, compare, hash]

        val external_rpc : t -> Host_and_port.Stable.V1.t
      end

      module Gossip_net : sig
        module Config : Gossip_net.Config_intf
      end

      module Config :
        Minibit_networking.Config_intf
        with type gossip_config := Gossip_net.Config.t
    end

    module Sparse_ledger : sig
      type t
    end

    module Ledger_proof : sig
      type t

      type statement
    end

    module Super_transaction : sig
      type t
    end

    module Snark_worker :
      Snark_worker_lib.Intf.S
      with type proof := Ledger_proof.t
       and type statement := Ledger_proof.statement
       and type transition := Super_transaction.t
       and type sparse_ledger := Sparse_ledger.t

    module Snark_pool : sig
      type t

      val add_completed_work :
        t -> Snark_worker.Work.Result.t -> unit Deferred.t
    end

    module Transaction_pool : sig
      type t

      val add : t -> Transaction.t -> unit Deferred.t
    end

    module Transition_tree :
      Coda.Ktree_intf
      with type elem := Consensus_mechanism.External_transition.t
  end

  module Consensus_mechanism : Consensus.Mechanism.S

  module Blockchain :
    Blockchain.S with module Consensus_mechanism = Consensus_mechanism

  module Prover :
    Prover.S
    with module Consensus_mechanism = Consensus_mechanism
     and module Blockchain = Blockchain

  module Config : sig
    type t =
      { log: Logger.t
      ; should_propose: bool
      ; run_snark_worker: bool
      ; net_config: Inputs.Net.Config.t
      ; ledger_builder_persistant_location: string
      ; transaction_pool_disk_location: string
      ; snark_pool_disk_location: string
      ; ledger_builder_transition_backup_capacity: int [@default 10]
      ; time_controller: Inputs.Time.Controller.t }
    [@@deriving make]
  end

  type t

  val should_propose : t -> bool

  val run_snark_worker : t -> bool

  val request_work : t -> Inputs.Snark_worker.Work.Spec.t option

  val best_ledger : t -> Inputs.Ledger.t

  val best_protocol_state :
    t -> Inputs.Consensus_mechanism.Protocol_state.value

  val peers : t -> Kademlia.Peer.t list

  val strongest_ledgers :
    t -> Inputs.Consensus_mechanism.External_transition.t Linear_pipe.Reader.t

  val transaction_pool : t -> Inputs.Transaction_pool.t

  val snark_pool : t -> Inputs.Snark_pool.t

  val create : Config.t -> t Deferred.t

  val lbc_transition_tree : t -> Inputs.Transition_tree.t option

  val snark_worker_command_name : string

  val ledger_builder_ledger_proof : t -> Inputs.Ledger_proof.t option
end

module Run (Config_in : Config_intf) (Program : Main_intf) = struct
  include Program
  open Inputs

  module For_tests = struct
    let get_transition_tree t = lbc_transition_tree t

    let ledger_proof t = ledger_builder_ledger_proof t
  end

  let get_balance t (addr: Public_key.Compressed.t) =
    let open Option.Let_syntax in
    let ledger = best_ledger t in
    let%bind location = Ledger.location_of_key ledger addr in
    let%map account = Ledger.get ledger location in
    account.Account.balance

  let is_valid_transaction t (txn: Transaction.t) =
    let remainder =
      let open Option.Let_syntax in
      let%bind balance = get_balance t (Public_key.compress txn.sender)
      and cost = Currency.Amount.add_fee txn.payload.amount txn.payload.fee in
      Currency.Balance.sub_amount balance cost
    in
    Option.is_some remainder

  (** For status *)
  let txn_count = ref 0

  let send_txn log t txn =
    let open Deferred.Let_syntax in
    assert (is_valid_transaction t txn) ;
    let txn_pool = transaction_pool t in
    don't_wait_for (Transaction_pool.add txn_pool txn) ;
    Logger.info log
      !"Added transaction %{sexp: Transaction.t} to pool successfully"
      txn ;
    txn_count := !txn_count + 1 ;
    Deferred.unit

  let get_nonce t (addr: Public_key.Compressed.t) =
    let open Option.Let_syntax in
    let ledger = best_ledger t in
    let%bind location = Ledger.location_of_key ledger addr in
    let%map account = Ledger.get ledger location in
    account.Account.nonce

  let start_time = Time_ns.now ()

  let get_status t =
    let ledger = best_ledger t in
    let num_accounts = Ledger.num_accounts ledger in
    let state = best_protocol_state t in
    let block_count =
      state |> Consensus_mechanism.Protocol_state.consensus_state
      |> Consensus_mechanism.Consensus_state.length
    in
    let uptime_secs =
      Time_ns.diff (Time_ns.now ()) start_time
      |> Time_ns.Span.to_sec |> Int.of_float
    in
    { Client_lib.Status.num_accounts
    ; block_count= Int.of_string (Length.to_string block_count)
    ; uptime_secs
    ; conf_dir= Config_in.conf_dir
    ; peers= List.map (peers t) ~f:(fun (p, _) -> Host_and_port.to_string p)
    ; transactions_sent= !txn_count
    ; run_snark_worker= run_snark_worker t
    ; propose= should_propose t }

  let setup_local_server ?rest_server_port ~minibit ~log ~client_port () =
    let log = Logger.child log "client" in
    (* Setup RPC server for client interactions *)
    let client_impls =
      [ Rpc.Rpc.implement Client_lib.Send_transaction.rpc (fun () ->
            send_txn log minibit )
      ; Rpc.Rpc.implement Client_lib.Get_balance.rpc (fun () pk ->
            return (get_balance minibit pk) )
      ; Rpc.Rpc.implement Client_lib.Get_nonce.rpc (fun () pk ->
            return (get_nonce minibit pk) )
      ; Rpc.Rpc.implement Client_lib.Get_status.rpc (fun () () ->
            return (get_status minibit) ) ]
    in
    let snark_worker_impls =
      let solved_work_reader, solved_work_writer = Linear_pipe.create () in
      Linear_pipe.write_without_pushback solved_work_writer () ;
      [ Rpc.Rpc.implement Snark_worker.Rpcs.Get_work.rpc (fun () () ->
            match%map Linear_pipe.read solved_work_reader with
            | `Ok () ->
                let r = request_work minibit in
                ( match r with
                | None ->
                    Linear_pipe.write_without_pushback solved_work_writer ()
                | Some _ -> () ) ;
                r
            | `Eof -> assert false )
      ; Rpc.Rpc.implement Snark_worker.Rpcs.Submit_work.rpc (fun () work ->
            let%map () =
              Snark_pool.add_completed_work (snark_pool minibit) work
            in
            Linear_pipe.write_without_pushback solved_work_writer () ) ]
    in
    Option.iter rest_server_port ~f:(fun rest_server_port ->
        ignore
          Cohttp_async.(
            Server.create
              ~on_handler_error:
                (`Call
                  (fun net exn ->
                    Logger.error log "%s" (Exn.to_string_mach exn) ))
              (Tcp.Where_to_listen.bind_to Localhost (On_port rest_server_port))
              (fun ~body _sock req ->
                let uri = Cohttp.Request.uri req in
                match Uri.path uri with
                | "/status" ->
                    Server.respond_string
                      ( get_status minibit |> Client_lib.Status.to_yojson
                      |> Yojson.Safe.pretty_to_string )
                | _ ->
                    Server.respond_string ~status:`Not_found "Route not found"
                )) ) ;
    let where_to_listen =
      Tcp.Where_to_listen.bind_to Localhost (On_port client_port)
    in
    ignore
      (Tcp.Server.create
         ~on_handler_error:
           (`Call
             (fun net exn -> Logger.error log "%s" (Exn.to_string_mach exn)))
         where_to_listen
         (fun address reader writer ->
           Rpc.Connection.server_with_close reader writer
             ~implementations:
               (Rpc.Implementations.create_exn
                  ~implementations:(client_impls @ snark_worker_impls)
                  ~on_unknown_rpc:`Raise)
             ~connection_state:(fun _ -> ())
             ~on_handshake_error:
               (`Call
                 (fun exn ->
                   Logger.error log "%s" (Exn.to_string_mach exn) ;
                   Deferred.unit )) ))

  let create_snark_worker ~log ~public_key ~client_port ~shutdown_on_disconnect =
    let open Snark_worker_lib in
    let%map p =
      let our_binary = Sys.executable_name in
      Process.create_exn () ~prog:our_binary
        ~args:
          ( "internal" :: Program.snark_worker_command_name
          :: Snark_worker.arguments ~public_key ~daemon_port:client_port
               ~shutdown_on_disconnect )
    in
    let log = Logger.child log "snark_worker" in
    Pipe.iter_without_pushback
      (Reader.pipe (Process.stdout p))
      ~f:(fun s -> Logger.info log "%s" s)
    |> don't_wait_for ;
    Pipe.iter_without_pushback
      (Reader.pipe (Process.stderr p))
      ~f:(fun s -> Logger.error log "%s" s)
    |> don't_wait_for ;
    Deferred.unit

  let run_snark_worker ?shutdown_on_disconnect:(s = true) ~log ~client_port
      run_snark_worker =
    match run_snark_worker with
    | `Don't_run -> ()
    | `With_public_key public_key ->
        create_snark_worker ~shutdown_on_disconnect:s ~log ~public_key
          ~client_port
        |> ignore
end
