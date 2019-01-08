type ('a, 's, 'field, 'var, 'sys) t =
  ('a, 's, 'field, 'var, 'sys) Types.Checked.t

module T = struct
  open Types.Checked

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
