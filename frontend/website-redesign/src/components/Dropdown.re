module Styles = {
  open Css;
  let currentItemTitle =
    style([
      display(`inlineFlex),
      alignItems(`center),
      justifyContent(`spaceBetween),
      margin2(~h=`rem(0.2), ~v=`rem(0.2)),
      width(`percent(100.)),
    ]);

  let container = {
    merge([
      Theme.Type.paragraphMono,
      style([
        position(`relative),
        width(`percent(100.)),
        letterSpacing(`rem(-0.0125)),
        fontWeight(`num(500)),
        border(`px(1), `solid, Theme.Colors.gray),
        borderRadius(`px(4)),
        padding(`px(5)),
        cursor(`pointer),
      ]),
    ]);
  };

  let collapsedDropdown = {
    style([
      position(`absolute),
      left(`zero),
      right(`zero),
      fontWeight(`num(500)),
      backgroundColor(Theme.Colors.white),
      pointerEvents(`none),
      border(`px(1), `solid, Theme.Colors.orange),
      opacity(0.),
    ]);
  };

  let expandedDropdown = {
    merge([
      collapsedDropdown,
      style([
        top(`rem(2.3)),
        borderRadius(`px(4)),
        pointerEvents(`auto),
        opacity(1.),
        zIndex(100),
        selector(
          "li",
          [
            display(`block),
            textDecoration(`none),
            padding(`px(10)),
            hover([background(Theme.Colors.orange)]),
          ],
        ),
      ]),
    ]);
  };
};

[@react.component]
let make = (~items, ~currentItem, ~onItemPress) => {
  let (menuOpen, toggleMenu) = React.useState(() => false);

  let onDropdownItemPress = item => {
    onItemPress(item);
    toggleMenu(_ => !menuOpen);
  };

  <div className=Styles.container onClick={_ => {toggleMenu(_ => !menuOpen)}}>
    <span className=Styles.currentItemTitle>
      <span> {React.string(currentItem)} </span>
      <Icon kind=Icon.ChevronDown />
    </span>
    <ul
      className={menuOpen ? Styles.expandedDropdown : Styles.collapsedDropdown}>
      {items
       |> Array.map(item => {
            <li key=item onClick={_ => {onDropdownItemPress(item)}}>
              {React.string(item)}
            </li>
          })
       |> React.array}
    </ul>
  </div>;
};
