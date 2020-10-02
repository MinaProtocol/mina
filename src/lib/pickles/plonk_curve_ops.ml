open Core_kernel

module Make
    (Impl : Snarky_backendless.Snark_intf.Run)
    (G : Intf.Group(Impl).S with type t = Impl.Field.t * Impl.Field.t) =
struct
  open Zexe_backend_common.Plonk_constraint_system.Plonk_constraint
  open Impl

  let add_fast p1 p2 =
    let p3 =
      exists G.typ_unchecked
        ~compute:
          As_prover.(
            fun () -> G.Constant.( + ) (read G.typ p1) (read G.typ p2))
    in
    assert_
      [ { annotation= Some __LOC__
        ; basic=
            Zexe_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (EC_add {p1; p2; p3}) } ] ;
    p3

  (* TODO: Make sure (xt, yt) is a pure var *)
  let scale_fast ((xt, yt) as t : Field.t * Field.t)
      (`Times_two_plus_1_plus_2_to_len r) : Field.t * Field.t =
    let n = Array.length r in
    let acc = ref (with_label __LOC__ (fun () -> G.double t)) in
    let rows_rev = ref [] in
    let module Var = struct
      type t = Var.t

      include Sexpable.Of_sexpable
                (Int)
                (struct
                  include Var

                  let to_sexpable = index

                  let of_sexpable = create
                end)
    end in
    let () =
      for i = 0 to n - 1 do
        let xp, yp = !acc in
        let xq = xt in
        let l1 =
          exists Field.typ
            ~compute:
              As_prover.(
                fun () ->
                  (* (yq - yp) / (xq - xp) *)
                  let open Field.Constant in
                  let yq =
                    let yt = read_var yt in
                    if read Boolean.typ r.(i) then yt else negate yt
                  in
                  (yq - read_var yp) / (read_var xq - read_var xp))
        in
        let xr =
          As_prover.Ref.create
            As_prover.(
              fun () ->
                (* B l1^2 - A - xp - xq *)
                let open Field.Constant in
                (G.Params.b * square (read_var l1))
                - G.Params.a - read_var xp - read_var xq)
        in
        let l2 =
          As_prover.Ref.create
            As_prover.(
              fun () ->
                (* 2 yp / (xp - xr) - l1 *)
                let open Field.Constant in
                let yp = read_var yp in
                ((yp + yp) / (read_var xp - Ref.get xr)) - read_var l1)
        in
        let xs =
          exists Field.typ
            ~compute:
              As_prover.(
                fun () ->
                  (* B l2^2 - A - xr - xp *)
                  let open Field.Constant in
                  (G.Params.b * square (Ref.get l2))
                  - G.Params.a - Ref.get xr - read_var xp)
        in
        let ys =
          exists Field.typ
            ~compute:
              As_prover.(
                fun () ->
                  (* (xp - xs) * l2 - yp *)
                  let open Field.Constant in
                  ((read_var xp - read_var xs) * Ref.get l2) - read_var yp)
        in
        let row =
          { Zexe_backend_common.Scale_round.xt
          ; yt
          ; b= (r.(i) :> Field.t)
          ; l1
          ; xp
          ; yp
          ; xs
          ; ys }
        in
        rows_rev := row :: !rows_rev ;
        acc := (xs, ys)
      done
    in
    assert_
      [ { annotation= Some __LOC__
        ; basic=
            Zexe_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (EC_scale {state= Array.of_list_rev !rows_rev}) } ] ;
    !acc

  let scale_fast t (`Plus_two_to_len_minus_1 k) =
    with_label __LOC__ (fun () ->
        let t =
          with_label __LOC__ (fun () ->
              Tuple_lib.Double.map ~f:(Util.seal (module Impl)) t )
        in
        let m = Array.length k - 1 in
        let r = Array.init m ~f:(fun i -> k.(i + 1)) in
        let two_r_plus_1_plus_two_to_m =
          scale_fast t (`Times_two_plus_1_plus_2_to_len r)
        in
        G.if_ k.(0) ~then_:two_r_plus_1_plus_two_to_m
          ~else_:(G.( + ) two_r_plus_1_plus_two_to_m (G.negate t)) )
end
