module Styles = {
  open Css;
  let sideNav = sticky =>
    style([
      display(`none),
      position(sticky ? `fixed : `absolute),
      top(sticky ? `rem(3.5) : `rem(66.)),
      marginLeft(`calc((`sub, `vw(50.), `rem(71. /. 2.)))),
      width(`rem(14.)),
      zIndex(100),
      background(white),
      media(Theme.MediaQuery.desktop, [display(`block)]),
    ]);

  let sectionContainer = bg =>
    style([
      position(`relative),
      background(`url(bg)),
      unsafe("background-size", "100% auto"),
      backgroundRepeat(`noRepeat),
      padding(`rem(2.)),
      media(Theme.MediaQuery.desktop, [padding(`zero)]),
    ]);

  let divider =
    style([
      maxWidth(`rem(71.)),
      margin2(~v=`zero, ~h=`auto),
      height(`px(1)),
      backgroundColor(Theme.Colors.digitalBlack),
    ]);

  let section =
    style([
      width(`percent(100.)),
      maxWidth(`rem(71.)),
      margin2(~v=`auto, ~h=`auto),
      paddingTop(`rem(3.)),
      backgroundPosition(`rem(-6.5), `rem(-2.)),
      gridTemplateColumns([`em(14.), `auto]),
      selector("> aside", [gridColumnStart(1)]),
      selector("> :not(aside)", [gridColumnStart(2)]),
      selector("> img", [width(`percent(100.))]),
      media(Theme.MediaQuery.desktop, [paddingLeft(`rem(16.))]),
    ]);
};

module NodeOperatorsSideNav = {
  [@react.component]
  let make = () => {
    let router = Next.Router.useRouter();
    let hashExp = Js.Re.fromString("#(.+)");
    let scrollTop = Hooks.useScroll();
    let calcHash = path =>
      Js.Re.(exec_(hashExp, path) |> Option.map(captures))
      |> Js.Option.andThen((. res) => Js.Nullable.toOption(res[0]))
      |> Js.Option.getWithDefault("");
    let (hash, setHash) = React.useState(() => calcHash(router.asPath));

    React.useEffect(() => {
      let handleRouteChange = url => setHash(_ => calcHash(url));
      router.events
      ->Next.Router.Events.on("hashChangeStart", handleRouteChange);
      Some(
        () =>
          router.events
          ->Next.Router.Events.off("hashChangeStart", handleRouteChange),
      );
    });

    <SideNav currentSlug=hash className={Styles.sideNav(scrollTop > 1000)}>
      <SideNav.Item title="Node Overview" slug="#how-mina-works" />
      <SideNav.Item title="Block Explorers & Tools" slug="#projects" />
      <SideNav.Item title="Help & Transport" slug="#incentives" />
      <SideNav.Item title="Knowledge Base" slug="#roadmap" />
    </SideNav>;
    // <SideNav.Item title="Knowledge Base" slug="#knowledge" />
  };
};

module Section = {
  [@react.component]
  let make = (~title, ~subhead, ~slug, ~children) => {
    <section className=Styles.section id=slug>
      <h2 className=Theme.Type.h2> {React.string(title)} </h2>
      <Spacer height=1.5 />
      <p className=Theme.Type.sectionSubhead> {React.string(subhead)} </p>
      <Spacer height=4. />
      children
      <Spacer height=6.5 />
    </section>;
  };
};

module NodeOverview = {
  [@react.component]
  let make = () =>
    <div>
     {React.string("Node Overview")} 
    </div>;
};

[@react.component]
let make = () => {
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Nav.Styles.spacer />
    <Hero
      background={
        Theme.desktop: "/static/img/tech-hero-desktop.jpg",
        Theme.tablet: "/static/img/tech-hero-tablet.jpg",
        Theme.mobile: "/static/img/tech-hero-mobile.jpg",
      }
      title="Get Started For Node Operators"
      header="Run a Node"
      copy={
        Some(
          {js|With the world’s lightest blockchain, running a node is easier than ever. Here you’ll find everything you need to get up and running.|js},
        )
      }>
      <Spacer height=1. />
      <Button
        href={`Internal("/docs")}
        bgColor=Theme.Colors.orange
        width={`rem(14.)}
        height={`rem(4.5)}>
        <Icon kind=Icon.Documentation size=2.5 />
        {React.string("Go To Documentation")}
      </Button>
    </Hero>
    <NodeOperatorsSideNav />
    <NodeOverview />
    <FeaturedSingleRow
      row={
        FeaturedSingleRow.Row.rowType: ImageLeftCopyRight,
        title: "Testnet",
        copySize: `Small,
        description: {js|Check out what’s in beta, take on Testnet challenges and earn Testnet points.|js},
        textColor: Theme.Colors.white,
        image: "/static/img/NodeOpsTestnet.png",
        background: Image("/static/img/MinaSpectrumPrimarySilver.jpg"),
        contentBackground: Image("/static/img/MinaSepctrumSecondary.png"),
        button: {
          FeaturedSingleRow.Row.buttonText: "Go to Testnet",
          buttonColor: Theme.Colors.orange,
          buttonTextColor: Theme.Colors.white,
          dark: true,
          href: `Internal("/testnet"),
        },
      }
    />
    // TODO: Block Exploreers & Tools
    <FeaturedSingleRow
      row=FeaturedSingleRow.Row.{
        rowType: ImageRightCopyLeft,
        copySize: `Large,
        title: "Genesis Program",
        description: "Calling all block producers and snark producers, community leaders and content creators! Join Genesis, meet great people, play an essential role in the network, and earn Mina tokens.",
        textColor: Theme.Colors.white,
        image: "/static/img/BlogLandingHero.jpg",
        background:
          Image("/static/img/community-page/CommunityBackground.jpg"),
        contentBackground: Image("/static/img/BecomeAGenesisMember.jpg"),
        button: {
          buttonColor: Theme.Colors.mint,
          buttonTextColor: Theme.Colors.digitalBlack,
          buttonText: "Learn More",
          dark: true,
          href: `Internal("/genesis"),
        },
      }
    />
    // TODO: Knowledge Base
    <ButtonBar
      kind=ButtonBar.HelpAndSupport
      backgroundImg="/static/img/ButtonBarBackground.jpg"
    />
  </Page>;
};
