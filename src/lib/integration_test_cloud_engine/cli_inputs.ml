open Cmdliner

module Cluster_config = struct
  type t =
    { cluster_id : string
    ; cluster_name : string
    ; cluster_region : string
    ; cluster_zone : string
    }
end

type t =
  { mina_automation_location : string; cluster_config : Cluster_config.t }

let term =
  let mina_automation_location =
    let doc =
      "Location of the Mina automation repository to use when deploying the \
       network."
    in
    let env = Arg.env_var "MINA_AUTOMATION_LOCATION" ~doc in
    Arg.(
      value & opt string "./automation"
      & info
          [ "mina-automation-location" ]
          ~env ~docv:"MINA_AUTOMATION_LOCATION" ~doc)
  in
  let cluster_id_arg =
    let doc = "Identifier of the cluster in which the test should run" in
    Arg.(
      value
        (opt string Constants.default_cluster_id (info [ "cluster-id" ] ~doc)))
  in
  let cluster_name_arg =
    let doc = "Name of the cluster in which the test should run" in
    Arg.(
      value
        (opt string Constants.default_cluster_name
           (info [ "cluster-name" ] ~doc) ))
  in
  let cluster_region_arg =
    let doc = "Region of the cluster in which the test should run" in
    Arg.(
      value
        (opt string Constants.default_cluster_region
           (info [ "cluster-region" ] ~doc) ))
  in
  let cluster_zone_arg =
    let doc = "Zone of the cluster in which the test should run" in
    Arg.(
      value
        (opt string Constants.default_cluster_zone
           (info [ "cluster-zone" ] ~doc) ))
  in
  let cons_inputs mina_automation_location cluster_id cluster_name cluster_zone
      cluster_region =
    { mina_automation_location
    ; cluster_config =
        { cluster_id; cluster_name; cluster_zone; cluster_region }
    }
  in
  Term.(
    const cons_inputs $ mina_automation_location $ cluster_id_arg
    $ cluster_name_arg $ cluster_zone_arg $ cluster_region_arg)
