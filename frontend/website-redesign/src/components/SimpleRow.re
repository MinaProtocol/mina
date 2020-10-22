module Styles = {
  open Css;

  let simpleRowContainer =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      alignItems(`flexStart),
      padding2(~v=`rem(6.5), ~h=`zero),
      media(
        Theme.MediaQuery.notMobile,
        [flexDirection(`row), alignItems(`center)],
      ),
    ]);

  let simpleRowImage =
    style([
      width(`percent(100.)),
      media(Theme.MediaQuery.notMobile, [width(`rem(35.))]),
    ]);

  let simpleColumnContainer =
    style([
      display(`flex),
      flexDirection(`column),
      width(`rem(26.)),
      height(`percent(100.)),
      marginTop(`rem(2.)),
      media(
        Theme.MediaQuery.notMobile,
        [marginTop(`zero), marginLeft(`rem(3.))],
      ),
    ]);
};

[@react.component]
let make = (~img, ~title, ~copy, ~buttonCopy, ~buttonUrl) => {
  <Wrapped>
    <div className=Styles.simpleRowContainer>
      <img className=Styles.simpleRowImage src=img />
      <div className=Styles.simpleColumnContainer>
        <h2 className=Theme.Type.h2> {React.string(title)} </h2>
        <Spacer height=1. />
        <p className=Theme.Type.paragraph> {React.string(copy)} </p>
        <Spacer height=2.5 />
        <Button href={`Internal(buttonUrl)} bgColor=Theme.Colors.orange>
          {React.string(buttonCopy)}
          <Icon kind=Icon.ArrowRightSmall />
        </Button>
      </div>
    </div>
  </Wrapped>;
};
