module Styles = {
  open Css;

  let container =
    style([
      position(`sticky),
      display(`flex),
      alignItems(`center),
      justifyContent(`spaceBetween),
      padding2(~v=`zero, ~h=`rem(1.5)),
      height(`rem(4.25)),
      marginBottom(`rem(-4.25)),
      width(`percent(100.)),
      zIndex(100),
      media(
        Theme.MediaQuery.tablet,
        [
          position(`absolute),
          height(`rem(6.25)),
          padding2(~v=`zero, ~h=`rem(2.5)),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [height(`rem(7.)), padding2(~v=`zero, ~h=`rem(3.5))],
      ),
    ]);

  let spacer =
    style([
      height(`rem(4.25)),
      media(Theme.MediaQuery.tablet, [height(`rem(6.25))]),
      media(Theme.MediaQuery.desktop, [height(`rem(7.))]),
    ]);

  let spacerLarge =
    style([
      height(`rem(6.25)),
      media(Theme.MediaQuery.tablet, [height(`rem(9.5))]),
      media(Theme.MediaQuery.desktop, [height(`rem(14.))]),
    ]);

  let logo = style([cursor(`pointer), height(`rem(2.25))]);

  let nav =
    style([
      display(`flex),
      flexDirection(`column),
      position(`absolute),
      left(`zero),
      right(`zero),
      top(`rem(4.25)),
      width(`percent(90.)),
      margin2(~h=`auto, ~v=`zero),
      background(Theme.Colors.digitalBlack),
      media(
        Theme.MediaQuery.tablet,
        [margin2(~h=`zero, ~v=`zero), top(`rem(6.25))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          position(`relative),
          top(`zero),
          width(`auto),
          flexDirection(`row),
          alignItems(`center),
          background(`none),
        ],
      ),
    ]);

  let navLink =
    merge([
      Theme.Type.navLink,
      style([
        display(`flex),
        alignItems(`center),
        padding2(~v=`zero, ~h=`rem(1.5)),
        minHeight(`rem(5.5)),
        important(color(white)),
        borderBottom(`px(1), `solid, Theme.Colors.digitalGray),
        hover([color(Theme.Colors.orange)]),
        media(
          Theme.MediaQuery.desktop,
          [
            position(`relative),
            marginRight(`rem(2.5)),
            width(`auto),
            height(`auto),
            padding(`zero),
            color(Theme.Colors.digitalBlack),
            border(`zero, `none, black),
          ],
        ),
      ]),
    ]);

  let navLabel = dark =>
    merge([
      navLink,
      style([
        media(
          Theme.MediaQuery.desktop,
          [important(color(dark ? white : Theme.Colors.digitalBlack))],
        ),
      ]),
    ]);

  let navGroup =
    style([
      width(`percent(100.)),
      top(`rem(4.5)),
      left(`rem(1.)),
      listStyleType(`none),
      color(white),
      background(Theme.Colors.digitalBlack),
      padding2(~h=`rem(1.5), ~v=`zero),
      selector(
        "> li",
        [
          display(`flex),
          alignItems(`center),
          width(`percent(100.)),
          height(`rem(5.5)),
          cursor(`pointer),
          borderBottom(`px(1), `solid, Theme.Colors.digitalGray),
          hover([color(Theme.Colors.orange)]),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [width(`rem(19.)), position(`absolute)],
      ),
    ]);

  let navToggle =
    style([
      cursor(`pointer),
      hover([color(Theme.Colors.orange)]),
      media(Theme.MediaQuery.desktop, [display(`none)]),
    ]);

  let hiddenToggle =
    style([
      display(`none),
      selector("+ label > #close-nav", [display(`none)]),
      selector("+ label > #open-nav", [display(`block)]),
      selector("~ nav", [display(`none)]),
      checked([
        selector("~ nav", [display(`flex)]),
        selector("+ label > #close-nav", [display(`block)]),
        selector("+ label > #open-nav", [display(`none)]),
      ]),
      media(
        Theme.MediaQuery.desktop,
        [selector("~ nav", [display(`flex)])],
      ),
    ]);

  let ctaContainer =
    style([
      padding2(~v=`rem(1.5), ~h=`rem(1.5)),
      media(Theme.MediaQuery.desktop, [padding(`zero)]),
    ]);
};

module NavLink = {
  [@react.component]
  let make = (~href, ~label, ~dark) => {
    <Next.Link href>
      <span className={Styles.navLabel(dark)}> {React.string(label)} </span>
    </Next.Link>;
  };
};

module NavGroup = {
  [@react.component]
  let make = (~label, ~children, ~dark=false) => {
    let (active, setActive) = React.useState(() => false);
    <>
      <span
        className={Styles.navLabel(dark)}
        onClick={_ => setActive(_ => !active)}>
        {React.string(label)}
      </span>
      {active
         ? <ul
             onClick={_ => setActive(_ => !active)} className=Styles.navGroup>
             children
           </ul>
         : React.null}
    </>;
  };
};

module NavGroupLink = {
  [@react.component]
  let make = (~icon, ~href, ~label) => {
    <Next.Link href>
      <li>
        <Icon kind=icon size=2. />
        <Spacer width=1. />
        <span
          className=Css.(
            merge([
              Theme.Type.navLink,
              style([color(currentColor), flexGrow(1.)]),
            ])
          )>
          {React.string(label)}
        </span>
        <Icon kind=Icon.ArrowRightSmall size=1.5 />
      </li>
    </Next.Link>;
  };
};

[@react.component]
let make = (~dark=false) => {
  <header className=Styles.container>
    <Next.Link href="/">
      {dark
         ? <img
             src="/static/img/mina-wordmark-dark.svg"
             className=Styles.logo
           />
         : <img
             src="/static/img/mina-wordmark-light.svg"
             className=Styles.logo
           />}
    </Next.Link>
    <input type_="checkbox" id="nav_toggle" className=Styles.hiddenToggle />
    <label htmlFor="nav_toggle" className=Styles.navToggle>
      <span id="open-nav"> <Icon kind=Icon.BurgerMenu size=2. /> </span>
      <span id="close-nav"> <Icon kind=Icon.CloseMenu size=3. /> </span>
    </label>
    <nav className=Styles.nav>
      <NavLink label="About" href="/about" dark />
      <NavLink label="Tech" href="/tech" dark />
      <NavGroup label="Get Started" dark>
        <NavGroupLink icon=Icon.Box label="Overview" href="/get-started" />
        <NavGroupLink
          icon=Icon.Documentation
          label="Documentation"
          href="/docs"
        />
        <NavGroupLink icon=Icon.Testnet label="Testnet" href="/testnet" />
        <NavGroupLink
          icon=Icon.NodeOperators
          label="Node Operators"
          href="/node-operators"
        />
      </NavGroup>
      <NavLink label="Community" href="/community" dark />
      <NavLink label="Blog" href="/blog" dark />
      <Spacer width=1.5 />
      <div className=Styles.ctaContainer>
        <Button
          href={`Internal("/genesis")} width={`rem(13.)} paddingX=1. dark>
          <img src="/static/img/promo-logo.svg" height="40" />
          <Spacer width=0.5 />
          <span> {React.string("Join Genesis Token Program")} </span>
        </Button>
      </div>
    </nav>
  </header>;
};
