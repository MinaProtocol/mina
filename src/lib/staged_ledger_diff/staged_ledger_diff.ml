include Diff
module Body = Body
module Bitswap_block = Bitswap_block

let genesis_body_reference =
  (* Tag Body is fixed to integer value 0 *)
  Body.compute_reference ~tag:0 (Body.Stable.Latest.create Stable.Latest.empty_diff)
