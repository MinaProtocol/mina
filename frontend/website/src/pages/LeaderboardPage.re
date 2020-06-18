module Styles = {
  open Css;
  let page =
    style([
      maxWidth(`rem(58.0)),
      margin(`auto),
      media(Theme.MediaQuery.tablet, [maxWidth(`rem(89.))]),
    ]);
  let filters =
    style([
      display(`flex),
      flexDirection(`column),
      media(Theme.MediaQuery.notMobile, [flexDirection(`row)]),
      justifyContent(`spaceBetween),
      width(`percent(100.)),
      marginTop(`rem(2.)),
      media(Theme.MediaQuery.tablet, [marginTop(`rem(5.))]),
    ]);
  let searchBar =
    style([
      display(`flex),
      flexDirection(`column),
      marginTop(`rem(3.)),
      media(
        Theme.MediaQuery.notMobile,
        [width(`percent(45.)), marginTop(`zero)],
      ),
    ]);
  let textField =
    style([
      display(`inlineFlex),
      alignItems(`center),
      height(px(40)),
      borderRadius(px(4)),
      width(`percent(100.)),
      fontSize(rem(1.)),
      color(Theme.Colors.teal),
      padding(px(12)),
      marginTop(`rem(0.5)),
      border(px(1), `solid, Theme.Colors.hyperlinkAlpha(0.3)),
      active([
        outline(px(0), `solid, `transparent),
        padding(px(11)),
        borderWidth(px(2)),
        borderColor(Theme.Colors.hyperlinkAlpha(1.)),
      ]),
      focus([
        outline(px(0), `solid, `transparent),
        padding(px(11)),
        borderWidth(px(2)),
        borderColor(Theme.Colors.hyperlinkAlpha(1.)),
      ]),
      hover([borderColor(Theme.Colors.hyperlinkAlpha(1.))]),
      selector(
        "::placeholder",
        [
          fontSize(`px(12)),
          fontWeight(normal),
          color(Theme.Colors.slateAlpha(0.7)),
        ],
      ),
      media(Theme.MediaQuery.tablet, [width(`rem(28.))]),
      media(Theme.MediaQuery.desktop, [width(`rem(39.))]),
    ]);
};

module SearchBar = {
  [@react.component]
  let make = (~onUsernameEntered, ~username) => {
    <div className=Styles.searchBar>
      <span className=Theme.H5.semiBold> {React.string("Find")} </span>
      <input
        type_="text"
        value=username
        placeholder="SEARCH:"
        onChange={e => {
          let value = ReactEvent.Form.target(e)##value;
          onUsernameEntered(value);
        }}
        className=Styles.textField
      />
    </div>;
  };
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
        width(`percent(100.)),
        marginTop(`rem(2.0)),
        media(
          Theme.MediaQuery.notMobile,
          [width(`percent(45.)), marginTop(`zero)],
        ),
      ]);

    let dropdownStyle = {
      merge([
        Theme.Body.medium,
        style([
          backgroundColor(Theme.Colors.white),
          borderRadius(`px(4)),
          boxSizing(`borderBox),
          border(`px(1), `solid, Theme.Colors.tealAlpha(0.3)),
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
  username: string,
};
let initialState = {
  currentToggle: ToggleButtons.toggleLabels[0],
  currentFilter: FilterDropdown.filterLabels[0],
  username: "",
};

type action =
  | Toggled(string)
  | Filtered(string)
  | UsernameEntered(string);

let reducer = (prevState, action) => {
  switch (action) {
  | Toggled(toggle) => {...prevState, currentToggle: toggle}
  | Filtered(filter) => {...prevState, currentFilter: filter}
  | UsernameEntered(input) => {...prevState, username: input}
  };
};

[@react.component]
let make = (~lastManualUpdatedDate) => {
  let (state, dispatch) = React.useReducer(reducer, initialState);
  let onTogglePress = s => {
    dispatch(Toggled(s));
  };

  let onUsernameEntered = username => {
    dispatch(UsernameEntered(username));
  };

  let onFilterPress = s => {
    dispatch(Filtered(s));
  };

  <Page title="Testnet Leaderboard">
    <Wrapped>
      <div className=Styles.page> <Summary lastManualUpdatedDate /> </div>
      <div className=Styles.filters>
        <SearchBar onUsernameEntered username={state.username} />
        <ToggleButtons currentToggle={state.currentToggle} onTogglePress />
        <FilterDropdown onFilterPress />
      </div>
    </Wrapped>
  </Page>;
};