module Link = {
  let component = ReasonReact.statelessComponent("GetInvolved.Link");
  let make = (~message, _) => {
    ...component,
    render: _ => {
      <a className=Style.Link.basic>
        {ReasonReact.string(message ++ {js|\u00A0→|js})}
      </a>;
    },
  };
};

module KnowledgeBase = {
  module SubSection = {
    let component =
      ReasonReact.statelessComponent("GetInvolved.KnowledgeBase.SubSection");
    let make = (~title, ~content, _) => {
      ...component,
      render: _ => {
        let items =
          Belt.Array.map(content, ((copy, link)) =>
            <li>
              <a href=link className=Style.Link.basic>
                {ReasonReact.string(copy)}
              </a>
            </li>
          );

        <div>
          <h5 className=Style.H5.basic> {ReasonReact.string(title)} </h5>
          <ul> ...items </ul>
        </div>;
      },
    };
  };

  let component = ReasonReact.statelessComponent("GetInvolved.KnowledgeBase");
  let make = _ => {
    ...component,
    render: _ => {
      <div>
        <h4 className=Css.(style([textAlign(`center)]))>
          {ReasonReact.string("Knowledge base")}
        </h4>
        <div
          className=Css.(
            style([
              display(`flex),
              justifyContent(`center),
              flexWrap(`wrap),
            ])
          )>
          <SubSection
            title="Articles"
            content=[|
              ("Fast Accumulation on Streams", "#"),
              ("Coindesk: This Blockchain Tosses Blocks", "#"),
              ("TokenDaily: Deep Dive with O(1) on Coda Protocol", "#"),
            |]
          />
          <SubSection
            title="Videos & Podcasts"
            content=[|
              ("Hack Summit 2018: Coda Talk", "#"),
              ("Token Talks - Interview with Coda", "#"),
              ("A High-Level Language for Verifiable Computation", "#"),
              ("Snarky, a DSL for Writing SNARKs", "#"),
            |]
          />
        </div>
      </div>;
    },
  };
};

module SocialLink = {
  let component = ReasonReact.statelessComponent("GetInvolved.SocialLink");
  let make = (~icon, ~name, _) => {
    ...component,
    render: _ => {
      <div
        className=Css.(
          style([
            display(`flex),
            justifyContent(`center),
            alignItems(`center),
          ])
        )>
        <Svg link=icon dims=(2.0, 2.0) />
        <h3 className=Style.H3.wide> {ReasonReact.string(name)} </h3>
      </div>;
    },
  };
};

let component = ReasonReact.statelessComponent("GetInvolved");
let make = _ => {
  ...component,
  render: _self =>
    <div>
      <h1
        className=Css.(
          merge([
            Style.H1.hero,
            style([color(Style.Colors.denimTwo), textAlign(`center)]),
          ])
        )>
        {ReasonReact.string("Get Involved")}
      </h1>
      <div
        className=Css.(
          style([display(`flex), justifyContent(`center), flexWrap(`wrap)])
        )>
        <p
          className=Css.(
            merge([Style.Body.basic, style([maxWidth(`rem(22.5))])])
          )>
          {ReasonReact.string(
             "Help us build a more accessible, sustainable cryptocurrency. Join our community on discord, and follow our progress on twitter.",
           )}
        </p>
        <ul>
          <li> <Link message="Stay updated about developing with Coda" /> </li>
          <li>
            <Link message="Notify me about participating in consensus" />
          </li>
          <li>
            <Link message="Earn Coda by helping to compress the blockchain" />
          </li>
          <li> <Link message="Join our mailing list for updates" /> </li>
        </ul>
      </div>
      <div
        className=Css.(
          style([
            display(`flex),
            justifyContent(`center),
            alignItems(`center),
          ])
        )>
        <SocialLink icon="/static/img/leaf.svg" name="Twitter" />
        <SocialLink icon="/static/img/leaf.svg" name="Discord" />
        <SocialLink icon="/static/img/leaf.svg" name="Telegram" />
      </div>
      <KnowledgeBase />
    </div>,
};
