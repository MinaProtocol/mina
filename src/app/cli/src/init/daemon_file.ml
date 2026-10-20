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
