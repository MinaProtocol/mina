module Schema = Graphql_wrapper.Make(Graphql_async.Schema)
open Schema

let protocol_state_proof () =
  obj "protocolStateProof" ~fields:(fun _ ->
      [ field "base64" ~typ:string ~doc:"Base-64 encoded proof"
          ~args:Arg.[]
          ~resolve:(fun _ proof ->
            (* Use the precomputed block proof encoding, for consistency. *)
            Some (Mina_block.Precomputed.Proof.to_bin_string proof) )
    ] )
