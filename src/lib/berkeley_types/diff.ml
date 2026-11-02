(* The staged ledger diff of a Berkeley precomputed block, which writes it in
   `3.4.0`'s `Legacy_format.Staged_ledger_diff`. *)

open Core_kernel
module Diff = Staged_ledger_diff

type 'command pre_diffs =
  ( Transaction_snark_work.Stable.V2.t
  , 'command Mina_base.With_status.Stable.V2.t )
  Diff.Pre_diff_two.Stable.V2.t
  * ( Transaction_snark_work.Stable.V2.t
    , 'command Mina_base.With_status.Stable.V2.t )
    Diff.Pre_diff_one.Stable.V2.t
    option
[@@deriving yojson]

type t = { diff : User_command.t pre_diffs } [@@deriving yojson]

let map_commands ((two, one) : 'a pre_diffs) ~(f : 'a -> 'b) : 'b pre_diffs =
  let f = List.map ~f:(Mina_base.With_status.map ~f) in
  ( { two with Diff.Pre_diff_two.Stable.V2.commands = f two.commands }
  , Option.map one ~f:(fun one ->
        { one with Diff.Pre_diff_one.Stable.V2.commands = f one.commands } ) )

(** Each command keeps its Berkeley hash. *)
let commands_with_hashes ({ diff } : t) :
    (User_command.t * Mina_transaction.Transaction_hash.t) pre_diffs =
  map_commands diff ~f:(fun command -> (command, User_command.hash command))

let to_mesa ({ diff } : t) : Diff.Stable.V3.t =
  { diff = map_commands diff ~f:User_command.to_mesa }
