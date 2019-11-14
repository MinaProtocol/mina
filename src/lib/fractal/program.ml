open Core_kernel
  type t = Statement.t list

  open Statement

  let rec to_ocaml = function
    | [] ->
        ""
    | Assign (name, e) :: ss ->
        sprintf "let %s = %s in\n%s" name (Expr.to_ocaml e) (to_ocaml ss)
    | [Return e] ->
        Expr.to_ocaml e
    | Proc_call (name, args) :: ss ->
        sprintf "%s;\n%s" (Expr.to_ocaml (Fun_call (name, args))) (to_ocaml ss)
    | Method_call (self, name, args) :: ss ->
      sprintf "%s;\n%s" 
        (Expr.to_ocaml (Method_call (self, name, args))) (to_ocaml ss)
    | Return _ :: _ :: _ ->
        failwith "Return should be the last statement"

  let rec to_rust = function
    | [] ->
        ""
    | Assign (name, e) :: ss ->
      sprintf "let %s = %s;\n%s" name (Expr.to_rust e) (to_rust ss)
    | [Return e] ->
      sprintf "return %s;" (Expr.to_rust e)
    | Proc_call (name, args) :: ss ->
        sprintf "%s;\n%s" (Expr.to_rust (Fun_call (name, args))) (to_rust ss)
    | Return _ :: _ :: _ ->
        failwith "Return should be the last statement"
    | Method_call (self, name, args) :: ss ->
        sprintf "%s;\n%s" (Expr.to_rust (Method_call (self, name, args))) (to_rust ss)

  let rec to_cpp = function
    | [] ->
        ""
    | Assign (name, e) :: ss ->
      sprintf "auto %s = %s;\n%s" name (Expr.to_cpp e) (to_cpp ss)
    | [Return e] ->
      sprintf "return %s;" (Expr.to_cpp e)
    | Proc_call (name, args) :: ss ->
        sprintf "%s;\n%s" (Expr.to_cpp (Fun_call (name, args))) (to_cpp ss)
    | Return _ :: _ :: _ ->
        failwith "Return should be the last statement"
    | Method_call (self, name, args) :: ss ->
        sprintf "%s;\n%s" (Expr.to_cpp (Method_call (self, name, args))) (to_cpp ss)

