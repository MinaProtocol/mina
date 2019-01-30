open Core
open Network_peer

module Incoming = struct
  type 'a t = {data: 'a; sender: Peer.t} [@@deriving sexp, bin_io]

  let sender {sender; _} = sender

  let data {data; _} = data

  let wrap ~data ~sender = {data; sender}

  let map ~f t = {t with data= f t.data}

  let local data =
    let sender =
      Peer.create Unix.Inet_addr.localhost ~discovery_port:0
        ~communication_port:0
    in
    {data; sender}
end
