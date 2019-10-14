open Async_kernel
open Core_kernel
open Coda_base
open Coda_state
open Module_version

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        { protocol_state: Protocol_state.Value.Stable.V1.t
        ; protocol_state_proof: Proof.Stable.V1.t sexp_opaque
        ; staged_ledger_diff: Staged_ledger_diff.Stable.V1.t
        ; delta_transition_chain_proof:
            State_hash.Stable.V1.t * State_body_hash.Stable.V1.t list }
      [@@deriving sexp, fields, bin_io, version]

      let to_yojson
          { protocol_state
          ; protocol_state_proof= _
          ; staged_ledger_diff= _
          ; delta_transition_chain_proof= _ } =
        `Assoc
          [ ("protocol_state", Protocol_state.value_to_yojson protocol_state)
          ; ("protocol_state_proof", `String "<opaque>")
          ; ("staged_ledger_diff", `String "<opaque>")
          ; ("delta_transition_chain_proof", `String "<opaque>") ]

      let delta_transition_chain_proof {delta_transition_chain_proof; _} =
        delta_transition_chain_proof

      let consensus_state {protocol_state; _} =
        Protocol_state.consensus_state protocol_state

      let global_slot t =
        consensus_state t |> Consensus.Data.Consensus_state.global_slot

      let blockchain_state {protocol_state; _} =
        Protocol_state.blockchain_state protocol_state

      let protocol_state_body_hash {protocol_state; _} =
        Protocol_state.body protocol_state |> Protocol_state.Body.hash

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
          ~f:(Fn.compose User_command_payload.is_payment User_command.payload)

      let compare =
        Comparable.lift
          (fun existing candidate ->
            (* To prevent the logger to spam a lot of messsages, the logger input is set to null *)
            if Consensus.Data.Consensus_state.Value.equal existing candidate
            then 0
            else if
              `Keep
              = Consensus.Hooks.select ~existing ~candidate
                  ~logger:(Logger.null ())
            then -1
            else 1 )
          ~f:consensus_state
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
  ; staged_ledger_diff: Staged_ledger_diff.t
  ; delta_transition_chain_proof: State_hash.t * State_body_hash.t list }
[@@deriving sexp]

type external_transition = t

[%%define_locally
Stable.Latest.
  ( protocol_state
  , protocol_state_body_hash
  , protocol_state_proof
  , delta_transition_chain_proof
  , blockchain_state
  , staged_ledger_diff
  , consensus_state
  , state_hash
  , parent_hash
  , proposer
  , user_commands
  , payments
  , to_yojson
  , global_slot )]

include Comparable.Make (Stable.Latest)

let create ~protocol_state ~protocol_state_proof ~staged_ledger_diff
    ~delta_transition_chain_proof =
  { protocol_state
  ; protocol_state_proof
  ; staged_ledger_diff
  ; delta_transition_chain_proof }

let timestamp {protocol_state; _} =
  Protocol_state.blockchain_state protocol_state |> Blockchain_state.timestamp

module Validation = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ( 'time_received
             , 'proof
             , 'delta_merkle_list
             , 'frontier_dependencies
             , 'staged_ledger_diff
             , 'delta_boundary )
             t =
          'time_received
          * 'proof
          * 'delta_merkle_list
          * 'frontier_dependencies
          * 'staged_ledger_diff
          * 'delta_boundary
          constraint 'time_received = [`Time_received] * (unit, _) Truth.t
          constraint 'proof = [`Proof] * (unit, _) Truth.t
          constraint
            'delta_merkle_list =
            [`Delta_merkle_list] * (State_hash.t Non_empty_list.t, _) Truth.t
          constraint
            'frontier_dependencies =
            [`Frontier_dependencies] * (unit, _) Truth.t
          constraint
            'staged_ledger_diff =
            [`Staged_ledger_diff] * (unit, _) Truth.t
          constraint 'delta_boundary = [`Delta_boundary] * (unit, _) Truth.t
        [@@deriving version]
      end

      include T
    end

    module Latest = V1
  end

  type ( 'time_received
       , 'proof
       , 'delta_merkle_list
       , 'frontier_dependencies
       , 'staged_ledger_diff
       , 'delta_boundary )
       t =
    ( 'time_received
    , 'proof
    , 'delta_merkle_list
    , 'frontier_dependencies
    , 'staged_ledger_diff
    , 'delta_boundary )
    Stable.Latest.t

  type fully_invalid =
    ( [`Time_received] * unit Truth.false_t
    , [`Proof] * unit Truth.false_t
    , [`Delta_merkle_list] * State_hash.t Non_empty_list.t Truth.false_t
    , [`Frontier_dependencies] * unit Truth.false_t
    , [`Staged_ledger_diff] * unit Truth.false_t
    , [`Delta_boundary] * unit Truth.false_t )
    t

  type fully_valid =
    ( [`Time_received] * unit Truth.true_t
    , [`Proof] * unit Truth.true_t
    , [`Delta_merkle_list] * State_hash.t Non_empty_list.t Truth.true_t
    , [`Frontier_dependencies] * unit Truth.true_t
    , [`Staged_ledger_diff] * unit Truth.true_t
    , [`Delta_boundary] * unit Truth.true_t )
    t

  type ( 'time_received
       , 'proof
       , 'delta_merkle_list
       , 'frontier_dependencies
       , 'staged_ledger_diff
       , 'delta_boundary )
       with_transition =
    (external_transition, State_hash.t) With_hash.t
    * ( 'time_received
      , 'proof
      , 'delta_merkle_list
      , 'frontier_dependencies
      , 'staged_ledger_diff
      , 'delta_boundary )
      t

  let fully_invalid =
    ( (`Time_received, Truth.False)
    , (`Proof, Truth.False)
    , (`Delta_merkle_list, Truth.False)
    , (`Frontier_dependencies, Truth.False)
    , (`Staged_ledger_diff, Truth.False)
    , (`Delta_boundary, Truth.False) )

  type initial_valid =
    ( [`Time_received] * unit Truth.true_t
    , [`Proof] * unit Truth.true_t
    , [`Delta_merkle_list] * State_hash.t Non_empty_list.t Truth.true_t
    , [`Frontier_dependencies] * unit Truth.false_t
    , [`Staged_ledger_diff] * unit Truth.false_t
    , [`Delta_boundary] * unit Truth.false_t )
    t

  type almost_valid =
    ( [`Time_received] * unit Truth.true_t
    , [`Proof] * unit Truth.true_t
    , [`Delta_merkle_list] * State_hash.t Non_empty_list.t Truth.true_t
    , [`Frontier_dependencies] * unit Truth.true_t
    , [`Staged_ledger_diff] * unit Truth.false_t
    , [`Delta_boundary] * unit Truth.true_t )
    t

  let wrap t = (t, fully_invalid)

  let extract_delta_transition_chain_witness = function
    | ( _
      , _
      , (`Delta_merkle_list, Truth.True delta_transition_chain_witness)
      , _
      , _
      , _ ) ->
        delta_transition_chain_witness
    | _ ->
        failwith "why can't this be refuted?"

  let reset_frontier_dependencies_validation (transition_with_hash, validation)
      =
    match validation with
    | ( time_received
      , proof
      , delta_merkle_list
      , (`Frontier_dependencies, Truth.True ())
      , staged_ledger_diff
      , delta_boundary ) ->
        ( transition_with_hash
        , ( time_received
          , proof
          , delta_merkle_list
          , (`Frontier_dependencies, Truth.False)
          , staged_ledger_diff
          , delta_boundary ) )
    | _ ->
        failwith "why can't this be refuted?"

  let reset_delta_boundary_validation (transition_with_hash, validation) =
    match validation with
    | ( time_received
      , proof
      , delta_merkle_list
      , frontier_dependencies
      , staged_ledger_diff
      , (`Delta_boundary, Truth.True ()) ) ->
        ( transition_with_hash
        , ( time_received
          , proof
          , delta_merkle_list
          , frontier_dependencies
          , staged_ledger_diff
          , (`Delta_boundary, Truth.False) ) )
    | _ ->
        failwith "why can't this be refuted?"

  let reset_staged_ledger_diff_validation (transition_with_hash, validation) =
    match validation with
    | ( time_received
      , proof
      , delta_merkle_list
      , frontier_dependencies
      , (`Staged_ledger_diff, Truth.True ())
      , delta_boundary ) ->
        ( transition_with_hash
        , ( time_received
          , proof
          , delta_merkle_list
          , frontier_dependencies
          , (`Staged_ledger_diff, Truth.False)
          , delta_boundary ) )
    | _ ->
        failwith "why can't this be refuted?"

  let forget_validation (t, _) = With_hash.data t

  module Unsafe = struct
    let set_valid_time_received :
           ( [`Time_received] * unit Truth.false_t
           , 'proof
           , 'delta_merkle_list
           , 'frontier_dependencies
           , 'staged_ledger_diff
           , 'delta_boundary )
           t
        -> ( [`Time_received] * unit Truth.true_t
           , 'proof
           , 'delta_merkle_list
           , 'frontier_dependencies
           , 'staged_ledger_diff
           , 'delta_boundary )
           t = function
      | ( (`Time_received, Truth.False)
        , proof
        , delta_merkle_list
        , frontier_dependencies
        , staged_ledger_diff
        , delta_boundary ) ->
          ( (`Time_received, Truth.True ())
          , proof
          , delta_merkle_list
          , frontier_dependencies
          , staged_ledger_diff
          , delta_boundary )
      | _ ->
          failwith "why can't this be refuted?"

    let set_valid_proof :
           ( 'time_received
           , [`Proof] * unit Truth.false_t
           , 'delta_merkle_list
           , 'frontier_dependencies
           , 'staged_ledger_diff
           , 'delta_boundary )
           t
        -> ( 'time_received
           , [`Proof] * unit Truth.true_t
           , 'delta_merkle_list
           , 'frontier_dependencies
           , 'staged_ledger_diff
           , 'delta_boundary )
           t = function
      | ( time_received
        , (`Proof, Truth.False)
        , delta_merkle_list
        , frontier_dependencies
        , staged_ledger_diff
        , delta_boundary ) ->
          ( time_received
          , (`Proof, Truth.True ())
          , delta_merkle_list
          , frontier_dependencies
          , staged_ledger_diff
          , delta_boundary )
      | _ ->
          failwith "why can't this be refuted?"

    let set_valid_delta_merkle_list :
           ( 'time_received
           , 'proof
           , [`Delta_merkle_list] * State_hash.t Non_empty_list.t Truth.false_t
           , 'frontier_dependencies
           , 'staged_ledger_diff
           , 'delta_boundary )
           t
        -> State_hash.t Non_empty_list.t
        -> ( 'time_received
           , 'proof
           , [`Delta_merkle_list] * State_hash.t Non_empty_list.t Truth.true_t
           , 'frontier_dependencies
           , 'staged_ledger_diff
           , 'delta_boundary )
           t =
     fun validation hashes ->
      match validation with
      | ( time_received
        , proof
        , (`Delta_merkle_list, Truth.False)
        , frontier_dependencies
        , staged_ledger_diff
        , delta_boundary ) ->
          ( time_received
          , proof
          , (`Delta_merkle_list, Truth.True hashes)
          , frontier_dependencies
          , staged_ledger_diff
          , delta_boundary )
      | _ ->
          failwith "why can't this be refuted?"

    let set_valid_frontier_dependencies :
           ( 'time_received
           , 'proof
           , 'delta_merkle_list
           , [`Frontier_dependencies] * unit Truth.false_t
           , 'staged_ledger_diff
           , 'delta_boundary )
           t
        -> ( 'time_received
           , 'proof
           , 'delta_merkle_list
           , [`Frontier_dependencies] * unit Truth.true_t
           , 'staged_ledger_diff
           , 'delta_boundary )
           t = function
      | ( time_received
        , proof
        , delta_merkle_list
        , (`Frontier_dependencies, Truth.False)
        , staged_ledger_diff
        , delta_boundary ) ->
          ( time_received
          , proof
          , delta_merkle_list
          , (`Frontier_dependencies, Truth.True ())
          , staged_ledger_diff
          , delta_boundary )
      | _ ->
          failwith "why can't this be refuted?"

    let set_valid_staged_ledger_diff :
           ( 'time_received
           , 'proof
           , 'delta_merkle_list
           , 'frontier_dependencies
           , [`Staged_ledger_diff] * unit Truth.false_t
           , 'delta_boundary )
           t
        -> ( 'time_received
           , 'proof
           , 'delta_merkle_list
           , 'frontier_dependencies
           , [`Staged_ledger_diff] * unit Truth.true_t
           , 'delta_boundary )
           t = function
      | ( time_received
        , proof
        , delta_merkle_list
        , frontier_dependencies
        , (`Staged_ledger_diff, Truth.False)
        , delta_boundary ) ->
          ( time_received
          , proof
          , delta_merkle_list
          , frontier_dependencies
          , (`Staged_ledger_diff, Truth.True ())
          , delta_boundary )
      | _ ->
          failwith "why can't this be refuted?"

    let set_valid_delta_boundary :
           ( 'time_received
           , 'proof
           , 'delta_merkle_list
           , 'frontier_dependencies
           , 'staged_ledger_diff
           , [`Delta_boundary] * unit Truth.false_t )
           t
        -> ( 'time_received
           , 'proof
           , 'delta_merkle_list
           , 'frontier_dependencies
           , 'staged_ledger_diff
           , [`Delta_boundary] * unit Truth.true_t )
           t = function
      | ( time_received
        , proof
        , delta_merkle_list
        , frontier_dependencies
        , staged_ledger_diff
        , (`Delta_boundary, Truth.False) ) ->
          ( time_received
          , proof
          , delta_merkle_list
          , frontier_dependencies
          , staged_ledger_diff
          , (`Delta_boundary, Truth.True ()) )
      | _ ->
          failwith "why can't this be refuted?"
  end
end

let skip_time_received_validation `This_transition_was_not_received_via_gossip
    (t, validation) =
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

let skip_delta_merkle_list_validation
    `This_transition_was_not_received_via_gossip (t, validation) =
  let previous_protocol_state_hash = With_hash.data t |> parent_hash in
  ( t
  , Validation.Unsafe.set_valid_delta_merkle_list validation
      (Non_empty_list.singleton previous_protocol_state_hash) )

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

let validate_delta_merkle_list (t, validation) =
  let transition = With_hash.data t in
  match
    Transition_chain_verifier.verify ~target_hash:(parent_hash transition)
      ~transition_chain_proof:transition.delta_transition_chain_proof
  with
  | Some hashes ->
      Ok (t, Validation.Unsafe.set_valid_delta_merkle_list validation hashes)
  | None ->
      Error `Invalid_delta_transition_chain_proof

let skip_frontier_dependencies_validation
    `This_transition_belongs_to_a_detached_subtree (t, validation) =
  (t, Validation.Unsafe.set_valid_frontier_dependencies validation)

let validate_staged_ledger_hash
    (`Staged_ledger_already_materialized staged_ledger_hash) (t, validation) =
  if
    Staged_ledger_hash.equal staged_ledger_hash
      (Blockchain_state.staged_ledger_hash
         (blockchain_state (With_hash.data t)))
  then Ok (t, Validation.Unsafe.set_valid_staged_ledger_diff validation)
  else Error `Staged_ledger_hash_mismatch

let skip_staged_ledger_diff_validation
    `This_transition_has_a_trusted_staged_ledger (t, validation) =
  (t, Validation.Unsafe.set_valid_staged_ledger_diff validation)

let skip_delta_boundary_validation `This_transition_was_not_received_via_gossip
    (t, validation) =
  (t, Validation.Unsafe.set_valid_delta_boundary validation)

module With_validation = struct
  let state_hash (t, _) = With_hash.hash t

  let lift f (t, _) = With_hash.data t |> f

  let protocol_state t = lift protocol_state t

  let protocol_state_body_hash t = lift protocol_state_body_hash t

  let protocol_state_proof t = lift protocol_state_proof t

  let blockchain_state t = lift blockchain_state t

  let staged_ledger_diff t = lift staged_ledger_diff t

  let consensus_state t = lift consensus_state t

  let parent_hash t = lift parent_hash t

  let proposer t = lift proposer t

  let user_commands t = lift user_commands t

  let payments t = lift payments t

  let delta_transition_chain_proof t = lift delta_transition_chain_proof t

  let global_slot t = lift global_slot t
end

module Initial_validated = struct
  type t =
    (external_transition, State_hash.t) With_hash.t * Validation.initial_valid

  include With_validation
end

module Almost_validated = struct
  type t =
    (external_transition, State_hash.t) With_hash.t * Validation.almost_valid

  include With_validation
end

module Validated = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          (Stable.V1.t, State_hash.Stable.V1.t) With_hash.Stable.V1.t
          * ( [`Time_received]
              * (unit, Truth.True.Stable.V1.t) Truth.Stable.V1.t
            , [`Proof] * (unit, Truth.True.Stable.V1.t) Truth.Stable.V1.t
            , [`Delta_merkle_list]
              * ( State_hash.Stable.V1.t Non_empty_list.Stable.V1.t
                , Truth.True.Stable.V1.t )
                Truth.Stable.V1.t
            , [`Frontier_dependencies]
              * (unit, Truth.True.Stable.V1.t) Truth.Stable.V1.t
            , [`Staged_ledger_diff]
              * (unit, Truth.True.Stable.V1.t) Truth.Stable.V1.t
            , [`Delta_boundary]
              * (unit, Truth.True.Stable.V1.t) Truth.Stable.V1.t )
            Validation.Stable.V1.t
        [@@deriving version]

        type erased =
          ( Stable.Latest.t
          , State_hash.Stable.Latest.t )
          With_hash.Stable.Latest.t
          * State_hash.Stable.Latest.t Non_empty_list.Stable.Latest.t
        [@@deriving sexp, bin_io]

        let erase (transition_with_hash, validation) =
          ( transition_with_hash
          , Validation.extract_delta_transition_chain_witness validation )

        let elaborate (transition_with_hash, delta_transition_chain_witness) =
          ( transition_with_hash
          , ( (`Time_received, Truth.True ())
            , (`Proof, Truth.True ())
            , (`Delta_merkle_list, Truth.True delta_transition_chain_witness)
            , (`Frontier_dependencies, Truth.True ())
            , (`Staged_ledger_diff, Truth.True ())
            , (`Delta_boundary, Truth.True ()) ) )

        include Sexpable.Of_sexpable (struct
                    type t = erased [@@deriving sexp]
                  end)
                  (struct
                    type nonrec t = t

                    let of_sexpable = elaborate

                    let to_sexpable = erase
                  end)

        include Binable.Of_binable (struct
                    type t = erased [@@deriving bin_io]
                  end)
                  (struct
                    type nonrec t = t

                    let of_binable = elaborate

                    let to_binable = erase
                  end)

        let compare (t1, _) (t2, _) =
          compare (With_hash.data t1) (With_hash.data t2)

        let to_yojson (transition_with_hash, _) =
          With_hash.to_yojson to_yojson State_hash.to_yojson
            transition_with_hash

        let create_unsafe t =
          `I_swear_this_is_safe_see_my_comment
            ( Validation.wrap (With_hash.of_data t ~hash_data:state_hash)
            |> skip_time_received_validation
                 `This_transition_was_not_received_via_gossip
            |> skip_proof_validation `This_transition_was_generated_internally
            |> skip_delta_merkle_list_validation
                 `This_transition_was_not_received_via_gossip
            |> skip_frontier_dependencies_validation
                 `This_transition_belongs_to_a_detached_subtree
            |> skip_staged_ledger_diff_validation
                 `This_transition_has_a_trusted_staged_ledger
            |> skip_delta_boundary_validation
                 `This_transition_was_not_received_via_gossip )

        include With_validation
      end

      include T
      include Comparable.Make (T)
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "external_transition_validated"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  type t = Stable.Latest.t

  [%%define_locally
  Stable.Latest.
    ( sexp_of_t
    , t_of_sexp
    , create_unsafe
    , protocol_state
    , protocol_state_body_hash
    , delta_transition_chain_proof
    , protocol_state_proof
    , blockchain_state
    , staged_ledger_diff
    , consensus_state
    , state_hash
    , parent_hash
    , proposer
    , user_commands
    , payments
    , to_yojson
    , global_slot )]

  include Comparable.Make (Stable.Latest)

  let degenerate_to_initial_validated t =
    t |> Validation.reset_frontier_dependencies_validation
    |> Validation.reset_delta_boundary_validation
    |> Validation.reset_staged_ledger_diff_validation
end

module Transition_frontier_validation (Transition_frontier : sig
  type t

  module Breadcrumb : sig
    type t

    val validated_transition : t -> Validated.t

    val global_slot : t -> int
  end

  val root : t -> Breadcrumb.t

  val find : t -> State_hash.t -> Breadcrumb.t option

  val find_in_frontier_or_root_history :
    t -> State_hash.t -> Breadcrumb.t option
end) =
struct
  let validate_frontier_dependencies (t, validation) ~logger ~frontier =
    let open Result.Let_syntax in
    let hash = With_hash.hash t in
    let protocol_state = protocol_state (With_hash.data t) in
    let parent_hash = Protocol_state.previous_state_hash protocol_state in
    let root_protocol_state =
      Transition_frontier.root frontier
      |> Transition_frontier.Breadcrumb.validated_transition
      |> Validated.protocol_state
    in
    let%bind () =
      Result.ok_if_true
        (Transition_frontier.find frontier hash |> Option.is_none)
        ~error:`Already_in_frontier
    in
    let%bind () =
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
    let%map () =
      Result.ok_if_true
        (Transition_frontier.find frontier parent_hash |> Option.is_some)
        ~error:`Parent_missing_from_frontier
    in
    (t, Validation.Unsafe.set_valid_frontier_dependencies validation)

  let validate_delta_boundary (t, validation) ~frontier =
    let open Int in
    let open Result.Let_syntax in
    let global_slot =
      t |> With_hash.data |> consensus_state
      |> Consensus.Data.Consensus_state.global_slot
    in
    let delta_transition_chain_witness =
      Validation.extract_delta_transition_chain_witness validation
      |> Non_empty_list.rev
    in
    let%bind () =
      let open Option.Let_syntax in
      let boundary_hash = Non_empty_list.head delta_transition_chain_witness in
      if
        State_hash.equal boundary_hash
          (With_hash.hash (force Genesis_protocol_state.t))
      then Ok ()
      else
        match
          let%map boundary_transition =
            Transition_frontier.find_in_frontier_or_root_history frontier
              boundary_hash
          in
          let boundary_slot =
            Transition_frontier.Breadcrumb.global_slot boundary_transition
          in
          boundary_slot <= global_slot - Consensus.Constants.delta
        with
        | None | Some true ->
            Ok ()
        | Some false ->
            Error `Missing_transitions_in_delta_transition_chain
    in
    let%bind () =
      let open Option.Let_syntax in
      match
        let%bind oldest_hash =
          Non_empty_list.tail delta_transition_chain_witness |> List.hd
        in
        let%map oldest_transition =
          Transition_frontier.find_in_frontier_or_root_history frontier
            oldest_hash
        in
        let oldest_slot =
          Transition_frontier.Breadcrumb.global_slot oldest_transition
        in
        oldest_slot > global_slot - Consensus.Constants.delta
      with
      | None | Some true ->
          Ok ()
      | Some false ->
          Error `Including_unnecessary_transitions_in_delta_transition_chain
    in
    return @@ (t, Validation.Unsafe.set_valid_delta_boundary validation)
end

module Staged_ledger_validation = struct
  let target_hash_of_ledger_proof =
    let open Ledger_proof in
    Fn.compose statement_target statement

  let validate_staged_ledger_diff :
         ( 'time_received
         , 'proof
         , 'delta_merkle_list
         , 'frontier_dependencies
         , [`Staged_ledger_diff] * unit Truth.false_t
         , 'delta_boundary )
         Validation.with_transition
      -> logger:Logger.t
      -> verifier:Verifier.t
      -> parent_staged_ledger:Staged_ledger.t
      -> parent_protocol_state:Protocol_state.value
      -> ( [`Just_emitted_a_proof of bool]
           * [ `External_transition_with_validation of
               ( 'time_received
               , 'proof
               , 'delta_merkle_list
               , 'frontier_dependencies
               , [`Staged_ledger_diff] * unit Truth.true_t
               , 'delta_boundary )
               Validation.with_transition ]
           * [`Staged_ledger of Staged_ledger.t]
         , [ `Invalid_staged_ledger_diff of
             [ `Incorrect_target_staged_ledger_hash
             | `Incorrect_target_snarked_ledger_hash
             | `Incorrect_staged_ledger_diff_state_body_hash ]
             list
           | `Staged_ledger_application_failed of
             Staged_ledger.Staged_ledger_error.t ] )
         Deferred.Result.t =
   fun (t, validation) ~logger ~verifier ~parent_staged_ledger
       ~parent_protocol_state ->
    let open Deferred.Result.Let_syntax in
    let transition = With_hash.data t in
    let blockchain_state =
      Protocol_state.blockchain_state (protocol_state transition)
    in
    let staged_ledger_diff = staged_ledger_diff transition in
    let diff_state_body_hash =
      Staged_ledger_diff.state_body_hash staged_ledger_diff
    in
    let parent_state_body_hash =
      Protocol_state.(Body.hash @@ body parent_protocol_state)
    in
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
            `Incorrect_target_snarked_ledger_hash
        ; Option.some_if
            (State_body_hash.equal diff_state_body_hash parent_state_body_hash)
            `Incorrect_staged_ledger_diff_state_body_hash ]
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
