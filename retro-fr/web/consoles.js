// Consoles prises en charge : identifiant EmulatorJS, nom affiché, extensions reconnues.
// Une extension partagée (.bin, .zip, .iso…) n'est pas dans la liste : l'application demande alors la console.
const CONSOLES = [
  { id: "nes",       nom: "NES",                 marque: "Nintendo", couleur: "#c62828", ext: ["nes", "fds", "unf", "unif"] },
  { id: "snes",      nom: "Super Nintendo",      marque: "Nintendo", couleur: "#6a1b9a", ext: ["sfc", "smc", "fig", "swc"] },
  { id: "n64",       nom: "Nintendo 64",         marque: "Nintendo", couleur: "#2e7d32", ext: ["n64", "z64", "v64"] },
  { id: "gb",        nom: "Game Boy / Color",    marque: "Nintendo", couleur: "#558b2f", ext: ["gb", "gbc", "dmg"] },
  { id: "gba",       nom: "Game Boy Advance",    marque: "Nintendo", couleur: "#3949ab", ext: ["gba"] },
  { id: "nds",       nom: "Nintendo DS",         marque: "Nintendo", couleur: "#455a64", ext: ["nds"] },
  { id: "vb",        nom: "Virtual Boy",         marque: "Nintendo", couleur: "#b71c1c", ext: ["vb", "vboy"] },
  { id: "segaMS",    nom: "Master System",       marque: "Sega",     couleur: "#d84315", ext: ["sms"] },
  { id: "segaMD",    nom: "Mega Drive",          marque: "Sega",     couleur: "#212121", ext: ["md", "gen", "smd"] },
  { id: "segaGG",    nom: "Game Gear",           marque: "Sega",     couleur: "#1565c0", ext: ["gg"] },
  { id: "sega32x",   nom: "Sega 32X",            marque: "Sega",     couleur: "#ef6c00", ext: ["32x"] },
  { id: "segaCD",    nom: "Mega-CD",             marque: "Sega",     couleur: "#37474f", ext: [] },
  { id: "psx",       nom: "PlayStation",         marque: "Sony",     couleur: "#757575", ext: ["pbp", "chd", "cue"] },
  { id: "pce",       nom: "PC Engine",           marque: "NEC",      couleur: "#f9a825", ext: ["pce"] },
  { id: "ngp",       nom: "Neo Geo Pocket",      marque: "SNK",      couleur: "#00838f", ext: ["ngp", "ngc"] },
  { id: "ws",        nom: "WonderSwan",          marque: "Bandai",   couleur: "#5d4037", ext: ["ws", "wsc"] },
  { id: "lynx",      nom: "Atari Lynx",          marque: "Atari",    couleur: "#4e342e", ext: ["lnx"] },
  { id: "atari2600", nom: "Atari 2600",          marque: "Atari",    couleur: "#8d6e63", ext: ["a26"] },
  { id: "atari7800", nom: "Atari 7800",          marque: "Atari",    couleur: "#6d4c41", ext: ["a78"] },
];

function consoleParId(id) {
  return CONSOLES.find((c) => c.id === id);
}

function deviner(nomFichier) {
  const ext = nomFichier.split(".").pop().toLowerCase();
  const c = CONSOLES.find((c) => c.ext.includes(ext));
  return c ? c.id : null;
}

// Jeux gratuits et légaux, distribués par leurs auteurs. On ne fait que pointer vers leur page :
// la personne télécharge le jeu là-bas puis l'importe avec le bouton « Ajouter ».
const JEUX_GRATUITS = [
  { titre: "Tobu Tobu Girl Deluxe", console: "gb", auteur: "Tangram Games",
    lien: "https://tangramgames.itch.io/tobutobugirl-dx", note: "Jeu de plateforme vertical, gratuit." },
  { titre: "µCity", console: "gb", auteur: "Antonio Niño Díaz",
    lien: "https://github.com/AntonioND/ucity", note: "Jeu de gestion de ville, libre (GPL)." },
  { titre: "Super Tilt Bro.", console: "nes", auteur: "sgadrat",
    lien: "https://sgadrat.itch.io/super-tilt-bro", note: "Jeu de combat, libre (WTFPL)." },
  { titre: "Homebrew Hub", console: "gb", auteur: "Collectif",
    lien: "https://hh.gbdev.io/", note: "Des centaines de jeux Game Boy amateurs, avec leur licence." },
];
