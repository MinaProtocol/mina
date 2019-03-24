open Core_kernel
open Coda_base

module type Transition_database_schema = sig
  type external_transition

  type state_hash

  type scan_state

  type _ t =
    | Transition : (external_transition * state_hash list) -> state_hash t
    | Root : (state_hash * scan_state) t
end

module Make (Inputs : Transition_frontier.Inputs_intf) = struct
  open Inputs

  module Transition = struct
    module Data = struct
      type t =
        External_transition.Stable.Latest.t * State_hash.Stable.Latest.t list
      [@@deriving bin_io]
    end
  end

  module Root_data = struct
    module Data = struct
      type t =
        State_hash.Stable.Latest.t * Staged_ledger.Scan_state.Stable.Latest.t
      [@@deriving bin_io]
    end
  end

  type root_data =
    State_hash.Stable.Latest.t * Staged_ledger.Scan_state.Stable.Latest.t
  [@@deriving bin_io]

  type _ t =
    | Transition : Transition.Data.t -> State_hash.Stable.Latest.t t
    | Root : Root_data.Data.t -> unit t

  module Root_binable = struct
    type t =
      State_hash.Stable.Latest.t * Staged_ledger.Scan_state.Stable.Latest.t
    [@@deriving bin_io]
  end

  let binable_data_type (type a) : a t -> a Bin_prot.Type_class.t = function
    | Transition _ -> [%bin_type_class: State_hash.Stable.Latest.t]
    | Root _ -> [%bin_type_class: unit]

  (* HACK: a simple way to derive Bin_prot.Type_class.t for each case of a GADT *)
  let gadt_input_type_class (type data a) :
         (module Binable.S with type t = data)
      -> to_gadt:(data -> a t)
      -> of_gadt:(a t -> data)
      -> a t Bin_prot.Type_class.t =
   fun (module M) ~to_gadt ~of_gadt ->
    let ({shape; writer= {size; write}; reader= {read; vtag_read}}
          : data Bin_prot.Type_class.t) =
      [%bin_type_class: M.t]
    in
    { shape
    ; writer=
        { size= Fn.compose size of_gadt
        ; write= (fun buffer ~pos gadt -> write buffer ~pos (of_gadt gadt)) }
    ; reader=
        { read= (fun buffer ~pos_ref -> to_gadt (read buffer ~pos_ref))
        ; vtag_read=
            (fun buffer ~pos_ref number ->
              to_gadt (vtag_read buffer ~pos_ref number) ) } }

  (* HACK: The OCaml compiler thought the pattern matching in of_gadts was
     non-exhaustive. However, it should not be since I constrained the
     polymorphic type *)
  let[@warning "-8"] binable_key_type (type a) :
      a t -> a t Bin_prot.Type_class.t = function
    | Transition _ ->
        gadt_input_type_class
          (module Transition.Data)
          ~to_gadt:(fun transition -> Transition transition)
          ~of_gadt:(fun (Transition transition) -> transition)
    | Root _ ->
        gadt_input_type_class
          (module Root_data.Data)
          ~to_gadt:(fun root_data -> Root root_data)
          ~of_gadt:(fun (Root root_data) -> root_data)
end
