
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
    module Rendered = {
      type t = {
        stateHash: string,
        produced: Instant.t,
        received: array(Instant.t)
      };
    };

    type t = These.t( [ `Produced(Instant.t) ], list(Instant.t));

    let render: (t, string) => option(Rendered.t) = (entry: t, stateHash: string) => {
      switch (entry) {
      | This(`Produced(produced)) => Some { Rendered.stateHash, produced, received: [||] }
      | That(_) => { Js.log(Printf.sprintf("Couldn't find produced for one of the blocks %s, skipping", stateHash)); None }
      | Those(`Produced(produced), received) => Some { Rendered.stateHash, produced, received: Array.of_list(received) }
      }
    };
  };


  module Rendered = {
    type t = array(Entry.Rendered.t);
  };

  type t = Js.Dict.t(Entry.t);

  let empty = () => Js.Dict.empty();

  let produced = (t: t, ~stateHash: string, ~instant: Instant.t) => {
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

  let received = (t: t, ~stateHash: string, ~instant: Instant.t) => {
      let set = Js.Dict.set(t, stateHash);
      switch (Js.Dict.get(t, stateHash)) {
      | None => set(That([instant]))
      | Some(This(x)) => set(Those(x, [instant]))
      | Some(That(y)) => set(That([instant, ...y]))
      | Some(Those(x, y)) => set(Those(x, [instant, ...y]))
      }
  };

  let render = (t: t) => {
    let unsafeGet = fun | None => failwith("expected some") | Some(x) => x;
    Js.Dict.keys(t)
      |> Array.map(key => Entry.render(Js.Dict.get(t, key) |> unsafeGet, key))
      |> Array.to_list
      |> List.map(fun | None => [] | Some(x) => [x]) |> List.concat
      |> Array.of_list
  }
};

/// Metadata from google logs "reflects" type information. Use these wrappers to workaround it
module Reflected = {
  module String = {
    type t = { kind: string, stringValue: string };
  };
  module Struct = {
    type structValue('a) = { fields: 'a };
    type t('a) = { kind: string, structValue: structValue('a) };
  };
};

// TODO: Pull the ids from `coda internal dump-structured-events`
module StructuredLog = {
  module BlockProduced = {
    module Metadata = {
      type validated_transition = { hash: Reflected.String.t };
      type breadcrumb = { validated_transition: Reflected.Struct.t(validated_transition) };
      type t_ = { breadcrumb: Reflected.Struct.t(breadcrumb) };

      type t = Reflected.Struct.t(t_);
    };
    let id = "64e2d3e86c37c09b15efdaf7470ce879";
  };

  module BlockReceived = {
    module Metadata = {
      type t_ = { state_hash: Reflected.String.t };
      type t = Reflected.Struct.t(t_);
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
      // we will obj-magic this placeholder to the right type depending on the event_id
      type placeholder;
      type fields = {
        event_id: option(Reflected.String.t),
        metadata: placeholder
      };
      type t = { fields: fields };
    };

    module Labels = {
      type t =
        { [@bs.as "k8s-pod/app"] k8sPodApp: string };
    };

    module Metadata = {
      type t = { timestamp : Js.Date.t, resource: Resource.t, jsonPayload: JsonPayload.t, labels: Labels.t };
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
      pageToken: option(string),
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
module TopLevel = {
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

  let rec go: int => Log.getEntryOptions => Promise.t(unit) = (i, req) => {
    Log.getEntries(log, req)
    /*-> P.tap(((es, _, _)) => {*/
        /*Js.Json.stringifyAny(es)*/
        /*|> Js.log*/
    /*})*/
    -> P.tap(((es, _, _)) => {
      let _ =
        es
          |> Array.to_list
          |> List.map((e : Entry.t) =>
            switch (e.metadata.jsonPayload.fields.event_id) {
            | None => []
            | Some(id) => [(e, id)]
            }
          )
          |> List.concat
          |> List.iter(((e: Entry.t, event_id: Reflected.String.t)) => {
            if (event_id.stringValue == StructuredLog.BlockProduced.id) {
              let metadata: StructuredLog.BlockProduced.Metadata.t =
                Obj.magic(e.metadata.jsonPayload.fields.metadata);

              BlockLifetime.produced(
                blockLifetimes,
                ~instant={ BlockLifetime.Instant.time: e.metadata.timestamp
                  , podRealName: e.metadata.labels.k8sPodApp },
                ~stateHash=metadata.structValue.fields.breadcrumb.structValue.fields.validated_transition.structValue.fields.hash.stringValue
              );
            } else if (event_id.stringValue == StructuredLog.BlockReceived.id) {
              let metadata: StructuredLog.BlockReceived.Metadata.t =
                Obj.magic(e.metadata.jsonPayload.fields.metadata);

              BlockLifetime.received(
                blockLifetimes,
                ~instant={ BlockLifetime.Instant.time: e.metadata.timestamp
                  , podRealName: e.metadata.labels.k8sPodApp },
                ~stateHash=metadata.structValue.fields.state_hash.stringValue
              );
            } else {
              failwith(Printf.sprintf("Unexpected event_id %s", event_id.stringValue));
            }
          });

      Js.log("Finished processing entries for this page")
    })
    -> P.flatMap(((_, {pageToken}, _)) => {
      let is_none = fun | None => true | Some(_) => false;
                 if (i == 0 || is_none(pageToken)) {
                   P.resolved(())
                 } else {
                   go(i-1, { ...req, pageToken })
                 }})
  };

    go(3, {
      resourceNames: [| "projects/o1labs-192920" |],
      pageSize: 100,
      autoPaginate: false,
      orderBy: "timestamp desc",
      pageToken: None,
      filter: Printf.sprintf({|
resource.type="k8s_container"
resource.labels.project_id="o1labs-192920"
resource.labels.location="us-east1"
resource.labels.cluster_name="coda-infra-east"
resource.labels.namespace_name="%s"
resource.labels.container_name="coda"
jsonPayload.event_id = ("%s" OR "%s")
timestamp > "2020-10-13T22:48:30Z"
|},
    testnetName,
    StructuredLog.BlockProduced.id,
    StructuredLog.BlockReceived.id)
  }) -> P.get(_ => Js.log2("All done", Js.Json.stringifyAny(BlockLifetime.render(blockLifetimes))));
};

