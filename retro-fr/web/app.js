const $ = (s) => document.querySelector(s);
let filtre = "tous";
let jeux = [];

function message(texte) {
  const m = $("#message");
  m.textContent = texte;
  m.hidden = false;
  clearTimeout(message.t);
  message.t = setTimeout(() => { m.hidden = true; }, 3000);
}

function optionsConsoles(select, choisi) {
  select.innerHTML = "";
  for (const c of CONSOLES) {
    const o = document.createElement("option");
    o.value = c.id;
    o.textContent = `${c.nom} (${c.marque})`;
    if (c.id === choisi) o.selected = true;
    select.append(o);
  }
}

function demanderConsole(nomFichier) {
  const d = $("#choix-console");
  $("#choix-fichier").textContent = nomFichier;
  optionsConsoles($("#choix-select"), "psx");
  return new Promise((ok) => {
    d.addEventListener("close", () => ok(d.returnValue === "ok" ? $("#choix-select").value : null), { once: true });
    d.returnValue = "";
    d.showModal();
  });
}

async function importer(fichiers) {
  let n = 0;
  for (const f of fichiers) {
    const id = deviner(f.name) || (await demanderConsole(f.name));
    if (!id) continue;
    try {
      await Biblio.ajouter(f, id);
      n++;
    } catch (e) {
      message(`Impossible d'ajouter ${f.name} : ${e.message || e}`);
    }
  }
  if (n) message(n === 1 ? "1 jeu ajouté" : `${n} jeux ajoutés`);
  await rafraichir();
}

function initiales(titre) {
  return titre.replace(/\(.*?\)/g, "").trim().split(/\s+/).slice(0, 2).map((m) => m[0] || "").join("").toUpperCase();
}

function carte(jeu) {
  const c = consoleParId(jeu.console) || { nom: jeu.console, couleur: "#444" };
  const el = document.createElement("article");
  el.className = "jeu";
  el.innerHTML = `
    <button class="jaquette" style="--c:${c.couleur}">
      <span class="lettres"></span>
      <span class="badge"></span>
    </button>
    <div class="infos">
      <span class="titre"></span>
      <button class="plus" aria-label="Options">⋮</button>
    </div>`;
  el.querySelector(".lettres").textContent = initiales(jeu.titre);
  el.querySelector(".badge").textContent = c.nom;
  el.querySelector(".titre").textContent = jeu.titre;
  el.querySelector(".jaquette").onclick = () => { location.href = `play.html?id=${encodeURIComponent(jeu.id)}`; };
  el.querySelector(".plus").onclick = () => options(jeu);
  return el;
}

function options(jeu) {
  const d = $("#options-jeu");
  $("#options-titre").textContent = jeu.titre;
  $("#options-nom").value = jeu.titre;
  optionsConsoles($("#options-console"), jeu.console);
  d.returnValue = "";
  d.addEventListener("close", async () => {
    if (d.returnValue === "ok") {
      await Biblio.modifier(jeu.id, { titre: $("#options-nom").value.trim() || jeu.titre, console: $("#options-console").value });
    } else if (d.returnValue === "supprimer") {
      if (!confirm(`Supprimer « ${jeu.titre} » ? Les sauvegardes de ce jeu restent dans l'émulateur.`)) return;
      await Biblio.supprimer(jeu.id);
      message("Jeu supprimé");
    }
    rafraichir();
  }, { once: true });
  d.showModal();
}

function afficher() {
  const q = $("#recherche").value.trim().toLowerCase();
  const visibles = jeux
    .filter((j) => filtre === "tous" || j.console === filtre)
    .filter((j) => !q || j.titre.toLowerCase().includes(q))
    .sort((a, b) => (b.joue || 0) - (a.joue || 0) || a.titre.localeCompare(b.titre, "fr"));

  const liste = $("#liste");
  liste.innerHTML = "";
  visibles.forEach((j) => liste.append(carte(j)));
  $("#vide").hidden = jeux.length > 0;

  const presentes = CONSOLES.filter((c) => jeux.some((j) => j.console === c.id));
  const filtres = $("#filtres");
  filtres.innerHTML = "";
  if (presentes.length > 1) {
    for (const c of [{ id: "tous", nom: "Toutes" }, ...presentes]) {
      const b = document.createElement("button");
      b.textContent = c.nom;
      b.className = c.id === filtre ? "actif" : "";
      b.onclick = () => { filtre = c.id; afficher(); };
      filtres.append(b);
    }
  }
}

async function rafraichir() {
  jeux = await Biblio.tous();
  if (filtre !== "tous" && !jeux.some((j) => j.console === filtre)) filtre = "tous";
  afficher();
}

function onglet(nom) {
  document.querySelectorAll(".onglets button").forEach((b) => b.classList.toggle("actif", b.dataset.onglet === nom));
  document.querySelectorAll("main > section").forEach((s) => { s.hidden = s.id !== nom; });
}

function remplirGratuits() {
  const box = $("#liste-gratuits");
  for (const g of JEUX_GRATUITS) {
    const c = consoleParId(g.console);
    const a = document.createElement("a");
    a.className = "carte";
    a.href = g.lien;
    a.target = "_blank";
    a.rel = "noopener";
    a.innerHTML = `<b></b><span class="badge"></span><small></small><em></em>`;
    a.querySelector("b").textContent = g.titre;
    a.querySelector(".badge").textContent = c.nom;
    a.querySelector("small").textContent = g.auteur;
    a.querySelector("em").textContent = g.note;
    box.append(a);
  }
  const t = $("#tableau-consoles");
  t.innerHTML = "<table><tr><th>Console</th><th>Fichiers</th></tr></table>";
  for (const c of CONSOLES) {
    const tr = document.createElement("tr");
    tr.innerHTML = "<td></td><td></td>";
    tr.cells[0].textContent = c.nom;
    tr.cells[1].textContent = c.ext.length ? c.ext.map((e) => "." + e).join(" ") : "à choisir (.zip, .chd…)";
    t.querySelector("table").append(tr);
  }
}

$("#ajouter").onclick = () => $("#fichiers").click();
$("#fichiers").onchange = (e) => { importer([...e.target.files]); e.target.value = ""; };
$("#recherche").oninput = afficher;
document.querySelectorAll(".onglets button").forEach((b) => { b.onclick = () => onglet(b.dataset.onglet); });

remplirGratuits();
rafraichir();
