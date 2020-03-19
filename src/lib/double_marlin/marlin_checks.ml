open Core_kernel
open Rugelach_types

type 'field domain = < size: 'field ; vanishing_polynomial: 'field -> 'field >

module Make (Impl : Snarky.Snark_intf.Run) = struct
  open Impl
  open Util
  module F = Field

  type nonrec domain = Field.t domain

  (* x^{2 ^ k} - 1 *)
  let vanishing_polynomial domain x =
    let k = Domain.log2_size domain in
    let rec pow acc i = if i = 0 then acc else pow (F.square acc) (i - 1) in
    F.(pow x k - one)

  let domain (domain : Domain.t) : domain =
    let size = Field.of_int (Domain.size domain) in
    object
      method size = size

      method vanishing_polynomial x = vanishing_polynomial domain x
    end

  let sum' xs f = List.reduce_exn (List.map xs ~f) ~f:F.( + )

  let prod xs f = List.reduce_exn (List.map xs ~f) ~f:F.( * )

  open Vector

  let check ~input_domain ~domain_h ~domain_k ~x_hat_beta_1
      { Types.Dlog_based.Proof_state.Deferred_values.Marlin.sigma_2
      ; sigma_3
      ; alpha
      ; eta_a
      ; eta_b
      ; eta_c
      ; beta_1
      ; beta_2
      ; beta_3 }
      { Pairing_marlin_types.Evals.w_hat
      ; z_hat_a
      ; z_hat_b
      ; g_1
      ; h_1
      ; g_2
      ; h_2
      ; g_3
      ; h_3
      ; row= {a= row_a; b= row_b; c= row_c}
      ; col= {a= col_a; b= col_b; c= col_c}
      ; value= {a= value_a; b= value_b; c= value_c}
      ; rc= {a= rc_a; b= rc_b; c= rc_c} } =
    let open F in
    (* Marlin checks follow *)
    let row = abc row_a row_b row_c
    and col = abc col_a col_b col_c
    and value = abc value_a value_b value_c
    and rc = abc rc_a rc_b rc_c
    and eta = abc eta_a eta_b eta_c
    and z_ = abc z_hat_a z_hat_b (z_hat_a * z_hat_b) in
    let z_hat =
      (w_hat * vanishing_polynomial input_domain beta_1) + x_hat_beta_1
    in
    let sum = sum' in
    let r_alpha =
      let v_h_alpha = domain_h#vanishing_polynomial alpha in
      fun x -> (v_h_alpha - domain_h#vanishing_polynomial x) / (alpha - x)
    in
    let v_h_beta_1 = domain_h#vanishing_polynomial beta_1 in
    let v_h_beta_2 = domain_h#vanishing_polynomial beta_2 in
    let a_beta_3, b_beta_3 =
      let beta_1_beta_2 = beta_1 * beta_2 in
      let term =
        Memo.general ~cache_size_bound:10 (fun m ->
            beta_1_beta_2 + rc m - (beta_1 * row m) - (beta_2 * col m) )
      in
      let a =
        v_h_beta_1 * v_h_beta_2
        * sum ms (fun m -> eta m * value m * prod (all_but m) term)
      in
      let b = prod ms term in
      (a, b)
    in
    List.mapi
      ~f:(fun i (x, y) ->
        as_prover
          As_prover.(
            fun () ->
              let x = read_var x in
              let y = read_var y in
              if not (Field.Constant.equal x y) then (
                Core.printf "bad marlin %d\n%!" i ;
                Field.Constant.print x ;
                Core.printf "%!" ;
                Field.Constant.print y ;
                Core.printf "%!" )) ;
        equal x y )
      [ ( h_3 * domain_k#vanishing_polynomial beta_3
        , a_beta_3 - (b_beta_3 * ((beta_3 * g_3) + sigma_3)) )
      ; ( r_alpha beta_2 * sigma_3 * domain_k#size
        , (h_2 * v_h_beta_2) + sigma_2 + (g_2 * beta_2) )
      ; ( (r_alpha beta_1 * sum ms (fun m -> eta m * z_ m))
          - (sigma_2 * domain_h#size * z_hat)
        , (h_1 * v_h_beta_1) + (beta_1 * g_1) ) ]
    |> Boolean.all
end
