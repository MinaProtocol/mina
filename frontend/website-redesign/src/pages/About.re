open Css;

module Hero = {
  module Styles = {
    let heroContainer =
      style([
        display(`flex),
        flexDirection(`column),
        justifyContent(`flexStart),
        alignContent(`spaceBetween),
        backgroundImage(`url("/static/img/02_About_1_750x1056_mobile.jpg")),
        backgroundSize(`cover),
        media(
          Theme.MediaQuery.tablet,
          [
            backgroundImage(
              `url("/static/img/02_About_1_1536x1504_tablet.jpg"),
            ),
          ],
        ),
        media(
          Theme.MediaQuery.desktop,
          [backgroundImage(`url("/static/img/02_About_1_2880x1504.jpg"))],
        ),
      ]);
    let heroContent =
      style([
        marginTop(`rem(4.2)),
        marginBottom(`rem(1.9)),
        marginLeft(`rem(1.25)),
        media(
          Theme.MediaQuery.tablet,
          [
            marginTop(`rem(7.)),
            marginBottom(`rem(6.5)),
            marginLeft(`rem(2.5)),
          ],
        ),
        media(
          Theme.MediaQuery.desktop,
          [
            marginTop(`rem(17.1)),
            marginBottom(`rem(8.)),
            marginLeft(`rem(9.5)),
          ],
        ),
      ]);
    let headerLabel =
      merge([
        Theme.Type.label,
        style([color(black), marginTop(`zero), marginBottom(`zero)]),
      ]);
    let header =
      merge([
        Theme.Type.h1,
        style([
          unsafe("width", "max-content"),
          backgroundColor(white),
          marginRight(`rem(1.)),
          fontSize(`rem(1.5)),
          padding2(~v=`rem(1.3), ~h=`rem(1.3)),
          media(
            Theme.MediaQuery.desktop,
            [padding2(~v=`rem(1.5), ~h=`rem(1.5))],
          ),
          marginTop(`rem(1.)),
          marginBottom(`rem(1.5)),
        ]),
      ]);
    let headerCopy =
      merge([
        Theme.Type.pageSubhead,
        style([
          backgroundColor(white),
          padding2(~v=`rem(1.5), ~h=`rem(1.5)),
          marginRight(`rem(1.)),
          media(Theme.MediaQuery.tablet, [width(`rem(34.))]),
          marginTop(`zero),
          marginBottom(`zero),
        ]),
      ]);
  };

  // TODO: Add title
  [@react.component]
  let make = () => {
    <div className=Styles.heroContainer>
      <div className=Styles.heroContent>
        <h4 className=Styles.headerLabel> {React.string("About")} </h4>
        <h1 className=Styles.header>
          {React.string("We're on a mission.")}
        </h1>
        <p className=Styles.headerCopy>
          {React.string(
             "To create a vibrant decentralized network and open programmable currency - so we can all participate, build, exchange and thrive.",
           )}
        </p>
      </div>
    </div>;
  };
};

/** Section for alternating rows */
module HeroRows = {
  module Styles = {
    let rowBackgroundImage =
      style([
        height(`px(1924)),
        width(`percent(100.)),
        important(backgroundSize(`cover)),
        backgroundImage(`url("/static/img/BackgroundGlowCluster01.png")),
      ]);
    let container =
      style([
        display(`flex),
        flexDirection(`column),
        media(
          Theme.MediaQuery.desktop,
          [
            position(`relative),
            flexDirection(`row),
            padding2(~h=`rem(9.5), ~v=`rem(11.6)),
          ],
        ),
      ]);

    /** Can reuse and extract into a reusable component in the future */
    let column =
      style([
        display(`flex),
        flexDirection(`column),
        justifyContent(`flexStart),
        media(Theme.MediaQuery.desktop, [width(`rem(35.))]),
      ]);

    /* First and second rows  */
    let firstColumn = merge([column, style([marginRight(`rem(7.))])]);
    let secondColumn = merge([column, style([marginLeft(`rem(35.))])]);

    let header = merge([Theme.Type.h2, style([width(`rem(18.2))])]);
    let subhead =
      merge([
        Theme.Type.sectionSubhead,
        style([
          marginTop(`rem(1.5)),
          letterSpacing(`px(-1)),
          marginBottom(`rem(1.5)),
        ]),
      ]);
    let heroRowImage =
      style([
        height(`rem(21.)),
        width(`rem(21.)),
        media(
          Theme.MediaQuery.desktop,
          [height(`rem(38.5)), width(`rem(38.5))],
        ),
        unsafe("object-fit", "cover"),
      ]);
    let firstImage =
      merge([heroRowImage, style([position(`absolute), right(`zero)])]);
    let secondImage =
      merge([
        heroRowImage,
        style([
          position(`absolute),
          left(`zero),
          backgroundImage(`url("/static/img/triangle_mobile.png")),
          media(
            Theme.MediaQuery.tablet,
            [backgroundImage(`url("/static/img/triangle_tablet.png"))],
          ),
          media(
            Theme.MediaQuery.desktop,
            [backgroundImage(`url("/static/img/triangle_desktop.png"))],
          ),
        ]),
      ]);
    let imageContainer = style([position(`relative)]);

    let copy = Theme.Type.paragraph;
    let rule =
      style([
        width(`percent(100.)),
        color(Theme.Colors.digitalBlack),
        border(`px(1), `solid, black),
      ]);
    let orange =
      merge([copy, style([display(`inlineBlock), color(orange)])]);
  };

  [@react.component]
  let make = () => {
    <div className=Styles.rowBackgroundImage>
      <div className=Styles.container>
        <div className=Styles.firstColumn>
          <hr className=Styles.rule />
          <h2 className=Styles.header>
            {React.string("It's Time to Own Our Future")}
          </h2>
          <p className=Styles.subhead>
            {React.string(
               "Living in today's world requires giving up a lot of control.",
             )}
          </p>
          <p className=Styles.copy>
            {React.string(
               "Every day, we give up control of intimate data to large tech companies to use online services. We give up control of our finances to banks and unaccountable credit bureaus. We give up control of our elections to voting system companies who run opaque and unauditable elections. ",
             )}
          </p>
          <Spacer height=1.75 />
          <p className=Styles.copy>
            {React.string(
               "Even when we try to escape this power imbalance and participate in blockchains, most of us give up control and trust to third parties to verify transactions. Why? Because running a full node requires expensive hardware, unsustainable amounts of electricity and tons of time to sync increasingly heavier and heavier chains.",
             )}
          </p>
          <Spacer height=1.75 />
          <p className=Styles.copy>
            <strong>
              {React.string("But it doesn't have to be this way. ")}
            </strong>
          </p>
        </div>
        <img
          className=Styles.firstImage
          src="/static/img/02_About_2_1232x1232.jpg"
        />
      </div>
      <Spacer height=7.93 />
      <div className=Styles.container>
        <div className=Styles.secondImage />
        <div className=Styles.secondColumn>
          <p className=Styles.subhead>
            {React.string("That's why we created Mina.")}
          </p>
          <p className=Styles.copy>
            {React.string(
               "In June of 2017, O(1) Labs kicked off an ambitious
               new open source project to design a layer one protocol
               that could deliver on the original promise of blockchain
               - true decentralization, scale and security.
               Rather than apply brute computing force, Mina offers
               an elegant solution using advanced cryptography
               and recursive zk-SNARKs. ",
             )}
          </p>
          <Spacer height=1. />
          <p className=Styles.copy>
            {React.string(
               "Over the past three years,
               our team together with our incredible
               community have launched and learned through several
               testnet phases. And now, at long last, we are proud
               to introduce Mina to the wider world. Here, developers
               can build ",
             )}
            <span className=Styles.orange>
              {React.string("powerful applications ")}
            </span>
            {React.string(
               " like Snapps (SNARK-powered apps)
               to offer financial services without compromising data privacy
               and programmable money that anyone can access trustlessly from their phones.
               And that's just the beginning.",
             )}
          </p>
          <Spacer height=1. />
          <p className=Styles.copy>
            {React.string(
               "While there will still be challenges to come, the world's lightest, most accessible blockchain is ready to be powered by a whole new generation of participants.",
             )}
          </p>
          <Spacer height=1. />
          <p className=Styles.copy>
            <strong>
              {React.string(
                 "Here's to a more efficient, elegant and fair future - for all of us.",
               )}
            </strong>
          </p>
        </div>
      </div>
    </div>;
  };
};

[@react.component]
let make = () => {
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <Hero />
    <HeroRows />
    <QuoteSection />
  </Page>;
};
