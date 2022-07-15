open Tuple_lib
module SC = Scalar_challenge
open Core_kernel
open Async_kernel
open Pickles_types
open Poly_types
open Hlist
open Backend
module Backend = Backend

let%test_module "can we wordle" =
  ( module struct
    let () = Tock.Keypair.set_urs_info []

    let () = Tick.Keypair.set_urs_info []


    open Pickles.Impls.Step

    let () = Snarky_backendless.Snark0.set_eval_constraints true

    module Why = struct
      module Statement = struct

      type _ Snarky_backendless.Request.t +=
        | Soln : Field.Constant.t array Snarky_backendless.Request.t
        | Guess : Field.Constant.t array Snarky_backendless.Request.t
        | In_place : bool array Snarky_backendless.Request.t

      let handler (soln : Field.Constant.t array) (guess : Field.Constant.t array) (in_place : bool array)
          (Snarky_backendless.Request.With { request; respond }) =
        match request with
        | Soln ->
            respond (Provide soln)
        | Guess ->
            respond (Provide guess)
        | In_place ->
            respond (Provide in_place)

      module Statement = struct
        type t = Field.t Boolean.var array * Field.t Boolean.var array

        let to_field_elements (x, y) =
          let map = Array.map ~f:(fun (x : 'a Snarky_backendless.Boolean.t) -> (x :> 'a)) in
          Array.append (map x) (map y)

          module Constant = struct
            type t = bool array

            let to_field_elements (x, y) =
              let map = Array.map ~f:(fun x -> if x then Field.Constant.zero else Field.Constant.one) in
              Array.append (map x) (map y)
          end
      end

      let tag, _, p, [ step ] =
            Pickles.compile
              (module Statement)
              (module Statement.Constant)
              ~public_input:(Output Typ.(array ~length:5 Field.typ * array ~length:5 Field.typ)) ~auxiliary_typ:Typ.unit
              ~branches:(module Nat.N1)
              ~max_proofs_verified:(module Nat.N0)
              ~name:"blockchain-snark"
              ~constraint_constants:
                (* Dummy values *)
                { sub_windows_per_window = 0
                ; ledger_depth = 0
                ; work_delay = 0
                ; block_window_duration_ms = 0
                ; transaction_capacity = Log_2 0
                ; pending_coinbase_depth = 0
                ; coinbase_amount = Unsigned.UInt64.of_int 0
                ; supercharged_coinbase_factor = 0
                ; account_creation_fee = Unsigned.UInt64.of_int 0
                ; fork = None
                }
              ~choices:(fun ~self ->
                [ { identifier = "main"
                  ; prevs = [ ]
                  ; main =
                      (fun { public_input = () } ->
                        let guess =
                          exists Field.typ ~request:(fun () -> Guess)
                        in
                        let soln =
                          exists Field.typ ~request:(fun () -> Soln)
                        in
                        let in_place =
                          exists Boolean.typ ~request:(fun () -> In_place)
                        in
                        let res = Array.iter2 guess ordered_soln ~f:(fun guess soln ->
                          Field.equal guess soln
                        ) in
                        let res_out_of_order = Array.iter2 res in_place ~f:(fun res in_place ->
                          Boolean.(res && in_place)
                          )
                        in
                        let res_in_order = Array.iter2 res in_place ~f:(fun res in_place ->
                          Boolean.(res && not in_place)
                          )
                        in
                        { previous_proof_statements = []
                        ; public_output = (res_out_of_order, res_in_order)
                        ; auxiliary_output = () } )
                  }
                ] )
    
   end
   end
  end )

