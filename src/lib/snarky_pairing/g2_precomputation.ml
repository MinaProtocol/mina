module type S = sig
  module Impl : Snarky.Snark_intf.S

  module Fqe : Snarky_field_extensions.Intf.S with module Impl = Impl

  module Coeff : sig
    type t = {rx: Fqe.t; ry: Fqe.t; gamma: Fqe.t; gamma_x: Fqe.t}
  end

  type t = {q: Fqe.t * Fqe.t; coeffs: Coeff.t list}

  val create : Fqe.t * Fqe.t -> (t, _) Impl.Checked.t
end

module Make
    (Fqe : Snarky_field_extensions.Intf.S)
    (N : Snarkette.Nat_intf.S) (Params : sig
        val coeff_a : Fqe.t

        val loop_count : N.t
    end) =
struct
  module Fqe = Fqe
  module Impl = Fqe.Impl

  module Coeff = struct
    type t = {rx: Fqe.t; ry: Fqe.t; gamma: Fqe.t; gamma_x: Fqe.t}
  end

  type g2 = Fqe.t * Fqe.t

  type t = {q: g2; coeffs: Coeff.t list}

  open Impl
  open Let_syntax

  type loop_state = {rx: Fqe.t; ry: Fqe.t}

  (* I verified using sage that if the input [s] satisfies ry^2 = rx^3 + a rx + b, then
   so does the output. *)
  let doubling_step (s : loop_state) =
    let open Fqe in
    let%bind c =
      let%bind gamma =
        let%bind rx_squared = square s.rx in
        div_unsafe
          (scale rx_squared (Field.of_int 3) + Params.coeff_a)
          (scale s.ry (Field.of_int 2))
        (* ry will never be zero. And thus this [div_unsafe] is ok.
             A loop invariant is that s is actually a non-identity curve point.
             If ry = 0 then s is a point of order <= two, and hence the identity
             since our curve has prime order. *)
      in
      let%map gamma_x = gamma * s.rx in
      {Coeff.rx= s.rx; ry= s.ry; gamma; gamma_x}
    in
    let%map s =
      let%bind rx =
        let%map gamma_squared = square c.gamma in
        gamma_squared - scale s.rx (Field.of_int 2)
      in
      let%map ry =
        let%map t = c.gamma * (s.rx - rx) in
        t - s.ry
      in
      {rx; ry}
    in
    (s, c)

  (* I verified using sage that if both q and s are on the curve than so is the output. *)
  let addition_step naf_i ~q:(qx, qy) (s : loop_state) =
    let open Fqe in
    let%bind c =
      let%bind gamma =
        let top = if naf_i > 0 then s.ry - qy else s.ry + qy in
        (*  This [div_unsafe] is definitely safe in the context of pre-processing
            a verification key. The reason is the following. The top hash of the SNARK commits
            the prover to using the correct verification key inside the SNARK, and we know for
            that verification key that we will not hit a 0/0 case.

            In the general pairing context (e.g., for precomputing on G2 elements in the proof),
            I am not certain about this use of [div_unsafe]. *)
        div_unsafe top (s.rx - qx)
      in
      let%map gamma_x = gamma * qx in
      {Coeff.rx= s.rx; ry= s.ry; gamma; gamma_x}
    in
    let%map s =
      let%bind rx =
        let%map gamma_squared = square c.gamma in
        gamma_squared - (s.rx + qx)
      in
      let%map ry =
        let%map t = c.gamma * (s.rx - rx) in
        t - s.ry
      in
      {rx; ry}
    in
    (s, c)

  (* TODO: I believe this updates the computation of s even when it doesn't have to.
     Not a huge deal, but it does waste a few [Fqe] multiplications. *)
  let create ((qx, qy) as q) =
    let naf = Snarkette.Fields.find_wnaf (module N) 1 Params.loop_count in
    let rec go i found_nonzero (s : loop_state) acc =
      if i < 0 then return (List.rev acc)
      else if not found_nonzero then
        go (i - 1) (found_nonzero || naf.(i) <> 0) s acc
      else
        let%bind s, c = doubling_step s in
        let acc = c :: acc in
        if naf.(i) <> 0 then
          let%bind s, c = addition_step naf.(i) ~q s in
          let acc = c :: acc in
          go (i - 1) found_nonzero s acc
        else go (i - 1) found_nonzero s acc
    in
    let%map coeffs = go (Array.length naf - 1) false {rx= qx; ry= qy} [] in
    {q; coeffs}
end
