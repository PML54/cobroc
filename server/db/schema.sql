CREATE TABLE historic (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  hist_name        TEXT    NOT NULL,
  hist_date        TEXT    NOT NULL,
  hist_good        INTEGER NOT NULL DEFAULT 0,
  hist_ville       TEXT    NOT NULL,
  hist_code_postal INTEGER NOT NULL DEFAULT 0,
  hist_adresse     TEXT    NOT NULL DEFAULT '',
  hist_nb_expo     INTEGER NOT NULL DEFAULT 0,
  hist_pml_dep     INTEGER NOT NULL DEFAULT 0,
  hist_fra_dep     INTEGER NOT NULL DEFAULT 0,
  hist_maison_dep  INTEGER NOT NULL DEFAULT 0,
  hist_avis        TEXT    NOT NULL DEFAULT '',
  hist_detail      TEXT    NOT NULL DEFAULT '',
  validated        INTEGER NOT NULL DEFAULT 0,
  agent_notes      TEXT    NOT NULL DEFAULT '',
  created_at       TEXT    NOT NULL DEFAULT (datetime('now'))
, ville_normalized TEXT, lieu_id INTEGER REFERENCES lieux(id), heure_arrivee TEXT NOT NULL DEFAULT '', pluie INTEGER NOT NULL DEFAULT 0, arrivee_tard INTEGER NOT NULL DEFAULT 0, ordre INTEGER NOT NULL DEFAULT 1, endroit_parking INTEGER NOT NULL DEFAULT 0, endroit_champ INTEGER NOT NULL DEFAULT 0, endroit_stade INTEGER NOT NULL DEFAULT 0, endroit_place INTEGER NOT NULL DEFAULT 0, endroit_rues INTEGER NOT NULL DEFAULT 0, endroit_salle INTEGER NOT NULL DEFAULT 0, qualite_agreable INTEGER NOT NULL DEFAULT 0, qualite_non_signalee INTEGER NOT NULL DEFAULT 0, qualite_a_faire_a_2 INTEGER NOT NULL DEFAULT 0);
CREATE TABLE sqlite_sequence(name,seq);
CREATE INDEX idx_ville      ON historic(hist_ville);
CREATE INDEX idx_date       ON historic(hist_date);
CREATE INDEX idx_name       ON historic(hist_name);
CREATE INDEX idx_validated  ON historic(validated);
CREATE TABLE lieux (
                id               INTEGER PRIMARY KEY AUTOINCREMENT,
                nom              TEXT    NOT NULL DEFAULT '',
                ville            TEXT    NOT NULL,
                ville_normalized TEXT,
                code_postal      INTEGER NOT NULL DEFAULT 0,
                adresse          TEXT    NOT NULL DEFAULT '',
                recurrence       TEXT    NOT NULL DEFAULT '',
                created_at       TEXT    NOT NULL DEFAULT (datetime('now'))
            , parking INTEGER NOT NULL DEFAULT 0, rues INTEGER NOT NULL DEFAULT 0, stade INTEGER NOT NULL DEFAULT 0, espace INTEGER NOT NULL DEFAULT 0);
CREATE INDEX idx_lieux_ville ON lieux(ville_normalized);
CREATE INDEX idx_lieu_id ON historic(lieu_id);
