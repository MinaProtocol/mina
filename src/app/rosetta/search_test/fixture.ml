(* Helpers for rosetta_search_test.ml: a chain described by names, searches written
   with those names, and results printed back in them ("pay_ab @ b2"), so a
   test reads as the situation it sets up and what a search must return. *)

open Core
open Async
module B = Synthetic_archive

let block_on f = Thread_safe.block_on_async_exn f

(** The chain a test sets up. Every account, block and command is known by
    the name the test gives it. *)
module Chain = struct
  type t =
    { builder : B.t
    ; name_of_key : string String.Table.t
          (** public key, state hash or command hash -> name *)
    ; key_of_name : string String.Table.t
    }

  let create () =
    { builder = B.create ()
    ; name_of_key = String.Table.create ()
    ; key_of_name = String.Table.create ()
    }

  let remember t ~key name =
    Hashtbl.set t.name_of_key ~key ~data:name ;
    Hashtbl.set t.key_of_name ~key:name ~data:key

  let name_of t key =
    Hashtbl.find t.name_of_key key |> Option.value ~default:key

  let key_of t name = Hashtbl.find_exn t.key_of_name name

  let account t name =
    let account = B.account t.builder name in
    remember t ~key:(B.public_key account) name ;
    account

  let block t ?parent ~height name status =
    let block = B.block t.builder ?parent ~name ~height status in
    remember t ~key:(B.state_hash block) name ;
    block

  let canonical t ?parent ~height name = block t ?parent ~height name Canonical

  let orphaned t ?parent ~height name = block t ?parent ~height name Orphaned

  let pending t ?parent ~height name = block t ?parent ~height name Pending

  (** Canonical blocks [h1] .. [h<length>], each the parent of the next. *)
  let canonical_chain t ~length =
    List.folding_map
      (List.range 1 (length + 1))
      ~init:None
      ~f:(fun parent height ->
        let block = canonical t ?parent ~height (sprintf "h%d" height) in
        (Some block, block) )

  let in_blocks ?(status = B.Applied) blocks =
    List.map blocks ~f:(fun block -> (block, status))

  let payment t ?fee_payer ?status name ~from ~to_ ~in_ =
    let command =
      B.payment t.builder ?fee_payer ~name ~source:from ~receiver:to_
        ~in_:(in_blocks ?status in_)
    in
    remember t ~key:(B.user_command_hash command) name

  let delegation t ?status name ~from ~to_ ~in_ =
    let command =
      B.delegation t.builder ~name ~delegator:from ~delegate:to_
        ~in_:(in_blocks ?status in_)
    in
    remember t ~key:(B.user_command_hash command) name

  let coinbase t ~to_ block =
    let coinbase =
      B.coinbase t.builder
        ~name:("coinbase in " ^ B.state_hash block)
        ~receiver:to_ block
    in
    remember t ~key:(B.coinbase_hash coinbase)
      ("coinbase to " ^ name_of t (B.public_key to_))

  let zkapp t name ~fee_payer ~updating ~in_ =
    let command =
      B.zkapp_command t.builder ~name ~fee_payer
        ~account_updates:(List.map updating ~f:B.account_update)
        ~in_:(in_blocks in_)
    in
    remember t ~key:(B.zkapp_command_hash command) name
end

(** Searches against an archive holding a {!Chain}, through the
    /search/transactions handler itself: a Rosetta request in, the response a
    client gets out. Only the network check, which asks a daemon, is left
    out. *)
module Search = struct
  type t = { chain : Chain.t; conn : (module Mina_caqti.CONNECTION) }

  type result =
    { rows : string list; total_count : int; next_offset : int option }

  (** A request. Accounts and transactions are given by name; [token] is a
      token id, the default token when left out. *)
  let query t ?operator ?max_block ?offset ?limit ?address ?account ?token
      ?transaction ?op_type ?op_status ?success () =
    let key = Chain.key_of t.chain in
    let field name value to_json =
      Option.map value ~f:(fun v -> (name, to_json v))
    in
    let int n = `Int n in
    let string s = `String s in
    let body =
      `Assoc
        ( ( "network_identifier"
          , `Assoc
              [ ("blockchain", `String "mina"); ("network", `String "testnet") ]
          )
        :: List.filter_opt
             [ field "operator" operator (function
                 | `And ->
                     `String "and"
                 | `Or ->
                     `String "or" )
             ; field "max_block" max_block int
             ; field "offset" offset int
             ; field "limit" limit int
             ; field "address" (Option.map address ~f:key) string
             ; field "account_identifier" account (fun name ->
                   `Assoc
                     [ ("address", `String (key name))
                     ; ( "metadata"
                       , Rosetta_lib.Amount_of.Token_id.encode
                           (Option.value token
                              ~default:Mina_base.Token_id.(to_string default) )
                       )
                     ] )
             ; field "transaction_identifier" transaction (fun name ->
                   `Assoc [ ("hash", `String (key name)) ] )
             ; field "type" op_type string
             ; field "status" op_status string
             ; field "success" success (fun b -> `Bool b)
             ] )
    in
    Rosetta_models.Search_transactions_request.of_yojson body
    |> Result.ok_or_failwith

  (* every transaction as "<transaction> @ <block>", in the response's order *)
  (* every transaction as "<transaction> @ <block>", in the response's order;
     an internal command's identifier is <kind>:<sequence no>:<secondary
     sequence no>:<hash> *)
  let rows_of t (response : Rosetta_models.Search_transactions_response.t) =
    let name = Chain.name_of t.chain in
    List.map response.transactions ~f:(fun { block_identifier; transaction } ->
        let hash =
          String.split transaction.transaction_identifier.hash ~on:':'
          |> List.last_exn
        in
        sprintf "%s @ %s" (name hash) (name block_identifier.hash) )

  let run t (request : Rosetta_models.Search_transactions_request.t) =
    let env =
      { Lib.Search.Specific.Env.Real.db_transactions =
          Lib.Search.Sql.run ~logger:(Logger.null ()) t.conn
      ; validate_network_choice =
          (fun ~network_identifier:_ ~minimum_user_command_fee:_ ~graphql_uri:_ ->
            Deferred.Result.return () )
      }
    in
    match
      block_on (fun () ->
          Lib.Search.Specific.Real.handle
            ~graphql_uri:(Uri.of_string "http://unused")
            ~minimum_user_command_fee:Currency.Fee.zero ~env request )
    with
    | Ok response ->
        { rows = rows_of t response
        ; total_count = Int64.to_int_exn response.total_count
        ; next_offset = Option.map response.next_offset ~f:Int64.to_int_exn
        }
    | Error e ->
        failwith (Rosetta_lib.Errors.show e)

  let rows t request = (run t request).rows

  (** The pages of [size] a client reads by following [next_offset] from the
      first page until the response has none. *)
  let pages t ~size request =
    let page offset =
      run t
        { request with
          offset = Some (Int64.of_int offset)
        ; limit = Some (Int64.of_int size)
        }
    in
    let rec from offset =
      let current = page offset in
      match current.next_offset with
      | None ->
          [ current ]
      | Some next ->
          current :: from next
    in
    from 0
end

(** [with_search chain f] writes [chain] into a fresh archive and runs [f]
    with searches against it; the archive is dropped afterwards. *)
let with_search (chain : Chain.t) f =
  let db =
    block_on (fun () ->
        B.Db.create ~server_uri:(B.Db.test_server_uri ())
          ~name:(Mina_automation.Psql.random_db_name ~prefix:"test_search")
          () )
    |> Or_error.ok_exn
  in
  Exn.protect
    ~f:(fun () ->
      let (_ : B.built) =
        block_on (fun () -> B.materialize chain.builder db) |> Or_error.ok_exn
      in
      let conn =
        match block_on (fun () -> Mina_caqti.connect db.uri) with
        | Ok conn ->
            conn
        | Error e ->
            failwith (Caqti_error.show e)
      in
      let (module Conn : Mina_caqti.CONNECTION) = conn in
      Exn.protect
        ~f:(fun () -> f { Search.chain; conn })
        ~finally:(fun () -> block_on Conn.disconnect) )
    ~finally:(fun () -> block_on (fun () -> B.Db.drop db) |> Or_error.ok_exn)

(** [expect what ~found expected]: [found] holds exactly the rows [expected],
    in any order. *)
let expect what ~found expected =
  let sorted = List.sort ~compare:String.compare in
  Alcotest.(check (list string)) what (sorted expected) (sorted found)
