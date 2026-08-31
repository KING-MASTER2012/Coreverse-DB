// Coreverse DB — small, dependency-free UX enhancements for mdBook.

(function () {
  "use strict";

  const root = document.documentElement;

  // Add a subtle class to the document once the page is ready. This gives
  // future CSS tweaks a stable hook without changing mdBook's markup.
  document.addEventListener("DOMContentLoaded", function () {
    root.classList.add("coreverse-docs-ready");

    // External links open in a new tab and are marked for assistive tech.
    document.querySelectorAll('a[href^="http://"], a[href^="https://"]').forEach(function (link) {
      if (link.hostname !== window.location.hostname) {
        link.target = "_blank";
        link.rel = "noopener noreferrer";
        link.setAttribute("aria-label", (link.textContent || "External link") + " (opens in a new tab)");
      }
    });
  });
})();
