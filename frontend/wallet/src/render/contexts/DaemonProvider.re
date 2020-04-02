module DaemonContextType = {
  type t = (string, (string => string) => unit);

  let initialContext = ("localhost", _ => ());
};

type t = DaemonContextType.t;
include ContextProvider.Make(DaemonContextType);

let createContext = () => {
  React.useState(() => "localhost");
};
