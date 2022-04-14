open Ppxlib
open Asttypes
open Parsetree
open Core_kernel

module Parties_templates = struct
  let pooled_zkapp_commands =
    Printf.sprintf
      {graphql|
    query zkapp_commands($public_key: PublicKey) {
      pooledZkappCommands(publicKey: $public_key) {
        id
        hash
        failureReason {
                         index
                         failures
                       }
        parties %s
      }
    }|graphql}

  let internal_send_zkapp =
    Printf.sprintf
      {|
         mutation ($parties: SendTestZkappInput!) {
            internalSendZkapp(parties: $parties) {
               zkapp { id
                       hash
                       failureReason {
                         index
                         failures
                       }
                       parties %s
                     }
             }
         }
      |}
end

let party_query_expr template ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  estring @@ template (Lazy.force Mina_base.Parties.inner_query)

let structure ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%str
    module Pooled_zkapp_commands =
    [%graphql
    [%e party_query_expr Parties_templates.pooled_zkapp_commands ~loc]]

    module Send_test_zkapp =
    [%graphql
    [%e party_query_expr Parties_templates.internal_send_zkapp ~loc]]]

let main () =
  Out_channel.with_file "generated_graphql_queries.ml" ~f:(fun ml_file ->
      let fmt = Format.formatter_of_out_channel ml_file in
      Pprintast.top_phrase fmt (Ptop_def (structure ~loc:Ppxlib.Location.none)))

let () = main ()
