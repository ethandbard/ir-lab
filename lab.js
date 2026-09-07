// Progress tracking for IR Lab exercises.
//
// quarto-live renders a grading result as `.alert.exercise-grade`. When a
// success alert appears inside a `.lab-exercise[data-exercise]` wrapper, the
// exercise id is stored in localStorage. Track cards on the index and lesson
// pages read the store to show completion counts. Everything stays in this
// browser; nothing is sent anywhere.

(function () {
  const KEY = "irlab.done";

  function load() {
    try {
      return JSON.parse(localStorage.getItem(KEY) || "{}");
    } catch (e) {
      return {};
    }
  }

  function save(done) {
    try {
      localStorage.setItem(KEY, JSON.stringify(done));
    } catch (e) {
      /* private mode or storage blocked: progress is simply not kept */
    }
  }

  function markDone(el) {
    if (!el.classList.contains("is-done")) {
      el.classList.add("is-done");
      if (!el.querySelector(".lab-done-badge")) {
        const badge = document.createElement("span");
        badge.className = "lab-done-badge";
        badge.textContent = "Done";
        el.prepend(badge);
      }
    }
  }

  function refreshProgress(done) {
    document.querySelectorAll(".lab-progress[data-exercises]").forEach((el) => {
      const ids = el.dataset.exercises.split(/\s+/).filter(Boolean);
      const n = ids.filter((id) => done[id]).length;
      if (ids.length === 0) {
        el.textContent = "";
      } else if (n === 0) {
        el.textContent = `${ids.length} exercises`;
      } else if (n === ids.length) {
        el.textContent = `All ${ids.length} exercises done`;
      } else {
        el.textContent = `${n} of ${ids.length} exercises done`;
      }
    });
  }

  function init() {
    const done = load();

    document.querySelectorAll(".lab-exercise[data-exercise]").forEach((el) => {
      if (done[el.dataset.exercise]) markDone(el);
    });
    refreshProgress(done);

    const observer = new MutationObserver((mutations) => {
      for (const m of mutations) {
        for (const node of m.addedNodes) {
          if (!(node instanceof HTMLElement)) continue;
          const alert = node.matches(".alert.exercise-grade.alert-success")
            ? node
            : node.querySelector(".alert.exercise-grade.alert-success");
          if (!alert) continue;
          const wrapper = alert.closest(".lab-exercise[data-exercise]");
          if (!wrapper) continue;
          const id = wrapper.dataset.exercise;
          const store = load();
          if (!store[id]) {
            store[id] = new Date().toISOString();
            save(store);
          }
          markDone(wrapper);
          refreshProgress(store);
        }
      }
    });
    observer.observe(document.body, { childList: true, subtree: true });

    // "Reset progress" links.
    document.querySelectorAll("[data-lab-reset]").forEach((a) => {
      a.addEventListener("click", (ev) => {
        ev.preventDefault();
        save({});
        document.querySelectorAll(".lab-exercise.is-done").forEach((el) => el.classList.remove("is-done"));
        refreshProgress({});
      });
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
