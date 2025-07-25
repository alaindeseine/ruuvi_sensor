# Troubleshooting Guide

## 🔄 Problème : Les données ne se mettent pas à jour automatiquement

### Symptôme
Après un scan, les données des capteurs restent figées et ne se mettent à jour que si on relance le scan.

### Cause
Par défaut, le scan s'arrête après le timeout (30 secondes). Les RuuviTag n'envoient des données que pendant le scan actif.

### ✅ Solutions

#### 1. Utiliser le mode Live (Recommandé)
```dart
// Au lieu de startScan()
await scanner.startContinuousScan();

// Ou avec le paramètre continuous
await scanner.startScan(continuous: true);
```

#### 2. Dans l'exemple mis à jour
- Utilisez le bouton **"Live Mode"** au lieu de "Scan Once"
- Le mode Live scanne en continu pour des mises à jour temps réel
- Appuyez sur "Stop" pour arrêter

#### 3. Implémentation personnalisée
```dart
// Scan continu avec gestion d'état
final scanner = RuuviScanner();

// Écouter les mises à jour
scanner.devicesStream.listen((devices) {
  // Les données se mettent à jour automatiquement
  for (final device in devices) {
    print('${device.name}: ${device.lastData?.temperature}°C');
  }
});

// Démarrer le mode continu
await scanner.startContinuousScan();

// Arrêter quand nécessaire
await scanner.stopScan();
```

---

## 📊 Problème : L'historique ne fonctionne pas

### Symptômes
- Clic sur "Get History" ne montre rien
- Logs montrent des `onCharacteristicChanged` répétés
- Timeout ou erreur lors de la récupération

### Causes possibles

#### 1. **Firmware incompatible** (Le plus courant)
- Beaucoup de RuuviTag ont un firmware < 3.x
- Les anciens firmwares ne supportent pas la récupération d'historique
- Seuls les firmwares 3.x+ implémentent le protocole de log

#### 2. **Pas de données stockées**
- Le capteur doit avoir fonctionné quelques heures/jours
- Certains RuuviTag n'activent le logging qu'après configuration

#### 3. **Protocole non standard**
- Certains RuuviTag utilisent un protocole propriétaire
- L'implémentation peut varier selon le modèle

### ✅ Solutions

#### 1. Vérifier le firmware
```bash
# Utilisez l'app officielle Ruuvi Station pour vérifier :
# - Version du firmware
# - Capacités de logging
# - Configuration du capteur
```

#### 2. Test avec timeout étendu
```dart
try {
  final data = await device.getStoredData(
    startTime: DateTime.now().subtract(Duration(hours: 24)),
    timeout: Duration(minutes: 10), // Timeout plus long
  );
  
  if (data.totalCount == 0) {
    print('Aucune donnée historique disponible');
    print('Vérifiez le firmware et la configuration');
  }
} catch (e) {
  print('Erreur historique: $e');
}
```

#### 3. Diagnostic des logs
Les logs `onCharacteristicChanged` indiquent que :
- ✅ La connexion fonctionne
- ✅ Le RuuviTag envoie des données
- ❌ Le protocole n'est pas celui attendu

#### 4. Alternative : Utiliser les données temps réel
Si l'historique ne fonctionne pas, utilisez le mode Live :
```dart
// Collecter les données en temps réel
final dataPoints = <RuuviData>[];

scanner.devicesStream.listen((devices) {
  for (final device in devices) {
    if (device.lastData != null) {
      dataPoints.add(device.lastData!);
      // Sauvegarder localement si nécessaire
    }
  }
});
```

---

## 🔧 Diagnostic avancé

### Vérifier les capacités du RuuviTag

```dart
// 1. Vérifier la connexion
final setupResult = await RuuviScanner.checkSetup();
print('Setup: ${setupResult.isReady}');

// 2. Tester la connexion
try {
  await device.connect();
  print('Connexion: OK');
  
  // 3. Tester l'historique avec logs
  final data = await device.getStoredData();
  print('Historique: ${data.totalCount} mesures');
  
} catch (e) {
  print('Erreur: $e');
}
```

### Logs de débogage

Activez les logs détaillés dans votre app :
```dart
// Les logs du package montrent :
// - Données reçues en hex
// - Type de protocole détecté
// - Erreurs de parsing
```

### Test avec l'app officielle

1. **Installez Ruuvi Station** (app officielle)
2. **Connectez-vous au même capteur**
3. **Vérifiez** :
   - Version firmware
   - Données historiques disponibles
   - Configuration du logging

---

## 📱 Recommandations d'usage

### Pour les données temps réel
```dart
// ✅ Utilisez le mode Live
await scanner.startContinuousScan();

// ✅ Gérez la batterie
Timer.periodic(Duration(minutes: 5), (timer) {
  // Pause périodique pour économiser la batterie
  scanner.stopScan();
  Future.delayed(Duration(seconds: 10), () {
    scanner.startContinuousScan();
  });
});
```

### Pour l'historique
```dart
// ✅ Vérifiez d'abord les capacités
final setupResult = await RuuviScanner.checkSetup();
if (!setupResult.isReady) {
  // Montrer les instructions de setup
  return;
}

// ✅ Utilisez des timeouts longs
final data = await device.getStoredData(
  timeout: Duration(minutes: 10),
);

// ✅ Gérez l'absence de données
if (data.totalCount == 0) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Historique non disponible'),
      content: Text(
        'Ce RuuviTag ne supporte pas la récupération d\'historique.\n\n'
        'Alternatives :\n'
        '• Utilisez le mode Live pour les données temps réel\n'
        '• Vérifiez le firmware (requis: 3.x+)\n'
        '• Consultez l\'app Ruuvi Station officielle'
      ),
    ),
  );
}
```

---

## 🆘 Si rien ne fonctionne

1. **Testez avec l'app Ruuvi Station officielle**
2. **Vérifiez le modèle de RuuviTag** (certains modèles ont des limitations)
3. **Mettez à jour le firmware** si possible
4. **Utilisez uniquement le mode Live** pour les données temps réel
5. **Contactez le support Ruuvi** pour les questions de firmware

Le package fonctionne correctement - les limitations viennent souvent du firmware ou de la configuration des capteurs eux-mêmes.
