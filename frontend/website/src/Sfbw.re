module Styles = {
  open Css;

  let wrapper =
    style([
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
      justifyContent(`center),
      minHeight(vh(70.)),
    ]);

  let header =
    merge([
      Style.H1.hero,
      style([marginBottom(rem(1.)), color(Style.Colors.marine)]),
    ]);
};

[@react.component]
let make = () =>
  <div className=Styles.wrapper>
    <h1 className=Styles.header> {React.string("Stay in touch")} </h1>
    <NewsletterWidget />
  </div>;
