module ToastContextType = {
  type t = (bool, unit => unit);

  let initialContext = (false, () => ());
};

type t = ToastContextType.t;
include ContextProvider.Make(ToastContextType);

let createContext = () => {
  let (showToast, setToast) = React.useState(() => false);
  toastText => {
    setToast(toastText);
  };
};
