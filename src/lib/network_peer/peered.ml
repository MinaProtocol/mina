(* peered.ml -- pair some data with a Peer.t *)

type 'a t = {data: 'a; peer: Peer.t} [@@deriving bin_io, sexp, fields]

let create data peer = {data; peer}
