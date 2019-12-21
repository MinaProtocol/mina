open Core_kernel

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

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      ( Hash.Stable.V1.t
      , Lite_base.Public_key.Compressed.Stable.V1.t
      , Account.Stable.V1.t )
      Sparse_ledger_lib.Sparse_ledger.T.Stable.V1.t
    [@@deriving sexp]

    let to_latest = Fn.id
  end
end]

module M =
  Sparse_ledger_lib.Sparse_ledger.Make (Hash) (Lite_base.Public_key.Compressed)
    (struct
      include Account

      let data_hash = Account.digest
    end)

[%%define_locally
M.
  ( of_hash
  , get_exn
  , path_exn
  , set_exn
  , find_index_exn
  , add_path
  , merkle_root
  , iteri )]
