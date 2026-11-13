-- Lets the RLS business computer remove parts that have core slots or numbered cargo slots.
--
-- Two faults, both fixed by wrapping RLS at runtime so no RLS code is copied into this mod:
--
-- 1. Removing a part also adds a removal row for everything under it. The core-part check reads
--    every row, so a core slot under the part (a seat's occupant, a muffler's tips) rejects the
--    whole cart. Those children go with the parent anyway, so only the rows the player chose are
--    checked now. Removing a part in a core slot itself is still refused.
--
-- 2. Numbered cargo slots describe themselves with a {txt, ctx} translation table. RLS passes it
--    to the UI as the slot name, where sorting names (localeCompare) fails. It becomes text here.

local M = {}

local TAG = "xRlsBusinessParts"
local PREVIEW_MODULE = "overhaul/career/business/partCustomization/preview"
local LABELS_MODULE = "overhaul/lib/parts/slotLabels"
local OWNER_EXTENSION = "overhaul_career_business_partCustomization"

local warned = {}

local function warnOnce(message)
  if warned[message] then return end
  warned[message] = true
  log("W", TAG, message)
end

local function isRemovalRow(part)
  return part.emptyPlaceholder or part.partName == "" or not part.partName
end

-- True when a slot above this path is also being removed in the same cart.
local function parentIsBeingRemoved(slotPath, removedPaths)
  local parent = slotPath:match("^(.*/)[^/]+/$")
  while parent and parent ~= "/" do
    if removedPaths[parent] then return true end
    parent = parent:match("^(.*/)[^/]+/$")
  end
  return false
end

-- The cart without removal rows that are only there because their parent is being removed.
function M.withoutChildRemovals(parts)
  local removedPaths = {}
  for _, part in ipairs(parts) do
    if isRemovalRow(part) and part.slotPath then removedPaths[part.slotPath] = true end
  end

  local kept = {}
  for _, part in ipairs(parts) do
    if not (isRemovalRow(part) and part.slotPath and parentIsBeingRemoved(part.slotPath, removedPaths)) then
      table.insert(kept, part)
    end
  end
  return kept
end

-- Readable text for a {txt, ctx} slot description, such as "Cargo Box M A".
function M.descriptionTableToText(description, slotName)
  local context = description.ctx
  if type(context) ~= "table" or type(context.name) ~= "string" then return slotName end
  local name = context.name:match("([^%.]+)$") or context.name
  if context.number ~= nil then return name .. " " .. tostring(context.number) end
  return name
end

local function hookSlotLabels()
  local ok, labels = pcall(require, LABELS_MODULE)
  if not ok or type(labels) ~= "table" or type(labels.getLabel) ~= "function" then
    warnOnce("RLS slot labels not found; cargo slot names are unchanged")
    return
  end
  if labels.xRlsBusinessPartsHooked then return end

  local getLabel = labels.getLabel
  labels.getLabel = function(slotName, slotInfo, translate)
    local description = slotInfo and slotInfo.description
    if type(description) == "table" and not description.description then
      local text = M.descriptionTableToText(description, slotName)
      return getLabel(slotName, {description = text}, translate)
    end
    return getLabel(slotName, slotInfo, translate)
  end
  labels.xRlsBusinessPartsHooked = true
  log("I", TAG, "Slot label hook active")
end

local function wrapCoreCheck(previewApi)
  local check = previewApi and previewApi.cartHasBlockedCoreRemovals
  if type(check) ~= "function" then
    warnOnce("RLS core removal check not found; removal rules are unchanged")
    return
  end
  previewApi.cartHasBlockedCoreRemovals = function(parts, session, vehicleData)
    if type(parts) ~= "table" then return check(parts, session, vehicleData) end
    return check(M.withoutChildRemovals(parts), session, vehicleData)
  end
end

-- RLS builds the preview API once per load of its owner extension, so the builder is wrapped.
local function hookPreview()
  local ok, installer = pcall(require, PREVIEW_MODULE)
  if not ok or type(installer) ~= "table" or type(installer.new) ~= "function" then
    warnOnce("RLS preview module not found; removal rules are unchanged")
    return
  end
  if installer.xRlsBusinessPartsHooked then return end

  local new = installer.new
  installer.new = function(inputs)
    local previewApi = new(inputs)
    wrapCoreCheck(previewApi)
    return previewApi
  end
  installer.xRlsBusinessPartsHooked = true
  log("I", TAG, "Core removal hook active")

  -- An owner loaded before this hook still holds the unwrapped API, so it is built again.
  if rawget(_G, OWNER_EXTENSION) then
    extensions.reload(OWNER_EXTENSION)
  end
end

local function install()
  hookSlotLabels()
  hookPreview()
end

M.onExtensionLoaded = install
M.onOverhaulActive = install

return M
