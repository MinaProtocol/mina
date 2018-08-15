open Core

module Test (Input : sig
  val depth : int
end) =
struct
  module Index = struct
    include Index_address.Make (Input)

    let%test_unit "dirs_from_root" =
      let dir_list = Direction.gen_list Input.depth in
      Quickcheck.test dir_list ~f:(fun dirs ->
          assert (
            dirs_from_root (List.fold dirs ~f:child_exn ~init:root) = dirs ) )

    let%test_unit "to_index (of_index i) = i" =
      Quickcheck.test ~sexp_of:[%sexp_of : int]
        (Int.gen_incl 0 (Input.depth - 1))
        ~f:(fun i -> [%test_eq : int] (to_index (of_index i)) i)
  end

  module Bit = struct
    include Merkle_db_address_adapter.Make (Input)

    let%test "the merkle root should have no path" = dirs_from_root root = []

    let%test_unit "behaves like Index_address" =
      let module Merkle_address = Index_address.Make (Input) in
      Quickcheck.test ~sexp_of:[%sexp_of : [`Left | `Right] List.t]
        (Direction.gen_list Input.depth) ~f:(fun dirs ->
          assert (
            let db_result = dirs_from_root (of_direction dirs)
            and ledger_result =
              Merkle_address.dirs_from_root
                (List.fold dirs ~f:Merkle_address.child_exn
                   ~init:Merkle_address.root)
            in
            db_result = ledger_result ) )
  end
end

let%test_module "Address" =
  ( module struct
    module T4 = Test (struct
      let depth = 4
    end)

    module T16 = Test (struct
      let depth = 16
    end)
  end )
