include Diff
module Body = Body
module Bitswap_block = Bitswap_block

let genesis_body_reference = Body.compute_reference (Body.create empty_diff)
