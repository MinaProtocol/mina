module Hash = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Lite_base.Pedersen.Digest.t
        [@@deriving sexp, to_yojson, bin_io, eq, compare, version {asserted}]
      end

      include T

      let merge = Merkle_path.merge
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp, to_yojson, eq, compare]

  let merge = Stable.Latest.merge
end

module V1_make =
  Sparse_ledger_lib.Sparse_ledger.Make
    (Hash.Stable.V1)
    (Lite_base.Public_key.Compressed.Stable.V1)
    (struct
      include Account.Stable.V1

      let data_hash = Account.digest
    end)

module Stable = struct
  module V1 = struct
    module T = struct
      type t = V1_make.Stable.V1.t [@@deriving bin_io, sexp, version]
    end

    include T
  end

  module Latest = V1
end

module Latest_make = V1_make

let ( of_hash
    , get_exn
    , path_exn
    , set_exn
    , find_index_exn
    , add_path
    , merkle_root
    , iteri ) =
  Latest_make.
    ( of_hash
    , get_exn
    , path_exn
    , set_exn
    , find_index_exn
    , add_path
    , merkle_root
    , iteri )
