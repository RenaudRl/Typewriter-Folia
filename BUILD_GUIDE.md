# Typewriter-Folia Build Guide

## Pré-requis

1. **Java 21** installé et accessible via `JAVA_HOME`
2. **Flutter SDK** (optionnel, pour le panneau web)
3. **Au moins 8 Go de RAM** disponibles

Pour éviter les erreurs de mémoire, configurez Gradle:
```powershell
setx GRADLE_OPTS "-Xmx4g -XX:MaxMetaspaceSize=1024m"
```

---

## 🎯 BUILD RELEASE COMPLET

**Script automatique qui génère un dossier `release/` complet:**

```powershell
cd D:\GitHub\Typewriter-Folia
.\release-build.ps1
```

Le script:
1. Nettoie les sorties précédentes
2. Compile `module-plugin`
3. Reconstruit l'application Flutter (si disponible)
4. Génère le JAR de l'engine avec les assets web (`buildRelease`)
5. Compile toutes les extensions (`buildReleaseAll`)
6. Copie tous les artefacts dans `release/`

**Structure finale:**
```
release/
  engine/Typewriter-<version>.jar
  extensions/*.jar
  module-plugin/*.jar
  web/** (panneau Flutter)
  version.txt
```

---

## Commandes Manuelles

### 1. Module Plugin
```powershell
cd module-plugin
.\gradlew.bat clean build -x test
```

### 2. Application Flutter (optionnel)
```powershell
cd app
flutter clean
flutter pub get  
flutter build web
```

### 3. Engine avec panneau web
```powershell
cd engine
.\gradlew.bat clean :engine-paper:buildRelease -x test
```

### 4. Toutes les extensions
```powershell
cd extensions
.\gradlew.bat clean buildReleaseAll -x test
```

---

## Commandes de Build Individuelles

### Build du Module Engine
```powershell
cd engine
.\gradlew.bat :engine-paper:build -x test
.\gradlew.bat :engine-paper:shadowJar -x test    # Fat JAR sans web
.\gradlew.bat :engine-paper:buildRelease -x test # Avec panneau web
.\gradlew.bat :engine-paper:buildAndMove -x test # Copie vers server/plugins
```

### Build des Extensions
```powershell
cd extensions
.\gradlew.bat build -x test                        # Toutes
.\gradlew.bat buildReleaseAll -x test              # Toutes vers jars/extensions/
.\gradlew.bat :RoadNetworkExtension:buildRelease   # Une seule
```

---

## 📍 Emplacement des JARs

| Module | Chemin du JAR |
|--------|---------------|
| Engine (buildRelease) | `jars/engine/Typewriter-*.jar` |
| Extensions (buildRelease) | `jars/extensions/*.jar` |
| Engine (shadowJar) | `engine/engine-paper/build/libs/*-all.jar` |
| Extensions (build) | `extensions/*/build/libs/*.jar` |

---

## 🧹 Nettoyage

```powershell
# Nettoyer tout
Remove-Item .\release -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item .\jars -Recurse -Force -ErrorAction SilentlyContinue

# Nettoyer les builds
cd engine; .\gradlew.bat clean; cd ..\extensions; .\gradlew.bat clean; cd ..
```

---

## 📝 Notes Importantes

1. **Ordre de build**: `module-plugin` → Flutter (optionnel) → `engine` → `extensions`
2. **buildRelease vs shadowJar**: `buildRelease` inclut le panneau Flutter, `shadowJar` non
3. **buildReleaseAll**: Compile toutes les extensions et les copie vers `jars/extensions/`
