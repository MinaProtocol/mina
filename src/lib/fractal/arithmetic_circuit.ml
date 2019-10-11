    module F = struct
      type ('k, 'f) t =
        | Eval : 'f Arithmetic_expression.t * ('f -> 'k) -> ('k, 'f) t

      let map t ~f = match t with Eval (x, k) -> Eval (x, fun y -> f (k y))
    end

    module T = Free_monad.Make2 (F)

    include (T : module type of T with module Let_syntax := T.Let_syntax)

    let eval x = Free (Eval (x, return))

    module Let_syntax = struct
      module Let_syntax = T.Let_syntax
      include Let_syntax.Let_syntax
    end
