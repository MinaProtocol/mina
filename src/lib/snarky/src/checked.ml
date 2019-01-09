open Core_kernel
open Types.Checked

type ('a, 's, 'field, 'var, 'sys) t =
  ('a, 's, 'field, 'var, 'sys) Types.Checked.t

module T0 = struct
  let return x = Pure x

  let as_prover x = As_prover (x, return ())

  let rec map : type s a b field var sys.
      (a, s, field, var, sys) t -> f:(a -> b) -> (b, s, field, var, sys) t =
   fun t ~f ->
    match t with
    | Pure x -> Pure (f x)
    | With_label (s, t, k) -> With_label (s, t, fun b -> map (k b) ~f)
    | With_constraint_system (c, k) -> With_constraint_system (c, map k ~f)
    | As_prover (x, k) -> As_prover (x, map k ~f)
    | Add_constraint (c, t1) -> Add_constraint (c, map t1 ~f)
    | With_state (p, and_then, t_sub, k) ->
        With_state (p, and_then, t_sub, fun b -> map (k b) ~f)
    | With_handler (h, t, k) -> With_handler (h, t, fun b -> map (k b) ~f)
    | Clear_handler (t, k) -> Clear_handler (t, fun b -> map (k b) ~f)
    | Exists (typ, c, k) -> Exists (typ, c, fun v -> map (k v) ~f)
    | Next_auxiliary k -> Next_auxiliary (fun x -> map (k x) ~f)

  let map = `Custom map

  let rec bind : type s a b field var sys.
         (a, s, field, var, sys) t
      -> f:(a -> (b, s, field, var, sys) t)
      -> (b, s, field, var, sys) t =
   fun t ~f ->
    match t with
    | Pure x -> f x
    | With_label (s, t, k) -> With_label (s, t, fun b -> bind (k b) ~f)
    | With_constraint_system (c, k) -> With_constraint_system (c, bind k ~f)
    | As_prover (x, k) -> As_prover (x, bind k ~f)
    (* Someday: This case is probably a performance bug *)
    | Add_constraint (c, t1) -> Add_constraint (c, bind t1 ~f)
    | With_state (p, and_then, t_sub, k) ->
        With_state (p, and_then, t_sub, fun b -> bind (k b) ~f)
    | With_handler (h, t, k) -> With_handler (h, t, fun b -> bind (k b) ~f)
    | Clear_handler (t, k) -> Clear_handler (t, fun b -> bind (k b) ~f)
    | Exists (typ, c, k) -> Exists (typ, c, fun v -> bind (k v) ~f)
    | Next_auxiliary k -> Next_auxiliary (fun x -> bind (k x) ~f)
end

let rec all_unit = function
  | [] -> T0.return ()
  | t :: ts -> T0.bind t ~f:(fun () -> all_unit ts)

module Let_syntax = struct
  let bind = T0.bind

  let map =
    match T0.map with
    | `Define_using_bind -> fun ma ~f -> bind ma ~f:(fun a -> T0.return (f a))
    | `Custom x -> x

  let both a b = bind a ~f:(fun a -> map b ~f:(fun b -> (a, b)))
end

module T = struct
  include T0

  let request_witness (typ : ('var, 'value, 'field, 'cvar, 'sys) Types.Typ.t)
      (r : ('value Request.t, 'cvar -> 'field, 's) As_prover.t) =
    Exists (typ, Request r, fun h -> return (Handle.var h))

  let request ?such_that typ r =
    match such_that with
    | None -> request_witness typ (As_prover.return r)
    | Some such_that ->
        let open Let_syntax in
        let%bind x = request_witness typ (As_prover.return r) in
        let%map () = such_that x in
        x

  let provide_witness (typ : ('var, 'value, 'field, 'cvar, 'sys) Types.Typ.t)
      (c : ('value, 'cvar -> 'field, 's) As_prover.t) =
    Exists (typ, Compute c, fun h -> return (Handle.var h))

  let exists ?request ?compute typ =
    let provider =
      let request =
        Option.value request ~default:(As_prover.return Request.Fail)
      in
      match compute with
      | None -> Provider.Request request
      | Some c -> Provider.Both (request, c)
    in
    Exists (typ, provider, fun h -> return (Handle.var h))

  type response = Request.response

  let unhandled = Request.unhandled

  type request = Request.request =
    | With :
        { request: 'a Request.t
        ; respond: 'a Request.Response.t -> response }
        -> request

  let handle t k = With_handler (Request.Handler.create_single k, t, return)

  let next_auxiliary = Next_auxiliary return

  let with_constraint_system f = With_constraint_system (f, return ())

  let with_label s t = With_label (s, t, return)

  let do_nothing _ = As_prover.return ()

  let with_state ?(and_then = do_nothing) f sub =
    With_state (f, and_then, sub, return)

  let assert_ ?label c =
    Add_constraint
      (List.map c ~f:(fun c -> Constraint.override_label c label), return ())

  let assert_r1cs ?label a b c = assert_ (Constraint.r1cs ?label a b c)

  let assert_square ?label a c = assert_ (Constraint.square ?label a c)

  let assert_all =
    let map_concat_rev xss ~f =
      let rec go acc xs xss =
        match (xs, xss) with
        | [], [] -> acc
        | [], xs :: xss -> go acc xs xss
        | x :: xs, _ -> go (f x :: acc) xs xss
      in
      go [] [] xss
    in
    fun ?label cs ->
      Add_constraint
        ( map_concat_rev ~f:(fun c -> Constraint.override_label c label) cs
        , return () )

  let assert_equal ?label x y = assert_ (Constraint.equal ?label x y)
end

include T
