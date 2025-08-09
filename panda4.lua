-- Key GUI + Panel Verification (Rayfield)
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Ganti dengan endpoint check API panelmu (POST/GET sesuai implementasi backend)
local VERIFY_URL = "https://velouramlbb.xyz/api/game/BS" -- endpoint yang menerima form-data
local SCRIPT_URL = "https://velouramlbb.xyz/auth/script.lua" -- script utama yang akan di-load setelah validasi
local GAME_ID = "BS"
local CLIENT_VERSION = "1.7"

-- Utility: buat random string (resource)
local function RandString(len)
    local res = {}
    local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    for i = 1, len do
        local idx = math.random(1, #charset)
        res[i] = charset:sub(idx, idx)
    end
    return table.concat(res)
end

-- Utility: buat "serial" yang cukup unik di Roblox (tidak HWID asli)
-- Rekomendasi: server mengaitkan key dengan Roblox UserId untuk keamanan.
local function MakeSerial()
    -- kombinasi UserId + username + jobId (agar sedikit berbeda tiap session)
    local pid = tostring(LocalPlayer.UserId or 0)
    local name = LocalPlayer.Name or "Unknown"
    local job = tostring(game.JobId or "")
    local rand = RandString(8)
    return pid .. "-" .. name .. "-" .. job .. "-" .. rand
end

-- Buat tab Key (gunakan Window yang sudah ada di script-mu)
local KeyTab = Window:CreateTab("Key", "key")

local userKey = ""
KeyTab:CreateInput({
    Name = "Masukkan Key",
    PlaceholderText = "Input key di sini...",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        userKey = tostring(text or "")
    end
})

KeyTab:CreateParagraph({
    Title = "Petunjuk",
    Content = "Masukkan key yang kamu peroleh dari panel. Jika valid, script utama akan diunduh otomatis."
})

-- Fungsi verifikasi yang melakukan POST form-data ke server
local function VerifyKeyAndLoad(key)
    if key == "" or not key then
        Rayfield:Notify({ Title = "❌ Key Kosong", Content = "Masukkan key terlebih dahulu.", Duration = 3 })
        return
    end

    local serial = MakeSerial()
    local resource = RandString(32)

    -- Mempersiapkan body sebagai urlencoded (sama format yg dipakai di C++ contoh)
    local form = "game=" .. HttpService:UrlEncode(GAME_ID)
              .. "&version=" .. HttpService:UrlEncode(CLIENT_VERSION)
              .. "&user_key=" .. HttpService:UrlEncode(key)
              .. "&serial=" .. HttpService:UrlEncode(serial)
              .. "&resource=" .. HttpService:UrlEncode(resource)

    Rayfield:Notify({ Title = "🔐 Verifikasi Key", Content = "Sedang memverifikasi key...", Duration = 3 })

    local ok, response = pcall(function()
        -- gunakan HttpPost agar mengirim body; jika server hanya menerima GET, sesuaikan
        return game:HttpPost(VERIFY_URL, form, Enum.HttpContentType.ApplicationUrlEncoded)
    end)

    if not ok then
        Rayfield:Notify({ Title = "❌ Gagal Terhubung", Content = "Tidak dapat menghubungi server: " .. tostring(response), Duration = 4 })
        return
    end

    local decoded
    local ok2, err = pcall(function() decoded = HttpService:JSONDecode(response) end)
    if not ok2 then
        Rayfield:Notify({ Title = "❌ Respon Tidak Valid", Content = "Server mengembalikan data tak terduga.", Duration = 4 })
        warn("Verify decode error:", err, "raw:", response)
        return
    end

    -- Pastikan pola respon sesuai (contoh: { status = true, data = { token=..., rng=..., expired=... } })
    if decoded.status == true then
        local data = decoded.data or {}
        local token = data.token or ""
        local expired = data.expired or ""
        -- opsional: check rng / timestamp jika panel mengirim rng untuk anti-replay
        Rayfield:Notify({ Title = "✅ Key Valid", Content = "Key terverifikasi. Memuat script...", Duration = 2 })

        -- load script utama dari server (pastikan endpoint aman)
        local ok3, mainScript = pcall(function()
            return game:HttpGet(SCRIPT_URL)
        end)
        if ok3 and mainScript and mainScript ~= "" then
            local ok4, errLoad = pcall(function() loadstring(mainScript)() end)
            if not ok4 then
                Rayfield:Notify({ Title = "❌ Gagal Jalankan Script", Content = tostring(errLoad), Duration = 4 })
            end
        else
            Rayfield:Notify({ Title = "❌ Gagal Ambil Script", Content = "Server tidak merespon script utama.", Duration = 4 })
            warn("Failed to get script:", mainScript)
        end
    else
        local reason = decoded.message or decoded.reason or "Key tidak valid"
        Rayfield:Notify({ Title = "❌ Key Tidak Valid", Content = tostring(reason), Duration = 4 })
    end
end

KeyTab:CreateButton({
    Name = "Verifikasi & Load Script",
    Callback = function()
        spawn(function()
            VerifyKeyAndLoad(userKey)
        end)
    end
})

-- Optional: tombol untuk copy link pembelian key / membuka website
KeyTab:CreateButton({
    Name = "Buka Panel Key",
    Callback = function()
        setclipboard("https://velouramlbb.xyz/auth/member")
        Rayfield:Notify({ Title = "Link Disalin", Content = "URL panel disalin ke clipboard.", Duration = 3 })
    end
})
