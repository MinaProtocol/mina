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
  let make = (~currentToggle, ~onTogglePress) => {
    let renderToggleButtons = () => {
      toggleLabels
      |> Array.map(label => {
           <ToggleButton currentToggle onTogglePress label key=label />
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

module FilterDropdown = {
  module FilterDropdownStyles = {
    open Css;
    let flexColumn =
      style([
        display(`flex),
        flexDirection(`column),
        justifyContent(`center),
        height(`rem(4.5)),
        media(Theme.MediaQuery.tablet, [display(`none)]),
      ]);

    let dropdownStyle = {
      merge([
        Theme.Body.medium,
        style([
          backgroundColor(Theme.Colors.white),
          borderRadius(`px(4)),
          boxSizing(`borderBox),
          border(`px(1), `solid, Theme.Colors.tealAlpha(0.3)),
          width(`percent(100.)),
          height(`rem(2.5)),
          textIndent(`rem(0.5)),
        ]),
      ]);
    };
  };

  let filterLabels = [|"This Release", "Previous Phase", "All Time"|];
  [@react.component]
  let make = (~onFilterPress) => {
    let renderDropdown = () => {
      <select
        onClick={e => onFilterPress(ReactEvent.Mouse.target(e)##value)}
        className=FilterDropdownStyles.dropdownStyle>
        {filterLabels
         |> Array.map(label => {
              <option key=label value=label> {React.string(label)} </option>
            })
         |> React.array}
      </select>;
    };

    <div className=FilterDropdownStyles.flexColumn>
      <h3 className=Theme.H5.semiBold> {React.string("View")} </h3>
      <Spacer height=0.5 />
      {renderDropdown()}
    </div>;
  };
};

type state = {
  currentToggle: string,
  currentFilter: string,
};
let initialState = {
  currentToggle: ToggleButtons.toggleLabels[0],
  currentFilter: FilterDropdown.filterLabels[0],
};

type action =
  | Toggled(string)
  | Filtered(string);

let reducer = (state, action) => {
  switch (action) {
  | Toggled(toggle) => {...state, currentToggle: toggle}
  | Filtered(filter) => {...state, currentFilter: filter}
  };
};

[@react.component]
let make = (~lastManualUpdatedDate) => {
  let (state, dispatch) = React.useReducer(reducer, initialState);

  let onTogglePress = s => {
    dispatch(Toggled(s));
  };

  let onFilterPress = s => {
    dispatch(Filtered(s));
  };

  <Page title="Testnet Leaderboard">
    <Wrapped>
      <div className=Styles.page> <Summary lastManualUpdatedDate /> </div>
      <ToggleButtons currentToggle={state.currentToggle} onTogglePress />
      <FilterDropdown onFilterPress />
    </Wrapped>
  </Page>;
};
