(* Testing
   -------

   Component: Pickles / Unix
   Subject: Test Graphql scalars
   Invocation: dune exec src/lib/pickles/unix/test/test_graphql_scalars.exe
*)

include Graphql_scalars.For_tests_only
module Make_test = Graphql_basic_scalars.Testing.Produce_test

module VerificationKey_gen = struct
  include Pickles.Side_loaded.Verification_key

  let gen = Core_kernel.Quickcheck.Generator.return dummy
end

module Vk = Make_test (VerificationKey) (VerificationKey_gen)

let test_vk () = Vk.test_query ()

module VerificationKeyHash_gen = struct
  include Pickles.Backend.Tick.Field

  let gen =
    Core_kernel.Int.quickcheck_generator
    |> Core_kernel.Quickcheck.Generator.map ~f:Pasta_bindings.Fp.of_int
end

module Vk_hash = Make_test (VerificationKeyHash) (VerificationKeyHash_gen)

let test_vk_hash () = Vk_hash.test_query ()

let () =
  let open Alcotest in
  run "Pickles unix"
    [ ( "Graphql scalars"
      , [ test_case "verification key query" `Quick test_vk
        ; test_case "verification key hash query" `Quick test_vk_hash
        ] )
    ]
