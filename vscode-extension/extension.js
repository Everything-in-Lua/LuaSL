// Minimal completion provider for Luau-SL.

const KEYWORDS = [
  "let",
  "var",
  "function",
  "return",
  "struct",
  "uniform",
  "in",
  "out",
  "extern",
  "for",
  "do",
  "end",
  "if",
  "then",
  "else",
  "and",
  "or",
  "@fragment",
  "@vertex",
];

const TYPES = [
  "float",
  "int",
  "bool",
  "vec2",
  "vec3",
  "vec4",
  "mat2",
  "mat3",
  "mat4",
  "sampler2D",
  "void",
];

const BUILTINS = [
  "sin",
  "cos",
  "tan",
  "dot",
  "normalize",
  "length",
  "fract",
  "mix",
  "clamp",
  "smoothstep",
  "texture",
  "vec2",
  "vec3",
  "vec4",
];

function activate(context) {
  const vscode = require("vscode");
  const provider = {
    provideCompletionItems() {
      const items = [];
      for (const k of KEYWORDS) {
        const item = new vscode.CompletionItem(k, vscode.CompletionItemKind.Keyword);
        items.push(item);
      }
      for (const t of TYPES) {
        const item = new vscode.CompletionItem(t, vscode.CompletionItemKind.TypeParameter);
        items.push(item);
      }
      for (const b of BUILTINS) {
        const item = new vscode.CompletionItem(b, vscode.CompletionItemKind.Function);
        items.push(item);
      }
      return items;
    },
  };

  const disposable = vscode.languages.registerCompletionItemProvider(
    { language: "luasl" },
    provider
  );
  context.subscriptions.push(disposable);
}

function deactivate() {}

module.exports = {
  activate,
  deactivate,
};
