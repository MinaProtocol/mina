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
  Format.printf "expected:\n%s\n\n" expected ;
  Format.printf "obtained:\n%s\n" obtained ;
  assert (String.(trim obtained = trim expected))

let check_asm ~input_typ ~return_typ ~circuit filename () =
  let cs : Impl.R1CS_constraint_system.t =
    Impl.constraint_system ~input_typ ~return_typ circuit
  in
  let asm =
    Kimchi_backend.Pasta.Vesta_based_plonk.R1CS_constraint_system.get_asm cs
  in
  compare_with asm filename

(* monadic API tests *)

(** Both the monadic and imperative API will produce the same circuit hash. *)
let expected = "5357346d161dcccaa547c7999b8148db"

module MonadicAPI = struct
  module Impl = Snarky_backendless.Snark.Make (struct
    include Kimchi_backend.Pasta.Vesta_based_plonk
    module Inner_curve = Kimchi_backend.Pasta.Pasta.Pallas
  end)

  let main ((b1, b2) : Impl.Boolean.var * Impl.Boolean.var) =
    let open Impl in
    let%bind x = exists Boolean.typ ~compute:(As_prover.return true) in
    let%bind y = exists Boolean.typ ~compute:(As_prover.return true) in
    let%bind z = Boolean.(x &&& y) in
    let%bind b3 = Boolean.(b1 && b2) in

    let%bind () = Boolean.Assert.is_true z in
    let%bind () = Boolean.Assert.is_true b3 in

    Checked.return ()

  let get_hash_of_circuit () =
    let input_typ = Impl.Typ.tuple2 Impl.Boolean.typ Impl.Boolean.typ in
    let return_typ = Impl.Typ.unit in
    let cs : Impl.R1CS_constraint_system.t =
      Impl.constraint_system ~input_typ ~return_typ main
    in
    let digest = Md5.to_hex (Impl.R1CS_constraint_system.digest cs) in
    Format.printf "expected:\n%s\n\n" expected ;
    Format.printf "obtained:\n%s\n" digest ;
    assert (String.(digest = expected))
end

(* circuit-focused tests *)

module BooleanCircuit = struct
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

  let input_typ = Impl.Typ.tuple2 Impl.Boolean.typ Impl.Boolean.typ

  let return_typ = Impl.Typ.unit

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
end

module FieldCircuit = struct
  let input_typ = Impl.Field.typ

  let return_typ = Impl.Typ.unit

  let main (x : Impl.Field.t) () =
    let y = Impl.Field.one in
    let res = Impl.Field.(x + y) in
    let two = Impl.Field.of_int 2 in

    Impl.Field.Assert.equal res two ;
    Impl.Field.Assert.not_equal res Impl.Field.one ;
    Impl.Field.Assert.non_zero res
end

module RangeCircuits = struct
  let input_typ = Impl.Field.typ

  let return_typ = Impl.Typ.unit

  let lte (x : Impl.Field.t) () =
    Impl.Field.Assert.lte ~bit_length:2 x (Impl.Field.of_int 3) ;
    ()

  let gte (x : Impl.Field.t) () =
    Impl.Field.Assert.gte ~bit_length:2 x (Impl.Field.of_int 3) ;
    ()

  let gt (x : Impl.Field.t) () =
    Impl.Field.Assert.gt ~bit_length:2 x (Impl.Field.of_int 3) ;
    ()

  let lt (x : Impl.Field.t) () =
    Impl.Field.Assert.lt ~bit_length:2 x (Impl.Field.of_int 3) ;
    ()
end

module TernaryCircuit = struct
  let input_typ = Impl.Boolean.typ

  let return_typ = Impl.Typ.unit

  let main (x : Impl.Boolean.var) () =
    let two = Impl.Field.of_int 2 in
    let res = Impl.if_ x ~typ:Impl.Field.typ ~then_:two ~else_:Impl.Field.one in
    Impl.Field.Assert.equal res two
end

module PublicOutput = struct
  let input_typ = Impl.Boolean.typ

  let return_typ = Impl.Boolean.typ

  let main (x : Impl.Boolean.var) () : Impl.Boolean.var =
    Impl.Boolean.(x && Impl.Boolean.true_)
end

let circuit_tests =
  [ ( "boolean circuit"
    , `Quick
    , check_asm ~input_typ:BooleanCircuit.input_typ
        ~return_typ:BooleanCircuit.return_typ ~circuit:BooleanCircuit.main
        "simple.asm" )
  ; ( "circuit with field arithmetic"
    , `Quick
    , check_asm ~input_typ:FieldCircuit.input_typ
        ~return_typ:FieldCircuit.return_typ ~circuit:FieldCircuit.main
        "field.asm" )
  ; ( "circuit with range check (less than equal)"
    , `Quick
    , check_asm ~input_typ:RangeCircuits.input_typ
        ~return_typ:RangeCircuits.return_typ ~circuit:RangeCircuits.lte
        "range_lte.asm" )
  ; ( "circuit with range check (greater than equal)"
    , `Quick
    , check_asm ~input_typ:RangeCircuits.input_typ
        ~return_typ:RangeCircuits.return_typ ~circuit:RangeCircuits.gte
        "range_gte.asm" )
  ; ( "circuit with range check (less than)"
    , `Quick
    , check_asm ~input_typ:RangeCircuits.input_typ
        ~return_typ:RangeCircuits.return_typ ~circuit:RangeCircuits.lt
        "range_lt.asm" )
  ; ( "circuit with range check (greater than)"
    , `Quick
    , check_asm ~input_typ:RangeCircuits.input_typ
        ~return_typ:RangeCircuits.return_typ ~circuit:RangeCircuits.gt
        "range_gt.asm" )
  ; ( "circuit with ternary operator"
    , `Quick
    , check_asm ~input_typ:TernaryCircuit.input_typ
        ~return_typ:TernaryCircuit.return_typ ~circuit:TernaryCircuit.main
        "ternary.asm" )
  ; ( "circuit with public output"
    , `Quick
    , check_asm ~input_typ:PublicOutput.input_typ
        ~return_typ:PublicOutput.return_typ ~circuit:PublicOutput.main
        "output.asm" )
  ]

(* API tests *)

let get_hash_of_circuit () =
  let input_typ = Impl.Typ.tuple2 Impl.Boolean.typ Impl.Boolean.typ in
  let return_typ = Impl.Typ.unit in
  let cs : Impl.R1CS_constraint_system.t =
    Impl.constraint_system ~input_typ ~return_typ BooleanCircuit.main
  in
  let digest = Md5.to_hex (Impl.R1CS_constraint_system.digest cs) in
  Format.printf "expected:\n%s\n\n" expected ;
  Format.printf "obtained:\n%s\n" digest ;
  assert (String.(digest = expected))

let generate_witness () =
  let thing input _ = BooleanCircuit.main input () in
  let main_handled input () =
    Impl.handle (thing input) BooleanCircuit.Request.handler
  in

  let input_typ = Impl.Typ.tuple2 Impl.Boolean.typ Impl.Boolean.typ in
  let return_typ = Impl.Typ.unit in
  let f (inputs : Impl.Proof_inputs.t) _ = inputs in
  let compiled =
    Impl.generate_witness_conv ~f ~input_typ ~return_typ main_handled
  in

  let _b = compiled (true, true) in

  ()

let api_tests =
  [ ("generate witness", `Quick, generate_witness)
  ; ("compile imperative API", `Quick, get_hash_of_circuit)
  ; ("compile monadic API", `Quick, MonadicAPI.get_hash_of_circuit)
  ]

(* run tests *)

let () =
  Alcotest.run "BooleanCircuit snarky tests"
    [ ("API tests", api_tests); ("circuit tests", circuit_tests) ]
