module DaemonContextType = {
  type t = (string, (string => string) => unit);

  let initialContext = ("localhost", _ => ());
};

type t = DaemonContextType.t;
include ContextProvider.Make(DaemonContextType);

let createContext = () => {
  let (daemon, setDaemon) =
    React.useState(() => {
      let daemonCache =
        Bindings.LocalStorage.getItem(`DaemonHost) |> Js.Nullable.toOption;
      switch (daemonCache) {
      | None => "localhost"
      | Some("") => "localhost"
      | Some(value) => value
      };
    });
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
