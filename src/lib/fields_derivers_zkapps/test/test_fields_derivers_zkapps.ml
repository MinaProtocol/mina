open Core_kernel

module IO = struct
  type +'a t = 'a

  let bind t f = f t

  let return t = t

  module Stream = struct
    type 'a t = 'a Seq.t

    let map t f = Seq.map f t

    let iter t f = Seq.iter f t

    let close _t = ()
  end
end

module Field_error = struct
  type t = string

  let message_of_field_error t = t

  let extensions_of_field_error _t = None
end

module Schema = Graphql_schema.Make (IO) (Field_error)
module Field = Snark_params.Tick.Field
module Public_key = Signature_lib.Public_key.Compressed
module Derivers = Fields_derivers_zkapps.Make (Schema)
include Derivers

module Or_ignore_test = struct
  type 'a t = Check of 'a | Ignore [@@deriving compare, sexp, equal]

  let of_option = function None -> Ignore | Some x -> Check x

  let to_option = function Ignore -> None | Check x -> Some x

  let to_yojson a x = [%to_yojson: 'a option] a (to_option x)

  let of_yojson a x = Result.map ~f:of_option ([%of_yojson: 'a option] a x)

  let derived inner init =
    Derivers.iso ~map:of_option ~contramap:to_option
      (( Derivers.option ~js_type:Fields_derivers_zkapps.Js_layout.Flagged_option
       @@ inner @@ Derivers.o () )
         (Derivers.o ()) )
      init
end

module V = struct
  type t =
    { foo : int
    ; foo1 : Unsigned_extended.UInt64.t
    ; bar : Unsigned_extended.UInt64.t Or_ignore_test.t
    ; baz : Unsigned_extended.UInt32.t list
    }
  [@@deriving annot, compare, sexp, equal, fields, yojson]

  let v =
    { foo = 1
    ; foo1 = Unsigned.UInt64.of_int 10
    ; bar = Or_ignore_test.Check (Unsigned.UInt64.of_int 10)
    ; baz = Unsigned.UInt32.[ of_int 11; of_int 12 ]
    }

  let ( !. ) = ( !. ) ~t_fields_annots

  let derivers obj =
    Fields.make_creator obj ~foo:!.int ~foo1:!.uint64
      ~bar:!.(Or_ignore_test.derived uint64)
      ~baz:!.(list @@ uint32 @@ o ())
    |> finish "V" ~t_toplevel_annots
end

module V2 = struct
  type t = { field : Field.t; nothing : unit [@skip] }
  [@@deriving annot, compare, sexp, equal, fields]

  let v = { field = Field.of_int 10; nothing = () }

  let derivers obj =
    let open Derivers in
    let ( !. ) ?skip_data = ( !. ) ?skip_data ~t_fields_annots in
    Fields.make_creator obj ~field:!.field ~nothing:(( !. ) ~skip_data:() skip)
    |> finish "V2" ~t_toplevel_annots
end

module V3 = struct
  type t = { public_key : Public_key.t }
  [@@deriving annot, compare, sexp, equal, fields]

  let v =
    { public_key =
        Public_key.of_base58_check_exn
          "B62qoTqMG41DFgkyQmY2Pos1x671Gfzs9k8NKqUdSg7wQasEV6qnXQP"
    }

  let derivers obj =
    let open Derivers in
    let ( !. ) = ( !. ) ~t_fields_annots in
    Fields.make_creator obj ~public_key:!.public_key
    |> finish "V3" ~t_toplevel_annots
end

(* Test functions *)
let test_verification_key_with_hash () =
  let open Pickles.Side_loaded.Verification_key in
  (* we do this because the dummy doesn't have a wrap_vk on it *)
  let data = dummy |> to_base58_check |> of_base58_check_exn in
  let v = { With_hash.data; hash = Field.one } in
  let o =
    Fields_derivers_zkapps.verification_key_with_hash
    @@ Fields_derivers_zkapps.o ()
  in
  let roundtrip =
    Fields_derivers_zkapps.of_json o (Fields_derivers_zkapps.to_json o v)
  in
  Alcotest.(check bool)
    "verification key with hash roundtrip" true
    (With_hash.equal equal Field.equal v roundtrip)

let test_full_roundtrips () =
  let v1 = V.derivers @@ Derivers.o () in
  Derivers.Test.Loop.run v1 V.v ;
  Alcotest.(check pass) "full roundtrips" () ()

let test_v2_to_json () =
  let v2 = V2.derivers @@ Derivers.o () in
  let expected = {|{"field":"10"}|} in
  let actual = Yojson.Safe.to_string (Derivers.to_json v2 V2.v) in
  Alcotest.(check string) "to_json'" expected actual

let test_v2_roundtrip_json () =
  let v2 = V2.derivers @@ Derivers.o () in
  let roundtrip = Derivers.of_json v2 (Derivers.to_json v2 V2.v) in
  Alcotest.(check bool) "roundtrip json" true (V2.equal roundtrip V2.v)

let test_v3_to_json () =
  let v3 = V3.derivers @@ Derivers.o () in
  let expected =
    {|{"publicKey":"B62qoTqMG41DFgkyQmY2Pos1x671Gfzs9k8NKqUdSg7wQasEV6qnXQP"}|}
  in
  let actual = Yojson.Safe.to_string (Derivers.to_json v3 V3.v) in
  Alcotest.(check string) "v3 to_json" expected actual

let test_v3_roundtrip_json () =
  let v3 = V3.derivers @@ Derivers.o () in
  let roundtrip = Derivers.of_json v3 (Derivers.to_json v3 V3.v) in
  Alcotest.(check bool) "v3 roundtrip json" true (V3.equal roundtrip V3.v)

let () =
  Alcotest.run "Fields_derivers_zkapps"
    [ ( "verification_key_with_hash"
      , [ Alcotest.test_case "roundtrip json" `Quick
            test_verification_key_with_hash
        ] )
    ; ( "test_module"
      , [ Alcotest.test_case "full roundtrips" `Quick test_full_roundtrips
        ; Alcotest.test_case "v2 to_json" `Quick test_v2_to_json
        ; Alcotest.test_case "v2 roundtrip json" `Quick test_v2_roundtrip_json
        ; Alcotest.test_case "v3 to_json" `Quick test_v3_to_json
        ; Alcotest.test_case "v3 roundtrip json" `Quick test_v3_roundtrip_json
        ] )
    ]
