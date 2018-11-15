type 'a t = 'a option =
  | None
  | Some of 'a

module O = struct
  let (>>|) t f =
    match t with
    | None   -> None
    | Some a -> Some (f a)

  let (>>=) t f =
    match t with
    | None   -> None
    | Some a -> f a
end

let map  t ~f = O.(>>|) t f
let bind t ~f = O.(>>=) t f

let iter t ~f =
  match t with
  | None -> ()
  | Some x -> f x

let value t ~default =
  match t with
  | Some x -> x
  | None -> default

let value_exn = function
  | Some x -> x
  | None -> invalid_arg "Option.value_exn"

let some x = Some x

let some_if cond x =
  if cond then Some x else None

let is_some = function
  | None   -> false
  | Some _ -> true

let is_none = function
  | None   -> true
  | Some _ -> false

let both x y =
  match x, y with
  | Some x, Some y -> Some (x, y)
  | _ -> None

let to_list = function
  | None -> []
  | Some x -> [x]

let equal eq x y =
  match (x, y) with
  | None, None -> true
  | Some _, None -> false
  | None, Some _ -> false
  | Some sx, Some sy -> eq sx sy

let compare cmp x y =
  match x, y with
  | None, None -> Ordering.Eq
  | Some _, None -> Gt
  | None, Some _ -> Lt
  | Some x, Some y -> cmp x y
