open Impl
module Hash = Knapsack_hash

module Field = struct
  include Field

  let to_bits = Field.unpack

  let var_to_bits =
    Field.Checked.choose_preimage_var ~length:Field.size_in_bits
end
