// Nav styles adapted from https://medium.com/creative-technology-concepts-code/responsive-mobile-dropdown-navigation-using-css-only-7218e4498a99

module NavStyle = {
  open Css;
  open Style;

  module MediaQuery = {
    let menu = "(min-width: 58rem)";
    let statusLift = "(min-width: 38rem)";
  };

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
        MediaQuery.menu,
        [
          display(`flex),
          justifyContent(`spaceBetween),
          position(`static),
          width(`percent(100.0)),
        ],
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
  let svg =
    <svg className=Css.(style([width(`rem(7.125)), height(`rem(1.25))]))>
      <image xlinkHref="/static/img/new-logo.svg" width="114" height="20" />
    </svg>;
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
                 @ Style.paddingY(`zero)
                 @ [listStyle(`none, `inside, `none)],
               )
             )>
             elem
           </li>
         );

    let bottomNudge = Css.marginBottom(`rem(1.25));

    <nav className=NavStyle.nav>
      <a
        href="/"
        className=Css.(
          style([
            display(`block),
            bottomNudge,
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
            bottomNudge,
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
                merge([NavStyle.menuText, style([bottomNudge])])
              )>
              {ReasonReact.string("Menu")}
            </span>
          </label>
          <ul
            className=Css.(
              merge([
                NavStyle.options,
                style([marginTop(`zero), bottomNudge]),
              ])
            )>
            ...items
          </ul>
        </div>
    </nav>;
  },
};
