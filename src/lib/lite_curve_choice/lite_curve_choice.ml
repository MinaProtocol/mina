[%%import
"../../config.mlh"]

module Tock298 = struct
  include Snarkette.Mnt6_80

  let fq_to_scalars (x : Fq.t) : N.t list = [Fq.to_bigint x]
end

module Tock753 = struct
  include Snarkette.Mnt6753

  let () = assert (Fq.length_in_bits = 753)

  let fq_to_scalars (x : Fq.t) : N.t list =
    let k' = Fq.length_in_bits - 1 in
    let x = Fq.to_bigint x in
    let one = N.of_int 1 in
    let all_but_top = N.(shift_left one k' - one) in
    [N.log_and all_but_top x; N.(shift_right x k')]
end

[%%if
curve_size = 298]

module Tock = Tock298

[%%elif
curve_size = 753]

module Tock = Tock753

[%%else]

[%%show
curve_size]

[%%error
"invalid value for \"curve_size\""]

[%%endif]
