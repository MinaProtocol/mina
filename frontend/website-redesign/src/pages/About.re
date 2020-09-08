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
          [
            height(`rem(41.)),
            backgroundImage(`url("/static/img/02_About_1_2880x1504.jpg")),
          ],
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
            [padding2(~v=`rem(1.5), ~h=`rem(1.5)), width(`rem(27.))],
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
    let rowsSection =
      style([backgroundImage(`url("/static/img/BackgroundAbout.png"))]);
    let container =
      style([
        backgroundSize(`cover),
        display(`flex),
        flexDirection(`column),
        padding2(~v=`rem(3.), ~h=`rem(3.)),
        media(
          Theme.MediaQuery.desktop,
          [
            flexDirection(`row),
            justifyContent(`spaceBetween),
            width(`rem(80.5)),
            padding2(~v=`rem(3.), ~h=`rem(9.2)),
          ],
        ),
      ]);
    let column =
      style([
        display(`flex),
        flexDirection(`column),
        justifyContent(`flexStart),
        media(Theme.MediaQuery.desktop, [width(`rem(35.))]),
      ]);
    let header = Theme.Type.h2;
    let subhead =
      merge([Theme.Type.sectionSubhead, style([letterSpacing(`px(-1))])]);
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
    let imageContainer = style([position(`relative)]);

    let copy = Theme.Type.paragraph;
  };

  module Row = {
    [@react.component]
    let make = (~children) => {
      <div className=Styles.container> children </div>;
    };
  };

  [@react.component]
  let make = () => {
    <div className=Styles.rowsSection>
      <Row>
        <div className=Styles.column>
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
          <p className=Styles.copy>
            {React.string(
               "Even when we try to escape this power imbalance and participate in blockchains, most of us give up control and trust to third parties to verify transactions. Why? Because running a full node requires expensive hardware, unsustainable amounts of electricity and tons of time to sync increasingly heavier and heavier chains.",
             )}
          </p>
          <p className=Styles.copy>
            <strong>
              {React.string("But it doesn't have to be this way. ")}
            </strong>
          </p>
        </div>
        <img
          className=Styles.heroRowImage
          src="/static/img/02_About_2_1232x1232.jpg"
        />
      </Row>
      <Spacer height=7.93 />
      <Row>
        <img
          className=Styles.heroRowImage
          src="/static/img/02_About_3_1232x1364.jpg"
        />
        <div className=Styles.column>
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
               and recursive zk-SNARKs. Over the past three years,
               our team together with our incredible
               community have launched and learned through several
               testnet phases. And now, at long last, we are proud
               to introduce Mina to the wider world. Here, developers
               can build powerful applications like Snapps (SNARK-powered apps)
               to offer financial services without compromising data privacy
               and programmable money that anyone can access trustlessly from their phones. And that's just the beginning.
               While there will still be challenges to come, the world's lightest, most accessible blockchain is ready to be powered by a whole new generation of participants. Here's to a more efficient, elegant and fair future - for all of us.",
             )}
          </p>
          <p className=Styles.copy>
            <strong>
              {React.string(
                 "Here's to a more efficient, elegant and fair future - for all of us.",
               )}
            </strong>
          </p>
        </div>
      </Row>
    </div>;
  };
};

// TODO: Change title
[@react.component]
let make = () => {
  <div>
    <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
      <Hero />
      <Spacer height=1. />
      <HeroRows />
      <QuoteSection />
    </Page>
  </div>;
};
