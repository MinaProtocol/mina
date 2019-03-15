module Header = {
  let component = ReasonReact.statelessComponent("Header");
  let make = (~extra, children) => {
    ...component,
    render: _self =>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        extra
        <meta
          property="og:image"
          content="https://codaprotocol.com/static/img/compare-outlined-png.png"
        />
        <meta property="og:updated_time" content="1526001445" />
        <meta property="og:type" content="website" />
        <meta property="og:url" content="https://codaprotocol.com" />
        <meta property="og:title" content="Coda Cryptocurrency Protocol" />
        <meta
          property="og:description"
          content="That means that no matter how many transactions are performed, verifying the blockchain remains inexpensive and accessible to everyone."
        />
        <meta
          name="description"
          content="That means that no matter how many transactions are performed, verifying the blockchain remains inexpensive and accessible to everyone."
        />
        <title> {ReasonReact.string("Coda Cryptocurrency Protocol")} </title>
        <link
          rel="stylesheet"
          type_="text/css"
          href="https://fonts.googleapis.com/css?family=Rubik:500"
        />
        <link
          rel="stylesheet"
          type_="text/css"
          href="https://fonts.googleapis.com/css?family=Alegreya+Sans:300,300i,400,400i,500,500i,700,700i,800,800i,900,900i"
        />
        <link
          rel="stylesheet"
          href="https://use.fontawesome.com/releases/v5.0.12/css/all.css"
          integrity="sha384-G0fIWCsCzJIMAVNQPfjH08cyYaUtMwjJwqiRKxxE/rx96Uroj1BtIQ6MLJuheaO9"
          crossOrigin="anonymous"
        />
        <link rel="stylesheet" type_="text/css" href="static/css/common.css" />
        <link
          rel="stylesheet"
          type_="text/css"
          href="static/css/gallery.css"
        />
        <link
          media="only screen and (min-device-width: 700px)"
          rel="stylesheet"
          href="/static/css/main.css"
        />
        <link
          media="only screen and (max-device-width: 700px)"
          rel="stylesheet"
          href="/static/css/mobile.css"
        />
        <link
          rel="icon"
          type_="image/png"
          href="/static/favicon-32x32.png"
          sizes="32x32"
        />
        <link
          rel="icon"
          type_="image/png"
          href="/static/favicon-16x16.png"
          sizes="16x16"
        />
        <script
          src="https://www.googletagmanager.com/gtag/js?id=UA-115553548-2"
        />
        <RunScript>
          {|
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());

  gtag('config', 'UA-115553548-2');
  var _gaq = document._gaq || [];
|}
        </RunScript>
      </head>,
  };
};

module Footer = {
  let dot = ReasonReact.string({js| · |js});

  let component = ReasonReact.statelessComponent("Footer");
  let make = (~color="", children) => {
    ...component,
    render: _self =>
      <div>
        <div className={"bxs-cb " ++ color}>
          <section
            className="section-wrapper pv4 mw9 center bxs-bb ph6-l ph5-m ph4 mw9-l">
            <div className="flex justify-center tc mb4">
              <ul className="list ph0">
                <li className="mb2 dib">
                  <a
                    href="mailto:contact@o1labs.org"
                    className="no-underline fw3 f6 silver hover-link"
                    name="footer-mail"
                    target="_blank">
                    {ReasonReact.string("contact@o1labs.org")}
                  </a>
                  <span className="f6 silver"> dot </span>
                </li>
                <li className="mb2 dib">
                  <a
                    href="https://o1labs.org"
                    className="no-underline fw3 f6 silver hover-link"
                    name="footer-o1www"
                    target="_blank">
                    {ReasonReact.string(" o1labs.org")}
                  </a>
                  <span className="f6 silver"> dot </span>
                </li>
                <li className="mb2 dib">
                  <a
                    href="https://twitter.com/codaprotocol"
                    className="no-underline fw3 f6 silver hover-link"
                    name="footer-twitter"
                    target="_blank">
                    {ReasonReact.string(" Twitter")}
                  </a>
                  <span className="f6 silver"> dot </span>
                </li>
                <li className="mb2 dib">
                  <a
                    href="https://github.com/o1-labs"
                    className="no-underline fw3 f6 silver hover-link"
                    name="footer-github"
                    target="_blank">
                    {ReasonReact.string(" GitHub")}
                  </a>
                  <span className="f6 silver"> dot </span>
                </li>
                <li className="mb2 dib">
                  <a
                    href="https://reddit.com/r/coda"
                    className="no-underline fw3 f6 silver hover-link"
                    name="footer-reddit"
                    target="_blank">
                    {ReasonReact.string(" Reddit")}
                  </a>
                  <span className="f6 silver"> dot </span>
                </li>
                <li className="mb2 dib">
                  <a
                    href="https://t.me/codaprotocol"
                    className="no-underline fw3 f6 silver hover-link"
                    name="footer-telegram"
                    target="_blank">
                    {ReasonReact.string(" Telegram")}
                  </a>
                  <span className="f6 silver"> dot </span>
                </li>
                <li className="mb2 dib">
                  <a
                    href="/tos.html"
                    className="no-underline fw3 f6 silver hover-link"
                    name="footer-tos"
                    target="_blank">
                    {ReasonReact.string(" Terms of Service")}
                  </a>
                  <span className="f6 silver"> dot </span>
                </li>
                <li className="mb2 dib">
                  <a
                    href="/privacy.html"
                    className="no-underline fw3 f6 silver hover-link"
                    name="footer-privacy"
                    target="_blank">
                    {ReasonReact.string(" Privacy Policy")}
                  </a>
                  <span className="f6 silver"> dot </span>
                </li>
                <li className="mb2 dib">
                  <a
                    href="/jobs.html"
                    className="no-underline fw3 f6 silver hover-link"
                    name="footer-hiring"
                    target="_blank">
                    {ReasonReact.string(" We're Hiring")}
                  </a>
                  <span className="dn" />
                </li>
              </ul>
            </div>
          </section>
        </div>
        <RunScript>
          {|
          Array.from(document.getElementsByTagName('a')).forEach(e => {
            if (e.name != "") e.onclick = (event) => {
                _gaq.push(['_trackEvent', 'coda', 'click', e.name, '0']);
            }
          })|}
        </RunScript>
      </div>,
  };
};

let component = ReasonReact.statelessComponent("Page");
let make = (~extraHeaders=ReasonReact.null, children) => {
  ...component,
  render: _ =>
    <html>
      <Header extra=extraHeaders />
      <body className="metropolis black bg-white">
        <Nav />
        <div className="wrapper"> ...children </div>
        <Footer color="bg-snow" />
      </body>
    </html>,
};
