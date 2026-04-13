open Core_kernel
open Mina_base
open Mina_state

let%test_module "ancestor" =
  ( module struct
    open Ancestor

    let%test_unit "verify rejects wrong ancestor" =
      let open Quickcheck in
      test
        (Generator.tuple3 State_hash.gen State_hash.gen
           (Generator.list State_body_hash.gen) )
        ~trials:100
        ~f:(fun (ancestor, wrong_ancestor, bs) ->
          if State_hash.equal ancestor wrong_ancestor then ()
          else
            let n = List.length bs in
            if n = 0 then ()
            else
              let prover = Prover.create ~max_size:(2 * n) in
              let hashes =
                List.folding_map bs ~init:(ancestor, Mina_numbers.Length.zero)
                  ~f:(fun (prev, length) body ->
                    let length = Mina_numbers.Length.succ length in
                    let hs =
                      Protocol_state.hashes_abstract ~hash_body:Fn.id
                        { previous_state_hash = prev; body }
                    in
                    Prover.add prover ~prev_hash:prev ~hash:hs.state_hash
                      ~length ~body_hash:body ;
                    ((hs.state_hash, length), hs.state_hash) )
              in
              let descendant = List.last_exn hashes in
              let input =
                { Input.generations = List.length hashes; descendant }
              in
              let _, proof =
                Prover.prove prover input
                |> Option.value_exn ?here:None ?error:None ?message:None
              in
              assert (not (verify input wrong_ancestor proof)) )

    let%test_unit "verify rejects wrong proof length" =
      let open Quickcheck in
      test
        (Generator.tuple2 State_hash.gen
           (Generator.list_non_empty State_body_hash.gen) )
        ~trials:100
        ~f:(fun (ancestor, bs) ->
          let n = List.length bs in
          let prover = Prover.create ~max_size:(2 * n) in
          let hashes =
            List.folding_map bs ~init:(ancestor, Mina_numbers.Length.zero)
              ~f:(fun (prev, length) body ->
                let length = Mina_numbers.Length.succ length in
                let hs =
                  Protocol_state.hashes_abstract ~hash_body:Fn.id
                    { previous_state_hash = prev; body }
                in
                Prover.add prover ~prev_hash:prev ~hash:hs.state_hash ~length
                  ~body_hash:body ;
                ((hs.state_hash, length), hs.state_hash) )
          in
          let descendant = List.last_exn hashes in
          let wrong_input =
            { Input.generations = List.length hashes + 1; descendant }
          in
          match Prover.prove prover wrong_input with
          | None ->
              ()
          | Some (a, proof) ->
              assert (not (verify wrong_input a proof)) )

    let%test_unit "verify_and_add rejects bad proof" =
      let open Quickcheck in
      test
        (Generator.tuple3 State_hash.gen State_body_hash.gen
           State_body_hash.gen ) ~trials:100
        ~f:(fun (ancestor, body1, wrong_body) ->
          if State_body_hash.equal body1 wrong_body then ()
          else
            let prover = Prover.create ~max_size:10 in
            let hs =
              Protocol_state.hashes_abstract ~hash_body:Fn.id
                { previous_state_hash = ancestor; body = body1 }
            in
            Prover.add prover ~prev_hash:ancestor ~hash:hs.state_hash
              ~length:Mina_numbers.Length.(succ zero)
              ~body_hash:body1 ;
            let input =
              { Input.generations = 1; descendant = hs.state_hash }
            in
            let result =
              Prover.verify_and_add prover input ancestor
                ~ancestor_length:Mina_numbers.Length.zero [ wrong_body ]
            in
            assert (Or_error.is_error result) )
  end )

let%test_module "local_state" =
  ( module struct
    open Local_state

    let%test_unit "dummy creates valid state" =
      let d = dummy () in
      assert d.success ;
      assert d.will_succeed ;
      assert (Currency.Amount.Signed.is_zero d.excess) ;
      assert (Currency.Amount.Signed.is_zero d.supply_increase) ;
      [%test_eq: Mina_numbers.Index.t] d.account_update_index
        Mina_numbers.Index.zero

    let%test_unit "empty equals dummy" =
      let d = dummy () in
      let e = empty () in
      [%test_eq: t] d e

    let%test_unit "display does not raise on dummy" =
      let d = dummy () in
      let (_ : _) = display d in
      ()

    let%test_unit "display does not raise on generated values" =
      Quickcheck.test gen ~trials:20 ~f:(fun ls ->
          let (_ : _) = display ls in
          () )

    let%test_unit "to_input does not raise on dummy" =
      let d = dummy () in
      let (_ : _) = to_input d in
      ()

    let%test_unit "to_input does not raise on generated values" =
      Quickcheck.test gen ~trials:50 ~f:(fun ls ->
          let (_ : _) = to_input ls in
          () )

    let%test_unit "to_input is deterministic" =
      let d = dummy () in
      let i1 = to_input d in
      let i2 = to_input d in
      [%test_eq: Snark_params.Tick.Field.t Random_oracle.Input.Chunked.t] i1 i2

    let%test_unit "gen produces distinct values" =
      let values =
        Quickcheck.random_value (Quickcheck.Generator.list_with_length 10 gen)
      in
      let distinct = List.dedup_and_sort values ~compare:[%compare: t] in
      assert (List.length distinct > 1)
  end )

let%test_module "snarked_ledger_state" =
  ( module struct
    open Snarked_ledger_state

    let genesis_hash = Frozen_ledger_hash.empty_hash

    let%test_unit "genesis creates valid state" =
      let g = genesis ~genesis_ledger_hash:genesis_hash in
      [%test_eq: Frozen_ledger_hash.t] g.connecting_ledger_left genesis_hash ;
      [%test_eq: Frozen_ledger_hash.t] g.connecting_ledger_right genesis_hash ;
      assert (Currency.Amount.Signed.is_zero g.supply_increase)

    let%test_unit "genesis source equals target" =
      let g = genesis ~genesis_ledger_hash:genesis_hash in
      [%test_eq: Registers.Value.t] g.source g.target

    let%test_unit "to_input does not raise on genesis" =
      let g = genesis ~genesis_ledger_hash:genesis_hash in
      let (_ : _) = to_input g in
      ()

    let%test_unit "to_input is deterministic on genesis" =
      let g = genesis ~genesis_ledger_hash:genesis_hash in
      let i1 = to_input g in
      let i2 = to_input g in
      [%test_eq: Snark_params.Tick.Field.t Random_oracle.Input.Chunked.t] i1 i2

    let%test_unit "to_field_elements does not raise on genesis" =
      let g = genesis ~genesis_ledger_hash:genesis_hash in
      let fields = to_field_elements g in
      assert (Int.( > ) (Array.length fields) 0)

    let%test_unit "to_field_elements is deterministic" =
      let g = genesis ~genesis_ledger_hash:genesis_hash in
      let f1 = to_field_elements g in
      let f2 = to_field_elements g in
      [%test_eq: Snark_params.Tick.Field.t array] f1 f2

    let%test_unit "display does not raise on genesis" =
      let g = genesis ~genesis_ledger_hash:genesis_hash in
      let (_ : _) = display g in
      ()

    let%test_unit "genesis with different ledger hashes differ" =
      Quickcheck.test
        (Quickcheck.Generator.tuple2 Frozen_ledger_hash.gen
           Frozen_ledger_hash.gen ) ~trials:20 ~f:(fun (h1, h2) ->
          if Frozen_ledger_hash.equal h1 h2 then ()
          else
            let g1 = genesis ~genesis_ledger_hash:h1 in
            let g2 = genesis ~genesis_ledger_hash:h2 in
            assert (not ([%equal: t] g1 g2)) )

    let%test_unit "With_sok.genesis creates valid state" =
      let g = With_sok.genesis ~genesis_ledger_hash:genesis_hash in
      [%test_eq: Frozen_ledger_hash.t] g.connecting_ledger_left genesis_hash ;
      assert (Currency.Amount.Signed.is_zero g.supply_increase)
  end )
