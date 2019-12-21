open Fold_lib

module Body = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          { blockchain_state: Blockchain_state.Stable.V1.t
          ; consensus_state: Consensus_state.Stable.V1.t }
        [@@deriving eq, bin_io, sexp, version]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t =
    { blockchain_state: Blockchain_state.Stable.V1.t
    ; consensus_state: Consensus_state.Stable.V1.t }
  [@@deriving eq, sexp]

  let fold {blockchain_state; consensus_state} =
    let open Fold in
    Blockchain_state.fold blockchain_state
    +> Consensus_state.fold consensus_state
end

module Stable = struct
  module V1 = struct
    module T = struct
      type t = {previous_state_hash: Pedersen.Digest.t; body: Body.Stable.V1.t}
      [@@deriving eq, bin_io, sexp, version {asserted}]
    end

    include T
  end

  module Latest = V1
end

type t = Stable.Latest.t =
  {previous_state_hash: Pedersen.Digest.t; body: Body.Stable.V1.t}
[@@deriving eq, sexp]

let fold ~fold_body {previous_state_hash; body} =
  let open Fold in
  State_hash.fold previous_state_hash +> fold_body body
