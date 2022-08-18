(**
   This file re-exports the modules containing graphql custom scalars and their serializers.
   These are used by graphql_ppx to automatically use the correct decoder for the fields.
 *)

include Graphql_basic_scalars
include Mina_base_unix.Graphql_scalars
include Mina_block_unix.Graphql_scalars
include Mina_numbers_unix.Graphql_scalars
include Currency_unix.Graphql_scalars
include Signature_lib_unix.Graphql_scalars
include Block_time_unix.Graphql_scalars
include Filtered_external_transition_unix.Graphql_scalars
include Consensus.Graphql_scalars
include Mina_transaction_unix.Graphql_scalars

let tester ?(equal = ( = )) input ~left ~right ~f =
  input
  |> List.map (fun (a, b) -> (left a, right b))
  |> List.for_all (fun (input, expected) -> equal (f input) expected)

let idempotence_tester ?(equal = ( = )) input ~parse ~serialize =
  input |> List.for_all (fun json -> equal (json |> parse |> serialize) json)

(* Graphql_basic_scalars *)
let%test_module "UInt32" =
  ( module struct
    let%test "parse" =
      let input =
        [ ("+2343", 2343)
        ; ("23", 23)
        ; ("3459", 3459)
        ; ("4294967295", 4294967295)
        ]
      in
      tester input
        ~left:(fun s -> `String s)
        ~right:Unsigned.UInt32.of_int ~f:UInt32.parse

    (* this doesn't work right now because parsing numbers that are negative
       or greater than Unsigned.UInt32.max_int wrap around to form valid
       Unsigned.UInt32.t numbers *)

    (* also fix UInt64 when we are done with this *)

    (* let%test_unit "parse simple uint32 with - sign" =
       let json = `String "-331" in
       match UInt32.parse json with
       | _result ->
           print_endline (Unsigned.UInt32.to_string _result) ;
           failwith "Expected a parse failure when parsing -331 as an Unsigned.UInt32.t"
       | exception _ ->
           () *)

    (* also, parsing strings like `23423ddkl` succeeds and only return the
       integer section. *)
    let%test_unit "parse failure" =
      let strs = [ "dfs233"; "gfhh32"; "ins23f"; "hgsf" ] in
      strs
      |> List.iter (fun str ->
             let json = `String str in
             match UInt32.parse json with
             | _result ->
                 failwith
                 @@ Printf.sprintf
                      "Expected a parse failure when parsing %s as an \
                       Unsigned.UInt32.t. It parsed as %s"
                      str
                      (Unsigned.UInt32.to_string _result)
             | exception _ ->
                 () )

    let%test "serialize" =
      let input =
        [ (53, "53")
        ; (23, "23")
        ; (23432, "23432")
        ; (4294967295, "4294967295")
        ; (543, "543")
        ]
      in
      tester input ~left:Unsigned.UInt32.of_int
        ~right:(fun s -> `String s)
        ~f:UInt32.serialize

    let%test "idempotence (id = serialize . parse)" =
      let strs =
        [ "2354"; "3466"; "982372"; "238472"; "9845" ]
        |> List.map (fun str -> `String str)
      in
      idempotence_tester strs ~parse:UInt32.parse ~serialize:UInt32.serialize
  end )

let%test_module "UInt64" =
  ( module struct
    let%test "parse" =
      let input =
        [ ("+349857", 349857L)
        ; ("0", 0L)
        ; ("23", 23L)
        ; ("34592233323423", 34592233323423L)
        ; ("1844674407370955161", 1844674407370955161L)
        ; ("4294967295", 4294967295L)
        ]
      in
      tester input
        ~left:(fun s -> `String s)
        ~right:Unsigned.UInt64.of_int64 ~f:UInt64.parse

    let%test_unit "parse failure" =
      let strs = [ "dfs233"; "gfhh32"; "ins23f"; "hgsf" ] in
      strs
      |> List.iter (fun str ->
             let json = `String str in
             match UInt64.parse json with
             | result ->
                 failwith
                 @@ Printf.sprintf
                      "Expected a parse failure when parsing %s as an \
                       Unsigned.UInt64.t. It parsed as %s"
                      str
                      (Unsigned.UInt64.to_string result)
             | exception _ ->
                 () )

    let%test "serialize" =
      let input =
        [ (122342553L, "122342553")
        ; (23123423L, "23123423")
        ; (23432L, "23432")
        ; (4294967295L, "4294967295")
        ; (1844674407370955161L, "1844674407370955161")
        ]
      in
      tester input ~left:Unsigned.UInt64.of_int64
        ~right:(fun s -> `String s)
        ~f:UInt64.serialize

    let%test "idempotence (id = serialize . parse)" =
      let strs =
        [ "4294967295"
        ; "346453456"
        ; "982333458972"
        ; "0"
        ; "2398723446"
        ; "1844674407370955161"
        ]
        |> List.map (fun str -> `String str)
      in
      idempotence_tester strs ~parse:UInt64.parse ~serialize:UInt64.serialize
  end )

let%test_module "String_json" =
  ( module struct
    let dup x = (x, x)

    let%test "parse" =
      let input =
        [ dup "sadfafkj"
        ; dup "skjsdf"
        ; dup "home"
        ; dup "devljfs"
        ; dup "nixos"
        ; dup "nix"
        ]
      in
      tester input
        ~left:(fun s -> `String s)
        ~right:Core.Fn.id ~f:String_json.parse

    let%test "serialize" =
      let input =
        [ dup "selcted"
        ; dup "textinpuds"
        ; dup "random"
        ; dup "joifdslkj"
        ; dup "creailj"
        ]
      in
      tester input ~left:Core.Fn.id
        ~right:(fun s -> `String s)
        ~f:String_json.serialize

    let%test "idempotence (id = serialize . parse)" =
      let strs =
        [ "sdfljsfn"; "thissf sd"; "sfdlkjs"; "nixdeveljs"; "sadfjs"; "sdfl" ]
        |> List.map (fun str -> `String str)
      in
      idempotence_tester strs ~parse:String_json.parse
        ~serialize:String_json.serialize
  end )

let%test_module "Time" =
  ( module struct
    let time_of_span =
      Core.Fn.compose Core_kernel.Time.of_span_since_epoch
        Core_kernel.Time.Span.of_sec

    let%test "parse" =
      let input =
        [ ("2022-08-16 23:05:57.955511Z", 1660691157.95551085)
        ; ("2022-08-16 23:52:26.813910Z", 1660693946.81390977)
        ; ("1970-01-27 21:35:24.352200Z", 2324124.3522)
        ; ("1983-10-18 22:32:12.344400Z", 435364332.3444)
        ; ("2020-08-16 23:05:57.955511Z", 1597619157.95551109)
        ]
      in
      tester input
        ~left:(fun s -> `String s)
        ~right:time_of_span ~f:Time.parse ~equal:Core_kernel.Time.( =. )

    let%test "serialize" =
      let input =
        [ (1660691157.95551085, "2022-08-16 23:05:57.955511Z")
        ; (1660693946.81390977, "2022-08-16 23:52:26.813910Z")
        ; (2324124.3522, "1970-01-27 21:35:24.352200Z")
        ; (435364332.3444, "1983-10-18 22:32:12.344400Z")
        ; (1597619157.95551109, "2020-08-16 23:05:57.955511Z")
        ]
      in
      tester input ~left:time_of_span
        ~right:(fun s -> `String s)
        ~f:Time.serialize

    let%test "idempotence (id = serialize . parse)" =
      let strs =
        [ "2020-08-16 23:05:57.955511Z"
        ; "1983-10-18 22:32:12.344400Z"
        ; "1970-01-27 21:35:24.352200Z"
        ; "2022-08-16 23:52:26.813910Z"
        ; "2022-08-16 23:05:57.955511Z"
        ]
        |> List.map (fun str -> `String str)
      in
      idempotence_tester strs ~parse:Time.parse ~serialize:Time.serialize
  end )

let%test_module "Span" =
  ( module struct
    let%test "parse" =
      let input =
        [ ("23423943985", 23423943985.)
        ; ("9873453", 9873453.)
        ; ("487493", 487493.)
        ; ("4294967295", 4294967295.)
        ]
      in
      tester input
        ~left:(fun s -> `String s)
        ~right:Core.Time.Span.of_ms ~f:Span.parse

    let%test "serialize" =
      let input =
        [ (5784843., "5784843")
        ; (9874573., "9874573")
        ; (876342., "876342")
        ; (3587324287., "3587324287")
        ]
      in
      tester input ~left:Core.Time.Span.of_ms
        ~right:(fun s -> `String s)
        ~f:Span.serialize

    let%test "idempotence (id = serialize . parse)" =
      let strs =
        [ "4294967295"
        ; "1232498366"
        ; "34443929823"
        ; "321983498"
        ; "0"
        ; "12348745"
        ]
        |> List.map (fun str -> `String str)
      in
      idempotence_tester strs ~parse:Span.parse ~serialize:Span.serialize
  end )

(*  Consensus.Graphql_scalars *)
let%test_module "Slot" =
  ( module struct
    let%test "parse" =
      let input =
        [ ("234234", 234234)
        ; ("46346", 46346)
        ; ("459874", 459874)
        ; ("974534", 974534)
        ; ("0", 0)
        ]
      in
      tester input
        ~left:(fun s -> `String s)
        ~right:Consensus__Slot.of_int ~f:Slot.parse

    let%test "serialize" =
      let input =
        [ (5784843, "5784843")
        ; (9874573, "9874573")
        ; (876342, "876342")
        ; (3587324287, "3587324287")
        ]
      in
      tester input ~left:Consensus__Slot.of_int
        ~right:(fun s -> `String s)
        ~f:Slot.serialize

    let%test "idempotence (id = serialize . parse)" =
      let strs =
        [ "967295"
        ; "123246"
        ; "3444392"
        ; "321998"
        ; "0"
        ; "123745"
        ; "438753"
        ; "2234"
        ]
        |> List.map (fun str -> `String str)
      in
      idempotence_tester strs ~parse:Slot.parse ~serialize:Slot.serialize
  end )
