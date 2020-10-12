module Styles = {
  open Css;
  let heroBackgroundImage = backgroundImg =>
    style([
      minHeight(`vh(200.)),
      width(`percent(100.)),
      position(`relative),
      important(backgroundSize(`cover)),
      backgroundImage(`url(backgroundImg)),
      media(
        Theme.MediaQuery.tablet,
        [
          height(`auto),
          after([
            contentRule(""),
            position(`absolute),
            bottom(`zero),
            left(`zero),
            right(`zero),
            height(`rem(20.)),
            background(
              linearGradient(
                deg(0.),
                [
                  (`percent(0.), white),
                  (`percent(100.), rgba(255, 255, 255, 0.)),
                ],
              ),
            ),
          ]),
        ],
      ),
      media(Theme.MediaQuery.desktop, [height(`rem(120.))]),
      position(`relative),
    ]);

  let container =
    style([
      height(`percent(100.)),
      width(`percent(100.)),
      display(`flex),
      flexDirection(`column),
    ]);

  let heroContentContainer =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      marginBottom(`rem(12.)),
      media(Theme.MediaQuery.tablet, [marginTop(`rem(12.))]),
      media(Theme.MediaQuery.desktop, [flexDirection(`row)]),
    ]);

  let heroHeadlineContainr =
    style([
      height(`vh(100.)),
      minHeight(`rem(32.)),
      position(`relative),
    ]);

  let heroHeadline =
    merge([
      Theme.Type.h1jumbo,
      style([
        fontSize(`rem(4.6)),
        important(fontWeight(`num(100))),
        lineHeight(`rem(5.)),
        position(`absolute),
        display(`flex),
        justifyContent(`center),
        alignItems(`center),
        bottom(`rem(12.)),
      ]),
    ]);

  let heroImageSize =
    style([
      width(`percent(100.)),
      media(
        "(min-width:38rem)",
        [height(`rem(33.5)), width(`rem(38.5))],
      ),
    ]);

  let heroImageContainer =
    merge([heroImageSize, style([marginLeft(`rem(10.))])]);

  let heroImage =
    merge([
      heroImageSize,
      style([
        position(`absolute),
        right(`px(0)),
        marginTop(`rem(5.)),
        alignSelf(`flexEnd),
        justifySelf(`flexEnd),
        important(backgroundSize(`cover)),
        backgroundImage(`url("/static/img/HeroSectionHands.jpg")),
        media(
          Theme.MediaQuery.tablet,
          [
            alignSelf(`center),
            justifySelf(`center),
            backgroundImage(`url("/static/img/HeroSectionHands.jpg")),
          ],
        ),
      ]),
    ]);

  let heroButton = style([marginTop(`rem(2.))]);

  let buttonIcon =
    style([
      height(`rem(1.5)),
      marginLeft(`rem(0.5)),
      color(Theme.Colors.orange),
    ]);

  let heroText =
    merge([
      Theme.Type.pageSubhead,
      style([lineHeight(`px(31)), fontSize(`px(21))]),
    ]);

  let heroTextButtonContainer =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`flexStart),
      alignItems(`flexStart),
      justifySelf(`flexStart),
      alignSelf(`flexStart),
      width(`percent(100.)),
      media(
        Theme.MediaQuery.tablet,
        [height(`rem(12.)), width(`rem(34.))],
      ),
    ]);
};

[@react.component]
let make = (~backgroundImg) => {
  <div className={Styles.heroBackgroundImage(backgroundImg)}>
    <Wrapped>
      <div className=Styles.container>
        <div className=Styles.heroHeadlineContainr>
          <h1 className=Styles.heroHeadline>
            {React.string(
               "The world's lightest blockchain, powered by participants.",
             )}
          </h1>
        </div>
        <div className=Styles.heroContentContainer>
          <div className=Styles.heroTextButtonContainer>
            <span>
              <p className=Styles.heroText>
                {React.string(
                   "By design, the entire Mina blockchain is and will always be about 22kb - the size of a couple of tweets. So anyone with a smartphone will be able to sync and verify the network in seconds.",
                 )}
              </p>
            </span>
            <span className=Styles.heroButton>
              <Button
                href={`Internal("/tech")}
                bgColor=Theme.Colors.white
                paddingX=1.
                width={`rem(13.5)}>
                <span> {React.string("See Behind The Tech")} </span>
                <span className=Styles.buttonIcon>
                  <Icon kind=Icon.ArrowRightMedium />
                </span>
              </Button>
            </span>
          </div>
          <div className=Styles.heroImageContainer>
            <img
              src="/static/img/HeroSectionHands.jpg"
              className=Styles.heroImage
            />
          </div>
        </div>
      </div>
    </Wrapped>
  </div>;
};
