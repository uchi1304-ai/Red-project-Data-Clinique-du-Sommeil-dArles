
-- Niveau 1 : Requêtes simples

-- 1. Nombre de patients
SELECT 
    COUNT(*) AS nombre_patients
FROM patient;


-- 2. Âge moyen des patients
SELECT 
    AVG(TIMESTAMPDIFF(YEAR, patient.date_naissance, CURDATE())) AS age_moyen
FROM patient;


-- 3. IMC moyen des patients
SELECT 
    AVG(patient.imc_initial) AS imc_moyen
FROM patient;


-- 4. Nombre de patients actifs / non actifs
SELECT 
    patient.actif,
    COUNT(*) AS nombre_patients
FROM patient
GROUP BY patient.actif;


-- 5. Nombre de patients fumeurs / non fumeurs
SELECT 
    patient.fumeur,
    COUNT(*) AS nombre_patients
FROM patient
GROUP BY patient.fumeur;


-- 6. Nombre total de consultations
SELECT 
    COUNT(*) AS nombre_consultations
FROM consultation;


-- 7. Nombre de consultations par patient
SELECT
    patient.id_patient,
    patient.nom,
    patient.prenom,
    COUNT(consultation.id_consultation) AS nombre_consultations
FROM patient 
LEFT JOIN consultation 
    ON patient.id_patient = consultation.id_patient
GROUP BY patient.id_patient, patient.nom, patient.prenom
ORDER BY nombre_consultations DESC;


-- 8. Nombre de nuits d'étude
SELECT 
    COUNT(*) AS nombre_nuits_etude
FROM nuit_etude;



-- Niveau 2 : Questions métier
-- 09. Comorbidités les plus fréquentes
SELECT
    comorbidite.libelle,
    COUNT(patient_comorbidite.id_patient) AS nombre_patients
FROM patient_comorbidite
JOIN comorbidite
    ON patient_comorbidite.id_comorbidite = comorbidite.id_comorbidite
GROUP BY comorbidite.libelle
ORDER BY nombre_patients DESC;


-- 10. Patients avec la moins bonne compliance CPAP
SELECT
    patient.nom,
    patient.prenom,
    bilan_mensuel_cpap.compliance_pct
FROM patient
JOIN appareil_cpap
    ON patient.id_patient = appareil_cpap.id_patient
JOIN bilan_mensuel_cpap
    ON appareil_cpap.id_appareil = bilan_mensuel_cpap.id_appareil
ORDER BY bilan_mensuel_cpap.compliance_pct ASC;


-- 11. Parcours patient
SELECT
    patient.nom,
    patient.prenom,
    consultation.date_consultation,
    prescription_nuit.id_prescription,
    nuit_etude.date_nuit,
    resultat_nuit.iah,
    suivi_patient.date_suivi,
    suivi_patient.statut_patient
FROM patient
LEFT JOIN consultation
    ON patient.id_patient = consultation.id_patient
LEFT JOIN prescription_nuit
    ON consultation.id_consultation = prescription_nuit.id_consultation
LEFT JOIN nuit_etude
    ON prescription_nuit.id_nuit = nuit_etude.id_nuit
LEFT JOIN resultat_nuit
    ON nuit_etude.id_nuit = resultat_nuit.id_nuit
LEFT JOIN suivi_patient
    ON patient.id_patient = suivi_patient.id_patient;
