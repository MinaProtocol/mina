module Styles = {
  open Css;

  let sectionContainer = bg =>
    style([
      position(`relative),
      background(`url(bg)),
      unsafe("background-size", "100% auto"),
      backgroundRepeat(`noRepeat),
      padding(`rem(2.)),
      media(Theme.MediaQuery.desktop, [padding(`zero)]),
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

  let divider =
    style([
      maxWidth(`rem(71.)),
      width(`percent(100.)),
      margin2(~v=`zero, ~h=`auto),
      height(`px(1)),
      backgroundColor(Theme.Colors.digitalBlack),
    ]);

  let typesOfGrantsImage =
    style([
      important(backgroundSize(`cover)),
      backgroundImage(`url("/static/img/MinaSpectrumBackground.jpg")),
      width(`percent(100.)),
      height(`rem(43.)),
      display(`flex),
      justifyContent(`center),
      alignItems(`center),
      media(Theme.MediaQuery.notMobile, [height(`rem(37.5))]),
    ]);

  let typesOfGrantsOuterContainer =
    style([
      display(`flex),
      justifyContent(`center),
      alignItems(`center),
      width(`percent(100.)),
      height(`percent(100.)),
      backgroundColor(white),
      media(
        Theme.MediaQuery.notMobile,
        [alignItems(`center), height(`rem(21.))],
      ),
    ]);

  let typesOfGrantsInnerContainer =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      alignItems(`center),
      height(`percent(100.)),
      width(`percent(100.)),
      padding2(~v=`rem(2.), ~h=`zero),
      borderBottom(`px(1), `solid, Theme.Colors.digitalBlack),
      borderTop(`px(1), `solid, Theme.Colors.digitalBlack),
      media(
        Theme.MediaQuery.notMobile,
        [
          flexDirection(`row),
          alignItems(`flexStart),
          height(`percent(80.)),
          width(`percent(90.)),
        ],
      ),
      selector(
        "h3",
        [width(`rem(17.)), marginRight(`rem(1.)), marginBottom(`auto)],
      ),
    ]);

  let grantRowContainer =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      alignItems(`flexStart),
      padding2(~v=`rem(6.5), ~h=`zero),
      media(
        Theme.MediaQuery.notMobile,
        [flexDirection(`row), alignItems(`center)],
      ),
    ]);

  let grantColumnContainer =
    style([
      display(`flex),
      flexDirection(`column),
      width(`rem(26.)),
      height(`percent(100.)),
      marginTop(`rem(2.)),
      media(
        Theme.MediaQuery.notMobile,
        [marginTop(`zero), marginLeft(`rem(3.))],
      ),
    ]);

  let grantRowImage =
    style([
      width(`percent(100.)),
      media(Theme.MediaQuery.notMobile, [width(`rem(35.))]),
    ]);

  let grantContainer =
    style([
      width(`rem(17.)),
      margin2(~h=`rem(1.), ~v=`rem(1.)),
      media(
        Theme.MediaQuery.notMobile,
        [flexDirection(`row), alignItems(`center)],
      ),
    ]);

  let faqList =
    style([
      marginLeft(`rem(2.)),
      selector("li", [marginTop(`rem(1.))]),
    ]);

  let grantDescriptionOuterContainer =
    style([
      display(`flex),
      flexDirection(`column),
      width(`percent(100.)),
    ]);

  let grantDescriptionInnerContainer =
    style([display(`flex), justifyContent(`spaceBetween)]);

  let grantAllocation = style([width(`percent(50.))]);
};

module GrantsSideNav = {
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
      <SideNav.Item title="Product / Front-end Projects" slug="#" />
      <SideNav.Item title="Protocol Projects" slug="#" />
      <SideNav.Item
        title="Opening Marketing and Community Projects"
        slug="#"
      />
      <SideNav.Item title="How to Apply" slug="#" />
      <SideNav.Item title="Contributers" slug="#" />
      <SideNav.Item title="FAQ" slug="#faq" />
    </SideNav>;
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

module TypesOfGrants = {
  module TypeOfGrant = {
    [@react.component]
    let make = (~img, ~title, ~copy) => {
      <div className=Styles.grantContainer>
        <img src=img />
        <h4 className=Theme.Type.h4> {React.string(title)} </h4>
        <p className=Theme.Type.paragraph> {React.string(copy)} </p>
      </div>;
    };
  };

  [@react.component]
  let make = () => {
    <div className=Styles.typesOfGrantsImage>
      <Wrapped>
        <div className=Styles.typesOfGrantsOuterContainer>
          <div className=Styles.typesOfGrantsInnerContainer>
            <h3 className=Theme.Type.h3>
              {React.string("Types of Grants")}
            </h3>
            <TypeOfGrant
              img="static/img/TechinalGrants.png"
              title="Technical Grants"
              copy="Contribute to engineering projects like web interfaces or to protocol enhancements like stablecoins."
            />
            <TypeOfGrant
              img="static/img/CommunityGrants.png"
              title="Community Grants"
              copy="Help with community organizing or create much-needed content to better serve our members."
            />
            <TypeOfGrant
              img="static/img/SubmitYourOwnGrant.png"
              title="Submit Your Own"
              copy="Share an idea for how to improve the Mina network or build the Mina community."
            />
          </div>
        </div>
      </Wrapped>
    </div>;
  };
};

module GrantRow = {
  [@react.component]
  let make = (~img, ~title, ~copy, ~buttonCopy, ~buttonUrl) => {
    <Wrapped>
      <div className=Styles.grantRowContainer>
        <img className=Styles.grantRowImage src=img />
        <div className=Styles.grantColumnContainer>
          <h2 className=Theme.Type.h2> {React.string(title)} </h2>
          <Spacer height=1. />
          <p className=Theme.Type.paragraph> {React.string(copy)} </p>
          <Spacer height=2.5 />
          <Button href={`Internal(buttonUrl)} bgColor=Theme.Colors.orange>
            {React.string(buttonCopy)}
            <Icon kind=Icon.ArrowRightMedium />
          </Button>
        </div>
      </div>
    </Wrapped>;
  };
};

module FAQ = {
  module FAQRow = {
    [@react.component]
    let make = (~title, ~children) => {
      <div>
        <Spacer height=3.5 />
        <h4 className=Theme.Type.h4> {React.string(title)} </h4>
        <Spacer height=1. />
        children
      </div>;
    };
  };
  [@react.component]
  let make = () => {
    <Wrapped>
      <Section title="General Questions" subhead="" slug="FAQ">
        <hr className=Styles.divider />
        <div>
          <FAQRow
            title="Where do I begin if I want to understand how Coda works?">
            <Spacer height=1. />
            <span className=Theme.Type.paragraph>
              <span> {React.string("Visit ")} </span>
              <Next.Link href="/docs">
                <span className=Theme.Type.link>
                  {React.string("the Mina Docs")}
                </span>
              </Next.Link>
            </span>
          </FAQRow>
          <FAQRow title="Can teams apply?">
            <Spacer height=1. />
            <span className=Theme.Type.paragraph>
              <span>
                {React.string(
                   "Yes, both individuals and teams are eligible to apply.",
                 )}
              </span>
            </span>
          </FAQRow>
          <FAQRow
            title="How do I increase my chance of getting selected for a grant?">
            <Spacer height=1. />
            <span className=Theme.Type.paragraph>
              <span> {React.string("See the ")} </span>
              <Next.Link href="/">
                <span className=Theme.Type.link>
                  {React.string("Application Process ")}
                </span>
              </Next.Link>
              <span>
                {React.string(
                   "section for selection criteria. Please also reach out to us if you have any unique skills that don't apply to current projects. You can also start ",
                 )}
              </span>
              <Next.Link href="/">
                <span className=Theme.Type.link>
                  {React.string("Contributing code to Mina ")}
                </span>
              </Next.Link>
              <span>
                {React.string(
                   "-- grants will give precedence to previous contributors.",
                 )}
              </span>
            </span>
          </FAQRow>
          <FAQRow title="What is expected of me, if I receive a grant?">
            <Spacer height=1. />
            <span className=Theme.Type.paragraph>
              <span> {React.string("We expect grant recipients to:")} </span>
              <ul className=Styles.faqList>
                <li>
                  {React.string(
                     "Communicate effectively and create a tight feedback loop",
                   )}
                </li>
                <li> {React.string("Meet project milestones")} </li>
                <li>
                  {React.string(
                     "Serve as ambassadors of Mina in the larger crypto community",
                   )}
                </li>
              </ul>
            </span>
          </FAQRow>
          <FAQRow title="Where do I go if I need help?">
            <Spacer height=1. />
            <span className=Theme.Type.paragraph>
              <span>
                {React.string(
                   "Join the Mina Discord channel or reach out to grants[at]o1labs[dot]org to get help.",
                 )}
              </span>
            </span>
          </FAQRow>
        </div>
      </Section>
    </Wrapped>;
  };
};

module Project = {
  module AllocationDescription = {
    [@react.component]
    let make = (~title, ~allocation, ~description, ~buttonUrl) =>
      <div className=Styles.grantDescriptionOuterContainer>
        <hr className=Styles.divider />
        <Spacer height=1. />
        <h3 className=Theme.Type.h3> {React.string(title)} </h3>
        <Spacer height=2. />
        <div className=Styles.grantDescriptionInnerContainer>
          <div className=Styles.grantAllocation>
            <h4 className=Theme.Type.h4> {React.string("Allocation")} </h4>
            <Spacer height=1. />
            <p className=Theme.Type.paragraph> {React.string(allocation)} </p>
          </div>
          <div className=Styles.grantAllocation>
            <h4 className=Theme.Type.h4> {React.string("Description")} </h4>
            <Spacer height=1. />
            <p className=Theme.Type.paragraph>
              {React.string(description)}
            </p>
          </div>
        </div>
        <Spacer height=4. />
        <span className=Css.(style([marginLeft(`auto)]))>
          <Button
            href={`Internal(buttonUrl)}
            bgColor=Theme.Colors.orange
            width={`rem(7.)}>
            {React.string("Apply")}
            <Icon kind=Icon.ArrowRightSmall />
          </Button>
        </span>
      </div>;
  };
};

module FrontEndProjects = {
  [@react.component]
  let make = () =>
    <div
      className={Styles.sectionContainer("/static/img/tech-gradient-1.jpg")}>
      <Spacer height=6.5 />
      <hr className=Styles.divider />
      <Section
        title="Product / Front-End Projects"
        subhead={js|Assist with building interfaces and platforms for users to interact with Mina.|js}
        slug="frontend">
        <Button href={`Internal("/docs")} bgColor=Theme.Colors.orange>
          {React.string("Install SDK")}
          <Icon kind=Icon.ArrowRightMedium />
        </Button>
        <Spacer height=4. />
        <Project.AllocationDescription
          title="Graph QL API"
          allocation={js|Minimum of $10,000 USD per month of Coda tokens (minimum 2 months commitment)|js}
          description={js|Help Coda update its GraphQL API to support new use cases. Work closely with O(1) Labs Engineering to gather requirements. You must be familiar with OCaml.|js}
          buttonUrl="/docs"
        />
      </Section>
    </div>;
};

[@react.component]
let make = () => {
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Nav.Styles.spacer />
    <Hero
      title=""
      header="Grants Program"
      copy={
        Some(
          "The Project Grant program is designed to encourage community members to work on projects related to developing the Coda protocol and community.",
        )
      }
      background={
        Theme.desktop: "/static/img/GrantsHero.jpg",
        Theme.tablet: "/static/img/GrantsHero.jpg",
        Theme.mobile: "/static/img/GrantsHero.jpg",
      }
    />
    <GrantRow
      img="/static/img/GrantsRow.jpg"
      title="Work on projects with us and earn Mina tokens"
      copy={js|About $2.1M USD in Coda token grants has been allocated to support these efforts prior to Coda’s mainnet launch. There will be additional Coda token grants allocated after mainnet.|js}
      buttonCopy="Learn More"
      buttonUrl="/docs"
    />
    <TypesOfGrants />
    <GrantsSideNav />
    <FrontEndProjects />
    <FAQ />
  </Page>;
};
