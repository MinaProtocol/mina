open Core_kernel

module Make3 (State : State_or_error_intf.State_intf2) :
  State_or_error_intf.S3 with type ('a, 'b) state = ('a, 'b) State.t = struct
  module T = struct
    type ('a, 'b) state = ('a, 'b) State.t

    type ('c, 'a, 'b) t = ('a, 'b) state -> ('c * ('a, 'b) state) Or_error.t

    let return : type a b c. c -> (c, a, b) t = fun a s -> Ok (a, s)

    let bind m ~f s =
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

module S3_to_S2 (X : State_or_error_intf.S3) :
  State_or_error_intf.S2
    with type ('a, 'b) t := ('a, 'b, unit) X.t
     and type 'a state := ('a, unit) X.state = struct
  include (
    X :
      State_or_error_intf.S3
        with type ('a, 'b, 'e) t := ('a, 'b, 'e) X.t
         and type ('b, 'e) state := ('b, 'e) X.state )
end

module S2_to_S (X : State_or_error_intf.S2) :
  State_or_error_intf.S
    with type 'a t := ('a, unit) X.t
     and type state := unit X.state = struct
  include (
    X :
      State_or_error_intf.S2
        with type ('a, 'b) t := ('a, 'b) X.t
         and type 'a state := 'a X.state )
end

module Make2 (State : State_or_error_intf.State_intf1) :
  State_or_error_intf.S2 = struct
  module M = Make3 (struct
    type ('a, 'b) t = 'a State.t
  end)

  type ('a, 'b) t = ('a, 'b, unit) M.t

  type 'a state = ('a, unit) M.state

  include S3_to_S2 (M)
end

module Make (State : State_or_error_intf.State_intf) : State_or_error_intf.S =
struct
  module M = Make2 (struct
    type 'a t = State.t
  end)

  type 'a t = ('a, unit) M.t

  type state = unit M.state

  include S2_to_S (M)
end
