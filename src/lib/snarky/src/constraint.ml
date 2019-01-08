open Base

type 'var basic =
  | Boolean of 'var
  | Equal of 'var * 'var
  | Square of 'var * 'var
  | R1CS of 'var * 'var * 'var
[@@deriving sexp]

type 'v basic_with_annotation = {basic: 'v basic; annotation: string option}
[@@deriving sexp]

type 'v t = 'v basic_with_annotation list [@@deriving sexp]

module T = struct
  let create_basic ?label basic = {basic; annotation= label}

  let override_label {basic; annotation= a} label_opt =
    {basic; annotation= (match label_opt with Some x -> Some x | None -> a)}

  let equal ?label x y = [create_basic ?label (Equal (x, y))]

  let boolean ?label x = [create_basic ?label (Boolean x)]

  let r1cs ?label a b c = [create_basic ?label (R1CS (a, b, c))]

  let square ?label a c = [create_basic ?label (Square (a, c))]

  let annotation (t : 'a t) =
    String.concat ~sep:"; "
      (List.filter_map t ~f:(fun {annotation; _} -> annotation))
end

include T
