open Core_kernel
open Coda_base
open Coda_transition

module Make (Inputs : sig
  include Inputs.Inputs_intf

  module Breadcrumb : Coda_intf.Transition_frontier_breadcrumb_intf
end) :
  Coda_intf.Transition_frontier_diff_intf
  with type breadcrumb := Inputs.Breadcrumb.t = struct
  open Inputs

  (* TODO: Remove New_frontier.
     Each transition frontier extension should be initialized by the input, the root breadcrumb *)
  type t =
    | New_breadcrumb of {previous: Breadcrumb.t; added: Breadcrumb.t}
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
        ; parent: Breadcrumb.t
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
    module Root = struct
      module Poly = struct
        module Stable = struct
          module V1 = struct
            module T = struct
              type ('root, 'scan_state, 'pending_coinbase) t =
                { root: 'root
                ; scan_state: 'scan_state
                ; pending_coinbase: 'pending_coinbase }
              [@@deriving bin_io, version]
            end

            include T
          end

          module Latest = V1
        end

        type ('root, 'scan_state, 'pending_coinbase) t =
              ('root, 'scan_state, 'pending_coinbase) Stable.Latest.t =
          { root: 'root
          ; scan_state: 'scan_state
          ; pending_coinbase: 'pending_coinbase }
      end

      type 'root t =
        ('root, Staged_ledger.Scan_state.t, Pending_coinbase.t) Poly.t
    end

    module Key = struct
      module New_frontier = struct
        [%%versioned
        module Stable = struct
          module V1 = struct
            type t =
              ( External_transition.Validated.Stable.V1.t
              , Staged_ledger.Scan_state.Stable.V1.t
              , Pending_coinbase.Stable.V1.t )
              Root.Poly.Stable.V1.t

            let to_latest = Fn.id
          end
        end]

        type t = Stable.Latest.t
      end

      module Add_transition = struct
        [%%versioned
        module Stable = struct
          module V1 = struct
            type t = External_transition.Validated.Stable.V1.t

            let to_latest = Fn.id
          end
        end]

        type t = Stable.Latest.t
      end

      module Update_root = struct
        [%%versioned
        module Stable = struct
          module V1 = struct
            type t =
              ( State_hash.Stable.V1.t
              , Staged_ledger.Scan_state.Stable.V1.t
              , Pending_coinbase.Stable.V1.t )
              Root.Poly.Stable.V1.t

            let to_latest = Fn.id
          end
        end]

        type t = Stable.Latest.t
      end
    end

    type _ t =
      | New_frontier : Key.New_frontier.t -> unit t
      | Add_transition :
          Key.Add_transition.t
          -> Consensus.Data.Consensus_state.Value.Stable.V1.t t
      | Remove_transitions :
          State_hash.t list
          -> Consensus.Data.Consensus_state.Value.Stable.V1.t list t
      | Update_root : Key.Update_root.t -> State_hash.Stable.V1.t Root.t t

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
        | ( Update_root _
          , { Root.Poly.root= old_state_hash
            ; scan_state= old_scan_state
            ; pending_coinbase= old_pending_coinbase } ) ->
            update_root_to_yojson
              (old_state_hash, old_scan_state, old_pending_coinbase)
      in
      `List [`String (name key); json_value]

    let key_to_yojson (type a) (key : a t) =
      let json_key =
        match key with
        | New_frontier {Root.Poly.root= root_transition; _} ->
            External_transition.Validated.state_hash root_transition
            |> State_hash.to_yojson
        | Add_transition validated_transition ->
            External_transition.Validated.state_hash validated_transition
            |> State_hash.to_yojson
        | Remove_transitions removed_transitions ->
            `List (List.map ~f:State_hash.to_yojson removed_transitions)
        | Update_root {Root.Poly.root= state_hash; scan_state; pending_coinbase}
          ->
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
      | New_frontier
          {Root.Poly.root= root_transition; scan_state; pending_coinbase} ->
          hash_root_data
            ( External_transition.Validated.state_hash root_transition
            , scan_state
            , pending_coinbase )
            acc
      | Add_transition validated_transition ->
          Hash.merge acc
            (State_hash.raw_hash_bytes
               (External_transition.Validated.state_hash validated_transition))
      | Remove_transitions removed_transitions ->
          List.fold removed_transitions ~init:acc
            ~f:(fun acc_hash transition ->
              Hash.merge acc_hash (State_hash.raw_hash_bytes transition) )
      | Update_root
          { Root.Poly.root= new_hash
          ; scan_state= new_scan_state
          ; pending_coinbase= new_pending_coinbase } ->
          hash_root_data (new_hash, new_scan_state, new_pending_coinbase) acc

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
      | ( Update_root _
        , { Root.Poly.root= old_root
          ; scan_state= old_scan_state
          ; pending_coinbase= old_pending_coinbase } ) ->
          hash_root_data (old_root, old_scan_state, old_pending_coinbase) acc

    let hash (type mutant) acc_hash (t : mutant t) (mutant : mutant) =
      let diff_contents_hash = hash_diff_contents t acc_hash in
      hash_mutant t mutant diff_contents_hash

    module E = struct
      type t = E : 'output diff_mutant -> t

      (* HACK:  This makes the existential type easily binable *)
      include Binable.Of_binable (struct
                  type t =
                    [ `New_frontier of Key.New_frontier.Stable.Latest.t
                    | `Add_transition of Key.Add_transition.Stable.Latest.t
                    | `Remove_transitions of State_hash.Stable.Latest.t list
                    | `Update_root of Key.Update_root.Stable.Latest.t ]
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

      type with_value =
        | With_value : 'output diff_mutant * 'output -> with_value
    end
  end

  module Best_tip_diff = struct
    type t = unit

    type input = unit

    (* these are populated by the best-tip-path changes *)
    type view =
      { new_user_commands: User_command.t list
      ; removed_user_commands: User_command.t list
      ; reorg_best_tip: bool }

    let create () = ()

    let initial_view () : view =
      {new_user_commands= []; removed_user_commands= []; reorg_best_tip= false}

    let handle_diff () diff : view Option.t =
      match diff with
      | New_breadcrumb _ ->
          None (* We only care about the best tip *)
      | New_frontier breadcrumb ->
          Some
            { new_user_commands= Breadcrumb.user_commands breadcrumb
            ; removed_user_commands= []
            ; reorg_best_tip= false }
      | New_best_tip {added_to_best_tip_path; removed_from_best_tip_path; _} ->
          Some
            { new_user_commands=
                List.bind
                  (Non_empty_list.to_list added_to_best_tip_path)
                  ~f:Breadcrumb.user_commands
            ; removed_user_commands=
                List.bind removed_from_best_tip_path
                  ~f:Breadcrumb.user_commands
                (* Using `removed_user_commands` as a proxy for reorg_best_tip is not a good enough because we could be reorg-ing orphaning only coinbase blocks. However, `removed_from_best_tip_path` are all breadcrumbs including those with no user_commands *)
            ; reorg_best_tip= not @@ List.is_empty removed_from_best_tip_path
            }
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
            {user_commands= Breadcrumb.user_commands root; root_length= Some 0}
      | New_best_tip {old_root; new_root; old_root_length; _} ->
          if
            State_hash.equal
              (Breadcrumb.state_hash old_root)
              (Breadcrumb.state_hash new_root)
          then None
          else
            Some
              { user_commands= Breadcrumb.user_commands new_root
              ; root_length= Some (1 + old_root_length) }
  end

  (** A transition frontier extension that exposes the changes in the transactions
      in the best tip. *)
  module Persistence_diff = struct
    type t = unit

    type input = unit

    type view = Mutant.E.with_value list

    let create () = ()

    let initial_view () = []

    let scan_state breadcrumb =
      breadcrumb |> Breadcrumb.staged_ledger |> Staged_ledger.scan_state

    let pending_coinbase breadcrumb =
      breadcrumb |> Breadcrumb.staged_ledger
      |> Staged_ledger.pending_coinbase_collection

    let consensus_state breadcrumb =
      breadcrumb |> Breadcrumb.validated_transition
      |> External_transition.Validated.consensus_state

    let get_root_data root =
      { Mutant.Root.Poly.root= Breadcrumb.state_hash root
      ; scan_state= scan_state root
      ; pending_coinbase= pending_coinbase root }

    let compute_ground_truth_mutants = function
      | New_frontier breadcrumb ->
          [ Mutant.E.With_value
              ( New_frontier
                  { Mutant.Root.Poly.root=
                      Breadcrumb.validated_transition breadcrumb
                  ; scan_state= scan_state breadcrumb
                  ; pending_coinbase= pending_coinbase breadcrumb }
              , () ) ]
      | New_breadcrumb {previous; added} ->
          [ With_value
              ( Add_transition (Breadcrumb.validated_transition added)
              , consensus_state previous ) ]
      | New_best_tip
          {garbage; added_to_best_tip_path; new_root; old_root; parent; _} ->
          let added_transition =
            Mutant.E.With_value
              ( Add_transition
                  ( Breadcrumb.validated_transition
                  @@ Non_empty_list.last added_to_best_tip_path )
              , consensus_state parent )
          in
          let remove_transition =
            Mutant.E.With_value
              ( Remove_transitions (List.map garbage ~f:Breadcrumb.state_hash)
              , List.map garbage ~f:consensus_state )
          in
          if
            State_hash.equal
              (Breadcrumb.state_hash old_root)
              (Breadcrumb.state_hash new_root)
          then [added_transition]
          else
            let update_root_diff =
              Mutant.E.With_value
                (Update_root (get_root_data new_root), get_root_data old_root)
            in
            [added_transition; update_root_diff; remove_transition]

    let handle_diff () (diff : diff) =
      Option.return @@ compute_ground_truth_mutants diff
  end
end
