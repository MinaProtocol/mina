open Core
open Async

type single_spec =
  ( Transaction_witness.Stable.Latest.t
  , Transaction_snark.Stable.Latest.t )
  Snark_work_lib.Work.Single.Spec.Stable.Latest.t
[@@deriving sexp]

let rec sexp_to_sexp : Sexp.t -> Sexplib0.Sexp.t = function
  | Atom s ->
      Atom s
  | List xs ->
      List (List.map ~f:sexp_to_sexp xs)

let () = ignore sexp_to_sexp

let main (spec_path : string) ~constraint_constants ~proof_level =
  let module Inputs = Snark_worker.Prod.Inputs in
  let%bind spec = Reader.load_sexp_exn spec_path Inputs.single_spec_of_sexp in
  let%bind worker =
    Inputs.Worker_state.create ~constraint_constants ~proof_level ()
  in
  let message =
    Mina_base.Sok_message.create ~fee:Currency.Fee.zero
      ~prover:
        Signature_lib.(
          Public_key.compress
            (Public_key.of_private_key_exn (Private_key.create ())))
  in
  Inputs.perform_single worker ~message spec >>| ignore

let cmd =
  Command.async ~summary:"Run a snark worker on a single work spec"
    Command.(
      let open Let_syntax in
      let%map path =
        let open Command.Param in
        flag "--spec" ~doc:"PATH Spec path" (required string)
      and config_file = Cli_lib.Flag.conf_file in
      fun () ->
        let open Deferred.Let_syntax in
        let%bind (constraint_constants, proof_level) =
          let logger = Logger.create () in
          let%map constants =Runtime_config.Constants.load_constants ~logger config_file
      in  (Runtime_config.Constants.constraint_constants constants, Runtime_config.Constants.proof_level constants)
        in
        Obj.magic (main path ~constraint_constants ~proof_level))

let () = Command.run cmd
