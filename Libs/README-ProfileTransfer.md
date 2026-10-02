# Profile transfer libraries

These libraries are loaded after LibStub. LibSerialize is unmodified.
LibDeflate is adapted locally to enforce an output limit during decompression
and registers as `MSBTLibDeflate` so other addons cannot replace this API.
The zlib and printable formats remain compatible with upstream LibDeflate.

| Library | Upstream | Pinned commit | License |
| --- | --- | --- | --- |
| LibSerialize | https://github.com/rossnichols/LibSerialize | e89d5055c761f48faa216ba9087d8c2e8bceab8a | MIT |
| LibDeflate | https://github.com/SafeteeWoW/LibDeflate | afc3b78d12fb3bcfa6b21e5332031ad3d7572e19 | zlib |

The respective license texts are retained in `LICENSE-LibSerialize.txt` and
`LICENSE-LibDeflate.txt`. This development reference is excluded from releases
by the existing `*/README*` packaging rule.

Profile strings use stable LibSerialize serialization, zlib compression (with
the built-in Adler-32 checksum), and LibDeflate's printable encoding. The
`!MSBT:1!` prefix identifies the addon transfer format. Import never executes
profile strings as Lua.
