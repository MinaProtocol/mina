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

module Git_build = struct
  type t = Commit of string | Tag of string

  let to_yojson : t -> Yojson.Safe.t = function
    | Commit commit ->
        `Assoc [ ("commit", `String commit) ]
    | Tag tag ->
        `Assoc [ ("tag", `String tag) ]
end

module Archive_node = struct
  type t =
    { node_name : string
    ; account_name : string
    ; docker_image : string option
    ; archive_image : string option
    ; git_build : Git_build.t option
    }
  [@@deriving to_yojson]
end

module Epoch_data = struct
  module Data = struct
    (* the seed is a field value in Base58Check format *)
    type t = { epoch_ledger : Test_Account.t list; epoch_seed : string }
    [@@deriving to_yojson]
  end

  type t = { staking : Data.t; next : Data.t option } [@@deriving to_yojson]
end

module Block_producer_node = struct
  type t =
    { node_name : string
    ; account_name : string
    ; docker_image : string option
    ; git_build : Git_build.t option
    }
  [@@deriving to_yojson]
end

module Seed_node = struct
  type t =
    { node_name : string
    ; account_name : string
    ; docker_image : string option
    ; git_build : Git_build.t option
    }
  [@@deriving to_yojson]
end

module Snark_coordinator_node = struct
  type t =
    { node_name : string
    ; account_name : string
    ; docker_image : string option
    ; git_build : Git_build.t option
    ; worker_nodes : int
    }
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
  ; epoch_data : Epoch_data.t option
  ; block_producers : Block_producer_node.t list
  ; seed_nodes : Seed_node.t list
  ; snark_coordinator : Snark_coordinator_node.t option
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
  type t = Archive_node | Block_producer | Seed_node | Snark_coordinator

  let to_yojson = function
    | Archive_node ->
        `String "Archive_node"
    | Block_producer ->
        `String "Block_producer"
    | Seed_node ->
        `String "Seed_node"
    | Snark_coordinator ->
        `String "Snark_coordinator"
end

module Topology = struct
  type snark_coordinator_info =
    { pk : string
    ; sk : string
    ; role : Node_role.t
    ; docker_image : string option
    ; git_build : Git_build.t option
    ; worker_nodes : int
    ; snark_worker_fee : string
    ; libp2p_pass : string
    ; libp2p_keyfile : string
    ; libp2p_keypair : Yojson.Safe.t
    ; libp2p_peerid : Yojson.Safe.t
    }
  [@@deriving to_yojson]

  type snark_worker_info =
    { pk : string
    ; sk : string
    ; role : Node_role.t
    ; docker_image : string option
    }
  [@@deriving to_yojson]

  type archive_info =
    { pk : string
    ; sk : string
    ; role : Node_role.t
    ; docker_image : string option
    ; archive_image : string option
    ; git_build : Git_build.t option
    ; schema_files : string list
    ; libp2p_pass : string
    ; libp2p_keyfile : string
    ; libp2p_keypair : Yojson.Safe.t
    ; libp2p_peerid : Yojson.Safe.t
    }
  [@@deriving to_yojson]

  type node_info =
    { pk : string
    ; sk : string
    ; privkey_path : string option
    ; role : Node_role.t
    ; docker_image : string option
    ; git_build : Git_build.t option
    ; libp2p_pass : string
    ; libp2p_keyfile : string
    ; libp2p_keypair : Yojson.Safe.t
    ; libp2p_peerid : Yojson.Safe.t
    }
  [@@deriving to_yojson]

  type top_info =
    | Archive of string * archive_info
    | Node of string * node_info
    | Snark_coordinator of string * snark_coordinator_info

  type t = top_info list

  let to_yojson nodes : Yojson.Safe.t =
    let alist =
      List.map nodes ~f:(function
        | Archive (a, b) ->
            (a, archive_info_to_yojson b)
        | Node (a, b) ->
            (a, node_info_to_yojson b)
        | Snark_coordinator (a, b) ->
            (a, snark_coordinator_info_to_yojson b) )
    in
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
  ; epoch_data = None
  ; block_producers = []
  ; seed_nodes =
      [ { node_name = "default-seed"
        ; account_name = "default-seed-key"
        ; docker_image = None
        ; git_build = None
        }
      ]
  ; snark_coordinator = None
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

let topology_of_test_config t private_keys libp2p_keypairs libp2p_peerids :
    Topology.t =
  let num_bp = List.length t.block_producers in
  let num_bp_sc =
    num_bp + if Option.is_some t.snark_coordinator then 1 else 0
  in
  let num_bp_sc_an = num_bp_sc + List.length t.archive_nodes in
  let keypairs = ref Core.String.Map.empty in
  let pk_sk name n =
    let open Signature_lib in
    let sk = List.nth_exn private_keys n in
    let pk =
      let open Public_key in
      Private_key.of_base58_check_exn sk
      |> of_private_key_exn |> compress |> Compressed.to_base58_check
    in
    match Core.String.Map.find !keypairs name with
    | Some keys ->
        keys
    | None ->
        keypairs := Core.String.Map.add_exn !keypairs ~key:name ~data:(pk, sk) ;
        (pk, sk)
  in
  let libp2p_pass = "naughty blue worm" in
  let topology_of_block_producer n
      { Block_producer_node.account_name; node_name; docker_image; git_build } :
      Topology.top_info =
    let pk, sk = pk_sk account_name n in
    Node
      ( node_name
      , { pk
        ; sk
        ; privkey_path = Some "instantiated in network_config.ml"
        ; role = Block_producer
        ; docker_image
        ; git_build
        ; libp2p_pass
        ; libp2p_keyfile = "instantiated in network_config.ml"
        ; libp2p_keypair = List.nth_exn libp2p_keypairs n
        ; libp2p_peerid = `String List.(nth_exn libp2p_peerids n)
        } )
  in
  let topology_of_snark_coordinator
      { Snark_coordinator_node.account_name
      ; node_name
      ; docker_image
      ; git_build
      ; worker_nodes
      } : Topology.top_info =
    let pk, sk = pk_sk account_name num_bp in
    Snark_coordinator
      ( node_name
      , { pk
        ; sk
        ; role = Snark_coordinator
        ; docker_image
        ; git_build
        ; worker_nodes
        ; snark_worker_fee = t.snark_worker_fee
        ; libp2p_pass
        ; libp2p_keyfile = "instantiated in network_config.ml"
        ; libp2p_keypair = List.nth_exn libp2p_keypairs num_bp
        ; libp2p_peerid = `String List.(nth_exn libp2p_peerids num_bp)
        } )
  in
  let snark_coordinator =
    match Option.map t.snark_coordinator ~f:topology_of_snark_coordinator with
    | None ->
        []
    | Some sc ->
        [ sc ]
  in
  let topology_of_archive n
      { Archive_node.account_name
      ; node_name
      ; docker_image
      ; archive_image
      ; git_build
      } : Topology.top_info =
    let n = n + num_bp_sc in
    let pk, sk = pk_sk account_name n in
    Archive
      ( node_name
      , { pk
        ; sk
        ; role = Archive_node
        ; docker_image
        ; archive_image
        ; git_build
        ; schema_files = []
        ; libp2p_pass
        ; libp2p_keyfile = "instantiated in network_config.ml"
        ; libp2p_keypair = List.nth_exn libp2p_keypairs n
        ; libp2p_peerid = `String List.(nth_exn libp2p_peerids n)
        } )
  in
  let topology_of_seed n
      { Seed_node.account_name; node_name; docker_image; git_build } :
      Topology.top_info =
    let n = n + num_bp_sc_an in
    let pk, sk = pk_sk account_name n in
    Node
      ( node_name
      , { pk
        ; sk
        ; privkey_path = None
        ; role = Seed_node
        ; docker_image
        ; git_build
        ; libp2p_pass
        ; libp2p_keyfile = "instantiated in network_config.ml"
        ; libp2p_keypair = List.nth_exn libp2p_keypairs n
        ; libp2p_peerid = `String List.(nth_exn libp2p_peerids n)
        } )
  in
  snark_coordinator
  @ List.mapi t.archive_nodes ~f:topology_of_archive
  @ List.mapi t.block_producers ~f:topology_of_block_producer
  @ List.mapi t.seed_nodes ~f:topology_of_seed

let test_account ?(pk = "") ?(timing = Mina_base.Account.Timing.Untimed)
    account_name balance : Test_Account.t =
  { account_name; balance; timing; pk }

module Unit_tests = struct
  let test_config =
    { default with
      genesis_ledger =
        [ test_account "receiver" "9999999"
        ; test_account "empty-bp" "0"
        ; test_account "snark-node" "0"
        ]
        @ List.init 2 ~f:(fun i ->
              test_account (sprintf "sender-account-%d" i) "10000" )
    ; block_producers =
        [ { node_name = "receiver"
          ; account_name = "receiver-key"
          ; docker_image = Some "bp-image"
          ; git_build = None
          }
        ; { node_name = "empty-node-0"
          ; account_name = "empty-bp-key"
          ; docker_image = None
          ; git_build = Some (Commit "6131f41e")
          }
        ; { node_name = "empty-node-1"
          ; account_name = "empty-bp-key"
          ; docker_image = Some "bp-image-1"
          ; git_build = None
          }
        ]
    ; snark_coordinator =
        Some
          { node_name = "snark-node"
          ; account_name = "snark-node-key"
          ; docker_image = Some "snark-coordinator-image"
          ; git_build = None
          ; worker_nodes = 4
          }
    ; seed_nodes =
        [ { node_name = "seed-node-0"
          ; account_name = "seed-node-0-key"
          ; docker_image = Some "seed-image-0"
          ; git_build = None
          }
        ]
    ; txpool_max_size = 10_000_000
    ; snark_worker_fee = "0.0001"
    ; proof_config =
        { proof_config_default with
          work_delay = Some 1
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.small
        }
    }

  let private_keys =
    [ "EKEGuARLLw4uxXQ1WLL75HQhZpYSMqiXSc5Y5rbNFC7JvwWT6vgr"
    ; "EKF7fXWzfSCmBUXU6nDXMvHuVFQWae4rRwvjALybczfe3rVk3893"
    ; "EKEq5fbQzUyvuzPLb1mdd9McpAbXX8cuyJVHSYaCurnyQS6xYFvx"
    ; "EKDrCY8JTBqscUz992LjZs8Jbf7LRVmH5XzCPeoGAveMvo5ryoZJ"
    ; "EKDp3HVFL6PfDPuXeLnLzBq1cEbv1j18jWynPuSwFBgRHard1LFP"
    ; "EKF8miHH6qJY5YTncLNFJZzpaBm3GCkH9VZMNS15CxdgLPp8Y19D"
    ; "EKEp3pmqba7oBRnetJvmyFev9gEU6bGe5ELBDcBgYYP9gXrZadJ3"
    ; "EKDkDNB3cDhfjWkfH1t5WnkiH92NQmdYpnNE3HybTzcm5ncQsW6o"
    ; "EKDmK3a1bnaNu7g1dJM2X2coLXDgWAfLmG5kYmyxHHTDpd4FqXFE"
    ]

  let libp2p_keypairs =
    List.map ~f:Yojson.Safe.from_string
      [ {json|
        {
          "box_primitive": "xsalsa20poly1305",
          "pw_primitive": "argon2i",
          "nonce": "7NJv3URmZRNFvGp3wjbfKNtGsJRLXoqZewJenM9",
          "pwsalt": "8nLZQAJZBaFgKz9kNjs6kj6HAPnJ",
          "pwdiff": [
            134217728,
            6
          ],
          "ciphertext": "8SpinAQfG7vhvpceA4bPoyU3v3CoiJcNA75JZr5EWb9631biapTLX2AUryDyMtVYYtV26ahf8NWEYJsPbeLmNtszumPBbzozGcasQTJGCVa7EacEoCTGCLVpgVZphRDkPHFbpgGTUpFTgaxa4NpUpPtrkUFTpDtEgY8dtpC27RHyj83jS8GCrfznMqYKWSiGCMfBfX5K3KH2Z1PQZB6iL28cqbYx3YnAf4wQNFyemWfH7MzBzhRLXX6CHqWd5m71fUUuv5F2C9TLqeqbD75ZKbikrhNY43UDPEsgC"
        }
      |json}
      ; {json|
        {
          "box_primitive": "xsalsa20poly1305",
          "pw_primitive": "argon2i",
          "nonce": "6ogEKiFNXwko1WELXrLsjNovy7WWhm5qkdX7dDR",
          "pwsalt": "BLeWoEHTgFags57xEgbQvT5FYprq",
          "pwdiff": [
            134217728,
            6
          ],
          "ciphertext": "8NCrBdZbtQ9JTwTj9a1GWbQihjMXUZnotuctEyEq5xv6aN3Pecf2o54skHB6ezqeuhD5xnQSTjvG7hh15UKo6QJFongyVZsA5DxvLYcgXWbT26j8UzihMByuY1CzsF3zgwpkYLha63VwJT4irqM9vkD1YeaGC9wjLrXdiVWML9bXvMpE2g7YgSETdLsPCGBbAmg1FSg26gkWoVEnkHPaajagqtMuS9N2nJxjLk3w55V9PbkzvzcBW2134mro6MJgsp9BYdLkDjZMyRw7FtHcWm6HvTXML2rw78QXz"
        }
      |json}
      ; {json|
        {
          "box_primitive": "xsalsa20poly1305",
          "pw_primitive": "argon2i",
          "nonce": "8rQDwmqSnZMiaYPXHhVpimLU716M4pGnebMeE7W",
          "pwsalt": "BbWDiSvA7wPkzsGLMepeQVV5o7HJ",
          "pwdiff": [
            134217728,
            6
          ],
          "ciphertext": "8VZJzft4R7EH7Fawgaxb1hERPztsaKURHtHkFTH1L2vmkJtPoUGQecvFCePXaAnK5LzLmBkczSNAxACmmt2ojjGXnyCVTFgjiaUKHfQ244ur2jBEQp2kkz6ZTgZDZZ2UH4WcsamPJyjmnBCNSP8B7C3w2pgarpozT49w9i87KuYJWJywRKytoxHM747ydSNuDo3ooQrNewhgbJV6S71ikFYdMQc9ejKZDMv6n4zPj8c913TYj1JQSgKA14gegaGAZZtdRXwgJCKxQW4WVyeLRzNMeLkEyn9kND85a"
        }
      |json}
      ; {json|
        {
          "box_primitive": "xsalsa20poly1305",
          "pw_primitive": "argon2i",
          "nonce": "6wwcrYF73ZdxRPAM4PDRhGY8QMRYdgEJDQ5jVVu",
          "pwsalt": "A3xzWd5eUT9xrQkGF2xrKdYbm2d9",
          "pwdiff": [
            134217728,
            6
          ],
          "ciphertext": "7znhmqfvuUGPDE4js899VGVXv4tHd6LSXZCmnfCj14642KjzA4BcLY9maJiVaq5YCpUhPLVRjMPWDnovoAb5BKLmcbVywvPFSDREbhKdBh24u3z3wYzphAr9vZkPJiDNRXhFZ7b9JPoBchdJT4RZxKsHBbbpBmhBDuqM395YaPF1d2jPg5P5quivK98BLvX26SiJ8KAeswKk5YsoC3irA4PbZ5E7AQ5TfRCZj7k8c2g5f6awn18fcg4xt6hUwZ8o3usuqNX62HXDhETjGfXfYUvsam25522vj7Pzu"
        }
      |json}
      ; {json|
        {
          "box_primitive": "xsalsa20poly1305",
          "pw_primitive": "argon2i",
          "nonce": "7r3DGH71WaBsGA2LXV1RWNys5Vj3rGsLxiAeUxi",
          "pwsalt": "8NQcBj9grs7Gx8L77C16XXcjTvPD",
          "pwdiff": [
            134217728,
            6
          ],
          "ciphertext": "934bNqreFhzuC36gpi8j5tAiL38huhwkdTgPR3CfMy7GPS1611ryVHGtoEayS1h7m77VdHMTvP5kgX5ZpExk2qAP4Rd1Zac2iVB9ZGUDmnSrR4Lp7fthYPmMPEzKtyXBMszjzFcLoiTiyYc18a8ZgwG14GvMvED8dHQz1cdHWzJBTptXQtMzd12J7NSsnBcqP8ZKrF68G3LWE6ehck6Q1wC11jAwwzq4tiWLgQpf4z2hU7tbdMJjMFbP3pNUPX2BeV8eUcsn8Jd16jwyqdWzSXDj1Kj5rAPo3V7eA"
        }
      |json}
      ; {json|
        {
          "box_primitive": "xsalsa20poly1305",
          "pw_primitive": "argon2i",
          "nonce": "7CWMdMioqAXuCbXAGCySnNyvHNv3biiwtephci8",
          "pwsalt": "9bjDaPFvjDQWP9nycZWG4wWTsutJ",
          "pwdiff": [
            134217728,
            6
          ],
          "ciphertext": "8XBiDBr2dMwFTwvnHE4RsQDYVL5ycHAuZATskMURr3wmAWhpqfMJUnhQmVk6fJgiVzcfqks6ha2qhNCcv6BTxp5MCgKSHT5v4q4Ei89HPRUxthGrvWzf9xwzyCn1gcZyK25v5VhUFFwx2U7pG89iVaGHrwMMDH5onGTMUWJ5LVwRZhbp7mfraTYPZPanhBQz3Dqw9z21SYbvaS23q59D9swrYVB9Ncu7kjh7exteqXCEwmPgjDJiTSv78VCNgWAxB1tRFejqwMUuHJQVZTHnUcAtirGYz3w4iagGQ"
        }
      |json}
      ; {json|
        {
          "box_primitive": "xsalsa20poly1305",
          "pw_primitive": "argon2i",
          "nonce": "8dk4cDaooY3yc3rf149wucqeEbb89FmoCMnXu97",
          "pwsalt": "Ap3ew2UusjQa973JYv7LJYUtugde",
          "pwdiff": [
            134217728,
            6
          ],
          "ciphertext": "8KVBFy4cc4E4JCgvGQbH6k32nxzN4JD12YMJmU8UiGg7m6VVPrYxA1HNnxtzNabkvRZQA9s2fhiGxDqyyZuxch27KFKBUYwtNDsFquCx2uQPM1aTUMPDmDnduNVy4ZjaSPBVwqGcTjLqVTjGzsMj3oW6ASMoBJB7E94UekNuLQwMz5iyawzQPshBKdcCauL97mKyzPM2pyWeYCxBXAuCLopsqq1CtsZCdiGXH1Rvx6uuLJDQwL2N5vHeZFpULTuo1kYqry8iVra3Yfic83vHcsaY2a9MPm1pKoyAM"
        }
      |json}
      ; {json|
        {
          "box_primitive": "xsalsa20poly1305",
          "pw_primitive": "argon2i",
          "nonce": "7LrW1q7Lvg5vQD5vgL1eKnAT157WdnJHnS5u5Uv",
          "pwsalt": "AnZ678uLBtfzwryiZrzHFSc2CB3d",
          "pwdiff": [
            134217728,
            6
          ],
          "ciphertext": "8xtTBGmEZWKa3PQtVF47BWJk2u6saHpZ7mo4e3b1nLJNUmLZoUq5cg8MyDWntsqkTQiiixWLWrnjV192e4qy1ULF4CywYWRz5xGHGeFVUVj88gJvLQ9gqQKjbA39mTB29jjVhyyUbmoMi7FALLYx6p9h7rbAWTam3a3QCmg4nUksqKSDcxyihP1QFtfHZb7DxcBoYZUb5LDA5Xp7bu92NkDZmmn4VHtRDmtxv7VoqATmeL3NhypTbgqwfCAj2PxB28wL8STLCwtB8uqxqxRTA8gRJ7gpMEM1Js4fm"
        }
      |json}
      ; {json|
        {
          "box_primitive": "xsalsa20poly1305",
          "pw_primitive": "argon2i",
          "nonce": "7fKJMu1E7Qny5ma4EuRiLFXQpoTMv6b8GU9E3jt",
          "pwsalt": "8z7PecFQ7CezTQjmbdm4NG6sFTSy",
          "pwdiff": [
            134217728,
            6
          ],
          "ciphertext": "7GBDTTuhwbWME11jYZkjsCguJgfzR6NcejpJbvsBiGiyWbzvaQrEfTmSd4KaVZkp6UQZ8U3QK54WSW6x1mFPoJmDT2xGHcekTuBccWe5KSU1MEtxhtmbRyWkpT14T22Rrt4b5f4XimySxFAhnex6vwwZgKGANAmHSvNp9mEqaVXcPS2VuniyTsN72wMjg8uHM4jo3YALDKWXb8t4uhZTv7QQw7N51gfYEBkcZxfXAWdBK75cMGSK2VgXgxFrCKSE81D76xBBqdn2nPLZQYW2yqL9MrjaMoaj7bP9G"
        }
      |json}
      ]

  let libp2p_peerids =
    [ "12D3KooWJE7cTbqhsY1qpoXeXEFhEHu14FVJEJ69brG6mkbvtVuP"
    ; "12D3KooWBEwyZgnSojuUSeU8oSwmAdPYoA2Pn8uqMPCdWHNTjx8h"
    ; "12D3KooWEMRzv3RKHsMgFqmFEZAQ12c4QhRsg4J8uYye5wWRzQA6"
    ; "12D3KooWE9Jw7s97bEnDJCen4v2sZGREH6jQfKso7Qp3kF7WxU75"
    ; "12D3KooWP5ae8JYBVdX3KnsnfW8ohn3M6FCBEyitSrC4h9Vy8cvQ"
    ; "12D3KooWL85m2z7hrvg6NMtE9ibE44mBDjnuqYSWwhwJMPQe6gtD"
    ; "12D3KooWLTdMy4Jt2zAT6JsgnmVznB2zvYNr2eybVGumdhuhgN5U"
    ; "12D3KooWECCM7imLRwh7RExK64Vwf14edwctq7U8ubZ2muZUuXgE"
    ; "12D3KooWJnNwLdE82a2WcSvkpLMHicL3onayZJaSEk1M1uPkmbH7"
    ]

  let%test_unit "topology_of_test_config" =
    let open Yojson.Safe in
    let topology =
      topology_of_test_config test_config private_keys libp2p_keypairs
        libp2p_peerids
      |> Topology.to_yojson
    in
    print_endline "=== Topology ===" ;
    topology |> pretty_to_string |> print_endline ;
    let empty_node_0 = Util.member "empty-node-0" topology in
    let empty_node_1 = Util.member "empty-node-1" topology in
    let pk_0 = Util.member "pk" empty_node_0 in
    let sk_0 = Util.member "sk" empty_node_0 in
    let kp_0 = Util.member "libp2p_keypair" empty_node_0 in
    let pk_1 = Util.member "pk" empty_node_1 in
    let sk_1 = Util.member "sk" empty_node_1 in
    let kp_1 = Util.member "libp2p_keypair" empty_node_1 in
    let ( = ) = equal in
    assert (
      (* same public + private keys *)
      (not (pk_0 = `Null))
      && pk_0 = pk_1 && sk_0 = sk_1
      (* different libp2p keys *)
      && not (kp_0 = kp_1) )
end
