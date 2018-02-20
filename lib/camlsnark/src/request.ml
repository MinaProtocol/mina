type _ t = ..

type _ t += Fail : 'a t

type 'a r = 'a t

type response = ..

type response += Unhandled

let unhandled = Unhandled

type request =
  | With : { request :'a t; respond : ('a -> response) } -> request

module Handler = struct
  type nonrec t = { with_ : 'a. 'a t -> 'a }

  let create (handler : request -> response) =
    let f : type a. a r -> a =
      fun request ->
        let module T = struct
          type response += T of a
        end
        in
        match handler (With { request; respond = fun x -> T.T x}) with
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
