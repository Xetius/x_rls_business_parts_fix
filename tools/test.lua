-- Runs the hooks against RLS's real preview.lua and slotLabels.lua, with the game's globals stubbed.
-- Usage: luajit tools/test.lua <folder holding RLS's lua/ tree>

local rlsRoot = assert(arg[1], "pass the folder holding RLS's lua/ tree")
local extensionRoot = "lua/ge/extensions/"

local logged, reloads = {}, {}
log = function(level, tag, message) table.insert(logged, level .. " " .. message) end
extensions = {reload = function(name) table.insert(reloads, name) end}

local function preloadFile(moduleName, path)
  package.preload[moduleName] = function() return assert(loadfile(path))() end
end
package.preload["overhaul/lib/platform/capabilities"] = function() return {get = function() return {} end} end
preloadFile("overhaul/career/business/partCustomization/preview",
  rlsRoot .. "/" .. extensionRoot .. "overhaul/career/business/partCustomization/preview.lua")
preloadFile("overhaul/lib/parts/slotLabels", rlsRoot .. "/" .. extensionRoot .. "overhaul/lib/parts/slotLabels.lua")

local failures, checks = 0, 0
local function check(name, actual, expected)
  checks = checks + 1
  if actual == expected then
    print("ok    " .. name)
  else
    failures = failures + 1
    print("FAIL  " .. name .. ": got " .. tostring(actual) .. ", expected " .. tostring(expected))
  end
end

-- Real RLS behaviour before the hooks, so the test proves the fault exists.
local installer = require("overhaul/career/business/partCustomization/preview")
local labels = require("overhaul/lib/parts/slotLabels")
local inputs = {runtime = {}, parts = {}, jbeamIO = {}, jbeamSlotSystem = {}, owner = {}}
local unhooked = installer.new(inputs)

local SEAT = "/sbr_body/sbr_interior/sbr_seat_FR/"
local MUFFLER = "/sbr_body/sbr_engine/sbr_muffler/"
local session = {
  initial = {partList = {
    [SEAT] = "sbr_race_seat_FR",
    [SEAT .. "seat_occupant_FR/"] = "occupant_generic",
    [SEAT .. "race_seat_FR/"] = "seat_race_gray",
    [MUFFLER] = "sbr_muffler_race",
    [MUFFLER .. "sbr_exhausttip/"] = "sbr_exhausttip",
    ["/sbr_body/sbr_interior/"] = "sbr_interior_rally",
  }},
  slotData = {
    ["/sbr_seat_FR/"] = {},
    ["/seat_occupant_FR/"] = {coreSlot = true},
    ["/race_seat_FR/"] = {},
    ["/sbr_muffler/"] = {},
    ["/sbr_exhausttip/"] = {coreSlot = true},
    ["/sbr_interior/"] = {coreSlot = true},
  },
}
local function removal(path) return {type = "part", partName = "", emptyPlaceholder = true, slotPath = path} end
local seatCart = {removal(SEAT), removal(SEAT .. "seat_occupant_FR/"), removal(SEAT .. "race_seat_FR/")}
local mufflerCart = {removal(MUFFLER), removal(MUFFLER .. "sbr_exhausttip/")}
local cargoDescription = {txt = "ui.vehicleconfig.generic.numberedSlotName",
  ctx = {name = "ui.vehicleconfig.slot.description.Cargo Box M", number = "A"}}

check("unhooked RLS blocks removing the seat", unhooked.cartHasBlockedCoreRemovals(seatCart, session), true)
check("unhooked RLS blocks removing the muffler", unhooked.cartHasBlockedCoreRemovals(mufflerCart, session), true)
check("unhooked RLS returns a table for cargo names",
  type(labels.getLabel("cargo_load_box_M_seats_RA", {description = cargoDescription})), "table")

-- Hooks, with no owner loaded yet.
package.path = "./" .. extensionRoot .. "?.lua;" .. package.path
local mod = require("xRlsBusinessParts")
mod.onExtensionLoaded()
local hooked = installer.new(inputs)

check("seat with core occupant can be removed", hooked.cartHasBlockedCoreRemovals(seatCart, session), false)
check("muffler with core tips can be removed", hooked.cartHasBlockedCoreRemovals(mufflerCart, session), false)
check("the cart passed in keeps its rows", #seatCart, 3)
check("a core slot chosen directly is still refused",
  hooked.cartHasBlockedCoreRemovals({removal("/sbr_body/sbr_interior/")}, session), true)
check("a core child alone is still refused",
  hooked.cartHasBlockedCoreRemovals({removal(SEAT .. "seat_occupant_FR/")}, session), true)
check("a cart with core and normal rows is still refused",
  hooked.cartHasBlockedCoreRemovals({removal(SEAT), removal("/sbr_body/sbr_interior/")}, session), true)
check("a similar path isn't treated as a child",
  hooked.cartHasBlockedCoreRemovals({removal("/sbr_body/sbr_interior/sbr_seat_F/"),
    removal(SEAT .. "seat_occupant_FR/")}, session), true)
check("a part being added isn't checked",
  hooked.cartHasBlockedCoreRemovals({{partName = "sbr_seat_FR", slotPath = SEAT}}, session), false)

check("cargo slot gets a text name",
  labels.getLabel("cargo_load_box_M_seats_RA", {description = cargoDescription}), "Cargo Box M A")
check("unknown table falls back to the slot name", labels.getLabel("some_slot", {description = {txt = "x"}}), "some_slot")
check("plain names are unchanged", labels.getLabel("sbr_seat_FR", {description = "Passenger Seat"}), "Passenger Seat")
check("wrapped descriptions are unchanged",
  labels.getLabel("slot", {description = {description = "Wrapped"}}), "Wrapped")
check("a missing name uses the slot", labels.getLabel("slot", {}), "slot")
check("no owner means no reload", #reloads, 0)

-- Hooks are applied once, however often the event fires.
local newAfterHook, labelAfterHook = installer.new, labels.getLabel
mod.onOverhaulActive(true)
check("second install leaves the builder alone", installer.new, newAfterHook)
check("second install leaves the label function alone", labels.getLabel, labelAfterHook)

-- An owner that loaded first gets rebuilt.
package.loaded["xRlsBusinessParts"] = nil
package.loaded["overhaul/career/business/partCustomization/preview"] = nil
package.loaded["overhaul/lib/parts/slotLabels"] = nil
overhaul_career_business_partCustomization = {}
require("xRlsBusinessParts").onExtensionLoaded()
check("an owner loaded first is reloaded", reloads[1], "overhaul_career_business_partCustomization")

-- A different RLS version only warns.
package.loaded["xRlsBusinessParts"] = nil
package.loaded["overhaul/career/business/partCustomization/preview"] = {new = function() return {} end}
package.loaded["overhaul/lib/parts/slotLabels"] = {}
logged = {}
local changed = require("xRlsBusinessParts")
changed.onExtensionLoaded()
package.loaded["overhaul/career/business/partCustomization/preview"].new({})
local warnings = table.concat(logged, "\n")
check("missing labels only warn", warnings:find("slot labels not found", 1, true) ~= nil, true)
check("missing core check only warns", warnings:find("core removal check not found", 1, true) ~= nil, true)

print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
