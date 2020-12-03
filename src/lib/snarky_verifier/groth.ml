open Core

(* This module implements a snarky function for the gammaless Groth16 verifier. *)
module Make (Inputs : Inputs.S) = struct
  open Inputs
  open Impl
  open Let_syntax

  module Verification_key = struct
    type ('g1, 'g2, 'fqk) t_ =
      {query_base: 'g1; query: 'g1 list; delta: 'g2; alpha_beta: 'fqk}
    [@@deriving fields]

    include Summary.Make (Inputs)

    let summary_length_in_bits ~twist_extension_degree ~input_size =
      summary_length_in_bits ~twist_extension_degree ~g1_count:(input_size + 1)
        ~g2_count:1 ~gt_count:1

    let summary_input {query_base; query; delta; alpha_beta} =
      {Summary.Input.g1s= query_base :: query; g2s= [delta]; gts= [alpha_beta]}

    type ('a, 'b, 'c) vk = ('a, 'b, 'c) t_

    let if_pair if_ b ~then_:(tx, ty) ~else_:(ex, ey) =
      let%map x = if_ b ~then_:tx ~else_:ex
      and y = if_ b ~then_:ty ~else_:ey in
      (x, y)

    let if_g1 b ~then_ ~else_ = if_pair Field.Checked.if_ b ~then_ ~else_

    let if_g2 b ~then_ ~else_ = if_pair Fqe.if_ b ~then_ ~else_

    let if_list if_ b ~then_ ~else_ =
      Checked.List.map (List.zip_exn then_ else_) ~f:(fun (t, e) ->
          if_ b ~then_:t ~else_:e )

    let if_ b ~then_ ~else_ =
      let c if_ p = if_ b ~then_:(p then_) ~else_:(p else_) in
      let%map query_base = c if_g1 query_base
      and query = c (if_list if_g1) query
      and delta = c if_g2 delta
      and alpha_beta = c Fqk.if_ alpha_beta in
      {query_base; query; delta; alpha_beta}

    module Precomputation = struct
      type t = {delta: G2_precomputation.t}

      let create (vk : (_, _, _) vk) =
        let%map delta = G2_precomputation.create vk.delta in
        {delta}

      let create_constant (vk : (_, _, _) vk) =
        {delta= G2_precomputation.create_constant vk.delta}

      let if_ b ~then_ ~else_ =
        let%map delta =
          G2_precomputation.if_ b ~then_:then_.delta ~else_:else_.delta
        in
        {delta}
    end
  end

  module Proof = struct
    type ('g1, 'g2) t_ = {a: 'g1; b: 'g2; c: 'g1} [@@deriving sexp, hlist]

    let typ =
      Typ.of_hlistable
        Data_spec.[G1.typ; G2.typ; G1.typ]
        ~var_to_hlist:t__to_hlist ~var_of_hlist:t__of_hlist
        ~value_to_hlist:t__to_hlist ~value_of_hlist:t__of_hlist
  end

  let verify (vk : (_, _, _) Verification_key.t_)
      (vk_precomp : Verification_key.Precomputation.t) inputs {Proof.a; b; c} =
    let%bind acc =
      let%bind (module Shifted) = G1.Shifted.create () in
      let%bind init = Shifted.(add zero vk.query_base) in
      Checked.List.fold (List.zip_exn vk.query inputs) ~init
        ~f:(fun acc (g, input) -> G1.scale (module Shifted) g input ~init:acc
      )
      >>= Shifted.unshift_nonzero
    in
    let%bind test =
      let%bind b = G2_precomputation.create b in
      batch_miller_loop
        (* This is where we use [one : G2.t] rather than gamma. *)
        [ ( Neg
          , G1_precomputation.create acc
          , G2_precomputation.create_constant G2.Unchecked.one )
        ; (Neg, G1_precomputation.create c, vk_precomp.delta)
        ; (Pos, G1_precomputation.create a, b) ]
      >>= final_exponentiation
    in
    Fqk.equal test vk.alpha_beta
end
