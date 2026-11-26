# chatbot_personnel

# Atlas

Assistant personnel intelligent : une application de bureau Flutter connectée à un serveur Node.js et à l'IA Gemini de Google.

## Fonctionnalités

- Discussion avec une IA (Gemini)
- Analyse de documents : PDF, Word (.docx) et images (OCR)
- Reconnaissance vocale (dictée)
- Envoi de fichiers au serveur pour traitement
- (à vérifier / compléter : mémoire des conversations, synthèse vocale, autres fonctions)

## Technologies

| Partie | Technologies |
|---|---|
| Application | Flutter, Dart (Windows) |
| Serveur | Node.js, Express, Multer, CORS |
| IA | API Google Gemini (`@google/genai`) |
| Traitement de documents | pdf-parse, mammoth, Tesseract.js |
| Voix | speech_to_text |

## Architecture

```
Application Flutter  <-->  Serveur Node.js (atlas-server)  <-->  API Gemini
```

L'application envoie les messages et les fichiers au serveur, qui les traite puis interroge l'IA et renvoie la réponse.

## Installation

### Prérequis
- Flutter SDK
- Node.js
- Une clé API Gemini : https://aistudio.google.com/apikey

### 1. Cloner le projet
```bash
git clone https://github.com/chevalierandre233-cm/Atlas.git
cd Atlas
```

### 2. Lancer le serveur
```bash
cd atlas-server
npm install
```
Créez un fichier `.env` dans `atlas-server` :
```
GEMINI_API_KEY=votre_cle_ici
```
Puis lancez le serveur (à vérifier : nom du fichier d'entrée) :
```bash
node server.js
```

### 3. Lancer l'application
```bash
flutter pub get
flutter run -d windows
```

## Captures d'écran

(ajoutez ici 2 ou 3 images : ![Accueil](docs/accueil.png))

## Auteur

André Chevalier (https://github.com/chevalierandre233-cm)

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
