module Styles = {
  open Css;

  let circle =
    style([
      color(Theme.Colors.slateAlpha(0.4)),
      display(`flex),
      alignItems(`center),
    ]);

  let container =
    style([textAlign(`left), position(`relative), display(`inlineBlock)]);

  let text =
    style([
      borderRadius(`px(6)),
      transform(translate(`percent(-50.), `percent(-100.))),
      position(`absolute),
      zIndex(1),
      minWidth(`rem(15.)),
      top(`rem(-1.0)),
      left(`rem(-0.75)),
      display(`flex),
      flexDirection(`column),
      unsafe(
        "box-shadow",
        "0px 0px 20px rgba(0, 0, 0, 0.25), 0px 4px 4px rgba(31, 45, 61, 0.1)",
      ),
    ]);

  let borderRadiusSize = `px(6);

  let header =
    merge([
      Theme.Text.Body.regular,
      style([
        backgroundColor(Theme.Colors.saville),
        color(white),
        padding2(~v=`zero, ~h=`rem(1.)),
        borderTopLeftRadius(borderRadiusSize),
        borderTopRightRadius(borderRadiusSize),
        height(`rem(2.25)),
        display(`flex),
        alignItems(`center),
      ]),
    ]);

  let body =
    merge([
      Theme.Text.Body.small,
      style([
        position(`relative),
        backgroundColor(Theme.Colors.slate),
        color(white),
        borderBottomLeftRadius(borderRadiusSize),
        borderBottomRightRadius(borderRadiusSize),
        padding2(~v=`rem(0.75), ~h=`rem(1.)),
        before([
          contentRule(""),
          position(`absolute),
          left(`percent(50.)),
          bottom(`px(-8)),
          borderTopLeftRadius(`px(2)),
          width(`zero),
          height(`zero),
          borderColor(Theme.Colors.slate),
          transforms([`rotate(`deg(225)), `translate((`px(7), `zero))]),
          borderLeft(`px(5), `solid, Theme.Colors.slate),
          borderRight(`px(5), `solid, transparent),
          borderTop(`px(5), `solid, Theme.Colors.slate),
          borderBottom(`px(5), `solid, transparent),
        ]),
      ]),
    ]);
};

module Hover = {
  [@react.component]
  let make = (~header, ~body) =>
    <div className=Styles.container>
      <div className=Styles.text>
        <div className=Styles.header> {React.string(header)} </div>
        <div className=Styles.body> {React.string(body)} </div>
      </div>
    </div>;
};

[@react.component]
let make = (~header, ~body, ()) => {
  let (hover, setHover) = React.useState(() => false);
  <div
    className=Styles.circle
    onMouseOver={_ => setHover(_ => true)}
    onMouseOut={_ => setHover(_ => false)}>
    <Icon kind=Icon.Question />
    {hover ? <Hover header body /> : React.null}
  </div>;
};
