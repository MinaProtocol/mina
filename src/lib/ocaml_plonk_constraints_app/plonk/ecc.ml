open Core
open Snarky
open Zexe_backend_common
open Zexe_backend_common.Plonk_constraint_system
open Snarky_bn382.Tweedle

module Constraints (Intf : Snark_intf.Run with type prover_state = unit and type field = Dee.Field.t ) = struct
  open Intf
  open Field

  module Basic = struct
    open Constant

    let threehalfs = of_int 3 / of_int 2

    let add ((x1, y1) : field * field) ((x2, y2) : field * field) : field * field  =
      let s = (y2 - y1) / (x2 - x1) in
      let x3 = square s - x1 - x2 in
      let y3 = (x1 - x3) * s - y1 in
      (x3, y3)

    let double ((x, y) : field * field) : field * field  =
      let s = square x * threehalfs / y in
      let x1 = square s - x * of_int 2 in
      let y1 = s * (x - x1) - y in
      (x1, y1)
  end

  let add (p1 : t * t) (p2 : t * t) : t * t  =
    let p3 = exists Typ.(typ * typ) ~compute:As_prover.(fun () ->
        (Basic.add (read_var (fst p1), read_var (snd p1)) (read_var (fst p2), read_var (snd p2))))
    in
    Intf.assert_
      [{
        basic= Plonk_constraint.T (EC_add { p1; p2; p3 }) ;
        annotation= None
      }];
    p3

  let double ((x, y) : t * t) : t * t  =
    let s = square x * of_int 3 / of_int 2 / y in
    let x1 = square s - x * of_int 2 in
    let y1 = s * (x - x1) - y in
    x1, y1

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

  let endoscale ((xt, yt) : t * t) (scalar : t array) : t * t =
    (*
      Acc := [2](endo(P) + P)
      for i from n/2-1 down to 0:
        let S[i] =
          (
            [2r[2i] - 1]P; if r[2i+1] = 0
            endo[2r[2i] - 1]P; otherwise
          )
        Acc := (Acc + S[i]) + Acc
      return Acc
    *)
    let n = Array.length scalar in
    let n = Int.(if n%2 = 0 then n/2 else (n+1)/2) in
    let endo = Endo.Dee.scalar () in
    let xp, yp = double (add (Field.scale xt endo, yt) (xt, yt)) in

    let state = exists (Snarky.Typ.array ~length:n (Endoscale_round.typ typ)) ~compute:As_prover.(fun () ->
        (
          let state = ref [] in
          let xpl, ypl = ref (read_var xp), ref (read_var yp) in
          let xtl, ytl = read_var xt, read_var yt in

          for i = Int.(n - 1) downto 0 do
            let b2il = read_var scalar.(Int.(2 * i)) in
            let b2i1l = Int.(if 2*i+1 < (Array.length scalar) then read_var scalar.(2*i+1) else Field.Constant.zero) in
            let xql =  (one + (endo - one) * b2i1l) * xtl in
            let xsl, ysl = Basic.add (!xpl, !ypl) (Basic.add (!xpl, !ypl) (xql, (b2il+b2il-one) * ytl)) in
            let round = Endoscale_round.
            {
              b2i1= b2i1l; xt=xtl;
              b2i= b2il; xq= xql; yt=ytl;
              xp=(!xpl); l1=((!ypl)-((b2il+b2il-one) * ytl))/((!xpl)-(xql)); yp=(!ypl);
              xs=xsl; ys=ysl
            } in
            state := !state @ [round];
            xpl := xsl;
            ypl := ysl;
          done;
          Array.of_list !state
        ))
    in
    Array.iteri state ~f:(fun i s ->
    (
      s.xt <- xt; s.yt <- yt;
      s.b2i <- scalar.(Int.(2*(n-i-1)));
      s.b2i1 <- Int.(if 2*(n-i-1)+1 < (Array.length scalar) then scalar.(2*(n-i-1)+1) else Field.zero)
    ));
    state.(0).xp <- xp;
    state.(0).yp <- yp;
    Intf.assert_
      [{
        basic= Plonk_constraint.T (EC_endoscale { state }) ;
        annotation= None
      }];
    let finish = state.(Int.(n - 1)) in
    finish.xs, finish.ys

end
