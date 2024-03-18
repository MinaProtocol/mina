(* mina_caqti.ml -- Mina helpers for the Caqti database bindings *)

let find_req t u s = Caqti_request.Infix.(t ->! u) s

let find_req_opt t u s = Caqti_request.Infix.(t ->? u) s

let collect_req t u s = Caqti_request.Infix.(t ->* u) s

let exec_req t s = Caqti_request.Infix.(t ->. Caqti_type.unit) s
