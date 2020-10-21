/// Bindings to @google-cloud/logging nodejs library for pulling logs from
/// stackdriver

module ReadableStream = {
  type t('a);

  [@bs.send "on"] external on: t('a) => string => ('b => 'c) => t('a);

  let onError = (f: string => unit) => (s: t('a)) => on(s, "error", f);
  let onData = (f: 'a => unit) => (s: t('a)) => on(s, "error", f);
  let onEnd = (f: unit => unit) => (s: t('a)) => on(s, "end", f);
}

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

  // more options (which are unused here) are hidden
  // https://googleapis.dev/nodejs/logging/latest/global.html#GetEntriesRequest
  type getEntriesRequest = {
    filter: string,
    resourceNames: array(string)
  };

  [@bs.send "getEntriesStream"] external getEntriesStream: (t, getEntriesRequest) => ReadableStream.t(Entry.t);
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
