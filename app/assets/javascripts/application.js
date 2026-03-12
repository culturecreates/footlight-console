//= require jquery
//= require jquery.turbolinks
//= require rails-ujs
//= require turbolinks
//= require bulmahead.bundle
//= require underscore
//= require select2
//= require reconciliation
//= require_tree .



$(document).on("turbolinks:load", function () {

  const tabs = document.querySelectorAll("#settings-tabs li");
  if (!tabs.length) return;

  const contents = document.querySelectorAll(".tab-content");

  function activateTab(tabName, updateURL = true) {

    tabs.forEach(t => t.classList.remove("is-active"));
    contents.forEach(c => c.classList.add("is-hidden"));

    const tab = document.querySelector(`#settings-tabs li[data-tab="${tabName}"]`);
    const panel = document.getElementById(tabName);

    if (tab && panel) {
      tab.classList.add("is-active");
      panel.classList.remove("is-hidden");

      localStorage.setItem("websiteSettingsTab", tabName);

      if (updateURL) {
        history.replaceState(null, null, "#" + tabName);
      }
    }
  }

  // Priority: URL hash > saved tab > default
  const hashTab = globalThis.location.hash.replace("#", "");
  const savedTab = localStorage.getItem("websiteSettingsTab");

  if (hashTab) {
    activateTab(hashTab, false);
  } else if (savedTab) {
    activateTab(savedTab, false);
  }

  tabs.forEach(tab => {
    tab.addEventListener("click", () => {
      activateTab(tab.dataset.tab);
    });
  });

});

document.addEventListener("turbolinks:load", () => {

  const toggle = document.getElementById("toggle-pipeline");
  if (!toggle) return;

  const key = "dashboard_show_pipeline";

  // restore preference
  const saved = localStorage.getItem(key);

  if (saved === "true") {
    document.body.classList.add("show-pipeline");
    toggle.checked = true;
  }

  toggle.addEventListener("change", () => {

    if (toggle.checked) {
      document.body.classList.add("show-pipeline");
    } else {
      document.body.classList.remove("show-pipeline");
    }

    localStorage.setItem(key, toggle.checked);
  });

});