type t = exn

exception Code_error of Sexp.t

exception Fatal_error of string

exception Loc_error of Loc.t * string

external raise         : exn -> _ = "%raise"
external raise_notrace : exn -> _ = "%raise_notrace"
external reraise       : exn -> _ = "%reraise"

let fatalf ?loc fmt =
  Format.ksprintf (fun s ->
    match loc with
    | None -> raise (Fatal_error s)
    | Some loc -> raise (Loc_error (loc, s))
  ) fmt

let protectx x ~f ~finally =
  match f x with
  | y           -> finally x; y
  | exception e -> finally x; raise e

let protect ~f ~finally = protectx () ~f ~finally

let code_error message vars =
  Code_error
    (List (Atom message
           :: List.map vars ~f:(fun (name, value) ->
             Sexp.List [Atom name; value])))
  |> raise

include
  ((struct
    [@@@warning "-32-3"]
    let raise_with_backtrace exn _ = reraise exn
    include Printexc
    let raise_with_backtrace exn bt = raise_with_backtrace exn bt
  end) : (sig
     val raise_with_backtrace: exn -> Printexc.raw_backtrace -> _
   end))
