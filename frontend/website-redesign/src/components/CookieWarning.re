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
      background(Theme.Colors.gray),
    ]);

  let content = merge([Theme.Type.paragraph, style([color(white)])]);

  let button =
    merge([
      Theme.Type.paragraph,
      style([
        opacity(1.),
        color(Theme.Colors.gray),
        background(white),
        borderRadius(px(3)),
        padding2(~v=`rem(0.75), ~h=`rem(1.5)),
        border(`zero, `none, `transparent),
        textTransform(`capitalize),
        hover([opacity(0.7)]),
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
