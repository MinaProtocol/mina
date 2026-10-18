(** Testing
    -------

    Component: Pickles
    Subject: Test Common module utilities
    Invocation: \
     dune exec src/lib/crypto/pickles/test/test_common.exe
*)

(** {2 Domain Configuration Tests} *)

let test_wrap_domains_0_proofs () =
  let domains = Common.wrap_domains ~proofs_verified:0 in
  let log2_size = match domains.h with Pow_2_roots_of_unity n -> n in
  Alcotest.(check int) "domain log2 size for 0 proofs" 13 log2_size

let test_wrap_domains_1_proof () =
  let domains = Common.wrap_domains ~proofs_verified:1 in
  let log2_size = match domains.h with Pow_2_roots_of_unity n -> n in
  Alcotest.(check int) "domain log2 size for 1 proof" 14 log2_size

let test_wrap_domains_2_proofs () =
  let domains = Common.wrap_domains ~proofs_verified:2 in
  let log2_size = match domains.h with Pow_2_roots_of_unity n -> n in
  Alcotest.(check int) "domain log2 size for 2 proofs" 15 log2_size

let test_wrap_domains_invalid () =
  (* Test that wrap_domains raises for any proofs_verified > 2 *)
  let invalid_values = [ 3; 4; 5; 10; 100; 1000 ] in
  List.iter invalid_values ~f:(fun proofs_verified ->
      let raises =
        try
          let (_ : Pickles_base.Domains.t) =
            Common.wrap_domains ~proofs_verified
          in
          false
        with _ -> true
      in
      Alcotest.(check bool)
        (Printf.sprintf "wrap_domains raises for proofs_verified=%d"
           proofs_verified )
        true raises )

let test_actual_wrap_domain_size_inverse () =
  for proofs_verified = 0 to 2 do
    let domains = Common.wrap_domains ~proofs_verified in
    let log2 = match domains.h with Pow_2_roots_of_unity n -> n in
    let result = Common.actual_wrap_domain_size ~log_2_domain_size:log2 in
    Alcotest.(check int)
      (Printf.sprintf "inverse for proofs_verified=%d" proofs_verified)
      proofs_verified
      (Pickles_base.Proofs_verified.to_int result)
  done

(** {2 Bit/Byte Conversion Tests} *)

let test_bits_to_bytes_empty () =
  Alcotest.(check string)
    "empty list produces empty string" "" (Common.bits_to_bytes [])

let test_bits_to_bytes_all_zeros () =
  let bits = [ false; false; false; false; false; false; false; false ] in
  Alcotest.(check string) "all zeros byte" "\x00" (Common.bits_to_bytes bits)

let test_bits_to_bytes_all_ones () =
  let bits = [ true; true; true; true; true; true; true; true ] in
  Alcotest.(check string) "all ones byte" "\xff" (Common.bits_to_bytes bits)

let test_bits_to_bytes_value_1 () =
  (* LSB first: bit 0 = true means value 1 *)
  let bits = [ true; false; false; false; false; false; false; false ] in
  Alcotest.(check string)
    "value 1 (LSB first)" "\x01"
    (Common.bits_to_bytes bits)

let test_bits_to_bytes_value_128 () =
  let bits = [ false; false; false; false; false; false; false; true ] in
  Alcotest.(check string)
    "value 128 (MSB set)" "\x80"
    (Common.bits_to_bytes bits)

let test_bits_to_bytes_multiple () =
  let bits =
    (* First byte: 0x01, Second byte: 0x02 *)
    [ true
    ; false
    ; false
    ; false
    ; false
    ; false
    ; false
    ; false
    ; false
    ; true
    ; false
    ; false
    ; false
    ; false
    ; false
    ; false
    ]
  in
  Alcotest.(check string)
    "multiple bytes" "\x01\x02"
    (Common.bits_to_bytes bits)

let test_bits_to_bytes_partial () =
  (* Only 4 bits: should produce one byte with value 5 (0101 in binary) *)
  let bits = [ true; false; true; false ] in
  Alcotest.(check string)
    "partial byte (4 bits)" "\x05"
    (Common.bits_to_bytes bits)

let test_bits_to_bytes_roundtrip () =
  (* Test that converting known byte values works correctly *)
  let test_byte value =
    let bits = List.init 8 ~f:(fun i -> (value lsr i) land 1 = 1) in
    let result = Common.bits_to_bytes bits in
    Alcotest.(check int)
      (Printf.sprintf "roundtrip for byte %d" value)
      value
      (Char.to_int result.[0])
  in
  List.iter [ 0; 1; 127; 128; 255 ] ~f:test_byte

(** {2 finite_exn Tests} *)

let test_finite_exn_finite () =
  let x, y = Common.finite_exn (Kimchi_types.Finite (42, 99)) in
  Alcotest.(check int) "x coordinate" 42 x ;
  Alcotest.(check int) "y coordinate" 99 y

let test_finite_exn_infinity () =
  let raises =
    try
      let (_ : int * int) = Common.finite_exn Kimchi_types.Infinity in
      false
    with Invalid_argument _ -> true
  in
  Alcotest.(check bool) "finite_exn raises for Infinity" true raises

(** {2 Max_degree Constants Tests} *)

let test_max_degree_step_consistency () =
  Alcotest.(check int)
    "step equals 2^step_log2"
    (1 lsl Common.Max_degree.step_log2)
    Common.Max_degree.step

let test_max_degree_positive () =
  Alcotest.(check bool) "step > 0" true (Common.Max_degree.step > 0) ;
  Alcotest.(check bool) "step_log2 > 0" true (Common.Max_degree.step_log2 > 0) ;
  Alcotest.(check bool) "wrap_log2 > 0" true (Common.Max_degree.wrap_log2 > 0)

(** {2 FFT Shifts Tests} *)

let test_tick_shifts_non_empty () =
  let shifts = Common.tick_shifts ~log2_size:10 in
  Alcotest.(check bool)
    "tick_shifts returns non-empty array" true
    (Array.length shifts > 0)

let test_tock_shifts_non_empty () =
  let shifts = Common.tock_shifts ~log2_size:10 in
  Alcotest.(check bool)
    "tock_shifts returns non-empty array" true
    (Array.length shifts > 0)

let test_tick_shifts_memoized () =
  let shifts1 = Common.tick_shifts ~log2_size:12 in
  let shifts2 = Common.tick_shifts ~log2_size:12 in
  Alcotest.(check bool)
    "tick_shifts is memoized" true
    (Core_kernel.phys_equal shifts1 shifts2)

let test_tock_shifts_memoized () =
  let shifts1 = Common.tock_shifts ~log2_size:12 in
  let shifts2 = Common.tock_shifts ~log2_size:12 in
  Alcotest.(check bool)
    "tock_shifts is memoized" true
    (Core_kernel.phys_equal shifts1 shifts2)

let test_tick_shifts_different_sizes () =
  let shifts1 = Common.tick_shifts ~log2_size:10 in
  let shifts2 = Common.tick_shifts ~log2_size:11 in
  Alcotest.(check bool)
    "different sizes produce different arrays" false
    (Core_kernel.phys_equal shifts1 shifts2)

(** {2 Profiling Tests} *)

let test_when_profiling_default () =
  (* Test that when_profiling returns the correct argument based on env.
     We test the logic by checking that the function returns one of the
     two provided values (we can't easily control env in tests). *)
  let result = Common.when_profiling "profiling" "default" in
  let is_valid =
    String.equal result "profiling" || String.equal result "default"
  in
  Alcotest.(check bool) "returns one of the two provided values" true is_valid

let test_time_returns_result () =
  let result = Common.time "test" (fun () -> 42) in
  Alcotest.(check int) "time executes function and returns result" 42 result

let test_time_preserves_exceptions () =
  let raises =
    try
      let (_ : unit) =
        Common.time "test" (fun () -> failwith "test exception")
      in
      false
    with Failure msg -> String.equal msg "test exception"
  in
  Alcotest.(check bool) "time preserves exceptions" true raises

let test_time_executes_side_effects () =
  let counter = ref 0 in
  let (_ : int) = Common.time "test" (fun () -> incr counter ; !counter) in
  Alcotest.(check int) "time executes side effects" 1 !counter

(** {2 IPA Regression Tests} *)

(* Helper to create a scalar challenge from two int64 limbs *)
let make_scalar_challenge (l0 : int64) (l1 : int64) =
  let challenge : Limb_vector.Challenge.Constant.t =
    Pickles_types.Vector.[ l0; l1 ]
  in
  Kimchi_backend_common.Scalar_challenge.create challenge

(* Wrap.endo_to_field regression tests *)
let test_wrap_endo_to_field_1_2 () =
  let sc = make_scalar_challenge 1L 2L in
  let result = Common.Ipa.Wrap.endo_to_field sc in
  let expected =
    "2719017978331529270847521198778747340188358548055489578169293623337352440597"
  in
  Alcotest.(check string)
    "Wrap.endo_to_field([1,2])" expected
    (Backend.Tock.Field.to_string result)

let test_wrap_endo_to_field_zero () =
  let sc = make_scalar_challenge 0L 0L in
  let result = Common.Ipa.Wrap.endo_to_field sc in
  let expected =
    "13464412046258283063145842131498198913757338040311201334259493836276836242548"
  in
  Alcotest.(check string)
    "Wrap.endo_to_field([0,0])" expected
    (Backend.Tock.Field.to_string result)

let test_wrap_endo_to_field_hex () =
  let sc = make_scalar_challenge 0xDEADBEEFCAFEBABEL 0x123456789ABCDEF0L in
  let result = Common.Ipa.Wrap.endo_to_field sc in
  let expected =
    "3157699691692010035895060508840773759741805810852272103979321912060089824709"
  in
  Alcotest.(check string)
    "Wrap.endo_to_field([0xDEAD...,0x1234...])" expected
    (Backend.Tock.Field.to_string result)

(* Step.endo_to_field regression tests *)
let test_step_endo_to_field_1_2 () =
  let sc = make_scalar_challenge 1L 2L in
  let result = Common.Ipa.Step.endo_to_field sc in
  let expected =
    "6572569482697360481513594310601353836203307207270872842979315960925898757767"
  in
  Alcotest.(check string)
    "Step.endo_to_field([1,2])" expected
    (Backend.Tick.Field.to_string result)

let test_step_endo_to_field_zero () =
  let sc = make_scalar_challenge 0L 0L in
  let result = Common.Ipa.Step.endo_to_field sc in
  let expected =
    "11459188392808088023716231022519329373779186861103795231732712461615739579512"
  in
  Alcotest.(check string)
    "Step.endo_to_field([0,0])" expected
    (Backend.Tick.Field.to_string result)

let test_step_endo_to_field_hex () =
  let sc = make_scalar_challenge 0xDEADBEEFCAFEBABEL 0x123456789ABCDEF0L in
  let result = Common.Ipa.Step.endo_to_field sc in
  let expected =
    "14692341689041640409374680542529680697373469829962348207529812283743150813271"
  in
  Alcotest.(check string)
    "Step.endo_to_field([0xDEAD...,0x1234...])" expected
    (Backend.Tick.Field.to_string result)

(* Test that Wrap and Step produce different results for the same input *)
let test_wrap_step_endo_differ () =
  let sc = make_scalar_challenge 42L 123L in
  let wrap_result = Common.Ipa.Wrap.endo_to_field sc in
  let step_result = Common.Ipa.Step.endo_to_field sc in
  let wrap_str = Backend.Tock.Field.to_string wrap_result in
  let step_str = Backend.Tick.Field.to_string step_result in
  Alcotest.(check bool)
    "Wrap and Step endo_to_field produce different results" true
    (not (String.equal wrap_str step_str))

(* compute_challenge regression tests - verifies compute_challenge equals endo_to_field *)
let test_wrap_compute_challenge_equals_endo () =
  let sc = make_scalar_challenge 1L 2L in
  let challenge_result = Common.Ipa.Wrap.compute_challenge sc in
  let endo_result = Common.Ipa.Wrap.endo_to_field sc in
  Alcotest.(check string)
    "Wrap.compute_challenge equals endo_to_field"
    (Backend.Tock.Field.to_string endo_result)
    (Backend.Tock.Field.to_string challenge_result)

let test_step_compute_challenge_equals_endo () =
  let sc = make_scalar_challenge 1L 2L in
  let challenge_result = Common.Ipa.Step.compute_challenge sc in
  let endo_result = Common.Ipa.Step.endo_to_field sc in
  Alcotest.(check string)
    "Step.compute_challenge equals endo_to_field"
    (Backend.Tick.Field.to_string endo_result)
    (Backend.Tick.Field.to_string challenge_result)

(* compute_challenges regression tests using Dummy challenges *)
module Dummy = Pickles__Dummy

(* Expected values for Wrap.compute_challenges (15 elements) *)
let wrap_compute_challenges_expected =
  [| "7048930911355605315581096707847688535149125545610393399193999502037687877674"
   ; "5945064094191074331354717685811267396540107129706976521474145740173204364019"
   ; "20315491820009986698838977727629973056499886675589920515484193128018854963801"
   ; "375929229548289966749422550601268097380795636681684498450629863247980915833"
   ; "19682218496321100578766622300447982536359891434050417209656101638029891689955"
   ; "516598185966802396400068849903674663130928531697254466925429658676832606723"
   ; "23729760760563685146228624125180554011222918208600079938584869191222807389336"
   ; "11155777282048225577422475738306432747575091690354122761439079853293714987855"
   ; "24977767586983413450834833875715786066408803952857478894197349635213480783870"
   ; "2813347787496113574506936084777563965225649411532015639663405402448028142689"
   ; "22626141769059119580550800305467929090916842064220293932303261732461616709448"
   ; "18748107085456859495495117012311103043200881556220793307463332157672741458218"
   ; "22196219950929618042921320796106738233125483954115679355597636800196070731081"
   ; "13054421325261400802177761929986025883530654947859503505174678618288142017333"
   ; "4799483385651443229337780097631636300491234601736019220096005875687579936102"
  |]

let test_wrap_compute_challenges_all () =
  let chals_computed =
    Common.Ipa.Wrap.compute_challenges Dummy.Ipa.Wrap.challenges
  in
  let chals_list = Pickles_types.Vector.to_list chals_computed in
  let chals_strings =
    Core_kernel.List.map chals_list ~f:Backend.Tock.Field.to_string
  in
  Alcotest.(check int)
    "Wrap.compute_challenges length" 15
    (Core_kernel.List.length chals_list) ;
  (* First print all mismatches *)
  let has_mismatch = ref false in
  Core_kernel.List.iteri chals_strings ~f:(fun i actual ->
      let expected = wrap_compute_challenges_expected.(i) in
      if not (String.equal expected actual) then (
        Printf.printf "  ; \"%s\" (* %d *)\n" actual i ;
        has_mismatch := true ) ) ;
  (* Then check all values *)
  if !has_mismatch then
    Alcotest.fail "Wrap.compute_challenges values mismatch (see above)"

(* Expected values for Step.compute_challenges (16 elements) *)
let step_compute_challenges_expected =
  [| "7495663189519076456878324238415292467012945870012832444850485639358393479268"
   ; "388698164585548974934817724189574785139851269733029709355370076076616265220"
   ; "16211690239820640934419707440800640715772094470488029352806394140849460499366"
   ; "19660767386333838085549000243591542798150442487419024559562124380763066947223"
   ; "3804191934641277266825939456740395716006727418575334949907761799006951240328"
   ; "18570333327677121098853677483616132304851142649800358431192661910558495770797"
   ; "2885988345150694614354230616472074099998052091287012799686730182775015809772"
   ; "26941570725129557194472457464313030750768597876248657068167847720705824432410"
   ; "11031939102021548268582687527395546394462552178834987820391978709224042719328"
   ; "6635159214963234537223243370996260502046741015718543202847863438182226573507"
   ; "3123982144639717810070104930175949984822659675428941158107237873724846395068"
   ; "22100131743595904534278023371975366782332995882031444298009028129572218436492"
   ; "26699469737251775041171879406801327630656476958614785279587470558078266497754"
   ; "14931081622979512493702242057574822158556931395424601456904686553568978135221"
   ; "13215496949030789875154586717734663769533434569051642948945201035069761057380"
   ; "9608414576668132631768032439576786729901517711700624403511207659611494885692"
  |]

let test_step_compute_challenges_all () =
  let chals_computed =
    Common.Ipa.Step.compute_challenges Dummy.Ipa.Step.challenges
  in
  let chals_list = Pickles_types.Vector.to_list chals_computed in
  let chals_strings =
    Core_kernel.List.map chals_list ~f:Backend.Tick.Field.to_string
  in
  Alcotest.(check int)
    "Step.compute_challenges length" 16
    (Core_kernel.List.length chals_list) ;
  (* First print all mismatches *)
  let has_mismatch = ref false in
  Core_kernel.List.iteri chals_strings ~f:(fun i actual ->
      let expected = step_compute_challenges_expected.(i) in
      if not (String.equal expected actual) then (
        Printf.printf "  ; \"%s\" (* %d *)\n" actual i ;
        has_mismatch := true ) ) ;
  (* Then check all values *)
  if !has_mismatch then
    Alcotest.fail "Step.compute_challenges values mismatch (see above)"

(** {2 Test Suite Registration} *)

let domain_tests =
  [ Alcotest.test_case "wrap_domains 0 proofs" `Quick test_wrap_domains_0_proofs
  ; Alcotest.test_case "wrap_domains 1 proof" `Quick test_wrap_domains_1_proof
  ; Alcotest.test_case "wrap_domains 2 proofs" `Quick test_wrap_domains_2_proofs
  ; Alcotest.test_case "wrap_domains invalid" `Quick test_wrap_domains_invalid
  ; Alcotest.test_case "actual_wrap_domain_size inverse" `Quick
      test_actual_wrap_domain_size_inverse
  ]

let bits_to_bytes_tests =
  [ Alcotest.test_case "empty" `Quick test_bits_to_bytes_empty
  ; Alcotest.test_case "all zeros" `Quick test_bits_to_bytes_all_zeros
  ; Alcotest.test_case "all ones" `Quick test_bits_to_bytes_all_ones
  ; Alcotest.test_case "value 1" `Quick test_bits_to_bytes_value_1
  ; Alcotest.test_case "value 128" `Quick test_bits_to_bytes_value_128
  ; Alcotest.test_case "multiple bytes" `Quick test_bits_to_bytes_multiple
  ; Alcotest.test_case "partial byte" `Quick test_bits_to_bytes_partial
  ; Alcotest.test_case "roundtrip" `Quick test_bits_to_bytes_roundtrip
  ]

let finite_exn_tests =
  [ Alcotest.test_case "finite" `Quick test_finite_exn_finite
  ; Alcotest.test_case "infinity" `Quick test_finite_exn_infinity
  ]

let max_degree_tests =
  [ Alcotest.test_case "step consistency" `Quick
      test_max_degree_step_consistency
  ; Alcotest.test_case "positive values" `Quick test_max_degree_positive
  ]

let shifts_tests =
  [ Alcotest.test_case "tick_shifts non-empty" `Quick test_tick_shifts_non_empty
  ; Alcotest.test_case "tock_shifts non-empty" `Quick test_tock_shifts_non_empty
  ; Alcotest.test_case "tick_shifts memoized" `Quick test_tick_shifts_memoized
  ; Alcotest.test_case "tock_shifts memoized" `Quick test_tock_shifts_memoized
  ; Alcotest.test_case "different sizes" `Quick test_tick_shifts_different_sizes
  ]

let profiling_tests =
  [ Alcotest.test_case "when_profiling default" `Quick
      test_when_profiling_default
  ; Alcotest.test_case "time returns result" `Quick test_time_returns_result
  ; Alcotest.test_case "time preserves exceptions" `Quick
      test_time_preserves_exceptions
  ; Alcotest.test_case "time executes side effects" `Quick
      test_time_executes_side_effects
  ]

let ipa_tests =
  [ Alcotest.test_case "Wrap.endo_to_field [1,2]" `Quick
      test_wrap_endo_to_field_1_2
  ; Alcotest.test_case "Wrap.endo_to_field [0,0]" `Quick
      test_wrap_endo_to_field_zero
  ; Alcotest.test_case "Wrap.endo_to_field [hex]" `Quick
      test_wrap_endo_to_field_hex
  ; Alcotest.test_case "Step.endo_to_field [1,2]" `Quick
      test_step_endo_to_field_1_2
  ; Alcotest.test_case "Step.endo_to_field [0,0]" `Quick
      test_step_endo_to_field_zero
  ; Alcotest.test_case "Step.endo_to_field [hex]" `Quick
      test_step_endo_to_field_hex
  ; Alcotest.test_case "Wrap and Step endo differ" `Quick
      test_wrap_step_endo_differ
  ; Alcotest.test_case "Wrap.compute_challenge = endo" `Quick
      test_wrap_compute_challenge_equals_endo
  ; Alcotest.test_case "Step.compute_challenge = endo" `Quick
      test_step_compute_challenge_equals_endo
  ; Alcotest.test_case "Wrap.compute_challenges all" `Quick
      test_wrap_compute_challenges_all
  ; Alcotest.test_case "Step.compute_challenges all" `Quick
      test_step_compute_challenges_all
  ]

let () =
  Alcotest.run "Pickles Common"
    [ ("Domain configuration", domain_tests)
    ; ("bits_to_bytes", bits_to_bytes_tests)
    ; ("finite_exn", finite_exn_tests)
    ; ("Max_degree", max_degree_tests)
    ; ("FFT shifts", shifts_tests)
    ; ("Profiling", profiling_tests)
    ; ("IPA", ipa_tests)
    ]
