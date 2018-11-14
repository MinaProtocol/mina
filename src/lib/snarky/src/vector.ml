open Ctypes
open Foreign
open Core

module type S = sig
  type elt

  type t

  val typ : t Ctypes.typ

  val delete : t -> unit

  val create : unit -> t

  val get : t -> int -> elt

  val emplace_back : t -> elt -> unit

  val length : t -> int
end

let with_prefix prefix s = sprintf "%s_%s" prefix s

module Make (M : sig
  type elt

  val typ : elt Ctypes.typ

  val schedule_delete : elt -> unit

  val prefix : string
end) : S with type elt = M.elt = struct
  type elt = M.elt

  type t = unit ptr

  let typ = ptr void

  let func_name = with_prefix M.prefix

  let delete = foreign (func_name "delete") (typ @-> returning void)

  let create =
    let stub = foreign (func_name "create") (void @-> returning typ) in
    fun () ->
      let t = stub () in
      Caml.Gc.finalise delete t ; t

  let get =
    let stub = foreign (func_name "get") (typ @-> int @-> returning M.typ) in
    fun t i ->
      let x = stub t i in
      M.schedule_delete x ; x

  let length = foreign (func_name "length") (typ @-> returning int)

  let emplace_back =
    foreign (func_name "emplace_back") (typ @-> M.typ @-> returning void)
end
