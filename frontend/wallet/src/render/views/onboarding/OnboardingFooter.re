module Styles = {
  open Css;
  open Theme;
  let footer =
    style([
      position(`fixed),
      left(`zero),
      bottom(`zero),
      width(`percent(100.)),
      height(Spacing.footerHeight),
      maxHeight(Spacing.footerHeight),
      minHeight(Spacing.footerHeight),
      zIndex(101),
      display(`flex),
      alignItems(`center),
      justifyContent(`spaceBetween),
      padding2(~v=`zero, ~h=`rem(4.5)),
      paddingBottom(`rem(2.25)),
      fontFamily("IBM Plex Sans, Sans-Serif"),
    ]);
  let step = style([display(`flex), flexDirection(`column)]);
  let currentStep =
    style([
      selector("p", [color(Theme.Colors.slate)]),
      selector(
        ".stepLine",
        [
          width(`rem(12.0)),
          borderBottom(`px(4), solid, Theme.Colors.slate),
        ],
      ),
    ]);
  let inactiveStep =
    style([
      selector("p", [color(Theme.Colors.gandalf)]),
      selector(
        ".stepLine",
        [
          width(`rem(12.0)),
          borderBottom(`px(4), solid, Theme.Colors.gandalf),
        ],
      ),
    ]);
};

[@react.component]
let make = (~onboardingSteps, ~onboardingStep) =>
  if (onboardingStep == 0) {
    React.null;
  } else {
    <div className=Styles.footer>
      {React.array(
         Array.mapi(
           (index, _) =>
             index == 0
               ? React.null
               : <div
                   className={
                     onboardingStep == index
                       ? Styles.currentStep : Styles.inactiveStep
                   }
                   key={string_of_int(index)}>
                   <p className=Theme.Text.Body.smallCaps>
                     {React.string("Step " ++ string_of_int(index))}
                   </p>
                   <div className="stepLine" />
                 </div>,
           Array.of_list(onboardingSteps),
         ),
       )}
      <div className=Styles.inactiveStep>
        <p className=Theme.Text.Body.smallCaps>
          {React.string("Complete")}
        </p>
        <div className="stepLine" />
      </div>
    </div>;
  };
