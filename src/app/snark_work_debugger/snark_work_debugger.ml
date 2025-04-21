open Core
open Async
module Work = Snark_work_lib

let rec sexp_to_sexp : Sexp.t -> Sexplib0.Sexp.t = function
  | Atom s ->
      Atom s
  | List xs ->
      List (List.map ~f:sexp_to_sexp xs)

let () = ignore sexp_to_sexp

let main (spec_path : string) ~constraint_constants ~proof_level =
  let module Impl = Snark_worker.Impl.Prod in
  let%bind spec =
    Reader.load_sexp_exn spec_path
      Work.Partitioned.Single.Spec.Stable.Latest.t_of_sexp
  in
  let spec =
    Work.Partitioned.Single.Spec.cache
      ~proof_cache_db:(Proof_cache_tag.create_identity_db ())
      spec
  in
  let%bind worker =
    Impl.Worker_state.create ~constraint_constants ~proof_level ()
  in
  let message =
    Mina_base.Sok_message.create ~fee:Currency.Fee.zero
      ~prover:
        Signature_lib.(
          Public_key.compress
            (Public_key.of_private_key_exn (Private_key.create ())))
  in
  Impl.perform_single worker ~message spec >>| ignore

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
