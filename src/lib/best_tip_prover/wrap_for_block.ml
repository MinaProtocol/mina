let map ~f
    { Proof_carrying_data.proof = merkle_list, root_unverified
    ; data = best_tip_unverified
    } =
  let%map.Async_kernel.Deferred.Or_error ( `Root root_header
                                         , `Best_tip best_tip_header ) =
    f
      { Proof_carrying_data.proof =
          (merkle_list, Mina_block.header root_unverified)
      ; data = Mina_block.header best_tip_unverified
      }
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
