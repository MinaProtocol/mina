open Core
open Coda_base
open Snark_params
open Tick

(** Transactions included in a block with the associated block data. Block data
gets added to the pending coinbase once per stack for each block. Therefore,
only the first transaction from a sequence of transactions included in a block
needs to carry this information and the rest of the transactions will have the
updated stacks as part of their statements. Block data is currently the state
body hash of the previous block. TODO: This will change to current block in an
upcoming PR*)

module Block_data : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = State_body_hash.Stable.V1.t option [@@deriving sexp]
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp]

  type var

  val typ : (var, t) Typ.t

  module Checked : sig
    val push_state : var -> Boolean.var

    val state_body_hash : var -> State_body_hash.var
  end
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
