local translate = _

local digit_values = {}
for digit = 0, 9 do
    digit_values[#digit_values+1] = tostring(digit)
end

local first_digit_values = { translate("peppie84_hmt_none"), "-" }
for digit = 1, 9 do
    first_digit_values[#first_digit_values+1] = tostring(digit)
end

-- Entwicklungsschalter: true blendet im Abstands-Slider zusätzlich 50 m ein (letzter Eintrag), für kurze Testabstände. Vor einem Release auf false setzen.
local DEV_SHORT_SPACING = false

local auto_spacing_values = {}
for meters = 100, 1000, 100 do
    auto_spacing_values[#auto_spacing_values+1] = meters .. " m"
end
if DEV_SHORT_SPACING then auto_spacing_values[#auto_spacing_values+1] = "50 m" end

function data()
    return {
        description = {
            name = translate("peppie84_hmt_stone_name"),
            description = translate("peppie84_hmt_stone_description"),
            icon = "icons/hmt_s_840x480@2x.tga",
            previewIcon = "icons/hmt_s_840x480_preview.tga",
            attributes = {
				cost = {
                    150,
                    -1
                },
			},
        },
        availability = {
			yearFrom = 1850,
			yearTo = 0,
		},
        menuCategory = {
            categories = {
                {
                    category = "rail_assets",
                    order = 613
                }
            }
        },
        edgeObject = {
            snapToTrack = true
        },
        params = {
            {
                key = "peppie84_hmt_double_sided",
                name = translate("peppie84_hmt_double_sided_name"),
                tooltip = translate("peppie84_hmt_double_sided_tooltip"),
                displayMode = "Horizontal",
                values = { translate("peppie84_hmt_single"), translate("peppie84_hmt_double") },
                defaultIndex = 1
            },
            {
                key = "peppie84_hmt_first_digit",
                name = translate("peppie84_hmt_first_digit_name"),
                tooltip = translate("peppie84_hmt_first_digit_tooltip"),
                displayMode = "Horizontal",
                group = "peppie84_hmt_group_digits",
                values = first_digit_values,
                defaultIndex = 1
            },
            {
                key = "peppie84_hmt_second_digit",
                name = translate("peppie84_hmt_second_digit_name"),
                tooltip = translate("peppie84_hmt_second_digit_tooltip"),
                displayMode = "Horizontal",
                group = "peppie84_hmt_group_digits",
                values = digit_values,
                defaultIndex = 1
            },
            {
                key = "peppie84_hmt_hectometer_digit",
                name = translate("peppie84_hmt_hectometer_digit_name"),
                tooltip = translate("peppie84_hmt_hectometer_digit_tooltip"),
                displayMode = "Horizontal",
                group = "peppie84_hmt_group_digits",
                values = digit_values,
                defaultIndex = 1
            },
            {
                key = "peppie84_hmt_distance",
                name = translate("peppie84_hmt_distance_name"),
                tooltip = translate("peppie84_hmt_distance_tooltip"),
                uiType = "Slider",
                values = { "1.8 m", "2.0 m", "2.1 m", "2.2 m", "2.4 m", "2.6 m", "2.8 m", "3.0 m", "3.2 m", "3.4 m" },
                numbers = { 1.8, 2.0, 2.15, 2.2, 2.4, 2.6, 2.8, 3.0, 3.2, 3.4 },
                defaultIndex = 1
            },
            {
                key = "peppie84_hmt_along_offset",
                name = translate("peppie84_hmt_along_offset_name"),
                tooltip = translate("peppie84_hmt_along_offset_tooltip"),
                uiType = "Slider",
                values = { "-1.5 m", "-1.25 m", "-1.0 m", "-0.75 m", "-0.5 m", "-0.25 m", "0 m", "0.25 m", "0.5 m", "0.75 m", "1.0 m", "1.25 m", "1.5 m" },
                numbers = { -1.5, -1.25, -1.0, -0.75, -0.5, -0.25, 0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5 },
                defaultIndex = 7
            },
            {
                key = "peppie84_hmt_side",
                name = translate("peppie84_hmt_side_name"),
                tooltip = translate("peppie84_hmt_side_tooltip"),
                displayMode = "Horizontal",
                values = { translate("peppie84_hmt_left"), translate("peppie84_hmt_right") },
                defaultIndex = 2
            },
            {
                key = "peppie84_hmt_auto",
                name = translate("peppie84_hmt_auto_name"),
                tooltip = translate("peppie84_hmt_auto_tooltip"),
                group = "peppie84_hmt_auto_placement",
                displayMode = "Horizontal",
                values = { translate("peppie84_hmt_off"), translate("peppie84_hmt_on") },
                defaultIndex = 1
            },
            {
                key = "peppie84_hmt_auto_spacing",
                name = translate("peppie84_hmt_auto_spacing_name"),
                tooltip = translate("peppie84_hmt_auto_spacing_tooltip"),
                group = "peppie84_hmt_auto_placement",
                uiType = "Slider",
                values = auto_spacing_values,
                defaultIndex = 1
            },
            {
                key = "peppie84_hmt_auto_stop_at",
                name = translate("peppie84_hmt_auto_stop_at_name"),
                tooltip = translate("peppie84_hmt_auto_stop_at_tooltip"),
                group = "peppie84_hmt_auto_placement",
                displayMode = "Horizontal",
                uiType = "ComboBox",
                values = {
                    translate("peppie84_hmt_auto_stop_at_switch"),
                    translate("peppie84_hmt_auto_stop_at_tunnel"),
                    translate("peppie84_hmt_auto_stop_at_station"),
                    translate("peppie84_hmt_auto_stop_at_bridge"),
                    translate("peppie84_hmt_auto_stop_at_none")
                },
                numbers = { 2, 3, 4, 5, 1 },
                defaultIndex = 1,
                checkEnabledScript = {
                    fileName = "hectometermarker.script@autoEnabledFn",
                    params = {}
                }
            },
            {
                key = "peppie84_hmt_auto_double_track",
                name = translate("peppie84_hmt_auto_double_track_name"),
                tooltip = translate("peppie84_hmt_auto_double_track_tooltip"),
                group = "peppie84_hmt_auto_placement",
                displayMode = "Horizontal",
                values = { translate("peppie84_hmt_no"), translate("peppie84_hmt_yes") },
                defaultIndex = 1,
                checkEnabledScript = {
                    fileName = "hectometermarker.script@autoEnabledFn",
                    params = {}
                }
            }
        },
        updateScript = {
            fileName = "hectometermarker.script@updateFn",
            params = {
                model = "stone_840x480"
            }
        }
    }
end
