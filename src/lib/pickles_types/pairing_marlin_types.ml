open Core_kernel
module H_list = Snarky.H_list
module Typ = Snarky.Typ

module Evals = struct
  open Vector

  type 'a t =
    { w_hat: 'a
    ; z_hat_a: 'a
    ; z_hat_b: 'a
    ; g_1: 'a
    ; h_1: 'a
    ; g_2: 'a
    ; h_2: 'a
    ; g_3: 'a
    ; h_3: 'a
    ; row: 'a Abc.t
    ; col: 'a Abc.t
    ; value: 'a Abc.t 
    ; rc: 'a Abc.t 
    }
  [@@deriving fields, bin_io]

  (* This is just the order used for iterating when absorbing the evaluations
     into the sponge. *)
  let to_vector
      { w_hat
      ; z_hat_a
      ; z_hat_b
      ; h_1
      ; h_2
      ; h_3
      ; row= {a= row_a; b= row_b; c= row_c}
      ; col= {a= col_a; b= col_b; c= col_c}
      ; value= {a= value_a; b= value_b; c= value_c} 
      ; rc= {a= rc_a; b= rc_b; c= rc_c} 
      ; g_1
      ; g_2
      ; g_3
      } =
    Vector.
      [ w_hat
      ; z_hat_a
      ; z_hat_b
      ; h_1
      ; h_2
      ; h_3
      ; row_a
      ; row_b
      ; row_c
      ; col_a
      ; col_b
      ; col_c
      ; value_a
      ; value_b
      ; value_c
      ; rc_a
      ; rc_b
      ; rc_c
      ; g_1
      ; g_2
      ; g_3 
      ]

  let of_vector
      Vector.
        [ w_hat
        ; z_hat_a
        ; z_hat_b
        ; h_1
        ; h_2
        ; h_3
        ; row_a
        ; row_b
        ; row_c
        ; col_a
        ; col_b
        ; col_c
        ; value_a
        ; value_b
        ; value_c
        ; rc_a
        ; rc_b
        ; rc_c
        ; g_1
        ; g_2
        ; g_3 
        ] =
    { w_hat
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
    ; rc= {a= rc_a; b= rc_b; c= rc_c} 
    }

  let to_vectors
      { w_hat
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
      ; value= {a= value_a; b= value_b; c= value_c} } ~x_hat =
    Vector.
      ( ([x_hat; w_hat; z_hat_a; z_hat_b; h_1], [g_1])
      , ([h_2], [g_2])
      , ( [ h_3
          ; row_a
          ; row_b
          ; row_c
          ; col_a
          ; col_b
          ; col_c
          ; value_a
          ; value_b
          ; value_c ]
        , [g_3] ) )

  let to_combined_vectors
      { w_hat
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
      ; value= {a= value_a; b= value_b; c= value_c} } ~x_hat =
    Vector.
      ( [x_hat; w_hat; z_hat_a; z_hat_b; g_1; h_1]
      , [g_2; h_2]
      , [ g_3
        ; h_3
        ; row_a
        ; row_b
        ; row_c
        ; col_a
        ; col_b
        ; col_c
        ; value_a
        ; value_b
        ; value_c ] )

  let of_vectors
      Vector.(
        ( ([w_hat; z_hat_a; z_hat_b; h_1], [g_1])
        , ([h_2], [g_2])
        , ( [ h_3
            ; row_a
            ; row_b
            ; row_c
            ; col_a
            ; col_b
            ; col_c
            ; value_a
            ; value_b
            ; value_c 
            ; rc_a
            ; rc_b
            ; rc_c 
            ]
          , [g_3] ) )) =
    { w_hat
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
    ; rc= {a= rc_a; b= rc_b; c= rc_c} 
    }

  let typ fq =
    let there = to_vector in
    let back = of_vector in
    Vector.typ fq Nat.N21.n |> Typ.transport ~there ~back
    |> Typ.transport_var ~there ~back
end

module Accumulator = struct
  let on_both t1 t2 f x = f (x t1) (x t2)

  module Degree_bound_checks = struct
    (*
       For the degree bound checks

       e(U_i, beta^{N - d_i} H) = e(V_i, H)

       To batch this, we check (in Einstein notation)

       0
       = r_i ( e(U_i, beta^{N - d_i} H) - e(V_i, H) )
       = e(r_i U_i, beta^{N - d_i} H) - e(r_i V_i, H)
    *)

    module Unshifted_accumulators = struct
      module N = Nat.N2

      type 'a t = ('a, N.n) Vector.t

      include Vector.Binable (N)
    end

    type 'g t =
      { shifted_accumulator: 'g
      ; unshifted_accumulators: 'g Unshifted_accumulators.t }
    [@@deriving fields, bin_io]

    let to_hlist {shifted_accumulator; unshifted_accumulators} =
      H_list.[shifted_accumulator; unshifted_accumulators]

    let of_hlist
        ([shifted_accumulator; unshifted_accumulators] : (unit, _) H_list.t) =
      {shifted_accumulator; unshifted_accumulators}

    let typ g =
      Snarky.Typ.of_hlistable
        [g; Vector.typ g Unshifted_accumulators.N.n]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let assert_equal g t1 t2 =
      Vector.iter2 (unshifted_accumulators t1) (unshifted_accumulators t2) ~f:g ;
      on_both t1 t2 g shifted_accumulator

    let map {shifted_accumulator; unshifted_accumulators} ~f =
      { shifted_accumulator= f shifted_accumulator
      ; unshifted_accumulators= Vector.map ~f unshifted_accumulators }
  end

  module Opening_check = struct
    (* For a commitment f opening at a point z to a value v one checks

       e(f - [v], H) = e(pi, beta*H - z H)

       e(f - [v], H) = e(pi, beta*H) - e(pi, z H)

       e(f - [v], H) = e(pi, beta*H) - e(z pi, H)

       e(f - [v] + z pi, H) = e(pi, beta*H)
    *)
    type 'g t = {r_f_minus_r_v_plus_rz_pi: 'g; r_pi: 'g}
    [@@deriving fields, bin_io]

    let to_hlist {r_f_minus_r_v_plus_rz_pi; r_pi} =
      H_list.[r_f_minus_r_v_plus_rz_pi; r_pi]

    let of_hlist ([r_f_minus_r_v_plus_rz_pi; r_pi] : (unit, _) H_list.t) =
      {r_f_minus_r_v_plus_rz_pi; r_pi}

    let typ g =
      Snarky.Typ.of_hlistable [g; g] ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let assert_equal g t1 t2 =
      let on_both f = on_both t1 t2 f in
      List.iter ~f:(on_both g) [r_f_minus_r_v_plus_rz_pi; r_pi]

    let map {r_f_minus_r_v_plus_rz_pi; r_pi} ~f =
      {r_f_minus_r_v_plus_rz_pi= f r_f_minus_r_v_plus_rz_pi; r_pi= f r_pi}
  end

  type 'g t =
    { opening_check: 'g Opening_check.t
    ; degree_bound_checks: 'g Degree_bound_checks.t }
  [@@deriving fields, bin_io]

  let to_hlist {opening_check; degree_bound_checks} =
    H_list.[opening_check; degree_bound_checks]

  let of_hlist ([opening_check; degree_bound_checks] : (unit, _) H_list.t) =
    {opening_check; degree_bound_checks}

  let typ g =
    Snarky.Typ.of_hlistable
      [Opening_check.typ g; Degree_bound_checks.typ g]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  let assert_equal g t1 t2 =
    let on_both f = on_both t1 t2 f in
    on_both (Opening_check.assert_equal g) opening_check ;
    on_both (Degree_bound_checks.assert_equal g) degree_bound_checks

  let map {opening_check; degree_bound_checks} ~f =
    { opening_check= Opening_check.map ~f opening_check
    ; degree_bound_checks= Degree_bound_checks.map ~f degree_bound_checks }
end

module Opening = struct
  type ('proof, 'values) t = {proof: 'proof; values: 'values}
  [@@deriving fields, bin_io]

  let to_hlist {proof; values} = H_list.[proof; values]

  let of_hlist ([proof; values] : (unit, _) H_list.t) = {proof; values}

  let typ proof values =
    Snarky.Typ.of_hlistable [proof; values] ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
end

module Openings = struct
  open Evals

  type ('proof, 'fp) t = {proofs: 'proof Tuple_lib.Triple.t; evals: 'fp Evals.t}
  [@@deriving bin_io]

  let to_hlist {proofs; evals} = H_list.[proofs; evals]

  let of_hlist ([proofs; evals] : (unit, _) H_list.t) = {proofs; evals}

  let typ proof fp =
    let open Snarky.Typ in
    of_hlistable
      [tuple3 proof proof proof; Evals.typ fp]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

module Messages = struct
  type 'pc degree_bounded = 'pc * 'pc [@@deriving bin_io]

  type ('pc, 'fp) t =
    { w_hat: 'pc
    ; z_hat_a: 'pc
    ; z_hat_b: 'pc
    ; gh_1: 'pc degree_bounded * 'pc
    ; sigma_gh_2: 'fp * ('pc degree_bounded * 'pc)
    ; sigma_gh_3: 'fp * ('pc degree_bounded * 'pc) }
  [@@deriving fields, bin_io]

  let to_hlist {w_hat; z_hat_a; z_hat_b; gh_1; sigma_gh_2; sigma_gh_3} =
    H_list.[w_hat; z_hat_a; z_hat_b; gh_1; sigma_gh_2; sigma_gh_3]

  let of_hlist
      ([w_hat; z_hat_a; z_hat_b; gh_1; sigma_gh_2; sigma_gh_3] :
        (unit, _) H_list.t) =
    {w_hat; z_hat_a; z_hat_b; gh_1; sigma_gh_2; sigma_gh_3}

  let typ pc fp =
    let open Snarky.Typ in
    let db = pc * pc in
    of_hlistable
      [pc; pc; pc; db * pc; fp * (db * pc); fp * (db * pc)]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

module Proof = struct
  type ('pc, 'fp, 'openings) t =
    {messages: ('pc, 'fp) Messages.t; openings: 'openings}
  [@@(* ('proof, 'fp) Openings.t} *)
    deriving fields, bin_io]

  let to_hlist {messages; openings} = H_list.[messages; openings]

  let of_hlist ([messages; openings] : (unit, _) H_list.t) =
    {messages; openings}

  let typ pc fp openings =
    Snarky.Typ.of_hlistable
      [Messages.typ pc fp; openings]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end
