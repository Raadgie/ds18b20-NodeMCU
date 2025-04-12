--- @module ds18b20
-- Module for working with DS18B20 temperature sensors using the 1-Wire bus.
-- Provides functions to scan for devices, read temperature, read configuration,
-- and set alarm thresholds. Supports both powered and parasite power modes.
--
-- @author Raadgie
-- @release 1.0
-- @license MIT
-- @see https://www.maximintegrated.com/en/products/DS18B20.html
-- @usage
--     local ds18, devices = require ("ds18b20").create (3, 1)
--     ds18.broadcastConvertT (function ()
--         for i, addr in ipairs (devices) do
--             local result = ds18.readScratchpad (addr)
--             print (result.temp)
--         end
--     end)

local modname = ...
local M = {}

local parasite_power, bus_pin

local convert_time = 750 -- max conversion time (for 12-bit resolution)
local EEPROM_time = 10   -- EEPROM write time in milliseconds

--- Scans the 1-Wire bus and returns a list of found devices.
-- @param pin            1-Wire bus pin number
-- @param alarm_search   optional, 1 = search only devices with active alarm
-- @return table         with ROM addresses of found devices
function M.scan (pin, alarm_search)
    local addr
    local crc
    local device = 1
    local devices = {}
    local alarm = (alarm_search == 0 or alarm_search == 1) and alarm_search or nil

    ow.reset_search (pin)

    repeat
        addr = ow.search (pin, alarm)

        if addr then
            crc = ow.crc8 (string.sub (addr, 1, 7))
            if crc == addr:byte (8) then
                devices [device] = addr
                device = device + 1
            else
                print ("ROM CRC error during scan")
            end
        end
    until addr == nil

    return devices
end

--- Starts a temperature conversion on a specific device.
-- @param device     8-byte device address
-- @param callback   function to call after conversion is done
function M.convertT (device, callback)
    assert (device, "No device address provided!")
    assert (type(callback) == "function", "Callback must be a function!")

    ow.reset (bus_pin)
    ow.select (bus_pin, device)
    ow.write (bus_pin, 0x44, parasite_power)

    tmr.create ():alarm (convert_time, tmr.ALARM_SINGLE, function ()
        if parasite_power == 1 then ow.depower (bus_pin) end
        callback ()
    end)
end

--- Starts temperature conversion on all devices (using Skip ROM).
-- @param callback   function to call after conversion is done
function M.broadcastConvertT (callback)
    assert (type (callback) == "function", "Callback must be a function!")

    ow.reset (bus_pin)
    ow.skip (bus_pin)
    ow.write (bus_pin, 0x44, parasite_power)

    tmr.create ():alarm (convert_time, tmr.ALARM_SINGLE, function ()
        if parasite_power == 1 then ow.depower (bus_pin) end
        callback ()
    end)
end

--- Reads and decodes the scratchpad data from the sensor.
-- @param  device   8-byte device address
-- @return table    { temp, th, tl, resolution }
-- @return string   error message (or nil on success)
function M.readScratchpad (device)
    assert (device, "No device address provided!")

    ow.reset (bus_pin)
    ow.select (bus_pin, device)
    ow.write (bus_pin, 0xBE, parasite_power)

    local data = ow.read_bytes (bus_pin, 9)
    if not data or #data ~= 9 then
        return nil, "Read error"
    end

    local crc = ow.crc8 (string.sub (data, 1, 8))
    if crc ~= data:byte (9) then
        return nil, "CRC error"
    end

    local t_raw = bit.bor (data:byte (1), bit.lshift (data:byte (2), 8))
    if bit.isset (t_raw, 15) then
        t_raw = t_raw - 65536
    end
    local temp_c = t_raw * 0.0625

    local resolution_lookup = {
        [0x1F] = 9,
        [0x3F] = 10,
        [0x5F] = 11,
        [0x7F] = 12
    }

    local resolution = resolution_lookup [data:byte (5)] or 12

    return {
        temp = temp_c,
        th = data:byte (3),
        tl = data:byte (4),
        resolution = resolution,
    }
end

--- Sets alarm thresholds and optionally the resolution.
-- @param device            device address
-- @param th                upper temperature limit (integer)
-- @param tl                lower temperature limit (integer)
-- @param resolution_bits   optionally 9, 10, 11, or 12 bits (default 12)
function M.setAlarmLimits (device, th, tl, resolution_bits)
    assert (device, "No device address provided!")
    assert (th and tl, "Must provide TH and TL!")

    local config_map = {
        [9]  = 0x1F,
        [10] = 0x3F,
        [11] = 0x5F,
        [12] = 0x7F
    }

    local config = config_map [resolution_bits or 12] or 0x7F

    ow.reset (bus_pin)
    ow.select (bus_pin, device)
    ow.write (bus_pin, 0x4E, parasite_power)
    ow.write (bus_pin, th, parasite_power)
    ow.write (bus_pin, tl, parasite_power)
    ow.write (bus_pin, config, parasite_power)

    ow.reset (bus_pin)
    ow.select (bus_pin, device)
    ow.write (bus_pin, 0x48, parasite_power)

    tmr.delay (EEPROM_time * 10e3)

    if parasite_power == 1 then ow.depower (bus_pin) end
end

--- Initializes the DS18B20 module and sets up the 1-Wire bus.
-- @param pin       pin number (1–12) for the 1-Wire bus
-- @param power     0 = powered, 1 = parasite power, nil = no power
-- @return M        table with module functions
-- @return devices  table of detected ROM addresses
function M.create (pin, power)
    assert (pin, "No pin set for 1-Wire bus!")

    bus_pin = pin
    parasite_power = (power == 0 or power == 1) and power or nil

    ow.setup (pin)
    local devices = M.scan (bus_pin)

    package.loaded [modname] = nil
    M.create = nil

    return M, devices
end

return M
