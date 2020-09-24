open Coda_base

type view =
  { new_commands: User_command.Valid.t With_status.t list
  ; removed_commands: User_command.Valid.t With_status.t list
  ; reorg_best_tip: bool }

include Intf.Extension_intf with type view := view
