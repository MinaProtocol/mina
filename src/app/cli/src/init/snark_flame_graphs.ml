open Core
open Snark_params

let name = "snark-flame-graphs"

let main () =
  let open Blockchain_snark.Blockchain_transition in
  let module M = Make (Transaction_snark.Verification.Make (struct
    let keys = Transaction_snark.Keys.Verification.dummy
  end)) in
  let module W = M.Wrap_base (struct
    let verification_key = Keys.Verification.dummy.step
  end) in
  let cwd = Sys.getcwd () in
  let module L_Tick = Snarky_log.Constraints (Snark_params.Tick) in
  let module L_Tock = Snarky_log.Constraints (Snark_params.Tock) in
  let logger = Logger.create () in
  let log main typ = Snarky.Checked.(exists typ >>= main) in
  let logs =
    [ ( "step"
      , L_Tick.log
          (log
             (M.Step_base.main ~logger ~proof_level:Full
                ~ledger_depth:Genesis_constants.ledger_depth)
             Tick.Field.typ) )
    ; ("wrap", L_Tock.log (log W.main Crypto_params.Wrap_input.typ)) ]
  in
  List.iter logs ~f:(fun (name, log) ->
      Snarky_log.to_file (cwd ^/ name ^ ".flame-graph") log )

let command =
  let open Command.Let_syntax in
  Command.basic ~summary:"transaction snark profiler" (return main)
