const express = require("express");
const cors = require("cors");
const fs = require("fs");
const path = require("path");
const { randomUUID } = require("crypto");
const multer = require("multer");
const pdfParse = require("pdf-parse");
const mammoth = require("mammoth");
const { createWorker } = require("tesseract.js");

const app = express();
app.use(cors());
app.use(express.json({ limit: "1mb" }));

// Pièces jointes : stockage en mémoire, sans créer de fichiers temporaires.
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 12 * 1024 * 1024, files: 5 },
  fileFilter: (req, file, callback) => {
    const allowed = /\.(pdf|docx|doc|txt|png|jpe?g|webp)$/i.test(file.originalname);
    callback(allowed ? null : new Error("Format non pris en charge."), allowed);
  }
});

let ocrWorkerPromise;
async function extractAttachmentText(file) {
  const name = file.originalname || "fichier";
  const ext = path.extname(name).toLowerCase();
  let extracted = "";

  if (ext === ".txt") {
    extracted = file.buffer.toString("utf8");
  } else if (ext === ".pdf") {
    const parsed = await pdfParse(file.buffer);
    extracted = parsed.text || "";
  } else if (ext === ".docx") {
    const result = await mammoth.extractRawText({ buffer: file.buffer });
    extracted = result.value || "";
  } else if ([".png", ".jpg", ".jpeg", ".webp"].includes(ext)) {
    if (!ocrWorkerPromise) ocrWorkerPromise = createWorker("fra+eng");
    const worker = await ocrWorkerPromise;
    const result = await worker.recognize(file.buffer);
    extracted = result.data.text || "";
  } else if (ext === ".doc") {
    throw new Error(`Le format .doc ancien n'est pas pris en charge pour « ${name} ». Enregistre-le en .docx.`);
  }

  const clean = String(extracted).trim().slice(0, 30000);
  return `Fichier : ${name}\n${clean || "Aucun texte exploitable n'a été détecté."}`;
}

async function buildAttachmentContext(files) {
  if (!files || files.length === 0) return "";
  const sections = await Promise.all(files.map(extractAttachmentText));
  const combined = sections.join("\n\n---\n\n");
  const maxChars = 5000; // Évite de saturer le contexte du modèle 1.5B.
  const clipped = combined.length > maxChars
    ? combined.slice(0, maxChars) + "\n\n[Contenu raccourci pour respecter la limite de contexte d'ATLAS.]"
    : combined;
  return "\n\n[CONTENU DES PIÈCES JOINTES]\n" + clipped;
}

const PORT = 3000;
const OLLAMA_URL = "http://127.0.0.1:11434/api/chat";
const MODEL = "qwen2.5:1.5b";

const MEMORY_FILE = path.join(__dirname, "atlas-memory.json");
const FACTS_FILE = path.join(__dirname, "atlas-facts.json");
const CONVERSATIONS_FILE = path.join(__dirname, "atlas-conversations.json");

const MAX_HISTORY_MESSAGES = 8;
const MAX_PERSONAL_FACTS = 30;
const MAX_CONVERSATIONS = 100;

function initializeFile(file, defaultData) {
  if (!fs.existsSync(file)) {
    fs.writeFileSync(file, JSON.stringify(defaultData, null, 2), "utf8");
  }
}

function readJSON(file, defaultData) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (error) {
    console.error("Erreur de lecture :", file, error.message);
    return defaultData;
  }
}

function saveJSON(file, data) {
  fs.writeFileSync(file, JSON.stringify(data, null, 2), "utf8");
}

initializeFile(MEMORY_FILE, { messages: [] });
initializeFile(FACTS_FILE, { facts: [] });
initializeFile(CONVERSATIONS_FILE, { conversations: [] });

function getFacts() {
  const data = readJSON(FACTS_FILE, { facts: [] });
  return Array.isArray(data.facts) ? data.facts : [];
}

function saveFact(content) {
  const facts = getFacts();

  if (facts.length >= MAX_PERSONAL_FACTS) {
    return { success: false, message: "La mémoire personnelle est pleine." };
  }

  const normalized = content.trim().toLowerCase();
  if (facts.some((fact) => fact.content.trim().toLowerCase() === normalized)) {
    return { success: false, message: "Cette information est déjà enregistrée." };
  }

  facts.push({
    id: randomUUID(),
    content: content.trim(),
    createdAt: new Date().toISOString()
  });

  saveJSON(FACTS_FILE, { facts });
  return { success: true, message: "Souvenir enregistré." };
}

const ATLAS_INSTRUCTIONS = `
Tu es ATLAS, un assistant personnel intelligent.
- Tu parles principalement en français.
- Tu es chaleureux, naturel, patient et pédagogique.
- Tu donnes des réponses claires et utiles.
- Tu expliques les choses simplement.
- Tu peux comprendre progressivement l'argot camerounais.
- Si tu ne comprends pas une expression, tu poses une question.
- Tu ne prétends jamais connaître une information que tu ignores.
- Tu tiens compte des souvenirs personnels fournis dans le contexte.
- Tu ne prétends jamais avoir enregistré ou supprimé un souvenir
  si le système ne l'a pas réellement fait.
`;

function getConversations() {
  const data = readJSON(CONVERSATIONS_FILE, { conversations: [] });
  return Array.isArray(data.conversations) ? data.conversations : [];
}

function saveConversations(conversations) {
  saveJSON(CONVERSATIONS_FILE, { conversations });
}

function findConversation(id) {
  return getConversations().find((conversation) => conversation.id === id);
}

function createConversation() {
  const conversations = getConversations();

  if (conversations.length >= MAX_CONVERSATIONS) {
    throw new Error("La limite de conversations est atteinte.");
  }

  const now = new Date().toISOString();
  const conversation = {
    id: randomUUID(),
    title: "Nouvelle conversation",
    createdAt: now,
    updatedAt: now,
    messages: []
  };

  conversations.unshift(conversation);
  saveConversations(conversations);
  return conversation;
}

// Migration de l'ancien historique vers une première conversation.
// Le fichier atlas-memory.json n'est pas supprimé.
(function migrateLegacyHistory() {
  const conversations = getConversations();
  if (conversations.length > 0) return;

  const legacy = readJSON(MEMORY_FILE, { messages: [] });
  const oldMessages = Array.isArray(legacy)
    ? legacy
    : (Array.isArray(legacy.messages) ? legacy.messages : []);

  if (oldMessages.length === 0) return;

  const now = new Date().toISOString();
  const migrated = {
    id: randomUUID(),
    title: "Ancienne conversation",
    createdAt: now,
    updatedAt: now,
    messages: oldMessages.map((message) => ({
      id: randomUUID(),
      role: message.role === "assistant" ? "atlas" : "user",
      content: String(message.content || ""),
      createdAt: now
    }))
  };

  saveConversations([migrated]);
  console.log("Ancien historique importé dans atlas-conversations.json");
})();

// Les confirmations sont isolées par conversation.
const pendingActions = new Map();

function detectMemoryCommand(message) {
  const text = message.trim();

  const rememberMatch = text.match(
    /^(?:atlas[,\s]*)?(?:retiens|mémorise|memorise|souviens-toi)\s+(?:bien\s+)?(?:que\s+)?(.+)[.!?]*$/i
  );

  if (rememberMatch && rememberMatch[1]) {
    return { type: "remember", content: rememberMatch[1].trim() };
  }

  const forgetMatch = text.match(
    /^(?:atlas[,\s]*)?(?:oublie|efface|supprime)\s+(?:que\s+)?(.+)[.!?]*$/i
  );

  if (forgetMatch && forgetMatch[1]) {
    return { type: "forget", content: forgetMatch[1].trim() };
  }

  return null;
}

function isConfirmation(message) {
  return /^(oui|oui oui|je confirme|confirme|vas-y|enregistre|d'accord|ok|okay|yes)$/i
    .test(message.trim());
}

function isRejection(message) {
  return /^(non|non non|annule|annuler|ne fais pas ça|laisse tomber)$/i
    .test(message.trim());
}

function makeConversationTitle(text) {
  const clean = text.replace(/\s+/g, " ").trim();
  return clean.length > 38 ? `${clean.slice(0, 35)}...` : clean;
}

function addConversationMessage(conversationId, role, content) {
  const conversations = getConversations();
  const index = conversations.findIndex((item) => item.id === conversationId);
  if (index === -1) return;

  const conversation = conversations[index];

  conversation.messages.push({
    id: randomUUID(),
    role,
    content,
    createdAt: new Date().toISOString()
  });

  if (role === "user" && conversation.title === "Nouvelle conversation") {
    conversation.title = makeConversationTitle(content);
  }

  // L'historique envoyé au modèle reste limité aux derniers messages,
  // mais la conversation complète demeure enregistrée sur le disque.
  conversation.updatedAt = new Date().toISOString();
  saveConversations(conversations);
}

function updateConversationAfterAssistant(conversationId, content) {
  addConversationMessage(conversationId, "atlas", content);
}

function getRecentModelMessages(conversation) {
  return conversation.messages.slice(-MAX_HISTORY_MESSAGES).map((message) => ({
    role: message.role === "atlas" ? "assistant" : "user",
    content: message.content
  }));
}

function buildSystemPrompt() {
  const facts = getFacts();
  const factsText = facts.length
    ? facts.map((fact) => `- ${fact.content}`).join("\n")
    : "Aucun souvenir personnel enregistré.";

  return `${ATLAS_INSTRUCTIONS}

Voici les souvenirs personnels de l'utilisateur :
${factsText}

Utilise ces informations uniquement lorsqu'elles sont pertinentes.`;
}

function sendText(res, text) {
  res.status(200);
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.setHeader("Cache-Control", "no-cache, no-transform");
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("Transfer-Encoding", "chunked");
  res.flushHeaders();
  res.write(text);
  res.end();
}

async function handleChat(req, res, streaming) {
  let responseStarted = false;

  try {
    const { message = "", conversationId } = req.body;
    const attachedFiles = req.files || [];

    if ((typeof message !== "string" || !message.trim()) && attachedFiles.length === 0) {
      return res.status(400).json({ error: "Écris un message ou joins un fichier." });
    }

    if (typeof conversationId !== "string" || !conversationId.trim()) {
      return res.status(400).json({ error: "Identifiant de conversation manquant." });
    }

    const attachmentContext = await buildAttachmentContext(attachedFiles);
    const typedMessage = typeof message === "string" ? message.trim() : "";
    const userMessage = [typedMessage, attachmentContext].filter(Boolean).join("\n\n");
    const conversation = findConversation(conversationId);

    if (!conversation) {
      return res.status(404).json({ error: "Conversation introuvable." });
    }

    addConversationMessage(conversationId, "user", userMessage);

    const pending = pendingActions.get(conversationId);

    if (pending) {
      if (isConfirmation(userMessage)) {
        pendingActions.delete(conversationId);

        if (pending.type === "remember") {
          const result = saveFact(pending.content);
          const reply = result.success
            ? `C'est enregistré ! Je retiendrai que ${pending.content}.`
            : result.message;
          updateConversationAfterAssistant(conversationId, reply);
          return streaming ? sendText(res, reply) : res.json({ reply });
        }

        if (pending.type === "forget") {
          const conversationsFacts = getFacts();
          const searchText = pending.content.toLowerCase();
          const updatedFacts = conversationsFacts.filter(
            (fact) => !fact.content.toLowerCase().includes(searchText)
          );

          const reply = updatedFacts.length === conversationsFacts.length
            ? "Je n'ai trouvé aucun souvenir correspondant à cette information."
            : "C'est fait ! J'ai supprimé le souvenir correspondant.";

          if (updatedFacts.length !== conversationsFacts.length) {
            saveJSON(FACTS_FILE, { facts: updatedFacts });
          }

          updateConversationAfterAssistant(conversationId, reply);
          return streaming ? sendText(res, reply) : res.json({ reply });
        }
      }

      if (isRejection(userMessage)) {
        pendingActions.delete(conversationId);
        const reply = "D'accord, je n'ai rien modifié dans ma mémoire.";
        updateConversationAfterAssistant(conversationId, reply);
        return streaming ? sendText(res, reply) : res.json({ reply });
      }

      const reply = "J'attends ta réponse : veux-tu confirmer cette opération ? Réponds par oui ou non.";
      updateConversationAfterAssistant(conversationId, reply);
      return streaming ? sendText(res, reply) : res.json({ reply });
    }

    const memoryCommand = detectMemoryCommand(userMessage);
    if (memoryCommand) {
      pendingActions.set(conversationId, memoryCommand);

      const reply = memoryCommand.type === "remember"
        ? `Je peux retenir cette information : "${memoryCommand.content}". Veux-tu que je l'enregistre dans ma mémoire personnelle ?`
        : `Je peux supprimer le souvenir correspondant à : "${memoryCommand.content}". Veux-tu confirmer cette suppression ?`;

      updateConversationAfterAssistant(conversationId, reply);
      return streaming ? sendText(res, reply) : res.json({ reply });
    }

    const latestConversation = findConversation(conversationId);
    const messages = [
      { role: "system", content: buildSystemPrompt() },
      ...getRecentModelMessages(latestConversation)
    ];

    const ollamaResponse = await fetch(OLLAMA_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: MODEL,
        messages,
        stream: false,
        keep_alive: "30m",
        options: {
          num_ctx: 1024,
          num_predict: 256,
          num_gpu: 8
        }
      })
    });

    if (!ollamaResponse.ok) {
      const errorText = await ollamaResponse.text();
      throw new Error(`Erreur Ollama (${ollamaResponse.status}) : ${errorText}`);
    }

    let fullReply = "";

    if (streaming) {
      res.status(200);
      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      res.setHeader("Cache-Control", "no-cache, no-transform");
      res.setHeader("X-Accel-Buffering", "no");
      res.flushHeaders();
      responseStarted = true;

      let buffer = "";

      for await (const chunk of ollamaResponse.body) {
        buffer += Buffer.from(chunk).toString("utf8");
        const lines = buffer.split("\n");
        buffer = lines.pop() || "";

        for (const line of lines) {
          if (!line.trim()) continue;
          const item = JSON.parse(line);

          if (item.message && typeof item.message.content === "string") {
            const token = item.message.content;
            fullReply += token;
            res.write(token);
          }

          if (item.error) {
            throw new Error(item.error);
          }
        }
      }

      if (buffer.trim()) {
        const item = JSON.parse(buffer);
        if (item.message && typeof item.message.content === "string") {
          fullReply += item.message.content;
          res.write(item.message.content);
        }
      }

      if (fullReply.trim()) {
        updateConversationAfterAssistant(conversationId, fullReply);
      }

      res.end();
      return;
    }

    const data = await ollamaResponse.json();
    fullReply = data.message?.content || "";

    if (!fullReply) {
      throw new Error("Ollama n'a retourné aucune réponse.");
    }

    updateConversationAfterAssistant(conversationId, fullReply);
    return res.json({ reply: fullReply });

  } catch (error) {
    console.error("Erreur /chat :", error);

    if (streaming && responseStarted) {
      res.write("\n\n[Erreur pendant la génération de la réponse.]");
      return res.end();
    }

    return res.status(500).json({
      error: "Une erreur est survenue.",
      details: error.message
    });
  }
}

// État du serveur
app.get("/", (req, res) => {
  const conversations = getConversations();
  res.json({
    status: "ATLAS fonctionne",
    model: MODEL,
    conversations: conversations.length,
    personalFacts: getFacts().length
  });
});

// Conversations : liste
app.get("/conversations", (req, res) => {
  const conversations = getConversations()
    .map(({ id, title, createdAt, updatedAt, messages }) => ({
      id,
      title,
      createdAt,
      updatedAt,
      messageCount: messages.length
    }))
    .sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));

  res.json({ conversations });
});

// Conversations : création
app.post("/conversations", (req, res) => {
  try {
    const conversation = createConversation();
    res.status(201).json({ conversation });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Conversations : lecture complète
app.get("/conversations/:id", (req, res) => {
  const conversation = findConversation(req.params.id);

  if (!conversation) {
    return res.status(404).json({ error: "Conversation introuvable." });
  }

  res.json({ conversation });
});

// Conversations : suppression
app.delete("/conversations/:id", (req, res) => {
  const conversations = getConversations();
  const updated = conversations.filter((item) => item.id !== req.params.id);

  if (updated.length === conversations.length) {
    return res.status(404).json({ error: "Conversation introuvable." });
  }

  saveConversations(updated);
  pendingActions.delete(req.params.id);
  res.json({ success: true });
});

// Chat classique pour compatibilité avec les anciens clients
app.post("/chat", upload.array("files", 5), (req, res) => handleChat(req, res, false));

// Chat en streaming pour la nouvelle version Flutter
app.post("/chat/stream", upload.array("files", 5), (req, res) => handleChat(req, res, true));

// Souvenirs personnels
app.get("/memory", (req, res) => {
  res.json({ facts: getFacts() });
});

app.post("/memory", (req, res) => {
  const { content, confirm } = req.body;

  if (confirm !== true) {
    return res.status(400).json({
      error: "Une confirmation explicite est nécessaire."
    });
  }

  if (
    typeof content !== "string" ||
    content.trim().length < 1 ||
    content.trim().length > 500
  ) {
    return res.status(400).json({
      error: "Le souvenir doit contenir entre 1 et 500 caractères."
    });
  }

  return res.json(saveFact(content));
});

app.delete("/memory/:id", (req, res) => {
  const facts = getFacts();
  const updatedFacts = facts.filter((fact) => fact.id !== req.params.id);

  if (updatedFacts.length === facts.length) {
    return res.status(404).json({ error: "Souvenir introuvable." });
  }

  saveJSON(FACTS_FILE, { facts: updatedFacts });
  res.json({ success: true, message: "Souvenir supprimé." });
});

// Réinitialise uniquement l'ancien fichier de mémoire conversationnelle.
// Les conversations multiples et les souvenirs personnels sont conservés.
app.post("/reset", (req, res) => {
  saveJSON(MEMORY_FILE, { messages: [] });
  pendingActions.clear();

  res.json({
    success: true,
    message: "Ancien historique réinitialisé. Les conversations et souvenirs personnels sont conservés."
  });
});

// Erreurs de taille/type des pièces jointes (Multer).
app.use((error, req, res, next) => {
  if (error instanceof multer.MulterError || error.message === "Format non pris en charge.") {
    return res.status(400).json({ error: error.message });
  }
  return next(error);
});

app.listen(PORT, () => {
  console.log("----------------------------------");
  console.log("ATLAS est démarré !");
  console.log(`Serveur : http://localhost:${PORT}`);
  console.log(`Modèle : ${MODEL}`);
  console.log("----------------------------------");
});
