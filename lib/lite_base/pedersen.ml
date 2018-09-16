open Snarkette
open Mnt6

include Pedersen_lib.Pedersen.Make (struct
            include Fq
          end)
          (G1)
