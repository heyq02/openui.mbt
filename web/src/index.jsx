import { Renderer } from "@openuidev/react-lang";
import { openuiLibrary } from "@openuidev/react-ui";
import "@openuidev/react-ui/defaults.css";
import "@openuidev/react-ui/index.css";
import { createRoot } from "react-dom/client";
import { useState } from "react";
import sample from "../../examples/signup.openui";
import "./index.css";

function App() {
  const [source, setSource] = useState(sample.trim());
  const [response, setResponse] = useState(sample.trim());
  const [status, setStatus] = useState("");
  const [errors, setErrors] = useState([]);

  return (
    <main>
      <h1>OpenUI Lang</h1>
      <p className="lead">
        官方 Renderer 渲染界面。词法和表达式解析换成 MoonBit Wasm-GC，组件库仍是 OpenUI。
      </p>
      <div className="layout">
        <section>
          <textarea
            value={source}
            spellCheck={false}
            onChange={(event) => setSource(event.target.value)}
          />
          <p>
            <button type="button" onClick={() => setResponse(source)}>
              渲染
            </button>
          </p>
          <p className={errors.length > 0 ? "error" : "status"}>{status}</p>
          {errors.length > 0 && (
            <pre className="error">
              {errors.map((error) => error.message).join("\n")}
            </pre>
          )}
        </section>
        <section className="preview" aria-label="渲染结果">
          <Renderer
            library={openuiLibrary}
            response={response}
            onParseResult={(result) => {
              if (!result?.root) {
                setStatus("没有可渲染的根节点。");
                return;
              }
              setStatus(
                `已渲染 ${result.root.typeName}，${result.meta.statementCount} 条语句。`,
              );
            }}
            onError={setErrors}
            onAction={(event) => {
              const human = event.humanFriendlyMessage ?? event.type ?? "action";
              setStatus(`动作：${human}`);
            }}
          />
        </section>
      </div>
    </main>
  );
}

createRoot(document.querySelector("#root")).render(<App />);
