open Core_kernel
open Coda_base

module Make (Inputs : sig
  include Inputs.Inputs_intf

  module Breadcrumb :
    Coda_intf.Transition_frontier_breadcrumb_intf
    with type mostly_validated_external_transition :=
                ( [`Time_received] * Truth.true_t
                , [`Proof] * Truth.true_t
                , [`Frontier_dependencies] * Truth.true_t
                , [`Staged_ledger_diff] * Truth.false_t )
                External_transition.Validation.with_transition
     and type external_transition_validated := External_transition.Validated.t
     and type staged_ledger := Staged_ledger.t
     and type verifier := Verifier.t
end) :
  Coda_intf.Transition_frontier_diff_intf
  with type breadcrumb := Inputs.Breadcrumb.t
   and type transaction_snark_scan_state := Inputs.Staged_ledger.Scan_state.t
   and type external_transition_validated :=
              Inputs.External_transition.Validated.t = struct
  open Inputs

  (* TODO: Remove New_frontier. 
    Each transition frontier extension should be initialized by the input, the root breadcrumb *)
  type t =
    | New_breadcrumb of Breadcrumb.t
        (** Triggered when a new breadcrumb is added without changing the root or best_tip *)
    | New_frontier of Breadcrumb.t
        (** First breadcrumb to become the root of the frontier  *)
    | New_best_tip of
        { old_root: Breadcrumb.t
        ; old_root_length: int
        ; new_root: Breadcrumb.t
              (** Same as old root if the root doesn't change *)
        ; added_to_best_tip_path: Breadcrumb.t Non_empty_list.t
              (* oldest first *)
        ; new_best_tip_length: int
        ; removed_from_best_tip_path: Breadcrumb.t list (* also oldest first *)
        ; garbage: Breadcrumb.t list }
        (** Triggered when a new breadcrumb is added, causing a new best_tip *)
  [@@deriving sexp]

  type diff = t

  module Hash = struct
    open Digestif.SHA256

    type nonrec t = t

    include Binable.Of_stringable (struct
      type nonrec t = t

      let of_string = of_hex

      let to_string = to_hex
    end)

    let equal t1 t2 = equal t1 t2

    let empty = digest_string ""

    let merge t1 string = digestv_string [to_hex t1; string]

    let to_string = to_raw_string
  end

  module Mutant = struct
    module Key = struct
      module New_frontier = struct
        (* TODO: version *)
        type t =
          ( External_transition.Validated.Stable.V1.t
          , State_hash.Stable.V1.t )
          With_hash.Stable.V1.t
          * Staged_ledger.Scan_state.Stable.V1.t
          * Pending_coinbase.Stable.V1.t
        [@@deriving bin_io]
      end

      module Add_transition = struct
        (* TODO: version *)
        type t =
          ( External_transition.Validated.Stable.V1.t
          , State_hash.Stable.V1.t )
          With_hash.Stable.V1.t
        [@@deriving bin_io]
      end

      module Update_root = struct
        (* TODO: version *)
        type t =
          State_hash.Stable.V1.t
          * Staged_ledger.Scan_state.Stable.V1.t
          * Pending_coinbase.Stable.V1.t
        [@@deriving bin_io]
      end
    end

    type _ t =
      | New_frontier : Key.New_frontier.t -> unit t
      | Add_transition :
          Key.Add_transition.t
          -> Consensus.Data.Consensus_state.Value.Stable.V1.t t
      | Remove_transitions :
          ( External_transition.Validated.Stable.V1.t
          , State_hash.Stable.V1.t )
          With_hash.Stable.V1.t
          list
          -> Consensus.Data.Consensus_state.Value.Stable.V1.t list t
      | Update_root :
          Key.Update_root.t
          -> ( State_hash.Stable.V1.t
             * Staged_ledger.Scan_state.Stable.V1.t
             * Pending_coinbase.t )
             t

    type 'a diff_mutant = 'a t

    let serialize_consensus_state =
      Binable.to_string (module Consensus.Data.Consensus_state.Value.Stable.V1)

    let json_consensus_state consensus_state =
      Consensus.Data.Consensus_state.(
        display_to_yojson @@ display consensus_state)

    let name : type a. a t -> string = function
      | New_frontier _ ->
          "New_frontier"
      | Add_transition _ ->
          "Add_transition"
      | Remove_transitions _ ->
          "Remove_transitions"
      | Update_root _ ->
          "Update_root"

    let update_root_to_yojson (state_hash, scan_state, pending_coinbase) =
      (* We need some representation of scan_state and pending_coinbase,
        so the serialized version of these states would be fine *)
      `Assoc
        [ ("state_hash", State_hash.to_yojson state_hash)
        ; ( "scan_state"
          , `Int
              ( String.hash
              @@ Binable.to_string
                   (module Staged_ledger.Scan_state.Stable.V1)
                   scan_state ) )
        ; ( "pending_coinbase"
          , `Int
              ( String.hash
              @@ Binable.to_string
                   (module Pending_coinbase.Stable.V1)
                   pending_coinbase ) ) ]

    (* Yojson is not performant and should be turned off *)
    let value_to_yojson (type a) (key : a t) (value : a) =
      let json_value =
        match (key, value) with
        | New_frontier _, () ->
            `Null
        | Add_transition _, parent_consensus_state ->
            json_consensus_state parent_consensus_state
        | Remove_transitions _, removed_consensus_state ->
            `List (List.map removed_consensus_state ~f:json_consensus_state)
        | Update_root _, (old_state_hash, old_scan_state, old_pending_coinbase)
          ->
            update_root_to_yojson
              (old_state_hash, old_scan_state, old_pending_coinbase)
      in
      `List [`String (name key); json_value]

    let key_to_yojson (type a) (key : a t) =
      let json_key =
        match key with
        | New_frontier (With_hash.{hash; _}, _, _) ->
            State_hash.to_yojson hash
        | Add_transition With_hash.{hash; _} ->
            State_hash.to_yojson hash
        | Remove_transitions removed_transitions ->
            `List
              (List.map removed_transitions ~f:(fun With_hash.{hash; _} ->
                   State_hash.to_yojson hash ))
        | Update_root (state_hash, scan_state, pending_coinbase) ->
            update_root_to_yojson (state_hash, scan_state, pending_coinbase)
      in
      `List [`String (name key); json_key]

    let merge = Fn.flip Hash.merge

    let hash_root_data (hash, scan_state, pending_coinbase) acc =
      merge
        ( Bin_prot.Utils.bin_dump
            [%bin_type_class:
              State_hash.Stable.V1.t
              * Staged_ledger.Scan_state.Stable.V1.t
              * Pending_coinbase.Stable.V1.t]
              .writer
            (hash, scan_state, pending_coinbase)
        |> Bigstring.to_string )
        acc

    let hash_diff_contents (type mutant) (t : mutant t) acc =
      match t with
      | New_frontier ({With_hash.hash; _}, scan_state, pending_coinbase) ->
          hash_root_data (hash, scan_state, pending_coinbase) acc
      | Add_transition {With_hash.hash; _} ->
          Hash.merge acc (State_hash.to_bytes hash)
      | Remove_transitions removed_transitions ->
          List.fold removed_transitions ~init:acc
            ~f:(fun acc_hash With_hash.{hash= state_hash; _} ->
              Hash.merge acc_hash (State_hash.to_bytes state_hash) )
      | Update_root (new_hash, new_scan_state, pending_coinbase) ->
          hash_root_data (new_hash, new_scan_state, pending_coinbase) acc

    let hash_mutant (type mutant) (t : mutant t) (mutant : mutant) acc =
      match (t, mutant) with
      | New_frontier _, () ->
          acc
      | Add_transition _, parent_external_transition ->
          merge (serialize_consensus_state parent_external_transition) acc
      | Remove_transitions _, removed_transitions ->
          List.fold removed_transitions ~init:acc
            ~f:(fun acc_hash removed_transition ->
              merge (serialize_consensus_state removed_transition) acc_hash )
      | Update_root _, (old_root, old_scan_state, old_pending_coinbase) ->
          hash_root_data (old_root, old_scan_state, old_pending_coinbase) acc

    let hash (type mutant) acc_hash (t : mutant t) (mutant : mutant) =
      let diff_contents_hash = hash_diff_contents t acc_hash in
      hash_mutant t mutant diff_contents_hash

    module E = struct
      type t = E : 'output diff_mutant -> t

      (* HACK:  This makes the existential type easily binable *)
      include Binable.Of_binable (struct
                  type t =
                    [ `New_frontier of Key.New_frontier.t
                    | `Add_transition of Key.Add_transition.t
                    | `Remove_transitions of
                      ( External_transition.Validated.Stable.V1.t
                      , State_hash.Stable.V1.t )
                      With_hash.Stable.V1.t
                      list
                    | `Update_root of Key.Update_root.t ]
                  [@@deriving bin_io]
                end)
                (struct
                  type nonrec t = t

                  let of_binable = function
                    | `New_frontier data ->
                        E (New_frontier data)
                    | `Add_transition data ->
                        E (Add_transition data)
                    | `Remove_transitions transitions ->
                        E (Remove_transitions transitions)
                    | `Update_root data ->
                        E (Update_root data)

                  let to_binable = function
                    | E (New_frontier data) ->
                        `New_frontier data
                    | E (Add_transition data) ->
                        `Add_transition data
                    | E (Remove_transitions transitions) ->
                        `Remove_transitions transitions
                    | E (Update_root data) ->
                        `Update_root data
                end)
    end
  end

  module Best_tip_diff = struct
    type t = unit

    type input = unit

    type view =
      { new_user_commands: User_command.t list
      ; removed_user_commands: User_command.t list }

    let create () = ()

    let initial_view () : view =
      {new_user_commands= []; removed_user_commands= []}

    let handle_diff () diff : view Option.t =
      match diff with
      | New_breadcrumb _ ->
          None (* We only care about the best tip *)
      | New_frontier breadcrumb ->
          Some
            { new_user_commands= Breadcrumb.to_user_commands breadcrumb
            ; removed_user_commands= [] }
      | New_best_tip {added_to_best_tip_path; removed_from_best_tip_path; _} ->
          Some
            { new_user_commands=
                List.bind
                  (Non_empty_list.to_list added_to_best_tip_path)
                  ~f:Breadcrumb.to_user_commands
            ; removed_user_commands=
                List.bind removed_from_best_tip_path
                  ~f:Breadcrumb.to_user_commands }
  end

  module Root_diff = struct
    type t = unit

    type input = unit

    type view =
      {user_commands: User_command.Stable.V1.t list; root_length: int option}
    [@@deriving bin_io]

    let create () = ()

    let initial_view () = {user_commands= []; root_length= None}

    let handle_diff () diff =
      match diff with
      | New_breadcrumb _ ->
          None
      | New_frontier root ->
          Some
            { user_commands= Breadcrumb.to_user_commands root
            ; root_length= Some 0 }
      | New_best_tip {old_root; new_root; old_root_length; _} ->
          if
            State_hash.equal
              (Breadcrumb.state_hash old_root)
              (Breadcrumb.state_hash new_root)
          then None
          else
            Some
              { user_commands= Breadcrumb.to_user_commands new_root
              ; root_length= Some (1 + old_root_length) }
  end

  (** A transition frontier extension that exposes the changes in the transactions
      in the best tip. *)
  module Persistence_diff = struct
    type t = unit

    type input = unit

    type view = Mutant.E.t list

    let create () = ()

    let initial_view () = []

    let scan_state breadcrumb =
      breadcrumb |> Breadcrumb.staged_ledger |> Staged_ledger.scan_state

    let pending_coinbase breadcrumb =
      breadcrumb |> Breadcrumb.staged_ledger
      |> Staged_ledger.pending_coinbase_collection

    let handle_diff () (diff : diff) : view option =
      let open Mutant.E in
      Option.return
      @@
      match diff with
      | New_frontier breadcrumb ->
          [ E
              (New_frontier
                 ( Breadcrumb.transition_with_hash breadcrumb
                 , scan_state breadcrumb
                 , pending_coinbase breadcrumb )) ]
      | New_breadcrumb breadcrumb ->
          [E (Add_transition (Breadcrumb.transition_with_hash breadcrumb))]
      | New_best_tip {garbage; added_to_best_tip_path; new_root; old_root; _}
        ->
          let added_transition =
            E
              (Add_transition
                 ( Non_empty_list.last added_to_best_tip_path
                 |> Breadcrumb.transition_with_hash ))
          in
          let remove_transition =
            E
              (Remove_transitions
                 (List.map garbage ~f:Breadcrumb.transition_with_hash))
          in
          if
            State_hash.equal
              (Breadcrumb.state_hash old_root)
              (Breadcrumb.state_hash new_root)
          then [added_transition; remove_transition]
          else
            [ added_transition
            ; E
                (Update_root
                   ( Breadcrumb.state_hash new_root
                   , scan_state new_root
                   , pending_coinbase new_root ))
            ; remove_transition ]
  end
end
