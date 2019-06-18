open Snarkette.Mnt6_80
open Laurent

module Backend = struct
  module N = N
  module G1 = G1
  module G2 = G2
  module Fqe = Fq3
  module Fq_target = Fq6
  module Fr = Snarkette.Mnt4_80.Fq
  module Fr_laurent = Make_laurent (N) (Fr)
  module Bivariate_fr_laurent = Make_laurent (N) (Fr_laurent)
end
