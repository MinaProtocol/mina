type ('a, 'e, 's) t =
  | Request of ('a Request.t, 'e, 's) As_prover0.t
  | Compute of ('a, 'e, 's) As_prover0.t
  | Both of ('a Request.t, 'e, 's) As_prover0.t * ('a, 'e, 's) As_prover0.t

let run t tbl s (handler : Request.Handler.t) =
  match t with
  | Request rc ->
      let s', r = As_prover0.run rc tbl s in
      (s', Request.Handler.run handler r)
  | Compute c -> As_prover0.run c tbl s
  | Both (rc, c) -> (
      let s', r = As_prover0.run rc tbl s in
      match Request.Handler.run handler r with
      | exception _ -> As_prover0.run c tbl s
      | x -> (s', x) )
