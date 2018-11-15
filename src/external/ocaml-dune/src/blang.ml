open! Stdune

module Op = struct
  type t =
    | Eq
    | Gt
    | Gte
    | Lte
    | Lt
    | Neq

  let eval t (x : Ordering.t) =
    match t, x with
    | (Eq  | Gte | Lte) , Eq
    | (Neq | Lt  | Lte) , Lt
    | (Neq | Gt  | Gte) , Gt -> true
    | _, _ -> false
end

type t =
  | Const of bool
  | Expr of String_with_vars.t
  | And of t list
  | Or of t list
  | Compare of Op.t * String_with_vars.t * String_with_vars.t

let true_ = Const true

let rec eval t ~dir ~f =
  match t with
  | Const x -> x
  | Expr sw ->
    begin match String_with_vars.expand sw ~mode:Single ~dir ~f with
    | String "true" -> true
    | String "false" -> false
    | _ ->
      let loc = String_with_vars.loc sw in
      Errors.fail loc "This value must be either true or false"
    end
  | And xs -> List.for_all ~f:(eval ~f ~dir) xs
  | Or xs -> List.exists ~f:(eval ~f ~dir) xs
  | Compare (op, x, y) ->
    let x = String_with_vars.expand x ~mode:Many ~dir ~f
    and y = String_with_vars.expand y ~mode:Many ~dir ~f in
    Op.eval op (Value.L.compare_vals ~dir x y)
