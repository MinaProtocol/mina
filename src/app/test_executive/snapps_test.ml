open Core
open Async
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  (* TODO: find a way to avoid this type alias (first class module signatures restrictions make this tricky) *)
  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config =
    let open Test_config in
    let open Test_config.Block_producer in
    { default with
      requires_graphql = true
    ; block_producers = [ { balance = "4000000000"; timing = Untimed } ]
    ; num_snark_workers = 0
    }

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let block_producer_nodes = Network.block_producers network in
    let%bind () =
      Malleable_error.List.iter block_producer_nodes
        ~f:(Fn.compose (wait_for t) Wait_condition.node_to_initialize)
    in
    let node = List.hd_exn block_producer_nodes in
    let%map () =
      section "send a snapp"
        (let (user_cmd : Mina_base.User_command.t), _, _, _ =
           Quickcheck.random_value
             (Mina_base.User_command_generators.parties_with_ledger ())
         in
         let parties0 =
           match user_cmd with
           | Parties p ->
               p
           | Signed_command _ ->
               failwith "Expected a Parties command"
         in
         let%bind fee_payer_pk = Util.pub_key_of_node node in
         (* substitute key in test ledger into generated Parties.t
            substitute dummy signature
         *)
         let parties =
           { parties0 with
             fee_payer =
               { data =
                   { parties0.fee_payer.data with
                     body =
                       { parties0.fee_payer.data.body with
                         public_key = fee_payer_pk
                       }
                   }
               ; authorization = Mina_base.Signature.dummy
               }
           }
         in
         match%bind.Deferred Network.Node.send_snapp ~logger node ~parties with
         | Ok () ->
             [%log error]
               "Snapps transaction succeeded, expected failure due to invalid \
                signature" ;
             Malleable_error.soft_error_format ~value:()
               "Snapps transaction succeeded despite invalid signature"
         | Error err ->
             let err_str = Error.to_string_mach err in
             if String.is_substring ~substring:"Invalid_signature" err_str then (
               [%log info] "Snapps failed as expected with invalid signature" ;
               Malleable_error.return () )
             else (
               [%log error]
                 "Error sending snapp, for a reason other than the expected \
                  invalid signature"
                 ~metadata:[ ("error", `String err_str) ] ;
               Malleable_error.soft_error_format ~value:()
                 "Snapp failed in unexpected way: %s" err_str ))
    in
    ()
end
