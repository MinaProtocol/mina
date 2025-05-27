open Core_kernel

(** Testing
    -------
    Component:  Mina stdlib
    Invocation: dune exec src/lib/mina_stdlib/tests/main.exe
    Subject:    Test JSON roundtrip for Time.Span.Stable.V1
 *)

module SpanV1 = Mina_stdlib.Time.Span.Stable.V1

(* Test that basic JSON serialization roundtrip works *)
let test_basic_json_roundtrip () =
  let span = Core_kernel.Time.Span.of_sec 42.0 in
  let json = SpanV1.to_yojson span in
  match SpanV1.of_yojson json with
  | Ok decoded ->
      Alcotest.(check bool)
        "Roundtrip equality" true
        (Core_kernel.Time.Span.equal span decoded)
  | Error msg ->
      Alcotest.fail ("JSON parsing failed: " ^ msg)

(* Test zero span roundtrip *)
let test_zero_span_roundtrip () =
  let span = Core_kernel.Time.Span.of_sec 0.0 in
  let json = SpanV1.to_yojson span in
  match SpanV1.of_yojson json with
  | Ok decoded ->
      Alcotest.(check bool)
        "Zero span roundtrip" true
        (Core_kernel.Time.Span.equal span decoded)
  | Error msg ->
      Alcotest.fail ("JSON parsing failed: " ^ msg)

(* Test positive span roundtrip *)
let test_positive_span_roundtrip () =
  let span = Core_kernel.Time.Span.of_sec 86400.0 in
  (* One day *)
  let json = SpanV1.to_yojson span in
  match SpanV1.of_yojson json with
  | Ok decoded ->
      Alcotest.(check bool)
        "Positive span roundtrip" true
        (Core_kernel.Time.Span.equal span decoded)
  | Error msg ->
      Alcotest.fail ("JSON parsing failed: " ^ msg)

(* Test negative span roundtrip *)
let test_negative_span_roundtrip () =
  let span = Core_kernel.Time.Span.of_sec (-3600.0) in
  (* Negative one hour *)
  let json = SpanV1.to_yojson span in
  match SpanV1.of_yojson json with
  | Ok decoded ->
      Alcotest.(check bool)
        "Negative span roundtrip" true
        (Core_kernel.Time.Span.equal span decoded)
  | Error msg ->
      Alcotest.fail ("JSON parsing failed: " ^ msg)

(* Test fraction span roundtrip *)
let test_fraction_span_roundtrip () =
  let span = Core_kernel.Time.Span.of_sec 0.001 in
  (* 1 millisecond *)
  let json = SpanV1.to_yojson span in
  match SpanV1.of_yojson json with
  | Ok decoded ->
      Alcotest.(check bool)
        "Fraction span roundtrip" true
        (Core_kernel.Time.Span.equal span decoded)
  | Error msg ->
      Alcotest.fail ("JSON parsing failed: " ^ msg)

(* Test very small span roundtrip *)
let test_very_small_span_roundtrip () =
  let span = Core_kernel.Time.Span.of_sec 1e-6 in
  (* 1 microsecond *)
  let json = SpanV1.to_yojson span in
  match SpanV1.of_yojson json with
  | Ok decoded ->
      Alcotest.(check bool)
        "Very small span roundtrip" true
        (Core_kernel.Time.Span.equal span decoded)
  | Error msg ->
      Alcotest.fail ("JSON parsing failed: " ^ msg)

(* Test large span roundtrip *)
let test_large_span_roundtrip () =
  let span = Core_kernel.Time.Span.of_sec 31536000.0 in
  (* 1 year *)
  let json = SpanV1.to_yojson span in
  match SpanV1.of_yojson json with
  | Ok decoded ->
      Alcotest.(check bool)
        "Large span roundtrip" true
        (Core_kernel.Time.Span.equal span decoded)
  | Error msg ->
      Alcotest.fail ("JSON parsing failed: " ^ msg)

(* Test invalid JSON input *)
let test_invalid_json_input () =
  match SpanV1.of_yojson (`String "not a valid float") with
  | Ok _ ->
      Alcotest.fail "Expected error for invalid input"
  | Error _ ->
      (* Expected error, test passes *)
      ()

(* Test non-float JSON type *)
let test_non_float_json_type () =
  match SpanV1.of_yojson (`Bool true) with
  | Ok _ ->
      Alcotest.fail "Expected error for non-float JSON type"
  | Error _ ->
      (* Expected error, test passes *)
      ()
