open Async_kernel
open Core
open Mina_base
open Mina_state
open Mina_block
open Network_peer

let command_hashes_of_transition validated_transition =
  Mina_block.Validated.body validated_transition
  |> Body.staged_ledger_diff |> Staged_ledger_diff.command_hashes

type stored_transition =
  | Full of Mina_block.Validated.t
  | Lite of
      { header : Mina_block.Header.t
      ; hashes : State_hash.State_hashes.t
      ; delta_block_chain_proof : State_hash.t Mina_stdlib.Nonempty_list.t
      ; command_stats : Command_stats.t
      }

let state_hash_of_stored_transition = function
  | Full validated_transition ->
      Mina_block.Validated.state_hash validated_transition
  | Lite { hashes; _ } ->
      hashes.state_hash

module T = struct
  let id = "breadcrumb"

  type t =
    { validated_transition : stored_transition
    ; staged_ledger : Staged_ledger.t
    ; just_emitted_a_proof : bool
    ; transition_receipt_time : Time.t option
    ; staged_ledger_hash : Staged_ledger_hash.t
    ; accounts_created : Account_id.t list
    ; block_tag : Mina_block.Stable.Latest.t State_hash.File_storage.tag
    ; mutable staged_ledger_aux_and_pending_coinbases_cached :
        Network_types.Staged_ledger_aux_and_pending_coinbases.data_tag option
    ; transaction_hashes : Mina_transaction.Transaction_hash.Set.t
          (* Should be some for non-root *)
    ; application_data : Staged_ledger.Scan_state.Application_data.t option
    }
  [@@deriving fields]

  type 'a creator =
       validated_transition:Mina_block.Validated.t
    -> staged_ledger:Staged_ledger.t
    -> just_emitted_a_proof:bool
    -> transition_receipt_time:Time.t option
    -> accounts_created:Account_id.t list
    -> block_tag:Mina_block.Stable.Latest.t State_hash.File_storage.tag
    -> 'a

  let map_creator creator ~f ~validated_transition ~staged_ledger
      ~just_emitted_a_proof ~transition_receipt_time ~accounts_created
      ~block_tag =
    f
      (creator ~validated_transition ~staged_ledger ~just_emitted_a_proof
         ~transition_receipt_time ~accounts_created ~block_tag )

  let create ~validated_transition ~staged_ledger ~just_emitted_a_proof
      ~transition_receipt_time ~accounts_created ~block_tag =
    (* TODO This looks terrible, consider removing this in the hardfork by either
       removing staged_ledger_hash from the header or computing it consistently
       for the genesis block *)
    let staged_ledger_hash =
      if Mina_block.Validated.is_genesis validated_transition then
        Staged_ledger.hash staged_ledger
      else
        Mina_block.Validated.header validated_transition
        |> Mina_block.Header.protocol_state |> Protocol_state.blockchain_state
        |> Blockchain_state.staged_ledger_hash
    in
    { validated_transition = Full validated_transition
    ; staged_ledger
    ; just_emitted_a_proof
    ; transition_receipt_time
    ; staged_ledger_hash
    ; accounts_created
    ; block_tag
    ; staged_ledger_aux_and_pending_coinbases_cached = None
    ; transaction_hashes =
        command_hashes_of_transition validated_transition
        |> Mina_transaction.Transaction_hash.Set.of_list
    ; application_data = None
    }

  let to_yojson
      { validated_transition
      ; staged_ledger = _
      ; just_emitted_a_proof
      ; transition_receipt_time
      ; staged_ledger_hash = _
      ; accounts_created = _
      ; block_tag = _
      ; staged_ledger_aux_and_pending_coinbases_cached = _
      ; transaction_hashes
      ; application_data = _
      } =
    `Assoc
      [ ( "state_hash"
        , State_hash.to_yojson
          @@ state_hash_of_stored_transition validated_transition )
      ; ("just_emitted_a_proof", `Bool just_emitted_a_proof)
      ; ( "transition_receipt_time"
        , `String
            (Option.value_map transition_receipt_time ~default:"<not available>"
               ~f:(Time.to_string_iso8601_basic ~zone:Time.Zone.utc) ) )
      ; ( "transaction_hashes_unordered"
        , `List
            ( Mina_transaction.Transaction_hash.Set.to_list transaction_hashes
            |> List.map ~f:Mina_transaction.Transaction_hash.to_yojson ) )
      ]
end

[%%define_locally
T.
  ( staged_ledger
  , just_emitted_a_proof
  , transition_receipt_time
  , to_yojson
  , staged_ledger_hash
  , accounts_created
  , block_tag
  , staged_ledger_aux_and_pending_coinbases_cached )]

let header t =
  match T.validated_transition t with
  | Full validated_transition ->
      Mina_block.Validated.header validated_transition
  | Lite { header; _ } ->
      header

(* TODO: for better efficiency, add set of tx hashes to `maps_t`
   and use existing mechanism of mask handling to get accumulated lookups,
   then in transaction_status it will be necessary to only traverse
   all of the tips instead of all of the breadcrumbs. *)
let contains_transaction_by_hash t hash =
  Mina_transaction.Transaction_hash.Set.mem t.T.transaction_hashes hash

include Allocation_functor.Make.Basic (T)

let compute_block_trace_metadata transition_with_validation =
  (* No need to compute anything if internal tracing is disabled, will be dropped anyway *)
  if not @@ Internal_tracing.is_enabled () then []
  else
    let header =
      Mina_block.header
      @@ Mina_block.Validation.block transition_with_validation
    in
    let ps = Mina_block.Header.protocol_state header in
    let cs = Mina_state.Protocol_state.consensus_state ps in
    let open Consensus.Data.Consensus_state in
    [ ( "global_slot"
      , Mina_numbers.Global_slot_since_genesis.to_yojson
        @@ global_slot_since_genesis cs )
    ; ("slot", Unsigned_extended.UInt32.to_yojson @@ curr_slot cs)
    ; ( "previous_state_hash"
      , State_hash.to_yojson @@ Mina_state.Protocol_state.previous_state_hash ps
      )
    ; ("creator", Account.key_to_yojson @@ block_creator cs)
    ; ("winner", Account.key_to_yojson @@ block_stake_winner cs)
    ; ("coinbase_receiver", Account.key_to_yojson @@ coinbase_receiver cs)
    ]

let build ?skip_staged_ledger_verification ?transaction_pool_proxy ~logger
    ~precomputed_values ~verifier ~trust_system ~parent
    ~transition:(transition_with_validation : Mina_block.almost_valid_block)
    ~get_completed_work ~sender ~transition_receipt_time () =
  let state_hash =
    ( With_hash.hash
    @@ Mina_block.Validation.block_with_hash transition_with_validation )
      .state_hash
  in
  Internal_tracing.with_state_hash state_hash
  @@ fun () ->
  [%log internal] "Build_breadcrumb" ;
  let metadata = compute_block_trace_metadata transition_with_validation in
  [%log internal] "@block_metadata" ~metadata ;
  O1trace.thread "build_breadcrumb" (fun () ->
      let open Deferred.Let_syntax in
      match%bind
        Validation.validate_staged_ledger_diff ?skip_staged_ledger_verification
          ~get_completed_work ~logger ~precomputed_values ~verifier
          ~parent_staged_ledger:(staged_ledger parent)
          ~parent_protocol_state:
            (header parent |> Mina_block.Header.protocol_state)
          ?transaction_pool_proxy transition_with_validation
      with
      | Ok
          ( `Just_emitted_a_proof just_emitted_a_proof
          , `Block_with_validation fully_valid_block
          , `Staged_ledger transitioned_staged_ledger
          , `Accounts_created accounts_created
          , `Block_serialized block_tag
          , `Scan_state_application_data application_data ) ->
          [%log internal] "Create_breadcrumb" ;
          let validated_transition =
            Mina_block.Validated.lift fully_valid_block
          in
          Deferred.Result.return
            { T.validated_transition = Full validated_transition
            ; staged_ledger = transitioned_staged_ledger
            ; accounts_created
            ; just_emitted_a_proof
            ; transition_receipt_time
            ; block_tag
            ; application_data = Some application_data
            ; staged_ledger_hash =
                Mina_block.Validated.header validated_transition
                |> Mina_block.Header.protocol_state
                |> Protocol_state.blockchain_state
                |> Blockchain_state.staged_ledger_hash
            ; staged_ledger_aux_and_pending_coinbases_cached = None
            ; transaction_hashes =
                command_hashes_of_transition validated_transition
                |> Mina_transaction.Transaction_hash.Set.of_list
            }
      | Error `Invalid_body_reference ->
          let message = "invalid body reference" in
          let%map () =
            match sender with
            | None | Some Envelope.Sender.Local ->
                return ()
            | Some (Envelope.Sender.Remote peer) ->
                Trust_system.(
                  record trust_system logger peer
                    Actions.(Gossiped_invalid_transition, Some (message, [])))
          in
          Error (`Invalid_staged_ledger_diff (Error.of_string message))
      | Error (`Invalid_staged_ledger_diff errors) ->
          let reasons =
            String.concat ~sep:" && "
              (List.map errors ~f:(function
                | `Incorrect_target_staged_ledger_hash ->
                    "staged ledger hash"
                | `Incorrect_target_snarked_ledger_hash ->
                    "snarked ledger hash" ) )
          in
          let message = "invalid staged ledger diff: incorrect " ^ reasons in
          let%map () =
            match sender with
            | None | Some Envelope.Sender.Local ->
                return ()
            | Some (Envelope.Sender.Remote peer) ->
                Trust_system.(
                  record trust_system logger peer
                    Actions.(Gossiped_invalid_transition, Some (message, [])))
          in
          Error (`Invalid_staged_ledger_hash (Error.of_string message))
      | Error (`Staged_ledger_application_failed staged_ledger_error) ->
          let%map () =
            match sender with
            | None | Some Envelope.Sender.Local ->
                return ()
            | Some (Envelope.Sender.Remote peer) ->
                let error_string =
                  Staged_ledger.Staged_ledger_error.to_string
                    staged_ledger_error
                in
                let make_actions action =
                  ( action
                  , Some
                      ( "Staged_ledger error: $error"
                      , [ ("error", `String error_string) ] ) )
                in
                let open Trust_system.Actions in
                (* TODO : refine these actions (#2375) *)
                let open Staged_ledger.Pre_diff_info.Error in
                with_return (fun { return } ->
                    let action =
                      match staged_ledger_error with
                      | Couldn't_reach_verifier _ ->
                          return Deferred.unit
                      | Invalid_proofs _ ->
                          make_actions Sent_invalid_proof
                      | Pre_diff (Verification_failed _) ->
                          make_actions Sent_invalid_signature_or_proof
                      | Pre_diff _
                      | Non_zero_fee_excess _
                      | Insufficient_work _
                      | Mismatched_statuses _
                      | Invalid_public_key _
                      | ZkApps_exceed_limit _
                      | Unexpected _ ->
                          make_actions Gossiped_invalid_transition
                    in
                    Trust_system.record trust_system logger peer action )
          in
          Error
            (`Invalid_staged_ledger_diff
              (Staged_ledger.Staged_ledger_error.to_error staged_ledger_error)
              ) )

let command_stats t =
  match t.T.validated_transition with
  | Full validated_transition ->
      Command_stats.of_body @@ Mina_block.Validated.body @@ validated_transition
  | Lite { command_stats; _ } ->
      command_stats

let state_hash t = state_hash_of_stored_transition t.T.validated_transition

let protocol_state b = Mina_block.Header.protocol_state (header b)

let protocol_state_with_hashes breadcrumb =
  match breadcrumb.T.validated_transition with
  | Full validated_transition ->
      Mina_block.Validated.forget validated_transition
      |> With_hash.map
           ~f:(Fn.compose Mina_block.Header.protocol_state Mina_block.header)
  | Lite { hashes; header; _ } ->
      { With_hash.hash = hashes
      ; data = Mina_block.Header.protocol_state header
      }

let delta_block_chain_proof breadcrumb =
  match breadcrumb.T.validated_transition with
  | Full validated_transition ->
      Mina_block.Validated.delta_block_chain_proof validated_transition
  | Lite { delta_block_chain_proof; _ } ->
      delta_block_chain_proof

let consensus_state = Fn.compose Protocol_state.consensus_state protocol_state

let consensus_state_with_hashes breadcrumb =
  protocol_state_with_hashes breadcrumb
  |> With_hash.map ~f:Protocol_state.consensus_state

let parent_hash b = b |> protocol_state |> Protocol_state.previous_state_hash

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
  { state_hash : string
  ; blockchain_state : Blockchain_state.display
  ; consensus_state : Consensus.Data.Consensus_state.display
  ; parent : string
  }
[@@deriving yojson]

let display t =
  let protocol_state = t |> header |> Mina_block.Header.protocol_state in
  let blockchain_state =
    Blockchain_state.display (Protocol_state.blockchain_state protocol_state)
  in
  let consensus_state = Protocol_state.consensus_state protocol_state in
  let parent =
    t |> parent_hash |> State_hash.to_base58_check
    |> Visualization.display_prefix_of_string
  in
  { state_hash = name t
  ; blockchain_state
  ; consensus_state = Consensus.Data.Consensus_state.display consensus_state
  ; parent
  }

let staged_ledger_aux_and_pending_coinbases_at_hash_compute
    ~scan_state_protocol_states breadcrumb =
  let staged_ledger = staged_ledger breadcrumb in
  let scan_state = Staged_ledger.scan_state staged_ledger in
  let%map.Option protocol_states = scan_state_protocol_states scan_state in
  let staged_ledger_hash = staged_ledger_hash breadcrumb in
  let merkle_root = Staged_ledger_hash.ledger_hash staged_ledger_hash in
  let pending_coinbase =
    Staged_ledger.pending_coinbase_collection staged_ledger
  in
  let module Data =
    Network_types.Staged_ledger_aux_and_pending_coinbases.Data.Stable.Latest
  in
  (* Cache in frontier and return tag *)
  State_hash.File_storage.append_values_exn (state_hash breadcrumb)
    ~f:(fun writer ->
      State_hash.File_storage.write_value writer
        (module Data)
        ( Staged_ledger.Scan_state.Stable.V2.of_latest_exn scan_state
        , merkle_root
        , pending_coinbase
        , protocol_states ) )

let staged_ledger_aux_and_pending_coinbases ~scan_state_protocol_states
    breadcrumb :
    Network_types.Staged_ledger_aux_and_pending_coinbases.data_tag option =
  match staged_ledger_aux_and_pending_coinbases_cached breadcrumb with
  | Some res ->
      Some res
  | None ->
      let res =
        staged_ledger_aux_and_pending_coinbases_at_hash_compute
          ~scan_state_protocol_states breadcrumb
      in
      Option.iter res ~f:(fun tag ->
          breadcrumb.staged_ledger_aux_and_pending_coinbases_cached <- Some tag ) ;
      res

let to_maps (staged_ledger : Staged_ledger.t) =
  let ledger = Staged_ledger.ledger staged_ledger in
  Mina_ledger.Ledger.get_maps ledger
  |> Mina_ledger.Ledger.Mask_maps.to_stable
       ~ledger_depth:(Mina_ledger.Ledger.depth ledger)

let to_block_data_exn (breadcrumb : T.t) : Block_data.Full.t =
  let application_data =
    match breadcrumb.application_data with
    | Some application_data ->
        application_data
    | None ->
        failwithf "application_data is not set for breadcrumb %s"
          (State_hash.to_base58_check @@ state_hash breadcrumb)
          ()
  in
  { Block_data.Full.Stable.Latest.header = header breadcrumb
  ; block_tag = breadcrumb.block_tag
  ; delta_block_chain_proof = delta_block_chain_proof breadcrumb
  ; staged_ledger_data = (to_maps breadcrumb.staged_ledger, application_data)
  ; accounts_created = breadcrumb.accounts_created
  ; staged_ledger_aux_and_pending_coinbases_cached =
      breadcrumb.staged_ledger_aux_and_pending_coinbases_cached
  ; transaction_hashes_unordered =
      Mina_transaction.Transaction_hash.Set.to_list
        breadcrumb.transaction_hashes
  ; command_stats = command_stats breadcrumb
  }

let lighten ?(retain_application_data = false) (breadcrumb : T.t) : T.t =
  match breadcrumb.T.validated_transition with
  | Full validated_transition ->
      { breadcrumb with
        validated_transition =
          Lite
            { header = header breadcrumb
            ; hashes =
                Mina_block.Validated.forget validated_transition
                |> With_hash.hash
            ; delta_block_chain_proof = delta_block_chain_proof breadcrumb
            ; command_stats = command_stats breadcrumb
            }
      ; application_data =
          (let%bind.Option () = Option.some_if retain_application_data () in
           breadcrumb.application_data )
      }
  | Lite _ ->
      breadcrumb

(* Methods below are expensive if called on Lite transition *)
(* TODO consider strengthening usage of these on a type level
   to avoid calling them on Lite transitions without explicit conversion to Full *)

let validated_transition t =
  match t.T.validated_transition with
  | Full validated_transition ->
      validated_transition
  | Lite { hashes; delta_block_chain_proof; _ } ->
      let proof_cache_db =
        (* TODO: replace with actual DB  *)
        Proof_cache_tag.create_identity_db ()
      in
      let block_stable =
        State_hash.File_storage.read
          (module Mina_block.Stable.Latest)
          t.T.block_tag
        (* TODO consider using a more specific error *)
        |> Or_error.tag ~tag:"get_root_transition"
        |> Or_error.ok_exn
      in
      let block =
        Mina_block.write_all_proofs_to_disk
          ~signature_kind:Mina_signature_kind.t_DEPRECATED ~proof_cache_db
          block_stable
      in
      Mina_block.Validated.unsafe_of_trusted_block ~delta_block_chain_proof
        (`This_block_is_trusted_to_be_safe
          { With_hash.data = block; hash = hashes } )

let block_with_hash =
  Fn.compose Mina_block.Validated.forget validated_transition

let block = Fn.compose With_hash.data block_with_hash

let command_hashes t = command_hashes_of_transition (validated_transition t)

let valid_commands_hashed (t : T.t) =
  List.map2_exn
    (Mina_block.Validated.valid_commands @@ validated_transition t)
    (command_hashes t)
    ~f:(fun command hash ->
      With_status.map command
        ~f:
          (Fn.flip
             Mina_transaction.Transaction_hash.User_command_with_valid_signature
             .make hash ) )

let stored_transition_of_block_data ~state_hash (block_data : Block_data.Full.t)
    : stored_transition =
  Lite
    { hashes = { State_hash.State_hashes.state_hash; state_body_hash = None }
    ; delta_block_chain_proof = block_data.delta_block_chain_proof
    ; command_stats = block_data.command_stats
    ; header = block_data.header
    }

let of_block_data ~logger ~constraint_constants ~parent_staged_ledger
    ~state_hash (block_data : Block_data.Full.t) : (t, _) Deferred.Result.t =
  let maps_stable, application_data = block_data.staged_ledger_data in
  let parent_ledger = Staged_ledger.ledger parent_staged_ledger in
  let maps =
    Mina_ledger.Ledger.Mask_maps.of_stable
      ~ledger_depth:(Mina_ledger.Ledger.depth parent_ledger)
      maps_stable
  in
  let new_mask =
    Mina_ledger.Ledger.Mask.create
      ~depth:(Mina_ledger.Ledger.depth parent_ledger)
      ()
  in
  let new_ledger = Mina_ledger.Ledger.register_mask parent_ledger new_mask in
  Mina_ledger.Ledger.append_maps new_ledger maps ;
  let%map.Deferred.Result staged_ledger, res_opt =
    Staged_ledger.apply_to_scan_state ~logger ~skip_verification:true
      ~log_prefix:"of_block_data" ~ledger:new_ledger
      ~previous_pending_coinbase_collection:
        (Staged_ledger.pending_coinbase_collection parent_staged_ledger)
      ~previous_scan_state:(Staged_ledger.scan_state parent_staged_ledger)
      ~constraint_constants application_data
  in
  { T.validated_transition =
      stored_transition_of_block_data ~state_hash block_data
  ; staged_ledger
  ; accounts_created = block_data.accounts_created
  ; just_emitted_a_proof = Option.is_some res_opt
  ; transition_receipt_time = None
  ; block_tag = block_data.block_tag
  ; application_data = None
  ; staged_ledger_hash =
      Mina_block.Header.protocol_state block_data.header
      |> Protocol_state.blockchain_state |> Blockchain_state.staged_ledger_hash
  ; staged_ledger_aux_and_pending_coinbases_cached = None
  ; transaction_hashes =
      Mina_transaction.Transaction_hash.Set.of_list
        block_data.transaction_hashes_unordered
  }

module For_tests = struct
  open Currency
  open Signature_lib

  (* Generate valid payments for each blockchain state by having
     each user send a payment of one coin to another random
     user if they have at least one coin*)
  let gen_payments ~send_to_random_pk staged_ledger accounts_with_secret_keys :
      Signed_command.With_valid_signature.t Sequence.t =
    let account_ids =
      List.map accounts_with_secret_keys ~f:(fun (_, account) ->
          Account.identifier account )
    in
    (* One transaction is sent to a random address to make sure generated block
       contains a transaction to new account, not only to existing *)
    let random_pk =
      lazy
        ( Private_key.create () |> Public_key.of_private_key_exn
        |> Public_key.compress )
    in
    Sequence.filter_map (accounts_with_secret_keys |> Sequence.of_list)
      ~f:(fun (sender_sk, sender_account) ->
        let open Option.Let_syntax in
        let%bind sender_sk = sender_sk in
        let sender_keypair = Keypair.of_private_key_exn sender_sk in
        let token = sender_account.token_id in
        (* Send some transactions to the new accounts *)
        let%bind receiver_pk =
          if send_to_random_pk && not (Lazy.is_val random_pk) then
            Some (Lazy.force random_pk)
          else
            account_ids
            |> List.filter
                 ~f:(Fn.compose (Token_id.equal token) Account_id.token_id)
            |> List.random_element >>| Account_id.public_key
        in
        let nonce =
          let ledger = Staged_ledger.ledger staged_ledger in
          let status, account_location =
            Mina_ledger.Ledger.get_or_create_account ledger
              (Account.identifier sender_account)
              sender_account
            |> Or_error.ok_exn
          in
          assert ([%equal: [ `Existed | `Added ]] status `Existed) ;
          (Option.value_exn (Mina_ledger.Ledger.get ledger account_location))
            .nonce
        in
        let send_amount = Currency.Amount.of_nanomina_int_exn 1_000_000_001 in
        let sender_account_amount =
          sender_account.Account.balance |> Currency.Balance.to_amount
        in
        let%map _ = Currency.Amount.sub sender_account_amount send_amount in
        let sender_pk = Account.public_key sender_account in
        let payload : Signed_command.Payload.t =
          Signed_command.Payload.create ~fee:Fee.zero ~fee_payer_pk:sender_pk
            ~nonce ~valid_until:None ~memo:Signed_command_memo.dummy
            ~body:(Payment { receiver_pk; amount = send_amount })
        in
        Signed_command.sign ~signature_kind:Testnet sender_keypair payload )

  let gen ?(logger = Logger.null ()) ?(send_to_random_pk = false)
      ~(precomputed_values : Precomputed_values.t) ~verifier
      ?(trust_system = Trust_system.null ()) ~accounts_with_secret_keys () :
      (t -> t Deferred.t) Quickcheck.Generator.t =
    let open Quickcheck.Let_syntax in
    let%bind slot_advancement = Int.gen_incl 1 10 in
    let%bind make_next_consensus_state =
      Consensus_state_hooks.For_tests.gen_consensus_state ~slot_advancement
        ~constraint_constants:
          precomputed_values.Precomputed_values.constraint_constants
        ~constants:precomputed_values.consensus_constants
    in
    let zkapp_cmd_limit = None in
    let%map supercharge_coinbase = Quickcheck.Generator.bool in
    fun parent_breadcrumb ->
      let open Deferred.Let_syntax in
      let parent_staged_ledger = staged_ledger parent_breadcrumb in
      let transactions =
        gen_payments ~send_to_random_pk parent_staged_ledger
          accounts_with_secret_keys
        |> Sequence.map ~f:(fun x ->
               Mina_transaction.Transaction_hash
               .User_command_with_valid_signature
               .create @@ User_command.Signed_command x )
      in
      let _, largest_account =
        List.max_elt accounts_with_secret_keys
          ~compare:(fun (_, acc1) (_, acc2) -> Account.compare acc1 acc2)
        |> Option.value_exn
      in
      let largest_account_public_key = Account.public_key largest_account in
      let get_completed_work stmts =
        let { Keypair.public_key; _ } = Keypair.create () in
        let prover = Public_key.compress public_key in
        Some
          (Transaction_snark_work.Checked.create_unsafe
             { fee = Fee.of_nanomina_int_exn 1
             ; proofs =
                 One_or_two.map stmts ~f:(fun statement ->
                     Ledger_proof.Cached.create ~statement
                       ~sok_digest:Sok_message.Digest.default
                       ~proof:(Lazy.force Proof.For_tests.transaction_dummy_tag) )
             ; prover
             } )
      in
      let current_state_view, state_and_body_hash, parent_protocol_state_body =
        let prev_state =
          parent_breadcrumb |> block |> Mina_block.header
          |> Mina_block.Header.protocol_state
        in
        let prev_state_hashes = Protocol_state.hashes prev_state in
        let parent_protocol_state_body = Protocol_state.body prev_state in
        let current_state_view =
          Protocol_state.Body.view parent_protocol_state_body
        in
        ( current_state_view
        , ( prev_state_hashes.state_hash
          , Option.value_exn prev_state_hashes.state_body_hash )
        , parent_protocol_state_body )
      in
      let current_global_slot =
        Mina_numbers.Global_slot_since_genesis.add
          current_state_view.global_slot_since_genesis
          (Mina_numbers.Global_slot_span.of_int slot_advancement)
      in
      let coinbase_receiver = largest_account_public_key in
      let staged_ledger_diff, _invalid_txns =
        Staged_ledger.create_diff parent_staged_ledger ~logger
          ~global_slot:current_global_slot
          ~constraint_constants:precomputed_values.constraint_constants
          ~coinbase_receiver ~current_state_view ~supercharge_coinbase
          ~transactions_by_fee:transactions ~get_completed_work ~zkapp_cmd_limit
        |> Result.map_error ~f:Staged_ledger.Pre_diff_info.Error.to_error
        |> Or_error.ok_exn
      in
      let body =
        Mina_block.Body.create @@ Staged_ledger_diff.forget staged_ledger_diff
      in
      let ledger_and_proof =
        let%bind.Deferred.Result ( `Ledger new_ledger
                                 , `Accounts_created _
                                 , `Stack_update stack_update
                                 , `First_pass_ledger_end first_pass_ledger_end
                                 , `Witnesses witnesses
                                 , `Works works
                                 , `Pending_coinbase_update (is_new_stack, _) )
            =
          Staged_ledger.apply_diff_unchecked parent_staged_ledger
            ~global_slot:current_global_slot ~coinbase_receiver ~logger
            staged_ledger_diff
            ~constraint_constants:precomputed_values.constraint_constants
            ~parent_protocol_state_body ~state_and_body_hash
            ~supercharge_coinbase
            ~zkapp_cmd_limit_hardcap:
              precomputed_values.genesis_constants.zkapp_cmd_limit_hardcap
            ~signature_kind:Testnet
        in
        (* For test it is not important which file to write to *)
        let state_hash = Quickcheck.random_value State_hash.gen in
        let tagged_witnesses, tagged_works =
          State_hash.File_storage.write_values_exn state_hash ~f:(fun writer ->
              let witnesses' =
                Staged_ledger.Scan_state.Transaction_with_witness.persist_many
                  witnesses writer
              in
              let works' =
                Staged_ledger.Scan_state.Ledger_proof_with_sok_message
                .persist_many works writer
              in
              (witnesses', works') )
        in
        let scan_state_application_data =
          { Staged_ledger.Scan_state.Application_data.is_new_stack
          ; stack_update
          ; first_pass_ledger_end
          ; tagged_works
          ; tagged_witnesses
          }
        in
        Staged_ledger.apply_to_scan_state ~logger ~skip_verification:false
          ~log_prefix:"apply_diff" ~ledger:new_ledger
          ~previous_pending_coinbase_collection:
            (Staged_ledger.pending_coinbase_collection parent_staged_ledger)
          ~previous_scan_state:(Staged_ledger.scan_state parent_staged_ledger)
          ~constraint_constants:precomputed_values.constraint_constants
          scan_state_application_data
      in
      let%bind transitioned_staged_ledger, ledger_proof_opt =
        match%bind ledger_and_proof with
        | Ok r ->
            return r
        | Error e ->
            failwith (Staged_ledger.Staged_ledger_error.to_string e)
      in
      let previous_protocol_state =
        parent_breadcrumb |> block |> Mina_block.header
        |> Mina_block.Header.protocol_state
      in
      let previous_ledger_proof_stmt =
        previous_protocol_state |> Protocol_state.blockchain_state
        |> Blockchain_state.ledger_proof_statement
      in
      let ledger_proof_statement =
        Option.value_map ledger_proof_opt ~f:Ledger_proof.Tagged.statement
          ~default:previous_ledger_proof_stmt
      in
      let genesis_ledger_hash =
        previous_protocol_state |> Protocol_state.blockchain_state
        |> Blockchain_state.genesis_ledger_hash
      in
      let staged_ledger_hash = Staged_ledger.hash transitioned_staged_ledger in
      let next_blockchain_state =
        Blockchain_state.create_value
          ~timestamp:(Block_time.now @@ Block_time.Controller.basic ~logger)
          ~staged_ledger_hash ~genesis_ledger_hash
          ~body_reference:
            ( Body.compute_reference ~tag:Mina_net2.Bitswap_tag.(to_enum Body)
            @@ Body.read_all_proofs_from_disk body )
          ~ledger_proof_statement
      in
      let previous_state_hashes =
        Protocol_state.hashes previous_protocol_state
      in
      let consensus_state =
        make_next_consensus_state
          ~snarked_ledger_hash:
            (Blockchain_state.snarked_ledger_hash next_blockchain_state)
          ~previous_protocol_state:
            With_hash.
              { data = previous_protocol_state; hash = previous_state_hashes }
          ~coinbase_receiver ~supercharge_coinbase
      in
      let genesis_state_hash =
        Protocol_state.genesis_state_hash
          ~state_hash:(Some previous_state_hashes.state_hash)
          previous_protocol_state
      in
      let protocol_state =
        Protocol_state.create_value ~genesis_state_hash
          ~previous_state_hash:previous_state_hashes.state_hash
          ~blockchain_state:next_blockchain_state ~consensus_state
          ~constants:(Protocol_state.constants previous_protocol_state)
      in
      let next_block =
        let header =
          Mina_block.Header.create ~protocol_state
            ~protocol_state_proof:(Lazy.force Proof.blockchain_dummy)
            ~delta_block_chain_proof:(previous_state_hashes.state_hash, [])
            ()
        in
        (* We manually created a validated an block *)
        let block =
          { With_hash.hash = Protocol_state.hashes protocol_state
          ; data = Mina_block.create ~header ~body
          }
        in
        Mina_block.Validated.unsafe_of_trusted_block
          ~delta_block_chain_proof:
            (Mina_stdlib.Nonempty_list.singleton
               previous_state_hashes.state_hash )
          (`This_block_is_trusted_to_be_safe block)
      in
      let transition_receipt_time = Some (Time.now ()) in
      match%map
        build ~logger ~precomputed_values ~trust_system ~verifier
          ~get_completed_work:(Fn.const None) ~parent:parent_breadcrumb
          ~transition:
            ( next_block |> Mina_block.Validated.remember
            |> Validation.reset_staged_ledger_diff_validation )
          ~sender:None ~skip_staged_ledger_verification:`All
          ~transition_receipt_time ()
      with
      | Ok new_breadcrumb ->
          [%log info]
            ~metadata:
              [ ("state_hash", state_hash new_breadcrumb |> State_hash.to_yojson)
              ]
            "Producing a breadcrumb with hash: $state_hash" ;
          new_breadcrumb
      | Error (`Fatal_error exn) ->
          raise exn
      | Error (`Invalid_staged_ledger_diff e) ->
          failwithf !"Invalid staged ledger diff: %{sexp:Error.t}" e ()
      | Error (`Invalid_staged_ledger_hash e) ->
          failwithf !"Invalid staged ledger hash: %{sexp:Error.t}" e ()

  let gen_non_deferred ?logger ~precomputed_values ~verifier ?trust_system
      ~accounts_with_secret_keys () =
    let open Quickcheck.Generator.Let_syntax in
    let%map make_deferred =
      gen ?logger ~verifier ~precomputed_values ?trust_system
        ~accounts_with_secret_keys ()
    in
    fun x -> Async.Thread_safe.block_on_async_exn (fun () -> make_deferred x)

  let gen_seq ?logger ~precomputed_values ~verifier ?trust_system
      ~accounts_with_secret_keys n =
    let open Quickcheck.Generator.Let_syntax in
    let gen_list =
      List.gen_with_length n
        (gen ?logger ~precomputed_values ~verifier ?trust_system
           ~accounts_with_secret_keys () )
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

  let build_fail ?skip_staged_ledger_verification:_ ~logger:_
      ~precomputed_values:_ ~verifier:_ ~trust_system:_ ~parent:_ ~transition:_
      ~sender:_ ~transition_receipt_time:_ () :
      ( t
      , [> `Fatal_error of exn
        | `Invalid_staged_ledger_diff of Core_kernel.Error.t
        | `Invalid_staged_ledger_hash of Core_kernel.Error.t ] )
      result
      Async_kernel.Deferred.t =
    Deferred.return
      (Error (`Fatal_error (failwith "deliberately failing for unit tests")))
end
