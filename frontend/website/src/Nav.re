// Nav styles adapted from https://medium.com/creative-technology-concepts-code/responsive-mobile-dropdown-navigation-using-css-only-7218e4498a99

module NavStyle = {
  open Css;
  open Style;

  module MediaQuery = {
    let menu = "(min-width: 62rem)";
    let menuMax = "(max-width: 61.9375rem)";
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
          Style.paddingY(`rem(0.3))
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
            marginTop(`zero),
            marginRight(`rem(-0.6)),
            display(`flex),
            maxWidth(`rem(10.)),
            flexDirection(`column),
            alignItems(`flexStart),
            position(`absolute),
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
                zIndex(-1),
              ],
            ),
            after(triangle(white, 0) @ [zIndex(1)]),
          ],
        ),
      ]),
    ]);
};

module DropdownMenu = {
  [@react.component]
  let make = (~children) => {
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
        {React.string("Menu")}
      </button>
      <div className=Css.(style([zIndex(1), position(`relative)]))>
        <ul id="nav-menu" className=NavStyle.collapsedMenuItems> children </ul>
      </div>
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
  };
};

// TODO Please fix these styles so we don't need to mapi...
module NavWrapper = {
  [@react.component]
  let make = (~keepAnnouncementBar, ~children) => {
    let items =
      children
      |> Array.mapi((idx, elem) =>
           if (idx == Array.length(children) - 1) {
             <li
               key={string_of_int(idx)}
               className={Css.style([
                 Css.paddingLeft(`rem(0.75)), // we need to skip padding right here as it's on the edge
                 Css.listStyle(`none, `inside, `none),
                 Css.media(
                   NavStyle.MediaQuery.menuMax,
                   [Css.width(`percent(100.)), Css.padding(`zero)],
                 ),
               ])}>
               elem
             </li>;
           } else {
             <>
               <li
                 key={string_of_int(idx) ++ "-li"}
                 className={Css.style(
                   Style.paddingX(`rem(0.75))
                   @ Style.paddingY(`rem(0.5))
                   @ [
                     Css.listStyle(`none, `inside, `none),
                     Css.media(
                       NavStyle.MediaQuery.menuMax,
                       [Css.width(`percent(100.)), Css.padding(`zero)],
                     ),
                   ],
                 )}>
                 elem
               </li>
               <hr
                 key={string_of_int(idx) ++ "-hr"}
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
         )
      |> React.array;

    <nav
      className=Css.(
        style([
          display(`flex),
          justifyContent(`spaceBetween),
          alignItems(`flexEnd),
          flexWrap(`wrap),
          media(
            Style.MediaQuery.statusLift(keepAnnouncementBar),
            [flexWrap(`nowrap), alignItems(`center)],
          ),
        ])
      )>
      <A
        name="nav-home"
        href="/"
        className=Css.(
          style([
            display(`flex),
            NavStyle.bottomNudge,
            width(`percent(50.0)),
            marginTop(`zero),
            media(
              Style.MediaQuery.statusLift(keepAnnouncementBar),
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
      </A>
      <div
        className=Css.(
          style([
            order(3),
            width(`percent(100.0)),
            NavStyle.bottomNudge,
            display(`none), // just hide when status lift happens
            media(
              Style.MediaQuery.statusLift(keepAnnouncementBar),
              [
                order(2),
                width(`auto),
                marginLeft(`zero),
                ...keepAnnouncementBar
                     ? [display(`block)] : [display(`none)],
              ],
            ),
            media(NavStyle.MediaQuery.menu, [width(`percent(40.0))]),
          ])
        )>
        <div
          className=Css.(
            style([
              width(`rem(21.25)),
              media(
                Style.MediaQuery.statusLift(keepAnnouncementBar),
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
            maxWidth(px(500)),
            order(2),
            NavStyle.bottomNudgeOffset(0.5),
            media(
              Style.MediaQuery.statusLift(keepAnnouncementBar),
              [order(3), width(`auto), NavStyle.bottomNudge],
            ),
            media(NavStyle.MediaQuery.menu, [width(`percent(50.0))]),
          ])
        )>
        <DropdownMenu> items </DropdownMenu>
      </div>
    </nav>;
  };
};

let menuStyle =
  Style.paddingX(`rem(1.8))
  @ Style.paddingY(`rem(0.5))
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
      display(`block),
      width(`percent(100.)),
      textTransform(`none),
      outline(`zero, `none, `transparent),
      focus([color(Style.Colors.hyperlink)]),
      hover([backgroundColor(`transparent), color(Style.Colors.hyperlink)]),
    ];

module SimpleButton = {
  open Style;

  [@react.component]
  let make = (~name, ~activePage=false, ~link) => {
    <A
      name={"nav-" ++ name}
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
      {React.string(name)}
    </A>;
  };
};

[@react.component]
let make = (~page) => {
  <NavWrapper keepAnnouncementBar=true>
    [|
      <SimpleButton name="Blog" link="/blog" activePage={page == `Blog} />,
      <SimpleButton name="Docs" link="/docs/" activePage={page == `Docs} />,
      <SimpleButton name="Careers" link="/jobs" activePage={page == `Jobs} />,
      <SimpleButton
        name="GitHub"
        link="https://github.com/CodaProtocol/coda"
        activePage=false
      />,
    |]
  </NavWrapper>;
};
