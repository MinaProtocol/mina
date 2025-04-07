open Core_kernel
open Pickles_types
open Pickles.Impls.Step

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

(* This testcase implements OEIS A000073: https://oeis.org/A000073 *)

module Trib_return = struct
  type branch_direction = Left | Middle | Right

  type _ Snarky_backendless.Request.t +=
    | Input : branch_direction -> Field.Constant.t Snarky_backendless.Request.t
    | Output : branch_direction -> Field.Constant.t Snarky_backendless.Request.t
    | Proof :
        branch_direction
        -> (Nat.N3.n, Nat.N3.n) Pickles.Proof.t Snarky_backendless.Request.t

  type step_data =
    { input : Field.Constant.t
    ; output : Field.Constant.t
    ; proof : (Nat.N3.n, Nat.N3.n) Pickles.Proof.t
    }

  let handler (left : step_data) (middle : step_data) (right : step_data)
      (Snarky_backendless.Request.With { request; respond }) =
    match request with
    | Input Left ->
        respond (Provide left.input)
    | Output Left ->
        respond (Provide left.output)
    | Proof Left ->
        respond (Provide left.proof)
    | Input Middle ->
        respond (Provide middle.input)
    | Output Middle ->
        respond (Provide middle.output)
    | Proof Middle ->
        respond (Provide middle.proof)
    | Input Right ->
        respond (Provide right.input)
    | Output Right ->
        respond (Provide right.output)
    | Proof Right ->
        respond (Provide right.proof)
    | _ ->
        respond Unhandled

  let _tag, _, p, Pickles.Provers.[ step ] =
    Pickles.Common.time "compile-trib-return" (fun () ->
        Pickles.compile_promise ()
          ~public_input:(Input_and_output (Field.typ, Field.typ))
            (* Need confirm *)
          ~override_wrap_domain:Pickles_base.Proofs_verified.N2
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Nat.N3)
          ~name:"trib-return"
          ~choices:(fun ~self ->
            [ { identifier = "main"
              ; feature_flags = Plonk_types.Features.none_bool
              ; prevs = [ self; self ]
              ; main =
                  (fun { public_input = n } ->
                    let prev_input direction =
                      exists Field.typ ~request:(const @@ Input direction)
                    in
                    let prev_output direction =
                      exists Field.typ ~request:(const @@ Output direction)
                    in
                    let prev_input_output direction =
                      (prev_input direction, prev_output direction)
                    in
                    let prev_proof direction =
                      exists (Typ.prover_value ())
                        ~request:(const @@ Proof direction)
                    in
                    let is_zero_case =
                      Boolean.any [ Field.(equal n zero); Field.(equal n one) ]
                    in
                    let is_one_case = Field.(equal n (of_int 2)) in
                    let is_recursive_case =
                      let n_minus_one = prev_input Left in
                      let n_minus_two = prev_input Middle in
                      let n_minus_three = prev_input Right in
                      Boolean.all
                        [ Field.(equal n_minus_one (sub n one))
                        ; Field.(equal n_minus_two (sub n (of_int 2)))
                        ; Field.(equal n_minus_three (sub n (of_int 3)))
                        ]
                    in
                    (* ensure precondition holds *)
                    Boolean.Assert.exactly_one
                      [ is_zero_case; is_one_case; is_recursive_case ] ;
                    let recursive_value =
                      [ Left; Middle; Right ] |> List.map ~f:prev_input
                      |> Field.sum
                    in
                    let trib_value =
                      Field.(
                        if_ is_zero_case ~then_:zero
                          ~else_:
                            (if_ is_one_case ~then_:one ~else_:recursive_value))
                    in
                    Promise.return
                      { Pickles.Inductive_rule.previous_proof_statements =
                          [ { public_input = prev_input_output Left
                            ; proof = prev_proof Left
                            ; proof_must_verify = is_recursive_case
                            }
                          ; { public_input = prev_input_output Middle
                            ; proof = prev_proof Middle
                            ; proof_must_verify = is_recursive_case
                            }
                          ; { public_input = prev_input_output Right
                            ; proof = prev_proof Right
                            ; proof_must_verify = is_recursive_case
                            }
                          ]
                      ; public_output = trib_value
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let trib =
    let memo_ref =
      ref
        (Memo.of_comparable
           (module Int)
           (fun _ -> failwith "reaching inside empty trib memo") )
    in
    let trib = function
      | 0 | 1 ->
          0
      | 2 ->
          1
      | n ->
          !memo_ref (n - 1) + !memo_ref (n - 2)
    in
    memo_ref := Memo.of_comparable (module Int) trib ;
    trib

  let trib_step_data =
    let dummy_proof =
      Pickles.Proof.dummy Nat.N3.n Nat.N3.n Nat.N3.n ~domain_log2:16
    in
    let memo_ref =
      ref
        (Memo.of_comparable
           (module Int)
           (fun _ -> failwith "reaching inside empty trib proof memo") )
    in
    let trib_step_data = function
      | (0 | 1 | 2) as n ->
          let dummy =
            { input = Field.Constant.zero
            ; output = Field.Constant.zero
            ; proof = dummy_proof
            }
          in
          let input = Field.Constant.of_int n in
          let output, _, proof =
            Promise.block_on_async_exn (fun () ->
                step input ~handler:(handler dummy dummy dummy) )
          in
          { input; output; proof }
      | n ->
          let input = Field.Constant.of_int n in
          let output, _, proof =
            Promise.block_on_async_exn (fun () ->
                let step_left = !memo_ref (n - 1) in
                let step_middle = !memo_ref (n - 2) in
                let step_right = !memo_ref (n - 3) in
                step input ~handler:(handler step_left step_middle step_right) )
          in
          { input; output; proof }
    in
    memo_ref := Memo.of_comparable (module Int) trib_step_data ;
    trib_step_data

  let trib5_data =
    let data = trib_step_data 5 in
    assert (Field.Constant.(equal data.output (of_int (trib 5)))) ;
    data
end

let test_trib5 () =
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Trib_return.Proof.verify_promise
           [ Trib_return.
               ((trib5_data.input, trib5_data.output), trib5_data.proof)
           ] ) )

let () =
  let open Alcotest in
  run "Test branching factor three"
    [ ("trib", [ ("trib5", `Quick, test_trib5) ]) ]
