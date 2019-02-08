open Core
open Async

(** Visualizable_ledger shows a subgraph of a merkle_ledger using Graphviz *)
module type S = sig
  type addr

  type ledger

  type t

  (* Visualize will enumerate through all edges of a subtree with a
     initial_address. It will then interpret all of the edges and nodes into an
     intermediate form that will be easy to write into a dot file *)
  val visualize : ledger -> initial_address:addr -> t

  (* Write will transform the intermediate form generate by visualize and save
     the results into a dot file *)
  val write : path:string -> name:string -> t -> unit Deferred.t
end

module type Inputs_intf = sig
  module Key : Merkle_ledger.Intf.Key

  module Balance : Merkle_ledger.Intf.Balance

  module Account : sig
    include Merkle_ledger.Intf.Account with type key := Key.t

    val balance : t -> Balance.t
  end

  module Hash : Merkle_ledger.Intf.Hash with type account := Account.t

  module Location : Merkle_ledger.Location_intf.S

  module Ledger :
    Merkle_ledger.Base_ledger_intf.S
    with module Addr = Location.Addr
     and module Location = Location
     and type key := Key.t
     and type key_set := Key.Set.t
     and type hash := Hash.t
     and type root_hash := Hash.t
     and type account := Account.t
end

module Make (Inputs : Inputs_intf) =
(* : S with type addr := Inputs.Location.Addr.t and type ledger := Inputs.Ledger.t *)
struct
  open Inputs

  module Account = struct
    include Account
    include Comparator.Make (Account)
  end

  (* type edge = Inner of (Hash.t * Hash.t) | Leaf of (Hash.t * Account.t option) *)

  type ('source, 'target) edge = {source: 'source; target: 'target}

  type merkle_tree_edge =
    | Inner of (Hash.t, Hash.t) edge
    | Leaf of (Hash.t, Account.t option) edge

  type pretty_format_account = {public_key: string; balance: int}

  type node = Account of pretty_format_account | Empty_hash of string

  type t = {edges: (string, string) edge list; nodes: node list}

  let display_prefix_of_string string = String.prefix string 8

  let string_of_hash hash =
    hash |> Hash.sexp_of_t |> Sexp.to_string |> display_prefix_of_string

  module Addr = Location.Addr

  let string_of_account_key account =
    account |> Account.public_key |> Key.to_string |> display_prefix_of_string

  let empty_hashes =
    Empty_hashes.cache (module Hash) ~init_hash:Hash.empty_account Ledger.depth
    |> Immutable_array.to_list

  let visualize t ~(initial_address : Ledger.Addr.t) =
    let rec bfs ~edges ~accounts ~seen_empty_hashes jobs =
      match Queue.dequeue jobs with
      | None -> (List.rev edges, accounts)
      | Some address ->
          let parent_address = Addr.parent_exn address in
          let parent_hash =
            Ledger.get_inner_hash_at_addr_exn t parent_address
          in
          if Addr.is_leaf address then
            let account = Ledger.get t (Location.Account address) in
            let new_accounts =
              Option.value_map account ~default:accounts ~f:(fun new_account ->
                  assert (not @@ Set.mem accounts new_account) ;
                  Set.add accounts new_account )
            in
            bfs
              ~edges:(Leaf {source= parent_hash; target= account} :: edges)
              ~seen_empty_hashes ~accounts:new_accounts jobs
          else
            let current_hash = Ledger.get_inner_hash_at_addr_exn t address in
            if
              not
              @@ Hash_set.mem
                   (empty_hashes |> Hash.Hash_set.of_list)
                   current_hash
            then (
              Queue.enqueue jobs (Addr.child_exn address Direction.Left) ;
              Queue.enqueue jobs (Addr.child_exn address Direction.Right) )
            else Hash_set.add seen_empty_hashes current_hash ;
            bfs
              ~edges:
                (Inner {source= parent_hash; target= current_hash} :: edges)
              ~accounts ~seen_empty_hashes jobs
    in
    let seen_empty_hashes = Hash.Hash_set.of_list [] in
    let edges, accounts =
      bfs ~edges:[]
        ~accounts:(Set.empty (module Account))
        ~seen_empty_hashes
        (Queue.of_list
           [ Addr.child_exn initial_address Direction.Left
           ; Addr.child_exn initial_address Direction.Right ])
    in
    let string_edges =
      List.map edges ~f:(function
        | Inner {source; target} ->
            {source= string_of_hash source; target= string_of_hash target}
        | Leaf {source= source_hash; target= account_option} ->
            let open Option.Let_syntax in
            let account_string =
              (let%map account = account_option in
               string_of_account_key account)
              |> Option.value ~default:"EMPTY_ACCOUNT"
            in
            {source= string_of_hash source_hash; target= account_string} )
    in
    let nodes =
      List.map (Set.to_list accounts) ~f:(fun account ->
          let string_key = string_of_account_key account in
          Account
            { public_key= string_key
            ; balance= Account.balance account |> Balance.to_int } )
      @ List.map (seen_empty_hashes |> Hash_set.to_list) ~f:(fun hash ->
            Empty_hash (string_of_hash hash) )
    in
    {edges= string_edges; nodes}

  module Dot_writer = struct
    let wrapper ~name body = sprintf "digraph %s { \n %s\n}" name body

    let write ~path ~name {edges; nodes} =
      let body =
        List.map edges ~f:(fun {source; target} ->
            sprintf "\"%s\" -> \"%s\" " source target )
        @ List.map nodes ~f:(function
            | Account {public_key; balance} ->
                sprintf "\"%s\" [shape=record,label=\"{%s|%d}\"]" public_key
                  public_key balance
            | Empty_hash hash -> sprintf "\"%s\" [shape=point]" hash )
        |> String.concat ~sep:"\n"
      in
      let code = wrapper ~name body in
      Writer.save path ~contents:code
  end

  let write = Dot_writer.write
end
