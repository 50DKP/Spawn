//Thanks to abrandnewday, DarthNinja, HL-SDK, X3Mano, and others for your plugins that were so helpful to me in writing my plugin!
//Changelog is at the very bottom.

#pragma semicolon 1

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <updater>

#define PLUGIN_VERSION "1.0.0 Beta 22"
#define MAXENTITIES 256
#define UPDATE_URL "http://198.27.69.149/updater/spawn/update.txt"

new Handle:MerasmusBaseHP=INVALID_HANDLE;
new Handle:MerasmusHPPerPlayer=INVALID_HANDLE;
new Handle:MonoculusHPLevel2=INVALID_HANDLE;
new Handle:MonoculusHPPerPlayer=INVALID_HANDLE;
new Handle:MonoculusHPPerLevel=INVALID_HANDLE;

new Handle:adminMenu=INVALID_HANDLE;

new Float:position[3];
new trackEntity=-1;
new healthBar=-1;
new people=0;
new letsChangeThisEvent=0;

public Plugin:myinfo=
{
	name="TF2 Entity Spawner",
	author="Wliu",
	description="Allows admins to spawn entities without turning on cheats",
	version=PLUGIN_VERSION,
	url="http://www.50dkp.com"
}

public OnPluginStart()
{
	CreateConVar("spawn_version", PLUGIN_VERSION, "Plugin version (DO NOT HARDCODE)", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	RegAdminCmd("spawn", Command_Spawn, ADMFLAG_GENERIC, "Manually choose an entity to spawn!  Usage: spawn <entity> <level/health>.  0 arguments will bring up the menu.  Use spawn_help to see the list of entities.");
	RegAdminCmd("spawn_menu", Command_Menu, ADMFLAG_GENERIC, "Bring up the menu!");
	RegAdminCmd("spawn_remove", Command_Remove, ADMFLAG_GENERIC, "Remove an entity!  Usage: spawn_remove <entity|aim> <amount>.");
	RegAdminCmd("spawn_help", Command_Spawn_Help, ADMFLAG_GENERIC, "Need some help?  Come here!  Usage: spawn_help <entity>.  0 arguments will bring up the generic help text.");

	MerasmusBaseHP=FindConVar("tf_merasmus_health_base");
	MerasmusHPPerPlayer=FindConVar("tf_merasmus_health_per_player");
	MonoculusHPPerPlayer=FindConVar("tf_eyeball_boss_health_per_player");
	MonoculusHPPerLevel=FindConVar("tf_eyeball_boss_health_per_level");
	MonoculusHPLevel2=FindConVar("tf_eyeball_boss_health_at_level_2");

	HookEvent("merasmus_summoned", Event_Merasmus_Summoned, EventHookMode_Pre);
	HookEvent("eyeball_boss_summoned", Event_Monoculus_Summoned, EventHookMode_Pre);
	HookEvent("player_team", Event_Player_Change_Team, EventHookMode_Post);

	new Handle:topmenu=INVALID_HANDLE;
	if(LibraryExists("adminmenu") && ((topmenu=GetAdminTopMenu())!=INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}

	if(LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}

public OnMapStart()
{
	PrecacheGeneral();
	PrecacheMerasmus();
	PrecacheMonoculus();
	PrecacheHorsemann();
	FindHealthBar();
	people=0;
}

public OnLibraryAdded(const String:name[])
{
    if(StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}

public OnLibraryRemoved(const String:name[])
{
	if(StrEqual(name, "adminmenu"))
	{
		adminMenu=INVALID_HANDLE;
	}
}

/*==========ENTITIES==========*/
public Action:Command_Spawn(client, args)
{
	if(!IsValidClient(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Could not find the spawn point.");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}

	decl String:selection[128];
	decl String:other[128];
	if(args==1)
	{
		GetCmdArg(1, selection, sizeof(selection));
	}
	else if(args==2)
	{
		GetCmdArg(1, selection, sizeof(selection));
		GetCmdArg(2, other, sizeof(other));
	}
	else
	{
		Command_Menu(client, args);
		return Plugin_Handled;
	}
	
	if(StrEqual(selection, "cow", false))
	{
		Command_Spawn_Cow(client);
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "explosive_barrel", false))
	{
		Command_Spawn_Explosive_Barrel(client);
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "ammopack", false))
	{
		new String:size[128]="large";
		if(args==2)
		{
			size=other;
		}
		Command_Spawn_Ammopack(client, size);
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "healthpack", false))
	{
		new String:size[128]="large";
		if(args==2)
		{
			size=other;
		}
		Command_Spawn_Healthpack(client, size);
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "sentry", false))
	{
		new level=1;
		if(args==2)
		{
			level=StringToInt(other);
		}
		Command_Spawn_Sentry(client, level);
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "dispenser", false))
	{
		new level=1;
		if(args==2)
		{
			level=StringToInt(other);
		}
		Command_Spawn_Dispenser(client, level);
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "merasmus", false))
	{
		new health=-131313;
		if(args==2)
		{
			health=StringToInt(other);
		}
		Command_Spawn_Merasmus(client, health);
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "monoculus", false))
	{
		Command_Spawn_Monoculus(client, args);
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "hhh", false))
	{
		Command_Spawn_Horsemann(client);
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "tank", false))
	{
		Command_Spawn_Tank(client);
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "skeleton", false))
	{
		Command_Spawn_Skeleton(client);
		return Plugin_Handled;
	}
	else
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default}  Invalid argument!  Usage: spawn <entity> <level/health>.  0 arguments will open up the menu.");
		return Plugin_Handled;
	}
}

stock Command_Spawn_Cow(client)
{
	new entity=CreateEntityByName("prop_dynamic_override");
	if(!IsValidEntity(entity))
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return;
	}
	SetEntityModel(entity, "models/props_2fort/cow001_reference.mdl");
	DispatchSpawn(entity);
	position[2]-=10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
	SetEntityMoveType(entity, MOVETYPE_VPHYSICS);
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
	SetEntProp(entity, Prop_Data, "m_CollisionGroup", 5);
	//SetEntProp(entity, Prop_Data, "m_nSolidType", 6);  //Not working

	CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N Spawned a cow!", client);
	LogAction(client, client, "[Spawn] \"%L\" spawned a cow", client);
	return;
}

stock Command_Spawn_Explosive_Barrel(client)
{
	new entity=CreateEntityByName("prop_physics");
	if(!IsValidEntity(entity))
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return;
	}
	SetEntityModel(entity, "models/props_c17/oildrum001_explosive.mdl");
	DispatchSpawn(entity);
	position[2]-=10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
	SetEntityMoveType(entity, MOVETYPE_VPHYSICS);
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
	SetEntProp(entity, Prop_Data, "m_CollisionGroup", 5);
	//SetEntProp(entity, Prop_Data, "m_nSolidType", 6);  //Not working

	CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N spawned an explosive barrel!", client);
	LogAction(client, client, "[Spawn] \"%L\" spawned an explosive barrel", client);
	return;
}

stock Command_Spawn_Ammopack(client, String:size[128])
{
	new entity=CreateEntityByName("item_ammopack_full");
	if(StrEqual(size, "large", false))
	{
		entity=CreateEntityByName("item_ammopack_full");
	}
	else if(StrEqual(size, "medium", false))
	{
		entity=CreateEntityByName("item_ammopack_medium");	
	}
	else if(StrEqual(size, "small", false))
	{
		entity=CreateEntityByName("item_ammopack_small");
	}
	else
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Since you decided not to use the given options, the ammopack size has been set to large.");
		size="large";
		entity=CreateEntityByName("item_ammopack_full");
	}

	if(!IsValidEntity(entity))
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return;
	}
	DispatchKeyValue(entity, "OnPlayerTouch", "!self,Kill,,0,-1");
	DispatchSpawn(entity);
	position[2]-=10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
	EmitSoundToAll("items/spawn_item.wav", entity, _, _, _, 0.75);

	CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N spawned a %s ammopack!", client, size);
	LogAction(client, client, "[Spawn] \"%L\" spawned a %s ammopack", client, size);
}

stock Command_Spawn_Healthpack(client, String:size[128])
{
	new entity=CreateEntityByName("item_healthkit_full");
	if(StrEqual(size, "large", false))
	{
		entity=CreateEntityByName("item_healthkit_full");
	}
	else if(StrEqual(size, "medium", false))
	{
		entity=CreateEntityByName("item_healthkit_medium");	
	}
	else if(StrEqual(size, "small", false))
	{
		entity=CreateEntityByName("item_healthkit_small");
	}
	else
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Since you decided not to use the given options, the healthpack size has been set to large.");
		size="large";
		entity=CreateEntityByName("item_healthkit_full");
	}

	if(!IsValidEntity(entity))
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return;
	}
	DispatchKeyValue(entity, "OnPlayerTouch", "!self,Kill,,0,-1");
	DispatchSpawn(entity);
	position[2]-=10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
	EmitSoundToAll("items/spawn_item.wav", entity, _, _, _, 0.75);

	CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%s spawned %s healthpack!", client, size);
	LogAction(client, client, "[Spawn] \"%L\" spawned a %s healthpack", client, size);
}

/*==========BUILDINGS==========*/
stock Command_Spawn_Sentry(client, level=1)
{
	new Float:angles[3];
	GetClientEyeAngles(client, angles);
	angles[0]=0.0;
	decl String:model[64];
	new bullets, health, rockets;
	new team=GetClientTeam(client);
	new skin=team-2;
	if(team==_:TFTeam_Spectator)
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} You must be on either {Red}RED{Default} or {Blue}BLU{Default} to use this command.");
		return;
	}

	switch(level)
	{
		case 1:
		{
			model="models/buildables/sentry1.mdl";
			bullets=150;
			health=150;
		}
		case 2:
		{
			model="models/buildables/sentry2.mdl";
			bullets=200;
			health=180;
		}
		case 3:
		{
			model="models/buildables/sentry3.mdl";
			bullets=200;
			health=216;
			rockets=20;
		}
		default:
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Haha, no.  The sentry's level has been set to 1.  Good try though.");
			level=1;
			model="models/buildables/sentry1.mdl";
			bullets=150;
			health=150;
		}
	}

	new entity=CreateEntityByName("obj_sentrygun");
	if(!IsValidEntity(entity))
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return;
	}
	DispatchSpawn(entity);
	TeleportEntity(entity, position, angles, NULL_VECTOR);
	SetEntityModel(entity, model);

	SetEntProp(entity, Prop_Send, "m_iAmmoShells", bullets);
	SetEntProp(entity, Prop_Send, "m_iHealth", health);
	SetEntProp(entity, Prop_Send, "m_iMaxHealth", health);
	SetEntProp(entity, Prop_Send, "m_iObjectType", _:TFObject_Sentry);
	SetEntProp(entity, Prop_Send, "m_iTeamNum", team);
	SetEntProp(entity, Prop_Send, "m_nSkin", skin);
	SetEntProp(entity, Prop_Send, "m_iUpgradeLevel", level);
	SetEntProp(entity, Prop_Send, "m_iHighestUpgradeLevel", level);
	SetEntProp(entity, Prop_Send, "m_iAmmoRockets", rockets);
	SetEntPropEnt(entity, Prop_Send, "m_hBuilder", client);
	SetEntProp(entity, Prop_Send, "m_iState", 3);
	SetEntPropFloat(entity, Prop_Send, "m_flPercentageConstructed", level==1 ? 0.99:1.0);
	if(level==1)
	{
		SetEntProp(entity, Prop_Send, "m_bBuilding", 1);
	}
	SetEntProp(entity, Prop_Send, "m_bPlayerControlled", 1);
	SetEntProp(entity, Prop_Send, "m_bHasSapper", 0);
	SetEntPropVector(entity, Prop_Send, "m_vecBuildMaxs", Float:{24.0, 24.0, 66.0});
	SetEntPropVector(entity, Prop_Send, "m_vecBuildMins", Float:{-24.0, -24.0, 0.0});

	new offs=FindSendPropInfo("CObjectSentrygun", "m_iDesiredBuildRotations");
	if(offs<=0)
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Something went wrong with the build rotation!");
		return;
	}
	SetEntData(entity, offs-12, 1, 1, true);

	CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N spawned a level %i sentry!", client, level);
	LogAction(client, client, "[Spawn] \"%L\" spawned a level %i sentry", client, level);
	return;
}

stock Command_Spawn_Dispenser(client, level=1)
{
	decl String:model[128];
	new Float:angles[3];
	GetClientEyeAngles(client, angles);
	angles[0]=0.0;
	new health;
	new ammo=400;
	new team=GetClientTeam(client);
	if(team==_:TFTeam_Spectator)
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} You must be on either {Red}RED{Default} or {Blue}BLU{Default} to use this command.");
		return;
	}

	switch(level)
	{
		case 1:
		{
			model="models/buildables/dispenser.mdl";
			health=150;
		}
		case 2:
		{
			model="models/buildables/dispenser_lvl2.mdl";
			health=180;
		}
		case 3:
		{
			model="models/buildables/dispenser_lvl3.mdl";
			health=216;
		}
		default:
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Haha, no.  The dispenser's level has been set to 1.  Good try though.");
			level=1;
			model="models/buildables/dispenser.mdl";
			health=150;
		}
	}

	new entity=CreateEntityByName("obj_dispenser");
	if(!IsValidEntity(entity))
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return;
	}
	DispatchSpawn(entity);
	TeleportEntity(entity, position, angles, NULL_VECTOR);

	SetVariantInt(team);
	AcceptEntityInput(entity, "TeamNum");
	SetVariantInt(team);
	AcceptEntityInput(entity, "SetTeam");

	ActivateEntity(entity);

	SetEntProp(entity, Prop_Send, "m_iAmmoMetal", ammo);
	SetEntProp(entity, Prop_Send, "m_iHealth", health);
	SetEntProp(entity, Prop_Send, "m_iMaxHealth", health);
	SetEntProp(entity, Prop_Send, "m_iObjectType", _:TFObject_Dispenser);
	SetEntProp(entity, Prop_Send, "m_iTeamNum", team);
	SetEntProp(entity, Prop_Send, "m_nSkin", team-2);
	SetEntProp(entity, Prop_Send, "m_iUpgradeLevel", level);
	SetEntProp(entity, Prop_Send, "m_iHighestUpgradeLevel", level);
	SetEntProp(entity, Prop_Send, "m_iState", 3);
	SetEntPropVector(entity, Prop_Send, "m_vecBuildMaxs", Float:{24.0, 24.0, 55.0});
	SetEntPropVector(entity, Prop_Send, "m_vecBuildMins", Float:{-24.0, -24.0, 0.0});
	SetEntPropFloat(entity, Prop_Send, "m_flPercentageConstructed", level==1 ? 0.99:1.0);
	if(level==1)
	{
		SetEntProp(entity, Prop_Send, "m_bBuilding", 1);
	}
	SetEntPropEnt(entity, Prop_Send, "m_hBuilder", client);
	SetEntityModel(entity, model);

	new offs=FindSendPropInfo("CObjectDispenser", "m_iDesiredBuildRotations");
	if(offs<=0)
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Something went wrong with the build rotation!");
		return;
	}
	SetEntData(entity, offs-12, 1, 1, true);

	CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N spawned a level %i dispenser!", client, level);
	LogAction(client, client, "[Spawn] \"%L\" spawned a level %i dispenser", client, level);
	return;
}

/*==========BOSSES==========*/
stock Command_Spawn_Merasmus(client, health=-131313)
{
	new merasmus_health=GetConVarInt(MerasmusBaseHP);
	new merasmus_health_per_player=GetConVarInt(MerasmusHPPerPlayer);
	if(health<=0)
	{
		if(health!=-131313)  //Hacky, but oh well.
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Haha, no.  Merasmus's health has been set to the default value.  Good try though.");
		}
		health=merasmus_health+(merasmus_health_per_player*people);
	}

	new entity=CreateEntityByName("merasmus");
	if(!IsValidEntity(entity))
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return;
	}

	if(health>=0)
	{
		SetEntProp(entity, Prop_Data, "m_iHealth", health*4);
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", health*4);
	}
	else
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} {Red}ERROR:{Default} Merasmus' health was below 1!  That shouldn't be happening.");
		return;
	}
	DispatchSpawn(entity);
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);

	CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N spawned Merasmus with %i health!", client, health);
	LogAction(client, client, "[Spawn] \"%L\" spawned Merasmus with %i health", client, health);
	return;
}

stock Command_Spawn_Monoculus(client, level=1)
{
	new entity=CreateEntityByName("eyeball_boss");
	if(!IsValidEntity(entity))
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return;
	}

	if(level<=0)
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Haha, no.  Monoculus's level has been set to 1.  Good try though.");
		level=1;
	}

	if(level>1)
	{
		new monoculus_base_hp=GetConVarInt(MonoculusHPLevel2);
		new monoculus_hp_per_level=GetConVarInt(MonoculusHPPerLevel);
		new monoculus_hp_per_player=GetConVarInt(MonoculusHPPerPlayer);

		new HP=monoculus_base_hp;
		HP=(HP+((level-2)*monoculus_hp_per_level));
		if(people>10)
		{
			HP=(HP+((people-10)*monoculus_hp_per_player));
		}
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", HP);
		SetEntProp(entity, Prop_Data, "m_iHealth", HP);
		SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
	}
	else if(level<=0)
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} {Red}ERROR:{Default} Monoculus' level was below 1!  That shouldn't be happening.");
		return;
	}
	DispatchSpawn(entity);
	position[2]-=10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);

	CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N spawned a level %i Monoculus!", client, level);
	LogAction(client, client, "[Spawn] \"%L\" spawned a level %i Monoculus", client, level);
	return;
}

stock Command_Spawn_Horsemann(client)
{
	new entity=CreateEntityByName("headless_hatman");
	if(!IsValidEntity(entity))
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return;
	}
	DispatchSpawn(entity);
	position[2]-=10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);

	CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N spawned the Horseless Headless Horsemann!", client);
	LogAction(client, client, "[Spawn] \"%L\" spawned the Horseless Headless Horsemann", client);
	return;
}

stock Command_Spawn_Tank(client)
{
	new entity=CreateEntityByName("tank_boss");
	if(!IsValidEntity(entity))
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return;
	}
	DispatchSpawn(entity);
	position[2] -= 10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);

	CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N spawned a tank!", client);
	LogAction(client, client, "[Spawn] \"%L\" spawned a tank", client);
	return;
}

stock Command_Spawn_Skeleton(client)
{
	new entity=CreateEntityByName("tf_zombie");
	if(!IsValidEntity(entity))
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return;
	}
	DispatchSpawn(entity);
	position[2]-=10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned a skeleton!");
	CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N spawned a skeleton!", client);
	LogAction(client, client, "[Spawn] \"%L\" spawned a skeleton", client);
	return;
}

/*==========REMOVING ENTITIES==========*/
public Action:Command_Remove(client, args)
{
	if(!IsValidClient(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}
	
	new String:selection[128]="aim";
	new String:amountString[128]="0";
	new amount;
	if(args==1)
	{
		GetCmdArg(1, selection, sizeof(selection));
	}
	else if(args==2)
	{
		GetCmdArg(1, selection, sizeof(selection));
		GetCmdArg(2, amountString, sizeof(amountString));
		amount=StringToInt(amountString);
		if(amount<0)
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} The amount must be at least 0!");
			return Plugin_Handled;
		}
	}
	else
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Usage: spawn_remove <entity|aim>");
		return Plugin_Handled;
	}
	
	new entity=-1;
	new count=0;
	if(StrEqual(selection, "cow", false))
	{
		while((entity=FindEntityByClassname(entity, "prop_dynamic_override"))!=-1 && IsValidEntity(entity))
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")==client)
			{
				SetVariantInt(9999);
				AcceptEntityInput(entity, "Kill");
				count++;
			}
		}

		if(count!=0)
		{
			if(count==1)
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N slayed one cow!", client);
				LogAction(client, client, "[Spawn] \"%L\" slayed one cow", client);
			}
			else
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N slayed %i cows!", client, count);
				LogAction(client, client, "[Spawn] \"%L\" slayed %i cows", client, count);
			}
			count=0;
		}
		else
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Couldn't find any cows to slay!");
		}
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "explosive_barrel", false))
	{
		while((entity=FindEntityByClassname(entity, "prop_physics"))!=-1 && IsValidEntity(entity))
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")==client)
			{
				SetVariantInt(9999);
				AcceptEntityInput(entity, "Kill");
				count++;
			}
		}

		if(count!=0)
		{
			if(count==1)
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N removed one explosive barrel!", client);
				LogAction(client, client, "[Spawn] \"%L\" removed one explosive barrel", client);
			}
			else
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N removed %i explosive barrels!", client, count);
				LogAction(client, client, "[Spawn] \"%L\" removed %i explosive barrels", client, count);
			}
			count=0;
		}
		else
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Couldn't find any explosive barrels to remove!");
		}
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "ammopack", false))
	{
		while(((entity=FindEntityByClassname(entity, "item_ammopack_full"))!=-1 || (entity=FindEntityByClassname(entity, "item_ammopack_medium"))!=-1 || (entity=FindEntityByClassname(entity, "item_ammopack_small"))!=-1) && IsValidEntity(entity))
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")==client)
			{
				SetVariantInt(9999);
				AcceptEntityInput(entity, "Kill");
				count++;
			}
		}

		if(count!=0)
		{
			if(count==1)
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N removed one ammopack!", client, count);
				LogAction(client, client, "[Spawn] \"%L\" removed one ammopack", client);
			}
			else
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N removed %i ammopacks!", client, count);
				LogAction(client, client, "[Spawn] \"%L\" removed %i ammopacks", client, count);
			}
			count=0;
		}
		else
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Couldn't find any ammopacks to remove!");
		}
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "healthpack", false))
	{
		while(((entity=FindEntityByClassname(entity, "item_healthpack_full"))!=-1 || (entity=FindEntityByClassname(entity, "item_healthpack_medium"))!=-1 || (entity=FindEntityByClassname(entity, "item_healthpack_small"))!=-1) && IsValidEntity(entity))
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")==client)
			{
				SetVariantInt(9999);
				AcceptEntityInput(entity, "Kill");
				count++;
			}
		}

		if(count!=0)
		{
			if(count==1)
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N removed one healthpack!", client);
				LogAction(client, client, "[Spawn] \"%L\" removed his/her healthpack", client);
			}
			else
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N removed %i healthpacks!", client, count);
				LogAction(client, client, "[Spawn] \"%L\" removed %i healthpacks", client, count);
			}
			count=0;
		}
		else
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Couldn't find any healthpacks to remove!");
		}
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "sentry", false))
	{
		while((entity=FindEntityByClassname(entity, "obj_sentrygun"))!=-1 && IsValidEntity(entity))
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hBuilder")==client)
			{
				SetVariantInt(9999);
				AcceptEntityInput(entity, "RemoveHealth");
				count++;
			}
		}

		if(count!=0)
		{
			if(count==1)
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N destroyed one sentry.", client);
				LogAction(client, client, "[Spawn] \"%L\" destroyed one sentry", client);
			}
			else
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N destroyed %i sentries.", client, count);
				LogAction(client, client, "[Spawn] \"%L\" destroyed %i sentries", client, count);
			}
			count=0;
		}
		else
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Couldn't find any sentries to destroy!");
		}
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "dispenser", false))
	{
		while((entity=FindEntityByClassname(entity, "obj_dispenser"))!=-1 && IsValidEntity(entity))
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hBuilder")==client)
			{
				SetVariantInt(9999);
				AcceptEntityInput(entity, "RemoveHealth");
				count++;
			}
		}

		if(count!=0)
		{
			if(count==1)
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N destroyed one dispenser!", client);
				LogAction(client, client, "[Spawn] \"%L\" destroyed one dispenser", client);
			}
			else
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N destroyed %i dispensers!", client, count);
				LogAction(client, client, "[Spawn] \"%L\" destroyed %i dispensers", client, count);
			}
			count=0;
		}
		else
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Couldn't find any dispensers to destroy!");
		}
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "merasmus", false))
	{
		while((entity=FindEntityByClassname(entity, "merasmus"))!=-1 && IsValidEntity(entity))
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")==client)
			{
				new Handle:event=CreateEvent("merasmus_killed", true);
				FireEvent(event);
				SetVariantInt(9999);
				AcceptEntityInput(entity, "Kill");
				count++;
			}
		}

		if(count!=0)
		{
			if(count==1)
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N slayed one Merasmus!", client);
				LogAction(client, client, "[Spawn] \"%L\" slayed one Merasmus", client);
			}
			else
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N slayed %i Merasmuses!", client, count);
				LogAction(client, client, "[Spawn] \"%L\" slayed %i Merasmuses", client, count);
			}
			count=0;
		}
		else
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Couldn't find any Merasmuses to slay!");
		}
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "monoculus", false))
	{
		while((entity=FindEntityByClassname(entity, "eyeball_boss"))!=-1 && IsValidEntity(entity))
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")==client)
			{
				new Handle:event=CreateEvent("eyeball_boss_killed", true);
				FireEvent(event);
				SetVariantInt(9999);
				AcceptEntityInput(entity, "Kill");
				count++;
			}
		}

		if(count!=0)
		{
			if(count==1)
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N slayed one Monoculus!", client);
				LogAction(client, client, "[Spawn] \"%L\" slayed his/her Monoculus", client);
			}
			else
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N slayed %i Monoculuses!", client, count);
				LogAction(client, client, "[Spawn] \"%L\" slayed %i Monoculuses", client, count);
			}
			count=0;
		}
		else
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Couldn't find any Monoculuses to slay!");
		}
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "hhh", false))
	{
		while((entity=FindEntityByClassname(entity, "headless_hatman"))!=-1 && IsValidEntity(entity))
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")==client)
			{
				new Handle:event=CreateEvent("pumpkin_lord_killed", true);
				FireEvent(event);
				SetVariantInt(9999);
				AcceptEntityInput(entity, "Kill");
				count++;
			}
		}

		if(count!=0)
		{
			if(count==1)
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N slayed one Horseless Headless Horsemann!", client);
				LogAction(client, client, "[Spawn] \"%L\" slayed one Horseless Headless Horsemann", client);
			}
			else
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N slayed %i Horselss Headless Horsemenn!", client, count);
				LogAction(client, client, "[Spawn] \"%L\" slayed %i Horseless Headless Horsemenn", client, count);
			}
			count=0;
		}
		else
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Couldn't find any Horseless Headless Horsemenn to slay!");
		}
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "tank", false))
	{
		while((entity=FindEntityByClassname(entity, "tank_boss"))!=-1 && IsValidEntity(entity))
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")==client)
			{
				SetVariantInt(9999);
				AcceptEntityInput(entity, "Kill");
				count++;
			}
		}

		if(count!=0)
		{
			if(count==1)
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N destroyed one tank!", client);
				LogAction(client, client, "[Spawn] \"%L\" destroyed one tank", client);
			}
			else
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N destroyed %i tanks!", client, count);
				LogAction(client, client, "[Spawn] \"%L\" destroyed %i tanks", client, count);
			}
			count=0;
		}
		else
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Couldn't find any tanks to destroy!");
		}
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "skeleton", false))
	{
		while((entity=FindEntityByClassname(entity, "tf_zombie"))!=-1 && IsValidEntity(entity))
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")==client)
			{
				SetVariantInt(9999);
				AcceptEntityInput(entity, "Kill");
				count++;
			}
		}

		if(count!=0)
		{
			if(count==1)
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N slayed one skeleton!", client);
				LogAction(client, client, "[Spawn] \"%L\" slayed one skeleton", client);
			}
			else
			{
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N slayed %i skeletons!", client, count);
				LogAction(client, client, "[Spawn] \"%L\" slayed %i skeletons", client, count);
			}
			count=0;
		}
		else
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Couldn't find any skeletons to slay!");
		}
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "aim", false))
	{
		if(GetClientTeam(client)==_:TFTeam_Spectator)
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} You must be on either {Red}RED{Default} or {Blue}BLU{Default} to use this command.");
			return Plugin_Handled;
		}

		entity=GetClientAimTarget(client, false);
		if(!IsValidEntity(entity))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} {Black}DEBUG:{Default} Entity is %i", entity);
			CPrintToChat(client, "{Vintage}[Spawn]{Default} No valid entity found at aim.");
			return Plugin_Handled;
		}

		if((entity=FindEntityByClassname(entity, "obj_dispenser"))!=-1 || (entity=FindEntityByClassname(entity, "obj_sentrygun"))!=-1)
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hBuilder")==client)
			{
				SetVariantInt(9999);
				AcceptEntityInput(entity, "RemoveHealth");
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N removed a building (entity %i)!", client, entity);
				LogAction(client, client, "[Spawn] \"%L\" removed a building (entity %i)", client, entity);
				return Plugin_Handled;
			}
			else
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You don't own that building!");
				return Plugin_Handled;
			}
		}
		else
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")==client)
			{
				SetVariantInt(9999);
				AcceptEntityInput(entity, "Kill");
				CShowActivity2(client, "{Vintage}[Spawn]{Default} ", "%N removed an entity (entity %i)!", client, entity);
				LogAction(client, client, "[Spawn] \"%L\" removed an entity (entity %i)", client, entity);
				return Plugin_Handled;
			}
			else
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You don't own that entity!");
				return Plugin_Handled;
			}
		}
	}
	else
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Invalid entity!  Usage: spawn_remove <entity|aim>");
		return Plugin_Handled;
	}
}

/*==========MENUS==========*/
public Action:Command_Menu(client, args)
{
	if(!IsValidClient(client))
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}
	CreateMenuGeneral(client);
	return Plugin_Handled;
}

stock CreateMenuGeneral(client)
{
	new Handle:menu=CreateMenu(MenuHandlerGeneral);
	SetMenuTitle(menu, "Choose entity:");
	AddMenuItem(menu, "cow", "Cow");
	AddMenuItem(menu, "explosive_barrel", "Explosive Barrel");
	AddMenuItem(menu, "sentry1", "Level 1 Sentry");
	AddMenuItem(menu, "sentry2", "Level 2 Sentry");
	AddMenuItem(menu, "sentry3", "Level 3 Sentry");
	AddMenuItem(menu, "dispenser1", "Level 1 Dispenser");
	AddMenuItem(menu, "dispenser2", "Level 2 Dispenser");
	AddMenuItem(menu, "dispenser3", "Level 3 Dispenser");
	AddMenuItem(menu, "ammo_large", "Large Ammopack");
	AddMenuItem(menu, "ammo_medium", "Medium Ammopack");
	AddMenuItem(menu, "ammo_small", "Small Ammopack");
	AddMenuItem(menu, "health_large", "Large Healthpack");
	AddMenuItem(menu, "health_medium", "Medium Healthpack");
	AddMenuItem(menu, "health_small", "Small Healthpack");
	AddMenuItem(menu, "merasmus", "Merasmus");
	AddMenuItem(menu, "monoculus", "Monoculus");
	AddMenuItem(menu, "hhh", "Horseless Headless Horsemann");
	AddMenuItem(menu, "tank", "Tank");
	AddMenuItem(menu, "skeleton", "Skeleton");

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandlerGeneral(Handle:menu, MenuAction:action, client, menuPos)
{
	new String:selection[32];
	GetMenuItem(menu, menuPos, selection, sizeof(selection));
	if(action==MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if(action==MenuAction_Cancel)
	{
		if(menuPos==MenuCancel_ExitBack && menu!=INVALID_HANDLE)
		{
			DisplayTopMenu(menu, client, TopMenuPosition_LastCategory);
		}
	}
	else if(action==MenuAction_Select)
	{
		if(StrEqual(selection, "cow"))
		{
			Command_Spawn_Cow(client);
		}
		else if(StrEqual(selection, "explosive_barrel"))
		{
			Command_Spawn_Explosive_Barrel(client);
		}
		else if(StrEqual(selection, "sentry1"))
		{
			Command_Spawn_Sentry(client, 1);
		}
		else if(StrEqual(selection, "sentry2"))
		{
			Command_Spawn_Sentry(client, 2);
		}
		else if(StrEqual(selection, "sentry3"))
		{
			Command_Spawn_Sentry(client, 3);
		}
		else if(StrEqual(selection, "dispenser1"))
		{
			Command_Spawn_Dispenser(client, 1);
		}
		else if(StrEqual(selection, "dispenser2"))
		{
			Command_Spawn_Dispenser(client, 2);
		}
		else if(StrEqual(selection, "dispenser3"))
		{
			Command_Spawn_Dispenser(client, 3);
		}
		else if(StrEqual(selection, "ammo_large"))
		{
			Command_Spawn_Ammopack(client, "large");
		}
		else if(StrEqual(selection, "ammo_medium"))
		{
			Command_Spawn_Ammopack(client, "medium");
		}
		else if(StrEqual(selection, "ammo_small"))
		{
			Command_Spawn_Ammopack(client, "small");
		}
		else if(StrEqual(selection, "health_large"))
		{
			Command_Spawn_Healthpack(client, "large");
		}
		else if(StrEqual(selection, "health_medium"))
		{
			Command_Spawn_Healthpack(client, "medium");
		}
		else if(StrEqual(selection, "health_small"))
		{
			Command_Spawn_Healthpack(client, "small");
		}
		else if(StrEqual(selection, "merasmus"))
		{
			Command_Spawn_Merasmus(client);
		}
		else if(StrEqual(selection, "monoculus"))
		{
			Command_Spawn_Monoculus(client);
		}
		else if(StrEqual(selection, "hhh"))
		{
			Command_Spawn_Horsemann(client);
		}
		else if(StrEqual(selection, "tank"))
		{
			Command_Spawn_Tank(client);
		}
		else if(StrEqual(selection, "skeleton"))
		{
			Command_Spawn_Skeleton(client);
		}
		else
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} {Red}ERROR:{Default} Something went horribly wrong with the menu code!");
		}
		CreateMenuGeneral(client);
	}
}

public OnAdminMenuReady(Handle:topmenu)
{
	if(topmenu==adminMenu)
	{
		return;
	}
	adminMenu=topmenu;
	new TopMenuObject:player_commands=FindTopMenuCategory(adminMenu, ADMINMENU_PLAYERCOMMANDS);

	if(player_commands!=INVALID_TOPMENUOBJECT)
	{
		AddToTopMenu(adminMenu, "spawn", TopMenuObject_Item, AdminMenu_Spawn, player_commands, "spawn", ADMFLAG_GENERIC);
	}
}
 
public AdminMenu_Spawn(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, client, String:buffer[], maxlength)
{
	if(action==TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Spawn");
	}
	else if(action==TopMenuAction_SelectOption)
	{
		CreateMenuGeneral(client);
		RedisplayAdminMenu(topmenu, client);
	}
}

/*==========TECHNICAL STUFF==========*/
SetTeleportEndPoint(client)
{
	decl Float:angles[3];
	decl Float:origin[3];
	decl Float:buffer[3];
	decl Float:start[3];
	decl Float:distance;

	GetClientEyePosition(client, origin);
	GetClientEyeAngles(client, angles);

	new Handle:trace=TR_TraceRayFilterEx(origin, angles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);

	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(start, trace);
		GetVectorDistance(origin, start, false);
		distance=-35.0;
		GetAngleVectors(angles, buffer, NULL_VECTOR, NULL_VECTOR);
		position[0]=start[0]+(buffer[0]*distance);
		position[1]=start[1]+(buffer[1]*distance);
		position[2]=start[2]+(buffer[2]*distance);
	}
	else
	{
		CloseHandle(trace);
		return false;
	}
	CloseHandle(trace);
	return true;
}

public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
	return entity>GetMaxClients() || !entity;
}

FindHealthBar()
{
	healthBar=FindEntityByClassname(-1, "m_iBossHealthPercentageByte");
	if(healthBar==-1)
	{
		healthBar=CreateEntityByName("m_iBossHealthPercentageByte");
		if(healthBar!=-1)
		{
			DispatchSpawn(healthBar);
		}
	}
}

public Action:Event_Merasmus_Summoned(Handle:event, const String:name[], bool:dontBroadcast)
{
	SetEffects();
}

public OnMerasmusDamaged(victim, attacker, inflictor, Float:damage, damagetype)
{
	UpdateBossHealth(victim);
	UpdateDeathEvent(victim);
}

public Action:Event_Monoculus_Summoned(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(letsChangeThisEvent!=0)
	{
		new Handle:hEvent=CreateEvent(name);
		if(hEvent==INVALID_HANDLE)
		{
			return Plugin_Handled;
		}
		SetEventInt(hEvent, "level", letsChangeThisEvent);
		FireEvent(hEvent);
		letsChangeThisEvent=0;
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public OnEntityCreated(entity, const String:classname[])
{
	if(StrEqual(classname, "m_iBossHealthPercentageByte"))
	{
		healthBar=entity;
	}
	else if(trackEntity==-1 && StrEqual(classname, "merasmus"))
	{
		trackEntity=entity;
		SDKHook(entity, SDKHook_SpawnPost, UpdateBossHealth);
		SDKHook(entity, SDKHook_OnTakeDamagePost, OnMerasmusDamaged);
	}
}

stock SetEffects()
{
	new entity=-1;
	while((entity=FindEntityByClassname(entity, "merasmus"))!=-1 && IsValidEntity(entity))
	{
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 1.0);
		SetEntProp(entity, Prop_Send, "m_bGlowEnabled", 0.0);
	}
}

public OnEntityDestroyed(entity)
{
	if(entity==-1)
	{
		return;
	}
	else if(entity==trackEntity)
	{
		trackEntity=FindEntityByClassname(-1, "merasmus");
		if(trackEntity==entity)
		{
			trackEntity=FindEntityByClassname(entity, "merasmus");
		}

		if(trackEntity>-1)
		{
			SDKHook(trackEntity, SDKHook_OnTakeDamagePost, OnMerasmusDamaged);
		}
		UpdateBossHealth(trackEntity);
	}
}

public UpdateBossHealth(entity)
{
	if(healthBar==-1)
	{
		return;
	}

	new percentage;
	if(IsValidEntity(entity))
	{
		new maxHP=GetEntProp(entity, Prop_Data, "m_iMaxHealth");
		new HP=GetEntProp(entity, Prop_Data, "m_iHealth");

		if(HP<=0)
		{
			percentage=0;
		}
		else
		{
			percentage=RoundToCeil(float(HP)/(maxHP/4)*255);
		}
	}
	else
	{
		percentage=0;
	}
	SetEntProp(healthBar, Prop_Send, "m_iBossHealthPercentageByte", percentage);
}

public UpdateDeathEvent(entity)
{
	if(IsValidEntity(entity))
	{
		new maxHP=GetEntProp(entity, Prop_Data, "m_iMaxHealth");
		new HP=GetEntProp(entity, Prop_Data, "m_iHealth");
		
		if(HP<=(maxHP*0.75))
		{
			SetEntProp(entity, Prop_Data, "m_iHealth", 0);
			if(HP<=-1)
			{
				SetEntProp(entity, Prop_Data, "m_takedamage", 0, 1);
			}
		}
	}
}

public Action:Event_Player_Change_Team(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client=GetEventInt(event,"userid");
	new index=-1;
	while((index=FindEntityByClassname(index,"obj_sentrygun"))!=-1)
	{
		if(GetEntPropEnt(index,Prop_Send,"m_hBuilder")==client)
		{
			SetVariantInt(9999);
			AcceptEntityInput(index, "RemoveHealth");
		}
	}
	while((index=FindEntityByClassname(index,"obj_dispenser"))!=-1)
	{
		if(GetEntPropEnt(index,Prop_Send,"m_hBuilder")==client)
		{
			SetVariantInt(9999);
			AcceptEntityInput(index, "RemoveHealth");
		}
	}
	return Plugin_Handled;
}

public OnClientConnected(client)
{
	if(!IsFakeClient(client))
	{
		people++;
	}
}

public OnClientDisconnect(client)
{
	if(!IsFakeClient(client))
	{
		people--;
	}

	new entity=-1;
	while((entity=FindEntityByClassname(entity, "obj_sentrygun"))!=-1 || (entity=FindEntityByClassname(entity, "obj_dispenser"))!=-1)
	{
		if(GetEntPropEnt(entity, Prop_Send, "m_hBuilder")==client)
		{
			SetVariantInt(9999);
			AcceptEntityInput(entity, "RemoveHealth");
		}
	}
}

stock bool:IsValidClient(client, bool:replay=true)
{
	if(client<=0 || client>MaxClients || !IsClientInGame(client) || GetEntProp(client, Prop_Send, "m_bIsCoaching"))
	{
		return false;
	}

	if(replay && (IsClientSourceTV(client) || IsClientReplay(client)))
	{
		return false;
	}
	return true;
}

/*==========PRECACHING==========*/
PrecacheGeneral()
{
	PrecacheModel("models/props_2fort/cow001_reference.mdl");
	PrecacheModel("models/props_c17/oildrum001_explosive.mdl");
}

PrecacheMerasmus()
{
	PrecacheModel("models/bots/merasmus/merasmus.mdl", true);
	PrecacheModel("models/prop_lakeside_event/bomb_temp.mdl", true);
	PrecacheModel("models/prop_lakeside_event/bomb_temp_hat.mdl", true);
	for(new i=1; i<=17; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		if(i<10)
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_appears0%i.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_appears%i.wav", i);
		}

		if(FileExists(iString))
		{
			PrecacheSound(iString, true);
		}
	}

	for(new i=1; i<=11; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		if(i<10)
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_attacks0%i.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_attacks%i.wav", i);
		}

		if(FileExists(iString))
		{
			PrecacheSound(iString, true);
		}
	}

	for(new i=1; i<=54; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		if(i<10)
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_headbomb0%i.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_headbomb%i.wav", i);
		}

		if(FileExists(iString))
		{
			PrecacheSound(iString, true);
		}
	}

	for(new i=1; i<=33; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		if(i<10)
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_held_up0%i.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_held_up%i.wav", i);
		}

		if(FileExists(iString))
		{
			PrecacheSound(iString, true);
		}
	}

	for(new i=2; i<=4; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_island0%i.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=1; i<=3; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_skullhat0%i.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=1; i<=2; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_combat_idle0%i.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=1; i<=12; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		if(i<10)
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_defeated0%i.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_defeated%i.wav", i);
		}

		if(FileExists(iString))
		{
			PrecacheSound(iString, true);
		}
	}

	for(new i=1; i<=9; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_found0%i.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=3; i<=6; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_grenades0%i.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=1; i<=26; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		if(i<10)
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_headbomb_hit0%i.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_headbomb_hit%i.wav", i);
		}

		if(FileExists(iString))
		{
			PrecacheSound(iString, true);
		}
	}

	for(new i=1; i<=19; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		if(i<10)
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_hide_heal10%i.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_hide_heal1%i.wav", i);
		}

		if(FileExists(iString))
		{
			PrecacheSound(iString, true);
		}
	}

	for(new i=1; i<=49; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		if(i<10)
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_hide_idles0%i.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_hide_idles%i.wav", i);
		}

		if(FileExists(iString))
		{
			PrecacheSound(iString, true);
		}
	}

	for(new i=1; i<=16; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		if(i<10)
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_leaving0%i.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_leaving%i.wav", i);
		}

		if(FileExists(iString))
		{
			PrecacheSound(iString, true);
		}
	}

	for(new i=1; i<=5; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_pain0%i.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=4; i<=8; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_ranged_attack0%i.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=2; i<=13; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		if(i<10)
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_staff_magic0%i.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_staff_magic%i.wav", i);
		}

		if(FileExists(iString))
		{
			PrecacheSound(iString, true);
		}
	}
	PrecacheSound("vo/halloween_merasmus/sf12_hide_idles_demo01.wav", true);
	PrecacheSound("vo/halloween_merasmus/sf12_magic_backfire06.wav", true);
	PrecacheSound("vo/halloween_merasmus/sf12_magic_backfire07.wav", true);
	PrecacheSound("vo/halloween_merasmus/sf12_magic_backfire23.wav", true);
	PrecacheSound("vo/halloween_merasmus/sf12_magic_backfire29.wav", true);
	PrecacheSound("vo/halloween_merasmus/sf12_magicwords11.wav", true);

	PrecacheSound("misc/halloween/merasmus_appear.wav", true);
	PrecacheSound("misc/halloween/merasmus_death.wav", true);
	PrecacheSound("misc/halloween/merasmus_disappear.wav", true);
	PrecacheSound("misc/halloween/merasmus_float.wav", true);
	PrecacheSound("misc/halloween/merasmus_hiding_explode.wav", true);
	PrecacheSound("misc/halloween/merasmus_spell.wav", true);
	PrecacheSound("misc/halloween/merasmus_stun.wav", true);
}

PrecacheMonoculus()
{
	PrecacheModel("models/props_halloween/halloween_demoeye.mdl", true);
	PrecacheModel("models/props_halloween/eyeball_projectile.mdl", true);
	for(new i=1; i<=3; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_eyeball/eyeball_laugh0%i.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=1; i<=3; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_eyeball/eyeball_mad0%i.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=1; i<=13; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		if(i<10)
		{
			Format(iString, sizeof(iString), "vo/halloween_eyeball/eyeball0%i.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_eyeball/eyeball%i.wav", i);
		}

		if(FileExists(iString))
		{
			PrecacheSound(iString, true);
		}
	}
	PrecacheSound("vo/halloween_eyeball/eyeball_biglaugh01.wav", true);
	PrecacheSound("vo/halloween_eyeball/eyeball_boss_pain01.wav", true);
	PrecacheSound("vo/halloween_eyeball/eyeball_teleport01.wav", true);
	PrecacheSound("ui/halloween_boss_summon_rumble.wav", true);
	PrecacheSound("ui/halloween_boss_chosen_it.wav", true);
	PrecacheSound("ui/halloween_boss_defeated_fx.wav", true);
	PrecacheSound("ui/halloween_boss_defeated.wav", true);
	PrecacheSound("ui/halloween_boss_player_becomes_it.wav", true);
	PrecacheSound("ui/halloween_boss_summoned_fx.wav", true);
	PrecacheSound("ui/halloween_boss_summoned.wav", true);
	PrecacheSound("ui/halloween_boss_tagged_other_it.wav", true);
	PrecacheSound("ui/halloween_boss_escape.wav", true);
	PrecacheSound("ui/halloween_boss_escape_sixty.wav", true);
	PrecacheSound("ui/halloween_boss_escape_ten.wav", true);
	PrecacheSound("ui/halloween_boss_tagged_other_it.wav", true);
}

PrecacheHorsemann()
{
	PrecacheModel("models/bots/headless_hatman.mdl", true); 
	PrecacheModel("models/weapons/c_models/c_bigaxe/c_bigaxe.mdl", true);

	for(new i=1; i<=2; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_boss/knight_alert0%i.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=1; i<=4; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_boss/knight_attack0%i.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=1; i<=2; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_boss/knight_death0%i.wav", i);
		PrecacheSound(iString, true);
	}
	
	for(new i=1; i<=4; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_boss/knight_laugh0%i.wav", i);
		PrecacheSound(iString, true);
	}
	
	for(new i=1; i<=3; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_boss/knight_pain0%i.wav", i);
		PrecacheSound(iString, true);
	}
	PrecacheSound("ui/halloween_boss_summon_rumble.wav", true);
	PrecacheSound("vo/halloween_boss/knight_dying.wav", true);
	PrecacheSound("vo/halloween_boss/knight_spawn.wav", true);
	PrecacheSound("vo/halloween_boss/knight_alert.wav", true);
	PrecacheSound("weapons/halloween_boss/knight_axe_hit.wav", true);
	PrecacheSound("weapons/halloween_boss/knight_axe_miss.wav", true);
}

/*==========HELP==========*/
public Action:Command_Spawn_Help(client, args)
{
	decl String:help[128];
	if(args==1)
	{
		GetCmdArg(1, help, sizeof(help));
		if(StrEqual(help, "cow", false) || StrEqual(help, "explosive_barrel", false) || StrEqual(help, "hhh", false) || StrEqual(help, "tank", false) || StrEqual(help, "skeleton", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Just type {Skyblue}spawn %s{Default} in console and you're done!", help);
			return Plugin_Handled;
		}
		else if(StrEqual(help, "ammopack", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} {Skyblue}spawn ammopack <large|medium|small>{Default} has one argument: The size of the ammopack.  Just choose large, medium, or small!  Example: {Skyblue}spawn ammopack medium{Default}.");
			return Plugin_Handled;
		}
		else if(StrEqual(help, "healthpack", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} {Skyblue}spawn healthpack <large|medium|small>{Default} has one argument: The size of the healthpack.  Just choose large, medium, or small!  Example: {Skyblue}spawn healthpack medium{Default}.");
			return Plugin_Handled;
		}
		else if(StrEqual(help, "sentry", false) || StrEqual(help, "dispenser", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} {Skyblue}spawn %s <level>{Default} has one argument: The level of the Ts.  Just choose 1, 2, or 3!  Example: {Skyblue}spawn %s 2{Default}.", help);
			return Plugin_Handled;
		}
		else if(StrEqual(help, "merasmus", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} {Skyblue}spawn merasmus <health>{Default} has one argument: Merasmus's health.  Just choose any integer larger than 0!  Example: {Skyblue}spawn merasmus 2394723{Default}.");
			return Plugin_Handled;
		}
		else if(StrEqual(help, "monoculus", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} {Skyblue}spawn monoculus <level>{Default} has one argument: Monoculus's level.  Just choose any integer larger than 0!  Example: {Skyblue}spawn monoculus 3{Default}.");
			return Plugin_Handled;
		}
		else if(StrEqual(help, "remove", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} {Skyblue}spawn_remove <entity|aim> has one arugment: How to remove the entity.  You can either choose to remove all of one entity, or the entity you're aiming at.  Example: {Skyblue}spawn_remove monoculus{Default}.");
			return Plugin_Handled;
		}
		else
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} That wasn't a valid entity!  Try {Skyblue}spawn_help{Default} without any arguments for more info.");
			return Plugin_Handled;
		}
	}
	else
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Available entities: cow, explosive_barrel, ammopack <large|medium|small>, healthpack <large|medium|small>, sentry <level>, dispenser <level>, merasmus <health>, monoculus <level>, hhh, tank, skeleton");
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Need to remove something?  Try {Skyblue}spawn_remove <entity|aim> <amount>{Default}!");
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Still confused?  Type {Skyblue}spawn_menu{Default} to bring up the menu!  You could also try {Skyblue}spawn_help <entity>{Default}.");
		return Plugin_Handled;
	}
}

/*
CHANGELOG:
----------
1.0.0 Beta 22 (February 11, 2014 A.D.): Actually fixed Updater once and for all.
1.0.0 Beta 21 (January 2, 2014 A.D.): Fixed m_hOwnerEntity, fixed CShowActivity2 by removing CPrintToChat, fixed improper sentry ammo values, and added an amount argument to spawn_remove.
1.0.0 Beta 20 (November 24, 2013 A.D.): Fixed sentries always being on RED team, removed minisentries, fixed buildings spawning at impossible angles, and downgraded release status.
1.0.0 Beta 19 (November 19, 2013 A.D.): Added m_hOwnerEntity check before removing non-building entities.
1.0.0 Beta 18 (November 18, 2013 A.D.): Cleaned up the help command and added CShowActivity2.
1.0.0 Beta 17 (November 16, 2013 A.D.): Changed spawn zombie command to spawn skeleton, as zombies are now skeletons.  Removed Precache_Zombie() as it's no longer needed.  Fixed RED not being able to remove sentries or dispensers.  Addd yet another speculative fix for sentries/dispensers.  Fixed Merasmus's HP always being set to the default value.  Changed Updater link to BitBucket.
1.0.0 Beta 16 (October 17, 2013 A.D.): Fixed RED not being able to build sentries and dispensers...  Still need to figure out why they won't ****ing work though.  Also need to figure out why spawning via the menu and via the command will yield different results o.O.
1.0.0 Beta 15 (October 10, 2013 A.D.): Made admin menu redisplay itself whenever you choose an option (see slap) and added more robust admin menu support.
1.0.0 Beta 14 (October 8, 2013 A.D.): Finished admin menu support and tried to fix disabled sentries.
1.0.0 Beta 13 (October 7, 2013 A.D.): Added experimental Updater support.
1.0.0 Beta 12 (October 7, 2013 A.D.): Major refactor of spawn commands, added way more info to spawn_help, changed all CReplyToCommands to CPrintToChats except for the IsValidClient checks, hopefully fixed dispenser's model being incorrect, forbid spectators from spawning buildings and removing entities using "aim", slight code formatting, and changed around Merasmus' and Monoculus' avaliable arguments.
1.0.0 Beta 11 (October 3, 2013 A.D.): Changed Plugin_Continue back to Plugin_Handled, changed the spawn command to let you manually choose an entity to spawn, fixed entity health, changed spawn_medipack to spawn_healthpack, fixed being spammed whenever you removed an entity, more minor code formatting, and changed "Headless Horseless Horsemann" to "Horseless Headless Horsemann".
1.0.0 Beta 10 (October 2, 2013 A.D.): Changed some ReplyToCommands back to PrintToChats, refactored remove code, removed menu destroy code, changed if(client<1) to if(IsValidClient(client)), formatted some code, and fixed Merasmus for hopefully the very last time...
1.0.0 Beta 9 (September 27, 2013 A.D.): Added sentry/dispenser destroy code and removed Menu Command Forward code (not sure why I implemented that in the first place...), fixed healthpacks, ammopacks, and Merasmus again.
1.0.0 Beta 8 (September 25, 2013 A.D.): Finished implementing standalone menu code and worked a bit on the admin menu.  Might not work as intended.
1.0.0 Beta 7 (September 24, 2013 A.D.): Changed sentry/dispenser code again (added mini-sentries!), added big error messages, added another line to spawn_help, started to implement the menu code, corrected more typos, and optimized/re-organized more code.
1.0.0 Beta 6 (September 23, 2013 A.D.): Fixed spawn_help's Plugin_Continue->Plugin_Handled, tried fixing sentries always being on RED team and not shooting, slightly optimized some more code, made [Spawn] Vintage-colored.
1.0.0 Beta 5 (September 23, 2013 A.D.): Fixed Merasmus, ammopacks, and healthpacks not spawning, fixed some checks activating at the wrong time, re-organized/optimized code, made many messages more verbose, changed Plugin_Handled after the entity spawned to Plugin_Continue, changed CPrintToChat to CReplyToCommand, and added WIP menu code.
1.0.0 Beta 4 (September 20, 2013 A.D.): Fixed cows and hopefully Merasmus/ammopacks/healthpacks not spawning, fixed typos, optimized code, created more fallbacks, removed unfinished code, made some messages more verbose, and added more invalid checks.
*/