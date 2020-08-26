open Core
open Snarky
open Zexe_backend_common.R1cs_constraint_system

module Constraints (Intf : Snark_intf.Run with type prover_state = unit) = struct
  open Intf
  open Field

  module Basic = struct
    open Field.Constant

    let add (p1 : field * field) (p2 : field * field) : field * field  =
      let s = (snd p2 - snd p1) / (fst p2 - fst p1) in
      let x3 = square s - fst p1 - fst p2 in
      let y3 = (fst p1 - x3) * s - snd p1 in
      (x3, y3)

    let double (p : field * field) : field * field  =
      let s = square (fst p) * of_int 3 / of_int 2 / snd p in
      let x = square s - fst p * of_int 2 in
      let y = s * (fst p - x) - snd p in
      (x, y)
  end

  let add (p1 : Field.t * Field.t) (p2 : Field.t * Field.t) : Field.t * Field.t  =
    let p3 = exists Typ.(Field.typ * Field.typ) ~compute:As_prover.(fun () ->
        (Basic.add (read_var (fst p1), read_var (snd p1)) (read_var (fst p2), read_var (snd p2))))
    in
    Intf.assert_
      [{
        basic= Zexe_backend.R1CS_constraint_system.Plonk_constraint.T (EC_add { p1= p1; p2= p2; p3= p3 }) ;
        annotation= None
      }];
    p3

  let double (p : Field.t * Field.t) : Field.t * Field.t  =
    let s = square (fst p) * of_int 3 / of_int 2 / snd p in
    let x = square s - fst p * of_int 2 in
    let y = s * (fst p - x) - snd p in
    (x, y)

  let scale (base : Field.t * Field.t) (scalar : Field.t array) : Field.t * Field.t =
    let n = Array.length scalar in
    (*
      Acc := [2] T + T
      for i from n-2 down to 0
          Q := ki+1 ? T : −T
          Acc := (Acc + Q) + Acc
      return (k0 = 0) ? (Acc - T) : Acc
    *)

    let p = add (double base) base in

    let state = exists (Snarky.Typ.array ~length:n (Scale_round.typ Field.typ)) ~compute:As_prover.(fun () ->
        (
          let state = ref [] in
          let xpl, ypl = read_var (fst p), read_var (snd p) in

          for i = Int.(n - 2) to 0 do
            let xtl = read_var (fst base) in
            let ytl = read_var (snd base) in
            let bit = read_var scalar.(Int.(i + 1)) in
            let yq = if bit = Field.Constant.one then ytl else negate ytl in
            let xsl, ysl = Basic.add (xpl, ypl) (Basic.add (xpl, ypl) (xtl, yq)) in

            let round = Scale_round.{ xt=xtl; b=bit; yt=ytl; xp=xpl; l1=(ypl+yq)/(xpl-xtl); yp=ypl; xs=xsl; ys=ysl } in
            state := !state @ [round];
          done;
          Array.of_list !state
        ))
    in
    Intf.assert_
      [{
        basic= Zexe_backend.R1CS_constraint_system.Plonk_constraint.T (EC_scale { state }) ;
        annotation= None
      }];
    let finish = state.(Int.(n - 1)) in

    let if_pair b (tx, ty) (ex, ey) =
      Field.(if_ b ~then_:tx ~else_:ty, if_ b ~then_:ty ~else_:tx)
    in
    if_pair
      (Intf.Boolean.of_field scalar.(0))
       (add (finish.xs, finish.ys) (fst base, negate (snd base)))
        (finish.xs, finish.ys)

  let endoscale (p : Field.t * Field.t) (scalar : Field.t array) : Field.t * Field.t =
    let length = Array.length scalar in
    let state = exists (Snarky.Typ.array ~length:length (Endoscale_round.typ Field.typ)) ~compute:As_prover.(fun () ->
        (
          let state = Array.map scalar ~f:(fun x -> Endoscale_round.{
              b2i1= Field.Constant.zero;
              xt= Field.Constant.zero;
              b2i= Field.Constant.zero;
              xq= Field.Constant.zero;
              yt= Field.Constant.zero;
              xp= Field.Constant.zero;
              l1= Field.Constant.zero;
              yp= Field.Constant.zero;
              xs= Field.Constant.zero;
              ys= Field.Constant.zero; 
            }) in
          state
        ))
    in
    Intf.assert_
      [{
        basic= Zexe_backend.R1CS_constraint_system.Plonk_constraint.T (EC_endoscale { state }) ;
        annotation= None
      }];
    let finish = state.(Int.(length - 1)) in
    (finish.xs, finish.ys)

end
