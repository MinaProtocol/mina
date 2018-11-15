open Stdune

type t = Cmi | Cmo | Cmx

let all = [Cmi; Cmo; Cmx]

let choose cmi cmo cmx = function
  | Cmi -> cmi
  | Cmo -> cmo
  | Cmx -> cmx

let ext = choose ".cmi" ".cmo" ".cmx"

let source = choose Ml_kind.Intf Impl Impl

module Dict = struct
  type 'a t =
    { cmi : 'a
    ; cmo : 'a
    ; cmx : 'a
    }

  let get t = function
    | Cmi -> t.cmi
    | Cmo -> t.cmo
    | Cmx -> t.cmx

  let of_func f =
    { cmi = f ~cm_kind:Cmi
    ; cmo = f ~cm_kind:Cmo
    ; cmx = f ~cm_kind:Cmx
    }

  let make_all x =
    { cmi = x
    ; cmo = x
    ; cmx = x
    }
end

let to_sexp =
  let open Sexp.Encoder in
  function
  | Cmi -> string "cmi"
  | Cmo -> string "cmo"
  | Cmx -> string "cmx"
