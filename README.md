Based on the example from https://github.com/WebAssembly/threads/blob/main/proposals/threads/Overview.md

# How to start

- build the .wasm from the .wat by running `./build.sh` (wat2wasm is from https://github.com/WebAssembly/wabt)
- start the server with `./server_start.sh`
- open the web page at `http://localhost:8085/`
- view logs in the browser dev console

# Useful links for further research

- https://web.dev/articles/webassembly-threads very good doc
- https://webassembly.github.io/wabt/demo/wat2wasm/ to quickly test conversions wat to wasm, and the options required in the command line
- https://surma.dev/postits/wasi-threads/ This seems to describe how to spawn a thread from wasm directly. I don't yet know what wasi is.
- https://emscripten.org/docs/porting/pthreads.html how emscripten handles threads
- https://github.com/GoogleChromeLabs/comlink could help manage workers more easily.
- https://web.dev/articles/cross-origin-isolation-guide doc on cross isolation, which is required to have shared memory