let tests = Test_pcs_batch.tests @ Test_vector.tests

let () = Alcotest.run "Pickles types" tests
