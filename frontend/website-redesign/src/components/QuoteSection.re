module Styles = {
  open Css;

  // TODO: Fix background sizes once wrapper is merged in
  let container =
    style([
      display(`flex),
      flexDirection(`row),
      justifyContent(`flexStart),
      alignContent(`spaceAround),
      position(`relative),
      important(backgroundSize(`cover)),
      background(`url("/static/img/SectionQuoteMobile.png")),
      height(`rem(27.25)),
      media(
        Theme.MediaQuery.tablet,
        [
          background(`url("/static/img/SectionQuoteTablet.png")),
          height(`rem(42.)),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [background(`url("/static/img/SectionQuoteDesktop.png"))],
      ),
    ]);
  let headshot =
    style([
      height(`rem(3.5)),
      media(Theme.MediaQuery.desktop, [height(`rem(5.5))]),
    ]);
  /**
   * This is the actual white box of the quote section
   */
  let quoteContainer =
    style([
      position(`absolute),
      top(`rem(4.)),
      background(white),
      width(`rem(21.)),
      height(`rem(19.25)),
      media(
        Theme.MediaQuery.tablet,
        [
          width(`rem(43.)),
          marginTop(`rem(7.18)),
          marginLeft(`rem(2.5)),
          marginRight(`rem(2.5)),
          height(`rem(27.)),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          width(`rem(47.)),
          height(`rem(25.)),
          right(`rem(9.5)),
        ],
      ),
    ]);
  let quote =
    merge([
      Theme.Type.quote,
      style([
        fontSize(`rem(1.3)),
        paddingLeft(`rem(1.25)),
        paddingTop(`rem(1.5)),
        media(
          Theme.MediaQuery.tablet,
          [
            marginTop(`zero),
            marginBottom(`zero),
            paddingLeft(`rem(4.56)),
            paddingRight(`rem(2.5)),
            paddingTop(`rem(2.5)),
          ],
        ),
      ]),
    ]);
  let attribute =
    style([
      position(`absolute),
      display(`flex),
      flexDirection(`row),
      justifyContent(`spaceBetween),
      marginLeft(`rem(1.25)),
      media(
        Theme.MediaQuery.tablet,
        [marginLeft(`zero), left(`rem(4.56)), top(`rem(19.6))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [left(`rem(4.56)), top(`rem(16.5))],
      ),
    ]);
  let name =
    style([
      marginLeft(`rem(1.5)),
      marginTop(`rem(1.)),
      media(Theme.MediaQuery.tablet, [marginTop(`zero)]),
    ]);
};

[@react.component]
let make = () => {
  <div className=Styles.container>

      <div className=Styles.quoteContainer>
        <p className=Styles.quote>
          {React.string(
             "\"What attracted me was a small, scalable blockchain that's still independently verifiable on small nodes.\"",
           )}
        </p>
        <div className=Styles.attribute>
          <img
            className=Styles.headshot
            src="/static/img/headshots/naval.jpg"
          />
          <div className=Styles.name>
            <p className=Theme.Type.pageLabel>
              {React.string("Naval Ravikant")}
            </p>
            <p className=Theme.Type.contributorLabel>
              {React.string("AngelList Co-Founder")}
            </p>
          </div>
        </div>
      </div>
    </div>;
    /*** This is the actual white box */
};
