open Core_kernel

module T = struct
  include Data_hash.Make_full_size ()
end

include T

include Comparable.Make (T)

let zero = Snark_params.Tick.Pedersen.zero_hash
