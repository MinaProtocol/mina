open Core
open Network_peer
open Module_version

module Sender : sig
  module Stable : sig
    module V1 : sig
      type t = Local | Remote of Peer.t [@@deriving sexp, bin_io]
    end
  end

  type t = Local | Remote of Peer.t [@@deriving sexp]
end
