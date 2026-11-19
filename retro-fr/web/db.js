// Bibliothèque de jeux stockée dans IndexedDB, sur le téléphone uniquement.
const DB_NOM = "retrofr";
const DB_STORE = "jeux";

function ouvrirDb() {
  return new Promise((ok, ko) => {
    const req = indexedDB.open(DB_NOM, 1);
    req.onupgradeneeded = () => {
      const store = req.result.createObjectStore(DB_STORE, { keyPath: "id" });
      store.createIndex("console", "console");
    };
    req.onsuccess = () => ok(req.result);
    req.onerror = () => ko(req.error);
  });
}

async function tx(mode, fn) {
  const db = await ouvrirDb();
  return new Promise((ok, ko) => {
    const t = db.transaction(DB_STORE, mode);
    const store = t.objectStore(DB_STORE);
    let resultat;
    Promise.resolve(fn(store)).then((r) => { resultat = r; });
    t.oncomplete = () => { db.close(); ok(resultat); };
    t.onerror = () => { db.close(); ko(t.error); };
    t.onabort = () => { db.close(); ko(t.error); };
  });
}

function requete(req) {
  return new Promise((ok, ko) => {
    req.onsuccess = () => ok(req.result);
    req.onerror = () => ko(req.error);
  });
}

const Biblio = {
  async tous() {
    // Sans le fichier : la liste reste légère même avec beaucoup de jeux.
    const jeux = await tx("readonly", (s) => requete(s.getAll()));
    return jeux.map(({ fichier, ...meta }) => meta);
  },
  async un(id) {
    return tx("readonly", (s) => requete(s.get(id)));
  },
  async ajouter(fichier, consoleId) {
    const jeu = {
      id: (crypto.randomUUID ? crypto.randomUUID() : String(Date.now()) + Math.random()),
      titre: titreDepuisFichier(fichier.name),
      nomFichier: fichier.name,
      console: consoleId,
      taille: fichier.size,
      ajoute: Date.now(),
      joue: 0,
      fichier: new Blob([await fichier.arrayBuffer()], { type: "application/octet-stream" }),
    };
    await tx("readwrite", (s) => requete(s.put(jeu)));
    return jeu;
  },
  async modifier(id, champs) {
    return tx("readwrite", async (s) => {
      const jeu = await requete(s.get(id));
      if (jeu) await requete(s.put({ ...jeu, ...champs }));
    });
  },
  async supprimer(id) {
    return tx("readwrite", (s) => requete(s.delete(id)));
  },
};

// « Mon_Jeu (France) [!].sfc » → « Mon Jeu (France) »
function titreDepuisFichier(nom) {
  return nom
    .replace(/\.[^.]+$/, "")
    .replace(/[_]+/g, " ")
    .replace(/\s*\[[^\]]*\]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}
