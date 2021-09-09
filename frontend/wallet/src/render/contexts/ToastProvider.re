type mode =
  | Default
  | Warning
  | Success
  | Error;

type toast = {
  text: string,
  style: mode,
  timeoutId: Js.Global.timeoutId,
};

module ToastContextType = {
  type t = (option(toast), (option(toast) => option(toast)) => unit);

  let initialContext = (None, _ => ());
};

type t = ToastContextType.t;
include ContextProvider.Make(ToastContextType);

let createContext = () => {
  let (showToast, setToast) = React.useState(() => None);
  (showToast, setToast);
};
