import { Renderer } from "@openuidev/react-lang";
import { openuiLibrary } from "@openuidev/react-ui";

import "@openuidev/react-ui/defaults.css";
import "@openuidev/react-ui/index.css";
import { createRoot } from "react-dom/client";

import sample from "../signup.openui";

const source = sample.trim();

function App() {
  return (
    <main>
      <Renderer
        library={openuiLibrary}
        response={source}
        onParseResult={(result) => {
          requestAnimationFrame(() => {
            requestAnimationFrame(() => {
              const root = document.documentElement;
              root.dataset.bench = "ready";
              root.dataset.benchMs = performance.now().toFixed(2);
              root.dataset.benchRoot = result?.root?.typeName ?? "";
              root.dataset.benchStatements = String(result?.meta?.statementCount ?? 0);
            });
          });
        }}
        onError={() => {
          document.documentElement.dataset.bench = "error";
        }}
      />
    </main>
  );
}

createRoot(document.querySelector("#root")).render(<App />);
