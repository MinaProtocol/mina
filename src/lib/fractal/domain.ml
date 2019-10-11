open Core_kernel
  type t = Binary_roots_of_unity of int

  let size = function Binary_roots_of_unity k -> Int.pow 2 k

  module Expr = struct
    type nonrec t = Domain of t | Set_minus_input of t * int
  end

let vanishing = function
  | Binary_roots_of_unity k ->
      let rec go acc i =
        let open Arithmetic_expression in
        let open Arithmetic_circuit in
        if Int.(i = k) then eval (acc - int 1)
        else
          let%bind acc = eval (acc * acc) in
          go !acc Int.(i + 1)
      in
      fun x -> go x 1
