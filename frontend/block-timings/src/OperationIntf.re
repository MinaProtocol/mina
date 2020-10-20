module type S = {
  type input;
  type state;
  type output;

  // TODO: wire into toplevel cli
  let inputTerm: Cmdliner.Term.t(input);

  let init: input => state;
  let logFilter: input => string;
  let processLogEntry: state => CloudLogging.Entry.t => StructuredLogs.metadata => state;
  let render: state => output;
};

type operation_with_input =
  OperationWithInput((module S with type input = 'a), 'a): operation_with_input;
