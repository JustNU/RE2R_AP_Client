local Tools = {}

function Tools.ShowGUI()
    local scenario_text = '   (not connected)'

    if Lookups.character and Lookups.scenario then
        scenario_text = "   " .. Lookups.character:gsub("^%l", string.upper) .. " " .. string.upper(Lookups.scenario)
    end

    imgui.begin_window("Archipelago Game Mod", nil,
        8 -- NoScrollbar
        | 64 -- AlwaysAutoResize
    )

    imgui.text_colored("Mod Version Number: ", -10825765)
    imgui.text("   " .. tostring(Manifest.version))
    imgui.new_line()
    imgui.text_colored("AP Character and Scenario:   ", -10825765)
    imgui.text(scenario_text)
    imgui.new_line()
    imgui.text_colored("Credits:", -10825765)
    imgui.text("@Fuzzy")
    imgui.text("   - Mod Dev, Leon A")
    imgui.text("@Solidus")
    imgui.text("   - Claire A & B, Leon B")
    imgui.new_line()

    imgui.end_window()
end

return Tools