(*All the limits set for zkApp transactions*)
open Core_kernel

let main () =
  let Genesis_constants.
        { max_event_elements
        ; max_action_elements
        ; max_zkapp_segment_per_transaction
        ; _
        } =
    Genesis_constants.Compiled.genesis_constants
  in
  let values = List.init (1 + max_zkapp_segment_per_transaction) ~f:Fn.id in
  printf "max field elements for events per transaction: %d\n"
    max_event_elements ;
  printf "max field elements for actions per transaction: %d\n"
    max_action_elements ;
  printf "All possible zkApp account update combinations:\n" ;
  List.iter values ~f:(fun proof_segments ->
      List.iter values ~f:(fun signed_single_segments ->
          List.iter values ~f:(fun signed_pair_segments ->
              let cost =
                Mina_base.Zkapp_command.zkapp_cost ~proof_segments
                  ~signed_single_segments ~signed_pair_segments
              in
              if cost <= max_zkapp_segment_per_transaction then
                printf
                  "Proofs updates=%d  Signed/None updates=%d  Pairs of \
                   Signed/None updates=%d: Total account updates: %d Cost: %d \n\
                   %!"
                  proof_segments signed_single_segments signed_pair_segments
                  ( proof_segments + signed_single_segments
                  + (signed_pair_segments * 2) )
                  cost ) ) )

let () = main ()
