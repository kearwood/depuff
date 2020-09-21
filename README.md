This is a WIP.  Expect updates and better documentation soon.  I plan to soon add a non-SIMD fallback implementation.

This WASM module implements compression compatible with WebGL's EXT_texture_compression_s3tc, with the prioritization of speed of compression over quality.  This enables runtime compression for the GPU without depending on offline processing of textures.

https://www.khronos.org/registry/OpenGL/extensions/EXT/EXT_texture_compression_s3tc.txt

The `depuff_simd.wasm` file is generated from the source, `depuff_simd.wat` using the `wat2wasm` tool
from the WebAssembly Binary Toolkit (WABT).

If you wish to build it, get the WABT repo and follow the instructions in its README.md to set up the tool:

https://github.com/webassembly/wabt

`depuff_simd.wat` uses WASM simd instructions:

https://github.com/WebAssembly/simd/blob/master/proposals/simd/SIMD.md

Currently, SIMD instructions are not yet enabled by default in all browsers.
It is enabled by default in Firefox Nightly.

For Chrome, it can be activated by enabling the `WebAssembly SIMD support`
expriment in `chrome://flags/`.

To run the `example.html` file locally, it needs to be running in a web server to
avoid CORS errors.  You can quickly set up an HTTP server using Python.

For example, on Windows:

```
choco install python3
refreshenv
py -m http.server
```

You would then access the example with:

```
http://localhost:8000/example.html
```

