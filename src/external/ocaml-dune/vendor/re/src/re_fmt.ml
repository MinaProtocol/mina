(** Very small tooling for format printers. *)

include Format

(* Only in the stdlib since 4.02, so we copy. *)
let rec list pp ppf = function
  | [] -> ()
  | [v] -> pp ppf v
  | v :: vs ->
    pp ppf v;
    pp_print_space ppf ();
    list pp ppf vs

let str = pp_print_string
let sexp fmt s pp x = fprintf fmt "@[<3>(%s@ %a)@]" s pp x
let pair pp1 pp2 fmt (v1,v2) =
  pp1 fmt v1; pp_print_space fmt () ; pp2 fmt v2
let triple pp1 pp2 pp3 fmt (v1, v2, v3) =
  pp1 fmt v1; pp_print_space fmt () ;
  pp2 fmt v2; pp_print_space fmt () ;
  pp3 fmt v3
let int = pp_print_int
let optint fmt = function
  | None -> ()
  | Some i -> fprintf fmt "@ %d" i
