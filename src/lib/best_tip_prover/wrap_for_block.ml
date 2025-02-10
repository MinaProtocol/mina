let to_header_data ~to_header
    { Proof_carrying_data.proof = merkle_list, root_unverified
    ; data = best_tip_unverified
    } =
  { Proof_carrying_data.proof = (merkle_list, to_header root_unverified)
  ; data = to_header best_tip_unverified
  }

let map ~f
    ( { Proof_carrying_data.proof = _, root_unverified
      ; data = best_tip_unverified
      } as pcd ) =
  let%map.Async_kernel.Deferred.Or_error ( `Root root_header
                                         , `Best_tip best_tip_header ) =
    f (to_header_data ~to_header:Mina_block.header pcd)
  in
  let root =
    Mina_block.Validation.with_body root_header
      (Mina_block.body root_unverified)
  in
  let best_tip =
    Mina_block.Validation.with_body best_tip_header
      (Mina_block.body best_tip_unverified)
  in
  (`Root root, `Best_tip best_tip)
