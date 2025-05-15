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

module Work = Snark_work_lib

let main (spec_path : string) ~constraint_constants ~proof_level =
  let open Snark_worker.Worker.Prod in
  let%bind single_spec =
    Reader.load_sexp_exn spec_path
      Work.Selector.Single.Spec.Stable.Latest.t_of_sexp
  in
  let%bind state = Worker_state.create ~constraint_constants ~proof_level () in
  let message =
    Mina_base.Sok_message.create ~fee:Currency.Fee.zero
      ~prover:
        Signature_lib.(
          Public_key.compress
            (Public_key.of_private_key_exn (Private_key.create ())))
  in

  let sok_digest = Mina_base.Sok_message.digest message in

  let spec : Work.Selector.Spec.Stable.Latest.t =
    { instances = `One single_spec; fee = Currency.Fee.zero }
  in
  perform ~state ~sok_digest ~spec >>| ignore

let cmd =
  Command.async ~summary:"Run a snark worker on a single work spec"
    Command.(
      let open Let_syntax in
      let%map path =
        let open Command.Param in
        flag "--spec" ~doc:"PATH Spec path" (required string)
      in
      fun () ->
        let constraint_constants =
          Genesis_constants.Compiled.constraint_constants
        in
        let proof_level = Genesis_constants.Compiled.proof_level in
        Obj.magic (main path ~constraint_constants ~proof_level))

let () = Command.run cmd
