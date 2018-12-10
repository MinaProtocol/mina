open Sexplib.Std
open Bin_prot.Std
open Fold_lib

module Aux_hash = struct
  type t = string [@@deriving bin_io, eq, sexp]

  let fold = Fold_lib.Fold.string_triples
end

type t = {ledger_hash: Ledger_hash.t; aux_hash: Aux_hash.t}
[@@deriving bin_io, eq, sexp]

let digest {ledger_hash; aux_hash} =
  let h = Digestif.SHA256.init () in
  let h = Digestif.SHA256.feed_string h (Ledger_hash.to_bytes ledger_hash) in
  let h = Digestif.SHA256.feed_string h aux_hash in
  (Digestif.SHA256.get h :> string)

let fold t = Fold.string_triples (digest t)
