open Pickles_types
open Core_kernel
open Import
open Backend

module Step = struct
  module Impl = Snarky_backendless.Snark.Run.Make (Tick) (Unit)
  include Impl
  module Fp = Field

  module Other_field = struct
    let size_in_bits = Fp.size_in_bits

    module Constant = struct
      type t = Tock.Field.t
    end

    type t = (* Low bits, high bit *)
      Fp.t * Boolean.var

    let typ =
      Typ.transport
        (Typ.tuple2 Fp.typ Boolean.typ)
        ~there:(fun x ->
          let low, high = Util.split_last (Tock.Field.to_bits x) in
          (Fp.Constant.project low, high) )
        ~back:(fun (low, high) ->
          let low, _ = Util.split_last (Fp.Constant.unpack low) in
          Tock.Field.of_bits (low @ [high]) )

    let to_bits (x, b) = Field.unpack x ~length:(Field.size_in_bits - 1) @ [b]
  end

  module Digest = Digest.Make (Impl)
  module Challenge = Challenge.Make (Impl)

  let input ~branching ~wrap_rounds =
    let open Types.Pairing_based.Statement in
    let spec = spec branching wrap_rounds in
    let (T (typ, f)) =
      Spec.packed_typ (module Impl) (T (Other_field.typ, Fn.id)) spec
    in
    let typ = Typ.transport typ ~there:to_data ~back:of_data in
    Spec.ETyp.T (typ, fun x -> of_data (f x))
end

module Wrap = struct
  module Impl = Snarky_backendless.Snark.Run.Make (Tock) (Unit)
  include Impl
  module Challenge = Challenge.Make (Impl)
  module Digest = Digest.Make (Impl)
  module Wrap_field = Tock.Field
  module Step_field = Tick.Field

  let input () =
    let fp_as_fq (x : Step_field.t) =
      Wrap_field.of_bigint (Step_field.to_bigint x)
    in
    let fp =
      Typ.transport Field.typ ~there:fp_as_fq ~back:(fun (x : Wrap_field.t) ->
          Step_field.of_bigint (Wrap_field.to_bigint x) )
    in
    let open Types.Dlog_based.Statement in
    let (T (typ, f)) =
      Spec.packed_typ (module Impl) (T (fp, Fn.id)) In_circuit.spec
    in
    let typ =
      Typ.transport typ ~there:In_circuit.to_data ~back:In_circuit.of_data
    in
    Spec.ETyp.T (typ, fun x -> In_circuit.of_data (f x))
end
