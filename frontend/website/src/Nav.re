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

  let collapsedMenuItems =
    style([
      marginTop(`zero),
      bottomNudge,
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

  let expandedMenuItems =
    merge([
      collapsedMenuItems,
      style([
        media(
          // Make expanded menu not show up on a wide screen
          MediaQuery.menuMax,
          [
            border(`px(1), `solid, Style.Colors.hyperlinkHover),
            boxShadow(
              ~x=`zero,
              ~y=`zero,
              ~blur=`px(12),
              ~spread=`zero,
              `rgba((0, 0, 0, 0.12)),
            ),
            borderRadius(`px(10)),
            paddingLeft(`rem(0.5)),
            marginTop(`rem(2.)),
            marginRight(`rem(-0.6)),
            display(`flex),
            maxWidth(`rem(10.)),
            flexDirection(`column),
            alignItems(`flexStart),
          ],
        ),
      ]),
    ]);
};

module DropdownMenu = {
  let component = ReasonReact.statelessComponent("Nav.DropdownMenu");
  let make = children => {
    ...component,
    render: _self => {
      <>
        <button
          className=Css.(
            merge([
              Style.Link.basic,
              style([
                NavStyle.bottomNudge,
                marginLeft(`rem(1.0)),
                border(`zero, `solid, `transparent),
                cursor(`pointer),
                display(`flex),
                justifyContent(`flexEnd),
                position(`relative),
                userSelect(`none),
                backgroundColor(`transparent),
                outline(`zero, `none, `transparent),
                focus([color(Style.Colors.hyperlinkHover)]),
                // The menu is always shown on full-size
                media(NavStyle.MediaQuery.menu, [display(`none)]),
              ]),
            ])
          )
          id="nav-menu-btn">
          {ReasonReact.string("Menu")}
        </button>
        <ul id="nav-menu" className=NavStyle.collapsedMenuItems>
          ...children
        </ul>
        <RunScript>
          {Printf.sprintf(
             {|
              var menuState = false;
              var menuBtn = document.getElementById("nav-menu-btn");
              function setMenuOpen(open) {
                menuState = open;
                document.getElementById("nav-menu").className =
                  (open ? "%s" : "%s");
              };

              document.onclick = (e) => {
                if (e.target != menuBtn) {
                  var previousState = menuState;
                  setMenuOpen(false);
                }
              };

              menuBtn.onclick = () => setMenuOpen(!menuState);
            |},
             NavStyle.expandedMenuItems,
             NavStyle.collapsedMenuItems,
           )}
        </RunScript>
      </>;
    },
  };
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

    <nav
      className=Css.(
        style([
          display(`flex),
          justifyContent(`spaceBetween),
          alignItems(`center),
          flexWrap(`wrap),
          media(NavStyle.MediaQuery.statusLift, [flexWrap(`nowrap)]),
        ])
      )>
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
        <DropdownMenu> ...items </DropdownMenu>
      </div>
    </nav>;
  },
};
