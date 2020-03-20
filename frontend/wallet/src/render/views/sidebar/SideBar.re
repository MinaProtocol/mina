open ReactIntl

module Styles = {
  open Css;

  let sidebar =
    style([
      width(`rem(14.)),
      overflow(`hidden),
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      borderRight(`px(1), `solid, Theme.Colors.borderColor),
    ]);

  let footer = style([padding2(~v=`rem(0.5), ~h=`rem(0.75))]);

  let addAccountLink =
    merge([
      Theme.Text.Body.regular,
      style([
        display(`inlineFlex),
        alignItems(`center),
        cursor(`default),
        color(Theme.Colors.tealAlpha(0.5)),
        padding2(~v=`zero, ~h=`rem(0.5)),
        hover([
          color(Theme.Colors.teal),
          backgroundColor(Theme.Colors.hyperlinkAlpha(0.15)),
          borderRadius(`px(2)),
        ]),
        textTransform(`capitalize)
      ]),
    ]);
};

[@react.component]
let make = () => {
  let (modalOpen, setModalOpen) = React.useState(() => false);

  <div className=Styles.sidebar>
    <AccountList />
    <div className=Styles.footer>
      <a
        className=Styles.addAccountLink onClick={_ => setModalOpen(_ => true)}>
        <FormattedMessage
          id="sidebar.new-account"
          defaultMessage="+ New Account"
        />
      </a>
    </div>
    {switch (modalOpen) {
     | false => React.null
     | true => <NewAccountModal onClose={() => setModalOpen(_ => false)} />
     }}
  </div>;
};
