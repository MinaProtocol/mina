open Core_kernel

[%%versioned
module Stable = struct
  module V2 = struct
    type 'f t = 'f Kimchi_types.scalar_challenge = { inner : 'f }
    [@@deriving sexp, compare, equal, yojson, hash]
  end
end]

let create t = { inner = t }

module Make_typ (Impl : Snarky_backendless.Snark_intf.Run) = struct
  let typ f =
    let there { inner = x } = x in
    let back x = create x in
    Impl.Typ.(transport_var (transport f ~there ~back) ~there ~back)
end

include Make_typ (Kimchi_pasta_snarky_backend.Step_impl)

include (
  struct
    include Make_typ (Kimchi_pasta_snarky_backend.Wrap_impl)

    let wrap_typ = typ
  end :
    sig
      val wrap_typ :
           ('var, 'value) Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t
        -> ('var t, 'value t) Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t
    end )

let map { inner = x } ~f = create (f x)
