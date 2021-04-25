open Core
open Snarky
open Zexe_backend_common
open Zexe_backend_common.Plonk_plookup_constraint_system
open Marlin_plonk_bindings

module Constraints (Intf : Snark_intf.Run with type prover_state = unit and type field = Pasta_fp.t ) = struct
  open Intf
  open Field

  module Basic = struct
    open Constant

    let threehalfs = of_int 3 / of_int 2

    let add ((x1, y1) : field * field) ((x2, y2) : field * field) : (field * field) * field  =
      if x1 = zero && y1 = zero then ((x2, y2), zero)
      else if x2 = zero && y2 = zero then ((x1, y1), zero)
      else
      (
        let r = one / (x2 - x1) in
        let s = (y2 - y1) * r in
        let x3 = square s - x1 - x2 in
        let y3 = (x1 - x3) * s - y1 in
        ((x3, y3), r)
      )

    let double ((x, y) : field * field) : (field * field) * field =
      if x = zero && y = zero then ((zero, zero), zero)
      else
      (
        let r = one / y in
        let s = square x * threehalfs * r in
        let x1 = square s - x * of_int 2 in
        let y1 = s * (x - x1) - y in
        ((x1, y1), r)
      )

    let add1 ((x1, y1) : field * field) ((x2, y2) : field * field) : field * field  =
      if x1 = zero && y1 = zero then x2, y2
      else if x2 = zero && y2 = zero then x1, y1
      else if x2 = x1 then zero, zero
      else
      (
        let s = (y2 - y1) / (x2 - x1) in
        let x3 = square s - x1 - x2 in
        let y3 = (x1 - x3) * s - y1 in
        x3, y3
      )

    let double1 ((x, y) : field * field) : field * field =
      if y = zero then zero, zero
      else
      (
        let s = square x * threehalfs / y in
        let x1 = square s - x * of_int 2 in
        let y1 = s * (x - x1) - y in
        x1, y1
      )

    (*
      N ← P
      Q ← 0
      for i from 0 to m do
        if di = 1 then
            Q ← point_add(Q, N)
        N ← point_double(N)
      return Q
    *)
    let mul ((x, y) : field * field) (s: int): (field * field) =
      let rec doubleadd n q s =
        if s = 0 then n, q, s
        else
        (
          if (s land 1) = 1 then doubleadd (double1 n) (add1 q n) (s lsr 1)
          else doubleadd (double1 n) q (s lsr 1)
        )
      in
      let n, q, s = doubleadd (x, y) (zero, zero) s in
      q

      let rec random () =
      (
        let x = Int64.(Random.int64 max_value) in
        let x = Field.Constant.of_string (Int64.to_string x) in
        let y = Field.Constant.(x*x*x + (of_int 5)) in
        if is_square y = true then (x, y)
        else random ()
      )
    
  end

  let add (p1 : t * t) (p2 : t * t) : t * t  =
    let (p3, r) = exists Typ.((typ * typ) * typ) ~compute:As_prover.(fun () ->
        (Basic.add (read_var (fst p1), read_var (snd p1)) (read_var (fst p2), read_var (snd p2))))
    in
    assert_
      [{
        basic= Plonk_constraint.T (EC_add { p1; p2; p3; r }) ;
        annotation= None
      }];
    p3

  let sub ((x1, y1) : t * t) ((x2, y2) : t * t) : t * t =
    add (x1, y1) (x2, (Field.negate y2))

  let double (p1 : t * t) : t * t =
    let (p2, r) = exists Typ.((typ * typ) * typ) ~compute:As_prover.(fun () ->
        (Basic.double (read_var (fst p1), read_var (snd p1))))
    in
    assert_
      [{
        basic= Plonk_constraint.T (EC_double { p1; p2; r }) ;
        annotation= None
      }];
    p2

  (* this function constrains computation of [2^n + k]T with unpacking *)
  let scale_pack ((xt, yt) : t * t) (scalar : t) : t * t =

    (*
      Acc := [2] T + T
      for i from n-2 down to 0
          Q := ki+1 ? T : −T
          Acc := (Acc + Q) + Acc
      return (k0 = 0) ? (Acc - T) : Acc
    *)
    let n = Field.size_in_bits in
    let xp, yp = add (double (xt, yt)) (xt, yt) in
    let xp, yp, bit =
      let state = exists (Snarky.Typ.array ~length:Int.(n - 1) (Scale_pack_round_5_wires.typ typ)) ~compute:As_prover.(fun () ->
          (
            let bits =  Constant.unpack (read_var scalar) |> Array.of_list |>
              Array.map ~f:(fun x -> if x = true then Constant.one else Constant.zero) in
            let state = ref [] in
            let xpl, ypl = ref (read_var xp), ref (read_var yp) in
            let xtl, ytl = read_var xt, read_var yt in
            let n2l = ref zero in

            for i = Int.(n - 2) downto 0 do
              let bit = bits.(Int.(i + 1)) in
              let ((xtmp, ytmp), _) = Basic.add (!xpl, !ypl) (xtl, ytl * (bit+bit-one)) in
              let ((xsl, ysl), _) = Basic.add (!xpl, !ypl) (xtmp, ytmp) in
              let n1l = (!n2l) * (Constant.of_int 2) + bit in
              let round = Scale_pack_round_5_wires.
              {
                xt=xtl; b=bit; yt=ytl; xp=(!xpl);
                l1=(!ypl-(ytl * (bit+bit-one)))/(!xpl-xtl);
                yp=(!ypl); xs=xsl; ys=ysl;
                n1=n1l;
                n2=(!n2l)
              } in
              state := !state @ [round];
              xpl := xsl;
              ypl := ysl;
              n2l := n1l;
            done;
            Array.of_list !state
          ))
      in
      let bit = exists (typ) ~compute:As_prover.(fun () ->
      (
        let bits = Bigint.of_field (read_var scalar) in
        if Bigint.test_bit bits 0 then one else zero
      ))
      in
      let state = Array.mapi state ~f:(fun i s ->
      (
        if i > 0 then
        {
          s with
          xt = xt;
          yt = yt;
          n2 = state.(Int.(i-1)).n1;
          xp = state.(Int.(i-1)).xs;
          yp = state.(Int.(i-1)).ys;
        }
        else
        {
          s with
          xt = xt;
          yt = yt;
          xp = xp;
          yp = yp;
        }
      ))
      in
      assert_
        [{
          basic= Plonk_constraint.T (EC_scale_pack { state }) ;
          annotation= None
        }];
      let finish = state.(Int.(n - 2)) in
      assert_ (Constraint.equal scalar (finish.n1 * (Field.of_int 2) + bit));
      finish.xs, finish.ys, bit
    in
    let xtp, ytp = add (xp, yp) (xt, negate yt) in
    let b = Boolean.of_field bit in
    if_ b ~then_:xp ~else_:xtp, if_ b ~then_:yp ~else_:ytp

  (* this function constrains computation of [k]T with unpacking *)
  let mul ((xt, yt) : t * t) (scalar : t) : t * t =
    let rec dbl q n = if n < 1 then q else dbl (double q) Int.(n - 1) in
    sub (scale_pack (xt, yt) scalar) (dbl (xt, yt) Field.size_in_bits)

end
