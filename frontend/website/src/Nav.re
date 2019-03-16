/* Nav styles adapted from https://medium.com/creative-technology-concepts-code/responsive-mobile-dropdown-navigation-using-css-only-7218e4498a99 */

module Style = {
  open Style;
  open Css;

  let no_list = style([listStyle(`none, `inside, `none)]);

  let item =
    merge([style(paddingX(`rem(1.0)) @ paddingY(`rem(1.0))), no_list]);

  let options =
    style([
      // hidden on mobile by default
      display(`none),
      // when it's not hidden, make the dropdown appear
      position(`absolute),
      right(`rem(0.0)),
      top(`rem(2.0)),
      backgroundColor(Colors.white),
      // always visible and flexed on full
      media(
        MediaQuery.full,
        [display(`flex), justifyContent(`flexEnd), position(`static)],
      ),
    ]);

  let menuBtn =
    style([
      display(`none),
      selector({j|:checked ~ .$options|j}, [display(`block)]),
    ]);

  let menuIcon =
    style([
      cursor(`pointer),
      display(`flex),
      justifyContent(`flexEnd),
      position(`relative),
      userSelect(`none),
      // The menu is always shown on full-size
      media(MediaQuery.full, [display(`none)]),
    ]);

  let menuText = style(paddingX(`rem(1.0)) @ paddingY(`rem(1.0)));

  let nav =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      alignItems(`center),
    ]);
};

let component = ReasonReact.statelessComponent("Nav");
let make = children => {
  ...component,
  render: _self => {
    let items =
      children |> Array.map(elem => <li className=Style.item> elem </li>);

    <nav className=Style.nav>
      <p> {ReasonReact.string("TODO Logo")} </p>
      /* we use the input to get a :checked pseudo selector
       * that we can use to get on-click without javascript at runtime */
      <input className=Style.menuBtn type_="checkbox" id="nav-menu-btn" />
      <label className=Style.menuIcon htmlFor="nav-menu-btn">
        <span className=Style.menuText> {ReasonReact.string("Menu")} </span>
      </label>
      <ul className=Style.options> ...items </ul>
    </nav>;
  },
};
