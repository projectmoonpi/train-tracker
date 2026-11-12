// About and credits › Updates: is there a newer US Train Tracker? Check now asks GitHub at once. On the computer
// running Train Tracker, Update to <version> downloads it in the background, checks it, unpacks it and opens its
// installer in front (updates.py); other devices are told to update from that computer. Made from SkyScope's.
// Designed and Created by Project Moon Pi.
(() => {
  const $ = id => document.getElementById(id);
  let timer = null;
  async function show(now) {
    if (!$("up-line")) return;
    if (now) $("up-job").textContent = "Checking…";
    try {
      const u = await (await fetch("api/update" + (now ? "?now=1" : ""), { cache: "no-store" })).json();
      const j = u.job || {}, busy = ["downloading", "checking", "unpacking", "opening"].includes(j.stage);
      if (u.newer) {
        $("up-line").textContent = `US Train Tracker ${u.latest} is available (you have ${u.current}).`;
        $("up-go").hidden = !(u.here && u.download); $("up-go").textContent = `Update to ${u.latest}`; $("up-go").disabled = busy;
        $("up-get").href = u.download || u.page; $("up-get").hidden = !u.here && !!u.download;
        $("up-get").textContent = u.here && u.download ? "Or download it yourself" : "See the new version";
      } else {
        $("up-line").textContent = u.latest ? `You have US Train Tracker ${u.current}, the newest.` : `You have US Train Tracker ${u.current}.`;
        $("up-go").hidden = true; $("up-get").hidden = true;
      }
      $("up-bar").hidden = !(u.here && (busy || j.stage === "open"));
      $("up-fill").style.width = (j.pct || 0) + "%";
      $("up-job").textContent = u.newer && !u.here ? "Update from the computer running Train Tracker."
        : j.error || j.text || u.error || (u.checked ? `Checked ${u.checked}.` : "");
      clearTimeout(timer);
      if (busy) timer = setTimeout(() => show(false), 600);   // (follow the update until the installer's open)
    } catch { $("up-job").textContent = "Train Tracker isn't answering."; }
  }
  $("up-now")?.addEventListener("click", () => show(true));
  $("up-go")?.addEventListener("click", async () => {
    const r = await (await fetch("api/update/start", { method: "POST" })).json().catch(() => ({ ok: false }));
    if (!r.ok) $("up-job").textContent = r.why || "The update couldn't start.";
    show(false);
  });
  show(false);
  setInterval(() => show(false), 6 * 3600 * 1000);

  // A newer version: a note at the top of the panel ("Update" opens About's Updates), until it's dismissed for
  // that version. "#updates" in the address (the icon by the clock, or the note) opens About at Updates.
  function openUpdates() {
    const about = $("credits");
    if (!about || !$("updates")) return;
    about.open = true;
    $("updates").scrollIntoView({ behavior: "smooth", block: "start" });
  }
  async function note() {
    try {
      const u = await (await fetch("api/update", { cache: "no-store" })).json();
      let gone = null;
      try { gone = localStorage.getItem("tt-update-dismissed"); } catch {}
      $("update-note").hidden = !(u.newer && u.latest !== gone);
      if (u.newer) $("update-text").textContent = `Train Tracker ${u.latest} is available.`;
      $("update-close").onclick = () => {
        $("update-note").hidden = true;
        try { localStorage.setItem("tt-update-dismissed", u.latest); } catch {}
      };
    } catch {}
  }
  $("update-open")?.addEventListener("click", e => { e.preventDefault(); openUpdates(); });
  if (location.hash === "#updates") setTimeout(openUpdates, 600);
  window.addEventListener("hashchange", () => { if (location.hash === "#updates") openUpdates(); });
  setTimeout(note, 15000);                 // (the first check runs in the background: ask again shortly)
  setInterval(note, 3 * 3600 * 1000);
  note();
})();
