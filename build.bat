@echo off

set "FLAGS=--enable-threads --enable-memory64" 

wat2wasm %FLAGS% wasm/memory.wat -o public/memory.wasm
wat2wasm %FLAGS% wasm/atomic.wat -o public/atomic.wasm