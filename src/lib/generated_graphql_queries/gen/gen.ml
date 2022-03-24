open Ppxlib
open Asttypes
open Parsetree
open Core_kernel

module Parties_templates = struct
  let pooled_snapp_commands =
    Printf.sprintf
      {graphql|
    query snapp_commands($public_key: PublicKey) {
      pooledSnappCommands(publicKey: $public_key) {
        id
        hash
        failureReason
        parties %s
      }
    }|graphql}

  let internal_send_snapp =
    Printf.sprintf
      {|
         mutation ($parties: SendTestSnappInput!) {
            internalSendSnapp(parties: $parties) {
               snapp { id
                       hash
                       failureReason
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
    module Pooled_snapp_commands =
    [%graphql
    [%e party_query_expr Parties_templates.pooled_snapp_commands ~loc]]

    module Send_test_snapp =
    [%graphql
    [%e party_query_expr Parties_templates.internal_send_snapp ~loc]]]

let main () =
  Out_channel.with_file "generated_graphql_queries.ml" ~f:(fun ml_file ->
      let fmt = Format.formatter_of_out_channel ml_file in
      Pprintast.top_phrase fmt (Ptop_def (structure ~loc:Ppxlib.Location.none)))

let () = main ()
