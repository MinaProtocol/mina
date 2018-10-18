module Tock_128 = struct
  include Snarkette.Mnt6_128

  let fq_to_scalars (x: Fq.t) : N.t list =
    let n = Fq.length_in_bits in
    (* 2^{n - 1} - 1 *)
    let one = N.of_int 1 in
    let all_but_top_bit_mask = N.( - ) (N.shift_left one (n - 1)) one in
    let x = Fq.to_bigint x in
    [ N.log_and all_but_top_bit_mask x
    ; (if N.test_bit x (n - 1) then one else N.of_int 0) ]
end

module Tock_80 = struct
  include Snarkette.Mnt6_80

  let fq_to_scalars (x: Fq.t) : N.t list = [Fq.to_bigint x]
end

module Tock = Tock_80
