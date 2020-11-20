open Pickles_types
open Core_kernel
open Import
open Backend

module Step = struct
  module Impl = Snarky_backendless.Snark.Run.Make (Tick) (Unit)
  include Impl

  module Other_field = struct
    (* Tick.Field.t = p < q = Tock.Field.t *)
    let size_in_bits = Tock.Field.size_in_bits

    module Constant = Tock.Field

    type t = (* Low bits, high bit *)
      Field.t * Boolean.var

    let typ : (t, Constant.t) Typ.t =
      Typ.transport
        (Typ.tuple2 Field.typ Boolean.typ)
        ~there:(fun x ->
          let low, high = Util.split_last (Tock.Field.to_bits x) in
          (Field.Constant.project low, high) )
        ~back:(fun (low, high) ->
          let low, _ = Util.split_last (Field.Constant.unpack low) in
          Tock.Field.of_bits (low @ [high]) )

    let to_bits (x, b) = Field.unpack x ~length:(Field.size_in_bits - 1) @ [b]
  end

  module Digest = Digest.Make (Impl)
  module Challenge = Challenge.Make (Impl)

  let input ~branching ~wrap_rounds =
    let open Types.Pairing_based.Statement in
    let spec = spec branching wrap_rounds in
    let (T (typ, f)) =
      Spec.packed_typ
        (module Impl)
        (T (Shifted_value.typ Other_field.typ, Fn.id))
        spec
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

  module Other_field = struct
    module Constant = Tick.Field
    open Impl

    type t = Field.t

    let typ =
      Typ.transport Field.typ
        ~there:(Fn.compose Tock.Field.of_bits Tick.Field.to_bits)
        ~back:(Fn.compose Tick.Field.of_bits Tock.Field.to_bits)

    let to_bits x = Field.unpack x ~length:Field.size_in_bits
  end

  let input () =
    let fp : ('a, Other_field.Constant.t) Typ.t = Other_field.typ in
    let open Types.Dlog_based.Statement in
    let (T (typ, f)) =
      Spec.packed_typ
        (module Impl)
        (T (Shifted_value.typ fp, Fn.id))
        In_circuit.spec
    in
    let typ =
      Typ.transport typ ~there:In_circuit.to_data ~back:In_circuit.of_data
    in
    Spec.ETyp.T (typ, fun x -> In_circuit.of_data (f x))
end
