open Core

module Var : sig
  type t 

  val (!) : string -> t
end = struct
  type t = string
  let (!) = Fn.id
end

module Ctx : sig
  type t
end = struct
  type t = Todo
end

module Op : sig
  type t
end = struct
  type t = Todo
end

module T = struct
  type 'a t =
    | Create_var of string * (Var.t -> 'a t)
    | Op of Op.t * (unit -> 'a t)
    | For of
        { index: string
        ; closure : Var.t list
        ; body : (Ctx.t -> unit t)
        ; after : (Ctx.t -> 'a t)
        }
    | Phi of Var.t list * (unit -> 'a t)
    | If of { cond : Var.t; then_ : unit t; else_ : unit t; after : (unit -> 'a t) }
    | Pure of 'a

  let rec map t ~f =
    match t with
    | Pure x -> Pure (f x)
    | Create_var (s, k) -> Create_var (s, fun v -> map (k v) ~f)
    | Op (op, k) -> Op (op, fun () -> map (k ()) ~f)
    | For { index; closure; body; after } ->
      For { index; closure; body; after = fun ctx -> map (after ctx) ~f }
    | Phi (vs, k) -> Phi (vs, fun () -> map (k ()) ~f)
    | If { cond; then_; else_; after } ->
      If { cond; then_; else_; after = fun () -> map (after ()) ~f }

  let rec bind t ~f =
    match t with
    | Pure x -> f x
    | Create_var (s, k) -> Create_var (s, fun v -> bind (k v) ~f)
    | Op (op, k) -> Op (op, fun () -> bind (k ()) ~f)
    | For { index; closure; body; after } ->
      For { index; closure; body; after = fun ctx -> bind (after ctx) ~f }
    | Phi (vs, k) -> Phi (vs, fun () -> bind (k ()) ~f)
    | If { cond; then_; else_; after } ->
      If { cond; then_; else_; after = fun () -> bind (after ()) ~f }

  let return x = Pure x

  let for_ index body = For { index; closure = failwith ""; body; after = fun _ -> return () }
  let if_ cond ~then_ ~else_ = If { cond; then_; else_; after = fun () -> return () }
end

include Monad.Make(struct
    include T
    let map = `Custom map
  end)

include T
open Let_syntax

let _ =
  let%bind () =
    for_ "foo" (fun ctx ->
      if_ (Var.(!) "cond")
        ~then_:(
          let%map () = return () in
          ())
        ~else_:(
          let%map () = return () in
          ())
    )
  in
  return ()
