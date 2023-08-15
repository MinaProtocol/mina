open Core_kernel

(*
  Appending a nonce to messages emitted by transaction and snark pools allows to circumvent
  libp2p's gossip deduplication logic and allow broadcasts to be broadcasted over and over again.
*)

[%%versioned
module Stable = struct
  module V1 = struct
    type 'a t = { message : 'a; nonce : int } [@@deriving compare, sexp, yojson]
  end
end]
