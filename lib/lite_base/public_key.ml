open Fold_lib
open Sexplib.Std
open Bin_prot.Std
open Snarkette
module Field = Mnt6.Fq

type t = Mnt6.G1.t

module Compressed = struct
  type t = {x: Field.t; is_odd: bool} [@@deriving bin_io, eq, sexp]

  let fold_bits {is_odd; x} =
    {Fold.fold= (fun ~init ~f -> f ((Field.fold_bits x).fold ~init ~f) is_odd)}

  let fold t = Fold.group3 ~default:false (fold_bits t)

  let length_in_triples = (Field.length_in_bits + 1 + 2) / 3
end
