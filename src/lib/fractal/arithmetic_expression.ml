    type 'f t =
      | Op of [`Add | `Sub | `Mul | `Div] * 'f t * 'f t
      | Constant of 'f
      | Negate of 'f t
      | Int of int

    let op o x y = Op (o, x, y)

    let ( + ) x y = op `Add x y

    let ( - ) x y = op `Sub x y

    let ( * ) x y = op `Mul x y

    let ( / ) x y = op `Div x y

    let constant x = Constant x

    let int x = Int x

    let ( ! ) = constant

    let to_expr ~constant ~int ~negate ~op t =
      let rec go = function
        | Op (o, x, y) ->
            Expr.Fun_call (op o, [go x; go y])
        | Constant x ->
            constant x
        | Int n ->
            int n
        | Negate x ->
          negate x
      in
      go t
