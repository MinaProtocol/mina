open Core
open Coda_base
open Coda_intf

module Make (Inputs : sig
  include Inputs.Inputs_intf

  module Breadcrumb :
    Transition_frontier_breadcrumb_intf
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
  Transition_frontier_diff_intf
  with type breadcrumb := Inputs.Breadcrumb.t
   and type external_transition_validated :=
              Inputs.External_transition.Validated.t = struct
  open Inputs

  module Root_data = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t =
            { root: State_hash.Stable.V1.t
            ; scan_state: Staged_ledger.Scan_state.Stable.V1.t
            ; pending_coinbase: Pending_coinbase.Stable.V1.t }
          [@@deriving bin_io, version {unnumbered}]
        end

        include T
      end

      module Latest = V1
    end

    type t = Stable.Latest.t =
      { root: State_hash.t
      ; scan_state: Staged_ledger.Scan_state.t
      ; pending_coinbase: Pending_coinbase.t }
  end

  type _ t =
    | New_breadcrumb : Breadcrumb.t -> External_transition.Validated.t t
    | Root_transitioned :
        { new_: Breadcrumb.t
        ; garbage: Breadcrumb.t list }
        -> Root_data.t t
    | Best_tip_changed : Breadcrumb.t -> External_transition.Validated.t t

  let name : type a. a t -> string = function
    | Root_transitioned _ ->
        "Root_transitioned"
    | New_breadcrumb _ ->
        "New_breadcrumb"
    | Best_tip_changed _ ->
        "Best_tip_changed"

  let key_to_yojson (type a) (key : a t) =
    let json_key =
      match key with
      | New_breadcrumb breadcrumb ->
          State_hash.to_yojson (Breadcrumb.state_hash breadcrumb)
      | Root_transitioned {new_; garbage} ->
          `Assoc
            [ ("new_root", State_hash.to_yojson (Breadcrumb.state_hash new_))
            ; ( "garbage"
              , `List
                  (List.map
                     ~f:(Fn.compose State_hash.to_yojson Breadcrumb.state_hash)
                     garbage) ) ]
      | Best_tip_changed breadcrumb ->
          State_hash.to_yojson (Breadcrumb.state_hash breadcrumb)
    in
    `List [`String (name key); json_key]

  type 'a diff_mutant = 'a t

  module E = struct
    type t = E : 'output diff_mutant -> t
  end
end
