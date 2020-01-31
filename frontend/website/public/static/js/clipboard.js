/* Clipboard integration */
const blocks = document.querySelectorAll("pre > code");

Array.prototype.forEach.call(blocks, (block, index) => {
  const parent = block.parentNode;

  const button = document.createElement("div");
  button.style.position = "absolute";
  button.style.top = "6px";
  button.style.right = "6px";
  button.style.width = "24px";
  button.style.height = "24px";
  button.style.opacity = '0.2';
  button.style.cursor = 'pointer';
  button.style.backgroundImage = 'url("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNTEyIiBoZWlnaHQ9IjUxMiIgdmlld0JveD0iMCAwIDUxMiA1MTIiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI1MTIiIGhlaWdodD0iNTEyIiAvPgo8cGF0aCBmaWxsLXJ1bGU9ImV2ZW5vZGQiIGNsaXAtcnVsZT0iZXZlbm9kZCIgZD0iTTMwMSAxMzBIMTUzVjM3MUgxMzdWMTIyQzEzNyAxMTcuNTgyIDE0MC41ODIgMTE0IDE0NSAxMTRIMzAxVjEzMFpNMTg2IDM4NlYxNjJIMzI2VjM4NkgxODZaTTE3MCAxNTRDMTcwIDE0OS41ODIgMTczLjU4MiAxNDYgMTc4IDE0NkgzMzRDMzM4LjQxOCAxNDYgMzQyIDE0OS41ODIgMzQyIDE1NFYzOTRDMzQyIDM5OC40MTggMzM4LjQxOCA0MDIgMzM0IDQwMkgxNzhDMTczLjU4MiA0MDIgMTcwIDM5OC40MTggMTcwIDM5NFYxNTRaIiBmaWxsPSJibGFjayIvPgo8L3N2Zz4K")';
  button.style.backgroundSize = 'cover';

  button.onmouseenter = function() { button.style.opacity = '0.7'; }
  button.onmouseleave = function() { button.style.opacity = '0.2'; }

  button.onclick = function() {
    navigator.clipboard.writeText(block.innerText).then(function() {
      // TODO: show "Copied!" toast here
    });
  };

  const containerElement = document.createElement("div");

  containerElement.style.position = "relative";

  containerElement.appendChild(button);
  containerElement.appendChild(parent.cloneNode(true));
  parent.replaceWith(containerElement);
});
