type _ t = ..

type _ t += Fail : 'a t

type 'a req = 'a t

type response = ..

type response += Unhandled

let unhandled = Unhandled

module Response = struct
  type 'a t = Provide of 'a | Delegate of 'a req | Unhandled
end

type request =
  | With : {request: 'a t; respond: 'a Response.t -> response} -> request

module Handler = struct
  type single = {handle: 'a. 'a t -> 'a Response.t}

  type t = single list

  let fail = []

  let run : t -> 'a req -> 'a =
   fun stack0 req0 ->
    let rec go req = function
      | [] -> failwith "Unhandled request"
      | {handle} :: hs -> (
        match handle req with
        | Provide x -> x
        | Delegate req' -> go req' hs
        | Unhandled -> go req hs )
    in
    go req0 stack0

  let create_single (handler : request -> response) : single =
    let handle : type a. a req -> a Response.t =
     fun request ->
      let module T = struct
        type response += T of a Response.t
      end in
      match handler (With {request; respond= (fun x -> T.T x)}) with
      | T.T x -> x
      | _ -> Response.Unhandled
    in
    {handle}

  let push (t : t) (single : single) : t = single :: t
end
