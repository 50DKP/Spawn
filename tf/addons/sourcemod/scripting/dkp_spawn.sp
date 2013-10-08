//TODO:  ADMIN MENU, SENTRY/DISPENSER
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

#define PLUGIN_VERSION "1.0.0 Beta 12"
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

	RegAdminCmd("spawn", Command_Spawn, ADMFLAG_GENERIC, "Manually choose an entity to spawn!  Usage: spawn <entity> <level/health> <mini>.  0 arguments will bring up the menu.  Use spawn_help to see the list of entities.");
	RegAdminCmd("spawn_menu", Command_Menu, ADMFLAG_GENERIC, "Bring up the menu!");
	RegAdminCmd("spawn_remove", Command_Remove, ADMFLAG_GENERIC, "Remove an entity!  Usage: spawn_remove <entity|aim>.  Note:  Selecting an entity will delete ALL entites of that type (except sentries and dispensers)!");
	RegAdminCmd("spawn_help", Command_Spawn_Help, ADMFLAG_GENERIC, "Need some help?  Come here!  Usage:  spawn_help <entity>.  0 arguments will bring up the generic help text.");

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
}

public OnMapStart()
{
	PrecacheGeneral();
	PrecacheMerasmus();
	PrecacheMonoculus();
	PrecacheHorsemann();
	PrecacheZombie();
	FindHealthBar();
	people=0;
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
	decl String:minisentry[128];
	if(args==1)
	{
		GetCmdArg(1, selection, sizeof(selection));
	}
	else if(args==2)
	{
		GetCmdArg(1, selection, sizeof(selection));
		GetCmdArg(2, other, sizeof(other));
	}
	else if(args==3)
	{
		GetCmdArg(1, selection, sizeof(selection));
		GetCmdArg(2, other, sizeof(other));
		GetCmdArg(3, minisentry, sizeof(minisentry));
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
		new String:ammosize[128]="large";
		if(args==2)
		{
			ammosize=other;
		}
		Command_Spawn_Ammopack(client, ammosize);
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "healthpack", false))
	{
		new String:healthsize[128]="large";
		if(args==2)
		{
			healthsize=other;
		}
		Command_Spawn_Healthpack(client, healthsize);
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "sentry", false))
	{
		new level=1;
		new bool:mini=false;
		if(args==2)
		{
			level=StringToInt(other);
		}
		else if(args==3)
		{
			if(StrEqual(minisentry, "true", false))
			{
				mini=true;
			}
		}
		Command_Spawn_Sentry(client, level, mini);
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
		Command_Spawn_Merasmus(client, 0);
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
	else if(StrEqual(selection, "zombie", false))
	{
		Command_Spawn_Zombie(client);
		return Plugin_Handled;
	}
	else
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default}  Usage: spawn <entity> <level/health>.  0 arguments will open up the menu.");
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
	position[2] -= 10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
	SetEntityMoveType(entity, MOVETYPE_VPHYSICS);
	SetEntProp(entity, Prop_Data, "m_CollisionGroup", 5);
	SetEntProp(entity, Prop_Data, "m_nSolidType", 6);  //Not working?

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned a cow!");
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
	SetEntProp(entity, Prop_Data, "m_CollisionGroup", 5);
	SetEntProp(entity, Prop_Data, "m_nSolidType", 6);

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned an explosive barrel!");
	LogAction(client, client, "[Spawn] \"%L\" spawned an explosive barrel", client);
	return;
}

stock Command_Spawn_Ammopack(client, String:ammosize[128])
{
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
	else
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Since you decided not to use the given options, the ammopack size has been set to large.");
		ammosize="large";
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
	EmitSoundToAll("items/spawn_item.wav", entity, _, _, _, 0.75);

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned a %s ammopack!", ammosize);
	LogAction(client, client, "[Spawn] \"%L\" spawned a %s ammopack", client, ammosize);
}

stock Command_Spawn_Healthpack(client, String:healthsize[128])
{
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
	else
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Since you decided not to use the given options, the healthpack size has been set to large.");
		healthsize="large";
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
	EmitSoundToAll("items/spawn_item.wav", entity, _, _, _, 0.75);

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned a %s healthpack!", healthsize);
	LogAction(client, client, "[Spawn] \"%L\" spawned a %s healthpack", client, healthsize);
}

/*==========BUILDINGS==========*/
stock Command_Spawn_Sentry(client, level=1, bool:mini=false)
{
	new Float:angles[3];
	GetClientEyeAngles(client, angles);
	decl String:model[64];
	new shells, health, rockets;
	new team=GetClientTeam(client);
	if(team==2)
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} You must be on either {Red}RED{Default} or {Blue}BLU{Default} to use this command.");
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
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Haha, no.  The sentry's level has been set to 1.  Good try though.");
			level=1;
			model="models/buildables/sentry1.mdl";
			shells=100;
			health=150;
		}
	}

	new skin=team-2;
	if(mini && level==1)
	{
		skin=team;
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
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Something went wrong with the build rotation!");
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
	return;
}

stock Command_Spawn_Dispenser(client, level=1)
{
	decl String:model[128];
	new Float:angles[3];
	GetClientEyeAngles(client, angles);
	new health;
	new ammo=400;
	new team=GetClientTeam(client);
	if(team==2)
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
	SetEntityModel(entity, model);

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
	SetEntPropEnt(entity, Prop_Send, "m_hBuilder", client);
	SetEntPropVector(entity, Prop_Send, "m_vecBuildMaxs", Float:{24.0, 24.0, 55.0});
	SetEntPropVector(entity, Prop_Send, "m_vecBuildMins", Float:{-24.0, -24.0, 0.0});
	SetEntPropFloat(entity, Prop_Send, "m_flPercentageConstructed", level==1 ? 0.99:1.0);
	if(level==1)
	{
		SetEntProp(entity, Prop_Send, "m_bBuilding", 1);
	}

	new offs=FindSendPropInfo("CObjectDispenser", "m_iDesiredBuildRotations");
	if(offs<=0)
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Something went wrong with the build rotation!");
		return;
	}
	SetEntData(entity, offs-12, 1, 1, true);

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned a level %i dispenser!", level);
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

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned Merasmus with %i health!", health);
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
		letsChangeThisEvent=level;
	}
	else if(level<=0)
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} {Red}ERROR:{Default} Monoculus' level was below 1!  That shouldn't be happening.");
		return;
	}
	DispatchSpawn(entity);
	position[2]-=10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned a level %i Monoculus!", level);
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

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned the Horseless Headless Horsemann!");
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

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned a tank!");
	LogAction(client, client, "[Spawn] \"%L\" spawned a tank", client);
	return;
}

stock Command_Spawn_Zombie(client)
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

	CPrintToChat(client, "{Vintage}[Spawn]{Default} You spawned a zombie!");
	LogAction(client, client, "[Spawn] \"%L\" spawned a zombie", client);
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
	if(args==1)
	{
		GetCmdArg(1, selection, sizeof(selection));
	}
	else if(args>1)
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
			SetVariantInt(9999);
			AcceptEntityInput(entity, "Kill");
			count++;
		}

		if(count!=0)
		{
			if(count==1)
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You slayed the only cow!");
				LogAction(client, client, "[Spawn] \"%L\" slayed the only cow", client);
			}
			else
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You slayed %i cows!", count);
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
			SetVariantInt(9999);
			AcceptEntityInput(entity, "Kill");
			count++;
		}

		if(count!=0)
		{
			if(count==1)
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You removed the only explosive barrel!");
				LogAction(client, client, "[Spawn] \"%L\" removed the only explosive barrel", client);
			}
			else
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You removed %i explosive barrels!", count);
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
			SetVariantInt(9999);
			AcceptEntityInput(entity, "Kill");
			count++;
		}

		if(count!=0)
		{
			if(count==1)
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You removed the only ammopack!");
				LogAction(client, client, "[Spawn] \"%L\" removed the only ammopack", client);
			}
			else
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You removed %i ammopacks!", count);
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
			SetVariantInt(9999);
			AcceptEntityInput(entity, "Kill");
			count++;
		}

		if(count!=0)
		{
			if(count==1)
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You removed the only healthpack!");
				LogAction(client, client, "[Spawn] \"%L\" removed the only healthpack", client);
			}
			else
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You removed %i healthpacks!", count);
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
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You destroyed your only sentry!");
				LogAction(client, client, "[Spawn] \"%L\" destroyed his/her only sentry", client);
			}
			else
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You destroyed all %i of your sentries!", count);
				LogAction(client, client, "[Spawn] \"%L\" destroyed all %i of his/her sentries", client, count);
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
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You destroyed your only dispenser!");
				LogAction(client, client, "[Spawn] \"%L\" destroyed his/her only dispenser", client);
			}
			else
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You destroyed all %i of your dispensers!", count);
				LogAction(client, client, "[Spawn] \"%L\" destroyed all %i of his/her dispensers", client, count);
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
			new Handle:event=CreateEvent("merasmus_killed", true);
			FireEvent(event);
			SetVariantInt(9999);
			AcceptEntityInput(entity, "Kill");
			count++;
		}

		if(count!=0)
		{
			if(count==1)
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You slayed the only Merasmus!");
				LogAction(client, client, "[Spawn] \"%L\" slayed the only Merasmus", client);
			}
			else
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You slayed %i Merasmuses!", count);
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
			new Handle:event=CreateEvent("eyeball_boss_killed", true);
			FireEvent(event);
			SetVariantInt(9999);
			AcceptEntityInput(entity, "Kill");
			count++;
		}

		if(count!=0)
		{
			if(count==1)
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You slayed the only Monoculus!");
				LogAction(client, client, "[Spawn] \"%L\" slayed the only Monoculus", client);
			}
			else
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You slayed %i Monoculuses!", count);
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
			new Handle:event=CreateEvent("pumpkin_lord_killed", true);
			FireEvent(event);
			SetVariantInt(9999);
			AcceptEntityInput(entity, "Kill");
			count++;
		}

		if(count!=0)
		{
			if(count==1)
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You slayed the only Horseless Headless Horsemann!");
				LogAction(client, client, "[Spawn] \"%L\" slayed the only Horseless Headless Horsemann", client);
			}
			else
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You slayed %i Horseless Headless Horsemanns!", count);
				LogAction(client, client, "[Spawn] \"%L\" slayed %i Horseless Headless Horsemanns", client, count);
			}
			count=0;
		}
		else
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Couldn't find any Horseless Headless Horsemanns to slay!");
		}
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "tank", false))
	{
		while((entity=FindEntityByClassname(entity, "tank_boss"))!=-1 && IsValidEntity(entity))
		{
			SetVariantInt(9999);
			AcceptEntityInput(entity, "Kill");
			count++;
		}

		if(count!=0)
		{
			if(count==1)
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You destroyed the only tank!");
				LogAction(client, client, "[Spawn] \"%L\" destroyed the only tank", client);
			}
			else
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You destroyed %i tanks!", count);
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
	else if(StrEqual(selection, "zombie", false))
	{
		while((entity=FindEntityByClassname(entity, "tf_zombie"))!=-1 && IsValidEntity(entity))
		{
			SetVariantInt(9999);
			AcceptEntityInput(entity, "Kill");
			count++;
		}

		if(count!=0)
		{
			if(count==1)
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You slayed the only zombie!");
				LogAction(client, client, "[Spawn] \"%L\" slayed the only zombie", client);
			}
			else
			{
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You slayed %i zombies!", count);
				LogAction(client, client, "[Spawn] \"%L\" slayed %i zombies", client, count);
			}
			count=0;
		}
		else
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Couldn't find any zombies to slay!");
		}
		return Plugin_Handled;
	}
	else if(StrEqual(selection, "aim", false))
	{
		if(GetClientTeam(client)==2)
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} You must be on either {Red}RED{Default} or {Blue}BLU{Default} to use this command.");
			return Plugin_Handled;
		}

		entity=GetClientAimTarget(client, false);
		if(!IsValidEntity(entity))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} No valid entity found at aim.");
			return Plugin_Handled;
		}

		if((entity=FindEntityByClassname(entity, "obj_dispenser"))!=-1 || (entity=FindEntityByClassname(entity, "obj_sentrygun"))!=-1)
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hBuilder")==client)
			{
				SetVariantInt(9999);
				AcceptEntityInput(entity, "RemoveHealth");
				CPrintToChat(client, "{Vintage}[Spawn]{Default} You removed a building!");
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
			SetVariantInt(9999);
			AcceptEntityInput(entity, "Kill");
			CPrintToChat(client, "{Vintage}[Spawn]{Default} You removed an entity!");
			LogAction(client, client, "[Spawn] \"%L\" removed an entity (entity %i)", client, entity);
			return Plugin_Handled;
		}
	}
	else
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Usage: spawn_remove <entity|aim>");
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
	AddMenuItem(menu, "health_large", "Large Healthpack");
	AddMenuItem(menu, "health_medium", "Medium Healthpack");
	AddMenuItem(menu, "health_small", "Small Healthpack");
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
	if(action==MenuAction_Select)
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
			Command_Spawn_Sentry(client, 1, false);
		}
		else if(StrEqual(selection, "sentry1m"))
		{
			Command_Spawn_Sentry(client, 1, true);
		}
		else if(StrEqual(selection, "sentry2"))
		{
			Command_Spawn_Sentry(client, 2, false);
		}
		else if(StrEqual(selection, "sentry2m"))
		{
			Command_Spawn_Sentry(client, 2, true);
		}
		else if(StrEqual(selection, "sentry3"))
		{
			Command_Spawn_Sentry(client, 3, false);
		}
		else if(StrEqual(selection, "sentry3m"))
		{
			Command_Spawn_Sentry(client, 3, true);
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
		else if(StrEqual(selection, "zombie"))
		{
			Command_Spawn_Zombie(client);
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
}

/*AttachAdminMenu()
{
	AddToTopMenu(adminMenu, "Spawn Commands", TopMenuObject_Category, CategoryHandler, INVALID_TOPMENUOBJECT);
}
 
public CategoryHandler(Handle:topmenu, TopMenuAction:action, TopMenuObject:objectID, param, String:buffer[], maxlength)
{
	if(action==TopMenuAction_DisplayTitle)
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
	while((entity=FindEntityByClassname(entity, "obj_sentrygun"))!=-1)
	{
		if(GetEntPropEnt(entity, Prop_Send, "m_hBuilder")==client)
		{
			SetVariantInt(9999);
			AcceptEntityInput(entity, "RemoveHealth");
		}
	}
	while((entity=FindEntityByClassname(entity, "obj_dispenser"))!=-1)
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
	decl String:help[128];
	if(args==1)
	{
		GetCmdArg(1, help, sizeof(help));
		if(StrEqual(help, "cow", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Just type {Skyblue}spawn cow{Default} in console and you're done!");
			return Plugin_Handled;
		}
		else if(StrEqual(help, "explosive_barrel", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Just type {Skyblue}spawn explosive_barrel{Default} in console and you're done!");
			return Plugin_Handled;
		}
		else if(StrEqual(help, "ammopack", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} {Skyblue}spawn ammopack <large|medium|small>{Default} has one argument:  The size of the ammopack.  Just choose large, medium, or small!  Example:  {Skyblue}spawn ammopack medium{Default}.");
			return Plugin_Handled;
		}
		else if(StrEqual(help, "healthpack", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} {Skyblue}spawn healthpack <large|medium|small>{Default} has one argument:  The size of the healthpack.  Just choose large, medium, or small!  Example:  {Skyblue}spawn healthpack medium{Default}.");
			return Plugin_Handled;
		}
		else if(StrEqual(help, "sentry", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} {Skyblue}spawn sentry <level> <mini (true/false)>{Default} has two arguments:  The level of the sentry and whether it is a mini-sentry.  Choose 1, 2, or 3 for the first argument and true/false for the second (you don't need to input the second argument if you're not creating a mini-sentry)!  Example:  {Skyblue}spawn sentry 2 true{Default}.");
			return Plugin_Handled;
		}
		else if(StrEqual(help, "dispenser", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} {Skyblue}spawn dispenser <level>{Default} has one argument:  The level of the dispenser.  Just choose 1, 2, or 3!  Example:  {Skyblue}spawn dispenser 2{Default}.");
			return Plugin_Handled;
		}
		else if(StrEqual(help, "merasmus", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} {Skyblue}spawn merasmus <health>{Default} has one argument:  The amount of health Merasmus has.  Just choose any integer larger than 0!  Example:  {Skyblue}spawn merasmus 2394723{Default}.");
			return Plugin_Handled;
		}
		else if(StrEqual(help, "monoculus", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} {Skyblue}spawn monoculus <level>{Default} has one argument:  Monoculus' level.  Just choose any integer larger than 0!  Example:  {Skyblue}spawn monoculus 3{Default}.");
			return Plugin_Handled;
		}
		else if(StrEqual(help, "hhh", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Just type {Skyblue}spawn hhh{Default} in console and you're done!");
			return Plugin_Handled;
		}
		else if(StrEqual(help, "tank", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Just type {Skyblue}spawn tank{Default} in console and you're done!");
			return Plugin_Handled;
		}
		else if(StrEqual(help, "zombie", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} Just type {Skyblue}spawn zombie{Default} in console and you're done!");
			return Plugin_Handled;
		}
		else if(StrEqual(help, "remove", false))
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} {Skyblue}spawn_remove <entity|aim> has one arugment:  How to remove the entity.  You can either choose to remove all of one entity, or the entity you're aiming at.  Example:  {Skyblue}spawn_remove monoculus{Default}.");
			return Plugin_Handled;
		}
		else
		{
			CPrintToChat(client, "{Vintage}[Spawn]{Default} That wasn't a valid entity!  Try {Skyblue}spawn_help{Default} without any arguments for more info!");
			return Plugin_Handled;
		}
	}
	else
	{
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Available entities:  cow, explosive_barrel, ammopack <large|medium|small>, healthpack <large|medium|small>, sentry <level> <mini (true/false)>, dispenser <level>, merasmus <health>, monoculus <level>, hhh, tank, zombie");
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Need to remove something?  Try {Skyblue}spawn_remove <entity|aim>{Default}!");
		CPrintToChat(client, "{Vintage}[Spawn]{Default} Still confused?  Type {Skyblue}spawn_menu{Default} to bring up the menu!  You could also try {Skyblue}spawn_help <entity>{Default}.");
		return Plugin_Handled;
	}
}

/*
CHANGELOG:
----------
1.0.0 Beta 12 (October 7, 2013 A.D.):  Major refactor of spawn commands, added way more info to spawn_help, changed all CReplyToCommands to CPrintToChats except for the IsValidClient checks, hopefully fixed dispenser's model being incorrect, forbid spectators from spawning buildings and removing entities using "aim", slight code formatting, and changed around Merasmus' and Monoculus' avaliable arguments.
1.0.0 Beta 11 (October 3, 2013 A.D.):  Changed Plugin_Continue back to Plugin_Handled, changed the spawn command to let you manually choose an entity to spawn, fixed entity health, changed spawn_medipack to spawn_healthpack, fixed being spammed whenever you removed an entity, more minor code formatting, and changed "Headless Horseless Horsemann" to "Horseless Headless Horsemann".
1.0.0 Beta 10 (October 2, 2013 A.D.):  Changed some ReplyToCommands back to PrintToChats, refactored remove code, removed menu destroy code, changed if(client<1) to if(IsValidClient(client)), formatted some code, and fixed Merasmus for hopefully the very last time...
1.0.0 Beta 9 (September 27, 2013 A.D.):  Added sentry/dispenser destroy code and removed Menu Command Forward code (not sure why I implemented that in the first place...), fixed healthpacks, ammopacks, and Merasmus again.
1.0.0 Beta 8 (September 25, 2013 A.D.):  Finished implementing standalone menu code and worked a bit on the admin menu.  Might not work as intended.
1.0.0 Beta 7 (September 24, 2013 A.D.):  Changed sentry/dispenser code again (added mini-sentries!), added big error messages, added another line to spawn_help, started to implement the menu code, corrected more typos, and optimized/re-organized more code.
1.0.0 Beta 6 (September 23, 2013 A.D.):  Fixed spawn_help's Plugin_Continue->Plugin_Handled, tried fixing sentries always being on RED team and not shooting, slightly optimized some more code, made [Spawn] Vintage-colored.
1.0.0 Beta 5 (September 23, 2013 A.D.):  Fixed Merasmus, ammopacks, and healthpacks not spawning, fixed some checks activating at the wrong time, re-organized/optimized code, made many messages more verbose, changed Plugin_Handled after the entity spawned to Plugin_Continue, changed CPrintToChat to CReplyToCommand, and added WIP menu code.
1.0.0 Beta 4 (September 20, 2013 A.D.):  Fixed cows and hopefully Merasmus/ammopacks/healthpacks not spawning, fixed typos, optimized code, created more fallbacks, removed unfinished code, made some messages more verbose, and added more invalid checks.
*/