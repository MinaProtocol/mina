module CookieConsent = {
  [@bs.module "react-cookie-consent"] [@react.component]
  external make:
    (
      ~acceptOnScroll: bool=?,
      ~disableStyles: bool=?,
      ~containerClasses: string=?,
      ~buttonClasses: string=?,
      ~contentClasses: string=?,
      ~children: React.element
    ) =>
    React.element =
    "default";
};

module Styles = {
  open Css;

  let container =
    style([
      position(`fixed),
      padding2(~v=`rem(1.), ~h=`rem(2.)),
      alignItems(`center),
      justifyContent(`spaceBetween),
      display(`flex),
      width(`percent(100.)),
      background(white),
    ]);

  let content = Theme.Body.basic_semibold;

  let button =
    merge([
      Theme.Body.small,
      style([
        background(Theme.Colors.azureAlpha(0.1)),
        borderRadius(px(3)),
        padding2(~v=`rem(0.5), ~h=`rem(1.)),
        border(`zero, `none, `transparent),
        hover([background(Theme.Colors.azureAlpha(0.3))]),
      ]),
    ]);
};

[@react.component]
let make = () =>
  <CookieConsent
    acceptOnScroll=true
    disableStyles=true
    containerClasses=Styles.container
    contentClasses=Styles.content
    buttonClasses=Styles.button>
    {React.string("This website uses cookies to enhance the user experience.")}
  </CookieConsent>;
