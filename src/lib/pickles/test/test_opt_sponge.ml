module Wrap_main_inputs = Pickles__Wrap_main_inputs
module Opt_sponge = Pickles__Opt_sponge

module Test_make
    (Impl : Snarky_backendless.Snark_intf.Run)
    (P : Sponge.Intf.Permutation with type Field.t = Impl.Field.t) =
struct
  module O = Opt_sponge.Make (Impl) (P)
  module S = Sponge.Make_sponge (P)
  open Impl

  let test_correctness () =
    let params : _ Sponge.Params.t =
      let a () =
        Array.init 3 ~f:(fun _ -> Field.(constant (Constant.random ())))
      in
      { mds = Array.init 3 ~f:(fun _ -> a ())
      ; round_constants = Array.init 40 ~f:(fun _ -> a ())
      }
    in
    let gen =
      let open Quickcheck.Generator.Let_syntax in
      let%bind n = Quickcheck.Generator.small_positive_int
      and n_pre = Quickcheck.Generator.small_positive_int in
      let%map xs = List.gen_with_length n Field.Constant.gen
      and bs = List.gen_with_length n Bool.quickcheck_generator
      and pre = List.gen_with_length n_pre Field.Constant.gen in
      (pre, List.zip_exn bs xs)
    in
    Quickcheck.test gen ~trials:10 ~f:(fun (pre, ps) ->
        let filtered =
          List.filter_map ps ~f:(fun (b, x) -> if b then Some x else None)
        in
        let init () =
          let pre =
            exists
              (Typ.list ~length:(List.length pre) Field.typ)
              ~compute:(fun () -> pre)
          in
          let s = S.create params in
          List.iter pre ~f:(S.absorb s) ;
          s
        in
        let filtered_res =
          let length = List.length filtered in
          Impl.Internal_Basic.Test.checked_to_unchecked
            (Typ.list ~length Field.typ)
            Field.typ
            (fun xs ->
              make_checked (fun () ->
                  let s = init () in
                  List.iter xs ~f:(S.absorb s) ;
                  S.squeeze s ) )
            filtered
        in
        let opt_res =
          let length = List.length ps in
          Impl.Internal_Basic.Test.checked_to_unchecked
            (Typ.list ~length (Typ.tuple2 Boolean.typ Field.typ))
            Field.typ
            (fun xs ->
              make_checked (fun () ->
                  let s =
                    match pre with
                    | [] ->
                        O.create params
                    | _ :: _ ->
                        O.of_sponge (init ())
                  in
                  List.iter xs ~f:(O.absorb s) ;
                  O.squeeze s ) )
            ps
        in
        if not (Field.Constant.equal filtered_res opt_res) then
          failwithf
            !"hash(%{sexp:Field.Constant.t list}) = %{sexp:Field.Constant.t}\n\
              hash(%{sexp:(bool * Field.Constant.t) list}) = \
              %{sexp:Field.Constant.t}"
            filtered filtered_res ps opt_res () )
end

module Wrap = Test_make (Impls.Wrap) (Wrap_main_inputs.Sponge.Permutation)
module Step = Test_make (Impls.Step) (Step_main_inputs.Sponge.Permutation)

let tests =
  let open Alcotest in
  [ ( "Opt_sponge"
    , [ test_case "wrap correct" `Quick Wrap.test_correctness
      ; test_case "step correct" `Quick Step.test_correctness
      ] )
  ]
