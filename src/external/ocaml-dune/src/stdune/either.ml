type ('a, 'b) t =
  | Left  of 'a
  | Right of 'b

let map t ~l ~r =
  match t with
  | Left x -> l x
  | Right x -> r x
