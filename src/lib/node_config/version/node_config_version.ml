(* transaction >= 1, network >= 0, patch >= 0 *)
let protocol_version_transaction = 4

let protocol_version_network = 0

let protocol_version_patch = 0

(* The version this build signals as its proposed next protocol version in the
   blocks it produces, unless overridden by --proposed-protocol-version. [None]
   signals no proposal. *)
let proposed_protocol_version = Some (4, 0, 1)
