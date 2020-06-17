module Styles = {
  open Css;
  let page =
    style([
      maxWidth(`rem(58.0)),
      margin(`auto),
      media(Theme.MediaQuery.tablet, [maxWidth(`rem(89.))]),
    ]);
};

module ToggleButtons = {
  module ToggleStyles = {
    open Css;

    let flexColumn =
      style([
        display(`flex),
        flexDirection(`column),
        justifyContent(`center),
        height(`rem(4.5)),
        media("(max-width: 960px)", [display(`none)]),
      ]);

    let buttonRow =
      merge([
        style([
          display(`flex),
          width(`rem(40.5)),
          borderRadius(`px(4)),
          overflow(`hidden),
          selector(
            "*:not(:last-child)",
            [borderRight(`px(1), `solid, Theme.Colors.grey)],
          ),
        ]),
      ]);
  };

  let toggleLabels = [|
    "All Participants",
    "Genesis Members",
    "Non-Genesis Members",
  |];

  [@react.component]
  let make = (~currentOption, ~onTogglePress) => {
    let renderToggleButtons = () => {
      toggleLabels
      |> Array.map(label => {
           <ToggleButton currentOption onTogglePress label key=label />
         })
      |> React.array;
    };

    <div className=ToggleStyles.flexColumn>
      <h3 className=Theme.H5.semiBold> {React.string("View")} </h3>
      <Spacer height=0.5 />
      <div className=ToggleStyles.buttonRow> {renderToggleButtons()} </div>
    </div>;
  };
};

type state = {currentOption: string};
let initialState = {currentOption: ToggleButtons.toggleLabels[0]};

type action =
  | Toggled(string);

let reducer = (_, action) => {
  switch (action) {
  | Toggled(option) => {currentOption: option}
  };
};

[@react.component]
let make = (~lastManualUpdatedDate) => {
  let (state, dispatch) = React.useReducer(reducer, initialState);

  let onTogglePress = s => {
    dispatch(Toggled(s));
  };

  <Page title="Testnet Leaderboard">
    <Wrapped>
      <div className=Styles.page> <Summary lastManualUpdatedDate /> </div>
      <ToggleButtons currentOption={state.currentOption} onTogglePress />
    </Wrapped>
  </Page>;
};
