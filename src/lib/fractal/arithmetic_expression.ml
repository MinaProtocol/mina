    type 'f t =
      | Op of [`Add | `Sub | `Mul | `Div] * 'f t * 'f t
      | Pow of 'f t * int
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

    let to_expr' ~constant ~int ~negate ~op ~pow t =
      let rec go = function
        | Op (o, x, y) ->
          op o (go x) (go y)
        | Constant x ->
            constant x
        | Int n ->
            int n
        | Negate x ->
          negate (go x)
        | Pow (x,n) ->
          pow (go x) n
      in
      go t

    let to_expr ~constant ~int ~negate ~op ~pow t =
      let rec go = function
        | Op (o, x, y) ->
            Expr.Fun_call (op o, [go x; go y])
        | Constant x ->
            constant x
        | Int n ->
            int n
        | Negate x ->
          negate (go x)
        | Pow (x,n) ->
          pow (go x) n
      in
      go t

let rec map : type a b. a t -> f :(a -> b) -> b t =
  fun t ~f ->
  match t with
  | Op (o, x, y) ->
    Op (o,  map x ~f, map y ~f)
  | Constant x -> Constant (f x)
  | Int n ->
      int n
  | Negate x -> Negate (map x ~f)
  | Pow (x,n) -> Pow (map x ~f, n)
