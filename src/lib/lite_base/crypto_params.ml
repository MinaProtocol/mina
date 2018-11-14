module Tock_80 = struct
  include Snarkette.Mnt6_80

  let fq_to_scalars (x : Fq.t) : N.t list = [Fq.to_bigint x]
end

module Tock = Tock_80
