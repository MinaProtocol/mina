module Styles = {
  open Css;

  let container =
    style([
      display(`none),
      media(Theme.MediaQuery.desktop, [display(`block)]),
    ]);
};

[@react.component]
let make = (~currentSlug) => {
  module Item = SideNav.Item;
  module Section = SideNav.Section;
  let f = s => "/docs/" ++ s;
  <div className=Styles.container>
    <SideNav currentSlug>
      <Item title="Overview" slug="/docs" />
      <Item title="Getting Started" slug={f("getting-started")} />
      <Item title="My First Transaction" slug={f("my-first-transaction")} />
      <Item title="Become a Node Operator" slug={f("node-operator")} />
      <Item title="Contributing to Mina" slug={f("contributing")} />
      <Section title="Developers" slug={f("developers")}>
        <Item title="Developers Overview" slug="" />
        <Item title="Codebase Overview" slug="codebase-overview" />
        <Item title="Repository Structure" slug="directory-structure" />
        <Item title="Code Reviews" slug="code-reviews" />
        <Item title="Style Guide" slug="style-guide" />
        <Item title="Sandbox Node" slug="sandbox-node" />
        <Item title="GraphQL API" slug="graphql-api" />
      </Section>
      <Section title="Mina Protocol Architecture" slug={f("architecture")}>
        <Item title="Mina Overview" slug="" />
        <Item title="Lifecycle of a Payment" slug="lifecycle-payment" />
        <Item title="Consensus" slug="consensus" />
        <Item title="Proof of Stake" slug="proof-of-stake" />
        <Item title="Snark Workers" slug="snark-workers" />
      </Section>
      <Section title="SNARKs" slug={f("snarks")}>
        <Item title="SNARKs Overview" slug="" />
        <Item title="Getting started using SNARKs" slug="snarky" />
        <Item title="Which SNARK is right for me?" slug="constructions" />
        <Item title="The snarkyjs-crypto library" slug="snarkyjs-crypto" />
        <Item title="The snarky-universe library" slug="snarky-universe" />
      </Section>
      <Item title="Snapps" slug={f("snapps")} />
      <Item title="CLI Reference" slug={f("cli-reference")} />
      <Item title="Tokens" slug={f("tokens")} />
      <Item title="Troubleshooting" slug={f("troubleshooting")} />
      <Item title="FAQ" slug={f("faq")} />
      <Item title="Glossary" slug={f("glossary")} />
    </SideNav>
  </div>;
};
