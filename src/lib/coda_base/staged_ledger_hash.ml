open Core
open Fold_lib
open Tuple_lib
open Snark_params.Tick

module Aux_hash = struct
  let length_in_bits = 256

  let length_in_bytes = length_in_bits / 8

  module Stable = struct
    module V1 = struct
      type t = string [@@deriving bin_io, sexp, eq, compare, hash]
    end
  end

  include Stable.V1

  let of_bytes = Fn.id

  let to_bytes = Fn.id

  let dummy : t = String.init length_in_bytes ~f:(fun _ -> '\000')

  let fold = Fold.string_triples
end

module Stable = struct
  module V1 = struct
    module T = struct
      type t = {ledger_hash: Ledger_hash.Stable.V1.t; aux_hash: Aux_hash.t}
      [@@deriving bin_io, sexp, eq, compare, hash]
    end

    include T
    include Hashable.Make_binable (T)
  end
end

include Stable.V1

let ledger_hash {ledger_hash; _} = ledger_hash

let aux_hash {aux_hash; _} = aux_hash

let dummy =
  {ledger_hash= Ledger_hash.of_hash Field.zero; aux_hash= Aux_hash.dummy}

let to_string {ledger_hash; aux_hash} =
  Printf.sprintf "%s:%s"
    (Ledger_hash.to_bytes ledger_hash)
    (Aux_hash.to_bytes aux_hash)

let of_aux_and_ledger_hash aux_hash ledger_hash = {aux_hash; ledger_hash}

let length_in_bits = 256

let length_in_triples = (length_in_bits + 2) / 3

let digest {ledger_hash; aux_hash} =
  let h = Digestif.SHA256.init () in
  let h = Digestif.SHA256.feed_string h (Ledger_hash.to_bytes ledger_hash) in
  let h = Digestif.SHA256.feed_string h aux_hash in
  (Digestif.SHA256.get h :> string)

let fold t = Fold.string_triples (digest t)

type var = Boolean.var Triple.t list

let var_to_triples = Checked.return

let typ : (var, t) Typ.t =
  let triple t = Typ.tuple3 t t t in
  Typ.transport
    (Typ.list ~length:length_in_triples (triple Boolean.typ))
    ~there:(Fn.compose Fold.to_list fold)
    ~back:(fun _ -> failwith "Cannot read a ledger_builder_hash from a var")
