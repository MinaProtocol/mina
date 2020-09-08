module Styles = {
  open Css;
  let container =
    style([
      display(`flex),
      flexDirection(`row),
      justifyContent(`flexStart),
      alignContent(`spaceAround),
      position(`relative),
      backgroundSize(`cover),
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
  let quoteContainer =
    style([
      position(`absolute),
      background(white),
      width(`rem(21.)),
      height(`rem(19.25)),
      media(
        Theme.MediaQuery.tablet,
        [
          width(`rem(38.)),
          marginTop(`rem(7.18)),
          marginLeft(`rem(2.5)),
          marginRight(`rem(2.5)),
          height(`rem(27.)),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          marginLeft(`rem(33.5)),
          marginTop(`rem(8.75)),
          width(`rem(41.)),
        ],
      ),
    ]);
  let quote =
    merge([
      Theme.Type.quote,
      style([
        paddingLeft(`rem(2.375)),
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
      display(`flex),
      flexDirection(`row),
      justifyContent(`spaceBetween),
      width(`rem(15.68)),
    ]);
  let column =
    style([display(`flex), flexDirection(`column), width(`rem(11.18))]);
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
      <span className=Styles.attribute>
        <img src="/static/img/headshots/naval.png" />
        <span className=Styles.column>
          <p className=Theme.Type.pageLabel>
            {React.string("Naval Ravikant")}
          </p>
          <p className=Theme.Type.contributorLabel>
            {React.string("AngelList Co-Founder")}
          </p>
        </span>
      </span>
    </div>
  </div>;
};
