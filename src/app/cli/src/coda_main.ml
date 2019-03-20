[%%import
"../../../config.mlh"]

open Core
open Async
open Coda_base
open Signature_lib
open Blockchain_snark
open Coda_numbers
open Pipe_lib
open O1trace
module Fee = Protocols.Coda_pow.Fee

[%%if
proof_level = "full"]

module Ledger_proof = Ledger_proof.Prod

[%%else]

(* TODO #1698: proof_level=check *)

module Ledger_proof = struct
  module Statement = Transaction_snark.Statement
  include Ledger_proof.Debug
end

[%%endif]

module Graphql_cohttp_async =
  Graphql_cohttp.Make (Graphql_async.Schema) (Cohttp_async.Body)

module Staged_ledger_aux_hash = struct
  include Staged_ledger_hash.Aux_hash.Stable.Latest

  let of_bytes = Staged_ledger_hash.Aux_hash.of_bytes

  let to_bytes = Staged_ledger_hash.Aux_hash.to_bytes
end

module Staged_ledger_hash = struct
  include Staged_ledger_hash.Stable.Latest

  let ledger_hash = Staged_ledger_hash.ledger_hash

  let aux_hash = Staged_ledger_hash.aux_hash

  let of_aux_and_ledger_hash = Staged_ledger_hash.of_aux_and_ledger_hash
end

module Ledger_hash = struct
  include Ledger_hash

  let of_digest = Ledger_hash.of_digest

  let merge = Ledger_hash.merge

  let to_bytes = Ledger_hash.to_bytes

  let of_digest = Ledger_hash.of_digest

  let merge = Ledger_hash.merge
end

module Frozen_ledger_hash = struct
  include Frozen_ledger_hash

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

module type Work_selector_F = functor
  (Inputs : Work_selector.Inputs.Inputs_intf)
  -> Protocols.Coda_pow.Work_selector_intf
     with type staged_ledger := Inputs.Staged_ledger.t
      and type work :=
                 ( Inputs.Ledger_proof_statement.t
                 , Inputs.Transaction.t
                 , Inputs.Sparse_ledger.t
                 , Inputs.Ledger_proof.t )
                 Snark_work_lib.Work.Single.Spec.t
      and type snark_pool := Inputs.Snark_pool.t
      and type fee := Inputs.Fee.t

module type Config_intf = sig
  val logger : Logger.t

  val conf_dir : string

  val lbc_tree_max_depth : [`Infinity | `Finite of int]

  val propose_keypair : Keypair.t option

  val genesis_proof : Snark_params.Tock.Proof.t

  val commit_id : Daemon_rpcs.Types.Git_sha.t option

  val work_selection : Protocols.Coda_pow.Work_selection.t
end

module type Init_intf = sig
  include Config_intf

  module Transaction_snark_work :
    Protocols.Coda_pow.Transaction_snark_work_intf
    with type proof := Ledger_proof.t
     and type statement := Transaction_snark.Statement.t
     and type public_key := Public_key.Compressed.t

  module Staged_ledger_diff :
    Protocols.Coda_pow.Staged_ledger_diff_intf
    with type completed_work_checked := Transaction_snark_work.Checked.t
     and type completed_work := Transaction_snark_work.t
     and type public_key := Public_key.Compressed.t
     and type staged_ledger_hash := Staged_ledger_hash.t
     and type user_command := User_command.t
     and type user_command_with_valid_signature :=
                User_command.With_valid_signature.t
     and type fee_transfer_single := Fee_transfer.single

  module Make_work_selector : Work_selector_F

  val proposer_prover : [`Proposer of Prover.t | `Non_proposer]

  val verifier : Verifier.t

  val genesis_proof : Proof.t
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

      val merkle_path :
           t
        -> Ledger.Location.t
        -> [`Left of Ledger_hash.t | `Right of Ledger_hash.t] list

      val num_accounts : t -> int

      val depth : int

      val merkle_root : t -> Ledger_hash.t

      val to_list : t -> Account.t list

      val fold_until :
           t
        -> init:'accum
        -> f:('accum -> Account.t -> ('accum, 'stop) Base.Continue_or_stop.t)
        -> finish:('accum -> 'stop)
        -> 'stop
    end

    module Net : sig
      type t

      module Peer : sig
        type t =
          { host: Unix.Inet_addr.Blocking_sexp.t
          ; discovery_port: int (* UDP *)
          ; communication_port: int
          (* TCP *) }
        [@@deriving bin_io, sexp, compare, hash]
      end

      module Gossip_net : sig
        module Config : Gossip_net.Config_intf
      end

      module Config :
        Coda_networking.Config_intf
        with type gossip_config := Gossip_net.Config.t
         and type time_controller := Time.Controller.t
    end

    module Sparse_ledger : sig
      type t
    end

    module Ledger_proof : sig
      type t

      type statement
    end

    module Ledger_proof_statement : sig
      type t

      include Comparable.S with type t := t
    end

    module Transaction : sig
      type t
    end

    module Snark_worker :
      Snark_worker_lib.Intf.S
      with type proof := Ledger_proof.t
       and type statement := Ledger_proof.statement
       and type transition := Transaction.t
       and type sparse_ledger := Sparse_ledger.t

    module Snark_pool : sig
      type t

      val add_completed_work :
        t -> Snark_worker.Work.Result.t -> unit Deferred.t
    end

    module Transaction_pool : sig
      type t

      val add : t -> User_command.t -> unit Deferred.t
    end

    module Protocol_state_proof : sig
      type t

      val dummy : t
    end

    module Transaction_snark_work :
      Protocols.Coda_pow.Transaction_snark_work_intf
      with type proof := Ledger_proof.t
       and type statement := Transaction_snark.Statement.t
       and type public_key := Public_key.Compressed.t

    module Staged_ledger_diff :
      Protocols.Coda_pow.Staged_ledger_diff_intf
      with type completed_work := Transaction_snark_work.t
       and type completed_work_checked := Transaction_snark_work.Checked.t
       and type user_command := User_command.t
       and type user_command_with_valid_signature :=
                  User_command.With_valid_signature.t
       and type public_key := Public_key.Compressed.t
       and type staged_ledger_hash := Staged_ledger_hash.t
       and type fee_transfer_single := Fee_transfer.single

    module Staged_ledger :
      Protocols.Coda_pow.Staged_ledger_intf
      with type diff := Staged_ledger_diff.t
       and type valid_diff :=
                  Staged_ledger_diff.With_valid_signatures_and_proofs.t
       and type staged_ledger_hash := Staged_ledger_hash.t
       and type staged_ledger_aux_hash := Staged_ledger_aux_hash.t
       and type ledger_hash := Ledger_hash.t
       and type frozen_ledger_hash := Frozen_ledger_hash.t
       and type public_key := Public_key.Compressed.t
       and type ledger := Ledger.t
       and type ledger_proof := Ledger_proof.t
       and type user_command_with_valid_signature :=
                  User_command.With_valid_signature.t
       and type statement := Transaction_snark_work.Statement.t
       and type completed_work_checked := Transaction_snark_work.Checked.t
       and type sparse_ledger := Sparse_ledger.t
       and type ledger_proof_statement := Ledger_proof_statement.t
       and type ledger_proof_statement_set := Ledger_proof_statement.Set.t
       and type transaction := Transaction.t
       and type user_command := User_command.t

    module Internal_transition :
      Coda_base.Internal_transition.S
      with module Snark_transition = Consensus.Snark_transition
       and module Prover_state := Consensus.Prover_state
       and module Staged_ledger_diff := Staged_ledger_diff

    module External_transition :
      Coda_base.External_transition.S
      with module Protocol_state = Consensus.Protocol_state
       and module Staged_ledger_diff := Staged_ledger_diff

    module Transition_frontier :
      Protocols.Coda_pow.Transition_frontier_intf
      with type state_hash := State_hash.t
       and type external_transition_verified := External_transition.Verified.t
       and type ledger_database := Coda_base.Ledger.Db.t
       and type masked_ledger := Coda_base.Ledger.t
       and type staged_ledger := Staged_ledger.t
       and type staged_ledger_diff := Staged_ledger_diff.t
       and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
       and type consensus_local_state := Consensus.Local_state.t
       and type user_command := User_command.t
       and type Extensions.Work.t = Transaction_snark_work.Statement.t
  end

  module Config : sig
    (** If ledger_db_location is None, will auto-generate a db based on a UUID *)
    type t =
      { logger: Logger.t
      ; propose_keypair: Keypair.t option
      ; run_snark_worker: bool
      ; net_config: Inputs.Net.Config.t
      ; staged_ledger_persistant_location: string
      ; transaction_pool_disk_location: string
      ; snark_pool_disk_location: string
      ; ledger_db_location: string option
      ; staged_ledger_transition_backup_capacity: int [@default 10]
      ; time_controller:
          Inputs.Time.Controller.t (* FIXME trust system goes here? *)
      ; receipt_chain_database: Receipt_chain_database.t
      ; snark_work_fee: Currency.Fee.t
      ; monitor: Async.Monitor.t option }
    [@@deriving make]
  end

  type t

  val propose_keypair : t -> Keypair.t option

  val run_snark_worker : t -> bool

  val request_work : t -> Inputs.Snark_worker.Work.Spec.t option

  val best_staged_ledger : t -> Inputs.Staged_ledger.t Participating_state.t

  val best_ledger : t -> Inputs.Ledger.t Participating_state.t

  val best_protocol_state :
    t -> Consensus.Protocol_state.Value.t Participating_state.t

  val best_tip :
    t -> Inputs.Transition_frontier.Breadcrumb.t Participating_state.t

  val visualize_frontier : filename:string -> t -> unit Participating_state.t

  val peers : t -> Network_peer.Peer.t list

  val strongest_ledgers :
       t
    -> (Inputs.External_transition.Verified.t, State_hash.t) With_hash.t
       Strict_pipe.Reader.t

  val root_diff :
       t
    -> User_command.t Protocols.Coda_transition_frontier.Root_diff_view.t
       Strict_pipe.Reader.t

  val transaction_pool : t -> Inputs.Transaction_pool.t

  val snark_pool : t -> Inputs.Snark_pool.t

  val create : Config.t -> t Deferred.t

  val staged_ledger_ledger_proof : t -> Inputs.Ledger_proof.t option

  val get_ledger :
    t -> Staged_ledger_hash.t -> Account.t list Deferred.Or_error.t

  val receipt_chain_database : t -> Receipt_chain_database.t
end

module Fee_transfer = Coda_base.Fee_transfer
module Ledger_proof_statement = Transaction_snark.Statement
module Transaction_snark_work =
  Staged_ledger.Make_completed_work
    (Ledger_proof.Stable.V1)
    (Ledger_proof_statement)

module Staged_ledger_diff = Staged_ledger.Make_diff (struct
  module Ledger_proof = Ledger_proof.Stable.V1
  module Ledger_hash = Ledger_hash
  module Staged_ledger_hash = Staged_ledger_hash
  module Staged_ledger_aux_hash = Staged_ledger_aux_hash
  module Compressed_public_key = Public_key.Compressed
  module User_command = User_command
  module Transaction_snark_work = Transaction_snark_work
  module Fee_transfer = Fee_transfer
end)

let make_init ~should_propose (module Config : Config_intf) :
    (module Init_intf) Deferred.t =
  let open Config in
  let%bind proposer_prover =
    if should_propose then Prover.create ~conf_dir >>| fun p -> `Proposer p
    else return `Non_proposer
  in
  let%map verifier = Verifier.create ~conf_dir in
  let (module Make_work_selector : Work_selector_F) =
    match work_selection with
    | Seq -> (module Work_selector.Sequence.Make : Work_selector_F)
    | Random -> (module Work_selector.Random.Make : Work_selector_F)
  in
  let module Init = struct
    module Ledger_proof_statement = Ledger_proof_statement
    module Transaction_snark_work = Transaction_snark_work
    module Staged_ledger_diff = Staged_ledger_diff
    module Make_work_selector = Make_work_selector
    include Config

    let proposer_prover = proposer_prover

    let verifier = verifier
  end in
  (module Init : Init_intf)

module Make_inputs0
    (Init : Init_intf)
    (Ledger_proof_verifier : Ledger_proof_verifier_intf) =
struct
  open Protocols.Coda_pow
  open Init
  module Protocol_state = Consensus.Protocol_state
  module Protocol_state_hash = State_hash.Stable.Latest

  module Time : Time_intf with type t = Block_time.t = Block_time

  module Time_close_validator = struct
    let limit = Block_time.Span.of_time_span (Core.Time.Span.of_sec 15.)

    let validate t =
      let now = Block_time.now Block_time.Controller.basic in
      (* t should be at most [limit] greater than now *)
      Block_time.Span.( < ) (Block_time.diff t now) limit
  end

  module Masked_ledger = Ledger.Mask.Attached
  module Sok_message = Sok_message

  module Amount = struct
    module Signed = struct
      include Currency.Amount.Signed

      include (
        Currency.Amount.Signed.Stable.Latest :
          module type of Currency.Amount.Signed.Stable.Latest
          with type t := t
           and type ('a, 'b) t_ := ('a, 'b) t_ )
    end
  end

  module Protocol_state_proof = struct
    include Proof.Stable.V1

    type input = Protocol_state.Value.t

    let dummy = Coda_base.Proof.dummy

    let verify state_proof state =
      match%map
        Verifier.verify_blockchain Init.verifier {proof= state_proof; state}
      with
      | Ok b -> b
      | Error e ->
          Logger.error Init.logger ~module_:__MODULE__ ~location:__LOC__
            ~metadata:[("error", `String (Error.to_string_hum e))]
            "Could not connect to verifier: $error" ;
          false
  end

  module Coinbase = Coda_base.Coinbase
  module Fee_transfer = Fee_transfer
  module Account = Account

  module Transaction = struct
    module T = struct
      type t = Coda_base.Transaction.t =
        | User_command of User_command.With_valid_signature.t
        | Fee_transfer of Fee_transfer.t
        | Coinbase of Coinbase.t
      [@@deriving compare, eq]
    end

    let fee_excess = Transaction.fee_excess

    let supply_increase = Transaction.supply_increase

    include T

    include (
      Coda_base.Transaction :
        module type of Coda_base.Transaction with type t := t )
  end

  module Ledger = Ledger
  module Ledger_db = Ledger.Db
  module Ledger_transfer = Ledger_transfer.Make (Ledger) (Ledger_db)

  module Transaction_snark = struct
    include Ledger_proof
    include Ledger_proof_verifier
  end

  module Proof = Coda_base.Proof.Stable.V1
  module Ledger_proof = Ledger_proof
  module Sparse_ledger = Coda_base.Sparse_ledger

  module Transaction_snark_work_proof = struct
    type t = Ledger_proof.Stable.V1.t list [@@deriving sexp, bin_io]
  end

  module Staged_ledger = struct
    module Inputs = struct
      module Sok_message = Sok_message
      module Account = Account
      module Proof = Proof
      module Sparse_ledger = Sparse_ledger
      module Amount = Amount
      module Transaction_snark_work = Transaction_snark_work
      module Compressed_public_key = Public_key.Compressed
      module User_command = User_command
      module Fee_transfer = Fee_transfer
      module Coinbase = Coinbase
      module Transaction = Transaction
      module Ledger = Ledger
      module Ledger_proof = Ledger_proof
      module Ledger_proof_verifier = Ledger_proof_verifier
      module Ledger_proof_statement = Ledger_proof_statement
      module Ledger_hash = Ledger_hash
      module Frozen_ledger_hash = Frozen_ledger_hash
      module Staged_ledger_diff = Staged_ledger_diff
      module Staged_ledger_hash = Staged_ledger_hash
      module Staged_ledger_aux_hash = Staged_ledger_aux_hash
      module Transaction_validator = Transaction_validator
      module Config = Init

      let check (Transaction_snark_work.({fee; prover; proofs}) as t) stmts =
        let message = Sok_message.create ~fee ~prover in
        match List.zip proofs stmts with
        | None -> return None
        | Some ps ->
            let%map good =
              Deferred.List.for_all ps ~f:(fun (proof, stmt) ->
                  Transaction_snark.verify ~message proof stmt )
            in
            Option.some_if good
              (Transaction_snark_work.Checked.create_unsafe t)
    end

    include Staged_ledger.Make (Inputs)
  end

  module Staged_ledger_aux = Staged_ledger.Scan_state

  module Staged_ledger_transition = struct
    type t = {old: Staged_ledger.t sexp_opaque; diff: Staged_ledger_diff.t}
    [@@deriving sexp]

    module With_valid_signatures_and_proofs = struct
      type t =
        { old: Staged_ledger.t sexp_opaque
        ; diff: Staged_ledger_diff.With_valid_signatures_and_proofs.t }
      [@@deriving sexp]
    end

    let forget {With_valid_signatures_and_proofs.old; diff} =
      {old; diff= Staged_ledger_diff.forget diff}
  end

  module Internal_transition =
    Coda_base.Internal_transition.Make
      (Staged_ledger_diff)
      (Consensus.Snark_transition)
      (Consensus.Prover_state)
  module External_transition =
    Coda_base.External_transition.Make (Staged_ledger_diff) (Protocol_state)

  let max_length = Consensus.Constants.k

  module Transition_frontier = Transition_frontier.Make (struct
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Ledger_proof_statement = Ledger_proof_statement
    module Ledger_proof = Ledger_proof
    module Transaction_snark_work = Transaction_snark_work
    module Staged_ledger_diff = Staged_ledger_diff
    module External_transition = External_transition
    module Staged_ledger = Staged_ledger

    let max_length = max_length
  end)

  module Transaction_pool = struct
    module Pool = Transaction_pool.Make (Staged_ledger) (Transition_frontier)
    include Network_pool.Make (Transition_frontier) (Pool) (Pool.Diff)

    type pool_diff = Pool.Diff.t

    (* TODO *)
    let load ~logger ~disk_location:_ ~incoming_diffs ~frontier_broadcast_pipe
        =
      return (create ~logger ~incoming_diffs ~frontier_broadcast_pipe)

    let transactions t = Pool.transactions (pool t)

    (* TODO: This causes the signature to get checked twice as it is checked
       below before feeding it to add *)
    let add t txn = apply_and_broadcast t (Envelope.Incoming.local [txn])
  end

  module Transaction_pool_diff = Transaction_pool.Pool.Diff

  module Tip = struct
    type t =
      { state: Protocol_state.Value.t
      ; proof: Protocol_state_proof.t
      ; staged_ledger: Staged_ledger.t sexp_opaque }
    [@@deriving sexp, fields]

    type external_transition_verified = External_transition.Verified.t

    let of_verified_transition_and_staged_ledger transition staged_ledger =
      { state= External_transition.Verified.protocol_state transition
      ; proof= External_transition.Verified.protocol_state_proof transition
      ; staged_ledger }

    let bin_tip =
      [%bin_type_class:
        Protocol_state.Value.Stable.V1.t
        * Protocol_state_proof.t
        * Staged_ledger.serializable]

    let copy t = {t with staged_ledger= Staged_ledger.copy t.staged_ledger}
  end
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
  module Staged_ledger_diff = Staged_ledger_diff
  module Transaction_snark_work = Transaction_snark_work
  module State_body_hash = State_body_hash
  module Staged_ledger_hash = Staged_ledger_hash
  module Staged_ledger_aux_hash = Staged_ledger_aux_hash
  module Ledger_proof_verifier = Ledger_proof_verifier
  module Ledger_hash = Ledger_hash
  module Frozen_ledger_hash = Frozen_ledger_hash
  module User_command = User_command
  module Public_key = Public_key
  module Compressed_public_key = Public_key.Compressed
  module Private_key = Private_key
  module Keypair = Keypair

  module Genesis = struct
    let state = Consensus.genesis_protocol_state

    let ledger = Genesis_ledger.t

    let proof = Init.genesis_proof
  end

  module Snark_pool = struct
    module Work = Transaction_snark_work.Statement
    module Proof = Transaction_snark_work_proof

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

    module Pool = Snark_pool.Make (Proof) (Fee) (Work) (Transition_frontier)
    module Diff =
      Network_pool.Snark_pool_diff.Make (Proof) (Fee) (Work)
        (Transition_frontier)
        (Pool)

    type pool_diff = Diff.t

    include Network_pool.Make (Transition_frontier) (Pool) (Diff)

    let get_completed_work t statement =
      Option.map
        (Pool.request_proof (pool t) statement)
        ~f:(fun {proof; fee= {fee; prover}} ->
          Transaction_snark_work.Checked.create_unsafe
            {Transaction_snark_work.fee; proofs= proof; prover} )

    let load ~logger ~disk_location ~incoming_diffs ~frontier_broadcast_pipe =
      match%map Reader.load_bin_prot disk_location Pool.bin_reader_t with
      | Ok pool ->
          let network_pool = of_pool_and_diffs pool ~logger ~incoming_diffs in
          Pool.listen_to_frontier_broadcast_pipe frontier_broadcast_pipe pool ;
          network_pool
      | Error _e -> create ~logger ~incoming_diffs ~frontier_broadcast_pipe

    open Snark_work_lib.Work
    open Network_pool.Snark_pool_diff

    let add_completed_work t
        (res :
          (('a, 'b, 'c, 'd) Single.Spec.t Spec.t, Ledger_proof.t) Result.t) =
      apply_and_broadcast t
        (Envelope.Incoming.wrap
           ~data:
             (Add_solved_work
                ( List.map res.spec.instances ~f:Single.Spec.statement
                , Diff.Priced_proof.
                    { proof= res.proofs
                    ; fee= {fee= res.spec.fee; prover= res.prover} } ))
           ~sender:Envelope.Sender.Local)
  end

  module Root_sync_ledger = Sync_ledger.Db

  module Net = Coda_networking.Make (struct
    include Inputs0
    module Snark_pool = Snark_pool
    module Snark_pool_diff = Snark_pool.Diff
    module Sync_ledger = Sync_ledger
    module Staged_ledger_hash = Staged_ledger_hash
    module Ledger_hash = Ledger_hash
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Blockchain_state = Consensus.Blockchain_state
  end)

  module Protocol_state_validator = Protocol_state_validator.Make (struct
    include Inputs0
    module State_proof = Protocol_state_proof
    module Transaction_snark_work = Transaction_snark_work
    module Staged_ledger_diff = Staged_ledger_diff
    module Ledger_proof_statement = Ledger_proof_statement
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
  end)

  module Sync_handler = Sync_handler.Make (struct
    include Inputs0
    module Staged_ledger_diff = Staged_ledger_diff
    module Transaction_snark_work = Transaction_snark_work
    module Syncable_ledger = Sync_ledger
    module Ledger_proof_statement = Ledger_proof_statement
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Protocol_state_validator = Protocol_state_validator
  end)

  module Transition_handler = Transition_handler.Make (struct
    include Inputs0
    module State_proof = Protocol_state_proof
    module Transaction_snark_work = Transaction_snark_work
    module Staged_ledger_diff = Staged_ledger_diff
    module Ledger_proof_statement = Ledger_proof_statement
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
  end)

  module Ledger_catchup = Ledger_catchup.Make (struct
    include Inputs0
    module Staged_ledger_diff = Staged_ledger_diff
    module Transaction_snark_work = Transaction_snark_work
    module Transition_handler_validator = Transition_handler.Validator
    module Unprocessed_transition_cache =
      Transition_handler.Unprocessed_transition_cache
    module Ledger_proof_statement = Ledger_proof_statement
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Protocol_state_validator = Protocol_state_validator
    module Network = Net
  end)

  module Root_prover = Root_prover.Make (struct
    include Inputs0
    module Staged_ledger_diff = Staged_ledger_diff
    module Transaction_snark_work = Transaction_snark_work
    module Ledger_proof_statement = Ledger_proof_statement
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Protocol_state_validator = Protocol_state_validator
  end)

  module Bootstrap_controller = Bootstrap_controller.Make (struct
    include Inputs0
    module Staged_ledger_diff = Staged_ledger_diff
    module Transaction_snark_work = Transaction_snark_work
    module Ledger_proof_statement = Ledger_proof_statement
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Consensus_mechanism = Consensus
    module Root_sync_ledger = Root_sync_ledger
    module Protocol_state_validator = Protocol_state_validator
    module Network = Net
    module Sync_handler = Sync_handler
    module Root_prover = Root_prover
  end)

  module Transition_frontier_controller =
  Transition_frontier_controller.Make (struct
    include Inputs0
    module Protocol_state_validator = Protocol_state_validator
    module Transaction_snark_work = Transaction_snark_work
    module Syncable_ledger = Sync_ledger
    module Sync_handler = Sync_handler
    module Catchup = Ledger_catchup
    module Transition_handler = Transition_handler
    module Staged_ledger_diff = Staged_ledger_diff
    module Ledger_diff = Staged_ledger_diff
    module Consensus_mechanism = Consensus
    module Ledger_proof_statement = Ledger_proof_statement
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Network = Net
  end)

  module Transition_router = Transition_router.Make (struct
    include Inputs0
    module Transaction_snark_work = Transaction_snark_work
    module Syncable_ledger = Root_sync_ledger
    module Sync_handler = Sync_handler
    module Catchup = Ledger_catchup
    module Transition_handler = Transition_handler
    module Staged_ledger_diff = Staged_ledger_diff
    module Ledger_diff = Staged_ledger_diff
    module Consensus_mechanism = Consensus
    module Ledger_proof_statement = Ledger_proof_statement
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Network = Net
    module Bootstrap_controller = Bootstrap_controller
    module Transition_frontier_controller = Transition_frontier_controller
    module Protocol_state_validator = Protocol_state_validator
    module State_proof = Protocol_state_proof
  end)

  module Proposer = Proposer.Make (struct
    include Inputs0
    module Genesis_ledger = Genesis_ledger
    module State_hash = State_hash
    module Staged_ledger_diff = Staged_ledger_diff
    module Ledger_proof_verifier = Ledger_proof_verifier
    module Transaction_snark_work = Transaction_snark_work
    module Staged_ledger_hash = Staged_ledger_hash
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Ledger_proof_statement = Ledger_proof_statement
    module Ledger_hash = Ledger_hash
    module Frozen_ledger_hash = Frozen_ledger_hash
    module User_command = User_command
    module Public_key = Public_key
    module Private_key = Private_key
    module Keypair = Keypair
    module Compressed_public_key = Public_key.Compressed
    module Consensus_mechanism = Consensus
    module Transaction_validator = Transaction_validator

    module Prover = struct
      let prove ~prev_state ~prev_state_proof ~next_state
          (transition : Internal_transition.t) =
        match Init.proposer_prover with
        | `Non_proposer -> failwith "prove: Coda not run as proposer"
        | `Proposer prover ->
            let open Deferred.Or_error.Let_syntax in
            Prover.extend_blockchain prover
              (Blockchain.create ~proof:prev_state_proof ~state:prev_state)
              next_state
              (Internal_transition.snark_transition transition)
              (Internal_transition.prover_state transition)
            >>| fun {Blockchain.proof; _} -> proof
    end
  end)

  module Work_selector_inputs = struct
    module Ledger_proof_statement = Ledger_proof_statement
    module Sparse_ledger = Sparse_ledger
    module Transaction = Transaction
    module Ledger_hash = Ledger_hash
    module Ledger_proof = Ledger_proof
    module Staged_ledger = Staged_ledger
    module Fee = Fee.Unsigned
    module Snark_pool = Snark_pool

    module Transaction_snark_work = struct
      type t = Transaction_snark_work.Checked.t

      let fee t =
        let {Transaction_snark_work.fee; _} =
          Transaction_snark_work.forget t
        in
        fee
    end
  end

  module Work_selector = Make_work_selector (Work_selector_inputs)

  let request_work ~logger ~best_staged_ledger
      ~(seen_jobs : 'a -> Work_selector.State.t)
      ~(set_seen_jobs : 'a -> Work_selector.State.t -> unit)
      ~(snark_pool : 'a -> Snark_pool.t) (t : 'a) (fee : Fee.Unsigned.t) =
    let best_staged_ledger t =
      match best_staged_ledger t with
      | `Active staged_ledger -> Some staged_ledger
      | `Bootstrapping ->
          Logger.info logger ~module_:__MODULE__ ~location:__LOC__
            "Could not retrieve staged_ledger due to bootstrapping" ;
          None
    in
    let open Option.Let_syntax in
    let%bind sl = best_staged_ledger t in
    let instances, seen_jobs =
      Work_selector.work ~fee ~snark_pool:(snark_pool t) sl (seen_jobs t)
    in
    set_seen_jobs t seen_jobs ;
    if List.is_empty instances then None
    else Some {Snark_work_lib.Work.Spec.instances; fee}
end

[%%if
proof_level = "full"]

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
          Verifier.verify_transaction_snark Init.verifier t ~message
        with
        | Ok b -> b
        | Error e ->
            Logger.warn Init.logger ~module_:__MODULE__ ~location:__LOC__
              ~metadata:[("error", `String (Error.to_string_hum e))]
              "Bad transaction snark: $error" ;
            false
  end

  module Inputs = struct
    include Make_inputs (Init) (Ledger_proof_verifier) (Storage.Disk)
    module Genesis_ledger = Genesis_ledger
    module Ledger_proof_statement = Ledger_proof_statement
    module Snark_worker = Snark_worker_lib.Prod.Worker
    module Consensus_mechanism = Consensus
    module Transaction_validator = Transaction_validator
  end

  include Coda_lib.Make (Inputs)

  let request_work t =
    Inputs.request_work ~logger:t.logger ~best_staged_ledger ~seen_jobs
      ~set_seen_jobs ~snark_pool t (snark_work_fee t)
end

[%%else]

(* TODO #1698: proof_level=check ledger proofs *)
module Make_coda (Init : Init_intf) = struct
  module Ledger_proof_verifier = struct
    let verify _ _ ~message:_ = return true
  end

  module Inputs = struct
    include Make_inputs (Init) (Ledger_proof_verifier) (Storage.Disk)
    module Genesis_ledger = Genesis_ledger
    module Ledger_proof_statement = Ledger_proof_statement
    module Snark_worker = Snark_worker_lib.Debug.Worker
    module Consensus_mechanism = Consensus
    module Transaction_validator = Transaction_validator
  end

  include Coda_lib.Make (Inputs)

  let request_work t =
    Inputs.request_work ~logger:t.logger ~best_staged_ledger ~seen_jobs
      ~set_seen_jobs ~snark_pool t (snark_work_fee t)
end

[%%endif]

module Run (Config_in : Config_intf) (Program : Main_intf) = struct
  include Program
  open Inputs

  module For_tests = struct
    let ledger_proof t = staged_ledger_ledger_proof t
  end

  module Lite_compat = Lite_compat.Make (Consensus.Blockchain_state)

  let get_account t (addr : Public_key.Compressed.t) =
    let open Participating_state.Let_syntax in
    let%map ledger = best_ledger t in
    Ledger.location_of_key ledger addr |> Option.bind ~f:(Ledger.get ledger)

  let get_balance t (addr : Public_key.Compressed.t) =
    let open Participating_state.Option.Let_syntax in
    let%map account = get_account t addr in
    account.Account.balance

  let get_accounts t =
    let open Participating_state.Let_syntax in
    let%map ledger = best_ledger t in
    Ledger.to_list ledger

  let string_of_public_key =
    Fn.compose Public_key.Compressed.to_base64 Account.public_key

  let get_public_keys t =
    let open Participating_state.Let_syntax in
    let%map account = get_accounts t in
    List.map account ~f:string_of_public_key

  let get_keys_with_balances t =
    let open Participating_state.Let_syntax in
    let%map accounts = get_accounts t in
    List.map accounts ~f:(fun account ->
        ( string_of_public_key account
        , Account.balance account |> Currency.Balance.to_int ) )

  let is_valid_payment t (txn : User_command.t) account_opt =
    let remainder =
      let open Option.Let_syntax in
      let%bind account = account_opt
      and cost =
        let fee = txn.payload.common.fee in
        match txn.payload.body with
        | Stake_delegation (Set_delegate _) ->
            Some (Currency.Amount.of_fee fee)
        | Payment {amount; _} -> Currency.Amount.add_fee amount fee
      in
      Currency.Balance.sub_amount account.Account.balance cost
    in
    Option.is_some remainder

  (** For status *)
  let txn_count = ref 0

  let record_payment ~logger t (txn : User_command.t) account =
    let previous = Account.receipt_chain_hash account in
    let receipt_chain_database = receipt_chain_database t in
    match Receipt_chain_database.add receipt_chain_database ~previous txn with
    | `Ok hash ->
        Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:
            [ ("user_command", User_command.to_yojson txn)
            ; ("receipt_chain_hash", Receipt.Chain_hash.to_yojson hash) ]
          "Added  payment $user_command into receipt_chain database. You \
           should wait for a bit to see your account's receipt chain hash \
           update as $receipt_chain_hash" ;
        hash
    | `Duplicate hash ->
        Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:[("user_command", User_command.to_yojson txn)]
          "Already sent transaction $user_command" ;
        hash
    | `Error_multiple_previous_receipts parent_hash ->
        Logger.fatal logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:
            [ ( "parent_receipt_chain_hash"
              , Receipt.Chain_hash.to_yojson parent_hash )
            ; ( "previous_receipt_chain_hash"
              , Receipt.Chain_hash.to_yojson previous ) ]
          "A payment is derived from two different blockchain states \
           ($parent_receipt_chain_hash, $previous_receipt_chain_hash). \
           Receipt.Chain_hash is supposed to be collision resistant. This \
           collision should not happen." ;
        Core.exit 1

  module Payment_verifier =
    Receipt_chain_database_lib.Verifier.Make
      (User_command)
      (Receipt.Chain_hash)

  let verify_payment t log (addr : Public_key.Compressed.Stable.Latest.t)
      (verifying_txn : User_command.t) proof =
    let open Participating_state.Let_syntax in
    let%map account = get_account t addr in
    let account = Option.value_exn account in
    let resulting_receipt = Account.receipt_chain_hash account in
    let open Or_error.Let_syntax in
    let%bind () = Payment_verifier.verify ~resulting_receipt proof in
    if
      List.exists (Payment_proof.payments proof) ~f:(fun txn ->
          User_command.equal verifying_txn txn )
    then Ok ()
    else
      Or_error.errorf
        !"Merkle list proof does not contain payment %{sexp:User_command.t}"
        verifying_txn

  let schedule_payment log t (txn : User_command.t) account_opt =
    if not (is_valid_payment t txn account_opt) then
      Or_error.error_string "Invalid payment: account balance is too low"
    else
      let txn_pool = transaction_pool t in
      don't_wait_for (Transaction_pool.add txn_pool txn) ;
      Logger.info log ~module_:__MODULE__ ~location:__LOC__
        ~metadata:[("user_command", User_command.to_yojson txn)]
        "Added payment $user_command to pool successfully" ;
      txn_count := !txn_count + 1 ;
      Or_error.return ()

  let send_payment logger t (txn : User_command.t) =
    Deferred.return
    @@
    let public_key = Public_key.compress txn.sender in
    let open Participating_state.Let_syntax in
    let%map account_opt = get_account t public_key in
    let open Or_error.Let_syntax in
    let%map () = schedule_payment logger t txn account_opt in
    record_payment ~logger t txn (Option.value_exn account_opt)

  (* TODO: Properly record receipt_chain_hash for multiple transactions. See #1143 *)
  let schedule_payments logger t txns =
    List.map txns ~f:(fun (txn : User_command.t) ->
        let public_key = Public_key.compress txn.sender in
        let open Participating_state.Let_syntax in
        let%map account_opt = get_account t public_key in
        match schedule_payment logger t txn account_opt with
        | Ok () -> ()
        | Error err ->
            Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
              ~metadata:[("error", `String (Error.to_string_hum err))]
              "Failure in schedule_payments: $error. This is not yet reported \
               to the client, see #1143" )
    |> Participating_state.sequence
    |> Participating_state.map ~f:ignore

  let prove_receipt t ~proving_receipt ~resulting_receipt :
      Payment_proof.t Deferred.Or_error.t =
    let receipt_chain_database = receipt_chain_database t in
    (* TODO: since we are making so many reads to `receipt_chain_database`,
       reads should be async to not get IO-blocked. See #1125 *)
    let result =
      Receipt_chain_database.prove receipt_chain_database ~proving_receipt
        ~resulting_receipt
    in
    Deferred.return result

  let get_nonce t (addr : Public_key.Compressed.t) =
    let open Participating_state.Let_syntax in
    let%map ledger = best_ledger t in
    let open Option.Let_syntax in
    let%bind location = Ledger.location_of_key ledger addr in
    let%map account = Ledger.get ledger location in
    account.Account.nonce

  let start_time = Time_ns.now ()

  let snark_job_list_json t =
    let open Participating_state.Let_syntax in
    let%map sl = best_staged_ledger t in
    Staged_ledger.Scan_state.snark_job_list_json (Staged_ledger.scan_state sl)

  type active_state_fields =
    { num_accounts: int option
    ; block_count: int option
    ; ledger_merkle_root: string option
    ; staged_ledger_hash: string option
    ; state_hash: string option
    ; consensus_time_best_tip: string option }

  let get_status ~flag t =
    let uptime_secs =
      Time_ns.diff (Time_ns.now ()) start_time
      |> Time_ns.Span.to_sec |> Int.of_float
    in
    let commit_id = Config_in.commit_id in
    let conf_dir = Config_in.conf_dir in
    let peers =
      List.map (peers t) ~f:(fun peer ->
          Network_peer.Peer.to_discovery_host_and_port peer
          |> Host_and_port.to_string )
    in
    let user_commands_sent = !txn_count in
    let run_snark_worker = run_snark_worker t in
    let propose_pubkey =
      Option.map ~f:(fun kp -> kp.public_key) (propose_keypair t)
    in
    let consensus_mechanism = Consensus.name in
    let consensus_time_now = Consensus.time_hum (Core_kernel.Time.now ()) in
    let consensus_configuration = Consensus.Configuration.t in
    let r = Perf_histograms.report in
    let histograms =
      match flag with
      | `Performance ->
          let rpc_timings =
            let open Daemon_rpcs.Types.Status.Rpc_timings in
            { get_staged_ledger_aux=
                { Rpc_pair.dispatch=
                    r ~name:"rpc_dispatch_get_staged_ledger_aux"
                ; impl= r ~name:"rpc_impl_get_staged_ledger_aux" }
            ; answer_sync_ledger_query=
                { Rpc_pair.dispatch=
                    r ~name:"rpc_dispatch_answer_sync_ledger_query"
                ; impl= r ~name:"rpc_impl_answer_sync_ledger_query" }
            ; get_ancestry=
                { Rpc_pair.dispatch= r ~name:"rpc_dispatch_get_ancestry"
                ; impl= r ~name:"rpc_impl_get_ancestry" }
            ; transition_catchup=
                { Rpc_pair.dispatch= r ~name:"rpc_dispatch_transition_catchup"
                ; impl= r ~name:"rpc_impl_transition_catchup" } }
          in
          Some
            { Daemon_rpcs.Types.Status.Histograms.rpc_timings
            ; external_transition_latency=
                r ~name:"external_transition_latency"
            ; accepted_transition_local_latency=
                r ~name:"accepted_transition_local_latency"
            ; accepted_transition_remote_latency=
                r ~name:"accepted_transition_remote_latency"
            ; snark_worker_transition_time=
                r ~name:"snark_worker_transition_time"
            ; snark_worker_merge_time= r ~name:"snark_worker_merge_time" }
      | `None -> None
    in
    let active_status () =
      let open Participating_state.Let_syntax in
      let%bind ledger = best_ledger t in
      let ledger_merkle_root =
        Ledger.merkle_root ledger |> [%sexp_of: Ledger_hash.t]
        |> Sexp.to_string
      in
      let num_accounts = Ledger.num_accounts ledger in
      let%bind state = best_protocol_state t in
      let state_hash =
        Consensus.Protocol_state.hash state
        |> [%sexp_of: State_hash.t] |> Sexp.to_string
      in
      let consensus_state =
        state |> Consensus.Protocol_state.consensus_state
      in
      let block_count =
        Length.to_int @@ Consensus.Consensus_state.length consensus_state
      in
      let%map staged_ledger = best_staged_ledger t in
      let staged_ledger_hash =
        staged_ledger |> Staged_ledger.hash |> Staged_ledger_hash.sexp_of_t
        |> Sexp.to_string
      in
      let consensus_time_best_tip =
        Consensus.Consensus_state.time_hum consensus_state
      in
      { num_accounts= Some num_accounts
      ; block_count= Some block_count
      ; ledger_merkle_root= Some ledger_merkle_root
      ; staged_ledger_hash= Some staged_ledger_hash
      ; state_hash= Some state_hash
      ; consensus_time_best_tip= Some consensus_time_best_tip }
    in
    let ( is_bootstrapping
        , { num_accounts
          ; block_count
          ; ledger_merkle_root
          ; staged_ledger_hash
          ; state_hash
          ; consensus_time_best_tip } ) =
      match active_status () with
      | `Active result -> (false, result)
      | `Bootstrapping ->
          ( true
          , { num_accounts= None
            ; block_count= None
            ; ledger_merkle_root= None
            ; staged_ledger_hash= None
            ; state_hash= None
            ; consensus_time_best_tip= None } )
    in
    { Daemon_rpcs.Types.Status.num_accounts
    ; is_bootstrapping
    ; block_count
    ; uptime_secs
    ; ledger_merkle_root
    ; staged_ledger_hash
    ; state_hash
    ; consensus_time_best_tip
    ; commit_id
    ; conf_dir
    ; peers
    ; user_commands_sent
    ; run_snark_worker
    ; propose_pubkey
    ; histograms
    ; consensus_time_now
    ; consensus_mechanism
    ; consensus_configuration }

  let get_lite_chain :
      (t -> Public_key.Compressed.t list -> Lite_base.Lite_chain.t) option =
    Option.map Consensus.Consensus_state.to_lite
      ~f:(fun consensus_state_to_lite t pks ->
        let ledger = best_ledger t |> Participating_state.active_exn in
        let transition =
          With_hash.data
            (Transition_frontier.Breadcrumb.transition_with_hash
               (best_tip t |> Participating_state.active_exn))
        in
        let state = External_transition.Verified.protocol_state transition in
        let proof =
          External_transition.Verified.protocol_state_proof transition
        in
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
                ( Consensus.Protocol_state.previous_state_hash state
                  :> Snark_params.Tick.Pedersen.Digest.t )
          ; body=
              { blockchain_state=
                  Lite_compat.blockchain_state
                    (Consensus.Protocol_state.blockchain_state state)
              ; consensus_state=
                  consensus_state_to_lite
                    (Consensus.Protocol_state.consensus_state state) } }
        in
        let proof = Lite_compat.proof proof in
        {Lite_base.Lite_chain.proof; ledger; protocol_state} )

  let clear_hist_status ~flag t = Perf_histograms.wipe () ; get_status ~flag t

  let log_shutdown ~conf_dir ~logger t =
    let frontier_file = conf_dir ^/ "frontier.dot" in
    let mask_file = conf_dir ^/ "registered_masks.dot" in
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__ "%s"
      (Visualization_message.success "registered masks" frontier_file) ;
    Coda_base.Ledger.Debug.visualize ~filename:mask_file ;
    match visualize_frontier ~filename:frontier_file t with
    | `Active () ->
        Logger.info logger ~module_:__MODULE__ ~location:__LOC__ "%s"
          (Visualization_message.success "transition frontier" frontier_file)
    | `Bootstrapping ->
        Logger.info logger ~module_:__MODULE__ ~location:__LOC__ "%s"
          (Visualization_message.bootstrap "transition frontier")

  (* TODO: handle participation_status more appropriately than doing participate_exn *)
  let setup_local_server ?(client_whitelist = []) ?rest_server_port ~coda
      ~logger ~client_port () =
    let client_whitelist =
      Unix.Inet_addr.Set.of_list (Unix.Inet_addr.localhost :: client_whitelist)
    in
    (* Setup RPC server for client interactions *)
    let implement rpc f =
      Rpc.Rpc.implement rpc (fun () input ->
          trace_recurring_task (Rpc.Rpc.name rpc) (fun () -> f () input) )
    in
    let client_impls =
      [ implement Daemon_rpcs.Send_user_command.rpc (fun () tx ->
            let%map result = send_payment logger coda tx in
            result |> Participating_state.active_exn )
      ; implement Daemon_rpcs.Send_user_commands.rpc (fun () ts ->
            schedule_payments logger coda ts |> Participating_state.active_exn ;
            Deferred.unit )
      ; implement Daemon_rpcs.Get_balance.rpc (fun () pk ->
            return (get_balance coda pk |> Participating_state.active_exn) )
      ; implement Daemon_rpcs.Verify_proof.rpc (fun () (pk, tx, proof) ->
            return
              ( verify_payment coda logger pk tx proof
              |> Participating_state.active_exn ) )
      ; implement Daemon_rpcs.Prove_receipt.rpc
          (fun () (proving_receipt, pk) ->
            let open Deferred.Or_error.Let_syntax in
            let%bind account =
              get_account coda pk |> Participating_state.active_exn
              |> Result.of_option
                   ~error:
                     (Error.of_string
                        (sprintf
                           !"Could not find account of public key %{sexp: \
                             Public_key.Compressed.t}"
                           pk))
              |> Deferred.return
            in
            prove_receipt coda ~proving_receipt
              ~resulting_receipt:(Account.receipt_chain_hash account) )
      ; implement Daemon_rpcs.Get_public_keys_with_balances.rpc (fun () () ->
            return
              (get_keys_with_balances coda |> Participating_state.active_exn)
        )
      ; implement Daemon_rpcs.Get_public_keys.rpc (fun () () ->
            return (get_public_keys coda |> Participating_state.active_exn) )
      ; implement Daemon_rpcs.Get_nonce.rpc (fun () pk ->
            return (get_nonce coda pk |> Participating_state.active_exn) )
      ; implement Daemon_rpcs.Get_status.rpc (fun () flag ->
            return (get_status ~flag coda) )
      ; implement Daemon_rpcs.Clear_hist_status.rpc (fun () flag ->
            return (clear_hist_status ~flag coda) )
      ; implement Daemon_rpcs.Get_ledger.rpc (fun () lh -> get_ledger coda lh)
      ; implement Daemon_rpcs.Stop_daemon.rpc (fun () () ->
            Scheduler.yield () >>= (fun () -> exit 0) |> don't_wait_for ;
            Deferred.unit )
      ; implement Daemon_rpcs.Snark_job_list.rpc (fun () () ->
            return (snark_job_list_json coda |> Participating_state.active_exn)
        )
      ; implement Daemon_rpcs.Start_tracing.rpc (fun () () ->
            Coda_tracing.start Config_in.conf_dir )
      ; implement Daemon_rpcs.Stop_tracing.rpc (fun () () ->
            Coda_tracing.stop () ; Deferred.unit )
      ; implement Daemon_rpcs.Visualization.Frontier.rpc (fun () filename ->
            return (visualize_frontier ~filename coda) )
      ; implement Daemon_rpcs.Visualization.Registered_masks.rpc
          (fun () filename ->
            return (Coda_base.Ledger.Debug.visualize ~filename) ) ]
    in
    let snark_worker_impls =
      [ implement Snark_worker.Rpcs.Get_work.rpc (fun () () ->
            let r = request_work coda in
            Option.iter r ~f:(fun r ->
                Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
                  !"Get_work: %{sexp:Snark_worker.Work.Spec.t}"
                  r ) ;
            return r )
      ; implement Snark_worker.Rpcs.Submit_work.rpc
          (fun () (work : Snark_worker.Work.Result.t) ->
            Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
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
        trace_task "REST server" (fun () ->
            let graphql_schema =
              Graphql_async.Schema.(
                schema
                  [ field "greeting" ~typ:(non_null string)
                      ~args:Arg.[]
                      ~resolve:(fun _ () -> "hello coda") ])
            in
            let graphql_callback =
              Graphql_cohttp_async.make_callback
                (fun _req -> ())
                graphql_schema
            in
            Cohttp_async.(
              Server.create
                ~on_handler_error:
                  (`Call
                    (fun net exn ->
                      Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                        "%s" (Exn.to_string_mach exn) ))
                (Tcp.Where_to_listen.bind_to Localhost
                   (On_port rest_server_port))
                (fun ~body _sock req ->
                  let uri = Cohttp.Request.uri req in
                  let status flag =
                    Server.respond_string
                      ( get_status ~flag coda
                      |> Daemon_rpcs.Types.Status.to_yojson
                      |> Yojson.Safe.pretty_to_string )
                  in
                  match Uri.path uri with
                  | "/graphql" -> graphql_callback () req body
                  | "/status" -> status `None
                  | "/status/performance" -> status `Performance
                  | _ ->
                      Server.respond_string ~status:`Not_found
                        "Route not found" )) )
        |> ignore ) ;
    let where_to_listen =
      Tcp.Where_to_listen.bind_to All_addresses (On_port client_port)
    in
    trace_task "client RPC handling" (fun () ->
        Tcp.Server.create
          ~on_handler_error:
            (`Call
              (fun net exn ->
                Logger.error logger ~module_:__MODULE__ ~location:__LOC__ "%s"
                  (Exn.to_string_mach exn) ))
          where_to_listen
          (fun address reader writer ->
            let address = Socket.Address.Inet.addr address in
            if not (Set.mem client_whitelist address) then (
              Logger.error logger ~module_:__MODULE__ ~location:__LOC__
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
                      Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                        "%s" (Exn.to_string_mach exn) ;
                      Deferred.unit )) ) )
    |> ignore

  let create_snark_worker ~logger ~public_key ~client_port
      ~shutdown_on_disconnect =
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
    (* We want these to be printfs so we don't double encode our logs here *)
    Pipe.iter_without_pushback
      (Reader.pipe (Process.stdout p))
      ~f:(fun s -> printf "%s" s)
    |> don't_wait_for ;
    Pipe.iter_without_pushback
      (Reader.pipe (Process.stderr p))
      ~f:(fun s -> printf "%s" s)
    |> don't_wait_for ;
    Deferred.unit

  let run_snark_worker ?shutdown_on_disconnect:(s = true) ~logger ~client_port
      run_snark_worker =
    match run_snark_worker with
    | `Don't_run -> ()
    | `With_public_key public_key ->
        create_snark_worker ~shutdown_on_disconnect:s ~logger ~public_key
          ~client_port
        |> ignore

  let handle_shutdown ~monitor ~conf_dir ~logger t =
    Monitor.detach_and_iter_errors monitor ~f:(fun exn ->
        log_shutdown ~conf_dir ~logger t ;
        raise exn ) ;
    Async_unix.Signal.(
      handle terminating ~f:(fun signal ->
          log_shutdown ~conf_dir ~logger t ;
          Logger.info logger ~module_:__MODULE__ ~location:__LOC__
            !"Coda process got interrupted by signal %{sexp:t}"
            signal ))
end
