(* signed_command_memo.mli *)

include
  Signed_command_memo_intf.S
    with type t = Mina_wire_types.Mina_base.Signed_command_memo.V1.t
