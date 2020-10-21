module BlockLifetime = {
  open These;

  module ProducedInstant = {
    /// When and where an event occurred
    type t = {
      time: Js.Date.t,
      podRealName: string
    };
  };


  module ReceivedInstant = {
    type t = {
      // could nest instant here, but looks nicer this way
      time: Js.Date.t,
      podRealName: string,
      sender: string
    };
  };

  module Entry = {
    module Rendered = {
      /// A fully-rendered entry corresponds to one block that is produced at
      /// some instant and received at others
      type t = {
        stateHash: string,
        produced: ProducedInstant.t,
        received: array(ReceivedInstant.t)
      };
    };

    /// A (partially) complete entry is either the instant a block was produced
    /// or a list of instants that a block was received
    type t = These.t([ | `Produced(ProducedInstant.t)], list(ReceivedInstant.t));

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

  let produced = (t: t, ~stateHash: string, ~producedInstant: ProducedInstant.t) => {
    let set = Js.Dict.set(t, stateHash);
    let x = `Produced(producedInstant);
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

  let received = (t: t, ~stateHash: string, ~receivedInstant: ReceivedInstant.t) => {
    let set = Js.Dict.set(t, stateHash);
    switch (Js.Dict.get(t, stateHash)) {
    | None => set(That([receivedInstant]))
    | Some(This(x)) => set(Those(x, [receivedInstant]))
    | Some(That(y)) => set(That([receivedInstant, ...y]))
    | Some(Those(x, y)) => set(Those(x, [receivedInstant, ...y]))
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

  switch (structuredMetadata) {
  | BlockProduced(metadata) =>
      let producedInstant = BlockLifetime.ProducedInstant.{
        time: entry.metadata.timestamp,
        podRealName: entry.metadata.labels.k8sPodApp
      };
      BlockLifetime.produced(
        blockLifetimes,
        ~producedInstant,
        ~stateHash=
          metadata.structValue.fields.breadcrumb.structValue.
            fields.
            validated_transition.
            structValue.
            fields.
            hash.
            stringValue,
      )
  | BlockReceived(metadata) => {
      let receivedInstant = BlockLifetime.ReceivedInstant.{
        time: entry.metadata.timestamp,
        podRealName: entry.metadata.labels.k8sPodApp,
        sender: metadata.structValue.fields.sender.structValue.fields._Remote.structValue.fields.host.stringValue
      };
      BlockLifetime.received(
        blockLifetimes,
        ~receivedInstant,
        ~stateHash=
          metadata.structValue.fields.state_hash.stringValue,
      )
    }
  };

  Promise.resolved(blockLifetimes)
}

let render = BlockLifetime.render
