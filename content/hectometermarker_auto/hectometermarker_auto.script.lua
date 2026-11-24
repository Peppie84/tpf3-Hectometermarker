local AUTO_KEY = "peppie84_hmt_auto"
local SPACING_KEY = "peppie84_hmt_auto_spacing"
local STOP_AT_KEY = "peppie84_hmt_auto_stop_at"
local DOUBLE_TRACK_KEY = "peppie84_hmt_auto_double_track"
local SIDE_KEY = "peppie84_hmt_side"
local MODEL_KEY = "peppie84_hmt_model_type"
local FIRST_DIGIT_KEY = "peppie84_hmt_first_digit"
local SECOND_DIGIT_KEY = "peppie84_hmt_second_digit"
local THIRD_DIGIT_KEY = "peppie84_hmt_third_digit"
local HECTOMETER_DIGIT_KEY = "peppie84_hmt_hectometer_digit"
local WIDE_HECTOMETER_DIGIT_KEY = "peppie84_hmt_wide_hectometer_digit"
local METER_DISPLAY_KEY = "peppie84_hmt_meter_display"
local METER_FIRST_KEY = "peppie84_hmt_meter_first_digit"
local METER_SECOND_KEY = "peppie84_hmt_meter_second_digit"
local MAX_EDGES = 1000
local MAX_JOBS = 1000
local STATE_VERSION = 1
local TRACK_SEGMENT_TYPE = 1
local FIRST_PLACEHOLDER_ENTITY = -400000000
local WIDE_MODEL_TYPES = { [8] = true }
local METER_MODEL_TYPES = { [1] = true, [2] = true, [3] = true, [4] = true, [6] = true, [7] = true, [8] = true }
local METER_DISPLAY_ON_INDEX = 2
local NEGATIVE_FIRST_INDEX = 2
local FIRST_DIGIT_INDEX_OFFSET = 2
local SPACING_METERS = { 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 50 }
local DEFAULT_SPACING_INDEX = 1
local STOP_TARGET_SWITCH = 2
local STOP_TARGET_TUNNEL = 3
local STOP_TARGET_STATION = 4
local STOP_TARGET_BRIDGE = 5
local STOP_TARGET_REASONS = {
	[STOP_TARGET_SWITCH] = "target switch",
	[STOP_TARGET_TUNNEL] = "target tunnel",
	[STOP_TARGET_STATION] = "target station",
	[STOP_TARGET_BRIDGE] = "target bridge",
}
local DOUBLE_TRACK_ON_INDEX = 2
local LEFT_SIDE_INDEX = 1
local NEIGHBOUR_SEARCH_RADIUS = 12
local NEIGHBOUR_MIN_DISTANCE = 2
local NEIGHBOUR_MAX_DISTANCE = 9
local NEIGHBOUR_MAX_HEIGHT_DIFFERENCE = 3
local NEIGHBOUR_MAX_ALONG_OFFSET = 1.5
local NEIGHBOUR_MIN_PARALLEL = 0.9
local NEIGHBOUR_LOCATE_STEPS = 40
local NEIGHBOUR_REFINE_STEPS = 8
local unpack_values = table.unpack or unpack
local VALUE_EPSILON = 1e-9
local TANGENT_TIE_EPSILON = 1e-3
local MAX_SHIFT_METERS = 15
local SHIFT_STEP_METERS = 15
local MIN_EDGE_MARGIN_METERS = 0.5
local PROGRESS_KEY = "peppie84_hmt_auto_progress"
local PROGRESS_STEP_PERCENT = 10
local PROGRESS_VALIDATION_SHARE = 60
local PROGRESS_FILTER_SHARE = 35
local PROGRESS_MIN_MARKERS = 30

local function log_message(message)
	debugPrint("[hectometermarker_auto] " .. tostring(message))
end

local function combo_box_index(raw_value, default_index)
	local index_value = tonumber(raw_value) or 0
	if index_value < 1 then return default_index end
	return math.floor(index_value)
end


local function is_wide_model(params)
	if params[MODEL_KEY] == nil then return params[THIRD_DIGIT_KEY] ~= nil end
	local model_type = combo_box_index(params[MODEL_KEY], 1)
	return WIDE_MODEL_TYPES[model_type] == true
end

local function hectometer_digit_key(params)
	if params[MODEL_KEY] == nil then return HECTOMETER_DIGIT_KEY end
	return is_wide_model(params) and WIDE_HECTOMETER_DIGIT_KEY or THIRD_DIGIT_KEY
end

local function second_digit_index_offset(params)
	if params[MODEL_KEY] == nil and params[THIRD_DIGIT_KEY] ~= nil then return 2 end
	return 1
end

local function value_from_params(params)
	local first_index = combo_box_index(params[FIRST_DIGIT_KEY], 1)
	local is_negative = first_index == NEGATIVE_FIRST_INDEX
	local first_digit = math.max(first_index - FIRST_DIGIT_INDEX_OFFSET, 0)
	local second_digit = math.max(combo_box_index(params[SECOND_DIGIT_KEY], 1) - second_digit_index_offset(params), 0)
	local magnitude = first_digit * 10 + second_digit
	if is_wide_model(params) then
		magnitude = magnitude * 10 + combo_box_index(params[THIRD_DIGIT_KEY], 1) - 1
	end
	magnitude = magnitude * 10 + combo_box_index(params[hectometer_digit_key(params)], 1) - 1
	return is_negative and -magnitude or magnitude
end

local function name_prefix()
	local succeeded, translated_text = pcall(_, "peppie84_hmt_section_name")
	if succeeded and type(translated_text) == "string" and translated_text ~= "" and translated_text ~= "peppie84_hmt_section_name" then
		return translated_text
	end
	return "Hektometertafel"
end

local function is_meter_display_on(params)
	if params[MODEL_KEY] == nil then return params[METER_DISPLAY_KEY] == METER_DISPLAY_ON_INDEX end
	local model_type = combo_box_index(params[MODEL_KEY], 1)
	return METER_MODEL_TYPES[model_type] == true and params[METER_DISPLAY_KEY] == METER_DISPLAY_ON_INDEX
end

local function meter_from_params(params)
	local tens = math.min(combo_box_index(params[METER_FIRST_KEY], 1) - 1, 9)
	local units = math.min(combo_box_index(params[METER_SECOND_KEY], 1) - 1, 9)
	return tens * 10 + units
end

local function meter_suffix(params)
	if not is_meter_display_on(params) then return "" end
	return string.format("%02d", meter_from_params(params))
end

local function marker_name(params)
	local value = value_from_params(params)
	local magnitude = math.abs(value)
	local sign = value < 0 and "-" or ""
	return string.format("%s %s%d,%d%s", name_prefix(), sign, math.floor(magnitude / 10), magnitude % 10, meter_suffix(params))
end

local function max_value(params)
	return is_wide_model(params) and 9999 or 999
end

local function shift_meters_in_value(base_params, value, shift_meters)
	local sign = value < 0 and -1 or 1
	local total_meters = sign * (math.abs(value) * 100 + meter_from_params(base_params)) + shift_meters
	local magnitude = math.abs(total_meters)
	local shifted_value = (total_meters < 0 and -1 or 1) * math.floor(magnitude / 100)
	if math.abs(shifted_value) > max_value(base_params) then return value, 99 end
	return shifted_value, magnitude % 100
end

local function params_for_value(base_params, value, shift_meters)
	local new_params = {}
	for key, param_value in pairs(base_params) do new_params[key] = param_value end
	new_params[AUTO_KEY] = 1
	if shift_meters and shift_meters ~= 0 and is_meter_display_on(base_params) then
		local shifted_meter
		value, shifted_meter = shift_meters_in_value(base_params, value, shift_meters)
		new_params[METER_FIRST_KEY] = math.floor(shifted_meter / 10) + 1
		new_params[METER_SECOND_KEY] = shifted_meter % 10 + 1
	end
	local is_negative = value < 0
	local magnitude = math.abs(value)
	local hectometer = magnitude % 10
	local kilometers = math.floor(magnitude / 10)
	local is_wide = is_wide_model(base_params)
	if is_negative then
		new_params[FIRST_DIGIT_KEY] = NEGATIVE_FIRST_INDEX
	else
		local first_digit = math.floor(kilometers / (is_wide and 100 or 10))
		new_params[FIRST_DIGIT_KEY] = first_digit > 0 and first_digit + FIRST_DIGIT_INDEX_OFFSET or 1
	end
	if is_wide then
		local second_index_offset = second_digit_index_offset(base_params)
		-- Führende Null der zweiten Stelle entfällt, wenn "keine" zur Auswahl steht (Index 1)
		local has_second_digit = second_index_offset == 1 or kilometers >= 10
		new_params[SECOND_DIGIT_KEY] = has_second_digit and math.floor(kilometers / 10) % 10 + second_index_offset or 1
		new_params[THIRD_DIGIT_KEY] = kilometers % 10 + 1
	else
		new_params[SECOND_DIGIT_KEY] = kilometers % 10 + 1
	end
	new_params[hectometer_digit_key(base_params)] = hectometer + 1
	return new_params
end

local function distance_from_params(params)
	if type(params) ~= "table" or params[AUTO_KEY] ~= 2 then return nil end
	local spacing_index = math.min(combo_box_index(params[SPACING_KEY], DEFAULT_SPACING_INDEX), #SPACING_METERS)
	return SPACING_METERS[spacing_index]
end

local function stop_target_from_params(params)
	if type(params) ~= "table" then return nil end
	local stop_target = combo_box_index(params[STOP_AT_KEY], 1)
	return STOP_TARGET_REASONS[stop_target] and stop_target or nil
end

local function double_track_from_params(params)
	return type(params) == "table" and params[DOUBLE_TRACK_KEY] == DOUBLE_TRACK_ON_INDEX
end

local function is_hectometer_marker(entity)
	local edge_object = api.engine.getComponent(entity, api.type.ComponentType.EDGE_OBJECT)
	return edge_object ~= nil and type(edge_object.params) == "table" and edge_object.params[FIRST_DIGIT_KEY] ~= nil
end

local function find_markers_on_edge(edge_entity)
	local transport_network = api.engine.getComponent(edge_entity, api.type.ComponentType.TRANSPORT_NETWORK)
	local markers_by_entity = {}
	local total_length = 0
	if not transport_network then return markers_by_entity, total_length end
	local section_ranges = {}
	for section_index, network_edge in ipairs(transport_network.edges) do
		local section_length = network_edge.geometry.length
		section_ranges[section_index] = { start_position = total_length, end_position = total_length + section_length }
		total_length = total_length + section_length
	end
	for section_index, section_range in ipairs(section_ranges) do
		local edge_id = api.type.EdgeId.new(edge_entity, section_index - 1)
		local forward_signal = api.engine.system.signalSystem.getSignal(edge_id, false)
		local reverse_signal = api.engine.system.signalSystem.getSignal(edge_id, true)
		local forward_signal_entity = forward_signal and forward_signal.entity or -1
		local reverse_signal_entity = reverse_signal and reverse_signal.entity or -1
		if forward_signal_entity > 0 and is_hectometer_marker(forward_signal_entity) then
			markers_by_entity[forward_signal_entity] = { position = section_range.end_position, is_left = true }
		end
		if reverse_signal_entity > 0 and is_hectometer_marker(reverse_signal_entity) then
			markers_by_entity[reverse_signal_entity] = { position = section_range.start_position, is_left = false }
		end
	end
	return markers_by_entity, total_length
end

local function sort_markers_by_position(markers, is_descending)
	local sorted_markers = {}
	for _, marker in pairs(markers) do sorted_markers[#sorted_markers + 1] = marker end
	table.sort(sorted_markers, function(first_marker, second_marker)
		if is_descending then return first_marker.position > second_marker.position end
		return first_marker.position < second_marker.position
	end)
	return sorted_markers
end

local function is_station(edge_entity)
	local succeeded, station_construction = pcall(api.engine.system.streetConnectorSystem.getConstructionEntityForEdge, edge_entity)
	return succeeded and station_construction ~= nil and station_construction >= 0
end

local function is_area_target(edge_entity, base_edge, stop_target)
	local edge_types = api.type.enum.BaseEdgeType
	if stop_target == STOP_TARGET_TUNNEL then return base_edge.type == edge_types.TUNNEL end
	if stop_target == STOP_TARGET_BRIDGE then return base_edge.type == edge_types.BRIDGE end
	if stop_target == STOP_TARGET_STATION then return is_station(edge_entity) end
	return false
end

local function planar_direction(tangent, is_inverted)
	if tangent == nil then return nil end
	local length = math.sqrt(tangent.x * tangent.x + tangent.y * tangent.y)
	if length == 0 then return nil end
	local sign = is_inverted and -1 or 1
	return sign * tangent.x / length, sign * tangent.y / length
end

local function direction_leaving_edge(base_edge, is_backward)
	if is_backward then return planar_direction(base_edge.tangent0, true) end
	return planar_direction(base_edge.tangent1, false)
end

local function direction_entering_edge(base_edge, node)
	if base_edge.node0 == node then return planar_direction(base_edge.tangent0, false) end
	return planar_direction(base_edge.tangent1, true)
end

local function node_position(node)
	local base_node = api.engine.getComponent(node, api.type.ComponentType.BASE_NODE)
	return base_node and base_node.position
end

local function chord_alignment(candidate_base_edge, node, incoming_x, incoming_y)
	local far_node = candidate_base_edge.node0 == node and candidate_base_edge.node1 or candidate_base_edge.node0
	local from, to = node_position(node), node_position(far_node)
	if from == nil or to == nil then return 0 end
	local chord_x, chord_y = planar_direction({ x = to.x - from.x, y = to.y - from.y }, false)
	if chord_x == nil then return 0 end
	return incoming_x * chord_x + incoming_y * chord_y
end

local function pick_straightest_edge(candidates, node, last_edge)
	local incoming_x, incoming_y = direction_leaving_edge(last_edge.base_edge, last_edge.is_backward)
	if incoming_x == nil then
		log_message(string.format("node %s: no tangent on edge %s", tostring(node), tostring(last_edge.entity)))
		return nil
	end
	local best_edge, best_alignment, best_chord = nil, 0, -2
	for _, candidate in ipairs(candidates) do
		local candidate_base_edge = api.engine.getComponent(candidate, api.type.ComponentType.BASE_EDGE)
		if candidate_base_edge and candidate_base_edge.node0 ~= candidate_base_edge.node1 then
			local outgoing_x, outgoing_y = direction_entering_edge(candidate_base_edge, node)
			if outgoing_x ~= nil then
				local alignment = incoming_x * outgoing_x + incoming_y * outgoing_y
				local chord = chord_alignment(candidate_base_edge, node, incoming_x, incoming_y)
				log_message(string.format("node %s: from edge %s (%.2f, %.2f) candidate edge %s (%.2f, %.2f) alignment %.3f, chord %.3f",
					tostring(node), tostring(last_edge.entity), incoming_x, incoming_y, tostring(candidate), outgoing_x, outgoing_y, alignment, chord))
				local is_better = alignment > best_alignment + TANGENT_TIE_EPSILON
					or (alignment > 0 and math.abs(alignment - best_alignment) <= TANGENT_TIE_EPSILON and chord > best_chord)
				if is_better then best_edge, best_alignment, best_chord = candidate, alignment, chord end
			end
		end
	end
	return best_edge
end

local function plan_new_markers(marker_entity, distance, max_count, stop_target)
	local edge_entity = api.engine.system.streetSystem.getEdgeForEdgeObject(marker_entity)
	if not edge_entity or edge_entity < 0 then return nil, "marker has no edge" end
	local base_edge = api.engine.getComponent(edge_entity, api.type.ComponentType.BASE_EDGE)
	local markers_by_entity, edge_length = find_markers_on_edge(edge_entity)
	local placed_marker = markers_by_entity[marker_entity]
	if not placed_marker then return nil, "marker not found in the signal system" end

	local walked_edges = { {
		entity = edge_entity,
		base_edge = base_edge,
		is_backward = placed_marker.is_left,
		length = edge_length,
		start_position = 0,
		end_position = edge_length,
		is_in_target_area = is_area_target(edge_entity, base_edge, stop_target),
	} }
	local first_edge = walked_edges[1]

	local is_finished, stop_reason = false, nil
	local blocking_markers = {}
	for _, other_marker in pairs(markers_by_entity) do
		local is_same_side = other_marker.is_left == placed_marker.is_left
		local is_ahead = (first_edge.is_backward and other_marker.position < placed_marker.position)
			or (not first_edge.is_backward and other_marker.position > placed_marker.position)
		if is_same_side and is_ahead then
			blocking_markers[#blocking_markers + 1] = other_marker
		end
	end
	blocking_markers = sort_markers_by_position(blocking_markers, first_edge.is_backward)
	if #blocking_markers > 0 then
		is_finished, stop_reason = true, "marker"
		first_edge.end_position = first_edge.is_backward and (first_edge.length - blocking_markers[1].position) or blocking_markers[1].position
	end

	local visited_edges = { [edge_entity] = true }
	local switch_count, station_edge_count = 0, 0
	while not is_finished do
		if #walked_edges >= MAX_EDGES then
			stop_reason = "edge limit"
			break
		end
		local last_edge = walked_edges[#walked_edges]
		local node = last_edge.is_backward and last_edge.base_edge.node0 or last_edge.base_edge.node1
		local connected_edges = api.engine.system.streetSystem.getNodeTrackSegments(node) or {}
		local next_edge_candidates = {}
		for _, connected_edge in ipairs(connected_edges) do
			if connected_edge ~= last_edge.entity then next_edge_candidates[#next_edge_candidates + 1] = connected_edge end
		end
		if #next_edge_candidates == 0 then
			stop_reason = "track end"
			break
		end
		local next_edge_entity = next_edge_candidates[1]
		if #next_edge_candidates > 1 then
			if stop_target == STOP_TARGET_SWITCH then
				stop_reason = STOP_TARGET_REASONS[STOP_TARGET_SWITCH]
				break
			end
			next_edge_entity = pick_straightest_edge(next_edge_candidates, node, last_edge)
			if next_edge_entity == nil then
				stop_reason = "switch"
				break
			end
			switch_count = switch_count + 1
		end
		if visited_edges[next_edge_entity] then
			stop_reason = "loop"
			break
		end
		local next_base_edge = api.engine.getComponent(next_edge_entity, api.type.ComponentType.BASE_EDGE)
		local next_is_in_target_area = is_area_target(next_edge_entity, next_base_edge, stop_target)
		if next_is_in_target_area and not last_edge.is_in_target_area then
			stop_reason = STOP_TARGET_REASONS[stop_target]
			break
		end
		local next_is_station = is_station(next_edge_entity)
		if next_is_station then station_edge_count = station_edge_count + 1 end
		visited_edges[next_edge_entity] = true
		local next_edge_markers, next_edge_length = find_markers_on_edge(next_edge_entity)
		local is_backward = next_base_edge.node1 == node
		local next_edge = {
			entity = next_edge_entity,
			base_edge = next_base_edge,
			is_backward = is_backward,
			is_station = next_is_station,
			is_in_target_area = next_is_in_target_area,
			start_position = last_edge.end_position,
			end_position = last_edge.end_position + next_edge_length,
			length = next_edge_length,
		}
		local wanted_is_left = placed_marker.is_left
		if is_backward ~= first_edge.is_backward then wanted_is_left = not wanted_is_left end
		for _, next_edge_marker in ipairs(sort_markers_by_position(next_edge_markers, is_backward)) do
			if next_edge_marker.is_left == wanted_is_left then
				local marker_offset = is_backward and (next_edge_length - next_edge_marker.position) or next_edge_marker.position
				next_edge.end_position = last_edge.end_position + marker_offset
				is_finished, stop_reason = true, "marker"
				break
			end
		end
		walked_edges[#walked_edges + 1] = next_edge
	end

	local start_position = (first_edge.is_backward and (first_edge.length - placed_marker.position) or placed_marker.position) + distance
	local last_position = walked_edges[#walked_edges].end_position
	local planned_positions = {}
	local step_count = 1
	for position = start_position, last_position - 1, distance do
		if step_count > max_count then
			stop_reason = "maximum value"
			break
		end
		planned_positions[#planned_positions + 1] = { position = position, step_count = step_count }
		step_count = step_count + 1
	end
	log_message(string.format("marker %d: %d m, walked %d edges (%.0f m, %d switches, %d station edges), stop: %s, new markers: %d",
		marker_entity, distance, #walked_edges, last_position, switch_count, station_edge_count, tostring(stop_reason), #planned_positions))

	local steps = {}
	for _, walked_edge in ipairs(walked_edges) do
		local positions_on_edge = {}
		for _, planned_position in ipairs(planned_positions) do
			if planned_position.position > walked_edge.start_position + 0.5 and planned_position.position < walked_edge.end_position - 0.5 then
				local relative_position = (planned_position.position - walked_edge.start_position) / walked_edge.length
				if walked_edge.is_backward then relative_position = 1 - relative_position end
				positions_on_edge[#positions_on_edge + 1] = { relative_position = relative_position, step_count = planned_position.step_count }
			end
		end
		if #positions_on_edge > 0 and not walked_edge.is_station then
			local is_left = placed_marker.is_left
			if first_edge.is_backward ~= walked_edge.is_backward then is_left = not is_left end
			steps[#steps + 1] = {
				edge = walked_edge.entity,
				positions = positions_on_edge,
				is_left = is_left,
				length = walked_edge.length,
				is_walked_backward = walked_edge.is_backward,
			}
		end
	end
	local start_reference = nil
	if edge_length > 0 then
		start_reference = {
			edge = edge_entity,
			relative_position = placed_marker.position / edge_length,
			is_walked_backward = first_edge.is_backward,
			step_count = 0,
			shift_meters = 0,
		}
	end
	return steps, nil, start_reference
end

local function try_set_params(new_edge_object, params)
	return (pcall(function() new_edge_object.params = params end))
end

local function build_proposal(marker_edge_object, base_params, start_value, value_step, steps)
	local player = api.engine.util.getPlayer()
	local all_params_applied = nil

	local edges_to_add, edges_to_remove, edge_objects_to_add = {}, {}, {}
	local next_placeholder_entity = FIRST_PLACEHOLDER_ENTITY
	for step_index, step in ipairs(steps) do
		local base_edge = api.engine.getComponent(step.edge, api.type.ComponentType.BASE_EDGE)
		if base_edge then
			local edge_objects = {}
			for _, object_entry in ipairs(base_edge.objects or {}) do
				edge_objects[#edge_objects + 1] = { object_entry[1], object_entry[2] }
			end
			local segment = api.type.SegmentAndEntity.new()
			segment.entity = -step_index
			segment.type = TRACK_SEGMENT_TYPE
			segment.comp = base_edge
			local player_owned = api.engine.getComponent(step.edge, api.type.ComponentType.PLAYER_OWNED)
			if player_owned then segment.playerOwned = player_owned end
			for _, position in ipairs(step.positions) do
				edge_objects[#edge_objects + 1] = { next_placeholder_entity, api.type.enum.EdgeObjectType.SIGNAL }
				next_placeholder_entity = next_placeholder_entity - 1
				local new_edge_object = api.type.SimpleStreetProposal.EdgeObject.new()
				new_edge_object.edgeEntity = segment.entity
				new_edge_object.param = position.relative_position
				new_edge_object.oneWay = false
				new_edge_object.left = step.is_left
				new_edge_object.model = marker_edge_object.edgeObjectConstruction
				new_edge_object.playerEntity = player
				local params_applied = try_set_params(new_edge_object, params_for_value(base_params, start_value + math.floor(position.step_count * value_step + VALUE_EPSILON), position.shift_meters))
				if all_params_applied == nil then all_params_applied = params_applied else all_params_applied = all_params_applied and params_applied end
				edge_objects_to_add[#edge_objects_to_add + 1] = new_edge_object
			end
			segment.comp.objects = edge_objects
			edges_to_add[#edges_to_add + 1] = segment
			edges_to_remove[#edges_to_remove + 1] = step.edge
		end
	end
	if #edge_objects_to_add == 0 then return nil end

	local proposal = api.type.SimpleProposal.new()
	proposal.streetProposal.edgesToRemove = edges_to_remove
	proposal.streetProposal.edgesToAdd = edges_to_add
	proposal.streetProposal.edgeObjectsToAdd = edge_objects_to_add
	local context = api.type.Context.new()
	context.player = player
	return proposal, context, #edge_objects_to_add, all_params_applied
end

local function proposal_errors(proposal, context)
	local make_proposal_data = api.engine.util.proposal and api.engine.util.proposal.makeProposalData
	if not make_proposal_data then return "proposal validation is unavailable" end
	local succeeded, proposal_data = pcall(make_proposal_data, proposal, context)
	if not succeeded then return "proposal validation failed: " .. tostring(proposal_data) end
	if not proposal_data or not proposal_data.errorState then return "proposal validation returned no error state" end
	local messages = {}
	for _, message in ipairs(proposal_data.errorState.messages or {}) do messages[#messages + 1] = tostring(message) end
	if not proposal_data.errorState.critical and #messages == 0 then return nil end
	return #messages > 0 and table.concat(messages, ", ") or "unknown error"
end

local function geometry_results(...)
	local results = { ... }
	if #results == 1 and type(results[1]) == "table" then return unpack_values(results[1]) end
	return unpack_values(results)
end

-- calcPos and locate are functions of the EdgeGeometry instance (not of api.type.EdgeGeometry).
local function geometry_call(geometry, function_name, ...)
	local method = geometry[function_name]
	if type(method) ~= "function" then error("EdgeGeometry has no function " .. function_name) end
	return geometry_results(method(geometry, ...))
end

local function edge_sections(edge_entity)
	local transport_network = api.engine.getComponent(edge_entity, api.type.ComponentType.TRANSPORT_NETWORK)
	if not transport_network then return nil end
	local sections, total_length = {}, 0
	for _, network_edge in ipairs(transport_network.edges) do
		local length = network_edge.geometry.length
		sections[#sections + 1] = { geometry = network_edge.geometry, start_position = total_length, length = length }
		total_length = total_length + length
	end
	if #sections == 0 or total_length <= 0 then return nil end
	return sections, total_length
end

local function point_on_edge(sections, total_length, relative_position)
	local meters = relative_position * total_length
	local section = sections[#sections]
	for _, candidate in ipairs(sections) do
		if meters <= candidate.start_position + candidate.length then
			section = candidate
			break
		end
	end
	local param = section.length > 0 and math.min(math.max((meters - section.start_position) / section.length, 0), 1) or 0
	return geometry_call(section.geometry, "calcPos", param)
end

local function is_track_edge(edge_entity, base_edge)
	for _, node in ipairs({ base_edge.node0, base_edge.node1 }) do
		for _, track_edge in ipairs(api.engine.system.streetSystem.getNodeTrackSegments(node) or {}) do
			if track_edge == edge_entity then return true end
		end
	end
	return false
end

-- Nearest point of a candidate edge next to the position, accepted only when it lies sideways and runs parallel.
local function locate_neighbour_on_edge(edge_entity, position, direction_x, direction_y, normal_x, normal_y, notes)
	local sections, total_length = edge_sections(edge_entity)
	if not sections then return nil end
	local world_position = api.type.Vec3f.new(position.x, position.y, position.z)
	local best_match = nil
	for section_index, section in ipairs(sections) do
		local param, found = geometry_call(section.geometry, "locate", world_position, NEIGHBOUR_LOCATE_STEPS, NEIGHBOUR_MAX_DISTANCE)
		if not found then
			notes[#notes + 1] = string.format("edge %s/%d: locate found nothing", tostring(edge_entity), section_index)
		else
			local point, point_tangent = geometry_call(section.geometry, "calcPos", param)
			-- locate only returns a coarse parameter, so move along the tangent until the point is abreast of the position.
			for _ = 1, NEIGHBOUR_REFINE_STEPS do
				local refine_x, refine_y = planar_direction(point_tangent, false)
				if refine_x == nil or section.length <= 0 then break end
				local remaining = (position.x - point.x) * refine_x + (position.y - point.y) * refine_y
				if math.abs(remaining) < 0.0001 then break end
				param = math.min(math.max(param + remaining / section.length, 0), 1)
				point, point_tangent = geometry_call(section.geometry, "calcPos", param)
			end
			local offset_x, offset_y = point.x - position.x, point.y - position.y
			local lateral = offset_x * normal_x + offset_y * normal_y
			local along = offset_x * direction_x + offset_y * direction_y
			local tangent_x, tangent_y = planar_direction(point_tangent, false)
			local is_beside = lateral >= NEIGHBOUR_MIN_DISTANCE and lateral <= NEIGHBOUR_MAX_DISTANCE and math.abs(along) <= NEIGHBOUR_MAX_ALONG_OFFSET
			local parallel = tangent_x ~= nil and math.abs(tangent_x * direction_x + tangent_y * direction_y) or 0
			local height_difference = math.abs(point.z - position.z)
			notes[#notes + 1] = string.format("edge %s/%d: param %.3f lateral %.2f along %.2f parallel %.2f height %.2f", tostring(edge_entity), section_index, param, lateral, along, parallel, height_difference)
			if tangent_x ~= nil and is_beside
				and parallel >= NEIGHBOUR_MIN_PARALLEL
				and height_difference <= NEIGHBOUR_MAX_HEIGHT_DIFFERENCE
				and (best_match == nil or lateral < best_match.lateral) then
				best_match = {
					edge = edge_entity,
					length = total_length,
					relative_position = (section.start_position + param * section.length) / total_length,
					is_walked_backward = tangent_x * direction_x + tangent_y * direction_y < 0,
					lateral = lateral,
				}
			end
		end
	end
	return best_match
end

-- The neighbour track lies on the side opposite to the marker's side, measured from the counting direction.
local function find_neighbour_track(reference, is_marker_left, excluded_edges, notes)
	local sections, total_length = edge_sections(reference.edge)
	if not sections then return nil end
	local position, tangent = point_on_edge(sections, total_length, reference.relative_position)
	local direction_x, direction_y = planar_direction(tangent, reference.is_walked_backward)
	if direction_x == nil then return nil end
	local normal_x, normal_y = -direction_y, direction_x
	if is_marker_left then normal_x, normal_y = direction_y, -direction_x end
	notes[#notes + 1] = string.format("reference edge %s at %.4f (%.1f, %.1f, %.1f) direction (%.2f, %.2f) normal (%.2f, %.2f)", tostring(reference.edge), reference.relative_position, position.x, position.y, position.z, direction_x, direction_y, normal_x, normal_y)
	local radius = NEIGHBOUR_SEARCH_RADIUS
	local height = NEIGHBOUR_MAX_HEIGHT_DIFFERENCE + 2
	local box = api.type.Box3.new(
		api.type.Vec3f.new(position.x - radius, position.y - radius, position.z - height),
		api.type.Vec3f.new(position.x + radius, position.y + radius, position.z + height))
	local candidates = {}
	api.engine.system.octreeSystem.findIntersectingEntities(box, function(entity) candidates[#candidates + 1] = entity end)
	notes[#notes + 1] = string.format("%d octree entities", #candidates)
	local best_match = nil
	for _, candidate in ipairs(candidates) do
		local candidate_edge = not excluded_edges[candidate] and api.engine.getComponent(candidate, api.type.ComponentType.BASE_EDGE)
		if candidate_edge and is_track_edge(candidate, candidate_edge) and not is_station(candidate) then
			local match = locate_neighbour_on_edge(candidate, position, direction_x, direction_y, normal_x, normal_y, notes)
			if match and (best_match == nil or match.lateral < best_match.lateral) then best_match = match end
		end
	end
	return best_match
end

local function plan_double_track_steps(references, is_marker_left, excluded_edges)
	local steps, steps_by_edge, found_count = {}, {}, 0
	for _, reference in ipairs(references) do
		local notes = {}
		local succeeded, match = pcall(find_neighbour_track, reference, is_marker_left, excluded_edges, notes)
		if not succeeded then
			log_message("double track: neighbour search failed: " .. tostring(match))
			match = nil
		end
		local margin = match and MIN_EDGE_MARGIN_METERS / match.length
		if match and not (match.relative_position > margin and match.relative_position < 1 - margin) then
			notes[#notes + 1] = string.format("neighbour on edge %s at %.4f rejected: too close to the edge end", tostring(match.edge), match.relative_position)
		end
		if not match or not (match.relative_position > margin and match.relative_position < 1 - margin) then
			log_message("double track: no neighbour: " .. table.concat(notes, "; "))
		end
		local margin = match and MIN_EDGE_MARGIN_METERS / match.length
		if match and match.relative_position > margin and match.relative_position < 1 - margin then
			local step = steps_by_edge[match.edge]
			if not step then
				step = {
					edge = match.edge,
					is_left = not match.is_walked_backward,
					length = match.length,
					is_walked_backward = match.is_walked_backward,
					is_double_track = true,
					positions = {},
				}
				steps_by_edge[match.edge] = step
				steps[#steps + 1] = step
			end
			local base_shift = reference.shift_meters or 0
			step.positions[#step.positions + 1] = {
				relative_position = match.relative_position,
				step_count = reference.step_count,
				shift_meters = base_shift,
				base_shift = base_shift,
			}
			found_count = found_count + 1
		end
	end
	log_message(string.format("double track: %d neighbour markers on %d edges, %d left out without a neighbour track", found_count, #steps, #references - found_count))
	return steps
end

local function shifted_position(step, position, shift_meters)
	if shift_meters == 0 then return position end
	if not step.length or step.length <= 0 then return nil end
	local direction = step.is_walked_backward and -1 or 1
	local relative_position = position.relative_position + direction * shift_meters / step.length
	local margin = MIN_EDGE_MARGIN_METERS / step.length
	if relative_position <= margin or relative_position >= 1 - margin then return nil end
	return {
		relative_position = relative_position,
		step_count = position.step_count,
		shift_meters = shift_meters + (position.base_shift or 0),
		base_shift = position.base_shift,
	}
end

local function shift_candidates(base_shift)
	local candidates = { base_shift }
	for _, candidate in ipairs({ base_shift + SHIFT_STEP_METERS, base_shift - SHIFT_STEP_METERS }) do
		if math.abs(candidate) <= MAX_SHIFT_METERS then candidates[#candidates + 1] = candidate end
	end
	return candidates
end

local function new_placement(marker_entity, steps, value_step, start_reference)
	local marker_edge_object = api.engine.getComponent(marker_entity, api.type.ComponentType.EDGE_OBJECT)
	local base_params = {}
	for key, value in pairs(type(marker_edge_object.params) == "table" and marker_edge_object.params or {}) do
		base_params[key] = value
	end
	return {
		marker = marker_entity,
		steps = steps,
		value_step = value_step,
		start_reference = start_reference,
		base_params = base_params,
		start_value = value_from_params(base_params),
		carries_shift = is_meter_display_on(base_params),
		buildable_steps = {},
		current_shift = 0,
		step_index = 1,
		phase = "edge",
	}
end

local function step_with_positions(step, positions)
	return {
		edge = step.edge,
		is_left = step.is_left,
		length = step.length,
		is_walked_backward = step.is_walked_backward,
		is_double_track = step.is_double_track,
		positions = positions,
	}
end

-- Appends the steps on the neighbour track, derived from the final positions on the marker's own track.
local function append_double_track_steps(placement)
	local references, excluded_edges = {}, {}
	if placement.start_reference then
		references[1] = placement.start_reference
		excluded_edges[placement.start_reference.edge] = true
	end
	for _, step in ipairs(placement.steps) do excluded_edges[step.edge] = true end
	for _, step in ipairs(placement.buildable_steps) do
		for _, position in ipairs(step.positions) do
			references[#references + 1] = {
				edge = step.edge,
				relative_position = position.relative_position,
				is_walked_backward = step.is_walked_backward,
				step_count = position.step_count,
				shift_meters = position.shift_meters,
			}
		end
	end
	local is_marker_left = placement.base_params[SIDE_KEY] == LEFT_SIDE_INDEX
	local double_track_steps = plan_double_track_steps(references, is_marker_left, excluded_edges)
	for _, step in ipairs(double_track_steps) do placement.steps[#placement.steps + 1] = step end
	return #double_track_steps
end

local function with_candidate(entries, candidate)
	local result = {}
	for _, entry in ipairs(entries) do result[#result + 1] = entry end
	result[#result + 1] = candidate
	return result
end

local function advance_placement(placement)
	local marker_edge_object = api.engine.getComponent(placement.marker, api.type.ComponentType.EDGE_OBJECT)
	if not marker_edge_object then
		log_message("placement cancelled: start marker no longer exists")
		return true
	end

	local function check_steps(steps)
		local proposal, context, count, applied = build_proposal(marker_edge_object, placement.base_params,
			placement.start_value, placement.value_step, steps)
		if not proposal then return "no markers" end
		return proposal_errors(proposal, context), proposal, context, count, applied
	end

	local step = placement.steps[placement.step_index]
	local chains_shift = placement.carries_shift and not (step and step.is_double_track)
	if placement.phase == "edge" then
		if not step then
			if not placement.double_track_planned and double_track_from_params(placement.base_params) then
				placement.double_track_planned = true
				if append_double_track_steps(placement) > 0 then return false end
			end
			placement.phase = "combined"
			return false
		end
		local entry_shift = chains_shift and placement.current_shift or 0
		local whole_positions = {}
		for _, position in ipairs(step.positions) do
			whole_positions[#whole_positions + 1] = shifted_position(step, position, entry_shift)
		end
		local whole_step = #whole_positions == #step.positions and step_with_positions(step, whole_positions) or nil
		local errors = whole_step == nil and "marker outside of the edge" or check_steps({ whole_step })
		if not errors then
			placement.buildable_steps[#placement.buildable_steps + 1] = whole_step
			placement.step_index = placement.step_index + 1
		else
			placement.edge_errors = errors
			placement.kept_positions, placement.shift_notes = {}, {}
			placement.running_shift = entry_shift
			placement.position_index, placement.candidate_index = 1, 1
			placement.phase = "shift"
		end
	elseif placement.phase == "shift" then
		local position = step.positions[placement.position_index]
		if not position then
			placement.phase = "reduced"
			return false
		end
		local base_shift = chains_shift and placement.running_shift or 0
		local candidate_shift = shift_candidates(base_shift)[placement.candidate_index]
		if candidate_shift == nil then
			placement.position_index = placement.position_index + 1
			placement.candidate_index = 1
			return false
		end
		local candidate = shifted_position(step, position, candidate_shift)
		if candidate and not check_steps({ step_with_positions(step, { candidate }) }) then
			placement.kept_positions[#placement.kept_positions + 1] = candidate
			if chains_shift then placement.running_shift = candidate_shift end
			if candidate_shift ~= 0 then
				placement.shift_notes[#placement.shift_notes + 1] = string.format("step %d %+d m", position.step_count, candidate_shift)
			end
			placement.position_index = placement.position_index + 1
			placement.candidate_index = 1
		else
			placement.candidate_index = placement.candidate_index + 1
		end
	elseif placement.phase == "reduced" then
		if chains_shift then placement.current_shift = placement.running_shift end
		local kept_positions, shift_notes = placement.kept_positions, placement.shift_notes
		local reduced_step = step_with_positions(step, kept_positions)
		local is_valid = #kept_positions > 0 and not check_steps({ reduced_step })
		log_message(string.format("edge %s: %s, kept %d of %d markers%s%s", tostring(step.edge), placement.edge_errors,
			is_valid and #kept_positions or 0, #step.positions,
			#kept_positions > 0 and not is_valid and " (rejected together)" or "",
			#shift_notes > 0 and (", shifted: " .. table.concat(shift_notes, ", ")) or ""))
		if is_valid then placement.buildable_steps[#placement.buildable_steps + 1] = reduced_step end
		placement.step_index = placement.step_index + 1
		placement.phase = "edge"
	elseif placement.phase == "combined" or placement.phase == "final" then
		local steps = placement.phase == "final" and placement.accepted_steps or placement.buildable_steps
		local errors, proposal, context, count, applied = check_steps(steps)
		if not proposal then return true end
		if not errors then
			api.cmd.sendCommand(api.cmd.makeWorldBuildProposalCmd(proposal, context, false, true))
			log_message("sent " .. count .. " new markers (" .. tostring(marker_edge_object.edgeObjectConstruction) .. ", params set " .. tostring(applied) .. ")")
			return true
		end
		if placement.phase == "final" then
			log_message("combined proposal remains invalid: " .. errors)
			return true
		end
		log_message("combined proposal rejected: " .. errors .. "; filtering colliding markers")
		placement.accepted_steps = {}
		placement.filter_index = 1
		placement.phase = "filter_edge"
	elseif placement.phase == "filter_edge" then
		local filter_step = placement.buildable_steps[placement.filter_index]
		if not filter_step then
			placement.phase = "final"
			return false
		end
		if not check_steps(with_candidate(placement.accepted_steps, filter_step)) then
			placement.accepted_steps[#placement.accepted_steps + 1] = filter_step
			placement.filter_index = placement.filter_index + 1
		else
			placement.kept_positions = {}
			placement.position_index = 1
			placement.phase = "filter_position"
		end
	elseif placement.phase == "filter_position" then
		local filter_step = placement.buildable_steps[placement.filter_index]
		local position = filter_step.positions[placement.position_index]
		if not position then
			if #placement.kept_positions > 0 then
				placement.accepted_steps[#placement.accepted_steps + 1] = step_with_positions(filter_step, placement.kept_positions)
			end
			placement.filter_index = placement.filter_index + 1
			placement.phase = "filter_edge"
			return false
		end
		local candidate_step = step_with_positions(filter_step, with_candidate(placement.kept_positions, position))
		local errors = check_steps(with_candidate(placement.accepted_steps, candidate_step))
		if errors then
			log_message(string.format("edge %s: marker step %d rejected in combined proposal: %s", tostring(filter_step.edge), position.step_count, errors))
		else
			placement.kept_positions[#placement.kept_positions + 1] = position
		end
		placement.position_index = placement.position_index + 1
	else
		error("unknown placement phase: " .. tostring(placement.phase))
	end
	return false
end

local function submit_build_proposal(marker_entity, steps, value_step, start_reference)
	local placement = new_placement(marker_entity, steps, value_step, start_reference)
	while not advance_placement(placement) do end
end

local function read_state(state)
	local job_state = state:get()
	if type(job_state) ~= "table" then job_state = {} end
	job_state.jobs = type(job_state.jobs) == "table" and job_state.jobs or {}
	job_state.next_job_id = job_state.next_job_id or 1
	return job_state
end

local function update(user_params, state, dt)
	local job_state = read_state(state)
	if job_state.version ~= STATE_VERSION or not state:hasEventSubscriptions() then
		state:subscribeToNoEvents()
		state:subscribeToEvent("onPostBuildProposal")
		job_state.version = STATE_VERSION
		state:set(job_state)
	end
end

local function on_post_build_proposal(event_params, job_state)
	local build_event = event_params and event_params[1]
	if not build_event or not build_event.proposal or not event_params[4] then return end
	local built_proposal = build_event.proposal
	local removed_object_entities = {}
	for _, segment in ipairs(built_proposal.removedSegments or {}) do
		for _, object_entry in ipairs(segment.comp and segment.comp.objects or {}) do removed_object_entities[object_entry[1]] = true end
	end
	local found_marker_entities = {}
	for _, segment in ipairs(built_proposal.addedSegments or {}) do
		if segment.type == TRACK_SEGMENT_TYPE and segment.comp and segment.comp.objects and #segment.comp.objects > 0 then
			local start_node_edges = api.engine.system.streetSystem.getNodeTrackSegments(segment.comp.node0) or {}
			local end_node_edges = api.engine.system.streetSystem.getNodeTrackSegments(segment.comp.node1) or {}
			for _, start_node_edge in ipairs(start_node_edges) do
				for _, end_node_edge in ipairs(end_node_edges) do
					if start_node_edge == end_node_edge then
						local base_edge = api.engine.getComponent(start_node_edge, api.type.ComponentType.BASE_EDGE)
						for _, object_entry in ipairs(base_edge and base_edge.objects or {}) do
							if object_entry[2] == api.type.enum.EdgeObjectType.SIGNAL and not removed_object_entities[object_entry[1]] then
								found_marker_entities[object_entry[1]] = true
							end
						end
					end
				end
			end
		end
	end
	for marker in pairs(found_marker_entities) do
		local edge_object = api.engine.getComponent(marker, api.type.ComponentType.EDGE_OBJECT)
		if edge_object and type(edge_object.params) == "table" and edge_object.params[FIRST_DIGIT_KEY] ~= nil then
			local distance = distance_from_params(edge_object.params)
			job_state.jobs[#job_state.jobs + 1] = { id = job_state.next_job_id, marker = marker, distance = distance }
			log_message("job " .. job_state.next_job_id .. ": marker " .. marker .. ", " .. tostring(distance) .. " m")
			job_state.next_job_id = job_state.next_job_id + 1
		end
	end
	while #job_state.jobs > MAX_JOBS do table.remove(job_state.jobs, 1) end
end

local function handle_event(user_params, state, source, id, event_name, event_params)
	if event_name ~= "onPostBuildProposal" then return end
	local job_state = read_state(state)
	job_state.build_revision = (job_state.build_revision or 0) + 1
	local succeeded, error_message = pcall(on_post_build_proposal, event_params, job_state)
	if not succeeded then log_message("event error: " .. tostring(error_message)) end
	state:set(job_state)
end

local function run_job(job, defer_placement)
	local edge_object = api.engine.getComponent(job.marker, api.type.ComponentType.EDGE_OBJECT)
	if not edge_object or type(edge_object.params) ~= "table" then
		log_message("job " .. job.id .. " skipped: marker has no params")
		return
	end
	local name = marker_name(edge_object.params)
	api.cmd.sendCommand(api.cmd.makeEntitySetNameCmd(job.marker, name, true))
	log_message("job " .. job.id .. ": named marker " .. job.marker .. " '" .. name .. "'")
	if not job.distance then return end
	local value_step = job.distance / 100
	local max_count = math.floor((max_value(edge_object.params) - value_from_params(edge_object.params)) / value_step + VALUE_EPSILON)
	local steps, skip_reason, start_reference = plan_new_markers(job.marker, job.distance, max_count, stop_target_from_params(edge_object.params))
	if not steps then
		log_message("job " .. job.id .. " skipped: " .. tostring(skip_reason))
	elseif #steps > 0 or (start_reference and double_track_from_params(edge_object.params)) then
		if defer_placement then return new_placement(job.marker, steps, value_step, start_reference) end
		submit_build_proposal(job.marker, steps, value_step, start_reference)
	end
end

-- Only Lua planning data survives a GUI update; native proposals are rebuilt each time.
local pending_job

local progress_hint = { percent = nil, failed = false }

local function planned_marker_count(placement)
	local count = 0
	for _, step in ipairs(placement.steps) do count = count + #step.positions end
	return count
end

local function placement_percent(placement)
	local phase = placement.phase
	if phase == "edge" or phase == "shift" or phase == "reduced" then
		return math.floor(PROGRESS_VALIDATION_SHARE * (placement.step_index - 1) / math.max(#placement.steps, 1))
	end
	if phase == "filter_edge" or phase == "filter_position" then
		return PROGRESS_VALIDATION_SHARE + math.floor(PROGRESS_FILTER_SHARE * (placement.filter_index - 1) / math.max(#placement.buildable_steps, 1))
	end
	return phase == "combined" and PROGRESS_VALIDATION_SHARE or PROGRESS_VALIDATION_SHARE + PROGRESS_FILTER_SHARE
end

local function progress_text(percent)
	local succeeded, translated_text = pcall(_, PROGRESS_KEY)
	if not succeeded or type(translated_text) ~= "string" or translated_text == "" or translated_text == PROGRESS_KEY then
		translated_text = "Hektometertafeln werden gesetzt ... %d%%"
	end
	return (string.format(translated_text, percent))
end

-- The guide system is the only documented GUI element that can show free text; failures only disable the hint.
local function show_progress(percent)
	if progress_hint.failed then return end
	if progress_hint.percent and percent - progress_hint.percent < PROGRESS_STEP_PERCENT then return end
	local had_hint = progress_hint.percent ~= nil
	local succeeded, shown = pcall(function()
		local guide = api.gui.guide
		local text = progress_text(percent)
		local spawned = guide.trySpawnGuideFree(guide.FreeGuidePosition.High, text, text)
		if had_hint and spawned ~= true then
			guide.resetGuide()
			spawned = guide.trySpawnGuideFree(guide.FreeGuidePosition.High, text, text)
		end
		return spawned
	end)
	if succeeded and shown == true then
		progress_hint.percent = percent
		return
	end
	progress_hint.percent = nil
	progress_hint.failed = true
	log_message("progress hint unavailable: " .. (succeeded and "guide was not spawned" or tostring(shown)))
end

local function hide_progress()
	local had_hint = progress_hint.percent ~= nil
	progress_hint.percent = nil
	progress_hint.failed = false
	if had_hint then pcall(function() api.gui.guide.resetGuide() end) end
end

local function gui_update(user_params, state, gui_state)
	local job_state = state:get()
	local jobs = type(job_state) == "table" and type(job_state.jobs) == "table" and job_state.jobs or {}
	local gui_progress = gui_state:get()
	if type(gui_progress) ~= "table" or gui_progress.done == nil then
		pending_job = nil
		hide_progress()
		local newest_job_id = 0
		for _, job in ipairs(jobs) do newest_job_id = math.max(newest_job_id, job.id or 0) end
		gui_state:set({ done = newest_job_id })
		return
	end
	local build_revision = type(job_state) == "table" and job_state.build_revision or 0
	if pending_job and pending_job.build_revision ~= build_revision then
		log_message("job " .. pending_job.id .. " cancelled: world changed during placement validation; place the start marker again to retry")
		pending_job = nil
		hide_progress()
		return
	end
	if not pending_job then
		for _, job in ipairs(jobs) do
			if (job.id or 0) > gui_progress.done then
				pending_job = {
					id = job.id,
					job = job,
					build_revision = build_revision,
				}
				gui_state:set({ done = job.id })
				break
			end
		end
	end
	if not pending_job then return end
	local succeeded, finished = pcall(function()
		if not pending_job.placement then
			pending_job.placement = run_job(pending_job.job, true)
		end
		local placement = pending_job.placement
		local is_finished = not placement or advance_placement(placement)
		if not is_finished and planned_marker_count(placement) > PROGRESS_MIN_MARKERS then
			show_progress(placement_percent(placement))
		end
		return is_finished
	end)
	if not succeeded then log_message("job " .. pending_job.id .. " failed: " .. tostring(finished)) end
	if not succeeded or finished then
		pending_job = nil
		hide_progress()
	end
end

local AutoPlacementScript = {
	update = update,
	handleEvent = handle_event,
	guiUpdate = gui_update,
}

function data()
	return AutoPlacementScript
end

return AutoPlacementScript
