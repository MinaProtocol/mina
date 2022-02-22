(* state_hash.ml *)
open Core_kernel

[%%import "/src/config.mlh"]

[%%ifdef consensus_mechanism]

module T = Data_hash_lib.State_hash

[%%else]

module T = Data_hash_lib_nonconsensus.State_hash

[%%endif]

include T

module State_hashes = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { state_body_hash: State_body_hash.Stable.V1.t
        ; state_hash: T.Stable.V1.t }
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]
end

module With_state_hashes = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = ('a, State_hashes.Stable.V1.t) With_hash.Stable.V1.t
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  open With_hash
  open State_hashes.Stable.Latest

  let data {data;_} = data

  let hashes {hash=hashes;_} = hashes

  let state_hash {hash={state_hash;_};_} = state_hash

  let state_body_hash {hash={state_body_hash;_};_} = state_body_hash
end
