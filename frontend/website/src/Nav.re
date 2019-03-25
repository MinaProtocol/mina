// Nav styles adapted from https://medium.com/creative-technology-concepts-code/responsive-mobile-dropdown-navigation-using-css-only-7218e4498a99

module NavStyle = {
  open Css;
  open Style;

  module MediaQuery = {
    let menu = "(min-width: 58rem)";
    let menuMax = "(max-width: 58rem)";
    let statusLift = "(min-width: 38rem)";
  };
  let bottomNudge = Css.marginBottom(`rem(1.25));

  let options =
    style([
      // hidden on mobile by default
      display(`none),
      // when it's not hidden, make the dropdown appear
      position(`absolute),
      right(`rem(0.0)),
      top(`rem(0.0)),
      backgroundColor(Colors.white),
      // always visible and flexed on full
      media(
        MediaQuery.menu,
        [
          display(`flex),
          justifyContent(`spaceBetween),
          position(`static),
          alignItems(`center),
          width(`percent(100.0)),
        ],
      ),
    ]);

  let dropDownOptions =
    merge([options, style([marginTop(`zero), bottomNudge])]);

  let menuBtn =
    style([
      display(`none),
      media(
        // Make expanded menu not show up on a wide screen
        MediaQuery.menuMax,
        [
          selector(
            {j|:checked ~ .$dropDownOptions|j},
            [
              border(`px(2), `solid, Style.Colors.gandalf),
              borderRadius(`px(3)),
              paddingLeft(`rem(0.5)),
              marginTop(`rem(2.)),
              marginRight(`rem(-0.6)),
              display(`flex),
              maxWidth(`rem(10.)),
              flexDirection(`column),
              alignItems(`flexEnd),
            ],
          ),
        ],
      ),
    ]);

  let menuIcon =
    style([
      cursor(`pointer),
      display(`flex),
      justifyContent(`flexEnd),
      position(`relative),
      userSelect(`none),
      // The menu is always shown on full-size
      media(MediaQuery.menu, [display(`none)]),
    ]);

  let menuText = merge([style([marginLeft(`rem(1.0))]), Link.basic]);

  let nav =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      alignItems(`center),
      flexWrap(`wrap),
      media(MediaQuery.statusLift, [flexWrap(`nowrap)]),
    ]);
};

module Logo = {
  let svg = <Svg link="/static/img/new-logo.svg" dims=(7.125, 1.25) />;
};

let component = ReasonReact.statelessComponent("Nav");
let make = children => {
  ...component,
  render: _self => {
    let items =
      children
      |> Array.map(elem =>
           <li
             className=Css.(
               style(
                 Style.paddingX(`rem(0.75))
                 @ Style.paddingY(`rem(0.75))
                 @ [listStyle(`none, `inside, `none)],
               )
             )>
             elem
           </li>
         );

    <nav className=NavStyle.nav>
      <a
        href="/"
        className=Css.(
          style([
            display(`block),
            NavStyle.bottomNudge,
            width(`percent(50.0)),
            media(
              NavStyle.MediaQuery.statusLift,
              [width(`auto), marginRight(`rem(0.75))],
            ),
          ])
        )>
        Logo.svg
      </a>
      <div
        className=Css.(
          style([
            order(3),
            width(`percent(100.0)),
            NavStyle.bottomNudge,
            media(
              NavStyle.MediaQuery.statusLift,
              [order(2), width(`auto)],
            ),
            media(NavStyle.MediaQuery.menu, [width(`percent(40.0))]),
          ])
        )>
        <div
          className=Css.(
            style([
              width(`percent(100.0)),
              margin(`auto),
              media(NavStyle.MediaQuery.statusLift, [width(`rem(21.25))]),
            ])
          )>
          <AnnouncementBar />
        </div>
      </div>
      <div
        className=Css.(
          style([
            position(`relative),
            width(`auto),
            order(2),
            media(
              NavStyle.MediaQuery.statusLift,
              [order(3), width(`auto)],
            ),
            media(NavStyle.MediaQuery.menu, [width(`percent(50.0))]),
          ])
        )>
        /* we use the input to get a :checked pseudo selector
         * that we can use to get on-click without javascript at runtime */

          <input
            className=NavStyle.menuBtn
            type_="checkbox"
            id="nav-menu-btn"
          />
          <label className=NavStyle.menuIcon htmlFor="nav-menu-btn">
            <span
              className=Css.(
                merge([NavStyle.menuText, style([NavStyle.bottomNudge])])
              )>
              {ReasonReact.string("Menu")}
            </span>
          </label>
          <ul className=NavStyle.dropDownOptions> ...items </ul>
        </div>
    </nav>;
  },
};
