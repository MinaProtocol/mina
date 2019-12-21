(* data_hash.ml -- data hash that uses Snarky *)

open Core_kernel
open Snark_params.Tick

module type Full_size =
  Data_hash_functor.Make_sigs(Snark_params.Tick).Full_size

module type Small = Data_hash_functor.Make_sigs(Snark_params.Tick).Small

module Data_hash_type = struct
  module Arg = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Pedersen.Digest.Stable.V1.t
        [@@deriving sexp, compare, hash, yojson]

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Pedersen.Digest.Stable.V1.t
      [@@deriving sexp, compare, hash, yojson]

      let to_latest = Fn.id

      type _unused = unit
        constraint t = Crypto_params.Tick0.field constraint t = Arg.Stable.V1.t

      let version_byte = Base58_check.Version_bytes.data_hash

      include Comparable.Make (Arg.Stable.V1)
      include Hashable.Make_binable (Arg.Stable.V1)
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, compare, hash, yojson]

  include Comparable.Make (Stable.Latest)
  include Hashable.Make (Stable.Latest)
end

include Data_hash_functor.Make (Snark_params.Tick) (Data_hash_type)
