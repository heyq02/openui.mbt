import { Renderer } from "@openuidev/react-lang";
import { openuiLibrary } from "@openuidev/react-ui";

import "@openuidev/react-ui/defaults.css";
import "@openuidev/react-ui/index.css";
import { useEffect, useState } from "react";
import { flushSync } from "react-dom";
import { createRoot } from "react-dom/client";

import sample from "../signup.openui";

const source = sample.trim();
const lines = source.split("\n");
const stream = new URLSearchParams(window.location.search).get("stream") === "1";

function markReady(result) {
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      const root = document.documentElement;
      root.dataset.bench = "ready";
      root.dataset.benchMs = performance.now().toFixed(2);
      root.dataset.benchRoot = result?.root?.typeName ?? "";
      root.dataset.benchStatements = String(result?.meta?.statementCount ?? 0);
      root.dataset.benchMode = stream ? "stream" : "parse";
    });
  });
}

function App() {
  const [shown, setShown] = useState(stream ? 1 : lines.length);
  const complete = shown >= lines.length;
  useEffect(() => {
    if (!stream) return;
    for (let count = 2; count <= lines.length; count += 1) {
      flushSync(() => setShown(count));
    }
  }, []);
  return (
    <main>
      <Renderer
        library={openuiLibrary}
        response={lines.slice(0, shown).join("\n")}
        isStreaming={stream && !complete}
        onParseResult={(result) => {
          if (!complete) return;
          markReady(result);
        }}
        onError={() => {
          document.documentElement.dataset.bench = "error";
        }}
      />
    </main>
  );
}

createRoot(document.querySelector("#root")).render(<App />);
