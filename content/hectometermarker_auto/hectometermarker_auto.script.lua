local AUTO_KEY = "peppie84_hmt_auto"
local SPACING_KEY = "peppie84_hmt_auto_spacing"
local STOP_AT_KEY = "peppie84_hmt_auto_stop_at"
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
local SPACING_METERS = { 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000 }
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
local VALUE_EPSILON = 1e-9
local TANGENT_TIE_EPSILON = 1e-3
local MAX_SHIFT_METERS = 15
local SHIFT_STEP_METERS = 15
local MIN_EDGE_MARGIN_METERS = 0.5

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
	return steps
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

local function shifted_position(step, position, shift_meters)
	if shift_meters == 0 then return position end
	if not step.length or step.length <= 0 then return nil end
	local direction = step.is_walked_backward and -1 or 1
	local relative_position = position.relative_position + direction * shift_meters / step.length
	local margin = MIN_EDGE_MARGIN_METERS / step.length
	if relative_position <= margin or relative_position >= 1 - margin then return nil end
	return { relative_position = relative_position, step_count = position.step_count, shift_meters = shift_meters }
end

local function shift_candidates(base_shift)
	local candidates = { base_shift }
	for _, candidate in ipairs({ base_shift + SHIFT_STEP_METERS, base_shift - SHIFT_STEP_METERS }) do
		if math.abs(candidate) <= MAX_SHIFT_METERS then candidates[#candidates + 1] = candidate end
	end
	return candidates
end

local function submit_build_proposal(marker_entity, steps, value_step)
	local marker_edge_object = api.engine.getComponent(marker_entity, api.type.ComponentType.EDGE_OBJECT)
	local base_params = type(marker_edge_object.params) == "table" and marker_edge_object.params or {}
	local start_value = value_from_params(base_params)
	local carries_shift = is_meter_display_on(base_params)

	local function step_with_positions(step, positions)
		return { edge = step.edge, is_left = step.is_left, length = step.length, is_walked_backward = step.is_walked_backward, positions = positions }
	end

	local function errors_of_step(step)
		local step_proposal, step_context = build_proposal(marker_edge_object, base_params, start_value, value_step, { step })
		if not step_proposal then return "no markers" end
		return proposal_errors(step_proposal, step_context)
	end

	local buildable_steps = {}
	local current_shift = 0
	for _, step in ipairs(steps) do
		local whole_positions = {}
		for _, position in ipairs(step.positions) do
			whole_positions[#whole_positions + 1] = shifted_position(step, position, current_shift)
		end
		local whole_step = #whole_positions == #step.positions and step_with_positions(step, whole_positions) or nil
		local errors = whole_step == nil and "marker outside of the edge" or errors_of_step(whole_step)
		if not errors then
			buildable_steps[#buildable_steps + 1] = whole_step
		else
			local kept_positions, shift_notes = {}, {}
			local running_shift = current_shift
			for _, position in ipairs(step.positions) do
				local base_shift = carries_shift and running_shift or 0
				for _, candidate_shift in ipairs(shift_candidates(base_shift)) do
					local candidate = shifted_position(step, position, candidate_shift)
					if candidate and not errors_of_step(step_with_positions(step, { candidate })) then
						kept_positions[#kept_positions + 1] = candidate
						if carries_shift then running_shift = candidate_shift end
						if candidate_shift ~= 0 then
							shift_notes[#shift_notes + 1] = string.format("step %d %+d m", position.step_count, candidate_shift)
						end
						break
					end
				end
			end
			if carries_shift then current_shift = running_shift end
			local reduced_step = step_with_positions(step, kept_positions)
			local is_reduced_step_valid = #kept_positions > 0 and not errors_of_step(reduced_step)
			log_message(string.format("edge %s: %s, kept %d of %d markers%s%s", tostring(step.edge), errors, is_reduced_step_valid and #kept_positions or 0, #step.positions,
				#kept_positions > 0 and not is_reduced_step_valid and " (rejected together)" or "",
				#shift_notes > 0 and (", shifted: " .. table.concat(shift_notes, ", ")) or ""))
			if is_reduced_step_valid then buildable_steps[#buildable_steps + 1] = reduced_step end
		end
	end

	local proposal, context, marker_count, all_params_applied = build_proposal(marker_edge_object, base_params, start_value, value_step, buildable_steps)
	if not proposal then return end
	local combined_errors = proposal_errors(proposal, context)
	if combined_errors then
		log_message("combined proposal rejected: " .. combined_errors .. "; filtering colliding markers")
		local accepted_steps = {}
		local function steps_with_candidate(candidate)
			local candidate_steps = {}
			for _, accepted_step in ipairs(accepted_steps) do
				candidate_steps[#candidate_steps + 1] = accepted_step
			end
			candidate_steps[#candidate_steps + 1] = candidate
			return candidate_steps
		end
		local function errors_of_steps(candidate_steps)
			local candidate_proposal, candidate_context = build_proposal(marker_edge_object, base_params, start_value, value_step, candidate_steps)
			if not candidate_proposal then return "no markers" end
			return proposal_errors(candidate_proposal, candidate_context)
		end

		for _, step in ipairs(buildable_steps) do
			if not errors_of_steps(steps_with_candidate(step)) then
				accepted_steps[#accepted_steps + 1] = step
			else
				local kept_positions = {}
				for _, position in ipairs(step.positions) do
					local candidate_positions = {}
					for _, kept_position in ipairs(kept_positions) do
						candidate_positions[#candidate_positions + 1] = kept_position
					end
					candidate_positions[#candidate_positions + 1] = position
					local candidate_step = step_with_positions(step, candidate_positions)
					local errors = errors_of_steps(steps_with_candidate(candidate_step))
					if errors then
						log_message(string.format("edge %s: marker step %d rejected in combined proposal: %s", tostring(step.edge), position.step_count, errors))
					else
						kept_positions[#kept_positions + 1] = position
					end
				end
				if #kept_positions > 0 then
					accepted_steps[#accepted_steps + 1] = step_with_positions(step, kept_positions)
				end
			end
		end

		buildable_steps = accepted_steps
		proposal, context, marker_count, all_params_applied = build_proposal(marker_edge_object, base_params, start_value, value_step, buildable_steps)
		if not proposal then return end
		combined_errors = proposal_errors(proposal, context)
		if combined_errors then
			log_message("combined proposal remains invalid: " .. combined_errors)
			return
		end
	end
	api.cmd.sendCommand(api.cmd.makeWorldBuildProposalCmd(proposal, context, false, true))
	log_message("sent " .. marker_count .. " new markers (" .. tostring(marker_edge_object.edgeObjectConstruction) .. ", params set " .. tostring(all_params_applied) .. ")")
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
	local succeeded, error_message = pcall(on_post_build_proposal, event_params, job_state)
	if not succeeded then log_message("event error: " .. tostring(error_message)) end
	state:set(job_state)
end

local function run_job(job)
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
	local steps, skip_reason = plan_new_markers(job.marker, job.distance, max_count, stop_target_from_params(edge_object.params))
	if not steps then
		log_message("job " .. job.id .. " skipped: " .. tostring(skip_reason))
	elseif #steps > 0 then
		submit_build_proposal(job.marker, steps, value_step)
	end
end

local function gui_update(user_params, state, gui_state)
	local job_state = state:get()
	local jobs = type(job_state) == "table" and type(job_state.jobs) == "table" and job_state.jobs or {}
	local gui_progress = gui_state:get()
	if type(gui_progress) ~= "table" or gui_progress.done == nil then
		local newest_job_id = 0
		for _, job in ipairs(jobs) do newest_job_id = math.max(newest_job_id, job.id or 0) end
		gui_state:set({ done = newest_job_id })
		return
	end
	local done_job_id = gui_progress.done
	for _, job in ipairs(jobs) do
		if (job.id or 0) > done_job_id then
			local succeeded, error_message = pcall(run_job, job)
			if not succeeded then log_message("job " .. job.id .. " failed: " .. tostring(error_message)) end
			done_job_id = job.id
		end
	end
	if done_job_id ~= gui_progress.done then gui_state:set({ done = done_job_id }) end
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
