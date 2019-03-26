open Core_kernel
open Coda_base

module Make (Inputs : Transition_frontier.Inputs_intf) :
  Intf.Transition_database_schema
  with type external_transition := Inputs.External_transition.Stable.Latest.t
   and type scan_state := Inputs.Staged_ledger.Scan_state.t
   and type state_hash := State_hash.t = struct
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

  type _ t =
    | Transition : State_hash.Stable.Latest.t -> Transition.Data.t t
    | Root : Root_data.Data.t t

  module Root_binable = struct
    type t =
      State_hash.Stable.Latest.t * Staged_ledger.Scan_state.Stable.Latest.t
    [@@deriving bin_io]
  end

  let binable_data_type (type a) : a t -> a Bin_prot.Type_class.t = function
    | Transition _ -> [%bin_type_class: Transition.Data.t]
    | Root -> [%bin_type_class: Root_data.Data.t]

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
          (module State_hash.Stable.Latest)
          ~to_gadt:(fun transition -> Transition transition)
          ~of_gadt:(fun (Transition transition) -> transition)
    | Root ->
        gadt_input_type_class
          (module Unit)
          ~to_gadt:(fun _ -> Root)
          ~of_gadt:(fun Root -> ())
end
