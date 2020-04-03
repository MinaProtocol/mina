module DaemonContextType = {
  type t = (string, (string => string) => unit);

  let initialContext = ("localhost", _ => ());
};

type t = DaemonContextType.t;
include ContextProvider.Make(DaemonContextType);

let createContext = () => {
  let (daemon, setDaemon) =
    React.useState(() =>
      Bindings.LocalStorage.getItem(`DaemonHost)
      |> Js.Nullable.toOption
      |> Tc.Option.withDefault(~default="localhost")
    );
  (
    daemon,
    (nextValue: string => string) => {
      Bindings.LocalStorage.setItem(
        ~key=`DaemonHost,
        ~value=nextValue(daemon),
      );
      setDaemon(nextValue);
    },
  );
};
