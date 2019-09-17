open Async_kernel
open Core_kernel
open Coda_base
open Coda_state
open Module_version

module Make
    (Ledger_proof : Coda_intf.Ledger_proof_intf)
    (Verifier : Coda_intf.Verifier_intf
                with type ledger_proof := Ledger_proof.t)
                                                        (Transaction_snark_work : sig
        module Stable : sig
          module V1 : sig
            type t [@@deriving bin_io, sexp, version]
          end
        end

        type t = Stable.V1.t

        module Checked : sig
          type t [@@deriving sexp]
        end
    end)
    (Staged_ledger_diff : Coda_intf.Staged_ledger_diff_intf
                          with type transaction_snark_work :=
                                      Transaction_snark_work.t
                           and type transaction_snark_work_checked :=
                                      Transaction_snark_work.Checked.t) :
  Coda_intf.External_transition_intf
  with type ledger_proof := Ledger_proof.t
   and type verifier := Verifier.t
   and type staged_ledger_diff := Staged_ledger_diff.t = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          { protocol_state: Protocol_state.Value.Stable.V1.t
          ; protocol_state_proof: Proof.Stable.V1.t sexp_opaque
          ; staged_ledger_diff: Staged_ledger_diff.Stable.V1.t }
        [@@deriving sexp, fields, bin_io, version]

        type external_transition = t

        let to_yojson
            {protocol_state; protocol_state_proof= _; staged_ledger_diff= _} =
          `Assoc
            [ ("protocol_state", Protocol_state.value_to_yojson protocol_state)
            ; ("protocol_state_proof", `String "<opaque>")
            ; ("staged_ledger_diff", `String "<opaque>") ]

        (* TODO: Important for bkase to review *)
        let compare t1 t2 =
          Protocol_state.Value.Stable.V1.compare t1.protocol_state
            t2.protocol_state

        let consensus_state {protocol_state; _} =
          Protocol_state.consensus_state protocol_state

        let state_hash {protocol_state; _} = Protocol_state.hash protocol_state

        let parent_hash {protocol_state; _} =
          Protocol_state.previous_state_hash protocol_state

        let proposer {staged_ledger_diff; _} =
          Staged_ledger_diff.creator staged_ledger_diff

        let user_commands {staged_ledger_diff; _} =
          Staged_ledger_diff.user_commands staged_ledger_diff

        let payments external_transition =
          List.filter
            (user_commands external_transition)
            ~f:
              (Fn.compose User_command_payload.is_payment User_command.payload)
      end

      include T
      include Comparable.Make (T)
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "external_transition"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  (* bin_io omitted *)
  type t = Stable.Latest.t =
    { protocol_state: Protocol_state.Value.Stable.V1.t
    ; protocol_state_proof: Proof.Stable.V1.t sexp_opaque
    ; staged_ledger_diff: Staged_ledger_diff.t }
  [@@deriving sexp]

  type external_transition = t

  [%%define_locally
  Stable.Latest.
    ( protocol_state
    , protocol_state_proof
    , staged_ledger_diff
    , consensus_state
    , state_hash
    , parent_hash
    , proposer
    , user_commands
    , payments
    , to_yojson )]

  include Comparable.Make (Stable.Latest)

  let create ~protocol_state ~protocol_state_proof ~staged_ledger_diff =
    {protocol_state; protocol_state_proof; staged_ledger_diff}

  let timestamp {protocol_state; _} =
    Protocol_state.blockchain_state protocol_state
    |> Blockchain_state.timestamp

  module Validated = struct
    include Stable.Latest
    module Stable = Stable

    let create_unsafe t = `I_swear_this_is_safe_see_my_comment t

    let forget_validation = Fn.id
  end

  module Validation = struct
    type ( 'time_received
         , 'proof
         , 'frontier_dependencies
         , 'staged_ledger_diff )
         t =
      'time_received * 'proof * 'frontier_dependencies * 'staged_ledger_diff
      constraint 'time_received = [`Time_received] * _ Truth.t
      constraint 'proof = [`Proof] * _ Truth.t
      constraint 'frontier_dependencies = [`Frontier_dependencies] * _ Truth.t
      constraint 'staged_ledger_diff = [`Staged_ledger_diff] * _ Truth.t

    type 'a all =
      ( [`Time_received] * 'a
      , [`Proof] * 'a
      , [`Frontier_dependencies] * 'a
      , [`Staged_ledger_diff] * 'a )
      t
      constraint 'a = _ Truth.t

    type fully_invalid = Truth.false_t all

    type fully_valid = Truth.true_t all

    type ( 'time_received
         , 'proof
         , 'frontier_dependencies
         , 'staged_ledger_diff )
         with_transition =
      (external_transition, State_hash.t) With_hash.t
      * ('time_received, 'proof, 'frontier_dependencies, 'staged_ledger_diff) t

    let all t =
      ( (`Time_received, t)
      , (`Proof, t)
      , (`Frontier_dependencies, t)
      , (`Staged_ledger_diff, t) )

    let fully_invalid = all Truth.False

    let fully_valid = all Truth.True

    let wrap t = (t, fully_invalid)

    let lift (t, _) = t

    let lower t v = (t, v)

    module Unsafe = struct
      let set_valid_time_received :
             ( [`Time_received] * Truth.false_t
             , 'proof
             , 'frontier_dependencies
             , 'staged_ledger_diff )
             t
          -> ( [`Time_received] * Truth.true_t
             , 'proof
             , 'frontier_dependencies
             , 'staged_ledger_diff )
             t = function
        | ( (`Time_received, Truth.False)
          , proof
          , frontier_dependencies
          , staged_ledger_diff ) ->
            ( (`Time_received, Truth.True)
            , proof
            , frontier_dependencies
            , staged_ledger_diff )
        | _ ->
            failwith "why can't this be refuted?"

      let set_valid_proof :
             ( 'time_received
             , [`Proof] * Truth.false_t
             , 'frontier_dependencies
             , 'staged_ledger_diff )
             t
          -> ( 'time_received
             , [`Proof] * Truth.true_t
             , 'frontier_dependencies
             , 'staged_ledger_diff )
             t = function
        | ( time_received
          , (`Proof, Truth.False)
          , frontier_dependencies
          , staged_ledger_diff ) ->
            ( time_received
            , (`Proof, Truth.True)
            , frontier_dependencies
            , staged_ledger_diff )
        | _ ->
            failwith "why can't this be refuted?"

      let set_valid_frontier_dependencies :
             ( 'time_received
             , 'proof
             , [`Frontier_dependencies] * Truth.false_t
             , 'staged_ledger_diff )
             t
          -> ( 'time_received
             , 'proof
             , [`Frontier_dependencies] * Truth.true_t
             , 'staged_ledger_diff )
             t = function
        | ( time_received
          , proof
          , (`Frontier_dependencies, Truth.False)
          , staged_ledger_diff ) ->
            ( time_received
            , proof
            , (`Frontier_dependencies, Truth.True)
            , staged_ledger_diff )
        | _ ->
            failwith "why can't this be refuted?"

      let set_valid_staged_ledger_diff :
             ( 'time_received
             , 'proof
             , 'frontier_dependencies
             , [`Staged_ledger_diff] * Truth.false_t )
             t
          -> ( 'time_received
             , 'proof
             , 'frontier_dependencies
             , [`Staged_ledger_diff] * Truth.true_t )
             t = function
        | ( time_received
          , proof
          , frontier_dependencies
          , (`Staged_ledger_diff, Truth.False) ) ->
            ( time_received
            , proof
            , frontier_dependencies
            , (`Staged_ledger_diff, Truth.True) )
        | _ ->
            failwith "why can't this be refuted?"
    end
  end

  type with_initial_validation =
    ( [`Time_received] * Truth.true_t
    , [`Proof] * Truth.true_t
    , [`Frontier_dependencies] * Truth.false_t
    , [`Staged_ledger_diff] * Truth.false_t )
    Validation.with_transition

  let skip_time_received_validation
      `This_transition_was_not_received_via_gossip (t, validation) =
    (t, Validation.Unsafe.set_valid_time_received validation)

  let validate_time_received (t, validation) ~time_received =
    let consensus_state =
      With_hash.data t |> protocol_state |> Protocol_state.consensus_state
    in
    let received_unix_timestamp =
      Block_time.to_span_since_epoch time_received |> Block_time.Span.to_ms
    in
    match
      Consensus.Hooks.received_at_valid_time consensus_state
        ~time_received:received_unix_timestamp
    with
    | Ok () ->
        Ok (t, Validation.Unsafe.set_valid_time_received validation)
    | Error err ->
        Error (`Invalid_time_received err)

  let skip_proof_validation `This_transition_was_generated_internally
      (t, validation) =
    (t, Validation.Unsafe.set_valid_proof validation)

  let validate_proof (t, validation) ~verifier =
    let open Blockchain_snark.Blockchain in
    let open Deferred.Let_syntax in
    let {protocol_state= state; protocol_state_proof= proof; _} =
      With_hash.data t
    in
    match%map Verifier.verify_blockchain_snark verifier {state; proof} with
    | Ok verified ->
        if verified then Ok (t, Validation.Unsafe.set_valid_proof validation)
        else Error `Invalid_proof
    | Error e ->
        Error (`Verifier_error e)

  let skip_frontier_dependencies_validation
      `This_transition_belongs_to_a_detached_subtree (t, validation) =
    (t, Validation.Unsafe.set_valid_frontier_dependencies validation)

  module Transition_frontier_validation (Transition_frontier : sig
    type t

    module Breadcrumb : sig
      type t

      val transition_with_hash : t -> (Validated.t, State_hash.t) With_hash.t
    end

    val root : t -> Breadcrumb.t

    val find : t -> State_hash.t -> Breadcrumb.t option
  end) =
  struct
    let validate_frontier_dependencies (t, validation) ~logger ~frontier =
      let open Result.Let_syntax in
      let hash = With_hash.hash t in
      let protocol_state = protocol_state (With_hash.data t) in
      let parent_hash = Protocol_state.previous_state_hash protocol_state in
      let root_protocol_state =
        Transition_frontier.root frontier
        |> Transition_frontier.Breadcrumb.transition_with_hash
        |> With_hash.data |> Validated.protocol_state
      in
      let%bind () =
        Result.ok_if_true
          (Transition_frontier.find frontier hash |> Option.is_none)
          ~error:`Already_in_frontier
      in
      let%bind () =
        Result.ok_if_true
          (Transition_frontier.find frontier parent_hash |> Option.is_some)
          ~error:`Parent_missing_from_frontier
      in
      let%map () =
        (* need pervasive (=) in scope for comparing polymorphic variant *)
        let ( = ) = Pervasives.( = ) in
        Result.ok_if_true
          ( `Take
          = Consensus.Hooks.select
              ~logger:
                (Logger.extend logger
                   [ ( "selection_context"
                     , `String
                         "External_transition.Transition_frontier_validation.validate_frontier_dependencies"
                     ) ])
              ~existing:(Protocol_state.consensus_state root_protocol_state)
              ~candidate:(Protocol_state.consensus_state protocol_state) )
          ~error:`Not_selected_over_frontier_root
      in
      (t, Validation.Unsafe.set_valid_frontier_dependencies validation)
  end

  module Staged_ledger_validation (Staged_ledger : sig
    type t

    module Staged_ledger_error : sig
      type t
    end

    val apply :
         t
      -> Staged_ledger_diff.t
      -> logger:Logger.t
      -> verifier:Verifier.t
      -> ( [`Hash_after_applying of Staged_ledger_hash.t]
           * [`Ledger_proof of (Ledger_proof.t * Transaction.t list) option]
           * [`Staged_ledger of t]
           * [`Pending_coinbase_data of bool * Currency.Amount.t]
         , Staged_ledger_error.t )
         Deferred.Result.t

    val current_ledger_proof : t -> Ledger_proof.t option
  end) =
  struct
    let target_hash_of_ledger_proof =
      let open Ledger_proof in
      Fn.compose statement_target statement

    let validate_staged_ledger_diff :
           ( 'time_received
           , 'proof
           , 'frontier_dependencies
           , [`Staged_ledger_diff] * Truth.false_t )
           Validation.with_transition
        -> logger:Logger.t
        -> verifier:Verifier.t
        -> parent_staged_ledger:Staged_ledger.t
        -> ( [`Just_emitted_a_proof of bool]
             * [ `External_transition_with_validation of
                 ( 'time_received
                 , 'proof
                 , 'frontier_dependencies
                 , [`Staged_ledger_diff] * Truth.true_t )
                 Validation.with_transition ]
             * [`Staged_ledger of Staged_ledger.t]
           , [ `Invalid_staged_ledger_diff of
               [ `Incorrect_target_staged_ledger_hash
               | `Incorrect_target_snarked_ledger_hash ]
               list
             | `Staged_ledger_application_failed of
               Staged_ledger.Staged_ledger_error.t ] )
           Deferred.Result.t =
     fun (t, validation) ~logger ~verifier ~parent_staged_ledger ->
      let open Deferred.Result.Let_syntax in
      let transition = With_hash.data t in
      let blockchain_state =
        Protocol_state.blockchain_state (protocol_state transition)
      in
      let staged_ledger_diff = staged_ledger_diff transition in
      let%bind ( `Hash_after_applying staged_ledger_hash
               , `Ledger_proof proof_opt
               , `Staged_ledger transitioned_staged_ledger
               , `Pending_coinbase_data _ ) =
        Staged_ledger.apply ~logger ~verifier parent_staged_ledger
          staged_ledger_diff
        |> Deferred.Result.map_error ~f:(fun e ->
               `Staged_ledger_application_failed e )
      in
      let target_ledger_hash =
        match proof_opt with
        | None ->
            Option.value_map
              (Staged_ledger.current_ledger_proof transitioned_staged_ledger)
              ~f:target_hash_of_ledger_proof
              ~default:
                (Frozen_ledger_hash.of_ledger_hash
                   (Ledger.merkle_root (Lazy.force Genesis_ledger.t)))
        | Some (proof, _) ->
            target_hash_of_ledger_proof proof
      in
      let maybe_errors =
        Option.all
          [ Option.some_if
              (not
                 (Staged_ledger_hash.equal staged_ledger_hash
                    (Blockchain_state.staged_ledger_hash blockchain_state)))
              `Incorrect_target_staged_ledger_hash
          ; Option.some_if
              (not
                 (Frozen_ledger_hash.equal target_ledger_hash
                    (Blockchain_state.snarked_ledger_hash blockchain_state)))
              `Incorrect_target_snarked_ledger_hash ]
      in
      Deferred.return
        ( match maybe_errors with
        | Some errors ->
            Error (`Invalid_staged_ledger_diff errors)
        | None ->
            Ok
              ( `Just_emitted_a_proof (Option.is_some proof_opt)
              , `External_transition_with_validation
                  (t, Validation.Unsafe.set_valid_staged_ledger_diff validation)
              , `Staged_ledger transitioned_staged_ledger ) )
  end

  let genesis =
    let genesis_protocol_state = With_hash.data Genesis_protocol_state.t in
    let pending_coinbases = Pending_coinbase.create () |> Or_error.ok_exn in
    let empty_diff =
      { Staged_ledger_diff.diff=
          ( { completed_works= []
            ; user_commands= []
            ; coinbase= Staged_ledger_diff.At_most_two.Zero }
          , None )
      ; prev_hash=
          Staged_ledger_hash.of_aux_ledger_and_coinbase_hash
            (Staged_ledger_hash.Aux_hash.of_bytes "")
            (Ledger.merkle_root Genesis_ledger.t)
            pending_coinbases
      ; creator= Account.public_key (snd (List.hd_exn Genesis_ledger.accounts))
      }
    in
    (* the genesis transition is assumed to be valid *)
    let (`I_swear_this_is_safe_see_my_comment transition) =
      Validated.create_unsafe
        (create ~protocol_state:genesis_protocol_state
           ~protocol_state_proof:Precomputed_values.base_proof
           ~staged_ledger_diff:empty_diff)
    in
    With_hash.of_data transition
      ~hash_data:(Fn.compose Protocol_state.hash protocol_state)
end

include Make (Ledger_proof) (Verifier) (Transaction_snark_work)
          (Staged_ledger_diff)
