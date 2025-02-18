objectdef obj_Configuration_PI inherits obj_Configuration_Base
{
    method Initialize()
    {
        This[parent]:Initialize["PI"]
    }

    	member:settingsetref SafeBookmarksRef()
	{
		if !${ConfigManager.ConfigRoot.FindSet[${This.SetName}].FindSet[SafeBookmarks](exists)}
		{
			This.ConfigRef:AddSet[SafeBookmarks]
		}
		return ${ConfigManager.ConfigRoot.FindSet[${This.SetName}].FindSet[SafeBookmarks]}
	}

    	method Set_Default_Values()
	{
		ConfigManager.ConfigRoot:AddSet[${This.SetName}]
		This.ConfigRef:AddSet[SafeBookmarks]
		This.ConfigRef:AddSetting[MunitionStorage, Personal Hangar]
		This.ConfigRef:AddSetting[Prefix,Salvage:]
		This.ConfigRef:AddSetting[Dropoff,""]
	}

    Setting(string, Prefix, SetPrefix)
	Setting(string, Dropoff, SetDropoff)
	Setting(string, MunitionStorage, SetMunitionStorage)
	Setting(string, MunitionStorageFolder, SetMunitionStorageFolder)
    Setting(string, ExtremelySharedDBPath, SetExtremelySharedDBPath)
    Setting(string, ExtremelySharedDBPrefix, SetExtremelySharedDBPrefix)

    Setting(string, Planet1, SetPlanet1)
    Setting(string, Planet1matt1, SetPlanet1matt1)
    Setting(string, Planet1matt1Qty, SetPlanet1matt1Qty)
    Setting(string, Planet1matt1, SetPlanet1matt1)
    Setting(string, Planet1matt1, SetPlanet1matt1)
    Setting(string, Planet2, SetPlanet2)
    Setting(string, Planet3, SetPlanet3)
    Setting(string, Planet4, SetPlanet4)
    Setting(string, Planet5, SetPlanet5)
    Setting(string, Planet6, SetPlanet6)
}

objectdef obj_PI inherits obj_StateQueue
{
    variable obj_Configuration_PI Config
	variable obj_PIUI LocalUI
    variable bool LargestBayRefreshed
    variable index:string 	GlobalStringIndex

    method Initialize()
    {
        This[parent]:Initialize
		DynamicAddBehavior("PI", "Dedicated PI")
    }

    	method Start()
	{
		This:LogInfo["obj_PI", "Starting", "g"]
		if ${This.IsIdle}
		{
			This:QueueState["PIhome", 500]
		}

        	member:bool PIhome()
	{
		if ${Client.InSpace}
		{
			This:InsertState["PIhome", 2500]
			This:InsertState["PINavigateToStation",3000]
			return TRUE		
		}
		; Is it time to halt? Or are we close to downtime? Only goes off when we are in a station.
		if ${Me.InStation} && (${Config.Halt} || ${halt} || ${Utility.DowntimeClose})
		{
			This:QueueState["HaltBot"]
			return TRUE
		}
		; Are we full or have an invalid ship cargo (we're on the wrong inventory window).
		if ${Me.InStation} && ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].UsedCapacity} < 0
		{
			This:InsertState["CheckCargoHold",3000]
			This:InsertState["RefreshCargoBayState",3000]
			return TRUE
		}
		if ${Me.InStation} && ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].UsedCapacity} > 1 
		{
			This:InsertState["PIhome",3000]
			This:InsertState["Traveling",5000]
			This:InsertState["Offload",3000]
			return TRUE		
		}
        if ${Me.InStation} && ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar].UsedCapacity} > 1 
		{
			This:InsertState["PIhome",3000]
			This:InsertState["Traveling",5000]
			This:InsertState["Offload",3000]
			return TRUE		
		}
		; We are not full, check for valid bookmarks in the DB. We don't want to hit this too terribly often. I will never be convinced that reads are non-blocking no matter what.
		; If we find BMs we will not return to this state directly.
		This:InsertState["PIhome",5000]
		This:InsertState["Idle",10000]
		return TRUE
	}

    ; This is where we will navigate back to our Home Structure
	member:bool PINavigateToStation()
	{
		if ${Config.Dropoff.NotNULLOrEmpty}
		{
			Move:Bookmark[${Config.Dropoff}]
			This:InsertState["Traveling",5000]
			return TRUE
		}
		else
		{
			This:LogInfo["No Home Structure BM, thats bad. Stopping."]
			This:Stop
			return TRUE
		}
	}

    	member:bool Offload()
	{
		switch ${Config.MunitionStorage}
		{
			case Personal Hangar
				Cargo:At[${Config.Dropoff}]:Unload
				break
			default
				Cargo:At[${Config.Dropoff},${Config.MunitionStorage},${Config.MunitionStorageFolder},${Config.DropoffContainer}]:Unload
				break
		}
		return TRUE
	}
    	member:bool CheckCargoHold()
	{
		if !${Client.Inventory}
		{
			return FALSE
		}
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].UsedCapacity} / ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].Capacity} > 0.75 && ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar].UsedCapacity} / ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar].Capacity} > 95
		{
			This:LogInfo["obj_PI", "Unload trip required", "g"]
			This:QueueState["Offload"]
			This:QueueState["Traveling"]
		}
		else
		{
			This:LogInfo["obj_PI", "Unload trip not required", "g"]
		}
		This:QueueState["PIhome", 3000]
		return TRUE
	}
}