// Nav styles adapted from https://medium.com/creative-technology-concepts-code/responsive-mobile-dropdown-navigation-using-css-only-7218e4498a99

module NavStyle = {
  open Css;
  open Style;

  module MediaQuery = {
    let menu = "(min-width: 62rem)";
    let menuMax = "(max-width: 61.9375rem)";
    let statusLift = keepAnnouncementBar =>
      keepAnnouncementBar ? "(min-width: 38rem)" : "(min-width: 0rem)";
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

  let expandedMenuBorderColor = Style.Colors.hyperlinkLight;
  let expandedMenuItems =
    merge([
      collapsedMenuItems,
      style([
        media(
          // Make expanded menu not show up on a wide screen
          MediaQuery.menuMax,
          Style.paddingY(`rem(0.25))
          @ [
            border(`px(1), `solid, expandedMenuBorderColor),
            boxShadow(
              ~x=`zero,
              ~y=`zero,
              ~blur=`px(12),
              ~spread=`zero,
              `rgba((0, 0, 0, 0.12)),
            ),
            borderRadius(`px(10)),
            marginTop(`rem(2.25)),
            marginRight(`rem(-0.6)),
            display(`flex),
            maxWidth(`rem(10.)),
            flexDirection(`column),
            alignItems(`flexStart),
            unsafe("padding-inline-start", "0"),
            unsafe("-webkit-padding-start", "0"),
            before(
              triangle(expandedMenuBorderColor, 1)
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

module NavWrapper = {
  let component = ReasonReact.statelessComponent("Nav");
  let make = (~keepAnnouncementBar, children) => {
    ...component,
    render: _self => {
      let items =
        children
        |> Array.mapi((idx, elem) =>
             if (idx == Array.length(children) - 1) {
               <li
                 className={Css.style(
                   Style.paddingX(`rem(0.75))
                   @ [Css.listStyle(`none, `inside, `none)],
                 )}>
                 elem
               </li>;
             } else {
               <>
                 <li
                   className={Css.style(
                     Style.paddingX(`rem(0.75))
                     @ Style.paddingY(`rem(0.5))
                     @ [Css.listStyle(`none, `inside, `none)],
                   )}>
                   elem
                 </li>
                 <hr
                   ariaHidden=true
                   className=Css.(
                     style([
                       borderTop(
                         `rem(0.0625),
                         `solid,
                         Style.Colors.hyperlinkAlpha(0.15),
                       ),
                       marginTop(`zero),
                       marginBottom(`zero),
                       borderBottomWidth(`zero),
                       borderLeftWidth(`zero),
                       borderRightWidth(`zero),
                       width(`percent(85.)),
                       media(NavStyle.MediaQuery.menu, [display(`none)]),
                     ])
                   )
                 />
               </>;
             }
           );

      <nav
        className=Css.(
          style([
            display(`flex),
            justifyContent(`spaceBetween),
            alignItems(`flexEnd),
            flexWrap(`wrap),
            media(
              NavStyle.MediaQuery.statusLift(keepAnnouncementBar),
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
                NavStyle.MediaQuery.statusLift(keepAnnouncementBar),
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
                NavStyle.MediaQuery.statusLift(keepAnnouncementBar),
                [order(2), width(`auto), marginLeft(`zero)],
              ),
              media(NavStyle.MediaQuery.menu, [width(`percent(40.0))]),
              ...keepAnnouncementBar ? [] : [display(`none)],
            ])
          )>
          <div
            className=Css.(
              style([
                width(`rem(21.25)),
                media(
                  NavStyle.MediaQuery.statusLift(keepAnnouncementBar),
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
                NavStyle.MediaQuery.statusLift(keepAnnouncementBar),
                [order(3), width(`auto), NavStyle.bottomNudge],
              ),
              media(NavStyle.MediaQuery.menu, [width(`percent(50.0))]),
            ])
          )>
          <DropdownMenu> ...items </DropdownMenu>
        </div>
      </nav>;
    },
  };
};

let menuStyle =
  Style.paddingX(`rem(1.75))
  @ Style.paddingY(`rem(0.75))
  @ Css.[
      height(`auto),
      margin(`zero),
      borderWidth(`zero),
      Style.Typeface.ibmplexsans,
      color(Style.Colors.saville),
      fontSize(`rem(1.0)),
      lineHeight(`rem(1.5)),
      fontWeight(`medium),
      letterSpacing(`rem(0.)),
      fontStyle(`normal),
      textTransform(`none),
      outline(`zero, `none, `transparent),
      focus([color(Style.Colors.hyperlink)]),
      hover([backgroundColor(`transparent), color(Style.Colors.hyperlink)]),
    ];

module SimpleButton = {
  open Style;

  let component = ReasonReact.statelessComponent("Nav.SimpleButton");
  let make = (~name, ~activePage=false, ~link, _children) => {
    ...component,
    render: _self => {
      <a
        href=link
        className=Css.(
          merge([
            Body.basic,
            style(
              Style.paddingY(`rem(0.75))
              @ [
                margin(`zero),
                textDecoration(`none),
                whiteSpace(`nowrap),
                color(Colors.hyperlink),
                activePage
                  ? color(Colors.hyperlink) : color(Colors.metallicBlue),
                hover([color(Style.Colors.hyperlink)]),
                media(NavStyle.MediaQuery.menuMax, menuStyle),
              ],
            ),
          ])
        )>
        {ReasonReact.string(name)}
      </a>;
    },
  };
};

module SignupButton = {
  open Style;

  let component = ReasonReact.statelessComponent("Nav.SignupButton");
  let make = (~name, ~link, _children) => {
    ...component,
    render: _self => {
      <a
        href=link
        className=Css.(
          merge([
            H4.wide,
            style(
              paddingX(`rem(0.75))
              @ paddingY(`rem(0.75))
              @ [
                display(`flex),
                width(`rem(6.25)),
                height(`rem(2.5)),
                borderRadius(`px(5)),
                color(Style.Colors.hyperlink),
                border(`px(1), `solid, Style.Colors.hyperlink),
                textDecoration(`none),
                whiteSpace(`nowrap),
                hover([
                  backgroundColor(Style.Colors.hyperlink),
                  color(Style.Colors.whiteAlpha(0.95)),
                ]),
                // Make this display the same as a SimpleButton
                // when the screen is small enough to show a menu
                media(NavStyle.MediaQuery.menuMax, menuStyle),
              ],
            ),
          ])
        )>
        <span
          className=Css.(
            style([
              marginLeft(`rem(0.25)),
              marginRight(`rem(0.0625)),
              // HACK: vertically centering leaves it 1px too high
              paddingTop(`rem(0.0625)),
              media(
                NavStyle.MediaQuery.menuMax,
                [margin(`zero), ...Style.paddingY(`zero)],
              ),
            ])
          )>
          {ReasonReact.string(name)}
        </span>
      </a>;
    },
  };
};

let component = ReasonReact.statelessComponent("CodaNav");
let make = (~page, _children) => {
  ...component,
  render: _self => {
    <NavWrapper keepAnnouncementBar={page == `Home || page == `Blog}>
      <SimpleButton name="Blog" link="/blog.html" activePage={page == `Blog} />
      <SimpleButton
        name="Testnet"
        link="/testnet.html"
        activePage={page == `Testnet}
      />
      <SimpleButton
        name="GitHub"
        link="/code.html"
        activePage={page == `Code}
      />
      <SimpleButton
        name="Careers"
        link="/jobs.html"
        activePage={page == `Jobs}
      />
      <SignupButton name="Sign up" link=Links.mailingList />
    </NavWrapper>;
  },
};
