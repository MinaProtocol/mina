module ProcessDispatchContextType = {
  type t = CodaProcess.Action.t => unit;

  let initialContext = ignore;
};

type t = ProcessDispatchContextType.t;
include ContextProvider.Make(ProcessDispatchContextType);
