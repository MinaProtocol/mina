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

module E = struct
  module F = struct
    type ('k, _) t =
      | Eval : 'f Arithmetic_expression.t * ('f -> 'k) -> ('k, < field: 'f; .. >) t

    let map : type a b s. (a, s) t -> f:(a -> b) -> (b, s) t =
    fun t ~f -> match t with Eval (x, k) -> Eval (x, fun y -> f (k y))
  end

  module T = Free_monad.Make2 (F)

  include (T : module type of T with module Let_syntax := T.Let_syntax)

  let eval x = Free (Eval (x, return))

  module Let_syntax = struct
    module Let_syntax = T.Let_syntax
    include Let_syntax.Let_syntax
  end
end

module E2 = struct
  module F = struct
    type ('k, 'field, 'expr) t =
      | Eval of 'expr Arithmetic_expression.t * ('field -> 'k)

    let map : type a b f e. (a, f, e) t -> f:(a -> b) -> (b, f, e) t =
    fun t ~f -> match t with Eval (x, k) -> Eval (x, fun y -> f (k y))

    let interpret : type f e1 e2 k. (k, f, e1) t -> f:(e1 -> e2) -> (k, f, e2) t =
      fun t ~f ->
      match t with
      | Eval (e, k) -> Eval (Arithmetic_expression.map e ~f, k)
  end

  module T = Free_monad.Make3 (F)

  include (T : module type of T with module Let_syntax := T.Let_syntax)

  let rec interpret : type f e1 e2 a. (a, f, e1) t -> f:(e1 -> e2) -> (a, f, e2) t =
    fun t ~f ->
    match t with
    | Pure x -> Pure x
    | Free c -> Free (F.map (F.interpret c ~f) ~f:(interpret ~f))

  let eval x = Free (Eval (x, return))

  module Let_syntax = struct
    module Let_syntax = T.Let_syntax
    include Let_syntax.Let_syntax
  end
end
