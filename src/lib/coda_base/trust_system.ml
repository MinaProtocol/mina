(** The trust system, instantiated with Coda-specific stuff. *)

module Actions = struct
  (* Stub actions. Will fill in later. *)
  type t = Sent_bad_hash | Etc [@@deriving sexp_of, yojson]

  let to_trust_response t =
    let open Peer_trust.Trust_response in
    match t with Sent_bad_hash -> Insta_ban | Etc -> Trust_decrease 0.1
end

module Peer_trust = Peer_trust.Make (Actions)
include Peer_trust
