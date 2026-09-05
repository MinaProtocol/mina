(* The bin_prot instances of [Field] and [Bigint] write to and read from the
   buffer in place. These tests pin their encoding to [Bigint.to_bytes] on the
   values where a limb-wise implementation can go wrong: around zero, around
   the modulus, and with every subset of the four 64-bit limbs populated. *)

open Core

(* Every subset of the four limbs: "min" sets the lowest bit of each chosen
   limb, "max" saturates it. The top limb of "max" is capped at 2^62 - 1 so
   that every value is below both Pasta moduli. *)
let limb_patterns =
  [ ("limbs 0 min", "1")
  ; ("limbs 0 max", "18446744073709551615")
  ; ("limbs 1 min", "18446744073709551616")
  ; ("limbs 1 max", "340282366920938463444927863358058659840")
  ; ("limbs 01 min", "18446744073709551617")
  ; ("limbs 01 max", "340282366920938463463374607431768211455")
  ; ("limbs 2 min", "340282366920938463463374607431768211456")
  ; ("limbs 2 max", "6277101735386680763495507056286727952638980837032266301440")
  ; ("limbs 02 min", "340282366920938463463374607431768211457")
  ; ( "limbs 02 max"
    , "6277101735386680763495507056286727952657427581105975853055" )
  ; ("limbs 12 min", "340282366920938463481821351505477763072")
  ; ( "limbs 12 max"
    , "6277101735386680763835789423207666416083908700390324961280" )
  ; ("limbs 012 min", "340282366920938463481821351505477763073")
  ; ( "limbs 012 max"
    , "6277101735386680763835789423207666416102355444464034512895" )
  ; ("limbs 3 min", "6277101735386680763835789423207666416102355444464034512896")
  ; ( "limbs 3 max"
    , "28948022309329048849615644516785296199481706743202474593762040557514247897088"
    )
  ; ( "limbs 03 min"
    , "6277101735386680763835789423207666416102355444464034512897" )
  ; ( "limbs 03 max"
    , "28948022309329048849615644516785296199481706743202474593780487301587957448703"
    )
  ; ( "limbs 13 min"
    , "6277101735386680763835789423207666416120802188537744064512" )
  ; ( "limbs 13 max"
    , "28948022309329048849615644516785296199821989110123413057206968420872306556928"
    )
  ; ( "limbs 013 min"
    , "6277101735386680763835789423207666416120802188537744064513" )
  ; ( "limbs 013 max"
    , "28948022309329048849615644516785296199821989110123413057225415164946016108543"
    )
  ; ( "limbs 23 min"
    , "6277101735386680764176071790128604879565730051895802724352" )
  ; ( "limbs 23 max"
    , "28948022309329048855892746252171976962977213799489202546401021394546514198528"
    )
  ; ( "limbs 023 min"
    , "6277101735386680764176071790128604879565730051895802724353" )
  ; ( "limbs 023 max"
    , "28948022309329048855892746252171976962977213799489202546419468138620223750143"
    )
  ; ( "limbs 123 min"
    , "6277101735386680764176071790128604879584176795969512275968" )
  ; ( "limbs 123 max"
    , "28948022309329048855892746252171976963317496166410141009845949257904572858368"
    )
  ; ( "limbs 0123 min"
    , "6277101735386680764176071790128604879584176795969512275969" )
  ; ( "limbs 0123 max"
    , "28948022309329048855892746252171976963317496166410141009864396001978282409983"
    )
  ]

(* The "max" patterns with the top limb saturated too: above both moduli, so
   only valid for [Bigint]. The last one is 2^256 - 1. *)
let full_width_patterns =
  [ ( "limbs 3 max full"
    , "115792089237316195417293883273301227089434195242432897623355228563449095127040"
    )
  ; ( "limbs 03 max full"
    , "115792089237316195417293883273301227089434195242432897623373675307522804678655"
    )
  ; ( "limbs 13 max full"
    , "115792089237316195417293883273301227089774477609353836086800156426807153786880"
    )
  ; ( "limbs 013 max full"
    , "115792089237316195417293883273301227089774477609353836086818603170880863338495"
    )
  ; ( "limbs 23 max full"
    , "115792089237316195423570985008687907852929702298719625575994209400481361428480"
    )
  ; ( "limbs 023 max full"
    , "115792089237316195423570985008687907852929702298719625576012656144555070980095"
    )
  ; ( "limbs 123 max full"
    , "115792089237316195423570985008687907853269984665640564039439137263839420088320"
    )
  ; ( "limbs 0123 max full"
    , "115792089237316195423570985008687907853269984665640564039457584007913129639935"
    )
  ]

let around_zero = [ ("zero", "0"); ("one", "1"); ("two", "2") ]

(* Write at a nonzero offset so that a wrong base offset shows up, and fill
   the buffer with a sentinel so that bytes outside the element show up. *)
let offset = 3

let sentinel = '\xAA'

let fresh_buffer len = Bigstring.of_string (String.make (offset + len) sentinel)

let bytes_at buf ~len = Bigstring.To_string.sub buf ~pos:offset ~len

let prefix_of buf = Bigstring.To_string.sub buf ~pos:0 ~len:offset

module Bigint = Kimchi_pasta_snarky_backend.Bigint256

let len = Bigint.length_in_bytes

let check_bigint (name, decimal) =
  let b = Bigint.of_decimal_string decimal in
  let expected = Bytes.to_string (Bigint.to_bytes b) in
  Alcotest.(check bool)
    (name ^ ": of_bytes inverts to_bytes")
    true
    (Bigint.compare b (Bigint.of_bytes (Bigint.to_bytes b)) = 0) ;
  Alcotest.(check int) (name ^ ": bin_size_t") len (Bigint.bin_size_t b) ;
  let buf = fresh_buffer len in
  let pos = Bigint.bin_write_t buf ~pos:offset b in
  Alcotest.(check int) (name ^ ": bin_write_t advances") (offset + len) pos ;
  Alcotest.(check string)
    (name ^ ": bin_write_t matches to_bytes")
    expected (bytes_at buf ~len) ;
  Alcotest.(check string)
    (name ^ ": bin_write_t leaves the prefix alone")
    (String.make offset sentinel)
    (prefix_of buf) ;
  let pos_ref = ref offset in
  let b' = Bigint.bin_read_t buf ~pos_ref in
  Alcotest.(check bool)
    (name ^ ": bin_read_t inverts bin_write_t")
    true
    (Bigint.compare b b' = 0) ;
  Alcotest.(check int) (name ^ ": bin_read_t advances") (offset + len) !pos_ref ;
  let buf' = fresh_buffer len in
  Bigint.to_bytes_into b buf' offset ;
  Alcotest.(check string)
    (name ^ ": to_bytes_into matches to_bytes")
    expected (bytes_at buf' ~len) ;
  Alcotest.(check bool)
    (name ^ ": of_bytes_from inverts to_bytes_into")
    true
    (Bigint.compare b (Bigint.of_bytes_from buf' offset) = 0)

let test_bigint_values () =
  List.iter ~f:check_bigint (around_zero @ limb_patterns @ full_width_patterns)

let test_bigint_buffer_short () =
  let b = Bigint.of_decimal_string "1" in
  let short = Bigstring.create (offset + len - 1) in
  Alcotest.check_raises "bin_write_t on a short buffer"
    Bin_prot.Common.Buffer_short (fun () ->
      ignore (Bigint.bin_write_t short ~pos:offset b : int) ) ;
  Alcotest.check_raises "bin_read_t on a short buffer"
    Bin_prot.Common.Buffer_short (fun () ->
      ignore (Bigint.bin_read_t short ~pos_ref:(ref offset) : Bigint.t) )

module Make_field
    (Field : Kimchi_pasta_snarky_backend.Field.S_with_version)
    (M : sig
      val p_minus_1 : string

      val p_minus_2 : string

      val half_p_minus_1 : string

      val half_p_plus_1 : string
    end) =
struct
  module Bigint = Field.Bigint

  let check_field (name, decimal) =
    let b = Bigint.of_decimal_string decimal in
    let x = Field.of_bigint b in
    let expected = Bytes.to_string (Bigint.to_bytes b) in
    Alcotest.(check string)
      (name ^ ": to_bigint round trip")
      expected
      (Bytes.to_string (Bigint.to_bytes (Field.to_bigint x))) ;
    Alcotest.(check int)
      (name ^ ": bin_size_t") len
      (Field.Stable.Latest.bin_size_t x) ;
    let buf = fresh_buffer len in
    let pos = Field.Stable.Latest.bin_write_t buf ~pos:offset x in
    Alcotest.(check int) (name ^ ": bin_write_t advances") (offset + len) pos ;
    Alcotest.(check string)
      (name ^ ": bin_write_t matches Bigint.to_bytes")
      expected (bytes_at buf ~len) ;
    Alcotest.(check string)
      (name ^ ": bin_write_t leaves the prefix alone")
      (String.make offset sentinel)
      (prefix_of buf) ;
    let pos_ref = ref offset in
    let x' = Field.Stable.Latest.bin_read_t buf ~pos_ref in
    Alcotest.(check bool)
      (name ^ ": bin_read_t inverts bin_write_t")
      true (Field.equal x x') ;
    Alcotest.(check int)
      (name ^ ": bin_read_t advances")
      (offset + len) !pos_ref ;
    let buf' = fresh_buffer len in
    Field.to_bytes_into x buf' offset ;
    Alcotest.(check string)
      (name ^ ": to_bytes_into matches Bigint.to_bytes")
      expected (bytes_at buf' ~len) ;
    Alcotest.(check bool)
      (name ^ ": of_bytes_from inverts to_bytes_into")
      true
      (Field.equal x (Field.of_bytes_from buf' offset))

  (* The negatives, with their decimal values cross-checked against field
     arithmetic so that a wrong constant cannot pass. *)
  let around_modulus =
    [ ("p - 1 (-1)", M.p_minus_1, Field.negate Field.one)
    ; ("p - 2 (-2)", M.p_minus_2, Field.negate (Field.of_int 2))
    ; ("(p - 1) / 2", M.half_p_minus_1, Field.(negate one / of_int 2))
    ; ("(p + 1) / 2 (1/2)", M.half_p_plus_1, Field.inv (Field.of_int 2))
    ]

  let test_around_zero () = List.iter ~f:check_field around_zero

  let test_around_modulus () =
    List.iter around_modulus ~f:(fun (name, decimal, computed) ->
        let from_decimal = Field.of_bigint (Bigint.of_decimal_string decimal) in
        Alcotest.(check bool)
          (name ^ ": decimal constant agrees with field arithmetic")
          true
          (Field.equal from_decimal computed) ;
        check_field (name, decimal) )

  let test_limb_patterns () = List.iter ~f:check_field limb_patterns

  let test_buffer_short () =
    let x = Field.one in
    let short = Bigstring.create (offset + len - 1) in
    Alcotest.check_raises "bin_write_t on a short buffer"
      Bin_prot.Common.Buffer_short (fun () ->
        ignore (Field.Stable.Latest.bin_write_t short ~pos:offset x : int) ) ;
    Alcotest.check_raises "bin_read_t on a short buffer"
      Bin_prot.Common.Buffer_short (fun () ->
        ignore
          (Field.Stable.Latest.bin_read_t short ~pos_ref:(ref offset) : Field.t) )

  let tests =
    let open Alcotest in
    [ test_case "around zero" `Quick test_around_zero
    ; test_case "around the modulus" `Quick test_around_modulus
    ; test_case "limb patterns" `Quick test_limb_patterns
    ; test_case "buffer short" `Quick test_buffer_short
    ]
end

(* Vesta_based_plonk.Field is Fp; Pallas_based_plonk.Field is Fq. *)
module Fp =
  Make_field
    (Kimchi_pasta_snarky_backend.Vesta_based_plonk.Field)
    (struct
      let p_minus_1 =
        "28948022309329048855892746252171976963363056481941560715954676764349967630336"

      let p_minus_2 =
        "28948022309329048855892746252171976963363056481941560715954676764349967630335"

      let half_p_minus_1 =
        "14474011154664524427946373126085988481681528240970780357977338382174983815168"

      let half_p_plus_1 =
        "14474011154664524427946373126085988481681528240970780357977338382174983815169"
    end)

module Fq =
  Make_field
    (Kimchi_pasta_snarky_backend.Pallas_based_plonk.Field)
    (struct
      let p_minus_1 =
        "28948022309329048855892746252171976963363056481941647379679742748393362948096"

      let p_minus_2 =
        "28948022309329048855892746252171976963363056481941647379679742748393362948095"

      let half_p_minus_1 =
        "14474011154664524427946373126085988481681528240970823689839871374196681474048"

      let half_p_plus_1 =
        "14474011154664524427946373126085988481681528240970823689839871374196681474049"
    end)

let () =
  let open Alcotest in
  run "Serialization"
    [ ( "Bigint256"
      , [ test_case "around zero, limb patterns, full width" `Quick
            test_bigint_values
        ; test_case "buffer short" `Quick test_bigint_buffer_short
        ] )
    ; ("Fp", Fp.tests)
    ; ("Fq", Fq.tests)
    ]
