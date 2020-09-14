open Async_kernel
open Core_kernel
open Coda_base
open Coda_state
open Coda_transition
open Network_peer

type t =
  { validated_transition: External_transition.Validated.t
  ; staged_ledger: Staged_ledger.t sexp_opaque
  ; just_emitted_a_proof: bool }
[@@deriving sexp, fields]

let to_yojson {validated_transition; staged_ledger= _; just_emitted_a_proof} =
  `Assoc
    [ ( "validated_transition"
      , External_transition.Validated.to_yojson validated_transition )
    ; ("staged_ledger", `String "<opaque>")
    ; ("just_emitted_a_proof", `Bool just_emitted_a_proof) ]

let create validated_transition staged_ledger =
  {validated_transition; staged_ledger; just_emitted_a_proof= false}

let build ~logger ~precomputed_values ~verifier ~trust_system ~parent
    ~transition:(transition_with_validation :
                  External_transition.Almost_validated.t) ~sender =
  O1trace.trace_recurring "Breadcrumb.build" (fun () ->
      let open Deferred.Let_syntax in
      match%bind
        External_transition.Staged_ledger_validation
        .validate_staged_ledger_diff ~logger ~precomputed_values ~verifier
          ~parent_staged_ledger:parent.staged_ledger
          ~parent_protocol_state:
            (External_transition.Validated.protocol_state
               parent.validated_transition)
          transition_with_validation
      with
      | Ok
          ( `Just_emitted_a_proof just_emitted_a_proof
          , `External_transition_with_validation
              fully_valid_external_transition
          , `Staged_ledger transitioned_staged_ledger ) ->
          return
            (Ok
               { validated_transition= fully_valid_external_transition
               ; staged_ledger= transitioned_staged_ledger
               ; just_emitted_a_proof })
      | Error (`Invalid_staged_ledger_diff errors) ->
          let reasons =
            String.concat ~sep:" && "
              (List.map errors ~f:(function
                | `Incorrect_target_staged_ledger_hash ->
                    "staged ledger hash"
                | `Incorrect_target_snarked_ledger_hash ->
                    "snarked ledger hash" ))
          in
          let message = "invalid staged ledger diff: incorrect " ^ reasons in
          let%map () =
            match sender with
            | None | Some Envelope.Sender.Local ->
                return ()
            | Some (Envelope.Sender.Remote (inet_addr, _peer_id)) ->
                Trust_system.(
                  record trust_system logger inet_addr
                    Actions.(Gossiped_invalid_transition, Some (message, [])))
          in
          Error (`Invalid_staged_ledger_hash (Error.of_string message))
      | Error
          (`Staged_ledger_application_failed
            (Staged_ledger.Staged_ledger_error.Unexpected e)) ->
          return (Error (`Fatal_error (Error.to_exn e)))
      | Error (`Staged_ledger_application_failed staged_ledger_error) ->
          let%map () =
            match sender with
            | None | Some Envelope.Sender.Local ->
                return ()
            | Some (Envelope.Sender.Remote (inet_addr, _peer_id)) ->
                let error_string =
                  Staged_ledger.Staged_ledger_error.to_string
                    staged_ledger_error
                in
                let make_actions action =
                  ( action
                  , Some
                      ( "Staged_ledger error: $error"
                      , [("error", `String error_string)] ) )
                in
                let open Trust_system.Actions in
                (* TODO : refine these actions (#2375) *)
                let open Staged_ledger.Pre_diff_info.Error in
                let action =
                  match staged_ledger_error with
                  | Invalid_proofs _ ->
                      make_actions Sent_invalid_proof
                  | Pre_diff (Verification_failed _) ->
                      make_actions Sent_invalid_signature_or_proof
                  | Pre_diff _ | Non_zero_fee_excess _ | Insufficient_work _ ->
                      make_actions Gossiped_invalid_transition
                  | Unexpected _ ->
                      failwith
                        "build: Unexpected staged ledger error should have \
                         been caught in another pattern"
                in
                Trust_system.record trust_system logger inet_addr action
          in
          Error
            (`Invalid_staged_ledger_diff
              (Staged_ledger.Staged_ledger_error.to_error staged_ledger_error))
  )

let lift f {validated_transition; _} = f validated_transition

let state_hash = lift External_transition.Validated.state_hash

let parent_hash = lift External_transition.Validated.parent_hash

let protocol_state = lift External_transition.Validated.protocol_state

let consensus_state = lift External_transition.Validated.consensus_state

let blockchain_state = lift External_transition.Validated.blockchain_state

let blockchain_length = lift External_transition.Validated.blockchain_length

let block_producer = lift External_transition.Validated.block_producer

let commands = lift External_transition.Validated.commands

let payments = lift External_transition.Validated.payments

let mask = Fn.compose Staged_ledger.ledger staged_ledger

let equal breadcrumb1 breadcrumb2 =
  State_hash.equal (state_hash breadcrumb1) (state_hash breadcrumb2)

let compare breadcrumb1 breadcrumb2 =
  State_hash.compare (state_hash breadcrumb1) (state_hash breadcrumb2)

let hash = Fn.compose State_hash.hash state_hash

let name t =
  Visualization.display_prefix_of_string @@ State_hash.to_base58_check
  @@ state_hash t

type display =
  { state_hash: string
  ; blockchain_state: Blockchain_state.display
  ; consensus_state: Consensus.Data.Consensus_state.display
  ; parent: string }
[@@deriving yojson]

let display t =
  let blockchain_state = Blockchain_state.display (blockchain_state t) in
  let consensus_state = consensus_state t in
  let parent =
    Visualization.display_prefix_of_string @@ State_hash.to_base58_check
    @@ parent_hash t
  in
  { state_hash= name t
  ; blockchain_state
  ; consensus_state= Consensus.Data.Consensus_state.display consensus_state
  ; parent }

let all_user_commands breadcrumbs =
  Sequence.fold (Sequence.of_list breadcrumbs) ~init:Signed_command.Set.empty
    ~f:(fun acc_set breadcrumb ->
      breadcrumb |> commands
      |> List.filter_map ~f:(fun {data; _} ->
             match data with
             | Snapp_command _ ->
                 None
             | User_command c ->
                 Some (Signed_command.forget_check c) )
      |> Signed_command.Set.of_list |> Set.union acc_set )

module For_tests = struct
  open Currency
  open Signature_lib

  (* Generate valid payments for each blockchain state by having
     each user send a payment of one coin to another random
     user if they have at least one coin*)
  let gen_payments staged_ledger accounts_with_secret_keys :
      Signed_command.With_valid_signature.t Sequence.t =
    let account_ids =
      List.map accounts_with_secret_keys ~f:(fun (_, account) ->
          Account.identifier account )
    in
    Sequence.filter_map (accounts_with_secret_keys |> Sequence.of_list)
      ~f:(fun (sender_sk, sender_account) ->
        let open Option.Let_syntax in
        let%bind sender_sk = sender_sk in
        let sender_keypair = Keypair.of_private_key_exn sender_sk in
        let token = sender_account.token_id in
        let%bind receiver =
          account_ids
          |> List.filter
               ~f:(Fn.compose (Token_id.equal token) Account_id.token_id)
          |> List.random_element
        in
        let receiver_pk = Account_id.public_key receiver in
        let nonce =
          let ledger = Staged_ledger.ledger staged_ledger in
          let status, account_location =
            Ledger.get_or_create_account_exn ledger
              (Account.identifier sender_account)
              sender_account
          in
          assert (status = `Existed) ;
          (Option.value_exn (Ledger.get ledger account_location)).nonce
        in
        let send_amount = Currency.Amount.of_int 1 in
        let sender_account_amount =
          sender_account.Account.Poly.balance |> Currency.Balance.to_amount
        in
        let%map _ = Currency.Amount.sub sender_account_amount send_amount in
        let sender_pk = Account.public_key sender_account in
        let payload : Signed_command.Payload.t =
          Signed_command.Payload.create ~fee:Fee.zero ~fee_token:Token_id.default
            ~fee_payer_pk:sender_pk ~nonce ~valid_until:None
            ~memo:Signed_command_memo.dummy
            ~body:
              (Payment
                 { source_pk= sender_pk
                 ; receiver_pk
                 ; token_id= token
                 ; amount= send_amount })
        in
        Signed_command.sign sender_keypair payload )

  let gen ?(logger = Logger.null ())
      ~(precomputed_values : Precomputed_values.t) ?verifier
      ?(trust_system = Trust_system.null ()) ~accounts_with_secret_keys :
      (t -> t Deferred.t) Quickcheck.Generator.t =
    let open Quickcheck.Let_syntax in
    let verifier =
      match verifier with
      | Some verifier ->
          verifier
      | None ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              Verifier.create ~logger
                ~proof_level:precomputed_values.proof_level ~conf_dir:None
                ~pids:(Child_processes.Termination.create_pid_table ()) )
    in
    let gen_slot_advancement = Int.gen_incl 1 10 in
    let%map make_next_consensus_state =
      Consensus_state_hooks.For_tests.gen_consensus_state ~gen_slot_advancement
        ~constraint_constants:
          precomputed_values.Precomputed_values.constraint_constants
        ~constants:precomputed_values.consensus_constants
    in
    fun parent_breadcrumb ->
      let open Deferred.Let_syntax in
      let parent_staged_ledger = parent_breadcrumb.staged_ledger in
      let transactions =
        gen_payments parent_staged_ledger accounts_with_secret_keys
        |> Sequence.map ~f:(fun x -> Command_transaction.User_command x)
      in
      let _, largest_account =
        List.max_elt accounts_with_secret_keys
          ~compare:(fun (_, acc1) (_, acc2) -> Account.compare acc1 acc2)
        |> Option.value_exn
      in
      let largest_account_public_key = Account.public_key largest_account in
      let get_completed_work stmts =
        let {Keypair.public_key; _} = Keypair.create () in
        let prover = Public_key.compress public_key in
        Some
          Transaction_snark_work.Checked.
            { fee= Fee.of_int 1
            ; proofs=
                One_or_two.map stmts ~f:(fun statement ->
                    Ledger_proof.create ~statement
                      ~sok_digest:Sok_message.Digest.default
                      ~proof:Proof.transaction_dummy )
            ; prover }
      in
      let current_state_view, state_and_body_hash =
        let prev_state =
          validated_transition parent_breadcrumb
          |> External_transition.Validated.protocol_state
        in
        let current_state_view =
          Protocol_state.body prev_state |> Protocol_state.Body.view
        in
        let body_hash =
          Protocol_state.body prev_state |> Protocol_state.Body.hash
        in
        ( current_state_view
        , (Protocol_state.hash_with_body ~body_hash prev_state, body_hash) )
      in
      let staged_ledger_diff =
        Staged_ledger.create_diff parent_staged_ledger ~logger
          ~constraint_constants:precomputed_values.constraint_constants
          ~coinbase_receiver:`Producer ~self:largest_account_public_key
          ~current_state_view ~transactions_by_fee:transactions
          ~get_completed_work
      in
      let%bind ( `Hash_after_applying next_staged_ledger_hash
               , `Ledger_proof ledger_proof_opt
               , `Staged_ledger _
               , `Pending_coinbase_data _ ) =
        match%bind
          Staged_ledger.apply_diff_unchecked parent_staged_ledger ~logger
            staged_ledger_diff
            ~constraint_constants:precomputed_values.constraint_constants
            ~current_state_view ~state_and_body_hash
        with
        | Ok r ->
            return r
        | Error e ->
            failwith (Staged_ledger.Staged_ledger_error.to_string e)
      in
      let previous_transition = parent_breadcrumb.validated_transition in
      let previous_protocol_state =
        previous_transition |> External_transition.Validated.protocol_state
      in
      let previous_ledger_hash =
        previous_protocol_state |> Protocol_state.blockchain_state
        |> Blockchain_state.snarked_ledger_hash
      in
      let next_ledger_hash =
        Option.value_map ledger_proof_opt
          ~f:(fun (proof, _) ->
            Ledger_proof.statement proof |> Ledger_proof.statement_target )
          ~default:previous_ledger_hash
      in
      let snarked_next_available_token =
        match ledger_proof_opt with
        | Some (proof, _) ->
            (Ledger_proof.statement proof).next_available_token_after
        | None ->
            previous_protocol_state |> Protocol_state.blockchain_state
            |> Blockchain_state.snarked_next_available_token
      in
      let next_blockchain_state =
        Blockchain_state.create_value
          ~timestamp:(Block_time.now @@ Block_time.Controller.basic ~logger)
          ~snarked_ledger_hash:next_ledger_hash ~snarked_next_available_token
          ~staged_ledger_hash:next_staged_ledger_hash
      in
      let previous_state_hash = Protocol_state.hash previous_protocol_state in
      let consensus_state =
        make_next_consensus_state ~snarked_ledger_hash:previous_ledger_hash
          ~previous_protocol_state:
            With_hash.
              {data= previous_protocol_state; hash= previous_state_hash}
      in
      let genesis_state_hash =
        Protocol_state.genesis_state_hash
          ~state_hash:(Some previous_state_hash) previous_protocol_state
      in
      let protocol_state =
        Protocol_state.create_value ~genesis_state_hash ~previous_state_hash
          ~blockchain_state:next_blockchain_state ~consensus_state
          ~constants:(Protocol_state.constants previous_protocol_state)
      in
      Protocol_version.(set_current zero) ;
      let next_external_transition =
        External_transition.For_tests.create ~protocol_state
          ~protocol_state_proof:Proof.blockchain_dummy
          ~staged_ledger_diff:(Staged_ledger_diff.forget staged_ledger_diff)
          ~validation_callback:Fn.ignore
          ~delta_transition_chain_proof:(previous_state_hash, []) ()
      in
      (* We manually created a verified an external_transition *)
      let (`I_swear_this_is_safe_see_my_comment
            next_verified_external_transition) =
        External_transition.Validated.create_unsafe next_external_transition
      in
      match%map
        build ~logger ~precomputed_values ~trust_system ~verifier
          ~parent:parent_breadcrumb
          ~transition:
            (External_transition.Validation.reset_staged_ledger_diff_validation
               next_verified_external_transition)
          ~sender:None
      with
      | Ok new_breadcrumb ->
          [%log info]
            ~metadata:
              [ ( "state_hash"
                , state_hash new_breadcrumb |> State_hash.to_yojson ) ]
            "Producing a breadcrumb with hash: $state_hash" ;
          new_breadcrumb
      | Error (`Fatal_error exn) ->
          raise exn
      | Error (`Invalid_staged_ledger_diff e) ->
          failwithf !"Invalid staged ledger diff: %{sexp:Error.t}" e ()
      | Error (`Invalid_staged_ledger_hash e) ->
          failwithf !"Invalid staged ledger hash: %{sexp:Error.t}" e ()

  let gen_non_deferred ?logger ~precomputed_values ?verifier ?trust_system
      ~accounts_with_secret_keys =
    let open Quickcheck.Generator.Let_syntax in
    let%map make_deferred =
      gen ?logger ?verifier ~precomputed_values ?trust_system
        ~accounts_with_secret_keys
    in
    fun x -> Async.Thread_safe.block_on_async_exn (fun () -> make_deferred x)

  let gen_seq ?logger ~precomputed_values ?verifier ?trust_system
      ~accounts_with_secret_keys n =
    let open Quickcheck.Generator.Let_syntax in
    let gen_list =
      List.gen_with_length n
        (gen ?logger ~precomputed_values ?verifier ?trust_system
           ~accounts_with_secret_keys)
    in
    let%map breadcrumbs_constructors = gen_list in
    fun root ->
      let open Deferred.Let_syntax in
      let%map _, ls =
        Deferred.List.fold breadcrumbs_constructors ~init:(root, [])
          ~f:(fun (previous, acc) make_breadcrumb ->
            let%map breadcrumb = make_breadcrumb previous in
            (breadcrumb, breadcrumb :: acc) )
      in
      List.rev ls
end
