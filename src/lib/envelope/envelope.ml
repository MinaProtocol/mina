open Core_kernel

module Sender = struct
  type t = Local | Remote of Core.Unix.Inet_addr.Stable.V1.t
  [@@deriving sexp, compare]

  let equal sender1 sender2 = Int.equal (compare sender1 sender2) 0

  let to_yojson t : Yojson.Safe.json =
    match t with
    | Local ->
        `String "Local"
    | Remote inet_addr ->
        `Assoc [("Remote", `String (Core.Unix.Inet_addr.to_string inet_addr))]

  let of_yojson (json : Yojson.Safe.json) : (t, string) Result.t =
    match json with
    | `String "Local" ->
        Ok Local
    | `Assoc [("Remote", `String addr)] ->
        Ok (Remote (Core.Unix.Inet_addr.of_string addr))
    | _ ->
        Error "Expected JSON representing envelope sender"
end

module Incoming = struct
  type 'a t = {data: 'a; sender: Sender.t} [@@deriving eq, sexp, yojson]

  let sender t = t.sender

  let data t = t.data

  let wrap ~data ~sender = {data; sender}

  let map ~f t = {t with data= f t.data}

  let local data =
    let sender = Sender.Local in
    {data; sender}
end
