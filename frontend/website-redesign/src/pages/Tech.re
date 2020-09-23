module Styles = {
  open Css;

  let section =
    style([
      display(`grid),
      width(`rem(71.)),
      borderTop(`px(1), `solid, black),
      margin2(~v=`rem(6.5), ~h=`auto),
      paddingTop(`rem(3.)),
      backgroundPosition(`rem(-6.5), `rem(-2.)),
      gridTemplateColumns([`em(14.), `auto]),
      selector("> aside", [gridColumnStart(1)]),
      selector("> :not(aside)", [gridColumnStart(2)]),
    ]);

  let sideNav = style([position(`sticky), top(`zero), gridRowStart(1)]);
};

module Section = {
  [@react.component]
  let make = (~title, ~subhead, ~slug, ~children) => {
    <div className=Styles.section id=slug>
      <h2 className=Theme.Type.h2> {React.string(title)} </h2>
      <Spacer height=1.5 />
      <p className=Theme.Type.sectionSubhead> {React.string(subhead)} </p>
      <Spacer height=4. />
      children
    </div>;
  };
};

[@react.component]
let make = () => {
  let router = Next.Router.useRouter();
  let hashExp = Js.Re.fromString("#(.+)");
  let hash =
    Js.Re.(exec_(hashExp, router.asPath) |> Option.map(captures))
    |> Js.Option.andThen((. res) => Js.Nullable.toOption(res[0]))
    |> Js.Option.getWithDefault("");
  Js.log(hash);
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Nav.Styles.spacer />
    <Hero
      title="Tech"
      header="An Elegant Solution"
      copy="Rather than apply brute computing force, Mina uses advanced cryptography and recursive zk-SNARKs to deliver true decentralization at scale."
    />
    <Section
      title="How Mina Works"
      subhead={js|Mina is a layer one protocol designed to deliver on the original promise of blockchain — true decentralization, scale and security.|js}
      slug="how-mina-works">
      <SideNav currentSlug=hash className=Styles.sideNav>
        <SideNav.Item title="How Mina Works" slug="#how-mina-works" />
        <SideNav.Item title="Projects & Possibilities" slug="#projects" />
      </SideNav>
      <img
        src="/static/img/how-mina-works-mirrors.jpg"
        height="563"
        alt="A series of mirrors reflecting each other ad infinitum."
      />
      <Spacer height=4. />
      <p className=Theme.Type.paragraph>
        <b>
          {React.string(
             "In theory, blockchains are designed to be held accountable by its users.",
           )}
        </b>
        {React.string(
           {js|
            When anyone can enforce the rules by validating an irrevocable public
            ledger — power remains in the hands of the many, not the few. This
            decentralized structure is what allows the network to conduct trustless
            transactions.
          |js},
         )}
      </p>
      <Spacer height=1.5 />
      <p className=Theme.Type.paragraph>
        <b>
          {React.string({js|But in practice, this hasn’t been the case.|js})}
        </b>
        {React.string(
           {js|
             With legacy blockchains like Bitcoin and Ethereum, when a new participant
             joins, they have to check every transaction since the beginning of the
             network to verify correctness — which amounts to hundreds of gigabytes of
             data. Most people can’t afford the computing power it takes to verify these
             heavy chains on their own and are forced  to trust increasingly powerful
             intermediaries. This means most folks can no longer connect peer-to-peer
             — causing decentralization to suffer, power dynamics to shift, and the
             network to become more vulnerable to censorship.
          |js},
         )}
      </p>
      <Spacer height=1.5 />
      <p className=Theme.Type.paragraph>
        <b>
          {React.string(
             {js|
               Mina offers an elegant solution: replacing the blockchain with an
               easily verifiable, consistent-sized cryptographic proof.
             |js},
           )}
        </b>
        {React.string(
           {js|
             Mina dramatically reduces the amount of data each user needs to download.
             Instead of verifying the entire chain from the beginning of time,
             participants fully verify the network and transactions using recursive
             zero knowledge proofs (or zk-SNARKs). Nodes can then store just this proof,
             as opposed to the entire chain. And because it’s a consistent size, Mina
             stays accessible and can be trustlessly accessed from any device — even
             as it scales to millions of users and accumulates years of transaction data.
          |js},
         )}
      </p>
      <Spacer height=4. />
      // TODO replace with final animation
      <img
        src="/static/img/how-mina-works-mirrors.jpg"
        height="563"
        alt="A series of mirrors reflecting each other ad infinitum."
      />
      <Spacer height=4. />
      <p className=Theme.Type.paragraph>
        <b> {React.string("But how do zk-SNARKs work?")} </b>
        {React.string(
           {js|
            They capture the state of the entire blockchain as a lightweight snapshot
            and send that around — instead of the chain itself. It’s like sending your
            friend a postcard of an elephant, instead of a massive live animal. When
            the next block in the network is created, it takes a snapshot of itself
            — with the snapshot of the previous state of the blockchain as the background.
            That new snapshot will in turn be used as the backdrop for the next block,
            and so on and so on. Rather amazingly, while it can contain proof of an
            infinite amount of information, the snapshot always remains the same size.
          |js},
         )}
      </p>
      <Spacer height=1.5 />
      <p className=Theme.Type.paragraph>
        <b>
          {React.string(
             {js|
               Coming full circle, the world’s lightest blockchain empowers inclusive consensus.
             |js},
           )}
        </b>
        {React.string(
           {js|
             Our modified Ouroboros proof-of-stake protocol maximizes inclusivity in
             consensus. On Mina, all participants act as full nodes and anyone can take
             part in consensus, secure the blockchain and hold Mina accountable.
          |js},
         )}
      </p>
      <Spacer height=1.5 />
      <p className=Theme.Type.paragraph>
        <b>
          {React.string(
             {js|
               And that’s how Mina will deliver true decentralization, scale and security.
             |js},
           )}
        </b>
      </p>
    </Section>
    <Section
      title="Projects & Possibilities"
      subhead={js|Developers are already building powerful applications on Mina — but this is just the beginning.|js}
      slug="projects">
      <p className=Theme.Type.paragraph> {React.string("Built on Mina")} </p>
    </Section>
  </Page>;
};
