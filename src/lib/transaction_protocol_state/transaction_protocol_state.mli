open Core
open Snark_params
open Tick

(** Transactions included in a block with the associated block data which is the protocol state body of the previous block. TODO: This will change to current block*)

module Block_data : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = Coda_state.Protocol_state.Body.Value.Stable.V1.t
      [@@deriving sexp]
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp]

  type var

  val typ : (var, t) Typ.t
end

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type 'a t = {transaction: 'a; block_data: Block_data.Stable.V1.t}
      [@@deriving sexp]
    end
  end]

  type 'a t = 'a Stable.Latest.t = {transaction: 'a; block_data: Block_data.t}
  [@@deriving sexp]
end

[%%versioned:
module Stable : sig
  module V1 : sig
    type 'a t = 'a Poly.Stable.V1.t [@@deriving sexp]
  end
end]

type 'a t = 'a Stable.Latest.t [@@deriving sexp]

val transaction : 'a t -> 'a

val block_data : _ t -> Block_data.t
