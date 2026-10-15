(* Rosetta /search/transactions (Lib.Search.Sql.run) on hand-built archives:
   which transactions an account matches, which blocks are visible, and how
   pages split a result. Rows read "<transaction> @ <block>" (see Fixture).
   Needs the PostgreSQL server MINA_TEST_POSTGRES names. *)

open Core
open Fixture

(* The fee payer always matches a user command; its source and receiver only
   when the command was applied. *)
let which_transactions_an_account_matches () =
  let chain = Chain.create () in
  let alice = Chain.account chain "alice" in
  let bob = Chain.account chain "bob" in
  let carol = Chain.account chain "carol" in
  let dave = Chain.account chain "dave" in
  let erin = Chain.account chain "erin" in
  let b1 = Chain.canonical chain ~height:1 "b1" in
  let b2 = Chain.canonical chain ~parent:b1 ~height:2 "b2" in
  Chain.delegation chain "delegate_ab" ~from:alice ~to_:bob ~in_:[ b1 ] ;
  Chain.payment chain "pay_self" ~from:alice ~to_:alice ~in_:[ b1 ] ;
  Chain.payment chain "pay_ab" ~from:alice ~to_:bob ~in_:[ b2 ] ;
  Chain.payment chain "pay_ac_failed" ~from:alice ~to_:carol ~in_:[ b2 ]
    ~status:(Failed "Amount_insufficient_to_create_account") ;
  Chain.payment chain "pay_da_by_erin" ~fee_payer:erin ~from:dave ~to_:alice
    ~in_:[ b2 ] ;
  with_search chain (fun s ->
      let q = Search.query s and find = Search.rows s in
      (* the same answer whether the account is an address or an account
         identifier *)
      let expect_for name expected =
        expect (name ^ ", by address")
          ~found:(find (q ~address:name ()))
          expected ;
        expect
          (name ^ ", by account identifier")
          ~found:(find (q ~account:name ()))
          expected
      in
      let everything_of_alice =
        [ "delegate_ab @ b1"
        ; "pay_self @ b1"
        ; "pay_ab @ b2"
        ; "pay_ac_failed @ b2"
        ; "pay_da_by_erin @ b2"
        ]
      in
      expect_for "alice" everything_of_alice ;
      expect_for "bob" [ "delegate_ab @ b1"; "pay_ab @ b2" ] ;
      expect_for "carol" [] (* receiver of a failed payment only *) ;
      expect_for "dave" [ "pay_da_by_erin @ b2" ] (* source *) ;
      expect_for "erin" [ "pay_da_by_erin @ b2" ] (* fee payer *) ;

      expect "another token"
        ~found:
          (find
             (q ~account:"alice"
                ~token:"wfG3GivPMttpt6nQnPuX9eDPnoyA5RJZY23LTc4kkNkCRH2gUd" () ) )
        [] ;
      expect "payments to bob"
        ~found:(find (q ~address:"bob" ~op_type:"payment_receiver_inc" ()))
        [ "pay_ab @ b2" ] ;
      expect "delegations to bob"
        ~found:(find (q ~address:"bob" ~op_type:"delegate_change" ()))
        [ "delegate_ab @ b1" ] ;
      expect "alice's failed transactions"
        ~found:(find (q ~address:"alice" ~op_status:"failed" ()))
        [ "pay_ac_failed @ b2" ] ;
      expect "alice's successful transactions"
        ~found:(find (q ~address:"alice" ~success:true ()))
        (List.filter everything_of_alice
           ~f:(Fn.non (String.equal "pay_ac_failed @ b2")) ) ;
      expect "alice up to block 1"
        ~found:(find (q ~address:"alice" ~max_block:1 ()))
        [ "delegate_ab @ b1"; "pay_self @ b1" ] ;
      expect "alice AND a transaction of hers"
        ~found:(find (q ~address:"alice" ~transaction:"pay_da_by_erin" ()))
        [ "pay_da_by_erin @ b2" ] ;
      expect "bob AND a transaction not his"
        ~found:(find (q ~address:"bob" ~transaction:"pay_da_by_erin" ()))
        [] ;
      expect "carol OR a transaction"
        ~found:
          (find
             (q ~operator:`Or ~address:"carol" ~transaction:"pay_da_by_erin" ()) )
        [ "pay_da_by_erin @ b2" ] )

(* Visible: canonical blocks, and pending blocks above the canonical tip. *)
let which_blocks_are_visible () =
  let chain = Chain.create () in
  let alice = Chain.account chain "alice" in
  let bob = Chain.account chain "bob" in
  (* A - B - C - pending_4     canonical tip C at height 3
       \   \
        \   pending_3          pending at the tip's height
         B_orphan, pending_2   orphaned / pending below the tip *)
  let a = Chain.canonical chain ~height:1 "A" in
  let b = Chain.canonical chain ~parent:a ~height:2 "B" in
  let c = Chain.canonical chain ~parent:b ~height:3 "C" in
  let pending_4 = Chain.pending chain ~parent:c ~height:4 "pending_4" in
  let pending_3 = Chain.pending chain ~parent:b ~height:3 "pending_3" in
  let b_orphan = Chain.orphaned chain ~parent:a ~height:2 "B_orphan" in
  let pending_2 = Chain.pending chain ~parent:a ~height:2 "pending_2" in
  List.iter
    [ (a, "A")
    ; (b, "B")
    ; (c, "C")
    ; (pending_4, "pending_4")
    ; (pending_3, "pending_3")
    ; (b_orphan, "B_orphan")
    ; (pending_2, "pending_2")
    ]
    ~f:(fun (block, name) ->
      Chain.payment chain ("pay in " ^ name) ~from:alice ~to_:bob ~in_:[ block ] ;
      Chain.coinbase chain ~to_:alice block ) ;
  Chain.payment chain "pay in B and B_orphan" ~from:alice ~to_:bob
    ~in_:[ b_orphan; b ] ;
  Chain.zkapp chain "zkapp in C" ~fee_payer:alice ~updating:[ bob ] ~in_:[ c ] ;
  Chain.zkapp chain "zkapp in B_orphan" ~fee_payer:alice ~updating:[ bob ]
    ~in_:[ b_orphan ] ;
  with_search chain (fun s ->
      let q = Search.query s and find = Search.rows s in
      let everything_visible =
        [ "pay in A @ A"
        ; "pay in B @ B"
        ; "pay in C @ C"
        ; "pay in pending_4 @ pending_4"
        ; "pay in B and B_orphan @ B"
        ; "coinbase to alice @ A"
        ; "coinbase to alice @ B"
        ; "coinbase to alice @ C"
        ; "coinbase to alice @ pending_4"
        ; "zkapp in C @ C"
        ]
      in
      expect "alice, by address"
        ~found:(find (q ~address:"alice" ()))
        everything_visible ;
      expect "alice, by account identifier"
        ~found:(find (q ~account:"alice" ()))
        everything_visible ;
      (* by transaction hash: no account narrows the search *)
      let expect_transaction name expected =
        expect name ~found:(find (q ~transaction:name ())) expected
      in
      expect_transaction "pay in C" [ "pay in C @ C" ] ;
      expect_transaction "pay in pending_4" [ "pay in pending_4 @ pending_4" ] ;
      expect_transaction "pay in pending_3" [] ;
      expect_transaction "pay in pending_2" [] ;
      expect_transaction "pay in B_orphan" [] ;
      expect_transaction "pay in B and B_orphan" [ "pay in B and B_orphan @ B" ] ;
      expect_transaction "zkapp in B_orphan" [] )

(* Pages of any size, read by following next_offset, add up to the whole
   result in its order, and every page reports the size of the whole result
   as total_count. *)
let pages_add_up_to_the_whole ~with_coinbases_and_zkapps () =
  let chain = Chain.create () in
  let alice = Chain.account chain "alice" in
  let bob = Chain.account chain "bob" in
  let blocks = Chain.canonical_chain chain ~length:4 in
  List.iteri blocks ~f:(fun i block ->
      List.iter [ 1; 2; 3 ] ~f:(fun n ->
          Chain.payment chain
            (sprintf "pay %d in h%d" n (i + 1))
            ~from:alice ~to_:bob ~in_:[ block ] ) ;
      if with_coinbases_and_zkapps then Chain.coinbase chain ~to_:alice block ) ;
  if with_coinbases_and_zkapps then
    List.iteri (List.take blocks 2) ~f:(fun i block ->
        Chain.zkapp chain
          (sprintf "zkapp in h%d" (i + 1))
          ~fee_payer:alice ~updating:[ bob ] ~in_:[ block ] ) ;
  let whole_size = 12 + if with_coinbases_and_zkapps then 4 + 2 else 0 in
  with_search chain (fun s ->
      (* AND lets the account narrow the search; OR does not *)
      List.iter
        [ (`And, "AND"); (`Or, "OR") ]
        ~f:(fun (operator, label) ->
          let alice_s = Search.query s ~operator ~address:"alice" () in
          let whole = Search.run s alice_s in
          Alcotest.(check int)
            (label ^ ": the whole result")
            whole_size (List.length whole.rows) ;
          Alcotest.(check int)
            (label ^ ": its total_count")
            whole_size whole.total_count ;
          List.iter (List.range 1 8) ~f:(fun size ->
              let pages = Search.pages s ~size alice_s in
              let what = sprintf "%s, pages of %d" label size in
              List.iter pages ~f:(fun page ->
                  Alcotest.(check int)
                    (what ^ ": total_count") whole_size page.total_count ;
                  Alcotest.(check bool)
                    (what ^ ": not over-full") true
                    (List.length page.rows <= size) ) ;
              Alcotest.(check (list string))
                (what ^ ": add up to the whole")
                whole.rows
                (List.concat_map pages ~f:(fun page -> page.rows)) ) ;
          let past_the_end =
            Search.run s
              { alice_s with offset = Some (Int64.of_int whole_size) }
          in
          Alcotest.(check (list string))
            (label ^ ": past the end, nothing")
            [] past_the_end.rows ;
          Alcotest.(check int)
            (label ^ ": past the end, still the total_count")
            whole_size past_the_end.total_count ) )

let () =
  Alcotest.run "rosetta search"
    [ ( "search_transactions"
      , [ Alcotest.test_case "which transactions an account matches" `Quick
            which_transactions_an_account_matches
        ; Alcotest.test_case "which blocks are visible" `Quick
            which_blocks_are_visible
        ; Alcotest.test_case "pages of user commands add up to the whole" `Quick
            (pages_add_up_to_the_whole ~with_coinbases_and_zkapps:false)
        ; Alcotest.test_case
            "pages across user, internal and zkApp commands add up to the whole"
            `Quick
            (pages_add_up_to_the_whole ~with_coinbases_and_zkapps:true)
        ] )
    ]
