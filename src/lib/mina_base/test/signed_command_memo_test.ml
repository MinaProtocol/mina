(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^signed command memo$'
    Subject:    Test signed command memo.
 *)

open Core_kernel
open Mina_base
open Signed_command_memo
open For_test

let data memo =
  String.sub (string_of_memo memo) ~pos:(length_index + 1) ~len:(length memo)

let gen min_length max_length =
  let open Quickcheck.Generator.Let_syntax in
  let%bind len = Int.gen_incl min_length max_length in
  String.gen_with_length len Char.gen_alphanum

let with_catch f a = try f a with e -> Or_error.of_exn e

let digest_string () =
  Quickcheck.test (gen 1 max_digestible_string_length) ~f:(fun s ->
      [%test_pred: t] is_valid (create_by_digesting_string_exn s) )

let digest_too_long_string () =
  Quickcheck.test
    (gen (max_digestible_string_length + 1) 10000)
    ~f:(fun s ->
      [%test_eq: t Or_error.t]
        (Or_error.error_string "create_by_digesting_string: string too long")
        (with_catch create_by_digesting_string s) )

let memo_from_string () =
  Quickcheck.test (gen 1 max_input_length) ~f:(fun s ->
      [%test_pred: t] is_valid (create_from_string_exn s) )

let memo_from_too_long_string () =
  Quickcheck.test
    (gen (max_input_length + 1) 10000)
    ~f:(fun s ->
      [%test_eq: t Or_error.t]
        (Or_error.of_exn Too_long_user_memo_input)
        (with_catch (fun x -> Or_error.return @@ create_from_string_exn x) s) )

let typ_is_identity () =
  Quickcheck.test (gen 1 max_input_length) ~f:(fun s ->
      let memo = create_by_digesting_string_exn s in
      let read_constant = function
        | Snarky_backendless.Cvar.Constant x ->
            x
        | _ ->
            assert false
      in
      let (Typ typ) = typ in
      let memo_var =
        memo |> typ.value_to_fields
        |> (fun (arr, aux) ->
             ( Array.map arr ~f:(fun x -> Snarky_backendless.Cvar.Constant x)
             , aux ) )
        |> typ.var_of_fields
      in
      let memo_read =
        memo_var |> typ.var_to_fields
        |> (fun (arr, aux) -> (Array.map arr ~f:(fun x -> read_constant x), aux))
        |> typ.value_of_fields
      in
      [%test_eq: t] memo memo_read )
