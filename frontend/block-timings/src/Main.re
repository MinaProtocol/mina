
module These = {
  type t('a, 'b) = This('a) | That('b) | Those('a, 'b)
};
open These;

module BlockLifetime = {
  module Instant = {
    type t = {
      time: Js.Date.t,
      podRealName: string
    };
  };

  module Entry = {
    type t = These.t( [ `Produced(Instant.t) ], list(Instant.t));
  };

  type t = Js.Dict.t(Entry.t);

  let empty = () => Js.Dict.empty();

  let produced = (t: t, stateHash: string, instant: Instant.t) => {
      let set = Js.Dict.set(t, stateHash);
      let x = `Produced(instant);
      switch (Js.Dict.get(t, stateHash)) {
      | None => set(This(x))
      | Some(This(_)) | Some(Those(_, _)) =>
        Js.log("WARNING: We couldn't have produced a block with the same stateHash more than once, ignoring because we're assuming this is just a duplicate entry");
        ();
      | Some(That(y)) => set(Those(x, y))
      }
  };

  let received = (t: t, stateHash: string, instant: Instant.t) => {
      let set = Js.Dict.set(t, stateHash);
      switch (Js.Dict.get(t, stateHash)) {
      | None => set(That([instant]))
      | Some(This(x)) => set(Those(x, [instant]))
      | Some(That(y)) => set(That([instant, ...y]))
      | Some(Those(x, y)) => set(Those(x, [instant, ...y]))
      }
  };
};

// TODO: Pull the ids from `coda internal dump-structured-events`
module StructuredLog = {
  module BlockProduced = {
    module Metadata = {
      type validated_transition = { hash: string };
      type breadcrumb = { validated_transition: validated_transition };
      type t = { breadcrumb: breadcrumb };
    };
    let id = "64e2d3e86c37c09b15efdaf7470ce879";
  };

  module BlockReceived = {
    module Metadata = {
      type t = { state_hash: string };
    };
    let id = "586638300e6d186ec71e4cf1e1808a1b";
  };
};

module CloudLogging = {
  module Entry = {
    module Resource = {
      type labels = {
        pod_name: string,
        namespace_name: string,
        location: string,
        cluster_name: string,
        container_name: string,
        project_id: string
      };
      type t = { labels: labels };
    };
    module JsonPayload = {
      type dummy;
      type t = { fields: dummy };
    };
    module Metadata = {
      type t = { timestamp : Js.Date.t, resource: Resource.t, jsonPayload: JsonPayload.t };
    };

    module Data = {
      type source = { [@bs.as "module"] module_: string, location: string };

      type t = { source: source, level: string, message: string };
    };

    type t = {
      metadata: Metadata.t,
      data: Data.t
    }
  };

  module Log = {
    type t = { name : string };

    type getEntryOptions = {
      filter: string,
      pageSize: int,
      autoPaginate: bool,
      resourceNames: array(string),
      orderBy: string,
      pageToken: option(string)
    };

    type getEntryResponse = {
      nextPageToken: string
    };

    // returns: Entries, nextPageQuery, options
    [@bs.send "getEntries"] external getEntries : (t, getEntryOptions) => Promise.t((array(Entry.t), getEntryOptions, getEntryResponse));
  };

  module Logging = {
    type t;

    // set the log name for which getEntries acts upon
    [@bs.send "log"] external log : (t, string) => Log.t;

    [@bs.send "getLogs"] external getLogs : t => Promise.t(list(Log.t));
  };

  type input = { projectId: string };

  [@bs.module "@google-cloud/logging"] [@bs.new] external create : input => Logging.t = "Logging";
};

// TODO: Figure out how to get bs-let/ppx to work
module Usage = {
  open CloudLogging;

  Js.log("Starting scrape from cloud logging");
  let logging = CloudLogging.create({projectId: "o1labs-192920"});

  let testnetName = "pickles-nightly";
/*Logging.getLogs(logging)
    -> P.tap(logs => Js.log2("Finished listing logs", logs))*/
    /*-> P.map(_ => Logging.log(logging, "projects/o1labs-192920/logs/stdout"))*/

  let module P = Promise;

  let log = Logging.log(logging, "projects/o1labs-192920/logs/stdout");

  let blockLifetimes = BlockLifetime.empty();

  let rec go = (i, req) => {
    Log.getEntries(log, req)
    -> P.tap(((es, _, _)) => {
      let data = Array.map(e => e.Entry.data, es);
      // TODO: Decode log data here into entries and shove them into blockLifetimes
      Js.log2("Finished getting entries for this page", sources)
    })
    -> P.flatMap(((_, {pageToken}, _)) =>
                 if (i == 0) {
                   P.resolved(())
                 } else {
                   go(i-1, { ...req, pageToken })
                 })
  };

    go(3, {
      resourceNames: [| "projects/o1labs-192920" |],
      pageSize: 100,
      autoPaginate: false,
      orderBy: "timestamp desc",
      pageToken: None,
      filter: Printf.sprintf({|resource.type="k8s_container" AND
resource.labels.project_id="o1labs-192920" AND
resource.labels.location="us-east1" AND
resource.labels.cluster_name="coda-infra-east" AND
resource.labels.namespace_name="%s" AND
resource.labels.container_name="coda" AND
(
jsonPayload.event_id = "%s" OR
jsonPayload.event_id = "%s"
)
|}, testnetName, StructuredLog.BlockProduced.id, StructuredLog.BlockReceived.id)
    }) -> P.get(_ => Js.log("All done"));
};

