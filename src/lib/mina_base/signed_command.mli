open Core_kernel
open Mina_base_import

include
  Signed_command_intf.Full
    with type With_valid_signature.Stable.Latest.t =
      Mina_wire_types.Mina_base.Signed_command.With_valid_signature.V2.t
