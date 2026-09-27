(* transaction >= 1, network >= 0, patch >= 0 *)
(* Bump [protocol_version_transaction] by exactly one for every hard fork.
   The pre-fork daemon names the migrated genesis tarball with the next
   transaction version, and the post-fork daemon looks it up by its own
   current version; without the bump it cannot find its genesis ledger. *)
let protocol_version_transaction = 5

let protocol_version_network = 0

let protocol_version_patch = 0
