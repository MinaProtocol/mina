(**
   Utils for roundtrip testing of graphql scalars.
 *)
open Utils

module type Test_Intf = sig
  type t

  val gen : t Base_quickcheck.Generator.t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val compare : t -> t -> int
end

let list_of_seq seq =
  let rec loop seq =
    match seq () with
    | Seq.Nil ->
        []
    | Seq.Cons (Ok x, next) ->
        x :: loop next
    | Seq.Cons (Error _, _) ->
        assert false
  in
  loop seq

let json_from_response = function
  | Ok (`Response data) ->
      data
  | Ok (`Stream stream) -> (
      try
        match stream () with
        | Seq.Cons (Ok _, _) ->
            `List (list_of_seq stream)
        | Seq.Cons (Error err, _) ->
            err
        | Seq.Nil ->
            `Null
      with _ -> `String "caught stream exn" )
  | Error err ->
      err

let test_query schema ctx query (f_test : Yojson.Basic.t -> unit) : unit =
  match Graphql_parser.parse query with
  | Error err ->
      failwith err
  | Ok doc ->
      Graphql.Schema.execute schema ctx doc |> json_from_response |> f_test

let get_test_field = function
  | `Assoc [ ("data", `Assoc [ ("test", value) ]) ] ->
      value
  | json ->
      Core_kernel.failwithf "(%s) Unexpected format of JSON response:%s" __LOC__
        (Yojson.Basic.to_string json)
        ()

module Make_test
    (S : Json_intf_any_typ with type ('a, 'b) typ := ('a, 'b) Graphql.Schema.typ)
    (G : Test_Intf with type t = S.t) =
struct
  let query_server_and_compare value =
    let schema =
      Graphql.Schema.(
        schema
          [ field "test"
              ~typ:(non_null @@ S.typ ())
              ~args:Arg.[]
              ~resolve:(fun _ () -> value)
          ])
    in
    test_query schema () "{ test }" (fun response ->
        [%test_eq: G.t] value (S.parse @@ get_test_field response) )

  let%test_unit "test" =
    Core_kernel.Quickcheck.test G.gen ~sexp_of:G.sexp_of_t
      ~f:query_server_and_compare
end
