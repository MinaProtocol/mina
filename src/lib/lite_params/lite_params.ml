open Core_kernel
open Fold_lib

let pedersen_params = Precomputed_params.pedersen_params

module Pedersen =
  Pedersen_lib.Pedersen.Make
    (Lite_curve_choice.Tock.Fq)
    (Lite_curve_choice.Tock.G1)

module Tock = struct
  include Lite_curve_choice.Tock

  module Bowe_gabizon = Snarkette.Bowe_gabizon.Make (struct
    module N = N
    module G1 = G1
    module G2 = G2
    module Fq = Fq
    module Fqe = Fq3
    module Fq_target = Fq6
    module Pairing = Pairing

    include Bowe_gabizon_hash.Make (struct
      module Field = struct
        include Fq

        let to_bits = Fn.compose Fold.to_list fold_bits

        let of_bits x = Option.value_exn (of_bits x)
      end

      module Bigint = struct
        include N

        let of_field = Fq.to_bigint
      end

      module Fqe = Fq3
      module G1 = G1
      module G2 = G2

      let params = Precomputed_params.group_map_params

      let pedersen =
        Pedersen.digest_fold
          { acc= Precomputed_params.bowe_gabizon_hash_prefix_acc
          ; triples_consumed= Hash_prefixes.length_in_triples
          ; params= pedersen_params }
    end)
  end)
end
