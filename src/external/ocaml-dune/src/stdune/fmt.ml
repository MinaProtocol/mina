
(* CR-someday diml: we should define a GADT for this:

   {[
     type 'a t =
       | Int : int t
       | Box : ...
           | Colored : ...
   ]}

   This way we could separate the creation of messages from the
   actual rendering.
*)
type 'a t = Format.formatter -> 'a -> unit

let kstrf f fmt =
  let buf = Buffer.create 17 in
  let f fmt = Format.pp_print_flush fmt () ; f (Buffer.contents buf) in
  Format.kfprintf f (Format.formatter_of_buffer buf) fmt

let failwith fmt = kstrf failwith fmt

let list = Format.pp_print_list
let string s ppf = Format.pp_print_string ppf s

let text = Format.pp_print_text

let nl = Format.pp_print_newline

let prefix f g ppf x = f ppf; g ppf x

let ocaml_list pp fmt = function
  | [] -> Format.pp_print_string fmt "[]"
  | l ->
    Format.fprintf fmt "@[<hv>[ %a@ ]@]"
      (list ~pp_sep:(fun fmt () -> Format.fprintf fmt "@,; ")
         pp) l

let quoted fmt = Format.fprintf fmt "%S"

let const
  : 'a t -> 'a -> unit t
  = fun pp a' fmt () -> pp fmt a'

let record fmt = function
  | [] -> Format.pp_print_string fmt "{}"
  | xs ->
    let pp fmt (field, pp) =
      Format.fprintf fmt "@[<hov 1>%s@ =@ %a@]"
        field pp () in
    let pp_sep fmt () = Format.fprintf fmt "@,; " in
    Format.fprintf fmt "@[<hv>{ %a@ }@]"
      (Format.pp_print_list ~pp_sep pp) xs

let tuple ppfa ppfb fmt (a, b) =
  Format.fprintf fmt "@[<hv>(%a, %a)@]" ppfa a ppfb b

let optional ppf fmt = function
  | None -> Format.fprintf fmt "<None>"
  | Some a -> ppf fmt a
