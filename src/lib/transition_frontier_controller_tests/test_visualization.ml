open Core
open Async

module Stubs = Stubs.Make (struct
  let max_length = 4
end)

open Stubs

let%test_module "Bootstrap Controller" =
  ( module struct
    let%test_unit "visualize a pretty graph" =
      let num_breadcrumbs = 2 * Transition_frontier.max_length in
      let logger = Logger.create () in
      Thread_safe.block_on_async_exn (fun () ->
          let accounts_with_secret_keys = Genesis_ledger.accounts in
          let%bind frontier =
            create_root_frontier ~logger accounts_with_secret_keys
          in
          let%map () =
            build_frontier_randomly frontier
              ~gen_root_breadcrumb_builder:(fun root_breadcrumb ->
                Quickcheck.Generator.with_size ~size:num_breadcrumbs
                @@ Quickcheck_lib.gen_imperative_ktree
                     (root_breadcrumb |> return |> Quickcheck.Generator.return)
                     (gen_breadcrumb ~logger ~accounts_with_secret_keys) )
          in
          Transition_frontier.visualize frontier
            ~filename:"frontier_output.dot" )
  end )
