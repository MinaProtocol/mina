type _ t = ..

type _ t += Fail : 'a t

type 'a r = 'a t

type empty = ..

type request =
  | Request : 'a r * ('a -> empty) -> request

module Handler = struct
  type nonrec t = { with_ : 'a. 'a t -> 'a }

  let create (handler : request -> empty) =
    let f : type a. a r -> a =
      fun r ->
        let module T = struct
          type empty += T of a
        end
        in
        match handler (Request (r, fun x -> T.T x)) with
        | T.T x -> x
        | _ -> failwith "Unhandled request"
    in
    { with_ = f }

  let fail = { with_ = fun _ -> failwith "Request.Handler.fail" }

  let extend t1 t2 =
    { with_ =
        fun r ->
          try t1.with_ r
          with _ -> t2.with_ r
    }
end

(*
open Core

type _ t = ..

type _ t += Fail : 'a t

type empty =

type request =
  | Request : 'a t * ('a -> empty) -> request

let _ =
  handle (return ()) (fun (Request (r, k)) ->
    match r with
    | Fuck ->
      k result

    | _ -> failwith "Not found"

module Handler = struct
  type t = request -> Nothing.t *)
