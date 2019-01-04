type ('a, 'e, 's) t =
  | Request of ('a Request.t, 'e, 's) As_prover.t
  | Compute of ('a, 'e, 's) As_prover.t
  | Both of ('a Request.t, 'e, 's) As_prover.t * ('a, 'e, 's) As_prover.t

let run t tbl s (handler : Request.Handler.t) =
  match t with
  | Request rc ->
      let s', r = As_prover.run rc tbl s in
      (s', Request.Handler.run handler r)
  | Compute c -> As_prover.run c tbl s
  | Both (rc, c) -> (
      let s', r = As_prover.run rc tbl s in
      match Request.Handler.run handler r with
      | exception _ -> As_prover.run c tbl s
      | x -> (s', x) )
