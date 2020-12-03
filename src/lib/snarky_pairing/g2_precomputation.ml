open Core_kernel

module type S = sig
  module Impl : Snarky_backendless.Snark_intf.S

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
        val coeff_a : Fqe.Unchecked.t

        val loop_count : N.t
    end) =
struct
  module Fqe = Fqe
  module Impl = Fqe.Impl

  module Coeff = struct
    type t = {rx: Fqe.t; ry: Fqe.t; gamma: Fqe.t; gamma_x: Fqe.t}
    [@@deriving fields]
  end

  type g2 = Fqe.t * Fqe.t

  type t = {q: g2; coeffs: Coeff.t list}

  open Impl
  open Let_syntax

  let if_g2 b ~then_:(tx, ty) ~else_:(ex, ey) =
    let%map x = Fqe.if_ b ~then_:tx ~else_:ex
    and y = Fqe.if_ b ~then_:ty ~else_:ey in
    (x, y)

  let if_coeff b ~(then_ : Coeff.t) ~(else_ : Coeff.t) =
    let c p = Fqe.if_ b ~then_:(p then_) ~else_:(p else_) in
    let open Coeff in
    let%map rx = c rx
    and ry = c ry
    and gamma = c gamma
    and gamma_x = c gamma_x in
    {rx; ry; gamma; gamma_x}

  let if_ b ~then_ ~else_ =
    let%map q = if_g2 b ~then_:then_.q ~else_:else_.q
    and coeffs =
      Checked.List.map (List.zip_exn then_.coeffs else_.coeffs)
        ~f:(fun (t, e) -> if_coeff b ~then_:t ~else_:e)
    in
    {q; coeffs}

  type 'fqe loop_state = {rx: 'fqe; ry: 'fqe}

  let length (a, b, c) =
    let l = Field.Var.length in
    max (l a) (max (l b) (l c))

  let doubling_step_unchecked (s : Fqe.Unchecked.t loop_state) =
    let open Fqe in
    let open Unchecked in
    let gamma =
      let rx_squared = square s.rx in
      (rx_squared + rx_squared + rx_squared + Params.coeff_a) / (s.ry + s.ry)
    in
    let c =
      let gamma_x = gamma * s.rx in
      { Coeff.rx= constant s.rx
      ; ry= constant s.ry
      ; gamma= constant gamma
      ; gamma_x= constant gamma_x }
    in
    let s =
      let rx = square gamma - (s.rx + s.rx) in
      let ry = (gamma * (s.rx - rx)) - s.ry in
      {rx; ry}
    in
    (s, c)

  let addition_step_unchecked naf_i ~q:(qx, qy)
      (s : Fqe.Unchecked.t loop_state) =
    let open Fqe in
    let open Unchecked in
    let gamma =
      let top = if naf_i > 0 then s.ry - qy else s.ry + qy in
      (*  This [div_unsafe] is definitely safe in the context of pre-processing
            a verification key. The reason is the following. The top hash of the SNARK commits
            the prover to using the correct verification key inside the SNARK, and we know for
            that verification key that we will not hit a 0/0 case.

            In the general pairing context (e.g., for precomputing on G2 elements in the proof),
            I am not certain about this use of [div_unsafe]. *)
      top / (s.rx - qx)
    in
    let c =
      let gamma_x = gamma * qx in
      { Coeff.rx= constant s.rx
      ; ry= constant s.ry
      ; gamma= constant gamma
      ; gamma_x= constant gamma_x }
    in
    let s =
      let rx = square gamma - (s.rx + qx) in
      let ry = (gamma * (s.rx - rx)) - s.ry in
      {rx; ry}
    in
    (s, c)

  let create_constant ((qx, qy) as q) =
    let naf = Snarkette.Fields.find_wnaf (module N) 1 Params.loop_count in
    let rec go i found_nonzero (s : Fqe.Unchecked.t loop_state) acc =
      if i < 0 then List.rev acc
      else if not found_nonzero then
        go (i - 1) (found_nonzero || naf.(i) <> 0) s acc
      else
        let s, c = doubling_step_unchecked s in
        let acc = c :: acc in
        if naf.(i) <> 0 then
          let s, c = addition_step_unchecked naf.(i) ~q s in
          let acc = c :: acc in
          go (i - 1) found_nonzero s acc
        else go (i - 1) found_nonzero s acc
    in
    let coeffs = go (Array.length naf - 1) false {rx= qx; ry= qy} [] in
    {q= Fqe.(constant qx, constant qy); coeffs}

  (* I verified using sage that if the input [s] satisfies ry^2 = rx^3 + a rx + b, then
   so does the output. *)
  let doubling_step (s : Fqe.t loop_state) =
    with_label __LOC__
      (let open Fqe in
      let%bind c =
        let%bind gamma =
          let%bind rx_squared = square s.rx in
          div_unsafe
            (scale rx_squared (Field.of_int 3) + constant Params.coeff_a)
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
        with_label __LOC__
          (let%bind rx =
             let%bind res =
               exists Fqe.typ
                 ~compute:
                   As_prover.(
                     Let_syntax.(
                       let%map gamma = read Fqe.typ c.gamma
                       and srx = read Fqe.typ s.rx in
                       Fqe.Unchecked.(square gamma - (srx + srx))))
             in
             (* rx = c.gamma^2 - 2 * s.rx
           rx + 2 * s.rx = c.gamma^2
        *)
             let%map () =
               assert_square c.gamma (res + scale s.rx (Field.of_int 2))
             in
             res
           in
           let%map ry =
             (*
           ry = c.gamma * (s.rx - rx) - s.ry
           ry + s.ry = c.gamma * (s.rx - rx)
        *)
             let%bind res =
               exists Fqe.typ
                 ~compute:
                   As_prover.(
                     Let_syntax.(
                       let%map gamma = read Fqe.typ c.gamma
                       and srx = read Fqe.typ s.rx
                       and rx = read Fqe.typ rx
                       and sry = read Fqe.typ s.ry in
                       Fqe.Unchecked.((gamma * (srx - rx)) - sry)))
             in
             let%map () = assert_r1cs c.gamma (s.rx - rx) (res + s.ry) in
             res
           in
           {rx; ry})
      in
      (s, c))

  (* I verified using sage that if both q and s are on the curve than so is the output. *)
  let addition_step naf_i ~q:(qx, qy) (s : Fqe.t loop_state) =
    with_label __LOC__
      (let open Fqe in
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
          (* rx = c.gamma^2 - (s.rx + qx)
           c.gamma^2 = rx + s.rx + qx
        *)
          let%bind res =
            exists Fqe.typ
              ~compute:
                As_prover.(
                  Let_syntax.(
                    let%map gamma = read Fqe.typ c.gamma
                    and srx = read Fqe.typ s.rx
                    and qx = read Fqe.typ qx in
                    Unchecked.(square gamma - (srx + qx))))
          in
          let%map () = assert_square c.gamma (res + s.rx + qx) in
          res
        in
        let%map ry =
          (* ry = c.gamma * (s.rx - rx) - s.ry
           c.gamma * (s.rx - rx) = ry + s.ry
        *)
          let%bind res =
            exists Fqe.typ
              ~compute:
                As_prover.(
                  Let_syntax.(
                    let%map gamma = read Fqe.typ c.gamma
                    and srx = read Fqe.typ s.rx
                    and rx = read Fqe.typ rx
                    and sry = read Fqe.typ s.ry in
                    Unchecked.((gamma * (srx - rx)) - sry)))
          in
          let%map () = assert_r1cs c.gamma (s.rx - rx) (res + s.ry) in
          res
        in
        {rx; ry}
      in
      (s, c))

  (* TODO: I believe this updates the computation of s even when it doesn't have to.
     Not a huge deal, but it does waste a few [Fqe] multiplications. *)
  let create ((qx, qy) as q) =
    let naf = Snarkette.Fields.find_wnaf (module N) 1 Params.loop_count in
    let rec go i found_nonzero (s : Fqe.t loop_state) acc =
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
    with_label __LOC__
      (let%map coeffs = go (Array.length naf - 1) false {rx= qx; ry= qy} [] in
       {q; coeffs})
end
