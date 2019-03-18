module Header = {
  let component = ReasonReact.statelessComponent("Header");
  let make = (~extra, ~filename, _children) => {
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
        <link rel="stylesheet" type_="text/css" href={filename ++ ".css"} />
        <link
          rel="stylesheet"
          type_="text/css"
          href="/static/css/common.css"
        />
        <link
          rel="stylesheet"
          type_="text/css"
          href="/static/css/gallery.css"
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
        // HACK: Force ibm plex fonts on all the pages
        <style
          dangerouslySetInnerHTML={
            "__html": {|
@font-face {
  font-family: 'IBM Plex Sans';
  font-style: normal;
  font-weight: 400;
  src: url("/static/font/IBMPlexSans-Regular-Latin1.woff2") format("woff2"),
    url("/static/font/IBMPlexSans-Regular-Latin1.woff") format("woff");
  unicode-range: U+0000, U+000D, U+0020-007E, U+00A0-00A3, U+00A4-00FF, U+0131, U+0152-0153, U+02C6, U+02DA, U+02DC, U+2013-2014, U+2018-201A, U+201C-201E, U+2020-2022, U+2026, U+2030, U+2039-203A, U+2044, U+2074, U+20AC, U+2122, U+2212, U+FB01-FB02;
}

@font-face {
  font-family: 'IBM Plex Sans';
  font-style: normal;
  font-weight: 500;
  src: url("/static/font/IBMPlexSans-Medium-Latin1.woff2") format("woff2"),
    url("/static/font/IBMPlexSans-Medium-Latin1.woff") format("woff");
  unicode-range: U+0000, U+000D, U+0020-007E, U+00A0-00A3, U+00A4-00FF, U+0131, U+0152-0153, U+02C6, U+02DA, U+02DC, U+2013-2014, U+2018-201A, U+201C-201E, U+2020-2022, U+2026, U+2030, U+2039-203A, U+2044, U+2074, U+20AC, U+2122, U+2212, U+FB01-FB02;
}

@font-face {
  font-family: 'IBM Plex Sans';
  font-style: normal;
  font-weight: 600;
  src: url("/static/font/IBMPlexSans-SemiBold-Latin1.woff2") format("woff2"),
    url("/static/font/IBMPlexSans-SemiBold-Latin1.woff") format("woff");
  unicode-range: U+0000, U+000D, U+0020-007E, U+00A0-00A3, U+00A4-00FF, U+0131, U+0152-0153, U+02C6, U+02DA, U+02DC, U+2013-2014, U+2018-201A, U+201C-201E, U+2020-2022, U+2026, U+2030, U+2039-203A, U+2044, U+2074, U+20AC, U+2122, U+2212, U+FB01-FB02;
}
@font-face {
  font-family: 'IBM Plex Sans';
  font-style: normal;
  font-weight: 700;
  src: url("/static/font/IBMPlexSans-Bold-Latin1.woff2") format("woff2"),
    url("/static/font/IBMPlexSans-Bold-Latin1.woff") format("woff");
  unicode-range: U+0000, U+000D, U+0020-007E, U+00A0-00A3, U+00A4-00FF, U+0131, U+0152-0153, U+02C6, U+02DA, U+02DC, U+2013-2014, U+2018-201A, U+201C-201E, U+2020-2022, U+2026, U+2030, U+2039-203A, U+2044, U+2074, U+20AC, U+2122, U+2212, U+FB01-FB02; }

@font-face {
  font-family: 'IBM Plex Mono';
  font-style: normal;
  font-weight: 600;
  src: url("/static/font/IBMPlexMono-SemiBold-Latin1.woff2") format("woff2"),
    url("/static/font/IBMPlexMono-SemiBold-Latin1.woff") format("woff");
  unicode-range: U+0000, U+000D, U+0020-007E, U+00A0-00A3, U+00A4-00FF, U+0131, U+0152-0153, U+02C6, U+02DA, U+02DC, U+2013-2014, U+2018-201A, U+201C-201E, U+2020-2022, U+2026, U+2030, U+2039-203A, U+2044, U+2074, U+20AC, U+2122, U+2212, U+FB01-FB02; }

@font-face {
  font-family: 'IBM Plex Italic';
  font-style: italic;
  font-weight: 400;
  src: url("/static/font/IBMPlexSans-Italic-Latin1.woff2") format("woff2"),
    url("/static/font/IBMPlexSans-Italic-Latin1.woff") format("woff");
  unicode-range: U+0000, U+000D, U+0020-007E, U+00A0-00A3, U+00A4-00FF, U+0131, U+0152-0153, U+02C6, U+02DA, U+02DC, U+2013-2014, U+2018-201A, U+201C-201E, U+2020-2022, U+2026, U+2030, U+2039-203A, U+2044, U+2074, U+20AC, U+2122, U+2212, U+FB01-FB02;
}
|},
          }
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
  module Link = {
    let component = ReasonReact.statelessComponent("LegacyPage.Footer.Link");
    let make = (~last=false, ~link, ~name, children) => {
      ...component,
      render: _self =>
        <li className="mb2 dib">
          <a
            href=link
            className="no-underline fw3 f6 silver hover-link"
            name={"footer-" ++ name}
            target="_blank">
            ...children
          </a>
          {last
             ? <span className="dn" />
             : <span className="f6 silver">
                 {ReasonReact.string({js| · |js})}
               </span>}
        </li>,
    };
  };

  let component = ReasonReact.statelessComponent("Footer");
  let make = (~color, _children) => {
    ...component,
    render: _self =>
      <div>
        <div className={"bxs-cb " ++ color}>
          <section
            className="section-wrapper pv4 mw9 center bxs-bb ph6-l ph5-m ph4 mw9-l">
            <div className="flex justify-center tc mb4">
              <ul className="list ph0">
                <Link link="mailto:contact@o1labs.org" name="mail">
                  {ReasonReact.string("contact@o1labs.org")}
                </Link>
                <Link link="https://o1labs.org" name="o1www">
                  {ReasonReact.string("o1labs.org")}
                </Link>
                <Link link="https://twitter.com/codaprotocol" name="twitter">
                  {ReasonReact.string("Twitter.org")}
                </Link>
                <Link link="https://github.com/o1-labs" name="github">
                  {ReasonReact.string("GitHub")}
                </Link>
                <Link link="https://reddit.com/r/coda" name="reddit">
                  {ReasonReact.string("Reddit")}
                </Link>
                <Link link="https://t.me/codaprotocol" name="telegram">
                  {ReasonReact.string("Telegram")}
                </Link>
                <Link link="/tos.html" name="tos">
                  {ReasonReact.string("Terms of service")}
                </Link>
                <Link link="/privacy.html" name="privacy">
                  {ReasonReact.string("Privacy Policy")}
                </Link>
                <Link link="/jobs.html" name="hiring" last=true>
                  {ReasonReact.string("We're Hiring")}
                </Link>
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

let component = ReasonReact.statelessComponent("LegacyPage");
let make = (~name, ~extraHeaders=ReasonReact.null, ~footerColor="", children) => {
  ...component,
  render: _ =>
    <html>
      <Header extra=extraHeaders filename=name />
      <body className="metropolis black bg-white">
        <CodaNav />
        <div className="wrapper"> ...children </div>
        <Footer color=footerColor />
      </body>
    </html>,
};
