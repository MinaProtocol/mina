open Core

module Field = struct
  type t

  let one : t = failwith "TODO"
end

module G = struct
  type t
end

module Bool = struct
  type t
end

module Poly = struct
  type 'a t =
    | Literal of 'a
    | Pow of 'a t * int
    | Add of 'a t * 'a t
    | Mul of 'a t * 'a t


  let (+) x y = Add (x, y)
  let ( * ) x y = Mul (x, y)

  let (^) x n = Pow (x, n)

  module Bivariate = struct
    type nonrec t = [ `R | `S' | `X | `Y | `Field of Field.t ] t
  end

  module Univariate = struct
    type nonrec t =
        [ `Z
        | `Field of Field.t
        | `T_plus of Field.t
        | `T_minus of Field.t
        | `Subst of [`X | `Y] * Bivariate.t * Field.t ] t
  end

  module Expr = struct
    type nonrec t =
      [ `Field of Field.t
      | `Subst of [ `Z ] * Univariate.t * Field.t ] t
  end

(*   let one = Literal Field.one *)

  let r = Literal `R
  let x : Bivariate.t = Literal `X
  let y : Bivariate.t = Literal `Y
  let z = Literal `Z
  let const x = Literal (`Field x)

  let (!) x = Literal x

  let t_plus y = ! (`T_plus y)
  let t_minus y = ! (`T_minus y)

  let s' : Bivariate.t = ! `S'

  let (:=) ((p : Bivariate.t), var) x = Literal (`Subst (var, p, x))
end


type 'a tag = ..

module Commitment = struct
  type t
end

type _ tag +=
  | Commitment : Commitment.t tag

type 'a computation =
  | Polynomial_commitment : Poly.Univariate.t -> Commitment.t computation

module T = struct
  module F = struct
    type 'k t = 
      | Commit of Poly.Univariate.t * (Commitment.t -> 'k)
      | Open of Commitment.t * Field.t * (Field.t -> 'k)
      | Challenge of (Field.t -> 'k)
      | Mul of Field.t * Field.t * (Field.t -> 'k)
      | Assert_equal of Poly.Expr.t * Poly.Expr.t * 'k

    let map t ~f =
      let cont k = fun x -> f (k x) in
      match t with
      | Commit (p, k) -> Commit (p, cont k)
      | Challenge k -> Challenge (cont k)
      | Open (c, x, k) -> Open (c, x, cont k)
      | Assert_equal (x, y, k) -> Assert_equal (x, y, f k)
      | Mul (x, y, k) -> Mul (x, y, cont k)
  end

  include Snarky.Free_monad.Make(F)

  let commit p = Free (Commit (p, return))
  let challenge = Free (Challenge return)
  let open_ c x = Free (Open (c, x, return))
  let mul x y = Free (Mul (x, y, return))
  let (==) x y = Free (Assert_equal (x, y, return ()))
  let (===) a b = Poly.const a == Poly.const b
end

let k : int = failwith "TODO"
let n : int = Int.pow 2 (k - 2)

(* What happens in which SNARK ? *)

let verify =
  let open T in let open Let_syntax in
  let s_old = failwith "TODO" in
  let y_old = failwith "TODO" in
  let%bind r =
    commit Poly.(
      ((r, `Y) := Field.one)
      * (z ^ Int.(3 * n - 1)))
  in
  let%bind y_cur  = challenge in
  let%bind t_plus = commit (Poly.t_plus y_cur)
  and t_minus     = commit (Poly.t_minus y_cur)
  and s_cur       = commit Poly.(((s', `Y) := y_cur) * (z ^ n))
  in
  let%bind x_challenge = challenge in
  let%bind c = commit Poly.( ((s', `X) := x_challenge) * (const x_challenge ^ n)) in
  let%bind y_new = challenge in
  let%bind s_new = commit Poly.( ((s', `Y) := y_new) * (z ^ n)) in
  let%bind s_cur_x = open_ s_cur x_challenge in
  (* TODO: equation 1 check from page 9 *)
  let%bind () =
    let%bind xy_cur = mul x_challenge y_cur in
    let%bind r_x = open_ r x_challenge
    and r_xy = open_ r xy_cur
    and t_plus_x = open_ t_plus x_challenge
    and t_minus_x = open_ t_minus x_challenge
    in
    return ()
  in
  let%bind () =
    let%bind c_y_old = open_ c y_old
    and c_y_cur = open_ c y_cur
    and s_old_x = open_ s_old x_challenge
    in
    all_unit [
      s_cur_x === c_y_cur;
      s_old_x === c_y_old
    ]
  in
  let%bind () =
    let%bind c_y_new = open_ c y_new
    and s_new_x = open_ s_new x_challenge in
    s_new_x === c_y_new
  in
  return ()

