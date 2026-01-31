# LuaSL

LuaSL is a small, statically typed shader language with Lua‑style syntax that compiles to GLSL 330.

## CLI

Build shaders:
```
luasl build examples/fragment_basic.luasl
luasl build examples/*.luasl -o build/shaders
luasl build examples/fragment_basic.luasl --stage fragment
```

Type check only:
```
luasl check examples/fragment_basic.luasl
```

## Add to PATH (Windows)

Add this repo root to your PATH so `luasl` works anywhere:
```
setx PATH "%PATH%;C:\path\to\LuaSL"
```
Open a new terminal after running that.

## Examples

See `examples/` for basic, mix, ripples, and struct/for samples.

## VS Code

The `vscode-extension/` folder provides syntax highlighting, snippets, and keyword completions.
