open Core
open Network_peer

module Sender = struct
  type t = Local | Remote of Peer.t [@@deriving sexp, bin_io]
end

module Incoming = struct
  type 'a t = {data: 'a; sender: Sender.t} [@@deriving sexp, bin_io]

  let sender {sender; _} = sender

  let data {data; _} = data

  let wrap ~data ~sender = {data; sender}

  let map ~f t = {t with data= f t.data}

  let local data =
    let sender = Sender.Local in
    {data; sender}
end
