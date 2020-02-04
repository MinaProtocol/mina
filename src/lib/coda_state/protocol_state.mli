open Core_kernel
open Coda_base
open Snark_params.Tick

module Poly : sig
  module Stable : sig
    module V1 : sig
      type ('state_hash, 'body, 'body_hash) t =
        {previous_state_hash: 'state_hash; body: 'body; body_hash: 'body_hash}
      [@@deriving eq, ord, bin_io, hash, sexp, to_yojson, version]
    end

    module Latest = V1
  end

  type ('state_hash, 'body, 'body_hash) t =
        ('state_hash, 'body, 'body_hash) Stable.Latest.t =
    {previous_state_hash: 'state_hash; body: 'body; body_hash: 'body_hash}
  [@@deriving sexp]
end

val hash_abstract :
  (State_hash.t, 'body, State_body_hash.t) Poly.t -> State_hash.t

module Body : sig
  module Poly : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type ('a, 'b, 'c) t [@@deriving sexp]
      end
    end]

    type ('a, 'b, 'c) t = ('a, 'b, 'c) Stable.V1.t [@@deriving sexp]
  end

  module Value : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type t =
          ( State_hash.Stable.V1.t
          , Blockchain_state.Value.Stable.V1.t
          , Consensus.Data.Consensus_state.Value.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving sexp, to_yojson]
      end
    end]

    type t = Stable.Latest.t [@@deriving sexp, to_yojson]
  end

  type var =
    ( State_hash.var
    , Blockchain_state.var
    , Consensus.Data.Consensus_state.var )
    Poly.t

  type ('a, 'b, 'c) t = ('a, 'b, 'c) Poly.t

  val hash : Value.t -> State_body_hash.t

  val hash_checked : var -> (State_body_hash.var, _) Checked.t
end

module Value : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t =
        ( State_hash.Stable.V1.t
        , Body.Value.Stable.V1.t
        , State_body_hash.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving sexp, compare, eq, to_yojson]
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, compare, eq, to_yojson]

  include Hashable.S with type t := t
end

type value = Value.t [@@deriving sexp, to_yojson]

type var = (State_hash.var, Body.var, State_body_hash.var) Poly.t

include Snarkable.S with type value := Value.t and type var := var

val create :
     previous_state_hash:State_hash.t
  -> body:Body.Value.t
  -> (State_hash.t, Body.Value.t, State_body_hash.t) Poly.t

val create_value :
     previous_state_hash:State_hash.t
  -> genesis_state_hash:State_hash.t
  -> blockchain_state:Blockchain_state.Value.t
  -> consensus_state:Consensus.Data.Consensus_state.Value.t
  -> Value.t

val create_var :
     previous_state_hash:State_hash.var
  -> genesis_state_hash:State_hash.var
  -> blockchain_state:Blockchain_state.var
  -> consensus_state:Consensus.Data.Consensus_state.var
  -> body_hash:State_body_hash.var
  -> var

val previous_state_hash :
  ('previous_state_hash, _, _) Poly.t -> 'previous_state_hash

val body : (_, 'body, _) Poly.t -> 'body

val body_hash : (_, _, 'body_hash) Poly.t -> 'body_hash

val blockchain_state :
  (_, (_, 'blockchain_state, _) Body.t, _) Poly.t -> 'blockchain_state

val genesis_state_hash :
  ?state_hash:State_hash.t option -> Value.t -> State_hash.t

val genesis_state_hash_checked :
  state_hash:State_hash.var -> var -> (State_hash.var, _) Checked.t

val consensus_state :
  (_, (_, _, 'consensus_state) Body.t, _) Poly.t -> 'consensus_state

val negative_one : genesis_ledger:Coda_base.Ledger.t Lazy.t -> Value.t

val hash_checked : var -> (State_hash.var * State_body_hash.var, _) Checked.t

val hash : Value.t -> State_hash.t
