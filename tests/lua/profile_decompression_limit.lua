-- Describe: output limits apply while expanding every DEFLATE block type.
local stubFile = assert(io.open("Libs/LibStub.lua", "rb"))
local stubSource = stubFile:read("*a"):gsub("^\239\187\191", "")
stubFile:close()
assert(loadstring(stubSource))()
local codec = dofile("Libs/LibDeflate.lua")
assert(type(codec.DecompressZlibBounded) == "function",
	"bounded decompression is missing")

for _, configs in ipairs({
	{ level = 0 }, { level = 1, strategy = "fixed" },
	{ level = 1, strategy = "dynamic" },
}) do
	-- Given a stream containing multiple blocks and repeated bytes.
	local data = string.rep("ABCDEF", 25000)
	local compressed = codec:CompressZlib(data, configs)

	-- When the cap is smaller than the expanded stream.
	local decoded, status = codec:DecompressZlibBounded(compressed, #data - 1)

	-- Then it stops with an output-limit error before checking the checksum.
	assert(not decoded and status == -18, "expansion limit was not enforced")

	-- When the exact expanded size is permitted.
	decoded, status = codec:DecompressZlibBounded(compressed, #data)

	-- Then the original data and trailing-byte contract are preserved.
	assert(decoded == data and status == 0, "exact limit rejected valid data")
	decoded, status = codec:DecompressZlibBounded(compressed .. "extra", #data)
	assert(decoded == data and status == 5, "trailing bytes were not detected")
end

-- Given a literal stream and a cap ending before the first literal.
local compressed = codec:CompressZlib("AB", { strategy = "fixed" })

-- When zero bytes or exactly one byte can be emitted.
local decoded, status = codec:DecompressZlibBounded(compressed, 0)
local oneByte, oneByteStatus = codec:DecompressZlibBounded(compressed, 1)

-- Then literals also respect the cap without emitting a partial result.
assert(not decoded and status == -18)
assert(not oneByte and oneByteStatus == -18)

-- Given a small clipboard string that expands far beyond the profile limit.
MikSBT = { Configuration = {} }
dofile("Libs/LibSerialize.lua")
local ProfileTransfer = dofile("Configuration/ProfileTransfer.lua")
local transfer = ProfileTransfer:New({
	masterProfile = {}, version = "12.029.0", client = 120100, locale = "enUS",
})
local large = string.rep("A", 4 * 1024 * 1024)
compressed = codec:CompressZlib(large, { level = 1 })
local text = "!MSBT:1!" .. codec:EncodeForPrint(compressed)
large = nil
assert(#text < 65536, "fixture does not bypass the clipboard size cap")
codec.DecompressZlib = function() error("unbounded decompression was called") end

-- When the profile is decoded and imported.
local payload, errorCode = transfer:Decode(text)
local profiles = { Default = {} }
local savedMedia = { fonts = {}, sounds = {} }
local name, importError = transfer:Import(text, "Rejected", profiles, savedMedia)

-- Then it uses bounded decoding and leaves saved storage untouched.
assert(not payload and errorCode == "TOO_LARGE")
assert(not name and importError == "TOO_LARGE")
assert(profiles.Rejected == nil)
assert(next(savedMedia.fonts) == nil and next(savedMedia.sounds) == nil)

-- Given an unrelated addon with a newer shared compression library.
local shared = LibStub:NewLibrary("LibDeflate", 99999)
shared.marker = "another addon"

-- When MSBT's library loads again.
local reloaded = dofile("Libs/LibDeflate.lua")

-- Then other addons cannot replace MSBT's bounded decoder or be overwritten.
assert(reloaded == codec, "shared library replaced the bounded decoder")
assert(LibStub("LibDeflate").marker == "another addon")

print("Bounded decompression tests passed")
