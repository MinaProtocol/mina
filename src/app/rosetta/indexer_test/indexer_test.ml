open Core_kernel
open Async

type async_pool = (Caqti_async.connection, Caqti_error.t) Mina_caqti.Pool.t

type pool = { uri : Uri.t; pool : async_pool }

let logger = Logger.create ()

let archive_uri_arg =
  let pool =
    let parse s =
      let open Result.Let_syntax in
      let uri = Uri.of_string s in
      let%map pool =
        Result.map_error ~f:(fun e -> `Msg (Caqti_error.show e))
        @@ Mina_caqti.connect_pool uri
      in
      { uri; pool }
    in
    let print ppf { uri; _ } = Uri.pp_hum ppf uri in
    Cmdliner.Arg.conv ~docv:"URI" (parse, print)
  in
  let doc = "Postgres database URI" in
  let env = Cmdliner.Arg.env_var ~doc "ARCHIVE_URI" in
  Cmdliner.Arg.(
    required & opt (some pool) None & info [ "archive_uri" ] ~env ~doc)

let ok_or_failwith show result =
  Result.ok_or_failwith @@ Result.map_error ~f:show result

let with_db pool f =
  let open Deferred.Let_syntax in
  Mina_caqti.Pool.use (fun db -> f db) pool >>| ok_or_failwith Caqti_error.show

module Ops = Lib.Search.Transactions_info.T (Deferred.Result)

type internal_command

type user_command

type zkapp_command

type _ command_t =
  | Internal_command :
      Lib.Search.Sql.Internal_commands.t
      -> internal_command command_t
  | User_command : Lib.Search.Sql.User_commands.t -> user_command command_t
  | Zkapp_command : Lib.Search.Sql.Zkapp_commands.t -> zkapp_command command_t

type _ info_t =
  | Internal_command_info :
      Lib.Search.Internal_command_info.t
      -> internal_command info_t
  | User_command_info : Lib.Search.User_command_info.t -> user_command info_t
  | Zkapp_command_info : Lib.Search.Zkapp_command_info.t -> zkapp_command info_t

let run_user_commands db ~offset ~limit query =
  Deferred.Result.map ~f:(fun (c, commands) ->
      (c, List.map commands ~f:(fun command -> User_command command)) )
  @@ Lib.Search.Sql.User_commands.run db ~logger ~offset ~limit query

let run_internal_commands db ~offset ~limit query =
  Deferred.Result.map ~f:(fun (c, commands) ->
      (c, List.map commands ~f:(fun command -> Internal_command command)) )
  @@ Lib.Search.Sql.Internal_commands.run db ~logger ~offset ~limit query

let run_zkapp_commands db ~offset ~limit query =
  Deferred.Result.map ~f:(fun (c, commands) ->
      (c, List.map commands ~f:(fun command -> Zkapp_command command)) )
  @@ Lib.Search.Sql.Zkapp_commands.run db ~logger ~offset ~limit query

module Test_values = struct
  module T = struct
    type 'a t =
      { user_commands : 'a list
      ; internal_commands : 'a list
      ; zkapp_commands : 'a list
      }
  end

  include T

  module Make (M : sig
    type t

    val get_values :
      (module Mina_caqti.CONNECTION) -> (t T.t, Caqti_error.t) Deferred.Result.t
  end) =
  struct
    type t = M.t

    let get_test_value =
      let values = ref None in
      let open Deferred.Result.Let_syntax in
      fun db kind ->
        let%map { user_commands; internal_commands; zkapp_commands } =
          match !values with
          | None ->
              let%map values' = M.get_values db in
              values := Some values' ;
              values'
          | Some values ->
              Deferred.Result.return values
        in
        match kind with
        | `User_commands ->
            user_commands
        | `Internal_commands ->
            internal_commands
        | `Zkapp_commands ->
            zkapp_commands

    let deferred_generator kind db =
      let open Deferred.Result.Let_syntax in
      let%map values = get_test_value db kind in
      Quickcheck.Generator.of_list values
  end

  module Txn_hash = Make (struct
    type t = string

    let get_values (module Conn : Mina_caqti.CONNECTION) =
      let open Deferred.Result.Let_syntax in
      let query table =
        [%string "SELECT hash FROM %{table} ORDER BY RANDOM() LIMIT 1000"]
      in
      let%bind user_commands =
        Conn.collect_list
          ( Mina_caqti.collect_req Caqti_type.unit Caqti_type.string
          @@ query "user_commands" )
          ()
      in
      let%bind internal_commands =
        Conn.collect_list
          ( Mina_caqti.collect_req Caqti_type.unit Caqti_type.string
          @@ query "internal_commands" )
          ()
      in
      let%map zkapp_commands =
        Conn.collect_list
          ( Mina_caqti.collect_req Caqti_type.unit Caqti_type.string
          @@ query "zkapp_commands" )
          ()
      in
      { user_commands; internal_commands; zkapp_commands }
  end)

  module Account_identifier = Make (struct
    type t = [ `Pk of string ] * [ `Token_id of string ]

    let typ =
      Caqti_type.custom
        ~encode:(fun (`Pk pk, `Token_id token_id) ->
          Result.return (pk, token_id) )
        ~decode:(fun (pk, token_id) ->
          Result.return (`Pk pk, `Token_id token_id) )
        Caqti_type.(t2 string string)

    let get_values (module Conn : Mina_caqti.CONNECTION) =
      let open Deferred.Result.Let_syntax in
      let query =
        [%string
          {sql|
        SELECT pk.value, t.value
        FROM account_identifiers ai
        INNER JOIN public_keys pk ON ai.public_key_id = pk.id 
        INNER JOIN tokens t ON ai.token_id = t.id
        ORDER BY RANDOM () 
        LIMIT 1000
      |sql}]
      in
      let%map user_commands =
        Conn.collect_list (Mina_caqti.collect_req Caqti_type.unit typ query) ()
      in
      let internal_commands = user_commands in
      let zkapp_commands = user_commands in
      { user_commands; internal_commands; zkapp_commands }
  end)

  module Op_status = Make (struct
    type t = Rosetta_lib.Operation_statuses.t

    let get_values _ =
      let values = [ `Success; `Failed ] in
      Deferred.Result.return
        { user_commands = values
        ; internal_commands = values
        ; zkapp_commands = values
        }
  end)

  module Success = Make (struct
    type t = bool

    let get_values _ =
      let values = [ true; false ] in
      Deferred.Result.return
        { user_commands = values
        ; internal_commands = values
        ; zkapp_commands = values
        }
  end)

  module Address = Make (struct
    type t = [ `Pk of string ]

    let typ =
      Caqti_type.custom
        ~encode:(function `Pk pk -> Result.return pk)
        ~decode:(fun pk -> Result.return (`Pk pk))
        Caqti_type.string

    let get_values (module Conn : Mina_caqti.CONNECTION) =
      let open Deferred.Result.Let_syntax in
      let query =
        [%string
          {sql|
        SELECT pk.value
        FROM public_keys pk
        ORDER BY RANDOM ()
        LIMIT 1000
      |sql}]
      in
      let%map user_commands =
        Conn.collect_list (Mina_caqti.collect_req Caqti_type.unit typ query) ()
      in
      let internal_commands = user_commands in
      let zkapp_commands = user_commands in
      { user_commands; internal_commands; zkapp_commands }
  end)

  module Op_type = Make (struct
    type t = Rosetta_lib.Operation_types.t

    let get_values _ =
      let values =
        List.map ~f:Rosetta_lib.Operation_types.of_name_exn
        @@ Lazy.force Rosetta_lib.Operation_types.all
      in
      Deferred.Result.return
        { user_commands = values
        ; internal_commands = values
        ; zkapp_commands = values
        }
  end)

  module Max_block = struct
    type t = int64

    let deferred_generator _ (module Conn : Mina_caqti.CONNECTION) =
      let open Deferred.Result.Let_syntax in
      let%map max_height =
        Conn.find
          (Mina_caqti.find_req Caqti_type.unit Caqti_type.int64
             "SELECT MAX(height) FROM blocks" )
          ()
      in
      Int64.gen_incl 1L max_height
  end
end

let hash_of_info (type a) : a info_t -> string = function
  | Internal_command_info info ->
      info.Lib.Search.Internal_command_info.info.hash
  | User_command_info info ->
      info.Lib.Search.User_command_info.info.hash
  | Zkapp_command_info info ->
      info.Lib.Search.Zkapp_command_info.info.hash

let to_info' (type a) : a command_t -> a info_t = function
  | Internal_command command ->
      Internal_command_info
        ( ok_or_failwith Rosetta_lib.Errors.show
        @@ Lib.Search.Sql.Internal_commands.to_info command )
  | User_command command ->
      User_command_info
        ( ok_or_failwith Rosetta_lib.Errors.show
        @@ Lib.Search.Sql.User_commands.to_info command )
  | Zkapp_command _ ->
      failwith "Zkapp command not supported"

let to_info (type a) : a command_t list -> a info_t list = function
  | Zkapp_command _ :: _ as commands ->
      List.map ~f:(fun info -> Zkapp_command_info info)
      @@ Lib.Search.Sql.Zkapp_commands.to_command_infos
      @@ List.map commands ~f:(function Zkapp_command command -> command)
  | commands ->
      List.map commands ~f:to_info'

module Make (T : sig
  type t

  val deferred_generator :
       [ `User_commands | `Internal_commands | `Zkapp_commands ]
    -> (module Mina_caqti.CONNECTION)
    -> (t Quickcheck.Generator.t, Caqti_error.t) Deferred.Result.t
end) (I : sig
  type t = T.t

  val to_query : t -> Lib.Search.Transaction_query.t

  val of_user_command_info : Lib.Search.User_command_info.t -> t list Deferred.t

  val of_internal_command_info :
    Lib.Search.Internal_command_info.t -> t list Deferred.t

  val of_zkapp_command_info :
    Lib.Search.Zkapp_command_info.t -> t list Deferred.t

  val check : t -> t -> bool

  val name : string

  val trials : int
end) =
struct
  type t = T.t

  let of_info (type a) : a info_t -> t list Deferred.t = function
    | Internal_command_info info ->
        I.of_internal_command_info info
    | User_command_info info ->
        I.of_user_command_info info
    | Zkapp_command_info info ->
        I.of_zkapp_command_info info

  let trials = I.trials

  let check = I.check

  let check_condition value infos =
    let open Deferred.Let_syntax in
    let%map result =
      Deferred.List.find infos ~f:(fun info ->
          let%map v = of_info info in
          not (List.exists v ~f:(check value)) )
    in
    Option.value_map result ~default:() ~f:(fun info ->
        failwith [%string "hash: %{hash_of_info info}\nno value matches filter"] )

  let test table ~pool:{ pool; _ } run =
    let open Deferred.Let_syntax in
    let%bind generator = with_db pool (T.deferred_generator table) in
    Quickcheck.async_test ~trials generator ~f:(fun value ->
        let query = I.to_query value in
        let limit = 100000L in
        let%bind total_count, commands =
          with_db pool (fun db -> run db ~offset:None ~limit:(Some limit) query)
        in
        let open Alcotest in
        let infos = to_info commands in
        if Int64.(total_count > limit) then
          check int64 "limit = len (commands)" limit
            (Int64.of_int (List.length infos))
        else
          check int64 "total_count = len (commands)" total_count
            (Int64.of_int (List.length infos)) ;
        check_condition value infos )

  let test_user_command pool = test `User_commands ~pool run_user_commands

  let test_internal_command pool =
    test `Internal_commands ~pool run_internal_commands

  let test_zkapp_command pool = test `Zkapp_commands ~pool run_zkapp_commands

  let test_suite =
    let open Alcotest_async in
    ( I.name
    , [ test_case ~timeout:(sec 400.) "User commands" `Slow @@ test_user_command
      ; test_case ~timeout:(sec 400.) "Internal commands" `Slow
        @@ test_internal_command
      ; test_case ~timeout:(sec 400.) "Zkapp commands" `Slow
        @@ test_zkapp_command
      ] )

  module Make_no_results_test (S : sig
    val deferred_non_existing_values_gen :
      async_pool -> string -> I.t Quickcheck.Generator.t Deferred.t
  end) =
  struct
    let test_not_existing ~limit ~table run { pool; _ } =
      let open Deferred.Let_syntax in
      let%bind generator = S.deferred_non_existing_values_gen pool table in
      Quickcheck.async_test ~trials:limit generator ~f:(fun value ->
          let query = I.to_query value in
          let%map total_count, commands =
            with_db pool (fun db -> run db ~offset:None ~limit:None query)
          in
          let open Alcotest in
          check int64 "total_count = 0" 0L total_count ;
          check int "len (commands) = 0" 0 (List.length commands) )

    let test_suite =
      let open Alcotest_async in
      let name, tests = test_suite in
      ( name
      , tests
        @ [ test_case ~timeout:(sec 400.) "Non existing user command" `Slow
            @@ test_not_existing ~limit:50 ~table:"user_commands"
                 run_user_commands
          ; test_case ~timeout:(sec 400.) "Non existing internal command" `Slow
            @@ test_not_existing ~limit:50 ~table:"internal_commands"
                 run_internal_commands
          ; test_case ~timeout:(sec 400.) "Non existing zkapp command" `Slow
            @@ test_not_existing ~limit:50 ~table:"zkapp_commands"
                 run_zkapp_commands
          ] )
  end
end

module Txn_hash = struct
  include
    Make
      (Test_values.Txn_hash)
      (struct
        type t = string

        let name = "transaction-hash"

        let trials = 50

        let to_query transaction_hash =
          Lib.Search.Transaction_query.make
            ~filter:
              (Lib.Search.Transaction_query.Filter.make ~transaction_hash ())
            ()

        let of_user_command_info info =
          Deferred.return [ info.Lib.Search.User_command_info.info.hash ]

        let of_internal_command_info info =
          Deferred.return [ info.Lib.Search.Internal_command_info.info.hash ]

        let of_zkapp_command_info info =
          Deferred.return [ info.Lib.Search.Zkapp_command_info.info.hash ]

        let check = String.equal
      end)

  include Make_no_results_test (struct
    let deferred_non_existing_values_gen _ _ =
      Deferred.return @@ Quickcheck.Generator.of_list [ "non_existing_hash" ]
  end)
end

module Account_identifier = struct
  include
    Make
      (Test_values.Account_identifier)
      (struct
        type t = [ `Pk of string ] * [ `Token_id of string ]

        let name = "account-identifier"

        let trials = 50

        let to_query (`Pk address, `Token_id token_id) =
          Lib.Search.Transaction_query.make
            ~filter:
              (Lib.Search.Transaction_query.Filter.make
                 ~account_identifier:{ address; token_id } () )
            ()

        let of_user_command_info { Lib.Search.User_command_info.info; _ } =
          Deferred.return
            [ (info.receiver, info.token)
            ; (info.source, info.token)
            ; (info.fee_payer, info.fee_token)
            ]

        let of_internal_command_info
            { Lib.Search.Internal_command_info.info; _ } =
          Deferred.return
          @@ (info.receiver, info.token)
             :: ( Option.to_list
                @@ Option.map
                     ~f:(fun coinbase_receiver ->
                       (coinbase_receiver, info.token) )
                     info.coinbase_receiver )

        let of_zkapp_command_info { Lib.Search.Zkapp_command_info.info; _ } =
          Deferred.return
          @@ (info.fee_payer, `Token_id Rosetta_lib.Amount_of.Token_id.default)
             :: List.map info.account_updates ~f:(fun { account; token; _ } ->
                    (account, token) )

        let check (`Pk address, `Token_id token_id)
            (`Pk address', `Token_id token_id') =
          String.(equal address address' && equal token_id token_id')
      end)

  include Make_no_results_test (struct
    let deferred_non_existing_values_gen pool _ =
      let open Deferred.Let_syntax in
      let query =
        [%string
          {sql|
            SELECT pk.value, t.value
            FROM public_keys pk, tokens t
            WHERE (pk.id, t.id) NOT IN
              (SELECT public_key_id, token_id FROM account_identifiers)
            ORDER BY RANDOM ()
            LIMIT 1000
          |sql}]
      in
      let%map values =
        with_db pool (fun (module Conn : Mina_caqti.CONNECTION) ->
            Conn.collect_list
              (Mina_caqti.collect_req Caqti_type.unit
                 Caqti_type.(t2 string string)
                 query )
              () )
      in
      Quickcheck.Generator.of_list
      @@ (`Pk "non_existing_address", `Token_id "non_existing_token_id")
         :: List.map
              ~f:(fun (pk, token_id) -> (`Pk pk, `Token_id token_id))
              values
  end)
end

module Op_status =
  Make
    (Test_values.Op_status)
    (struct
      type t = Rosetta_lib.Operation_statuses.t [@@deriving equal]

      let name = "operation-status"

      let trials = 20

      let to_query v =
        let op_status =
          match v with `Success -> "applied" | `Failed -> "failed"
        in
        Lib.Search.Transaction_query.make
          ~filter:(Lib.Search.Transaction_query.Filter.make ~op_status ())
          ()

      let of_user_command_info { Lib.Search.User_command_info.info; _ } =
        Deferred.return
          [ Option.value_map info.failure_status ~default:`Failed ~f:(function
              | `Applied _ ->
                  `Success
              | `Failed _ ->
                  `Failed )
          ]

      let of_internal_command_info _ = Deferred.return [ `Success ]

      let of_zkapp_command_info { Lib.Search.Zkapp_command_info.info; _ } =
        Deferred.return
          [ (match info.failure_reasons with [] -> `Success | _ -> `Failed) ]

      let check = equal
    end)

module Success =
  Make
    (Test_values.Success)
    (struct
      type t = bool

      let name = "success"

      let trials = 30

      let to_query success =
        Lib.Search.Transaction_query.make
          ~filter:(Lib.Search.Transaction_query.Filter.make ~success ())
          ()

      let of_user_command_info { Lib.Search.User_command_info.info; _ } =
        Deferred.return
          [ Option.value_map info.failure_status ~default:false ~f:(function
              | `Applied _ ->
                  true
              | `Failed _ ->
                  false )
          ]

      let of_internal_command_info _ = Deferred.return [ true ]

      let of_zkapp_command_info { Lib.Search.Zkapp_command_info.info; _ } =
        Deferred.return
          [ (match info.failure_reasons with [] -> true | _ -> false) ]

      let check = Bool.equal
    end)

module Address = struct
  include
    Make
      (Test_values.Address)
      (struct
        type t = [ `Pk of string ] [@@deriving equal]

        let name = "address"

        let trials = 50

        let to_query (`Pk address) =
          Lib.Search.Transaction_query.make
            ~filter:(Lib.Search.Transaction_query.Filter.make ~address ())
            ()

        let of_user_command_info { Lib.Search.User_command_info.info; _ } =
          Deferred.return [ info.receiver; info.source; info.fee_payer ]

        let of_internal_command_info
            { Lib.Search.Internal_command_info.info; _ } =
          Deferred.return
          @@ (info.receiver :: Option.to_list info.coinbase_receiver)

        let of_zkapp_command_info { Lib.Search.Zkapp_command_info.info; _ } =
          Deferred.return
          @@ info.fee_payer
             :: List.map info.account_updates ~f:(fun { account; _ } -> account)

        let check = equal
      end)

  include Make_no_results_test (struct
    let deferred_non_existing_values_gen _ _ =
      Deferred.return
      @@ Quickcheck.Generator.of_list [ `Pk "non_existing_address" ]
  end)
end

module Op_type =
  Make
    (Test_values.Op_type)
    (struct
      type t = Rosetta_lib.Operation_types.t [@@deriving equal]

      let name = "operation-type"

      let trials = 50

      let to_query op_type =
        Lib.Search.Transaction_query.make
          ~filter:(Lib.Search.Transaction_query.Filter.make ~op_type ())
          ()

      let of_operations =
        List.map ~f:(fun { Rosetta_models.Operation._type; _ } ->
            Rosetta_lib.Operation_types.of_name_exn _type )

      let of_user_command_info { Lib.Search.User_command_info.info; _ } =
        Deferred.return @@ of_operations
        @@ Lib.Commands_common.User_command_info.to_operations' info

      let of_internal_command_info { Lib.Search.Internal_command_info.info; _ }
          =
        let open Deferred.Let_syntax in
        let%map operations =
          let module M =
            Lib.Commands_common.Internal_command_info.T (Deferred.Result) in
          M.to_operations info
        in
        of_operations @@ ok_or_failwith Rosetta_lib.Errors.show operations

      let of_zkapp_command_info { Lib.Search.Zkapp_command_info.info; _ } =
        let open Deferred.Let_syntax in
        let%map operations =
          let module M =
            Lib.Commands_common.Zkapp_command_info.T (Deferred.Result) in
          M.to_operations info
        in
        of_operations @@ ok_or_failwith Rosetta_lib.Errors.show operations

      let check = equal
    end)

module Max_block =
  Make
    (Test_values.Max_block)
    (struct
      type t = int64

      let name = "max-block"

      let trials = 10

      let to_query max_block =
        Lib.Search.Transaction_query.make ~max_block
          ~filter:(Lib.Search.Transaction_query.Filter.make ())
          ()

      let of_user_command_info { Lib.Search.User_command_info.block_height; _ }
          =
        Deferred.return [ block_height ]

      let of_internal_command_info
          { Lib.Search.Internal_command_info.block_height; _ } =
        Deferred.return [ block_height ]

      let of_zkapp_command_info
          { Lib.Search.Zkapp_command_info.block_height; _ } =
        Deferred.return [ block_height ]

      let check = Int64.( >= )
    end)

module Offset_limit = struct
  type t = { offset : int; limit : int }

  let offset_generator = Int.gen_incl 1 100

  let limit_generator = Int.gen_incl 1 50

  let transaction_testable =
    Alcotest.testable
      (fun ppf transaction ->
        Fmt.string ppf
          Rosetta_models.(
            transaction.Block_transaction.block_identifier.Block_identifier.hash)
        )
      (fun t_1 t_2 ->
        String.equal
          Rosetta_models.(
            t_1.Block_transaction.block_identifier.Block_identifier.hash)
          Rosetta_models.(
            t_2.Block_transaction.block_identifier.Block_identifier.hash) )

  let to_query ~offset ~limit =
    let offset = Option.map offset ~f:Int64.of_int in
    let limit = Option.map limit ~f:Int64.of_int in
    Lib.Search.Transaction_query.make ?offset ?limit
      ~filter:(Lib.Search.Transaction_query.Filter.make ())
      ()

  let run ?offset ?limit { pool; _ } =
    with_db pool (fun db ->
        Deferred.Result.map_error ~f:(fun _ ->
            Caqti_error.(request_failed ~uri:Uri.empty ~query:"" (Msg "")) )
        @@ Lib.Search.Sql.run ~logger db (to_query ~offset ~limit) )

  let run' { offset; limit } = run ~offset ~limit

  let test_limit pool =
    Quickcheck.async_test ~trials:10 limit_generator ~f:(fun limit ->
        let open Deferred.Let_syntax in
        let%map info = run ~limit pool in
        if
          List.length info.user_commands
          + List.length info.internal_commands
          + List.length info.zkapp_commands
          <= limit
        then Alcotest.(check pass "len(commands) <= limit" () ())
        else
          Alcotest.failf "total_count = %Ld > limit = %d" info.total_count limit )

  let test pool =
    let generator =
      let open Quickcheck.Generator.Let_syntax in
      let%bind offset_1 = offset_generator in
      let%bind limit_1 = limit_generator in
      let%bind offset_2 = Int.(gen_incl 1 (offset_1 - 1)) in
      let%map limit_2 =
        Int.(gen_incl (offset_1 - offset_2 + 1) (offset_1 + limit_1 - offset_2))
      in
      ( { offset = offset_1; limit = limit_1 }
      , { offset = offset_2; limit = limit_2 } )
    in
    Quickcheck.async_test ~trials:5 generator ~f:(fun (value_1, value_2) ->
        let open Deferred.Let_syntax in
        let%bind info_1 = run' value_1 pool in
        let%bind transactions_1_result = Ops.to_transactions info_1 in
        let transactions_1' =
          ok_or_failwith Rosetta_lib.Errors.show transactions_1_result
        in
        let%bind info_2 = run' value_2 pool in
        let%map transactions_2_result = Ops.to_transactions info_2 in
        let transactions_2' =
          ok_or_failwith Rosetta_lib.Errors.show transactions_2_result
        in
        let transactions_1 =
          List.sub transactions_1' ~pos:0
            ~len:(value_2.limit + value_2.offset - value_1.offset)
        in
        let transactions_2 =
          let pos = value_1.offset - value_2.offset in
          List.sub transactions_2' ~pos ~len:(List.length transactions_2' - pos)
        in
        Alcotest.(
          check
            (list transaction_testable)
            "transactions_1 = transactions_2" transactions_1 transactions_2) )

  let test_suite =
    let open Alcotest_async in
    ( "offset-limit"
    , [ test_case ~timeout:(sec 400.) "Limit and offset" `Slow @@ test
      ; test_case ~timeout:(sec 400.) "Limit" `Slow @@ test_limit
      ] )
end

let () =
  Async.Thread_safe.block_on_async_exn (fun () ->
      Alcotest_async.(
        run_with_args "Indexer" archive_uri_arg
          [ Txn_hash.test_suite
          ; Account_identifier.test_suite
          ; Op_status.test_suite
          ; Success.test_suite
          ; Address.test_suite
          ; Op_type.test_suite
          ; Max_block.test_suite
          ; Offset_limit.test_suite
          ]) )
