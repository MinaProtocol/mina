open Core_kernel
open Async_kernel

module Writer = Pipe.Writer

module Reader : sig
  type ('a, 'tok) t

  val create : unit -> ('a, 'tok) t * 'a Writer.t

  val map : ('a, 'tok_a) t -> f:('a -> 'b) -> ('b, 'tok_b) t
end = struct
  type ('a, 'tok) t = 'a Pipe.Reader.t

  let create = Pipe.create

  let map = Pipe.map
end

let create = Reader.create

(*
module With_reader = struct
  type ('a, 'k) t =
    | T : (('a, 'tok) Reader.t -> 'k) -> ('a, 'k) t
end

*)
module Make_map (M : sig type a type b val f : a -> b end) : sig
  type tok

  val f : (M.a, tok) Reader.t -> (M.b, 'tok) Reader.t
end = struct
  type tok

  let f reader = Reader.map reader ~f:M.f
end

let () =
  let module Map = Make_map(struct type a = int type b = int let f x = x + 1 end) in
  let r, w = create () in
  let r' = Map.f r in
  let r'' = Map.f r in
  ()
;;

