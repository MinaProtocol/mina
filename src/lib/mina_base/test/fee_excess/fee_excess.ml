open Core_kernel
open Currency
open Mina_base
open Snark_params.Tick
open Fee_excess

let sole_non_zero_excess_is_on_the_left fe =
  let open Fee.Signed in
  equal zero fe.fee_excess_r || not (equal zero fe.fee_excess_l)

let zero_fee_excess_has_the_default_token fe =
  ( (not Fee.Signed.(equal zero fe.fee_excess_l))
  || Token_id.(equal default fe.fee_token_l) )
  && ( (not Fee.Signed.(equal zero fe.fee_excess_r))
     || Token_id.(equal default fe.fee_token_r) )

let fee_tokens_are_different fe =
  (* Right token can actually by the default even if the left one is. *)
  let open Token_id in
  (not (equal fe.fee_token_l fe.fee_token_r)) || equal default fe.fee_token_r

let rebalancing_properties_hold () =
  (* Properties that must hold in any rebalanced fee excess are:
     - if there is only 1 nonzero excess, it is to the left
     - any zero fee excess has the default token
     - if the fee tokens are the same, the excesses are combined *)
  Quickcheck.test gen ~f:(fun fee_excess ->
      [%test_pred: t Or_error.t]
        (function
          | Ok rebalanced ->
              sole_non_zero_excess_is_on_the_left rebalanced
              && zero_fee_excess_has_the_default_token rebalanced
              && fee_tokens_are_different rebalanced
          | Error _ ->
              false )
        (rebalance fee_excess) )

let combine_checked_unchecked_consistent () =
  Quickcheck.test (Quickcheck.Generator.tuple2 gen gen) ~f:(fun (fe1, fe2) ->
      let fe = combine fe1 fe2 in
      let fe_checked =
        Or_error.try_with (fun () ->
            Test_util.checked_to_unchecked
              Typ.(typ * typ)
              typ
              (fun (fe1, fe2) -> combine_checked fe1 fe2)
              (fe1, fe2) )
      in
      match (fe, fe_checked) with
      | Ok fe, Ok fe_checked ->
          [%test_eq: t] fe fe_checked
      | Error _, Error _ ->
          ()
      | _ ->
          [%test_eq: t Or_error.t] fe fe_checked )

let combine_succeed_with_0_middle () =
  Quickcheck.test
    (let open Quickcheck in
    let open Generator.Let_syntax in
    let%bind fe = gen in
    (* The tokens before and after should be distinct.
       Especially in this scenario, we may get an overflow error
       otherwise. *)
    let%map tid, excess =
      gen_single
        ~token_id:
          (Generator.filter Token_id.gen
             ~f:(Fn.compose not (Token_id.equal fe.fee_token_l)) )
        ()
    in
    (fe, tid, excess))
    ~f:(fun (fe1, tid, excess) ->
      let fe2 =
        if Fee.Signed.(equal zero) fe1.fee_excess_r then of_single (tid, excess)
        else
          match
            of_one_or_two
              (`Two
                ( (fe1.fee_token_r, Fee.Signed.negate fe1.fee_excess_r)
                , (tid, excess) ) )
          with
          | Ok fe2 ->
              fe2
          | Error _ ->
              (* The token is the same, and rebalancing causes an overflow. *)
              of_single (fe1.fee_token_r, Fee.Signed.negate fe1.fee_excess_r)
      in
      ignore @@ Or_error.ok_exn (combine fe1 fe2) )

let () =
  let open Alcotest in
  run "Test fee excesses."
    [ ( "fee-excess"
      , [ test_case "Checked and unchecked behaviour consistent." `Quick
            combine_checked_unchecked_consistent
        ; test_case "Combine succeeds when the middle excess is zero." `Quick
            combine_succeed_with_0_middle
        ; test_case "Rebalanced fee excess is really rebalanced." `Quick
            rebalancing_properties_hold
        ] )
    ]
