-- Gemeinsames Skript aller Hektometer-Konstruktionen in rail_assets.
-- Jede .con.lua wählt ihr Modell über updateScript.params.model.

local MODEL_ROOT = "/rail_assets/models/"
local DIGIT_FAMILY = "hmt_digits/hmt_digits"
local NEGATIVE_SIGN = "-"
local NEGATIVE_FIRST_DIGIT_INDEX = 2

local STONE_840X480_MODEL = "hmt_s_840x480/hmt_s_840x480"
local STONE_840X480_SCALE = 0.8
local STONE_840X480_HEIGHT_ADJUSTMENT = -0.5
local STONE_840X480_DIGIT_SCALE = 1.4 * STONE_840X480_SCALE
local STONE_840X480_DIGIT_FRONT_X = 0.155 * STONE_840X480_SCALE
-- Rückseite: Hektometer-Ziffer sitzt wegen der unregelmäßigen Steinfläche 5,6 mm weiter außen
local STONE_840X480_HECTOMETER_BACK_X = 0.162 * STONE_840X480_SCALE
-- Hektometer-Ziffer (unten) auf beiden Seiten 2 mm weiter außen, damit sie nicht in den Stein clippt und flackert
local STONE_840X480_HECTOMETER_CLEARANCE = 0.002
local STONE_840X480_HECTOMETER_FRONT_X = STONE_840X480_DIGIT_FRONT_X + STONE_840X480_HECTOMETER_CLEARANCE
local STONE_840X480_DIGIT_PAIR_HALF_GAP = 0.09 * STONE_840X480_SCALE
local STONE_840X480_TOP_Z = 0.89 * STONE_840X480_SCALE + STONE_840X480_HEIGHT_ADJUSTMENT
local STONE_840X480_BOTTOM_Z = 0.51 * STONE_840X480_SCALE + STONE_840X480_HEIGHT_ADJUSTMENT

local METER_DIGIT_SCALE = 0.175
local METER_DIGIT_PITCH = 0.0224
local METER_DIGITS_CENTER_Y_OFFSET = 0.114
local BOARD_800X480_SCALE_FACTOR = 1.31
-- Ziffern-Quads (hmt_digits) sind 0,12 x 0,20 m groß und um ihren Ursprung zentriert
local DIGIT_QUAD_WIDTH = 0.12
local DIGIT_QUAD_HALF_HEIGHT = 0.1

local SUPPORT_POLE = "pole"
local SUPPORT_WALL = "wall"
local SUPPORT_NONE = "none"

-- Maße der Tafel-Familien mit Mast bzw. Haltern. Die Ziffernpositionen sind auf das jeweilige Modell abgestimmt.
-- negative_sign: Minus als eigenes Zeichen zwischen den Ziffernreihen; fehlt es, ersetzt das Minus die erste Ziffer.
-- has_third_digit: dreistellige Kilometerzeile (erste, zweite und dritte Stelle); sonst nur erste und zweite Stelle.
-- mount_center_y_offset: Mitte der Halter relativ zur Tafelmitte im Modell (Y-Position der Halter in den _mount.mdl)
local BOARD_610X320_NEGATIVE_SIGN = { z = (2.33 + 2.07) / 2 - 0.005, y_offset = 0.09 }
local BOARD_FAMILIES = {
    board_610x320 = {
        size = "610x320",
        digit_scale = 1.15,
        digit_front_x = 0.054,
        pole_reflector_digit_front_x = 0.0651,
        digit_pair_half_gap = 0.077,
        top_z = 2.33,
        bottom_z = 2.07,
        negative_sign = BOARD_610X320_NEGATIVE_SIGN,
        meter = {
            z = 1.91,
            digit_scale = METER_DIGIT_SCALE,
            pitch = METER_DIGIT_PITCH,
            center_y_offset = METER_DIGITS_CENTER_Y_OFFSET
        },
        mount_center_y_offset = 0.15
    },
    board_610x480 = {
        size = "610x480",
        has_third_digit = true,
        digit_scale = 1.15,
        digit_front_x = 0.054,
        digit_pair_half_gap = 0.077,
        top_z = 2.33,
        bottom_z = 2.07,
        negative_sign = BOARD_610X320_NEGATIVE_SIGN,
        meter = {
            z = 1.91,
            digit_scale = METER_DIGIT_SCALE,
            pitch = METER_DIGIT_PITCH,
            center_y_offset = 0.17
        },
        mount_center_y_offset = 0.225
    },

    board_800x480 = {
        size = "800x480",
        digit_scale = 1.75,
        digit_front_x = 0.054,
        digit_pair_half_gap = 0.115,
        top_z = 2.385,
        bottom_z = 2.044,
        meter = {
            z = 1.835,
            digit_scale = METER_DIGIT_SCALE * BOARD_800X480_SCALE_FACTOR,
            pitch = METER_DIGIT_PITCH * BOARD_800X480_SCALE_FACTOR,
            center_y_offset = METER_DIGITS_CENTER_Y_OFFSET * BOARD_800X480_SCALE_FACTOR
        },
        mount_center_y_offset = 0.225
    },

    -- 800x480-Höhen mit dreistelliger KM-Zeile; Meter-Offset skaliert wie bei 610x480 (0,17) mit dem 800er-Faktor, plus 2 cm
    board_800x720 = {
        size = "800x720",
        has_third_digit = true,
        digit_scale = 1.75,
        digit_front_x = 0.054,
        digit_pair_half_gap = 0.115,
        top_z = 2.385,
        bottom_z = 2.044,
        meter = {
            z = 1.835,
            digit_scale = METER_DIGIT_SCALE * BOARD_800X480_SCALE_FACTOR,
            pitch = METER_DIGIT_PITCH * BOARD_800X480_SCALE_FACTOR,
            center_y_offset = 0.17 * BOARD_800X480_SCALE_FACTOR + 0.02
        },
        mount_center_y_offset = 0.225
    },

    -- Schmale Tafel (Platte 0,30 x 0,395 m) neben dem Mast, ohne Reflektor und Wandhalter. Die Platte ist beidseitig
    -- gleich; „Doppelt“ setzt deshalb nur Ziffern auf die Rückseite. Bei Seite „Links“ wird die Baugruppe um 180°
    -- gedreht, damit die Platte wie bei „Rechts“ auf der Gleisseite des Masts hängt (siehe build_board).
    -- plate_center_y: Plattenmitte relativ zum Mast; plate_x: Plattenflächen (Rückseite/Vorderseite) im Modell
    -- inline_meter: Hektometer-Ziffer und zweistellige Meter-Anzeige stehen in einer Zeile (Meter unten bündig);
    -- ohne Meter-Anzeige steht die Hektometer-Ziffer mittig
    board_200x300 = {
        size = "200x300",
        supports = { SUPPORT_POLE, SUPPORT_NONE },
        no_reflector = true,
        fixed_model_prefix = "t",
        plate_center_y = -0.188166,
        plate_x = { min = -0.004, max = 0.006 },
        digit_clearance = 0.002,
        digit_scale = 0.67,
        digit_pair_half_gap = 0.048,
        top_z = 2.333,
        bottom_z = 2.174,
        inline_meter = {
            digit_scale = 0.415,
            pitch = 0.06,
            gap = 0.016
        }
    }
}
-- Index 1 = Tief, 2 = Default, 3 = Hoch (nur ohne Mast); Höhenversatz in Metern
local POLE_HEIGHT_ADJUSTMENTS = { -1.0, 0 }
local MOUNTED_HEIGHT_ADJUSTMENTS = { -1.0, 0, 1.0 }
-- Stein (peppie84_hmt_stone_height): Index 1 = Default, 2 = Hoch
local STONE_HEIGHT_ADJUSTMENTS = { 0, 0.3 }

-- Index 1 = Nein, 2 = Ja
local NO_INDEX = 1
local YES_INDEX = 2
local LEFT_INDEX = 1
local METER_DISPLAY_ON_INDEX = 2
local AUTO_ON_INDEX = 2
-- Befestigung (peppie84_hmt_mounting): Index 1 = Mast, 2 = Wand, 3 = Ohne
local MOUNTING_SUPPORTS = { SUPPORT_POLE, SUPPORT_WALL, SUPPORT_NONE }

local PARAM_DEFAULTS = {
    peppie84_hmt_mounting = 1,
    peppie84_hmt_first_digit = 1,
    peppie84_hmt_second_digit = 1,
    peppie84_hmt_third_digit = 1,
    peppie84_hmt_hectometer_digit = 1,
    peppie84_hmt_double_sided = 1,
    peppie84_hmt_side = 2,
    peppie84_hmt_reflector = NO_INDEX,
    peppie84_hmt_height = 2,
    peppie84_hmt_height_mounted = 2,
    peppie84_hmt_stone_height = 1,
    peppie84_hmt_meter_display = 1,
    peppie84_hmt_meter_first_digit = 1,
    peppie84_hmt_meter_second_digit = 1
}

local IDENTITY_TRANSFORM = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
local REVERSED_TRANSFORM = { -1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }

local function model_transform(x, y, z, is_reverse, scale)
    local source = is_reverse and REVERSED_TRANSFORM or IDENTITY_TRANSFORM
    local transform = {}
    for index = 1, 16 do
        transform[index] = source[index] * (index <= 12 and (scale or 1) or 1)
    end
    transform[13] = x
    transform[14] = y
    transform[15] = z
    return transform
end

local function append_model(models, name, x, y, z, is_reverse, scale)
    models[#models+1] = {
        id = MODEL_ROOT .. name .. ".mdl",
        transf = model_transform(x, y, z, is_reverse, scale)
    }
end

local function decode_first_digit(index)
    if index <= NEGATIVE_FIRST_DIGIT_INDEX then
        return nil
    end
    return index - NEGATIVE_FIRST_DIGIT_INDEX
end

local function decode_other_digit(index)
    return index - 1
end

-- Zweite Stelle dreistelliger Tafeln: Index 1 = keine, 2-11 = 0-9
local function decode_optional_digit(index)
    if index <= 1 then
        return nil
    end
    return index - 2
end

local function append_digit(models, digit, x, y, z, is_double_sided, reverse_x, center_y, scale)
    if digit == nil then
        return
    end

    local model_name = DIGIT_FAMILY .. tostring(digit)
    append_model(models, model_name, x, y, z, false, scale)
    if is_double_sided then
        append_model(models, model_name, reverse_x, 2 * (center_y or y) - y, z, true, scale)
    end
end

local function append_pair(models, first_digit, second_digit, x, center_y, z, gap, is_double_sided, reverse_x, scale)
    if first_digit ~= nil and second_digit ~= nil then
        append_digit(models, first_digit, x, center_y - gap, z, is_double_sided, reverse_x, center_y, scale)
        append_digit(models, second_digit, x, center_y + gap, z, is_double_sided, reverse_x, center_y, scale)
    elseif first_digit ~= nil then
        append_digit(models, first_digit, x, center_y, z, is_double_sided, reverse_x, center_y, scale)
    elseif second_digit ~= nil then
        append_digit(models, second_digit, x, center_y, z, is_double_sided, reverse_x, center_y, scale)
    end
end

-- Vorhandene Stellen werden mit dem Abstand pitch mittig in der Zeile angeordnet
local function append_triple(models, first_digit, second_digit, third_digit, x, center_y, z, pitch, is_double_sided,
                             reverse_x, scale)
    local digits = {}
    for _, digit in ipairs({ first_digit or false, second_digit or false, third_digit or false }) do
        if digit ~= false then
            digits[#digits+1] = digit
        end
    end
    for index, digit in ipairs(digits) do
        local y = center_y + (index - (#digits + 1) / 2) * pitch
        append_digit(models, digit, x, y, z, is_double_sided, reverse_x, center_y, scale)
    end
end

local function build_stone_840x480(params)
    local offset = params.peppie84_hmt_distance
    local is_double_sided = params.peppie84_hmt_double_sided == 2
    local first_digit_index = params.peppie84_hmt_first_digit
    local first_digit = decode_first_digit(first_digit_index)
    local second_digit = decode_other_digit(params.peppie84_hmt_second_digit)
    local hectometer_digit = decode_other_digit(params.peppie84_hmt_hectometer_digit)
    local models = {}
    local height = STONE_HEIGHT_ADJUSTMENTS[tonumber(params.peppie84_hmt_stone_height) or 1] or 0

    append_model(models, STONE_840X480_MODEL, 0, offset, STONE_840X480_HEIGHT_ADJUSTMENT + height, false, STONE_840X480_SCALE)
    append_pair(models, first_digit_index == NEGATIVE_FIRST_DIGIT_INDEX and NEGATIVE_SIGN or first_digit,
        second_digit, STONE_840X480_DIGIT_FRONT_X, offset, STONE_840X480_TOP_Z + height, STONE_840X480_DIGIT_PAIR_HALF_GAP,
        is_double_sided, -STONE_840X480_DIGIT_FRONT_X, STONE_840X480_DIGIT_SCALE)
    append_digit(models, hectometer_digit, STONE_840X480_HECTOMETER_FRONT_X, offset, STONE_840X480_BOTTOM_Z + height, is_double_sided,
        -(STONE_840X480_HECTOMETER_BACK_X + STONE_840X480_HECTOMETER_CLEARANCE), offset, STONE_840X480_DIGIT_SCALE)
    return models
end

local function append_meter_display(models, meter, digits, x, center_y, z, is_double_sided, reverse_x)
    local digits_center_y = center_y + meter.center_y_offset
    for index, digit in ipairs(digits) do
        local digit_y = digits_center_y + (index - 2) * meter.pitch
        append_digit(models, digit, x, digit_y, z, is_double_sided, reverse_x, center_y, meter.digit_scale)
    end
end

local function param_or_default(params, key)
    local value = tonumber(params[key]) or 0
    return value < 1 and PARAM_DEFAULTS[key] or value
end

local function support_kind(params, family)
    local supports = family and family.supports or MOUNTING_SUPPORTS
    return supports[param_or_default(params, "peppie84_hmt_mounting")] or SUPPORT_POLE
end

local function board_variant(family, params)
    local support = support_kind(params, family)
    local has_pole = support == SUPPORT_POLE
    local has_reflector = not family.no_reflector and param_or_default(params, "peppie84_hmt_reflector") == YES_INDEX
    local prefix = family.fixed_model_prefix or (has_pole and "t" or "tl")
    local name = "hmt_" .. prefix .. (has_reflector and "r" or "") .. "_" .. family.size
    local path = name .. "/" .. name
    return {
        board_model = path .. "_board",
        support_model = support ~= SUPPORT_NONE and (path .. (has_pole and "_pole" or "_mount")) or nil,
        support = support,
        has_pole = has_pole,
        digit_front_x = (has_pole and has_reflector and family.pole_reflector_digit_front_x) or family.digit_front_x
    }
end

-- Hektometer-Ziffer und optionale Meter-Anzeige in einer Zeile: Die Gruppe steht mittig, die kleineren Meter-Ziffern
-- sitzen rechts neben der Hektometer-Ziffer und schließen unten mit ihr ab. Ohne Meter-Ziffern steht die Hektometer-Ziffer mittig.
local function append_inline_meter_row(models, family, hectometer_digit, meter_digits, x, center_y, row_z, is_double_sided,
                                       reverse_x)
    local row = family.inline_meter
    local large_width = DIGIT_QUAD_WIDTH * family.digit_scale
    local small_width = DIGIT_QUAD_WIDTH * row.digit_scale
    local group_width = large_width
    if #meter_digits > 0 then
        group_width = large_width + row.gap + (#meter_digits - 1) * row.pitch + small_width
    end
    local left = center_y - group_width / 2
    append_digit(models, hectometer_digit, x, left + large_width / 2, row_z, is_double_sided, reverse_x, center_y,
        family.digit_scale)
    local baseline = row_z - DIGIT_QUAD_HALF_HEIGHT * family.digit_scale
    for index, digit in ipairs(meter_digits) do
        local digit_y = left + large_width + row.gap + small_width / 2 + (index - 1) * row.pitch
        append_digit(models, digit, x, digit_y, baseline + DIGIT_QUAD_HALF_HEIGHT * row.digit_scale, is_double_sided,
            reverse_x, center_y, row.digit_scale)
    end
end

local function build_board(family, params)
    local offset = params.peppie84_hmt_distance
    local is_double_sided = params.peppie84_hmt_double_sided == 2
    local variant = board_variant(family, params)
    local height = variant.has_pole and POLE_HEIGHT_ADJUSTMENTS[params.peppie84_hmt_height]
        or MOUNTED_HEIGHT_ADJUSTMENTS[params.peppie84_hmt_height_mounted]
    local front_x = variant.digit_front_x
    local back_x = front_x and -front_x
    -- Bei Familien mit Platte neben dem Mast wird die Baugruppe bei „Links“ gedreht (Platte bleibt auf der Gleisseite);
    -- die Ziffern der Vorderseite liegen dann auf der Seite +x des gedrehten Modells
    local is_assembly_rotated = family.plate_center_y ~= nil and params.peppie84_hmt_side == LEFT_INDEX
    local digits_center_y = offset
    if family.plate_center_y then
        digits_center_y = offset + (is_assembly_rotated and -family.plate_center_y or family.plate_center_y)
        local plate_x_min = is_assembly_rotated and -family.plate_x.max or family.plate_x.min
        local plate_x_max = is_assembly_rotated and -family.plate_x.min or family.plate_x.max
        front_x = plate_x_max + family.digit_clearance
        back_x = plate_x_min - family.digit_clearance
    end
    local first_digit_index = params.peppie84_hmt_first_digit
    local is_negative = first_digit_index == NEGATIVE_FIRST_DIGIT_INDEX
    local first_digit = decode_first_digit(first_digit_index)
    local second_digit = (family.has_third_digit and decode_optional_digit or decode_other_digit)(params.peppie84_hmt_second_digit)
    local hectometer_digit = decode_other_digit(params.peppie84_hmt_hectometer_digit)
    local models = {}
    local mount_shift = 2 * (family.mount_center_y_offset or 0)
    local support_y = offset
    if variant.support == SUPPORT_WALL and params.peppie84_hmt_side == LEFT_INDEX then
        support_y = offset - mount_shift
    end
    if variant.support_model then
        append_model(models, variant.support_model, 0, support_y, height, false)
    end
    append_model(models, variant.board_model, 0, offset, height, is_assembly_rotated)
    if is_double_sided and not family.plate_center_y then
        append_model(models, variant.board_model, 0, offset, height, true)
        if variant.support == SUPPORT_WALL then
            append_model(models, variant.support_model, 0, support_y + mount_shift, height, true)
        end
    end

    local negative_sign = family.negative_sign
    local row_first_digit = first_digit
    if is_negative and not negative_sign then
        row_first_digit = NEGATIVE_SIGN
    end
    local top_z = family.top_z + height
    if family.has_third_digit then
        append_triple(models, row_first_digit, second_digit, decode_other_digit(params.peppie84_hmt_third_digit), front_x,
            digits_center_y, top_z, 2 * family.digit_pair_half_gap, is_double_sided, back_x, family.digit_scale)
    else
        append_pair(models, row_first_digit, second_digit, front_x, digits_center_y, top_z, family.digit_pair_half_gap,
            is_double_sided, back_x, family.digit_scale)
    end
    if family.inline_meter then
        local meter_digits = {}
        if params.peppie84_hmt_meter_display == METER_DISPLAY_ON_INDEX then
            meter_digits = {
                decode_other_digit(params.peppie84_hmt_meter_first_digit),
                decode_other_digit(params.peppie84_hmt_meter_second_digit)
            }
        end
        append_inline_meter_row(models, family, hectometer_digit, meter_digits, front_x, digits_center_y,
            family.bottom_z + height, is_double_sided, back_x)
        return models
    end
    append_digit(models, hectometer_digit, front_x, digits_center_y, family.bottom_z + height, is_double_sided, back_x,
        digits_center_y, family.digit_scale)
    if is_negative and negative_sign then
        append_digit(models, NEGATIVE_SIGN, front_x, digits_center_y - negative_sign.y_offset, negative_sign.z + height,
            is_double_sided, back_x, digits_center_y, family.digit_scale)
    end
    if params.peppie84_hmt_meter_display == METER_DISPLAY_ON_INDEX then
        append_meter_display(models, family.meter, {
            hectometer_digit,
            decode_other_digit(params.peppie84_hmt_meter_first_digit),
            decode_other_digit(params.peppie84_hmt_meter_second_digit)
        }, front_x, digits_center_y, family.meter.z + height, is_double_sided, back_x)
    end
    return models
end

local MODEL_BUILDERS = {
    stone_840x480 = build_stone_840x480
}
for name, family in pairs(BOARD_FAMILIES) do
    MODEL_BUILDERS[name] = function (params)
        return build_board(family, params)
    end
end

local function normalize_params(params)
    local filled = {}
    for key, value in pairs(params or {}) do
        filled[key] = value
    end
    for key in pairs(PARAM_DEFAULTS) do
        filled[key] = param_or_default(filled, key)
    end
    if (tonumber(filled.peppie84_hmt_distance) or 0) <= 0 then
        filled.peppie84_hmt_distance = 1.8
    end
    return filled
end

local function orient_models(params, models)
    local pivot_y = params.peppie84_hmt_distance
    local is_left = params.peppie84_hmt_side == 1
    -- Positiv verschiebt in Pfeilrichtung der Kante
    local along_offset = tonumber(params.peppie84_hmt_along_offset) or 0
    for _, model in ipairs(models) do
        local source = model.transf
        model.transf = {
            -source[1],
            -source[2],
            source[3],
            source[4],
            -source[5],
            -source[6],
            source[7],
            source[8],
            source[9],
            source[10],
            source[11],
            source[12],
            -source[13] + along_offset,
            is_left and (2 * pivot_y - source[14]) or -source[14],
            source[15],
            source[16]
        }
    end
    return models
end

function data()
    return {
        heightEnabledFn = function (_captureParams, params)
            return support_kind(params) == SUPPORT_POLE and "Enabled" or "Hidden"
        end,
        heightMountedEnabledFn = function (_captureParams, params)
            return support_kind(params) == SUPPORT_POLE and "Hidden" or "Enabled"
        end,
        meterDisplayEnabledFn = function (_captureParams, params)
            return params.peppie84_hmt_meter_display == METER_DISPLAY_ON_INDEX and "Enabled" or "Hidden"
        end,
        autoEnabledFn = function (_captureParams, params)
            return params.peppie84_hmt_auto == AUTO_ON_INDEX and "Enabled" or "Hidden"
        end,
        updateFn = function (captureParams, params)
            local build_models = MODEL_BUILDERS[captureParams and captureParams.model]
            assert(build_models, "unknown marker model: " .. tostring(captureParams and captureParams.model))
            params = normalize_params(params)
            local edge_models = {}
            for index, model in ipairs(orient_models(params, build_models(params))) do
                edge_models[index] = { edgeOffset = 0, model = model }
            end

            return {
                signal = {
                    soundevent = "",
                    type = "WAYPOINT"
                },
                edgeModels = edge_models
            }
        end
    }
end
