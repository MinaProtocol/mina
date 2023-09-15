open Core_kernel
open Async
open Signature_lib
open Integration_test_lib
module Network_config = Network_config

(* [network_runner] is instantiated when command line args are parsed *)
let network_runner = ref None

(* [archive_image] is instantiated when command line args are parsed *)
let archive_image : string option ref = ref None

(* [config_path] is instantiated when command line args are parsed *)
let config_path = ref ""

(* [mina_image] is instantiated when command line args are parsed *)
let mina_image = ref ""

let keypairs_path = Network_config.keypairs_path

module Network_id = struct
  type t = string [@@deriving eq, yojson]
end

module Node_id = struct
  type t = string [@@deriving eq, yojson]
end

module Node_type = struct
  type t =
    | Archive_node
    | Block_producer_node
    | Seed_node
    | Snark_coordinator
    | Snark_worker
  [@@deriving eq, to_yojson]

  let to_string nt = to_yojson nt |> Yojson.Safe.to_string

  let of_yojson (t : Yojson.Safe.t) =
    match t with
    | `String nt -> (
        match nt with
        | "Archive_node" | "ArchiveNode" | "Archive" ->
            Ok Archive_node
        | "Block_producer"
        | "Block_producer_node"
        | "BlockProducerNode"
        | "BlockProducer" ->
            Ok Block_producer_node
        | "Seed_node" | "SeedNode" | "Seed" ->
            Ok Seed_node
        | "Snark_coordinator" | "SnarkCoordinator" ->
            Ok Snark_coordinator
        | "Snark_worker" | "SnarkWorker" ->
            Ok Snark_worker
        | _ ->
            Error (sprintf "Invalid node type: %s" nt) )
    | _ ->
        Error (Yojson.Safe.to_string t)

  let of_string s = of_yojson @@ `String s |> Result.ok_or_failwith

  let is_archive_node = function Archive_node -> true | _ -> false

  let is_block_producer = function Block_producer_node -> true | _ -> false

  let is_seed_node = function Seed_node -> true | _ -> false

  let is_snark_worker = function Snark_worker -> true | _ -> false

  let is_snark_coordinator = function Snark_coordinator -> true | _ -> false
end

(** Logproc takes care of these logs so we bypass them here *)
module Node_logs = struct
  type t = string [@@deriving eq]

  let to_yojson s = `String s

  let of_yojson = function
    | `String s ->
        Ok s
    | x ->
        Error (Yojson.Safe.to_string x)
end

module Network_created = struct
  type t = { network_id : Network_id.t } [@@deriving eq, of_yojson]
end

module Network_deployed = struct
  exception Invalid_entry of string

  exception Invalid_output of string

  exception Invalid_keypair of Yojson.Safe.t

  type node_info =
    { graphql_uri : string option
    ; network_id : Network_id.t
    ; network_keypair : Network_keypair.t option
    ; node_id : Node_id.t
    ; node_type : Node_type.t
    }
  [@@deriving to_yojson]

  let equal_node_info m n =
    let node_type = Node_type.equal m.node_type n.node_type in
    let network_keypair =
      Option.equal
        (fun (m : Network_keypair.t) n ->
          Public_key.equal m.keypair.public_key n.keypair.public_key
          && String.equal m.public_key n.public_key
          && String.equal m.privkey_password n.privkey_password )
        m.network_keypair n.network_keypair
    in
    let graphql = Option.equal String.equal m.graphql_uri n.graphql_uri in
    node_type && network_keypair && graphql

  let is_archive_node node_info = Node_type.is_archive_node node_info.node_type

  let is_block_producer node_info =
    Node_type.is_block_producer node_info.node_type

  let is_seed_node node_info = Node_type.is_seed_node node_info.node_type

  let is_snark_coordinator node_info =
    Node_type.is_snark_coordinator node_info.node_type

  let is_snark_worker node_info = Node_type.is_snark_worker node_info.node_type

  let network_id { network_id; _ } = network_id

  type t = node_info Core.String.Map.t [@@deriving eq]

  let network_keypair_of_yojson node_id (private_key : Yojson.Safe.t) =
    match private_key with
    | `Null ->
        None
    | `String private_key ->
        let keypair =
          Keypair.of_private_key_exn
          @@ Private_key.of_base58_check_exn private_key
        in
        Some
          (Network_keypair.create_network_keypair ~keypair_name:node_id ~keypair)
    | _ ->
        raise @@ Invalid_keypair private_key

  let graphql_uri_of_yojson (uri : Yojson.Safe.t) =
    match uri with
    | `Null ->
        None
    | `String uri ->
        Some uri
    | _ ->
        raise @@ Invalid_argument (Yojson.Safe.to_string uri)

  let of_yojson =
    let node_info_helper network_id accum : string * Yojson.Safe.t -> t =
      function
      | ( node_id
        , `Assoc
            [ ("graphql_uri", graphql_uri)
            ; ("private_key", private_key)
            ; ("node_type", `String nt)
            ] ) ->
          Core.String.Map.set accum ~key:node_id
            ~data:
              { node_id
              ; network_id
              ; node_type = Node_type.of_string nt
              ; network_keypair = network_keypair_of_yojson node_id private_key
              ; graphql_uri = graphql_uri_of_yojson graphql_uri
              }
      | node_id, t ->
          raise
          @@ Invalid_entry (sprintf "%s: %s" node_id @@ Yojson.Safe.to_string t)
    in
    function
    | `Assoc [ ("network_id", `String network_id); ("nodes", `Assoc nodes) ] ->
        Ok
          (List.fold nodes ~init:Core.String.Map.empty
             ~f:(node_info_helper network_id) )
    | t ->
        print_endline @@ Yojson.Safe.pretty_to_string t ;
        raise @@ Invalid_output (Yojson.Safe.to_string t)
end

module Node_started = struct
  type t = { network_id : Network_id.t; node_id : Node_id.t }
  [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Node_stopped = struct
  type t = { network_id : Network_id.t; node_id : Node_id.t }
  [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Archive_data_dump = struct
  type t = { data : string; network_id : Network_id.t; node_id : Node_id.t }
  [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Mina_logs_dump = struct
  type t =
    { logs : Node_logs.t; network_id : Network_id.t; node_id : Node_id.t }
  [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Precomputed_block_dump = struct
  type t = { blocks : string; network_id : Network_id.t; node_id : Node_id.t }
  [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Replayer_run = struct
  type t =
    { logs : Node_logs.t; network_id : Network_id.t; node_id : Node_id.t }
  [@@deriving eq, of_yojson]

  exception Invalid_response of string
end

module Network_status = struct
  type t = Deploy_error of string | Status of Node_id.t Core.String.Map.t
  [@@deriving eq]

  exception Invalid_status of string * string

  let of_yojson (t : Yojson.Safe.t) =
    match t with
    | `Assoc [ ("deploy_error", `String error) ] ->
        Ok (Deploy_error error)
    | `Assoc statuses ->
        let status_map =
          let open Core.String.Map in
          List.fold statuses ~init:empty ~f:(fun acc -> function
            | node_id, `String status ->
                set acc ~key:node_id ~data:status
            | node_id, error ->
                raise @@ Invalid_status (node_id, Yojson.Safe.to_string error) )
        in
        Ok (Status status_map)
    | _ ->
        Error (Yojson.Safe.to_string t)
end

module Command_output = struct
  type t =
    | Network_created of Network_created.t
    | Network_deployed of Network_deployed.t
    | Network_destroyed
    | Network_status of Network_status.t
    | Node_started of Node_started.t
    | Node_stopped of Node_stopped.t
    | Archive_data_dump of Archive_data_dump.t
    | Mina_logs_dump of Mina_logs_dump.t
    | Precomputed_block_dump of Precomputed_block_dump.t
    | Replayer_run of Replayer_run.t
  [@@deriving eq, of_yojson]
end

module Arg_type = struct
  let bool = "bool"

  let int = "int"

  let string = "string"

  exception Invalid_arg_type of Yojson.Safe.t

  let arg_type (t : Yojson.Safe.t) =
    match t with
    | `Bool _ ->
        bool
    | `Int _ ->
        int
    | `String _ ->
        string
    | _ ->
        raise @@ Invalid_arg_type t
end

module Config_file = struct
  type t = { version : int; actions : action list } [@@deriving eq, yojson]

  and action = { name : string; args : Yojson.Safe.t; command : string }

  exception Invalid_version of Yojson.Safe.t

  exception Invalid_actions of Yojson.Safe.t

  exception Invalid_args of Yojson.Safe.t

  exception Invalid_arg_type_should_be_string of string * Yojson.Safe.t

  exception Invalid_list of Yojson.Safe.t list

  exception Invalid_command of Yojson.Safe.t

  exception Invalid_args_num of string * string list * string list

  exception Missing_arg of string * string * string

  exception Invalid_arg_type of string * string * Yojson.Safe.t * string

  let version config =
    match Yojson.Safe.Util.member "version" config with
    | `Int version ->
        version
    | t ->
        raise @@ Invalid_version t

  let action_name action =
    let open Yojson.Safe in
    Util.member "name" action |> to_string

  let action name config =
    let open Yojson.Safe in
    match Util.member "actions" config with
    | `List actions ->
        List.find_exn actions ~f:(fun action ->
            Util.member "name" action |> equal @@ `String name )
    | t ->
        raise @@ Invalid_actions t

  let args_of_action action =
    let open Yojson.Safe in
    let a_list =
      match Util.member "args" action with
      | `Assoc a_list ->
          a_list
      | t ->
          raise @@ Invalid_args t
    in
    List.map a_list ~f:(function
      | name, `String type_name ->
          (name, type_name)
      | name, t ->
          raise @@ Invalid_arg_type_should_be_string (name, t) )

  let raw_cmd action =
    match Yojson.Safe.Util.member "command" action with
    | `String raw_cmd ->
        raw_cmd
    | cmd ->
        raise @@ Invalid_command cmd

  let arg_to_flag s = "--" ^ String.substr_replace_all s ~pattern:"_" ~with_:"-"

  let validate_arg_type arg_typ arg_value =
    String.equal arg_typ @@ Arg_type.arg_type arg_value

  let validate_args ~args ~action =
    let arg_list = args_of_action action in
    let () =
      let open List in
      if not (length arg_list = length args) then
        let input_args = map args ~f:fst in
        let action_args = map ~f:fst @@ args_of_action action in
        raise @@ Invalid_args_num (action_name action, input_args, action_args)
    in
    let rec aux = function
      | [] ->
          true
      | (arg_name, arg_type) :: rest ->
          let arg_value =
            try
              List.find_map_exn args ~f:(fun (name, value) ->
                  Option.some_if (String.equal name arg_name) value )
            with Not_found_s _ ->
              raise @@ Missing_arg (action_name action, arg_name, arg_type)
          in
          if validate_arg_type arg_type arg_value then aux rest
          else
            raise
            @@ Invalid_arg_type
                 (action_name action, arg_name, arg_value, arg_type)
    in
    aux arg_list

  let eliminate_bool_arg raw_cmd pattern =
    let pattern = " " ^ pattern in
    String.substr_replace_all raw_cmd ~pattern ~with_:""

  let rec interpolate_args ~args raw_cmd =
    match args with
    | [] ->
        raw_cmd
    | (arg, value) :: args -> (
        let pattern = sprintf "{{%s}}" arg in
        match value with
        | `Bool b ->
            if b then
              interpolate_args ~args
              @@ String.substr_replace_all raw_cmd ~pattern
                   ~with_:(arg_to_flag arg)
            else eliminate_bool_arg raw_cmd pattern |> interpolate_args ~args
        | _ ->
            interpolate_args ~args
            @@ String.substr_replace_all raw_cmd ~pattern
                 ~with_:(Yojson.Safe.to_string value |> Util.drop_outer_quotes)
        )

  let prog_and_args ~args action =
    let raw_cmd = raw_cmd action in
    let cmd_list = interpolate_args ~args raw_cmd |> String.split ~on:' ' in
    (List.hd_exn cmd_list, List.tl_exn cmd_list)

  let evaluate_network_runner prog = Option.value !network_runner ~default:prog

  let run_command ?(suppress_logs = false) ?(timeout_seconds = 420) ?(dir = ".")
      ~config ~args cmd_name =
    let logger = Logger.create () in
    let config = Yojson.Safe.from_file config in
    let version = version config in
    let action = action cmd_name config in
    let action_args = args_of_action action in
    let () = assert (validate_args ~args ~action) in
    let prog, arg_values = prog_and_args ~args action in
    let prog = evaluate_network_runner prog in
    let cmd = String.concat ~sep:" " (prog :: arg_values) in
    [%log trace] "Running config command: %s" cmd ;
    let%map output =
      Util.run_cmd_or_error_timeout ~suppress_logs ~timeout_seconds dir prog
        arg_values
    in
    match output with
    | Ok output ->
        if not suppress_logs then
          [%log spam] "Successful command execution\n Command: %s\n Output: %s"
            cmd output ;
        Ok output
    | Error err ->
        if not suppress_logs then [%log error] "Failed to run command: %s" cmd ;
        Error
          (sprintf
             "Failed to run command: %s\n\
             \ Config version: %d\n\
             \ Expected arg types:\n\
             \     %s\n\
             \ Attempted args:\n\
             \     %s\n\
             \ Output: %s\n"
             cmd version
             ( String.concat ~sep:", "
             @@ List.map action_args ~f:(fun (name, type_name) ->
                    name ^ ": " ^ type_name ) )
             ( String.concat ~sep:", "
             @@ List.map args ~f:(fun (name, value) ->
                    name ^ " = " ^ Yojson.Safe.to_string value ) )
             (Error.to_string_hum err) )
end
