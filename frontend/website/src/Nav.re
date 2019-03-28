// Nav styles adapted from https://medium.com/creative-technology-concepts-code/responsive-mobile-dropdown-navigation-using-css-only-7218e4498a99

module NavStyle = {
  open Css;
  open Style;

  module MediaQuery = {
    let menu = "(min-width: 62rem)";
    let menuMax = "(max-width: 61.9375rem)";
    let statusLift = mainPage =>
      mainPage ? "(min-width: 38rem)" : "(min-width: 0rem)";
  };
  let bottomNudge = Css.marginBottom(`rem(2.0));
  let bottomNudgeOffset = offset => Css.marginBottom(`rem(2.0 -. offset));

  let collapsedMenuItems =
    style([
      marginTop(`zero),
      marginBottom(`zero),
      display(`none),
      // when it's not hidden, make the dropdown appear
      position(`absolute),
      right(`rem(1.0)),
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

  let triangle = (c, offset) => [
    unsafe("content", ""),
    width(`zero),
    height(`zero),
    position(`absolute),
    borderLeft(`px(4 + offset), `solid, c),
    borderRight(`px(4 + offset), `solid, transparent),
    borderTop(`px(4 + offset), `solid, c),
    borderBottom(`px(4 + offset), `solid, transparent),
    right(`px(15 - offset)),
    top(`px((-3) - offset)),
    transforms([`rotate(`deg(45))]),
    media(MediaQuery.menu, [display(`none)]),
  ];

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
            before(
              triangle(Style.Colors.hyperlinkHover, 1)
              @ [
                boxShadow(
                  ~x=`zero,
                  ~y=`zero,
                  ~blur=`px(12),
                  ~spread=`zero,
                  `rgba((0, 0, 0, 0.12)),
                ),
                zIndex(-10),
              ],
            ),
            after(triangle(white, 0) @ []),
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
              style(
                Style.paddingY(`rem(0.5))
                @ [
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
                ],
              ),
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

let component = ReasonReact.statelessComponent("Nav");
let make = (~mainPage, children) => {
  ...component,
  render: _self => {
    let items =
      children
      |> Array.mapi((idx, elem) =>
           <li
             className={Css.style(
               Style.paddingX(`rem(0.75))
               @ (
                 idx != Array.length(children) - 1
                   ? Style.paddingY(`rem(0.5)) : []
               )
               @ [Css.listStyle(`none, `inside, `none)],
             )}>
             elem
           </li>
         );

    <nav
      className=Css.(
        style([
          display(`flex),
          justifyContent(`spaceBetween),
          alignItems(`flexEnd),
          flexWrap(`wrap),
          media(
            NavStyle.MediaQuery.statusLift(mainPage),
            [flexWrap(`nowrap), alignItems(`center)],
          ),
        ])
      )>
      <a
        href="/"
        className=Css.(
          style([
            display(`flex),
            NavStyle.bottomNudge,
            width(`percent(50.0)),
            marginTop(`zero),
            media(
              NavStyle.MediaQuery.statusLift(mainPage),
              [
                width(`auto),
                marginRight(`rem(0.75)),
                marginTop(`zero),
                NavStyle.bottomNudgeOffset(0.1875),
              ],
            ),
            media(NavStyle.MediaQuery.menu, [marginTop(`zero)]),
          ])
        )>
        <Image className="" name="/static/img/coda-logo" alt="Coda Home" />
      </a>
      <div
        className=Css.(
          style([
            order(3),
            width(`percent(100.0)),
            NavStyle.bottomNudge,
            media(
              NavStyle.MediaQuery.statusLift(mainPage),
              [order(2), width(`auto), marginLeft(`zero)],
            ),
            media(NavStyle.MediaQuery.menu, [width(`percent(40.0))]),
            ...mainPage ? [] : [display(`none)],
          ])
        )>
        <div
          className=Css.(
            style([
              width(`rem(21.25)),
              media(
                NavStyle.MediaQuery.statusLift(mainPage),
                [width(`rem(21.25)), margin(`auto)],
              ),
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
            NavStyle.bottomNudgeOffset(0.5),
            media(
              NavStyle.MediaQuery.statusLift(mainPage),
              [order(3), width(`auto), NavStyle.bottomNudge],
            ),
            media(
              NavStyle.MediaQuery.menu,
              [mainPage ? width(`percent(50.0)) : width(`percent(70.0))],
            ),
          ])
        )>
        <DropdownMenu> ...items </DropdownMenu>
      </div>
    </nav>;
  },
};
