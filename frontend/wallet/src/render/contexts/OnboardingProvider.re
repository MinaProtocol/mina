module OnboardingContextType = {
  type t = (bool, unit => unit);

  let initialContext = (false, () => ());
};

type t = OnboardingContextType.t;
include ContextProvider.Make(OnboardingContextType);

let createContext = () => {
  let (showOnboarding, setOnboarding) =
    React.useState(() => {
      let temp =
        Bindings.LocalStorage.getItem(`Onboarding) |> Js.Nullable.toOption;
      switch (temp) {
      | None => true
      | Some(_) => false
      };
    });

  (
    showOnboarding,
    () => {
      Bindings.LocalStorage.setItem(~key=`Onboarding, ~value="COMPLETE");
      setOnboarding(_ => false);
    },
  );
};
