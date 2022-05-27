#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta_util>
#include <cstrike>
#include <hamsandwich>
#include <fun>
#include <zombie_escape_v1>

#define PLUGIN "Zombie Escape 1.1b + BOSS (Limited Edition)"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon & Hypnotize"

#define LANG_FILE "zombie_giant.txt"
#define LANG_DEFAULT LANG_SERVER
#define GAMENAME "Zombie Escape 1.1b + BOSS (Limited Edition)"

#define CAMERA_CLASSNAME "trigger_camera"
#define CAMERA_MODEL "models/rpgrocket.mdl"

new Float:g_TeamMsgTargetTime

// Task
#define TASK_COUNTDOWN 15110
#define TASK_ROUNDTIME 15111

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

// HUD
#define HUD_WIN_X -1.0
#define HUD_WIN_Y 0.20
#define HUD_NOTICE_X -1.0
#define HUD_NOTICE_Y 0.25
#define HUD_NOTICE2_X -1.0
#define HUD_NOTICE2_Y 0.70

new const CS_TEAM_NAMES[][] = { "UNASSIGNED", "TERRORIST", "CT", "SPECTATOR" }

// Environment
#define ENV_RAIN 0
#define ENV_SNOW 0
#define ENV_FOG 1
#define ENV_FOG_DENSITY "0.0005"
#define ENV_FOG_COLOR "255 212 85"

new g_MsgTeamInfo
new const Env_Sky[1][] =
{
	"Des"
}

new const Sound_GameStart[1][] =
{
	"zombie_giant/zombie_spawn.wav"
}

new const Sound_Ambience[3][] =
{
	"zombie_giant/ambience/Continuing_Suspense.mp3",
	"zombie_giant/ambience/L.O.T.B_The-Fiend.mp3",
	"zombie_giant/ambience/Luminous_Sword.mp3"
}

new const Sound_Result[1][] =
{
	"zombie_giant/zombie_result.wav"
}

//new const Vox_Count[] = "zombie_giant/count/%i.wav"

new const Vox_WinHuman[] = "zombie_giant/win_human.wav"
new const Vox_WinBoss[] = "zombie_giant/win_zombie.wav"

// Next
const PDATA_SAFE = 2

// Block Round Event
new g_BlockedObj[15][32] =
{
        "func_bomb_target",
        "info_bomb_target",
        "info_vip_start",
        "func_vip_safetyzone",
        "func_escapezone",
        "hostage_entity",
        "monster_scientist",
        "func_hostage_rescue",
        "info_hostage_rescue",
        "env_fog",
        "env_rain",
        "env_snow",
        "item_longjump",
        "func_vehicle",
        "func_buyzone"
}

// Main Cvars
new g_MaxPlayers
new g_IsZombie, g_Joined, Float:g_PassedTime, Float:g_PassedTime2, 
g_MyCamera[33], Float:g_CameraOrigin[33][3], g_MyClass[33]
new g_TotalClass, g_MyMana[33]
new Float:g_cur_origin[3], Float:g_cur_angles[3];

new Array:GiantBaseHP

// Forwards
#define MAX_FORWARD 8

enum
{
	FWD_ROUND_NEW = 0,
	FWD_ROUND_START,
	FWD_GAME_START,
	FWD_GAME_END,
	FWD_BECOME_GIANT,
	FWD_USER_KILL,
	FWD_RUNTIME,
	FWD_EQUIP
}

new g_Forwards[MAX_FORWARD], g_fwResult

new g_szPath[ 256 ];
new g_szMap[ 90 ]; 
new g_szRuta[ 300 ]; 
new g_iSaved = 0;
new g_bCargado = false;


// =============== Changing Model ===============
#define MODELCHANGE_DELAY 0.1 	// Delay between model changes (increase if getting SVC_BAD kicks)
#define ROUNDSTART_DELAY 2.0 	// Delay after roundstart (increase if getting kicks at round start)
#define SET_MODELINDEX_OFFSET 	// Enable custom hitboxes (experimental, might lag your server badly with some models)

#define MODELNAME_MAXLENGTH 32
#define TASK_CHANGEMODEL 1962

new const DEFAULT_MODELINDEX_T[] = "models/player/terror/terror.mdl"
new const DEFAULT_MODELINDEX_CT[] = "models/player/urban/urban.mdl"

new g_HasCustomModel
new Float:g_ModelChangeTargetTime
new g_CustomPlayerModel[MAX_PLAYERS+1][MODELNAME_MAXLENGTH]
#if defined SET_MODELINDEX_OFFSET
new g_CustomModelIndex[MAX_PLAYERS+1]
#endif

#define OFFSET_CSTEAMS 114
#define OFFSET_MODELINDEX 491 // Orangutanz
// ==============================================

// =============== Changing Team ================
#define TEAMCHANGE_DELAY 0.1

#define TASK_TEAMMSG 200
#define ID_TEAMMSG (taskid - TASK_TEAMMSG)

// CS Player PData Offsets (win32)
#define PDATA_SAFE 2
#define OFFSET_CSTEAMS 114

// ==============================================

// =============== Changing Speed ===============
#define Ham_CS_Player_ResetMaxSpeed Ham_Item_PreFrame 
#define SV_MAXSPEED 999.0

new g_HasCustomSpeed, g_MsgScoreInfo
// ==============================================

public plugin_init()
{
	g_iSaved = 0;
	g_bCargado = false;

	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_dictionary(LANG_FILE)
	
	// Event
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0")
	register_event("TextMsg", "Event_GameRestart", "a", "2=#Game_will_restart_in")
	register_event("DeathMsg", "Event_Death", "a")
	register_logevent("Event_RoundEnd", 2, "1=Round_End")	
	

	register_think(CAMERA_CLASSNAME, "FW_CameraThink");

	new iEntity = create_entity("info_target");

	entity_set_string(iEntity, EV_SZ_classname, "Entity_PlayerHUD");
	entity_set_float(iEntity, EV_FL_nextthink, get_gametime() + 1.0);
	register_think("Entity_PlayerHUD", "fw_StartFrame");

	g_MsgTeamInfo = get_user_msgid("TeamInfo")
	register_forward(FM_SetClientKeyValue, "fw_SetClientKeyValue")
	
	// Ham
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled_Post", 1)
	RegisterHam(Ham_Use, "func_tank", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tankmortar", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tankrocket", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tanklaser", "fw_UseStationary")
	RegisterHam(Ham_Touch, "weaponbox", "fw_TouchWeapon")
	RegisterHam(Ham_Touch, "armoury_entity", "fw_TouchWeapon")
	RegisterHam(Ham_Touch, "weapon_shield", "fw_TouchWeapon")
	RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "fw_Ham_ResetMaxSpeed")
	
	// Message
	register_message(get_user_msgid("StatusIcon"), "Message_StatusIcon")
	register_message(get_user_msgid("ClCorpse"), "Message_ClCorpse")
	
	// Forward
	g_Forwards[FWD_ROUND_NEW] = CreateMultiForward("zg_round_new", ET_IGNORE)
	g_Forwards[FWD_ROUND_START] = CreateMultiForward("zg_round_start", ET_IGNORE)
	g_Forwards[FWD_GAME_START] = CreateMultiForward("zg_game_start", ET_IGNORE)
	g_Forwards[FWD_GAME_END] = CreateMultiForward("zg_game_end", ET_IGNORE, FP_CELL)
	g_Forwards[FWD_BECOME_GIANT] = CreateMultiForward("zg_become_giant", ET_IGNORE, FP_CELL, FP_CELL, FP_FLOAT, FP_FLOAT, FP_FLOAT)
	g_Forwards[FWD_USER_KILL] = CreateMultiForward("zg_user_kill", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL)
	g_Forwards[FWD_RUNTIME] = CreateMultiForward("zg_runningtime", ET_IGNORE)
	g_Forwards[FWD_EQUIP] = CreateMultiForward("zg_equipment_menu", ET_IGNORE, FP_CELL)

	// Vars
	g_MaxPlayers = get_maxplayers()
	g_MsgScoreInfo = get_user_msgid("ScoreInfo")	

	register_clcmd( "say /boss", "f_Menu" );

	get_mapname( g_szMap, charsmax( g_szMap ) );
	get_configsdir( g_szPath, charsmax( g_szPath ) );
	formatex( g_szRuta, charsmax( g_szRuta ), "%s/%s_BOSS.ini", g_szPath, g_szMap );

	ReadPos( );
}

public plugin_precache()
{
	GiantBaseHP = ArrayCreate(1, 1)
	
	// Precache 
	new i;
	
	for(i = 0; i < sizeof(Sound_GameStart); i++)
		precache_sound(Sound_GameStart[i])
	for(i = 0; i < sizeof(Sound_Result); i++)
		precache_sound(Sound_Result[i])
	for(i = 0; i < sizeof(Sound_Ambience); i++)
		precache_sound(Sound_Ambience[i])

	precache_sound(Vox_WinHuman)
	precache_sound(Vox_WinBoss)
	precache_model(CAMERA_MODEL)
	// Handle
	Environment_Setting()
}

public plugin_natives()
{
	register_native("zg_is_giant", "Native_IsGiant", 1)
	register_native("zg_get_giantclass", "Native_GetClass", 1)
	register_native("zg_get_mana", "Native_GetMP", 1)
	register_native("zg_set_mana", "Native_SetMP", 1)
	
	register_native("zg_register_giantclass", "Native_RegisterClass", 1)
}

public plugin_cfg()
{
	server_cmd("mp_roundtime 5")
	server_cmd("sv_alltalk 1")
	server_cmd("sv_restart 1")
	
	set_cvar_num("sv_maxspeed", 999)
	set_cvar_num("sv_skycolor_r", 0)
	set_cvar_num("sv_skycolor_g", 0)
	set_cvar_num("sv_skycolor_b", 0)	
	
	// Sky
	set_cvar_string("sv_skyname", Env_Sky[random(sizeof(Env_Sky))])
	
	// New Round
	Event_NewRound()
}

public Native_IsGiant(id)
{
	if(!is_connected(id))
		return 0
		
	return Get_BitVar(g_IsZombie, id) ? 1 : 0
}

public Native_GetClass(id)
{
	if(!is_connected(id))
	{
		server_print("[ZG] Error: Get Class with unconnected User!")
		return -1
	}
	
	return g_MyClass[id]
}


public Native_GetMP(id)
{
	if(!is_connected(id))
		return 0
		
	return g_MyMana[id]
}

public Native_SetMP(id, MP)
{
	if(!is_connected(id))
		return
	
	g_MyMana[id] = MP
}

public Native_RegisterClass(BaseHealth)
{
	ArrayPushCell(GiantBaseHP, BaseHealth)
	
	g_TotalClass++
	return g_TotalClass - 1
}

public fw_BlockedObj_Spawn(ent)
{
	if (!pev_valid(ent))
		return FMRES_IGNORED
	
	static Ent_Classname[64]
	pev(ent, pev_classname, Ent_Classname, sizeof(Ent_Classname))
	
	for(new i = 0; i < sizeof g_BlockedObj; i++)
	{
		if (equal(Ent_Classname, g_BlockedObj[i]))
		{
			engfunc(EngFunc_RemoveEntity, ent)
			return FMRES_SUPERCEDE
		}
	}
	
	return FMRES_IGNORED
}

public client_putinserver(id)
{
	UnSet_BitVar(g_IsZombie, id)
	
	remove_task(id+TASK_CHANGEMODEL)

	UnSet_BitVar(g_HasCustomModel, id)
	UnSet_BitVar(g_HasCustomSpeed, id)
}

public client_disconnected(id)
{
	remove_task(id+TASK_CHANGEMODEL)
	remove_task(id+TASK_TEAMMSG)

	UnSet_BitVar(g_HasCustomModel, id)
	UnSet_BitVar(g_HasCustomSpeed, id)

	Remove_CameraEnt(id, 0)
}

public Environment_Setting()
{
	new Enable
	
	// Weather & Sky
	Enable = ENV_RAIN; if(Enable) engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_rain"))
	Enable = ENV_SNOW; if(Enable)engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_snow"))	
	Enable = ENV_FOG; 
	if(Enable)
	{
		remove_entity_name("env_fog")
		
		new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_fog"))
		if (pev_valid(ent))
		{
			fm_set_kvd(ent, "density", ENV_FOG_DENSITY, "env_fog")
			fm_set_kvd(ent, "rendercolor", ENV_FOG_COLOR, "env_fog")
		}
	}
	
	// Sky
	for(new i = 0; i < sizeof(Env_Sky); i++)
	{
		skyPrecache(Env_Sky[i])
	}		
}

public skyPrecache(const String[])
{
	new BufferB[128]

	// Preache custom sky files
	formatex(BufferB, charsmax(BufferB), "gfx/env/%sbk.tga", String); engfunc(EngFunc_PrecacheGeneric, BufferB)
	formatex(BufferB, charsmax(BufferB), "gfx/env/%sdn.tga", String); engfunc(EngFunc_PrecacheGeneric, BufferB)
	formatex(BufferB, charsmax(BufferB), "gfx/env/%sft.tga", String); engfunc(EngFunc_PrecacheGeneric, BufferB)
	formatex(BufferB, charsmax(BufferB), "gfx/env/%slf.tga", String); engfunc(EngFunc_PrecacheGeneric, BufferB)
	formatex(BufferB, charsmax(BufferB), "gfx/env/%srt.tga", String); engfunc(EngFunc_PrecacheGeneric, BufferB)
	formatex(BufferB, charsmax(BufferB), "gfx/env/%sup.tga", String); engfunc(EngFunc_PrecacheGeneric, BufferB)	
}

public Show_StatusHud()
{
	for(new i = 1; i <= g_MaxPlayers; i++)
	{
		if(!is_alive(i))
			continue
		if(cs_get_user_team(i) != CS_TEAM_T)
			continue
			
		if(g_MyMana[i] < 100)
			g_MyMana[i] = min(g_MyMana[i] + 5, 100)
	}
}

public FW_CameraThink(iEnt)
{
	new iOwner = entity_get_int(iEnt, EV_INT_iuser1);
	if(!is_user_alive(iOwner) || is_user_bot(iOwner))
		return;
	if(!is_valid_ent(iEnt))
		return;

	new Float:fPlayerOrigin[3], Float:fCameraOrigin[3], Float:vAngles[3], Float:vBack[3];

	entity_get_vector(iOwner, EV_VEC_origin, fPlayerOrigin)
	entity_get_vector(iOwner, EV_VEC_view_ofs, vAngles)
		
	fPlayerOrigin[2] += vAngles[2];
			
	entity_get_vector(iOwner, EV_VEC_v_angle, vAngles)

	angle_vector(vAngles, ANGLEVECTOR_FORWARD, vBack) 

	fCameraOrigin[0] = fPlayerOrigin[0] + (-vBack[0] * 270.0) //350
	fCameraOrigin[1] = fPlayerOrigin[1] + (-vBack[1] * 270.0) 
	fCameraOrigin[2] = fPlayerOrigin[2] + (-vBack[2] * 270.0) 

	engfunc(EngFunc_TraceLine, fPlayerOrigin, fCameraOrigin, IGNORE_MONSTERS, iOwner, 0) 
	
	new Float:flFraction; get_tr2(0, TR_flFraction, flFraction) 
	if(flFraction != 1.0)
	{ 
		flFraction *= 100.0; /* Automatic :) 200*/
	
		fCameraOrigin[0] = fPlayerOrigin[0] + (-vBack[0] * flFraction) 
		fCameraOrigin[1] = fPlayerOrigin[1] + (-vBack[1] * flFraction) 
		fCameraOrigin[2] = fPlayerOrigin[2] + (-vBack[2] * flFraction) 
	} 
	
	entity_set_vector(iEnt, EV_VEC_origin, fCameraOrigin)
	entity_set_vector(iEnt, EV_VEC_angles, vAngles)

	entity_set_float(iEnt, EV_FL_nextthink, get_gametime())
}

public Remove_CameraEnt(iPlayer, AttachView)
{
	g_MyCamera[ iPlayer ] = 0;
	if(AttachView) attach_view(iPlayer, iPlayer)

	new iEnt = -1;
	while((iEnt = find_ent_by_class(iEnt, CAMERA_CLASSNAME)))
	{
		if(!is_valid_ent(iEnt))
			continue;
		
		if(entity_get_int(iEnt, EV_INT_iuser1) == iPlayer) 
		{
			entity_set_int(iEnt, EV_INT_flags, FL_KILLME)
			dllfunc(DLLFunc_Think, iEnt)
		}
	}
}
	
public Create_Camera(id)
{
	if(pev_valid(g_MyCamera[id]))
		return
	
	static Float:vAngle[3], Float:Angles[3]
	
	pev(id, pev_origin, g_CameraOrigin[id])
	pev(id, pev_v_angle, vAngle)
	pev(id, pev_angles, Angles)

	new Ent = create_entity(CAMERA_CLASSNAME);
	if(!is_valid_ent(Ent)) return;

	entity_set_model(Ent, CAMERA_MODEL)
	entity_set_int(Ent, EV_INT_iuser1, id)
	entity_set_string(Ent, EV_SZ_classname, CAMERA_CLASSNAME)

	entity_set_int(Ent, EV_INT_solid, SOLID_NOT)
	entity_set_int(Ent, EV_INT_movetype, MOVETYPE_FLY)
	entity_set_int(Ent, EV_INT_rendermode, kRenderTransTexture)

	attach_view(id, Ent)

	entity_set_float(Ent, EV_FL_nextthink, get_gametime())

	static Float:Mins[3], Float:Maxs[3]
	
	Mins[0] = -1.0
	Mins[1] = -1.0
	Mins[2] = -1.0
	Maxs[0] = 1.0
	Maxs[1] = 1.0
	Maxs[2] = 1.0

	entity_set_size(Ent, Mins, Maxs)

	set_pev(Ent, pev_origin, g_CameraOrigin[id])
	set_pev(Ent, pev_v_angle, vAngle)
	set_pev(Ent, pev_angles, Angles)

	fm_set_rendering(Ent, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, 0)
	g_MyCamera[id] = Ent;
}

// ======================== EVENT ========================
// =======================================================
public Event_NewRound()
{
	remove_task( 5678 );
	new map[61];
	get_mapname(map, 60)

	server_cmd("zp_mode_on 0");

	// Player
	g_ModelChangeTargetTime = get_gametime() + ROUNDSTART_DELAY
	
	for(new i = 1; i <= g_MaxPlayers; i++)
	{
		remove_task(i+TASK_TEAMMSG)
		
		if(task_exists(i+TASK_CHANGEMODEL))
		{
			remove_task(i+TASK_CHANGEMODEL)
			fm_cs_user_model_update(i+TASK_CHANGEMODEL)
		}
		
		UnSet_BitVar(g_HasCustomSpeed, i)
	}
	
	// System
	remove_task(TASK_ROUNDTIME)
	remove_task(TASK_COUNTDOWN)
	
	StopSound(0)

	ExecuteForward(g_Forwards[FWD_ROUND_NEW], g_fwResult)
}

public f_Menu( id )
{
	if( ~get_user_flags( id ) & ADMIN_RCON || g_iSaved > 0 )
	return PLUGIN_HANDLED;
	
	new menu = menu_create( "Registrar BOSS","hn_poner" );
	
	menu_additem( menu, "Registrar Zona" );
	menu_additem( menu, "Guardar Zona" );
	
	menu_display( id, menu );
	return PLUGIN_HANDLED;
}

public hn_poner( id, menu, item )
{
	if ( item == MENU_EXIT || ~get_user_flags( id ) & ADMIN_RCON || g_iSaved > 0 )
	{
		menu_destroy( menu );
		return PLUGIN_HANDLED;
	}
	switch( item )
	{
		case 0: get_origin( id );
		case 1: SaveEnt( g_cur_origin, g_cur_angles );
	}
	f_Menu( id );
	return PLUGIN_HANDLED;  
} 
SaveEnt( Float:Origin[ 3 ], Float:Angles[ 3 ] )
{
	new iCoordenada[ 100 ]; 
	formatex( iCoordenada, charsmax( iCoordenada ),  "%.1f %.1f %.1f %.1f %.1f %.1f", Origin[ 0 ], Origin[ 1 ], Origin[ 2 ], Angles[ 0 ], Angles[ 1 ], Angles[ 2 ]);
	new szText[ 800 ];
	
	if( !file_exists( g_szRuta ) ) 
	{
		log_amx("Archivo '%s' No existe, pero lo creamos.", g_szRuta );
		write_file( g_szRuta, "; Archivo creado automaticamente" );
		formatex( szText, charsmax(szText), "; El mapa es %s:", g_szMap ); 
		write_file( g_szRuta, szText );
		write_file( g_szRuta, "; Las Coordenadas son:" );
		write_file( g_szRuta, "; --------------------------------" );
	}
	write_file( g_szRuta, iCoordenada );
}
public get_origin(id) 
{ 
	pev(id, pev_origin, g_cur_origin);
	pev(id, pev_angles, g_cur_angles); 
	
	client_print(id, print_chat, "[NG OBERON-NPC] El oberon nacera aqui!!!"); 
} 


public Event_RoundEnd()
{
	remove_task(TASK_ROUNDTIME)
	remove_task(TASK_COUNTDOWN)
	
	PlaySound(0, Sound_Result[random(sizeof(Sound_Result))])
}

public Event_GameRestart()
	Event_RoundEnd()

public Event_Death()
{
	static Attacker, Victim, Headshot, Weapon[32], CSW
	
	Attacker = read_data(1)
	Victim = read_data(2)
	Headshot = read_data(3)
	read_data(4, Weapon, sizeof(Weapon))
	
	if(equal(Weapon, "grenade"))
		CSW = CSW_HEGRENADE
	else { 
		static BukiNoNamae[64];
		formatex(BukiNoNamae, 63, "weapon_%s", Weapon)
		
		CSW = get_weaponid(BukiNoNamae)
	}
	
	ExecuteForward(g_Forwards[FWD_USER_KILL], g_fwResult, Victim, Attacker, Headshot, CSW)
}
//zp_round_started

public zp_round_started(mode, id)
{
	if (mode != MODE_NEMESIS+2 && g_bCargado)//adcheck que hayan cordenadas
	   return;

	Start_Game_Now(id)
}
public Start_Game_Now(iPlayer)
{
	// Play Sound
	PlaySound(0, Sound_GameStart[random(sizeof(Sound_GameStart))])
	
	//new iPlayer = ChooseRandomPlayer();
	//client_print_color(0 , print_team_blue, "%d", iPlayer)
	if(!iPlayer)
		return;

	Set_PlayerZombie(iPlayer);

	for(new i = 1; i <= g_MaxPlayers; i++)
	{
		if(!is_alive(i))
			continue
		if(is_user_zombie(i))
			continue
			
		// Show Message
		set_dhudmessage(0, 127, 255, HUD_NOTICE_X, HUD_NOTICE_Y, 0, 0.1, 5.0, 0.01, 0.5)
		show_dhudmessage(i, "%L", LANG_DEFAULT, "NOTICE_ZOMBIEAPPEAR")
			
		// Show Message
		set_dhudmessage(85, 255, 85, HUD_NOTICE2_X, HUD_NOTICE2_Y, 2, 0.1, 3.0, 0.01, 0.5)
		show_dhudmessage(i, "%L", LANG_DEFAULT, "NOTICE_ALIVETIME")

		Make_PlayerShake(i)

		if(cs_get_user_team(i) == CS_TEAM_CT)
			continue
			
		// Set Team
		//Set_PlayerTeam(i, CS_TEAM_CT)
	}
	
	// Ambience
	PlaySound(0, Sound_Ambience[random(sizeof(Sound_Ambience))])
	
	// Exec Forward
	ExecuteForward(g_Forwards[FWD_GAME_START], g_fwResult)
}

public Set_PlayerZombie(id)
{
	static CodeTitan; 
	CodeTitan = random_num(0, g_TotalClass-1);

	// Set Info
	Set_BitVar(g_IsZombie, id)	

	
	g_MyMana[id] = 100
	g_MyClass[id] = CodeTitan
	
	set_pev(id, pev_solid, SOLID_NOT)
	set_pev(id, pev_movetype, MOVETYPE_NOCLIP)
	fm_set_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, 0)
	
	// HP
	static HP; HP = ArrayGetCell(GiantBaseHP, CodeTitan)
	//console_print(0, "players %d", fnGetAlive() )
	static PlayerNum; PlayerNum = fnGetAlive() <= 0 ? 8000 : fnGetAlive() * 5000;
	//console_print(0, "hp %d", PlayerNum )
	
	HP *= PlayerNum

	set_user_health(id, PlayerNum);
	
	// Camera
	Create_Camera(id)
	
	// Handle Player
	fm_strip_user_weapons(id)
	fm_give_item(id, "weapon_knife")

	ExecuteForward(g_Forwards[FWD_BECOME_GIANT], g_fwResult, id, CodeTitan, g_cur_origin[0], g_cur_origin[1], g_cur_origin[2])
}

public fw_StartFrame(iEntity)
{
	if (!is_valid_ent(iEntity))
        return;

	static Float:Time; Time = get_gametime()
	
	if(Time - 1.0 > g_PassedTime)
	{
		ExecuteForward(g_Forwards[FWD_RUNTIME], g_fwResult);
		g_PassedTime = Time
	}
	if(Time - 0.5 > g_PassedTime2)
	{
		Show_StatusHud()
		g_PassedTime2 = Time
	}
	entity_set_float(iEntity, EV_FL_nextthink, get_gametime() + 0.1);
}

public fw_SetClientKeyValue(id, const infobuffer[], const key[], const value[])
{
	if (Get_BitVar(g_HasCustomModel, id) && equal(key, "model"))
	{
		static currentmodel[MODELNAME_MAXLENGTH]
		fm_cs_get_user_model(id, currentmodel, charsmax(currentmodel))
		
		if (!equal(currentmodel, g_CustomPlayerModel[id]) && !task_exists(id+TASK_CHANGEMODEL))
			fm_cs_set_user_model(id+TASK_CHANGEMODEL)
		
#if defined SET_MODELINDEX_OFFSET
		fm_cs_set_user_model_index(id)
#endif
		
		return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}

// ===================== HAMSANDWICH =====================
// =======================================================
public fw_PlayerSpawn_Post(id)
{
	if(!is_user_alive(id)) return
	
	Set_BitVar(g_Joined, id)
	
	UnSet_BitVar(g_IsZombie, id)
	Remove_CameraEnt(id, 1) 
	
	fm_set_user_rendering(id)
	
	Reset_PlayerSpeed(id)
	// Exec
	ExecuteForward(g_Forwards[FWD_EQUIP], g_fwResult, id)
}

public fw_PlayerKilled_Post(Victim, Attacker)
{
	if(is_user_connected(Victim))
		Remove_CameraEnt(Victim, 0)
}

public fw_UseStationary(entity, caller, activator, use_type)
{
	if (use_type == 2 && is_alive(caller) && is_user_zombie(caller))
		return HAM_SUPERCEDE
	
	return HAM_IGNORED
}

public fw_TouchWeapon(weapon, id)
{
	if(!is_connected(id))
		return HAM_IGNORED
	if(is_user_zombie(id))
		return HAM_SUPERCEDE
	
	return HAM_IGNORED
}

public fw_Ham_ResetMaxSpeed(id)
{
	return ( Get_BitVar(g_HasCustomSpeed, id) ) ? HAM_SUPERCEDE : HAM_IGNORED;
}  

public Make_PlayerShake(id)
{
	static MSG; if(!MSG) MSG = get_user_msgid("ScreenShake")
	
	if(!id) 
	{
		message_begin(MSG_BROADCAST, MSG)
		write_short(8<<12)
		write_short(5<<12)
		write_short(4<<12)
		message_end()
	} else {
		if(!is_user_connected(id))
			return
			
		message_begin(MSG_BROADCAST, MSG, _, id)
		write_short(8<<12)
		write_short(5<<12)
		write_short(4<<12)
		message_end()
	}
}

// ===================== MESSAGES ========================
// =======================================================
public Message_StatusIcon(msg_id, msg_dest, msg_entity)
{
	static szMsg[8];
	get_msg_arg_string(2, szMsg ,7)
	
	if(equal(szMsg, "buyzone") && get_msg_arg_int(1))
	{
		if(pev_valid(msg_entity) != PDATA_SAFE)
			return  PLUGIN_CONTINUE;
	
		set_pdata_int(msg_entity, 235, get_pdata_int(msg_entity, 235) & ~(1<<0))
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public Message_ClCorpse()
{
	static id; id = get_msg_arg_int(12)
	set_msg_arg_string(1, g_CustomPlayerModel[id])

	return PLUGIN_CONTINUE
}

public Set_PlayerModel(id, const Model[])
{
	if(!is_connected(id))
		return false
	
	remove_task(id+TASK_CHANGEMODEL)
	Set_BitVar(g_HasCustomModel, id)
	
	copy(g_CustomPlayerModel[id], charsmax(g_CustomPlayerModel[]), Model)
	
	#if defined SET_MODELINDEX_OFFSET	
	new modelpath[32+(2*MODELNAME_MAXLENGTH)]
	formatex(modelpath, charsmax(modelpath), "models/player/%s/%s.mdl", Model, Model)
	g_CustomModelIndex[id] = engfunc(EngFunc_ModelIndex, modelpath)
	#endif
	
	new currentmodel[MODELNAME_MAXLENGTH]
	fm_cs_get_user_model(id, currentmodel, charsmax(currentmodel))
	
	if (!equal(currentmodel, Model))
		fm_cs_user_model_update(id+TASK_CHANGEMODEL)
	
	return true;
}

public Reset_PlayerModel(id)
{
	if(!is_connected(id))
		return false;
	
	// Player doesn't have a custom model, no need to reset
	if(!Get_BitVar(g_HasCustomModel, id))
		return true;
	
	remove_task(id+TASK_CHANGEMODEL)
	UnSet_BitVar(g_HasCustomModel, id)
	fm_cs_reset_user_model(id)
	
	return true;	
}


public Reset_PlayerSpeed(id)
{
	if(!is_alive(id))
		return
		
	UnSet_BitVar(g_HasCustomSpeed, id)
	ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id)
}

public is_user_zombie(id)
{
	if(!is_connected(id))
		return 0
	
	return Get_BitVar(g_IsZombie, id) ? 1 : 0
}

stock Get_PlayerCount(Alive, Team)
// Alive: 0 - Dead | 1 - Alive | 2 - Both
// Team: 1 - T | 2 - CT
{
	new Flag[4], Flag2[12]
	new Players[32], PlayerNum

	if(!Alive) formatex(Flag, sizeof(Flag), "%sb", Flag)
	else if(Alive == 1) formatex(Flag, sizeof(Flag), "%sa", Flag)
	
	if(Team == 1) 
	{
		formatex(Flag, sizeof(Flag), "%se", Flag)
		formatex(Flag2, sizeof(Flag2), "TERRORIST", Flag)
	} else if(Team == 2) 
	{
		formatex(Flag, sizeof(Flag), "%se", Flag)
		formatex(Flag2, sizeof(Flag2), "CT", Flag)
	}
	
	get_players(Players, PlayerNum, Flag, Flag2)
	
	return PlayerNum
}

stock Get_TotalInPlayer(Alive)
{
	return Get_PlayerCount(Alive, 1) + Get_PlayerCount(Alive, 2)
}


stock PlaySound(id, const sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
}

stock StopSound(id) client_cmd(id, "mp3 stop; stopsound")

public fm_cs_set_user_model(taskid)
{
	static id; id = taskid - TASK_CHANGEMODEL
	set_user_info(id, "model", g_CustomPlayerModel[id])
}

stock fm_cs_set_user_model_index(id)
{
	if (pev_valid(id) != PDATA_SAFE)
		return;
	
	set_pdata_int(id, OFFSET_MODELINDEX, g_CustomModelIndex[id])
}

stock fm_cs_reset_user_model_index(id)
{
	if (pev_valid(id) != PDATA_SAFE)
		return;
	
	switch(cs_get_user_team(id))
	{
		case CS_TEAM_T: set_pdata_int(id, OFFSET_MODELINDEX, engfunc(EngFunc_ModelIndex, DEFAULT_MODELINDEX_T))
		case CS_TEAM_CT: set_pdata_int(id, OFFSET_MODELINDEX, engfunc(EngFunc_ModelIndex, DEFAULT_MODELINDEX_CT))
	}
}

stock fm_cs_get_user_model(id, model[], len)
{
	get_user_info(id, "model", model, len)
}

stock fm_cs_reset_user_model(id)
{
	// Set some generic model and let CS automatically reset player model to default
	copy(g_CustomPlayerModel[id], charsmax(g_CustomPlayerModel[]), "gordon")
	fm_cs_user_model_update(id+TASK_CHANGEMODEL)
#if defined SET_MODELINDEX_OFFSET
	fm_cs_reset_user_model_index(id)
#endif
}

stock fm_cs_user_model_update(taskid)
{
	new Float:current_time
	current_time = get_gametime()
	
	if(current_time - g_ModelChangeTargetTime >= MODELCHANGE_DELAY)
	{
		fm_cs_set_user_model(taskid)
		g_ModelChangeTargetTime = current_time
	} else {
		set_task((g_ModelChangeTargetTime + MODELCHANGE_DELAY) - current_time, "fm_cs_set_user_model", taskid)
		g_ModelChangeTargetTime = g_ModelChangeTargetTime + MODELCHANGE_DELAY
	}
}


public is_connected(id)
{
	if(!(1 <= id <= 32))
		return 0

	return is_user_connected(id) ? 1 : 0;
}

public is_alive(id)
{
	if(!is_user_connected(id))
		return 0;
	
		
	return is_user_alive(id) ? 1 : 0;
}

fnGetAlive()
{
	static iAlive, id
	iAlive = 0
	
	for (id = 1; id <= g_MaxPlayers; id++)
	{
		if (is_user_alive(id))
			iAlive++
	}
	
	return iAlive;
}

public ReadPos( )
{
	if( !file_exists( g_szRuta ) ) 
	{
		log_amx("[ AMXX ] Archivo '%s' NO Existe.", g_szRuta );
		return;
	}
	new szDat[ 40 ], szDat2[ 40 ], szDat3[ 40 ], szDat4[ 40 ], szDat5[ 40 ], szDat6[ 40 ];
	new szLine[ 700 ], iContador = 0;
	
	new file; file = fopen( g_szRuta, "r" );
	while( file && !feof( file ) )
	{
		fgets( file, szLine, charsmax( szLine ) );
		
		if( szLine[ 0 ] == ';' || szLine[ 0 ] == '/' && szLine[ 1 ] == '/' || !szLine[ 0 ] )
			continue;
		
		parse( szLine, szDat, charsmax( szDat ), szDat2, charsmax( szDat2 ), szDat3, charsmax( szDat3 ), szDat4, charsmax( szDat4 ), szDat5, charsmax( szDat5 ), szDat6, charsmax( szDat6 ) );
		
		if( iContador < 1 )
		{
			g_cur_origin[ 0 ] = str_to_float( szDat );
			g_cur_origin[ 1 ] = str_to_float( szDat2 );
			g_cur_origin[ 2 ] = str_to_float( szDat3 );
			
			g_cur_angles[ 0 ] = str_to_float( szDat4 );
			g_cur_angles[ 1 ] = str_to_float( szDat5 );
			g_cur_angles[ 2 ] = str_to_float( szDat6 );
			
			g_bCargado= true;
		}
		++iContador;
	}
	g_iSaved = iContador;
	fclose( file );
}

public Set_PlayerTeam(id, CsTeams:Team)
{
	if(!is_connected(id))
		return
	
	if(pev_valid(id) != PDATA_SAFE)
		return

	// Remove previous team message task
	remove_task(id+TASK_TEAMMSG)
	
	// Set team offset
	set_pdata_int(id, OFFSET_CSTEAMS, _:Team)
	
	// Send message to update team?
	fm_user_team_update_2(id)	
}
stock fm_user_team_update_2(id)
{	
	new Float:current_time
	current_time = get_gametime()
	
	if (current_time - g_TeamMsgTargetTime >= TEAMCHANGE_DELAY)
	{
		set_task(0.1, "fm_cs_set_user_team_msg2", id+TASK_TEAMMSG)
		g_TeamMsgTargetTime = current_time + TEAMCHANGE_DELAY
	}
	else
	{
		set_task((g_TeamMsgTargetTime + TEAMCHANGE_DELAY) - current_time, "fm_cs_set_user_team_msg2", id+TASK_TEAMMSG)
		g_TeamMsgTargetTime = g_TeamMsgTargetTime + TEAMCHANGE_DELAY
	}
}
public fm_cs_set_user_team_msg2(taskid)
{
	// Tell everyone my new team
	emessage_begin(MSG_ALL, g_MsgTeamInfo)
	ewrite_byte(ID_TEAMMSG) // player
	ewrite_string(CS_TEAM_NAMES[_:cs_get_user_team(ID_TEAMMSG)]) // team
	emessage_end()
	
	// Fix for AMXX/CZ bots which update team paramater from ScoreInfo message
	emessage_begin(MSG_BROADCAST, g_MsgScoreInfo)
	ewrite_byte(ID_TEAMMSG) // id
	ewrite_short(pev(ID_TEAMMSG, pev_frags)) // frags
	ewrite_short(cs_get_user_deaths(ID_TEAMMSG)) // deaths
	ewrite_short(0) // class?
	ewrite_short(_:cs_get_user_team(ID_TEAMMSG)) // team
	emessage_end()
}
