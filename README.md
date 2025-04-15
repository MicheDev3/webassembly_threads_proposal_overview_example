Based on the example from https://github.com/WebAssembly/threads/blob/main/proposals/threads/Overview.md

# How to Compile

You can compile the project by running `jai jai/build.jai` which will compile Jai into WASM and generate and compile any WAT file required 

# How to Run

You can start the server by running the python script `server.py` on a terminal; e.g: `python server.py`
You can view the web app using the following url `http://localhost:8085/` (use the browser dev console to view any logs)

# Requirements

- Jai compiler (version currently tested: jai-beta-2-009)
- WASM compiler (using wat2wasm from wabt)

# Useful links for further research

- https://web.dev/articles/webassembly-threads very good doc
- https://webassembly.github.io/wabt/demo/wat2wasm/ to quickly test conversions wat to wasm, and the options required in the command line
- https://surma.dev/postits/wasi-threads/ This seems to describe how to spawn a thread from wasm directly. I don't yet know what wasi is.
- https://emscripten.org/docs/porting/pthreads.html how emscripten handles threads
- https://github.com/GoogleChromeLabs/comlink could help manage workers more easily.
- https://web.dev/articles/cross-origin-isolation-guide doc on cross isolation, which is required to have shared memory