open Core

module Typ = struct
  type _ t =
    | Uint32 : int t
    | Array : 'a t -> 'a array t
end

module Var : sig
  type _ t 

  val (@@) : string -> 'a Typ.t -> 'a t
end = struct
  type _ t =
    | T : 'a Typ.t * string -> 'a t

  let (@@) s t = T (t, s)
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
    | Create_var : 'c Typ.t * string * ('c Var.t -> 'b t) ->  'b t
    | Op of Op.t * (unit -> 'a t)
    | For of
        { index: string
        ; closure : string list
        ; body : (Ctx.t -> unit t)
        ; after : (Ctx.t -> 'a t)
        }
    | Phi of string list * (unit -> 'a t)
    | If of { cond : bool Var.t; then_ : unit t; else_ : unit t; after : (unit -> 'a t) }
    | Pure of 'a

  let rec map t ~f =
    match t with
    | Pure x -> Pure (f x)
    | Create_var (typ, s, k) -> Create_var (typ, s, fun v -> map (k v) ~f)
    | Op (op, k) -> Op (op, fun () -> map (k ()) ~f)
    | For { index; closure; body; after } ->
      For { index; closure; body; after = fun ctx -> map (after ctx) ~f }
    | Phi (vs, k) -> Phi (vs, fun () -> map (k ()) ~f)
    | If { cond; then_; else_; after } ->
      If { cond; then_; else_; after = fun () -> map (after ()) ~f }

  let rec bind : type a b. a t -> f:(a -> b t) -> b t =
    fun t ~f ->
      match t with
      | Pure x -> f x
      | Create_var (typ, s, k) -> Create_var (typ, s, fun v -> bind (k v) ~f)
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

let f n xs ys rs =
  let%bind () =
    let%bind carry = create_var "carry" Typ.Bool in
    for_range "i" (0, n - 1) (fun i ->
      let%bind x = arr_get xs i
      and y = arr_get ys i in
      let%bind r = create_var "r" Typ.UInt32 in
      let%bind r_plus_carry = create_var "r_plus_carry" Typ.UInt32 in
      let%bind () = add r x y in
      let%bind () = array_set rs i r
      let%bind () = compare carry x y in
      in
      ())
  in
  rs


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
