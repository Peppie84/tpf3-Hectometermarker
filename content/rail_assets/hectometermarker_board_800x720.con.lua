local translate = _

local digit_values = {}
for digit = 0, 9 do
    digit_values[#digit_values+1] = tostring(digit)
end

local first_digit_values = { translate("peppie84_hmt_none"), "-" }
for digit = 1, 9 do
    first_digit_values[#first_digit_values+1] = tostring(digit)
end

local second_digit_values = { translate("peppie84_hmt_none") }
for digit = 0, 9 do
    second_digit_values[#second_digit_values+1] = tostring(digit)
end

local auto_spacing_values = {}
for meters = 100, 1000, 100 do
    auto_spacing_values[#auto_spacing_values+1] = meters .. " m"
end

function data()
    return {
        description = {
            name = translate("peppie84_hmt_board_800x720_name"),
            description = translate("peppie84_hmt_board_description"),
            icon = "icons/hmt_t_800x720@2x.tga",
            previewIcon = "icons/hmt_t_800x720_preview.tga",
            attributes = {
				cost = {
                    450,
                    -1
                },
			},
        },
        availability = {
			yearFrom = 1975,
			yearTo = 0,
		},
        menuCategory = {
            categories = {
                {
                    category = "rail_assets",
                    order = 617
                }
            }
        },
        edgeObject = {
            snapToTrack = true
        },
        params = {
            {
                key = "peppie84_hmt_mounting",
                name = translate("peppie84_hmt_mounting_name"),
                displayMode = "Horizontal",
                values = {
                    translate("peppie84_hmt_mounting_pole"),
                    translate("peppie84_hmt_mounting_wall"),
                    translate("peppie84_hmt_mounting_none")
                },
                defaultIndex = 1
            },
            {
                key = "peppie84_hmt_reflector",
                name = translate("peppie84_hmt_reflector_name"),
                displayMode = "Horizontal",
                values = { translate("peppie84_hmt_no"), translate("peppie84_hmt_yes") },
                defaultIndex = 1
            },
            {
                key = "peppie84_hmt_height",
                name = translate("peppie84_hmt_height_name"),
                displayMode = "Horizontal",
                values = {
                    translate("peppie84_hmt_height_low"),
                    translate("peppie84_hmt_height_default")
                },
                defaultIndex = 2,
                checkEnabledScript = {
                    fileName = "hectometermarker.script@heightEnabledFn",
                    params = {}
                }
            },
            {
                key = "peppie84_hmt_height_mounted",
                name = translate("peppie84_hmt_height_name"),
                displayMode = "Horizontal",
                values = {
                    translate("peppie84_hmt_height_low"),
                    translate("peppie84_hmt_height_default"),
                    translate("peppie84_hmt_height_high")
                },
                defaultIndex = 2,
                checkEnabledScript = {
                    fileName = "hectometermarker.script@heightMountedEnabledFn",
                    params = {}
                }
            },
            {
                key = "peppie84_hmt_double_sided",
                name = translate("peppie84_hmt_double_sided_name"),
                displayMode = "Horizontal",
                values = { translate("peppie84_hmt_single"), translate("peppie84_hmt_double") },
                defaultIndex = 1
            },
            {
                key = "peppie84_hmt_first_digit",
                name = translate("peppie84_hmt_first_digit_name"),
                displayMode = "Horizontal",
                group = "peppie84_hmt_group_digits",
                values = first_digit_values,
                defaultIndex = 1
            },
            {
                key = "peppie84_hmt_second_digit",
                name = translate("peppie84_hmt_second_digit_name"),
                displayMode = "Horizontal",
                group = "peppie84_hmt_group_digits",
                values = second_digit_values,
                defaultIndex = 1
            },
            {
                key = "peppie84_hmt_third_digit",
                name = translate("peppie84_hmt_third_digit_name"),
                displayMode = "Horizontal",
                group = "peppie84_hmt_group_digits",
                values = digit_values,
                defaultIndex = 1
            },
            {
                key = "peppie84_hmt_hectometer_digit",
                name = translate("peppie84_hmt_hectometer_digit_name"),
                displayMode = "Horizontal",
                group = "peppie84_hmt_group_digits",
                values = digit_values,
                defaultIndex = 1
            },
            {
                key = "peppie84_hmt_meter_display",
                name = translate("peppie84_hmt_meter_display_name"),
                displayMode = "Horizontal",
                tooltip = translate("peppie84_hmt_meter_display_tooltip"),
                group = "peppie84_hmt_meter_display",
                values = { translate("peppie84_hmt_meter_display_off"), translate("peppie84_hmt_meter_display_on") },
                defaultIndex = 1
            },
            {
                key = "peppie84_hmt_meter_first_digit",
                name = translate("peppie84_hmt_meter_first_digit_name"),
                group = "peppie84_hmt_meter_display",
                displayMode = "Horizontal",
                values = digit_values,
                defaultIndex = 1,
                checkEnabledScript = {
                    fileName = "hectometermarker.script@meterDisplayEnabledFn",
                    params = {}
                }
            },
            {
                key = "peppie84_hmt_meter_second_digit",
                name = translate("peppie84_hmt_meter_second_digit_name"),
                group = "peppie84_hmt_meter_display",
                displayMode = "Horizontal",
                values = digit_values,
                defaultIndex = 1,
                checkEnabledScript = {
                    fileName = "hectometermarker.script@meterDisplayEnabledFn",
                    params = {}
                }
            },
            {
                key = "peppie84_hmt_distance",
                name = translate("peppie84_hmt_distance_name"),
                uiType = "Slider",
                values = { "1.8 m", "2.0 m", "2.1 m", "2.2 m", "2.4 m", "2.6 m", "2.8 m", "3.0 m", "3.2 m", "3.4 m" },
                numbers = { 1.8, 2.0, 2.15, 2.2, 2.4, 2.6, 2.8, 3.0, 3.2, 3.4 },
                defaultIndex = 1
            },
            {
                key = "peppie84_hmt_along_offset",
                name = translate("peppie84_hmt_along_offset_name"),
                uiType = "Slider",
                values = { "-1.5 m", "-1.25 m", "-1.0 m", "-0.75 m", "-0.5 m", "-0.25 m", "0 m", "0.25 m", "0.5 m", "0.75 m", "1.0 m", "1.25 m", "1.5 m" },
                numbers = { -1.5, -1.25, -1.0, -0.75, -0.5, -0.25, 0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5 },
                defaultIndex = 7
            },
            {
                key = "peppie84_hmt_side",
                name = translate("peppie84_hmt_side_name"),
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
            }
        },
        updateScript = {
            fileName = "hectometermarker.script@updateFn",
            params = {
                model = "board_800x720"
            }
        }
    }
end
