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
      marginTop(`rem(3.5)),
      media(Theme.MediaQuery.desktop, [display(`block)]),
    ]);

  let sectionContainer = bg =>
    style([
      position(`relative),
      background(`url(bg)),
      unsafe("background-size", "100% auto"),
      backgroundSize(`cover),
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

  let rolesContainer =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      alignItems(`flexStart),
      media(
        Theme.MediaQuery.notMobile,
        [flexDirection(`row), alignItems(`center)],
      ),
    ]);

  let singleRowContainer = style([width(`rem(26.))]);

  let roleLink =
    merge([
      Theme.Type.buttonLink,
      style([
        display(`flex),
        alignItems(`center),
        selector(">:last-child", [marginLeft(`rem(0.5))]),
      ]),
    ]);

  let runNodeContainer = style([width(`percent(100.))]);

  let nodesContainer =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      alignItems(`flexStart),
      media(
        Theme.MediaQuery.notMobile,
        [flexDirection(`row), alignItems(`center)],
      ),
    ]);

  let runNodeContent = style([width(`rem(17.)), marginTop(`rem(2.))]);

  let blockAndToolsGrid =
    style([
      display(`grid),
      gridTemplateColumns([
        `repeat((`autoFit, `minmax((`rem(17.), `fr(1.))))),
      ]),
      gridGap(`rem(1.)),
    ]);

  let blockExplorerCard =
    style([width(`rem(17.)), display(`flex), flexDirection(`column)]);
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
      <SideNav.Item title="Help And Support" slug="#help-and-support" />
    </SideNav>;
    // <SideNav.Item
    //   title="Block Explorers & Tools"
    //   slug="#block-explorers-tools"
    // />
    // <SideNav.Item title="Knowledge Base" slug="#knowledge" />
  };
};

module Section = {
  [@react.component]
  let make = (~title, ~subhead=?, ~slug, ~children) => {
    <section className=Styles.section id=slug>
      <h2 className=Theme.Type.h2> {React.string(title)} </h2>
      <Spacer height=1.5 />
      {switch (subhead) {
       | Some(subhead) =>
         <p className=Theme.Type.sectionSubhead> {React.string(subhead)} </p>
       | None => React.null
       }}
      <Spacer height=4. />
      children
      <Spacer height=6.5 />
    </section>;
  };
};

module Roles = {
  module Role = {
    [@react.component]
    let make = (~img, ~title, ~copy, ~linkCopy, ~linkUrl) => {
      <div className=Styles.singleRowContainer>
        <img src=img />
        <Spacer height=1. />
        <h4 className=Theme.Type.h4> {React.string(title)} </h4>
        <Spacer height=0.5 />
        <p className=Theme.Type.paragraph> {React.string(copy)} </p>
        <Spacer height=0.5 />
        <Next.Link href=linkUrl>
          <span className=Styles.roleLink>
            <p> {React.string(linkCopy)} </p>
            <Icon kind=Icon.ArrowRightMedium />
          </span>
        </Next.Link>
      </div>;
    };
  };

  [@react.component]
  let make = () => {
    <div>
      <Spacer height=1. />
      <h3 className=Theme.Type.h3> {React.string("Two Roles")} </h3>
      <Spacer height=2. />
      <div className=Styles.rolesContainer>
        <Role
          img="/static/img/BlockProducers_2x.svg"
          title="Block Producers"
          copy={js|Similar to miners or stakers in other protocols, block producers can be selected to produce a block and earn block rewards, coinbase, transaction fees and network fees. Block producers can also be SNARK producers and generate their own proofs.|js}
          linkCopy="Block Producer Documentation"
          linkUrl="/docs"
        />
        <Role
          img="/static/img/SnarkProducers_2x.svg"
          title="Snark Producers"
          copy={js|SNARK producers help compress data in the network by generating SNARK proofs of transactions. They then sell those SNARK proofs to block producers on the Snarketplace in return for a portion of the block rewards|js}
          linkCopy="Snark Producer Documentation"
          linkUrl="/docs"
        />
      </div>
    </div>;
  };
};
module RunNode = {
  module RunNodeSection = {
    [@react.component]
    let make = (~sectionNumber, ~title, ~copy) =>
      <div className=Styles.runNodeContent>
        <h1 className=Theme.Type.h1> {React.string(sectionNumber)} </h1>
        <Spacer height=0.5 />
        <h4 className=Theme.Type.h4> {React.string(title)} </h4>
        <Spacer height=0.5 />
        <p className=Theme.Type.paragraph> {React.string(copy)} </p>
      </div>;
  };
  [@react.component]
  let make = () =>
    <div className=Styles.runNodeContainer>
      <Spacer height=1. />
      <h3 className=Theme.Type.h3> {React.string("Run a Node")} </h3>
      <div>
        <div className=Styles.nodesContainer>
          <RunNodeSection
            sectionNumber="01"
            title="Install Mina"
            copy={js|Check the systems requirements and install Mina. It’s around 1GB — which is smaller than most, but still takes some time.|js}
          />
          <RunNodeSection
            sectionNumber="02"
            title="Connect to Network"
            copy={js|Configure your network and use the provided seed nodes to connect to the live peer-to-peer Mina network.|js}
          />
          <RunNodeSection
            sectionNumber="03"
            title="Send A Transaction"
            copy={js|Create a new account. Request Mina tokens from the faucet. Then send funds to Mina’s echo service, and you’re done!|js}
          />
        </div>
        <Spacer height=3. />
        <Button
          href={`Internal("/docs")}
          bgColor=Theme.Colors.orange
          width={`rem(15.)}>
          {React.string("Go To Documentation")}
          <Icon kind=Icon.ArrowRightMedium />
        </Button>
      </div>
    </div>;
};

module NodeOverview = {
  [@react.component]
  let make = () =>
    <div
      className={Styles.sectionContainer("/static/img/tech-gradient-1.jpg")}>
      <Spacer height=6.5 />
      <hr className=Styles.divider />
      <Section
        title="Node Overview"
        subhead={js|Mina is secured by proof-of-stake consensus. Unlike other legacy protocols, any participant can validate transactions like a full node — making decentralization possible. And here, node operators can play two roles: they can produce blocks, and/or they can produce SNARKs.|js}
        slug="how-mina-works">
        <hr className=Styles.divider />
        <Roles />
        <Spacer height=3. />
        <hr className=Styles.divider />
        <RunNode />
        <Spacer height=13.5 />
      </Section>
    </div>;
};

module BlockExplorersAndTools = {
  module BlockExplorerAndTool = {
    [@react.component]
    let make = (~img, ~title, ~copy, ~linkCopy, ~linkUrl) =>
      <div className=Styles.blockExplorerCard>
        <img src=img />
        <Spacer height=1. />
        <h4 className=Theme.Type.h4> {React.string(title)} </h4>
        <Spacer height=0.5 />
        <p className=Theme.Type.paragraph> {React.string(copy)} </p>
        <Spacer height=0.5 />
        <Next.Link href=linkUrl>
          <span className=Styles.roleLink>
            <p> {React.string(linkCopy)} </p>
            <Icon kind=Icon.ExternalLink />
          </span>
        </Next.Link>
        <Spacer height=1. />
      </div>;
  };
  module BlockAndToolsGrid = {
    [@react.component]
    let make = () =>
      <div className=Styles.blockAndToolsGrid>
        <BlockExplorerAndTool
          img="/static/img/BlockExplorerAndTool.png"
          title="Mina Block Explorer"
          copy="Get access to key data like the number of active nodes, transactions and blocks."
          linkCopy="Check It Out"
          linkUrl="/docs"
        />
        <BlockExplorerAndTool
          img="/static/img/BlockExplorerAndTool.png"
          title="Block Producer Performance Dashboard"
          copy="Understand and optimize your block production with metrics pulled from your nodes."
          linkCopy="Check It Out"
          linkUrl="/docs"
        />
        <BlockExplorerAndTool
          img="/static/img/BlockExplorerAndTool.png"
          title="Snark Producer Performance Dashboard"
          copy="Understand and optimize your SNARK operation and pricing with metrics pulled from your  nodes."
          linkCopy="Check It Out"
          linkUrl="/docs"
        />
        <BlockExplorerAndTool
          img="/static/img/BlockExplorerAndTool.png"
          title="The Mina Snarketplace"
          copy="Tour the market where block and SNARK producers buy and sell SNARKs."
          linkCopy="Check It Out"
          linkUrl="/docs"
        />
        <BlockExplorerAndTool
          img="/static/img/BlockExplorerAndTool.png"
          title="Network Health Dashboard"
          copy={js|Get a bird’s-eye-view of the Mina network with aggregated data.|js}
          linkCopy="Check It Out"
          linkUrl="/docs"
        />
      </div>;
  };

  [@react.component]
  let make = () =>
    <div
      className={Styles.sectionContainer(
        "/static/img/MinaSpectrumPrimary1.jpg",
      )}>
      <Spacer height=6. />
      <Section title="Block Explorers & Tools" slug="block-explorers-tools">
        <BlockAndToolsGrid />
        <Spacer height=12.5 />
      </Section>
    </div>;
};

[@react.component]
let make = () => {
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Nav.Styles.spacer />
    <Hero
      background={
        Theme.desktop: "/static/img/NodeOperatorHero.jpg",
        Theme.tablet: "/static/img/NodeOperatorHero.jpg",
        Theme.mobile: "/static/img/NodeOperatorHero.jpg",
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
        <Spacer width=1. />
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
        image: "/static/img/NodeOperators_large.jpg",
        background: Image("/static/img/MinaSpectrumPrimarySilver.jpg"),
        contentBackground: Image("/static/img/BecomeAGenesisMember.jpg"),
        link:
          FeaturedSingleRow.Row.Button({
            FeaturedSingleRow.Row.buttonText: "Go to Testnet",
            buttonColor: Theme.Colors.orange,
            buttonTextColor: Theme.Colors.white,
            dark: true,
            href: `Internal("/testnet"),
          }),
      }
    />
    // TODO: Not currently ready to ship. Update component with proper info when available.
    //<BlockExplorersAndTools />
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
        link:
          {FeaturedSingleRow.Row.Button({
             buttonColor: Theme.Colors.mint,
             buttonTextColor: Theme.Colors.digitalBlack,
             buttonText: "Learn More",
             dark: true,
             href: `Internal("/genesis"),
           })},
      }
    />
    // TODO: Knowledge Base
    <section id="help-and-support">
      <ButtonBar
        kind=ButtonBar.HelpAndSupport
        backgroundImg="/static/img/ButtonBarBackground.jpg"
      />
    </section>
  </Page>;
};
