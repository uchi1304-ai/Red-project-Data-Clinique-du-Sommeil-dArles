-- ============================================================
--  CLINIQUE DU SOMMEIL D'ARLES
--  Base de production v1.0
--  Thomas Viviani : Base à usage pédagogique pour Simplon
-- ============================================================

DROP DATABASE IF EXISTS clinique_sommeil_prod;
CREATE DATABASE clinique_sommeil_prod
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;
USE clinique_sommeil_prod;

/* ============================================================
   1) PATIENT
   Données stables + snapshot initial au diagnostic
   ============================================================ */
CREATE TABLE patient (
    id_patient          INT             AUTO_INCREMENT PRIMARY KEY,
    nom                 VARCHAR(100)    NOT NULL,
    prenom              VARCHAR(100)    NOT NULL,
    date_naissance      DATE            NOT NULL,
    sexe                CHAR(1)         NOT NULL CHECK (sexe IN ('M','F')),
    adresse             VARCHAR(255),
    telephone           VARCHAR(20),
    email               VARCHAR(100),
    numero_secu         VARCHAR(20)     UNIQUE,
    -- Snapshot initial au diagnostic
    imc_initial         DECIMAL(4,1),
    fumeur              BOOLEAN         DEFAULT FALSE,
    pa_tabac            INT             COMMENT 'Paquets-années au diagnostic',
    consommation_alcool VARCHAR(50)     COMMENT 'aucune / occasionnelle / régulière / excessive',
    profession          VARCHAR(100),
    niveau_activite     VARCHAR(50)     COMMENT 'sédentaire / modéré / actif',
    -- Méta
    date_creation_dpi   DATE            NOT NULL DEFAULT (CURRENT_DATE),
    actif               BOOLEAN         DEFAULT TRUE
);

/* ============================================================
   2) SUIVI LONGITUDINAL PATIENT
   Évolutions importantes dans le temps
   ============================================================ */
CREATE TABLE suivi_patient (
    id_suivi            INT             AUTO_INCREMENT PRIMARY KEY,
    id_patient          INT             NOT NULL,
    id_medecin          INT             NOT NULL,
    date_suivi          DATE            NOT NULL,
    poids               DECIMAL(5,2),
    imc                 DECIMAL(4,1),
    tension_systolique  INT,
    tension_diastolique INT,
    statut_tabac        VARCHAR(50)     COMMENT 'fumeur / sevrage en cours / arrêté / non-fumeur',
    notes_evolution     TEXT,
    statut_patient      VARCHAR(20)     NOT NULL DEFAULT 'actif'
                        CHECK (statut_patient IN ('actif','perdu de vue','décédé'))
);

/* ============================================================
   3) DÉCÈS
   ============================================================ */
CREATE TABLE deces_patient (
    id_patient          INT             PRIMARY KEY,
    date_deces          DATE            NOT NULL,
    cause_principale    VARCHAR(255)    NOT NULL,
    cause_secondaire    VARCHAR(255),
    lien_apnee          BOOLEAN         NOT NULL DEFAULT FALSE
);

/* ============================================================
   4) COMORBIDITÉS
   ============================================================ */
CREATE TABLE comorbidite (
    id_comorbidite      INT             AUTO_INCREMENT PRIMARY KEY,
    libelle             VARCHAR(100)    NOT NULL UNIQUE,
    categorie           VARCHAR(50)     COMMENT 'cardiovasculaire / métabolique / respiratoire / psychiatrique / autre'
);

CREATE TABLE patient_comorbidite (
    id_patient          INT             NOT NULL,
    id_comorbidite      INT             NOT NULL,
    date_diagnostic     DATE,
    PRIMARY KEY (id_patient, id_comorbidite)
);

/* ============================================================
   5) PERSONNEL — HÉRITAGE
   ============================================================ */
CREATE TABLE personnel (
    id_personnel        INT             AUTO_INCREMENT PRIMARY KEY,
    nom                 VARCHAR(100)    NOT NULL,
    prenom              VARCHAR(100)    NOT NULL,
    date_embauche       DATE,
    telephone           VARCHAR(20),
    email               VARCHAR(100)    UNIQUE,
    actif               BOOLEAN         NOT NULL DEFAULT TRUE
);

CREATE TABLE medecin (
    id_personnel        INT             PRIMARY KEY,
    specialite          VARCHAR(100)    NOT NULL,
    numero_rpps         VARCHAR(50)     UNIQUE
);

CREATE TABLE infirmiere (
    id_personnel        INT             PRIMARY KEY,
    diplome             VARCHAR(100),
    experience_ans      INT             CHECK (experience_ans >= 0)
);

/* ============================================================
   6) APPAREILS — HÉRITAGE PSG / CPAP
   ============================================================ */
CREATE TABLE appareil (
    id_appareil         INT             AUTO_INCREMENT PRIMARY KEY,
    modele              VARCHAR(100)    NOT NULL,
    numero_serie        VARCHAR(100)    UNIQUE,
    fabricant           VARCHAR(100),
    date_installation   DATE,
    statut              VARCHAR(20)     NOT NULL DEFAULT 'actif'
                        CHECK (statut IN ('actif','maintenance','hors service')),
    localisation        VARCHAR(100)
);

CREATE TABLE appareil_psg (
    id_appareil         INT             PRIMARY KEY,
    version_firmware    VARCHAR(50),
    type_montage        VARCHAR(50)     COMMENT 'complet / ambulatoire'
);

CREATE TABLE appareil_cpap (
    id_appareil         INT             PRIMARY KEY,
    id_patient          INT             COMMENT 'Patient auquel l appareil est attribué',
    pression_initiale   DECIMAL(4,1)    CHECK (pression_initiale BETWEEN 4 AND 25),
    type_masque         VARCHAR(50)     COMMENT 'nasal / facial / narinaire',
    taille_masque       VARCHAR(10)
);

/* ============================================================
   7) CONSULTATIONS
   ============================================================ */
CREATE TABLE consultation (
    id_consultation     INT             AUTO_INCREMENT PRIMARY KEY,
    id_patient          INT             NOT NULL,
    id_medecin          INT             NOT NULL,
    date_consultation   DATE            NOT NULL,
    motif               VARCHAR(255),
    compte_rendu        TEXT
);

/* ============================================================
   8) NUIT D'ÉTUDE
   ============================================================ */
CREATE TABLE nuit_etude (
    id_nuit             INT             AUTO_INCREMENT PRIMARY KEY,
    id_patient          INT             NOT NULL,
    id_superviseur      INT             NOT NULL    COMMENT 'Infirmière superviseure',
    id_medecin          INT             NOT NULL,
    id_appareil_psg     INT             NOT NULL,
    date_nuit           DATE            NOT NULL,
    type_etude          VARCHAR(50)     NOT NULL
                        CHECK (type_etude IN ('polysomnographie','polygraphie','titration CPAP')),
    notes_techniques    TEXT
);

/* ============================================================
   9) PRESCRIPTION NUIT — lien Consultation → Nuit
   ============================================================ */
CREATE TABLE prescription_nuit (
    id_prescription     INT             AUTO_INCREMENT PRIMARY KEY,
    id_consultation     INT             NOT NULL,
    id_nuit             INT,
    motif_prescription  VARCHAR(255),
    urgence             VARCHAR(20)     NOT NULL DEFAULT 'normale'
                        CHECK (urgence IN ('normale','urgente'))
);

/* ============================================================
   10) RÉSULTAT NUIT (agrégé & validé par médecin)
   ============================================================ */
CREATE TABLE resultat_nuit (
    id_resultat             INT             AUTO_INCREMENT PRIMARY KEY,
    id_nuit                 INT             NOT NULL UNIQUE,
    id_medecin_validateur   INT             NOT NULL,
    date_validation         DATE            NOT NULL,

    -- Indices respiratoires
    iah                     DECIMAL(5,2)    CHECK (iah >= 0)
                            COMMENT 'Index Apnée-Hypopnée — événements/heure',
    spo2_min                DECIMAL(5,2)    CHECK (spo2_min BETWEEN 0 AND 100),
    spo2_moy                DECIMAL(5,2)    CHECK (spo2_moy BETWEEN 0 AND 100),
    spo2_mediane            DECIMAL(5,2)    CHECK (spo2_mediane BETWEEN 0 AND 100),

    -- Comptages
    nb_apnees               INT             CHECK (nb_apnees >= 0),
    nb_hypopnees            INT             CHECK (nb_hypopnees >= 0),
    nb_rera                 INT             CHECK (nb_rera >= 0),
    nb_microeveils          INT             CHECK (nb_microeveils >= 0),

    -- Durées
    duree_sommeil_min       INT             CHECK (duree_sommeil_min > 0),
    duree_hypoxie_min       INT             CHECK (duree_hypoxie_min >= 0),

    -- Position & ronflements
    position_dominante      VARCHAR(20)     CHECK (position_dominante IN ('dorsale','latérale','ventrale','mixte')),
    duree_apnee_moy_sec     INT             CHECK (duree_apnee_moy_sec >= 0),
    duree_apnee_max_sec     INT             CHECK (duree_apnee_max_sec >= 0),
    decibels_max            DECIMAL(5,2),
    decibels_moy            DECIMAL(5,2),
    nb_ronflements_forts    INT             CHECK (nb_ronflements_forts >= 0),

    -- Sévérité calculée
    severite_iah            VARCHAR(20)
                            GENERATED ALWAYS AS (
                                CASE
                                    WHEN iah < 5  THEN 'normal'
                                    WHEN iah < 15 THEN 'léger'
                                    WHEN iah < 30 THEN 'modéré'
                                    ELSE 'sévère'
                                END
                            ) STORED,

    commentaire_medical     TEXT
);

/* ============================================================
   11) ÉVÉNEMENTS RESPIRATOIRES
       Alimentés depuis le datalake (ETL)
   ============================================================ */
CREATE TABLE evenement_respiratoire (
    id_evenement        INT             AUTO_INCREMENT PRIMARY KEY,
    id_nuit             INT             NOT NULL,
    type_evenement      VARCHAR(50)     NOT NULL
                        CHECK (type_evenement IN ('apnée obstructive','apnée centrale','hypopnée','RERA')),
    debut_sec           INT             NOT NULL CHECK (debut_sec >= 0),
    fin_sec             INT             NOT NULL,
    duree_sec           INT             NOT NULL
                        GENERATED ALWAYS AS (fin_sec - debut_sec) STORED,
    severite            VARCHAR(20)     CHECK (severite IN ('légère','modérée','sévère')),
    decibels            DECIMAL(5,2),
    spo2_avant          DECIMAL(5,2)    CHECK (spo2_avant BETWEEN 0 AND 100),
    spo2_apres          DECIMAL(5,2)    CHECK (spo2_apres BETWEEN 0 AND 100),

    CHECK (fin_sec > debut_sec)
);

/* ============================================================
   12) SUIVI CPAP QUOTIDIEN
       Alimenté depuis le datalake (remontée appareils)
   ============================================================ */
CREATE TABLE suivi_cpap_jour (
    id_suivi            INT             AUTO_INCREMENT PRIMARY KEY,
    id_appareil         INT             NOT NULL,
    date_jour           DATE            NOT NULL,
    duree_utilisation_h DECIMAL(4,2)    CHECK (duree_utilisation_h >= 0),
    iah_residuel        DECIMAL(5,2)    CHECK (iah_residuel >= 0),
    fuites_l_min        DECIMAL(6,2)    CHECK (fuites_l_min >= 0),
    nb_evenements       INT             CHECK (nb_evenements >= 0),
    qualite_donnee      VARCHAR(20)     NOT NULL DEFAULT 'bonne'
                        CHECK (qualite_donnee IN ('bonne','dégradée','manquante')),

    UNIQUE (id_appareil, date_jour)
);

/* ============================================================
   13) BILAN MENSUEL CPAP
       Agrégat mensuel pour analytique & IA
   ============================================================ */
CREATE TABLE bilan_mensuel_cpap (
    id_bilan                INT             AUTO_INCREMENT PRIMARY KEY,
    id_appareil             INT             NOT NULL,
    annee                   INT             NOT NULL CHECK (annee >= 2000),
    mois                    INT             NOT NULL CHECK (mois BETWEEN 1 AND 12),
    duree_moy_h             DECIMAL(4,2),
    compliance_pct          DECIMAL(5,2)    CHECK (compliance_pct BETWEEN 0 AND 100),
    iah_residuel_moy        DECIMAL(5,2),
    fuites_moy              DECIMAL(6,2),
    nb_jours_utilises       INT             CHECK (nb_jours_utilises >= 0),
    nb_jours_non_utilises   INT             CHECK (nb_jours_non_utilises >= 0),

    UNIQUE (id_appareil, annee, mois)
);

/* ============================================================
   CONTRAINTES FK — ajoutées en fin de script
   (évite les problèmes d'ordre de création)
   ============================================================ */

-- suivi_patient
ALTER TABLE suivi_patient
    ADD CONSTRAINT fk_suivi_patient_patient
        FOREIGN KEY (id_patient) REFERENCES patient(id_patient),
    ADD CONSTRAINT fk_suivi_patient_medecin
        FOREIGN KEY (id_medecin) REFERENCES medecin(id_personnel);

-- deces_patient
ALTER TABLE deces_patient
    ADD CONSTRAINT fk_deces_patient
        FOREIGN KEY (id_patient) REFERENCES patient(id_patient);

-- patient_comorbidite
ALTER TABLE patient_comorbidite
    ADD CONSTRAINT fk_pc_patient
        FOREIGN KEY (id_patient) REFERENCES patient(id_patient),
    ADD CONSTRAINT fk_pc_comorbidite
        FOREIGN KEY (id_comorbidite) REFERENCES comorbidite(id_comorbidite);

-- medecin
ALTER TABLE medecin
    ADD CONSTRAINT fk_medecin_personnel
        FOREIGN KEY (id_personnel) REFERENCES personnel(id_personnel);

-- infirmiere
ALTER TABLE infirmiere
    ADD CONSTRAINT fk_infirmiere_personnel
        FOREIGN KEY (id_personnel) REFERENCES personnel(id_personnel);

-- appareil_psg
ALTER TABLE appareil_psg
    ADD CONSTRAINT fk_appareil_psg
        FOREIGN KEY (id_appareil) REFERENCES appareil(id_appareil);

-- appareil_cpap
ALTER TABLE appareil_cpap
    ADD CONSTRAINT fk_appareil_cpap
        FOREIGN KEY (id_appareil) REFERENCES appareil(id_appareil),
    ADD CONSTRAINT fk_cpap_patient
        FOREIGN KEY (id_patient) REFERENCES patient(id_patient);

-- consultation
ALTER TABLE consultation
    ADD CONSTRAINT fk_consul_patient
        FOREIGN KEY (id_patient) REFERENCES patient(id_patient),
    ADD CONSTRAINT fk_consul_medecin
        FOREIGN KEY (id_medecin) REFERENCES medecin(id_personnel);

-- nuit_etude
ALTER TABLE nuit_etude
    ADD CONSTRAINT fk_nuit_patient
        FOREIGN KEY (id_patient) REFERENCES patient(id_patient),
    ADD CONSTRAINT fk_nuit_superviseur
        FOREIGN KEY (id_superviseur) REFERENCES infirmiere(id_personnel),
    ADD CONSTRAINT fk_nuit_medecin
        FOREIGN KEY (id_medecin) REFERENCES medecin(id_personnel),
    ADD CONSTRAINT fk_nuit_appareil_psg
        FOREIGN KEY (id_appareil_psg) REFERENCES appareil_psg(id_appareil);

-- prescription_nuit
ALTER TABLE prescription_nuit
    ADD CONSTRAINT fk_prescription_consul
        FOREIGN KEY (id_consultation) REFERENCES consultation(id_consultation),
    ADD CONSTRAINT fk_prescription_nuit
        FOREIGN KEY (id_nuit) REFERENCES nuit_etude(id_nuit);

-- resultat_nuit
ALTER TABLE resultat_nuit
    ADD CONSTRAINT fk_resultat_nuit
        FOREIGN KEY (id_nuit) REFERENCES nuit_etude(id_nuit),
    ADD CONSTRAINT fk_resultat_medecin
        FOREIGN KEY (id_medecin_validateur) REFERENCES medecin(id_personnel);

-- evenement_respiratoire
ALTER TABLE evenement_respiratoire
    ADD CONSTRAINT fk_evenement_nuit
        FOREIGN KEY (id_nuit) REFERENCES nuit_etude(id_nuit);

-- suivi_cpap_jour
ALTER TABLE suivi_cpap_jour
    ADD CONSTRAINT fk_suivi_cpap_appareil
        FOREIGN KEY (id_appareil) REFERENCES appareil_cpap(id_appareil);

-- bilan_mensuel_cpap
ALTER TABLE bilan_mensuel_cpap
    ADD CONSTRAINT fk_bilan_appareil
        FOREIGN KEY (id_appareil) REFERENCES appareil_cpap(id_appareil);

/* ============================================================
   INDEX UTILES POUR LES REQUÊTES ANALYTIQUES ET IA
   ============================================================ */
CREATE INDEX idx_suivi_cpap_date       ON suivi_cpap_jour(date_jour);
CREATE INDEX idx_suivi_cpap_appareil   ON suivi_cpap_jour(id_appareil, date_jour);
CREATE INDEX idx_evenement_nuit        ON evenement_respiratoire(id_nuit);
CREATE INDEX idx_evenement_type        ON evenement_respiratoire(type_evenement);
CREATE INDEX idx_nuit_patient          ON nuit_etude(id_patient, date_nuit);
CREATE INDEX idx_resultat_iah          ON resultat_nuit(iah);
CREATE INDEX idx_consul_patient        ON consultation(id_patient, date_consultation);
CREATE INDEX idx_bilan_appareil_date   ON bilan_mensuel_cpap(id_appareil, annee, mois);