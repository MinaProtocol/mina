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
  module Key : Intf.Key

  module Token_id : Intf.Token_id

  module Account_id :
    Intf.Account_id with type key := Key.t and type token_id := Token_id.t

  module Balance : Intf.Balance

  module Account :
    Intf.Account
      with type account_id := Account_id.t
       and type balance := Balance.t

  module Hash : Intf.Hash with type account := Account.t

  module Location : Location_intf.S

  module Ledger :
    Base_ledger_intf.S
      with module Addr = Location.Addr
       and module Location = Location
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t
       and type hash := Hash.t
       and type root_hash := Hash.t
       and type account := Account.t
end

module Make (Inputs : Inputs_intf) :
  S with type addr := Inputs.Location.Addr.t and type ledger := Inputs.Ledger.t =
struct
  open Inputs

  module Account = struct
    include Account
    include Comparator.Make (Account)
  end

  type ('source, 'target) edge = { source : 'source; target : 'target }

  type target =
    | Hash of Hash.t
    | Empty_hash
    | Account of Account.t
    | Empty_account

  type merkle_tree_edge = (Hash.t, target) edge

  type pretty_format_account = { public_key : string; balance : int }

  type pretty_target =
    | Pretty_hash of string
    | Pretty_account of pretty_format_account
    | Pretty_empty_hash of int
    | Pretty_empty_account of int

  type t = (string, pretty_target) edge list

  let string_of_hash = Visualization.display_short_sexp (module Hash)

  module Addr = Location.Addr

  let string_of_account_id account =
    account |> Account.identifier
    |> Visualization.display_short_sexp (module Account_id)

  let empty_hash =
    Empty_hashes.extensible_cache (module Hash) ~init_hash:Hash.empty_account

  let visualize t ~(initial_address : Ledger.Addr.t) =
    let ledger_depth = Inputs.Ledger.depth t in
    let rec bfs ~(edges : merkle_tree_edge list) ~accounts jobs =
      match Queue.dequeue jobs with
      | None ->
          List.rev edges
      | Some address ->
          let parent_address = Addr.parent_exn address in
          let parent_hash =
            Ledger.get_inner_hash_at_addr_exn t parent_address
          in
          if Addr.is_leaf ~ledger_depth address then
            match Ledger.get t (Location.Account address) with
            | Some new_account ->
                (* let public_key = Account.public_key new_account in
                   let location = Ledger.location_of_account t public_key |> Option.value_exn in
                   let queried_account = Ledger.get t location |> Option.value_exn in
                   assert (Account.equal queried_account new_account); *)
                assert (not @@ Set.mem accounts new_account) ;
                let new_accounts = Set.add accounts new_account in
                bfs
                  ~edges:
                    ( { source = parent_hash; target = Account new_account }
                    :: edges )
                  ~accounts:new_accounts jobs
            | None ->
                bfs
                  ~edges:
                    ({ source = parent_hash; target = Empty_account } :: edges)
                  ~accounts jobs
          else
            let current_hash = Ledger.get_inner_hash_at_addr_exn t address in
            let target : target =
              if
                not
                @@ Hash_set.mem
                     ( List.init ~f:empty_hash ledger_depth
                     |> Hash.Hash_set.of_list )
                     current_hash
              then (
                Queue.enqueue jobs
                  (Addr.child_exn ~ledger_depth address Direction.Left) ;
                Queue.enqueue jobs
                  (Addr.child_exn ~ledger_depth address Direction.Right) ;
                Hash current_hash )
              else Empty_hash
            in
            bfs
              ~edges:({ source = parent_hash; target } :: edges)
              ~accounts jobs
    in
    let edges =
      bfs ~edges:[]
        ~accounts:(Set.empty (module Account))
        (Queue.of_list
           [ Addr.child_exn ~ledger_depth initial_address Direction.Left
           ; Addr.child_exn ~ledger_depth initial_address Direction.Right
           ] )
    in
    let edges =
      List.folding_map edges ~init:(0, 0)
        ~f:(fun (empty_account_counter, empty_hash_counter) { source; target }
           ->
          let source = string_of_hash source in
          match target with
          | Hash target_hash ->
              ( (empty_account_counter, empty_hash_counter)
              , { source; target = Pretty_hash (string_of_hash target_hash) } )
          | Account account ->
              let string_key = string_of_account_id account in
              let pretty_account =
                { public_key = string_key
                ; balance = Account.balance account |> Balance.to_int
                }
              in
              ( (empty_account_counter, empty_hash_counter)
              , { source; target = Pretty_account pretty_account } )
          | Empty_hash ->
              let new_empty_hash_counter = empty_hash_counter + 1 in
              ( (empty_account_counter, new_empty_hash_counter)
              , { source; target = Pretty_empty_hash new_empty_hash_counter } )
          | Empty_account ->
              let new_empty_account_counter = empty_account_counter + 1 in
              ( (new_empty_account_counter, empty_hash_counter)
              , { source
                ; target = Pretty_empty_account new_empty_account_counter
                } ) )
    in
    edges

  module Dot_writer = struct
    let wrapper ~name body = sprintf "digraph %s { \n %s\n}" name body

    let write_empty_entry ~id source count =
      let empty_hash_id = sprintf "EMPTY_%s_%d" id count in
      [ sprintf "\"%s\" -> \"%s\" " source empty_hash_id
      ; sprintf "\"%s\" [shape=point]" empty_hash_id
      ]

    let write ~path ~name edges =
      let body =
        List.map edges ~f:(fun { source; target } ->
            match target with
            | Pretty_hash hash ->
                [ sprintf "\"%s\" -> \"%s\" " source hash ]
            | Pretty_account { public_key; balance } ->
                [ sprintf "\"%s\" -> \"%s\" " source public_key
                ; sprintf "\"%s\" [shape=record,label=\"{%s|%d}\"]" public_key
                    public_key balance
                ]
            | Pretty_empty_hash count ->
                write_empty_entry ~id:"HASH" source count
            | Pretty_empty_account count ->
                write_empty_entry ~id:"ACCOUNT" source count )
        |> List.concat |> String.concat ~sep:"\n"
      in
      let code = wrapper ~name body in
      Writer.save path ~contents:code
  end

  let write = Dot_writer.write
end
