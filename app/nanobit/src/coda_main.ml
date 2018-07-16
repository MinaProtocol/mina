open Core
open Async
open Nanobit_base
open Blockchain_snark

module type Init_intf = sig
  val logger : Logger.t

  val conf_dir : string

  val prover : Prover.t

  val verifier : Verifier.t

  val genesis_proof : Proof.t

  (* Public key to allocate fees to *)

  val fee_public_key : Public_key.Compressed.t
end

module type State_proof_intf = sig
  type t [@@deriving bin_io, sexp]

  include Protocols.Coda_pow.Proof_intf
          with type input := State.t
           and type t := t
end

module Make_inputs0 (Ledger_proof : sig
  type t [@@deriving sexp, bin_io]

  val proof : t -> Proof.t

  val verify :
       t
    -> Transaction_snark.Statement.t
    -> message:Currency.Fee.t * Public_key.Compressed.t
    -> bool Deferred.t
end)
(Init : Init_intf) =
struct
  open Protocols.Coda_pow

  module Time : Time_intf with type t = Block_time.t = Block_time

  module Time_close_validator = struct
    let limit = Block_time.Span.of_time_span (Core.Time.Span.of_sec 15.)

    let validate t =
      let now = Block_time.now () in
      (* t should be at most [limit] greater than now *)
      Block_time.Span.( < ) (Block_time.diff t now) limit
  end

  module Public_key = Public_key
  module State_hash = State_hash.Stable.V1
  module Strength = Strength
  module Block_nonce = Block.Nonce

  module Ledger_builder_aux_hash = struct
    include Ledger_builder_hash.Aux_hash.Stable.V1

    let of_bytes = Ledger_builder_hash.Aux_hash.of_bytes
  end

  module Ledger_builder_hash = struct
    include Ledger_builder_hash.Stable.V1

    let of_aux_and_ledger_hash = Ledger_builder_hash.of_aux_and_ledger_hash

    let to_bytes = Ledger_builder_hash.to_bytes

    let of_bytes = Ledger_builder_hash.of_bytes
  end

  module Ledger_hash = struct
    include Ledger_hash.Stable.V1

    let to_bytes = Ledger_hash.to_bytes
  end

  module Pow = Proof_of_work
  module Difficulty = Difficulty

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

  module Fee = struct
    module Unsigned = struct
      include Currency.Fee

      include (
        Currency.Fee.Stable.V1 :
          module type of Currency.Fee.Stable.V1 with type t := t )
    end

    module Signed = struct
      include Currency.Fee.Signed

      include (
        Currency.Fee.Signed.Stable.V1 :
          module type of Currency.Fee.Signed.Stable.V1
          with type t := t
           and type ('a, 'b) t_ := ('a, 'b) t_ )
    end
  end

  module State = struct
    include State

    module Proof = struct
      include Proof.Stable.V1

      type input = State.t

      let verify state_proof state =
        match%map
          Verifier.verify_blockchain Init.verifier
            {proof= state_proof; state= State.to_blockchain_state state}
        with
        | Ok b -> b
        | Error e ->
            Logger.error Init.logger
              !"Could not connect to verifier: %{sexp:Error.t}"
              e ;
            false
    end
  end

  module Transaction = struct
    include (
      Transaction :
        module type of Transaction
        with module With_valid_signature := Transaction.With_valid_signature )

    let fee (t: t) = t.payload.Transaction.Payload.fee

    let seed = Secure_random.string ()

    let compare t1 t2 = Transaction.Stable.V1.compare ~seed t1 t2

    module With_valid_signature = struct
      module T = struct
        include Transaction.With_valid_signature

        let compare t1 t2 =
          Transaction.With_valid_signature.compare ~seed t1 t2
      end

      include T
      include Comparable.Make (T)
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

    include (
      Transaction_snark.Transition :
        module type of Transaction_snark.Transition with type t := t )
  end

  module Ledger = struct
    include Ledger

    let apply_super_transaction l = function
      | Super_transaction.Transaction t -> apply_transaction l t
      | Fee_transfer t -> apply_fee_transfer l t

    let undo_super_transaction l = function
      | Super_transaction.Transaction t -> undo_transaction l t
      | Fee_transfer t -> undo_fee_transfer l t
  end

  module Transaction_snark = struct
    module Statement = Transaction_snark.Statement
    include Ledger_proof
  end

  module Ledger_proof = struct
    include Ledger_proof

    type statement = Transaction_snark.Statement.t
  end

  module Completed_work = struct
    let proofs_length = 2

    module Statement = struct
      module T = struct
        type t = Transaction_snark.Statement.t list
        [@@deriving bin_io, sexp, hash, compare]
      end

      include T
      include Hashable.Make_binable (T)

      let gen =
        Quickcheck.Generator.list_with_length proofs_length
          Transaction_snark.Statement.gen
    end

    module Proof = struct
      type t = Transaction_snark.t list [@@deriving bin_io, sexp]
    end

    module T = struct
      type t =
        {fee: Fee.Unsigned.t; proofs: Proof.t; prover: Public_key.Compressed.t}
      [@@deriving sexp, bin_io]
    end

    include T

    module Checked = struct
      include T
    end

    let forget = Fn.id

    let check ({fee; prover; proofs} as t) stmts =
      let message = (fee, prover) in
      match List.zip proofs stmts with
      | None -> return None
      | Some ps ->
          let%map good =
            Deferred.List.for_all ps ~f:(fun (proof, stmt) ->
                Transaction_snark.verify ~message proof stmt )
          in
          Option.some_if good t
  end

  module Ledger_builder_diff = struct
    type t =
      { prev_hash: Ledger_builder_hash.t
      ; completed_works: Completed_work.t list
      ; transactions: Transaction.t list
      ; creator: Public_key.Compressed.t }
    [@@deriving sexp, bin_io]

    module With_valid_signatures_and_proofs = struct
      type t =
        { prev_hash: Ledger_builder_hash.t
        ; completed_works: Completed_work.Checked.t list
        ; transactions: Transaction.With_valid_signature.t list
        ; creator: Public_key.Compressed.t }
      [@@deriving sexp, bin_io]
    end

    let forget
        { With_valid_signatures_and_proofs.prev_hash
        ; completed_works
        ; transactions
        ; creator } =
      { prev_hash
      ; completed_works= List.map ~f:Completed_work.forget completed_works
      ; transactions= (transactions :> Transaction.t list)
      ; creator }
  end

  module Ledger_builder = struct
    include Ledger_builder.Make (struct
      module Amount = Amount
      module Fee = Fee
      module Public_key = Public_key.Compressed
      module Transaction = Transaction
      module Fee_transfer = Fee_transfer
      module Super_transaction = Super_transaction
      module Ledger = Ledger
      module Ledger_proof = Ledger_proof
      module Ledger_proof_statement = Transaction_snark.Statement
      module Ledger_hash = Ledger_hash
      module Ledger_builder_hash = Ledger_builder_hash
      module Ledger_builder_aux_hash = Ledger_builder_aux_hash
      module Ledger_builder_diff = Ledger_builder_diff
      module Completed_work = Completed_work
      module Config = Protocol_constants
    end)

    let of_aux_and_ledger ledger aux =
      Ok (make ~public_key:Init.fee_public_key ~aux ~ledger)
  end

  module Ledger_builder_aux = Ledger_builder.Aux

  module Ledger_builder_transition = struct
    type t = {old: Ledger_builder.t; diff: Ledger_builder_diff.t}
    [@@deriving sexp, bin_io]

    module With_valid_signatures_and_proofs = struct
      type t =
        { old: Ledger_builder.t
        ; diff: Ledger_builder_diff.With_valid_signatures_and_proofs.t }
      [@@deriving sexp, bin_io]
    end

    let forget {With_valid_signatures_and_proofs.old; diff} =
      {old; diff= Ledger_builder_diff.forget diff}
  end

  module External_transition = struct
    type t =
      { state_proof: State.Proof.t
      ; state: State.t
      ; ledger_builder_diff: Ledger_builder_diff.t }
    [@@deriving fields, bin_io, sexp]

    let compare t1 t2 = State.compare t1.state t2.state

    let equal t1 t2 = State.equal t1.state t2.state
  end

  module Internal_transition = struct
    type t =
      { ledger_hash: Ledger_hash.t
      ; ledger_builder_hash: Ledger_builder_hash.t
      ; ledger_proof: Ledger_proof.t option
      ; ledger_builder_diff: Ledger_builder_diff.t
      ; timestamp: Time.t
      ; nonce: Block_nonce.t }
    [@@deriving fields, sexp]
  end

  module Transaction_pool = struct
    module Pool = Transaction_pool.Make (Transaction)
    include Network_pool.Make (Pool) (Pool.Diff)

    type pool_diff = Pool.Diff.t [@@deriving bin_io]

    (* TODO *)
    let load ~disk_location:_ ~incoming_diffs = return (create ~incoming_diffs)

    let transactions t = Pool.transactions (pool t)
  end

  module Transaction_pool_diff = Transaction_pool.Pool.Diff
end

module Make_inputs (Ledger_proof0 : sig
  type t [@@deriving sexp, bin_io]

  val statement : t -> Transaction_snark.Statement.t

  val proof : t -> Proof.t

  val verify :
       t
    -> Transaction_snark.Statement.t
    -> message:Currency.Fee.t * Public_key.Compressed.t
    -> bool Deferred.t
end)
(Init : Init_intf)
(Store : Storage.With_checksum_intf)
() =
struct
  module Inputs0 = Make_inputs0 (Ledger_proof0) (Init)
  include Inputs0

  module Proof_carrying_state = struct
    type t = (State.t, State.Proof.t) Protocols.Coda_pow.Proof_carrying_data.t
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

    (*
    let check
          { Stripped.transactions; ledger_builder_transition; state } =
      let open Option.Let_syntax in
      let%map transactions = Option.all (List.map ~f:Transaction.check transactions) in
      { transactions
      ; ledger_builder_transition
      ; state
      } *)

    let forget_witness {ledger_builder_transition; state} = state

    let add_witness_exn = failwith "TODO?"

    let add_witness = failwith "TODO?"
  end

  module Genesis = struct
    let state = State.zero

    let ledger = Genesis_ledger.ledger

    let proof = Init.genesis_proof
  end

  module Snark_pool = struct
    module Work = Completed_work.Statement
    module Proof = Completed_work.Proof

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
          {Completed_work.fee; proofs= proof; prover} )

    let load ~disk_location ~incoming_diffs =
      match%map Reader.load_bin_prot disk_location Pool.bin_reader_t with
      | Ok pool -> of_pool_and_diffs pool ~incoming_diffs
      | Error _e -> create ~incoming_diffs
  end

  module type S_tmp =
    Coda.Network_intf
    with type state_with_witness := State_with_witness.t
     and type ledger_builder := Ledger_builder.t
     and type state := State.t
     and type ledger_builder_hash := Ledger_builder_hash.t

  module Sync_ledger =
    Syncable_ledger.Make (Ledger.Addr) (Public_key.Compressed)
      (Syncable_ledger.Valid (Ledger.Addr))
      (Account)
      (Merkle_hash)
      (struct
        include Ledger_hash

        let to_hash (h: t) = (h :> Merkle_hash.t)
      end)
      (struct
        include Ledger

        type path = Path.t
      end)

  module Net = Minibit_networking.Make (struct
    include Inputs0
    module Snark_pool = Snark_pool
    module Snark_pool_diff = Snark_pool.Diff
    module Sync_ledger = Sync_ledger
  end)

  module Ledger_builder_controller = struct
    module Inputs = struct
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

      module Ledger_builder = struct
        include Ledger_builder

        type proof = Ledger_proof.t

        let create ledger = create ~ledger ~self:Init.fee_public_key

        let apply t diff =
          Deferred.Or_error.map
            (Ledger_builder.apply t diff)
            ~f:
              (Option.map ~f:(fun proof ->
                   ((Ledger_proof0.statement proof).target, proof) ))
      end

      module State = State
      module State_hash = State_hash
      module Valid_transaction = Transaction.With_valid_signature
      module Strength = Strength
      module Sync_ledger = Sync_ledger
      module Internal_transition = Internal_transition
      module External_transition = External_transition

      (* TODO: Move into coda_pow or something *)
      module Step = struct
        let step (lb, old_state)
            ({state_proof; ledger_builder_diff; state= new_state}:
              External_transition.t) =
          let open Deferred.Or_error.Let_syntax in
          let%bind bc_good =
            Verifier.verify_blockchain Init.verifier
              {proof= state_proof; state= State.to_blockchain_state new_state}
          and ledger_hash =
            match%map Ledger_builder.apply lb ledger_builder_diff with
            | Some (h, _) -> h
            | None -> old_state.State.ledger_hash
          in
          let ledger_builder_hash = Ledger_builder.hash lb in
          let%map () =
            if
              Ledger_builder_hash.equal ledger_builder_hash
                new_state.ledger_builder_hash
              && Ledger_hash.equal ledger_hash new_state.ledger_hash
              && State_hash.equal (State.hash old_state)
                   new_state.previous_state_hash
            then Deferred.return (Ok ())
            else Deferred.Or_error.error_string "TODO: Punish"
          in
          new_state
      end
    end

    include Ledger_builder_controller.Make (Inputs)
  end

  module Miner = Minibit_miner.Make (struct
    include Inputs0

    module Prover = struct
      let prove ~prev_state:(old_state, old_proof)
          (transition: Internal_transition.t) =
        let open Deferred.Or_error.Let_syntax in
        Prover.extend_blockchain Init.prover
          {proof= old_proof; state= State.to_blockchain_state old_state}
          { header= {time= transition.timestamp; nonce= transition.nonce}
          ; body=
              { target_hash= transition.ledger_hash
              ; ledger_builder_hash= transition.ledger_builder_hash
              ; proof= Option.map ~f:Ledger_proof.proof transition.ledger_proof
              } }
        >>| fun {Blockchain_snark.Blockchain.proof; _} -> proof
    end
  end)
end

module Coda_with_snark
    (Store : Storage.With_checksum_intf)
    (Init : Init_intf)
    () =
struct
  module Ledger_proof = Ledger_proof.Make_prod (Init)

  module Inputs = Make_inputs (Ledger_proof) (Init) (Store) ()

  include Coda.Make (Inputs)
end

module Coda_without_snark (Init : Init_intf) () = struct
  module Store = Storage.Memory
  module Ledger_proof = Ledger_proof.Debug

  module Inputs = Make_inputs (Ledger_proof) (Init) (Store) ()

  include Coda.Make (Inputs)
end

module type Main_intf = sig
  module Inputs : Coda.Inputs_intf
end
