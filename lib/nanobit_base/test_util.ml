open Core
open Snark_params

let test_equal ?(equal=(=)) typ1 typ2 checked unchecked input =
  let open Tick in
  let ((), checked_result, passed) =
    Tick.run_and_check begin
      let open Let_syntax in
      let%bind input = provide_witness typ1 (As_prover.return input) in
      let%map result = checked input in
      As_prover.read typ2 result
    end ()
  in
  assert passed;
  let unchecked_result = unchecked input in
  assert (equal checked_result unchecked_result)
;;
