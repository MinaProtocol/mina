let test_dummy_step_sg () =
  let open Dummy.Ipa.Step in
  let _x = Pickles.Backend.Tick.Keypair.load_urs () in
  let x, y = Lazy.force sg in
  Printf.printf "%s\n" (Pasta_bindings.Fq.to_string x) ;
  Printf.printf "%s\n" (Pasta_bindings.Fq.to_string y)

let test_dummy_wrap_sg () =
  let open Dummy.Ipa.Wrap in
  let _x = Lazy.force sg in
  ()

let tests =
  let open Alcotest in
  [ ("Dummy:Step", [ test_case "sg" `Quick test_dummy_step_sg ])
  ; ("Dummy:Wrap", [ test_case "sg" `Quick test_dummy_wrap_sg ])
  ]
