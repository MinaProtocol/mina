open Core
open Snark_params
open Tick
open Fold_lib

module T = struct
  type t =
    { fee : Currency.Fee.Stable.V1.t
    ; prover : Public_key.Compressed.Stable.V1.t
    }
  [@@deriving bin_io]
end
include T

let create ~fee ~prover = { fee; prover }

module Digest = struct
  module Stable = struct
    module V1 = struct
      type t = string [@@deriving sexp, compare, eq, bin_io, hash]
    end
  end
  include Stable.V1

  let fold s =
    { Fold.fold =
      fun ~init ~f ->
        let n = String.length s in
        let rec go acc i =
          if i = n
          then acc
          else
            let b = (Char.to_int s.[i/8] lsr (7 - (i % 8))) land 1 = 1 in
            go (f acc b) (i +1)
        in
        go init 0
    }

  let fold t = Fold.group3 ~default:false (fold t)

  module Checked = struct
    type t = Boolean.var list
    let to_triples t = Fold.(to_list (group3 ~default:Boolean.false_ (of_list t)))
  end

  let length_in_bytes = 32

  let length_in_bits = 8 * length_in_bytes

  let length_in_triples = (length_in_bits + 2)/3

  let typ =
    Typ.transport (Typ.list ~length:length_in_bits Boolean.typ)
      ~there:(fun (s : t) ->
        List.init 256 ~f:(fun i ->
          (Char.to_int s.[i/8] lsr (7 - (i % 8))) land 1 = 1))
      ~back:Sha256_lib.Sha256.bits_to_string

  let default = String.init length_in_bytes ~f:(fun _ -> '\000')
end

let digest t =
  (Digestif.SHA256.digest_string
    (Binable.to_string (module T) t) :> string)

