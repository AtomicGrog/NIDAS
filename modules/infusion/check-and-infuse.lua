-- Import section

local component = require("component")

local findMatchingPattern = require("modules.infusion.find-matching-pattern")
local checkForMissingEssentia = require("modules.infusion.check-for-missing-essentia")
local getRequiredEssentia = require("modules.infusion.get-required-essentia")
local getFreeCPU = require("modules.infusion.get-free-cpu")

--

local function printIfDebug(...)
    if DEBUG then
        print(...)
    end
end

local hasWarnedAboutMissingEssentia = false
local function setCheckAndInfuse(namespace)
    local meInterface = namespace.infusionData.meInterface
    local transposer = namespace.infusionData.transposer

    -- TODO: Order missing essentia
    local function warnAboutMissingEssentia(missingEssentia, label)
        printIfDebug("WARNING! NOT ENOUGH ESSENTIA" .. (label and " TO MAKE " .. string.upper(label) .. "!" or "!"))
        printIfDebug("Missing:")
        for essentia, amount in pairs(missingEssentia) do
            printIfDebug("  " .. essentia .. ": " .. amount)
        end
        printIfDebug()
        hasWarnedAboutMissingEssentia = true
    end

    local function emptyCenterPedestal()
        while transposer.getStackInSlot(namespace.infusionData.centerPedestalNumber, 1) do
            transposer.transferItem(
                namespace.infusionData.centerPedestalNumber,
                namespace.infusionData.outputSlotNumber
            )
            os.sleep(0)
        end
    end

    local request
    local function checkAndInfuse()
        if getFreeCPU(meInterface.address) then
            local itemsInChest = {}
            -- Adds all items in the chest connected through the storage bus to the list
            for item in meInterface.allItems() do
                if item.size > 0 then
                    table.insert(itemsInChest, item)
                end
            end

            local pattern = findMatchingPattern(itemsInChest, meInterface.address)
            if pattern then
                local label
                for _, output in ipairs(pattern.outputs) do
                    if output.name then
                        label = output.name
                        break
                    end
                end

                local missingEssentia = checkForMissingEssentia(namespace.recipes[label] or {essentia = {}})
                if not namespace.recipes[label] or not missingEssentia then
                    local craftable = meInterface.getCraftables({label = label})[1]
                    printIfDebug("Crafting " .. label)
                    request = craftable.request()

                    local isCanceled, reason = request.isCanceled()
                    if isCanceled then
                        printIfDebug("Request cancelled. Please clean up your altar if that is the case")
                        printIfDebug(reason)
                        printIfDebug()
                        return
                    end

                    -- TODO: event-based, non-blocking code

                    -- Waits for an item to be in the center pedestal
                    local itemLabel
                    local item
                    while not itemLabel do
                        item = transposer.getStackInSlot(namespace.infusionData.centerPedestalNumber, 1)
                        itemLabel = item and item.label
                        os.sleep(0)
                    end

                    -- Starts the infusion
                    component.redstone.setOutput({15, 15, 15, 15, 15, 15})
                    component.redstone.setOutput({0, 0, 0, 0, 0, 0})

                    -- Checks for the required essentia on the first time the recipe is crafted
                    if not namespace.recipes[label] and not request.isCanceled() then
                        local inputs = {}
                        for _, input in ipairs(pattern and pattern.inputs or {}) do
                            -- Searches for input items in the pattern
                            if input.name then
                                table.insert(inputs, input.name)
                            end
                        end

                        namespace.recipes[label] = {
                            inputs = inputs,
                            essentia = getRequiredEssentia(namespace.runicMatrix.address)
                        }
                        namespace.save()

                        missingEssentia = checkForMissingEssentia(namespace.recipes[label])
                        if missingEssentia then
                            warnAboutMissingEssentia(missingEssentia, label)

                            emptyCenterPedestal()

                            printIfDebug("Removed " .. itemLabel .. " from the center pedestal. Sorry for the flux.")
                            printIfDebug("Please cancel the craft manually.")
                            printIfDebug()
                            return
                        end
                    end

                    -- TODO: event-based non-blocking code

                    -- Waits for the item in the center pedestal to change
                    while itemLabel == item.label do
                        item = transposer.getStackInSlot(namespace.infusionData.centerPedestalNumber, 1) or {}
                        os.sleep(0)
                    end

                    emptyCenterPedestal()

                    if request.isDone() then
                        printIfDebug("Done")
                    else
                        printIfDebug("Oh, oh...")
                        printIfDebug("Removed " .. item.label .. " from the pedestal.")
                        printIfDebug("But the craft for " .. label .. " is still going in the ME system.")
                        printIfDebug("Please cancel the craft manually.")
                        printIfDebug("Are you using a dummy item?")
                    end
                    printIfDebug()
                    hasWarnedAboutMissingEssentia = false
                else
                    if not hasWarnedAboutMissingEssentia then
                        warnAboutMissingEssentia(missingEssentia, label)
                    end
                end
            else
                hasWarnedAboutMissingEssentia = false
            end
        end
    end
    return checkAndInfuse
end

return setCheckAndInfuse
