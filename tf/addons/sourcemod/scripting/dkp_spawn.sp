//TODO:  SLAYING/REMOVING, MENUS
//Proposed color:  Vintage?
//Thanks to abrandnewday, DarthNinja, HL-SDK, and X3Mano for your plugins that were so helpful to me in writing my plugin!
//Changelog is at the very bottom.

#pragma semicolon 1

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <sdktools>
#include <sdkhooks>
#include <adminmenu>
#include <morecolors>

#define PLUGIN_VERSION "1.0.0 Beta 5"
#define MAXENTITIES 256

new Handle:Merasmus_Base_HP=INVALID_HANDLE;
new Handle:Merasmus_HP_Per_Player=INVALID_HANDLE;
new Handle:Monoculus_HP_Level_2=INVALID_HANDLE;
new Handle:Monoculus_HP_Player=INVALID_HANDLE;
new Handle:Monoculus_HP_Level=INVALID_HANDLE;

new Handle:AdminMenu=INVALID_HANDLE;

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

	RegAdminCmd("spawn_cow", Command_Spawn_Cow, ADMFLAG_GENERIC, "Spawn a cow!");
	RegAdminCmd("spawn_explosive_barrel", Command_Spawn_Explosive_Barrel, ADMFLAG_GENERIC, "Spawn an explosive barrel!");
	RegAdminCmd("spawn_ammopack", Command_Spawn_Ammopack, ADMFLAG_GENERIC, "Spawn an ammopack!  Usage:  spawn_ammopack <large|medium|small>");
	RegAdminCmd("spawn_medipack", Command_Spawn_Medipack, ADMFLAG_GENERIC, "Spawn a medipack!  Usage:  spawn_medipack <large|medium|small>");
	RegAdminCmd("spawn_sentry", Command_Spawn_Sentry, ADMFLAG_GENERIC, "Spawn a sentry!  Usage:  spawn_sentry <1|2|3>");
	RegAdminCmd("spawn_dispenser", Command_Spawn_Dispenser, ADMFLAG_GENERIC, "Spawn a dispenser!  Usage:  spawn_dispenser <1|2|3>");
	RegAdminCmd("spawn_merasmus", Command_Spawn_Merasmus, ADMFLAG_GENERIC, "Spawn Merasmus!  Usage:  spawn_merasmus <health>");
	RegAdminCmd("spawn_monoculus", Command_Spawn_Monoculus, ADMFLAG_GENERIC, "Spawn Monoculus!  Usage:  spawn_monoculus <level>");
	RegAdminCmd("spawn_horsemann", Command_Spawn_Horsemann, ADMFLAG_GENERIC, "Spawn the HHHH Jr!");
	RegAdminCmd("spawn_tank", Command_Spawn_Tank, ADMFLAG_GENERIC, "Spawn a tank!");
	RegAdminCmd("spawn_zombie", Command_Spawn_Zombie, ADMFLAG_GENERIC, "Spawn a zombie!");
	RegAdminCmd("spawn_help", Command_Spawn_Help, ADMFLAG_GENERIC, "Lists all entities that this plugin currently supports");

	Merasmus_Base_HP=FindConVar("tf_merasmus_health_base");
	Merasmus_HP_Per_Player=FindConVar("tf_merasmus_health_per_player");
	Monoculus_HP_Level_2=FindConVar("tf_eyeball_boss_health_at_level_2");
	Monoculus_HP_Player=FindConVar("tf_eyeball_boss_health_per_player");
	Monoculus_HP_Level=FindConVar("tf_eyeball_boss_health_per_level");

	HookEvent("merasmus_summoned", Event_Merasmus_Summoned, EventHookMode_Pre);
	HookEvent("eyeball_boss_summoned", Event_Monoculus_Summoned, EventHookMode_Pre);
	HookEvent("player_team", Event_Player_Change_Team, EventHookMode_Post);

	new Handle:topmenu;
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
		AdminMenu=INVALID_HANDLE;
	}
}

/*==========ENTITIES==========*/
public Action:Command_Spawn_Cow(client, args)
{
	if(client<1)
	{
		CReplyToCommand(client, "[Spawn] This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "[Spawn] Could not find the spawn point.");
		return Plugin_Handled;
	}

	new entity=CreateEntityByName("prop_dynamic_override");
	if(!IsValidEntity(entity))
	{
		CReplyToCommand(client, "[Spawn] The entity was invalid!");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "[Spawn] Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}
	SetEntityModel(entity, "models/props_2fort/cow001_reference.mdl");
	DispatchSpawn(entity);
	position[2] -= 10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
	SetEntityMoveType(entity, MOVETYPE_VPHYSICS);
	SetEntProp(entity, Prop_Data, "m_CollisionGroup", 5);
	SetEntProp(entity, Prop_Data, "m_nSolidType", 6);  //Not working?

	CReplyToCommand(client,"[Spawn] You spawned a cow!");
	LogAction(client, client, "[Spawn] \"%L\" spawned a cow", client);
	return Plugin_Continue;
}

public Action:Command_Spawn_Explosive_Barrel(client, args)
{
	if(client<1)
	{
		CReplyToCommand(client, "[Spawn] This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "[Spawn] Could not find the spawn point.");
		return Plugin_Handled;
	}

	new entity=CreateEntityByName("prop_physics");
	if(!IsValidEntity(entity))
	{
		CReplyToCommand(client, "[Spawn] The entity was invalid!");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "[Spawn] Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}
	SetEntityModel(entity, "models/props_c17/oildrum001_explosive.mdl");
	DispatchSpawn(entity);
	position[2]-=10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
	SetEntityMoveType(entity, MOVETYPE_VPHYSICS);
	SetEntProp(entity, Prop_Data, "m_CollisionGroup", 5);
	SetEntProp(entity, Prop_Data, "m_nSolidType", 6);

	CReplyToCommand(client,"[Spawn] You spawned an explosive barrel!");
	LogAction(client, client, "[Spawn] \"%L\" spawned an explosive barrel", client);
	return Plugin_Continue;
}

public Action:Command_Spawn_Ammopack(client, args/*, String:ammosize*/)
{
	if(client<1)
	{
		CReplyToCommand(client, "[Spawn] This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "[Spawn] Could not find the spawn point.");
		return Plugin_Handled;
	}

	new entity=CreateEntityByName("item_ammopack_full");
	if(!IsValidEntity(entity))
	{
		CReplyToCommand(client, "[Spawn] The entity was invalid!");
		return Plugin_Handled;
	}

	decl String:ammosize[128];
	if(args==1)
	{
		GetCmdArg(1, ammosize, sizeof(ammosize));
	}
	else if (args>1)
	{
		CReplyToCommand(client, "[Spawn] Format: spawn_ammopack <large|medium|small>");
		return Plugin_Handled;
	}

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
		CReplyToCommand(client, "[Spawn] Since you decided not to use the given options, the ammopack size has been set to large.");
		entity=CreateEntityByName("item_ammopack_full");
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "[Spawn] Could not find the spawn point.");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "[Spawn] Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}
	DispatchKeyValue(entity, "OnPlayerTouch", "!self,Kill,,0,-1");
	DispatchSpawn(entity);
	SetEntProp(entity, Prop_Send, "m_teamNum", 0, 4);
	position[2]-=10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);

	CReplyToCommand(client,"[Spawn] You spawned a %s ammopack!", ammosize);
	LogAction(client, client, "[Spawn] \"%L\" spawned a %s ammopack", client, ammosize);
	return Plugin_Continue;
}

public Action:Command_Spawn_Medipack(client, args/*, String:healthsize*/)
{
	if(client<1)
	{
		CReplyToCommand(client, "[Spawn] This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "[Spawn] Could not find the spawn point.");
		return Plugin_Handled;
	}

	new entity=CreateEntityByName("item_healthkit_full");
	if(!IsValidEntity(entity))
	{
		CReplyToCommand(client, "[Spawn] The entity was invalid!");
		return Plugin_Handled;
	}

	decl String:healthsize[128];
	if(args==1)
	{
		GetCmdArg(1, healthsize, sizeof(healthsize));
	}
	else
	{
		CReplyToCommand(client, "[Spawn] Format: spawn_medipack <large|medium|small>");
		return Plugin_Handled;
	}

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
		CReplyToCommand(client, "[Spawn] Since you decided not to use the given options, the medipack size has been set to large.");
		entity=CreateEntityByName("item_healthkit_full");
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "[Spawn] Could not find the spawn point.");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "[Spawn] Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}
	DispatchKeyValue(entity, "OnPlayerTouch", "!self,Kill,,0,-1");
	DispatchSpawn(entity);
	SetEntProp(entity, Prop_Send, "m_teamNum", 0, 4);
	position[2]-=10.0;
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
	EmitSoundToAll("items/spawn_item.wav", entity, _, _, _, 0.75);

	CReplyToCommand(client,"[Spawn] You spawned a %s medipack!", healthsize);
	LogAction(client, client, "[Spawn] \"%L\" spawned a %s medipack", client, healthsize);
	return Plugin_Continue;
}

/*==========BUILDINGS==========*/
public Action:Command_Spawn_Sentry(client, args/*, level*/)
{
	new Float:fBuildMaxs[]={24.0, 24.0, 66.0};
	new Float:fMdlWidth[]={1.0, 0.5, 0.0};
	new Float:angles[3];
	GetClientEyeAngles(client, angles);
	new String:model[64];
	new team=GetClientTeam(client);
	new shells, health, rockets;
	new level=1;
	if(client<1)
	{
		CReplyToCommand(client, "[Spawn] This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "[Spawn] Could not find the spawn point.");
		return Plugin_Handled;
	}

	decl String:sentrylevel[128];
	if(args==1)
	{
		GetCmdArgString(sentrylevel, sizeof(sentrylevel));
		level=StringToInt(sentrylevel);
		if(level<1 || level>4)
		{
			CReplyToCommand(client, "[Spawn] Haha, no.  The sentry's level has been set to 1.  Good try, though.");
			level=1;
		}
	}
	else if(args>1)
	{
		CReplyToCommand(client, "[Spawn] Format: spawn_sentry <1|2|3>");
		return Plugin_Handled;
	}

	if(level==1)
	{
		model="models/buildables/sentry1.mdl";
		shells=100;
		health=150;
	}
	else if(level==2)
	{
		model="models/buildables/sentry2.mdl";
		shells=120;
		health=180;
	}
	else if(level==3)
	{
		model="models/buildables/sentry3.mdl";
		shells=144;
		health=216;
		rockets=20;
	}
	else
	{
		CReplyToCommand(client, "[Spawn] The level was invalid!  That shouldn't be happening.");
		return Plugin_Handled;
	}
	new entity=CreateEntityByName("obj_sentrygun");
	if(!IsValidEntity(entity))
	{
		CReplyToCommand(client, "[Spawn] The entity was invalid!");
		return Plugin_Handled;
	}
	DispatchSpawn(entity);
	TeleportEntity(entity, position, angles, NULL_VECTOR);
	SetEntityModel(entity, model);

	SetEntData(entity, FindSendPropOffs("CObjectSentrygun", "m_flAnimTime"), 51, 4 , true);
	SetEntData(entity, FindSendPropOffs("CObjectSentrygun", "m_nNewSequenceParity"), 4, 4, true);
	SetEntData(entity, FindSendPropOffs("CObjectSentrygun", "m_nResetEventsParity"), 4, 4, true);
	SetEntData(entity, FindSendPropOffs("CObjectSentrygun", "m_ammoShells"), shells, 4, true);
	SetEntData(entity, FindSendPropOffs("CObjectSentrygun", "m_iMaxHealth"), health, 4, true);
	SetEntData(entity, FindSendPropOffs("CObjectSentrygun", "m_health"), health, 4, true);
	SetEntData(entity, FindSendPropOffs("CObjectSentrygun", "m_bBuilding"), 0, 2, true);
	SetEntData(entity, FindSendPropOffs("CObjectSentrygun", "m_bPlacing"), 0, 2, true);
	SetEntData(entity, FindSendPropOffs("CObjectSentrygun", "m_bDisabled"), 0, 2, true);
	SetEntData(entity, FindSendPropOffs("CObjectSentrygun", "m_iObjectType"), 3, true);
	SetEntData(entity, FindSendPropOffs("CObjectSentrygun", "m_iState"), 1, true);
	SetEntData(entity, FindSendPropOffs("CObjectSentrygun", "m_iUpgradeMetal"), 0, true);
	SetEntData(entity, FindSendPropOffs("CObjectSentrygun", "m_bHasSapper"), 0, 2, true);
	SetEntData(entity, FindSendPropOffs("CObjectSentrygun", "m_nSkin"), (team-2), 1, true);
	SetEntData(entity, FindSendPropOffs("CObjectSentrygun", "m_bServerOverridePlacement"), 1, 1, true);
	SetEntData(entity, FindSendPropOffs("CObjectSentrygun", "m_iUpgradeLevel"), level, 4, true);
	SetEntData(entity, FindSendPropOffs("CObjectSentrygun", "m_ammoRockets"), rockets, 4, true);

	SetEntDataEnt2(entity, FindSendPropOffs("CObjectSentrygun", "m_nSequence"), 0, true);
	SetEntDataEnt2(entity, FindSendPropOffs("CObjectSentrygun", "m_hclient"), client, true);

	SetEntDataFloat(entity, FindSendPropOffs("CObjectSentrygun", "m_flCycle"), 0.0, true);
	SetEntDataFloat(entity, FindSendPropOffs("CObjectSentrygun", "m_flPlaybackRate"), 1.0, true);
	SetEntDataFloat(entity, FindSendPropOffs("CObjectSentrygun", "m_flPercentageConstructed"), 1.0, true);
	
	SetEntDataVector(entity, FindSendPropOffs("CObjectSentrygun", "m_vecOrigin"), position, true);
	SetEntDataVector(entity, FindSendPropOffs("CObjectSentrygun", "m_angRotation"), angles, true);
	SetEntDataVector(entity, FindSendPropOffs("CObjectSentrygun", "m_vecBuildMaxs"), fBuildMaxs, true);
	SetEntDataVector(entity, FindSendPropOffs("CObjectSentrygun", "m_flModelWidthScale"), fMdlWidth, true);

	SetVariantInt(team);
	AcceptEntityInput(entity, "TeamNum", -1, -1, 0);

	SetVariantInt(team);
	AcceptEntityInput(entity, "SetTeam", -1, -1, 0);

	CReplyToCommand(client, "[Spawn] You spawned a level %i sentry!", level);
	LogAction(client, client, "[Spawn] \"%L\" a level %i sentry", client, level);
	return Plugin_Continue;
}

public Action:Command_Spawn_Dispenser(client, args/*, level*/)
{
	new Float:angles[3];
	new String:model[100];
	decl String:name[60];
	GetClientName(client, name, sizeof(name));
	GetClientEyeAngles(client, angles);
	new team=GetClientTeam(client);
	new health;
	new ammo=400;
	new level=1;
	if(client<1)
	{
		CReplyToCommand(client, "[Spawn] This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "[Spawn] Could not find the spawn point.");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "[Spawn] Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}

	decl String:dispenserlevel[128];
	if(args==1)
	{
		GetCmdArgString(dispenserlevel, sizeof(dispenserlevel));
		level=StringToInt(dispenserlevel);
		if(level<1 || level>4)
		{
			CReplyToCommand(client, "[Spawn] Haha, no.  The dispenser's level has been set to 1.  Good try though.");
			level=1;
		}
	}
	else if(args>1)
	{
		CReplyToCommand(client, "[Spawn] Format: spawn_dispenser <1|2|3>");
		return Plugin_Handled;
	}

	if(level==1)
	{
		model="models/buildables/dispenser.mdl";
		health=150;		
	}
	else if(level==2)
	{
		model="models/buildables/dispenser_lvl2.mdl";
		health=180;
	}
	else if(level==3)
	{
		model="models/buildables/dispenser_lvl3.mdl";
		health=216;
	}
	else
	{
		CReplyToCommand(client, "[Spawn] The level was invalid!  This shouldn't be happening.");
		return Plugin_Handled;
	}

	new entity=CreateEntityByName("obj_dispenser");
	if(IsValidEntity(entity))
	{
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
		SetEntProp(entity, Prop_Send, "m_teamNum", team);
		SetEntProp(entity, Prop_Send, "m_nSkin", team-2);
		SetEntProp(entity, Prop_Send, "m_iHighestUpgradeLevel", level);
		SetEntPropFloat(entity, Prop_Send, "m_flPercentageConstructed", 1.0);
		SetEntPropEnt(entity, Prop_Send, "m_hBuilder", client);		

		CReplyToCommand(client, "[Spawn] You spawned a level %i dispenser!", level);
		LogAction(client, client, "[Spawn] \"%L\" spawned a level %i dispenser", client, level);
	}
	else
	{
		CReplyToCommand(client, "[Spawn] The entity was invalid!");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

/*==========BOSSES==========*/
public Action:Command_Spawn_Merasmus(client, args)
{
	new merasmus_health=GetConVarInt(Merasmus_Base_HP);
	new merasmus_health_per_player=GetConVarInt(Merasmus_HP_Per_Player);
	new String:health[15], HP=-1;  //Temporary workaround to Merasmus not working?
	HP=merasmus_health+(merasmus_health_per_player*peopleConnected);
	if(client<1)
	{
		CReplyToCommand(client, "[Spawn] This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(args==1)
	{
		GetCmdArgString(health, sizeof(health));
		HP=StringToInt(health);
		if(HP<=0)
		{
			CReplyToCommand(client, "[Spawn] Haha, no.  Merasmus's health has been set to the default value.  Good try though.");
			HP=merasmus_health+(merasmus_health_per_player*peopleConnected);
		}
	}
	else if(args>1)
	{
		CReplyToCommand(client, "[Spawn] Format: spawn_merasmus <health>");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "[Spawn] Could not find the spawn point.");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "[Spawn] Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}

	new entity=CreateEntityByName("merasmus");
	if(!IsValidEntity(entity))
	{
		CReplyToCommand(client, "[Spawn] The entity was invalid!");
		return Plugin_Handled;
	}

	if(HP>0)
	{
		SetEntProp(entity, Prop_Data, "m_health", HP*4);
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", HP*4);
	}
	else
	{
		CReplyToCommand(client, "[Spawn] Merasmus' health was below 1!  That shouldn't be happening.");
		return Plugin_Handled;
	}
	DispatchSpawn(entity);
	TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);

	CReplyToCommand(client, "[Spawn] You spawned Merasmus with %i health!", HP);
	LogAction(client, client, "[Spawn] \"%L\" spawned Merasmus", client);
	return Plugin_Continue;
}

public Action:Command_Spawn_Monoculus(client, args)
{
	if(client<1)
	{
		CReplyToCommand(client, "[Spawn] This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "[Spawn] Could not find the spawn point.");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "[Spawn] Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}

	new entity = CreateEntityByName("eyeball_boss");
	if(IsValidEntity(entity))
	{
		new level=1;
		if(args==1)
		{
			decl String:buffer[15];
			GetCmdArg(1, buffer, sizeof(buffer));
			level=StringToInt(buffer);
			if(level<=0)
			{
				CReplyToCommand(client, "[Spawn] Haha, no.  Monoculus's level has been set to 1.  Good try though.");
				level=1;
			}
		}
		else if(args>1)
		{
			CReplyToCommand(client, "[Spawn] Format: spawn_monoculus <level>");
			return Plugin_Handled;
		}

		if(level>1)
		{
			new Monoculus_Base_HP=GetConVarInt(Monoculus_HP_Level_2);
			new Monoculus_HP_Per_Level=GetConVarInt(Monoculus_HP_Level);
			new Monoculus_HP_Per_Player=GetConVarInt(Monoculus_HP_Player);
			new NumPlayers=GetClientCount(true);

			new HP=Monoculus_Base_HP;
			HP=(HP+((level-2)*Monoculus_HP_Per_Level));
			if(NumPlayers>10)
			{
				HP=(HP+((NumPlayers-10)*Monoculus_HP_Per_Player));
			}
			SetEntProp(entity, Prop_Data, "m_iMaxHealth", HP);
			SetEntProp(entity, Prop_Data, "m_health", HP);
			letsChangeThisEvent=level;
		}
		else if(level<=0)
		{
			CReplyToCommand(client, "[Spawn] Monoculus' level was below 1!  That shouldn't be happening.");
			return Plugin_Handled;
		}
		DispatchSpawn(entity);
		position[2]-=10.0;
		TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);

		CReplyToCommand(client,"[Spawn] You spawned a level %i Monoculus!", level);
		LogAction(client, client, "[Spawn] \"%L\" spawned a level %i Monoculus", client, level);
	}
	else
	{
		CReplyToCommand(client, "[Spawn] The entity was invalid!");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:Command_Spawn_Horsemann(client, args)
{
	if(client<1)
	{
		CReplyToCommand(client, "[Spawn] This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "[Spawn] Could not find the spawn point.");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "[Spawn] Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}

	new entity=CreateEntityByName("headless_hatman");
	if(IsValidEntity(entity))
	{
		DispatchSpawn(entity);
		position[2]-=10.0;
		TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);

		CReplyToCommand(client, "[Spawn] You spawned the HHHH Jr!");
		LogAction(client, client, "[Spawn] \"%L\" spawned the HHHH Jr", client);
	}
	else
	{
		CReplyToCommand(client, "[Spawn] The entity was invalid!");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:Command_Spawn_Tank(client, args)
{
	if(client<1)
	{
		CReplyToCommand(client, "[Spawn] This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "[Spawn] Could not find the spawn point.");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "[Spawn] Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}

	new entity=CreateEntityByName("tank_boss");
	if(IsValidEntity(entity))
	{
		DispatchSpawn(entity);
		position[2] -= 10.0;
		TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);

		CReplyToCommand(client,"[Spawn] You spawned a tank!");
		LogAction(client, client, "[Spawn] \"%L\" spawned a tank", client);
	}
	else
	{
		CReplyToCommand(client, "[Spawn] The entity was invalid!");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:Command_Spawn_Zombie(client, args)
{
	if(client<1)
	{
		CReplyToCommand(client, "[Spawn] This command must be used in-game and without RCON.");
		return Plugin_Handled;
	}

	if(!SetTeleportEndPoint(client))
	{
		CReplyToCommand(client, "[Spawn] Could not find the spawn point.");
		return Plugin_Handled;
	}

	if(GetEntityCount()>=GetMaxEntities()-32)
	{
		CReplyToCommand(client, "[Spawn] Too many entities have been spawned, reload the map.");
		return Plugin_Handled;
	}

	new entity=CreateEntityByName("tf_zombie");
	if(IsValidEntity(entity))
	{
		DispatchSpawn(entity);
		position[2]-=10.0;
		TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);

		CReplyToCommand(client,"[Spawn] You spawned a zombie!");
		LogAction(client, client, "[Spawn] \"%L\" spawned a zombie", client);
	}
	else
	{
		CReplyToCommand(client, "[Spawn] The entity was invalid!");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

/*==========MENUS-WIP==========*/
/*public Action:Create_Menu(client)
{
	new Handle:menu=CreateMenu(MenuHandler);
	SetMenuTitle(menu, "Spawn Menu");
	AddMenuItem(menu, "cow", "Cow");
	AddMenuItem(menu, "explosive_barrel", "Explosive Barrel");
	AddMenuItem(menu, "sentry1", "Level 1 Sentry");
	AddMenuItem(menu, "sentry2", "Level 2 Sentry");
	AddMenuItem(menu, "sentry3", "Level 3 Sentry");
	AddMenuItem(menu, "dispenser1", "Level 1 Sentry");
	AddMenuItem(menu, "dispenser2", "Level 2 Sentry");
	AddMenuItem(menu, "dispenser3", "Level 3 Sentry");
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
	DisplayMenu(menu, client, 30);
}
public MenuHandler(Handle:menu, MenuAction:action, client, param2)
{
	new String:name[32];
	new String:selection[32];
	GetClientName(client, name, 80);
	GetMenuItem(menu, param2, selection, sizeof(selection));
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
			Command_Spawn_Sentry(client, 1, 1);
		}
		else if(StrEqual(selection, "sentry2"))
		{
			Command_Spawn_Sentry(client, 1, 2);
		}
		else if(StrEqual(selection, "sentry3"))
		{
			Command_Spawn_Sentry(client, 1, 3);
		}
		else if(StrEqual(selection, "dispenser1"))
		{
			Command_Spawn_Dispenser(client, 1, 1);
		}
		else if(StrEqual(selection, "dispenser2"))
		{
			Command_Spawn_Dispenser(client, 1, 2);
		}
		else if(StrEqual(selection, "dispenser3"))
		{
			Command_Spawn_Dispenser(client, 1, 3);
		}
		else if(StrEqual(selection, "ammo_large"))
		{
			Command_Spawn_Ammopack(client, 1, "large");
		}
		else if(StrEqual(selection, "ammo_medium"))
		{
			Command_Spawn_Ammopack(client, 1, "medium");
		}
		else if(StrEqual(selection, "ammo_small"))
		{
			Command_Spawn_Ammopack(client, 1, "small");
		}
		else if(StrEqual(selection, "health_large"))
		{
			Command_Spawn_Ammopack(client, 1, "large");
		}
		else if(StrEqual(selection, "health_medium"))
		{
			Command_Spawn_Ammopack(client, 1, "medium");
		}
		else if(StrEqual(selection, "health_small"))
		{
			Command_Spawn_Ammopack(client, 1, "small");
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
			CReplyToCommand(client, "[Spawn] Something went horribly wrong!");
		}
		Create_Menu(client);
	}
}*/

public OnAdminMenuReady(Handle:topmenu)
{
	if (topmenu==AdminMenu)
	{
		return;
	}
}

/*==========TECHNICAL STUFF==========*/
SetTeleportEndPoint(client)
{
	decl Float:vAngles[3];
	decl Float:vOrigin[3];
	decl Float:vBuffer[3];
	decl Float:vStart[3];
	decl Float:Distance;

	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);

	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(vStart, trace);
		GetVectorDistance(vOrigin, vStart, false);
		Distance=-35.0;
		GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
		position[0]=vStart[0]+(vBuffer[0]*Distance);
		position[1]=vStart[1]+(vBuffer[1]*Distance);
		position[2]=vStart[2]+(vBuffer[2]*Distance);
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
		new Handle:hEvent = CreateEvent(name);
		if (hEvent==INVALID_HANDLE)
		{
			return Plugin_Handled;
		}
		SetEventInt(hEvent, "level", letsChangeThisEvent);
		FireEvent(hEvent);
		letsChangeThisEvent = 0;
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
		percentage = 0;
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

	for(new i = 1; i <= 9; i++)
	{
		decl String:iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_found0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(new i = 3; i <= 6; i++)
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

	for(new i = 1; i <= 19; i++)
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

/*==========HELP COMMAND==========*/
public Action:Command_Spawn_Help(client, args)
{
	CReplyToCommand(client, "[Spawn] Available entities (append the name to spawn_):  cow, explosive_barrel, ammopack <large|medium|small>, medipack <large|medium|small>, sentry <1|2|3>, dispenser <1|2|3>, merasmus <health>, monoculus <level>, horsemann, tank, zombie");
	return Plugin_Handled;
}

/*
CHANGELOG:
----------
1.0.0 Beta 5 (September 23, 2013 A.D.):  Fixed Merasmus, ammopacks, and medipacks not spawning, fixed some checks activating at the wrong time, re-organized/optimized code, made many messages more verbose, changed Plugin_Handled after the entity spawned to Plugin_Continue, changed CPrintToChat to CReplyToCommand, and added WIP menu code.
1.0.0 Beta 4 (September 20, 2013 A.D.):  Fixed cows and hopefully Merasmus/ammopacks/medipacks not spawning, fixed typos, optimized code, created more fallbacks, removed unfinished code, made some messages more verbose, and added more invalid checks.
*/