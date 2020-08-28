module Styles = {
  open Css;
  let footerContainer =
    style([
      left(`zero),
      bottom(`zero),
      width(`percent(100.)),
      display(`flex),
      backgroundColor(black),
      flexDirection(`column),
      padding2(~v=`rem(4.), ~h=`rem(1.25)),
    ]);
  let logo = style([height(`rem(3.1)), width(`rem(11.))]);
  let label = merge([Theme.Type.h4, style([color(white)])]);
  let paragraph = merge([Theme.Type.paragraph, style([color(white)])]);
};

[@react.component]
let make = () => {
  <div className=Styles.footerContainer>
    <img
      src="/static/img/footerLogo.svg"
      alt="Mina Logo"
      className=Styles.logo
    />
    <EmailInput />
  </div>;
};
