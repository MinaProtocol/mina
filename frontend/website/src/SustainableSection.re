[@react.component]
let make = () => {
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
              color(Style.Colors.clover),
              position(`relative),
              display(`inlineBlock),
              marginTop(`zero),
              marginBottom(`zero),
              media(Style.MediaQuery.notSmallMobile, [margin(`auto)]),
            ]),
          ])
        )>
        {ReasonReact.string("Sustainable scalability")}
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
          <Svg link="/static/img/leaf.svg" dims=(6.25, 6.25) alt="" />
        </div>
      </h1>
    </div>
    <div
      className=Css.(
        style([
          marginTop(`rem(2.375)),
          display(`flex),
          maxWidth(`rem(81.5)),
          justifyContent(`spaceBetween),
          alignItems(`center),
          flexWrap(`wrapReverse),
          media(Style.MediaQuery.full, [marginTop(`rem(4.375))]),
          media(Style.MediaQuery.notMobile, [justifyContent(`spaceAround)]),
        ])
      )>
      <div
        className=Css.(
          style([
            userSelect(`none),
            media(Style.MediaQuery.notMobile, [marginBottom(`rem(2.375))]),
          ])
        )>
        <Svg
          inline=true
          className=Css.(
            style([
              width(`rem(18.75)),
              media(Style.MediaQuery.notMobile, [width(`rem(23.9375))]),
            ])
          )
          link="/static/img/chart-blockchain-size.svg"
          dims=(23.125, 16.8125)
          alt="Line graph comparing the size requirements of Coda to other blockchains. \
            Other blockchain's size requirements increase significantly over time, on the order \
            of 2TB+, whereas Coda staking nodes and user nodes remain constant, at around 1GB \
            and 22kb of data respectively."
        />
      </div>
      <div
        className=Css.(
          style([
            userSelect(`none),
            media(Style.MediaQuery.notMobile, [marginBottom(`rem(2.375))]),
          ])
        )>
        <Svg
          inline=true
          className=Css.(
            style([
              width(`rem(18.75)),
              media(Style.MediaQuery.notMobile, [width(`rem(23.9375))]),
            ])
          )
          link="/static/img/chart-blockchain-energy.svg"
          dims=(23.125, 16.8125)
          alt="Line graph comparing the energy usage of Coda to other blockchains. \
            Over time, the energy requirements for proof of work blockchains to process \
            a single transaction will go up, whereas the Coda network will remain constant."
        />
      </div>
      <div className=Css.(style([marginBottom(`rem(2.375))]))>
        <SideText
          paragraphs=[|
            `styled([
              `str(
                "With Coda's constant sized blockchain and energy efficient consensus, Coda will be",
              ),
              `emph(
                " sustainable even as it scales to thousands of transactions per second, millions of users, and years of transactions history",
              ),
              `str("."),
            ]),
            `str(
              "Help compress Coda by participating in snarking. Just like mining, with snarking anyone can contribute their compute to the network to help compress the blockchain.",
            ),
          |]
          cta={
            SideText.Cta.copy: {j|Learn more about helping compress Coda's\u00A0blockchain|j},
            link: Links.Forms.compressTheBlockchain,
          }
        />
      </div>
    </div>
  </div>;
};
