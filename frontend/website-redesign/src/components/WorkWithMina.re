module Styles = {
  open Css;
  let container =
    style([
      display(`flex),
      flexDirection(`column),
      padding2(~v=`rem(4.), ~h=`rem(2.5)),
      media(Theme.MediaQuery.tablet, [flexDirection(`row)]),
      media(
        Theme.MediaQuery.desktop,
        [
          justifyContent(`spaceBetween),
          padding2(~v=`rem(7.), ~h=`rem(9.5)),
        ],
      ),
    ]);
};

[@react.component]
let make = () => {
  <div className=Styles.container>
    <h2> {React.string("Work with Mina")} </h2>
    <Button bgColor=Theme.Colors.black>
      {React.string("See All Opportunities")}
      <Icon kind=Icon.ArrowRightMedium />
    </Button>
  </div>;
};
