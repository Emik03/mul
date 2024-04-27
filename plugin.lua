---@class HitObjectInfo
---@field StartTime number
---@field Lane 1|2|3|4|5|6|7|8
---@field EndTime number
---@field HitSound any
---@field EditorLayer integer

---@class ScrollVelocityInfo
---@field StartTime number
---@field Multiplier number

---Gets a value from the current state.
---@param identifier string
---@param defaultValue any
---@return any
function get(identifier, defaultValue)
    return state.GetValue(identifier) or defaultValue
end

---Removes duplicates from a table.
---@param list table
---@return table
function removeDuplicateValues(list)
    local hash = {}
    local newList = {}
    for _, value in ipairs(list) do
        if (not hash[value]) then
            newList[#newList + 1] = value
            hash[value] = true
        end
    end
    return newList
end

---Returns a list of unique offsets (in increasing order) of selected notes [Table]
---@return number[]
function uniqueSelectedNoteOffsets()
    local offsets = {}
    for i, hitObject in ipairs(state.SelectedHitObjects) do
        offsets[i] = hitObject.StartTime
    end
    offsets = removeDuplicateValues(offsets)
    return offsets
end

--- Returns a chronologically ordered list of SVs between two offsets/times
---@param startOffset number
---@param endOffset number
---@return ScrolVelocityInfo[]
function getSVsBetweenOffsets(startOffset, endOffset)
    local svsBetweenOffsets = {}
    for _, sv in ipairs(map.ScrollVelocities) do
        local svIsInRange = sv.StartTime >= startOffset and sv.StartTime < endOffset
        if svIsInRange then table.insert(svsBetweenOffsets, sv) end
    end
    return svsBetweenOffsets
end

---Finds the closest note to a scroll velocity point.
---@param sv ScrollVelocityInfo
---@param notes HitObjectInfo
---@return HitObjectInfo
---@return HitObjectInfo
function findAdjacentNotes(sv, notes)
    local p = notes[1]

    for _, n in pairs(notes) do
        if n > sv.StartTime then
            return p, n
        end

        p = n
    end

    return p, p
end

--- Applies the linear tween per selected region
--- @param from number
--- @param to number
function perSection(from, to)
    local offsets = uniqueSelectedNoteOffsets()
    local svs = getSVsBetweenOffsets(offsets[1], offsets[#offsets])
    local svsToAdd = {}

    for _, sv in pairs(svs) do
        local f = (sv.StartTime - svs[1].StartTime) / (svs[#svs].StartTime - svs[1].StartTime)
        local fm = from * (1 - f) + to * f
        table.insert(svsToAdd, utils.CreateScrollVelocity(sv.StartTime, sv.Multiplier * fm))
    end

    actions.PerformBatch({
        utils.CreateEditorAction(action_type.RemoveScrollVelocityBatch, svs),
        utils.CreateEditorAction(action_type.AddScrollVelocityBatch, svsToAdd)
    })
end

---Applies the linear tween per note
---@param from number
---@param to number
function perNote(from, to)
    local offsets = uniqueSelectedNoteOffsets()
    local svs = getSVsBetweenOffsets(offsets[1], offsets[#offsets])
    local svsToAdd = {}

    for _, sv in pairs(svs) do
        local b, e = findAdjacentNotes(sv, offsets)
        local f = (sv.StartTime - b) / (e - b)
        local fm = from * (1 - f) + to * f
        table.insert(svsToAdd, utils.CreateScrollVelocity(sv.StartTime, sv.Multiplier * fm))
    end

    actions.PerformBatch({
        utils.CreateEditorAction(action_type.RemoveScrollVelocityBatch, svs),
        utils.CreateEditorAction(action_type.AddScrollVelocityBatch, svsToAdd)
    })
end

-- The main function
function draw()
    imgui.Begin("mul")

    local from = get("from", 0)
    local to = get("to", 0)

    _, from = imgui.InputFloat("from", from)
    _, to = imgui.InputFloat("to", to)

    ActionButton("per section", "Y", perSection, { from, to })
    ActionButton("per note", "U", perNote, { from, to })
    if (imgui.Button("swap")) or utils.IsKeyPressed(keys.I) then
        from, to = swap(from, to)
    end

    state.SetValue("from", from)
    state.SetValue("to", to)

    imgui.End()
end

---Creates a button that runs a function using `from` and `to`.
---@param label string
---@param key string
---@param fn function
---@param tbl table
function ActionButton(label, key, fn, tbl)
    if (imgui.Button(label) or utils.IsKeyPressed(keys[key])) then
        fn(tbl[1], tbl[2])
    end
end

---Swaps two numbers.
---@param v1 number
---@param v2 number
---@return number
---@return number
function swap(v1, v2)
    local temp = v1
    v1 = v2
    v2 = temp

    return v1, v2
end
