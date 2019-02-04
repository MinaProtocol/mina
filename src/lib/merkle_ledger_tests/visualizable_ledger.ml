open Core
open Async

(** Visualizable_ledger shows a subgraph of a merkle_ledger using Graphviz *)
module type S = sig
  type addr

  type tree

  type t

  (* Visualize will enumerate through all edges of a subtree with a root
     initial_address. It will then interpret all of the edges and nodes into an
     intermediate form that will be easy to write into a dot file *)
  val visualize : tree -> initial_address:addr -> t

  (* Write will transform the intermediate form generate by visualze and save
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
    with type key := Key.t
     and type key_set := Key.Set.t
     and type hash := Hash.t
     and type root_hash := Hash.t
     and type account := Account.t
end

module Make (Inputs : Inputs_intf) :
  S with type addr := Inputs.Location.Addr.t and type tree := Inputs.Ledger.t =
struct
  open Inputs

  module Account = struct
    include Account
    include Comparator.Make (Account)
  end

  type edge = Inner of (Hash.t * Hash.t) | Leaf of (Hash.t * Account.t option)

  type t = (string * string) list * (string * int) list

  let shorten_string string = String.prefix string 8

  let string_of_hash hash =
    hash |> Hash.sexp_of_t |> Sexp.to_string |> shorten_string

  module Addr = Location.Addr

  let string_of_account_key account =
    account |> Account.public_key |> Key.to_string |> shorten_string

  let visualize t ~(initial_address : Ledger.Addr.t) =
    let rec bfs ~edges ~accounts jobs =
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
              ~edges:(Leaf (parent_hash, account) :: edges)
              ~accounts:new_accounts jobs
          else
            let current_hash = Ledger.get_inner_hash_at_addr_exn t address in
            Queue.enqueue jobs (Addr.child_exn address Direction.Left) ;
            Queue.enqueue jobs (Addr.child_exn address Direction.Right) ;
            bfs
              ~edges:(Inner (parent_hash, current_hash) :: edges)
              ~accounts jobs
    in
    let edges, accounts =
      bfs ~edges:[]
        ~accounts:(Set.empty (module Account))
        (Queue.of_list
           [ Addr.child_exn initial_address Direction.Left
           ; Addr.child_exn initial_address Direction.Right ])
    in
    let string_edges =
      List.map edges ~f:(function
        | Inner (source_hash, inner_hash) ->
            (string_of_hash source_hash, string_of_hash inner_hash)
        | Leaf (source_hash, account_option) ->
            let open Option.Let_syntax in
            let account_string =
              (let%map account = account_option in
               string_of_account_key account)
              |> Option.value ~default:"EMPTY_ACCOUNT"
            in
            (string_of_hash source_hash, account_string) )
    in
    let account_nodes =
      List.map (Set.to_list accounts) ~f:(fun account ->
          let string_key = string_of_account_key account in
          (string_key, Account.balance account |> Balance.to_int) )
    in
    (string_edges, account_nodes)

  module Dot_writer = struct
    let wrapper ~name body = sprintf "digraph %s { \n %s\n}" name body

    let write ~path ~name (edges, accounts) =
      let body =
        List.map edges ~f:(fun (source, edge) ->
            sprintf "\"%s\" -> \"%s\" " source edge )
        @ List.map accounts ~f:(fun (public_key, balance) ->
              sprintf "\"%s\" [shape=record,label=\"{%s|%d}\"]" public_key
                public_key balance )
        |> String.concat ~sep:"\n"
      in
      let code = wrapper ~name body in
      Writer.save path ~contents:code
  end

  let write = Dot_writer.write
end
