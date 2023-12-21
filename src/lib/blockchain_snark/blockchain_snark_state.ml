open Core_kernel
open Snark_params
open Tick
open Mina_base
open Mina_state
open Pickles_types

include struct
  open Snarky_backendless.Request

  type _ t +=
    | Prev_state : Protocol_state.Value.t t
    | Prev_state_proof : (Nat.N2.n, Nat.N2.n) Pickles.Proof.t t
    | Transition : Snark_transition.Value.t t
    | Txn_snark : Transaction_snark.Statement.With_sok.t t
    | Txn_snark_proof : (Nat.N2.n, Nat.N2.n) Pickles.Proof.t t
end

module Witness = struct
  type t =
    { prev_state : Protocol_state.Value.t
    ; prev_state_proof : (Nat.N2.n, Nat.N2.n) Pickles.Proof.t
    ; transition : Snark_transition.Value.t
    ; txn_snark : Transaction_snark.Statement.With_sok.t
    ; txn_snark_proof : (Nat.N2.n, Nat.N2.n) Pickles.Proof.t
    }
end

let blockchain_handler on_unhandled
    { Witness.prev_state
    ; prev_state_proof
    ; transition
    ; txn_snark
    ; txn_snark_proof
    } =
  let open Snarky_backendless.Request in
  fun (With { request; respond } as r) ->
    let k x = respond (Provide x) in
    match request with
    | Prev_state ->
        k prev_state
    | Prev_state_proof ->
        k prev_state_proof
    | Transition ->
        k transition
    | Txn_snark ->
        k txn_snark
    | Txn_snark_proof ->
        k txn_snark_proof
    | _ ->
        on_unhandled r

let wrap_handler h w =
  match h with
  | None ->
      blockchain_handler
        (fun (Snarky_backendless.Request.With { respond; _ }) ->
          respond Unhandled )
        w
  | Some h ->
      (* TODO: Clean up the handler composition interface. *)
      fun r -> blockchain_handler h w r

let with_handler k w ?handler =
  let h = wrap_handler handler w in
  k ?handler:(Some h)

module Impl = Pickles.Impls.Step

let non_pc_registers_equal_var t1 t2 =
  Impl.make_checked (fun () ->
      let module F = Core_kernel.Field in
      let ( ! ) eq x1 x2 = Impl.run_checked (eq x1 x2) in
      let f eq acc field = eq (F.get field t1) (F.get field t2) :: acc in
      Registers.Fields.fold ~init:[]
        ~first_pass_ledger:(f !Frozen_ledger_hash.equal_var)
        ~second_pass_ledger:(f !Frozen_ledger_hash.equal_var)
        ~pending_coinbase_stack:(fun acc f ->
          let () = F.get f t1 and () = F.get f t2 in
          acc )
        ~local_state:(fun acc f ->
          Local_state.Checked.equal' (F.get f t1) (F.get f t2) @ acc )
      |> Impl.Boolean.all )

let txn_statement_ledger_hashes_equal
    (s1 : Transaction_snark.Statement.Checked.t)
    (s2 : Transaction_snark.Statement.Checked.t) =
  Impl.make_checked (fun () ->
      let module F = Core_kernel.Field in
      let ( ! ) x = Impl.run_checked x in
      let source_eq =
        !(non_pc_registers_equal_var
            { s1.source with pending_coinbase_stack = () }
            { s2.source with pending_coinbase_stack = () } )
      in
      let target_eq =
        !(non_pc_registers_equal_var
            { s1.target with pending_coinbase_stack = () }
            { s2.target with pending_coinbase_stack = () } )
      in
      let left_ledger_eq =
        !(Frozen_ledger_hash.equal_var s1.connecting_ledger_left
            s2.connecting_ledger_left )
      in
      let right_ledger_eq =
        !(Frozen_ledger_hash.equal_var s1.connecting_ledger_right
            s2.connecting_ledger_right )
      in
      let supply_increase_eq =
        !(Currency.Amount.Signed.Checked.equal s1.supply_increase
            s2.supply_increase )
      in
      Impl.Boolean.all
        [ source_eq
        ; target_eq
        ; left_ledger_eq
        ; right_ledger_eq
        ; supply_increase_eq
        ] )

(* Blockchain_snark ~old ~nonce ~ledger_snark ~ledger_hash ~timestamp ~new_hash
      Input:
        old : Blockchain.t
        old_snark : proof
        nonce : int
        work_snark : proof
        ledger_hash : Ledger_hash.t
        timestamp : Time.t
        new_hash : State_hash.t
      Witness:
        transition : Transition.t
      such that
        the old_snark verifies against old
        new = update_with_asserts(old, nonce, timestamp, ledger_hash)
        hash(new) = new_hash
        the work_snark verifies against the old.ledger_hash and new_ledger_hash
        new.timestamp > old.timestamp
        transition consensus data is valid
        new consensus state is a function of the old consensus state
*)
let%snarkydef_ step ~(logger : Logger.t)
    ~(proof_level : Genesis_constants.Proof_level.t)
    ~(constraint_constants : Genesis_constants.Constraint_constants.t) new_state
    : _ Tick.Checked.t =
  let new_state_hash =
    State_hash.var_of_hash_packed (Data_as_hash.hash new_state)
  in
  let%bind transition =
    with_label __LOC__ (fun () ->
        exists Snark_transition.typ ~request:(As_prover.return Transition) )
  in
  let%bind txn_snark =
    with_label __LOC__ (fun () ->
        exists Transaction_snark.Statement.With_sok.typ
          ~request:(As_prover.return Txn_snark) )
  in
  let%bind ( previous_state
           , previous_state_hash
           , previous_blockchain_proof_input
           , previous_state_body_hash ) =
    let%bind prev_state_ref =
      with_label __LOC__ (fun () ->
          exists (Typ.Internal.ref ()) ~request:(As_prover.return Prev_state) )
    in
    let%bind t =
      with_label __LOC__ (fun () ->
          exists
            (Protocol_state.typ ~constraint_constants)
            ~compute:(As_prover.Ref.get prev_state_ref) )
    in
    let%map previous_state_hash, body = Protocol_state.hash_checked t in
    let previous_blockchain_proof_input =
      Data_as_hash.make_unsafe
        (State_hash.var_to_field previous_state_hash)
        prev_state_ref
    in
    (t, previous_state_hash, previous_blockchain_proof_input, body)
  in
  let%bind txn_stmt_ledger_hashes_didn't_change =
    txn_statement_ledger_hashes_equal
      (previous_state |> Protocol_state.blockchain_state).ledger_proof_statement
      { txn_snark with sok_digest = () }
  in
  let%bind supply_increase =
    (* only increase the supply if the txn statement represents a new ledger transition *)
    Currency.Amount.(
      Signed.Checked.if_ txn_stmt_ledger_hashes_didn't_change
        ~then_:
          (Signed.create_var ~magnitude:(var_of_t zero) ~sgn:Sgn.Checked.pos)
        ~else_:txn_snark.supply_increase)
  in
  let%bind `Success updated_consensus_state, consensus_state =
    with_label __LOC__ (fun () ->
        Consensus_state_hooks.next_state_checked ~constraint_constants
          ~prev_state:previous_state ~prev_state_hash:previous_state_hash
          transition supply_increase )
  in
  let global_slot =
    Consensus.Data.Consensus_state.global_slot_since_genesis_var consensus_state
  in
  let supercharge_coinbase =
    Consensus.Data.Consensus_state.supercharge_coinbase_var consensus_state
  in
  let prev_pending_coinbase_root =
    previous_state |> Protocol_state.blockchain_state
    |> Blockchain_state.staged_ledger_hash
    |> Staged_ledger_hash.pending_coinbase_hash_var
  in
  let%bind genesis_state_hash =
    (*get the genesis state hash from previous state unless previous state is the genesis state itslef*)
    Protocol_state.genesis_state_hash_checked ~state_hash:previous_state_hash
      previous_state
  in
  let%bind new_state, is_base_case =
    let t =
      Protocol_state.create_var ~previous_state_hash ~genesis_state_hash
        ~blockchain_state:(Snark_transition.blockchain_state transition)
        ~consensus_state
        ~constants:(Protocol_state.constants previous_state)
    in
    let%bind is_base_case =
      Protocol_state.consensus_state t
      |> Consensus.Data.Consensus_state.is_genesis_state_var
    in
    let%bind previous_state_hash =
      match constraint_constants.fork with
      | Some { previous_state_hash = fork_prev; _ } ->
          State_hash.if_ is_base_case
            ~then_:(State_hash.var_of_t fork_prev)
            ~else_:t.previous_state_hash
      | None ->
          Checked.return t.previous_state_hash
    in
    let t = { t with previous_state_hash } in
    let%map () =
      let%bind h, _ = Protocol_state.hash_checked t in
      with_label __LOC__ (fun () -> State_hash.assert_equal h new_state_hash)
    in
    (t, is_base_case)
  in
  let%bind txn_snark_should_verify, success =
    let%bind new_pending_coinbase_hash, deleted_stack, no_coinbases_popped =
      let coinbase_receiver =
        Consensus.Data.Consensus_state.coinbase_receiver_var consensus_state
      in
      let%bind root_after_delete, deleted_stack =
        Pending_coinbase.Checked.pop_coinbases ~constraint_constants
          prev_pending_coinbase_root
          ~proof_emitted:(Boolean.not txn_stmt_ledger_hashes_didn't_change)
      in
      (*If snarked ledger hash did not change (no new ledger proof) then pop_coinbases should be a no-op*)
      let%bind no_coinbases_popped =
        Pending_coinbase.Hash.equal_var root_after_delete
          prev_pending_coinbase_root
      in
      (*new stack or update one*)
      let%map new_root =
        with_label __LOC__ (fun () ->
            Pending_coinbase.Checked.add_coinbase ~constraint_constants
              root_after_delete
              (Snark_transition.pending_coinbase_update transition)
              ~coinbase_receiver ~supercharge_coinbase previous_state_body_hash
              global_slot )
      in
      (new_root, deleted_stack, no_coinbases_popped)
    in
    let current_ledger_statement =
      (Protocol_state.blockchain_state new_state).ledger_proof_statement
    in
    let pending_coinbase_source_stack =
      Pending_coinbase.Stack.Checked.create_with deleted_stack
    in
    let%bind txn_snark_input_correct =
      let open Checked in
      let%bind () =
        Fee_excess.(assert_equal_checked (var_of_t zero) txn_snark.fee_excess)
      in
      let previous_ledger_statement =
        (Protocol_state.blockchain_state previous_state).ledger_proof_statement
      in
      let ledger_statement_valid =
        Impl.make_checked (fun () ->
            Snarked_ledger_state.(
              valid_ledgers_at_merge_checked
                (Statement_ledgers.of_statement previous_ledger_statement)
                (Statement_ledgers.of_statement current_ledger_statement)) )
      in
      (*TODO: Any assertion about the local state and sok digest
         in the statement required?*)
      all
        [ ledger_statement_valid
        ; Pending_coinbase.Stack.equal_var
            txn_snark.source.pending_coinbase_stack
            pending_coinbase_source_stack
        ; Pending_coinbase.Stack.equal_var
            txn_snark.target.pending_coinbase_stack deleted_stack
        ]
      >>= Boolean.all
    in
    let%bind nothing_changed =
      Boolean.all [ txn_stmt_ledger_hashes_didn't_change; no_coinbases_popped ]
    in
    let%bind correct_coinbase_status =
      let new_root =
        transition |> Snark_transition.blockchain_state
        |> Blockchain_state.staged_ledger_hash
        |> Staged_ledger_hash.pending_coinbase_hash_var
      in
      Pending_coinbase.Hash.equal_var new_pending_coinbase_hash new_root
    in
    let%bind () =
      with_label __LOC__ (fun () ->
          Boolean.Assert.any [ txn_snark_input_correct; nothing_changed ] )
    in
    let transaction_snark_should_verifiy = Boolean.not nothing_changed in
    let%bind result =
      Boolean.all [ updated_consensus_state; correct_coinbase_status ]
    in
    let%map () =
      as_prover
        As_prover.(
          Let_syntax.(
            let%map txn_snark_input_correct =
              read Boolean.typ txn_snark_input_correct
            and nothing_changed = read Boolean.typ nothing_changed
            and no_coinbases_popped = read Boolean.typ no_coinbases_popped
            and updated_consensus_state =
              read Boolean.typ updated_consensus_state
            and correct_coinbase_status =
              read Boolean.typ correct_coinbase_status
            and result = read Boolean.typ result in
            [%log trace]
              "blockchain snark update success: $result = \
               (transaction_snark_input_correct=$transaction_snark_input_correct \
               ∨ nothing_changed \
               (no_coinbases_popped=$no_coinbases_popped)=$nothing_changed) ∧ \
               updated_consensus_state=$updated_consensus_state ∧ \
               correct_coinbase_status=$correct_coinbase_status"
              ~metadata:
                [ ( "transaction_snark_input_correct"
                  , `Bool txn_snark_input_correct )
                ; ("nothing_changed", `Bool nothing_changed)
                ; ("updated_consensus_state", `Bool updated_consensus_state)
                ; ("correct_coinbase_status", `Bool correct_coinbase_status)
                ; ("result", `Bool result)
                ; ("no_coinbases_popped", `Bool no_coinbases_popped)
                ]))
    in
    (transaction_snark_should_verifiy, result)
  in
  let txn_snark_should_verify =
    match proof_level with
    | Check | None ->
        Boolean.false_
    | Full ->
        txn_snark_should_verify
  in
  let prev_should_verify =
    match proof_level with
    | Check | None ->
        Boolean.false_
    | Full ->
        Boolean.not is_base_case
  in
  let%bind () =
    with_label __LOC__ (fun () -> Boolean.Assert.any [ is_base_case; success ])
  in
  let%bind previous_blockchain_proof =
    exists (Typ.Internal.ref ()) ~request:(As_prover.return Prev_state_proof)
  in
  let%map txn_snark_proof =
    exists (Typ.Internal.ref ()) ~request:(As_prover.return Txn_snark_proof)
  in
  ( { Pickles.Inductive_rule.Previous_proof_statement.public_input =
        previous_blockchain_proof_input
    ; proof = previous_blockchain_proof
    ; proof_must_verify = prev_should_verify
    }
  , { Pickles.Inductive_rule.Previous_proof_statement.public_input = txn_snark
    ; proof = txn_snark_proof
    ; proof_must_verify = txn_snark_should_verify
    } )

module Statement = struct
  type t = Protocol_state.Value.t

  let to_field_elements (t : t) : Tick.Field.t array =
    [| (Protocol_state.hashes t).state_hash |]
end

module Statement_var = struct
  type t = Protocol_state.Value.t Data_as_hash.t
end

type tag = (Statement_var.t, Statement.t, Nat.N2.n, Nat.N1.n) Pickles.Tag.t

let typ = Data_as_hash.typ ~hash:(fun t -> (Protocol_state.hashes t).state_hash)

let check w ?handler ~proof_level ~constraint_constants new_state_hash :
    unit Or_error.t =
  let open Tick in
  check
    (Fn.flip handle (wrap_handler handler w) (fun () ->
         let%bind curr =
           exists typ ~compute:(As_prover.return new_state_hash)
         in
         step ~proof_level ~constraint_constants ~logger:(Logger.create ()) curr )
    )

let rule ~proof_level ~constraint_constants transaction_snark self :
    _ Pickles.Inductive_rule.t =
  { identifier = "step"
  ; prevs = [ self; transaction_snark ]
  ; main =
      (fun { public_input = x } ->
        let b1, b2 =
          Run.run_checked
            (step ~proof_level ~constraint_constants ~logger:(Logger.create ())
               x )
        in
        { previous_proof_statements = [ b1; b2 ]
        ; public_output = ()
        ; auxiliary_output = ()
        } )
  ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
  }

module type S = sig
  module Proof :
    Pickles.Proof_intf
      with type t = (Nat.N2.n, Nat.N2.n) Pickles.Proof.t
       and type statement = Protocol_state.Value.t

  val tag : tag

  val cache_handle : Pickles.Cache_handle.t

  open Nat

  val step :
       Witness.t
    -> ( Protocol_state.Value.t * (Transaction_snark.Statement.With_sok.t * unit)
       , N2.n * (N2.n * unit)
       , N1.n * (N5.n * unit)
       , Protocol_state.Value.t
       , (unit * unit * Proof.t) Async.Deferred.t )
       Pickles.Prover.t

  val constraint_system_digests : (string * Md5_lib.t) list Lazy.t
end

let verify ts ~key = Pickles.verify (module Nat.N2) (module Statement) key ts

let constraint_system_digests ~proof_level ~constraint_constants () =
  let digest = Tick.R1CS_constraint_system.digest in
  [ ( "blockchain-step"
    , digest
        (let main x =
           let open Tick in
           let%map _ =
             step ~proof_level ~constraint_constants ~logger:(Logger.create ())
               x
           in
           ()
         in
         Tick.constraint_system ~input_typ:typ
           ~return_typ:(Snarky_backendless.Typ.unit ())
           main ) )
  ]

module Make (T : sig
  val tag : Transaction_snark.tag

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val proof_level : Genesis_constants.Proof_level.t
end) : S = struct
  open T

  let tag, cache_handle, p, Pickles.Provers.[ step ] =
    Pickles.compile () ~cache:Cache_dir.cache ~public_input:(Input typ)
      ~override_wrap_domain:Pickles_base.Proofs_verified.N1
      ~auxiliary_typ:Typ.unit
      ~branches:(module Nat.N1)
      ~max_proofs_verified:(module Nat.N2)
      ~name:"blockchain-snark"
      ~constraint_constants:
        (Genesis_constants.Constraint_constants.to_snark_keys_header
           constraint_constants )
      ~choices:(fun ~self ->
        [ rule ~proof_level ~constraint_constants T.tag self ] )

  let step = with_handler step

  let constraint_system_digests =
    lazy (constraint_system_digests ~proof_level ~constraint_constants ())

  module Proof = (val p)
end
