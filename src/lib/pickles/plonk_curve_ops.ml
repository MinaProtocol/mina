open Core_kernel

module Make
    (Impl : Snarky_backendless.Snark_intf.Run with type prover_state = unit)
    (G : Intf.Group(Impl).S with type t = Impl.Field.t * Impl.Field.t) =
struct
  open Zexe_backend_common.Plonk_constraint_system.Plonk_constraint
  open Impl

  let seal = Tuple_lib.Double.map ~f:(Util.seal (module Impl))

  let add_fast p1 p2 =
    let p1 = seal p1 in
    let p2 = seal p2 in
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

  let scale_fast t (`Plus_two_to_len scalar) =
    let ((xt, yt) as t) =
      with_label __LOC__ (fun () ->
          Tuple_lib.Double.map ~f:(Util.seal (module Impl)) t )
    in
    let module S = Zexe_backend_common.Scale_round in
    let n = Array.length scalar in
    if n = 0 then t
    else
      let p = add_fast (G.double t) t in
      let p =
        if n = 1 then p
        else
          let state =
            exists
              (Typ.array ~length:Int.(n - 1) (S.typ Field.typ))
              ~compute:
                As_prover.(
                  fun () ->
                    let xt, yt = Tuple_lib.Double.map t ~f:read_var in
                    let state = ref [] in
                    let pl = ref (read G.typ p) in
                    let tl = ref (read G.typ t) in
                    for i = Int.(n - 2) downto 0 do
                      let b = read Boolean.typ scalar.(Int.(i + 1)) in
                      let tl' = if b then !tl else G.Constant.negate !tl in
                      let sl = G.Constant.(!pl + (!pl + tl')) in
                      let xp, yp = G.Constant.to_affine_exn !pl in
                      let xs, ys = G.Constant.to_affine_exn sl in
                      let open Field.Constant in
                      let bit = if b then one else zero in
                      let round =
                        { S.xt
                        ; yt
                        ; b= bit
                        ; xp
                        ; yp
                        ; l1= (yp - (yt * (bit + bit - one))) / (xp - xt)
                        ; xs
                        ; ys }
                      in
                      state := round :: !state ;
                      pl := sl
                    done ;
                    Array.of_list_rev !state)
          in
          let state =
            Array.mapi state ~f:(fun i s ->
                {s with S.xt; yt; b= (scalar.(Int.(n - i - 1)) :> Field.t)} )
          in
          let xp, yp = p in
          state.(0) <- {(state.(0)) with xp; yp} ;
          assert_
            [ { annotation= Some __LOC__
              ; basic=
                  Zexe_backend_common.Plonk_constraint_system.Plonk_constraint
                  .T
                    (EC_scale {state}) } ] ;
          let fin = state.(Int.(n - 2)) in
          (fin.xs, fin.ys)
      in
      let tp = add_fast p (G.negate t) in
      G.if_ scalar.(0) ~then_:p ~else_:tp

  let scale_fast a b = with_label __LOC__ (fun () -> scale_fast a b)

  let%test_unit "scale fast" =
    let module T = Internal_Basic in
    let random_point =
      let rec pt x =
        let y2 = G.Params.(T.Field.(b + (x * (a + (x * x))))) in
        if T.Field.is_square y2 then (x, T.Field.sqrt y2)
        else pt T.Field.(x + one)
      in
      G.Constant.of_affine (pt (T.Field.of_int 0))
    in
    (*     let xs = [ true; true; false ; false ] in *)
    let n = Field.size_in_bits in
    Quickcheck.test ~trials:10
      (Quickcheck.Generator.list_with_length n Bool.quickcheck_generator)
      ~f:(fun xs ->
        try
          T.Test.test_equal ~equal:G.Constant.equal
            ~sexp_of_t:G.Constant.sexp_of_t
            (Typ.tuple2 G.typ (Typ.list ~length:n Boolean.typ))
            G.typ
            (fun (g, s) ->
              make_checked (fun () ->
                  scale_fast g (`Plus_two_to_len (Array.of_list s)) ) )
            (fun (g, s) ->
              let open G.Constant.Scalar in
              let shift = project (List.init n ~f:(fun _ -> false) @ [true]) in
              let x = project s + shift in
              G.Constant.scale g x )
            (random_point, xs)
        with e ->
          Core.eprintf !"Input %{sexp: bool list}\n%!" xs ;
          raise e )
end
