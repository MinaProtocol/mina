open Core_kernel

(* an extension that's not a test module *)

let%not_a_test_module "bad bin_io only" =
  ( module struct
    type t = string [@@deriving bin_io]
  end )
