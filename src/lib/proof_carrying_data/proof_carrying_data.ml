(* A convenient data structure to bundle statements along with their proofs together *)

module Stable = struct
  (* don't register versions, because of type parameters *)
  module V1 = struct
    type ('a, 'b) t = {data: 'a; proof: 'b} [@@deriving sexp, fields, bin_io]
  end

  module Latest = V1
end

(* bin_io omitted *)
type ('a, 'b) t = ('a, 'b) Stable.Latest.t = {data: 'a; proof: 'b}
[@@deriving sexp, fields]
