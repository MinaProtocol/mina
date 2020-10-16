open Css;
module Styles = {
  let rowBackgroundImage =
    style([
      height(`percent(100.)),
      width(`percent(100.)),
      important(backgroundSize(`cover)),
      backgroundImage(`url("/static/img/BackgroundGlowCluster01.jpg")),
    ]);

  let container =
    style([
      display(`flex),
      flexDirection(`column),
      padding2(~h=`rem(1.5), ~v=`rem(1.5)),
      media(
        Theme.MediaQuery.desktop,
        [
          position(`relative),
          flexDirection(`row),
          maxWidth(`rem(96.)),
          margin2(~v=`zero, ~h=`auto),
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
      width(`percent(100.)),
      media(Theme.MediaQuery.tablet, [width(`rem(21.))]),
      media(Theme.MediaQuery.desktop, [width(`rem(35.))]),
    ]);

  /* First and second rows  */
  let firstColumn =
    merge([
      column,
      style([
        media(Theme.MediaQuery.tablet, [marginRight(`rem(15.))]),
        media(Theme.MediaQuery.desktop, [marginRight(`rem(7.))]),
      ]),
    ]);
  let secondColumn =
    merge([
      column,
      style([
        marginLeft(`zero),
        media(Theme.MediaQuery.tablet, [marginLeft(`rem(23.))]),
        media(Theme.MediaQuery.desktop, [marginLeft(`rem(35.))]),
      ]),
    ]);

  let header =
    merge([
      Theme.Type.h2,
      style([
        marginTop(`rem(2.06)),
        media(Theme.MediaQuery.desktop, [width(`rem(18.2))]),
      ]),
    ]);
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
      width(`rem(21.)),
      marginTop(`rem(1.)),
      media(
        Theme.MediaQuery.desktop,
        [marginTop(`zero), height(`rem(38.5)), width(`rem(38.5))],
      ),
    ]);
  let firstImage =
    merge([
      heroRowImage,
      style([
        media(
          Theme.MediaQuery.tablet,
          [position(`absolute), right(`zero)],
        ),
      ]),
    ]);
  let secondImage =
    merge([
      heroRowImage,
      style([
        backgroundImage(`url("/static/img/triangle_mobile.png")),
        media(
          Theme.MediaQuery.tablet,
          [
            position(`absolute),
            left(`zero),
            backgroundImage(`url("/static/img/triangle_tablet.png")),
          ],
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
    merge([
      copy,
      style([
        display(`inlineBlock),
        textDecoration(`none),
        color(Theme.Colors.orange),
      ]),
    ]);
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
        src="/static/img/AboutHeroRow1Image.jpg"
      />
    </div>
    <div className=Styles.container>
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
          <Next.Link href="/docs">
            <span className=Styles.orange>
              {React.string("powerful applications ")}
            </span>
          </Next.Link>
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
        <img
          className=Styles.secondImage
          src="/static/img/triangle_desktop.png"
        />
      </div>
    </div>
  </div>;
};
