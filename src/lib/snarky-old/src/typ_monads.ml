module Store = struct
  module T = struct
    type ('k, 'field, 'var) t = Store of 'field * ('var -> 'k)

    let map t ~f = match t with Store (x, k) -> Store (x, fun v -> f (k v))
  end

  include Free_monad.Make3 (T)

  let store x = Free (T.Store (x, fun v -> Pure v))

  let rec run t f =
    match t with Pure x -> x | Free (T.Store (x, k)) -> run (k (f x)) f
end

module Read = struct
  module T = struct
    type ('k, 'field, 'cvar) t = Read of 'cvar * ('field -> 'k)

    let map t ~f = match t with Read (v, k) -> Read (v, fun x -> f (k x))
  end

  include Free_monad.Make3 (T)

  let read v = Free (T.Read (v, return))

  let rec run t f =
    match t with Pure x -> x | Free (T.Read (x, k)) -> run (k (f x)) f
end

module Alloc = struct
  module T = struct
    type ('k, 'var) t = Alloc of ('var -> 'k)

    let map t ~f = match t with Alloc k -> Alloc (fun v -> f (k v))
  end

  include Free_monad.Make2 (T)

  let alloc = Free (T.Alloc (fun v -> Pure v))

  let rec run t f =
    match t with Pure x -> x | Free (T.Alloc k) -> run (k (f ())) f
end
