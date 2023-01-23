open Core_kernel
open Mina_base

type t = bool

module Assert = struct
  let is_true ~pos b =
    try assert b
    with Assert_failure _ ->
      let file, line, col, _ecol = pos in
      raise (Assert_failure (file, line, col))

  let any ~pos bs = List.exists ~f:Fn.id bs |> is_true ~pos
end

let if_ (b : bool) ~(then_ : t) ~(else_ : t) = if b then then_ else else_

let true_ = true

let false_ = false

let equal = Bool.equal

let not = not

let ( ||| ) = ( || )

let ( &&& ) = ( && )

let display b ~label = sprintf "%s: %b" label b

let all = List.for_all ~f:Fn.id

type failure_status = Transaction_status.Failure.t option

type failure_status_tbl = Transaction_status.Failure.Collection.t

let is_empty t = List.join t |> List.is_empty

let assert_with_failure_status_tbl ~pos b failure_status_tbl =
  let file, line, col, ecol = pos in
  if (not b) && not (is_empty failure_status_tbl) then
    (* Raise a more useful error message if we have a failure
       description. *)
    let failure_msg =
      Yojson.Safe.to_string
      @@ Transaction_status.Failure.Collection.Display.to_yojson
      @@ Transaction_status.Failure.Collection.to_display failure_status_tbl
    in
    Error.raise @@ Error.of_string
    @@ sprintf "File %S, line %d, characters %d-%d: %s" file line col ecol
         failure_msg
  else
    try assert b
    with Assert_failure _ -> raise (Assert_failure (file, line, col))
