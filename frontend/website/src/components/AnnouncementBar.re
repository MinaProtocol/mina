module Icon = {
  let svg =
    <svg
      className=Css.(style([width(`rem(1.125)), height(`rem(1.125))]))
      width="18px"
      height="18px"
      viewBox="0 0 18 18"
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
          id="coda_testnet"
          transform="translate(-448.000000, -45.000000)"
          fill="#2D9EDB">
          <g id="nav" transform="translate(180.000000, 32.000000)">
            <g
              id="anouncement_bar" transform="translate(248.000000, 2.000000)">
              <path
                d="M21.125,14.375 L22.25,14.375 L22.25,21.125 L21.125,21.125 C20.503442,21.125 20,20.621558 20,20 L20,15.5 C20,14.878442 20.503442,14.375 21.125,14.375 Z M36.875,11 L30.125,14.375 L23.375,14.375 L23.375,27.875 C23.375,28.496558 23.878442,29 24.5,29 C25.121558,29 25.625,28.496558 25.625,27.875 L25.625,21.125 L30.125,21.125 L36.875,24.5 C37.496558,24.5 38,23.996558 38,23.375 L38,12.125 C38,11.503442 37.496558,11 36.875,11 Z"
                id="Fill-1"
              />
            </g>
          </g>
        </g>
      </g>
    </svg>;
};

[@react.component]
let make = () => {
  <>
    <style>
      {React.string(
         // HACK: On firefox (and only firefox) the text seems to not be centered in the announcementbar
         //  This way we can write CSS that only targets firefox
         {|
      @-moz-document url-prefix() {
        #announcementbar--viewdemo,#announcementbar--testnetlive {
          margin-bottom:-0.125rem;
        }
        #announcementbar--anchor {
          padding-top:0.5625rem;
        }
        #announcementbar--anchor {
          padding-bottom:0.5625rem;
        }
      }
          |},
       )}
    </style>
    <a
      name="announcementbar"
      href="/adversarial"
      className=Css.(
        style(
          Theme.paddingX(`rem(1.25))
          @ Theme.paddingY(`rem(0.5))
          @ [
            backgroundColor(Theme.Colors.azureAlpha(0.1)),
            textDecoration(`none),
            borderRadius(`px(3)),
            display(`flex),
            justifyContent(`spaceBetween),
            hover([
              opacity(0.9),
              backgroundColor(Theme.Colors.azureAlpha(0.2)),
            ]),
          ],
        )
      )>
      <div className=Css.(style([display(`flex), alignItems(`center)]))>
        Icon.svg
        <p
          className=Css.(
            merge([
              Theme.Body.basic,
              style([
                marginLeft(`rem(1.25)),
                marginBottom(`zero),
                marginTop(`px(0)),
              ]),
            ])
          )>
          {React.string("Adversarial Testnet is coming!")}
        </p>
      </div>
      <p
        className=Css.(
          merge([
            Theme.Link.No_hover.basic,
            style([
              marginTop(`px(0)),
              marginBottom(`zero),
              marginLeft(`rem(1.5)),
            ]),
          ])
        )>
        {React.string({j|Sign up \u00A0→|j})}
      </p>
    </a>
  </>;
};
