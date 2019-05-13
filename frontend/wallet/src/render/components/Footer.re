open Tc;

module Styles = {
  open Css;

  let footer =
    style([
      position(`fixed),
      bottom(`zero),
      left(`zero),
      right(`zero),
      display(`flex),
      height(Theme.Spacing.footerHeight),
      justifyContent(`spaceBetween),
      alignItems(`center),
      padding2(~v=`zero, ~h=`rem(2.)),
      borderTop(`px(1), `solid, Theme.Colors.borderColor),
    ]);
};

module StakingSwitch = {
  [@react.component]
  let make = () => {
    let (staking, setStaking) = React.useState(() => true);
    <div
      className=Css.(
        style([
          color(Theme.Colors.serpentine),
          display(`flex),
          alignItems(`center),
        ])
      )>
      <Toggle value=staking onChange={_e => setStaking(staking => !staking)} />
      <span
        className=Css.(
          merge([
            Theme.Text.body,
            style([
              color(staking ? Theme.Colors.serpentine : Theme.Colors.slateAlpha(0.7)),
              marginLeft(`rem(1.)),
            ])])
        )>
        {ReasonReact.string("Earn Coda > Vault")}
      </span>
    </div>;
  };
};

[@react.component]
let make = () => {
  <div className=Styles.footer>
    <StakingSwitch pubKey=stakingKey />
    <Button label="Send" />
  </div>;
};
