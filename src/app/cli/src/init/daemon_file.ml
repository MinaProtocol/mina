open Core_kernel
module YJ = Yojson.Safe

(** The [daemon] sections of the configuration files, latest file first, each
    with the name of the file it came from. *)
type t = (string * YJ.t) list

let of_config_jsons config_jsons : t =
  List.rev_filter_map config_jsons ~f:(fun (config_file, config_json) ->
      Option.map
        YJ.Util.(to_option Fn.id (YJ.Util.member "daemon" config_json))
        ~f:(fun daemon_config -> (config_file, daemon_config)) )

let maybe_from_config ~logger (rev_daemon_configs : t) (type a)
    (f : YJ.t -> a option) (keyname : string) (actual_value : a option) :
    a option =
  let open Option.Let_syntax in
  let open YJ.Util in
  match actual_value with
  | Some v ->
      Some v
  | None ->
      (* Load value from the latest config file that both
         * has the key we are looking for, and
         * has the key in a format that [f] can parse.
      *)
      let%map config_file, data =
        List.find_map rev_daemon_configs ~f:(fun (config_file, daemon_config) ->
            let%bind json_val =
              to_option Fn.id (member keyname daemon_config)
            in
            let%map data = f json_val in
            (config_file, data) )
      in
      [%log debug] "Key $key being used from config file $config_file"
        ~metadata:
          [ ("key", `String keyname); ("config_file", `String config_file) ] ;
      data

let or_from_config ~logger rev_daemon_configs map keyname actual_value ~default
    =
  match
    maybe_from_config ~logger rev_daemon_configs map keyname actual_value
  with
  | Some x ->
      x
  | None ->
      [%log trace] "Key '$key' not found in the config file, using default"
        ~metadata:[ ("key", `String keyname) ] ;
      default

(** A key of the configuration files' [daemon] sections, with the decoder for
    its value. *)
type 'a key = { name : string; decode : YJ.t -> 'a option }

let find ~logger t key actual_value =
  maybe_from_config ~logger t key.decode key.name actual_value

let find_or_default ~logger t key actual_value ~default =
  or_from_config ~logger t key.decode key.name actual_value ~default

module Key = struct
  let int name = { name; decode = YJ.Util.to_int_option }

  let bool name = { name; decode = YJ.Util.to_bool_option }

  let string name = { name; decode = YJ.Util.to_string_option }

  let node_status_url = string "node-status-url"

  let work_reassignment_wait = int "work-reassignment-wait"

  let log_snark_work_gossip = bool "log-snark-work-gossip"

  let log_txn_pool_gossip = bool "log-txn-pool-gossip"

  let log_block_creation = bool "log-block-creation"

  let snark_worker_parallelism = int "snark-worker-parallelism"

  let block_producer_key = string "block-producer-key"

  let block_producer_password = string "block-producer-password"

  let min_connections = int "min-connections"

  let max_connections = int "max-connections"

  let validation_queue_size = int "validation-queue-size"

  let stop_time = int "stop-time"

  let stop_time_interval = int "stop-time-interval"
end
