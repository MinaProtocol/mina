open Core_kernel
open Coda_spec

module Make (Hash : Ledger_intf.Hash.S) :
  Ledger_intf.Path.S with module Direction = Direction and module Hash = Hash =
struct
  module Direction = Direction
  module Hash = Hash

  module Elem = struct
    type t = Direction.t * Hash.t [@@deriving sexp]
  end

  type t = Elem.t list [@@deriving sexp]

  let implied_root (t: t) leaf_hash =
    List.fold t ~init:(leaf_hash, 0) ~f:(fun (acc, height) (dir, hash) ->
        let acc =
          match dir with
          | Direction.Left -> Hash.merge ~height acc hash
          | Direction.Right -> Hash.merge ~height hash acc
        in
        (acc, height + 1) )
    |> fst
end
