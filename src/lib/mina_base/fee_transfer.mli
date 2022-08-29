open Core_kernel
open Mina_base_import

include
  Fee_transfer_intf.Full
    with type Single.Stable.V2.t =
      Mina_wire_types.Mina_base.Fee_transfer.Single.V2.t
