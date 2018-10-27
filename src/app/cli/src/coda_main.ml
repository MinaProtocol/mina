[%%import
"../../../config.mlh"]

open Core
open Async
open Coda_base
open Signature_lib
open Blockchain_snark
open Coda_numbers
module Fee = Protocols.Coda_pow.Fee

[%%if
with_snark]

module Ledger_proof = Ledger_proof.Prod

[%%else]

module Ledger_proof = struct
  module Statement = Transaction_snark.Statement
  include Ledger_proof.Debug
end

[%%endif]

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

module Frozen_ledger_hash = struct
  include Frozen_ledger_hash.Stable.V1

  let to_bytes = Frozen_ledger_hash.to_bytes

  let of_ledger_hash = Frozen_ledger_hash.of_ledger_hash
end

module type Ledger_proof_verifier_intf = sig
  val verify :
       Ledger_proof.t
    -> Transaction_snark.Statement.t
    -> message:Sok_message.t
    -> bool Deferred.t
end

module Transaction = struct
  include (
    Transaction :
      module type of Transaction
      with module With_valid_signature := Transaction.With_valid_signature )

  let fee (t : t) = t.payload.Transaction.Payload.fee

  let receiver (t : t) = t.payload.receiver

  let sender (t : t) = Public_key.compress t.sender

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
    (Make_consensus_mechanism : functor
      (Ledger_builder_diff :sig
                            
                            type t [@@deriving sexp, bin_io]
                          end)
      -> Consensus.Mechanism.S
         with type Internal_transition.Ledger_builder_diff.t =
                     Ledger_builder_diff.t
          and type External_transition.Ledger_builder_diff.t =
                     Ledger_builder_diff.t) : Kernel_intf = struct
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

  val keypair : Keypair.t

  val genesis_proof : Snark_params.Tock.Proof.t

  val transaction_capacity_log_2 : int
  (** Capacity of transactions per block *)

  val commit_id : Client_lib.Git_sha.t option

  val work_selection : Protocols.Coda_pow.Work_selection.t
end

module type Make_work_selector_intf = sig
  module Make (Inputs : Work_selector.Inputs.Inputs_intf) :
    Protocols.Coda_pow.Work_selector_intf
    with type ledger_builder := Inputs.Ledger_builder.t
     and type work :=
                ( Inputs.Ledger_proof_statement.t
                , Inputs.Super_transaction.t
                , Inputs.Sparse_ledger.t
                , Inputs.Ledger_proof.t )
                Snark_work_lib.Work.Single.Spec.t
end

module type Init_intf = sig
  include Config_intf

  include Kernel_intf

  module Make_work_selector (Inputs : Work_selector.Inputs.Inputs_intf) :
    Protocols.Coda_pow.Work_selector_intf
    with type ledger_builder := Inputs.Ledger_builder.t
     and type work :=
                ( Inputs.Ledger_proof_statement.t
                , Inputs.Super_transaction.t
                , Inputs.Sparse_ledger.t
                , Inputs.Ledger_proof.t )
                Snark_work_lib.Work.Single.Spec.t

  val proposer_prover : [`Proposer of Prover.t | `Non_proposer]

  val verifier : Verifier.t

  val genesis_proof : Proof.t
end

let make_init ~should_propose (module Config : Config_intf)
    (module Kernel : Kernel_intf) : (module Init_intf) Deferred.t =
  let open Config in
  let open Kernel in
  let%bind proposer_prover =
    if should_propose then Prover.create ~conf_dir >>| fun p -> `Proposer p
    else return `Non_proposer
  in
  let%map verifier = Verifier.create ~conf_dir in
  let (module Selector : Make_work_selector_intf) =
    match work_selection with
    | Seq ->
        ( module struct
          module Make (Inputs : Work_selector.Inputs.Inputs_intf) :
            Protocols.Coda_pow.Work_selector_intf
            with type ledger_builder := Inputs.Ledger_builder.t
             and type work :=
                        ( Inputs.Ledger_proof_statement.t
                        , Inputs.Super_transaction.t
                        , Inputs.Sparse_ledger.t
                        , Inputs.Ledger_proof.t )
                        Snark_work_lib.Work.Single.Spec.t =
            Work_selector.Sequence.Make (Inputs)
        end )
    | Random ->
        ( module struct
          module Make (Inputs : Work_selector.Inputs.Inputs_intf) :
            Protocols.Coda_pow.Work_selector_intf
            with type ledger_builder := Inputs.Ledger_builder.t
             and type work :=
                        ( Inputs.Ledger_proof_statement.t
                        , Inputs.Super_transaction.t
                        , Inputs.Sparse_ledger.t
                        , Inputs.Ledger_proof.t )
                        Snark_work_lib.Work.Single.Spec.t =
            Work_selector.Random.Make (Inputs)
        end )
  in
  let module Init = struct
    include Kernel
    include Config

    let proposer_prover = proposer_prover

    let verifier = verifier

    module Make_work_selector = Selector.Make
  end in
  (module Init : Init_intf)

module type State_proof_intf = sig
  module Consensus_mechanism : Consensus.Mechanism.S

  type t [@@deriving bin_io, sexp]

  include
    Protocols.Coda_pow.Proof_intf
    with type input := Consensus_mechanism.Protocol_state.value
     and type t := t
end

module Make_inputs0
    (Init : Init_intf)
    (Ledger_proof_verifier : Ledger_proof_verifier_intf) =
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

  module Fee_transfer = Coda_base.Fee_transfer
  module Coinbase = Coda_base.Coinbase

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
    include Ledger_proof
    include Ledger_proof_verifier
  end

  module Proof = Coda_base.Proof.Stable.V1
  module Ledger_proof = Ledger_proof
  module Sparse_ledger = Coda_base.Sparse_ledger

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
      module Frozen_ledger_hash = Frozen_ledger_hash
      module Ledger_builder_diff = Ledger_builder_diff
      module Ledger_builder_hash = Ledger_builder_hash
      module Ledger_builder_aux_hash = Ledger_builder_aux_hash
      module Config = Init

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
    [@@deriving sexp]

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
    let load ~parent_log ~disk_location:_ ~incoming_diffs =
      return (create ~parent_log ~incoming_diffs)

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
    [@@deriving sexp, bin_io, fields]

    let of_transition_and_lb transition ledger_builder =
      { protocol_state=
          Consensus_mechanism.External_transition.protocol_state transition
      ; proof=
          Consensus_mechanism.External_transition.protocol_state_proof
            transition
      ; ledger_builder }

    let copy t = {t with ledger_builder= Ledger_builder.copy t.ledger_builder}
  end

  let keypair = Init.keypair
end

module Make_inputs
    (Init : Init_intf)
    (Ledger_proof_verifier : Ledger_proof_verifier_intf)
    (Store : Storage.With_checksum_intf with type location = string) =
struct
  open Init
  module Inputs0 = Make_inputs0 (Init) (Ledger_proof_verifier)
  include Inputs0
  module Blockchain_state = Coda_base.Blockchain_state
  module Ledger_builder_diff = Ledger_builder_diff
  module Completed_work = Completed_work
  module Ledger_builder_hash = Ledger_builder_hash
  module Ledger_builder_aux_hash = Ledger_builder_aux_hash
  module Ledger_proof_verifier = Ledger_proof_verifier
  module Ledger_hash = Ledger_hash
  module Frozen_ledger_hash = Frozen_ledger_hash
  module Transaction = Transaction
  module Public_key = Public_key
  module Compressed_public_key = Public_key.Compressed
  module Private_key = Private_key
  module Keypair = Keypair

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

    let ledger = Genesis_ledger.t

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

    let load ~parent_log ~disk_location ~incoming_diffs =
      match%map Reader.load_bin_prot disk_location Pool.bin_reader_t with
      | Ok pool -> of_pool_and_diffs pool ~parent_log ~incoming_diffs
      | Error _e -> create ~parent_log ~incoming_diffs

    open Snark_work_lib.Work

    let add_completed_work t
        (res :
          (('a, 'b, 'c, 'd) Single.Spec.t Spec.t, Ledger_proof.t) Result.t) =
      apply_and_broadcast t
        (Add_solved_work
           ( List.map res.spec.instances ~f:Single.Spec.statement
           , {proof= res.proofs; fee= {fee= res.spec.fee; prover= res.prover}}
           ))
  end

  module type S_tmp =
    Coda_lib.Network_intf
    with type state_with_witness := State_with_witness.t
     and type ledger_builder := Ledger_builder.t
     and type protocol_state := Protocol_state.value
     and type ledger_builder_hash := Ledger_builder_hash.t

  module Sync_ledger =
    Syncable_ledger.Make (Ledger.Addr) (Account)
      (struct
        include Merkle_hash

        let hash_account = Fn.compose Merkle_hash.of_digest Account.digest

        let empty_account = hash_account Account.empty
      end)
      (struct
        include Ledger_hash

        let to_hash (h : t) =
          Merkle_hash.of_digest (h :> Snark_params.Tick.Pedersen.Digest.t)
      end)
      (struct
        include Ledger

        let f = Account.hash
      end)
      (struct
        let subtree_height = 3
      end)

  module Net = Coda_networking.Make (struct
    include Inputs0
    module Snark_pool = Snark_pool
    module Snark_pool_diff = Snark_pool.Diff
    module Sync_ledger = Sync_ledger
    module Ledger_builder_hash = Ledger_builder_hash
    module Ledger_hash = Ledger_hash
    module Ledger_builder_aux_hash = Ledger_builder_aux_hash
    module Blockchain_state = Consensus_mechanism.Blockchain_state
  end)

  module Ledger_builder_controller = struct
    module Inputs = struct
      module Security = struct
        let max_depth = Init.lbc_tree_max_depth
      end

      module Tip = Tip
      module Snark_pool = Snark_pool
      module Ledger_hash = Ledger_hash
      module Frozen_ledger_hash = Frozen_ledger_hash
      module Ledger_proof = Transaction_snark
      module Private_key = Private_key

      module Public_key = struct
        module Private_key = Private_key
        include Public_key
      end

      module Keypair = Keypair
      module Ledger_proof_statement = Ledger_proof_statement
      module Ledger_builder_hash = Ledger_builder_hash
      module Ledger = Ledger
      module Ledger_builder_diff = Ledger_builder_diff
      module Ledger_builder_aux_hash = Ledger_builder_aux_hash
      module Ledger_builder = Ledger_builder
      module Blockchain_state = Blockchain_state
      module Consensus_mechanism = Consensus_mechanism
      module Protocol_state = Protocol_state
      module Protocol_state_proof = Protocol_state_proof
      module State_hash = State_hash
      module Valid_transaction = Transaction.With_valid_signature
      module Internal_transition = Internal_transition

      module Net = struct
        type net = Net.t

        include Net.Ledger_builder_io
      end

      module Store = Store
      module Sync_ledger = Sync_ledger

      let verify_blockchain proof state =
        Init.Verifier.verify_blockchain Init.verifier {proof; state}
    end

    include Ledger_builder_controller.Make (Inputs)
  end

  module Proposer = Proposer.Make (struct
    include Inputs0
    module Ledger_builder_diff = Ledger_builder_diff
    module Ledger_proof_verifier = Ledger_proof_verifier
    module Completed_work = Completed_work
    module Ledger_builder_hash = Ledger_builder_hash
    module Ledger_builder_aux_hash = Ledger_builder_aux_hash
    module Ledger_proof_statement = Ledger_proof_statement
    module Ledger_hash = Ledger_hash
    module Frozen_ledger_hash = Frozen_ledger_hash
    module Transaction = Transaction
    module Public_key = Public_key
    module Private_key = Private_key
    module Keypair = Keypair
    module Compressed_public_key = Public_key.Compressed

    module Prover = struct
      let prove ~prev_state ~prev_state_proof ~next_state
          (transition : Init.Consensus_mechanism.Internal_transition.t) =
        match Init.proposer_prover with
        | `Non_proposer -> failwith "prove: Coda not run as proposer"
        | `Proposer prover ->
            let open Deferred.Or_error.Let_syntax in
            Init.Prover.extend_blockchain prover
              (Init.Blockchain.create ~proof:prev_state_proof ~state:prev_state)
              next_state
              (Init.Consensus_mechanism.Internal_transition.snark_transition
                 transition)
            >>| fun {Init.Blockchain.proof; _} -> proof
    end
  end)

  module Work_selector_inputs = struct
    module Ledger_proof_statement = Ledger_proof_statement
    module Sparse_ledger = Sparse_ledger
    module Super_transaction = Super_transaction
    module Ledger_hash = Ledger_hash
    module Ledger_proof = Ledger_proof
    module Ledger_builder = Ledger_builder
  end

  module Work_selector = Make_work_selector (Work_selector_inputs)

  let request_work ~best_ledger_builder
      ~(seen_jobs : 'a -> Work_selector.State.t)
      ~(set_seen_jobs : 'a -> Work_selector.State.t -> unit) (t : 'a) =
    let lb = best_ledger_builder t in
    let instances, seen_jobs = Work_selector.work lb (seen_jobs t) in
    set_seen_jobs t seen_jobs ;
    if List.is_empty instances then None
    else Some {Snark_work_lib.Work.Spec.instances; fee= Fee.Unsigned.zero}
end

[%%if
with_snark]

module Make_coda (Init : Init_intf) = struct
  module Ledger_proof_verifier = struct
    let verify t stmt ~message =
      if
        not
          (Int.( = )
             (Transaction_snark.Statement.compare (Ledger_proof.statement t)
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
    include Make_inputs (Init) (Ledger_proof_verifier) (Storage.Disk)
    module Ledger_proof_statement = Ledger_proof_statement
    module Snark_worker = Snark_worker_lib.Prod.Worker
  end

  module Consensus_mechanism = Init.Consensus_mechanism
  module Blockchain = Init.Blockchain
  module Prover = Init.Prover
  include Coda_lib.Make (Inputs)

  let request_work =
    Inputs.request_work ~best_ledger_builder ~seen_jobs ~set_seen_jobs
end

[%%else]

module Make_coda (Init : Init_intf) = struct
  module Ledger_proof_verifier = struct
    let verify _ _ ~message:_ = return true
  end

  module Inputs = struct
    include Make_inputs (Init) (Ledger_proof_verifier) (Storage.Disk)
    module Ledger_proof_statement = Ledger_proof_statement
    module Snark_worker = Snark_worker_lib.Debug.Worker
  end

  module Consensus_mechanism = Init.Consensus_mechanism
  module Blockchain = Init.Blockchain
  module Prover = Init.Prover
  include Coda_lib.Make (Inputs)

  let request_work =
    Inputs.request_work ~best_ledger_builder ~seen_jobs ~set_seen_jobs
end

[%%endif]

module type Main_intf = sig
  module Inputs : sig
    module Time : Protocols.Coda_pow.Time_intf

    module Ledger : sig
      type t [@@deriving sexp]

      val copy : t -> t

      val location_of_key :
        t -> Public_key.Compressed.t -> Ledger.Location.t option

      val get : t -> Ledger.Location.t -> Account.t option

      val merkle_path :
           t
        -> Ledger.Location.t
        -> [`Left of Merkle_hash.t | `Right of Merkle_hash.t] list

      val num_accounts : t -> int

      val depth : int

      val merkle_root : t -> Coda_base.Ledger_hash.t

      val to_list : t -> Account.t list

      val fold_until :
           t
        -> init:'accum
        -> f:('accum -> Account.t -> ('accum, 'stop) Base.Continue_or_stop.t)
        -> finish:('accum -> 'stop)
        -> 'stop
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
        Coda_networking.Config_intf
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

    module Protocol_state_proof : sig
      type t
    end

    module Ledger_builder_hash : sig
      type t [@@deriving sexp]
    end

    module Ledger_builder : sig
      type t

      val hash : t -> Ledger_builder_hash.t
    end
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
      ; time_controller: Inputs.Time.Controller.t
      ; keypair: Keypair.t
      ; banlist: Banlist.t }
    [@@deriving make]
  end

  type t

  val should_propose : t -> bool

  val run_snark_worker : t -> bool

  val request_work : t -> Inputs.Snark_worker.Work.Spec.t option

  val best_ledger_builder : t -> Inputs.Ledger_builder.t

  val best_ledger : t -> Inputs.Ledger.t

  val best_tip :
       t
    -> Inputs.Ledger.t
       * Inputs.Consensus_mechanism.Protocol_state.value
       * Inputs.Protocol_state_proof.t

  val best_protocol_state :
    t -> Inputs.Consensus_mechanism.Protocol_state.value

  val best_tip :
       t
    -> Inputs.Ledger.t
       * Inputs.Consensus_mechanism.Protocol_state.value
       * Proof.t

  val peers : t -> Kademlia.Peer.t list

  val strongest_ledgers :
    t -> Inputs.Consensus_mechanism.External_transition.t Linear_pipe.Reader.t

  val transaction_pool : t -> Inputs.Transaction_pool.t

  val snark_pool : t -> Inputs.Snark_pool.t

  val create : Config.t -> t Deferred.t

  val ledger_builder_ledger_proof : t -> Inputs.Ledger_proof.t option

  val get_ledger : t -> Ledger_builder_hash.t -> Ledger.t Deferred.Or_error.t
end

module Run (Config_in : Config_intf) (Program : Main_intf) = struct
  include Program
  open Inputs

  module For_tests = struct
    let ledger_proof t = ledger_builder_ledger_proof t
  end

  module Lite_compat = Lite_compat.Make (Consensus_mechanism.Blockchain_state)

  let get_balance t (addr : Public_key.Compressed.t) =
    let open Option.Let_syntax in
    let ledger = best_ledger t in
    let%bind location = Ledger.location_of_key ledger addr in
    let%map account = Ledger.get ledger location in
    account.Account.balance

  let get_accounts t =
    let ledger = best_ledger t in
    Ledger.to_list ledger

  let string_of_public_key =
    Fn.compose Public_key.Compressed.to_base64 Account.public_key

  let get_public_keys t = get_accounts t |> List.map ~f:string_of_public_key

  let get_keys_with_balances t =
    get_accounts t
    |> List.map ~f:(fun account ->
           ( Account.balance account |> Currency.Balance.to_int
           , string_of_public_key account ) )

  let is_valid_transaction t (txn : Transaction.t) =
    let remainder =
      let open Option.Let_syntax in
      let%bind balance = get_balance t (Public_key.compress txn.sender)
      and cost = Currency.Amount.add_fee txn.payload.amount txn.payload.fee in
      Currency.Balance.sub_amount balance cost
    in
    Option.is_some remainder

  (** For status *)
  let txn_count = ref 0

  let schedule_transaction log t txn =
    let open Deferred.Let_syntax in
    if not (is_valid_transaction t txn) then (
      Core.Printf.eprintf "Invalid transaction: account balance is too low" ;
      Core.exit 1 ) ;
    let txn_pool = transaction_pool t in
    don't_wait_for (Transaction_pool.add txn_pool txn) ;
    Logger.info log
      !"Added transaction %{sexp: Transaction.t} to pool successfully"
      txn ;
    txn_count := !txn_count + 1

  let send_txn log t txn =
    schedule_transaction log t txn ;
    Deferred.unit

  let schedule_transactions log t txns =
    List.iter txns ~f:(schedule_transaction log t)

  let get_nonce t (addr : Public_key.Compressed.t) =
    let open Option.Let_syntax in
    let ledger = best_ledger t in
    let%bind location = Ledger.location_of_key ledger addr in
    let%map account = Ledger.get ledger location in
    account.Account.nonce

  let start_time = Time_ns.now ()

  let get_status t =
    let ledger = best_ledger t in
    let ledger_merkle_root =
      Ledger.merkle_root ledger |> [%sexp_of: Ledger_hash.t] |> Sexp.to_string
    in
    let num_accounts = Ledger.num_accounts ledger in
    let state = best_protocol_state t in
    let state_hash =
      Consensus_mechanism.Protocol_state.hash state
      |> [%sexp_of: State_hash.t] |> Sexp.to_string
    in
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
    ; ledger_merkle_root
    ; ledger_builder_hash=
        best_ledger_builder t |> Ledger_builder.hash
        |> Ledger_builder_hash.sexp_of_t |> Sexp.to_string
    ; state_hash
    ; external_transition_latency=
        Perf_histograms.report ~name:"external_transition_latency"
    ; snark_worker_transition_time=
        Perf_histograms.report ~name:"snark_worker_transition_time"
    ; snark_worker_merge_time=
        Perf_histograms.report ~name:"snark_worker_merge_time"
    ; commit_id= Config_in.commit_id
    ; conf_dir= Config_in.conf_dir
    ; peers= List.map (peers t) ~f:(fun (p, _) -> Host_and_port.to_string p)
    ; transactions_sent= !txn_count
    ; run_snark_worker= run_snark_worker t
    ; propose= should_propose t }

  let get_lite_chain :
      (t -> Public_key.Compressed.t list -> Lite_base.Lite_chain.t) option =
    Option.map Consensus_mechanism.Consensus_state.to_lite
      ~f:(fun consensus_state_to_lite t pks ->
        let ledger, state, proof = best_tip t in
        let ledger =
          List.fold pks
            ~f:(fun acc key ->
              let loc = Option.value_exn (Ledger.location_of_key ledger key) in
              Lite_lib.Sparse_ledger.add_path acc
                (Lite_compat.merkle_path (Ledger.merkle_path ledger loc))
                (Lite_compat.public_key key)
                (Lite_compat.account (Option.value_exn (Ledger.get ledger loc)))
              )
            ~init:
              (Lite_lib.Sparse_ledger.of_hash ~depth:Ledger.depth
                 (Lite_compat.digest
                    ( Ledger.merkle_root ledger
                      :> Snark_params.Tick.Pedersen.Digest.t )))
        in
        let protocol_state : Lite_base.Protocol_state.t =
          { previous_state_hash=
              Lite_compat.digest
                ( Consensus_mechanism.Protocol_state.previous_state_hash state
                  :> Snark_params.Tick.Pedersen.Digest.t )
          ; blockchain_state=
              Lite_compat.blockchain_state
                (Consensus_mechanism.Protocol_state.blockchain_state state)
          ; consensus_state=
              consensus_state_to_lite
                (Consensus_mechanism.Protocol_state.consensus_state state) }
        in
        let proof = Lite_compat.proof proof in
        {Lite_base.Lite_chain.proof; ledger; protocol_state} )

  let clear_hist_status t = Perf_histograms.wipe () ; get_status t

  let setup_local_server ?(client_whitelist = []) ?rest_server_port ~coda ~log
      ~client_port () =
    let client_whitelist =
      Unix.Inet_addr.Set.of_list (Unix.Inet_addr.localhost :: client_whitelist)
    in
    let log = Logger.child log "client" in
    (* Setup RPC server for client interactions *)
    let client_impls =
      [ Rpc.Rpc.implement Client_lib.Send_transactions.rpc (fun () ts ->
            schedule_transactions log coda ts ;
            Deferred.unit )
      ; Rpc.Rpc.implement Client_lib.Get_balance.rpc (fun () pk ->
            return (get_balance coda pk) )
      ; Rpc.Rpc.implement Client_lib.Get_public_keys_with_balances.rpc
          (fun () () -> return (get_keys_with_balances coda) )
      ; Rpc.Rpc.implement Client_lib.Get_public_keys.rpc (fun () () ->
            return (get_public_keys coda) )
      ; Rpc.Rpc.implement Client_lib.Get_nonce.rpc (fun () pk ->
            return (get_nonce coda pk) )
      ; Rpc.Rpc.implement Client_lib.Get_status.rpc (fun () () ->
            return (get_status coda) )
      ; Rpc.Rpc.implement Client_lib.Clear_hist_status.rpc (fun () () ->
            return (clear_hist_status coda) )
      ; Rpc.Rpc.implement Client_lib.Get_ledger.rpc (fun () lh ->
            get_ledger coda lh ) ]
    in
    let snark_worker_impls =
      [ Rpc.Rpc.implement Snark_worker.Rpcs.Get_work.rpc (fun () () ->
            let r = request_work coda in
            Option.iter r ~f:(fun r ->
                Logger.info log !"Get_work: %{sexp:Snark_worker.Work.Spec.t}" r
            ) ;
            return r )
      ; Rpc.Rpc.implement Snark_worker.Rpcs.Submit_work.rpc
          (fun () (work : Snark_worker.Work.Result.t) ->
            Logger.info log
              !"Submit_work: %{sexp:Snark_worker.Work.Spec.t}"
              work.spec ;
            List.iter work.metrics ~f:(fun (total, tag) ->
                match tag with
                | `Merge ->
                    Perf_histograms.add_span ~name:"snark_worker_merge_time"
                      total
                | `Transition ->
                    Perf_histograms.add_span
                      ~name:"snark_worker_transition_time" total ) ;
            Snark_pool.add_completed_work (snark_pool coda) work ) ]
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
                let route_not_found () =
                  Server.respond_string ~status:`Not_found "Route not found"
                in
                match Uri.path uri with
                | "/status" ->
                    Server.respond_string
                      ( get_status coda |> Client_lib.Status.to_yojson
                      |> Yojson.Safe.pretty_to_string )
                | _ -> route_not_found () )) ) ;
    let where_to_listen =
      Tcp.Where_to_listen.bind_to All_addresses (On_port client_port)
    in
    ignore
      (Tcp.Server.create
         ~on_handler_error:
           (`Call
             (fun net exn -> Logger.error log "%s" (Exn.to_string_mach exn)))
         where_to_listen
         (fun address reader writer ->
           let address = Socket.Address.Inet.addr address in
           if not (Set.mem client_whitelist address) then (
             Logger.error log
               !"Rejecting client connection from \
                 %{sexp:Unix.Inet_addr.Blocking_sexp.t}"
               address ;
             Deferred.unit )
           else
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

  let create_snark_worker ~log ~public_key ~client_port ~shutdown_on_disconnect
      =
    let open Snark_worker_lib in
    let%map p =
      let our_binary = Sys.executable_name in
      Process.create_exn () ~prog:our_binary
        ~args:
          ( "internal" :: Snark_worker_lib.Intf.command_name
          :: Snark_worker.arguments ~public_key
               ~daemon_address:
                 (Host_and_port.create ~host:"127.0.0.1" ~port:client_port)
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
