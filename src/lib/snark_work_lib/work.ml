(* WARN:
   This file would be rewritten finally
*)
(*
  The better name for this file should really be poly.ml, because the types here
  are polymorphic, and we really need the concretized version in selector.ml
 *)
open Core_kernel

module Single = struct
  module Spec = Single_spec.Poly
end

module Spec = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'single t =
        { instances : 'single One_or_two.Stable.V1.t
        ; fee : Currency.Fee.Stable.V1.t
        }
      [@@deriving fields, sexp, yojson]

      let to_latest single_latest { instances; fee } =
        { instances = One_or_two.Stable.V1.to_latest single_latest instances
        ; fee
        }

      let of_latest single_latest { instances; fee } =
        let open Result.Let_syntax in
        let%map instances =
          One_or_two.Stable.V1.of_latest single_latest instances
        in
        { instances; fee }
    end
  end]

  type 'single t = 'single Stable.Latest.t =
    { instances : 'single One_or_two.t; fee : Currency.Fee.t }
  [@@deriving fields, sexp, yojson]

  let map ~f { instances; fee } =
    { instances = One_or_two.map ~f instances; fee }

  let map_opt ~f_single { instances; fee } =
    let%map.Option instances = One_or_two.Option.map ~f:f_single instances in
    { instances; fee }
end

module Result = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('spec, 'single) t =
        { proofs : 'single One_or_two.Stable.V1.t
        ; metrics :
            (Core.Time.Stable.Span.V1.t * [ `Transition | `Merge ])
            One_or_two.Stable.V1.t
        ; spec : 'spec
        ; prover : Signature_lib.Public_key.Compressed.Stable.V1.t
        }
      [@@deriving fields]
    end
  end]

  let map ~f_spec ~f_single { proofs; metrics; spec; prover } =
    { proofs = One_or_two.map ~f:f_single proofs
    ; metrics
    ; spec = f_spec spec
    ; prover
    }
end
