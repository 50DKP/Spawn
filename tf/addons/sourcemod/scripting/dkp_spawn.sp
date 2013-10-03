//Thanks to abrandnewday, DarthNinja, HL-SDK, and X3Mano for your plugins that were so helpful to me in writing my plugin!
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

#define PLUGIN_VERSION "1.0.0 Beta 10"
#define MAXENTITIES 256

new Handle:MerasmusBaseHP=INVALID_HANDLE;
new Handle:MerasmusHPPerPlayer=INVALID_HANDLE;
new Handle:MonoculusHPLevel2=INVALID_HANDLE;
new Handle:MonoculusHPPerPlayer=INVALID_HANDLE;
new Handle:MonoculusHPPerLevel=INVALID_HANDLE;

new Handle:adminMenu=INVALID_HANDLE;

new Float:position[3];
new trackEntity=-1;
new healthBar=-1;
new peopleConnected;
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

	RegAdminCmd("spawn", Command_Menu, ADMFLAG_GENERIC, "Bring up the spawn menu!");
	RegAdminCmd("spawn_menu", Command_Menu, ADMFLAG_GENERIC, "Bring up the spawn menu!");
	RegAdminCmd("spawn_cow", Command_Spawn_Cow, ADMFLAG_GENERIC, "Spawn a cow!");
	RegAdminCmd("spawn_explosive_barrel", Command_Spawn_Explosive_Barrel, ADMFLAG_GENERIC, "Spawn an explosive barrel!");
	RegAdminCmd("spawn_ammopack", Forward_Command_Ammopack, ADMFLAG_GENERIC, "Spawn an ammopack!  Usage: spawn_ammopack <large|medium|small>");
	RegAdminCmd("spawn_medipack", Forward_Command_Medipack, ADMFLAG_GENERIC, "Spawn a medipack!  Usage: spawn_medipack <large|medium|small>");
	RegAdminCmd("spawn_sentry", Forward_Command_Sentry, ADMFLAG_GENERIC, "Spawn a sentry!  Usage: spawn_sentry <1|2|3|4|5|6> (4-6 are mini-sentries)");
	RegAdminCmd("spawn_dispenser", Forward_Command_Dispenser, ADMFLAG_GENERIC, "Spawn a dispenser!  Usage: spawn_dispenser <1|2|3>");
	RegAdminCmd("spawn_merasmus", Command_Spawn_Merasmus, ADMFLAG_GENERIC, "Spawn Merasmus!  Usage: spawn_merasmus <health>");
	RegAdminCmd("spawn_monoculus", Command_Spawn_Monoculus, ADMFLAG_GENERIC, "Spawn Monoculus!  Usage: spawn_monoculus <level>");
	RegAdminCmd("spawn_hhh", Command_Spawn_Horsemann, ADMFLAG_GENERIC, "Spawn the Headless Horseless Horsemann!");
	RegAdminCmd("spawn_tank", Command_Spawn_Tank, ADMFLAG_GENERIC, "Spawn a tank!");
	RegAdminCmd("spawn_zombie", Command_Spawn_Zombie, ADMFLAG_GENERIC, "Spawn a zombie!");
	RegAdminCmd("spawn_remove", Command_Remove, ADMFLAG_GENERIC, "Remove an entity!  Usage: spawn_remove <entity|aim>  Note:  Selecting an entity will delete ALL entites of that type (except sentries and dispensers)!");
	RegAdminCmd("spawn_help", Command_Spawn_Help, ADMFLAG_GENERIC, "Lists all entities that this plugin currently supports");

	MerasmusBaseHP=FindConVar("tf_merasmus_health_base");
	MerasmusHPPerPlayer=FindConVar("tf_merasmus_health_per_player");
	MonoculusHPPerPlayer=FindConVar("tf_eyeball_boss_health_per_player");
	MonoculusHPPerLevel=FindConVar("tf_eyeball_boss_health_per_level");
	MonoculusHPLevel2=FindConVar("tf_eyeball_boss_health_at_level_2");

	HookEvent("merasmus_summoned", Event_Merasmus_Summoned, EventHookMode_Pre);
	HookEvent("eyeball_boss_summoned", Event_Monoculus_Summoned, EventHookMode_Pre);
	HookEvent("player_team", Event_Player_Change_Team, EventHookMode_Post);

	new Handle:topmenu=INVALID_HANDLE;
	if (LibraryExists("adminmenu") && ((topmenu=GetAdminTopMenu())!=INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
}

public OnMapStart()
{
	PrecacheGeneral();
	PrecacheMerasmus();
	PrecacheMonoculus();
	PrecacheHorsemann();
	PrecacheZombie();
	FindHealthBar();
	peopleConnected=0;
}

public OnLibraryRemoved(const String:name[])
{
	if(StrEqual(name, "adminmenu"))
	{
		adminMenu=INVALID_HANDLE;
	}
}

/*==========ENTITIES==========*/
public Action:Command_Spawn_Cow(client, args)
{
	if(!IsValidClient(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Could not find the spawn point.");
		return Plugin_Handled;
	}

	new entity=CreateEntityByName("prop_dynamic_override");
	if(!IsValidEntity(entity))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}
	SetEntityModel(entity, "models/props_2fort/cow001_reference.mdl");
	DispatchSpawn(entity);
	position[2] -= 10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
	SetEntityMoveType(entity, MOVETYPE_VPHYSICS);
	SetEntProp(entity, Prop_Data, "m_CollisionGroup", 5);
	SetEntProp(entity, Prop_Data, "m_nSolidType", 6);  //Not working?

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned a cow!");
	LogAction(client, client, "[Spawn] \"%L\" spawned a cow", client);
	return Plugin_Continue;
}

public Action:Command_Spawn_Explosive_Barrel(client, args)
{
	if(!IsValidClient(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Could not find the spawn point.");
		return Plugin_Handled;
	}

	new entity=CreateEntityByName("prop_physics");
	if(!IsValidEntity(entity))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}
	SetEntityModel(entity, "models/props_c17/oildrum001_explosive.mdl");
	DispatchSpawn(entity);
	position[2]-=10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
	SetEntityMoveType(entity, MOVETYPE_VPHYSICS);
	SetEntProp(entity, Prop_Data, "m_CollisionGroup", 5);
	SetEntProp(entity, Prop_Data, "m_nSolidType", 6);

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned an explosive barrel!");
	LogAction(client, client, "[Spawn] \"%L\" spawned an explosive barrel", client);
	return Plugin_Continue;
}

public Action:Forward_Command_Ammopack(client, args)
{
	if(!IsValidClient(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	decl String:ammosize[128];
	if(args==1)
	{
		GetCmdArg(1, ammosize, sizeof(ammosize));
	}
	else if(args>1)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Format: spawn_ammopack <large|medium|small>");
		return Plugin_Handled;
	}
	else
	{
		ammosize="large";
	}
	Command_Spawn_Ammopack(client, args, ammosize);
	return Plugin_Continue;
}

stock Command_Spawn_Ammopack(client, args, String:ammosize[128])
{
	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Could not find the spawn point.");
		return;
	}

	new entity=CreateEntityByName("item_ammopack_full");
	if(StrEqual(ammosize, "large", false))
	{
		entity=CreateEntityByName("item_ammopack_full");
	}
	else if(StrEqual(ammosize, "medium", false))
	{
		entity=CreateEntityByName("item_ammopack_medium");	
	}
	else if(StrEqual(ammosize, "small", false))
	{
		entity=CreateEntityByName("item_ammopack_small");
	}
	else if(args==1)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Since you decided not to use the given options, the ammopack size has been set to large.");
		ammosize="large";
		entity=CreateEntityByName("item_ammopack_full");
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Too many entities have been spawned, reload the map.");
		return;
	}
	
	if(!IsValidEntity(entity))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return;
	}
	DispatchKeyValue(entity, "OnPlayerTouch", "!self,Kill,,0,-1");
	DispatchSpawn(entity);
	position[2]-=10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned a %s ammopack!", ammosize);
	LogAction(client, client, "[Spawn] \"%L\" spawned a %s ammopack", client, ammosize);
}

public Action:Forward_Command_Medipack(client, args)
{
	if(!IsValidClient(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	decl String:healthsize[128];
	if(args==1)
	{
		GetCmdArg(1, healthsize, sizeof(healthsize));
	}
	else if(args>1)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Format: spawn_medipack <large|medium|small>");
		return Plugin_Handled;
	}
	else
	{
		healthsize="large";
	}
	Command_Spawn_Medipack(client, args, healthsize);
	return Plugin_Continue;
}

stock Command_Spawn_Medipack(client, args, String:healthsize[128])
{
	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Could not find the spawn point.");
		return;
	}

	new entity=CreateEntityByName("item_healthkit_full");
	if(StrEqual(healthsize, "large", false))
	{
		entity=CreateEntityByName("item_healthkit_full");
	}
	else if(StrEqual(healthsize, "medium", false))
	{
		entity=CreateEntityByName("item_healthkit_medium");	
	}
	else if(StrEqual(healthsize, "small", false))
	{
		entity=CreateEntityByName("item_healthkit_small");
	}
	else if(args==1)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Since you decided not to use the given options, the medipack size has been set to large.");
		healthsize="large";
		entity=CreateEntityByName("item_healthkit_full");
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Too many entities have been spawned, reload the map.");
		return;
	}

	if(!IsValidEntity(entity))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return;
	}
	DispatchKeyValue(entity, "OnPlayerTouch", "!self,Kill,,0,-1");
	DispatchSpawn(entity);
	position[2]-=10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
	EmitSoundToAll("items/spawn_item.wav", entity, _, _, _, 0.75);

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned a %s medipack!", healthsize);
	LogAction(client, client, "[Spawn] \"%L\" spawned a %s medipack", client, healthsize);
}

/*==========BUILDINGS==========*/
public Action:Forward_Command_Sentry(client, args)
{
	new level=1;
	new bool:mini=false;
	decl String:sentrylevel[128];
	if(!IsValidClient(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(args==1)
	{
		GetCmdArgString(sentrylevel, sizeof(sentrylevel));
		level=StringToInt(sentrylevel);
		if(level>3 && level<7)
		{
			level=StringToInt(sentrylevel)-3;
			mini=true;
		}
		else if(level<1 || level>7)
		{
			CReplyToCommand(client, "{Vintage}[Spawn]{Default} Haha, no.  The sentry's level has been set to 1.  Good try though.");
			level=1;
		}
	}
	else if(args>1)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Format: spawn_sentry <1|2|3|4|5|6>.  Choosing 4-6 will spawn a mini-sentry with the level you chose-3.");
		return Plugin_Handled;
	}
	Command_Spawn_Sentry(client, args, level, mini);
	return Plugin_Continue;
}

stock Command_Spawn_Sentry(client, args, level, bool:mini)
{
	new Float:angles[3];
	GetClientEyeAngles(client, angles);
	decl String:model[64];
	new team=GetClientTeam(client);
	new skin=team-2;
	new shells, health, rockets;

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Could not find the spawn point.");
		return;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Too many entities have been spawned, reload the map.");
		return;
	}

	switch(level)
	{
		case 1:
		{
			model="models/buildables/sentry1.mdl";
			shells=100;
			health=150;
			if(mini)
			{
				health=100;
			}
		}
		case 2:
		{
			model="models/buildables/sentry2.mdl";
			shells=120;
			health=180;
			if(mini)
			{
				health=120;
			}
		}
		case 3:
		{
			model="models/buildables/sentry3.mdl";
			shells=144;
			health=216;
			rockets=20;
			if(mini)
			{
				health=180;
			}
		}
		default:
		{
			CReplyToCommand(client, "{Vintage}[Spawn]{Default} {Red}ERROR:{Default} The level was invalid!  That shouldn't be happening.");
			return;
		}
	}

	if(mini&&level==1)
	{
		skin=team;
	}

	new entity=CreateEntityByName("obj_sentrygun");
	if(entity<MaxClients || !IsValidEntity(entity))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return;
	}
	DispatchSpawn(entity);
	TeleportEntity(entity, position, angles, NULL_VECTOR);
	SetEntityModel(entity, model);

	SetEntProp(entity, Prop_Send, "m_ammoShells", shells);
	SetEntProp(entity, Prop_Send, "m_ammoRockets", rockets);
	SetEntProp(entity, Prop_Send, "m_bHasSapper", 0);
	SetEntProp(entity, Prop_Send, "m_bPlayerControlled", 1);
	SetEntProp(entity, Prop_Send, "m_health", health);
	SetEntProp(entity, Prop_Send, "m_iHighestUpgradeLevel", level);
	SetEntProp(entity, Prop_Send, "m_iMaxHealth", health);
	SetEntProp(entity, Prop_Send, "m_iObjectType", _:TFObject_Sentry);
	SetEntProp(entity, Prop_Send, "m_iState", 3);
	SetEntProp(entity, Prop_Send, "m_iUpgradeLevel", level);
	SetEntProp(entity, Prop_Send, "m_nSkin", skin);
	SetEntProp(entity, Prop_Send, "m_teamNum", team);
	SetEntPropEnt(entity, Prop_Send, "m_hBuilder", client);
	SetEntPropFloat(entity, Prop_Send, "m_flPercentageConstructed", level==1 ? 0.99:1.0);
	SetEntPropVector(entity, Prop_Send, "m_vecBuildMaxs", Float:{24.0, 24.0, 66.0});
	SetEntPropVector(entity, Prop_Send, "m_vecBuildMins", Float:{-24.0, -24.0, 0.0});
	if(level==1)
	{
		SetEntProp(entity, Prop_Send, "m_bBuilding", 1);
	}
	if(mini)
	{
		SetEntProp(entity, Prop_Send, "m_miniBuilding", 1);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.75);
	}
	new offs=FindSendPropInfo("CObjectSentrygun", "m_iDesiredBuildRotations");
	if(offs<=0)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Something went wrong with the build rotation!");
		return;
	}
	SetEntData(entity, offs-12, 1, 1, true);

	if(mini)
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned a level %i mini-sentry!", level);
		LogAction(client, client, "[Spawn] \"%L\" spawned a level %i mini-sentry", client, level);
	}
	else
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned a level %i sentry!", level);
		LogAction(client, client, "[Spawn] \"%L\" spawned a level %i sentry", client, level);
	}
}

public Action:Forward_Command_Dispenser(client, args)
{
	new level=1;
	decl String:dispenserlevel[128];
	if(!IsValidClient(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(args==1)
	{
		GetCmdArgString(dispenserlevel, sizeof(dispenserlevel));
		level=StringToInt(dispenserlevel);
		if(level<1 || level>3)
		{
			CReplyToCommand(client, "{Vintage}[Spawn]{Default} Haha, no.  The dispenser's level has been set to 1.  Good try though.");
			level=1;
		}
	}
	else if(args>1)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Format: spawn_dispenser <1|2|3>");
		return Plugin_Handled;
	}
	Command_Spawn_Dispenser(client, args, level);
	return Plugin_Continue;
}

stock Command_Spawn_Dispenser(client, args, level)
{
	decl String:model[128];
	new Float:angles[3];
	GetClientEyeAngles(client, angles);
	new team=GetClientTeam(client);
	new health;
	new ammo=400;

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Could not find the spawn point.");
		return;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Too many entities have been spawned, reload the map.");
		return;
	}

	switch (level)
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
			CReplyToCommand(client, "{Vintage}[Spawn]{Default} {Red}ERROR:{Default} The level was invalid!  That shouldn't be happening.");
			return;
		}
	}

	new entity=CreateEntityByName("obj_dispenser");
	if(entity<MaxClients || !IsValidEntity(entity))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return;
	}
	DispatchSpawn(entity);
	TeleportEntity(entity, position, angles, NULL_VECTOR);

	SetVariantInt(team);
	AcceptEntityInput(entity, "TeamNum");
	SetVariantInt(team);
	AcceptEntityInput(entity, "SetTeam");

	ActivateEntity(entity);

	SetEntProp(entity, Prop_Send, "m_ammoMetal", ammo);
	SetEntProp(entity, Prop_Send, "m_health", health);
	SetEntProp(entity, Prop_Send, "m_iMaxHealth", health);
	SetEntProp(entity, Prop_Send, "m_iObjectType", _:TFObject_Dispenser);
	SetEntProp(entity, Prop_Send, "m_iHighestUpgradeLevel", level);
	SetEntProp(entity, Prop_Send, "m_iState", 3);
	SetEntProp(entity, Prop_Send, "m_iUpgradeLevel", level);
	SetEntProp(entity, Prop_Send, "m_nSkin", team-2);
	SetEntProp(entity, Prop_Send, "m_teamNum", team);
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
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Something went wrong with the build rotation!");
		return;
	}
	SetEntData(entity, offs-12, 1, 1, true);

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned a level %i dispenser!", level);
	LogAction(client, client, "[Spawn] \"%L\" spawned a level %i dispenser", client, level);
}

/*==========BOSSES==========*/
public Action:Command_Spawn_Merasmus(client, args)
{
	new merasmus_health=GetConVarInt(MerasmusBaseHP);
	new merasmus_health_per_player=GetConVarInt(MerasmusHPPerPlayer);
	new String:health[15], HP=-1;
	HP=merasmus_health+(merasmus_health_per_player*peopleConnected);
	if(!IsValidClient(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(args==1)
	{
		GetCmdArgString(health, sizeof(health));
		HP=StringToInt(health);
		if(HP<=0)
		{
			CReplyToCommand(client, "{Vintage}[Spawn]{Default} Haha, no.  Merasmus's health has been set to the default value.  Good try though.");
			HP=merasmus_health+(merasmus_health_per_player*peopleConnected);
		}
	}
	else if(args>1)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Format: spawn_merasmus <health>");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Could not find the spawn point.");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}

	new entity=CreateEntityByName("merasmus");
	if(!IsValidEntity(entity))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return Plugin_Handled;
	}

	//CReplyToCommand(client, "{Vintage}[Spawn]{Default} {Yellow}DEBUG:{Default} %i", HP);
	if(HP>0)
	{
		SetEntProp(entity, Prop_Data, "m_iHealth", HP*4);
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", HP*4);
	}
	else
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} {Red}ERROR:{Default} Merasmus' health was below 1!  That shouldn't be happening.");
		return Plugin_Handled;
	}
	DispatchSpawn(entity);
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned Merasmus with %i health!", HP);
	LogAction(client, client, "[Spawn] \"%L\" spawned Merasmus", client);
	return Plugin_Continue;
}

public Action:Command_Spawn_Monoculus(client, args)
{
	if(!IsValidClient(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Could not find the spawn point.");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}

	new entity=CreateEntityByName("eyeball_boss");
	if(!IsValidEntity(entity))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return Plugin_Handled;
	}

	new level=1;
	if(args==1)
	{
		decl String:buffer[15];
		GetCmdArg(1, buffer, sizeof(buffer));
		level=StringToInt(buffer);
		if(level<=0)
		{
			CReplyToCommand(client, "{Vintage}[Spawn]{Default} Haha, no.  Monoculus's level has been set to 1.  Good try though.");
			level=1;
		}
	}
	else if(args>1)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Format: spawn_monoculus <level>");
		return Plugin_Handled;
	}

	if(level>1)
	{
		new monoculus_base_hp=GetConVarInt(MonoculusHPLevel2);
		new monoculus_hp_per_level=GetConVarInt(MonoculusHPPerLevel);
		new monoculus_hp_per_player=GetConVarInt(MonoculusHPPerPlayer);
		new NumPlayers=GetClientCount(true);

		new HP=monoculus_base_hp;
		HP=(HP+((level-2)*monoculus_hp_per_level));
		if(NumPlayers>10)
		{
			HP=(HP+((NumPlayers-10)*monoculus_hp_per_player));
		}
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", HP);
		SetEntProp(entity, Prop_Data, "m_health", HP);
		letsChangeThisEvent=level;
	}
	else if(level<=0)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} {Red}ERROR:{Default} Monoculus' level was below 1!  That shouldn't be happening.");
		return Plugin_Handled;
	}
	DispatchSpawn(entity);
	position[2]-=10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned a level %i Monoculus!", level);
	LogAction(client, client, "[Spawn] \"%L\" spawned a level %i Monoculus", client, level);
	return Plugin_Continue;
}

public Action:Command_Spawn_Horsemann(client, args)
{
	if(!IsValidClient(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Could not find the spawn point.");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}

	new entity=CreateEntityByName("headless_hatman");
	if(!IsValidEntity(entity))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return Plugin_Handled;
	}
	DispatchSpawn(entity);
	position[2]-=10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned the Headless Horseless Horsemann!");
	LogAction(client, client, "[Spawn] \"%L\" spawned the Headless Horseless Horsemann", client);
	return Plugin_Continue;
}

public Action:Command_Spawn_Tank(client, args)
{
	if(!IsValidClient(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Could not find the spawn point.");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}

	new entity=CreateEntityByName("tank_boss");
	if(!IsValidEntity(entity))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return Plugin_Handled;
	}
	DispatchSpawn(entity);
	position[2] -= 10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned a tank!");
	LogAction(client, client, "[Spawn] \"%L\" spawned a tank", client);
	return Plugin_Continue;
}

public Action:Command_Spawn_Zombie(client, args)
{
	if(!IsValidClient(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Could not find the spawn point.");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}

	new entity=CreateEntityByName("tf_zombie");
	if(!IsValidEntity(entity))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} The entity was invalid!");
		return Plugin_Handled;
	}
	DispatchSpawn(entity);
	position[2]-=10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned a zombie!");
	LogAction(client, client, "[Spawn] \"%L\" spawned a zombie", client);
	return Plugin_Continue;
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
	if(args==1)
	{
		GetCmdArg(1, selection, sizeof(selection));
	}
	else if(args>1)
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Usage: spawn_remove <entity|aim>");
		return Plugin_Handled;
	}
	
	new entity=-1;
	if(StrEqual(selection, "cow", false))
	{
		while((entity=FindEntityByClassname(entity, "prop_dynamic_override"))!=-1 && IsValidEntity(entity))
		{
			SetVariantInt(9999);
			AcceptEntityInput(entity, "Kill");
			CPrintToChat(client, "{Vintage}[Spawn]{Default} You slayed a cow!");
			LogAction(client, client, "[Spawn] \"%L\" force-slayed a cow", client);
		}
		return Plugin_Continue;
	}
	else if(StrEqual(selection, "explosive_barrel", false))
	{
		while((entity=FindEntityByClassname(entity, "prop_physics"))!=-1 && IsValidEntity(entity))
		{
			SetVariantInt(9999);
			AcceptEntityInput(entity, "Kill");
			CPrintToChat(client, "{Vintage}[Spawn]{Default} You removed an explosive barrel!");
			LogAction(client, client, "[Spawn] \"%L\" force-removed an explosive barrel", client);
		}
		return Plugin_Continue;
	}
	else if(StrEqual(selection, "ammopack", false))
	{
		while(((entity=FindEntityByClassname(entity, "item_ammopack_full"))!=-1 || (entity=FindEntityByClassname(entity, "item_ammopack_medium"))!=-1 || (entity=FindEntityByClassname(entity, "item_ammopack_small"))!=-1) && IsValidEntity(entity))
		{
			SetVariantInt(9999);
			AcceptEntityInput(entity, "Kill");
			CPrintToChat(client, "{Vintage}[Spawn]{Default} You removed an ammopack!");
			LogAction(client, client, "[Spawn] \"%L\" force-removed an ammopack", client);
		}
		return Plugin_Continue;
	}
	else if(StrEqual(selection, "medipack", false))
	{
		while(((entity=FindEntityByClassname(entity, "item_healthpack_full"))!=-1 || (entity=FindEntityByClassname(entity, "item_healthpack_medium"))!=-1 || (entity=FindEntityByClassname(entity, "item_healthpack_small"))!=-1) && IsValidEntity(entity))
		{
			SetVariantInt(9999);
			AcceptEntityInput(entity, "Kill");
			CPrintToChat(client, "{Vintage}[Spawn]{Default} You removed a medipack!");
			LogAction(client, client, "[Spawn] \"%L\" force-removed a medipack", client);
		}
		return Plugin_Continue;
	}
	else if(StrEqual(selection, "sentry", false))
	{
		while((entity=FindEntityByClassname(entity, "obj_sentrygun"))!=-1 && IsValidEntity(entity))
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hBuilder")==client)
			{
				SetVariantInt(9999);
				AcceptEntityInput(entity, "RemoveHealth");
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You destroyed one of your sentries!");
				LogAction(client, client, "[Spawn] \"%L\" force-destroyed a sentry", client);
			}
		}
		return Plugin_Continue;
	}
	else if(StrEqual(selection, "dispenser", false))
	{
		while((entity=FindEntityByClassname(entity, "obj_dispenser"))!=-1 && IsValidEntity(entity))
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hBuilder")==client)
			{
				SetVariantInt(9999);
				AcceptEntityInput(entity, "RemoveHealth");
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You destroyed one of your dispensers!");
				LogAction(client, client, "[Spawn] \"%L\" force-destroyed a dispenser", client);
			}
		}
		return Plugin_Continue;
	}
	else if(StrEqual(selection, "merasmus", false))
	{
		while((entity=FindEntityByClassname(entity, "merasmus"))!=-1 && IsValidEntity(entity))
		{
			new Handle:event=CreateEvent("merasmus_killed", true);
			FireEvent(event);
			AcceptEntityInput(entity, "Kill");
			CPrintToChat(client, "{Vintage}[Spawn]{Default} You slayed Merasmus!");
			LogAction(client, client, "[Spawn] \"%L\" force-slayed Merasmus", client);
		}
		return Plugin_Continue;
	}
	else if(StrEqual(selection, "monoculus", false))
	{
		while((entity=FindEntityByClassname(entity, "eyeball_boss"))!=-1 && IsValidEntity(entity))
		{
			new Handle:event=CreateEvent("eyeball_boss_killed", true);
			FireEvent(event);
			AcceptEntityInput(entity, "Kill");
			CPrintToChat(client, "{Vintage}[Spawn]{Default} You slayed Monoculus!");
			LogAction(client, client, "[Spawn] \"%L\" force-slayed Monoculus", client);
		}
		return Plugin_Continue;
	}
	else if(StrEqual(selection, "hhh", false))
	{
		while((entity=FindEntityByClassname(entity, "headless_hatman"))!=-1 && IsValidEntity(entity))
		{
			new Handle:event=CreateEvent("pumpkin_lord_killed", true);
			FireEvent(event);
			AcceptEntityInput(entity, "Kill");
			CPrintToChat(client, "{Vintage}[Spawn]{Default} You slayed the Horseless Headless Horsemann!");
			LogAction(client, client, "[Spawn] \"%L\" force-slayed the Horseless Headless Horsemann", client);
		}
		return Plugin_Continue;
	}
	else if(StrEqual(selection, "tank", false))
	{
		while((entity=FindEntityByClassname(entity, "tank_boss"))!=-1 && IsValidEntity(entity))
		{
			AcceptEntityInput(entity, "Kill");
			CPrintToChat(client, "{Vintage}[Spawn]{Default} You destroyed a tank!");
			LogAction(client, client, "[Spawn] \"%L\" force-destroyed a tank", client);
		}
		return Plugin_Continue;
	}
	else if(StrEqual(selection, "zombie", false))
	{
		while((entity=FindEntityByClassname(entity, "tf_zombie"))!=-1 && IsValidEntity(entity))
		{
			AcceptEntityInput(entity, "Kill");
			CPrintToChat(client, "{Vintage}[Spawn]{Default} You slayed a zombie!");
			LogAction(client, client, "[Spawn] \"%L\" force-slayed a zombie", client);
		}
		return Plugin_Continue;
	}
	else if(StrEqual(selection, "aim", false))
	{
		entity=GetClientAimTarget(client, false);
		if(!IsValidEntity(entity))
		{
			CReplyToCommand(client, "{Vintage}[Spawn]{Default} No valid entity found at aim.");
			return Plugin_Handled;
		}

		if((entity=FindEntityByClassname(entity, "obj_dispenser"))!=-1 || (entity=FindEntityByClassname(entity, "obj_sentrygun"))!=-1)
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hBuilder")==client)
			{
				SetVariantInt(9999);
				AcceptEntityInput(entity, "RemoveHealth");
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You removed a building!");
				LogAction(client, client, "[Spawn] \"%L\" force-removed a building (entity %i)", client, entity);
				return Plugin_Continue;
			}
			else
			{
				CReplyToCommand(client, "{Vintage}[Spawn]{Default} You don't own that building!");
				return Plugin_Handled;
			}
		}
		else
		{
			SetVariantInt(9999);
			AcceptEntityInput(entity, "Kill");
			CPrintToChat(client, "{Vintage}[Spawn]{Default} You removed an entity!");
			LogAction(client, client, "[Spawn] \"%L\" force-removed an entity (entity %i)", client, entity);
			return Plugin_Continue;
		}
	}
	else
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} Usage: spawn_remove <entity|aim>");
		return Plugin_Handled;
	}
}

/*==========MENUS==========*/
public Action:Command_Menu(client, args)
{
	if(!IsValidClient(client))
	{
		CReplyToCommand(client, "{Vintage}[Spawn]{Default} This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}
	CreateMenuGeneral(client);
	return Plugin_Continue;
}

stock CreateMenuGeneral(client)
{
	new Handle:menu=CreateMenu(MenuHandlerGeneral);
	SetMenuTitle(menu, "Spawn Menu");
	AddMenuItem(menu, "cow", "Cow");
	AddMenuItem(menu, "explosive_barrel", "Explosive Barrel");
	AddMenuItem(menu, "sentry1", "Level 1 Sentry");
	AddMenuItem(menu, "sentry1m", "Level 1 Mini-Sentry");
	AddMenuItem(menu, "sentry2", "Level 2 Sentry");
	AddMenuItem(menu, "sentry2m", "Level 2 Mini-Sentry");
	AddMenuItem(menu, "sentry3", "Level 3 Sentry");
	AddMenuItem(menu, "sentry3m", "Level 3 Mini-Sentry");
	AddMenuItem(menu, "dispenser1", "Level 1 Dispenser");
	AddMenuItem(menu, "dispenser2", "Level 2 Dispenser");
	AddMenuItem(menu, "dispenser3", "Level 3 Dispenser");
	AddMenuItem(menu, "ammo_large", "Large Ammopack");
	AddMenuItem(menu, "ammo_medium", "Medium Ammopack");
	AddMenuItem(menu, "ammo_small", "Small Ammopack");
	AddMenuItem(menu, "health_large", "Large Medipack");
	AddMenuItem(menu, "health_medium", "Health Ammopack");
	AddMenuItem(menu, "health_small", "Small Medipack");
	AddMenuItem(menu, "merasmus", "Merasmus");
	AddMenuItem(menu, "monoculus", "Monoculus");
	AddMenuItem(menu, "hhh", "Horseless Headless Horsemann");
	AddMenuItem(menu, "tank", "Tank");
	AddMenuItem(menu, "zombie", "Zombie");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandlerGeneral(Handle:menu, MenuAction:action, client, menuPos)
{
	new String:selection[32];
	GetMenuItem(menu, menuPos, selection, sizeof(selection));
	if (action==MenuAction_Select)
	{
		if(StrEqual(selection, "cow"))
		{
			Command_Spawn_Cow(client, 0);
		}
		else if(StrEqual(selection, "explosive_barrel"))
		{
			Command_Spawn_Explosive_Barrel(client, 0);
		}
		else if(StrEqual(selection, "sentry1"))
		{
			Command_Spawn_Sentry(client, 0, 1, false);
		}
		else if(StrEqual(selection, "sentry1m"))
		{
			Command_Spawn_Sentry(client, 0, 1, true);
		}
		else if(StrEqual(selection, "sentry2"))
		{
			Command_Spawn_Sentry(client, 0, 2, false);
		}
		else if(StrEqual(selection, "sentry2m"))
		{
			Command_Spawn_Sentry(client, 0, 2, true);
		}
		else if(StrEqual(selection, "sentry3"))
		{
			Command_Spawn_Sentry(client, 0, 3, false);
		}
		else if(StrEqual(selection, "sentry3m"))
		{
			Command_Spawn_Sentry(client, 0, 3, true);
		}
		else if(StrEqual(selection, "dispenser1"))
		{
			Command_Spawn_Dispenser(client, 0, 1);
		}
		else if(StrEqual(selection, "dispenser2"))
		{
			Command_Spawn_Dispenser(client, 0, 2);
		}
		else if(StrEqual(selection, "dispenser3"))
		{
			Command_Spawn_Dispenser(client, 0, 3);
		}
		else if(StrEqual(selection, "ammo_large"))
		{
			Command_Spawn_Ammopack(client, 0, "large");
		}
		else if(StrEqual(selection, "ammo_medium"))
		{
			Command_Spawn_Ammopack(client, 0, "medium");
		}
		else if(StrEqual(selection, "ammo_small"))
		{
			Command_Spawn_Ammopack(client, 0, "small");
		}
		else if(StrEqual(selection, "health_large"))
		{
			Command_Spawn_Medipack(client, 0, "large");
		}
		else if(StrEqual(selection, "health_medium"))
		{
			Command_Spawn_Medipack(client, 0, "medium");
		}
		else if(StrEqual(selection, "health_small"))
		{
			Command_Spawn_Medipack(client, 0, "small");
		}
		else if(StrEqual(selection, "merasmus"))
		{
			Command_Spawn_Merasmus(client, 0);
		}
		else if(StrEqual(selection, "monoculus"))
		{
			Command_Spawn_Monoculus(client, 0);
		}
		else if(StrEqual(selection, "hhh"))
		{
			Command_Spawn_Horsemann(client, 0);
		}
		else if(StrEqual(selection, "tank"))
		{
			Command_Spawn_Tank(client, 0);
		}
		else if(StrEqual(selection, "zombie"))
		{
			Command_Spawn_Zombie(client, 0);
		}
		else
		{
			CReplyToCommand(client, "{Vintage}[Spawn]{Default} {Red}ERROR:{Default} Something went horribly wrong with the menu code!");
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
}

/*AttachAdminMenu()
{
	AddToTopMenu(adminMenu, "Spawn Commands", TopMenuObject_Category, CategoryHandler, INVALID_TOPMENUOBJECT);
}
 
public CategoryHandler(Handle:topmenu, TopMenuAction:action, TopMenuObject:objectID, param, String:buffer[], maxlength)
{
	if (action==TopMenuAction_DisplayTitle)
	{
		Format(buffer, maxlength, "Spawn Commands:");
	}
	else if(action==TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Spawn Commands");
	}
}

AttachAdminMenu()
{
	new TopMenuObject:spawnCommands=FindTopMenuCategory(adminMenu, "Spawn Commands");
	if(spawnCommands==INVALID_TOPMENUOBJECT)
	{
		return;
	}
	AddToTopMenu(adminMenu, "spawn_cow", TopMenuObject_Item, AdminMenu_Poke, spawnCommands, "spawn_cow", ADMFLAG_GENERIC);
}
 
public AdminMenu_Cow(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if(action==TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Cow");
	}
	else if(action==TopMenuAction_SelectOption)
	{
		//TODO
	}
}*/

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
		if (hEvent==INVALID_HANDLE)
		{
			return Plugin_Handled;
		}
		SetEventInt(hEvent, "level", letsChangeThisEvent);
		FireEvent(hEvent);
		letsChangeThisEvent=0;
		return Plugin_Handled;
	}
	return Plugin_Continue;
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
	new i=-1;
	while((i=FindEntityByClassname(i, "merasmus"))!=-1 && IsValidEntity(i))
	{
		SetEntPropFloat(i, Prop_Send, "m_flModelScale", 1.0);
		SetEntProp(i, Prop_Send, "m_bGlowEnabled", 0.0);
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
		new HP=GetEntProp(entity, Prop_Data, "m_health");

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
		new HP=GetEntProp(entity, Prop_Data, "m_health");
		
		if(HP<=(maxHP*0.75))
		{
			SetEntProp(entity, Prop_Data, "m_health", 0);
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
	return Plugin_Continue;
}

public OnClientConnected(client)
{
	if(!IsFakeClient(client))
	{
		peopleConnected++;
	}
}

public OnClientDisconnect(client)
{
	if(!IsFakeClient(client))
	{
		peopleConnected--;
	}

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
}

stock bool:IsValidClient(i, bool:replay=true)
{
	if(i<=0 || i>MaxClients || !IsClientInGame(i) || GetEntProp(i, Prop_Send, "m_bIsCoaching"))
	{
		return false;
	}

	if(replay && (IsClientSourceTV(i) || IsClientReplay(i)))
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
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_appears0%d.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_appears%d.wav", i);
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
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_attacks0%d.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_attacks%d.wav", i);
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
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_headbomb0%d.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_headbomb%d.wav", i);
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
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_held_up0%d.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_held_up%d.wav", i);
		}

		if(FileExists(iString))
		{
			PrecacheSound(iString, true);
		}
	}

	for(new i=2; i<=4; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_island0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=1; i<=3; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_skullhat0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=1; i<=2; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_combat_idle0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=1; i<=12; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		if(i<10)
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_defeated0%d.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_defeated%d.wav", i);
		}

		if(FileExists(iString))
		{
			PrecacheSound(iString, true);
		}
	}

	for(new i=1; i <= 9; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_found0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=3; i <= 6; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_grenades0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=1; i<=26; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		if(i<10)
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_headbomb_hit0%d.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_headbomb_hit%d.wav", i);
		}

		if(FileExists(iString))
		{
			PrecacheSound(iString, true);
		}
	}

	for(new i=1; i <= 19; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		if(i<10)
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_hide_heal10%d.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_hide_heal1%d.wav", i);
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
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_hide_idles0%d.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_hide_idles%d.wav", i);
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
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_leaving0%d.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_leaving%d.wav", i);
		}

		if(FileExists(iString))
		{
			PrecacheSound(iString, true);
		}
	}

	for(new i=1; i<=5; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_pain0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=4; i<=8; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_ranged_attack0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=2; i<=13; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		if(i<10)
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_staff_magic0%d.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_staff_magic%d.wav", i);
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
		Format(iString, sizeof(iString), "vo/halloween_eyeball/eyeball_laugh0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=1; i<=3; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_eyeball/eyeball_mad0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=1; i<=13; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		if(i<10)
		{
			Format(iString, sizeof(iString), "vo/halloween_eyeball/eyeball0%d.wav", i);
		}
		else
		{
			Format(iString, sizeof(iString), "vo/halloween_eyeball/eyeball%d.wav", i);
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
		Format(iString, sizeof(iString), "vo/halloween_boss/knight_alert0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=1; i<=4; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_boss/knight_attack0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i=1; i<=2; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_boss/knight_death0%d.wav", i);
		PrecacheSound(iString, true);
	}
	
	for(new i=1; i<=4; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_boss/knight_laugh0%d.wav", i);
		PrecacheSound(iString, true);
	}
	
	for(new i=1; i<=3; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_boss/knight_pain0%d.wav", i);
		PrecacheSound(iString, true);
	}
	PrecacheSound("ui/halloween_boss_summon_rumble.wav", true);
	PrecacheSound("vo/halloween_boss/knight_dying.wav", true);
	PrecacheSound("vo/halloween_boss/knight_spawn.wav", true);
	PrecacheSound("vo/halloween_boss/knight_alert.wav", true);
	PrecacheSound("weapons/halloween_boss/knight_axe_hit.wav", true);
	PrecacheSound("weapons/halloween_boss/knight_axe_miss.wav", true);
}

PrecacheZombie()
{
	PrecacheModel("models/player/items/scout/scout_zombie.mdl", true);
	PrecacheModel("models/player/items/soldier/soldier_zombie.mdl", true);
	PrecacheModel("models/player/items/pyro/pyro_zombie.mdl", true);
	PrecacheModel("models/player/items/demo/demo_zombie.mdl", true);
	PrecacheModel("models/player/items/heavy/heavy_zombie.mdl", true);
	PrecacheModel("models/player/items/engineer/engineer_zombie.mdl", true);
	PrecacheModel("models/player/items/medic/medic_zombie.mdl", true);
	PrecacheModel("models/player/items/sniper/sniper_zombie.mdl", true);
	PrecacheModel("models/player/items/spy/spy_zombie.mdl", true);
}

/*==========HELP==========*/
public Action:Command_Spawn_Help(client, args)
{
	CReplyToCommand(client, "{Vintage}[Spawn]{Default} Available entities (append the name to spawn_):  cow, explosive_barrel, ammopack <large|medium|small>, medipack <large|medium|small>, sentry <1|2|3|4|5|6> (4-6 are level 1-3 mini-sentries), dispenser <1|2|3>, merasmus <health>, monoculus <level>, hhh, tank, zombie");
	CReplyToCommand(client, "{Vintage}[Spawn]{Default} Need to remove something?  Try {Skyblue}spawn_remove <entity|aim>{Default}!");
	CReplyToCommand(client, "{Vintage}[Spawn]{Default} Still confused?  Type {Skyblue}spawn{Default} or {Skyblue}spawn_menu{Default} to bring up the Spawn menu!  Note: The spawn menu CANNOT remove entities!");
	return Plugin_Continue;
}

/*
CHANGELOG:
----------
1.0.0 Beta 10 (October 2, 2013 A.D.):  Changed some ReplyToCommands back to PrintToChats, refactored remove code, removed menu destroy code, changed if(client<1) to if(IsValidClient(client)), formatted some code, and fixed Merasmus for hopefully the very last time...
1.0.0 Beta 9 (September 27, 2013 A.D.):  Added sentry/dispenser destroy code and removed Menu Command Forward code (not sure why I implemented that in the first place...), fixed medipacks, ammopacks, and Merasmus again.
1.0.0 Beta 8 (September 25, 2013 A.D.):  Finished implementing standalone menu code and worked a bit on the admin menu.  Might not work as intended.
1.0.0 Beta 7 (September 24, 2013 A.D.):  Changed sentry/dispenser code again (added mini-sentries!), added big error messages, added another line to spawn_help, started to implement the menu code, corrected more typos, and optimized/re-organized more code.
1.0.0 Beta 6 (September 23, 2013 A.D.):  Fixed spawn_help's Plugin_Handled->Plugin_Continue, tried fixing sentries always being on RED team and not shooting, slightly optimized some more code, made [Spawn] Vintage-colored.
1.0.0 Beta 5 (September 23, 2013 A.D.):  Fixed Merasmus, ammopacks, and medipacks not spawning, fixed some checks activating at the wrong time, re-organized/optimized code, made many messages more verbose, changed Plugin_Handled after the entity spawned to Plugin_Continue, changed CPrintToChat to CReplyToCommand, and added WIP menu code.
1.0.0 Beta 4 (September 20, 2013 A.D.):  Fixed cows and hopefully Merasmus/ammopacks/medipacks not spawning, fixed typos, optimized code, created more fallbacks, removed unfinished code, made some messages more verbose, and added more invalid checks.
*/