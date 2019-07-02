open Core_kernel

module Make : State_or_error_intf.S =
functor
  (State : State_or_error_intf.State_intf)
  ->
  struct
    module T = struct
      type state = State.t

      type 'a t = state -> ('a * state) Or_error.t

      let return : 'a -> 'a t = fun a s -> Ok (a, s)

      let bind m ~f = function
        | s ->
            let open Or_error.Let_syntax in
            let%bind a, s' = m s in
            f a s'

      let map = `Define_using_bind
    end

    include T
    include Monad.Make (T)

    let get = function s -> Ok (s, s)

    let put s = function _ -> Ok ((), s)

    let run_state t ~state = t state

    let error_if b ~message ~value =
      if b then fun _ -> Or_error.error_string message else return value
  end

module Make2 : State_or_error_intf.S2 =
functor
  (State : State_or_error_intf.State_intf1)
  ->
  struct
    module T = struct
      type 'a state = 'a State.t

      type ('b, 'a) t = 'a state -> ('b * 'a state) Or_error.t

      let return : 'b -> ('b, 'a) t = fun a s -> Ok (a, s)

      let bind m ~f = function
        | s ->
            let open Or_error.Let_syntax in
            let%bind a, s' = m s in
            f a s'

      let map = `Define_using_bind
    end

    include T
    include Monad.Make2 (T)

    let get = function s -> Ok (s, s)

    let put s = function _ -> Ok ((), s)

    let run_state t ~state = t state

    let error_if b ~message ~value =
      if b then fun _ -> Or_error.error_string message else return value
  end

module Make3 : State_or_error_intf.S3 =
functor
  (State : State_or_error_intf.State_intf2)
  ->
  struct
    module T = struct
      type ('a, 'b) state = ('a, 'b) State.t

      type ('c, 'a, 'b) t = ('a, 'b) state -> ('c * ('a, 'b) state) Or_error.t

      let return : type a b c. c -> (c, a, b) t = fun a s -> Ok (a, s)

      let bind m ~f = function
        | s ->
            let open Or_error.Let_syntax in
            let%bind a, s' = m s in
            f a s'

      let map = `Define_using_bind
    end

    include T
    include Monad.Make3 (T)

    let get = function s -> Ok (s, s)

    let put s = function _ -> Ok ((), s)

    let run_state t ~state = t state

    let error_if b ~message ~value =
      if b then fun _ -> Or_error.error_string message else return value
  end
