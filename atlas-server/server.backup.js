
const express = require("express");
const cors = require("cors");
const fs = require("fs");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;

const OLLAMA_URL = "http://127.0.0.1:11434";
const MODEL = "qwen2.5:1.5b";

// Fichier de mémoire persistante
const MEMORY_FILE = path.join(__dirname, "atlas-memory.json");
const MAX_HISTORY_MESSAGES = 8;

// Personnalité d'ATLAS
const ATLAS_INSTRUCTIONS = `
Tu es ATLAS, l'assistant personnel intelligent d'André.

TON IDENTITÉ :
Tu es chaleureux, naturel, attentif et serviable.

TA FAÇON DE PARLER :
- Tu réponds principalement en français.
- Tu utilises un langage naturel et accessible.
- Tu donnes des explications simples et précises.
- Tu évites les réponses inutilement longues.

TON ACCOMPAGNEMENT :
- Tu aides André dans ses études et ses projets informatiques.
- Tu expliques les difficultés étape par étape.
- Tu proposes des exemples pratiques.

CULTURE ET LANGAGE :
- Tu essaies de comprendre les expressions camerounaises.
- Si tu ne comprends pas une expression, tu demandes sa signification.
- Tu ne prétends pas connaître une expression dont tu ignores le sens.

TA MÉMOIRE :
- Tu utilises les informations présentes dans la conversation.
- Tu tiens compte des préférences communiquées par André.
- Tu ne prétends pas te souvenir d'informations absentes de ta mémoire.

TES PRINCIPES :
- Tu privilégies les réponses exactes et utiles.
- Tu reconnais tes erreurs.
- Tu ne fabriques pas de faits.
- Tu respectes la confidentialité des informations d'André.
`;

// Charger la mémoire au démarrage
function loadMemory() {
  try {
    if (!fs.existsSync(MEMORY_FILE)) {
      fs.writeFileSync(MEMORY_FILE, "[]", "utf8");
      return [];
    }

    const content = fs.readFileSync(MEMORY_FILE, "utf8")
      .replace(/^\uFEFF/, "");

    const history = JSON.parse(content);

    if (!Array.isArray(history)) {
      throw new Error("Format de mémoire invalide.");
    }

    return history
      .filter(item =>
        item &&
        ["user", "assistant"].includes(item.role) &&
        typeof item.content === "string"
      )
      .slice(-MAX_HISTORY_MESSAGES);

  } catch (error) {
    console.error("Erreur de lecture mémoire :", error.message);
    return [];
  }
}

// Sauvegarder la mémoire sur le disque
function saveMemory() {
  fs.writeFileSync(
    MEMORY_FILE,
    JSON.stringify(conversationHistory, null, 2),
    "utf8"
  );
}

// Mémoire chargée depuis le fichier JSON
let conversationHistory = loadMemory();

app.use(cors());
app.use(express.json());

// Vérifier le serveur et sa mémoire
app.get("/", (req, res) => {
  res.json({
    message: "ATLAS est en ligne !",
    status: "OK",
    model: MODEL,
    memory: "Active",
    savedMessages: conversationHistory.length
  });
});

// Envoyer un message à ATLAS
app.post("/chat", async (req, res) => {
  try {
    const { message } = req.body;

    if (
      !message ||
      typeof message !== "string" ||
      !message.trim()
    ) {
      return res.status(400).json({
        error: "Le message est vide ou invalide."
      });
    }

    const userMessage = {
      role: "user",
      content: message.trim()
    };

    const response = await fetch(
      `${OLLAMA_URL}/api/chat`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          model: MODEL,
          messages: [
            {
              role: "system",
              content: ATLAS_INSTRUCTIONS
            },
            ...conversationHistory,
            userMessage
          ],
          stream: false,
          keep_alive: "30m",
          options: {
            num_ctx: 1024,
            num_predict: 128,
            num_gpu: 8
          }
        })
      }
    );

    if (!response.ok) {
      const details = await response.text();
      console.error("Erreur Ollama :", details);

      return res.status(502).json({
        error: "Ollama n'a pas pu répondre."
      });
    }

    const data = await response.json();
    const reply = data.message?.content;

    if (!reply) {
      throw new Error("Réponse vide d'Ollama.");
    }

    // Ajouter les deux messages à la mémoire
    conversationHistory.push(userMessage);

    conversationHistory.push({
      role: "assistant",
      content: reply
    });

    // Garder uniquement les 8 derniers messages
    conversationHistory = conversationHistory.slice(
      -MAX_HISTORY_MESSAGES
    );

    // Enregistrer les messages dans atlas-memory.json
    try {
      saveMemory();
    } catch (memoryError) {
      console.error(
        "Erreur de sauvegarde mémoire :",
        memoryError.message
      );
    }

    res.json({
      reply: reply,
      model: MODEL,
      memory: "Active"
    });

  } catch (error) {
    console.error("ERREUR ATLAS :", error.message);

    res.status(500).json({
      error: "Impossible d'obtenir une réponse d'ATLAS."
    });
  }
});

// Effacer la mémoire conversationnelle
app.post("/reset", (req, res) => {
  try {
    conversationHistory = [];
    saveMemory();

    res.json({
      message: "Mémoire d'ATLAS effacée."
    });

  } catch (error) {
    console.error("Erreur de réinitialisation :", error.message);

    res.status(500).json({
      error: "Impossible d'effacer la mémoire."
    });
  }
});

// Démarrer le serveur
app.listen(PORT, "0.0.0.0", () => {
  console.log("================================");
  console.log("       ATLAS EST DEMARRE");
  console.log("================================");
  console.log(`Serveur : http://localhost:${PORT}`);
  console.log(`IA locale : ${MODEL}`);
  console.log("Mémoire persistante : ACTIVE");
  console.log(`Messages récupérés : ${conversationHistory.length}`);
  console.log("GPU demandé : 8 couches");
  console.log("================================");
});
