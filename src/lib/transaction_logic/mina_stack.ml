open Core_kernel
open Mina_base

module Make (Elt : sig
  type t
end) =
struct
  type t = Elt.t list

  let if_ = Zkapp_command.value_if

  let empty () = []

  let is_empty = List.is_empty

  let pop_exn : t -> Elt.t * t = function
    | [] ->
        failwith "pop_exn"
    | x :: xs ->
        (x, xs)

  let pop : t -> (Elt.t * t) option = function
    | x :: xs ->
        Some (x, xs)
    | _ ->
        None

  let push x ~onto : t = x :: onto
end

module Frame = struct
  include Stack_frame

  type t = value

  let if_ = Zkapp_command.value_if

  let make = Stack_frame.make
end
