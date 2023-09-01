open Core_kernel

module Container_images = struct
  type t =
    { mina : string
    ; archive_node : string
    ; user_agent : string
    ; bots : string
    ; points : string
    }

  let required_value field json ~fail =
    match Yojson.Safe.Util.member field json with
    | `String value ->
        value
    | _ ->
        failwith fail

  let optional_value field json ~default =
    match Yojson.Safe.Util.member field json with
    | `String value ->
        value
    | `Null ->
        default
    | _ ->
        failwithf "%s image parse error\n" field ()

  let mina_images path =
    let json = Yojson.Safe.from_file path in
    let mina = required_value "mina" json ~fail:"Must provide mina image" in
    let archive_node =
      optional_value "archive_node" json ~default:"archive_image_unused"
    in
    let user_agent =
      optional_value "user_agent" json
        ~default:"codaprotocol/coda-user-agent:0.1.5"
    in
    let bots =
      optional_value "bots" json ~default:"minaprotocol/mina-bots:latest"
    in
    let points =
      optional_value "points" json
        ~default:"codaprotocol/coda-points-hack:32b.4"
    in
    { mina; archive_node; user_agent; bots; points }

  let mk mina archive_node =
    { mina
    ; archive_node = Option.value archive_node ~default:"archive_image_unused"
    ; user_agent = "codaprotocol/coda-user-agent:0.1.5"
    ; bots = "minaprotocol/mina-bots:latest"
    ; points = "codaprotocol/coda-points-hack:32b.4"
    }
end

module Test_Account = struct
  type t =
    { account_name : string
    ; balance : string
    ; pk : string
    ; timing : Mina_base.Account_timing.t
    }
  [@@deriving to_yojson]
end

module Archive_node = struct
  type t = { node_name : string; account_name : string; docker_image : string }
  [@@deriving to_yojson]
end

module Block_producer_node = struct
  type t =
    { node_name : string
    ; account_name : string
    ; libp2p_keypair : Yojson.Safe.t
    ; libp2p_peerid : string
    ; docker_image : string
    }
  [@@deriving to_yojson]
end

module Seed_node = struct
  type t =
    { node_name : string
    ; account_name : string
    ; libp2p_keypair : Yojson.Safe.t
    ; libp2p_peerid : string
    ; docker_image : string
    }
  [@@deriving to_yojson]
end

module Snark_coordinator_node = struct
  type t =
    { node_name : string
    ; account_name : string
    ; docker_image : string
    ; worker_nodes : int
    }
  [@@deriving to_yojson]
end

module Snark_worker_node = struct
  type t = { node_name : string; account_name : string; docker_image : string }
  [@@deriving to_yojson]
end

type constants =
  { constraints : Genesis_constants.Constraint_constants.t
  ; genesis : Genesis_constants.t
  }
[@@deriving to_yojson]

type t =
  { requires_graphql : bool
  ; genesis_ledger : Test_Account.t list
  ; archive_nodes : Archive_node.t list
  ; block_producers : Block_producer_node.t list
  ; seed_nodes : Seed_node.t list
  ; snark_coordinator : Snark_coordinator_node.t option
  ; snark_workers : Snark_worker_node.t list
  ; snark_worker_fee : string
  ; log_precomputed_blocks : bool
  ; proof_config : Runtime_config.Proof_keys.t
  ; k : int
  ; delta : int
  ; slots_per_epoch : int
  ; slots_per_sub_window : int
  ; txpool_max_size : int
  }
[@@deriving to_yojson]

module Node_role = struct
  type t =
    | Archive_node
    | Block_producer
    | Seed_node
    | Snark_coordinator
    | Snark_worker

  let to_yojson = function
    | Archive_node ->
        `String "Archive_node"
    | Block_producer ->
        `String "Block_producer"
    | Seed_node ->
        `String "Seed_node"
    | Snark_coordinator ->
        `String "Snark_coordinator"
    | Snark_worker ->
        `String "Snark_worker"
end

module Topology = struct
  type node_info =
    { pk : string
    ; sk : string
    ; role : Node_role.t
    ; docker_image : string
    ; libp2p_keypair : Yojson.Safe.t
    ; libp2p_peerid : Yojson.Safe.t
    }
  [@@deriving to_yojson]

  type t = (string * node_info) list

  let to_yojson nodes : Yojson.Safe.t =
    let alist = List.map nodes ~f:(fun (a, b) -> (a, node_info_to_yojson b)) in
    `Assoc alist
end

let proof_config_default : Runtime_config.Proof_keys.t =
  { level = Some Full
  ; sub_windows_per_window = None
  ; ledger_depth = None
  ; work_delay = None
  ; block_window_duration_ms = Some 120000
  ; transaction_capacity = None
  ; coinbase_amount = None
  ; supercharged_coinbase_factor = None
  ; account_creation_fee = None
  ; fork = None
  }

let default =
  { requires_graphql = true
  ; genesis_ledger = []
  ; archive_nodes = []
  ; block_producers = []
  ; seed_nodes = []
  ; snark_coordinator = None
  ; snark_workers = []
  ; snark_worker_fee = "0.025"
  ; log_precomputed_blocks = false
  ; proof_config = proof_config_default
  ; k = 20
  ; slots_per_epoch = 3 * 8 * 20
  ; slots_per_sub_window = 2
  ; delta = 0
  ; txpool_max_size = 3000
  }

let transaction_capacity_log_2 (config : t) =
  match config.proof_config.transaction_capacity with
  | None ->
      Genesis_constants.Constraint_constants.compiled.transaction_capacity_log_2
  | Some (Log_2 i) ->
      i
  | Some (Txns_per_second_x10 tps_goal_x10) ->
      let max_coinbases = 2 in
      let block_window_duration_ms =
        Option.value
          ~default:
            Genesis_constants.Constraint_constants.compiled
              .block_window_duration_ms
          config.proof_config.block_window_duration_ms
      in
      let max_user_commands_per_block =
        (* block_window_duration is in milliseconds, so divide by 1000 divide
           by 10 again because we have tps * 10
        *)
        tps_goal_x10 * block_window_duration_ms / (1000 * 10)
      in
      (* Log of the capacity of transactions per transition.
          - 1 will only work if we don't have prover fees.
          - 2 will work with prover fees, but not if we want a transaction
            included in every block.
          - At least 3 ensures a transaction per block and the staged-ledger
            unit tests pass.
      *)
      1 + Core_kernel.Int.ceil_log2 (max_user_commands_per_block + max_coinbases)

let transaction_capacity config =
  let i = transaction_capacity_log_2 config in
  Int.pow 2 i

let blocks_for_first_ledger_proof (config : t) =
  let work_delay =
    Option.value
      ~default:Genesis_constants.Constraint_constants.compiled.work_delay
      config.proof_config.work_delay
  in
  let transaction_capacity_log_2 = transaction_capacity_log_2 config in
  ((work_delay + 1) * (transaction_capacity_log_2 + 1)) + 1

let slots_for_blocks blocks =
  (*Given 0.75 slots are filled*)
  Float.round_up (Float.of_int blocks *. 4.0 /. 3.0) |> Float.to_int

let transactions_needed_for_ledger_proofs ?(num_proofs = 1) config =
  let transactions_per_block = transaction_capacity config in
  (blocks_for_first_ledger_proof config * transactions_per_block)
  + (transactions_per_block * (num_proofs - 1))

let runtime_config_of_test_config t =
  let convert :
         Mina_base.Account_timing.t
      -> Runtime_config.Accounts.Single.Timed.t option = function
    | Untimed ->
        None
    | Timed timing ->
        Some
          { initial_minimum_balance = timing.initial_minimum_balance
          ; cliff_time = timing.cliff_time
          ; cliff_amount = timing.cliff_amount
          ; vesting_period = timing.vesting_period
          ; vesting_increment = timing.vesting_increment
          }
  in
  let open Yojson.Safe in
  let timed_opt_to_yojson : Runtime_config.Accounts.Single.Timed.t option -> t =
    function
    | None ->
        `Null
    | Some timed ->
        Runtime_config.Accounts.Single.Timed.to_yojson timed
  in
  let accounts : t =
    match to_yojson t |> Util.member "genesis_ledger" with
    | `List accounts ->
        let accounts =
          List.map accounts ~f:(function
            | `Assoc account ->
                `Assoc
                  (List.map account ~f:(fun (key, value) ->
                       ( key
                       , if String.equal key "timing" then
                           Mina_base.Account_timing.of_yojson value
                           |> Result.ok_or_failwith |> convert
                           |> timed_opt_to_yojson
                         else value ) ) )
            | _ ->
                failwith "Invalid account json" )
        in
        `List accounts
    | _ ->
        failwith "Invalid genesis ledger accounts"
  in
  to_string accounts
  |> sprintf {| { "accounts": %s } |}
  |> from_string |> Runtime_config.Ledger.of_yojson

let generate_pk_sk () =
  let open Signature_lib in
  let kp = Keypair.create () in
  let sk = kp.private_key |> Private_key.to_base58_check in
  let pk =
    kp.public_key |> Public_key.compress
    |> Public_key.Compressed.to_base58_check
  in
  (pk, sk)

let topology_of_test_config t : Yojson.Safe.t =
  let topology_of_archive { Archive_node.node_name; docker_image; _ } :
      string * Topology.node_info =
    let pk, sk = generate_pk_sk () in
    ( node_name
    , { pk
      ; sk
      ; role = Archive_node
      ; docker_image
      ; libp2p_keypair = `Null
      ; libp2p_peerid = `Null
      } )
  in
  let topology_of_block_producer
      { Block_producer_node.node_name
      ; docker_image
      ; libp2p_keypair
      ; libp2p_peerid
      ; _
      } : string * Topology.node_info =
    let pk, sk = generate_pk_sk () in
    ( node_name
    , { pk
      ; sk
      ; role = Block_producer
      ; docker_image
      ; libp2p_keypair
      ; libp2p_peerid = `String libp2p_peerid
      } )
  in
  let topology_of_seed
      { Seed_node.node_name; docker_image; libp2p_keypair; libp2p_peerid; _ } :
      string * Topology.node_info =
    let pk, sk = generate_pk_sk () in
    ( node_name
    , { pk
      ; sk
      ; role = Seed_node
      ; docker_image
      ; libp2p_keypair
      ; libp2p_peerid = `String libp2p_peerid
      } )
  in
  let topology_of_snark_coordinator
      { Snark_coordinator_node.node_name; docker_image; _ } :
      string * Topology.node_info =
    let pk, sk = generate_pk_sk () in
    ( node_name
    , { pk
      ; sk
      ; role = Snark_coordinator
      ; docker_image
      ; libp2p_keypair = `Null
      ; libp2p_peerid = `Null
      } )
  in
  let topology_of_snark_worker { Snark_worker_node.node_name; docker_image; _ }
      : string * Topology.node_info =
    let pk, sk = generate_pk_sk () in
    ( node_name
    , { pk
      ; sk
      ; role = Snark_worker
      ; docker_image
      ; libp2p_keypair = `Null
      ; libp2p_peerid = `Null
      } )
  in
  let snark_coordinator =
    match Option.map t.snark_coordinator ~f:topology_of_snark_coordinator with
    | None ->
        []
    | Some sc ->
        [ sc ]
  in
  let open List in
  snark_coordinator
  @ map t.archive_nodes ~f:topology_of_archive
  @ map t.block_producers ~f:topology_of_block_producer
  @ map t.seed_nodes ~f:topology_of_seed
  @ map t.snark_workers ~f:topology_of_snark_worker
  |> Topology.to_yojson

let test_account ?(pk = generate_pk_sk () |> fst)
    ?(timing = Mina_base.Account.Timing.Untimed) account_name balance :
    Test_Account.t =
  { account_name; balance; timing; pk }

let bp ?(libp2p_keypair = `Null) ?(libp2p_peerid = "") node_name
    ?(account_name = node_name ^ "-key") docker_image =
  { Block_producer_node.node_name
  ; account_name
  ; libp2p_keypair
  ; libp2p_peerid
  ; docker_image
  }

module Unit_tests = struct
  let test_config =
    { default with
      genesis_ledger =
        [ test_account "receiver-key" "9999999"
        ; test_account "empty-bp-key" "0"
        ; test_account "snark-node-key" "0"
        ]
        @ List.init 2 ~f:(fun i ->
              let i_str = Int.to_string i in
              test_account (sprintf "sender-account-%s" i_str) "10000" )
    ; block_producers =
        [ { node_name = "receiver"
          ; account_name = "receiver-key"
          ; docker_image = "bp-image-0"
          ; libp2p_keypair =
              Yojson.Safe.from_string
                {json|
                  {
                    "box_primitive": "xsalsa20poly1305",
                    "pw_primitive": "argon2i",
                    "nonce": "8tXZ3yVev59WGBFDhVkXYsqAkAy1oa4a9GkAgke",
                    "pwsalt": "AbLiWBzfVzdPK2YYRhhUxvQv7W8C",
                    "pwdiff": [
                      134217728,
                      6
                    ],
                    "ciphertext": "8uu1u388h2YJDfQGdAPurUrTgWGiUuRfz2t6TrRPEaqQoPVMHBvZFSC7BMZwCqoWk1PNAQVEPuBLQAhcBtdktmrjBnjhr2P38UiDzSa3gX7uawToQBV1WJh2gTNwPBYh2YRnRZNUY3ThaqqJmx7t7rrApYSqbSoAsLjydGSRYhxdrPtHeokmtcbtzFJ65Q5SWL6vAdhJqCqMcGXUhLDMpCsBwreqkFxn3QmQ9UinG1HTKGNV2FyrXDKUxseboBB3EEmq1Xvmt7ZaPropVcWeL9doWwYVW3xjiMXwR"
                  }
                |json}
          ; libp2p_peerid =
              "12D3KooWAZBFbTQWmegLFt8YSExEMTwJEiufRf4skYdZtaGxEXXo"
          }
        ; { node_name = "empty_node"
          ; account_name = "empty-bp-key"
          ; docker_image = "bp-image-1"
          ; libp2p_keypair = `Null
          ; libp2p_peerid = ""
          }
        ]
    ; snark_coordinator =
        Some
          { node_name = "snark-node"
          ; account_name = "snark-node-key"
          ; docker_image = "snark-coordinator-image"
          ; worker_nodes = 4
          }
    ; txpool_max_size = 10_000_000
    ; snark_worker_fee = "0.0001"
    ; proof_config =
        { proof_config_default with
          work_delay = Some 1
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.small
        }
    }

  open Yojson.Safe

  let%test_unit "runtime_config_of_test_config" =
    let config_json =
      runtime_config_of_test_config test_config
      |> Result.ok_or_failwith |> Runtime_config.Ledger.to_yojson
    in
    let () =
      print_endline "=== Runtime config ===" ;
      pretty_to_string config_json |> print_endline
    in
    ignore (config_json : t)

  let%test_unit "topology_of_test_config" =
    let () =
      print_endline "\n=== Topology ===" ;
      topology_of_test_config test_config |> pretty_to_string |> print_endline
    in
    ignore (topology_of_test_config test_config : t)
end
