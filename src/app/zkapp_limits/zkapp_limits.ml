(*All the limits set for zkApp transactions*)
open Core_kernel
open Async

let main (genesis_constants : Genesis_constants.t) =
  let cost_limit = genesis_constants.zkapp_transaction_cost_limit in
  let max_event_elements = genesis_constants.max_event_elements in
  let max_action_elements = genesis_constants.max_action_elements in
  let values = List.init 20 ~f:Fn.id in
  printf "max field elements for events per transaction: %d\n"
    max_event_elements ;
  printf "max field elements for actions per transaction: %d\n"
    max_action_elements ;
  printf "All possible zkApp account update combinations" ;
  List.iter values ~f:(fun proofs ->
      List.iter values ~f:(fun signed_single_segments ->
          List.iter values ~f:(fun signed_pair_segments ->
              let cost =
                Mina_base.Zkapp_command.zkapp_cost ~proof_segments:proofs
                  ~signed_single_segments ~signed_pair_segments
                  ~genesis_constants ()
              in
              if Float.(cost <. cost_limit) then
                printf
                  "Proofs updates=%d  Signed/None updates=%d  Pairs of \
                   Signed/None updates=%d: Total account updates: %d Cost: %f \n\
                   %!"
                  proofs signed_single_segments signed_pair_segments
                  (proofs + signed_single_segments + (signed_pair_segments * 2))
                  cost ) ) )

let () =
  Command.run
  @@
  let open Command.Let_syntax in
  Command.async ~summary:"All the limits set for zkApp transactions"
    (let%map_open config_file = Cli_lib.Flag.conf_file in
     fun () ->
       let open Deferred.Let_syntax in
       let%map genesis_constants =
         let logger = Logger.create () in
         let%map config =
           Runtime_config.Constants.load_constants ~logger config_file
         in
         Runtime_config.Constants.genesis_constants config
       in
       main genesis_constants )
