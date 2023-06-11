open Mina_base

type view =
  { new_commands : User_command.Valid.t With_status.t list
  ; removed_commands : User_command.Valid.t With_status.t list
  ; reorg_best_tip : bool
  }

module Log_event : sig
  type t =
    { protocol_state : Mina_state.Protocol_state.Value.t
    ; state_hash : State_hash.t
    ; just_emitted_a_proof : bool
    }
  [@@deriving yojson, sexp, compare]

  type Structured_log_events.t +=
    | New_best_tip_event of
        { added_transitions : t list
        ; removed_transitions : t list
        ; reorg_best_tip : bool
        }
    [@@deriving register_event]
end

include Intf.Extension_intf with type view := view
