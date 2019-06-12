let extraHeaders = () => <> {Head.legacyStylesheets()} </>;

{
  open Css;
  // Hide social links
  global("#block-explorer div div a.no-underline", [display(`none)]);
  // Hide header text
  global("#block-explorer div h2", [display(`none)]);
  // Make everything IBM plex sans
  global(
    ".roboto",
    [
      Style.Typeface.ibmplexsans,
      color(Style.Colors.saville),
      fontSize(`px(16)),
    ],
  );
  global(
    "#block-explorer .bg-lemoncurry",
    [Style.Typeface.ibmplexsans, fontWeight(`medium), fontSize(`px(16))],
  );

  // Remove the "status down" lemon curry popup as it's inaccurate
  global(".darksnow.tc.bg-lemoncurry", [display(`none)]);

  // Remove fade in of explanations
  global(".animate-opacity", [opacity(1.)]);

  // Remove explanations on mobile
  global(".o-90", [display(`none)]);

  // Remove box shadows
  global(".shadow-subtle", [opacity(1.), boxShadow(transparent)]);

  // Set explaination (and container contents) colors to white
  global(".bg-darksnow", [backgroundColor(white)]);

  // Remove borders around explanations
  global(".b-sky", [border(`zero, `none, transparent)]);

  // Remove border around merkle path previous state hash column
  global(
    "svg ~ div.b-silver",
    [
      margin(`zero),
      marginTop(`rem(-0.3)),
      padding(`zero),
      border(`zero, `none, transparent),
    ],
  );

  // Container contents
  global(
    ".bg-darksnow .ocean",
    [
      backgroundColor(`hex("eff2f7")),
      padding(`rem(0.75)),
      fontSize(`rem(0.875)),
      Style.Typeface.ibmplexsans,
      color(Style.Colors.saville),
    ],
  );

  // zk-Snark container
  global(
    ".shadow-subtle .grass-gradient",
    [Style.Typeface.ibmplexsans, color(Style.Colors.saville)],
  );

  // Disable red state since the demo is broken
  global(
    ".bg-brightred div",
    [
      backgroundColor(Style.Colors.teal),
      Style.Typeface.ibmplexsans,
      color(Style.Colors.saville),
    ],
  );

  global(
    ".shadow-small1.bg-brightred",
    [backgroundColor(`hex("bcbcbc")), boxShadow(transparent)],
  );

  global(
    ".state-with-proof div:nth-child(2) div .mw5 > div:nth-child(2)",
    [display(`none)],
  );

  // Header on other containers
  global(
    "div.silver-gradient div",
    [
      backgroundColor(Style.Colors.teal),
      Style.Typeface.ibmplexsans,
      color(Style.Colors.saville),
    ],
  );
  // Dot on other containers
  global(
    "div.silver-gradient div div div",
    [backgroundColor(`hex("bcbcbc")), boxShadow(transparent)],
  );

  // Style carets
  global(
    ".f1",
    [
      fontSize(`rem(5.)),
      color(Style.Colors.tealAlpha(0.2)),
      marginLeft(`zero),
      marginRight(`zero),
    ],
  );

  // Make things wider
  global(".mw5", [maxWidth(`rem(20.))]);

  // Smaller border radius
  global(".br3", [borderRadius(`px(5))]);
  global(
    ".br--top",
    [borderBottomLeftRadius(`px(0)), borderBottomRightRadius(`px(0))],
  );
  global(
    ".br--bottom",
    [borderTopLeftRadius(`px(0)), borderTopRightRadius(`px(0))],
  );

  // Style titles
  global(
    ".record-title-padding",
    [
      fontSize(`px(20)),
      color(Style.Colors.midnight),
      lineHeight(`rem(1.2)),
      marginBottom(`rem(1.5)),
    ],
  );
};
let component = ReasonReact.statelessComponent("Testnet");

let rightSideText =
  Css.(
    style([
      margin(`zero),
      Style.Typeface.ibmplexsans,
      color(Style.Colors.saville),
      fontWeight(`medium),
      lineHeight(`rem(1.5)),
      marginTop(`rem(1.)),
    ])
  );
let rightSideLink =
  Css.(
    merge([
      Style.Link.basic,
      rightSideText,
      style([
        marginTop(`rem(0.75)),
        display(`block),
        cursor(`pointer),
        color(Style.Colors.hyperlink),
        hover([color(Style.Colors.hyperlinkHover)]),
      ]),
    ])
  );

let make = _ => {
  ...component,
  render: _self =>
    <section>
      <h3
        className=Css.(
          merge([
            Style.H3.wings,
            style([marginTop(`rem(1.25)), marginBottom(`rem(3.0))]),
          ])
        )>
        {ReasonReact.string("Testnet")}
      </h3>
      <div
        className=Css.(
          style([
            display(`flex),
            flexWrap(`wrap),
            flexDirection(`column),
            justifyContent(`spaceBetween),
            maxWidth(`rem(32.)),
            marginLeft(`auto),
            marginRight(`auto),
            media(
              Style.MediaQuery.notMobile,
              [justifyContent(`spaceAround)],
            ),
          ])
        )>
        <div
          className=Css.(
            merge([
              Style.Body.basic,
              style([
                marginLeft(`rem(1.)),
                marginRight(`rem(1.)),
                marginTop(`rem(1.)),
                marginBottom(`zero),
              ]),
            ])
          )>
          {ReasonReact.string(
             "Public Testnet Beta is launching soon. See below \
              for an explanation of how the protocol state and \
              account balance are verified.",
           )}
        </div>
        <div
          className=Css.(
            style([
              maxWidth(`rem(25.)),
              marginLeft(`rem(1.)),
              marginRight(`rem(1.)),
            ])
          )>
          <A
            name={"testnet-" ++ Links.Forms.participateInConsensus.name}
            target="_blank"
            href={Links.Forms.participateInConsensus.link}
            className=rightSideLink>
            {ReasonReact.string({js|Participate in the testnet\u00A0→|js})}
          </A>
        </div>
      </div>
      <div
        className=Css.(
          style([
            marginLeft(`auto),
            marginRight(`auto),
            marginTop(`rem(4.0)),
            display(`flex),
            justifyContent(`center),
          ])
        )
        id="block-explorer"
      />
      <script defer=true src="/static/main.bc.js" />
    </section>,
};
