module Styles = {
  open Css;

  let container =
    style([
      display(`flex),
      alignItems(`center),
      justifyContent(`spaceBetween),
      padding2(~v=`zero, ~h=`rem(1.5)),
      height(`rem(4.25)),
      width(`percent(100.)),
      media(
        Theme.MediaQuery.tablet,
        [height(`rem(6.25)), padding2(~v=`zero, ~h=`rem(2.5))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [height(`rem(7.)), padding2(~v=`zero, ~h=`rem(3.5))],
      ),
    ]);

  let logo = style([cursor(`pointer), height(`rem(2.25))]);

  let nav = style([display(`flex), alignItems(`center)]);

  let navLink =
    merge([Theme.Type.navLink, style([position(`relative), marginRight(`rem(1.25))])]);

  let navGroup = style([position(`absolute)]);
};

module NavLink = {
  [@react.component]
  let make = (~href, ~label) => {
    <Next.Link href>
      <span className=Styles.navLink> {React.string(label)} </span>
    </Next.Link>;
  };
};

module NavGroup = {
  [@react.component]
  let make = (~label, ~children) => {
    let (active, setActive) = React.useState(() => false);
    <>
      <span className=Styles.navLink onMouseOver={_ => setActive(_ => true)}>
        {React.string(label)}
        {active ? <ul className=Styles.navGroup> children </ul> : React.null}
      </span>
    </>;
  };
};

module NavGroupLink = {
  [@react.component]
  let make = (~icon, ~href, ~label) => {
    <li> <Next.Link href> <span> <Icon kind=icon size=2. /> {React.string(label)} </span> </Next.Link> </li>;
  };
};

[@react.component]
let make = () => {
  <header className=Styles.container>
    <Next.Link href="/">
      <img src="/static/img/mina-wordmark.svg" className=Styles.logo />
    </Next.Link>
    <nav className=Styles.nav>
      <NavLink label="About" href="/about" />
      <NavLink label="Tech" href="/tech" />
      <NavGroup label="Get Started">
        <NavGroupLink icon=Icon.Box label="Get Started" href="/get-started" />
        <NavGroupLink
          icon=Icon.NodeOperators
          label="Node Operators"
          href="/node-operators"
        />
        <NavGroupLink
          icon=Icon.Developers
          label="Developers"
          href="/developers"
        />
        <NavGroupLink
          icon=Icon.Documentation
          label="Documentation"
          href="/docs"
        />
        <NavGroupLink icon=Icon.Testnet label="Testnet" href="/testnet" />
      </NavGroup>
      <NavLink label="Community" href="/community" />
      <NavLink label="Blog" href="/blog" />
      <Spacer width=1.5 />
      <Button>
        <img src="/static/img/promo-logo.svg" height="40" />
      </Button>
    </nav>
  </header>;
};
