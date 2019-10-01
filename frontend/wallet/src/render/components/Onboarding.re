module Styles = {
  open Css;

  let main =
    style([
      display(`flex),
      flexDirection(`row),
      paddingTop(Theme.Spacing.headerHeight),
      paddingBottom(Theme.Spacing.footerHeight),
      height(`vh(100.)),
      width(`vw(100.)),
    ]);
};

[@react.component]
let make = () => {
  let (showOnboarding, closeOnboarding) =
    React.useContext(OnboardingProvider.context);
  <div className=Styles.main>
    <Button label="Continue" onClick={_ => Js.log("Next page clicked")} />
  </div>;
};
