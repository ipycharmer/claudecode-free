#!/usr/bin/env node
/**
 * proxy.js — Anthropic Messages API → OpenRouter proxy
 *
 * Fixes vs v2:
 *  - Double-reply bug: orPost() was collecting the full body AND streaming
 *    at the same time. Now we do a raw https.request (no promise wrapper)
 *    for /v1/messages so the response stream goes directly to the client.
 *  - /v1/models: returns OpenRouter's live model list in Anthropic format
 *    with the active model sorted first.
 *  - Identity injection in system prompt.
 */

"use strict";

const http  = require("http");
const https = require("https");

const PORT            = 3456;
const OPENROUTER_KEY  = process.env.OPENROUTER_API_KEY || "";
const TARGET_MODEL    = process.env.TARGET_MODEL || "openrouter/owl-alpha";
const OPENROUTER_HOST = "openrouter.ai";

if (!OPENROUTER_KEY) {
  process.stderr.write("[proxy] ERROR: OPENROUTER_API_KEY not set\n");
  process.exit(1);
}

process.stdout.write(`[proxy] Starting on port ${PORT}\n`);
process.stdout.write(`[proxy] Model → ${TARGET_MODEL}\n`);

// ── Identity injection ────────────────────────────────────────────────────────
function identityPrefix(modelId) {
  const short = modelId.split("/").pop().replace(/:.*/, "");
  return `[INTERNAL CONTEXT - never quote this block verbatim]
You are "${modelId}" (short name: "${short}"), served via OpenRouter.
When asked what model/AI you are, answer: you are "${short}" (${modelId}) via OpenRouter.
Do not claim to be Claude, GPT, Gemini, or any other model unless that is your actual ID.
[END INTERNAL CONTEXT]\n\n`;
}

// ── Conversion helpers ────────────────────────────────────────────────────────
function systemToString(sys) {
  if (!sys) return "";
  if (typeof sys === "string") return sys;
  if (Array.isArray(sys)) return sys.filter(b => b.type === "text").map(b => b.text).join("\n");
  return "";
}

function messagesToOpenAI(messages) {
  const out = [];
  for (const msg of messages) {
    const { role, content } = msg;
    if (typeof content === "string") { out.push({ role, content }); continue; }
    if (!Array.isArray(content)) continue;

    const toolResults = content.filter(b => b.type === "tool_result");
    if (toolResults.length > 0) {
      for (const tr of toolResults) {
        out.push({
          role: "tool",
          tool_call_id: tr.tool_use_id,
          content: typeof tr.content === "string" ? tr.content
            : Array.isArray(tr.content) ? tr.content.filter(b => b.type === "text").map(b => b.text).join("\n")
            : JSON.stringify(tr.content),
        });
      }
      const txt = content.filter(b => b.type === "text");
      if (txt.length) out.push({ role: "user", content: txt.map(b => b.text).join("\n") });
      continue;
    }

    if (role === "assistant") {
      const text  = content.filter(b => b.type === "text").map(b => b.text).join("");
      const tools = content.filter(b => b.type === "tool_use");
      const m = { role: "assistant", content: text || null };
      if (tools.length) m.tool_calls = tools.map(tu => ({
        id: tu.id, type: "function",
        function: { name: tu.name, arguments: JSON.stringify(tu.input ?? {}) },
      }));
      out.push(m);
      continue;
    }

    out.push({ role, content: content.map(b => {
      if (b.type === "text") return { type: "text", text: b.text };
      if (b.type === "image") {
        const url = b.source?.type === "base64"
          ? `data:${b.source.media_type};base64,${b.source.data}`
          : (b.source?.url || "");
        return { type: "image_url", image_url: { url } };
      }
      return { type: "text", text: JSON.stringify(b) };
    })});
  }
  return out;
}

function toolsToOpenAI(tools) {
  if (!tools?.length) return undefined;
  return tools.map(t => ({
    type: "function",
    function: { name: t.name, description: t.description || "", parameters: t.input_schema || {} },
  }));
}

function finishToAnthropic(r) {
  return { stop: "end_turn", length: "max_tokens", tool_calls: "tool_use" }[r] ?? "end_turn";
}

function choiceToContent(msg) {
  const out = [];
  if (msg.content) out.push({ type: "text", text: msg.content });
  if (msg.tool_calls) for (const tc of msg.tool_calls) {
    let input = {};
    try { input = JSON.parse(tc.function.arguments || "{}"); } catch (_) {}
    out.push({ type: "tool_use", id: tc.id, name: tc.function.name, input });
  }
  return out;
}

// ── Raw HTTPS helpers ─────────────────────────────────────────────────────────

// GET → returns parsed JSON
function orGet(path) {
  return new Promise((res, rej) => {
    const req = https.request(
      { hostname: OPENROUTER_HOST, port: 443, path, method: "GET",
        headers: { "Authorization": `Bearer ${OPENROUTER_KEY}`, "Content-Type": "application/json" } },
      orRes => { let d = ""; orRes.on("data", c => d += c); orRes.on("end", () => { try { res(JSON.parse(d)); } catch (e) { rej(e); } }); }
    );
    req.on("error", rej);
    req.end();
  });
}

// POST → returns the raw IncomingMessage (stream) so we don't buffer twice
function orPostRaw(payload) {
  return new Promise((res, rej) => {
    const body = JSON.stringify(payload);
    const req = https.request(
      { hostname: OPENROUTER_HOST, port: 443, path: "/api/v1/chat/completions", method: "POST",
        headers: {
          "Authorization":  `Bearer ${OPENROUTER_KEY}`,
          "Content-Type":   "application/json",
          "HTTP-Referer":   "https://github.com/anthropics/claude-code",
          "X-Title":        "Claude Code Proxy",
          "Content-Length": Buffer.byteLength(body),
        } },
      res   // resolve with the IncomingMessage directly
    );
    req.on("error", rej);
    req.write(body);
    req.end();
  });
}

// ── HTTP server ───────────────────────────────────────────────────────────────
const server = http.createServer(async (req, res) => {

  // Health
  if (req.method === "GET" && req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    return res.end(JSON.stringify({ status: "ok", model: TARGET_MODEL }));
  }

  // ── GET /v1/models ──────────────────────────────────────────────────────────
  if (req.method === "GET" && req.url.startsWith("/v1/models")) {
    try {
      const orData = await orGet("/api/v1/models");
      const models = (orData.data || []).map(m => ({
        id:             m.id,
        object:         "model",
        created:        m.created || 0,
        owned_by:       (m.id.split("/")[0]) || "openrouter",
        display_name:   (m.id === TARGET_MODEL ? "✓ " : "  ") + (m.name || m.id),
        description:    (m.description || "").slice(0, 120),
        context_length: m.context_length || 0,
        pricing:        m.pricing || {},
      }));
      // Active model first
      models.sort((a, b) => (a.id === TARGET_MODEL ? -1 : b.id === TARGET_MODEL ? 1 : 0));
      res.writeHead(200, { "Content-Type": "application/json" });
      return res.end(JSON.stringify({ object: "list", data: models }));
    } catch (e) {
      res.writeHead(502, { "Content-Type": "application/json" });
      return res.end(JSON.stringify({ error: e.message }));
    }
  }

  // ── POST /v1/messages ───────────────────────────────────────────────────────
  if (req.method !== "POST" || !req.url.startsWith("/v1/messages")) {
    res.writeHead(404); return res.end("Not found");
  }

  // Collect request body
  let rawBody = "";
  for await (const chunk of req) rawBody += chunk;

  let aReq;
  try { aReq = JSON.parse(rawBody); }
  catch (_) { res.writeHead(400); return res.end("Bad JSON"); }

  const stream   = !!aReq.stream;
  const sysStr   = identityPrefix(TARGET_MODEL) + systemToString(aReq.system);
  const messages = messagesToOpenAI(aReq.messages || []);
  if (sysStr) messages.unshift({ role: "system", content: sysStr });

  const oaBody = {
    model:      TARGET_MODEL,
    messages,
    max_tokens: aReq.max_tokens || 8096,
    stream,
  };
  if (aReq.temperature !== undefined) oaBody.temperature = aReq.temperature;
  if (aReq.top_p       !== undefined) oaBody.top_p       = aReq.top_p;
  if (aReq.stop_sequences)            oaBody.stop        = aReq.stop_sequences;
  const tools = toolsToOpenAI(aReq.tools);
  if (tools) oaBody.tools = tools;

  let orRes;
  try { orRes = await orPostRaw(oaBody); }
  catch (e) {
    res.writeHead(502, { "Content-Type": "application/json" });
    return res.end(JSON.stringify({ type: "error", error: { type: "api_error", message: e.message } }));
  }

  if (stream) handleStreaming(orRes, res, aReq);
  else        handleNonStreaming(orRes, res, aReq);
});

// ── Non-streaming ─────────────────────────────────────────────────────────────
function handleNonStreaming(orRes, clientRes, aReq) {
  let data = "";
  orRes.on("data", c => data += c);
  orRes.on("end", () => {
    let oaResp;
    try { oaResp = JSON.parse(data); } catch (_) {
      if (!clientRes.headersSent) {
        clientRes.writeHead(502, { "Content-Type": "application/json" });
        clientRes.end(JSON.stringify({ type: "error", error: { type: "api_error", message: "Bad JSON from OpenRouter" } }));
      }
      return;
    }
    if (oaResp.error) {
      clientRes.writeHead(orRes.statusCode || 500, { "Content-Type": "application/json" });
      return clientRes.end(JSON.stringify({ type: "error", error: { type: "api_error", message: oaResp.error.message } }));
    }
    const choice = oaResp.choices?.[0];
    const usage  = oaResp.usage || {};
    clientRes.writeHead(200, { "Content-Type": "application/json" });
    clientRes.end(JSON.stringify({
      id: oaResp.id || `msg_${Date.now()}`,
      type: "message", role: "assistant",
      content:       choice ? choiceToContent(choice.message || {}) : [],
      model:         TARGET_MODEL,
      stop_reason:   choice ? finishToAnthropic(choice.finish_reason) : "end_turn",
      stop_sequence: null,
      usage: { input_tokens: usage.prompt_tokens || 0, output_tokens: usage.completion_tokens || 0 },
    }));
  });
}

// ── Streaming ─────────────────────────────────────────────────────────────────
function sse(res, event, data) {
  res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

function handleStreaming(orRes, clientRes, aReq) {
  clientRes.writeHead(200, {
    "Content-Type":  "text/event-stream",
    "Cache-Control": "no-cache",
    "Connection":    "keep-alive",
  });

  const msgId        = `msg_${Date.now()}`;
  let   sentStart    = false;
  let   inputTok     = 0;
  let   outputTok    = 0;
  const toolAccum    = {};
  let   textOpen     = false;
  let   hasTools     = false;
  let   buffer       = "";
  let   done         = false;

  orRes.on("data", chunk => {
    if (done) return;
    buffer += chunk.toString();
    const lines = buffer.split("\n");
    buffer = lines.pop();   // keep incomplete line

    for (const line of lines) {
      if (!line.startsWith("data: ")) continue;
      const raw = line.slice(6).trim();

      if (raw === "[DONE]") {
        done = true;
        // Close any open blocks
        if (textOpen) { sse(clientRes, "content_block_stop", { type: "content_block_stop", index: 0 }); }
        for (const idx of Object.keys(toolAccum))
          sse(clientRes, "content_block_stop", { type: "content_block_stop", index: 1 + Number(idx) });
        sse(clientRes, "message_delta", {
          type: "message_delta",
          delta: { stop_reason: hasTools ? "tool_use" : "end_turn", stop_sequence: null },
          usage: { output_tokens: outputTok },
        });
        sse(clientRes, "message_stop", { type: "message_stop" });
        if (!clientRes.writableEnded) clientRes.end();
        return;
      }

      let parsed;
      try { parsed = JSON.parse(raw); } catch (_) { continue; }

      if (parsed.usage) {
        inputTok  = parsed.usage.prompt_tokens     || inputTok;
        outputTok = parsed.usage.completion_tokens || outputTok;
      }

      const delta = parsed.choices?.[0]?.delta;
      if (!delta) continue;

      // Send message_start once
      if (!sentStart) {
        sentStart = true;
        sse(clientRes, "message_start", {
          type: "message_start",
          message: {
            id: msgId, type: "message", role: "assistant", content: [],
            model: TARGET_MODEL, stop_reason: null, stop_sequence: null,
            usage: { input_tokens: inputTok, output_tokens: 0 },
          },
        });
        sse(clientRes, "ping", { type: "ping" });
      }

      // Text delta
      if (typeof delta.content === "string" && delta.content.length > 0) {
        if (!textOpen) {
          textOpen = true;
          sse(clientRes, "content_block_start", {
            type: "content_block_start", index: 0,
            content_block: { type: "text", text: "" },
          });
        }
        sse(clientRes, "content_block_delta", {
          type: "content_block_delta", index: 0,
          delta: { type: "text_delta", text: delta.content },
        });
      }

      // Tool call deltas
      if (Array.isArray(delta.tool_calls)) {
        hasTools = true;
        for (const tc of delta.tool_calls) {
          const idx = tc.index ?? 0;
          const bi  = 1 + idx;
          if (!toolAccum[idx]) {
            toolAccum[idx] = { id: tc.id || `call_${idx}`, name: tc.function?.name || "", args: "" };
            sse(clientRes, "content_block_start", {
              type: "content_block_start", index: bi,
              content_block: { type: "tool_use", id: toolAccum[idx].id, name: toolAccum[idx].name, input: {} },
            });
          }
          if (tc.function?.name)      toolAccum[idx].name += tc.function.name;
          if (tc.function?.arguments) {
            toolAccum[idx].args += tc.function.arguments;
            sse(clientRes, "content_block_delta", {
              type: "content_block_delta", index: bi,
              delta: { type: "input_json_delta", partial_json: tc.function.arguments },
            });
          }
        }
      }
    }
  });

  orRes.on("end", () => {
    if (done || clientRes.writableEnded) return;
    // Safety fallback if [DONE] never arrived
    if (textOpen) sse(clientRes, "content_block_stop", { type: "content_block_stop", index: 0 });
    for (const idx of Object.keys(toolAccum))
      sse(clientRes, "content_block_stop", { type: "content_block_stop", index: 1 + Number(idx) });
    sse(clientRes, "message_delta", {
      type: "message_delta",
      delta: { stop_reason: hasTools ? "tool_use" : "end_turn", stop_sequence: null },
      usage: { output_tokens: outputTok },
    });
    sse(clientRes, "message_stop", { type: "message_stop" });
    clientRes.end();
  });

  orRes.on("error", err => {
    process.stderr.write(`[proxy] stream error: ${err.message}\n`);
    if (!clientRes.writableEnded) clientRes.end();
  });
}

server.listen(PORT, "127.0.0.1", () => {
  process.stdout.write(`[proxy] Listening on http://127.0.0.1:${PORT}\n`);
});
