open Core_kernel
open Async
module Prod = Snark_worker__Prod.Inputs

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Run snark worker directly"
    (let%map_open spec =
       flag "--spec-sexp" ~doc:""
         (required (sexp_conv Prod.single_spec_of_sexp))
     and proof_level =
       flag "--proof-level" ~doc:""
         (optional_with_default Genesis_constants.Proof_level.Full
            (Command.Arg_type.of_alist_exn
               [ ("Full", Genesis_constants.Proof_level.Full)
               ; ("Check", Check)
               ; ("None", None) ]))
     in
     fun () ->
       let open Async in
       let%bind worker_state = Prod.Worker_state.create ~proof_level () in
       let public_key =
         fst (Lazy.force Coda_base.Sample_keypairs.keypairs).(0)
       in
       let fee = Currency.Fee.of_int 10 in
       let message = Coda_base.Sok_message.create ~fee ~prover:public_key in
       match Prod.perform_single worker_state ~message spec with
       | Ok (proof, time) ->
           Caml.Format.printf
             !"Successfully proved in %{sexp: Time.Span.t}.@.Proof \
               was:@.%{sexp: Transaction_snark.t}@."
             time proof ;
           exit 0
       | Error err ->
           Caml.Format.printf
             !"Proving failed with error:@.%s"
             (Error.to_string_hum err) ;
           exit 1)

let () = Command.run command
