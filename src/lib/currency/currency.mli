[%%import "/src/config.mlh"]

open Core_kernel

[%%ifdef consensus_mechanism]

open Snark_params.Tick

[%%endif]

type uint64 = Unsigned.uint64

include
  Intf.Full
    with type Fee.Stable.V1.t = Mina_wire_types.Currency.fee
     and type Amount.Stable.V1.t = Mina_wire_types.Currency.amount
     and type Balance.Stable.V1.t = Mina_wire_types.Currency.balance
