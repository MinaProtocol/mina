open Snarkette.Mnt6_80
open Laurent

module Backend = struct
  module N = N

  module G1 = struct
    include G1

    let scale_plus_minus base s =
      if N.( < ) s N.zero then negate (scale base (N.negate s))
      else scale base s
  end

  module G2 = struct
    include G2

    let scale_plus_minus base s =
      if N.( < ) s N.zero then negate (scale base (N.negate s))
      else scale base s
  end

  module Fq = Fq
  module Fqe = Fq3
  module Fq_target = Fq6
  module Fr = Snarkette.Mnt4_80.Fq
  module Pairing = Pairing
  module Fr_laurent = Make_laurent (N) (Fr)
  module Bivariate_fr_laurent = Make_laurent (N) (Fr_laurent)
end
