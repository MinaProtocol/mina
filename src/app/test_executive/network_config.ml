open Core_kernel
open Coda_base
open Signature_lib

module Direct = struct
  type block_producer_config =
    { name: string
    ; class_: string [@key "class"]
    ; id: string
    ; private_key_secret: string
    ; enable_gossip_flooding: bool
    ; run_with_user_agent: bool
    ; run_with_bots: bool }
  [@@deriving to_yojson]

  type t =
    { cluster_name: string
    ; cluster_region: string
    ; testnet_name: string
    ; coda_image: string
    ; coda_agent_image: string
    ; coda_bots_image: string
    ; coda_points_image: string
          (* this field needs to be sent as a string to terraform, even though it's a json encoded value *)
    ; runtime_config: Yojson.Safe.t
          [@to_yojson fun j -> `String (Yojson.Safe.to_string j)]
    ; coda_faucet_amount: string
    ; coda_faucet_fee: string
    ; seed_zone: string
    ; seed_region: string
    ; log_level: string
    ; log_txn_pool_gossip: bool
    ; block_producer_key_pass: string
    ; block_producer_starting_host_port: int
    ; block_producer_configs: block_producer_config list
    ; snark_worker_replicas: int
    ; snark_worker_fee: string
    ; snark_worker_public_key: string
    ; snark_worker_host_port: int
    ; agent_min_fee: string
    ; agent_max_fee: string
    ; agent_min_tx: string
    ; agent_max_tx: string }
  [@@deriving to_yojson]

  let to_assoc t =
    let[@warning "-8"] (`Assoc assoc : Yojson.Safe.t) = to_yojson t in
    assoc
end

module Abstract = struct
  module Block_producer = struct
    type t = {balance: Currency.Balance.t}
  end

  module Images = struct
    type t = {coda: string; user_agent: string; bots: string; points: string}
  end

  module Cloud = struct
    type t =
      { cluster_id: string
      ; cluster_name: string
      ; cluster_region: string
      ; seed_zone: string
      ; seed_region: string }

    let default =
      { cluster_id= "gke_o1labs-192920_us-east1_coda-infra-east"
      ; cluster_name= "coda-infra-east"
      ; cluster_region= "us-east1"
      ; seed_zone= "us-east1-b"
      ; seed_region= "us-east1" }
  end

  type t =
    { images: Images.t
    ; cloud: Cloud.t
    ; k: int
    ; delta: int
    ; proof_level: Runtime_config.Proof_keys.Level.t
    ; txpool_max_size: int
    ; block_producers: Block_producer.t list
    ; num_snark_workers: int
    ; snark_worker_fee: string
    ; snark_worker_public_key: string }

  let render testnet_name t : (string, Keypair.t) List.Assoc.t * Direct.t =
    let { images
        ; cloud
        ; k
        ; delta
        ; proof_level
        ; txpool_max_size
        ; block_producers
        ; num_snark_workers
        ; snark_worker_fee
        ; snark_worker_public_key } =
      t
    in
    let { Cloud.cluster_id= _
        ; cluster_name
        ; cluster_region
        ; seed_zone
        ; seed_region } =
      cloud
    in
    let num_block_producers = List.length block_producers in
    let block_producer_keypairs, runtime_accounts =
      let keypairs = Array.to_list (Lazy.force Sample_keypairs.keypairs) in
      if List.length block_producers > List.length keypairs then
        failwith
          "not enough sample keypairs for specified number of block producers" ;
      let f index ({Block_producer.balance}, (pk, sk)) =
        let runtime_account =
          { Runtime_config.Accounts.pk=
              Some (Public_key.Compressed.to_string pk)
          ; sk= None
          ; balance (* delegation currently unsupported *)
          ; delegate= None }
        in
        let secret_name = "test-keypair-" ^ Int.to_string index in
        let keypair =
          {Keypair.public_key= Public_key.decompress_exn pk; private_key= sk}
        in
        ((secret_name, keypair), runtime_account)
      in
      List.mapi ~f
        (List.zip_exn block_producers
           (List.take keypairs (List.length block_producers)))
      |> List.unzip
    in
    let runtime_config =
      let open Runtime_config in
      { daemon= Some {txpool_max_size= Some txpool_max_size}
      ; genesis=
          Some
            { k= Some k
            ; delta= Some delta
            ; genesis_state_timestamp=
                Some Core.Time.(to_string_abs ~zone:Zone.utc (now ())) }
      ; proof=
          Some {level= Some proof_level}
          (* TODO: prebake ledger and only set hash *)
      ; ledger=
          Some {base= Accounts runtime_accounts; num_accounts= None; hash= None}
      }
    in
    let direct_network_config =
      let open Direct in
      let base_port = 10001 in
      let block_producer_config index (secret_name, _) =
        { name= "test-block-producer-" ^ Int.to_string (index + 1)
        ; class_= "test"
        ; id= Int.to_string index
        ; private_key_secret= secret_name
        ; enable_gossip_flooding= false
        ; run_with_user_agent= false
        ; run_with_bots= false }
      in
      { testnet_name
      ; cluster_name
      ; cluster_region
      ; seed_zone
      ; seed_region
      ; coda_image= images.coda
      ; coda_agent_image= images.user_agent
      ; coda_bots_image= images.bots
      ; coda_points_image= images.points
      ; runtime_config= Runtime_config.to_yojson runtime_config
      ; block_producer_key_pass= "naughty blue worm"
      ; block_producer_starting_host_port= base_port
      ; block_producer_configs=
          List.mapi block_producer_keypairs ~f:block_producer_config
      ; snark_worker_replicas= num_snark_workers
      ; snark_worker_host_port= base_port + num_block_producers
      ; snark_worker_public_key
      ; snark_worker_fee
          (* log level is currently statically set and not directly configurable *)
      ; log_level= "Trace"
      ; log_txn_pool_gossip=
          true
          (* these currently aren't used for testnets, so we just give them defaults *)
      ; coda_faucet_amount= "10000000000"
      ; coda_faucet_fee= "100000000"
      ; agent_min_fee= "0.06"
      ; agent_max_fee= "0.1"
      ; agent_min_tx= "0.0015"
      ; agent_max_tx= "0.0015" }
    in
    (block_producer_keypairs, direct_network_config)
end

(* this is only a partial (minimum required) implementation of the terraform json spec *)
module Terraform = struct
  let cons (type a) (key : string) (body : a) (to_yojson : a -> Yojson.Safe.t)
      =
    `Assoc [(key, to_yojson body)]

  type provider = string * string

  let provider_to_yojson (provider, alias) = `String (provider ^ "." ^ alias)

  type depends_on = provider list [@@deriving to_yojson]

  (*
  type ignore_changes =
    | All
    | Exactly of string list
  *)

  module Backend = struct
    module S3 = struct
      type t =
        { key: string
        ; encrypt: bool
        ; region: string
        ; bucket: string
        ; acl: string }
      [@@deriving to_yojson]
    end

    type t = S3 of S3.t

    let to_yojson = function S3 x -> cons "s3" x S3.to_yojson
  end

  module Block = struct
    module Terraform = struct
      type t = {required_version: string; backend: Backend.t}
      [@@deriving to_yojson]
    end

    (* should probably leave these untyped, but this covers basic keys for both google and aws *)
    module Provider = struct
      type t =
        { provider: string
        ; region: string
        ; alias: string option
        ; project: string option
        ; zone: string option }
      [@@deriving to_yojson]

      let to_yojson {provider; region; alias; project; zone} =
        cons provider () (fun () ->
            let open Option.Let_syntax in
            let field k v = (k, `String v) in
            let fields =
              [ Some (field "region" region)
              ; alias >>| field "alias"
              ; project >>| field "project"
              ; zone >>| field "zone" ]
            in
            `Assoc (List.filter_map fields ~f:Fn.id) )
    end

    module Module = struct
      type t =
        { local_name: string
        ; providers: (string * provider) list
        ; source: string
        ; args: (string * Yojson.Safe.t) list }

      let to_yojson {local_name; providers; source; args} =
        cons local_name () (fun () ->
            let const_fields =
              [ ( "providers"
                , `Assoc
                    (List.map providers ~f:(fun (k, v) ->
                         (k, provider_to_yojson v) )) )
              ; ("source", `String source) ]
            in
            `Assoc (const_fields @ args) )
    end

    module Data = struct
      type t =
        { data_source: string
        ; local_name: string
        ; args: (string * Yojson.Safe.t) list }

      let to_yojson {data_source; local_name; args} =
        cons data_source () (fun () ->
            cons local_name () (fun () -> `Assoc args) )
    end

    module Resource = struct
      type t =
        {type_: string; local_name: string; args: (string * Yojson.Safe.t) list}

      let to_yojson {type_; local_name; args} =
        cons type_ () (fun () -> cons local_name () (fun () -> `Assoc args))
    end

    type t =
      | Terraform of Terraform.t
      | Provider of Provider.t
      | Module of Module.t
      | Data of Data.t
      | Resource of Resource.t

    let to_yojson = function
      | Terraform x ->
          cons "terraform" x Terraform.to_yojson
      | Provider x ->
          cons "provider" x Provider.to_yojson
      | Module x ->
          cons "module" x Module.to_yojson
      | Data x ->
          cons "data" x Data.to_yojson
      | Resource x ->
          cons "resource" x Resource.to_yojson
  end

  type t = Block.t list [@@deriving to_yojson]
end

let seed_resource testnet_name id =
  let open Terraform in
  { Block.Resource.type_= "aws_route53_record"
  ; local_name= "seed_" ^ id
  ; args=
      [ ("zone_id", `String "${data.aws_route53_zone.selected.zone_id}")
      ; ( "name"
        , `String
            ( "seed-" ^ id ^ "." ^ testnet_name
            ^ ".${data.aws_route53_zone.selected.name}" ) )
      ; ("type", `String "A")
      ; ("ttl", `String "300")
      ; ( "records"
        , `List [`String ("${module.testnet_east.seed_" ^ id ^ "_ip}")] ) ] }

let testnet_blocks (network_config : Direct.t) =
  let open Terraform in
  [ Block.Terraform
      { Block.Terraform.required_version= "~> 0.12.0"
      ; backend=
          Backend.S3
            { Backend.S3.key=
                "terraform-" ^ network_config.testnet_name ^ ".tfstate"
            ; encrypt= true
            ; region= "us-west-2"
            ; bucket= "o1labs-terraform-state"
            ; acl= "bucket-owner-full-control" } }
  ; Block.Provider
      { Block.Provider.provider= "aws"
      ; region= "us-west-2"
      ; zone= None
      ; alias= None
      ; project= None }
  ; Block.Provider
      { Block.Provider.provider= "google"
      ; region= "us-east1"
      ; zone= Some "us-east1b"
      ; alias= Some "google-us-east1"
      ; project= Some "o1labs-192920" }
  ; Block.Module
      { Block.Module.local_name= "testnet_east"
      ; providers= [("google", ("google", "google-us-east1"))]
      ; source= "../../modules/kubernetes/testnet"
      ; args= Direct.to_assoc network_config } ]

let render network_config =
  testnet_blocks network_config
  |> Terraform.to_yojson |> Yojson.Safe.pretty_to_string
