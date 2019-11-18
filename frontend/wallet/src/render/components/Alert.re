module Styles = {
  open Css;

  let box = (bgColor, textColor) =>
    style([
      backgroundColor(bgColor),
      color(textColor),
      display(`flex),
      borderRadius(`px(3)),
      padding4(
        ~top=`rem(0.25),
        ~right=`rem(0.75),
        ~bottom=`rem(0.25),
        ~left=`rem(0.5),
      ),
    ]);

  let text = Theme.Text.Body.semiBold;

  let icon = style([flexShrink(0), display(`inlineFlex)]);
};

[@react.component]
let make = (~kind, ~message) => {
  let (bgColor, textColor, iconKind) =
    Theme.Colors.(
      switch (kind) {
      | `Success => (mossAlpha(0.15), clover, Icon.Success)
      | `Warning => (amberAlpha(0.15), clay, Icon.Warning)
      | `Info => (hyperlinkAlpha(0.15), marine, Icon.Info)
      | `Danger => (yeezyAlpha(0.15), yeezy, Icon.Danger)
      }
    );
  <div className={Styles.box(bgColor, textColor)}>
    <span className=Styles.icon> <Icon kind=iconKind /> </span>
    <Spacer width=0.25 />
    <div className=Styles.text> {React.string(message)} </div>
  </div>;
};
