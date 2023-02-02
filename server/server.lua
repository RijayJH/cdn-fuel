-- Variables
local QBCore = exports['qb-core']:GetCoreObject()

local function GlobalTax(value)
	local tax = (value / 100 * Config.GlobalTax)
	return tax
end

--- Events ---

if Config.RenewedPhonePayment then
	RegisterNetEvent('cdn-fuel:server:phone:givebackmoney', function(amount)
		local src = source
		local player = QBCore.Functions.GetPlayer(src)
		player.Functions.AddMoney("bank", math.ceil(amount), "Refund, for Unused Fuel @ Gas Station!")
	end)
end

lib.callback.register('cdn_fuel:getfuel', function(source)
	local src = source
	local fuel = exports.ox_inventory:Search(src, 1, 'jerrycan')
	for k, v in pairs(fuel) do
        fuel = v
        break
    end
	return tonumber(fuel.metadata.cdn_fuel)
end)

lib.callback.register('cdn_fuel:getsyphon', function(source)
	local src = source
	local fuel = exports.ox_inventory:Search(src, 1, 'syphoningkit')
	for k, v in pairs(fuel) do
        fuel = v
        break
    end
	return tonumber(fuel.metadata.cdn_syphon)
end)

RegisterNetEvent("cdn-fuel:server:OpenMenu", function(amount, inGasStation, hasWeapon, purchasetype)
	local src = source
	if not src then return end
	local player = QBCore.Functions.GetPlayer(src)
	if not player then return end
	local tax = GlobalTax(amount)
	local total = math.ceil(amount + tax)
	local fuelamounttotal = (amount / Config.CostMultiplier)
	if amount < 1 then TriggerClientEvent('QBCore:Notify', src, "You can't refuel a negative amount!", 'error') return end
	if inGasStation == true and not hasWeapon then
		if Config.RenewedPhonePayment and purchasetype == "bank" then
			TriggerClientEvent("cdn-fuel:client:phone:PayForFuel", src, fuelamounttotal)
		else
			TriggerClientEvent('qb-menu:client:openMenu', src, {
				{
					header = "Gas Station",
					isMenuHeader = true,
					icon = "fas fa-gas-pump",
				},
				{
					header = "",
					icon = "fas fa-info-circle",
					isMenuHeader = true,
					txt = 'The total cost is going to be: $'..total..' including taxes.' ,
				},
				{
					header = "Confirm",
					icon = "fas fa-check-circle",
					txt = 'I would like to purchase the fuel.' ,
					params = {
						event = "cdn-fuel:client:RefuelVehicle",
						args = {
							fuelamounttotal = fuelamounttotal, 
							purchasetype = purchasetype,
						}
					}
				},
				{
					header = "Cancel",
					txt = "I actually don't want fuel anymore.", 
					icon = "fas fa-times-circle",
				},
			})
		end
	end
end)

RegisterNetEvent("cdn-fuel:server:PayForFuel", function(amount, purchasetype)
	local src = source
	if not src then return end
	local player = QBCore.Functions.GetPlayer(src)
	if not player then return end
	local tax = GlobalTax(amount)
	local total = math.ceil(amount + tax)
	local fuelprice = (Config.CostMultiplier * 1)
	player.Functions.RemoveMoney(purchasetype, total, "Gasoline @ " ..fuelprice.." / L")
end)

RegisterNetEvent("cdn-fuel:server:purchase:jerrycan", function(purchasetype)
	local src = source if not src then return end
	local Player = QBCore.Functions.GetPlayer(src) if not Player then return end
	local tax = GlobalTax(Config.JerryCanPrice) local total = math.ceil(Config.JerryCanPrice + tax)
	local moneyremovetype = purchasetype
	if purchasetype == "bank" then
		moneyremovetype = "bank"
	elseif purchasetype == "cash" then
		moneyremovetype = "cash"
	end
	local info = {
		gasamount = Config.JerryCanGas,
	}
	if exports.ox_inventory:CanCarryItem(src, 'jerrycan', 1) then -- Dont remove money if AddItem() not possible!
		Player.Functions.RemoveMoney(moneyremovetype, total, "Purchased Jerry Can.")
		exports.ox_inventory:AddItem(src, 'jerrycan', 1, { cdn_fuel = '0' })
	end

end)
-- Jerry Can --

QBCore.Functions.CreateUseableItem("jerrycan", function(source, item)
	local src = source
	TriggerClientEvent('cdn-fuel:jerrycan:refuelmenu', src, item)
end)



--- Syphoning ---
if Config.UseSyphoning then
	QBCore.Functions.CreateUseableItem("syphoningkit", function(source, item)
		local src = source
		TriggerClientEvent('cdn-syphoning:syphon:menu', src, item)
	end)
end

RegisterNetEvent('cdn-fuel:info', function(type, amount, srcPlayerData, itemdata)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local srcPlayerData = srcPlayerData
	if itemdata == "jerrycan" then 
		if amount < 1 or amount > Config.JerryCanCap then if Config.FuelDebug then print("Error, amount is invalid (< 1 or > "..Config.SyphonKitCap..")! Amount:" ..amount) end return end
	elseif itemdata == "syphoningkit" then
		if amount < 1 or amount > Config.SyphonKitCap then if Config.SyphonDebug then print("Error, amount is invalid (< 1 or > "..Config.SyphonKitCap..")! Amount:" ..amount) end return end
	end
	print(itemdata)
	local jerry_can = exports.ox_inventory:Search(source, 1, itemdata)
	for k, v in pairs(jerry_can) do
        jerry_can = v
        break
    end
	local fuel_amount = tonumber(jerry_can.metadata.cdn_fuel)
    if type == "add" then
        fuel_amount = fuel_amount + amount
		jerry_can.metadata.cdn_fuel = tostring(fuel_amount)
		exports.ox_inventory:SetMetadata(src, jerry_can.slot, jerry_can.metadata)
    elseif type == "remove" then
        fuel_amount = fuel_amount - amount
		jerry_can.metadata.cdn_fuel = tostring(fuel_amount)
        exports.ox_inventory:SetMetadata(src, jerry_can.slot, jerry_can.metadata)
    else
        if Config.SyphonDebug then print("error, type is invalid!") end
    end
end)

RegisterNetEvent('cdn-syphoning:callcops', function(coords)
    TriggerClientEvent('cdn-syphoning:client:callcops', -1, coords)
end)

--- Updates ---
Citizen.CreateThread(function()
	updatePath = "/CodineDev/cdn-fuel"
	resourceName = "cdn-fuel ("..GetCurrentResourceName()..")"
	PerformHttpRequest("https://raw.githubusercontent.com"..updatePath.."/master/version", checkVersion, "GET")
end)

function checkVersion(err, responseText, headers)
    curVersion = LoadResourceFile(GetCurrentResourceName(), "version")
	if responseText == nil then print("^1"..resourceName.." check for updates failed ^7") return end
    if curVersion ~= nil and responseText ~= nil then
		if curVersion == responseText then Color = "^2" else Color = "^1" end
        print("\n^1----------------------------------------------------------------------------------^7")
        print(resourceName.."'s latest version is: ^2"..responseText.."!\n^7Installed version: "..Color..""..curVersion.."^7!\nIf needed, update from https://github.com"..updatePath.."")
        print("^1----------------------------------------------------------------------------------^7")
    end
end
