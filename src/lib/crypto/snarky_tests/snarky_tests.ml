(* this is ugly, but [Core_kernel.String] doesn't have a [trim] function *)
let trim = String.trim

open Core_kernel

(* instantiate snarky for Vesta *)

module Impl = Snarky_backendless.Snark.Run.Make (struct
  include Kimchi_backend.Pasta.Vesta_based_plonk
  module Inner_curve = Kimchi_backend.Pasta.Pasta.Pallas
end)

(* helpers *)

let compare_with obtained filepath =
  let (_ : int) = Sys.command "tree" in
  let expected = In_channel.read_all ("examples/" ^ filepath) in
  Format.printf "expected: %s\n" expected ;
  Format.printf "obtained: %s\n" obtained ;
  assert (String.(trim obtained = trim expected))

(* circuit "simple.asm" *)

module SimpleCircuit = struct
  module Request = struct
    type _ Snarky_backendless.Request.t +=
      | SimpleBool : bool Snarky_backendless.Request.t

    let handler (Snarky_backendless.Request.With { request; respond }) =
      match request with
      | SimpleBool ->
          respond (Provide true)
      | _ ->
          respond Unhandled
  end

  let main ((b1, b2) : Impl.Boolean.var * Impl.Boolean.var) () =
    let x =
      Impl.exists Impl.Boolean.typ ~request:(fun _ -> Request.SimpleBool)
    in
    let y = Impl.exists Impl.Boolean.typ ~compute:(fun _ -> true) in

    let z = Impl.Boolean.(x && y) in
    let b3 = Impl.Boolean.(b1 && b2) in
    Impl.Boolean.Assert.is_true z ;
    Impl.Boolean.Assert.is_true b3 ;
    ()

  let check_asm () =
    let input_typ = Impl.Typ.tuple2 Impl.Boolean.typ Impl.Boolean.typ in
    let return_typ = Impl.Typ.unit in
    let cs : Impl.R1CS_constraint_system.t =
      Impl.constraint_system ~input_typ ~return_typ main
    in
    let asm =
      Kimchi_backend.Pasta.Vesta_based_plonk.R1CS_constraint_system.get_asm cs
    in
    compare_with asm "simple.asm"
end

(* test API *)

let get_hash_of_circuit () =
  let input_typ = Impl.Typ.tuple2 Impl.Boolean.typ Impl.Boolean.typ in
  let return_typ = Impl.Typ.unit in
  let cs : Impl.R1CS_constraint_system.t =
    Impl.constraint_system ~input_typ ~return_typ SimpleCircuit.main
  in
  let digest = Md5.to_hex (Impl.R1CS_constraint_system.digest cs) in
  let expected = "5357346d161dcccaa547c7999b8148db" in
  Format.printf "expected:\n%s\n\n" expected ;
  Format.printf "obtained:\n%s\n" digest ;
  assert (String.(digest = expected))

let generate_witness () =
  let thing input _ = SimpleCircuit.main input () in
  let main_handled input () =
    Impl.handle (thing input) SimpleCircuit.Request.handler
  in

  let input_typ = Impl.Typ.tuple2 Impl.Boolean.typ Impl.Boolean.typ in
  let return_typ = Impl.Typ.unit in
  let f (inputs : Impl.Proof_inputs.t) _ = inputs in
  let compiled =
    Impl.generate_witness_conv ~f ~input_typ ~return_typ main_handled
  in

  let _b = compiled (true, true) in

  ()

(****************************
 * outside-of-circuit tests *
 ****************************)

let out_of_circuit_constant () =
  let one = Impl.Field.Constant.one in
  let two = Impl.Field.Constant.of_int 2 in
  let x = Impl.Field.constant one in
  let y = Impl.Field.constant two in
  let _const_mul : Impl.Field.t = Impl.Field.mul x y in
  ()

let out_of_circuit_constraint () =
  let one = Impl.Field.constant Impl.Field.Constant.one in
  let two = Impl.Field.constant (Impl.Field.Constant.of_int 2) in
  Impl.Field.Assert.not_equal one two

let out_of_circuit_constraint () =
  Alcotest.(
    check_raises "should fail to create constraints outside of a circuit"
      (Failure "This function can't be run outside of a checked computation."))
    out_of_circuit_constraint

let outside_circuit_tests =
  [ ("out-of-circuit constant", `Quick, out_of_circuit_constant)
  ; ("out-of-circuit constraint (bad)", `Quick, out_of_circuit_constraint)
  ]

(* run tests *)

let api_tests =
  [ ("generate_witness", `Quick, generate_witness)
  ; ("get_hash_of_circuit", `Quick, get_hash_of_circuit)
  ]

let circuit_tests = [ ("simple_circuit", `Quick, SimpleCircuit.check_asm) ]

let () =
  Alcotest.run "Simple snarky tests"
    [ ("outside of circuit tests", outside_circuit_tests)
    ; ("API tests", api_tests)
    ; ("circuit tests", circuit_tests)
    ]
