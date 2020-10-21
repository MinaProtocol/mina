// TODO: Figure out how to get bs-let/ppx to work
open CloudLogging;

[@bs.module "fs"] external writeFileSync: string => string => unit = "writeFileSync";

type inputs = {
  gcloudProjectId: string,
  gcloudRegion: string,
  gcloudKubernetesCluster: string,
  testnetName: string,
  startTimestamp: string,
  outputFile: string
};

let foldLogEntries = (f, init, log, request) => {
  let open ReadableStream;
  let promise_ref = ref(Promise.resolved(init));
  Promise.exec((resolve) => {
    Js.log("ho");
    let _ =
      Log.getEntriesStream(log, request)
      |> onError(err => resolve(Error(err)))
      |> onData(entry =>
           switch(StructuredLogs.ofLogEntry(entry)) {
           | None =>
               failwith(
                 Printf.sprintf(
                   "Invalid structured log returned from filter query; unexpected event id \"%s\"",
                   Entry.eventIdExn(entry),
                 ),
               )
           | Some(log) =>
               promise_ref := promise_ref^ -> Promise.flatMap((acc) => f(acc, entry, log))
           }
         )
      |> onEnd(() => resolve(Ok(promise_ref^)))
  })
};

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

let run = (config, OperationIntf.OperationWithInput((module Operation), input)) => {
  let {gcloudProjectId, outputFile, _} = config;
  let logging = CloudLogging.create({projectId: gcloudProjectId});
  let log = Logging.log(logging, {j|projects/$gcloudProjectId/logs/stdout|j});
  let state = Operation.init(input);
  Js.log(globalLogFilter(config) ++ Operation.logFilter(input));
  let request = Log.{
    resourceNames: [|{j|projects/$gcloudProjectId|j}|],
    filter: String.concat("\n", [globalLogFilter(config), Operation.logFilter(input)])
  };

  Js.log("Starting scrape from cloud logging");
  foldLogEntries(Operation.processLogEntry, state, log, request) -> Promise.get(fun
    | Error(err) => {
        Js.log("der she blows");
        failwith(err);
    }
    | Ok(promise) => {
        Js.log("and a bottle of rum");
        promise -> Promise.get(resultingState => {
          Js.log({j|All done. Writing results to "$outputFile".|j});
          let output = switch(Js.Json.stringifyAny(Operation.render(resultingState))) {
          | Some(json) => json
          | None => failwith("failed to render resulting operation state to json")
          };
          writeFileSync(outputFile, output);
        })
      }
  );
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
    let outputFile =
      value
      & opt(string, "results.json")
      & info(
          ~doc="File to output json results to.",
          ~docv="filename",
          ["output", "o"]
        );

    // configuration term (important: lift argument order needs to match term application order)
    let lift = (gcloudProjectId, gcloudRegion, gcloudKubernetesCluster, testnetName, startTimestamp, outputFile) => {
      gcloudProjectId,
      gcloudRegion,
      gcloudKubernetesCluster,
      testnetName,
      startTimestamp,
      outputFile
    };
    Term.(
      const(lift)
        $ gcloudProjectId
        $ gcloudRegion
        $ gcloudKubernetesCluster
        $ testnetName
        $ startTimestamp
        $ outputFile)
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
let () = {
  let exitStatus = Cmdliner.Term.(exit_status_of_result(eval(Cli.main)));
  if(exitStatus > 0) {
    exit(exitStatus);
  }
  Js.log("yo");
  // otherwise, wait for promise in main to terminate
};
