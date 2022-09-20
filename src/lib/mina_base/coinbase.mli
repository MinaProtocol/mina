open Core_kernel
open Mina_base_import

include
  Coinbase_intf.Full
    with type Stable.V1.t = Mina_wire_types.Mina_base.Coinbase.V1.t
