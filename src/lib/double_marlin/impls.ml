module D = Digest
open Core_kernel
module Digest = D
open Snarky_bn382_backend

module Pairing_based = struct
  module Impl = Snarky.Snark.Run.Make (Pairing_based) (Unit)
  include Impl
  module Fp = Field

  module Fq = struct
    let size_in_bits = Fp.size_in_bits

    module Constant = struct
      type t = Fq.t
    end

    type t = (* Low bits, high bit *)
      Fp.t * Boolean.var

    let typ =
      Typ.transport
        (Typ.tuple2 Fp.typ Boolean.typ)
        ~there:(fun x ->
          let low, high = Common.split_last (Fq.to_bits x) in
          (Fp.Constant.project low, high) )
        ~back:(fun (low, high) ->
          let low, _ = Common.split_last (Fp.Constant.unpack low) in
          Fq.of_bits (low @ [high]) )

    let to_bits (x, b) = Field.unpack x ~length:(Field.size_in_bits - 1) @ [b]
  end

  module Digest = D.Make (Impl)
  module Challenge = Challenge.Make (Impl)

  let input ~bulletproof_log2 =
    let open Pickles_types in
    let v = Vector.typ in
    let bulletproof_challenge =
      let open Types.Bulletproof_challenge in
      Typ.transport Typ.field
        ~there:(fun {prechallenge; is_square} ->
          Field.Constant.project
            (is_square :: Challenge.Constant.to_bits prechallenge) )
        ~back:(fun x ->
          match List.take (Field.Constant.unpack x) (1 + Challenge.length) with
          | is_square :: bs ->
              {is_square; prechallenge= Challenge.Constant.of_bits bs}
          | _ ->
              assert false )
    in
    Snarky.Typ.tuple5 (v Boolean.typ Nat.N1.n) (v Fq.typ Nat.N4.n)
      (v Digest.packed_typ Nat.N3.n)
      (v Challenge.packed_typ Nat.N9.n)
      (Typ.array ~length:bulletproof_log2 bulletproof_challenge)
end

module Dlog_based = struct
  module Impl = Snarky.Snark.Run.Make (Dlog_based) (Unit)
  include Impl
  module Challenge = Challenge.Make (Impl)
  module Digest = D.Make (Impl)
  module Fq = Fq

  let input =
    let open Pickles_types.Vector in
    let fp_as_fq (x : Fp.t) = Fq.of_bigint (Fp.to_bigint x) in
    let fp =
      Typ.transport Field.typ ~there:fp_as_fq ~back:(fun (x : Fq.t) ->
          Fp.of_bigint (Fq.to_bigint x) )
    in
    Snarky.Typ.tuple4
      (typ Impl.Boolean.typ Nat.N1.n)
      (typ fp Nat.N3.n)
      (typ Challenge.packed_typ Nat.N9.n)
      (typ Digest.packed_typ Nat.N3.n)
end
