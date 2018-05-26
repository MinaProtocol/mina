open Core_kernel
module Var = String

module Expr = struct
  type t =
    | Let of { name : Var.t; value : t; body : t }
    | Var of Var.t
    | Int of int
    | Add of t * t
    | Mul of t * t
  [@@deriving sexp]
end

let eval (e : Expr.t) : int =  
  let bindings = Var.Map.empty in
  let rec go (e : Expr.t) (bindings : int String.Map.t) : int =
    match e with
    | Let { name; value; body } -> 
      let bindings = String.Map.add bindings ~key:name ~data:(go value bindings) in
      go body bindings
    | Var var -> String.Map.find_exn bindings var
    | Int x -> x
    | Add (x, y) -> go x bindings + go y bindings
    | Mul (x, y) -> go x bindings * go y bindings
  in
  go e bindings

let x : Expr.t = 
  Let { name = "my_number"; value = Mul (Int 4, Int 5); body = Add (Int 7, Var "my_number") }
    

let () = printf "result: %d\n" (eval x)
