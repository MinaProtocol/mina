open Core
open Test_stubs

module Depth = struct
  let depth = 4
end

module DB = Database.Make (Balance) (Account) (Hash) (Depth) (In_memory_kvdb) (In_memory_sdb)
module L = Ledger.Make (Key) (Account) (Hash) (Depth)
module Binary_tree = Binary_tree.Make(Account)(Hash)(Depth)

module type Ledger_intf = sig
  type t

  val max_depth : int

  val get_inner_hash_at_addr_exn : t -> Direction.t list -> Hash.t
end

module Visualizable_ledger(L: Ledger_intf) = struct
  type t = L.t

  type tree = Leaf of (Direction.t list * Hash.t) | Node of (Direction.t list * Hash.t * tree * tree) [@@deriving sexp, eq]

  let to_tree t =    
    let rec go i dirs =
      if i = L.max_depth then Leaf (dirs, L.get_inner_hash_at_addr_exn t dirs)  else
        let hash = L.get_inner_hash_at_addr_exn t dirs in
        let left = go (i + 1) (dirs @ [Direction.Left]) in
        let right = go (i + 1) (dirs @ [Direction.Right]) in
        Node (dirs, hash, left, right)
    in
    go 0 []
end

module VDB = Visualizable_ledger(struct
  include DB
  
  let max_depth = Depth.depth

  let get_inner_hash_at_addr_exn db dirs = 
    get_inner_hash_at_addr_exn db (Addr.of_directions dirs)
end)

module VL = Visualizable_ledger(struct
  include L

  let max_depth = Depth.depth


  let get_inner_hash_at_addr_exn db dirs =
    let addr = Addr.of_directions dirs in
    if (List.length dirs = Depth.depth) then
      let index = to_index addr in
      get_leaf_hash db index
    else
    get_inner_hash_at_addr_exn db addr
end)

module Visualizable_binary_tree = Visualizable_ledger(Binary_tree)

(* let%test_unit "equivalent empty Hashes" =
  [%test_result : Hash.t array] L.empty_hash_array ~expect:DB.empty_hash_array *)

let%test_unit "databases have equivalent hash values" =
  let open Quickcheck.Generator in
  let gen_accounts = 
    let open Quickcheck.Let_syntax in
    let num_accounts =  (1 lsl Depth.depth) - 1 in
    let%map accounts = list_with_length num_accounts Account.gen in
    List.filter accounts ~f:(fun account -> Account.balance account <> Balance.zero)
  in

  printf !"Empty Hashes of Database: %{sexp:Hash.t array}\n" DB.empty_hash_array;

  let bad_example = (List.t_of_sexp Account.t_of_sexp) @@ Sexp.of_string "((0 1659469926793563215) (1 1421) (2 329277924) (3 65192403756884) (4 7995526446) (GV5 157924982187) (I6 13404882) (7 72) (8 592948123) (j9 445) (10 250001683) (t11 39237140913) (12 2) (13 22446807160894086))" in

  Quickcheck.test ~examples:[bad_example] ~sexp_of:([%sexp_of: Account.t list]) (gen_accounts) ~f:(fun accounts -> 
    
    let accounts = List.mapi accounts ~f:(fun i {public_key; balance} -> 
      Account.create (sprintf !"%s%d" public_key i) (Balance.to_int balance)
      ) in
    (* Core.printf "\n\n\------------------------Running comparison-----------------\n\n"; *)

    let db = DB.create ~key_value_db_dir:""  ~stack_db_file:"" in
    let l = L.create () in


    let enumerate_dir_combinations i = 
      Sequence.range 0 (i - 1) |>
      Sequence.fold ~init:[[]] ~f:(fun acc _ -> 
          acc @
          (List.map acc ~f:(List.cons Direction.Left ) ) @ 
          (List.map acc ~f:(List.cons Direction.Right ) )
        )
    in
    
    
    List.iteri accounts ~f:(fun i account -> 
      assert (DB.set_account db account = Ok ());
      L.set l (Int.to_string i) account
    );

    let binary_tree = Binary_tree.set_accounts accounts in

    L.recompute_tree l;

    Core.printf "\n\n\------------------------Running comparison-----------------\n\n";
    
    Core.printf !"Accounts: %{sexp:Account.t list}\n" accounts;

    printf !"Binary tree %{sexp:Visualizable_binary_tree.tree}\n\n" (Visualizable_binary_tree.to_tree binary_tree);
    
    printf !"Visualizing Database: %{sexp:VDB.tree}\n\n" (VDB.to_tree db);

    Core.printf !"Ledger: %{sexp:L.t}\n" l;

    printf !"Visualizing Ledger: %{sexp:VL.tree}\n\n" (VL.to_tree l);

    (* TODO: test the least common ancestor *)
    (Sequence.iter (enumerate_dir_combinations Depth.depth |> Sequence.of_list) ~f:(fun dirs -> 
      let mt_hash = DB.get_inner_hash_at_addr_exn db (DB.Addr.of_directions dirs) in
      let l_hash = L.get_inner_hash_at_addr_exn l (L.Addr.of_directions dirs) in
      [%test_result : Hash.t] ~expect:mt_hash l_hash
        ~message:(sprintf !"Difference occurs at %{sexp:Direction.t list}\n" dirs )
    ))

  )