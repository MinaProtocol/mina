module Link = {
  let component = ReasonReact.statelessComponent("GetInvolved.Link");
  let make = (~link, ~message, _) => {
    ...component,
    render: _ => {
      <a
        href=link
        className=Css.(merge([Style.Link.basic, style([cursor(`pointer)])]))>
        {ReasonReact.string(message ++ {js|\u00A0→|js})}
      </a>;
    },
  };
};

module KnowledgeBase = {
  module SubSection = {
    let component =
      ReasonReact.statelessComponent("GetInvolved.KnowledgeBase.SubSection");
    let make = (~className="", ~title, ~content, _) => {
      ...component,
      render: _ => {
        let items =
          Belt.Array.map(content, ((copy, link)) =>
            <li
              className=Css.(
                style([
                  marginBottom(`rem(0.5)),
                  color(Style.Colors.hyperlink),
                  listStyle(`none, `inside, `none),
                  marginLeft(`rem(1.5)),
                  marginRight(`rem(1.)),
                  before([
                    unsafe("content", {js|"*"|js}),
                    color(Style.Colors.hyperlink),
                    display(`inlineBlock),
                    marginLeft(`rem(-1.)),
                    marginRight(`rem(0.6)),
                  ]),
                ])
              )>
              <a
                href=link
                className=Css.(
                  merge([Style.Link.basic, style([cursor(`pointer)])])
                )
                dangerouslySetInnerHTML={"__html": copy}
              />
            </li>
          );

        <div className>
          <h5
            className=Css.(
              merge([
                Style.H5.basic,
                style([
                  marginLeft(`zero),
                  color(Style.Colors.slate),
                  marginRight(`zero),
                  marginTop(`rem(1.)),
                  marginBottom(`rem(0.75)),
                  media(
                    Style.MediaQuery.notMobile,
                    [marginTop(`rem(1.)), marginLeft(`rem(0.5))],
                  ),
                ]),
              ])
            )>
            {ReasonReact.string(title)}
          </h5>
          <ul
            className=Css.(
              style([
                marginRight(`zero),
                paddingBottom(`zero),
                paddingLeft(`zero),
                paddingRight(`zero),
                marginBottom(`zero),
                unsafe("-webkit-padding-before", "0"),
                unsafe("-webkit-margin-before", "0"),
              ])
            )>
            ...items
          </ul>
        </div>;
      },
    };
  };

  let component = ReasonReact.statelessComponent("GetInvolved.KnowledgeBase");
  let make = (~posts, _children) => {
    ...component,
    render: _ => {
      <fieldset
        className=Css.(
          style([
            textAlign(`center),
            Style.Typeface.ibmplexserif,
            display(`block),
            border(`px(1), `solid, Style.Colors.hyperlinkAlpha(0.3)),
            borderRadius(`px(18)),
            maxWidth(`rem(58.625)),
            marginLeft(`auto),
            marginRight(`auto),
            unsafe("min-width", "min-content"),
            unsafe("padding-inline-start", "0"),
            unsafe("padding-block-start", "0"),
            unsafe("-webkit-padding-before", "0"),
            unsafe("-webkit-padding-start", "0"),
            unsafe("-webkit-padding-end", "0"),
            unsafe("-webkit-padding-after", "0"),
            media(Style.MediaQuery.notMobile, [paddingBottom(`rem(2.))]),
          ])
        )>
        {ReactDOMRe.createElement(
           "legend",
           ~props=
             ReactDOMRe.objToDOMProps({
               "align": "center",
               "className":
                 Css.(
                   style([
                     textAlign(`center),
                     marginTop(`zero),
                     marginBottom(`zero),
                   ])
                 ),
             }),
           [|
             <h4
               className=Css.(
                 style([
                   textAlign(`center),
                   letterSpacing(`rem(0.1875)),
                   border(`px(1), `solid, Style.Colors.saville),
                   paddingLeft(`rem(1.25)),
                   paddingRight(`rem(1.25)),
                   paddingTop(`rem(0.25)),
                   paddingBottom(`rem(0.25)),
                   textTransform(`uppercase),
                   fontWeight(`medium),
                   color(Style.Colors.midnight),
                   unsafe("margin-block-start", "0"),
                   unsafe("margin-block-end", "0"),
                   unsafe("-webkit-margin-before", "0"),
                   unsafe("-webkit-margin-after", "0"),
                 ])
               )>
               {ReasonReact.string("Knowledge base")}
             </h4>,
           |],
         )}
        <div
          className=Css.(
            style([
              display(`flex),
              justifyContent(`spaceAround),
              flexWrap(`wrap),
              textAlign(`left),
              paddingLeft(`rem(1.0)),
              paddingRight(`rem(1.0)),
              paddingTop(`rem(1.5)),
              paddingBottom(`rem(1.5)),
            ])
          )>
          <SubSection
            title="Articles"
            content={
              // before the blog posts
              [("Read the Coda Whitepaper", Links.Static.whitepaper)]
              @ List.map(
                  ((name, _, metadata)) =>
                    (metadata.BlogPost.title, "/blog/" ++ name ++ ".html"),
                  posts,
                )
              // after the blog posts
              @ [
                (
                  "Coindesk: This Blockchain Tosses Blocks",
                  Links.ThirdParty.coindeskTossesBlocks,
                ),
                (
                  "TokenDaily: Deep Dive with O(1) on Coda Protocol",
                  Links.ThirdParty.tokenDailyQA,
                ),
              ]
              |> Array.of_list
            }
          />
          <SubSection
            title="Videos & Podcasts"
            content=[|
              ("Hack Summit 2018: Coda Talk", Links.Talks.hackSummit2018),
              ("Scanning for Scans", Links.Talks.scanningForScans),
              (
                "Token Talks - Interview with Coda",
                Links.Podcasts.tokenTalksInterview,
              ),
              (
                "A High-Level Language for Verifiable Computation",
                Links.Talks.highLevelLanguage,
              ),
              ("Snarky, a DSL for Writing SNARKs", Links.Talks.snarkyDsl),
            |]
          />
        </div>
      </fieldset>;
    },
  };
};

module SocialLink = {
  let fillStyle =
    ReactDOMRe.Style.unsafeAddProp(
      ReactDOMRe.Style.make(),
      "fill",
      "var(--svg-color-social)",
    );
  module Svg = {
    let twitter =
      <svg
        width="34px"
        height="28px"
        viewBox="0 0 34 28"
        version="1.1"
        xmlns="http://www.w3.org/2000/svg"
        xmlnsXlink="http://www.w3.org/1999/xlink">
        <path
          fill=Style.Colors.greyBlueString
          style=fillStyle
          d="M30.51,6.98 C30.53,7.28 30.5,7.59 30.52,7.90 C30.53,17.24 23.52,28 10.70,28 C6.75,28 3.09,26.84 0,24.83 C0.56,24.89 1.10,24.92 1.68,24.92 C4.94,24.92 7.93,23.80 10.33,21.90 C7.27,21.83 4.70,19.80 3.82,17.00 C4.25,17.06 4.68,17.11 5.13,17.11 C5.76,17.11 6.39,17.02 6.97,16.87 C3.78,16.21 1.38,13.37 1.38,9.93 L1.38,9.84 C2.31,10.37 3.39,10.70 4.53,10.74 C2.65,9.47 1.42,7.31 1.42,4.86 C1.42,3.54 1.77,2.34 2.37,1.29 C5.80,5.58 10.96,8.38 16.74,8.68 C16.63,8.16 16.57,7.61 16.57,7.07 C16.57,3.17 19.68,0 23.54,0 C25.54,0 27.36,0.85 28.63,2.23 C30.20,1.93 31.71,1.33 33.05,0.53 C32.53,2.17 31.43,3.54 29.99,4.42 C31.39,4.27 32.75,3.87 34,3.33 C33.05,4.72 31.86,5.97 30.51,6.98 Z"
          id="IconTwitter"
        />
      </svg>;

    let discord =
      <svg
        width="34px"
        height="38px"
        viewBox="0 0 34 38"
        version="1.1"
        xmlns="http://www.w3.org/2000/svg"
        xmlnsXlink="http://www.w3.org/1999/xlink">
        <defs>
          <polygon
            id="path-1"
            points="7.77142857e-05 0 34 0 34 37.999924 7.77142857e-05 37.999924"
          />
        </defs>
        <g
          id="coda_website"
          stroke="none"
          strokeWidth="1"
          fill="none"
          fillRule="evenodd">
          <g
            id="coda_homepage"
            transform="translate(-763.000000, -3290.000000)">
            <g id="Community" transform="translate(418.000000, 3032.000000)">
              <g id="Discord" transform="translate(345.000000, 258.000000)">
                <g id="IconDiscord">
                  <path
                    d="M19.944064,16.423984 C19.032064,16.423984 18.312064,17.223984 18.312064,18.199984 C18.312064,19.175984 19.047904,19.975984 19.944064,19.975984 C20.855904,19.975984 21.575904,19.175984 21.575904,18.199984 C21.575904,17.223984 20.855904,16.423984 19.944064,16.423984 M14.104064,16.423984 C13.192064,16.423984 12.472064,17.223984 12.472064,18.199984 C12.472064,19.175984 13.207904,19.975984 14.104064,19.975984 C15.016064,19.975984 15.736064,19.175984 15.736064,18.199984 C15.752064,17.223984 15.016064,16.423984 14.104064,16.423984"
                    id="Eyes"
                    fill=Style.Colors.greyBlueString
                    style=fillStyle
                  />
                  <g id="Bubble">
                    <mask id="mask-2" fill="white">
                      <use xlinkHref="#path-1" />
                    </mask>
                    <g id="Clip-4" />
                    <path
                      d="M22.517792,24.813924 C22.517792,24.813924 21.8181691,23.996924 21.235312,23.274924 C23.7806491,22.571924 24.7520777,21.013924 24.7520777,21.013924 C23.955312,21.526924 23.197792,21.888114 22.517792,22.134924 C21.5463634,22.533924 20.6135977,22.799924 19.7006491,22.951924 C17.835312,23.293924 16.125792,23.198924 14.6686491,22.933114 C13.5610263,22.723924 12.6092206,22.419924 11.8124549,22.116114 C11.365792,21.944924 10.8800777,21.736114 10.3943634,21.469924 C10.3360777,21.431924 10.277792,21.413114 10.2195063,21.374924 C10.1806491,21.356114 10.1610263,21.336924 10.141792,21.318114 C9.79207771,21.128114 9.597792,20.994924 9.597792,20.994924 C9.597792,20.994924 10.5303634,22.514924 12.997792,23.236924 C12.4149349,23.958924 11.6960777,24.813924 11.6960777,24.813924 C7.40236343,24.681114 5.77036343,21.926114 5.77036343,21.926114 C5.77036343,15.808114 8.56807771,10.848924 8.56807771,10.848924 C11.365792,8.796924 14.0275063,8.853924 14.0275063,8.853924 L14.221792,9.081924 C10.7246491,10.069924 9.11207771,11.570924 9.11207771,11.570924 C9.11207771,11.570924 9.53950629,11.343114 10.2581691,11.019924 C12.3372206,10.126924 13.9886491,9.879924 14.6686491,9.823114 C14.7852206,9.803924 14.8823634,9.784924 14.9989349,9.784924 C16.1838834,9.633114 17.5246491,9.594924 18.9235063,9.746924 C20.7692206,9.955924 22.7507406,10.488114 24.7715063,11.570924 C24.7715063,11.570924 23.2364549,10.145924 19.9335977,9.158114 L20.205792,8.853924 C20.205792,8.853924 22.8675063,8.796924 25.6650263,10.848924 C25.6650263,10.848924 28.4629349,15.808114 28.4629349,21.926114 C28.4629349,21.926114 26.8115063,24.681114 22.517792,24.813924 M30.0172206,-7.6e-05 L3.98293486,-7.6e-05 C1.78750629,-7.6e-05 7.77142857e-05,1.748114 7.77142857e-05,3.913924 L7.77142857e-05,29.601924 C7.77142857e-05,31.768114 1.78750629,33.516114 3.98293486,33.516114 L26.0149349,33.516114 L24.9850263,30.001114 L27.4720777,32.261924 L29.8229349,34.389924 L34.0000777,37.999924 L34.0000777,3.913924 C34.0000777,1.748114 32.2124549,-7.6e-05 30.0172206,-7.6e-05"
                      id="Fill-3"
                      fill=Style.Colors.greyBlueString
                      style=fillStyle
                      mask="url(#mask-2)"
                    />
                  </g>
                </g>
              </g>
            </g>
          </g>
        </g>
      </svg>;

    let telegram =
      <svg
        width="36px"
        height="30px"
        viewBox="0 0 36 30"
        version="1.1"
        xmlns="http://www.w3.org/2000/svg"
        xmlnsXlink="http://www.w3.org/1999/xlink">
        <g
          id="coda_website"
          stroke="none"
          strokeWidth="1"
          fill="none"
          fillRule="evenodd">
          <g
            id="coda_homepage"
            transform="translate(-1074.000000, -3292.000000)"
            fill=Style.Colors.greyBlueString
            style=fillStyle>
            <g id="Community" transform="translate(418.000000, 3032.000000)">
              <g id="Telegram" transform="translate(656.000000, 260.000000)">
                <path
                  d="M35.8974224,2.73110855 L30.4647954,28.1890674 C30.0549375,29.985818 28.9860922,30.4330092 27.4672069,29.5865401 L19.1896835,23.5255016 L15.1955776,27.3425983 C14.7535739,27.781804 14.3838981,28.1491396 13.5320365,28.1491396 L14.1267323,19.7722893 L29.4682781,5.99720177 C30.1353018,5.40627048 29.3236223,5.0788626 28.4315785,5.66979389 L9.46560267,17.5363331 L1.30058933,14.9969256 C-0.475461794,14.4459221 -0.507607516,13.2321173 1.67026514,12.3856482 L33.6070397,0.159758876 C35.0857429,-0.391244625 36.3796082,0.487166754 35.8974224,2.73110855 Z"
                  id="IconTelegram"
                />
              </g>
            </g>
          </g>
        </g>
      </svg>;
  };

  let component = ReasonReact.statelessComponent("GetInvolved.SocialLink");
  let make = (~link, ~name, ~svg, _children) => {
    ...component,
    render: _ => {
      <a
        href=link
        className=Css.(
          style([
            padding(`rem(1.)),
            cursor(`pointer),
            display(`flex),
            textDecoration(`none),
            justifyContent(`center),
            alignItems(`center),
            color(Style.Colors.fadedBlue),
            // Original color of svg
            unsafe("--svg-color-social", Style.Colors.greyBlueString),
            hover([
              color(Style.Colors.hyperlink),
              unsafe("--svg-color-social", Style.Colors.hyperlinkString),
            ]),
          ])
        )>
        <div className=Css.(style([marginRight(`rem(1.))]))> svg </div>
        <h3 className=Style.H3.wideNoColor> {ReasonReact.string(name)} </h3>
      </a>;
    },
  };
};

let marginBelow = Css.(style([marginBottom(`rem(0.5))]));

let component = ReasonReact.statelessComponent("GetInvolved");
let make = (~posts, _children) => {
  ...component,
  render: _self =>
    <div className=Css.(style([marginBottom(`rem(13.0))]))>
      <h1
        className=Css.(
          merge([
            Style.H1.hero,
            style([
              color(Style.Colors.denimTwo),
              textAlign(`center),
              marginTop(`rem(6.)),
            ]),
          ])
        )>
        {ReasonReact.string("Get involved")}
      </h1>
      <div
        className=Css.(
          style([display(`flex), justifyContent(`center), flexWrap(`wrap)])
        )>
        <p
          className=Css.(
            merge([
              Style.Body.basic,
              style([
                maxWidth(`rem(22.5)),
                media(
                  Style.MediaQuery.full,
                  [marginRight(`rem(3.75)), marginLeft(`rem(3.75))],
                ),
              ]),
            ])
          )>
          {ReasonReact.string(
             "Help us build a more accessible, sustainable cryptocurrency. Join our community on discord, and follow our progress on twitter.",
           )}
        </p>
        <ul
          className=Css.(
            style([
              listStyle(`none, `inside, `none),
              unsafe("-webkit-padding-before", "0"),
              unsafe("-webkit-margin-before", "0"),
            ])
          )>
          <li className=marginBelow>
            <Link
              link=Links.Forms.developingWithCoda
              message="Stay updated about developing with Coda"
            />
          </li>
          <li className=marginBelow>
            <Link
              link=Links.Forms.participateInConsensus
              message="Notify me about participating in consensus"
            />
          </li>
          <li className=marginBelow>
            <Link
              link=Links.Forms.compressTheBlockchain
              message="Earn Coda by helping to compress the blockchain"
            />
          </li>
          <li className=marginBelow>
            <Link
              link=Links.Forms.mailingList
              message="Join our mailing list for updates"
            />
          </li>
        </ul>
      </div>
      <div
        className=Css.(
          style([
            media(
              Style.MediaQuery.notMobile,
              [marginTop(`rem(1.0)), marginBottom(`rem(2.4))],
            ),
            display(`flex),
            flexWrap(`wrap),
            justifyContent(`spaceAround),
            alignItems(`center),
            marginBottom(`rem(1.25)),
            maxWidth(`rem(63.)),
            marginLeft(`auto),
            marginRight(`auto),
          ])
        )>
        <SocialLink
          link="https://twitter.com/codaprotocol"
          name="Twitter"
          svg=SocialLink.Svg.twitter
        />
        <SocialLink
          link="https://discord.gg/wz7zQyc"
          name="Discord"
          svg=SocialLink.Svg.discord
        />
        <SocialLink
          link="https://t.me/codaprotocol"
          name="Telegram"
          svg=SocialLink.Svg.telegram
        />
      </div>
      <KnowledgeBase posts />
    </div>,
};
