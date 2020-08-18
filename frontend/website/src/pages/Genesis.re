module Styles = {
  open Css;
  let page =
    style([
      marginLeft(`auto),
      marginRight(`auto),
      media(Theme.MediaQuery.tablet, [maxWidth(`rem(68.))]),
    ]);

  let lineBreak =
    style([
      height(px(2)),
      borderTop(px(1), `dashed, Theme.Colors.marine),
      borderLeft(`zero, solid, transparent),
      borderBottom(px(1), `dashed, Theme.Colors.marine),
    ]);

  let heroImage =
    style([
      display(`none),
      media(
        Theme.MediaQuery.tablet,
        [display(`flex), marginRight(`rem(-6.)), marginLeft(`rem(1.))],
      ),
    ]);

  let header =
    style([
      display(`flex),
      flexDirection(`column),
      width(`percent(100.)),
      color(Theme.Colors.saville),
      textAlign(`center),
    ]);

  let heroRow =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      alignItems(`center),
      media(
        Theme.MediaQuery.tablet,
        [
          flexDirection(`row),
          alignItems(`flexEnd),
          padding2(~v=`rem(3.5), ~h=`zero),
        ],
      ),
    ]);

  let heroText =
    merge([
      header,
      style([
        maxWidth(`px(500)),
        marginLeft(`zero),
        textAlign(`left),
        color(Theme.Colors.midnight),
      ]),
    ]);

  let heroHeading =
    merge([
      Theme.H1.hero,
      style([fontWeight(`semiBold), marginTop(`rem(1.53))]),
    ]);

  let heroCopy = merge([Theme.Body.basic]);

  let heroH3 =
    merge([
      Theme.H3.basic,
      style([
        textAlign(`left),
        fontWeight(`semiBold),
        color(Theme.Colors.marine),
      ]),
    ]);

  let ctaButton =
    merge([
      Theme.Body.basic_semibold,
      style([
        width(`rem(14.)),
        height(`rem(3.)),
        backgroundColor(Theme.Colors.clover),
        borderRadius(`px(6)),
        textDecoration(`none),
        color(white),
        padding2(~v=`px(12), ~h=`px(24)),
        textAlign(`center),
        alignSelf(`center),
        hover([backgroundColor(Theme.Colors.jungle)]),
        media(
          Theme.MediaQuery.tablet,
          [marginLeft(`rem(0.)), alignSelf(`flexStart)],
        ),
      ]),
    ]);

  let whitePaperButtonRow =
    style([
      display(`grid),
      gridTemplateColumns([`percent(100.)]),
      gridTemplateRows([auto]),
      gridRowGap(`rem(0.7)),
      media(
        Theme.MediaQuery.notMobile,
        [display(`flex), flexDirection(`row)],
      ),
    ]);

  let stepRowFlex = style([display(`flex), justifyContent(`flexStart)]);
  let stepRow =
    style([
      display(`grid),
      gridTemplateColumns([`repeat((`num(1), `rem(20.)))]),
      gridTemplateRows([auto]),
      gridRowGap(`rem(1.0)),
      gridColumnGap(`rem(2.43)),
      margin(`auto),
      media(
        Theme.MediaQuery.tablet,
        [
          gridTemplateColumns([`repeat((`num(3), `rem(17.5)))]),
          gridColumnGap(`rem(1.43)),
          margin(`zero),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          gridTemplateColumns([`repeat((`num(3), `rem(20.)))]),
          gridColumnGap(`rem(2.43)),
        ],
      ),
    ]);

  let textBlock = style([maxWidth(`rem(43.75)), width(`percent(100.))]);
  let legalListBlock =
    style([maxWidth(`rem(43.)), width(`percent(100.))]);
  let legalListItem = style([marginBottom(`rem(0.25))]);
  let legalListList = style([marginLeft(`rem(1.625))]);
  let textBlockHeading =
    style([
      Theme.Typeface.ibmplexsans,
      color(Theme.Colors.saville),
      fontWeight(`medium),
      fontSize(`rem(2.)),
    ]);

  let profileRow =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`center),
      margin(`auto),
      selector("> :last-child", [marginBottom(`zero), marginRight(`zero)]),
      media(
        Theme.MediaQuery.tablet,
        [justifyContent(`flexStart), flexDirection(`row)],
      ),
    ]);

  let profile =
    style([
      marginRight(`rem(2.)),
      marginBottom(`rem(5.)),
      media(Theme.MediaQuery.tablet, [marginBottom(`zero)]),
    ]);
};

[@react.component]
let make = (~profiles) => {
  <Page
    title="Genesis"
    description="Join Genesis. Become one of 1000 community members to receive a grant of 66,000 coda tokens. You'll participate in activities that will strengthen the Coda network and community.">
    <Wrapped>
      <div className=Styles.page>
        <div className=Styles.heroRow>
          <div className=Styles.heroText>
            <h1 className=Styles.heroHeading>
              {React.string("This is Genesis")}
            </h1>
            <Spacer height=2. />
            <h3 className=Styles.heroH3>
              {React.string(
                 "Become one of 1000 community members to receive a token grant.",
               )}
            </h3>
            <Spacer height=1. />
            <p className=Styles.heroCopy>
              {React.string(
                 "You'll complete challenges on testnet, learn how to operate the protocol, receive public recognition on our leaderboard, and help to strengthen the Coda network and community.",
               )}
            </p>
            <Spacer height=2. />
            <a
              href=" https://forms.gle/Eer4yM1gb5SvLCk79"
              target="_blank"
              className=Styles.ctaButton>
              {React.string({js| Apply Now |js})}
            </a>
          </div>
          <Image
            name="/static/img/genesisHero"
            alt="Genesis Program hero image with a light blue theme."
            className=Styles.heroImage
          />
        </div>
        <Spacer height=3. />
        <h1 className=Styles.textBlockHeading>
          {React.string("Become a Genesis Founding Member")}
        </h1>
        <div className=Styles.textBlock>
          <p className=Styles.heroCopy>
            {React.string(
               "Becoming a Genesis founding member is the highest honor in the Coda community.
             You'll have an opportunity to strengthen and harden the protocol, create tooling
              and documentation, and build the community.",
             )}
          </p>
          <Spacer height=0.25 />
          <p className=Styles.heroCopy>
            {React.string(
               "When the protocol launches in mainnet, you will be the backbone of robust,
             decentralized participation. Together, we will enable the first blockchain
             that is truly decentralized at scale. ",
             )}
          </p>
        </div>
        <Spacer height=3. />
        <div className=Styles.stepRowFlex>
          <div className=Styles.stepRow>
            <StepButton
              labelStep="Step 1: "
              label="Apply Now"
              image="/static/img/ApplyCircle.svg"
              buttonLabel="Apply"
              buttonLink=" https://forms.gle/Eer4yM1gb5SvLCk79"
              target="_blank"
            />
            <StepButton
              labelStep="Step 2: "
              label="Join Discord"
              image="/static/img/DiscordCircle.svg"
              buttonLabel="Join"
              buttonLink="http://bit.ly/GenesisDiscord"
              target="_blank"
            />
            <StepButton
              labelStep="Step 3: "
              label="Participate in Testnet"
              image="/static/img/TestnetCircle.svg"
              buttonLabel="Get Started"
              buttonLink="http://bit.ly/GenesisTestnet"
            />
          </div>
        </div>
        <Spacer height=7. />
        <h1 className=Styles.textBlockHeading>
          {React.string("Meet the Genesis Founding Members")}
        </h1>
        <div className=Styles.textBlock>
          <p className=Styles.heroCopy>
            {React.string(
               "Meet a few of the 40 members who are part of Genesis Cohort 1. These community members are crucial to strengthening the Coda network. They are the backbone of the global Coda community.",
             )}
          </p>
        </div>
        <Spacer height=4. />
        <div className=Styles.profileRow>
          {React.array(
             Array.map(
               (p: ContentType.GenesisProfile.t) => {
                 <div className=Styles.profile>
                   <MemberProfile
                     key={p.name}
                     name={p.name}
                     photo={p.profilePhoto.fields.file.url}
                     quote={"\"" ++ p.quote ++ "\""}
                     location={p.memberLocation}
                     twitter={p.twitter}
                     github={p.github}
                     blogPost={p.blogPost.fields.slug}
                   />
                 </div>
               },
               profiles,
             ),
           )}
        </div>
        <Spacer height=4. />
        <h1 className=Styles.textBlockHeading> {React.string("Details")} </h1>
        <Spacer height=1. />
        <div className=Styles.legalListBlock>
          <p className=Styles.heroCopy>
            {React.string(
               "Up to 1000 members will be selected from our testnet community to receive a distribution of 66,000 tokens as founding members of Genesis.",
             )}
          </p>
          <ul className={Css.merge([Styles.heroCopy, Styles.legalListList])}>
            <li className=Styles.legalListItem>
              {React.string(
                 "At mainnet launch, 6.6% of the protocol will be distributed in this manner.",
               )}
            </li>
            <li className=Styles.legalListItem>
              {React.string(
                 "Distributions will be locked up for up to four years after mainnet launch.",
               )}
            </li>
            <li className=Styles.legalListItem>
              {React.string(
                 "Starting on mainnet launch, Genesis founding members will have to participate as block producers and continuously stake all tokens received from the Genesis Program.",
               )}
            </li>
            <li className=Styles.legalListItem>
              {React.string(
                 "New Genesis founding members will be announced on a rolling basis.",
               )}
            </li>
            <li className=Styles.legalListItem>
              {React.string(
                 "To learn more about the selection criteria and requirements, see the ",
               )}
              <Next.Link href="/tcGenesis">
                <a className=Theme.Link.basic>
                  {React.string("Terms and Conditions.")}
                </a>
              </Next.Link>
            </li>
          </ul>
        </div>
        <Spacer height=4.25 />
        <h1 className=Styles.textBlockHeading>
          {React.string("Resources")}
        </h1>
        <Spacer height=2. />
        <div className=Styles.whitePaperButtonRow>
          <WhitepaperButton
            label="Technical whitepaper"
            sigil=Icons.technical
            href="https://eprint.iacr.org/2020/352.pdf"
          />
          <Spacer width=2.5 />
          <WhitepaperButton
            label="Economics whitepaper"
            sigil=Icons.economic
            href="/static/pdf/economicsWP.pdf"
          />
        </div>
        <Spacer height=1.5 />
        <a
          className=Theme.Link.basic
          href="https://forums.codaprotocol.com/t/genesis-token-program-faq/270">
          {React.string("FAQ")}
        </a>
        <Spacer height=1. />
        <Next.Link href="/tcGenesis">
          <a className=Theme.Link.basic>
            {React.string("Terms and Conditions ")}
          </a>
        </Next.Link>
        <Spacer height=5.65 />
        <h1 className=Styles.textBlockHeading>
          {React.string("About Coda Protocol")}
        </h1>
        <div className=Styles.textBlock>
          <Spacer height=1.875 />
          <p className=Styles.heroCopy>
            <a className=Theme.Link.basic href="https://codaprotocol.com">
              {React.string("Coda Protocol")}
            </a>
            {React.string(
               ", the world's lightest blockchain, provides a foundation for the decentralized digital economy (Web 3.0),
                offering scalability to thousands of transactions per second, millions of users, and years of transaction
                 history without sacrificing security. By utilizing recursive zk-SNARKs, the Coda blockchain always stays
                  the same size"
               ++ {js|—|js}
               ++ "about 20 kilobytes (the size of a few tweets). Recursive zk-SNARKs allow nodes to rapidly
                   share and update proof of the correct blockchain state across the network. This breakthrough application
                    of zk-SNARKs solves the issues of scalability and high barrier to entry for nodes that have plagued
                    legacy blockchains to-date. By making it easier for nodes to participate, Coda improves decentralization
                     and therefore security of the network. The Coda blockchain can be easily accessed from any device,
                      including phones and browsers, and can be seamlessly integrated into new decentralized applications (dapps).",
             )}
          </p>
          <Spacer height=1.3 />
          <p className=Styles.heroCopy>
            {React.string("For regular updates on Coda, follow us on ")}
            <a
              className=Theme.Link.basic
              href="https://twitter.com/codaprotocol?lang=en">
              {React.string("Twitter")}
            </a>
            {React.string(".")}
          </p>
        </div>
      </div>
    </Wrapped>
  </Page>;
};

Next.injectGetInitialProps(make, _ => {
  Contentful.getEntries(
    Lazy.force(Contentful.client),
    {
      "include": 1,
      "content_type": ContentType.GenesisProfile.id,
      "order": "-fields.publishDate",
      "limit": 3,
    },
  )
  |> Promise.map((entries: ContentType.GenesisProfile.entries) => {
       let profiles =
         Array.map(
           (e: ContentType.GenesisProfile.entry) => e.fields,
           entries.items,
         );
       {"profiles": profiles};
     })
});
