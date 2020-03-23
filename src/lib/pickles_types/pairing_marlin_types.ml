open Core_kernel
module H_list = Snarky.H_list
module Typ = Snarky.Typ

module Evals = struct
  open Vector

  module Stable = struct
    module V1 = struct
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
        ; row: 'a Abc.Stable.V1.t
        ; col: 'a Abc.Stable.V1.t
        ; value: 'a Abc.Stable.V1.t
        ; rc: 'a Abc.Stable.V1.t }
      [@@deriving version, fields, bin_io]
    end

    module Latest = V1
  end

  include Stable.Latest

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
      ; g_3 } =
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
      ; g_3 ]

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
        ; g_3 ] =
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
    ; rc= {a= rc_a; b= rc_b; c= rc_c} }

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
            ; rc_c ]
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
    ; rc= {a= rc_a; b= rc_b; c= rc_c} }

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

    module Shift = Int

    module Unshifted_accumulators = struct
      module Stable = struct
        module V1 = struct
          type 'a t = 'a Shift.Map.t
          [@@deriving version {asserted}, sexp, bin_io]
        end

        module Latest = V1
      end

      include Stable.Latest
    end

    module Stable = struct
      module V1 = struct
        type ('g, 'unshifted) t =
          {shifted_accumulator: 'g; unshifted_accumulators: 'unshifted}
        [@@deriving version, fields, bin_io, sexp]
      end

      module Latest = V1
    end

    include Stable.Latest

    let to_hlist {shifted_accumulator; unshifted_accumulators} =
      H_list.[shifted_accumulator; unshifted_accumulators]

    let of_hlist
        ([shifted_accumulator; unshifted_accumulators] : (unit, _) H_list.t) =
      {shifted_accumulator; unshifted_accumulators}

    let typ (shifts : Shift.Set.t) g =
      let key_order = `Increasing in
      let there (xs : _ Unshifted_accumulators.t) =
        Map.to_alist ~key_order xs |> List.map ~f:snd
      in
      let back xs =
        Set.to_sequence ~order:key_order shifts
        |> Fn.flip Sequence.zip (Sequence.of_list xs)
        |> Shift.Map.of_increasing_sequence |> Or_error.ok_exn
      in
      Snarky.Typ.of_hlistable
        [ g
        ; Typ.transport (Typ.list ~length:(Set.length shifts) g) ~there ~back
          |> Typ.transport_var ~there ~back
          (*
         Vector.typ
           (Vector.typ g Unshifted_accumulators_per_branch.n)
           branches *)
         ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let assert_equal g t1 t2 =
      Vector.iter2 (unshifted_accumulators t1) (unshifted_accumulators t2) ~f:g ;
      on_both t1 t2 g shifted_accumulator

    let map {shifted_accumulator; unshifted_accumulators} ~f =
      { shifted_accumulator= f shifted_accumulator
      ; unshifted_accumulators= Map.map ~f unshifted_accumulators }

    let map2 t1 t2 ~f =
      { shifted_accumulator= f t1.shifted_accumulator t2.shifted_accumulator
      ; unshifted_accumulators=
          Int.Map.merge
            ~f:(fun ~key:_ -> function `Both (x, y) -> Some (f x y) | _ ->
                  failwith "map2: Key not present in both maps" )
            t1.unshifted_accumulators t2.unshifted_accumulators }

    let accumulate t add ~into =
      { shifted_accumulator= add into.shifted_accumulator t.shifted_accumulator
      ; unshifted_accumulators=
          Int.Map.merge into.unshifted_accumulators t.unshifted_accumulators
            ~f:(fun ~key:_ -> function
            | `Both (x, y) ->
                Some (add x y)
            | `Left x ->
                Some x
            | `Right y ->
                failwith "shift not present in accumulating map" ) }
  end

  module Opening_check = struct
    (* For a commitment f opening at a point z to a value v one checks

       e(f - [v], H) = e(pi, beta*H - z H)

       e(f - [v], H) = e(pi, beta*H) - e(pi, z H)

       e(f - [v], H) = e(pi, beta*H) - e(z pi, H)

       e(f - [v] + z pi, H) = e(pi, beta*H)
    *)
    module Stable = struct
      module V1 = struct
        type 'g t = {r_f_minus_r_v_plus_rz_pi: 'g; r_pi: 'g}
        [@@deriving version, fields, bin_io, sexp]
      end

      module Latest = V1
    end

    include Stable.Latest

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

    let map2 t1 t2 ~f =
      { r_f_minus_r_v_plus_rz_pi=
          f t1.r_f_minus_r_v_plus_rz_pi t2.r_f_minus_r_v_plus_rz_pi
      ; r_pi= f t1.r_pi t2.r_pi }
  end

  module Stable = struct
    module V1 = struct
      type ('g, 'unshifted) t =
        { opening_check: 'g Opening_check.t
        ; degree_bound_checks: ('g, 'unshifted) Degree_bound_checks.t }
      [@@deriving version, fields, bin_io, sexp]
    end

    module Latest = V1
  end

  include Stable.Latest

  let to_hlist {opening_check; degree_bound_checks} =
    H_list.[opening_check; degree_bound_checks]

  let of_hlist ([opening_check; degree_bound_checks] : (unit, _) H_list.t) =
    {opening_check; degree_bound_checks}

  let typ shifts g =
    Snarky.Typ.of_hlistable
      [Opening_check.typ g; Degree_bound_checks.typ shifts g]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  let assert_equal g t1 t2 =
    let on_both f = on_both t1 t2 f in
    on_both (Opening_check.assert_equal g) opening_check ;
    on_both (Degree_bound_checks.assert_equal g) degree_bound_checks

  let map {opening_check; degree_bound_checks} ~f =
    { opening_check= Opening_check.map ~f opening_check
    ; degree_bound_checks= Degree_bound_checks.map ~f degree_bound_checks }

  let map2 t1 t2 ~f =
    { opening_check= Opening_check.map2 ~f t1.opening_check t2.opening_check
    ; degree_bound_checks=
        Degree_bound_checks.map2 ~f t1.degree_bound_checks
          t2.degree_bound_checks }

  let accumulate t add ~into =
    { opening_check=
        Opening_check.map2 ~f:add t.opening_check into.opening_check
    ; degree_bound_checks=
        Degree_bound_checks.accumulate t.degree_bound_checks add
          ~into:into.degree_bound_checks }
end

module Opening = struct
  module Stable = struct
    module V1 = struct
      type ('proof, 'values) t = {proof: 'proof; values: 'values}
      [@@deriving version, fields, bin_io]
    end

    module Latest = V1
  end

  include Stable.Latest

  let to_hlist {proof; values} = H_list.[proof; values]

  let of_hlist ([proof; values] : (unit, _) H_list.t) = {proof; values}

  let typ proof values =
    Snarky.Typ.of_hlistable [proof; values] ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
end

module Openings = struct
  open Evals

  module Stable = struct
    module V1 = struct
      type ('proof, 'fp) t =
        {proofs: 'proof * 'proof * 'proof; evals: 'fp Evals.t}
      [@@deriving version, bin_io]
    end

    module Latest = V1
  end

  include Stable.Latest

  let to_hlist {proofs; evals} = H_list.[proofs; evals]

  let of_hlist ([proofs; evals] : (unit, _) H_list.t) = {proofs; evals}

  let typ proof fp =
    let open Snarky.Typ in
    of_hlistable
      [tuple3 proof proof proof; Evals.typ fp]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

module Degree_bounded = struct
  module Stable = struct
    module V1 = struct
      type 'pc t = 'pc * 'pc [@@deriving version, bin_io]
    end

    module Latest = V1
  end

  include Stable.Latest
end

module Messages = struct
  module Stable = struct
    module V1 = struct
      type ('pc, 'fp) t =
        { w_hat: 'pc
        ; z_hat_a: 'pc
        ; z_hat_b: 'pc
        ; gh_1: 'pc Degree_bounded.Stable.V1.t * 'pc
        ; sigma_gh_2: 'fp * ('pc Degree_bounded.Stable.V1.t * 'pc)
        ; sigma_gh_3: 'fp * ('pc Degree_bounded.Stable.V1.t * 'pc) }
      [@@deriving version, fields, bin_io]
    end

    module Latest = V1
  end

  include Stable.Latest

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
  module Stable = struct
    module V1 = struct
      type ('pc, 'fp, 'openings) t =
        {messages: ('pc, 'fp) Messages.t; openings: 'openings}
      [@@deriving version, fields, bin_io]
    end

    module Latest = V1
  end

  include Stable.Latest

  let to_hlist {messages; openings} = H_list.[messages; openings]

  let of_hlist ([messages; openings] : (unit, _) H_list.t) =
    {messages; openings}

  let typ pc fp openings =
    Snarky.Typ.of_hlistable
      [Messages.typ pc fp; openings]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end
