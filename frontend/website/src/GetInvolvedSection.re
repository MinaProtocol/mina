module Link = {
  let component = ReasonReact.statelessComponent("GetInvolved.Link");
  let make = (~message, _) => {
    ...component,
    render: _ => {
      <a
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
                  before([
                    unsafe("content", {js|"•"|js}),
                    color(Style.Colors.hyperlink),
                    marginRight(`rem(1.)),
                    display(`inlineBlock),
                  ]),
                ])
              )>
              <a
                href=link
                className=Css.(
                  merge([Style.Link.basic, style([cursor(`pointer)])])
                )>
                {ReasonReact.string(copy)}
              </a>
            </li>
          );

        <div className>
          <h5
            className=Css.(
              merge([
                Style.H5.basic,
                style([
                  marginLeft(`zero),
                  marginRight(`zero),
                  marginTop(`zero),
                  marginBottom(`rem(0.75)),
                  media(
                    Style.MediaQuery.notMobile,
                    [marginTop(`rem(1.5)), marginRight(`rem(1.5))],
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
                media(
                  Style.MediaQuery.notMobile,
                  [marginRight(`rem(1.5))],
                ),
              ])
            )>
            ...items
          </ul>
        </div>;
      },
    };
  };

  let component = ReasonReact.statelessComponent("GetInvolved.KnowledgeBase");
  let make = _ => {
    ...component,
    render: _ => {
      <fieldset
        className=Css.(
          style([
            textAlign(`center),
            Style.Typeface.ibmplexserif,
            border(`px(1), `solid, Style.Colors.hyperlinkAlpha(0.3)),
            borderRadius(`px(18)),
            paddingBottom(`rem(1.)),
            marginLeft(`zero),
            marginRight(`zero),
            paddingTop(`rem(1.0)),
            unsafe("min-width", "min-content"),
            media(
              Style.MediaQuery.notMobile,
              [
                paddingBottom(`rem(3.)),
                marginLeft(`rem(3.)),
                marginRight(`rem(3.)),
              ],
            ),
          ])
        )>
        <legend>
          <h4
            className=Css.(
              style([
                letterSpacing(`rem(0.1875)),
                border(`px(1), `solid, black),
                paddingLeft(`rem(1.0)),
                paddingRight(`rem(1.0)),
                paddingTop(`rem(0.5)),
                paddingBottom(`rem(0.5)),
                textTransform(`uppercase),
                fontWeight(`medium),
                color(Style.Colors.midnight),
              ])
            )>
            {ReasonReact.string("Knowledge base")}
          </h4>
        </legend>
        <div
          className=Css.(
            style([
              display(`flex),
              justifyContent(`center),
              flexWrap(`wrap),
              textAlign(`left),
            ])
          )>
          <SubSection
            className=Css.(style([marginBottom(`rem(2.0))]))
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
      </fieldset>;
    },
  };
};

module SocialLink = {
  module Svg = {
    let twitter =
      <svg
        width="34px"
        height="28px"
        viewBox="0 0 34 28"
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
            transform="translate(-418.000000, -3293.000000)"
            fill="#7693BE">
            <g id="Community" transform="translate(418.000000, 3032.000000)">
              <g id="Twitter" transform="translate(0.000000, 261.000000)">
                <path
                  d="M30.5051582,6.97809959 C30.5267403,7.28433497 30.5267403,7.59063768 30.5267403,7.89687305 C30.5267403,17.237456 23.5153419,28 10.7005457,28 C6.75254591,28 3.08504721,26.8405746 0,24.828161 C0.560935785,24.8937444 1.10022305,24.915628 1.68274095,24.915628 C4.94031227,24.915628 7.93909742,23.800037 10.3337826,21.8969067 C7.27031746,21.831256 4.70304181,19.7968916 3.8185071,16.9968714 C4.2500166,17.0624548 4.68145969,17.1062219 5.13455131,17.1062219 C5.76016703,17.1062219 6.38584916,17.0186876 6.96830066,16.8656373 C3.77540928,16.209332 1.38065774,13.365612 1.38065774,9.93123748 L1.38065774,9.84377052 C2.30829027,10.3687743 3.38706401,10.6968933 4.53038488,10.7405931 C2.6534713,9.47181708 1.42382197,7.30621854 1.42382197,4.85620087 C1.42382197,3.54372507 1.7689366,2.3405998 2.37303661,1.29059223 C5.80326486,5.57808949 10.9593983,8.37804236 16.741081,8.68434507 C16.6332368,8.15934128 16.5684905,7.61252125 16.5684905,7.06563389 C16.5684905,3.17183897 19.6751198,0 23.5367912,0 C25.543131,0 27.3552983,0.853122738 28.6281782,2.23124926 C30.2030086,1.92501389 31.713159,1.33435938 33.0507854,0.525003788 C32.5329474,2.16566587 31.4327243,3.5437924 29.9873203,4.41873138 C31.3896265,4.26568102 32.7487685,3.87184402 34,3.32502399 C33.0509182,4.72496675 31.8643003,5.97179183 30.5051582,6.97809959 Z"
                  id="IconTwitter"
                />
              </g>
            </g>
          </g>
        </g>
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
                    fill="#7693BE"
                  />
                  <g id="Bubble">
                    <mask id="mask-2" fill="white">
                      <use xlinkHref="#path-1" />
                    </mask>
                    <g id="Clip-4" />
                    <path
                      d="M22.517792,24.813924 C22.517792,24.813924 21.8181691,23.996924 21.235312,23.274924 C23.7806491,22.571924 24.7520777,21.013924 24.7520777,21.013924 C23.955312,21.526924 23.197792,21.888114 22.517792,22.134924 C21.5463634,22.533924 20.6135977,22.799924 19.7006491,22.951924 C17.835312,23.293924 16.125792,23.198924 14.6686491,22.933114 C13.5610263,22.723924 12.6092206,22.419924 11.8124549,22.116114 C11.365792,21.944924 10.8800777,21.736114 10.3943634,21.469924 C10.3360777,21.431924 10.277792,21.413114 10.2195063,21.374924 C10.1806491,21.356114 10.1610263,21.336924 10.141792,21.318114 C9.79207771,21.128114 9.597792,20.994924 9.597792,20.994924 C9.597792,20.994924 10.5303634,22.514924 12.997792,23.236924 C12.4149349,23.958924 11.6960777,24.813924 11.6960777,24.813924 C7.40236343,24.681114 5.77036343,21.926114 5.77036343,21.926114 C5.77036343,15.808114 8.56807771,10.848924 8.56807771,10.848924 C11.365792,8.796924 14.0275063,8.853924 14.0275063,8.853924 L14.221792,9.081924 C10.7246491,10.069924 9.11207771,11.570924 9.11207771,11.570924 C9.11207771,11.570924 9.53950629,11.343114 10.2581691,11.019924 C12.3372206,10.126924 13.9886491,9.879924 14.6686491,9.823114 C14.7852206,9.803924 14.8823634,9.784924 14.9989349,9.784924 C16.1838834,9.633114 17.5246491,9.594924 18.9235063,9.746924 C20.7692206,9.955924 22.7507406,10.488114 24.7715063,11.570924 C24.7715063,11.570924 23.2364549,10.145924 19.9335977,9.158114 L20.205792,8.853924 C20.205792,8.853924 22.8675063,8.796924 25.6650263,10.848924 C25.6650263,10.848924 28.4629349,15.808114 28.4629349,21.926114 C28.4629349,21.926114 26.8115063,24.681114 22.517792,24.813924 M30.0172206,-7.6e-05 L3.98293486,-7.6e-05 C1.78750629,-7.6e-05 7.77142857e-05,1.748114 7.77142857e-05,3.913924 L7.77142857e-05,29.601924 C7.77142857e-05,31.768114 1.78750629,33.516114 3.98293486,33.516114 L26.0149349,33.516114 L24.9850263,30.001114 L27.4720777,32.261924 L29.8229349,34.389924 L34.0000777,37.999924 L34.0000777,3.913924 C34.0000777,1.748114 32.2124549,-7.6e-05 30.0172206,-7.6e-05"
                      id="Fill-3"
                      fill="#7693BE"
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
            fill="#7693BE">
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
            cursor(`pointer),
            display(`flex),
            textDecoration(`none),
            justifyContent(`center),
            alignItems(`center),
            hover([color(Style.Colors.hyperlinkHover)]),
          ])
        )>
        <div className=Css.(style([margin(`rem(1.))]))> svg </div>
        <h3
          className=Css.(
            merge([
              Style.H3.wide,
              style([hover([color(Style.Colors.hyperlinkHover)])]),
            ])
          )>
          {ReasonReact.string(name)}
        </h3>
      </a>;
    },
  };
};

let marginBelow = Css.(style([marginBottom(`rem(0.5))]));

let component = ReasonReact.statelessComponent("GetInvolved");
let make = _ => {
  ...component,
  render: _self =>
    <div>
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
        {ReasonReact.string("Get Involved")}
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
              unsafe("padding-left", "0"),
            ])
          )>
          <li className=marginBelow>
            <Link message="Stay updated about developing with Coda" />
          </li>
          <li className=marginBelow>
            <Link message="Notify me about participating in consensus" />
          </li>
          <li className=marginBelow>
            <Link message="Earn Coda by helping to compress the blockchain" />
          </li>
          <li className=marginBelow>
            <Link message="Join our mailing list for updates" />
          </li>
        </ul>
      </div>
      <div
        className=Css.(
          style([
            media(
              Style.MediaQuery.notMobile,
              [marginTop(`rem(2.0)), marginBottom(`rem(3.))],
            ),
            display(`flex),
            flexWrap(`wrap),
            justifyContent(`spaceAround),
            alignItems(`center),
            marginBottom(`rem(1.)),
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
      <KnowledgeBase />
    </div>,
};
