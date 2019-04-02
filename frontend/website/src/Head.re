let legacyStylesheets =
  <>
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
    <link rel="stylesheet" type_="text/css" href="/static/css/common.css" />
  </>;

let component = ReasonReact.statelessComponent("Header");
let make = (~extra, ~filename, _children) => {
  ...component,
  render: _self =>
    <head>
      {ReactDOMRe.createElement(
         "meta",
         ~props=ReactDOMRe.objToDOMProps({"charSet": "utf-8"}),
         [||],
       )}
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <meta
        property="og:image"
        content="https://coda-staging-84430.firebaseapp.com/static/img/coda_facebook_OG.jpg"
      />
      <meta property="og:updated_time" content="1526001445" />
      <meta property="og:type" content="website" />
      <meta property="og:url" content="https://codaprotocol.com" />
      <meta property="og:title" content="Coda Cryptocurrency Protocol" />
      <meta
        property="og:description"
        content="Coda is the first cryptocurrency with a succinct blockchain. Our lightweight blockchain means anyone can use Coda directly from any device, in less data than a few tweets."
      />
      <meta
        name="description"
        content="Coda is the first cryptocurrency with a succinct blockchain. Our lightweight blockchain means anyone can use Coda directly from any device, in less data than a few tweets."
      />
      extra
      <title> {ReasonReact.string("Coda Cryptocurrency Protocol")} </title>
      <link rel="stylesheet" type_="text/css" href="/fonts.css" />
      <link
        rel="stylesheet"
        type_="text/css"
        href="https://use.typekit.net/mta7mwm.css"
      />
      <link
        rel="stylesheet"
        type_="text/css"
        href="https://fonts.googleapis.com/css?family=Rubik:300,500"
      />
      <link
        rel="stylesheet"
        type_="text/css"
        href="/static/css/normalize.css"
      />
      <link rel="stylesheet" type_="text/css" href={filename ++ ".css"} />
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
      // On recent versions of firefox, the browser will do a "flash of
      // unstyled content" for images by displaying the alt text(!) before the
      // image loads. Of course, we must disable this.
      <style>
        {ReasonReact.string(
           {|
      img:-moz-loading {
        visibility: hidden;
      }|},
         )}
      </style>
      <RunScript>
        {|
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());

  gtag('config', 'UA-115553548-2');
  var _gaq = document._gaq || [];

  document.addEventListener("DOMContentLoaded", function() {
    Array.from(document.getElementsByTagName('a')).forEach(e => {
      if (e.name != "") e.onclick = (event) => {
          _gaq.push(['_trackEvent', 'coda', 'click', e.name, '0']);
      }
    })
  });
|}
      </RunScript>
    </head>,
};
