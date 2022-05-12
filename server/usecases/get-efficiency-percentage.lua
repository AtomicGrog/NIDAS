local function exec(efficiencyString)
    local noParagraphMarkString = "100.0"
    local efficiency = "0.0"
    pcall(
        function()
            if (efficiencyString ~= nul) then
                noParagraphMarkString = string.gsub(efficiencyString, "§r", "")
            end
            efficiency = string.sub(noParagraphMarkString, string.find(noParagraphMarkString, "%d+%.*%d*%s%%"))
        end
    )
    return tonumber((string.gsub(efficiency, "%s%%", "")))
end

return exec
