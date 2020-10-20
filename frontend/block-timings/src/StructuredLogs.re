// TODO: Pull the ids from `coda internal dump-structured-events`
/// Information about the specific structured log events we'll be needing to
/// pull

open CloudLogging;

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
  let id = Entry.eventIdExn(e);
  if (id == BlockProduced.id) {
    Some(BlockProduced(Obj.magic(metadata)));
  } else if (id == BlockReceived.id) {
    Some(BlockReceived(Obj.magic(metadata)));
  } else {
    None;
  };
};

let structuredLogFilter = (structuredLogIds) => {
  let idDisjunction =
    structuredLogIds
    |> List.map(Printf.sprintf("\"%s\""))
    |> String.concat(" OR ");
  Printf.sprintf("jsonPayload.event_id=(%s)", idDisjunction)
};
