open Core_kernel
open Mina_numbers

type 'extended relation =
  [ `Extends of 'extended
  | `Needs_ancestry
  | `Not_better of [ `Already_in_frontier | `Not_selected_over_root ] ]

let relation ~context frontier ~to_header candidate =
  let root_consensus_state =
    Transition_frontier.(
      Breadcrumb.consensus_state_with_hashes @@ root frontier)
  in
  let is_block_in_frontier =
    Fn.compose Option.is_some @@ Transition_frontier.find frontier
  in
  match
    Mina_block.Validation.validate_frontier_dependencies ~context
      ~root_consensus_state ~is_block_in_frontier ~to_header candidate
  with
  | Ok extended ->
      `Extends extended
  | Error `Parent_missing_from_frontier ->
      `Needs_ancestry
  | Error `Already_in_frontier ->
      `Not_better `Already_in_frontier
  | Error `Not_selected_over_frontier_root ->
      `Not_better `Not_selected_over_root

let to_consensus_state h =
  Mina_block.Validation.header_with_hash h
  |> With_hash.map
       ~f:
         (Fn.compose Mina_state.Protocol_state.consensus_state
            Mina_block.Header.protocol_state )

let orphans_anchor ~context:(module Context : Consensus.Intf.CONTEXT) frontier
    new_header =
  let root_consensus_state =
    Transition_frontier.root frontier
    |> Transition_frontier.Breadcrumb.consensus_state_with_hashes
  in
  let new_consensus_state = to_consensus_state new_header in
  match
    Consensus.Hooks.select
      ~context:(module Context)
      ~existing:root_consensus_state ~candidate:new_consensus_state
  with
  | `Keep ->
      false
  | `Take ->
      let slack = 5 in
      (* How far behind the frontier has to be for none of it to be worth
         keeping: [k] blocks, because that is how much of the chain the
         frontier holds. This used to be the literal 290 -- mainnet's k -- so
         on any network configured with a different k the check was measuring
         against the wrong chain. *)
      let k = Unsigned.UInt32.to_int Context.consensus_constants.k in
      if
        Length.to_int
          ( Transition_frontier.best_tip frontier
          |> Transition_frontier.Breadcrumb.consensus_state
          |> Consensus.Data.Consensus_state.blockchain_length )
        + k + slack
        < Length.to_int
            (Consensus.Data.Consensus_state.blockchain_length
               new_consensus_state.data )
      then (* Then our entire frontier is useless. *)
        true
      else
        let module Context = struct
          include Context

          let logger =
            Logger.extend logger
              [ ( "selection_context"
                , `String "Transition_handler.Catchup_classifier.orphans_anchor"
                )
              ]
        end in
        Consensus.Hooks.should_bootstrap
          ~context:(module Context)
          ~existing:root_consensus_state ~candidate:new_consensus_state

let classify ~context frontier header =
  if orphans_anchor ~context frontier header then `Orphans_anchor
  else
    ( relation ~context frontier ~to_header:Fn.id header
      :> [ `Orphans_anchor | _ relation ] )

let%test_module "Catchup_classifier" =
  ( module struct
    open Async

    let logger = Logger.null ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.For_tests.default
            ~constraint_constants:precomputed_values.constraint_constants
            ~logger ~proof_level:precomputed_values.proof_level () )

    module Context = struct
      let logger = logger

      let constraint_constants = precomputed_values.constraint_constants

      let consensus_constants = precomputed_values.consensus_constants
    end

    let k = Unsigned.UInt32.to_int Context.consensus_constants.k

    (* A frontier holding at most two blocks above its root, holding just its
       root, and a chain on that root long enough to outrun the frontier by
       more than k. *)
    let gen_frontier_and_chain =
      Transition_frontier.For_tests.gen_with_branch ~precomputed_values
        ~verifier ~max_length:2 ~frontier_size:1 ~branch_size:(k + 7) ()

    (* [breadcrumb]'s header as it arrives from the network. *)
    let header breadcrumb =
      Transition_frontier.Breadcrumb.validated_transition breadcrumb
      |> Mina_block.Validated.remember
      |> Mina_block.Validation.reset_frontier_dependencies_validation
      |> Mina_block.Validation.reset_staged_ledger_diff_validation
      |> Mina_block.Validation.to_header

    let outcome frontier breadcrumb =
      match classify ~context:(module Context) frontier (header breadcrumb) with
      | `Orphans_anchor ->
          "orphans anchor"
      | `Extends _ ->
          "extends"
      | `Needs_ancestry ->
          "needs ancestry"
      | `Not_better `Already_in_frontier ->
          "already in frontier"
      | `Not_better `Not_selected_over_root ->
          "not selected over root"

    let%test_unit "Each outcome is classified" =
      Quickcheck.test ~trials:1 gen_frontier_and_chain
        ~f:(fun (frontier, chain) ->
          let first = List.hd_exn chain in
          let second = List.nth_exn chain 1 in
          let last = List.last_exn chain in
          [%test_eq: string list]
            (List.map
               [ first; second; Transition_frontier.root frontier; last ]
               ~f:(outcome frontier) )
            [ "extends"
            ; "needs ancestry"
            ; "already in frontier"
            ; "orphans anchor"
            ] ;
          (* Adding four blocks to a frontier holding at most two above its
             root moves the root past the first. *)
          Thread_safe.block_on_async_exn (fun () ->
              Deferred.List.iter (List.take chain 4)
                ~f:(Transition_frontier.add_breadcrumb_exn frontier) ) ;
          [%test_eq: string] (outcome frontier first) "not selected over root" )
  end )
