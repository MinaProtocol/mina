(* signed_command_memo.mli *)

include
  Signed_command_memo_intf.S
    with type t = Mina_wire_types.Mina_base.Signed_command_memo.V1.t

module For_test : sig
  val string_of_memo : t -> string

  val length : t -> int

  val length_index : int
end
