let middleElementWidthRems = 21.5;

let topMarginUnderHeading = `rem(2.5);
// nudge so it looks like the center of the coda icon hits bar
let topMarginNegativeNudgeVeryLarge = `rem(-1.5);

module Code = {
  let component = ReasonReact.statelessComponent("CryptoAppsSection.Code");
  let make = (~src, _children) => {
    ...component,
    render: _self =>
      <div
        ariaLabel="Code example showing usage of coda on a webpage"
        className=Css.(
          style([
            display(`block),
            position(`relative),
            marginTop(topMarginUnderHeading),
            media(
              Style.MediaQuery.veryLarge,
              [
                width(`percent(40.0)),
                marginTop(topMarginNegativeNudgeVeryLarge),
                marginLeft(`zero),
                marginRight(`zero),
              ],
            ),
            media(
              Style.MediaQuery.notMobile,
              [marginLeft(`rem(1.0)), marginRight(`rem(1.0))],
            ),
            // the "line"
            before([
              contentRule(""),
              zIndex(-1),
              display(`none),
              media(
                Style.MediaQuery.veryLarge,
                [
                  display(`block),
                  position(`absolute),
                  top(`percent(50.0)),
                  width(`percent(100.0)),
                  height(`rem(0.125)),
                  backgroundColor(Style.Colors.blueBlue),
                ],
              ),
              // super hacky, but the it's the final hour
              // determined experimentally
              media("(min-width: 1100px)", [right(`rem(-5.25))]),
              media("(min-width: 1140px)", [right(`rem(-5.5))]),
              media("(min-width: 1180px)", [right(`rem(-5.25))]),
              media("(min-width: 1220px)", [right(`rem(-5.0))]),
              media("(min-width: 1260px)", [right(`rem(-4.75))]),
              media("(min-width: 1298px)", [right(`rem(-4.5))]),
              media("(min-width: 1324px)", [right(`rem(-4.25))]),
            ]),
          ])
        )>
        <pre
          className=Css.(
            style(
              Style.paddingX(`rem(1.0))
              @ Style.paddingY(`rem(0.75))
              @ [
                marginTop(`zero),
                marginBottom(`zero),
                backgroundColor(Style.Colors.navy),
                color(Style.Colors.white),
                Style.Typeface.pragmataPro,
                fontWeight(`medium),
                fontSize(`rem(0.8125)),
                borderRadius(`px(12)),
                lineHeight(`rem(1.0)),
                letterSpacing(`zero),
                maxWidth(`rem(23.0)),
                // the width demands it stick out a bit
                marginLeft(`rem(-0.25)),
                media(
                  Style.MediaQuery.notMobile,
                  [
                    width(`rem(23.0)),
                    // nudge so code background looks nicer
                    marginRight(`rem(0.25)),
                    marginLeft(`rem(0.25)),
                  ],
                ),
              ],
            )
          )>
          {ReasonReact.string(src)}
        </pre>
      </div>,
  };
};

module ImageCollage = {
  let component =
    ReasonReact.statelessComponent("CryptoAppsSection.ImageCollage");
  let make = (~className, _children) => {
    ...component,
    render: _self =>
      <div
        className=Css.(
          merge([
            className,
            style([
              position(`relative),
              top(`zero),
              left(`zero),
              zIndex(-1),
              media(Style.MediaQuery.veryLarge, [position(`static)]),
            ]),
          ])
        )>
        <Image
          className=Css.(
            style([
              position(`relative),
              top(`zero),
              left(`percent(-25.0)),
              right(`zero),
              bottom(`zero),
              margin(`auto),
              maxWidth(`percent(150.0)),
              media(
                Style.MediaQuery.full,
                [left(`zero), maxWidth(`percent(100.0))],
              ),
            ])
          )
          alt=""
          name="/static/img/map"
        />
        <Image
          className=Css.(
            style([
              position(`absolute),
              top(`zero),
              left(`percent(-10.0)),
              right(`zero),
              bottom(`zero),
              margin(`auto),
              maxWidth(`percent(120.0)),
              media(
                Style.MediaQuery.notMobile,
                [left(`zero), maxWidth(`percent(100.0))],
              ),
            ])
          )
          alt=""
          name="/static/img/centering-rectangle"
        />
        <Image
          className=Css.(
            style([
              position(`absolute),
              top(`zero),
              left(`zero),
              right(`zero),
              bottom(`zero),
              margin(`auto),
              maxWidth(`percent(40.0)),
              media(Style.MediaQuery.full, [maxWidth(`percent(100.0))]),
            ])
          )
          alt="Coda icon on a phone, connected to devices all around the world."
          name="/static/img/montage"
        />
      </div>,
  };
};

let component = ReasonReact.statelessComponent("CryptoAppsSection");
let make = _ => {
  ...component,
  render: _self => {
    <div
      className=Css.(
        style([
          marginTop(`rem(4.75)),
          media(Style.MediaQuery.full, [marginTop(`rem(8.0))]),
        ])
      )>
      <Title
        noBottomMargin=true
        fontColor=Style.Colors.denimTwo
        text={js|Build global cryptocurrency apps with\u00A0Coda|js}
      />
      <div
        className=Css.(
          style([
            position(`relative),
            left(`zero),
            top(`zero),
            minHeight(`rem(38.)),
          ])
        )>
        <ImageCollage
          className=Css.(
            style([
              display(`none),
              media(Style.MediaQuery.veryLarge, [display(`block)]),
            ])
          )
        />
        <div
          className=Css.(
            style([
              display(`flex),
              flexWrap(`wrapReverse),
              justifyContent(`spaceBetween),
              alignItems(`center),
              marginLeft(`auto),
              marginRight(`auto),
              marginBottom(`zero),
              maxWidth(`rem(78.0)),
              media(
                Style.MediaQuery.notMobile,
                [justifyContent(`spaceAround)],
              ),
              media(Style.MediaQuery.full, [marginBottom(`rem(2.0))]),
              // vertically/horiz center absolutely
              media(
                Style.MediaQuery.veryLarge,
                [
                  flexWrap(`nowrap),
                  position(`absolute),
                  top(`percent(50.0)),
                  left(`percent(50.0)),
                  transforms([
                    `translateX(`percent(-50.0)),
                    `translateY(`percent(-50.0)),
                  ]),
                  width(`percent(100.0)),
                ],
              ),
            ])
          )>
          <Code
            src={|<script src="coda_api.js"></script>
<script>
  onClick(button)
    .then(() => Coda.requestWallet())
    .then((wallet) =>
        wallet.sendTransaction(...))
</script>|}
          />
          // This keeps the right hand text aligned with the inclusive app section.
          <div
            className=Css.(
              style([
                width(`rem(middleElementWidthRems)),
                height(`rem(0.)),
                display(`none),
                media(Style.MediaQuery.veryLarge, [display(`block)]),
              ])
            )
          />
          <SideText
            className=Css.(
              style([
                marginTop(topMarginUnderHeading),
                media(
                  Style.MediaQuery.veryLarge,
                  [
                    marginTop(topMarginNegativeNudgeVeryLarge),
                    marginLeft(`zero),
                    marginRight(`zero),
                  ],
                ),
                media(
                  Style.MediaQuery.notMobile,
                  [marginLeft(`rem(1.0)), marginRight(`rem(1.0))],
                ),
              ])
            )
            paragraphs=[|
              `styled([
                `emph(
                  "Build apps and games that take advantage of the new capabilities enabled by cryptocurrency with just a script tag and a few lines of javascript.",
                ),
              ]),
              `str(
                "Your users will have a seamless, secure experience without having to download any extensions or trust additional 3rd parties.",
              ),
            |]
            cta={
              SideText.Cta.copy: {j|Stay informed about early access to developing with\u00A0Coda|j},
              link: Links.Forms.developingWithCoda,
            }
          />
        </div>
        <ImageCollage
          className=Css.(
            style([
              display(`block),
              marginBottom(`rem(4.0)),
              media(Style.MediaQuery.veryLarge, [display(`none)]),
            ])
          )
        />
      </div>
    </div>;
  },
};
