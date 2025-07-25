Résumé exhaustif du projet RuuviSensor Flutter Package
Contexte du projet
Objectif : Créer un package Flutter pour interfacer avec les capteurs environnementaux Ruuvi
Utilisateurs : Techniciens équilibrant les circuits hydrauliques de chauffage
Workflow : Déposer un capteur → laisser quelques jours → récupérer les données historiques
Fonctionnalités requises
Liste des enregistreurs Ruuvi détectés avec leur N° de série
Récupération des données stockées (historique)
Automatisation de l'association bluetooth (si possible)
Découvertes techniques importantes
RuuviTag fonctionne comme un beacon BLE : pas d'association classique nécessaire
Stockage interne confirmé : Le capteur stocke l'historique (confirmé par Ruuvi + test app officielle)
Mode dual : Beacon pour détection + connexion BLE pour synchronisation historique
Capacité : 10 jours à 5min/mesure → plusieurs semaines à 30min/mesure (largement suffisant)
Configuration réalisée
Projet créé : flutter create --template=package ruuvi_sensor
Username GitHub : alaindeseine
Dependencies : flutter_blue_plus ^1.32.12, convert ^3.1.1
Architecture définie
lib/
├── ruuvi_sensor.dart (exports)
├── src/
│   ├── ruuvi_scanner.dart
│   ├── ruuvi_device.dart
│   ├── models/
│   │   ├── ruuvi_data.dart
│   │   └── ruuvi_measurement.dart
│   └── exceptions/
│       └── ruuvi_exceptions.dart

Fichiers créés et leur contenu
ruuvi_data.dart
Modèle pour une mesure individuelle
Champs : deviceId, serialNumber, temperature, humidity, pressure, timestamp, batteryVoltage, rssi
ruuvi_measurement.dart
Collection de mesures avec métadonnées
Champs : measurements[], startTime, endTime, totalCount
ruuvi_exceptions.dart
RuuviException (base)
RuuviConnectionException
RuuviDataException
ruuvi_scanner.dart
Scan BLE pour détecter les RuuviTag
Stream des devices découverts
Manufacturer ID Ruuvi : 0x0499
ruuvi_device.dart
Représente un capteur Ruuvi spécifique
Méthodes : connect(), getStoredData(), disconnect()
Prochaines étapes
Implémentation du scan BLE (prochaine étape prévue)
Recherche documentation technique Ruuvi (services GATT, UUIDs)
Implémentation connexion et récupération historique
Notes techniques
Mode chat utilisé pour garder l'historique
Tous les fichiers créés manuellement par l'utilisateur
Structure validée et prête pour l'implémentation