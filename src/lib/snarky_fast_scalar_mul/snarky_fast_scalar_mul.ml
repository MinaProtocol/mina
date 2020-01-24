 open Core
open Snarky

module type Inputs_intf = sig
  module Impl : Snarky.Snark_intf.Run
  open Impl

  type t = Field.t * Field.t

  val a : field
  val b : field

  val double : t -> t

  val add : t -> t -> t

  val negate : t -> t
end

module type Field_intf = sig
  type t
  val ( + ) : t -> t -> t
  val ( * ) : t -> t -> t
  val square : t-> t
end

(*
module Sbox (Field : Field_intf ) = struct 
  open Field

    let sbox t =
      square (square t) * t
end

module Arithmetic_sponge 
(Field : Field_intf) : sig
type t

val init : unit -> t

val absorb : Field.t -> t -> unit

val squeeze : t -> Field.t
end  = struct 

  let rounds = 10

  let block_cipher state =
    Fn.apply_n_times rounds ~f:(fun state ->
      Array.map2_exn ~f:sbox
    )
    (Array.map2_exn ~f:Field.(+) state)
end
*)

(*
    Acc := [2] T
    for i from n-1 down to 0 {
        Q := ki+1 ? T : −T
        Acc := (Acc + Q) + Acc
    }
    return (k0 = 0) ? (Acc - T) : Acc


*)


module Make (Inputs : Inputs_intf) (*): sig
  open Inputs.Impl

  val scale : (Field.t * Field.t) -> (Boolean.var list) -> (Field.t * Field.t)
end *) = struct 
  open Inputs
  open Impl

(*)
  let conditional_negation (b: Boolean.var) (x, y) = 
    (x, Field.if_ b ~then_:y ~else_:(Field.(zero - y))) 

  let conditional_negation (b: Boolean.var) (x, y) = 
    (x, Field.((of_int 2 * (b :> Field.t) - of_int 1) * y))

  let conditional_negation (b: Boolean.var) (x, y) = 
    let y' = exists Field.typ ~compute:As_prover.(fun () ->
      if read Boolean.typ b
      then read Field.typ y
      else Field.Constant.negate (read Field.typ y))
    in
    assert_r1cs
      y
      Field.(of_int 2 * (b :> Field.t ) - of_int 1)
      y';
    (x, y')

 *)

(*
    (xQ - xP) × (λ1) = (yQ - yP)
    (B·λ1) × (λ1) = (A + xP + xQ + xR)
    (xP - xR) × (λ1 + λ2) = (2·yP)

and then complete the outer addition with:

    (B·λ2) × (λ2) = (A + xR + xP + xS)
    (xP - xS) × (λ2) = (yS + yP)*)
  
let p_plus_q_plus_p ((x1, y1) : Field.t * Field.t) ((x2, y2) : Field.t * Field.t) =
    let a = constant a in
    let b = constant b in
    let (!) = read Field.typ in
    let lambda_1  =
      exists Field.typ ~compute:As_prover.(fun () ->
        Field.Constant.(
          (!y2 - !y1) / (!x2 - !x1)
        )
      )
    in
    let x3 = 
      exists Field.typ ~compute:As_prover.(fun () ->
      Field.Constant.(
           !lambda_1 * !lambda_1  - !x1 - !x2
        )
      )
      in
    let lambda_2 = 
      exists Field.typ ~compute:As_prover.(fun () ->
      Field.Constant.(
          2 * !y1 /(!x1 - !x3) - !lambda_1
        )
      )
      in 
    let x4 = exists Field.typ ~compute:As_prover.(fun () ->
    Field.Constant.(
        !lambda_2 * !lambda_2 - !x3 - !x1
      )
    )
    in (* (xP - xS) × (λ2) = (yS + yP) *)
    let y4 = exists Field.typ ~compute:As_prover.(fun () ->
    Field.Constant.(
         (!x1 - !x4)  * !lambda_2  - !y1   
      )
    )
     in
    let open Field in
    assert_r1cs (x2 - x1) lambda_1 (y2 - y1);
    assert_r1cs
    (b * lambda_1) 
    lambda_1
    (x1 + x2 + x3);
    assert_r1cs
    (x3 - x1)
    (lambda_2)
    (y3 - y1);
    assert_r1cs
    (lambda_2)
    (lambda_2)
    (x3 + x1 + x4);
    assert_r1cs
    (x1 - x4 )
    lambda_2
    (y4 + y1);
    (x4, y4)

  let scale (t : Field.t * Field.t) (bits ) : (Field.t * Field.t) =
    let acc = ref (double t) in
    let () = for i = (Array.length bits - 1) downto 0 do
      let q = conditional_negation bits.(i) t in
      acc := p_plus_q_plus_p q !acc 
    done;
    in
    let res = Field.if_ bits.(0) ~then_:(!acc) ~else_:(add !acc (negate t)) in
    res;
end

(*
(x, y) -> (x, Field.if_ bits.(0) ~then_:y   ~else_:(Field.(zero - y)))
*)

module My_inputs = struct 
  module Impl = Snarky.Snark.Run.Make(Snarky.Backends.Mnt4.Default)(Unit)

  let a = Snarky.Backends.Mnt6.G1.Coefficients.a
  let b = Snarky.Backends.Mnt6.G1.Coefficients.b
end


(*
Weistrass
prover implementations



*)