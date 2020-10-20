// TODO: Figure out how to get bs-let/ppx to work
open CloudLogging;

module P = Promise;

type inputs = {
  gcloudProjectId: string,
  gcloudRegion: string,
  gcloudKubernetesCluster: string,
  testnetName: string,
  startTimestamp: string
};

let maxLogPulls = 6;

let globalLogFilter = (config) => {
  let {gcloudProjectId, gcloudRegion, gcloudKubernetesCluster, testnetName, startTimestamp} = config;
  {j|
resource.type="k8s_container"
resource.labels.project_id="$gcloudProjectId"
resource.labels.location="$gcloudRegion"
resource.labels.cluster_name="$gcloudKubernetesCluster"
resource.labels.namespace_name="$testnetName"
resource.labels.container_name="coda"
timestamp > "$startTimestamp"|j};
};

let rec foldLogEntries = (i, log, request, acc, f) => {
  Log.getEntries(log, request)
  -> P.map(((es, options, _)) => {
       let acc =
         Array.fold_left((acc, e) =>
           switch(StructuredLogs.ofLogEntry(e)) {
           | None =>
               failwith(
                 Printf.sprintf(
                   "Invalid structured log returned from filter query; unexpected event id \"%s\"",
                   Entry.eventIdExn(e),
                 ),
               )
           | Some(log) => f(acc, e, log)
         }, acc, es);

       Js.log("Finished processing entries for this page");

       (options, acc)
     })
  -> P.flatMap(((options, acc)) => {
       let pageToken =
         Js.Null_undefined.toOption(options)
         |> Js.Option.andThen((. opt) => opt.Log.pageToken);
       if(Js.Option.isNone(pageToken)) {
         Js.log("All logs were processed");
         P.resolved(acc);
       } else if(i >= maxLogPulls) {
         Js.log("Hit max log pulls -- refusing to continue");
         P.resolved(acc);
       } else {
         foldLogEntries(i + 1, log, {...request, pageToken}, acc, f);
       };
     });
};

let run = (config, OperationIntf.OperationWithInput((module Operation), input)) => {
  let {gcloudProjectId, _} = config;
  let logging = CloudLogging.create({projectId: gcloudProjectId});
  let log = Logging.log(logging, {j|projects/$gcloudProjectId/logs/stdout|j});
  let state = Operation.init(input);
  let request = Log.{
    resourceNames: [|{j|projects/$gcloudProjectId|j}|],
    pageSize: 100,
    autoPaginate: false,
    orderBy: "timestamp desc",
    pageToken: None,
    filter: globalLogFilter(config) ++ Operation.logFilter(input)
  };

  Js.log("Starting scrape from cloud logging");

  foldLogEntries(0, log, request, state, Operation.processLogEntry)
  -> P.get(state => Js.log2("All done", Js.Json.stringifyAny(Operation.render(state))));
};

module Cli = {
  open Cmdliner;

  let config = {
    let open Arg;

    // optional terms
    let gcloudProjectId =
      value
      & opt(string, "o1labs-192920")
      & info(
          ~doc="Google cloud project id of the project the network was deployed in.",
          ~docv="project-id",
          ~env=env_var("GCLOUD_PROJECT_ID"),
          ["gcloud-project-id"]
        );
    let gcloudRegion =
      value
      & opt(string, "us-east1")
      & info(
          ~doc="Google cloud region the network was deployed in.",
          ~docv="region",
          ~env=env_var("GCLOUD_REGION"),
          ["gcloud-region"]
        );
    let gcloudKubernetesCluster =
      value
      & opt(string, "coda-infra-east")
      & info(
          ~doc="Google cloud kubernetes cluster name of the cluster the network was deployed in.",
          ~docv="cluster-id",
          ~env=env_var("GCLOUD_KUBERNETES_CLUSTER"),
          ["gcloud-kubernetes-cluster"]
        );
    let testnetName =
      required
      & opt(some(string), None)
      & info(
          ~doc="The name the network was deployed with (used as the namespace logs are queried from).",
          ~docv="name",
          ~docs="REQUIRED",
          ["testnet-name", "n"]
        );
    let startTimestamp =
      required
      & opt(some(string), None)
      & info(
          ~doc="Start timestamp of the network. Example format: \"2020-10-15T20:00:00Z\"",
          ~docv="timestamp",
          ~docs="REQUIRED",
          ["start-timestamp", "t"]
        );

    // configuration term (important: lift argument order needs to match term application order)
    let lift = (gcloudProjectId, gcloudRegion, gcloudKubernetesCluster, testnetName, startTimestamp) => {
      gcloudProjectId,
      gcloudRegion,
      gcloudKubernetesCluster,
      testnetName,
      startTimestamp
    };
    Term.(
      const(lift)
        $ gcloudProjectId
        $ gcloudRegion
        $ gcloudKubernetesCluster
        $ testnetName
        $ startTimestamp)
  };

  // TODO: parse different choices w/ their respective cli inputs
  let op : Term.t(OperationIntf.operation_with_input) = {
    let open Term;
    const(input => OperationIntf.OperationWithInput((module BlockGossipConsistency : OperationIntf.S with type input = BlockGossipConsistency.input), input))
      $ BlockGossipConsistency.inputTerm;
  };

  let main = {
    let open Term;
    let term = const(run) $ config $ op;
    let info = info(
      ~doc="Analyzes intra-network communication of testnets from StackDriver logs.",
      "block-timing"
    );
    (term, info)
  };
};

// this line is necessary to make bs-cmdliner work correctly (because nodejs stdlib weirdness)
%raw "process.argv.shift()";
let () = Cmdliner.Term.(exit(eval(Cli.main)))
