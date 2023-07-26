[%%import "/src/config.mlh"]

type uint64 = Unsigned.uint64

(** Here, we simply include the full expected signature, while clarifying that
    the types are those defined in {!Mina_wire_types} *)
include
  Intf.Full
    with type Fee.Stable.V1.t = Mina_wire_types.Currency.Fee.V1.t
     and type Amount.Stable.V1.t = Mina_wire_types.Currency.Amount.V1.t
     and type Balance.Stable.V1.t = Mina_wire_types.Currency.Balance.V1.t
