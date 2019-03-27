let component = ReasonReact.statelessComponent("SustainableSection");
let make = _children => {
  ...component,
  render: _self => {
    <div
      className=Css.(
        style([
          marginTop(`rem(2.5)),
          media(Style.MediaQuery.full, [marginTop(`rem(11.25))]),
        ])
      )>
      <div
        className=Css.(
          style([
            width(`percent(100.0)),
            media(
              Style.MediaQuery.notMobile,
              [
                display(`flex),
                justifyContent(`center),
                width(`percent(100.0)),
              ],
            ),
          ])
        )>
        <h1
          className=Css.(
            merge([
              Style.H1.hero,
              style([
                color(Style.Colors.denimTwo),
                position(`relative),
                display(`inlineBlock),
                marginTop(`zero),
                marginBottom(`zero),
                media(Style.MediaQuery.notSmallMobile, [margin(`auto)]),
                media(Style.MediaQuery.full, [color(Style.Colors.clover)]),
              ]),
            ])
          )>
          {ReasonReact.string("Sustainable Scalability")}
          <div
            className=Css.(
              style([
                display(`none),
                media(
                  Style.MediaQuery.full,
                  [
                    display(`block),
                    position(`absolute),
                    top(`zero),
                    left(`zero),
                    transforms([
                      `translateX(`percent(-50.0)),
                      `translateY(`percent(-25.0)),
                    ]),
                  ],
                ),
              ])
            )>
            <Svg link="/static/img/leaf.svg" dims=(6.25, 6.25) />
          </div>
        </h1>
      </div>
      <div
        className=Css.(
          style([
            marginTop(`rem(2.375)),
            display(`flex),
            justifyContent(`spaceBetween),
            alignItems(`center),
            flexWrap(`wrapReverse),
            media(Style.MediaQuery.full, [marginTop(`rem(4.375))]),
            media(
              Style.MediaQuery.notMobile,
              [justifyContent(`spaceAround)],
            ),
          ])
        )>
        <div
          className=Css.(
            style([
              marginBottom(`rem(2.375)),
              userSelect(`none),
              marginRight(`rem(2.0)),
              maxWidth(`rem(23.875)),
            ])
          )>
          <Svg
            link="/static/img/chart-blockchain-size.svg"
            dims=(23.125, 17.3125)
            inline=true
          />
        </div>
        <div
          className=Css.(
            style([
              marginBottom(`rem(2.375)),
              userSelect(`none),
              marginRight(`rem(2.0)),
              maxWidth(`rem(23.125)),
            ])
          )>
          <Svg
            link="/static/img/chart-blockchain-energy.svg"
            dims=(23.9375, 18.1875)
            inline=true
          />
        </div>
        <div className=Css.(style([marginBottom(`rem(2.375))]))>
          <SideText
            paragraphs=[|
              "With Coda's constant sized blockchain and energy efficient consensus, Coda will be sustainable even as it scales to thousands of transactions per second, millions of users, and years of transaction history.",
            |]
            cta="Notify me about participating in consensus"
          />
        </div>
      </div>
    </div>;
  },
};
