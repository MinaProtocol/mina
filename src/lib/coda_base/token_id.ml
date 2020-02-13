open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Snark_params.Tick.Field.t
    [@@deriving version {asserted}, sexp, eq, hash, compare]

    let to_latest = Fn.id

    let to_yojson x = `String (Snark_params.Tick.Field.to_string x)

    let of_yojson = function
      | `String x ->
          Ok (Snark_params.Tick.Field.of_string x)
      | _ ->
          Error "Coda_base.Account.Token_id.of_yojson"
  end
end]

type t = Stable.Latest.t [@@deriving sexp, compare]

type var = Snark_params.Tick.Field.Var.t

let to_input (x : t) = Random_oracle.Input.field x

open Snark_params.Tick

let typ = Field.typ

let var_of_t = Field.Var.constant

let default = Field.one

let gen = Field.gen_uniform

let unpack = Field.unpack

include Comparable.Make (Stable.Latest)

module Checked = struct
  open Snark_params.Tick

  let to_input (x : var) = Random_oracle.Input.field x

  let equal = Field.Checked.equal

  let if_ = Field.Checked.if_

  module Assert = struct
    let equal = Field.Checked.Assert.equal
  end
end
