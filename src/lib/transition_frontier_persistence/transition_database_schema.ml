open Core_kernel
open Coda_base
open Coda_transition

module Make (Inputs : Transition_frontier.Inputs_intf) :
  Intf.Transition_database_schema
  with type external_transition_validated := External_transition.Validated.t
   and type scan_state := Staged_ledger.Scan_state.t
   and type state_hash := State_hash.t
   and type pending_coinbases := Pending_coinbase.t = struct
  module Data = struct
    module Transition = struct
      (* TODO: version *)
      type t =
        External_transition.Validated.Stable.V1.t * State_hash.Stable.V1.t list
      [@@deriving bin_io]
    end

    module Root_data = struct
      type t =
        State_hash.Stable.V1.t
        * Staged_ledger.Scan_state.Stable.V1.t
        * Pending_coinbase.Stable.V1.t
      [@@deriving bin_io]
    end
  end

  type _ t =
    | Transition : State_hash.Stable.V1.t -> Data.Transition.t t
    | Root : Data.Root_data.t t

  let binable_data_type (type a) : a t -> a Bin_prot.Type_class.t = function
    | Transition _ ->
        [%bin_type_class: Data.Transition.t]
    | Root ->
        [%bin_type_class: Data.Root_data.t]

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
          (module State_hash.Stable.V1)
          ~to_gadt:(fun transition -> Transition transition)
          ~of_gadt:(fun (Transition transition) -> transition)
    | Root ->
        gadt_input_type_class
          (module Unit)
          ~to_gadt:(fun _ -> Root)
          ~of_gadt:(fun Root -> ())
end
