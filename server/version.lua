
Config = Config or exports["Enzo-GangSiegeX"]:GetConfig()

local function checkForUpdates()
    if not Config.CheckUpdates then return end

    local currentVersion = GetResourceMetadata(GetCurrentResourceName(), "version", 0)
    local url = "https://github.com/enzonami/Enzo-GangSiegeX/releases"

    PerformHttpRequest(url, function(statusCode, response)
        if statusCode ~= 200 then return end

        local latestVersion = response:match('releases/tag/(v[%d%.]+)"')

        if latestVersion and latestVersion ~= "v" .. currentVersion then
            print(string.format("🚨 Update available! Latest: %s (Current: %s)", latestVersion, currentVersion))
        else
            print("✅ Your resource is up-to-date!")
        end
    end, "GET", "", { ["User-Agent"] = "Mozilla/5.0" })
end

checkForUpdates()
