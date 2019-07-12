let extraHeaders = () => <> {Head.legacyStylesheets()} </>;

module Styles = {
  open Css;

  let markdownStyles =
    style([
      position(`relative),
      selector(
        "h1, h2, h3, h4",
        [
          display(`flex),
          marginTop(rem(2.)),
          marginBottom(`rem(0.5)),
          color(Style.Colors.marine),
          hover([selector(".headerlink", [display(`inlineBlock)])]),
        ],
      ),
      selector(
        ".headerlink",
        [
          display(`none),
          width(rem(1.)),
          height(rem(1.)),
          marginLeft(rem(0.5)),
          color(`transparent),
          hover([color(`transparent)]),
          backgroundSize(`cover),
          backgroundImage(url("/static/img/link.svg")),
        ],
      ),
      selector(
        "h1",
        Style.H1.heroStyles
        @ [
          color(Style.Colors.teal),
          alignItems(`baseline),
          fontWeight(`normal),
        ],
      ),
      selector("h2", Style.H2.basicStyles @ [alignItems(`baseline)]),
      selector(
        "h3",
        Style.H3.basicStyles
        @ [textAlign(`left), alignItems(`center), fontWeight(`medium)],
      ),
      selector(
        "h4",
        Style.H4.basicStyles @ [textAlign(`left), alignItems(`center)],
      ),
      selector("p", Style.Body.basicStyles),
      selector(
        "ul, ol",
        [
          margin(`zero),
          marginLeft(rem(1.5)),
          padding(`zero),
          ...Style.Body.basicStyles,
        ],
      ),
      selector("ul", [margin2(~v=`rem(1.), ~h=`zero)]),
      selector(
        "code",
        [Style.Typeface.pragmataPro, color(Style.Colors.midnight)],
      ),
      selector(
        "p > code, li > code",
        [
          boxSizing(`borderBox),
          padding2(~v=`px(2), ~h=`px(6)),
          backgroundColor(Style.Colors.slateAlpha(0.05)),
          borderRadius(`px(4)),
        ],
      ),
      selector(
        "pre",
        [
          backgroundColor(Style.Colors.slateAlpha(0.05)),
          borderRadius(`px(9)),
          padding2(~v=`rem(0.5), ~h=`rem(1.)),
          overflow(`scroll),
        ],
      ),
      selector(
        "a",
        [
          hover([color(Style.Colors.hyperlinkHover)]),
          ...Style.Link.basicStyles,
        ],
      ),
      selector(
        "strong",
        [fontWeight(`num(600)), color(Style.Colors.metallicBlue)],
      ),
      selector(
        ".admonition",
        [
          border(px(1), `solid, `currentColor),
          borderRadius(px(9)),
          overflow(`hidden),
          selector(
            "p",
            [margin(`zero), padding2(~v=`rem(0.5), ~h=`rem(1.))],
          ),
          selector(".admonition-title", [fontWeight(`num(600))]),
        ],
      ),
      selector(
        ".admonition.note",
        [
          color(Style.Colors.marineAlpha(0.8)),
          selector(
            ".admonition-title",
            [
              color(white),
              backgroundColor(Style.Colors.marineAlpha(0.8)),
            ],
          ),
        ],
      ),
      selector(
        ".admonition.warning",
        [
          color(Style.Colors.rosebudAlpha(0.8)),
          selector(
            ".admonition-title",
            [
              color(white),
              backgroundColor(Style.Colors.rosebudAlpha(0.8)),
            ],
          ),
        ],
      ),
    ]);

  let sideNav =
    style([
      minWidth(rem(15.)),
      selector("ul", [listStyleType(`none)]),
      selector("ul:first-child", [marginLeft(`zero)]),
      selector("li > ul", [marginLeft(rem(1.))]),
      selector("li", [marginBottom(rem(0.5))]),
      selector(
        ".current > a",
        [
          position(`relative),
          fontWeight(`bold),
          before([
            position(`absolute),
            left(rem(-0.75)),
            contentRule("\\2022 "),
          ]),
        ],
      ),
      selector("ul > li > ul", [marginTop(rem(0.5))]),
      selector("input ~ ul", [display(`none)]),
      selector("input:checked ~ ul", [display(`block)]),
      selector(
        "li > label",
        [
          display(`flex),
          alignItems(`center),
          justifyContent(`spaceBetween),
        ],
      ),
      selector("label > img", [opacity(0.7), transform(rotate(`deg(0)))]),
      selector(
        "input:checked ~ label > img",
        [transform(rotate(`deg(-180)))],
      ),
      media(
        Style.MediaQuery.somewhatLarge,
        [marginRight(rem(2.)), marginTop(rem(3.))],
      ),
    ]);
};

// We need to calculate the CDN url and inject it into the template
let chevronUrl = Links.Cdn.url("/static/img/chevron-down.svg")

let component = ReasonReact.statelessComponent("Blog");

let make = _children => {
  ...component,
  render: _self =>
    <div
      className=Css.(
        merge([
          Styles.markdownStyles,
          style([
            display(`flex),
            flexDirection(`column),
            alignItems(`flexStart),
            justifyContent(`center),
            marginLeft(`auto),
            marginRight(`auto),
            media(Style.MediaQuery.full, [marginTop(`rem(2.0))]),
            media(Style.MediaQuery.somewhatLarge, [flexDirection(`row)]),
          ]),
        ])
      )>
      <aside
        className=Styles.sideNav
        dangerouslySetInnerHTML={
          "__html": {j|
            {% if nav|length>1 %}
              <ul>
              {% for nav_item in nav %}
                {% if nav_item.children %}
                  <li>
                    <input
                      type="checkbox"
                      {% if nav_item.children|map(attribute='active')|sort|last %}
                        checked
                      {% endif %}
                      style="display:none"
                      id="{{nav_item.title|replace(" ", "_") }}-toggle"
                    />
                    <label for="{{nav_item.title|replace(" ", "_") }}-toggle">
                      {{ nav_item.title }}
                      <img src="$chevronUrl" width="16" height="16" />
                    </label>
                    <ul>
                    {% for nav_item in nav_item.children %}
                      <li class="{% if nav_item.active%}current{% endif %}">
                        <a href="{{ nav_item.url|url }}">{{ nav_item.title }}</a>
                      </li>
                    {% endfor %}
                    </ul>
                  </li>
                {% else %}
                  <li class="{% if nav_item.active%}current{% endif %}">
                    <a href="{{ nav_item.url|url }}">{{ nav_item.title }}</a>
                  </li>
                {% endif %}
              {% endfor %}
              </ul>
            {% endif %}
          |j},
        }
      />
      <article
        className=Css.(
          style([maxWidth(`rem(43.)), width(`percent(100.))])
        )>
        {ReasonReact.string("{{ page.content }}")}
      </article>
    </div>,
};
