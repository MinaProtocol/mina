open Pickles_types
module D = Digest
open Core_kernel
module Digest = D
open Zexe_backend

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

  let input ~branching ~bulletproof_log2 =
    let open Types.Pairing_based.Statement in
    let spec = spec branching bulletproof_log2 in
    let (T (typ, f)) =
      Spec.packed_typ (module Impl) (T (Fq.typ, Fn.id)) spec
    in
    let typ = Typ.transport typ ~there:to_data ~back:of_data in
    Spec.ETyp.T (typ, fun x -> of_data (f x))
end

module Dlog_based = struct
  module Impl = Snarky.Snark.Run.Make (Dlog_based) (Unit)
  include Impl
  module Challenge = Challenge.Make (Impl)
  module Digest = D.Make (Impl)
  module Fq = Fq

  let input () =
    let fp_as_fq (x : Fp.t) = Fq.of_bigint (Fp.to_bigint x) in
    let fp =
      Typ.transport Field.typ ~there:fp_as_fq ~back:(fun (x : Fq.t) ->
          Fp.of_bigint (Fq.to_bigint x) )
    in
    let open Types.Dlog_based.Statement in
    let (T (typ, f)) = Spec.packed_typ (module Impl) (T (fp, Fn.id)) spec in
    let typ = Typ.transport typ ~there:to_data ~back:of_data in
    Spec.ETyp.T (typ, fun x -> of_data (f x))
end
