open Core_kernel

module Make
    (Impl : Snarky_backendless.Snark_intf.Run with type prover_state = unit)
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

  (*
    let module Var = struct
      type t = Var.t

      include Sexpable.Of_sexpable
                (Int)
                (struct
                  include Var

                  let to_sexpable = index

                  let of_sexpable = create
                end)
    end in *)

  (* TODO: Make sure (xt, yt) is a pure var *)
  let scale_fast ((xt, yt) as t : Field.t * Field.t)
      (`Times_two_plus_1_plus_2_to_len r) : Field.t * Field.t =
    let n = Array.length r in
    let acc = ref (with_label __LOC__ (fun () -> G.double t)) in
    let rows_rev = ref [] in
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
                (* l1^2 - xp - xq *)
                let open Field.Constant in
                square (read_var l1) - read_var xp - read_var xq)
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
                  (* l2^2 - xr - xp *)
                  let open Field.Constant in
                  square (Ref.get l2) - Ref.get xr - read_var xp)
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
          ~else_:(add_fast two_r_plus_1_plus_two_to_m (G.negate t)) )

  (*
  (* this function constrains computation of [2^n + k]T *)
  let scale ((xt, yt) : t * t) (scalar : t array) : t * t =
    (*
      Acc := [2] T + T
      for i from n-2 down to 0
          Q := ki+1 ? T : −T
          Acc := (Acc + Q) + Acc
      return (k0 = 0) ? (Acc - T) : Acc
    *)
    let n = Array.length scalar in
    if n = 0 then xt, yt
    else
      let xp, yp = add (double (xt, yt)) (xt, yt) in
      let xp, yp =
        if n < 2 then xp, yp
        else
          let state = exists (Snarky.Typ.array ~length:Int.(n - 1) (Scale_round.typ typ)) ~compute:As_prover.(fun () ->
              (
                let state = ref [] in
                let xpl, ypl = ref (read_var xp), ref (read_var yp) in
                let xtl, ytl = read_var xt, read_var yt in

                for i = Int.(n - 2) downto 0 do
                  let bit = read_var scalar.(Int.(i + 1)) in
                  let xsl, ysl = Basic.add (!xpl, !ypl) (Basic.add (!xpl, !ypl) (xtl, ytl * (bit+bit-one))) in
                  let round = Scale_round.
                  {
                    xt=xtl; b=bit; yt=ytl; xp=(!xpl);
                    l1=(!ypl-(ytl * (bit+bit-one)))/(!xpl-xtl);
                    yp=(!ypl); xs=xsl; ys=ysl
                  } in
                  state := !state @ [round];
                  xpl := xsl;
                  ypl := ysl;
                done;
                Array.of_list !state
              ))
          in
          Array.iteri state ~f:(fun i s -> (s.xt <- xt; s.yt <- yt; s.b <- scalar.(Int.(n-i-1))));
          state.(0).xp <- xp;
          state.(0).yp <- yp;
          Intf.assert_
            [{
              basic= Plonk_constraint.T (EC_scale { state }) ;
              annotation= None
            }];
          let finish = state.(Int.(n - 2)) in
          finish.xs, finish.ys
      in
      let xtp, ytp = add (xp, yp) (xt, negate yt) in
      let b = Intf.Boolean.of_field scalar.(0) in
      if_ b ~then_:xp ~else_:xtp, if_ b ~then_:yp ~else_:ytp
        *)

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
                    if Field.Constant.(equal xt zero) then begin
                      failwith "badd"
                    end ;
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
          let pre = !Zexe_backend_common.Plonk_constraint_system.next_row in
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
          let post = !Zexe_backend_common.Plonk_constraint_system.next_row in
          let bad = 194037 - 141 in
          if pre <= bad && bad <= post then begin
            as_prover As_prover.(fun () ->
                Core.printf !"xt: %{sexp:Field.Constant.t Snarky_backendless.Cvar.t}\n%!" xt ;
                Core.printf !"yt: %{sexp:Field.Constant.t Snarky_backendless.Cvar.t}\n%!" yt ;
              Array.iteri state ~f:(fun i r ->
                    Core.printf !"v[%d]: %{sexp:Field.Constant.t Snarky_backendless.Cvar.t S.t}\n%!" i
                      (r );
                    Core.printf !"w[%d]: %{sexp:Field.Constant.t S.t}\n%!" i
                      (read (S.typ Field.typ) r ) ) 
              ) 
          end ;
          let fin = state.(Int.(n - 2)) in
          (fin.xs, fin.ys)
      in
      let tp = add_fast p (G.negate t) in
      G.if_ scalar.(0) ~then_:p ~else_:tp

  let scale_fast a b = with_label __LOC__ (fun () -> scale_fast a b)

  (* b ? t : -t *)
  let conditional_negation (b : Boolean.var) (x, y) =
    let y' =
      exists Field.typ
        ~compute:
          As_prover.(
            fun () ->
              if read Boolean.typ b then read Field.typ y
              else Field.Constant.negate (read Field.typ y))
    in
    assert_r1cs y Field.((of_int 2 * (b :> Field.t)) - of_int 1) y' ;
    (x, y')

  let p_plus_q_plus_p (x1, y1) (x2, y2) =
    let open Field in
    let ( ! ) = As_prover.read typ in
    let lambda_1 =
      exists typ ~compute:Constant.(fun () -> (!y2 - !y1) / (!x2 - !x1))
    in
    let x3 =
      exists typ
        ~compute:Constant.(fun () -> (!lambda_1 * !lambda_1) - !x1 - !x2)
    in
    let lambda_2 =
      exists typ
        ~compute:
          Constant.(fun () -> (of_int 2 * !y1 / (!x1 - !x3)) - !lambda_1)
    in
    let x4 =
      exists typ
        ~compute:Constant.(fun () -> (!lambda_2 * !lambda_2) - !x3 - !x1)
    in
    let y4 =
      exists typ ~compute:Constant.(fun () -> ((!x1 - !x4) * !lambda_2) - !y1)
    in
    (* Determines lambda_1 *)
    assert_r1cs (x2 - x1) lambda_1 (y2 - y1) ;
    (* Determines x_3 *)
    assert_square lambda_1 (x1 + x2 + x3) ;
    (* Determines lambda_2 *)
    assert_r1cs (x1 - x3) (lambda_1 + lambda_2) (of_int 2 * y1) ;
    (* Determines x4 *)
    assert_square lambda_2 (x3 + x1 + x4) ;
    (* Determines y4 *)
    assert_r1cs (x1 - x4) lambda_2 (y4 + y1) ;
    (x4, y4)

  (*
  (* Input:
     t, r (LSB)

     Output:
    (2*r + 1 + 2^len(r)) t
  *)
  let scale_fast' (t : Field.t * Field.t) (`Times_two_plus_1_plus_2_to_len r) :
      Field.t * Field.t =
    let n = Array.length r in
    let acc = ref (G.double t) in
    as_prover As_prover.(fun () ->
      Core.printf !"acc = %{sexp: Field.Constant.t * Field.Constant.t}\n%!"
        (G.Constant.to_affine_exn (read G.typ !acc) ) ) ;
    let () =
      for i = 0 to n - 1 do
        let q = conditional_negation r.(i) t in
        acc := p_plus_q_plus_p !acc q ;
        as_prover As_prover.(fun () ->
          Core.printf !"acc = %{sexp: Field.Constant.t * Field.Constant.t}\n%!"
            (G.Constant.to_affine_exn (read G.typ !acc) ) ) ;
      done
    in
    !acc

  let scale_fast' t (`Plus_two_to_len_minus_1 k) =
    let m = Array.length k - 1 in
    let r = Array.init m ~f:(fun i -> k.(i + 1)) in
    let two_r_plus_1_plus_two_to_m =
      scale_fast' t (`Times_two_plus_1_plus_2_to_len r)
    in
    G.if_ k.(0) ~then_:two_r_plus_1_plus_two_to_m
      ~else_:(add_fast two_r_plus_1_plus_two_to_m (G.negate t))
*)
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
          (*
               s of length 3
               s = 5 = 0b101
               Checked: (s + 2)
               Unchecked: (s + 4)

               s of length 4
               Checked: s + 14
               Unchecked: s + 8

               s of length 5

               Checked: s + 2
               Unchecked s + 16
            *)
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
