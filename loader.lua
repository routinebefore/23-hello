local gameId = game.GameId
if gameId == 1087859240 then
    pcall(function()
        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/routinebefore/23-hello/refs/heads/main/ROGUE/rogue_ui.lua",
            true
        ))()
    end)
elseif gameId == 7359098240 then
    pcall(function()
        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/routinebefore/23-hello/refs/heads/main/ROGUE_BATTLEGROUNDS/rlb.lua",
            true
        ))()
    end)
end
