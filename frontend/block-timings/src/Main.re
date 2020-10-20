module These = {
  type t('a, 'b) =
    | This('a)
    | That('b)
    | Those('a, 'b);
};
open These;

module BlockLifetime = {
  module Instant = {
    /// When and where an event occurred
    type t = {
      time: Js.Date.t,
      podRealName: string,
    };
  };

  module Entry = {
    module Rendered = {
      /// A fully-rendered entry corresponds to one block that is produced at
      /// some instant and received at others
      type t = {
        stateHash: string,
        produced: Instant.t,
        received: array(Instant.t),
      };
    };

    /// A (partially) complete entry is either the instant a block was produced
    /// or a list of instants that a block was received
    type t = These.t([ | `Produced(Instant.t)], list(Instant.t));

    let render: (t, string) => option(Rendered.t) =
      (entry: t, stateHash: string) => {
        switch (entry) {
        | This(`Produced(produced)) =>
          Some({Rendered.stateHash, produced, received: [||]})
        | That(_) =>
          Js.log(
            Printf.sprintf(
              "Couldn't find produced for one of the blocks %s, skipping",
              stateHash,
            ),
          );
          None;
        | Those(`Produced(produced), received) =>
          Some({
            Rendered.stateHash,
            produced,
            received: Array.of_list(received),
          })
        };
      };
  };

  module Rendered = {
    type t = array(Entry.Rendered.t);
  };

  /// We map state-hashes to partially complete entries as we build up the data
  type t = Js.Dict.t(Entry.t);

  let empty = () => Js.Dict.empty();

  let produced = (t: t, ~stateHash: string, ~instant: Instant.t) => {
    let set = Js.Dict.set(t, stateHash);
    let x = `Produced(instant);
    switch (Js.Dict.get(t, stateHash)) {
    | None => set(This(x))
    | Some(This(_))
    | Some(Those(_, _)) =>
      Js.log(
        "WARNING: We couldn't have produced a block with the same stateHash more than once, ignoring because we're assuming this is just a duplicate entry",
      );
      ();
    | Some(That(y)) => set(Those(x, y))
    };
  };

  let received = (t: t, ~stateHash: string, ~instant: Instant.t) => {
    let set = Js.Dict.set(t, stateHash);
    switch (Js.Dict.get(t, stateHash)) {
    | None => set(That([instant]))
    | Some(This(x)) => set(Those(x, [instant]))
    | Some(That(y)) => set(That([instant, ...y]))
    | Some(Those(x, y)) => set(Those(x, [instant, ...y]))
    };
  };

  let render = (t: t) => {
    let unsafeGet =
      fun
      | None => failwith("expected some")
      | Some(x) => x;
    Js.Dict.keys(t)
    |> Array.map(key => Entry.render(Js.Dict.get(t, key) |> unsafeGet, key))
    |> Array.to_list
    |> List.map(
         fun
         | None => []
         | Some(x) => [x],
       )
    |> List.concat
    |> Array.of_list;
  };
};

/// Metadata from google logs "reflects" type information. Use these wrappers to workaround it
module Reflected = {
  module String = {
    type t = {
      kind: string,
      stringValue: string,
    };
  };
  module Struct = {
    type structValue('a) = {fields: 'a};
    type t('a) = {
      kind: string,
      structValue: structValue('a),
    };
  };
};

/// Bindings to @google-cloud/logging nodejs library for pulling logs from
/// stackdriver
module CloudLogging = {
  module Entry = {
    module Resource = {
      type labels = {
        pod_name: string,
        namespace_name: string,
        location: string,
        cluster_name: string,
        container_name: string,
        project_id: string,
      };
      type t = {labels};
    };
    module JsonPayload = {
      // we will obj-magic this placeholder to the right type depending on the event_id
      type placeholder;
      type fields = {
        event_id: option(Reflected.String.t),
        metadata: placeholder,
      };
      type t = {fields};
    };

    module Labels = {
      type t = {
        [@bs.as "k8s-pod/app"]
        k8sPodApp: string,
      };
    };

    module Metadata = {
      type t = {
        timestamp: Js.Date.t,
        resource: Resource.t,
        jsonPayload: JsonPayload.t,
        labels: Labels.t,
      };
    };

    module Data = {
      type source = {
        [@bs.as "module"]
        module_: string,
        location: string,
      };

      type t = {
        source,
        level: string,
        message: string,
      };
    };

    type t = {
      metadata: Metadata.t,
      data: Data.t,
    };

    let eventIdExn = (log: t) => {
      switch (log.metadata.jsonPayload.fields.event_id) {
      | None =>
        failwith(
          "expected log to be a structured event, but no event_id found",
        )
      | Some(id) => id.stringValue
      };
    };
  };

  module Log = {
    type t = {name: string};

    type getEntryOptions = {
      filter: string,
      pageSize: int,
      autoPaginate: bool,
      resourceNames: array(string),
      orderBy: string,
      pageToken: option(string),
    };

    type getEntryResponse = {nextPageToken: string};

    // returns: Entries, nextPageQuery, options
    [@bs.send "getEntries"]
    external getEntries:
      (t, getEntryOptions) =>
      Promise.t(
        (
          array(Entry.t),
          Js.Null_undefined.t(getEntryOptions),
          getEntryResponse,
        ),
      );
  };

  module Logging = {
    type t;

    // set the log name for which getEntries acts upon
    [@bs.send "log"] external log: (t, string) => Log.t;

    [@bs.send "getLogs"] external getLogs: t => Promise.t(list(Log.t));
  };

  type input = {projectId: string};

  [@bs.module "@google-cloud/logging"] [@bs.new]
  external create: input => Logging.t = "Logging";

  let structuredLogFilter = (structuredLogIds) => {
    let idDisjunction =
      structuredLogIds
      |> List.map(Printf.sprintf("\"%s\""))
      |> String.concat(" OR ");
    Printf.sprintf("jsonPayload.event_id=(%s)", idDisjunction)
  };
};

// TODO: Pull the ids from `coda internal dump-structured-events`
/// Information about the specific structured log events we'll be needing to
/// pull
module StructuredLog = {
  module BlockProduced = {
    module Metadata = {
      type validated_transition = {hash: Reflected.String.t};
      type breadcrumb = {
        validated_transition: Reflected.Struct.t(validated_transition),
      };
      type t_ = {breadcrumb: Reflected.Struct.t(breadcrumb)};

      type t = Reflected.Struct.t(t_);
    };
    let id = "64e2d3e86c37c09b15efdaf7470ce879";
  };

  module BlockReceived = {
    module Metadata = {
      type t_ = {state_hash: Reflected.String.t};
      type t = Reflected.Struct.t(t_);
    };
    let id = "586638300e6d186ec71e4cf1e1808a1b";
  };

  type metadata =
    | BlockProduced(BlockProduced.Metadata.t)
    | BlockReceived(BlockReceived.Metadata.t);

  let ofLogEntry = (e: CloudLogging.Entry.t) => {
    let metadata = e.metadata.jsonPayload.fields.metadata;
    let id = CloudLogging.Entry.eventIdExn(e);
    if (id == BlockProduced.id) {
      Some(BlockProduced(Obj.magic(metadata)));
    } else if (id == BlockReceived.id) {
      Some(BlockReceived(Obj.magic(metadata)));
    } else {
      None;
    };
  };
};

module Operations = {
  module type Intf = {
    type input;
    type state;
    type output;

    // TODO: wire into toplevel cli
    let inputTerm: Cmdliner.Term.t(input);

    let init: input => state;
    let logFilter: input => string;
    let processLogEntry: state => CloudLogging.Entry.t => StructuredLog.metadata => state;
    let render: state => output;
  };

  module BlockGossipConsistency : Intf = {
    type input = unit;
    type state = BlockLifetime.t;
    type output = BlockLifetime.Rendered.t;

    let inputTerm = Cmdliner.Term.const();

    let init = (_input) => BlockLifetime.empty();

    let structuredLogIds = [
      StructuredLog.BlockProduced.id,
      StructuredLog.BlockReceived.id
    ]

    let logFilter = (_input) => CloudLogging.structuredLogFilter(structuredLogIds)

    let processLogEntry = (blockLifetimes, entry, structuredMetadata) => {
      let open CloudLogging.Entry;
      let open StructuredLog;

      let instant = BlockLifetime.Instant.{
        time: entry.metadata.timestamp,
        podRealName: entry.metadata.labels.k8sPodApp,
      };

      switch (structuredMetadata) {
      | BlockProduced(metadata) =>
        BlockLifetime.produced(
          blockLifetimes,
          ~instant,
          ~stateHash=
            metadata.structValue.fields.breadcrumb.structValue.
              fields.
              validated_transition.
              structValue.
              fields.
              hash.
              stringValue,
        )
      | BlockReceived(metadata) =>
        BlockLifetime.received(
          blockLifetimes,
          ~instant,
          ~stateHash=
            metadata.structValue.fields.state_hash.stringValue,
        )
      };

      blockLifetimes
    }

    let render = BlockLifetime.render
  };
};


// TODO: Figure out how to get bs-let/ppx to work
/// The top-level execution of this script when you run with `node`
module TopLevel = {
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
             switch(StructuredLog.ofLogEntry(e)) {
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
  }

  let run = (type input, config, module Operation: Operations.Intf with type input = input, input: input) => {
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
    let lift = (gcloudProjectId, gcloudRegion, gcloudKubernetesCluster, testnetName, startTimestamp) => TopLevel.{
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

  type operation = Operation((module Operations.Intf with type input = 'a), 'a): operation;

  // TODO: parse different choices w/ their respective cli inputs
  let op : Term.t(operation) = {
    let open Term;
    const(input => Operation((module Operations.BlockGossipConsistency : Operations.Intf with type input = Operations.BlockGossipConsistency.input), input))
      $ Operations.BlockGossipConsistency.inputTerm;
  };

  let main = {
    let open Term;
    let run = (config, Operation(opMod, input)) => TopLevel.run(config, opMod, input);
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
