module BlockLifetime = {
  open These;

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

type input = unit;
type state = BlockLifetime.t;
type output = BlockLifetime.Rendered.t;

let inputTerm = Cmdliner.Term.const();

let init = (_input) => BlockLifetime.empty();

let structuredLogIds = [
  StructuredLogs.BlockProduced.id,
  StructuredLogs.BlockReceived.id
]

let logFilter = (_input) => StructuredLogs.structuredLogFilter(structuredLogIds)

let processLogEntry = (blockLifetimes, entry, structuredMetadata) => {
  let open CloudLogging.Entry;
  let open StructuredLogs;

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
