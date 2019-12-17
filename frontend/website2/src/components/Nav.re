module Style = {
  open Css;
  let header =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      alignItems(`center),
      padding2(~v=`zero, ~h=`rem(1.25)),
      marginTop(`rem(1.0)),
      marginBottom(`rem(2.)),
      height(`rem(2.5)),
      media(
        Theme.MediaQuery.notSmallMobile,
        [padding2(~v=`zero, ~h=`rem(3.)), marginTop(`rem(2.0))],
      ),
      media(
        Theme.MediaQuery.full,
        [maxWidth(`rem(89.)), marginLeft(`auto), marginRight(`auto)],
      ),
    ]);
  let link =
    style([
      marginRight(`rem(2.)),
      textDecoration(`none),
      fontWeight(`light),
      Theme.Typeface.ibmplexsans,
      color(Theme.Colors.saville),
      hover([color(Theme.Colors.hyperlink)]),
    ]);
  let nav = style([display(`flex), alignItems(`center)]);
  let announcementBar =
    style([
      display(`none),
      media(Theme.MediaQuery.somewhatLarge, [display(`block)]),
    ]);
  let logo = style([height(`px(20))]);
};

[@react.component]
let make = () => {
  <header className=Style.header>
    <Next.Link href="/">
      <a>
        <ContentfulImage
          src="coda-logo_2x-7d63082a6d95ed08cfa6f160e742a274d24bf23764036eacaa0c6f2d422f682a.png"
          alt="Coda Home"
          className=Style.logo
        />
      </a>
    </Next.Link>
    <div className=Style.announcementBar> <AnnouncementBar /> </div>
    <nav>
      <Next.Link href="/blog">
        <a className=Style.link> {React.string("Blog")} </a>
      </Next.Link>
      <Next.Link href="/docs">
        <a className=Style.link> {React.string("Docs")} </a>
      </Next.Link>
      <Next.Link href="/jobs">
        <a className=Style.link> {React.string("Careers")} </a>
      </Next.Link>
      <a
        className=Style.link
        href="https://github.com/CodaProtocol/coda"
        target="_blank">
        {React.string("Github")}
      </a>
      <Next.Link href="/testnet">
        <a className=Style.link> {React.string("Testnet")} </a>
      </Next.Link>
    </nav>
  </header>;
};

let default = make;
