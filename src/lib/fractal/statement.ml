type t =
  | Proc_call of Name.t * Expr.t list
  | Assign of Name.t * Expr.t
  | Return of Expr.t

