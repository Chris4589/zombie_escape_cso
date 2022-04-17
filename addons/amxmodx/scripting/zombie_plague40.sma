/*
	CREATE TABLE IF NOT EXISTS zp_datos
	( 
		id_cuenta INT PRIMARY KEY NOT NULL,
		level int(10) NOT NULL DEFAULT '0',
		reset int(10) NOT NULL DEFAULT '0',
		exp int(10) NOT NULL DEFAULT '0',
		rango int(10) NOT NULL DEFAULT '0',
		ammopacks int(10) NOT NULL DEFAULT '0',
		hud int(10) NOT NULL DEFAULT '0',
		nvision int(10) NOT NULL DEFAULT '0',
		hat int(10) NOT NULL DEFAULT '0',
		kill_zombies int(10) NOT NULL DEFAULT '0',
		escapes int(10) NOT NULL DEFAULT '0'
	);
	CREATE TABLE IF NOT EXISTS zp_mapas
	(
		id_mapa INT AUTO_INCREMENT PRIMARY KEY,
		MapName VARCHAR(80) NOT NULL,
		Coordenada VARCHAR(80) NOT NULL
	);
	CREATE TABLE IF NOT EXISTS zp_record
	(
		id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
		id_user INT(10) NOT NULL,
		MapName VARCHAR(40) NOT NULL,
		Record FLOAT(10) NOT NULL
	);
	CREATE TABLE IF NOT EXISTS amx_codigos
	( 
		id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	    Code varchar(32) NOT NULL UNIQUE,
	    Pj varchar(52) NOT NULL DEFAULT 'null',
	    premio int(20) NOT NULL DEFAULT '5000',
	    usado int(2) not null default '0'
    )
*/
/*================================================================================
 [Plugin Customization]
=================================================================================*/

// All customization settings have been moved
// to external files to allow easier editing
new const ZP_CUSTOMIZATION_FILE[] = "zombieplague.ini"

// Limiters for stuff not worth making dynamic arrays out of (increase if needed)
const MAX_CSDM_SPAWNS = 128
const MAX_STATS_SAVED = 64

/*================================================================================
 Customization ends here! Yes, that's it. Editing anything beyond
 here is not officially supported. Proceed at your own risk...
=================================================================================*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <fun>
#include <accsys>
#include <sqlx>
#include <engine>
#include <regex>
#include <print_center_fx>
#include <reapi_reunion>

native active_button();//para que no revivan si tocan el escape
//native get_roleUser(id, dest[], len);
//native get_flagsUser(id, dest[], len);
/*
native get_user_coins(index);
native set_user_coins(index, value);
*/
/*================================================================================
 [Constants, Offsets, Macros]
=================================================================================*/

// Plugin Version
new const PLUGIN_VERSION[] = "1.1b"

new const g_szTop15[] = "http://45.58.56.30/zombie_escape/top15.php";
new const g_szTopAps[] = "http://45.58.56.30/zombie_escape/topaps.php";

// Customization file sections
enum
{
	SECTION_NONE = 0,
	SECTION_GRENADE_SPRITES,
	SECTION_SOUNDS,
	SECTION_AMBIENCE_SOUNDS,
	SECTION_EXTRA_ITEMS_WEAPONS,
	SECTION_HARD_CODED_ITEMS_COSTS,
	SECTION_WEATHER_EFFECTS,
	SECTION_SKY,
	SECTION_LIGHTNING,
	SECTION_KNOCKBACK,
	SECTION_OBJECTIVE_ENTS
}
// Task offsets
enum (+= 100)
{
	TASK_MODEL = 2000,
	TASK_TEAM,
	TASK_SPAWN,
	TASK_BLOOD,
	TASK_BURN,
	TASK_NVISION,
	TASK_SHOWHUD,
	TASK_MAKEZOMBIE,
	TASK_WELCOMEMSG,
	TASK_AMBIENCESOUNDS,
	TASK_CONTEO,
	BLAST_TASK,
	TASK_DROGA
}

// IDs inside tasks
#define ID_TEAM (taskid - TASK_TEAM)
#define ID_SPAWN (taskid - TASK_SPAWN)
#define ID_BLOOD (taskid - TASK_BLOOD)
#define ID_BURN (taskid - TASK_BURN)
#define ID_DROGA (taskid - TASK_DROGA)
#define ID_NVISION (taskid - TASK_NVISION)
#define ID_SHOWHUD (taskid - TASK_SHOWHUD)
#define porcentaje(%1,%2) floatround( (%1 * 100) / %2 )
#define PATTERN_IP "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"

#define ClassName "info_checkpoint" 
#define MaxCheckOnTheMap 10

// BP Ammo Refill task
#define REFILL_WEAPONID args[0]

// For player list menu handlers
#define PL_ACTION g_menu_data[id][0]

// For extra items menu handlers
#define EXTRAS_CUSTOM_STARTID (EXTRA_WEAPONS_STARTID + ArraySize(g_extraweapon_names))

const MAX_LEVEL = 30;
const DEFAULT_DAMAGE = 2000;

enum (+= 77) 
{
    TASK_ACEPT = 777
}

enum 
{
    NONE = -1,
    Master,
    Start_Amount
}

enum _:pdata 
{
    In_Party,
    Position,
    Amount_In_Party,
    Block_Party,
    UserName[32]
}

enum _:DataCallBack 
{
    MASTER,
    USER
}

enum eRadio
{
	nameRadio[40],
	rutaRadio[80]
}

new g_PartyData[33][pdata], Array:Party_Ids[33], g_MenuCallback[DataCallBack];

new cvar_time_acept, cvar_max_players, cvar_allow_bots;

const TASK_FINISH_COMBO = 6969
#define ID_FINISH_COMBO (taskid - TASK_FINISH_COMBO)

#define SOUND  "Event_Checkpoints/Take.wav"

new Float:iComboTime[33], g_iComboPartyHits[33], g_iComboPartyAP[33];

const AmmoDamageReward = 500 // Cantidad de Daño a realizar para recibir 1 ammopack
const Float:fHudX = -1.0;
const Float:fHudY = 0.9;

new g_MsgSyncParty, g_iExplode, g_bTouchExplote, g_iTouched;

// Menu selections
const MENU_KEY_AUTOSELECT = 7
const MENU_KEY_BACK = 7
const MENU_KEY_NEXT = 8
const MENU_KEY_EXIT = 9
const m_iVGUI = 510;

new tiempo_de_conteo;

new const szRadioX[ ][ eRadio ] = 
{
	{"Adelante", "zombie_plague/radio/com_go.wav",},
	{"Estoy En Posicion", "zombie_plague/radio/com_getinpos.wav",},
	{"Cubranme", "zombie_plague/radio/ct_coverme.wav",},
	{"Zombie Abatido", "zombie_plague/radio/enemydown.wav",},
	{"Retrocedan", "zombie_plague/radio/fallback.wav",},
	{"Necesito Ayuda", "zombie_plague/radio/fireassis.wav",}
};

new const SOUNDS[ ][ ] = 
{
	"radio/reloading01.wav",
	"radio/reloading02.wav"
};
new const MESSAGE_SOUND[]	= "TalRasha/countdown/player.wav";

new const sonidos_de_conteo[][] = 
{ 
	"TalRasha/countdown/one.wav",						// 1
	"TalRasha/countdown/two.wav",						// 2
	"TalRasha/countdown/three.wav",						// 3
	"TalRasha/countdown/four.wav",						// 4
	"TalRasha/countdown/five.wav",						// 5
	"TalRasha/countdown/six.wav",						// 6
	"TalRasha/countdown/seven.wav",						// 7
	"TalRasha/countdown/eight.wav",						// 8
	"TalRasha/countdown/nine.wav",						// 9
	"TalRasha/countdown/ten.wav", //10
	"TalRasha/countdown/NewRoundIn.wav" //11

} 
// Hard coded extra items
enum
{
	EXTRA_NVISION = 0,
	EXTRA_ANTIDOTE,

	EXTRA_MADNESS,
	EXTRA_INFBOMB,
	EXTRA_JUMPBOMB,
	NO_FROST,
	NO_FIRE,
	NO_PIPE,
	
	BALAS_INFINITAS,
	BALAS_CONGELADORAS,
	GASK_MASK,
	BOOST,

	EXTRA_WEAPONS_STARTID
}

// Game modes
enum
{
	MODE_NONE = 0,
	MODE_INFECTION,
	MODE_MULTI,
	MODE_NEMESIS,
	MODE_ALIEN,
	MODE_BOSS,

	MODE_SURVIVOR,
	MODE_SWARM,
	MODE_PLAGUE,
	MODE_SNIPER,
	MODE_WESKER,
	MODE_SIRIO,
	MODE_NINJA,
	MODE_MUTILADOR
}

enum _:menu_granadas 
{
    granada_nombre[90],
    cantidad_fire,
    cantidad_chain,
    cantidad_bubble,
    cantidad_pipe,
    cantidad_frost,
    cantidad_droga,
    granada_nivel
};
//flash = frost, smoke = campo
new const Granadas[][menu_granadas] = 
{ 
	{"Fire", 1, 0, 0, 0, 0, 0, 1 },//0
	{"Fire + Frost", 1, 0, 0, 0, 1, 0, 3 },//1
	{"Chain + Frost", 0, 1, 0, 0, 1, 0, 6},//2
	{"Chain + Fire", 1, 1, 0, 0, 0, 0, 15},//3
	{"2 Chain", 0, 2, 0, 0, 0, 0, 10},//4
	{"2 Chain + Frost", 0, 2, 0, 0, 1, 0, 11},//5
	{"Chain + Frost + Fire", 1, 1, 0, 0, 1, 0, 12},//6
	{"2 Chain + 2 Frost", 0, 2, 0, 0, 2, 0, 13},//7
	{"2 Chain + Droga", 0, 2, 0, 0, 0, 1, 14},//8
	{"Pipe + Droga", 0, 0, 0, 1, 0, 1, 15},//9
	{"2 Chain + Pipe", 0, 2, 0, 1, 0, 0, 16},//10
	{"Frost + Pipe + Buble", 0, 0, 1, 1, 1, 0, 20},//11
	{"2Frost + 2Pipe + 1Buble", 0, 0, 1, 2, 2, 0, 22}//12

};
new g_iGranada[33];
new g_iHat[33];

enum nvision{ nvisionName[50], nvisionColor[3] };
new const g_ColorNVsion[][nvision] = {
	{"Azul", {0, 0, 225}},
	{"Rojo", {225, 0, 0}},
	{"Verde", {0, 225, 0}},
	{ "Anaranjado", {255, 140, 0} },
    { "Blanco", {255, 255, 255} },
    { "Amarillo", {255, 255, 0} },
    { "Fucsia", {217, 0, 217} },
    { "Celeste",{ 0, 255, 255} }
};
new g_iNVsion[33];

enum hudd{ hudName[50], hudColor[3] };
new const g_ColorHud[][hudd] = {
	{"Blanco", {225, 225, 225}},
	{"Rojo", {225, 0, 0}},
	{"Verde", {0, 225, 0}},
	{"Azul", {0, 0, 225}},
	{ "Anaranjado", {255, 140, 0} },
    { "Blanco", {255, 255, 255} },
    { "Amarillo", {255, 255, 0} },
    { "Fucsia", {217, 0, 217} },
    { "Celeste",{ 0, 255, 255} }
};
new g_iHud[33];

new bool:g_bHappyTime, g_iHappyMulti;

enum _:__HappyData { HH_HOUR[3], HH_DAMAGE, HH_MULTI };
enum range{ range_name[80], range_level, url_range[120] };

new const rango[][range] = 
{
	{ "Unranked", 2, "https://i.ibb.co/HHzfg5T/0.png" },
	{ "Silver I", 3, "https://i.ibb.co/hDWSG8d/1.png" },
	{ "Silver II", 4, "https://i.ibb.co/dgSPLD9/2.png" },
	{ "Silver III", 5, "https://i.ibb.co/Bc6jsjM/3.png" },
	{ "Silver IV", 6, "https://i.ibb.co/3pnjRS7/4.png" },
	{ "Silver Elite", 8, "https://i.ibb.co/GpkgZq0/5.png" },
	{ "Silver Elite Master", 9, "https://i.ibb.co/b6F3PPF/6.png" },
	{ "Gold Nova I", 10, "https://i.ibb.co/JjB8JYH/7.png" },
	{ "Gold Nova II", 11, "https://i.ibb.co/kmrfpqH/8.png" },
	{ "Gold Nova III", 13, "https://i.ibb.co/HVzW4jF/9.png" },
	{ "Gold Nova Master", 14, "https://i.ibb.co/7XMCzyV/10.png" },
	{ "Master Guardian I", 15, "https://i.ibb.co/q7s3Syr/11.png" },
	{ "Master Guardian II", 16, "https://i.ibb.co/hWSbXfh/12.png" },
	{ "Master Guardian Elite", 17, "https://i.ibb.co/P9GNsTk/13.png" },
	{ "Distinguished Master Guardian", 18, "https://i.ibb.co/6Dr0D41/14.png" },
	{ "Legendary Eagle", 20, "https://i.ibb.co/qd5J8Rh/15.png" },
	{ "Legendary Eagle Master", 22, "https://i.ibb.co/fX5nPZx/16.png" },
	{ "Supreme Master First Class", 25, "https://i.ibb.co/xFgd2jg/17.png" },
	{ "The Global Elite", 0, "https://i.ibb.co/WVqzsg7/18.png" }
}
new g_iRango[33];

enum _:__TagData { SZTAG[32] , SZFLAG[22], mult_exp, multi_aps };
new const __Tags[][__TagData] =
{
	{ "[ OWNER ]" , "abcdefghijklmnopqrstu", 2, 4 },
    { "[ STAFF ]" , "abcdefijnopqrstu", 2, 4 },
    { "[ MODERADOR ]" , "acdefijnopqrstu", 2, 4 },
    { "[ GOLD ]" , "acdefijpqrstu", 2, 3 },
	{ "[ SILVER ]" , "cdefijnqrstu", 2, 2 },
	{ "[ BRONZE ]" , "cefijmqrstu", 2, 2 },
	{ "[VIP]",          "mnopr",                   2, 2}
}

new g_szTag[ 33 ][ 32 ];
new g_szFlags[ 33 ][ 32 ];
new g_iMultiplicador[ 33 ][ 2 ];

new const _HappyHour[][__HappyData] =
{
	{ "06",     1000,                 2 },
    { "07",     1000,                 2 },

    { "14",     1000,                 2 },
    { "15",     1000,                 2 },
    { "16",     1000,                 2 },

    { "19",     1400,                 2 },
    { "20",     1600,                 2 },

    { "22",     1400,                 2 },
    { "23",     1600,                 2 }
}

new const RequiredExp[MAX_LEVEL]=
{
	200,//2
	400,//3
	600,//4
	900,//5
	1250,//6
	1650,//7
	2050,//8
	2450,//9
	2900,//10
	3400,//11
	3925,//12
	4525,//13
	5325,//14
	6375,//15
	7475,//16
	9475,//17
	11975,//18
	14975,//19
	18475,//20
 	21975,//21
	24975,//22
	26975,//23
	29475,//24
	33475,//25
	35000,//26
	38200,//27
	41000,//28
	44000,//29
	49300,//30
	55000 //31
}
new g_iDamage[33], g_iExp[33], g_iLevel[33], g_iReset[33];
new cvar_exp, g_iDefaultDamage; 
new g_temExp[ 33 ], g_tempDamage[ 33 ], g_tempApps[33];

// ZP Teams
const ZP_TEAM_NO_ONE = 0
const ZP_TEAM_ANY = 0
const ZP_TEAM_ZOMBIE = (1<<0)
const ZP_TEAM_HUMAN = (1<<1)
const ZP_TEAM_NEMESIS = (1<<2)
const ZP_TEAM_SURVIVOR = (1<<3)

// Zombie classes
const ZCLASS_NONE = -1

// HUD messages
const Float:HUD_EVENT_X = -1.0
const Float:HUD_EVENT_Y = 0.17
const Float:HUD_INFECT_X = 0.05
const Float:HUD_INFECT_Y = 0.45
const Float:HUD_SPECT_X = 0.6
const Float:HUD_SPECT_Y = 0.8
const Float:HUD_STATS_X = 0.02
const Float:HUD_STATS_Y = 0.02

const TASK_SPEED_BOOST = 100
#define ID_SPEED_BOOST (taskid - TASK_SPEED_BOOST)

// Hack to be able to use Ham_Player_ResetMaxSpeed (by joaquimandrade)
new Ham:Ham_Player_ResetMaxSpeed = Ham_Item_PreFrame

// CS Player PData Offsets (win32)
const OFFSET_PAINSHOCK = 108 // ConnorMcLeod
const OFFSET_CSTEAMS = 114
const OFFSET_CSMONEY = 115
const OFFSET_FLASHLIGHT_BATTERY = 244
const OFFSET_CSDEATHS = 444

// CS Player CBase Offsets (win32)
const OFFSET_ACTIVE_ITEM = 373

// CS Weapon CBase Offsets (win32)
const OFFSET_WEAPONOWNER = 41

// Linux diff's
const OFFSET_LINUX = 5 // offsets 5 higher in Linux builds
const OFFSET_LINUX_WEAPONS = 4 // weapon offsets are only 4 steps higher on Linux

// CS Teams
enum
{
	FM_CS_TEAM_UNASSIGNED = 0,
	FM_CS_TEAM_T,
	FM_CS_TEAM_CT,
	FM_CS_TEAM_SPECTATOR
}
new const CS_TEAM_NAMES[][] = { "UNASSIGNED", "TERRORIST", "CT", "SPECTATOR" }

// Some constants
const HIDE_MONEY = (1<<5)
const HIDE_RHA = (1<<3)
const UNIT_SECOND = (1<<12)
const DMG_HEGRENADE = (1<<24)
const IMPULSE_FLASHLIGHT = 100
const USE_USING = 2
const USE_STOPPED = 0
const STEPTIME_SILENT = 999
const BREAK_GLASS = 0x01
const FFADE_IN = 0x0000
const FFADE_STAYOUT = 0x0004
const PEV_SPEC_TARGET = pev_iuser2

new const Float:g_iMaxClip[ CSW_P90 + 1 ] = {
	0.0, 13.0, 0.0, 10.0, 1.0,  7.0, 1.0, 30.0, 30.0, 1.0, 30.0, 
	20.0, 25.0, 30.0, 35.0, 25.0, 12.0, 20.0, 10.0, 30.0, 100.0, 
	8.0, 30.0, 30.0, 20.0, 2.0, 7.0, 30.0, 30.0, 0.0, 50.0 };

const m_iTeam            = 114;
const m_pPlayer          = 41;
const m_fInReload        = 54;
const m_fInSpecialReload = 55;
const m_flTimeWeaponIdle = 48;

// Max BP ammo for weapons
new const MAXBPAMMO[] = { -1, 52, -1, 90, 1, 32, 1, 100, 90, 1, 120, 100, 100, 90, 90, 90, 100, 120,
			30, 120, 200, 32, 90, 120, 90, 2, 35, 90, 90, -1, 100 }

// Max Clip for weapons
new const MAXCLIP[] = { -1, 13, -1, 10, -1, 7, -1, 30, 30, -1, 30, 20, 25, 30, 35, 25, 12, 20,
			10, 30, 100, 8, 30, 30, 20, -1, 7, 30, 30, -1, 50 }

// Amount of ammo to give when buying additional clips for weapons
new const BUYAMMO[] = { -1, 13, -1, 30, -1, 8, -1, 12, 30, -1, 30, 50, 12, 30, 30, 30, 12, 30,
			10, 30, 30, 8, 30, 30, 30, -1, 7, 30, 30, -1, 50 }

// Ammo IDs for weapons
new const AMMOID[] = { -1, 9, -1, 2, 12, 5, 14, 6, 4, 13, 10, 7, 6, 4, 4, 4, 6, 10,
			1, 10, 3, 5, 4, 10, 2, 11, 8, 4, 2, -1, 7 }

// Ammo Type Names for weapons
new const AMMOTYPE[][] = { "", "357sig", "", "762nato", "", "buckshot", "", "45acp", "556nato", "", "9mm", "57mm", "45acp",
			"556nato", "556nato", "556nato", "45acp", "9mm", "338magnum", "9mm", "556natobox", "buckshot",
			"556nato", "9mm", "762nato", "", "50ae", "556nato", "762nato", "", "57mm" }

// Weapon IDs for ammo types
new const AMMOWEAPON[] = { 0, CSW_AWP, CSW_SCOUT, CSW_M249, CSW_AUG, CSW_XM1014, CSW_MAC10, CSW_FIVESEVEN, CSW_DEAGLE,
			CSW_P228, CSW_ELITE, CSW_FLASHBANG, CSW_HEGRENADE, CSW_SMOKEGRENADE, CSW_C4 }

// Weapon entity names
new const WEAPONENTNAMES[][] = { "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
			"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
			"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
			"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
			"weapon_ak47", "weapon_knife", "weapon_p90" }

//record ent
new const g_szEnt[] = "ZonaSegura";
new const MODEL_meta[] = "models/zombie_plague/modelo_boton.mdl";
// CS sounds
new const sound_flashlight[] = "items/flashlight1.wav"
new const sound_buyammo[] = "items/9mmclip1.wav"
new const sound_armorhit[] = "player/bhit_helmet-1.wav"

// Explosion radius for custom grenades
const Float:NADE_EXPLOSION_RADIUS = 240.0

// HACK: pev_ field used to store additional ammo on weapons
const PEV_ADDITIONAL_AMMO = pev_iuser1

// HACK: pev_ field used to store custom nade types and their values
const PEV_NADE_TYPE = pev_flTimeStepSound
const NADE_TYPE_INFECTION = 1111;
const NADE_TYPE_NAPALM = 2222;
const NADE_TYPE_FROST = 3333;
const NADE_TYPE_CAMPO = 4444;
const NADE_TYPE_PIPEBOMB = 5555;
const NADE_TYPE_HE = 6666;
const NADE_TYPE_DROGA = 7777;
const NADE_TYPE_JUMPING = 8888;

const PEV_FLARE_COLOR = pev_punchangle
const PEV_FLARE_DURATION = pev_flSwimTime

// Weapon bitsums
const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)

// Allowed weapons for zombies (added grenades/bomb for sub-plugin support, since they shouldn't be getting them anyway)
const ZOMBIE_ALLOWED_WEAPONS_BITSUM = (1<<CSW_KNIFE)|(1<<CSW_HEGRENADE)|(1<<CSW_FLASHBANG)|(1<<CSW_SMOKEGRENADE)|(1<<CSW_C4)

// Menu keys
const KEYSMENU = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0

// Ambience Sounds
enum
{
	AMBIENCE_SOUNDS_INFECTION = 0,
	AMBIENCE_SOUNDS_NEMESIS,
	AMBIENCE_SOUNDS_SURVIVOR,
	AMBIENCE_SOUNDS_SWARM,
	AMBIENCE_SOUNDS_PLAGUE,
	MAX_AMBIENCE_SOUNDS
}

// Admin menu actions
enum
{
	ACTION_ZOMBIEFY_HUMANIZE = 0,
	ACTION_MAKE_NEMESIS,
	ACTION_MAKE_ALIEN,

	ACTION_MAKE_SURVIVOR,
	ACTION_MAKE_SNIPER,
	ACTION_MAKE_WESKER,
	ACTION_MAKE_SIRIO,
	ACTION_MAKE_NINJA,

	ACTION_RESPAWN_PLAYER,
	ACTION_MODE_SWARM,
	ACTION_MODE_MULTI,
	ACTION_MODE_PLAGUE
}

// Custom forward return values
const ZP_PLUGIN_HANDLED = 97

#if AMXX_VERSION_NUM > 182
#define client_disconnect client_disconnected
#else
#include <dhudmessage>
#endif
new const g_szPrefix[] = "[ZE]";

enum
{
	CREAR_META = 0,
	BUSCAR_META,
	BEST_RECORD
}


/*================================================================================
 [Recursos]
=================================================================================*/

new const szSurvivor[] = "new_survi";
new const szM4CHINE[] = "models/zombie_plague/machine_cso.mdl";
new const szSniper[] = "zbheroex_hero";
new const soundSniper[] = "sound/zombie_plague/the-sword-of-promised-victory-fate-zero-ver.mp3"
new const szWesker[] = "zbheroex_heroine";
new const soundWesker[] = "sound/zombie_plague/the-battle-is-to-the-strong.mp3"
new const szHuman[] = "yuri2";
new const szNemesis[] = "Old_Nemesis";
new const szSirio[] = "aris_hasam_sirio";
new const soundSirio[] = "sound/zombie_plague/pain-theme.mp3";
new const ModelNinja[] = "cso_ninja";
new const KnifeNinja[] = "models/zombie_plague/v_ninja_knife.mdl";
new const ModelAlien[] = "ze_alien";
new const KnifeAlien[] = "models/zombie_plague/avh_alienclaws.mdl"; 
new const SoundAlien[] = "sound/zombie_plague/the-sword-of-promised-victory-fate-zero-ver.mp3";
new const ModelAlien2[] = "ze_alien_mini";

new const soundMutilador[] = { "zombie_plague/survivor1.wav" } 

new const V_KNIFE_NEMESIS[] = "models/zombie_plague/zp_v_knife_nemesis.mdl";
new const GRENADE_INFECT[] = "models/zombie_plague/v_grenade_infect.mdl";
new const GRENADE_FIRE[] = "models/zombie_plague/v_cso_fire.mdl";
new const GRENADE_FROST[] = "models/zombie_plague/v_buz.mdl";
new const g_szJump_v [ ] = "models/cz/v_zombibomb.mdl";
new const g_szJump_p [ ] = "models/cz/p_zombibomb.mdl";
new const g_SoundBombExplode [ ] [ ] = { "nst_zombie/zombi_bomb_exp.wav" };
new const frogbomb_sound [ ] = { "nst_zombie/zombi_bomb_deploy.wav" };
new const frogbomb_sound_idle [ ] = { "nst_zombie/zombi_bomb_idle_4.wav" };
//new const GRENADE_FLARE[] = "models/zombie_plague/v_grenade_flare.mdl";

new const szFireHole[] = "zombie_plague/radio/ct_fireinhole.wav";

new const g_sound[] = "items/pipe_beep.wav"; 
new const g_vmodel[] = "models/zombie_plague/v_pipe.mdl"; 
new const g_pmodel[] = "models/zombie_plague/p_pipe.mdl"; 
new const g_vChain[] = "models/zombie_plague/v_chaingren.mdl"

new const grenade_droga[] = "models/zombie_plague/v_grenade_droga.mdl";
new const sound_drogado[] = { "x/x_die1.wav" };

new const model_grenade[] = "models/zombie_plague/v_cso_bubble.mdl";
new const model[] = "models/zombie_plague/aura8.mdl";
new const entclas[] = "campo_grenade_forze";

/*================================================================================
 [Global Variables]
=================================================================================*/
enum
{
	HUMAN = 0,
	LAST_HUMAN,
	SURVIVOR,
	SNIPER,
	WESKER,
	SIRIO,
	NINJA,
	//mas mods
	ZOMBIE,
	FIRST_ZOMBIE,
	LAST_ZOMBIE,
	NEMESIS,
	ALIEN,
	BOSS
	//mas mods
}
// Player vars
new g_class[33] //CLASS
new jumpnum[33];
new bool:dojump[33];
new g_iJumpClass[33], g_iJumpClass2[33];
new g_iNoJump[33]
new g_iNoDroga[33];
new g_iJumpingNadeCount[ 33 ]
new g_iExplote[33], g_iFisher[33], g_iGhost[33];
new g_steamBonus[33]
new g_bBalas[33], g_iSkinsEnable[33];
new g_bMask[33];
new g_iEscapes[ 33 ];
new cvar_boost_amount
new cvar_boost_duration
new g_has_speed_boost[33]
new g_iNoPipe[33], g_iNoFrost[33], g_iNoFire[33];
new g_szNameRecord[33], Float:g_fTimeRecord;
new g_fOrigin[ 33 ][ 3 ], g_iCanKill[ 33 ];
new cvar_radius, cvar_damage 
new g_fire, g_iPipe[33], g_iHe[33], g_iDroga[33];
new g_frozen[33] // is frozen (can't move)
new Float:g_frozen_gravity[33] // store previous gravity when frozen
new g_nodamage[33] // has spawn protection/zombie madness
new g_respawn_as_zombie[33] // should respawn as zombie
new g_nvision[33] // has night vision
new g_nvisionenabled[33] // has night vision turned on
new g_zombieclass[33], g_humanclass[33] // zombie class
new g_zombieclassnext[33], g_humanclassnext[33] // zombie class for next infection
new g_ammopacks[33] // ammo pack count
new g_damagedealt[33] // damage dealt to zombies (used to calculate ammo packs reward)
new Float:g_lastleaptime[33] // time leap was last used
new g_playermodel[33][32] // current model's short name [player][model]
new g_menu_data[33][5] // data for some menu handlers
new g_burning_duration[33] // burning task duration
new g_iBalasEspeciales[33];
new Float:g_fRecord[33], g_touched[33], Float:g_fTiempo[33], Float:g_currencyTime[33];
new g_iMsgTextMsg, g_iMsgSendAudio;
//armas
new Array:g_aArray;
//new Array:g_szName, Array:g_aLevel, Array:g_aReset, Array:g_iCat, Array:g_iTipo, Array:g_szTipo;
new fw_Item_Selected, gTotalItems;
new g_Prim, g_Sec, g_Knife;

enum{ PRIMARIA=1, SECUNDARIA, KNIFE, MAX_ARMS };

enum 
{ 
	CLASS_ZOMBIE = 0, 
	CLASS_HUMAN 
};

/*
	mejoras
*/

new g_habilidad[33][CLASS_HUMAN+1][6] // Variable de Habilidad
new g_puntos[33][CLASS_HUMAN+1] // puntos de zombie y humano
new g_gastados[33][CLASS_HUMAN+1] // Gastados de human y zm

enum habilities {
	hability_name[40],
	hability_max
}

new const habilityZombie[][habilities] = {
	{"Daño", 10},
	{"Vida", 10},
	{"Velocidad", 10},
	{"Gravedad", 14}
}

new const habilityHuman[][habilities] = {
	{"Daño", 10}, 
	{"Vida", 10},
	{"Armor", 10},
	{"Velocidad", 10},
	{"Gravedad", 10}
}

new g_iSelected[33][MAX_ARMS];
new g_iCategoria[33];
new bool:g_bAutoSeleccion[33], bool: g_bAnterior[33];

// Game vars
new g_pPercent;
new cvar_timedroga, cvar_timeCampo, cvar_radiodroga, cvar_damageHE;
new Regex:xResult, xReturnValue, xError[64];
new g_pluginenabled

new cvar_jump_radius, g_iExplo, cvar_speed;
new g_newround // new round starting
new g_endround // round ended
new g_modestarted // mode fully started
new g_currentmode // current playing mode
new g_lastmode; // last played mode
new cvar_event;
new g_scorezombies, g_scorehumans // team scores
new g_spawnCount, g_spawnCount2 // available spawn points counter
new Float:g_spawns[MAX_CSDM_SPAWNS][3], Float:g_spawns2[MAX_CSDM_SPAWNS][3] // spawn points data
new Float:g_teams_targettime // for adding delays between Team Change messages
new g_MsgSync, g_MsgSync2 // message sync objects
new g_trailSpr, g_exploSpr, g_flameSpr, g_smokeSpr, g_glassSpr, m_spriteTexture // grenade sprites
new g_modname[32] // for formatting the mod name
new g_freezetime // whether CS's freeze time is on
new g_maxplayers // max players counter
new g_hamczbots // whether ham forwards are registered for CZ bots
new g_fwSpawn, g_fwPrecacheSound // spawn and precache sound forward handles
new g_infbombcounter, g_antidotecounter, g_madnesscounter // to limit buying some items
new g_iBalas, g_boost, cvar_balaslimit, cvar_boost_speed;
new g_arrays_created // to prevent stuff from being registered before initializing arrays
new g_lastplayerleaving // flag for whenever a player leaves and another takes his place
new g_switchingteam // flag for whenever a player's team change emessage is sent
new g_frostexp, g_frost_gibs;
new g_fireexp, g_fire_gibs;
new cvar_survidamage;

new cvar_mutilador, cvar_mutiladorchance, cvar_mutiladorminplayer, cvar_mutiladorratio, cvar_mutiladorhpsurvi, cvar_mutiladorhpneme;

new cvar_modes;

//ninja
new cvar_ninja, 
cvar_ninjachance, 
cvar_ninjaminplayer,
cvar_ninjahp,
cvar_ninjaspd,
cvar_ninjagvt, 
cvar_ninjadamage, 
cvar_ninjapainfree; 

//alien
new cvar_alien, 
cvar_alienchance, 
cvar_alienminplayer,
cvar_alienhp,
cvar_alienspd,
cvar_aliengvt,
cvar_alienpainfree;

//sniper mod
new cvar_sniper,
cvar_sniperchance,
cvar_sniperminplayer,
cvar_sniperhp,
cvar_sniperspd, 
cvar_snipergvt, 
cvar_sniperdamage, 
cvar_sniperpainfree; 

//sirio
new cvar_sirio, 
cvar_siriochance,
cvar_siriominplayer,
cvar_siriohp, 
cvar_siriospd, 
cvar_siriogvt, 
cvar_siriopainfree;

//wesker mod
new cvar_wesker, 
cvar_weskerchance,
cvar_weskerminplayer,
cvar_weskerhp, 
cvar_weskerspd, 
cvar_weskergvt, 
cvar_weskerdamage, 
cvar_weskerpainfree;

// Message IDs vars
new g_msgScoreInfo, g_msgNVGToggle, g_msgScoreAttrib, g_msgAmmoPickup, g_msgScreenFade,
g_msgDeathMsg, g_msgSetFOV, g_msgTeamInfo, g_msgDamage,
g_msgHideWeapon, g_msgCrosshair, g_msgSayText, g_msgScreenShake, g_msgCurWeapon

// Some forward handlers
new g_fwRoundStart, g_fwRoundEnd, g_fwUserInfected_pre, g_fwUserInfected_post,
g_fwUserHumanized_pre, g_fwUserHumanized_post, g_fwUserInfect_attempt,
g_fwUserHumanize_attempt, g_fwExtraItemSelected, g_fwUserUnfrozen,
g_fwUserLastZombie, g_fwUserLastHuman, g_fwDummyResult

// Extra Items vars
new Array:g_extraitem_name // caption
new Array:g_extraitem_cost // cost
new Array: g_extraitem_level; // level
new Array:g_extraitem_team // team
new g_extraitem_i // loaded extra items counter

// Zombie Classes vars
new Array:g_zclass_name // caption
new Array:g_zclass_info // description
new Array: g_zclass_level;
new Array: g_zclass_reset;
new Array: g_zclass_admin;
new Array: g_zclass_type;
new Array: g_zclass_model;
new Array: g_zclass_knife;
new Array:g_zclass_hp // health
new Array:g_zclass_chaleco; // health
new Array:g_zclass_spd // speed
new Array:g_zclass_grav // gravity
new Array:g_zclass_kb // knockback
new g_zclass_i // loaded zombie classes counter

// Customization vars
new sprite_grenade_trail[64], sprite_grenade_ring[64], sprite_grenade_fire[64],
sprite_grenade_smoke[64], sprite_grenade_glass[64], Array:sound_win_zombies,
Array:sound_win_humans, Array:sound_win_no_one, Array:zombie_infect, Array:zombie_idle,
Array:zombie_pain, Array:nemesis_pain, Array:zombie_die, Array:zombie_fall,
Array:zombie_miss_wall, Array:zombie_hit_normal, Array:zombie_hit_stab, g_ambience_rain,
Array:zombie_idle_last, Array:zombie_madness, Array:sound_nemesis, Array:sound_survivor,
Array:sound_swarm, Array:sound_multi, Array:sound_plague, Array:grenade_infect,
Array:grenade_infect_player, Array:grenade_fire, Array:grenade_fire_player,
Array:grenade_frost, Array:grenade_frost_player, Array:grenade_frost_break,
Array:sound_antidote, Array:sound_thunder, g_ambience_sounds[MAX_AMBIENCE_SOUNDS],
Array:sound_ambience1, Array:sound_ambience2, Array:sound_ambience3, Array:sound_ambience4,
Array:sound_ambience5, Array:sound_ambience1_duration, Array:sound_ambience2_duration,
Array:sound_ambience3_duration, Array:sound_ambience4_duration,
Array:sound_ambience5_duration, Array:sound_ambience1_ismp3, Array:sound_ambience2_ismp3,
Array:sound_ambience3_ismp3, Array:sound_ambience4_ismp3, Array:sound_ambience5_ismp3,
Array:g_extraweapon_names,
Array:g_extraweapon_items, Array:g_extraweapon_costs, g_extra_costs2[EXTRA_WEAPONS_STARTID],
g_ambience_snow, g_ambience_fog, g_fog_density[10], g_fog_color[12], g_sky_enable,
Array:g_sky_names, Array:lights_thunder, Array:g_objective_ents,
Float:kb_weapon_power[31] = { -1.0, ... }, Array:zombie_miss_slash

// CVAR pointers
new cvar_lighting, cvar_zombiefov, cvar_plague, cvar_plaguechance, cvar_zombiefirsthp,
cvar_removemoney, cvar_zombiebonushp, cvar_nemhp, cvar_nem, cvar_surv,
cvar_nemchance, cvar_deathmatch, cvar_customnvg, cvar_hitzones, cvar_humanhp,
cvar_nemgravity, cvar_ammodamage, cvar_zombiearmor, cvar_survpainfree,
cvar_nempainfree, cvar_nemspd, cvar_survchance, cvar_survhp, cvar_survspd, cvar_humanspd,
cvar_swarmchance, cvar_removedoors,
cvar_randspawn, cvar_multi, cvar_multichance, cvar_swarm, cvar_ammoinfect,
cvar_toggle, cvar_knockbackpower, cvar_freezeduration, cvar_triggered,
cvar_survgravity,
cvar_humangravity, cvar_spawnprotection, cvar_zclasses,
cvar_extraitems, cvar_humanlasthp, cvar_warmup, cvar_fireduration, cvar_firedamage,
cvar_knockbackducking, cvar_knockbackdamage, cvar_knockbackzvel,
cvar_multiratio, cvar_spawndelay, cvar_extraantidote, cvar_extramadness,
cvar_extraweapons, cvar_extranvision, cvar_nvggive, cvar_preventconsecutive, cvar_botquota,
cvar_buycustom, cvar_zombiepainfree, cvar_fireslowdown, cvar_survbasehp,
cvar_knockback,
cvar_fragsinfect, cvar_fragskill, cvar_humanarmor, cvar_zombiesilent, cvar_removedropped,
cvar_plagueratio, cvar_blocksuicide, cvar_knockbackdist, cvar_nemdamage, cvar_leapzombies,
cvar_leapzombiesforce, cvar_leapzombiesheight, cvar_leapzombiescooldown, cvar_leapnemesis,
cvar_leapnemesisforce, cvar_leapnemesisheight, cvar_leapnemesiscooldown, cvar_leapsurvivor,
cvar_leapsurvivorforce, cvar_leapsurvivorheight, cvar_nemminplayers, cvar_survminplayers,
cvar_respawnafterlast, cvar_leapsurvivorcooldown,
cvar_swarmminplayers, cvar_multiminplayers, cvar_plagueminplayers,
cvar_nembasehp, cvar_blockpushables, cvar_respawnworldspawnkill,
cvar_madnessduration, cvar_plaguenemnum, cvar_plaguenemhpmulti, cvar_plaguesurvhpmulti,
cvar_survweapon, cvar_plaguesurvnum, cvar_infectionscreenfade, cvar_infectionscreenshake,
cvar_infectionsparkle, cvar_infectiontracers, cvar_infectionparticles, cvar_infbomblimit,
cvar_nemknockback,
cvar_hudicons,
cvar_startammopacks, cvar_antidotelimit, cvar_madnesslimit,
cvar_keephealthondisconnect;

// Cached stuff for players
new g_isconnected[33] // whether player is connected
new g_isalive[33] // whether player is alive
new g_isbot[33] // whether player is a bot
new g_currentweapon[33] // player's current weapon id
new g_playername[33][32] // player's name
new Float:g_zombie_spd[33], Float:g_human_spd[33] // zombie class speed
new Float:g_zombie_knockback[33] // zombie class knockback
new g_zombie_classname[33][32], g_human_classname[33][32] // zombie class name
#define is_user_valid_connected(%1) (1 <= %1 <= g_maxplayers && g_isconnected[%1])
#define is_user_valid_alive(%1) (1 <= %1 <= g_maxplayers && g_isalive[%1])

#define ammount_cost(%1)        (%1 * 3) + 1 
#define ammount_hdamage(%1)         (%1 + 1) * 0.1 
#define ammount_hspeed(%1)         (%1 * 15) 
#define ammount_hhealth(%1)         (%1 * 10)
#define ammount_harmor(%1)         (%1 * 5)
#define ammount_hgravity(%1)     ((%1 * 0.01) * 3)
#define ammount_zdamage(%1)         (%1 + 3) * 0.3
#define ammount_zspeed(%1)         (%1 * 15)
#define ammount_zhealth(%1)         (%1 * 2000) 
#define ammount_zgravity(%1)     ((%1 * 0.01) * 3)

// Cached CVARs
new g_cached_zombiesilent, Float:g_cached_humanspd, Float:g_cached_nemspd,
Float:g_cached_survspd, g_cached_leapzombies, Float:g_cached_leapzombiescooldown, g_cached_leapnemesis,
Float:g_cached_leapnemesiscooldown, g_cached_leapsurvivor, Float:g_cached_leapsurvivorcooldown

new const szTable[] = "zp_datos";
new const g_szTableRecord[] = "zp_record";
new const g_szTableMaps[] = "zp_mapas";
new const szTableCodes[] = "amx_codigos";
new const iWeb[] = "fb.com/groups/625860961367978/";

new g_id[ 33 ];
new Handle:g_hTuple;
new g_bModEscape;
enum
{
	REGISTRAR_USUARIO,
	LOGUEAR_USUARIO,
	GUARDAR_DATOS,
	SQL_RANK,
	INSERTAR_RECORD,
	CARGAR_RECORD,
	ACTIVAR_CODE
};

new g_iStatus[33];
enum
{
	NO_LOGUEADO = 0,
	LOGUEADO
}


enum _:e_WeaponsInfo
{
    Weapon_Name[ 52 ],
    Weapon_AdminType[40],
    Weapon_Level,
    Weapon_Reset,
    Weapon_Category,
    Weapon_Admin,
    Weapon_Pos
}
new weaponOrder[ e_WeaponsInfo ];

/*================================================================================
 [Natives, Precache and Init]
=================================================================================*/

public advacc_guardado_login_success( id )
{
	if( is_user_connected( id ) )
	{
		new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];

		g_id[ id ] = advacc_guardado_id( id );

		iData[ 0 ] = id;
		iData[ 1 ] = LOGUEAR_USUARIO;

		formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE id_cuenta='%d'", szTable, g_id[ id ] );
		SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );


		/*if( is_user_admin(id) ) {
			get_roleUser(id, g_szTag[id], charsmax(g_szTag[]));
			get_flagsUser(id, g_szFlags[id], charsmax(g_szFlags[]));

			for(new i=0; i < sizeof(__Tags); i++)
			{
				if(equali(g_szFlags[id], __Tags[i][SZFLAG]))
				{
					g_iMultiplicador[id][ 0 ] = __Tags[i][mult_exp];
					g_iMultiplicador[id][ 1 ] = __Tags[i][multi_aps];
					break;
				}
			}
		}	*/
	}
}

public plugin_natives()
{
	register_native("zp_weapons_force_buy", "force_give_weapon", 0);
	register_native("zp_arma", "register_arma", 0);
	register_native("enable_skins", "handler_skins_enable", 1);
	register_native("zp_set_no_jump", "handler_set_nojump", 1);
	register_native("zp_get_no_jump", "handler_get_nojump", 1);
	register_native("zp_triple_salto", "handler_jump", 1);
	register_native("zp_doble_salto", "handler_jump2", 1);
	register_native("zp_set_boost", "handler_boost", 1)
	register_native("zp_no_droga", "handler_no_droga", 1);
	register_native("zp_get_user_inparty", "is_user_inparty");
	register_native("zp_set_unfrozen", "set_unfrozen", 1);
	register_native("zp_set_chain", "handler_chain", 1);
	register_native("zp_set_nofire", "set_nofire", 1);
	register_native("zp_set_nopipe", "set_nopipe", 1);
	register_native("zp_set_fisher", "handler_fisher", 1);
	register_native("zp_set_ghost", "handler_ghost", 1);
	// Player specific natives
	register_native("zp_get_user_zombie", "native_get_user_zombie", 1)
	register_native("zp_get_user_nemesis", "native_get_user_nemesis", 1)
	register_native("zp_get_user_survivor", "native_get_user_survivor", 1)
	register_native("zp_get_class", "native_get_user_class", 1);
	register_native("zp_get_user_sniper", "native_get_user_sniper", 1);
	register_native("zp_get_round_sniper", "native_get_round_sniper", 1); 
	register_native("zp_get_user_wesker", "native_get_user_wesker", 1);
	register_native("zp_get_round_wesker", "native_get_round_wesker", 1);

	register_native("zp_get_user_first_zombie", "native_get_user_first_zombie", 1)
	register_native("zp_get_user_last_zombie", "native_get_user_last_zombie", 1)
	register_native("zp_get_user_last_human", "native_get_user_last_human", 1)
	register_native("zp_get_user_zombie_class", "native_get_user_zombie_class", 1)
	register_native("zp_get_user_human_class", "native_get_user_human_class", 1)
	register_native("zp_get_user_next_class", "native_get_user_next_class", 1)
	register_native("zp_set_user_zombie_class", "native_set_user_zombie_class", 1)
	register_native("zp_get_user_ammo_packs", "native_get_user_ammo_packs", 1)
	register_native("zp_set_user_ammo_packs", "native_set_user_ammo_packs", 1)
	register_native("zp_get_zombie_maxhealth", "native_get_zombie_maxhealth", 1)
	register_native("zp_get_user_nightvision", "native_get_user_nightvision", 1)
	register_native("zp_set_user_nightvision", "native_set_user_nightvision", 1)
	register_native("zp_infect_user", "native_infect_user", 1)
	register_native("zp_disinfect_user", "native_disinfect_user", 1)
	register_native("zp_make_user_nemesis", "native_make_user_nemesis", 1)
	register_native("zp_make_user_zombie", "native_make_user_zombie", 1)
	register_native("zp_make_user_survivor", "native_make_user_survivor", 1)
	register_native("zp_respawn_user", "native_respawn_user", 1)
	register_native("zp_force_buy_extra_item", "native_force_buy_extra_item", 1)
	
	// Round natives
	register_native("zp_has_round_started", "native_has_round_started", 1)
	register_native("zp_is_nemesis_round", "native_is_nemesis_round", 1)
	register_native("zp_is_survivor_round", "native_is_survivor_round", 1)
	register_native("zp_is_swarm_round", "native_is_swarm_round", 1)
	register_native("zp_is_plague_round", "native_is_plague_round", 1)
	register_native("zp_get_zombie_count", "native_get_zombie_count", 1)
	register_native("zp_get_human_count", "native_get_human_count", 1)
	register_native("zp_get_nemesis_count", "native_get_nemesis_count", 1)
	register_native("zp_get_survivor_count", "native_get_survivor_count", 1)
	
	// External additions natives
	register_native("zp_register_extra_item", "native_register_extra_item", 1)
	register_native("zp_register_class", "native_register_zombie_class", 1)
	register_native("zp_get_extra_item_id", "native_get_extra_item_id", 1)
	register_native("zp_get_zombie_class_id", "native_get_zombie_class_id", 1)

	register_native("zp_damage_req", "native_damage", 1);
	register_native("zp_set_exp", "native_exp", 1);
	register_native("zp_get_damage", "native_getdamage", 1);
}

public native_getdamage(id) {
	return g_iDamage[id];
}

public native_exp(id, value)
{
	SetExp(id, value);
	return value;
}

public native_damage()
	return g_iDefaultDamage;

public plugin_modules() require_module("engine")

public is_user_inparty(const id) return g_PartyData[id][In_Party] ? 1 : 0;

public plugin_precache()
{
	// Register earlier to show up in plugins list properly after plugin disable/error at loading
	register_plugin("Zombie Escape Evolution", PLUGIN_VERSION, "MeRcyLeZZ & Hypnotize")
	
	// To switch plugin on/off
	register_concmd("zp_toggle", "cmd_toggle", _, "<1/0> - Enable/Disable Zombie Plague (will restart the current map)", 0)
	cvar_toggle = register_cvar("zp_on", "1")
	
	// Plugin disabled?
	if (!get_pcvar_num(cvar_toggle)) return;
	g_pluginenabled = true

	// Initialize a few dynamically sized arrays (alright, maybe more than just a few...)
	sound_win_zombies = ArrayCreate(64, 1)
	sound_win_humans = ArrayCreate(64, 1)
	sound_win_no_one = ArrayCreate(64, 1)
	zombie_infect = ArrayCreate(64, 1)
	zombie_pain = ArrayCreate(64, 1)
	nemesis_pain = ArrayCreate(64, 1)
	zombie_die = ArrayCreate(64, 1)
	zombie_fall = ArrayCreate(64, 1)
	zombie_miss_slash = ArrayCreate(64, 1)
	zombie_miss_wall = ArrayCreate(64, 1)
	zombie_hit_normal = ArrayCreate(64, 1)
	zombie_hit_stab = ArrayCreate(64, 1)
	zombie_idle = ArrayCreate(64, 1)
	zombie_idle_last = ArrayCreate(64, 1)
	zombie_madness = ArrayCreate(64, 1)
	sound_nemesis = ArrayCreate(64, 1)
	sound_survivor = ArrayCreate(64, 1)
	sound_swarm = ArrayCreate(64, 1)
	sound_multi = ArrayCreate(64, 1)
	sound_plague = ArrayCreate(64, 1)
	grenade_infect = ArrayCreate(64, 1)
	grenade_infect_player = ArrayCreate(64, 1)
	grenade_fire = ArrayCreate(64, 1)
	grenade_fire_player = ArrayCreate(64, 1)
	grenade_frost = ArrayCreate(64, 1)
	grenade_frost_player = ArrayCreate(64, 1)
	grenade_frost_break = ArrayCreate(64, 1)
	sound_antidote = ArrayCreate(64, 1)
	sound_thunder = ArrayCreate(64, 1)
	sound_ambience1 = ArrayCreate(64, 1)
	sound_ambience2 = ArrayCreate(64, 1)
	sound_ambience3 = ArrayCreate(64, 1)
	sound_ambience4 = ArrayCreate(64, 1)
	sound_ambience5 = ArrayCreate(64, 1)
	sound_ambience1_duration = ArrayCreate(1, 1)
	sound_ambience2_duration = ArrayCreate(1, 1)
	sound_ambience3_duration = ArrayCreate(1, 1)
	sound_ambience4_duration = ArrayCreate(1, 1)
	sound_ambience5_duration = ArrayCreate(1, 1)
	sound_ambience1_ismp3 = ArrayCreate(1, 1)
	sound_ambience2_ismp3 = ArrayCreate(1, 1)
	sound_ambience3_ismp3 = ArrayCreate(1, 1)
	sound_ambience4_ismp3 = ArrayCreate(1, 1)
	sound_ambience5_ismp3 = ArrayCreate(1, 1)
	g_extraweapon_names = ArrayCreate(32, 1)
	g_extraweapon_items = ArrayCreate(32, 1)
	g_extraweapon_costs = ArrayCreate(1, 1)
	g_sky_names = ArrayCreate(32, 1)
	lights_thunder = ArrayCreate(32, 1)
	g_objective_ents = ArrayCreate(32, 1)
	g_extraitem_name = ArrayCreate(32, 1)
	g_extraitem_cost = ArrayCreate(1, 1)
	g_extraitem_level = ArrayCreate(1, 1)
	g_extraitem_team = ArrayCreate(1, 1)
	g_zclass_name = ArrayCreate(32, 1)
	g_zclass_info = ArrayCreate(32, 1)
	
	g_zclass_hp = ArrayCreate(1, 1)
	g_zclass_chaleco = ArrayCreate(1, 1);
	g_zclass_level = ArrayCreate(1, 1)
	g_zclass_reset = ArrayCreate(1, 1);
	g_zclass_admin = ArrayCreate(1, 1);
	g_zclass_type = ArrayCreate(1, 1)
	g_zclass_model = ArrayCreate(32, 1)
	g_zclass_knife = ArrayCreate(32, 1)
	g_zclass_spd = ArrayCreate(1, 1)
	g_zclass_grav = ArrayCreate(1, 1)
	g_zclass_kb = ArrayCreate(1, 1)
	
	/*g_szName = ArrayCreate(50);
	g_szTipo = ArrayCreate(42);
	g_aLevel = ArrayCreate();
	g_aReset = ArrayCreate();*/
	g_aArray = ArrayCreate(e_WeaponsInfo);
	/*g_iCat = ArrayCreate();
	g_iTipo = ArrayCreate();*/

	// Allow registering stuff now
	g_arrays_created = true
	
	// Load customization data
	load_customization_from_files()
	
	new i, buffer[100];
	
	// Load up the hard coded extra items
	native_register_extra_item2("NightVision", g_extra_costs2[EXTRA_NVISION], 1, ZP_TEAM_HUMAN)

	
	if(!g_bModEscape) native_register_extra_item2("T-Virus Antidote", g_extra_costs2[EXTRA_ANTIDOTE], 6, ZP_TEAM_ZOMBIE)
	native_register_extra_item2("Zombie Madness", g_extra_costs2[EXTRA_MADNESS], 1, ZP_TEAM_ZOMBIE)
	native_register_extra_item2("Infection Bomb", g_extra_costs2[EXTRA_INFBOMB], 8, ZP_TEAM_ZOMBIE)
	native_register_extra_item2("Jump Bomb", g_extra_costs2[EXTRA_JUMPBOMB], 1, ZP_TEAM_ZOMBIE)
	native_register_extra_item2("UnFrozen", g_extra_costs2[NO_FROST], 0, ZP_TEAM_ZOMBIE)
	native_register_extra_item2("No Fire", g_extra_costs2[NO_FIRE], 0, ZP_TEAM_ZOMBIE)
	native_register_extra_item2("No Pipe", g_extra_costs2[NO_PIPE], 0, ZP_TEAM_ZOMBIE)

	native_register_extra_item2("Infinite Bullets", g_extra_costs2[BALAS_INFINITAS], 3, ZP_TEAM_HUMAN)
	native_register_extra_item2("Freezer Bullets", g_extra_costs2[BALAS_CONGELADORAS], 3, ZP_TEAM_HUMAN)

	native_register_extra_item2("Gask Mask", g_extra_costs2[GASK_MASK], 12, ZP_TEAM_HUMAN)

	native_register_extra_item2("Speed Boost", g_extra_costs2[BOOST], 0, ZP_TEAM_HUMAN)

	// Extra weapons
	for (i = 0; i < ArraySize(g_extraweapon_names); i++)
	{
		ArrayGetString(g_extraweapon_names, i, buffer, charsmax(buffer))
		native_register_extra_item2(buffer, ArrayGetCell(g_extraweapon_costs, i), 8, ZP_TEAM_HUMAN)
	}

	precache_player_model(szNemesis);
	precache_player_model(szSurvivor);
	precache_player_model(szSniper);
	precache_player_model(szWesker);
	precache_player_model(szHuman);
	precache_player_model(szSirio);
	precache_player_model(ModelAlien);
	precache_player_model(ModelAlien2);
	precache_player_model(ModelNinja);
	precache_model("models/rpgrocket.mdl");

	precache_sound(MESSAGE_SOUND);
	precache_sound(szFireHole);
	precache_sound(g_sound);
	precache_sound(sound_drogado);


	// Custom weapon models
	engfunc(EngFunc_PrecacheModel, V_KNIFE_NEMESIS);
	engfunc(EngFunc_PrecacheModel, KnifeNinja);
	engfunc(EngFunc_PrecacheModel, KnifeAlien);
	engfunc(EngFunc_PrecacheModel, GRENADE_INFECT);
	engfunc(EngFunc_PrecacheModel, GRENADE_FIRE);
	engfunc(EngFunc_PrecacheModel, GRENADE_FROST);
	engfunc(EngFunc_PrecacheModel, MODEL_meta);
	engfunc(EngFunc_PrecacheModel, g_vmodel); 
	engfunc(EngFunc_PrecacheModel, g_pmodel);  
	engfunc(EngFunc_PrecacheModel, g_vChain);
	engfunc(EngFunc_PrecacheModel, grenade_droga);
	engfunc(EngFunc_PrecacheModel, model_grenade);
	engfunc(EngFunc_PrecacheModel, model);
	engfunc(EngFunc_PrecacheModel, szM4CHINE);
	engfunc( EngFunc_PrecacheModel, g_szJump_v );
	engfunc( EngFunc_PrecacheModel, g_szJump_p );  

	// Custom sprites for grenades
	g_trailSpr = engfunc(EngFunc_PrecacheModel, sprite_grenade_trail)
	g_exploSpr = engfunc(EngFunc_PrecacheModel, sprite_grenade_ring)
	g_flameSpr = engfunc(EngFunc_PrecacheModel, sprite_grenade_fire)
	g_smokeSpr = engfunc(EngFunc_PrecacheModel, sprite_grenade_smoke)
	g_glassSpr = engfunc(EngFunc_PrecacheModel, sprite_grenade_glass)
	m_spriteTexture = engfunc(EngFunc_PrecacheModel, "sprites/ef_laserfist_laserbeam.spr")
	g_frost_gibs = engfunc(EngFunc_PrecacheModel, "sprites/zombie_plague/Frost_Gibs.spr");
	g_frostexp = engfunc(EngFunc_PrecacheModel, "sprites/zombie_plague/Frost_Exp.spr");
	g_fireexp = engfunc(EngFunc_PrecacheModel, "sprites/zombie_plague/Fire_Exp.spr");
	g_fire_gibs = engfunc(EngFunc_PrecacheModel, "sprites/zombie_plague/Fire_gibs.spr");
	g_iExplo = engfunc(EngFunc_PrecacheModel, "sprites/zombiebomb_exp.spr" )

	engfunc( EngFunc_PrecacheGeneric, soundSirio );
	engfunc( EngFunc_PrecacheGeneric, soundWesker );
	engfunc( EngFunc_PrecacheGeneric, soundSniper );
	engfunc( EngFunc_PrecacheGeneric, SoundAlien );
	engfunc( EngFunc_PrecacheGeneric, soundMutilador );
	precache_sound( frogbomb_sound );
	precache_sound( frogbomb_sound_idle );

	for ( i = 0; i < sizeof g_SoundBombExplode; i++ )
		engfunc( EngFunc_PrecacheSound, g_SoundBombExplode [ i ] );

	// Custom sounds
	for (i = 0; i < ArraySize(sound_win_zombies); i++)
	{
		ArrayGetString(sound_win_zombies, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(sound_win_humans); i++)
	{
		ArrayGetString(sound_win_humans, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(sound_win_no_one); i++)
	{
		ArrayGetString(sound_win_no_one, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(zombie_infect); i++)
	{
		ArrayGetString(zombie_infect, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(zombie_pain); i++)
	{
		ArrayGetString(zombie_pain, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(nemesis_pain); i++)
	{
		ArrayGetString(nemesis_pain, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(zombie_die); i++)
	{
		ArrayGetString(zombie_die, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(zombie_fall); i++)
	{
		ArrayGetString(zombie_fall, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(zombie_miss_slash); i++)
	{
		ArrayGetString(zombie_miss_slash, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(zombie_miss_wall); i++)
	{
		ArrayGetString(zombie_miss_wall, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(zombie_hit_normal); i++)
	{
		ArrayGetString(zombie_hit_normal, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(zombie_hit_stab); i++)
	{
		ArrayGetString(zombie_hit_stab, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(zombie_idle); i++)
	{
		ArrayGetString(zombie_idle, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(zombie_idle_last); i++)
	{
		ArrayGetString(zombie_idle_last, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(zombie_madness); i++)
	{
		ArrayGetString(zombie_madness, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(sound_nemesis); i++)
	{
		ArrayGetString(sound_nemesis, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(sound_survivor); i++)
	{
		ArrayGetString(sound_survivor, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(sound_swarm); i++)
	{
		ArrayGetString(sound_swarm, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(sound_multi); i++)
	{
		ArrayGetString(sound_multi, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(sound_plague); i++)
	{
		ArrayGetString(sound_plague, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(grenade_infect); i++)
	{
		ArrayGetString(grenade_infect, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(grenade_infect_player); i++)
	{
		ArrayGetString(grenade_infect_player, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(grenade_fire); i++)
	{
		ArrayGetString(grenade_fire, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(grenade_fire_player); i++)
	{
		ArrayGetString(grenade_fire_player, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(grenade_frost); i++)
	{
		ArrayGetString(grenade_frost, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(grenade_frost_player); i++)
	{
		ArrayGetString(grenade_frost_player, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(grenade_frost_break); i++)
	{
		ArrayGetString(grenade_frost_break, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(sound_antidote); i++)
	{
		ArrayGetString(sound_antidote, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < ArraySize(sound_thunder); i++)
	{
		ArrayGetString(sound_thunder, i, buffer, charsmax(buffer))
		engfunc(EngFunc_PrecacheSound, buffer)
	}
	for (i = 0; i < sizeof sonidos_de_conteo; i++)
        precache_sound(sonidos_de_conteo[i]) 

	for( i = 0; i < sizeof(szRadioX) ; ++i )
		precache_sound(szRadioX[i][rutaRadio]); 

	for( new i; i < sizeof SOUNDS; i++ )
		precache_sound( SOUNDS[ i ] );

	// Ambience Sounds
	if (g_ambience_sounds[AMBIENCE_SOUNDS_INFECTION])
	{
		for (i = 0; i < ArraySize(sound_ambience1); i++)
		{
			ArrayGetString(sound_ambience1, i, buffer, charsmax(buffer))
			
			if (ArrayGetCell(sound_ambience1_ismp3, i))
			{
				format(buffer, charsmax(buffer), "sound/%s", buffer)
				engfunc(EngFunc_PrecacheGeneric, buffer)
			}
			else
			{
				engfunc(EngFunc_PrecacheSound, buffer)
			}
		}
	}
	if (g_ambience_sounds[AMBIENCE_SOUNDS_NEMESIS])
	{
		for (i = 0; i < ArraySize(sound_ambience2); i++)
		{
			ArrayGetString(sound_ambience2, i, buffer, charsmax(buffer))
			
			if (ArrayGetCell(sound_ambience2_ismp3, i))
			{
				format(buffer, charsmax(buffer), "sound/%s", buffer)
				engfunc(EngFunc_PrecacheGeneric, buffer)
			}
			else
			{
				engfunc(EngFunc_PrecacheSound, buffer)
			}
		}
	}
	if (g_ambience_sounds[AMBIENCE_SOUNDS_SURVIVOR])
	{
		for (i = 0; i < ArraySize(sound_ambience3); i++)
		{
			ArrayGetString(sound_ambience3, i, buffer, charsmax(buffer))
			
			if (ArrayGetCell(sound_ambience3_ismp3, i))
			{
				format(buffer, charsmax(buffer), "sound/%s", buffer)
				engfunc(EngFunc_PrecacheGeneric, buffer)
			}
			else
			{
				engfunc(EngFunc_PrecacheSound, buffer)
			}
		}
	}
	if (g_ambience_sounds[AMBIENCE_SOUNDS_SWARM])
	{
		for (i = 0; i < ArraySize(sound_ambience4); i++)
		{
			ArrayGetString(sound_ambience4, i, buffer, charsmax(buffer))
			
			if (ArrayGetCell(sound_ambience4_ismp3, i))
			{
				format(buffer, charsmax(buffer), "sound/%s", buffer)
				engfunc(EngFunc_PrecacheGeneric, buffer)
			}
			else
			{
				engfunc(EngFunc_PrecacheSound, buffer)
			}
		}
	}
	if (g_ambience_sounds[AMBIENCE_SOUNDS_PLAGUE])
	{
		for (i = 0; i < ArraySize(sound_ambience5); i++)
		{
			ArrayGetString(sound_ambience5, i, buffer, charsmax(buffer))
			
			if (ArrayGetCell(sound_ambience5_ismp3, i))
			{
				format(buffer, charsmax(buffer), "sound/%s", buffer)
				engfunc(EngFunc_PrecacheGeneric, buffer)
			}
			else
			{
				engfunc(EngFunc_PrecacheSound, buffer)
			}
		}
	}

	precache_sound(SOUND)
		
	// CS sounds (just in case)
	engfunc(EngFunc_PrecacheSound, sound_flashlight)
	engfunc(EngFunc_PrecacheSound, sound_buyammo)
	engfunc(EngFunc_PrecacheSound, sound_armorhit)
	
	new ent
	
	// Fake Hostage (to force round ending)
	ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "hostage_entity"))
	if (pev_valid(ent))
	{
		engfunc(EngFunc_SetOrigin, ent, Float:{8192.0,8192.0,8192.0})
		dllfunc(DLLFunc_Spawn, ent)
	}
	
	// Weather/ambience effects
	if (g_ambience_fog)
	{
		ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_fog"))
		if (pev_valid(ent))
		{
			fm_set_kvd(ent, "density", g_fog_density, "env_fog")
			fm_set_kvd(ent, "rendercolor", g_fog_color, "env_fog")
		}
	}
	if (g_ambience_rain) engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_rain"))
	if (g_ambience_snow) engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_snow"))
	
	// Prevent some entities from spawning
	g_fwSpawn = register_forward(FM_Spawn, "fw_Spawn")
	
	// Prevent hostage sounds from being precached
	g_fwPrecacheSound = register_forward(FM_PrecacheSound, "fw_PrecacheSound")
}

public plugin_init()
{
	// Plugin disabled?
	if (!g_pluginenabled) return;
	
	// No zombie classes?
	if (!g_zclass_i) set_fail_state("No zombie classes loaded!")
	
	// Language files
	register_dictionary("zombie_plague.txt")
	
	// Events
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	register_logevent("logevent_round_start",2, "1=Round_Start")
	register_logevent("logevent_round_end", 2, "1=Round_End")
	register_event("AmmoX", "event_ammo_x", "be")
	if (g_ambience_sounds[AMBIENCE_SOUNDS_INFECTION] || g_ambience_sounds[AMBIENCE_SOUNDS_NEMESIS] || g_ambience_sounds[AMBIENCE_SOUNDS_SURVIVOR] || g_ambience_sounds[AMBIENCE_SOUNDS_SWARM] || g_ambience_sounds[AMBIENCE_SOUNDS_PLAGUE])
		register_event("30", "event_intermission", "a")
	
	// HAM Forwards
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled_Post", 1)
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	RegisterHam(Ham_TakeDamage,"func_breakable","FwdHamBreakableKilled",1)
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage_Post", 1)
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
	RegisterHam(Ham_Player_ResetMaxSpeed, "player", "fw_ResetMaxSpeed_Post", 1)
	RegisterHam(Ham_TraceAttack, "worldspawn", "make_tracer", 1)
	RegisterHam(Ham_Use, "func_tank", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tankmortar", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tankrocket", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tanklaser", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tank", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankmortar", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankrocket", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tanklaser", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_pushable", "fw_UsePushable")
	RegisterHam(Ham_Touch, "weaponbox", "fw_TouchWeapon")
	RegisterHam(Ham_Touch, "armoury_entity", "fw_TouchWeapon")
	RegisterHam(Ham_Touch, "weapon_shield", "fw_TouchWeapon")
	RegisterHam(Ham_AddPlayerItem, "player", "fw_AddPlayerItem")

	for (new i = 1; i < sizeof WEAPONENTNAMES; i++)
		if (WEAPONENTNAMES[i][0]) RegisterHam(Ham_Item_Deploy, WEAPONENTNAMES[i], "fw_Item_Deploy_Post", 1)

	// FM Forwards
	register_forward(FM_AddToFullPack, "AddToFullPackPost", 1);
	register_forward(FM_ClientDisconnect, "fw_ClientDisconnect")
	register_forward(FM_ClientDisconnect, "fw_ClientDisconnect_Post", 1)
	register_forward(FM_ClientKill, "fw_ClientKill")
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_SetClientKeyValue, "fw_SetClientKeyValue")
	register_forward(FM_ClientUserInfoChanged, "fw_ClientUserInfoChanged")
	register_forward(FM_GetGameDescription, "fw_GetGameDescription")
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_Touch, "fw_Touch")
	RegisterHam(Ham_Think, "grenade", "fw_ThinkGrenade")
	register_forward(FM_PlayerPreThink, "fw_PlayerPreThink")
	unregister_forward(FM_Spawn, g_fwSpawn)
	unregister_forward(FM_PrecacheSound, g_fwPrecacheSound)
	register_touch("trigger_hurt", "player", "touch_trigger_hurt")
	register_touch(entclas, "player", "touch_bubble");
	register_impulse(IMPULSE_FLASHLIGHT, "cmdBlock_linterna");

	// Client commands
	register_clcmd( "amx_code", "amx_activar" );
	register_clcmd("say /offskins", "offSkins");
	//register_clcmd( "say /top15", "checkTop" );
	register_clcmd("say /rank", "checkRank");
	register_clcmd("say /spect", "fnSpect");
	register_clcmd("say /winhumans", "bugRoundCt");
	//register_clcmd( "sayteam /top15", "checkTop" );
	register_clcmd("sayteam /rank", "checkRank");
	register_clcmd("say", "clcmd_say");
	register_clcmd("say_team", "clcmd_say");
	register_clcmd("say zpmenu", "clcmd_saymenu");
	register_clcmd("say /zpmenu", "clcmd_saymenu");
	register_clcmd("say unstuck", "clcmd_sayunstuck");
	register_clcmd("say /unstuck", "clcmd_sayunstuck");
	register_clcmd("nightvision", "clcmd_nightvision");
	register_clcmd("drop", "clcmd_drop");
	register_clcmd("buyammo1", "clcmd_buyammo");
	register_clcmd("buyammo2", "clcmd_buyammo");
	register_clcmd("chooseteam", "clcmd_changeteam");
	register_clcmd("jointeam", "clcmd_changeteam");
	register_clcmd("say /party", "cmdParty");
	register_clcmd("radio1", "cmdRadio");
	register_clcmd("radio2", "cmdRadio");
	register_clcmd("radio3", "cmdRadio");
	register_clcmd("buyequip", "show_menu_extras");
	register_clcmd("say /meta", "menu_cordenada");
	register_clcmd("say /myid", "my_id");

	cvar_time_acept = register_cvar("party_time_acept","15")
	cvar_max_players = register_cvar("party_max_players","3")
	cvar_allow_bots = register_cvar("party_allow_bots","0")

	g_MenuCallback[MASTER] = menu_makecallback("check_master")
	g_MenuCallback[USER] = menu_makecallback("check_user")

	fw_Item_Selected = CreateMultiForward("dar_arma", ET_STOP, FP_CELL, FP_CELL);
	
	// Menus
	register_menu("Game Menu", KEYSMENU, "menu_game")
	register_menu("Menu Armas", KEYSMENU, "handlerMenu")
	register_menu("Menu Clases", KEYSMENU, "HandlerClases")
	
	// Admin commands
	register_concmd("zp_zombie", "cmd_zombie", ADMIN_IMMUNITY, "<target> - Turn someone into a Zombie", 0)
	register_concmd("zp_human", "cmd_human", ADMIN_IMMUNITY, "<target> - Turn someone back to Human", 0)
	register_concmd("zp_nemesis", "cmd_nemesis", ADMIN_IMMUNITY, "<target> - Turn someone into a Nemesis", 0)
	register_concmd("zp_survivor", "cmd_survivor", ADMIN_IMMUNITY, "<target> - Turn someone into a Survivor", 0)
	register_concmd("zp_respawn", "cmd_respawn", ADMIN_IMMUNITY, "<target> - Respawn someone", 0)
	register_concmd("zp_swarm", "cmd_swarm", ADMIN_IMMUNITY, " - Start Swarm Mode", 0)
	register_concmd("zp_multi", "cmd_multi", ADMIN_IMMUNITY, " - Start Multi Infection", 0)
	register_concmd("zp_plague", "cmd_plague", ADMIN_IMMUNITY, " - Start Plague Mode", 0)
	register_concmd("zp_sniper", "cmdSniper", ADMIN_IMMUNITY, "<Target> Sleccionamos al jugador para que sea sniper");
	register_concmd("zp_wesker", "cmdWesker", ADMIN_IMMUNITY, "<Target> Sleccionamos al jugador para que sea wesker");
	register_concmd("zp_sirio", "cmdSirio", ADMIN_IMMUNITY, "<Target> Sleccionamos al jugador para que sea Sirio");
	register_concmd("zp_alien", "cmdAlien", ADMIN_IMMUNITY, "<Target> Sleccionamos al jugador para que sea Alien");
	register_concmd("zp_ninja", "cmdNinja", ADMIN_IMMUNITY, "<Target> Sleccionamos al jugador para que sea ninja");
	register_concmd("zp_mutilador", "CmdMutilador", ADMIN_IMMUNITY, " - Comienzo del Modo Mutilador") ;
	//register_concmd("amx_donar", "cmdDonar", _, "amx_donar <nombre> <cantidad>")

	// Message IDs
	g_msgScoreInfo = get_user_msgid("ScoreInfo")
	g_msgTeamInfo = get_user_msgid("TeamInfo")
	g_msgDeathMsg = get_user_msgid("DeathMsg")
	g_msgScoreAttrib = get_user_msgid("ScoreAttrib")
	g_msgSetFOV = get_user_msgid("SetFOV")
	g_msgScreenFade = get_user_msgid("ScreenFade")
	g_msgScreenShake = get_user_msgid("ScreenShake")
	g_msgNVGToggle = get_user_msgid("NVGToggle")
	g_msgAmmoPickup = get_user_msgid("AmmoPickup")
	g_msgDamage = get_user_msgid("Damage")
	g_msgHideWeapon = get_user_msgid("HideWeapon")
	g_msgCrosshair = get_user_msgid("Crosshair")
	g_msgSayText = get_user_msgid("SayText")
	g_msgCurWeapon = get_user_msgid("CurWeapon")
	g_iMsgTextMsg   = get_user_msgid( "TextMsg" );
	g_iMsgSendAudio = get_user_msgid( "SendAudio" );
	
	register_menucmd(register_menuid("Menu de camaras"), 1023, "setview") 

	register_clcmd("say /camera", "chooseview")
	register_clcmd("say_team /camera", "chooseview")

	register_clcmd("say /cam", "chooseview")
	register_clcmd("say_team /cam", "chooseview")  
	// Message hooks
	register_message(g_msgCurWeapon, "message_cur_weapon")
	register_message(get_user_msgid("Money"), "message_money")
	register_message(get_user_msgid("Health"), "message_health")
	register_message(g_msgScreenFade, "message_screenfade")
	register_message(g_msgNVGToggle, "message_nvgtoggle")
	//if (g_handle_models_on_separate_ent) register_message(get_user_msgid("ClCorpse"), "message_clcorpse")
	register_message(get_user_msgid("WeapPickup"), "message_weappickup")
	register_message(g_msgAmmoPickup, "message_ammopickup")
	register_message(get_user_msgid("Scenario"), "message_scenario")
	register_message(get_user_msgid("HostagePos"), "message_hostagepos")
	register_message(g_iMsgTextMsg, "message_textmsg")
	register_message(g_iMsgSendAudio, "message_sendaudio")
	register_message(get_user_msgid("TeamScore"), "message_teamscore")
	register_message(g_msgTeamInfo, "message_teaminfo")
	set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET)
	
	// 2 = CSW_SHIELD = UNDEFINED | PUT SHOTGUNS HERE TO SKIP IN LOOP AND REGISTER MANUALLY
	new const NO_RELOAD = ( 1 << 2 ) | ( 1 << CSW_KNIFE ) | ( 1 << CSW_C4 ) | ( 1 << CSW_M3 ) |
		( 1 << CSW_XM1014 ) | ( 1 << CSW_HEGRENADE ) | ( 1 << CSW_FLASHBANG ) | ( 1 << CSW_SMOKEGRENADE );
	
	new szWeaponName[ 20 ];
	for( new i = CSW_P228; i <= CSW_P90; i++ ) {
		if( NO_RELOAD & ( 1 << i ) )
			continue;
		
		get_weaponname( i, szWeaponName, 19 );
		RegisterHam( Ham_Weapon_Reload, szWeaponName, "FwdHamWeaponReload", 1 );
	}
	
	RegisterHam( Ham_Weapon_Reload, "weapon_m3",     "FwdHamShotgunReload", 1 );
	RegisterHam( Ham_Weapon_Reload, "weapon_xm1014", "FwdHamShotgunReload", 1 );

	cvar_event = register_cvar("zp_event", "0");
	g_pPercent = register_cvar( "rr_percent", "55" );
	cvar_exp = register_cvar("exp_damage", "1"); // Exp al alcanzar el daño requerido
	g_iDefaultDamage = DEFAULT_DAMAGE;

	cvar_modes = register_cvar("zp_mode_on", "1");

	// CVARS - General Purpose
	cvar_speed = register_cvar ( "zp_zombiebomb_knockback", "600" );
	cvar_jump_radius = register_cvar ( "zp_zombiebomb_radius", "300.0" );
	cvar_radius = register_cvar ( "zp_pipe_radius", "200"); 
	cvar_damage = register_cvar("zp_pipe_damage", "1500.0"); 
	cvar_timedroga = register_cvar("zp_droga_time", "5");
	cvar_timeCampo = register_cvar("zp_bubble_time", "8");
	cvar_radiodroga = register_cvar("zp_droga_radio", "400");
	cvar_damageHE = register_cvar("zp_hedamage", "800");
	cvar_warmup = register_cvar("zp_delay", "10");
	cvar_lighting = register_cvar("zp_lighting", "j")
	cvar_triggered = register_cvar("zp_triggered_lights", "1")
	cvar_removedoors = register_cvar("zp_remove_doors", "0")
	cvar_blockpushables = register_cvar("zp_blockuse_pushables", "1")
	cvar_blocksuicide = register_cvar("zp_block_suicide", "1")
	cvar_randspawn = register_cvar("zp_random_spawn", "1")
	cvar_respawnworldspawnkill = register_cvar("zp_respawn_on_worldspawn_kill", "1")
	cvar_removedropped = register_cvar("zp_remove_dropped", "1")
	cvar_removemoney = register_cvar("zp_remove_money", "1")
	cvar_buycustom = register_cvar("zp_buy_custom", "1")
	cvar_zclasses = register_cvar("zp_zombie_classes", "1")
	cvar_startammopacks = register_cvar("zp_starting_ammo_packs", "5")
	cvar_preventconsecutive = register_cvar("zp_prevent_consecutive_modes", "1")
	cvar_keephealthondisconnect = register_cvar("zp_keep_health_on_disconnect", "1")

	// Cvar - Mutilador mode
	cvar_mutilador = register_cvar("zp_mutilador_enable", "1")
	cvar_mutiladorchance = register_cvar("zp_mutilador_chance", "40")
	cvar_mutiladorminplayer = register_cvar("zp_mutilador_min_player", "0")
	cvar_mutiladorratio = register_cvar("zp_mutilador_ratio", "1.5")
	cvar_mutiladorhpsurvi = register_cvar("zp_mutilador_hp_ninja", "15")
	cvar_mutiladorhpneme = register_cvar("zp_mutilador_hp_alien", "800") 

	cvar_boost_amount = register_cvar("zp_boost_amount", "130.0")
	cvar_boost_duration = register_cvar("zp_boost_duration", "12.0")
	cvar_boost_speed = register_cvar("zp_boost_limit", "1")
	
	// CVARS - Deathmatch
	cvar_deathmatch = register_cvar("zp_deathmatch", "1")
	cvar_spawndelay = register_cvar("zp_spawn_delay", "3")
	cvar_spawnprotection = register_cvar("zp_spawn_protection", "5")
	cvar_respawnafterlast = register_cvar("zp_respawn_after_last_human", "1")

	// CVARS - Extra Items
	cvar_extraitems = register_cvar("zp_extra_items", "1")
	cvar_extraweapons = register_cvar("zp_extra_weapons", "1")
	cvar_extranvision = register_cvar("zp_extra_nvision", "1")
	cvar_extraantidote = register_cvar("zp_extra_antidote", "1")
	cvar_antidotelimit = register_cvar("zp_extra_antidote_limit", "4")
	cvar_extramadness = register_cvar("zp_extra_madness", "1")
	cvar_madnesslimit = register_cvar("zp_extra_madness_limit", "2")
	cvar_madnessduration = register_cvar("zp_extra_madness_duration", "5.0")
	cvar_infbomblimit = register_cvar("zp_extra_infbomb_limit", "1")
	cvar_balaslimit = register_cvar("zp_extra_balas_limit", "2")
	
	// CVARS - Flashlight and Nightvision
	cvar_nvggive = register_cvar("zp_nvg_give", "1")
	cvar_customnvg = register_cvar("zp_nvg_custom", "1")
	
	// CVARS - Knockback
	cvar_knockback = register_cvar("zp_knockback", "1")
	cvar_knockbackdamage = register_cvar("zp_knockback_damage", "1")
	cvar_knockbackpower = register_cvar("zp_knockback_power", "1")
	cvar_knockbackzvel = register_cvar("zp_knockback_zvel", "0")
	cvar_knockbackducking = register_cvar("zp_knockback_ducking", "0.25")
	cvar_knockbackdist = register_cvar("zp_knockback_distance", "500")
	cvar_nemknockback = register_cvar("zp_knockback_nemesis", "0.25")
	
	// CVARS - Leap
	cvar_leapzombies = register_cvar("zp_leap_zombies", "0")
	cvar_leapzombiesforce = register_cvar("zp_leap_zombies_force", "500")
	cvar_leapzombiesheight = register_cvar("zp_leap_zombies_height", "300")
	cvar_leapzombiescooldown = register_cvar("zp_leap_zombies_cooldown", "5.0")
	cvar_leapnemesis = register_cvar("zp_leap_nemesis", "1")
	cvar_leapnemesisforce = register_cvar("zp_leap_nemesis_force", "500")
	cvar_leapnemesisheight = register_cvar("zp_leap_nemesis_height", "300")
	cvar_leapnemesiscooldown = register_cvar("zp_leap_nemesis_cooldown", "5.0")
	cvar_leapsurvivor = register_cvar("zp_leap_survivor", "0")
	cvar_leapsurvivorforce = register_cvar("zp_leap_survivor_force", "500")
	cvar_leapsurvivorheight = register_cvar("zp_leap_survivor_height", "300")
	cvar_leapsurvivorcooldown = register_cvar("zp_leap_survivor_cooldown", "5.0")
	
	// CVARS - Humans
	cvar_humanhp = register_cvar("zp_human_health", "100")
	cvar_humanlasthp = register_cvar("zp_human_last_extrahp", "0")
	cvar_humanspd = register_cvar("zp_human_speed", "280")
	cvar_humangravity = register_cvar("zp_human_gravity", "1.0")
	cvar_humanarmor = register_cvar("zp_human_armor_protect", "1")
	cvar_ammodamage = register_cvar("zp_human_damage_reward", "500")
	cvar_fragskill = register_cvar("zp_human_frags_for_kill", "1")

	// CVAR - alien mode
	cvar_alien = register_cvar("zp_alien_enabled", "1");
	cvar_alienchance = register_cvar("zp_alien_chance", "35");
	cvar_alienminplayer = register_cvar("zp_alien_min_player", "8");
	cvar_alienhp = register_cvar("zp_alien_health", "3200");
	cvar_alienspd = register_cvar("zp_alien_speed", "330");
	cvar_aliengvt = register_cvar("zp_alien_gravity", "0.5");
	cvar_alienpainfree = register_cvar("zp_alien_painshock_free", "0"); 

	//ninja
	cvar_ninja = register_cvar("zp_ninja_enabled", "1");
	cvar_ninjachance = register_cvar("zp_ninja_chance", "35");
	cvar_ninjaminplayer = register_cvar("zp_ninja_min_player", "15");
	cvar_ninjahp = register_cvar("zp_ninja_health", "75");
	cvar_ninjaspd = register_cvar("zp_ninja_speed", "350");
	cvar_ninjagvt = register_cvar("zp_ninja_gravity", "0.5");
	cvar_ninjadamage = register_cvar("zp_ninja_damage", "5000.0");
	cvar_ninjapainfree = register_cvar("zp_ninja_painshock_free", "0"); 

	//sirio
	cvar_sirio = register_cvar("zp_sirio_enabled", "1");
	cvar_siriochance = register_cvar("zp_sirio_chance", "45");
	cvar_siriominplayer = register_cvar("zp_sirio_min_player", "5");
	cvar_siriohp = register_cvar("zp_sirio_health", "150");
	cvar_siriospd = register_cvar("zp_sirio_speed", "300");
	cvar_siriogvt = register_cvar("zp_sirio_gravity", "0.7");
	cvar_siriopainfree = register_cvar("zp_sirio_painshock_free", "0");

	//sniper
	cvar_sniper = register_cvar("zp_sniper_enabled", "1");
	cvar_sniperchance = register_cvar("zp_sniper_chance", "45");
	cvar_sniperminplayer = register_cvar("zp_sniper_min_player", "5");
	cvar_sniperhp = register_cvar("zp_sniper_health", "150");
	cvar_sniperspd = register_cvar("zp_sniper_speed", "300");
	cvar_snipergvt = register_cvar("zp_sniper_gravity", "0.7");
	cvar_sniperdamage = register_cvar("zp_sniper_damage", "25.0");
	cvar_sniperpainfree = register_cvar("zp_sniper_painshock_free", "0");

	//wesker
	cvar_wesker = register_cvar("zp_wesker_enabled", "1");
	cvar_weskerchance = register_cvar("zp_wesker_chance", "45");
	cvar_weskerminplayer = register_cvar("zp_wesker_min_player", "5");
	cvar_weskerhp = register_cvar("zp_wesker_health", "150");
	cvar_weskerspd = register_cvar("zp_wesker_speed", "300");
	cvar_weskergvt = register_cvar("zp_wesker_gravity", "0.7");
	cvar_weskerdamage = register_cvar("zp_wesker_damage", "15.0");
	cvar_weskerpainfree = register_cvar("zp_wesker_painshock_free", "0"); 

	// CVARS - Custom Grenades
	cvar_fireduration = register_cvar("zp_fire_duration", "10")
	cvar_firedamage = register_cvar("zp_fire_damage", "5")
	cvar_fireslowdown = register_cvar("zp_fire_slowdown", "0.5")
	cvar_freezeduration = register_cvar("zp_frost_duration", "3")
	
	// CVARS - Zombies
	cvar_zombiefirsthp = register_cvar("zp_zombie_first_hp", "2.0")
	cvar_zombiearmor = register_cvar("zp_zombie_armor", "0.75")
	cvar_hitzones = register_cvar("zp_zombie_hitzones", "0")
	cvar_zombiebonushp = register_cvar("zp_zombie_infect_health", "100")
	cvar_zombiefov = register_cvar("zp_zombie_fov", "110")
	cvar_zombiesilent = register_cvar("zp_zombie_silent", "1")
	cvar_zombiepainfree = register_cvar("zp_zombie_painfree", "2")
	cvar_ammoinfect = register_cvar("zp_zombie_infect_reward", "1")
	cvar_fragsinfect = register_cvar("zp_zombie_frags_for_infect", "1")
	
	// CVARS - Special Effects
	cvar_infectionscreenfade = register_cvar("zp_infection_screenfade", "1")
	cvar_infectionscreenshake = register_cvar("zp_infection_screenshake", "1")
	cvar_infectionsparkle = register_cvar("zp_infection_sparkle", "1")
	cvar_infectiontracers = register_cvar("zp_infection_tracers", "1")
	cvar_infectionparticles = register_cvar("zp_infection_particles", "1")
	cvar_hudicons = register_cvar("zp_hud_icons", "1")
	
	// CVARS - Nemesis
	cvar_nem = register_cvar("zp_nem_enabled", "1")
	cvar_nemchance = register_cvar("zp_nem_chance", "20")
	cvar_nemminplayers = register_cvar("zp_nem_min_players", "0")
	cvar_nemhp = register_cvar("zp_nem_health", "0")
	cvar_nembasehp = register_cvar("zp_nem_base_health", "0")
	cvar_nemspd = register_cvar("zp_nem_speed", "250")
	cvar_nemgravity = register_cvar("zp_nem_gravity", "0.5")
	cvar_nemdamage = register_cvar("zp_nem_damage", "250")
	cvar_nempainfree = register_cvar("zp_nem_painfree", "0")
	
	// CVARS - Survivor
	cvar_surv = register_cvar("zp_surv_enabled", "1")
	cvar_survchance = register_cvar("zp_surv_chance", "20")
	cvar_survminplayers = register_cvar("zp_surv_min_players", "0")
	cvar_survhp = register_cvar("zp_surv_health", "0")
	cvar_survbasehp = register_cvar("zp_surv_base_health", "0")
	cvar_survspd = register_cvar("zp_surv_speed", "330")
	cvar_survgravity = register_cvar("zp_surv_gravity", "1.0")
	cvar_survpainfree = register_cvar("zp_surv_painfree", "1")
	cvar_survweapon = register_cvar("zp_surv_weapon", "weapon_m249")
	cvar_survidamage = register_cvar("zp_surv_dmg", "2.5")
	
	// CVARS - Swarm Mode
	cvar_swarm = register_cvar("zp_swarm_enabled", "1")
	cvar_swarmchance = register_cvar("zp_swarm_chance", "20")
	cvar_swarmminplayers = register_cvar("zp_swarm_min_players", "20")
	
	// CVARS - Multi Infection
	cvar_multi = register_cvar("zp_multi_enabled", "1")
	cvar_multichance = register_cvar("zp_multi_chance", "20")
	cvar_multiminplayers = register_cvar("zp_multi_min_players", "0")
	cvar_multiratio = register_cvar("zp_multi_ratio", "0.15")
	
	// CVARS - Plague Mode
	cvar_plague = register_cvar("zp_plague_enabled", "1")
	cvar_plaguechance = register_cvar("zp_plague_chance", "30")
	cvar_plagueminplayers = register_cvar("zp_plague_min_players", "0")
	cvar_plagueratio = register_cvar("zp_plague_ratio", "0.5")
	cvar_plaguenemnum = register_cvar("zp_plague_nem_number", "1")
	cvar_plaguenemhpmulti = register_cvar("zp_plague_nem_hp_multi", "0.5")
	cvar_plaguesurvnum = register_cvar("zp_plague_surv_number", "1")
	cvar_plaguesurvhpmulti = register_cvar("zp_plague_surv_hp_multi", "0.5")
	
	// CVARS - Others
	cvar_botquota = get_cvar_pointer("bot_quota")
	register_cvar("zp_version", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY)
	set_cvar_string("zp_version", PLUGIN_VERSION)
	
	// Custom Forwards
	g_fwRoundStart = CreateMultiForward("zp_round_started", ET_IGNORE, FP_CELL, FP_CELL)
	g_fwRoundEnd = CreateMultiForward("zp_round_ended", ET_IGNORE, FP_CELL)
	g_fwUserInfected_pre = CreateMultiForward("zp_user_infected_pre", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_fwUserInfected_post = CreateMultiForward("zp_user_infected_post", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_fwUserHumanized_pre = CreateMultiForward("zp_user_humanized_pre", ET_IGNORE, FP_CELL, FP_CELL)
	g_fwUserHumanized_post = CreateMultiForward("zp_user_humanized_post", ET_IGNORE, FP_CELL, FP_CELL)
	g_fwUserInfect_attempt = CreateMultiForward("zp_user_infect_attempt", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL)
	g_fwUserHumanize_attempt = CreateMultiForward("zp_user_humanize_attempt", ET_CONTINUE, FP_CELL, FP_CELL)
	g_fwExtraItemSelected = CreateMultiForward("zp_extra_item_selected", ET_CONTINUE, FP_CELL, FP_CELL)
	g_fwUserUnfrozen = CreateMultiForward("zp_user_unfrozen", ET_IGNORE, FP_CELL)
	g_fwUserLastZombie = CreateMultiForward("zp_user_last_zombie", ET_IGNORE, FP_CELL)
	g_fwUserLastHuman = CreateMultiForward("zp_user_last_human", ET_IGNORE, FP_CELL)
	
	// Collect random spawn points
	load_spawns()
	
	// Set a random skybox?
	if (g_sky_enable)
	{
		new sky[32]
		ArrayGetString(g_sky_names, random_num(0, ArraySize(g_sky_names) - 1), sky, charsmax(sky))
		set_cvar_string("sv_skyname", sky)
	}
	g_bModEscape = false;

	new szMap[40];
	get_mapname(szMap, 39);

	if(containi(szMap, "ze_"))
		g_bModEscape = true;
	
	// Disable sky lighting so it doesn't mess with our custom lighting
	set_cvar_num("sv_skycolor_r", 0)
	set_cvar_num("sv_skycolor_g", 0)
	set_cvar_num("sv_skycolor_b", 0)
	
	// Create the HUD Sync Objects
	g_MsgSync = CreateHudSyncObj()
	g_MsgSync2 = CreateHudSyncObj()
	g_MsgSyncParty = CreateHudSyncObj();

	// Format mod name
	formatex(g_modname, charsmax(g_modname), "Zombie Escape %s", PLUGIN_VERSION)
	
	// Get Max Players
	g_maxplayers = get_maxplayers()

	MySQL_Init();
}
public FwdHamBreakableKilled(ent, weapon, killer)
{
	if ( !is_user_connected( killer ) )
		return HAM_IGNORED;

	if(entity_get_float(ent,EV_FL_health)<0)
	{
		static name[ 32 ];
		get_user_name( killer, name, charsmax( name ) );
		zp_colored_print(0,"^x4%s^x1 El Player ^x4%s ^x1rompio un ^x4Objeto^x1 ^x3[ %d ^x3].", g_szPrefix, g_playername[killer], ent);
		return HAM_IGNORED;
	}
	return HAM_IGNORED;
}
public MySQL_Init()
{
	g_hTuple = advacc_guardado_get_handle( );
	
	if( !g_hTuple ) 
	{
		log_to_file( "SQL_ERROR.txt", "No se pudo conectar con la base de datos." );
		return pause( "a" );
	}
	set_task(4.0, "record_task")

	return PLUGIN_CONTINUE;
}

public record_task()
{
	new szQuery[ MAX_MENU_LENGTH ], iData[ 1 ], szMapName[40]; get_mapname(szMapName, 39);
				
	iData[ 0 ] = BUSCAR_META;

	formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE MapName=^"%s^"", g_szTableMaps, szMapName );
	SQL_ThreadQuery( g_hTuple, "DataHandlerServer", szQuery, iData, sizeof(iData) );
}
public plugin_cfg()
{
	// Plugin disabled?
	if (!g_pluginenabled) return;
	
	// Get configs dir
	new cfgdir[32]
	get_configsdir(cfgdir, charsmax(cfgdir))
	
	// Execute config file (zombieplague.cfg)
	server_cmd("exec %s/zombieplague.cfg", cfgdir)
	
	// Prevent any more stuff from registering
	g_arrays_created = false
	
	// Cache CVARs after configs are loaded / call roundstart manually
	set_task(0.5, "cache_cvars")
	set_task(0.5, "event_round_start")
	set_task(0.5, "logevent_round_start")

	for(new i = 1; i <= g_maxplayers; i++)
        Party_Ids[i] = ArrayCreate(1, 1);
}

/*================================================================================
 [Main Events]
=================================================================================*/
public conteo()
{
	if (!tiempo_de_conteo) 
	{
		remove_task(TASK_CONTEO)
		return;
	}
	switch(tiempo_de_conteo)
	{
		case 12:
		{
			set_dhudmessage(0, 0, 255,HUD_EVENT_X, 0.30, 0, 6.0, 0.001, 0.1, 1.0)
			show_dhudmessage(0, "Preparate para attackar!");
			PlaySound(MESSAGE_SOUND)
		}
		case 11:
		{
			set_dhudmessage(0, 0, 255, HUD_EVENT_X, 0.30, 0, 6.0, 0.001, 0.1, 1.0)
			show_dhudmessage(0, "Evacua rapidamente el area y escondete!");
		}
		case 9:
		{
			PlaySound(MESSAGE_SOUND)
		}
		case 8:
		{
			set_dhudmessage(255, 0, 0, HUD_EVENT_X, 0.30, 0, 6.0, 0.001, 0.1, 1.0)
			show_dhudmessage(0, "¡Peligro!");
		}
		case 6:
		{
			set_dhudmessage(0, 0, 255, HUD_EVENT_X, 0.30, 0, 6.0, 0.001, 0.1, 1.0)
			show_dhudmessage(0, "¡Los zombies se estan preparando..!");
		}
		case 4:
		{
			set_dhudmessage(255, 255, 255, HUD_EVENT_X, 0.30, 0, 6.0, 0.001, 0.1, 1.0)
			show_dhudmessage(0, "Prepara tus armas para la infeccion!");
				
			PlaySound(MESSAGE_SOUND)
		}
		case 2:
		{
			set_dhudmessage(255, 0, 0, HUD_EVENT_X, 0.30, 0, 6.0, 0.001, 0.1, 1.0)
			show_dhudmessage(0, "EL virus T se ha esparcido en el area!!");

			PlaySound(MESSAGE_SOUND)
		}
    }
	if(tiempo_de_conteo <= sizeof(sonidos_de_conteo))
		emit_sound(0, CHAN_VOICE, sonidos_de_conteo[tiempo_de_conteo-1], 1.0, ATTN_NORM, 0, PITCH_NORM);

	set_dhudmessage(random_num(57, 255), random_num(0, 255), random_num(0, 255), HUD_EVENT_X, HUD_EVENT_Y, 0, 6.0, 0.001, 0.1, 1.0)
	show_dhudmessage(0, "/----------------------------------------\^n| %d seconds until biological hazard |^n\----------------------------------------/", tiempo_de_conteo)

	--tiempo_de_conteo;
} 
// Event Round Start
public event_round_start()
{
	cache_cvars();

	// Get lighting style
	static lighting[2];
	get_pcvar_string(cvar_lighting, lighting, charsmax(lighting));
	strtolower(lighting);

	for(new i = 1; i <= g_maxplayers; ++i)
	{
		g_iCategoria[i] = 0;
		g_bAnterior[i] = false;

		if( !advacc_user_logged(i) || g_iStatus[ i ] != LOGUEADO )
			continue;
		
		set_player_light( i, lighting );

		guardar_datos( i );
		g_iDroga[i] = g_iPipe[i] = g_iHe[i] = g_tempDamage[i] = g_tempApps[i] = g_temExp[i] = 0;
		g_iNoDroga[i] = g_iExplote[i] = g_bMask[i] = g_iBalasEspeciales[i] = g_bBalas[i] = 0;
		g_iGhost[i] = g_iFisher[i] = g_iNoJump[i] = g_iCanKill[ i ] = 0;
		g_touched[i] = false;
		g_fTiempo[i] = get_gametime();
		g_currencyTime[i] = 0.0;
		g_steamBonus[i] = 1;
		//g_iJumpClass[i] = 0;
		g_iJumpingNadeCount[i] = 0;

		g_has_speed_boost[i] = false
		remove_task(i+TASK_SPEED_BOOST);
	}

	// Remove doors/lights?
	set_task(0.1, "remove_stuff")

	RefreshHH();

	remove_task(BLAST_TASK);
	remove_task(TASK_CONTEO);

	tiempo_de_conteo = (2 + get_pcvar_num(cvar_warmup));
	set_task(1.0, "conteo", TASK_CONTEO, _, _, "b") 

	// New round starting
	g_newround = true
	g_endround = false
	g_currentmode = MODE_NONE;
	g_modestarted = false
	g_bTouchExplote = false;
	g_iTouched = 0;
	// Reset bought infection bombs counter
	g_infbombcounter = 0
	g_antidotecounter = 0
	g_madnesscounter = 0
	g_iBalas = 0;
	g_boost = 0;
	// Freezetime begins
	g_freezetime = true
	
	// Show welcome message and T-Virus notice
	remove_task(TASK_WELCOMEMSG)
	set_task(2.0, "welcome_msg", TASK_WELCOMEMSG)
	
	// Set a new "Make Zombie Task"
	remove_task(TASK_MAKEZOMBIE)
	set_task(2.0 + get_pcvar_float(cvar_warmup), "make_zombie_task", TASK_MAKEZOMBIE)
}

// Log Event Round Start
public logevent_round_start()
{
	// Freezetime ends
	g_freezetime = false
}

// Log Event Round End
public logevent_round_end()
{
	// Prevent this from getting called twice when restarting (bugfix)
	static Float:lastendtime, Float:current_time, id; 
	current_time = get_gametime()
	if (current_time - lastendtime < 0.5) return;
	lastendtime = current_time
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		g_iJumpClass2[id] = 0;
		g_iJumpClass[id] = 0;
		// Not connected
		if (!g_isconnected[id])
			continue;
		
		// Not playing
		if ( g_iStatus[ id ] != LOGUEADO )
			continue;
		
		if(fnGetPlaying()-1 >= 4)
		{
			if(is_user_alive(id) && g_class[id] < ZOMBIE && g_touched[id])
			{
				if(g_iLevel[id] <= 20) SetExp(id, 8);
				else SetExp(id, 4);
			}
			
			UpdateFrags(id, -1, (g_temExp[id]/2), 0, 0);
			set_dhudmessage(238, 238, 238, HUD_EVENT_X, 0.22, 0, 6.0, 5.0, 0.1, 1.0)
			show_dhudmessage(id, "Estadisticas de la Ronda^n^nExperiencia Obtenida: %i^nAmmopacks Obtenidos: %i^n Damage Realizado: %i", g_temExp[id], g_tempApps[id], g_tempDamage[id]);
		}
		else
		{
			zp_colored_print(id, "^x4%s^x1 Se necesitan^x4 4^x1 o mas ^x4players^x1 poder ganar experiencia.", g_szPrefix);
		}
	}
	
	// Round ended
	g_endround = true
	
	// Stop old tasks (if any)
	remove_task(TASK_WELCOMEMSG)
	remove_task(TASK_MAKEZOMBIE)
	
	// Stop ambience sounds
	if ((g_ambience_sounds[AMBIENCE_SOUNDS_NEMESIS] && g_currentmode == MODE_NEMESIS) || (g_ambience_sounds[AMBIENCE_SOUNDS_SURVIVOR] && g_currentmode == MODE_SURVIVOR) || (g_ambience_sounds[AMBIENCE_SOUNDS_SWARM] && g_currentmode == MODE_SWARM) 
		|| (g_ambience_sounds[AMBIENCE_SOUNDS_PLAGUE] && g_currentmode == MODE_PLAGUE) || (g_ambience_sounds[AMBIENCE_SOUNDS_INFECTION] && g_currentmode == MODE_INFECTION))
	{
		remove_task(TASK_AMBIENCESOUNDS)
		ambience_sound_stop()
	}
	
	// Show HUD notice, play win sound, update team scores...
	static sound[64];
	if (!fnGetZombies())
	{
		// Human team wins
		set_dhudmessage(0, 0, 200, HUD_EVENT_X, HUD_EVENT_Y, 0, 6.0, 5.0, 0.1, 1.0)
		show_dhudmessage(0, "%L", LANG_PLAYER, "WIN_HUMAN")
		// Play win sound and increase score
		ArrayGetString(sound_win_humans, random_num(0, ArraySize(sound_win_humans) - 1), sound, charsmax(sound))
		PlaySound(sound)
		g_scorehumans++
		
		// Round end forward
		ExecuteForward(g_fwRoundEnd, g_fwDummyResult, ZP_TEAM_HUMAN);
		
	}
	else if (!fnGetHumans())
	{
		// Zombie team wins
		set_dhudmessage(200, 0, 0, HUD_EVENT_X, HUD_EVENT_Y, 0, 6.0, 5.0, 0.1, 1.0)
		show_dhudmessage(0, "%L", LANG_PLAYER, "WIN_ZOMBIE")
		
		// Play win sound and increase score
		ArrayGetString(sound_win_zombies, random_num(0, ArraySize(sound_win_zombies) - 1), sound, charsmax(sound))
		PlaySound(sound)
		g_scorezombies++
		
		// Round end forward
		ExecuteForward(g_fwRoundEnd, g_fwDummyResult, ZP_TEAM_ZOMBIE);

	}
	else
	{
		// No one wins
		set_dhudmessage(0, 200, 0, HUD_EVENT_X, HUD_EVENT_Y, 0, 6.0, 5.0, 0.1, 1.0)
		show_dhudmessage(0, "%L", LANG_PLAYER, "WIN_NO_ONE")
		
		// Play win sound
		ArrayGetString(sound_win_no_one, random_num(0, ArraySize(sound_win_no_one) - 1), sound, charsmax(sound))
		PlaySound(sound)
		
		// Round end forward
		ExecuteForward(g_fwRoundEnd, g_fwDummyResult, ZP_TEAM_NO_ONE);
	}
	
	// Balance the teams
	balance_teams()

	new iPlayers[32], iNum;
	get_players(iPlayers, iNum);
	 
	if (iNum > 2)
	{
		new id;
		new iGuardar[32][2], Count = 0;

		for (new i = 0; i < iNum; i++)
		{
		    id = iPlayers[i];
		    
		    // Guardar ID y Ammo Packs juntados en un array 2 dimensiones
		    iGuardar[Count][0] = id
		    iGuardar[Count][1] = g_temExp[id];
		    Count++
		}

		SortCustom2D(iGuardar, Count, "CompareFunc")

		new szTopPlayers[300], iLen

		for(Count = 0; Count < 3; Count++)
		{
		    id = iGuardar[Count][0]

		    if (!g_isconnected[id])
				continue;

		    iLen += formatex(szTopPlayers[iLen], charsmax(szTopPlayers) - iLen, "%d. %s (%d Exp),^n", Count+1, g_playername[id], g_temExp[id])
		   
		    if(g_temExp[id] > 0)
		    {
		        g_ammopacks[id] += 15 * (g_iMultiplicador[id][ 1 ] * g_steamBonus[id]);
		        client_print(id, print_chat, "%s Ganaste 15 Ammo Packs por ser el Numero %d de los mejores de la ronda.", g_szPrefix, Count+1);
		    }
		}

		szTopPlayers[strlen(szTopPlayers) - 2] = 0 // Borrar la ultima coma
		set_dhudmessage(238, 238, 238, HUD_EVENT_X, 0.48, 0, 6.0, 5.0, 0.1, 1.0)
		show_dhudmessage(0, "Mejores Jugadores de la ronda:^n^n %s", szTopPlayers)
	}

}
public CompareFunc(elem1[], elem2[]) 
{
    if(elem1[1] > elem2[1]) 
        return -1 
    else if(elem1[1] < elem2[1])
        return 1
 
    return 0 
} 


// Event Map Ended
public event_intermission()
{
	// Remove ambience sounds task
	remove_task(TASK_AMBIENCESOUNDS)
}

// BP Ammo update
public event_ammo_x(id)
{
	// Humans only
	if (g_class[id] >= ZOMBIE)
		return;
	
	// Get ammo type
	static type
	type = read_data(1)
	
	// Unknown ammo type
	if (type >= sizeof AMMOWEAPON)
		return;
	
	// Get weapon's id
	static weapon
	weapon = AMMOWEAPON[type]
	
	// Primary and secondary only
	if (MAXBPAMMO[weapon] <= 2)
		return;
	
	// Get ammo amount
	static amount
	amount = read_data(2)
	
	// Unlimited BP Ammo?
	if (amount < MAXBPAMMO[weapon])
	{
		// The BP Ammo refill code causes the engine to send a message, but we
		// can't have that in this forward or we risk getting some recursion bugs.
		// For more info see: https://bugs.alliedmods.net/show_bug.cgi?id=3664
		static args[1]
		args[0] = weapon
		set_task(0.1, "refill_bpammo", id, args, sizeof args)
	}
	
	// Bots automatically buy ammo when needed
	else if (g_isbot[id] && amount <= BUYAMMO[weapon])
	{
		// Task needed for the same reason as above
		set_task(0.1, "clcmd_buyammo", id)
	}
}

/*================================================================================
 [Main Forwards]
=================================================================================*/

// Entity Spawn Forward
public fw_Spawn(entity)
{
	// Invalid entity
	if (!pev_valid(entity)) return FMRES_IGNORED;
	
	// Get classname
	new classname[32], objective[32], size = ArraySize(g_objective_ents)
	pev(entity, pev_classname, classname, charsmax(classname))
	
	// Check whether it needs to be removed
	for (new i = 0; i < size; i++)
	{
		ArrayGetString(g_objective_ents, i, objective, charsmax(objective))
		
		if (equal(classname, objective))
		{
			engfunc(EngFunc_RemoveEntity, entity)
			return FMRES_SUPERCEDE;
		}
	}
	
	return FMRES_IGNORED;
}

// Sound Precache Forward
public fw_PrecacheSound(const sound[])
{
	// Block all those unneeeded hostage sounds
	if (equal(sound, "hostage", 7))
		return FMRES_SUPERCEDE;
	
	return FMRES_IGNORED;
}

// Ham Player Spawn Post Forward
public fw_PlayerSpawn_Post(id)
{
	// Not alive or didn't join a team yet
	if (!is_user_alive(id) || !fm_cs_get_user_team(id) || !is_user_connected(id) )
		return;
	
	// Player spawned
	g_humanclass[id] = g_humanclassnext[id];
	g_isalive[id] = true
	
	// Remove previous tasks
	remove_task(id+TASK_SPAWN);
	remove_task(id+TASK_BLOOD);
	remove_task(id+TASK_BURN);
	remove_task(id+TASK_NVISION);
	remove_task(id+TASK_DROGA);
	off(id);
	
	// Spawn at a random location?
	if (get_pcvar_num(cvar_randspawn)) do_random_spawn(id)
	
	// Hide money?
	if (get_pcvar_num(cvar_removemoney))
		set_task(0.4, "task_hide_money", id+TASK_SPAWN)
	
	// Respawn player if he dies because of a worldspawn kill?
	if (get_pcvar_num(cvar_respawnworldspawnkill))
		set_task(2.0, "respawn_player_task", id+TASK_SPAWN)
	
	// Spawn as zombie?
	if (g_respawn_as_zombie[id] && !g_newround)
	{
		reset_vars(id, 0) // reset player vars
		zombieme(id, 0, 0, 0, 0) // make him zombie right away
		return;
	}
	
	// Reset player vars
	reset_vars(id, 0)

	strip_user_weapons(id);
	give_item(id, "weapon_knife");

	// Show custom buy menu?
	if (get_pcvar_num(cvar_buycustom)){
		if(!g_bAutoSeleccion[id]) 
			set_task(1.3, "show_menu_buy1", id);
		else if(g_bAutoSeleccion[id])
		{
			set_task(1.2, "Anteriores", id);
		}
	}
	if( g_class[id] < ZOMBIE )
	{
		if (g_humanclass[id] != ZCLASS_NONE)
		{
			static buffer[200];
			g_human_spd[id] = float(ArrayGetCell(g_zclass_spd, g_humanclass[id]))
			ArrayGetString(g_zclass_name, g_humanclass[id], g_human_classname[id], charsmax(g_human_classname[]))
			set_user_health(id, ArrayGetCell(g_zclass_hp, g_humanclass[id]) + ammount_hhealth(g_habilidad[id][CLASS_HUMAN][1]))
			set_user_armor(id, ArrayGetCell(g_zclass_chaleco, g_humanclass[id]) + ammount_harmor(g_habilidad[id][CLASS_HUMAN][2]));
			set_pev(id, pev_gravity, Float:ArrayGetCell(g_zclass_grav, g_humanclass[id]) - ammount_hgravity(g_habilidad[id][CLASS_HUMAN][4]))
			ArrayGetString(g_zclass_model, g_humanclass[id], buffer, charsmax(buffer))
			cs_set_user_model(id, buffer)

			//ExecuteForward(g_fwUserHumanized_post, g_fwDummyResult, id, 0)//fixed gg
		}
		else
		{
			// Set health and gravity
			set_user_health(id, get_pcvar_num(cvar_humanhp) + ammount_hhealth(g_habilidad[id][CLASS_HUMAN][1]))
			set_user_armor(id, ammount_harmor(g_habilidad[id][CLASS_HUMAN][2]));
			set_pev(id, pev_gravity, get_pcvar_float(cvar_humangravity) - ammount_hgravity(g_habilidad[id][CLASS_HUMAN][4]))
			formatex(g_playermodel[id], charsmax(g_playermodel[]), "%s", szHuman);
			cs_set_user_model(id, szHuman)
		}
		ExecuteForward(g_fwUserHumanized_post, g_fwDummyResult, id, 0)//fixed gg

		if (get_pcvar_num(cvar_nvggive))
		{
			g_nvision[id] = true
			
			if (!g_isbot[id])
			{
				// Turn on Night Vision automatically?
				if (get_pcvar_num(cvar_nvggive) == 1)
				{
					// Custom nvg?
					if (get_pcvar_num(cvar_customnvg))
					{
						g_nvisionenabled[id] = true
						remove_task(id+TASK_NVISION)
						off(id)
						set_task(0.1, "set_user_nvision", id+TASK_NVISION, _, _, "b")
					}
				}
				// Turn off nightvision when infected (bugfix)
				else if (g_nvisionenabled[id])
				{
					if (get_pcvar_num(cvar_customnvg)) {
						remove_task(id+TASK_NVISION); 
						off(id);
					}
					g_nvisionenabled[id] = false
				}
			}
		}
		// Disable nightvision when infected (bugfix)
		else if (g_nvision[id])
		{
			if (get_pcvar_num(cvar_customnvg)) {
				remove_task(id+TASK_NVISION); 
				off(id);
			}
			
			g_nvision[id] = false
			g_nvisionenabled[id] = false
		}
	}
		
	
	// Switch to CT if spawning mid-round
	if (!g_newround && fm_cs_get_user_team(id) != FM_CS_TEAM_CT) // need to change team?
	{
		remove_task(id+TASK_TEAM)
		fm_cs_set_user_team(id, FM_CS_TEAM_CT)
		fm_user_team_update(id)
	}
	
	// Remove glow
	set_user_rendering(id)
	
	// Enable spawn protection for humans spawning mid-round
	if (!g_newround && get_pcvar_float(cvar_spawnprotection) > 0.0)
	{
		// Do not take damage
		g_nodamage[id] = true
		
		// Make temporarily invisible
		set_pev(id, pev_effects, pev(id, pev_effects) | EF_NODRAW)
		
		// Set task to remove it
		set_task(get_pcvar_float(cvar_spawnprotection), "remove_spawn_protection", id+TASK_SPAWN)
	}
	
	// Replace weapon models (bugfix)
	static weapon_ent
	weapon_ent = fm_cs_get_current_weapon_ent(id)
	if (pev_valid(weapon_ent)) replace_weapon_models(id, cs_get_weapon_id(weapon_ent))
	
	// Last Zombie Check
	fnCheckLastZombie()
}

// Ham Player Killed Forward
public fw_PlayerKilled(victim, attacker, shouldgib)
{
	// Player killed
	g_isalive[victim] = false
	g_iJumpingNadeCount[ victim ] = 0;
	g_iNoJump[ victim ] = 0;
	
	// Enable dead players nightvision
	set_task(0.1, "spec_nvision", victim)
	
	// Disable nightvision when killed (bugfix)
	if (get_pcvar_num(cvar_nvggive) == 0 && g_nvision[victim])
	{
		if (get_pcvar_num(cvar_customnvg)) 
		{
			remove_task(victim+TASK_NVISION); 
			off(victim);
		}
		
		g_nvision[victim] = false
		g_nvisionenabled[victim] = false
	}
	
	// Turn off nightvision when killed (bugfix)
	if (get_pcvar_num(cvar_nvggive) == 2 && g_nvision[victim] && g_nvisionenabled[victim])
	{
		if (get_pcvar_num(cvar_customnvg)) 
		{
			remove_task(victim+TASK_NVISION); 
			off(victim);
		}
		
		g_nvisionenabled[victim] = false
	}

	if(g_has_speed_boost[victim])
	{
		g_has_speed_boost[victim] = false
		remove_task(victim+TASK_SPEED_BOOST)
	}
	
	// Stop bleeding/burning/aura when killed
	if (g_class[victim] >= ZOMBIE)
	{
		remove_task(victim+TASK_BLOOD)
		remove_task(victim+TASK_BURN)
		remove_task(victim+TASK_DROGA);

		get_user_origin( victim, g_fOrigin[ victim ] );
	}
	
	// Nemesis explodes!
	if (g_class[victim] >= NEMESIS)
		SetHamParamInteger(3, 2)

	// Get deathmatch mode status and whether the player killed himself
	static selfkill
	selfkill = (victim == attacker || !is_user_valid_connected(attacker)) ? true : false

	if(fnGetHumans() > 1)
	{
		if(g_class[victim] == ZOMBIE && g_currentmode <= MODE_MULTI)
		{
			g_respawn_as_zombie[victim] = true
			set_task(get_pcvar_float(cvar_spawndelay), "respawn_player_task", victim+TASK_SPAWN)
		}
	}
	
	// Killed by a non-player entity or self killed
	if (selfkill) return;
	
	// Ignore Nemesis/Survivor Frags?
	if (g_class[attacker] >= SURVIVOR)
		RemoveFrags(attacker, victim)
	
	// Zombie/nemesis killed human, reward ammo packs
	if (g_class[attacker] >= ZOMBIE)
	{
		if(g_iLevel[attacker] <= 20) SetExp(attacker, 6);
		else SetExp(attacker, 2);
		g_ammopacks[attacker] += (get_pcvar_num(cvar_ammoinfect) * g_iMultiplicador[attacker][ 1 ] * g_steamBonus[attacker]);
	}
	
	// Human killed zombie, add up the extra frags for kill
	if (g_class[attacker] == HUMAN && get_pcvar_num(cvar_fragskill) > 1)
		UpdateFrags(attacker, victim, get_pcvar_num(cvar_fragskill) - 1, 0, 0)
	
	// Zombie killed human, add up the extra frags for kill
	if (g_class[attacker] == ZOMBIE && get_pcvar_num(cvar_fragsinfect) > 1)
		UpdateFrags(attacker, victim, get_pcvar_num(cvar_fragsinfect) - 1, 0, 0)
}

// Ham Player Killed Post Forward
public fw_PlayerKilled_Post()
{
	// Last Zombie Check
	fnCheckLastZombie()
}
// Ham Take Damage Forward
public fw_TakeDamage(victim, inflictor, attacker, Float:damage, damage_type)
{
	if(damage_type & DMG_FALL)
        return HAM_SUPERCEDE

	// Non-player damage or self damage
	if (victim == attacker || !is_user_valid_connected(attacker))
		return HAM_IGNORED;
	
	// New round starting or round ended
	if (g_newround || g_endround)
		return HAM_SUPERCEDE;
	
	// Victim shouldn't take damage or victim is frozen
	if (g_nodamage[victim])
		return HAM_SUPERCEDE;
	
	// Prevent friendly fire
	if (g_class[attacker] >= ZOMBIE && g_class[victim] >= ZOMBIE)
		return HAM_SUPERCEDE;
	
	if( get_user_team(attacker) == get_user_team(victim) )
		return HAM_SUPERCEDE;

	// Attacker is human...
	if ( g_class[attacker] < ZOMBIE )
	{
		if(get_user_weapon(attacker) == CSW_HEGRENADE && (damage_type & DMG_HEGRENADE))
			SetHamParamFloat(4, get_pcvar_float(cvar_damageHE))

		g_iDamage[attacker] += floatround(damage);
		g_tempDamage[attacker] += floatround(damage);

		while(g_iDamage[attacker] >= g_iDefaultDamage)
		{
		    g_iDamage[attacker] -= g_iDefaultDamage;
		
		    SetExp(attacker, get_pcvar_num(cvar_exp));
		}
		
		switch(g_class[attacker])
		{
			case SURVIVOR:
			{
				if(get_user_weapon(attacker) == CSW_M249)
				{
					damage *= get_pcvar_float(cvar_survidamage);
					SetHamParamFloat(4, damage);
				}
			}
			case SNIPER:
			{
				if(get_user_weapon(attacker) == CSW_AWP)
				{
					damage *= get_pcvar_float(cvar_sniperdamage);
					SetHamParamFloat(4, damage);
				}
			}
			case WESKER:
			{
				if(get_user_weapon(attacker) == CSW_DEAGLE)
				{
					damage *= get_pcvar_float(cvar_weskerdamage);
					SetHamParamFloat(4, damage);
				}
			}
			case NINJA:
			{
				if(get_user_weapon(attacker) == CSW_KNIFE)
				{
					new button = pev(attacker, pev_button);
					if (button & IN_ATTACK2)
					{
						damage = get_pcvar_float(cvar_ninjadamage);
						SetHamParamFloat(4, damage);
					}
					else
					{
						damage = get_pcvar_float(cvar_ninjadamage);
						SetHamParamFloat(4, (damage/4));
					}
				}
			}
			case HUMAN..LAST_HUMAN:
			{
				if(g_iBalasEspeciales[attacker] && (random_num(0, 8) == 7) && ~(damage_type & DMG_HEGRENADE))
				{
					switch(g_iBalasEspeciales[attacker])
					{
						case 1: freeze_player(victim);
					}
				}
			}
		}

		// Armor multiplier for the final damage on normal zombies
		if (g_class[victim] >= NEMESIS)
		{
			damage *= get_pcvar_float(cvar_zombiearmor)
			SetHamParamFloat(4, damage)
		}
		
		// Reward ammo packs
		if (g_class[attacker] < SURVIVOR)
		{
			damage *= ammount_hdamage(g_habilidad[attacker][CLASS_HUMAN][0]);
			// Store damage dealt
			g_damagedealt[attacker] += floatround(damage)
			if(is_user_connected(victim) && g_PartyData[attacker][In_Party])
			{
			    static Float:gametime; gametime = get_gametime();
			    static players[32], user; get_party_index(attacker, players );
			    static bWinAP; bWinAP = false;
			    
			    while(g_damagedealt[attacker] >= AmmoDamageReward)
			    {
			        g_damagedealt[attacker] -= AmmoDamageReward;
			        bWinAP = true;
			    }
				
			    for(new i; i < g_PartyData[attacker][Amount_In_Party]; i++) 
			    {
			        user = players[i];
			        
			        g_iComboPartyHits[user]++; // hits totales del party

			        if(bWinAP) g_iComboPartyAP[user]++; // asignamos un AP al combo.
			    
			        if(iComboTime[user] < gametime)
			        {
			            ShowPartyCombo(user, attacker, damage);
			            iComboTime[user] = gametime+0.1;
			        }
			    }
			}
			else
			{
				if(~(damage_type & DMG_HEGRENADE))
				{
					// Reward ammo packs for every [ammo damage] dealt
					while (g_damagedealt[attacker] > get_pcvar_num(cvar_ammodamage))
					{
						g_ammopacks[attacker] += (1* g_iMultiplicador[attacker][ 1 ] * g_steamBonus[attacker])
						g_tempApps[attacker] += (1* g_iMultiplicador[attacker][ 1 ])
						g_damagedealt[attacker] -= get_pcvar_num(cvar_ammodamage)
					}
				}	
			}
		}
		
		return HAM_IGNORED;
	}
	if (ZOMBIE <= g_class[attacker] <= LAST_ZOMBIE) {
		SetHamParamFloat(4, damage *= ammount_zdamage(g_habilidad[attacker][CLASS_ZOMBIE][0]))
	}
        
	// Attacker is zombie...
	if (g_class[victim] >= SNIPER) 
		return HAM_IGNORED;

	// Prevent infection/damage by HE grenade (bugfix)
	if (damage_type & DMG_HEGRENADE)
		return HAM_SUPERCEDE;
	
	// Nemesis?
	if (g_class[attacker] >= NEMESIS)
	{
		// Ignore nemesis damage override if damage comes from a 3rd party entity
		// (to prevent this from affecting a sub-plugin's rockets e.g.)
		if (inflictor == attacker)
		{
			// Set nemesis damage
			SetHamParamFloat(4, get_pcvar_float(cvar_nemdamage))
		}
		
		return HAM_IGNORED;
	}
	
	// Last human or not an infection round
	if (g_currentmode > MODE_MULTI || fnGetHumans() == 1)
		return HAM_IGNORED; // human is killed
	
	// Does human armor need to be reduced before infecting?
	if (get_pcvar_num(cvar_humanarmor))
	{
		// Get victim armor
		static Float:armor
		pev(victim, pev_armorvalue, armor)
		
		// Block the attack if he has some
		if (armor > 0.0)
		{
			emit_sound(victim, CHAN_BODY, sound_armorhit, 1.0, ATTN_NORM, 0, PITCH_NORM)
			set_pev(victim, pev_armorvalue, floatmax(0.0, armor - damage))
			return HAM_SUPERCEDE;
		}
	}
	
	// Infection allowed
	zombieme(victim, attacker, 0, 0, 1) // turn into zombie
	return HAM_SUPERCEDE;
}

// Ham Take Damage Post Forward
public fw_TakeDamage_Post(victim)
{
	// --- Check if victim should be Pain Shock Free ---
	if (g_class[victim] >= ZOMBIE)
	{
		if (g_class[victim] == NEMESIS)
		{
			if (!get_pcvar_num(cvar_nempainfree)) return;
			else if (!get_pcvar_num(cvar_alienpainfree)) return;
		}
		else
		{
			switch (get_pcvar_num(cvar_zombiepainfree))
			{
				case 0: return;
				case 2: if (g_class[victim] != LAST_ZOMBIE) return;
				case 3: if (g_class[victim] != FIRST_ZOMBIE) return;
			}
		}
	}
	else
	{
		if (g_class[victim] == SNIPER)
	    {
	        if (!get_pcvar_num(cvar_sniperpainfree)) return;
	    }
		else if (g_class[victim] == WESKER)
	    {
	        if (!get_pcvar_num(cvar_weskerpainfree)) return;
	    }
		else if (g_class[victim] == SIRIO)
		{
			if (!get_pcvar_num(cvar_siriopainfree)) return;
		}
		else if (g_class[victim] == NINJA)
		{
			if (!get_pcvar_num(cvar_ninjapainfree)) return;
		}
		else if (g_class[victim] == SURVIVOR)
		{
			if (!get_pcvar_num(cvar_survpainfree)) return;
		}
		
		else return;
	}
	
	
	// Set pain shock free offset
	set_pdata_float(victim, OFFSET_PAINSHOCK, 1.0, OFFSET_LINUX)
}

// Ham Reset MaxSpeed Post Forward
public fw_ResetMaxSpeed_Post(id)
{
	// Freezetime active or player not alive
	if (g_freezetime || !g_isalive[id])
		return;
	
	set_player_maxspeed(id)
}
set_player_maxspeed(id)
{
	// If frozen, prevent from moving
	if (g_frozen[id])
	{
		set_pev(id, pev_maxspeed, 1.0)
	}
	// Otherwise, set maxspeed directly
	else
	{
		if (g_class[id] >= ZOMBIE)
		{
			if (g_class[id] >= NEMESIS)
				set_pev(id, pev_maxspeed, g_cached_nemspd)
			else if (g_class[id] == ALIEN)
				set_pev(id, pev_maxspeed, cvar_alienspd)
			else
				set_pev(id, pev_maxspeed, g_zombie_spd[id] + float(ammount_zspeed(g_habilidad[id][CLASS_ZOMBIE][2])))
		}
		else
		{
			if (g_class[id] == SNIPER)
    			set_pev(id, pev_maxspeed, get_pcvar_float(cvar_sniperspd));
			else if (g_class[id] == WESKER)
    			set_pev(id, pev_maxspeed, get_pcvar_float(cvar_weskerspd));
			else if (g_class[id] == SIRIO)
    			set_pev(id, pev_maxspeed, get_pcvar_float(cvar_siriospd));
			else if (g_class[id] == NINJA)
    			set_pev(id, pev_maxspeed, get_pcvar_float(cvar_ninjaspd));
			else if (g_class[id] >= SURVIVOR)
				set_pev(id, pev_maxspeed, g_cached_survspd)
			else
			{
				if(g_humanclass[id] != ZCLASS_NONE)
					set_pev(id, pev_maxspeed, g_human_spd[id] + float(ammount_hspeed(g_habilidad[id][CLASS_HUMAN][3])))
				else
					set_pev(id, pev_maxspeed, g_cached_humanspd + float(ammount_hspeed(g_habilidad[id][CLASS_HUMAN][3])))
			}

			if(g_has_speed_boost[id])
			{
				new Float:current_maxspeed;
				pev(id, pev_maxspeed, current_maxspeed);
				set_pev(id, pev_maxspeed, current_maxspeed + get_pcvar_float(cvar_boost_amount));
			}
		}
	}
}
// Ham Trace Attack Forward
public fw_TraceAttack(victim, attacker, Float:damage, Float:direction[3], tracehandle, damage_type)
{
	// Non-player damage or self damage
	if (victim == attacker || !is_user_valid_connected(attacker))
		return HAM_IGNORED;
	
	// New round starting or round ended
	if (g_newround || g_endround)
		return HAM_SUPERCEDE;
	
	// Victim shouldn't take damage or victim is frozen
	if (g_nodamage[victim])
		return HAM_SUPERCEDE;
	
	// Prevent friendly fire
	if (g_class[attacker] >= ZOMBIE && g_class[victim] >= ZOMBIE)
		return HAM_SUPERCEDE;
	
	// Victim isn't a zombie or not bullet damage, nothing else to do here
	if (g_class[victim] < ZOMBIE || !(damage_type & DMG_BULLET))
		return HAM_IGNORED;
	if( get_user_team(attacker) == get_user_team(victim) )
		return HAM_SUPERCEDE;
		
	// If zombie hitzones are enabled, check whether we hit an allowed one
	if (get_pcvar_num(cvar_hitzones) && g_class[victim] < NEMESIS && !(get_pcvar_num(cvar_hitzones) & (1<<get_tr2(tracehandle, TR_iHitgroup))))
		return HAM_SUPERCEDE;
	
	// Knockback disabled, nothing else to do here
	if (!get_pcvar_num(cvar_knockback))
		return HAM_IGNORED;
	
	// Nemesis knockback disabled, nothing else to do here
	if (g_class[victim] >= NEMESIS && get_pcvar_float(cvar_nemknockback) == 0.0)
		return HAM_IGNORED;
	
	// Get whether the victim is in a crouch state
	static ducking
	ducking = pev(victim, pev_flags) & (FL_DUCKING | FL_ONGROUND) == (FL_DUCKING | FL_ONGROUND)
	
	// Zombie knockback when ducking disabled
	if (ducking && get_pcvar_float(cvar_knockbackducking) == 0.0)
		return HAM_IGNORED;
	
	// Get distance between players
	static origin1[3], origin2[3]
	get_user_origin(victim, origin1)
	get_user_origin(attacker, origin2)
	
	// Max distance exceeded
	if (get_distance(origin1, origin2) > get_pcvar_num(cvar_knockbackdist))
		return HAM_IGNORED;
	
	// Get victim's velocity
	static Float:velocity[3]
	pev(victim, pev_velocity, velocity)
	
	// Use damage on knockback calculation
	if (get_pcvar_num(cvar_knockbackdamage))
		xs_vec_mul_scalar(direction, damage, direction)
	
	// Use weapon power on knockback calculation
	if (get_pcvar_num(cvar_knockbackpower) && kb_weapon_power[g_currentweapon[attacker]] > 0.0)
		xs_vec_mul_scalar(direction, kb_weapon_power[g_currentweapon[attacker]], direction)
	
	// Apply ducking knockback multiplier
	if (ducking)
		xs_vec_mul_scalar(direction, get_pcvar_float(cvar_knockbackducking), direction)
	
	// Apply zombie class/nemesis knockback multiplier
	if (g_class[victim] >= NEMESIS)
		xs_vec_mul_scalar(direction, get_pcvar_float(cvar_nemknockback), direction)
	else
		xs_vec_mul_scalar(direction, g_zombie_knockback[victim], direction)
	
	// Add up the new vector
	xs_vec_add(velocity, direction, direction)
	
	// Should knockback also affect vertical velocity?
	if (!get_pcvar_num(cvar_knockbackzvel))
		direction[2] = velocity[2]
	
	// Set the knockback'd victim's velocity
	set_pev(victim, pev_velocity, direction)
	
	return HAM_IGNORED;
}
public make_tracer(victim, attacker, Float:damage, Float:direction[3], tracehandle, damage_type)
{
	if (victim == attacker || !is_user_valid_connected(attacker))
		return HAM_IGNORED;

	if(get_user_weapon(attacker) == CSW_M249 && g_class[attacker] == SURVIVOR) 
	{
		new Float:vecEndPos[3] 
		get_tr2(tracehandle, TR_vecEndPos, vecEndPos) 

		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecEndPos, 0) 
		write_byte(TE_BEAMENTPOINT) 
		write_short(attacker | 0x1000) 
		engfunc(EngFunc_WriteCoord, vecEndPos[0]) // x 
		engfunc(EngFunc_WriteCoord, vecEndPos[1]) // x 
		engfunc(EngFunc_WriteCoord, vecEndPos[2]) // x 
		write_short(m_spriteTexture) 
		write_byte(0) // framerate 
		write_byte(0) // framerate 
		write_byte(1) // framerate 
		write_byte(225) // framerate 
		write_byte(0) // framerate 
		write_byte(random_num(10,225))
		write_byte(random_num(100,125))
		write_byte(random_num(50,205))
		write_byte(228) // brightness 
		write_byte(0) // brightness 
		message_end() 
	}
	return HAM_HANDLED
}
// Ham Use Stationary Gun Forward
public fw_UseStationary(entity, caller, activator, use_type)
{
	// Prevent zombies from using stationary guns
	if (use_type == USE_USING && is_user_valid_connected(caller) && g_class[caller] >= ZOMBIE)
		return HAM_SUPERCEDE;
	
	return HAM_IGNORED;
}

// Ham Use Stationary Gun Post Forward
public fw_UseStationary_Post(entity, caller, activator, use_type)
{
	// Someone stopped using a stationary gun
	if (use_type == USE_STOPPED && is_user_valid_connected(caller))
		replace_weapon_models(caller, g_currentweapon[caller]) // replace weapon models (bugfix)
}

// Ham Use Pushable Forward
public fw_UsePushable()
{
	// Prevent speed bug with pushables?
	if (get_pcvar_num(cvar_blockpushables))
		return HAM_SUPERCEDE;
	
	return HAM_IGNORED;
}
public touch_bubble(touched, toucher)
{
	if( !is_valid_ent(touched) || !is_user_valid_alive(toucher) )
		return;

	if( g_class[toucher] >= ZOMBIE )
	{
		new Float:pos_ptr[3], Float:pos_ptd[3];

		pev(touched, pev_origin, pos_ptr);
		pev(toucher, pev_origin, pos_ptd);

		xs_vec_sub( pos_ptd, pos_ptr, pos_ptd );
		xs_vec_mul_scalar( pos_ptd, 4.0, pos_ptd );

		set_pev(toucher, pev_velocity, pos_ptd);
		set_pev(toucher, pev_impulse, pos_ptd);

		set_task(0.4, "freeze_player", toucher);
	}
}

public touch_trigger_hurt(iEnt, id)
{
	if(is_user_alive(id))
	{
		if(g_bTouchExplote && entity_get_float(iEnt, EV_FL_dmg) > 20000.0)
		{
			g_iExplode = 90;

			g_iExplote[id] = 1;
			user_silentkill(id);

			if(!task_exists(BLAST_TASK))
			{
				remove_task(BLAST_TASK);
				set_task(1.0, "fnExplote", BLAST_TASK, _, _, "b");
			}	
		}
	}
	return PLUGIN_CONTINUE;
}
public fnExplote()
{
	if(!g_iExplode)
	{
		remove_task(BLAST_TASK);
		set_task(0.8, "task_launch", BLAST_TASK);
		set_task(2.5, "task_blast", BLAST_TASK);
		return;
	}
	set_dhudmessage(random_num(57, 255), random_num(0, 255), random_num(0, 255), HUD_EVENT_X, HUD_EVENT_Y, 0, 6.0, 0.001, 0.1, 1.0);
	show_dhudmessage(0, "/----------------------------------------\^n| Umbrella Explotara en %d |^n\----------------------------------------/", g_iExplode);
	--g_iExplode;
}
public task_launch()
{
    // Screen fade effect
    message_begin(MSG_BROADCAST, g_msgScreenFade)
    write_short((1<<12)*4)    // Duration
    write_short((1<<12)*1)    // Hold time
    write_short(0x0001)    // Fade type
    write_byte (255)    // Red
    write_byte (255)    // Green
    write_byte (255)    // Blue
    write_byte (255)    // Alpha
    message_end()
}

public task_blast()
{
	static id, deathmsg_block
	// Get current blocking state of the deathmsg
	deathmsg_block = get_msg_block(g_msgDeathMsg)

	// Set it to blocked
	set_msg_block(g_msgDeathMsg, BLOCK_SET)

	// "Eliminate" players
	for (id = 1; id <= g_maxplayers; id++)
	    if (is_user_alive(id) && g_class[id] >= ZOMBIE)
	        user_kill(id, 1);

	// Set the previous blocking state
	set_msg_block(g_msgDeathMsg, deathmsg_block)
} 
// Ham Weapon Touch Forward
public fw_TouchWeapon(weapon, id)
{
	// Not a player
	if (!is_user_valid_connected(id))
		return HAM_IGNORED;
	
	// Dont pickup weapons if zombie or survivor (+PODBot MM fix)
	if (g_class[id] >= SURVIVOR)
		return HAM_SUPERCEDE;
	
	return HAM_SUPERCEDE;//HAM_IGNORED
}

// Ham Weapon Pickup Forward
public fw_AddPlayerItem(id, weapon_ent)
{
	// HACK: Retrieve our custom extra ammo from the weapon
	static extra_ammo
	extra_ammo = pev(weapon_ent, PEV_ADDITIONAL_AMMO)
	
	// If present
	if (extra_ammo)
	{
		// Get weapon's id
		static weaponid
		weaponid = cs_get_weapon_id(weapon_ent)
		
		// Add to player's bpammo
		ExecuteHamB(Ham_GiveAmmo, id, extra_ammo, AMMOTYPE[weaponid], MAXBPAMMO[weaponid])
		set_pev(weapon_ent, PEV_ADDITIONAL_AMMO, 0)
	}
}

// Ham Weapon Deploy Forward
public fw_Item_Deploy_Post(weapon_ent)
{
	// Get weapon's owner
	static owner
	owner = fm_cs_get_weapon_ent_owner(weapon_ent)
	
	// Get weapon's id
	static weaponid
	weaponid = cs_get_weapon_id(weapon_ent)
	
	// Store current weapon's id for reference
	g_currentweapon[owner] = weaponid
	
	// Replace weapon models with custom ones
	replace_weapon_models(owner, weaponid)
	
	// Zombie not holding an allowed weapon for some reason
	if (g_class[owner] >= ZOMBIE && !((1<<weaponid) & ZOMBIE_ALLOWED_WEAPONS_BITSUM))
	{
		// Switch to knife
		g_currentweapon[owner] = CSW_KNIFE
		engclient_cmd(owner, "weapon_knife")
	}
}

// WeaponMod bugfix
//forward wpn_gi_reset_weapon(id);
public wpn_gi_reset_weapon(id)
{
	// Replace knife model
	replace_weapon_models(id, CSW_KNIFE)
}

public client_disconnected(id)
{
	if( g_iStatus[ id ] == LOGUEADO )
	{
		guardar_datos( id );
		g_iStatus[ id ] = NO_LOGUEADO;
	}
	

	if(g_PartyData[id][In_Party])
    	g_PartyData[id][Position] ? g_PartyData[id][Amount_In_Party] > 1 ? destoy_party(id) : remove_party_user(id) : destoy_party(id)
        
	g_PartyData[id][UserName][0] = 0
	g_PartyData[id][Block_Party] = false

	// COMBOLAS
	g_has_speed_boost[id] = false
	remove_task(id+TASK_SPEED_BOOST);
	remove_task(id+TASK_FINISH_COMBO);
	g_damagedealt[id] = 0;
	g_iComboPartyHits[id] = 0;
	g_iComboPartyAP[id] = 0;
	iComboTime[id] = 0.0;
	g_iNoJump[id] = 0;
	ClearSyncHud(id, g_MsgSyncParty);
}
// Client joins the game
public client_putinserver(id)
{
	// Plugin disabled?
	if (!g_pluginenabled) return;

	g_puntos[id][CLASS_HUMAN] = 10000;
	g_puntos[id][CLASS_ZOMBIE] = 10000;
	// Player joined
	g_isconnected[id] = true
	g_iStatus[id] = NO_LOGUEADO;
	
	// Cache player's name
	get_user_name(id, g_playername[id], charsmax(g_playername[]))

	g_szTag[id][0] = EOS;

	g_iMultiplicador[id][ 0 ] = 1;
	g_iMultiplicador[id][ 1 ] = 1;

	g_bAutoSeleccion[id] = false;
	g_iCategoria[id] = 0;

	for(new i = PRIMARIA; i < MAX_ARMS; ++i)
		g_iSelected[id][i] = get_rdnWeapon(id, i);

	g_fRecord[ id ] = 999.99;
	g_touched[ id ] = false;
	g_iSkinsEnable[ id ] = true;
	g_fTiempo[ id ] = 0.0;
	g_currencyTime[ id ] = 0.0;
	g_iCanKill[ id ] = 0;
	g_iGranada[ id ] = 0;
	g_iNoFrost[ id ] = g_iNoPipe[ id ] = g_iNoFire[ id ] = 0;
	jumpnum[id] = 0;
	dojump[id] = false;
	g_iJumpClass[ id ] = 0;
	g_iNoDroga[ id ] = 0;
	g_iNoJump[ id ] = 0;
	g_iFisher[ id ] = 0;
	g_iGhost[ id ] = 0;
	g_iEscapes[ id ] = 0;
	g_iJumpingNadeCount [ id ] = 0;
	// Initialize player vars
	reset_vars(id, 1)
	
	// Set some tasks for humans only
	if (is_user_bot(id))
	{
		// Set bot flag
		g_isbot[id] = true
		
		// CZ bots seem to use a different "classtype" for player entities
		// (or something like that) which needs to be hooked separately
		if (!g_hamczbots && cvar_botquota)
		{
			// Set a task to let the private data initialize
			set_task(0.1, "register_ham_czbots", id)
		}
	}
}

// Client leaving
public fw_ClientDisconnect(id)
{
	// Check that we still have both humans and zombies to keep the round going
	if (g_isalive[id]) check_round(id)
	
	// Remove previous tasks
	remove_task(id+TASK_TEAM);
	remove_task(id+TASK_SPAWN);
	remove_task(id+TASK_BLOOD);
	remove_task(id+TASK_DROGA);
	remove_task(id+TASK_BURN);
	remove_task(id+TASK_NVISION);
	remove_task(id+TASK_SHOWHUD);
	
	// Player left, clear cached flags
	g_isconnected[id] = false
	g_isbot[id] = false
	g_isalive[id] = false

	off(id);
}

// Client left
public fw_ClientDisconnect_Post()
{
	// Last Zombie Check
	fnCheckLastZombie()
}

// Client Kill Forward
public fw_ClientKill()
{
	// Prevent players from killing themselves?
	if (get_pcvar_num(cvar_blocksuicide))
		return FMRES_SUPERCEDE;
	
	return FMRES_IGNORED;
}

// Emit Sound Forward
public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	// Block all those unneeeded hostage sounds
	if (sample[0] == 'h' && sample[1] == 'o' && sample[2] == 's' && sample[3] == 't' && sample[4] == 'a' && sample[5] == 'g' && sample[6] == 'e')
		return FMRES_SUPERCEDE;
	
	// Replace these next sounds for zombies only
	if (!is_user_valid_connected(id) || g_class[id] < ZOMBIE)
		return FMRES_IGNORED;
	
	static sound[64]
	
	// Zombie being hit
	if (sample[7] == 'b' && sample[8] == 'h' && sample[9] == 'i' && sample[10] == 't')
	{
		if (g_class[id] >= NEMESIS)
		{
			ArrayGetString(nemesis_pain, random_num(0, ArraySize(nemesis_pain) - 1), sound, charsmax(sound))
			emit_sound(id, channel, sound, volume, attn, flags, pitch)
		}
		else
		{
			ArrayGetString(zombie_pain, random_num(0, ArraySize(zombie_pain) - 1), sound, charsmax(sound))
			emit_sound(id, channel, sound, volume, attn, flags, pitch)
		}
		return FMRES_SUPERCEDE;
	}
	
	// Zombie attacks with knife
	if (sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
	{
		if (sample[14] == 's' && sample[15] == 'l' && sample[16] == 'a') // slash
		{
			ArrayGetString(zombie_miss_slash, random_num(0, ArraySize(zombie_miss_slash) - 1), sound, charsmax(sound))
			emit_sound(id, channel, sound, volume, attn, flags, pitch)
			return FMRES_SUPERCEDE;
		}
		if (sample[14] == 'h' && sample[15] == 'i' && sample[16] == 't') // hit
		{
			if (sample[17] == 'w') // wall
			{
				ArrayGetString(zombie_miss_wall, random_num(0, ArraySize(zombie_miss_wall) - 1), sound, charsmax(sound))
				emit_sound(id, channel, sound, volume, attn, flags, pitch)
				return FMRES_SUPERCEDE;
			}
			else
			{
				ArrayGetString(zombie_hit_normal, random_num(0, ArraySize(zombie_hit_normal) - 1), sound, charsmax(sound))
				emit_sound(id, channel, sound, volume, attn, flags, pitch)
				return FMRES_SUPERCEDE;
			}
		}
		if (sample[14] == 's' && sample[15] == 't' && sample[16] == 'a') // stab
		{
			ArrayGetString(zombie_hit_stab, random_num(0, ArraySize(zombie_hit_stab) - 1), sound, charsmax(sound))
			emit_sound(id, channel, sound, volume, attn, flags, pitch)
			return FMRES_SUPERCEDE;
		}
	}
	
	// Zombie dies
	if (sample[7] == 'd' && ((sample[8] == 'i' && sample[9] == 'e') || (sample[8] == 'e' && sample[9] == 'a')))
	{
		ArrayGetString(zombie_die, random_num(0, ArraySize(zombie_die) - 1), sound, charsmax(sound))
		emit_sound(id, channel, sound, volume, attn, flags, pitch)
		return FMRES_SUPERCEDE;
	}
	
	// Zombie falls off
	if (sample[10] == 'f' && sample[11] == 'a' && sample[12] == 'l' && sample[13] == 'l')
	{
		ArrayGetString(zombie_fall, random_num(0, ArraySize(zombie_fall) - 1), sound, charsmax(sound))
		emit_sound(id, channel, sound, volume, attn, flags, pitch)
		return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}

public client_PreThink(id)
{
    if(!is_user_alive(id)) 
        return PLUGIN_CONTINUE
    if(g_iJumpClass[id] <= 0 && g_iJumpClass2[id] <= 0)
        return PLUGIN_CONTINUE

    new nbut = get_user_button(id)
    new obut = get_user_oldbutton(id)
    if((nbut & IN_JUMP) && !(get_entity_flags(id) & FL_ONGROUND) && !(obut & IN_JUMP))
    {
        if(jumpnum[id] < 1 && g_iJumpClass2[id] || jumpnum[id] < 2 && g_iJumpClass[id])
        {
            dojump[id] = true
            jumpnum[id]++
            return PLUGIN_CONTINUE
        }
        
    }
    if((nbut & IN_JUMP) && (get_entity_flags(id) & FL_ONGROUND))
    {
        jumpnum[id] = 0
        return PLUGIN_CONTINUE
    }
    return PLUGIN_CONTINUE
}

public client_PostThink(id)
{
    if(!is_user_alive(id)) 
        return PLUGIN_CONTINUE

    if(g_iJumpClass[id] > 0 || g_iJumpClass2[id] > 0)
    {
        if(dojump[id] == true)
	    {
	        new Float:velocity[3]    
	        entity_get_vector(id,EV_VEC_velocity,velocity)
	        velocity[2] = random_float(265.0,285.0)
	        entity_set_vector(id,EV_VEC_velocity,velocity)
	        dojump[id] = false
	        return PLUGIN_CONTINUE
	    }
    }
    
	    
    return PLUGIN_CONTINUE
} 

public AddToFullPackPost(es, e, ent, host, hostflags, player, pSet)
{
    if (!player || !is_user_alive(host) || !is_user_valid_connected(host) || !get_pcvar_num(cvar_modes))
        return FMRES_IGNORED;
    
    if(g_iGhost[ent])
    {
		if(get_user_team(host) != get_user_team(ent) && !g_iFisher[host])
		{
			set_es(es, ES_RenderMode, kRenderTransTexture);
			set_es(es, ES_RenderAmt, 7);
		}
    }
    
    return FMRES_IGNORED;
} 

// Forward Set ClientKey Value -prevent CS from changing player models-
public fw_SetClientKeyValue(id, const infobuffer[], const key[])
{
	// Block CS model changes
	if (key[0] == 'm' && key[1] == 'o' && key[2] == 'd' && key[3] == 'e' && key[4] == 'l')
		return FMRES_SUPERCEDE;
	
	return FMRES_IGNORED;
}

// Forward Client User Info Changed -prevent players from changing models-
public fw_ClientUserInfoChanged(id)
{
	if(!is_user_connected(id))
		return PLUGIN_CONTINUE;
		
	if( g_iStatus[ id ] != LOGUEADO )
		return PLUGIN_CONTINUE;
	// Cache player's name
	static name[ 32 ];
	get_user_info( id, "name", name, 31 );
	
	if( !equal( g_playername[ id ], name ) ) 
	{
		set_user_info( id, "name", g_playername[ id ] );	
		return PLUGIN_HANDLED;
	}
	
	//copy(g_playername[ id ], 31, name)
	//set_user_info( id, "name", g_playername[ id ] );
	return PLUGIN_CONTINUE;
}



// Forward Get Game Description
public fw_GetGameDescription()
{
	// Return the mod name so it can be easily identified
	forward_return(FMV_STRING, g_modname)
	
	return FMRES_SUPERCEDE;
}
public cmdRadio(id)
{
	if(!g_isconnected[id])
		return PLUGIN_HANDLED;

	static menu; menu = menu_create("Radio", "radio_handler");

	for(new i = 0; i < sizeof(szRadioX); ++i)
		menu_additem(menu, szRadioX[i][nameRadio]);
	
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public radio_handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	emit_sound(id, CHAN_VOICE, szRadioX[item][rutaRadio], 1.0, ATTN_NORM, 0, PITCH_NORM);

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
public bugRoundCt(id)
{
	if(get_user_flags(id) & ADMIN_IMMUNITY)
	{
		if(g_iTouched >= (fnGetHumans()/2))
		{
			remove_task(BLAST_TASK);
			set_task(0.8, "task_launch", BLAST_TASK);
			set_task(2.5, "task_blast", BLAST_TASK);
		}
		else
		{
			client_print(id, print_chat, "La mitad de los hms debe haber tocado la meta para este comando");
		}
	}	
}

public fw_Touch(ent, victim) 
{
    if (!pev_valid(ent))
        return FMRES_IGNORED;

    new EntClassName[32], szMapName[40], Float:time;
    entity_get_string(ent, EV_SZ_classname, EntClassName, charsmax(EntClassName));
    get_mapname(szMapName, 39);
        
    if(equal(EntClassName, g_szEnt) && is_user_alive(victim) && !g_touched[victim] && g_class[victim] < ZOMBIE /*&& iNumCheckRoundPl[victim] >= MaxCheckOnTheMap-1*/)
    {
		g_touched[victim] = true;
		time = g_currencyTime[victim];
		g_bTouchExplote = true;
		++g_iTouched;

		if(g_iLevel[victim] <= 20)
		{
			if(g_iTouched == 1) SetExp(victim, 24);
			else SetExp(victim, 14);
		}
		else
		{
			if(g_iTouched == 1) SetExp(victim, 20);
			else SetExp(victim, 12);
		} 		
		//set_user_coins(victim, get_user_coins(victim) + MoneyFinishCheck);

		if( get_pcvar_num( cvar_event ) && ( fnGetPlaying()-1 > 3 ) )
			++g_iEscapes[ victim ];
		
		if(g_fRecord[victim] > time)
		{
			new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];
			iData[ 0 ] = victim;
			iData[ 1 ] = GUARDAR_DATOS;

			formatex( szQuery, charsmax( szQuery ), "UPDATE %s SET Record='%f' WHERE id_user='%d' AND MapName = ^"%s^"", g_szTableRecord, time, g_id[ victim ], szMapName );
			SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );

			zp_colored_print(0, "^x4%s^x1 El player ^x4%s ^x1rompió su record de ^x4%.2f ^x1segundos por ^x4%.2f ^x1segundos.", g_szPrefix, g_playername[victim], g_fRecord[ victim ], (g_fRecord[ victim ]-time));
			g_fRecord[ victim ] = time;
		}
		else
		{
			zp_colored_print(victim, "^x4%s^x1 Tardaste ^x4%.2f^x1 segundos en llegar a la meta y tu ^x4record^x1 es de ^x4%.2f ^x1segundos", g_szPrefix, time, g_fRecord[ victim ]);
		}
    }
        
    return FMRES_IGNORED;
}
// Forward Set Model
public fw_SetModel(entity, const model[])
{
	// We don't care
	if (strlen(model) < 8)
		return;
	
	// Remove weapons?
	if (get_pcvar_float(cvar_removedropped) > 0.0)
	{
		// Get entity's classname
		static classname[10]
		pev(entity, pev_classname, classname, charsmax(classname))
		
		// Check if it's a weapon box
		if (equal(classname, "weaponbox"))
		{
			// They get automatically removed when thinking
			set_pev(entity, pev_nextthink, get_gametime() + get_pcvar_float(cvar_removedropped))
			return;
		}
	}
	
	// Narrow down our matches a bit
	if (model[7] != 'w' || model[8] != '_')
		return;
	
	// Get damage time of grenade
	static Float:dmgtime
	pev(entity, pev_dmgtime, dmgtime)
	
	// Grenade not yet thrown
	if (dmgtime == 0.0)
		return;
	// Get whether grenade's owner is a zombie
	if (g_class[pev(entity, pev_owner)] >= ZOMBIE)
	{
		if (model[9] == 'h' && model[10] == 'e') // Infection Bomb
		{
			// And a colored trail
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_BEAMFOLLOW) // TE id
			write_short(entity) // entity
			write_short(g_trailSpr) // sprite
			write_byte(10) // life
			write_byte(10) // width
			write_byte(0) // r
			write_byte(200) // g
			write_byte(0) // b
			write_byte(200) // brightness
			message_end()
			
			// Set grenade type on the thrown grenade entity
			set_pev(entity, PEV_NADE_TYPE, NADE_TYPE_INFECTION)
		}
		else if (model[9] == 's' && model[10] == 'm') // Flare
		{
			// And a colored trail
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_BEAMFOLLOW) // TE id
			write_short(entity) // entity
			write_short(g_trailSpr) // sprite
			write_byte(10) // life
			write_byte(10) // width
			write_byte(100) // r
			write_byte(200) // g
			write_byte(190) // b
			write_byte(200) // brightness
			message_end()

			set_pev ( entity, PEV_NADE_TYPE, NADE_TYPE_JUMPING );
			        
			g_iJumpingNadeCount [pev(entity, pev_owner)]--;
		}
	}
	else if (model[9] == 'h' && model[10] == 'e') // Napalm Grenade
	{
		if(g_iHe[pev(entity, pev_owner)] > 0)
		{
			// And a colored trail
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_BEAMFOLLOW) // TE id
			write_short(entity) // entity
			write_short(g_trailSpr) // sprite
			write_byte(10) // life
			write_byte(10) // width
			write_byte(200) // r
			write_byte(10) // g
			write_byte(60) // b
			write_byte(200) // brightness
			message_end()
			
			// Set grenade type on the thrown grenade entity
			set_pev(entity, PEV_NADE_TYPE, NADE_TYPE_HE)
			g_iHe[pev(entity, pev_owner)]--;
		}
		else 
		{
			// And a colored trail
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_BEAMFOLLOW) // TE id
			write_short(entity) // entity
			write_short(g_trailSpr) // sprite
			write_byte(10) // life
			write_byte(10) // width
			write_byte(200) // r
			write_byte(0) // g
			write_byte(0) // b
			write_byte(200) // brightness
			message_end()
			
			// Set grenade type on the thrown grenade entity
			set_pev(entity, PEV_NADE_TYPE, NADE_TYPE_NAPALM)
		}
			
	}
	else if (model[9] == 'f' && model[10] == 'l') // Frost Grenade
	{
		if(g_iDroga[pev(entity, pev_owner)] > 0)
		{
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_BEAMFOLLOW) 
			write_short(entity)
			write_short(g_trailSpr) 
			write_byte(10) 
			write_byte(10) 
			write_byte(250) 
			write_byte(0)  
			write_byte(250) 
			write_byte(200) 
			message_end()

			// Set grenade type on the thrown grenade entity
			set_pev(entity, PEV_NADE_TYPE, NADE_TYPE_DROGA)
			g_iDroga[pev(entity, pev_owner)]--;
		}
		else 
		{
			// And a colored trail
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_BEAMFOLLOW) // TE id
			write_short(entity) // entity
			write_short(g_trailSpr) // sprite
			write_byte(10) // life
			write_byte(10) // width
			write_byte(0) // r
			write_byte(100) // g
			write_byte(200) // b
			write_byte(200) // brightness
			message_end()
			
			// Set grenade type on the thrown grenade entity
			set_pev(entity, PEV_NADE_TYPE, NADE_TYPE_FROST)
		}
	}
	else if (model[9] == 's' && model[10] == 'm') // Flare
	{
		if(g_iPipe[pev(entity, pev_owner)])
		{
		    // And a colored trail
		    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		    write_byte(TE_BEAMFOLLOW) // TE id
		    write_short(entity) // entity
		    write_short(g_trailSpr) // sprite
		    write_byte(10) // life
		    write_byte(10) // width
		    write_byte(200) // r
		    write_byte(0) // g
		    write_byte(0) // b
		    write_byte(200) // brightness
		    message_end()
		    
		    // Set grenade type on the thrown grenade entity
		    set_pev(entity, PEV_NADE_TYPE, NADE_TYPE_PIPEBOMB)

		    g_iPipe[pev(entity, pev_owner)]--;
		} 
		else
		{
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
			write_byte(TE_BEAMFOLLOW);
			write_short(entity);
			write_short(g_trailSpr);
			write_byte(10);
			write_byte(10);
			write_byte(255);
			write_byte(255);
			write_byte(255);
			write_byte(200);
			message_end()

			set_pev(entity, pev_flTimeStepSound, NADE_TYPE_CAMPO);
		}	
	}
}

// Ham Grenade Think Forward
public fw_ThinkGrenade(entity)
{
	// Invalid entity
	if (!pev_valid(entity)) return HAM_IGNORED;
	
	// Get damage time of grenade
	static Float:dmgtime, Float:current_time;
	pev(entity, pev_dmgtime, dmgtime);
	current_time = get_gametime();

	// Check if it's time to go off
	if (dmgtime > current_time)
		return HAM_IGNORED;
	
	// Check if it's one of our custom nades
	switch (pev(entity, PEV_NADE_TYPE))
	{
		case NADE_TYPE_INFECTION: // Infection Bomb
		{
			infection_explode(entity)
			return HAM_SUPERCEDE;
		}
		case NADE_TYPE_NAPALM: // Napalm Grenade
		{
			fire_explode(entity)
			return HAM_SUPERCEDE;
		}
		case NADE_TYPE_FROST: // Frost Grenade
		{
			frost_explode(entity)
			return HAM_SUPERCEDE;
		}
		case NADE_TYPE_CAMPO: // Flare
		{
			bubble_explode(entity);
			return HAM_SUPERCEDE;
		}
		case NADE_TYPE_PIPEBOMB:
		{
		    set_task(0.1, "hook", entity, _, _, "a", 15); 
		    set_task(1.5, "deleteGren", entity) 
		 
		    new Float:originF[3] 
		    pev(entity, pev_origin, originF); 
		 
		    light(originF) 
		    return HAM_SUPERCEDE;
		} 
		case NADE_TYPE_DROGA:
		{
			droga_explode(entity);
			return HAM_SUPERCEDE;
		}
		case NADE_TYPE_JUMPING:
		{
			jumping_explode( entity );
			return HAM_SUPERCEDE;
		}
	}
	
	return HAM_IGNORED;
}

public cmdBlock_linterna(id)
{
	client_print(id, print_center, "La linterna se encuentra desactivada");
	return PLUGIN_HANDLED;
}
// Forward Player PreThink
public fw_PlayerPreThink(id)
{
	// Not alive
	if (!g_isalive[id])
		return;
	
	// Silent footsteps for zombies?
	if (g_cached_zombiesilent && g_class[id] >= ZOMBIE && g_class[id] < NEMESIS)
		set_pev(id, pev_flTimeStepSound, STEPTIME_SILENT)
	


	// Set Player MaxSpeed
	if (g_frozen[id])
	{
		set_pev(id, pev_velocity, Float:{0.0,0.0,0.0}) // stop motion
		set_pev(id, pev_maxspeed, 1.0) // prevent from moving
		return; // shouldn't leap while frozen
	}
	if (g_freezetime)
	{
		return; // shouldn't leap while in freezetime
	}
	// --- Check if player should leap ---
	
	// Check if proper CVARs are enabled and retrieve leap settings
	static Float:cooldown, Float:current_time
	if (g_class[id] >= ZOMBIE)
	{
		if (g_class[id] >= NEMESIS)
		{
			if (!g_cached_leapnemesis) return;
			cooldown = g_cached_leapnemesiscooldown
		}
		else
		{
			switch (g_cached_leapzombies)
			{
				case 0: return;
				case 2: if (g_class[id] != FIRST_ZOMBIE) return;
				case 3: if (g_class[id] != LAST_ZOMBIE) return;
			}
			cooldown = g_cached_leapzombiescooldown
		}
	}
	else
	{
		if (g_class[id] >= SURVIVOR)
		{
			if (!g_cached_leapsurvivor) return;
			cooldown = g_cached_leapsurvivorcooldown
		}
		else return;
	}
	
	current_time = get_gametime()
	
	// Cooldown not over yet
	if (current_time - g_lastleaptime[id] < cooldown)
		return;
	
	// Not doing a longjump (don't perform check for bots, they leap automatically)
	if (!g_isbot[id] && !(pev(id, pev_button) & (IN_JUMP | IN_DUCK) == (IN_JUMP | IN_DUCK)))
		return;
	
	// Not on ground or not enough speed
	if (!(pev(id, pev_flags) & FL_ONGROUND) || fm_get_speed(id) < 80)
		return;
	
	static Float:velocity[3]
	
	// Make velocity vector
	velocity_by_aim(id, g_class[id] >= SURVIVOR && g_class[id] < ZOMBIE ? get_pcvar_num(cvar_leapsurvivorforce) : g_class[id] >= NEMESIS ? get_pcvar_num(cvar_leapnemesisforce) : get_pcvar_num(cvar_leapzombiesforce), velocity)
	
	// Set custom height
	velocity[2] = g_class[id] >= SURVIVOR && g_class[id] < ZOMBIE ? get_pcvar_float(cvar_leapsurvivorheight) : g_class[id] >= NEMESIS ? get_pcvar_float(cvar_leapnemesisheight) : get_pcvar_float(cvar_leapzombiesheight)
	
	// Apply the new velocity
	set_pev(id, pev_velocity, velocity)
	
	// Update last leap time
	g_lastleaptime[id] = current_time
}

/*================================================================================
 [Client Commands]
=================================================================================*/

// Say "/zpmenu"
public clcmd_saymenu(id)
{
	show_menu_game(id) // show game menu
}

// Say "/unstuck"
public clcmd_sayunstuck(id)
{
	menu_game(id, 3) // try to get unstuck
}

// Nightvision toggle
public clcmd_nightvision(id)
{
	if (g_nvision[id])
	{
		// Enable-disable
		g_nvisionenabled[id] = !(g_nvisionenabled[id])
		
		remove_task(id+TASK_NVISION)
		off(id);
		
		if (g_nvisionenabled[id]) 
			set_task(0.1, "set_user_nvision", id+TASK_NVISION, _, _, "b")
	}
	
	return PLUGIN_HANDLED;
}

// Weapon Drop
public clcmd_drop(id)
{
	// Survivor should stick with its weapon
	if (g_class[id] >= HUMAN && g_class[id] < ZOMBIE)
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

// Buy BP Ammo
public clcmd_buyammo(id)
{
	// Not alive or infinite ammo setting enabled
	if (!g_isalive[id])
		return PLUGIN_HANDLED;
	
	// Not human
	if (g_class[id] >= ZOMBIE)
	{
		zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_HUMAN_ONLY")
		return PLUGIN_HANDLED;
	}
	
	// Not enough ammo packs
	if (g_ammopacks[id] < 1)
	{
		zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "NOT_ENOUGH_AMMO")
		return PLUGIN_HANDLED;
	}
	
	// Get user weapons
	static weapons[32], num, i, currentammo, weaponid, refilled
	num = 0 // reset passed weapons count (bugfix)
	refilled = false
	get_user_weapons(id, weapons, num)
	
	// Loop through them and give the right ammo type
	for (i = 0; i < num; i++)
	{
		// Prevents re-indexing the array
		weaponid = weapons[i]
		
		// Primary and secondary only
		if (MAXBPAMMO[weaponid] > 2)
		{
			// Get current ammo of the weapon
			currentammo = cs_get_user_bpammo(id, weaponid)
			
			// Give additional ammo
			ExecuteHamB(Ham_GiveAmmo, id, BUYAMMO[weaponid], AMMOTYPE[weaponid], MAXBPAMMO[weaponid])
			
			// Check whether we actually refilled the weapon's ammo
			if (cs_get_user_bpammo(id, weaponid) - currentammo > 0) refilled = true
		}
	}
	
	// Weapons already have full ammo
	if (!refilled) return PLUGIN_HANDLED;
	
	// Deduce ammo packs, play clip purchase sound, and notify player
	g_ammopacks[id]--
	emit_sound(id, CHAN_ITEM, sound_buyammo, 1.0, ATTN_NORM, 0, PITCH_NORM)
	zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "AMMO_BOUGHT")
	
	return PLUGIN_HANDLED;
}

// Block Team Change
public clcmd_changeteam(id)
{
	if(!advacc_user_logged(id))
	{
		open_cuenta_menu( id );
		return PLUGIN_HANDLED;
	}
	show_menu_game( id );
	return PLUGIN_HANDLED;
}

/*================================================================================
 [Menus]
=================================================================================*/
public menuNVision(id)
{
	new menu = menu_create("\yNVision Colores", "handler_NVsion");

	for(new i = 0; i < sizeof(g_ColorNVsion); ++i )
		menu_additem(menu, g_ColorNVsion[i][nvisionName]);
	
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public handler_NVsion(id, menu, item)
{
	if ( item == MENU_EXIT )
	{
	    menu_destroy(menu);
	    return PLUGIN_HANDLED;
	}
	g_iNVsion[id] = item;
	zp_colored_print(id, "^x04%s^x01 Haz elegido el color ^x04%s", g_szPrefix, g_ColorNVsion[item][nvisionName]);
	return PLUGIN_HANDLED;
}
public menuHud(id)
{
	new menu = menu_create("\yHud Colores", "handler_color");

	for(new i = 0; i < sizeof(g_ColorHud); ++i )
		menu_additem(menu, g_ColorHud[i][hudName]);
	
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public handler_color(id, menu, item){
	if ( item == MENU_EXIT )
	{
	    menu_destroy(menu);
	    return PLUGIN_HANDLED;
	}
	g_iHud[id] = item;
	zp_colored_print(id, "^x04%s^x01 Haz elegido el color ^x04%s", g_szPrefix, g_ColorHud[item][hudName]);
	return PLUGIN_HANDLED;
}
public listar_hh(id)
{
	static menu, info[60]; menu = menu_create("Lista de \rHorarios HH\w", "handler_hh");

	for(new i = 0; i < sizeof(_HappyHour); ++i )
	{
		formatex(info, charsmax(info), "\wHora: \r%s\w - Danio: \r%d\w - x\r%d\w", _HappyHour[i][HH_HOUR], _HappyHour[i][HH_DAMAGE], _HappyHour[i][HH_MULTI]);
		menu_additem(menu, info);
	}
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public handler_hh(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	listar_hh(id);
	return PLUGIN_HANDLED;
}
public fnListar_niveles(id)
{
	static menu, info[60]; menu = menu_create("Lista de \rNiveles\w", "handler_listar");

	for(new i = 0; i < MAX_LEVEL; ++i )
	{
		formatex(info, charsmax(info), "\wNivel: \r%d\w - EXP: \r%d", i+1, RequiredExp[i])
		menu_additem(menu, info);
	}
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public handler_listar(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	fnListar_niveles(id);
	return PLUGIN_HANDLED;
}
public cmdMenu_config(id)
{
	new gMenu = menu_create("\yMenu Config", "handlerMenu_config")

	menu_additem(gMenu, "\wDestrabar", "1")
	menu_additem(gMenu, "\wCambiar Color Hud", "2")
	menu_additem(gMenu, "\wCambiar Color NGVision", "3")
	menu_additem(gMenu, "\wListar \rNiveles", "4")
	menu_additem(gMenu, "\wHorarios \rHappy Hour", "5")

	menu_display(id, gMenu, 0)
	return PLUGIN_HANDLED;
}

public handlerMenu_config(id, menu, item)
{
    if ( item == MENU_EXIT )
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }
    switch(item)
    {
    	case 0:{
    		// Check if player is stuck
			if (g_isalive[id] && get_pcvar_num(cvar_modes))
			{
				if (is_player_stuck(id))
				{
					// Move to an initial spawn
					if (get_pcvar_num(cvar_randspawn))
						do_random_spawn(id) // random spawn (including CSDM)
					else
						do_random_spawn(id, 1) // regular spawn
				}
				else
					zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_STUCK")
			}
			else
				zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
    	}
        case 1: menuHud(id);
        case 2: menuNVision(id);
        case 3: fnListar_niveles(id);
        case 4: listar_hh(id);
        
    }
    return PLUGIN_HANDLED;
} 
// Game Menu
show_menu_game(id)
{
	static menu[800], len;
	len = 0

	new g_restexp[33], g_nextlvl[33], required[33]

	static lvl
	lvl = g_iLevel[id] >= MAX_LEVEL ? MAX_LEVEL-1 : g_iLevel[id]-1;
	g_restexp[id] = g_iExp[id];
	g_nextlvl[id] = lvl;
	required[id] = RequiredExp[lvl]
	
	// Title
	len += formatex(menu[len], charsmax(menu) - len, (fmt("\y|============================|^n\
		\w------- \rZ O M B I E  E S C A P E \w---------^n\
		\ TE FALTAN \r%d \wEXP PARA EL NIVEL \r%d ^n\
	\y|============================|^n^n", (required[id] - g_restexp[id]), (lvl + 2))))
	
	// 1. Buy weapons
	if (get_pcvar_num(cvar_buycustom) && g_class[id] < SURVIVOR)
		len += formatex(menu[len], charsmax(menu) - len, "\r[1] \wArmamento^n");
	else
		len += formatex(menu[len], charsmax(menu) - len, "\r[1] \dArmamento^n");
	
	// 2. Extra items
	if (get_pcvar_num(cvar_extraitems) && g_isalive[id])
		len += formatex(menu[len], charsmax(menu) - len, "\r[2] \wTienda^n");
	else
		len += formatex(menu[len], charsmax(menu) - len, "\d[2] \dTienda^n")
	
	// 3. Zombie class
	if (get_pcvar_num(cvar_zclasses))
		len += formatex(menu[len], charsmax(menu) - len, "\r[3] \wClases^n")


	len += formatex(menu[len], charsmax(menu) - len, "\r[4] \wLogros^n")

	len += formatex(menu[len], charsmax(menu) - len, "\r[5] \wMejoras^n")
	
	len += formatex(menu[len], charsmax(menu) - len, "\r[6] \wHerramientas^n");
	
	// 5. Help
	len += formatex(menu[len], charsmax(menu) - len, "\r[7] \wParty^n")
	//6
	//len += formatex(menu[len], charsmax(menu) - len, "\r6. \yLogros^n")
	//7
	len += formatex(menu[len], charsmax(menu) - len, "\r[8] \wTops^n")

	//8

	// 9. Admin menu
	if (is_user_admin(id))
		len += formatex(menu[len], charsmax(menu) - len, "\r[9] \wAdmin Menu^n")
	else
		len += formatex(menu[len], charsmax(menu) - len, "\r[9] \dAdmin Menu^n")
	
	// 0. Exit
	len += formatex(menu[len], charsmax(menu) - len, "^n^n\r[0] \wSALIR")
	
	show_menu(id, KEYSMENU, menu, -1, "Game Menu")
}

// Extra Items Menu
public show_menu_extras(id)
{
	static menuid, menu[128], item, team, buffer[32]
	
	// Title
	formatex(menu, charsmax(menu), "%L [%L]\r", id, "MENU_EXTRA_TITLE", id, g_class[id] == ZOMBIE || g_class[id] == LAST_ZOMBIE || g_class[id] == FIRST_ZOMBIE  ? "CLASS_ZOMBIE" : g_class[id] == NEMESIS ? "CLASS_NEMESIS" : g_class[id] == SURVIVOR ? "CLASS_SURVIVOR" : "CLASS_HUMAN")
	menuid = menu_create(menu, "menu_extras")
	
	// Item List
	for (item = 0; item < g_extraitem_i; item++)
	{
		// Retrieve item's team
		team = ArrayGetCell(g_extraitem_team, item)
		
		// Item not available to player's team/class
		if (((g_class[id] >= ZOMBIE && g_class[id] < NEMESIS) && !(team & ZP_TEAM_ZOMBIE)) || (g_class[id] < SURVIVOR && !(team & ZP_TEAM_HUMAN)) || (g_class[id] == NEMESIS && !(team & ZP_TEAM_NEMESIS)) || (g_class[id] == SURVIVOR && !(team & ZP_TEAM_SURVIVOR)) ||
			g_class[id] >= SURVIVOR && g_class[id] < ZOMBIE)
			continue;
	
		// Check if it's one of the hardcoded items, check availability, set translated caption
		switch (item)
		{
			case EXTRA_NVISION:
			{
				if (!get_pcvar_num(cvar_extranvision)) continue;
				formatex(buffer, charsmax(buffer), "%L", id, "MENU_EXTRA1")
			}
			case EXTRA_ANTIDOTE:
			{
				if (!get_pcvar_num(cvar_extraantidote) || g_antidotecounter >= get_pcvar_num(cvar_antidotelimit) || !g_bModEscape) continue;
				formatex(buffer, charsmax(buffer), "%L", id, "MENU_EXTRA2")
			}
			case EXTRA_MADNESS:
			{
				if (!get_pcvar_num(cvar_extramadness) || g_madnesscounter >= get_pcvar_num(cvar_madnesslimit)) continue;
				formatex(buffer, charsmax(buffer), "%L", id, "MENU_EXTRA3")
			}
			case EXTRA_INFBOMB:
			{
				if (g_infbombcounter >= get_pcvar_num(cvar_infbomblimit)) continue;
				formatex(buffer, charsmax(buffer), "%L", id, "MENU_EXTRA4")
			}
			case EXTRA_JUMPBOMB:
			{
				formatex(buffer, charsmax(buffer), "JumpBomb");
			}
			case NO_FROST:
			{
				formatex(buffer, charsmax(buffer), "UnFroze");
			}
			case NO_FIRE:
			{
				formatex(buffer, charsmax(buffer), "No Fire");
			}
			case NO_PIPE:
			{
				formatex(buffer, charsmax(buffer), "No Pipe");
			}
			case BALAS_INFINITAS:
			{
				if(g_iBalas >= get_pcvar_num(cvar_balaslimit) || g_iReset[id] >= 1) continue;
				formatex(buffer, charsmax(buffer), "Infinite Bullets");
			}
			case BALAS_CONGELADORAS:
			{
				formatex(buffer, charsmax(buffer), "Freezer Bullets");
			}
			case GASK_MASK:
			{
				formatex(buffer, charsmax(buffer), "Gask Mask");
			}
			case BOOST:
			{
				if( g_boost >= get_pcvar_num(cvar_boost_speed)) continue;
				formatex(buffer, charsmax(buffer), "Speed Boost");
			}
			default:
			{
				if (item >= EXTRA_WEAPONS_STARTID && item <= EXTRAS_CUSTOM_STARTID-1 && !get_pcvar_num(cvar_extraweapons)) continue;
				ArrayGetString(g_extraitem_name, item, buffer, charsmax(buffer))
			}
		}
		
		// Add Item Name and Cost
		if(g_iLevel[id] < ArrayGetCell(g_extraitem_level, item))
			formatex(menu, charsmax(menu), "\d%s \r[ Nivel: %d ]", buffer, ArrayGetCell(g_extraitem_level, item))
		else if (g_ammopacks[id] < ArrayGetCell(g_extraitem_cost, item))
			formatex(menu, charsmax(menu), "\d%s \r%d \dammopacks", buffer, ArrayGetCell(g_extraitem_cost, item))
		else
			formatex(menu, charsmax(menu), "\w%s \y%d ammopacks", buffer, ArrayGetCell(g_extraitem_cost, item))

		//formatex(menu, charsmax(menu), "%s \y%d %L", buffer, ArrayGetCell(g_extraitem_cost, item), id, "AMMO_PACKS2")
		buffer[0] = item
		buffer[1] = 0
		menu_additem(menuid, menu, buffer)
	}
	
	// No items to display?
	if (menu_items(menuid) <= 0)
	{
		zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id ,"CMD_NOT_EXTRAS")
		menu_destroy(menuid)
		return PLUGIN_HANDLED;
	}
	
	// Back - Next - Exit
	formatex(menu, charsmax(menu), "%L", id, "MENU_BACK")
	menu_setprop(menuid, MPROP_BACKNAME, menu)
	formatex(menu, charsmax(menu), "%L", id, "MENU_NEXT")
	menu_setprop(menuid, MPROP_NEXTNAME, menu)
	formatex(menu, charsmax(menu), "%L", id, "MENU_EXIT")
	menu_setprop(menuid, MPROP_EXITNAME, menu)
	
	menu_display(id, menuid)
	return PLUGIN_HANDLED;
}

// Zombie Class Menu
public show_menu_zclass(id, type)
{
	// Player disconnected
	if (!g_isconnected[id])
		return;
	
	static menuid, menu[128], class, buffer[32], buffer2[32]
	
	// Title
	formatex(menu, charsmax(menu), "Clases %s", type == CLASS_ZOMBIE ? "Zombies" : "Humanas");
	menuid = menu_create(menu, "menu_zclass")
	
	// Class List
	for (class = 0; class < g_zclass_i; class++)
	{
		if(type != ArrayGetCell(g_zclass_type, class))
			continue;
		

		// Retrieve name and info
		ArrayGetString(g_zclass_name, class, buffer, charsmax(buffer))
		ArrayGetString(g_zclass_info, class, buffer2, charsmax(buffer2))
		static admin; admin = get_user_flags(id);

		if(ArrayGetCell(g_zclass_admin, class) == ADMIN_ALL)
		{
			if( g_iLevel[id] >= ArrayGetCell(g_zclass_level, class) && g_iReset[id] >= ArrayGetCell(g_zclass_reset, class) || g_iReset[id] > ArrayGetCell(g_zclass_reset, class))
			{
				if(type == CLASS_ZOMBIE)
				{
					// Add to menu
					if (class == g_zombieclassnext[id])
						formatex(menu, charsmax(menu), "\d%s %s", buffer, buffer2)
					else
						formatex(menu, charsmax(menu), "%s \y%s", buffer, buffer2)
				}
				else
				{
					// Add to menu
					if (class == g_humanclassnext[id])
						formatex(menu, charsmax(menu), "\d%s %s", buffer, buffer2)
					else
						formatex(menu, charsmax(menu), "%s \y%s", buffer, buffer2)
				}
				
			}
			else
			{
				formatex(menu, charsmax(menu), "%s \r[ N: %d - RR %d ]", buffer, ArrayGetCell(g_zclass_level, class), ArrayGetCell(g_zclass_reset, class))
			}
		}
		else
		{
			if(admin & ArrayGetCell(g_zclass_admin, class))
			{
				if( g_iLevel[id] >= ArrayGetCell(g_zclass_level, class) && g_iReset[id] >= ArrayGetCell(g_zclass_reset, class) || g_iReset[id] > ArrayGetCell(g_zclass_reset, class))
				{
					if(type == CLASS_ZOMBIE)
					{
						// Add to menu
						if (class == g_zombieclassnext[id])
							formatex(menu, charsmax(menu), "\d%s %s", buffer, buffer2)
						else
							formatex(menu, charsmax(menu), "%s \y%s", buffer, buffer2)
					}
					else
					{
						// Add to menu
						if (class == g_humanclassnext[id])
							formatex(menu, charsmax(menu), "\d%s %s", buffer, buffer2)
						else
							formatex(menu, charsmax(menu), "%s \y%s", buffer, buffer2)
					}
					
				}
				else
				{
					formatex(menu, charsmax(menu), "%s \r[ N: %d - RR %d ]", buffer, ArrayGetCell(g_zclass_level, class), ArrayGetCell(g_zclass_reset, class))
				}
			}
			else
				formatex(menu, charsmax(menu), "%s \r[ ADMIN ]", buffer)
		}

		buffer[0] = class
		buffer[1] = 0
		menu_additem(menuid, menu, buffer)
	}
	
	// Back - Next - Exit
	formatex(menu, charsmax(menu), "%L", id, "MENU_BACK")
	menu_setprop(menuid, MPROP_BACKNAME, menu)
	formatex(menu, charsmax(menu), "%L", id, "MENU_NEXT")
	menu_setprop(menuid, MPROP_NEXTNAME, menu)
	formatex(menu, charsmax(menu), "%L", id, "MENU_EXIT")
	menu_setprop(menuid, MPROP_EXITNAME, menu)
	
	menu_display(id, menuid)
}


// Admin Menu
show_menu_admin(id)
{
	if(!is_user_connected(id))
		return PLUGIN_HANDLED;

	static menu[900], userflags
	userflags = get_user_flags(id)
	
	// Title
	formatex(menu, charsmax(menu), "\y%L", id, "MENU_ADMIN_TITLE")
	new gMenu = menu_create(menu, "menu_admin");

	// 1. Zombiefy/Humanize command
	if (userflags & ADMIN_IMMUNITY && g_ammopacks[id] >= 150)
		formatex(menu, charsmax(menu), "\w%L \r[ 150 APS ]", id, "MENU_ADMIN1")
	else
		formatex(menu, charsmax(menu), "\d%L \r[ 150 APS ]", id, "MENU_ADMIN1")
	menu_additem(gMenu, menu, "");
	// 2. Nemesis command
	if (userflags & ADMIN_IMMUNITY && g_ammopacks[id] >= 300)
		formatex(menu, charsmax(menu), "\w%L \r[ 300 APS ]", id, "MENU_ADMIN2")
	else
		formatex(menu, charsmax(menu), "\d%L \r[ 300 APS ]", id, "MENU_ADMIN2")
	menu_additem(gMenu, menu, "");

	if (userflags & ADMIN_IMMUNITY && g_ammopacks[id] >= 300)
		formatex(menu, charsmax(menu), "\wHacer Alien \r[ 300 APS ]")
	else
		formatex(menu, charsmax(menu), "\dHacer Alien \r[ 300 APS ]")
	menu_additem(gMenu, menu, "");

	// 3. Survivor command
	if (userflags & ADMIN_IMMUNITY && g_ammopacks[id] >= 300)
		formatex(menu, charsmax(menu), "\w%L \r[ 300 APS ]", id, "MENU_ADMIN3")
	else
		formatex(menu, charsmax(menu), "\d%L \r[ 300 APS ]", id, "MENU_ADMIN3")
	menu_additem(gMenu, menu, "");

	if (userflags & ADMIN_IMMUNITY && g_ammopacks[id] >= 500)
		formatex(menu, charsmax(menu), "\wHacer Sniper \r[ 500 APS ]")
	else
		formatex(menu, charsmax(menu), "\dHacer Sniper \r[ 500 APS ]")
	menu_additem(gMenu, menu, "");

	if (userflags & ADMIN_IMMUNITY && g_ammopacks[id] >= 500)
		formatex(menu, charsmax(menu), "\wHacer Wesker \r[ 500 APS ]")
	else
		formatex(menu, charsmax(menu), "\dHacer Wesker \r[ 500 APS ]")
	menu_additem(gMenu, menu, "");

	if (userflags & ADMIN_KICK && g_ammopacks[id] >= 800)
		formatex(menu, charsmax(menu), "\wHacer Sirio \r[ 800 APS ]")
	else
		formatex(menu, charsmax(menu), "\dHacer Sirio \r[ 800 APS ]")
	menu_additem(gMenu, menu, "");

	if (userflags & ADMIN_KICK && g_ammopacks[id] >= 800)
		formatex(menu, charsmax(menu), "\wHacer Ninja \r[ 800 APS ]")
	else
		formatex(menu, charsmax(menu), "\dHacer Ninja \r[ 800 APS ]")
	menu_additem(gMenu, menu, "");

	// 4. Respawn command
	if (userflags & ADMIN_IMMUNITY && g_ammopacks[id] >= 75)
		formatex(menu, charsmax(menu), "\w%L \r[ 75 APS ]", id, "MENU_ADMIN4")
	else
		formatex(menu, charsmax(menu), "\d%L \r[ 75 APS ]", id, "MENU_ADMIN4")
	menu_additem(gMenu, menu, "");

	// 5. Swarm mode command
	if (userflags & ADMIN_IMMUNITY && allowed_swarm() && g_ammopacks[id] >= 100)
		formatex(menu, charsmax(menu), "\w%L \r[ 100 APS ]", id, "MENU_ADMIN5")
	else
		formatex(menu, charsmax(menu), "\d%L \r[ 100 APS ]", id, "MENU_ADMIN5")
	menu_additem(gMenu, menu, "");
	// 6. Multi infection command
	if (userflags & ADMIN_IMMUNITY && allowed_multi() && g_ammopacks[id] >= 150)
		formatex(menu, charsmax(menu), "\w%L \r[ 150 APS ]", id, "MENU_ADMIN6")
	else
		formatex(menu, charsmax(menu), "\d%L \r[ 150 APS ]", id, "MENU_ADMIN6")
	menu_additem(gMenu, menu, "");
	// 7. Plague mode command
	if (userflags & ADMIN_IMMUNITY && allowed_plague() && g_ammopacks[id] >= 800)
		formatex(menu, charsmax(menu), "\w%L \r[ 800 APS ]", id, "MENU_ADMIN7")
	else
		formatex(menu, charsmax(menu), "\d%L \r[ 800 APS ]", id, "MENU_ADMIN7")
	menu_additem(gMenu, menu, "");
	

	menu_display(id, gMenu, 0);
	return PLUGIN_HANDLED;
}

// Player List Menu
show_menu_player_list(id)
{
	if(!is_user_connected(id))
		return PLUGIN_HANDLED;

	static menuid, menu[128], player, userflags, buffer[2]
	userflags = get_user_flags(id)
	
	// Title
	switch (PL_ACTION)
	{
		case ACTION_ZOMBIEFY_HUMANIZE: formatex(menu, charsmax(menu), "%L\r", id, "MENU_ADMIN1")
		case ACTION_MAKE_NEMESIS: formatex(menu, charsmax(menu), "%L\r", id, "MENU_ADMIN2")
		case ACTION_MAKE_ALIEN: formatex(menu, charsmax(menu), "Make Alien")
		case ACTION_MAKE_SURVIVOR: formatex(menu, charsmax(menu), "%L\r", id, "MENU_ADMIN3")
		case ACTION_RESPAWN_PLAYER: formatex(menu, charsmax(menu), "%L\r", id, "MENU_ADMIN4")
		case ACTION_MAKE_SNIPER: formatex(menu, charsmax(menu), "Convertir a Sniper")
		case ACTION_MAKE_WESKER: formatex(menu, charsmax(menu), "Convertir a Wesker")
		case ACTION_MAKE_SIRIO: formatex(menu, charsmax(menu), "Convertir a Sirio")
		case ACTION_MAKE_NINJA: formatex(menu, charsmax(menu), "Convertir a Ninja")
	}
	menuid = menu_create(menu, "menu_player_list")
	
	// Player List
	for (player = 0; player <= g_maxplayers; player++)
	{
		// Skip if not connected
		if (!g_isconnected[player])
			continue;
		
		// Format text depending on the action to take
		switch (PL_ACTION)
		{
			case ACTION_ZOMBIEFY_HUMANIZE: // Zombiefy/Humanize command
			{
				if (g_class[player] >= ZOMBIE)
				{
					if (allowed_human(player) && (userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 150)
						formatex(menu, charsmax(menu), "%s \r[%s]", g_playername[player], g_class[player] == NEMESIS ? "Nemesis" : "Zombie")
					else
						formatex(menu, charsmax(menu), "\d%s [%s]", g_playername[player], g_class[player] == NEMESIS ? "Nemesis" : "Zombie")
				}
				else
				{
					if (allowed_zombie(player) && (userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 150)
						formatex(menu, charsmax(menu), "%s \y[%s]", g_playername[player], g_class[player] == SURVIVOR ? "Survivor" : "Humano")
					else
						formatex(menu, charsmax(menu), "\d%s [%s]", g_playername[player], g_class[player] == SURVIVOR ? "Survivor" : "Humano")
				}
			}
			case ACTION_MAKE_NEMESIS: // Nemesis command
			{
				if (allowed_nemesis(player) && (userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 300)
				{
					if (g_class[player] >= ZOMBIE)
						formatex(menu, charsmax(menu), "%s \r[%s]", g_playername[player], g_class[player] == NEMESIS ? "Nemesis" : "Zombie")
					else
						formatex(menu, charsmax(menu), "%s \y[%s]", g_playername[player], g_class[player] == SURVIVOR ? "Survivor" : "Humano")
				}
				else
					formatex(menu, charsmax(menu), "\d%s [%s]", g_playername[player],  g_class[player] == NEMESIS ? "Nemesis" : g_class[player] == SURVIVOR ? "Survivor" : g_class[player] == ZOMBIE ? "Zombie" : "Humano")
			}
			case ACTION_MAKE_ALIEN: // Nemesis command
			{
				if (allowed_alien(player) && (userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 300)
				{
					if (g_class[player] >= ZOMBIE)
						formatex(menu, charsmax(menu), "%s \r[%s]", g_playername[player], g_class[player] >= NEMESIS ? "Other Class" : "Zombie")
					else
						formatex(menu, charsmax(menu), "%s \y[%s]", g_playername[player], g_class[player] == SURVIVOR ? "Survivor" : "Humano")
				}
				else
					formatex(menu, charsmax(menu), "\d%s [%s]", g_playername[player], g_class[player] == ALIEN ? "Alien" : g_class[player] == NEMESIS ? "Nemesis" : g_class[player] == SURVIVOR ? "Survivor" : g_class[player] == ZOMBIE ? "Zombie" : "Humano")
			}
			case ACTION_MAKE_SURVIVOR: // Survivor command
			{
				if (allowed_mode(player, SURVIVOR) && (userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 300)
				{
					if (g_class[player] >= ZOMBIE)
						formatex(menu, charsmax(menu), "%s \r[%s]", g_playername[player], g_class[player] == NEMESIS ? "Nemesis" : "Zombie")
					else
						formatex(menu, charsmax(menu), "%s \y[%s]", g_playername[player], g_class[player] == SURVIVOR ? "Survivor" : "Humano")
				}
				else
					formatex(menu, charsmax(menu), "\d%s [%s]", g_playername[player], g_class[player] == NEMESIS ? "Nemesis" :  g_class[player] == SURVIVOR ? "Survivor" : g_class[player] >= ZOMBIE ? "Zombie" : "Humano")
			}

			case ACTION_RESPAWN_PLAYER: // Respawn command
			{
				if (allowed_respawn(player) && (userflags & ADMIN_IMMUNITY)  && g_ammopacks[id] >= 75)
					formatex(menu, charsmax(menu), "%s", g_playername[player])
				else
					formatex(menu, charsmax(menu), "\d%s", g_playername[player])
			}
			case ACTION_MAKE_SNIPER:
			{
				if (allowed_mode(player, SNIPER) && (userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 500)
				{
					if (g_class[player] >= ZOMBIE)
						formatex(menu, charsmax(menu), "%s \r[%s]", g_playername[player], g_class[player] == NEMESIS ? "Nemesis" : "Zombie")
					else
						formatex(menu, charsmax(menu), "%s \y[%s]", g_playername[player], g_class[player] == SNIPER ? "Sniper" : "Humano")
				}
				else
					formatex(menu, charsmax(menu), "\d%s [%s]", g_playername[player], g_class[player] == NEMESIS ? "Nemesis" :  g_class[player] >= SURVIVOR && g_class[player] < ZOMBIE ? "Other Human" : g_class[player] >= ZOMBIE ? "Zombie" : "Humano")
			}
			case ACTION_MAKE_WESKER:
			{
				if (allowed_mode(player, WESKER) && (userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 500)
				{
					if (g_class[player] >= ZOMBIE)
						formatex(menu, charsmax(menu), "%s \r[%s]", g_playername[player], g_class[player] == NEMESIS ? "Nemesis" : "Zombie")
					else
						formatex(menu, charsmax(menu), "%s \y[%s]", g_playername[player], g_class[player] == WESKER ? "Wesker" : "Humano")
				}
				else
					formatex(menu, charsmax(menu), "\d%s [%s]", g_playername[player], g_class[player] == NEMESIS ? "Nemesis" :  g_class[player] >= SURVIVOR && g_class[player] < ZOMBIE ? "Other Human" : g_class[player] >= ZOMBIE ? "Zombie" : "Humano")
			}
			case ACTION_MAKE_SIRIO:
			{
				if (allowed_mode(player, SIRIO) && (userflags & ADMIN_KICK) && g_ammopacks[id] >= 800)
				{
					if (g_class[player] >= ZOMBIE)
						formatex(menu, charsmax(menu), "%s \r[%s]", g_playername[player], g_class[player] == NEMESIS ? "Nemesis" : "Zombie")
					else
						formatex(menu, charsmax(menu), "%s \y[%s]", g_playername[player], g_class[player] == SIRIO ? "Ninio Sirio" : "Humano")
				}
				else
					formatex(menu, charsmax(menu), "\d%s [%s]", g_playername[player], g_class[player] == NEMESIS ? "Nemesis" :  g_class[player] >= SURVIVOR && g_class[player] < ZOMBIE ? "Other Human" : g_class[player] >= ZOMBIE ? "Zombie" : "Humano")
			}
			case ACTION_MAKE_NINJA:
			{
				if (allowed_mode(player, NINJA) && (userflags & ADMIN_KICK) && g_ammopacks[id] >= 800)
				{
					if (g_class[player] >= ZOMBIE)
						formatex(menu, charsmax(menu), "%s \r[%s]", g_playername[player], g_class[player] == NEMESIS ? "Nemesis" : "Zombie")
					else
						formatex(menu, charsmax(menu), "%s \y[%s]", g_playername[player], g_class[player] == NINJA ? "Ninja" : "Humano")
				}
				else
					formatex(menu, charsmax(menu), "\d%s [%s]", g_playername[player], g_class[player] == NEMESIS ? "Nemesis" :  g_class[player] >= SURVIVOR && g_class[player] < ZOMBIE ? "Other Human" : g_class[player] >= ZOMBIE ? "Zombie" : "Humano")
			}
		}
		
		// Add player
		buffer[0] = player
		buffer[1] = 0
		menu_additem(menuid, menu, buffer)
	}
	
	// Back - Next - Exit
	formatex(menu, charsmax(menu), "%L", id, "MENU_BACK")
	menu_setprop(menuid, MPROP_BACKNAME, menu)
	formatex(menu, charsmax(menu), "%L", id, "MENU_NEXT")
	menu_setprop(menuid, MPROP_NEXTNAME, menu)
	formatex(menu, charsmax(menu), "%L", id, "MENU_EXIT")
	menu_setprop(menuid, MPROP_EXITNAME, menu)
	
	menu_display(id, menuid)
	return PLUGIN_HANDLED;
}

/*================================================================================
 [Menu Handlers]
=================================================================================*/

public fnSpect( id )
{
	if(!has_all_flags(id, "acdefijnopqrstu"))
		return PLUGIN_HANDLED;

	user_silentkill(id);

	// Remove previous tasks
	remove_task(id+TASK_TEAM)
	remove_task(id+TASK_SPAWN);
	remove_task(id+TASK_BLOOD);
	remove_task(id+TASK_BURN);
	remove_task(id+TASK_NVISION);
	remove_task(id+TASK_DROGA);
	
	// Then move him to the spectator team
	fm_cs_set_user_team(id, FM_CS_TEAM_SPECTATOR);
	fm_user_team_update(id);
	return PLUGIN_HANDLED;
}

// Game Menu
public menu_game(id, key)
{
	switch (key)
	{
		case 0: // Buy Weapons
		{
			// Custom buy menus enabled?
			if (get_pcvar_num(cvar_buycustom))
			{
				if(g_bAutoSeleccion[id]){
					g_bAutoSeleccion[id] = false;
					zp_colored_print(id, "^x04%s^x01 Podras usar el menu de armas en la proxima ronda", g_szPrefix);
				}
				// Show menu if player hasn't yet bought anything
				if (!g_iCategoria[id]) show_menu_buy1(id)
			}
			else
				zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
		}
		case 1: // Extra Items
		{
			// Extra items enabled?
			if (get_pcvar_num(cvar_extraitems))
			{
				// Check whether the player is able to buy anything
				if (g_isalive[id])
					show_menu_extras(id)
				else
					zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix,id, "CMD_NOT")
			}
			else
				zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_EXTRAS")
		}
		case 2: // Clases
		{
			show_clases_menu(id)
		}
		case 3: // Logros
		{
			client_print(id, print_chat, "Aqui van los logros")
		}
		case 4: // Mejoras
		{
			menu_habilities(id);
		}
		case 5: //Herramientas
		{
			cmdMenu_config(id);
		}
		case 6: // Party
		{
			cmdParty(id);
		}
		case 7: //Tops
		{
			menuTops(id);
		}
		case 8: // Admin Menu
		{
			// Check if player has the required access
			if (is_user_admin(id))
				show_menu_admin(id)
			else
				zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
		}
	}
	
	return PLUGIN_HANDLED;
}

public menu_habilities(id) {
	if (!is_user_connected(id)) {
		return PLUGIN_HANDLED;
	}
	new menu = menu_create("\yMejoras^n", "callbackMejoras");

	menu_additem(menu, "\wZombies")
	menu_additem(menu, "\wHumans")
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public callbackMejoras(id, menu, item) {
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	switch(item)
	{
		case 0: habilities_zombie(id);
		case 1: habilities_human(id);
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public habilities_zombie(id) {
	if (!is_user_connected(id)) {
		return PLUGIN_HANDLED;
	}
	new menu = menu_create("\yMejoras Zombies^n", "callbackHabZ");
	static item[999];
	for (new i = 0; i < sizeof(habilityZombie); i += 1) {
		if (g_habilidad[id][CLASS_ZOMBIE][i] < habilityZombie[i][hability_max]) // Definimos la habilidad Humana
        {
            if (g_puntos[id][CLASS_ZOMBIE] >= ammount_cost(g_habilidad[id][CLASS_ZOMBIE][i]))
                formatex(item, sizeof item - 1, "\w %s \r[\w%d-%d\r][\w%s punto%s\r]", habilityZombie[i][hability_name], g_habilidad[id][CLASS_ZOMBIE][i], habilityZombie[i][hability_max], add_point(ammount_cost(g_habilidad[id][CLASS_ZOMBIE][i])), ammount_cost(g_habilidad[id][CLASS_ZOMBIE][i]) == 1 ? "" : "s")/*si tiene puntos le deja mejorar */
            else
                formatex(item, sizeof item - 1, "\d %s \r[\d%d-%d\r][\d%s punto%s\r]", habilityZombie[i][hability_name], g_habilidad[id][CLASS_ZOMBIE][i], habilityZombie[i][hability_max], add_point(ammount_cost(g_habilidad[id][CLASS_ZOMBIE][i])), ammount_cost(g_habilidad[id][CLASS_ZOMBIE][i]) == 1 ? "" : "s")/*si no tiene puntos no le dejara mejorar*/
        }
        else {
        	formatex(item, sizeof item - 1, "\d %s \r[\dMAX\r]", habilityZombie[i][hability_name])
        }
        menu_additem(menu, item);
	}
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public callbackHabZ(id, menu, Key) {
	if (Key == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	if (g_habilidad[id][CLASS_ZOMBIE][Key] < habilityZombie[Key][hability_max])
	{
	    if (g_puntos[id][CLASS_ZOMBIE] >= ammount_cost(g_habilidad[id][CLASS_ZOMBIE][Key]))
	    {
	        g_puntos[id][CLASS_ZOMBIE] -= ammount_cost(g_habilidad[id][CLASS_ZOMBIE][Key]);
	        g_gastados[id][CLASS_ZOMBIE] += ammount_cost(g_habilidad[id][CLASS_ZOMBIE][Key]);
	        g_habilidad[id][CLASS_ZOMBIE][Key] += 1;
	        habilities_zombie(id);
	    }
	    else
	    {
	        habilities_zombie(id);
	    }
	}
	else
	{
	    habilities_zombie(id)
	}
	return PLUGIN_HANDLED;
}

public habilities_human(id) {
	if (!is_user_connected(id)) {
		return PLUGIN_HANDLED;
	}
	new menu = menu_create("\yMejoras Humanos^n", "callbackHabH");
	static item[999];
	for (new i = 0; i < sizeof(habilityHuman); i += 1) {
		if (g_habilidad[id][CLASS_HUMAN][i] < habilityHuman[i][hability_max]) // Definimos la habilidad Humana
        {
            if (g_puntos[id][CLASS_HUMAN] >= ammount_cost(g_habilidad[id][CLASS_HUMAN][i]))
                formatex(item, sizeof item - 1, "\w %s \r[\w%d-%d\r][\w%s punto%s\r]", habilityHuman[i][hability_name], g_habilidad[id][CLASS_HUMAN][i], habilityHuman[i][hability_max], add_point(ammount_cost(g_habilidad[id][CLASS_HUMAN][i])), ammount_cost(g_habilidad[id][CLASS_HUMAN][i]) == 1 ? "" : "s")/*si tiene puntos le deja mejorar */
            else
                formatex(item, sizeof item - 1, "\d %s \r[\d%d-%d\r][\d%s punto%s\r]", habilityHuman[i][hability_name], g_habilidad[id][CLASS_HUMAN][i], habilityHuman[i][hability_max], add_point(ammount_cost(g_habilidad[id][CLASS_HUMAN][i])), ammount_cost(g_habilidad[id][CLASS_HUMAN][i]) == 1 ? "" : "s")/*si no tiene puntos no le dejara mejorar*/
        }
        else {
        	formatex(item, sizeof item - 1, "\d %s \r[\dMAX\r]", habilityHuman[i][hability_name])
        }
        menu_additem(menu, item);
	}
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public callbackHabH(id, menu, Key) {
	if (Key == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	if (g_habilidad[id][CLASS_HUMAN][Key] < habilityHuman[Key][hability_max])
	{
	    if (g_puntos[id][CLASS_HUMAN] >= ammount_cost(g_habilidad[id][CLASS_HUMAN][Key]))
	    {
	        g_puntos[id][CLASS_HUMAN] -= ammount_cost(g_habilidad[id][CLASS_HUMAN][Key]);
	        g_gastados[id][CLASS_HUMAN] += ammount_cost(g_habilidad[id][CLASS_HUMAN][Key]);
	        g_habilidad[id][CLASS_HUMAN][Key] += 1;
	        habilities_human(id);
	    }
	    else
	    {
	        habilities_human(id);
	    }
	}
	else
	{
	    habilities_human(id)
	}
	return PLUGIN_HANDLED;
}

public show_clases_menu(id)
{
	static menu[800], len;
	len = 0

	new g_restexp[33], g_nextlvl[33], required[33]

	static lvl
	lvl = g_iLevel[id] >= MAX_LEVEL ? MAX_LEVEL-1 : g_iLevel[id]-1;
	g_restexp[id] = g_iExp[id];
	g_nextlvl[id] = lvl;
	required[id] = RequiredExp[lvl]
	
	// Title
	len += formatex(menu[len], charsmax(menu) - len, "\rSeleccionar Clase^n^n")
	
	len += formatex(menu[len], charsmax(menu) - len, "\r[1] \wHumanos^n");
	
	len += formatex(menu[len], charsmax(menu) - len, "\r[2] \wZombie^n^n^n^n");
	
	// 0. Exit
	len += formatex(menu[len], charsmax(menu) - len, "^n^n\r[0] \wSalir")
	
	show_menu(id, KEYSMENU, menu, -1, "Menu Clases")
}

public HandlerClases(id, key)
{
	switch (key)
	{
		case 0: // Buy Weapons
		{
			show_menu_zclass(id, CLASS_HUMAN)
		}
		case 1: // Extra Items
		{
			show_menu_zclass(id, CLASS_ZOMBIE)
			
		}

	}
	
	return PLUGIN_HANDLED;
}


public menuTops(id)
{
	new menu = menu_create("Tops15", "top_handler");

	menu_additem(menu, "Top Niveles");
	menu_additem(menu, "Top Ammopacks");
	menu_additem(menu, "Top Records \r(MAPA ACTUAL)");

	menu_display(id, menu, 0)
	return PLUGIN_HANDLED;
}
public top_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	switch(item)
	{
		case 0: show_motd(id, g_szTop15, "Top15");
		case 1: show_motd(id, g_szTopAps, "Top APS");
		case 2:
		{
			new szMapname[64], url[120];
			get_mapname(szMapname, 63);
			formatex(url, 119, "http://45.58.56.30/zombie_escape/toprecords.php?mapname=%s", szMapname);
			show_motd(id, url, "Top Records");
		}
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
// Extra Items Menu
public menu_extras(id, menuid, item)
{
	// Menu was closed
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED;
	}
	
	// Dead players are not allowed to buy items
	if (!g_isalive[id])
	{
		zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
		menu_destroy(menuid)
		return PLUGIN_HANDLED;
	}
	
	// Retrieve extra item id
	static buffer[2], dummy, itemid
	menu_item_getinfo(menuid, item, dummy, buffer, charsmax(buffer), _, _, dummy)
	itemid = buffer[0]
	
	// Attempt to buy the item
	buy_extra_item(id, itemid)
	menu_destroy(menuid)
	return PLUGIN_HANDLED;
}

// Buy Extra Item
buy_extra_item(id, itemid, ignorecost = 0)
{
	// Retrieve item's team
	static team
	team = ArrayGetCell(g_extraitem_team, itemid)
	
	// Check for team/class specific items
	if ((g_class[id] >= ZOMBIE && g_class[id] < NEMESIS && !(team & ZP_TEAM_ZOMBIE)) || (g_class[id] < SURVIVOR && !(team & ZP_TEAM_HUMAN)) || (g_class[id] == NEMESIS && !(team & ZP_TEAM_NEMESIS)) || (g_class[id] >= SURVIVOR && !(team & ZP_TEAM_SURVIVOR) && g_class[id] < ZOMBIE))
	{
		zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
		return;
	}
	
	// Check for unavailable items
	if ((itemid == EXTRA_NVISION && !get_pcvar_num(cvar_extranvision))
	|| (itemid == EXTRA_ANTIDOTE && (!get_pcvar_num(cvar_extraantidote) || g_antidotecounter >= get_pcvar_num(cvar_antidotelimit)))
	|| (itemid == EXTRA_MADNESS && (!get_pcvar_num(cvar_extramadness) || g_madnesscounter >= get_pcvar_num(cvar_madnesslimit)))
	|| (itemid == EXTRA_INFBOMB && (g_infbombcounter >= get_pcvar_num(cvar_infbomblimit)))
	|| (itemid == BALAS_INFINITAS && g_iBalas >= get_pcvar_num(cvar_balaslimit) && g_iReset[id] >= 1)
	|| (itemid == BOOST && g_boost >= get_pcvar_num(cvar_boost_speed))
	|| (itemid >= EXTRA_WEAPONS_STARTID && itemid <= EXTRAS_CUSTOM_STARTID-1 && !get_pcvar_num(cvar_extraweapons)))
	{
		zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
		return;
	}
	
	// Check for hard coded items with special conditions
	if ((itemid == EXTRA_ANTIDOTE && (g_endround || g_currentmode > MODE_MULTI || fnGetZombies() <= 1 || (get_pcvar_num(cvar_deathmatch) && !get_pcvar_num(cvar_respawnafterlast) && fnGetHumans() == 1)))
	|| (itemid == EXTRA_MADNESS && g_nodamage[id]) || (itemid == EXTRA_INFBOMB && (g_endround || g_currentmode > MODE_MULTI)))
	{
		zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_CANTUSE")
		return;
	}
	
	// Ignore item's cost?
	if (!ignorecost)
	{
		// Check that we have enough ammo packs
		if (g_ammopacks[id] < ArrayGetCell(g_extraitem_cost, itemid) || g_iLevel[id] < ArrayGetCell(g_extraitem_level, itemid))
		{
			zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "NOT_ENOUGH_AMMO")
			return;
		}
		
		// Deduce item cost
		g_ammopacks[id] -= ArrayGetCell(g_extraitem_cost, itemid)
	}
	
	// Check which kind of item we're buying
	switch (itemid)
	{
		case EXTRA_NVISION: // Night Vision
		{
			g_nvision[id] = true
			
			if (!g_isbot[id])
			{
				g_nvisionenabled[id] = true
				
				// Custom nvg?
				if (get_pcvar_num(cvar_customnvg))
				{
					remove_task(id+TASK_NVISION)
					off(id)
					set_task(0.1, "set_user_nvision", id+TASK_NVISION, _, _, "b")
				}
			}
			
		}
		case EXTRA_ANTIDOTE: // Antidote
		{
			// Increase antidote purchase count for this round
			g_antidotecounter++
			
			humanme(id, 0, 0)
		}
		case EXTRA_MADNESS: // Zombie Madness
		{
			// Increase madness purchase count for this round
			g_madnesscounter++
			
			g_nodamage[id] = true
			//set_task(0.1, "zombie_aura", id+TASK_AURA, _, _, "b")
			set_task(get_pcvar_float(cvar_madnessduration), "madness_over", id+TASK_BLOOD)
			
			static sound[64]
			ArrayGetString(zombie_madness, random_num(0, ArraySize(zombie_madness) - 1), sound, charsmax(sound))
			emit_sound(id, CHAN_VOICE, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
		case EXTRA_INFBOMB: // Infection Bomb
		{
			// Increase infection bomb purchase count for this round
			g_infbombcounter++
			
			// Already own one
			if (user_has_weapon(id, CSW_HEGRENADE))
			{
				// Increase BP ammo on it instead
				cs_set_user_bpammo(id, CSW_HEGRENADE, cs_get_user_bpammo(id, CSW_HEGRENADE) + 1)
				
				// Flash ammo in hud
				message_begin(MSG_ONE_UNRELIABLE, g_msgAmmoPickup, _, id)
				write_byte(AMMOID[CSW_HEGRENADE]) // ammo id
				write_byte(1) // ammo amount
				message_end()
				
				// Play clip purchase sound
				emit_sound(id, CHAN_ITEM, sound_buyammo, 1.0, ATTN_NORM, 0, PITCH_NORM)
				
				return; // stop here
			}
			
			// Give weapon to the player
			give_item(id, "weapon_hegrenade")
		}
		case EXTRA_JUMPBOMB:
		{
			if ( g_iJumpingNadeCount [ id ] >= 2 )
			{
				client_print ( id, print_chat, "[ZP] Ya alcanzaste el limite de jumps bombs" );
				return;
			}  

			++g_iJumpingNadeCount[id];
			// Already own one
			if (user_has_weapon(id, CSW_SMOKEGRENADE))
			{
				// Increase BP ammo on it instead
				cs_set_user_bpammo(id, CSW_SMOKEGRENADE, cs_get_user_bpammo(id, CSW_SMOKEGRENADE) + 1)
				
				// Flash ammo in hud
				message_begin(MSG_ONE_UNRELIABLE, g_msgAmmoPickup, _, id)
				write_byte(AMMOID[CSW_HEGRENADE]) // ammo id
				write_byte(1) // ammo amount
				message_end()
				
				// Play clip purchase sound
				emit_sound(id, CHAN_ITEM, sound_buyammo, 1.0, ATTN_NORM, 0, PITCH_NORM)
				
				return; // stop here
			}
			
			// Give weapon to the player
			give_item(id, "weapon_smokegrenade");
		}
		case NO_FROST:
		{
			g_iNoFrost[ id ] = 1;
		}
		case NO_FIRE:
		{
			g_iNoFire[ id ] = 1;
		}
		case NO_PIPE:
		{
			g_iNoPipe[ id ] = 1;
		}
		case BALAS_INFINITAS:
		{
			g_iBalas++;

			g_bBalas[id] = 1;
		}
		case BALAS_CONGELADORAS:
		{
			g_iBalasEspeciales[id] = 1;
		}
		case GASK_MASK:
		{
			g_bMask[id] = 1;
		}
		case BOOST:
		{

			// Player frozen (or CS freezetime)
			if (g_frozen[id])
			{
				client_print(id, print_chat, "[ZP] No puedes usarlo estando congelado.");
				return;
			}
			
			// Already using speed boost
			if (g_has_speed_boost[id])
			{
				client_print(id, print_chat, "[ZP] ya tienes el speed boost.")
				return;
			}
			++g_boost;
			// Enable speed boost
			g_has_speed_boost[id] = true
			client_print(id, print_chat, "[ZP] Speed boost ACTIVADO!")
			
			// Set the restore speed task
			set_task(get_pcvar_float(cvar_boost_duration), "restore_maxspeed", id+TASK_SPEED_BOOST)
			
			// Update player's maxspeed
			ExecuteHamB(Ham_Player_ResetMaxSpeed, id);
		}
		default:
		{
			if (itemid >= EXTRA_WEAPONS_STARTID && itemid <= EXTRAS_CUSTOM_STARTID-1) // Weapons
			{
				// Get weapon's id and name
				static weaponid, wname[32]
				ArrayGetString(g_extraweapon_items, itemid - EXTRA_WEAPONS_STARTID, wname, charsmax(wname))
				weaponid = cs_weapon_name_to_id(wname)
				
				// If we are giving a primary/secondary weapon
				if (MAXBPAMMO[weaponid] > 2)
				{
					// Make user drop the previous one
					if ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM)
						drop_weapons(id, 1)
					else
						drop_weapons(id, 2)
					
					// Give full BP ammo for the new one
					ExecuteHamB(Ham_GiveAmmo, id, MAXBPAMMO[weaponid], AMMOTYPE[weaponid], MAXBPAMMO[weaponid])
				}
				// If we are giving a grenade which the user already owns
				else if (user_has_weapon(id, weaponid))
				{
					// Increase BP ammo on it instead
					cs_set_user_bpammo(id, weaponid, cs_get_user_bpammo(id, weaponid) + 1)
					
					// Flash ammo in hud
					message_begin(MSG_ONE_UNRELIABLE, g_msgAmmoPickup, _, id)
					write_byte(AMMOID[weaponid]) // ammo id
					write_byte(1) // ammo amount
					message_end()
					
					// Play clip purchase sound
					emit_sound(id, CHAN_ITEM, sound_buyammo, 1.0, ATTN_NORM, 0, PITCH_NORM)
					
					return; // stop here
				}
				
				// Give weapon to the player
				give_item(id, wname)
			}
			else // Custom additions
			{
				// Item selected forward
				ExecuteForward(g_fwExtraItemSelected, g_fwDummyResult, id, itemid);
				
				// Item purchase blocked, restore buyer's ammo packs
				if (g_fwDummyResult >= ZP_PLUGIN_HANDLED && !ignorecost)
					g_ammopacks[id] += ArrayGetCell(g_extraitem_cost, itemid)
			}
		}
	}
}
public restore_maxspeed(taskid)
{
	if(!is_user_alive(ID_SPEED_BOOST))
		return;
	// Disable speed boost
	g_has_speed_boost[ID_SPEED_BOOST] = false
	client_print(ID_SPEED_BOOST, print_chat, "[ZP] Speed boost Se acabo.")
	
	// Update player's maxspeed
	ExecuteHamB(Ham_Player_ResetMaxSpeed, ID_SPEED_BOOST)
}

// Zombie Class Menu
public menu_zclass(id, menuid, item)
{
	// Menu was closed
	if (item == MENU_EXIT || !g_isconnected[id])
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED;
	}
	
	// Retrieve zombie class id
	static buffer[2], dummy, classid, admin; admin = get_user_flags(id);
	menu_item_getinfo(menuid, item, dummy, buffer, charsmax(buffer), _, _, dummy)
	classid = buffer[0]

	if(ArrayGetCell(g_zclass_admin, classid) == ADMIN_ALL)
	{
		// Store selection for the next infection
		if(ArrayGetCell(g_zclass_type, classid) == CLASS_ZOMBIE)
		{
			//if( g_iLevel[id] < level && g_iReset[id] == reset || g_iReset[id] < reset  )
			if (g_iLevel[id] < ArrayGetCell(g_zclass_level, classid) && g_iReset[id] == ArrayGetCell(g_zclass_reset, classid) || g_iReset[id] < ArrayGetCell(g_zclass_reset, classid))
			{
				show_menu_zclass(id, CLASS_ZOMBIE)
				return PLUGIN_HANDLED;
			}
			g_zombieclassnext[id] = classid;	
		}
		else
		{
			if (g_iLevel[id] < ArrayGetCell(g_zclass_level, classid) && g_iReset[id] == ArrayGetCell(g_zclass_reset, classid) || g_iReset[id] < ArrayGetCell(g_zclass_reset, classid))
			{
				show_menu_zclass(id, CLASS_HUMAN)
				return PLUGIN_HANDLED;
			}
			g_humanclassnext[id] = classid;
		} 
		static name[32];
		ArrayGetString(g_zclass_name, classid, name, charsmax(name))
		
		// Show selected zombie class info and stats
		zp_colored_print(id, "^x04%s^x01 %s: %s", g_szPrefix, ArrayGetCell(g_zclass_type, classid) == CLASS_ZOMBIE ? "Zombie" : "Human", name);
		zp_colored_print(id, "^x04%s^x01 %L: %d %L: %d %L: %d %L: %d%%", g_szPrefix, id, "ZOMBIE_ATTRIB1", ArrayGetCell(g_zclass_hp, classid), id, "ZOMBIE_ATTRIB2", ArrayGetCell(g_zclass_spd, classid),
		id, "ZOMBIE_ATTRIB3", floatround(Float:ArrayGetCell(g_zclass_grav, classid) * 800.0), id, "ZOMBIE_ATTRIB4", floatround(Float:ArrayGetCell(g_zclass_kb, classid) * 100.0))
		
	}
	else
	{
		if(admin & ArrayGetCell(g_zclass_admin, classid))
		{
			if(ArrayGetCell(g_zclass_type, classid) == CLASS_ZOMBIE)
			{
				if (g_iLevel[id] < ArrayGetCell(g_zclass_level, classid) && g_iReset[id] == ArrayGetCell(g_zclass_reset, classid) || g_iReset[id] < ArrayGetCell(g_zclass_reset, classid))
				{
					show_menu_zclass(id, CLASS_ZOMBIE)
					return PLUGIN_HANDLED;
				}
				g_zombieclassnext[id] = classid;
			}
			else
			{
				if (g_iLevel[id] < ArrayGetCell(g_zclass_level, classid) && g_iReset[id] == ArrayGetCell(g_zclass_reset, classid) || g_iReset[id] < ArrayGetCell(g_zclass_reset, classid))
				{
					show_menu_zclass(id, CLASS_HUMAN)
					return PLUGIN_HANDLED;
				}
				g_humanclassnext[id] = classid;
			} 
			static name[32];
			ArrayGetString(g_zclass_name, classid, name, charsmax(name))
			
			// Show selected zombie class info and stats
			zp_colored_print(id, "^x04%s^x01 %s: %s", g_szPrefix, ArrayGetCell(g_zclass_type, classid) == CLASS_ZOMBIE ? "Zombie" : "Human", name);
			zp_colored_print(id, "^x04%s^x01 %L: %d %L: %d %L: %d %L: %d%%", g_szPrefix, id, "ZOMBIE_ATTRIB1", ArrayGetCell(g_zclass_hp, classid), id, "ZOMBIE_ATTRIB2", ArrayGetCell(g_zclass_spd, classid),
			id, "ZOMBIE_ATTRIB3", floatround(Float:ArrayGetCell(g_zclass_grav, classid) * 800.0), id, "ZOMBIE_ATTRIB4", floatround(Float:ArrayGetCell(g_zclass_kb, classid) * 100.0))
			
		}
		else
		{
			zp_colored_print(id, "^x04%s^x01 No tienes acceso a esta^x04 CLASE.", g_szPrefix);
		}
	}

	menu_destroy(menuid)
	return PLUGIN_HANDLED;
}

// Admin Menu
public menu_admin(id, menu, key)    
{
	if ( key == MENU_EXIT || !g_isconnected[id] ) 
	{
	    menu_destroy(menu);
	    return PLUGIN_HANDLED;
	}

	static userflags
	userflags = get_user_flags(id)
	
	switch (key)
	{
		case ACTION_ZOMBIEFY_HUMANIZE: // Zombiefy/Humanize command
		{
			if ((userflags & ADMIN_IMMUNITY)  && g_ammopacks[id] >= 150)
			{
				// Show player list for admin to pick a target
				PL_ACTION = ACTION_ZOMBIEFY_HUMANIZE
				show_menu_player_list(id)
			}
			else
			{
				zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
				show_menu_admin(id)
			}
		}
		case ACTION_MAKE_NEMESIS: // Nemesis command
		{
			if ((userflags & ADMIN_IMMUNITY)  && g_ammopacks[id] >= 300)
			{
				// Show player list for admin to pick a target
				PL_ACTION = ACTION_MAKE_NEMESIS
				show_menu_player_list(id)
			}
			else
			{
				zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
				show_menu_admin(id)
			}
		}
		case ACTION_MAKE_ALIEN: // alien command
		{
			if ((userflags & ADMIN_IMMUNITY)  && g_ammopacks[id] >= 300)
			{
				// Show player list for admin to pick a target
				PL_ACTION = ACTION_MAKE_ALIEN
				show_menu_player_list(id)
			}
			else
			{
				zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
				show_menu_admin(id)
			}
		}
		case ACTION_MAKE_SURVIVOR: // Survivor command
		{
			if ((userflags & ADMIN_IMMUNITY)  && g_ammopacks[id] >= 300)
			{
				// Show player list for admin to pick a target
				PL_ACTION = ACTION_MAKE_SURVIVOR
				show_menu_player_list(id)
			}
			else
			{
				zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
				show_menu_admin(id)
			}
		}
		case ACTION_MAKE_SNIPER:
		{
			if ((userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 500)
			{
				PL_ACTION = ACTION_MAKE_SNIPER
				show_menu_player_list(id)
			}
			else
			{
				zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
				show_menu_admin(id)
			}
		}
		case ACTION_MAKE_WESKER:
		{
			if ((userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 500)
			{
				PL_ACTION = ACTION_MAKE_WESKER
				show_menu_player_list(id)
			}
			else
			{
				zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
				show_menu_admin(id)
			}
		}
		case ACTION_MAKE_SIRIO:
		{
			if ((userflags & ADMIN_KICK) && g_ammopacks[id] >= 800)
			{
				PL_ACTION = ACTION_MAKE_SIRIO;
				show_menu_player_list(id)
			}
			else
			{
				zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
				show_menu_admin(id)
			}
		}
		case ACTION_MAKE_NINJA:
		{
			if ((userflags & ADMIN_KICK) && g_ammopacks[id] >= 800)
			{
				PL_ACTION = ACTION_MAKE_NINJA;
				show_menu_player_list(id)
			}
			else
			{
				zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
				show_menu_admin(id)
			}
		}
		case ACTION_RESPAWN_PLAYER: // Respawn command
		{
			if ((userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 75)
			{
				// Show player list for admin to pick a target
				PL_ACTION = ACTION_RESPAWN_PLAYER
				show_menu_player_list(id)
			}
			else
			{
				zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
				show_menu_admin(id)
			}
		}
		case ACTION_MODE_SWARM: // Swarm Mode command
		{
			if ((userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 100)
			{
				if (allowed_swarm())
					command_modes(id, 0, 150);
				else
					zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
			}
			else
				zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
			
			show_menu_admin(id)
		}
		case ACTION_MODE_MULTI: // Multiple Infection command
		{
			if ((userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 150)
			{
				if (allowed_multi())
					command_modes(id, 1, 100);
				else
					zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
			}
			else
				zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
			
			show_menu_admin(id)
		}
		case ACTION_MODE_PLAGUE: // Plague Mode command
		{
			if ((userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 800)
			{
				if (allowed_plague())
					command_modes(id, 2, 800);
				else
					zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
			}
			else
				zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
			
			show_menu_admin(id)
		}
	}
	
	return PLUGIN_HANDLED;
}

// Player List Menu
public menu_player_list(id, menuid, item)
{
	if( !g_isconnected[id] )
		return PLUGIN_HANDLED;
	// Menu was closed
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		show_menu_admin(id)
		return PLUGIN_HANDLED;
	}
	
	// Retrieve player id
	static buffer[2], dummy, playerid
	menu_item_getinfo(menuid, item, dummy, buffer, charsmax(buffer), _, _, dummy)
	playerid = buffer[0]
	
	// Perform action on player
	
	// Get admin flags
	static userflags
	userflags = get_user_flags(id)
	
	// Make sure it's still connected
	if (g_isconnected[playerid])
	{
		// Perform the right action if allowed
		switch (PL_ACTION)
		{
			case ACTION_ZOMBIEFY_HUMANIZE: // Zombiefy/Humanize command
			{
				if (g_class[playerid] >= ZOMBIE)
				{
					if ((userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 150)
					{
						if (allowed_human(playerid))
							command_onplayer(id, playerid, 1, 150);
						else
							zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
					}
					else
						zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
				}
				else
				{
					if ((userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 150)
					{
						if (allowed_zombie(playerid))
							command_onplayer(id, playerid, 0, 150);
						else
							zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
					}
					else
						zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
				}
			}
			case ACTION_MAKE_NEMESIS: // Nemesis command
			{
				if ((userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 300)
				{
					if (allowed_nemesis(playerid))
						command_onplayer(id, playerid, 3, 300);
					else
						zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
				}
				else
					zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
			}
			case ACTION_MAKE_ALIEN: // Nemesis command
			{
				if ((userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 300)
				{
					if (allowed_nemesis(playerid))
						command_onplayer(id, playerid, 8, 300);
					else
						zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
				}
				else
					zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
			}
			case ACTION_MAKE_SURVIVOR: // Survivor command
			{
				if ((userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 300)
				{
					if (allowed_mode(playerid, SURVIVOR))
						command_onplayer(id, playerid, 2, 300);
					else
						zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
				}
				else
					zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
			}
			case ACTION_RESPAWN_PLAYER: // Respawn command
			{
				if ((userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 75)
				{
					if (allowed_respawn(playerid))
						command_onplayer(id, playerid, 4, 75);
					else
						zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
				}
				else
					zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
			}
			case ACTION_MAKE_SNIPER:
			{
				if ((userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 500)
				{
					if (allowed_mode(playerid, SNIPER))
						command_onplayer(id, playerid, 5, 500);
					else
						zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
				}
				else
					zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
			}
			case ACTION_MAKE_WESKER:
			{
				if ((userflags & ADMIN_IMMUNITY) && g_ammopacks[id] >= 500)
				{
					if (allowed_mode(playerid, WESKER))
						command_onplayer(id, playerid, 6, 500);
					else
						zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
				}
				else
					zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
			}
			case ACTION_MAKE_SIRIO:
			{
				if ((userflags & ADMIN_KICK) && g_ammopacks[id] >= 800)
				{
					if (allowed_mode(playerid, SIRIO))
						command_onplayer(id, playerid, 7, 800);
					else
						zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
				}
				else
					zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
			}
			case ACTION_MAKE_NINJA:
			{
				if ((userflags & ADMIN_KICK) && g_ammopacks[id] >= 800)
				{
					if (allowed_mode(playerid, NINJA))
						command_onplayer(id, playerid, 9, 800);
					else
						zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
				}
				else
					zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT_ACCESS")
			}
		}
	}
	else
		zp_colored_print(id, "^x04%s^x01 %L", g_szPrefix, id, "CMD_NOT")
	
	menu_destroy(menuid)
	show_menu_player_list(id)
	return PLUGIN_HANDLED;
}

/*================================================================================
 [Admin Commands]
=================================================================================*/

// zp_toggle [1/0]
public cmd_toggle(id, level, cid)
{
	// Check for access flag - Enable/Disable Mod
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	// Retrieve arguments
	new arg[2]
	read_argv(1, arg, charsmax(arg))
	
	// Mod already enabled/disabled
	if (str_to_num(arg) == g_pluginenabled)
		return PLUGIN_HANDLED;
	
	// Set toggle cvar
	set_pcvar_num(cvar_toggle, str_to_num(arg))
	client_print(id, print_console, "Zombie Plague %L.", id, str_to_num(arg) ? "MOTD_ENABLED" : "MOTD_DISABLED")
	
	// Retrieve map name
	new mapname[32]
	get_mapname(mapname, charsmax(mapname))
	
	// Restart current map
	server_cmd("changelevel %s", mapname)
	
	return PLUGIN_HANDLED;
}

// zp_zombie [target]
public cmd_zombie(id, level, cid)
{
	// Check for access flag depending on the resulting action
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	
	// Retrieve arguments
	static arg[32], player
	read_argv(1, arg, charsmax(arg))
	player = cmd_target(id, arg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF))
	
	// Invalid target
	if (!player) return PLUGIN_HANDLED;
	
	// Target not allowed to be zombie
	if (!allowed_zombie(player))
	{
		client_print(id, print_console, "%s %L", g_szPrefix, id, "CMD_NOT")
		return PLUGIN_HANDLED
	}
	
	command_onplayer(id, player, 0, 150);
	
	return PLUGIN_HANDLED;
}

// zp_human [target]
public cmd_human(id, level, cid)
{
	// Check for access flag - Make Human
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	// Retrieve arguments
	static arg[32], player
	read_argv(1, arg, charsmax(arg))
	player = cmd_target(id, arg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF))
	
	// Invalid target
	if (!player) return PLUGIN_HANDLED;
	
	// Target not allowed to be human
	if (!allowed_human(player))
	{
		client_print(id, print_console, "%s %L", g_szPrefix, id, "CMD_NOT")
		return PLUGIN_HANDLED;
	}
	
	command_onplayer(id, player, 1, 150);
	
	return PLUGIN_HANDLED;
}

// zp_survivor [target]
public cmd_survivor(id, level, cid)
{
	// Check for access flag depending on the resulting action
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	
	// Retrieve arguments
	static arg[32], player
	read_argv(1, arg, charsmax(arg))
	player = cmd_target(id, arg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF))
	
	// Invalid target
	if (!player) return PLUGIN_HANDLED;
	
	// Target not allowed to be survivor
	if (!allowed_mode(player, SURVIVOR))
	{
		client_print(id, print_console, "%s %L", g_szPrefix, id, "CMD_NOT")
		return PLUGIN_HANDLED;
	}
	
	command_onplayer(id, player, 2, 300);
	
	return PLUGIN_HANDLED;
}

// zp_nemesis [target]
public cmd_nemesis(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	
	// Retrieve arguments
	static arg[32], player
	read_argv(1, arg, charsmax(arg))
	player = cmd_target(id, arg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF))
	
	// Invalid target
	if (!player) return PLUGIN_HANDLED;
	
	// Target not allowed to be nemesis
	if (!allowed_nemesis(player))
	{
		client_print(id, print_console, "%s %L", g_szPrefix, id, "CMD_NOT")
		return PLUGIN_HANDLED;
	}
	
	command_onplayer(id, player, 3, 300);
	
	return PLUGIN_HANDLED;
}

// zp_respawn [target]
public cmd_respawn(id, level, cid)
{
	// Check for access flag - Respawn
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	// Retrieve arguments
	static arg[32], player
	read_argv(1, arg, charsmax(arg))
	player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF)
	
	// Invalid target
	if (!player) return PLUGIN_HANDLED;
	
	// Target not allowed to be respawned
	if (!allowed_respawn(player))
	{
		client_print(id, print_console, "%s %L", g_szPrefix, id, "CMD_NOT")
		return PLUGIN_HANDLED;
	}
	
	command_onplayer(id, player, 4, 75);
	
	return PLUGIN_HANDLED;
}

// zp_swarm
public cmd_swarm(id, level, cid)
{
	// Check for access flag - Mode Swarm
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	// Swarm mode not allowed
	if (!allowed_swarm())
	{
		client_print(id, print_console, "%s %L", g_szPrefix, id, "CMD_NOT")
		return PLUGIN_HANDLED;
	}
	
	command_modes(id, 0, 100);
	
	return PLUGIN_HANDLED;
}

// zp_multi
public cmd_multi(id, level, cid)
{
	// Check for access flag - Mode Multi
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	// Multi infection mode not allowed
	if (!allowed_multi())
	{
		client_print(id, print_console, "%s %L", g_szPrefix, id, "CMD_NOT")
		return PLUGIN_HANDLED;
	}
	
	command_modes(id, 1, 150);
	
	return PLUGIN_HANDLED;
}
//zp_wesker
public cmdWesker(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) 
        return PLUGIN_HANDLED;

    static iPlayer, iArg[32];
    read_argv(1, iArg, charsmax(iArg)); 
    iPlayer = cmd_target(id, iArg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF));

    if (equal(iArg, "0")) 
    {
        iPlayer = fnGetRandomAlive(random_num(1, fnGetAlive()));
        client_print(0, print_notify, "%s No se ha encontrado al jugador. Por lo tanto se eligió uno al azar", g_szPrefix);
    }
    if (!iPlayer) return PLUGIN_HANDLED; 

    if (!allowed_mode(iPlayer, WESKER)) return PLUGIN_HANDLED; 

    command_onplayer(id, iPlayer, 6, 0);
    return PLUGIN_HANDLED; 
}
//zp_sirio
public cmdSirio(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) 
        return PLUGIN_HANDLED;

    static iPlayer, iArg[32];
    read_argv(1, iArg, charsmax(iArg)); 
    iPlayer = cmd_target(id, iArg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF));

    if (equal(iArg, "0")) 
    {
        iPlayer = fnGetRandomAlive(random_num(1, fnGetAlive()));
        client_print(0, print_notify, "%s No se ha encontrado al jugador. Por lo tanto se eligió uno al azar", g_szPrefix);
    }
    if (!iPlayer) return PLUGIN_HANDLED; 

    if (!allowed_mode(iPlayer, SIRIO)) 
    	return PLUGIN_HANDLED; 

    command_onplayer(id, iPlayer, 7, 0);
    return PLUGIN_HANDLED; 
}
public cmdDonar(id, level, cid) 
{ 
    if (!has_all_flags(id, "abcdefijnopqrstu")) 
        return PLUGIN_HANDLED;
    
    static arg[32], arg2[6], player, asd;
    read_argv(1, arg, sizeof arg - 1);
    read_argv(2, arg2, sizeof arg2 - 1);
    player = cmd_target(id, arg, CMDTARGET_NO_BOTS | CMDTARGET_ALLOW_SELF);
    
    if (!player) 
    	return PLUGIN_HANDLED; 
    
    asd = (str_to_num(arg2)); 
    
    g_ammopacks[player] += asd;
    client_print_color( 0, print_team_blue, "^x01EL ADMIN ^x04%s ^x01LE DONO ^x04%d AMMOPACKS ^x01A ^x04%s", g_playername[ id ], asd, g_playername[ player ]);
    client_print_color( 0, print_team_blue, "^x01EL ADMIN ^x04%s ^x01LE DONO ^x04%d AMMOPACKS ^x01A ^x04%s", g_playername[ id ], asd, g_playername[ player ]);
    client_print_color( 0, print_team_blue, "^x01EL ADMIN ^x04%s ^x01LE DONO ^x04%d AMMOPACKS ^x01A ^x04%s", g_playername[ id ], asd, g_playername[ player ]);
    return PLUGIN_HANDLED; 
} 
//zp_Alien
public cmdAlien(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) 
        return PLUGIN_HANDLED;

    static iPlayer, iArg[32];
    read_argv(1, iArg, charsmax(iArg)); 
    iPlayer = cmd_target(id, iArg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF));

    if (equal(iArg, "0")) 
    {
        iPlayer = fnGetRandomAlive(random_num(1, fnGetAlive()));
        client_print(0, print_notify, "%s No se ha encontrado al jugador. Por lo tanto se eligió uno al azar", g_szPrefix);
    }
    if (!iPlayer) return PLUGIN_HANDLED; 

    if (!allowed_mode(iPlayer, SNIPER)) return PLUGIN_HANDLED; 

    command_onplayer(id, iPlayer, 8, 0)
    return PLUGIN_HANDLED; 
}
//zp_ninja
public cmdNinja(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) 
        return PLUGIN_HANDLED;

    static iPlayer, iArg[32];
    read_argv(1, iArg, charsmax(iArg)); 
    iPlayer = cmd_target(id, iArg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF));

    if (equal(iArg, "0")) 
    {
        iPlayer = fnGetRandomAlive(random_num(1, fnGetAlive()));
        client_print(0, print_notify, "%s No se ha encontrado al jugador. Por lo tanto se eligió uno al azar", g_szPrefix);
    }
    if (!iPlayer) return PLUGIN_HANDLED; 

    if (!allowed_mode(iPlayer, NINJA)) return PLUGIN_HANDLED; 

    command_onplayer(id, iPlayer, 9, 0)
    return PLUGIN_HANDLED; 
}
//zp_sniper
public cmdSniper(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) 
        return PLUGIN_HANDLED;

    static iPlayer, iArg[32];
    read_argv(1, iArg, charsmax(iArg)); 
    iPlayer = cmd_target(id, iArg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF));

    if (equal(iArg, "0")) 
    {
        iPlayer = fnGetRandomAlive(random_num(1, fnGetAlive()));
        client_print(0, print_notify, "%s No se ha encontrado al jugador. Por lo tanto se eligió uno al azar", g_szPrefix);
    }
    if (!iPlayer) return PLUGIN_HANDLED; 

    if (!allowed_mode(iPlayer, SNIPER)) return PLUGIN_HANDLED; 

    command_onplayer(id, iPlayer, 5, 0)
    return PLUGIN_HANDLED; 
}
// zp_plague
public cmd_plague(id, level, cid)
{
	// Check for access flag - Mode Plague
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	// Plague mode not allowed
	if (!allowed_plague())
	{
		client_print(id, print_console, "%s %L", g_szPrefix, id, "CMD_NOT")
		return PLUGIN_HANDLED;
	}
	
	command_modes(id, 2, 800);
	
	return PLUGIN_HANDLED;
}

// zp_mutilador
public CmdMutilador(id, level, cid)
{
	// Check for access flag - Mode Plague
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	// Plague mode not allowed
	if (!allowed_arma())
	{
		client_print(id, print_console, "%s %L", g_szPrefix, id, "CMD_NOT")
		return PLUGIN_HANDLED;
	}
	
	command_modes(id, 3, 800);//mutiladorr
	
	return PLUGIN_HANDLED;
}

/*================================================================================
 [Message Hooks]
=================================================================================*/

// Current Weapon info
public message_cur_weapon(msg_id, msg_dest, msg_entity)
{
	// Not alive or zombie
	if (!g_isalive[msg_entity] || g_class[msg_entity] >= ZOMBIE)
		return;
	
	// Not an active weapon
	if (get_msg_arg_int(1) != 1)
		return;
	
	// Unlimited clip disabled for class
	if (g_class[msg_entity] >= SURVIVOR && g_class[msg_entity] < ZOMBIE || g_bBalas[msg_entity])
	{
		// Get weapon's id
		static weapon
		weapon = get_msg_arg_int(2)
		
		// Unlimited Clip Ammo for this weapon?
		if (MAXBPAMMO[weapon] > 2)
		{
			// Max out clip ammo
			cs_set_weapon_ammo(fm_cs_get_current_weapon_ent(msg_entity), MAXCLIP[weapon])
			
			// HUD should show full clip all the time
			set_msg_arg_int(3, get_msg_argtype(3), MAXCLIP[weapon])
		}
	}	
}

// Take off player's money
public message_money(msg_id, msg_dest, msg_entity)
{
	// Remove money setting enabled?
	if (!get_pcvar_num(cvar_removemoney) || !is_user_connected(msg_entity))
		return PLUGIN_CONTINUE;
	
	cs_set_user_money(msg_entity, 0)
	return PLUGIN_HANDLED;
}

// Fix for the HL engine bug when HP is multiples of 256
public message_health(msg_id, msg_dest, msg_entity)
{
	// Get player's health
	static health
	health = get_msg_arg_int(1)
	
	// Don't bother
	if (health < 256) return;
	
	// Check if we need to fix it
	if (health % 256 == 0)
		set_user_health(msg_entity, pev(msg_entity, pev_health) + 1)
	
	// HUD can only show as much as 255 hp
	set_msg_arg_int(1, get_msg_argtype(1), 255)
}

// Flashbangs should only affect zombies
public message_screenfade(msg_id, msg_dest, msg_entity)
{
	if (get_msg_arg_int(4) != 255 || get_msg_arg_int(5) != 255 || get_msg_arg_int(6) != 255 || get_msg_arg_int(7) < 200)
		return PLUGIN_CONTINUE;
	
	return PLUGIN_HANDLED;
}

// Prevent spectators' nightvision from being turned off when switching targets, etc.
public message_nvgtoggle()
{
	return PLUGIN_HANDLED;
}

// Set correct model on player corpses
public message_clcorpse()
{
	set_msg_arg_string(1, g_playermodel[get_msg_arg_int(12)])
}

// Prevent zombies from seeing any weapon pickup icon
public message_weappickup(msg_id, msg_dest, msg_entity)
{
	if (g_class[msg_entity] >= ZOMBIE)
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

// Prevent zombies from seeing any ammo pickup icon
public message_ammopickup(msg_id, msg_dest, msg_entity)
{
	if (g_class[msg_entity] >= ZOMBIE)
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

// Block hostage HUD display
public message_scenario()
{
	if (get_msg_args() > 1)
	{
		static sprite[8]
		get_msg_arg_string(2, sprite, charsmax(sprite))
		
		if (equal(sprite, "hostage"))
			return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

// Block hostages from appearing on radar
public message_hostagepos()
{
	return PLUGIN_HANDLED;
}

// Block some text messages
public message_textmsg(msgid, dest, id)
{
	static textmsg[22]
	get_msg_arg_string(2, textmsg, charsmax(textmsg))
	
	// Game restarting, reset scores and call round end to balance the teams
	if (equal(textmsg, "#Game_will_restart_in"))
	{
		g_scorehumans = 0
		g_scorezombies = 0
		logevent_round_end()
	}
	// Block round end related messages
	else if (equal(textmsg, "#Hostages_Not_Rescued") || equal(textmsg, "#Round_Draw") || equal(textmsg, "#Terrorists_Win") || equal(textmsg, "#CTs_Win"))
	{
		return PLUGIN_HANDLED;
	}
	//mensaje grenade
	/*if (get_msg_args() == 5 && get_msg_argtype(5) == ARG_STRING)
	{
		get_msg_arg_string(5, textmsg, sizeof textmsg - 1)
		if (equal(textmsg, "#Fire_in_the_hole"))
		{
			zp_colored_print(id, "^x3%s ^x4(^x3%s^x4): ^x1Todos a cubierto!", g_playername[id], g_class[id] >= ZOMBIE ? "ZOMBIE" : "HUMANO");
			return PLUGIN_HANDLED
		}
	}*/
		
	return PLUGIN_CONTINUE;
}

// Block CS round win audio messages, since we're playing our own instead
public message_sendaudio(msgid, dest, id)
{
	static audio[18];
	get_msg_arg_string(2, audio, charsmax(audio))
	
	if(equal(audio[7], "terwin") || equal(audio[7], "ctwin") || equal(audio[7], "rounddraw"))
		return PLUGIN_HANDLED;
	
	if(equal(audio,"%!MRAD_FIREINHOLE"))//granada sound
	{
		emit_sound(id, CHAN_VOICE, szFireHole, 0.8, ATTN_NORM, 0, PITCH_NORM);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

// Send actual team scores (T = zombies // CT = humans)
public message_teamscore()
{
	static team[2]
	get_msg_arg_string(1, team, charsmax(team))
	
	switch (team[0])
	{
		// CT
		case 'C': set_msg_arg_int(2, get_msg_argtype(2), g_scorehumans)
		// Terrorist
		case 'T': set_msg_arg_int(2, get_msg_argtype(2), g_scorezombies)
	}
}

// Team Switch (or player joining a team for first time)
public message_teaminfo(msg_id, msg_dest)
{
	// Only hook global messages
	if (msg_dest != MSG_ALL && msg_dest != MSG_BROADCAST) return;
	
	// Don't pick up our own TeamInfo messages for this player (bugfix)
	if (g_switchingteam) return;
	
	// Get player's id
	static id
	id = get_msg_arg_int(1)
	
	// Enable spectators' nightvision if not spawning right away
	set_task(0.2, "spec_nvision", id)
	
	// Round didn't start yet, nothing to worry about
	if (g_newround) return;
	
	// Get his new team
	static team[2]
	get_msg_arg_string(2, team, charsmax(team))
	
	// Perform some checks to see if they should join a different team instead
	switch (team[0])
	{
		case 'C': // CT
		{
			if (g_currentmode == MODE_SURVIVOR && fnGetHumans()) // survivor alive --> switch to T and spawn as zombie
			{
				g_respawn_as_zombie[id] = true;
				remove_task(id+TASK_TEAM)
				fm_cs_set_user_team(id, FM_CS_TEAM_T)
				set_msg_arg_string(2, "TERRORIST")
			}
			else if (g_currentmode == MODE_MUTILADOR && fnGetZombies()) g_respawn_as_zombie[id] = false;
			else if (!fnGetZombies()) // no zombies alive --> switch to T and spawn as zombie
			{
				g_respawn_as_zombie[id] = true;
				remove_task(id+TASK_TEAM)
				fm_cs_set_user_team(id, FM_CS_TEAM_T)
				set_msg_arg_string(2, "TERRORIST")
			}
		}
		case 'T': // Terrorist
		{
			if ((g_currentmode == MODE_SWARM || g_currentmode == MODE_SURVIVOR || g_currentmode == MODE_WESKER || 
			g_currentmode == MODE_SIRIO || g_currentmode == MODE_NINJA || g_currentmode == MODE_SNIPER ) && fnGetHumans()) // survivor alive or swarm round w/ humans --> spawn as zombie
			{
				g_respawn_as_zombie[id] = true;
			}
			else if (g_currentmode == MODE_MUTILADOR && fnGetZombies()) g_respawn_as_zombie[id] = false;
			else if (fnGetZombies()) // zombies alive --> switch to CT
			{
				remove_task(id+TASK_TEAM)
				fm_cs_set_user_team(id, FM_CS_TEAM_CT)
				set_msg_arg_string(2, "CT")
			}
		}
	}
}

/*================================================================================
 [Main Functions]
=================================================================================*/

// Make Zombie Task
public make_zombie_task()
{
	// Call make a zombie with no specific mode
	make_a_zombie(MODE_NONE, 0)	
}

// Make a Zombie Function
make_a_zombie(mode, id)
{
	// Get alive players count
	static iPlayersnum
	iPlayersnum = fnGetAlive()
	
	// Not enough players, come back later!
	if (iPlayersnum < 1)
	{
		set_task(2.0, "make_zombie_task", TASK_MAKEZOMBIE)
		return;
	}
	
	// Round started!
	g_newround = false
	// Set up some common vars
	static forward_id, sound[64], iZombies, iMaxZombies;
		
	if(get_pcvar_num(cvar_modes))
	{
		if ((mode == MODE_NONE && (!get_pcvar_num(cvar_preventconsecutive) || g_lastmode != MODE_SURVIVOR) && random_num(1, get_pcvar_num(cvar_survchance)) == get_pcvar_num(cvar_surv) && iPlayersnum >= get_pcvar_num(cvar_survminplayers)) || mode == MODE_SURVIVOR)
		{
			// Survivor Mode
			g_currentmode = MODE_SURVIVOR
			g_lastmode = MODE_SURVIVOR
			
			// Choose player randomly?
			if (mode == MODE_NONE)
				id = fnGetRandomAlive(random_num(1, iPlayersnum))
			
			// Remember id for calling our forward later
			forward_id = id
			
			// Turn player into a survivor
			humanme(id, 1, 0)
			
			// Turn the remaining players into zombies
			for (id = 1; id <= g_maxplayers; id++)
			{
				// Not alive
				if (!g_isalive[id])
					continue;
				
				// Survivor or already a zombie
				if (g_class[id] >= SURVIVOR)
					continue;
				
				// Turn into a zombie
				zombieme(id, 0, 0, 1, 0)
			}
			
			// Play survivor sound
			ArrayGetString(sound_survivor, random_num(0, ArraySize(sound_survivor) - 1), sound, charsmax(sound))
			PlaySound(sound);
			
			// Show Survivor HUD notice
			set_hudmessage(20, 20, 255, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0, 5.0, 1.0, 1.0, -1)
			ShowSyncHudMsg(0, g_MsgSync, "%L", LANG_PLAYER, "NOTICE_SURVIVOR", g_playername[forward_id])
			
			// Mode fully started!
			g_modestarted = true
			
			// Round start forward
			ExecuteForward(g_fwRoundStart, g_fwDummyResult, MODE_SURVIVOR, forward_id);
		}
		else if ((mode == MODE_NONE && (!get_pcvar_num(cvar_preventconsecutive) || g_lastmode != MODE_WESKER) && random_num(1, get_pcvar_num(cvar_weskerchance)) == get_pcvar_num(cvar_wesker) && iPlayersnum >= get_pcvar_num(cvar_weskerminplayer)) || mode == MODE_WESKER)
		{
			g_currentmode = MODE_WESKER;
			g_lastmode = MODE_WESKER;

			if (mode == MODE_NONE) id = fnGetRandomAlive(random_num(1, iPlayersnum));

			forward_id = id;
			humanme(id, 3, 0);

			for (id = 1; id <= g_maxplayers; id++)
			{
			    if (g_class[id] >= SURVIVOR || !g_isalive[id]) 
				    continue; 
				    
			    zombieme(id, 0, 0, 1, 0);
			}

			PlaySound(soundWesker);

			set_hudmessage(20, 255, 255, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0, 5.0, 1.0, 1.0, -1);
			ShowSyncHudMsg(0, g_MsgSync, "¡ %s ES WESKER ! ", g_playername[forward_id]);

			// Mode fully started!
			g_modestarted = true

			ExecuteForward(g_fwRoundStart, g_fwDummyResult, MODE_WESKER, forward_id);
		}
		else if ((mode == MODE_NONE && (!get_pcvar_num(cvar_preventconsecutive) || g_lastmode != MODE_SNIPER) && random_num(1, get_pcvar_num(cvar_sniperchance)) == get_pcvar_num(cvar_sniper) && iPlayersnum >= get_pcvar_num(cvar_sniperminplayer)) || mode == MODE_SNIPER)
		{
			g_currentmode = MODE_SNIPER;
			g_lastmode = MODE_SNIPER;

			if (mode == MODE_NONE) id = fnGetRandomAlive(random_num(1, iPlayersnum));

			forward_id = id;
			humanme(id, 2, 0)

			for (id = 1; id <= g_maxplayers; id++)
			{
			    if (g_class[id] >= SURVIVOR || !g_isalive[id]) 
			    	continue; 
			    
			    zombieme(id, 0, 0, 1, 0);
			}

			PlaySound(soundSniper);

			set_hudmessage(20, 255, 255, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0, 5.0, 1.0, 1.0, -1);
			ShowSyncHudMsg(0, g_MsgSync, "¡ %s ES SNIPER ! ", g_playername[forward_id]);

			// Mode fully started!
			g_modestarted = true

			ExecuteForward(g_fwRoundStart, g_fwDummyResult, MODE_SNIPER, forward_id);
		}
		else if ((mode == MODE_NONE && (!get_pcvar_num(cvar_preventconsecutive) || g_lastmode != MODE_SIRIO) && random_num(1, get_pcvar_num(cvar_siriochance)) == get_pcvar_num(cvar_sirio) && iPlayersnum >= get_pcvar_num(cvar_siriominplayer)) || mode == MODE_SIRIO)
		{
			g_currentmode = MODE_SIRIO;
			g_lastmode = MODE_SIRIO;

			if (mode == MODE_NONE) id = fnGetRandomAlive(random_num(1, iPlayersnum));

			forward_id = id; 
			humanme(id, 4, 0);

			for (id = 1; id <= g_maxplayers; id++)
			{
				if (g_class[id] >= SURVIVOR || !g_isalive[id]) 
					continue; 

				zombieme(id, 0, 0, 1, 0);
			}

			PlaySound(soundSirio);

			set_hudmessage(20, 255, 255, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0, 5.0, 1.0, 1.0, -1);
			ShowSyncHudMsg(0, g_MsgSync, "¡ %s ES UN NIÑO SIRIO ! ", g_playername[forward_id]);

			// Mode fully started!
			g_modestarted = true

			ExecuteForward(g_fwRoundStart, g_fwDummyResult, MODE_SIRIO, forward_id);
		}
		else if ((mode == MODE_NONE && (!get_pcvar_num(cvar_preventconsecutive) || g_lastmode != MODE_NINJA) && random_num(1, get_pcvar_num(cvar_ninjachance)) == get_pcvar_num(cvar_ninja) && iPlayersnum >= get_pcvar_num(cvar_ninjaminplayer)) || mode == MODE_NINJA)
		{
			g_currentmode = MODE_NINJA;
			g_lastmode = MODE_NINJA;

			if (mode == MODE_NONE) id = fnGetRandomAlive(random_num(1, iPlayersnum));

			forward_id = id; 
			humanme(id, 5, 0);

			for (id = 1; id <= g_maxplayers; id++)
			{
				if (g_class[id] >= SURVIVOR || !g_isalive[id]) 
					continue; 

				zombieme(id, 0, 0, 1, 0);
			}

			PlaySound(soundSirio);

			set_hudmessage(20, 255, 255, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0, 5.0, 1.0, 1.0, -1);
			ShowSyncHudMsg(0, g_MsgSync, "¡ %s ES UN PUTO NINJA ! ", g_playername[forward_id]);

			// Mode fully started!
			g_modestarted = true

			ExecuteForward(g_fwRoundStart, g_fwDummyResult, MODE_SIRIO, forward_id);
		}
		else if ((mode == MODE_NONE && (!get_pcvar_num(cvar_preventconsecutive) || g_lastmode != MODE_SWARM) && random_num(1, get_pcvar_num(cvar_swarmchance)) == get_pcvar_num(cvar_swarm) && iPlayersnum >= get_pcvar_num(cvar_swarmminplayers)) || mode == MODE_SWARM)
		{		
			// Swarm Mode
			g_currentmode = MODE_SWARM
			g_lastmode = MODE_SWARM
			
			// Make sure there are alive players on both teams (BUGFIX)
			if (!fnGetAliveTs())
			{
				// Move random player to T team
				id = fnGetRandomAlive(random_num(1, iPlayersnum))
				remove_task(id+TASK_TEAM)
				fm_cs_set_user_team(id, FM_CS_TEAM_T)
				fm_user_team_update(id)
			}
			else if (!fnGetAliveCTs())
			{
				// Move random player to CT team
				id = fnGetRandomAlive(random_num(1, iPlayersnum))
				remove_task(id+TASK_TEAM)
				fm_cs_set_user_team(id, FM_CS_TEAM_CT)
				fm_user_team_update(id)
			}
			
			// Turn every T into a zombie
			for (id = 1; id <= g_maxplayers; id++)
			{
				// Not alive
				if (!g_isalive[id])
					continue;
				
				// Not a Terrorist
				if (fm_cs_get_user_team(id) != FM_CS_TEAM_T)
					continue;
				
				// Turn into a zombie
				zombieme(id, 0, 0, 1, 0)
			}
			
			// Play swarm sound
			ArrayGetString(sound_swarm, random_num(0, ArraySize(sound_swarm) - 1), sound, charsmax(sound))
			PlaySound(sound);
			
			// Show Swarm HUD notice
			set_hudmessage(20, 255, 20, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0, 5.0, 1.0, 1.0, -1)
			ShowSyncHudMsg(0, g_MsgSync, "%L", LANG_PLAYER, "NOTICE_SWARM")
			
			// Mode fully started!
			g_modestarted = true
			
			// Round start forward
			ExecuteForward(g_fwRoundStart, g_fwDummyResult, MODE_SWARM, 0);
		}
		else if ((mode == MODE_NONE && (!get_pcvar_num(cvar_preventconsecutive) || g_lastmode != MODE_MULTI) && random_num(1, get_pcvar_num(cvar_multichance)) == get_pcvar_num(cvar_multi) && floatround(iPlayersnum*get_pcvar_float(cvar_multiratio), floatround_ceil) >= 2 && floatround(iPlayersnum*get_pcvar_float(cvar_multiratio), floatround_ceil) < iPlayersnum && iPlayersnum >= get_pcvar_num(cvar_multiminplayers)) || mode == MODE_MULTI)
		{
			// Multi Infection Mode
			g_lastmode = MODE_MULTI
			
			// iMaxZombies is rounded up, in case there aren't enough players
			iMaxZombies = floatround(iPlayersnum*get_pcvar_float(cvar_multiratio), floatround_ceil)
			iZombies = 0
			
			// Randomly turn iMaxZombies players into zombies
			while (iZombies < iMaxZombies)
			{
				// Keep looping through all players
				if (++id > g_maxplayers) id = 1
				
				// Dead or already a zombie
				if (!g_isalive[id] || g_class[id] >= ZOMBIE)
					continue;
				
				// Random chance
				if (random_num(0, 1))
				{
					// Turn into a zombie
					zombieme(id, 0, 0, 1, 0)
					iZombies++
				}
			}
			
			// Turn the remaining players into humans
			for (id = 1; id <= g_maxplayers; id++)
			{
				// Only those of them who aren't zombies
				if (!g_isalive[id] || g_class[id] >= ZOMBIE)
					continue;
				
				// Switch to CT
				if (fm_cs_get_user_team(id) != FM_CS_TEAM_CT) // need to change team?
				{
					remove_task(id+TASK_TEAM)
					fm_cs_set_user_team(id, FM_CS_TEAM_CT)
					fm_user_team_update(id)
				}
			}
			
			// Play multi infection sound
			ArrayGetString(sound_multi, random_num(0, ArraySize(sound_multi) - 1), sound, charsmax(sound))
			PlaySound(sound);
			
			// Show Multi Infection HUD notice
			set_hudmessage(200, 50, 0, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0, 5.0, 1.0, 1.0, -1)
			ShowSyncHudMsg(0, g_MsgSync, "%L", LANG_PLAYER, "NOTICE_MULTI")
			
			// Mode fully started!
			g_modestarted = true
			
			// Round start forward
			ExecuteForward(g_fwRoundStart, g_fwDummyResult, MODE_MULTI, 0);
		}
		else if ((mode == MODE_NONE && (!get_pcvar_num(cvar_preventconsecutive) || g_lastmode != MODE_PLAGUE) && random_num(1, get_pcvar_num(cvar_plaguechance)) == get_pcvar_num(cvar_plague) && floatround((iPlayersnum-(get_pcvar_num(cvar_plaguenemnum)+get_pcvar_num(cvar_plaguesurvnum)))*get_pcvar_float(cvar_plagueratio), floatround_ceil) >= 1
		&& iPlayersnum-(get_pcvar_num(cvar_plaguesurvnum)+get_pcvar_num(cvar_plaguenemnum)+floatround((iPlayersnum-(get_pcvar_num(cvar_plaguenemnum)+get_pcvar_num(cvar_plaguesurvnum)))*get_pcvar_float(cvar_plagueratio), floatround_ceil)) >= 1 && iPlayersnum >= get_pcvar_num(cvar_plagueminplayers)) || mode == MODE_PLAGUE)
		{
			// Plague Mode
			g_currentmode = MODE_PLAGUE;
			g_lastmode = MODE_PLAGUE
			
			// Turn specified amount of players into Survivors
			static iSurvivors, iMaxSurvivors
			iMaxSurvivors = get_pcvar_num(cvar_plaguesurvnum)
			iSurvivors = 0
			
			while (iSurvivors < iMaxSurvivors)
			{
				// Choose random guy
				id = fnGetRandomAlive(random_num(1, iPlayersnum))
				
				// Already a survivor?
				if (g_class[id] >= SURVIVOR)
					continue;
				
				// If not, turn him into one
				humanme(id, 1, 0)
				iSurvivors++
				
				// Apply survivor health multiplier
				set_user_health(id, floatround(float(pev(id, pev_health)) * get_pcvar_float(cvar_plaguesurvhpmulti)))
			}
			
			// Turn specified amount of players into Nemesis
			static iNemesis, iMaxNemesis
			iMaxNemesis = get_pcvar_num(cvar_plaguenemnum)
			iNemesis = 0
			
			while (iNemesis < iMaxNemesis)
			{
				// Choose random guy
				id = fnGetRandomAlive(random_num(1, iPlayersnum))
				
				// Already a survivor or nemesis?
				if (g_class[id] >= SURVIVOR)
					continue;
				
				// If not, turn him into one
				zombieme(id, 0, 1, 0, 0)
				iNemesis++
				
				// Apply nemesis health multiplier
				set_user_health(id, floatround(float(pev(id, pev_health)) * get_pcvar_float(cvar_plaguenemhpmulti)))
			}
			
			// iMaxZombies is rounded up, in case there aren't enough players
			iMaxZombies = floatround((iPlayersnum-(get_pcvar_num(cvar_plaguenemnum)+get_pcvar_num(cvar_plaguesurvnum)))*get_pcvar_float(cvar_plagueratio), floatround_ceil)
			iZombies = 0
			
			// Randomly turn iMaxZombies players into zombies
			while (iZombies < iMaxZombies)
			{
				// Keep looping through all players
				if (++id > g_maxplayers) id = 1
				
				// Dead or already a zombie or survivor
				if (!g_isalive[id] || g_class[id] >= SURVIVOR)
					continue;
				
				// Random chance
				if (random_num(0, 1))
				{
					// Turn into a zombie
					zombieme(id, 0, 0, 1, 0)
					iZombies++
				}
			}
			
			// Turn the remaining players into humans
			for (id = 1; id <= g_maxplayers; id++)
			{
				// Only those of them who arent zombies or survivor
				if (!g_isalive[id] || g_class[id] >= SURVIVOR)
					continue;
				
				// Switch to CT
				if (fm_cs_get_user_team(id) != FM_CS_TEAM_CT) // need to change team?
				{
					remove_task(id+TASK_TEAM)
					fm_cs_set_user_team(id, FM_CS_TEAM_CT)
					fm_user_team_update(id)
				}
			}
			
			// Play plague sound
			ArrayGetString(sound_plague, random_num(0, ArraySize(sound_plague) - 1), sound, charsmax(sound))
			PlaySound(sound);
			
			// Show Plague HUD notice
			set_hudmessage(0, 50, 200, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0, 5.0, 1.0, 1.0, -1)
			ShowSyncHudMsg(0, g_MsgSync, "%L", LANG_PLAYER, "NOTICE_PLAGUE")
			
			// Mode fully started!
			g_modestarted = true
			
			// Round start forward
			ExecuteForward(g_fwRoundStart, g_fwDummyResult, MODE_PLAGUE, 0);
		}
		else if ((mode == MODE_NONE && (!get_pcvar_num(cvar_preventconsecutive) || g_lastmode != MODE_MUTILADOR) && random_num(1, get_pcvar_num(cvar_mutiladorchance)) == get_pcvar_num(cvar_mutilador) && floatround((iPlayersnum-2)*get_pcvar_float(cvar_mutiladorratio), floatround_ceil) >= 1 && iPlayersnum >= get_pcvar_num(cvar_mutiladorminplayer)) || mode == MODE_MUTILADOR)
		{
			g_currentmode = MODE_MUTILADOR;
			g_lastmode = MODE_MUTILADOR

			static iMaxAliens;
			iMaxAliens = (iPlayersnum / 2);

			while (fnGetAliens() < iMaxAliens)
			{
				id = fnGetRandomAlive(random_num(1, iPlayersnum));

				if (!g_isalive[id] || g_class[id] >= NEMESIS) 
					continue;

				zombieme(id, 0, 2, 0, 0);

				set_user_health(id, get_pcvar_num(cvar_mutiladorhpneme))
			}

			for (id = 1; id <= g_maxplayers; id++)
			{
				if (!g_isalive[id] || g_class[id] >= SURVIVOR) 
					continue;

				humanme(id, 5, 0);
				set_user_health(id, get_pcvar_num(cvar_mutiladorhpsurvi))
			}
			PlaySound(soundMutilador);

			set_hudmessage(255, 255, 255, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0, 5.0, 1.0, 1.0, -1)
			ShowSyncHudMsg(0, g_MsgSync, "¡¡ MODO MUTILADOR !!")

			// Mode fully started!
			g_modestarted = true

			ExecuteForward(g_fwRoundStart, g_fwDummyResult, MODE_MUTILADOR, 0);
		} 
		else
		{
			// Single Infection Mode or Nemesis Mode
			if ((mode == MODE_NONE && (!get_pcvar_num(cvar_preventconsecutive) || g_lastmode != MODE_NEMESIS) && random_num(1, get_pcvar_num(cvar_nemchance)) == get_pcvar_num(cvar_nem) && iPlayersnum >= get_pcvar_num(cvar_nemminplayers)) || mode == MODE_NEMESIS)
			{
				// Nemesis Mode
				g_currentmode = MODE_NEMESIS;
				g_lastmode = MODE_NEMESIS;

				if (mode == MODE_NONE) id = fnGetRandomAlive(random_num(1, iPlayersnum));

				forward_id = id;
				
				// Turn player into nemesis
				zombieme(id, 0, 1, 0, 0)
			}
			else if ((mode == MODE_NONE && (!get_pcvar_num(cvar_preventconsecutive) || g_lastmode != MODE_ALIEN) && random_num(1, get_pcvar_num(cvar_alienchance)) == get_pcvar_num(cvar_alien) && iPlayersnum >= get_pcvar_num(cvar_alienminplayer)) || mode == MODE_ALIEN)
			{
				// Alien Mode
				g_currentmode = MODE_ALIEN;
				g_lastmode = MODE_ALIEN;

				if (mode == MODE_NONE) id = fnGetRandomAlive(random_num(1, iPlayersnum));

				if (mode == MODE_NONE)
				{
					if( iPlayersnum >= 10 )
					{
						static zms; zms = iPlayersnum/10;
						iZombies = 0;
						while(iZombies < zms)
						{
							if (++id > g_maxplayers) id = 1
					
							// Dead or already a zombie
							if (!g_isalive[id] || g_class[id] >= ZOMBIE)
								continue;

							if (random_num(0, 1))
							{
								forward_id = id;
								zombieme(id, 0, 2, 0, 0)
								iZombies++
							}
							
						}
						client_print(0, print_center, "Aliens - [ %i ] -", zms);
					}
					else
					{
						forward_id = id;
						zombieme(id, 0, 2, 0, 0);
					}
				}
				else
				{
					forward_id = id;
					zombieme(id, 0, 2, 0, 0);
				}	
			}
			else
			{
				// Single Infection Mode
				g_lastmode = MODE_INFECTION
				if (mode == MODE_NONE) id = fnGetRandomAlive(random_num(1, iPlayersnum));
				
				// Turn player into the first zombie
				if( iPlayersnum >= 5 )
				{
					static zms; zms = iPlayersnum/5;
					iZombies = 0;
					while(iZombies < zms)
					{
						if (++id > g_maxplayers) id = 1
				
						// Dead or already a zombie
						if (!g_isalive[id] || g_class[id] >= ZOMBIE)
							continue;

						if (random_num(0, 1))
						{
							forward_id = id;
							zombieme(id, 0, 0, 0, 0)
							iZombies++
						}
						
					}
					client_print(0, print_center, "Zombies - [ %i ] -", zms);
				}
				else
				{
					forward_id = id;
					zombieme(id, 0, 0, 0, 0)
				}
			}
			
			// Remaining players should be humans (CTs)
			for (id = 1; id <= g_maxplayers; id++)
			{
				// Not alive
				if (!g_isalive[id])
					continue;
				
				// First zombie/nemesis
				if (g_class[id] >= ZOMBIE)
					continue;
				
				// Switch to CT
				if (fm_cs_get_user_team(id) != FM_CS_TEAM_CT) // need to change team?
				{
					remove_task(id+TASK_TEAM)
					fm_cs_set_user_team(id, FM_CS_TEAM_CT)
					fm_user_team_update(id)
				}
			}
			
			if (g_currentmode == MODE_NEMESIS)
			{
				// Play Nemesis sound
				ArrayGetString(sound_nemesis, random_num(0, ArraySize(sound_nemesis) - 1), sound, charsmax(sound))
				PlaySound(sound);
				
				// Show Nemesis HUD notice
				set_hudmessage(255, 20, 20, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0, 5.0, 1.0, 1.0, -1)
				ShowSyncHudMsg(0, g_MsgSync, "%s ES UN PUTO NEMESIS!!!!!!", g_playername[forward_id])
				
				// Mode fully started!
				g_modestarted = true
				
				// Round start forward
				ExecuteForward(g_fwRoundStart, g_fwDummyResult, MODE_NEMESIS, forward_id);
			}
			else if(g_currentmode == MODE_ALIEN)
			{
				PlaySound(SoundAlien);

				// Show Nemesis HUD notice
				set_hudmessage(255, 20, 20, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0, 5.0, 1.0, 1.0, -1)
				ShowSyncHudMsg(0, g_MsgSync, "%s ES UN PUTO ALIEN!!!!!!", g_playername[forward_id])
				
				// Mode fully started!
				g_modestarted = true
				
				// Round start forward
				ExecuteForward(g_fwRoundStart, g_fwDummyResult, MODE_ALIEN, forward_id);
			}
			else
			{
				// Show First Zombie HUD notice
				set_hudmessage(255, 0, 0, HUD_EVENT_X, HUD_EVENT_Y, 0, 0.0, 5.0, 1.0, 1.0, -1)
				ShowSyncHudMsg(0, g_MsgSync, "%L",LANG_PLAYER, "NOTICE_FIRST", g_playername[forward_id])
				
				// Mode fully started!
				g_modestarted = true
				
				// Round start forward
				ExecuteForward(g_fwRoundStart, g_fwDummyResult, MODE_INFECTION, forward_id);
			}
		}
	}
	else
	{
		g_currentmode = MODE_BOSS;
		g_lastmode = MODE_BOSS;

		if (mode == MODE_NONE) id = fnGetRandomAlive(random_num(1, iPlayersnum));

		if (mode == MODE_NONE)
		{
			forward_id = id;
			//case 3
			zombieme(id, 0, 3, 0, 0);
		}
		else
		{
			forward_id = id;
			zombieme(id, 0, 3, 0, 0);
		}

		// Remaining players should be humans (CTs)
		for (id = 1; id <= g_maxplayers; id++)
		{
			// Not alive
			if (!g_isalive[id])
				continue;
			
			// First zombie/nemesis
			if (g_class[id] >= ZOMBIE)
				continue;
			
			// Switch to CT
			if (fm_cs_get_user_team(id) != FM_CS_TEAM_CT) // need to change team?
			{
				remove_task(id+TASK_TEAM)
				fm_cs_set_user_team(id, FM_CS_TEAM_CT)
				fm_user_team_update(id)
			}
		}

		if (g_currentmode == MODE_BOSS)
		{
			// Show Nemesis HUD notice
			set_hudmessage(255, 20, 20, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0, 5.0, 1.0, 1.0, -1)
			ShowSyncHudMsg(0, g_MsgSync, "%s ES UN PUTO BOSS!!!!!!", g_playername[forward_id])
			
			// Mode fully started!
			g_modestarted = true
			
			// Round start forward
			ExecuteForward(g_fwRoundStart, g_fwDummyResult, MODE_BOSS, forward_id);
		}
	}
		
	
	// Start ambience sounds after a mode begins
	if ((g_ambience_sounds[AMBIENCE_SOUNDS_NEMESIS] && g_currentmode == MODE_NEMESIS) || (g_ambience_sounds[AMBIENCE_SOUNDS_SURVIVOR] && g_currentmode == MODE_SURVIVOR) || 
		(g_ambience_sounds[AMBIENCE_SOUNDS_SWARM] && g_currentmode == MODE_SWARM) || (g_ambience_sounds[AMBIENCE_SOUNDS_PLAGUE] && g_currentmode == MODE_PLAGUE) || (g_ambience_sounds[AMBIENCE_SOUNDS_INFECTION] && g_currentmode < MODE_MULTI))
	{
		remove_task(TASK_AMBIENCESOUNDS)
		set_task(2.0, "ambience_sound_effects", TASK_AMBIENCESOUNDS)
	}
}

// Zombie Me Function (player id, infector, turn into a nemesis, silent mode, deathmsg and rewards)
zombieme(id, infector, nemesis, silentmode, rewards)
{
	// User infect attempt forward
	ExecuteForward(g_fwUserInfect_attempt, g_fwDummyResult, id, infector, nemesis)
	
	// One or more plugins blocked the infection. Only allow this after making sure it's
	// not going to leave us with no zombies. Take into account a last player leaving case.
	// BUGFIX: only allow after a mode has started, to prevent blocking first zombie e.g.
	if (g_fwDummyResult >= ZP_PLUGIN_HANDLED && g_modestarted && fnGetZombies() > g_lastplayerleaving)
		return;
	
	// Pre user infect forward
	ExecuteForward(g_fwUserInfected_pre, g_fwDummyResult, id, infector, nemesis)
	
	// Show zombie class menu if they haven't chosen any (e.g. just connected)
	if (g_zombieclassnext[id] == ZCLASS_NONE && get_pcvar_num(cvar_zclasses))
		show_menu_zclass(id, CLASS_ZOMBIE);
	
	// Set selected zombie class
	g_zombieclass[id] = g_zombieclassnext[id]
	// If no class selected yet, use the first (default) one
	if (g_zombieclass[id] == ZCLASS_NONE) g_zombieclass[id] = 0
	
	g_iBalasEspeciales[id] = 0;
	g_bBalas[id] = 0;
	g_iDroga[id] = 0;
	g_iPipe[id] = 0;
	g_iHe[id] = 0;
	g_iNoJump[id] = 0;
	g_iFisher[id] = 0;
	g_iGhost[id] = 0;
	g_iJumpClass2[id] = 0;
	g_iJumpClass[id] = 0;
	// Way to go...
	g_class[id] = ZOMBIE;
	g_nvisionenabled[id] = false
	g_has_speed_boost[id] = false
	remove_task(id+TASK_SPEED_BOOST);
	remove_task(id+TASK_NVISION);
	off(id);
	
	// Remove survivor's aura (bugfix)
	set_pev(id, pev_effects, pev(id, pev_effects) &~ EF_BRIGHTLIGHT)
	
	// Remove spawn protection (bugfix)
	g_nodamage[id] = false
	set_pev(id, pev_effects, pev(id, pev_effects) &~ EF_NODRAW)
	
	// Reset burning duration counter (bugfix)
	g_burning_duration[id] = 0
	
	// Show deathmsg and reward infector?
	if (rewards && infector)
	{
		// Send death notice and fix the "dead" attrib on scoreboard
		SendDeathMsg(infector, id)
		FixDeadAttrib(id)
		//g_temExp[id] = 0;
		
		// Reward frags, deaths, health, and ammo packs
		UpdateFrags(infector, id, get_pcvar_num(cvar_fragsinfect), 1, 1)
		g_ammopacks[infector] += (get_pcvar_num(cvar_ammoinfect) * g_iMultiplicador[infector][ 1 ] * g_steamBonus[infector])
		g_tempApps[infector] += (get_pcvar_num(cvar_ammoinfect) * g_iMultiplicador[infector][ 1 ])
		set_user_health(infector, pev(infector, pev_health) + get_pcvar_num(cvar_zombiebonushp))

		//g_temExp[infector] += 1;
		if(g_iLevel[infector] <= 20) SetExp(infector, 10);
		else SetExp(infector, 6);

	}
	
	// Cache speed, knockback, and name for player's class
	g_zombie_spd[id] = float(ArrayGetCell(g_zclass_spd, g_zombieclass[id]))
	g_zombie_knockback[id] = Float:ArrayGetCell(g_zclass_kb, g_zombieclass[id])
	ArrayGetString(g_zclass_name, g_zombieclass[id], g_zombie_classname[id], charsmax(g_zombie_classname[]))
	
	// Set zombie attributes based on the mode
	static sound[64]
	if (!silentmode)
	{
		if (nemesis == 1)
		{
			do_random_spawn(id, 1);
			// Nemesis
			g_class[id] = NEMESIS;
			
			// Set health [0 = auto]
			if (get_pcvar_num(cvar_nemhp) == 0)
			{
				if (get_pcvar_num(cvar_nembasehp) == 0)
					set_user_health(id, ArrayGetCell(g_zclass_hp, 0) * fnGetAlive())
				else
					set_user_health(id, get_pcvar_num(cvar_nembasehp) * fnGetAlive())
			}
			else
				set_user_health(id, get_pcvar_num(cvar_nemhp))
			
			// Set gravity, unless frozen
			if (!g_frozen[id]) set_pev(id, pev_gravity, get_pcvar_float(cvar_nemgravity))
			else g_frozen_gravity[id] = get_pcvar_float(cvar_nemgravity)

			ExecuteHamB(Ham_Player_ResetMaxSpeed, id)

		}
		else if (nemesis == 2)
		{
			do_random_spawn(id, 1);
			// Nemesis
			g_class[id] = ALIEN;
			
			set_user_health(id, get_pcvar_num(cvar_alienhp) * fnGetAlive());
			if (!g_frozen[id]) set_pev(id, pev_gravity, get_pcvar_float(cvar_aliengvt))
			else g_frozen_gravity[id] = get_pcvar_float(cvar_aliengvt)

			strip_user_weapons(id);
			give_item(id, "weapon_knife");

			ExecuteHamB(Ham_Player_ResetMaxSpeed, id)

		}
		else if (nemesis == 3)
		{
			//do_random_spawn(id, 1);
			// Nemesis
			g_class[id] = BOSS;
			
			set_user_health(id, 15000 * fnGetAlive());

			strip_user_weapons(id);
			give_item(id, "weapon_knife");

			ExecuteHamB(Ham_Player_ResetMaxSpeed, id)

		}
		else if (fnGetZombies() == 1)
		{
			static rdn_zm; rdn_zm = random_num(0, 3);

			if(rdn_zm == 2) do_random_spawn(id, 1);
			// First zombie
			g_class[id] = FIRST_ZOMBIE;
			
			// Set health and gravity, unless frozen
			set_user_health(id, floatround(float(ArrayGetCell(g_zclass_hp, g_zombieclass[id])) * get_pcvar_float(cvar_zombiefirsthp)) + ammount_zhealth(g_habilidad[id][CLASS_ZOMBIE][1]))
			if (!g_frozen[id]) set_pev(id, pev_gravity, Float:ArrayGetCell(g_zclass_grav, g_zombieclass[id])- ammount_zgravity(g_habilidad[id][CLASS_ZOMBIE][3]))
			else g_frozen_gravity[id] = Float:ArrayGetCell(g_zclass_grav, g_zombieclass[id]) - ammount_zgravity(g_habilidad[id][CLASS_ZOMBIE][3])

			ExecuteHamB(Ham_Player_ResetMaxSpeed, id)
			
			// Infection sound
			ArrayGetString(zombie_infect, random_num(0, ArraySize(zombie_infect) - 1), sound, charsmax(sound))
			emit_sound(id, CHAN_VOICE, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
		else
		{
			// Infected by someone
			
			// Set health and gravity, unless frozen
			set_user_health(id, ArrayGetCell(g_zclass_hp, g_zombieclass[id]) + ammount_zhealth(g_habilidad[id][CLASS_ZOMBIE][1]))
			if (!g_frozen[id]) set_pev(id, pev_gravity, Float:ArrayGetCell(g_zclass_grav, g_zombieclass[id])- ammount_zgravity(g_habilidad[id][CLASS_ZOMBIE][3]))
			else g_frozen_gravity[id] = Float:ArrayGetCell(g_zclass_grav, g_zombieclass[id]) - ammount_zgravity(g_habilidad[id][CLASS_ZOMBIE][3])

			ExecuteHamB(Ham_Player_ResetMaxSpeed, id)
			
			// Infection sound
			ArrayGetString(zombie_infect, random_num(0, ArraySize(zombie_infect) - 1), sound, charsmax(sound))
			emit_sound(id, CHAN_VOICE, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
			
			// Show Infection HUD notice
			set_hudmessage(255, 0, 0, HUD_INFECT_X, HUD_INFECT_Y, 0, 0.0, 5.0, 1.0, 1.0, -1)
			
			if (infector) // infected by someone?
				ShowSyncHudMsg(0, g_MsgSync, "%L", LANG_PLAYER, "NOTICE_INFECT2", g_playername[id], g_playername[infector])
			else
				ShowSyncHudMsg(0, g_MsgSync, "%L", LANG_PLAYER, "NOTICE_INFECT", g_playername[id])
		}
	}
	else
	{
		// Silent mode, no HUD messages, no infection sounds
		
		// Set health and gravity, unless frozen
		set_user_health(id, ArrayGetCell(g_zclass_hp, g_zombieclass[id]) + ammount_zhealth(g_habilidad[id][CLASS_ZOMBIE][1]))
		if (!g_frozen[id]) set_pev(id, pev_gravity, Float:ArrayGetCell(g_zclass_grav, g_zombieclass[id])- ammount_zgravity(g_habilidad[id][CLASS_ZOMBIE][3]))
		else g_frozen_gravity[id] = Float:ArrayGetCell(g_zclass_grav, g_zombieclass[id]) - ammount_zgravity(g_habilidad[id][CLASS_ZOMBIE][3])

		ExecuteHamB(Ham_Player_ResetMaxSpeed, id)
	}
	
	// Remove previous tasks
	remove_task(id+TASK_BLOOD);
	remove_task(id+TASK_BURN);
	remove_task(TASK_CONTEO);
	remove_task(id+TASK_DROGA);

	// Switch to T
	if (fm_cs_get_user_team(id) != FM_CS_TEAM_T) // need to change team?
	{
		remove_task(id+TASK_TEAM)
		fm_cs_set_user_team(id, FM_CS_TEAM_T)
		fm_user_team_update(id)
	}
	static buffer2[80];

	cs_reset_user_model(id);
	// Set the right model, after checking that we don't already have it
	if (g_class[id] == NEMESIS)
	{
		formatex(g_playermodel[id], charsmax(g_playermodel[]), "%s", szNemesis);
		cs_set_user_model(id, szNemesis);
	}
	else if (g_class[id] == ALIEN)
	{
		formatex(g_playermodel[id], charsmax(g_playermodel[]), "%s", ModelAlien);
		cs_set_user_model(id, ModelAlien);
	}
	else
	{
		ArrayGetString(g_zclass_model, g_zombieclass[id], buffer2, charsmax(buffer2));
		//modelzm
		cs_set_user_model(id, buffer2);
	}
	
	// Nemesis glow / remove glow, unless frozen
	if (!g_frozen[id])
	{
		if (g_class[id] == NEMESIS)
			set_user_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 25)
		else if (g_class[id] == ALIEN)
			set_user_rendering(id, kRenderFxGlowShell, 0, 0, 225, kRenderNormal, 25)
		else
			set_user_rendering(id)
	}
	
	
	// Remove any zoom (bugfix)
	cs_set_user_zoom(id, CS_RESET_ZOOM, 1)
	
	// Remove armor
	set_pev(id, pev_armorvalue, 0.0)
	
	// Drop weapons when infected
	drop_weapons(id, 1)
	drop_weapons(id, 2)
	
	// Strip zombies from guns and give them a knife
	strip_user_weapons(id)
	give_item(id, "weapon_knife")
	
	// Fancy effects
	infection_effects(id)
	
	// Give Zombies Night Vision?
	if (get_pcvar_num(cvar_nvggive))
	{
		g_nvision[id] = true
		
		if (!g_isbot[id])
		{
			// Turn on Night Vision automatically?
			if (get_pcvar_num(cvar_nvggive) == 1)
			{
				// Custom nvg?
				if (get_pcvar_num(cvar_customnvg))
				{
					g_nvisionenabled[id] = true
					remove_task(id+TASK_NVISION)
					off(id)
					set_task(0.1, "set_user_nvision", id+TASK_NVISION, _, _, "b")
				}
			}
			// Turn off nightvision when infected (bugfix)
			else if (g_nvisionenabled[id])
			{
				if (get_pcvar_num(cvar_customnvg)) {
					remove_task(id+TASK_NVISION); 
					off(id);
				}
				g_nvisionenabled[id] = false
			}
		}
	}
	// Disable nightvision when infected (bugfix)
	else if (g_nvision[id])
	{
		if (get_pcvar_num(cvar_customnvg)) {
			remove_task(id+TASK_NVISION); 
			off(id);
		}
		
		g_nvision[id] = false
		g_nvisionenabled[id] = false
	}
	
	// Set custom FOV?
	if (get_pcvar_num(cvar_zombiefov) != 90 && get_pcvar_num(cvar_zombiefov) != 0)
	{
		message_begin(MSG_ONE, g_msgSetFOV, _, id)
		write_byte(get_pcvar_num(cvar_zombiefov)) // fov angle
		message_end()
	}
	
	// Idle sounds task
	if (g_class[id] < NEMESIS)
		set_task(random_float(50.0, 70.0), "zombie_play_idle", id+TASK_BLOOD, _, _, "b")
	
	// Post user infect forward
	ExecuteForward(g_fwUserInfected_post, g_fwDummyResult, id, infector, nemesis)
	
	// Last Zombie Check
	fnCheckLastZombie()
}

// Function Human Me (player id, turn into a survivor, silent mode)
humanme(id, survivor, silentmode)
{
	// User humanize attempt forward
	ExecuteForward(g_fwUserHumanize_attempt, g_fwDummyResult, id, survivor)
	
	// One or more plugins blocked the "humanization". Only allow this after making sure it's
	// not going to leave us with no humans. Take into account a last player leaving case.
	// BUGFIX: only allow after a mode has started, to prevent blocking first survivor e.g.
	if (g_fwDummyResult >= ZP_PLUGIN_HANDLED && g_modestarted && fnGetHumans() > g_lastplayerleaving)
		return;
	
	// Pre user humanize forward
	ExecuteForward(g_fwUserHumanized_pre, g_fwDummyResult, id, survivor)

	// Show zombie class menu if they haven't chosen any (e.g. just connected)
	/*if (g_humanclassnext[id] == ZCLASS_NONE && get_pcvar_num(cvar_zclasses))
		show_menu_zclass(id, CLASS_HUMAN);
	*/
	// Set selected zombie class
	g_humanclass[id] = g_humanclassnext[id]
	// If no class selected yet, use the first (default) one
	//if (g_humanclass[id] == ZCLASS_NONE) g_humanclass[id] = 0

	// Remove previous tasks
	g_has_speed_boost[id] = false
	remove_task(id+TASK_SPEED_BOOST);
	remove_task(id+TASK_BLOOD);
	remove_task(id+TASK_BURN);
	remove_task(id+TASK_NVISION);
	remove_task(TASK_CONTEO);
	remove_task(id+TASK_DROGA);
	off(id);

	// Cache speed, knockback, and name for player's class
	if (g_humanclass[id] != ZCLASS_NONE)
	{
		g_human_spd[id] = float(ArrayGetCell(g_zclass_spd, g_humanclass[id]))
		ArrayGetString(g_zclass_name, g_humanclass[id], g_human_classname[id], charsmax(g_human_classname[]))
	}
	
	
	// Reset some vars
	g_class[id] = HUMAN;
	g_iCategoria[id] = 0;
	g_nvision[id] = false
	g_nvisionenabled[id] = false
	g_bBalas[id] = 0;
	g_iBalasEspeciales[id] = 0;
	g_bMask[id] = 0;
	g_iNoJump[id] = 0;
	g_iFisher[id] = 0;
	g_iGhost[id] = 0;
	g_iJumpClass2[id] = 0;
	g_iJumpClass[id] = 0;
	g_iNoFire[ id ] = g_iNoFrost[ id ] = g_iNoPipe[ id ] = 0;
	// Remove survivor's aura (bugfix)
	set_pev(id, pev_effects, pev(id, pev_effects) &~ EF_BRIGHTLIGHT)
	
	// Remove spawn protection (bugfix)
	g_nodamage[id] = false
	set_pev(id, pev_effects, pev(id, pev_effects) &~ EF_NODRAW)
	
	// Reset burning duration counter (bugfix)
	g_burning_duration[id] = 0
	
	// Drop previous weapons
	drop_weapons(id, 1)
	drop_weapons(id, 2)
	
	// Strip off from weapons
	strip_user_weapons(id)
	give_item(id, "weapon_knife")
	
	// Set human attributes based on the mode
	if (survivor == 1)
	{
		// Survivor
		g_class[id] = SURVIVOR;
		
		// Set Health [0 = auto]
		if (get_pcvar_num(cvar_survhp) == 0)
		{
			if (get_pcvar_num(cvar_survbasehp) == 0)
				set_user_health(id, get_pcvar_num(cvar_humanhp) * fnGetAlive())
			else
				set_user_health(id, get_pcvar_num(cvar_survbasehp) * fnGetAlive())
		}
		else
			set_user_health(id, get_pcvar_num(cvar_survhp))
		
		// Set gravity, unless frozen
		if (!g_frozen[id]) set_pev(id, pev_gravity, get_pcvar_float(cvar_survgravity))
		
		// Give survivor his own weapon
		static survweapon[32]
		get_pcvar_string(cvar_survweapon, survweapon, charsmax(survweapon))
		give_item(id, survweapon)
		ExecuteHamB(Ham_GiveAmmo, id, MAXBPAMMO[cs_weapon_name_to_id(survweapon)], AMMOTYPE[cs_weapon_name_to_id(survweapon)], MAXBPAMMO[cs_weapon_name_to_id(survweapon)])
		
		g_iHe[id] = 3;
		give_item(id, "weapon_hegrenade");
		cs_set_user_bpammo(id, CSW_HEGRENADE, 3);
		
	}
	else if (survivor == 2)
	{
		g_class[id] = SNIPER;

		set_user_health(id, get_pcvar_num(cvar_sniperhp)* fnGetAlive())

		if (!g_frozen[id]) 
			set_pev(id, pev_gravity, get_pcvar_float(cvar_snipergvt)) 

		strip_user_weapons(id)
		give_item(id, "weapon_knife")
		give_item(id, "weapon_awp") 
		give_item(id, "weapon_flashbang");
		cs_set_user_bpammo(id, CSW_FLASHBANG, 3);
		g_iHe[id] = 3;
		give_item(id, "weapon_hegrenade");
		cs_set_user_bpammo(id, CSW_HEGRENADE, 3);
	}
	else if (survivor == 3)
	{
		g_class[id] = WESKER;

		set_user_health(id, get_pcvar_num(cvar_weskerhp) * fnGetAlive())

		if (!g_frozen[id]) 
			set_pev(id, pev_gravity, get_pcvar_float(cvar_weskergvt)) 

		strip_user_weapons(id)
		give_item(id, "weapon_deagle")
		give_item(id, "weapon_knife") 
		give_item(id, "weapon_flashbang");
		cs_set_user_bpammo(id, CSW_FLASHBANG, 3);
	}
	else if (survivor == 4)
	{
		g_class[id] = SIRIO;

		set_user_health(id, get_pcvar_num(cvar_siriohp) * fnGetAlive())

		if (!g_frozen[id]) 
			set_pev(id, pev_gravity, get_pcvar_float(cvar_siriogvt)) 

		strip_user_weapons(id);
		give_item(id, "weapon_knife") ;
		g_iHe[id] = 40;
		give_item(id, "weapon_hegrenade");
		cs_set_user_bpammo(id, CSW_HEGRENADE, 40);
	}
	else if (survivor == 5)
	{
		g_class[id] = NINJA;

		set_user_health(id, get_pcvar_num(cvar_ninjahp) * fnGetAlive())

		if (!g_frozen[id]) 
			set_pev(id, pev_gravity, get_pcvar_float(cvar_ninjagvt)) 

		strip_user_weapons(id);
		give_item(id, "weapon_knife");
	}
	else
	{
		// Human taking an antidote
		if (g_humanclass[id] != ZCLASS_NONE)
		{
			set_user_health(id, ArrayGetCell(g_zclass_hp, g_humanclass[id]));
			set_user_armor(id, ArrayGetCell(g_zclass_chaleco, g_humanclass[id]));
			if (!g_frozen[id]) set_pev(id, pev_gravity, Float:ArrayGetCell(g_zclass_grav, g_humanclass[id]));
		}
		else
		{
			// Set health
			set_user_health(id, get_pcvar_num(cvar_humanhp))
			// Set gravity, unless frozen
			if (!g_frozen[id]) set_pev(id, pev_gravity, get_pcvar_float(cvar_humangravity))
		}
		
		g_iCategoria[id] = 0;
		g_bAnterior[id] = false;
		// Show custom buy menu?
		/*if (get_pcvar_num(cvar_buycustom))
			set_task(1.0, "show_menu_buy1", id)*/
		if (get_pcvar_num(cvar_buycustom))
		{
			if(!g_bAutoSeleccion[id]) 
				set_task(1.3, "show_menu_buy1", id);
			else if(g_bAutoSeleccion[id])
			{
				set_task(1.2, "Anteriores", id);
			}
		}
		// Silent mode = no HUD messages, no antidote sound
		if (!silentmode)
		{
			// Antidote sound
			static sound[64]
			ArrayGetString(sound_antidote, random_num(0, ArraySize(sound_antidote) - 1), sound, charsmax(sound))
			emit_sound(id, CHAN_ITEM, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
			
			// Show Antidote HUD notice
			set_hudmessage(0, 0, 255, HUD_INFECT_X, HUD_INFECT_Y, 0, 0.0, 5.0, 1.0, 1.0, -1)
			ShowSyncHudMsg(0, g_MsgSync, "%L", LANG_PLAYER, "NOTICE_ANTIDOTE", g_playername[id])
		}
	}
	
	// Switch to CT
	if (fm_cs_get_user_team(id) != FM_CS_TEAM_CT) // need to change team?
	{
		remove_task(id+TASK_TEAM)
		fm_cs_set_user_team(id, FM_CS_TEAM_CT)
		fm_user_team_update(id)
	}
	//modelct
	static buffer[80];
	cs_reset_user_model(id);
	// Set the right model, after checking that we don't already have it
	if (g_class[id] == SURVIVOR)
	{
		formatex(g_playermodel[id], charsmax(g_playermodel[]), "%s", szSurvivor);
		cs_set_user_model(id, szSurvivor)
	}
	else if (g_class[id] == SNIPER)
	{
		formatex(g_playermodel[id], charsmax(g_playermodel[]), "%s", szSniper);
		cs_set_user_model(id, szSniper)
	}
	else if (g_class[id] == WESKER)
	{
		formatex(g_playermodel[id], charsmax(g_playermodel[]), "%s", szWesker);
		cs_set_user_model(id, szWesker)
	}
	else if (g_class[id] == SIRIO)
	{
		formatex(g_playermodel[id], charsmax(g_playermodel[]), "%s", szSirio);
		cs_set_user_model(id, szSirio)
	}
	else if (g_class[id] == NINJA)
	{
		formatex(g_playermodel[id], charsmax(g_playermodel[]), "%s", szSirio);
		cs_set_user_model(id, ModelNinja)
	}
	else
	{
		if (g_humanclass[id] != ZCLASS_NONE)
		{
			ArrayGetString(g_zclass_model, g_humanclass[id], buffer, charsmax(buffer))
			cs_set_user_model(id, buffer)
		}
		else
		{
			formatex(g_playermodel[id], charsmax(g_playermodel[]), "%s", szHuman);
			cs_set_user_model(id, szHuman)
		}
		
	}
	
	// Set survivor glow / remove glow, unless frozen
	if (!g_frozen[id])
	{
		if (g_class[id] >= SURVIVOR)
			set_user_rendering(id, kRenderFxGlowShell, random_num(0, 225), random_num(55, 225), random_num(125, 225), kRenderNormal, 25)
		else
			set_user_rendering(id)
	}
	
	
	// Restore FOV?
	if (get_pcvar_num(cvar_zombiefov) != 90 && get_pcvar_num(cvar_zombiefov) != 0)
	{
		message_begin(MSG_ONE, g_msgSetFOV, _, id)
		write_byte(90) // angle
		message_end()
	}
	
	// Give humanas Night Vision?
	if (get_pcvar_num(cvar_nvggive))
	{
		g_nvision[id] = true
		
		if (!g_isbot[id])
		{
			// Turn on Night Vision automatically?
			if (get_pcvar_num(cvar_nvggive) == 1)
			{
				// Custom nvg?
				if (get_pcvar_num(cvar_customnvg))
				{
					g_nvisionenabled[id] = true
					remove_task(id+TASK_NVISION)
					off(id)
					set_task(0.1, "set_user_nvision", id+TASK_NVISION, _, _, "b")
				}
			}
			// Turn off nightvision when infected (bugfix)
			else if (g_nvisionenabled[id])
			{
				if (get_pcvar_num(cvar_customnvg)) {
					remove_task(id+TASK_NVISION); 
					off(id);
				}
				g_nvisionenabled[id] = false
			}
		}
	}
	// Disable nightvision when infected (bugfix)
	else if (g_nvision[id])
	{
		if (get_pcvar_num(cvar_customnvg)) {
			remove_task(id+TASK_NVISION); 
			off(id);
		}
		
		g_nvision[id] = false
		g_nvisionenabled[id] = false
	}
	
	// Post user humanize forward
	ExecuteForward(g_fwUserHumanized_post, g_fwDummyResult, id, survivor)
	
	// Last Zombie Check
	fnCheckLastZombie()
}

/*================================================================================
 [Other Functions and Tasks]
=================================================================================*/

public cache_cvars()
{
	g_cached_zombiesilent = get_pcvar_num(cvar_zombiesilent)
	g_cached_humanspd = get_pcvar_float(cvar_humanspd)
	g_cached_nemspd = get_pcvar_float(cvar_nemspd)
	g_cached_survspd = get_pcvar_float(cvar_survspd)
	g_cached_leapzombies = get_pcvar_num(cvar_leapzombies)
	g_cached_leapzombiescooldown = get_pcvar_float(cvar_leapzombiescooldown)
	g_cached_leapnemesis = get_pcvar_num(cvar_leapnemesis)
	g_cached_leapnemesiscooldown = get_pcvar_float(cvar_leapnemesiscooldown)
	g_cached_leapsurvivor = get_pcvar_num(cvar_leapsurvivor)
	g_cached_leapsurvivorcooldown = get_pcvar_float(cvar_leapsurvivorcooldown)
}


load_customization_from_files()
{
	// Build customization file path
	new path[64]
	get_configsdir(path, charsmax(path))
	format(path, charsmax(path), "%s/%s", path, ZP_CUSTOMIZATION_FILE)
	
	// File not present
	if (!file_exists(path))
	{
		new error[100]
		formatex(error, charsmax(error), "Cannot load customization file %s!", path)
		set_fail_state(error)
		return;
	}
	
	// Set up some vars to hold parsing info
	new linedata[1024], key[64], value[960], section;
	
	// Open customization file for reading
	new file = fopen(path, "rt")
	
	while (file && !feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// Blank line or comment
		if (!linedata[0] || linedata[0] == ';') continue;
		
		// New section starting
		if (linedata[0] == '[')
		{
			section++
			continue;
		}
		
		// Get key and value(s)
		strtok(linedata, key, charsmax(key), value, charsmax(value), '=')
		
		// Trim spaces
		trim(key)
		trim(value)
		
		switch (section)
		{
			case SECTION_GRENADE_SPRITES:
			{
				if (equal(key, "TRAIL"))
					copy(sprite_grenade_trail, charsmax(sprite_grenade_trail), value)
				else if (equal(key, "RING"))
					copy(sprite_grenade_ring, charsmax(sprite_grenade_ring), value)
				else if (equal(key, "FIRE"))
					copy(sprite_grenade_fire, charsmax(sprite_grenade_fire), value)
				else if (equal(key, "SMOKE"))
					copy(sprite_grenade_smoke, charsmax(sprite_grenade_smoke), value)
				else if (equal(key, "GLASS"))
					copy(sprite_grenade_glass, charsmax(sprite_grenade_glass), value)
			}
			case SECTION_SOUNDS:
			{
				if (equal(key, "WIN ZOMBIES"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(sound_win_zombies, key)
					}
				}
				else if (equal(key, "WIN HUMANS"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(sound_win_humans, key)
					}
				}
				else if (equal(key, "WIN NO ONE"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(sound_win_no_one, key)
					}
				}
				else if (equal(key, "ZOMBIE INFECT"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(zombie_infect, key)
					}
				}
				else if (equal(key, "ZOMBIE PAIN"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(zombie_pain, key)
					}
				}
				else if (equal(key, "NEMESIS PAIN"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(nemesis_pain, key)
					}
				}
				else if (equal(key, "ZOMBIE DIE"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(zombie_die, key)
					}
				}
				else if (equal(key, "ZOMBIE FALL"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(zombie_fall, key)
					}
				}
				else if (equal(key, "ZOMBIE MISS SLASH"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(zombie_miss_slash, key)
					}
				}
				else if (equal(key, "ZOMBIE MISS WALL"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(zombie_miss_wall, key)
					}
				}
				else if (equal(key, "ZOMBIE HIT NORMAL"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(zombie_hit_normal, key)
					}
				}
				else if (equal(key, "ZOMBIE HIT STAB"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(zombie_hit_stab, key)
					}
				}
				else if (equal(key, "ZOMBIE IDLE"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(zombie_idle, key)
					}
				}
				else if (equal(key, "ZOMBIE IDLE LAST"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(zombie_idle_last, key)
					}
				}
				else if (equal(key, "ZOMBIE MADNESS"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(zombie_madness, key)
					}
				}
				else if (equal(key, "ROUND NEMESIS"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(sound_nemesis, key)
					}
				}
				else if (equal(key, "ROUND SURVIVOR"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(sound_survivor, key)
					}
				}
				else if (equal(key, "ROUND SWARM"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(sound_swarm, key)
					}
				}
				else if (equal(key, "ROUND MULTI"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(sound_multi, key)
					}
				}
				else if (equal(key, "ROUND PLAGUE"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(sound_plague, key)
					}
				}
				else if (equal(key, "GRENADE INFECT EXPLODE"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(grenade_infect, key)
					}
				}
				else if (equal(key, "GRENADE INFECT PLAYER"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(grenade_infect_player, key)
					}
				}
				else if (equal(key, "GRENADE FIRE EXPLODE"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(grenade_fire, key)
					}
				}
				else if (equal(key, "GRENADE FIRE PLAYER"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(grenade_fire_player, key)
					}
				}
				else if (equal(key, "GRENADE FROST EXPLODE"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(grenade_frost, key)
					}
				}
				else if (equal(key, "GRENADE FROST PLAYER"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(grenade_frost_player, key)
					}
				}
				else if (equal(key, "GRENADE FROST BREAK"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(grenade_frost_break, key)
					}
				}
				
				else if (equal(key, "ANTIDOTE"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(sound_antidote, key)
					}
				}
				else if (equal(key, "THUNDER"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(sound_thunder, key)
					}
				}
			}
			case SECTION_AMBIENCE_SOUNDS:
			{
				if (equal(key, "INFECTION ENABLE"))
					g_ambience_sounds[AMBIENCE_SOUNDS_INFECTION] = str_to_num(value)
				else if (g_ambience_sounds[AMBIENCE_SOUNDS_INFECTION] && equal(key, "INFECTION SOUNDS"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(sound_ambience1, key)
						ArrayPushCell(sound_ambience1_ismp3, equal(key[strlen(key)-4], ".mp3") ? 1 : 0)
					}
				}
				else if (g_ambience_sounds[AMBIENCE_SOUNDS_INFECTION] && equal(key, "INFECTION DURATIONS"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushCell(sound_ambience1_duration, str_to_num(key))
					}
				}
				else if (equal(key, "NEMESIS ENABLE"))
					g_ambience_sounds[AMBIENCE_SOUNDS_NEMESIS] = str_to_num(value)
				else if (g_ambience_sounds[AMBIENCE_SOUNDS_NEMESIS] && equal(key, "NEMESIS SOUNDS"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(sound_ambience2, key)
						ArrayPushCell(sound_ambience2_ismp3, equal(key[strlen(key)-4], ".mp3") ? 1 : 0)
					}
				}
				else if (g_ambience_sounds[AMBIENCE_SOUNDS_NEMESIS] && equal(key, "NEMESIS DURATIONS"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushCell(sound_ambience2_duration, str_to_num(key))
					}
				}
				else if (equal(key, "SURVIVOR ENABLE"))
					g_ambience_sounds[AMBIENCE_SOUNDS_SURVIVOR] = str_to_num(value)
				else if (g_ambience_sounds[AMBIENCE_SOUNDS_SURVIVOR] && equal(key, "SURVIVOR SOUNDS"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(sound_ambience3, key)
						ArrayPushCell(sound_ambience3_ismp3, equal(key[strlen(key)-4], ".mp3") ? 1 : 0)
					}
				}
				else if (g_ambience_sounds[AMBIENCE_SOUNDS_SURVIVOR] && equal(key, "SURVIVOR DURATIONS"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushCell(sound_ambience3_duration, str_to_num(key))
					}
				}
				else if (equal(key, "SWARM ENABLE"))
					g_ambience_sounds[AMBIENCE_SOUNDS_SWARM] = str_to_num(value)
				else if (g_ambience_sounds[AMBIENCE_SOUNDS_SWARM] && equal(key, "SWARM SOUNDS"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(sound_ambience4, key)
						ArrayPushCell(sound_ambience4_ismp3, equal(key[strlen(key)-4], ".mp3") ? 1 : 0)
					}
				}
				else if (g_ambience_sounds[AMBIENCE_SOUNDS_SWARM] && equal(key, "SWARM DURATIONS"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushCell(sound_ambience4_duration, str_to_num(key))
					}
				}
				else if (equal(key, "PLAGUE ENABLE"))
					g_ambience_sounds[AMBIENCE_SOUNDS_PLAGUE] = str_to_num(value)
				else if (g_ambience_sounds[AMBIENCE_SOUNDS_PLAGUE] && equal(key, "PLAGUE SOUNDS"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushString(sound_ambience5, key)
						ArrayPushCell(sound_ambience5_ismp3, equal(key[strlen(key)-4], ".mp3") ? 1 : 0)
					}
				}
				else if (g_ambience_sounds[AMBIENCE_SOUNDS_PLAGUE] && equal(key, "PLAGUE DURATIONS"))
				{
					// Parse sounds
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to sounds array
						ArrayPushCell(sound_ambience5_duration, str_to_num(key))
					}
				}
			}
			case SECTION_EXTRA_ITEMS_WEAPONS:
			{
				if (equal(key, "NAMES"))
				{
					// Parse weapon items
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to weapons array
						ArrayPushString(g_extraweapon_names, key)
					}
				}
				else if (equal(key, "ITEMS"))
				{
					// Parse weapon items
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to weapons array
						ArrayPushString(g_extraweapon_items, key)
					}
				}
				else if (equal(key, "COSTS"))
				{
					// Parse weapon items
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to weapons array
						ArrayPushCell(g_extraweapon_costs, str_to_num(key))
					}
				}
			}
			case SECTION_HARD_CODED_ITEMS_COSTS:
			{
				if (equal(key, "NIGHT VISION"))
					g_extra_costs2[EXTRA_NVISION] = str_to_num(value)
				else if (equal(key, "ANTIDOTE"))
					g_extra_costs2[EXTRA_ANTIDOTE] = str_to_num(value)
				else if (equal(key, "ZOMBIE MADNESS"))
					g_extra_costs2[EXTRA_MADNESS] = str_to_num(value)
				else if (equal(key, "INFECTION BOMB"))
					g_extra_costs2[EXTRA_INFBOMB] = str_to_num(value)
				else if(equal(key, "JUMP BOMB"))
					g_extra_costs2[EXTRA_JUMPBOMB] = str_to_num(value)
				else if (equal(key, "NO FROST"))
					g_extra_costs2[NO_FROST] = str_to_num(value)
				else if (equal(key, "NO FIRE"))
					g_extra_costs2[NO_FIRE] = str_to_num(value)
				else if (equal(key, "NO PIPE"))
					g_extra_costs2[NO_PIPE] = str_to_num(value)	
				else if(equal(key, "BALAS INFINITAS"))
					g_extra_costs2[BALAS_INFINITAS] = str_to_num(value);
				else if(equal(key, "BALAS CONGELADORAS"))
					g_extra_costs2[BALAS_CONGELADORAS] = str_to_num(value);
				else if(equal(key, "GASK MASK"))
					g_extra_costs2[GASK_MASK] = str_to_num(value);
				else if(equal(key, "SPEED BOOST"))
					g_extra_costs2[BOOST] = str_to_num(value);

				
			}
			case SECTION_WEATHER_EFFECTS:
			{
				if (equal(key, "RAIN"))
					g_ambience_rain = str_to_num(value)
				else if (equal(key, "SNOW"))
					g_ambience_snow = str_to_num(value)
				else if (equal(key, "FOG"))
					g_ambience_fog = str_to_num(value)
				else if (equal(key, "FOG DENSITY"))
					copy(g_fog_density, charsmax(g_fog_density), value)
				else if (equal(key, "FOG COLOR"))
					copy(g_fog_color, charsmax(g_fog_color), value)
			}
			case SECTION_SKY:
			{
				if (equal(key, "ENABLE"))
					g_sky_enable = str_to_num(value)
				else if (equal(key, "SKY NAMES"))
				{
					// Parse sky names
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to skies array
						ArrayPushString(g_sky_names, key)
						
						// Preache custom sky files
						formatex(linedata, charsmax(linedata), "gfx/env/%sbk.tga", key)
						engfunc(EngFunc_PrecacheGeneric, linedata)
						formatex(linedata, charsmax(linedata), "gfx/env/%sdn.tga", key)
						engfunc(EngFunc_PrecacheGeneric, linedata)
						formatex(linedata, charsmax(linedata), "gfx/env/%sft.tga", key)
						engfunc(EngFunc_PrecacheGeneric, linedata)
						formatex(linedata, charsmax(linedata), "gfx/env/%slf.tga", key)
						engfunc(EngFunc_PrecacheGeneric, linedata)
						formatex(linedata, charsmax(linedata), "gfx/env/%srt.tga", key)
						engfunc(EngFunc_PrecacheGeneric, linedata)
						formatex(linedata, charsmax(linedata), "gfx/env/%sup.tga", key)
						engfunc(EngFunc_PrecacheGeneric, linedata)
					}
				}
			}
			case SECTION_LIGHTNING:
			{
				if (equal(key, "LIGHTS"))
				{
					// Parse lights
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to lightning array
						ArrayPushString(lights_thunder, key)
					}
				}
			}
			
			case SECTION_KNOCKBACK:
			{
				// Format weapon entity name
				strtolower(key)
				format(key, charsmax(key), "weapon_%s", key)
				
				// Add value to knockback power array
				kb_weapon_power[cs_weapon_name_to_id(key)] = str_to_float(value)
			}
			case SECTION_OBJECTIVE_ENTS:
			{
				if (equal(key, "CLASSNAMES"))
				{
					// Parse classnames
					while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
					{
						// Trim spaces
						trim(key)
						trim(value)
						
						// Add to objective ents array
						ArrayPushString(g_objective_ents, key)
					}
				}
			}
		}
	}
	if (file) fclose(file)
	
}

// Register Ham Forwards for CZ bots
public register_ham_czbots(id)
{
	// Make sure it's a CZ bot and it's still connected
	if (g_hamczbots || !g_isconnected[id] || !get_pcvar_num(cvar_botquota))
		return;
	
	RegisterHamFromEntity(Ham_Spawn, id, "fw_PlayerSpawn_Post", 1)
	RegisterHamFromEntity(Ham_Killed, id, "fw_PlayerKilled")
	RegisterHamFromEntity(Ham_Killed, id, "fw_PlayerKilled_Post", 1)
	RegisterHamFromEntity(Ham_TakeDamage, id, "fw_TakeDamage")
	RegisterHamFromEntity(Ham_TakeDamage, id, "fw_TakeDamage_Post", 1)
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack")
	
	// Ham forwards for CZ bots succesfully registered
	g_hamczbots = true
	
	// If the bot has already spawned, call the forward manually for him
	if (is_user_alive(id)) fw_PlayerSpawn_Post(id)
}

// Refill BP Ammo Task
public refill_bpammo(const args[], id)
{
	// Player died or turned into a zombie
	if (!g_isalive[id] || g_class[id] >= ZOMBIE)
		return;
	
	set_msg_block(g_msgAmmoPickup, BLOCK_ONCE)
	ExecuteHamB(Ham_GiveAmmo, id, MAXBPAMMO[REFILL_WEAPONID], AMMOTYPE[REFILL_WEAPONID], MAXBPAMMO[REFILL_WEAPONID])
}

// Balance Teams Task
balance_teams()
{
	// Get amount of users playing
	static iPlayersnum
	iPlayersnum = fnGetPlaying()
	
	// No players, don't bother
	if (iPlayersnum < 1) return;
	
	// Split players evenly
	static iTerrors, iMaxTerrors, id, CsTeams:team[33]
	iMaxTerrors = iPlayersnum/2
	iTerrors = 0
	
	// First, set everyone to CT
	for (id = 1; id <= g_maxplayers; id++)
	{
		// Skip if not connected
		if (!g_isconnected[id])
			continue;
		
		team[id] = cs_get_user_team(id)//error
		
		// Skip if not playing
		if (team[id] == CS_TEAM_SPECTATOR || team[id] == CS_TEAM_UNASSIGNED)
			continue;
		
		// Set team
		remove_task(id+TASK_TEAM)
		cs_set_user_team(id, CS_TEAM_CT)
		team[id] = CS_TEAM_CT
	}
	
	// Then randomly set half of the players to Terrorists
	while (iTerrors < iMaxTerrors)
	{
		// Keep looping through all players
		if (++id > g_maxplayers) id = 1
		
		// Skip if not connected
		if (!g_isconnected[id])
			continue;
		
		// Skip if not playing or already a Terrorist
		if (team[id] != CS_TEAM_CT)
			continue;
		
		// Random chance
		if (random_num(0, 1))
		{
			cs_set_user_team(id, CS_TEAM_T)
			team[id] = CS_TEAM_T
			iTerrors++
		}
	}
}

// Welcome Message Task
public welcome_msg()
{
	zp_colored_print(0, "^x4%s ^x1Voces activadas en ^x4Z, X, & Y.", g_szPrefix);
	zp_colored_print(0, "^x4%s ^x1Si eres ^4STEAM ^x1 Ganas APS ^4X2", g_szPrefix);
	// Show T-virus HUD notice
	set_hudmessage(0, 125, 200, HUD_EVENT_X, HUD_EVENT_Y, 0, 0.0, 3.0, 2.0, 1.0, -1);
	ShowSyncHudMsg(0, g_MsgSync, "%L", LANG_PLAYER, "NOTICE_VIRUS_FREE");

	get_BestRecord();
}

// Respawn Player Task
public respawn_player_task(taskid)
{
	//player alive
	if (is_user_alive(ID_SPAWN) || g_endround)
	    return;
	// Get player's team
	new CsTeams:team = cs_get_user_team(ID_SPAWN)
	// Player moved to spectators
	if (team == CS_TEAM_SPECTATOR || team == CS_TEAM_UNASSIGNED)
	    return;
	
	// Respawn player automatically if allowed on current round
	if (g_currentmode <= MODE_MULTI)
	{
		// Respawn as zombie?
		if (get_pcvar_num(cvar_deathmatch) == 2 || (get_pcvar_num(cvar_deathmatch) == 3 && random_num(0, 1)) || (get_pcvar_num(cvar_deathmatch) == 4 && fnGetZombies() < fnGetAlive()/2))
			g_respawn_as_zombie[ID_SPAWN] = true
			
		// Override respawn as zombie setting on nemesis and survivor rounds
		if (g_currentmode == MODE_SURVIVOR) g_respawn_as_zombie[ID_SPAWN] = true
		else if (g_currentmode == MODE_NEMESIS) g_respawn_as_zombie[ID_SPAWN] = false
		
		respawn_player_manually(ID_SPAWN)
	}
}

// Respawn Player Manually (called after respawn checks are done)
respawn_player_manually(id)
{
	if(active_button() || g_iExplote[id] || !get_pcvar_num(cvar_modes))
		return;
		
	// Set proper team before respawning, so that the TeamInfo message that's sent doesn't confuse PODBots
	if (g_respawn_as_zombie[id])
		cs_set_user_team(id, CS_TEAM_T);
	else
		cs_set_user_team(id, CS_TEAM_CT);
	
	// Respawning a player has never been so easy
	ExecuteHamB(Ham_CS_RoundRespawn, id);

	if(g_class[id] >= ZOMBIE && g_class[id] < NEMESIS)
	{
		if(g_iCanKill[id] < 3 && g_iExplote[id] == 0)
		{
			set_user_origin( id, g_fOrigin[ id ] );

			if(is_player_stuck(id))
				do_random_spawn(id, 1);

			++g_iCanKill[id];
		}
	}
}

// Check Round Task -check that we still have both zombies and humans on a round-
check_round(leaving_player)
{
	// Round ended or make_a_zombie task still active
	if (g_endround || task_exists(TASK_MAKEZOMBIE))
		return;
	
	// Get alive players count
	static iPlayersnum, id
	iPlayersnum = fnGetAlive()
	
	// Last alive player, don't bother
	if (iPlayersnum < 2)
		return;
	
	// Last zombie disconnecting
	if (g_class[leaving_player] >= ZOMBIE && fnGetZombies() == 1)
	{
		// Only one CT left, don't bother
		if (fnGetHumans() == 1 && fnGetCTs() == 1)
			return;
		
		// Pick a random one to take his place
		while ((id = fnGetRandomAlive(random_num(1, iPlayersnum))) == leaving_player ) { /* keep looping */ }
		
		// Show last zombie left notice
		zp_colored_print(0, "^x04%s^x01 %L", g_szPrefix, LANG_PLAYER, "LAST_ZOMBIE_LEFT", g_playername[id])
		
		// Set player leaving flag
		// Turn into a Nemesis or just a zombie?
		g_lastplayerleaving = true
		switch(g_class[leaving_player])
		{
			case ZOMBIE..LAST_ZOMBIE:
			{
				zombieme(id, 0, 0, 0, 0)
			}
			case NEMESIS:
			{
				zombieme(id, 0, 1, 0, 0)
			}
			case ALIEN:
			{
				zombieme(id, 0, 2, 0, 0)
			}
			case BOSS:
			{
				zombieme(id, 0, 1, 0, 0);
				//ExecuteForward(g_fwRoundStart, g_fwDummyResult, MODE_BOSS, id);
			}
		}
		// Remove player leaving flag
		g_lastplayerleaving = false
		
		// If Nemesis, set chosen player's health to that of the one who's leaving
		if (get_pcvar_num(cvar_keephealthondisconnect) && g_class[leaving_player] >= NEMESIS)
			set_user_health(id, pev(leaving_player, pev_health))
	}
	
	// Last human disconnecting
	else if (g_class[leaving_player] < ZOMBIE && fnGetHumans() == 1)
	{
		// Only one T left, don't bother
		if (fnGetZombies() == 1 && fnGetTs() == 1)
			return;
		
		// Pick a random one to take his place
		while ((id = fnGetRandomAlive(random_num(1, iPlayersnum))) == leaving_player ) { /* keep looping */ }
		
		// Show last human left notice
		zp_colored_print(0, "^x04%s^x01 %L", g_szPrefix, LANG_PLAYER, "LAST_HUMAN_LEFT", g_playername[id])
		
		// Set player leaving flag
		g_lastplayerleaving = true
		
		// Turn into a Survivor or just a human?
		switch(g_class[leaving_player]){
			case HUMAN..LAST_HUMAN:{
				humanme(id, 0, 0);
			}
			case SURVIVOR:{
				humanme(id, 1, 0);
			}
			case SNIPER:{
				humanme(id, 2, 0);
			}
			case WESKER:{
				humanme(id, 3, 0);
			}
			case SIRIO:{
				humanme(id, 4, 0);
			}
			case NINJA:{
				humanme(id, 5, 0);
			}
		}
		
		// Remove player leaving flag
		g_lastplayerleaving = false
		
		// If Survivor, set chosen player's health to that of the one who's leaving
		if (get_pcvar_num(cvar_keephealthondisconnect) && g_class[leaving_player] >= SURVIVOR)
			set_user_health(id, pev(leaving_player, pev_health))
	}
}

// Ambience Sound Effects Task
public ambience_sound_effects(taskid)
{
	// Play a random sound depending on the round
	static sound[64], iRand, duration, ismp3
	
	if (g_currentmode == MODE_NEMESIS) // Nemesis Mode
	{
		iRand = random_num(0, ArraySize(sound_ambience2) - 1)
		ArrayGetString(sound_ambience2, iRand, sound, charsmax(sound))
		duration = ArrayGetCell(sound_ambience2_duration, iRand)
		ismp3 = ArrayGetCell(sound_ambience2_ismp3, iRand)
	}
	else if (g_currentmode == MODE_SURVIVOR) // Survivor Mode
	{
		iRand = random_num(0, ArraySize(sound_ambience3) - 1)
		ArrayGetString(sound_ambience3, iRand, sound, charsmax(sound))
		duration = ArrayGetCell(sound_ambience3_duration, iRand)
		ismp3 = ArrayGetCell(sound_ambience3_ismp3, iRand)
	}
	else if (g_currentmode == MODE_SWARM) // Swarm Mode
	{
		iRand = random_num(0, ArraySize(sound_ambience4) - 1)
		ArrayGetString(sound_ambience4, iRand, sound, charsmax(sound))
		duration = ArrayGetCell(sound_ambience4_duration, iRand)
		ismp3 = ArrayGetCell(sound_ambience4_ismp3, iRand)
	}
	else if (g_currentmode == MODE_PLAGUE) // Plague Mode
	{
		iRand = random_num(0, ArraySize(sound_ambience5) - 1)
		ArrayGetString(sound_ambience5, iRand, sound, charsmax(sound))
		duration = ArrayGetCell(sound_ambience5_duration, iRand)
		ismp3 = ArrayGetCell(sound_ambience5_ismp3, iRand)
	}
	else // Infection Mode
	{
		iRand = random_num(0, ArraySize(sound_ambience1) - 1)
		ArrayGetString(sound_ambience1, iRand, sound, charsmax(sound))
		duration = ArrayGetCell(sound_ambience1_duration, iRand)
		ismp3 = ArrayGetCell(sound_ambience1_ismp3, iRand)
	}
	
	// Play it on clients
	if (ismp3)
		client_cmd(0, "mp3 play ^"sound/%s^"", sound)
	else
		PlaySound(sound)
	
	// Set the task for when the sound is done playing
	set_task(float(duration), "ambience_sound_effects", TASK_AMBIENCESOUNDS)
}

// Ambience Sounds Stop Task
ambience_sound_stop()
{
	client_cmd(0, "mp3 stop; stopsound")
}

// Remove Spawn Protection Task
public remove_spawn_protection(taskid)
{
	// Not alive
	if (!g_isalive[ID_SPAWN])
		return;
	
	// Remove spawn protection
	g_nodamage[ID_SPAWN] = false
	set_pev(ID_SPAWN, pev_effects, pev(ID_SPAWN, pev_effects) & ~EF_NODRAW)
}

// Hide Player's Money Task
public task_hide_money(taskid)
{
	// Not alive
	if (!g_isalive[ID_SPAWN])
		return;
	
	// Hide money
	message_begin(MSG_ONE, g_msgHideWeapon, _, ID_SPAWN)
	write_byte(HIDE_MONEY) // what to hide bitsum
	message_end()
	
	// Hide the HL crosshair that's drawn
	message_begin(MSG_ONE, g_msgCrosshair, _, ID_SPAWN)
	write_byte(0) // toggle
	message_end()

	message_begin(MSG_ONE, g_msgHideWeapon, _, ID_SPAWN)
	write_byte(HIDE_RHA) // what to hide bitsum
	message_end() //agregado
}

public hook(entity) 
{ 
	if (!pev_valid(entity)) 
	{ 
	    remove_task(entity) 
	    return 
	} 

	emit_sound(entity, CHAN_WEAPON, g_sound, 1.0, ATTN_NORM, 0, PITCH_HIGH); 

	static Float:entOrigin[3], flOrigin[3], PlayerPos[3], distance 
	pev(entity, pev_origin, entOrigin); 

	flOrigin[0] = floatround(entOrigin[0]) 
	flOrigin[1] = floatround(entOrigin[1]) 
	flOrigin[2] = floatround(entOrigin[2]) 

	for (new i = 1; i <= g_maxplayers; i++) 
	{ 
	    if(!is_user_alive(i) || g_class[i] < ZOMBIE || g_iNoPipe[i]) 
	        continue 
	    
	    get_user_origin(i, PlayerPos) 
	    
	    distance = get_distance(PlayerPos, flOrigin) 
	    
	    if (distance <= get_pcvar_num(cvar_radius))  
	    { 
	        new Float:fl_Velocity[3] 
	        
	        if (distance > 25) 
	        { 
	            new Float:fl_Time = distance / 650.0 
	            
	            fl_Velocity[0] = (flOrigin[0] - PlayerPos[0]) / fl_Time 
	            fl_Velocity[1] = (flOrigin[1] - PlayerPos[1]) / fl_Time 
	            fl_Velocity[2] = (flOrigin[2] - PlayerPos[2]) / fl_Time 
	        } 
	        else 
	        { 
	            fl_Velocity[0] = 0.0 
	            fl_Velocity[1] = 0.0 
	            fl_Velocity[2] = 0.0 
	        } 
	        
	        entity_set_vector(i, EV_VEC_velocity, fl_Velocity) 
	    } 
	} 
} 

public deleteGren(entity) 
{ 
	if (!pev_valid(entity)) 
	    return 

	new Float:originF[3] 
	pev(entity, pev_origin, originF); 

	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0) 
	write_byte(TE_EXPLOSION) 
	engfunc(EngFunc_WriteCoord, originF[0]) 
	engfunc(EngFunc_WriteCoord, originF[1]) 
	engfunc(EngFunc_WriteCoord, originF[2]) 
	write_short(g_fire) //sprite index 
	write_byte(25) // scale in 0.1's 
	write_byte(10) // framerate 
	write_byte(0) // flags 
	message_end() 

	static flOrigin[3], PlayerPos[3], distance 
	pev(entity, pev_origin, originF); 
	new attacker = pev(entity, pev_owner) 

	flOrigin[0] = floatround(originF[0]) 
	flOrigin[1] = floatround(originF[1]) 
	flOrigin[2] = floatround(originF[2]) 

	for (new i = 1; i <= g_maxplayers; i++) 
	{ 
	    if(is_user_alive(i))  
	    { 
	        if(g_class[i] < ZOMBIE || g_iNoPipe[i]) 
	            continue 
	        
	        get_user_origin(i, PlayerPos) 
	        
	        distance = get_distance(PlayerPos, flOrigin) 
	        
	        if (distance <= get_pcvar_num(cvar_radius))  
	        { 
	            if(get_user_health(i) - get_pcvar_float(cvar_damage) > 0) 
	                fakedamage(i, "Pipe Bomb", get_pcvar_float(cvar_damage), 256); 
	            else 
	                ExecuteHamB(Ham_Killed, i, attacker, 2) 
	            
	            static Float: originP[3] 
	            pev(i, pev_origin, originP) 
	            
	            originP[0] = (originF[0] - flOrigin[0]) * 10.0  
	            originP[1] = (originP[1] - flOrigin[1]) * 10.0  
	            originP[2] = (originP[2] - flOrigin[2]) + 550.0 - float(distance) 
	            
	            set_pev(i, pev_velocity, originP) 
	        } 
	    } 
	} 

	remove_task(entity) 
	remove_entity(entity) 
} 

public light(const Float:originF[3])  // Blast ring and small red light around nade from zombie_plague40.sma. Great thx, MeRcyLeZZ!!! ;) 
{ 
	// Lighting 
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, originF, 0); 
	write_byte(TE_DLIGHT); // TE id 
	engfunc(EngFunc_WriteCoord, originF[0]); // x 
	engfunc(EngFunc_WriteCoord, originF[1]); // y 
	engfunc(EngFunc_WriteCoord, originF[2]); // z 
	write_byte(5); // radius 
	write_byte(128); // r 
	write_byte(0); // g 
	write_byte(0); // b 
	write_byte(51); //life 
	write_byte(0); //decay rate 
	message_end(); 
} 
// Infection Bomb Explosion
infection_explode(ent)
{
	// Round ended (bugfix)
	if (g_endround) return;
	
	// Get origin
	static Float:originF[3]
	pev(ent, pev_origin, originF)
	
	// Make the explosion
	create_blast(originF)
	
	// Infection nade explode sound
	static sound[64]
	ArrayGetString(grenade_infect, random_num(0, ArraySize(grenade_infect) - 1), sound, charsmax(sound))
	emit_sound(ent, CHAN_WEAPON, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	// Get attacker
	static attacker
	attacker = pev(ent, pev_owner)
	
	// Collisions
	static victim, infected_victims;
	victim = -1, infected_victims = 0;
	
	while ((victim = engfunc(EngFunc_FindEntityInSphere, victim, originF, NADE_EXPLOSION_RADIUS)) != 0)
	{
		// Only effect alive non-spawnprotected humans
		if (!is_user_valid_alive(victim) || g_class[victim] >= ZOMBIE || g_nodamage[victim] || g_bMask[victim] || infected_victims >= 2)
			continue;
		
		// Last human is killed
		if (fnGetHumans() == 1)
		{
			ExecuteHamB(Ham_Killed, victim, attacker, 0)
			continue;
		}
		
		// Infected victim's sound
		ArrayGetString(grenade_infect_player, random_num(0, ArraySize(grenade_infect_player) - 1), sound, charsmax(sound))
		emit_sound(victim, CHAN_VOICE, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
		
		// Turn into zombie
		zombieme(victim, attacker, 0, 1, 1);
		++infected_victims;
	}
	
	// Get rid of the grenade
	engfunc(EngFunc_RemoveEntity, ent)
}
// Bubble Grenade Explosion
public bubble_explode(ent)
{
	if ( ent < 0 )
		return PLUGIN_HANDLED;
		
	static Float:originF[3];
	pev(ent, pev_origin, originF);

	create_blast9(originF);

	new iEntity = create_entity("info_target");

	if(!is_valid_ent(iEntity))
	    return PLUGIN_HANDLED;

	entity_set_string(iEntity, EV_SZ_classname, entclas);

	entity_set_vector(iEntity,EV_VEC_origin, originF);
	entity_set_model(iEntity,model);
	entity_set_int(iEntity, EV_INT_solid, SOLID_TRIGGER);
	entity_set_int(iEntity, EV_INT_movetype, MOVETYPE_FLY);
	entity_set_size(iEntity, Float: {-110.0, -110.0, -110.0}, Float: {110.0, 110.0, 110.0});
	entity_set_int(iEntity, EV_INT_renderfx, kRenderFxGlowShell);
	entity_set_int(iEntity, EV_INT_rendermode, kRenderTransAlpha);
	entity_set_float(iEntity, EV_FL_renderamt, 50.0);
    
	new Float:vColor[3];

	for(new i = 0; i < 3; i++)
		vColor[i] = random_float(0.0, 255.0);

	entity_set_vector(iEntity, EV_VEC_rendercolor, vColor);

	drop_to_floor( iEntity );
	
	engfunc(EngFunc_RemoveEntity, ent)

	set_task(get_pcvar_float(cvar_timeCampo), "DeleteEntity", iEntity);

	return PLUGIN_CONTINUE;
}
public DeleteEntity(entity)
{
	if( is_valid_ent(entity) )
		remove_entity(entity);
} 
// Fire Grenade Explosion
fire_explode(ent)
{
	// Get origin
	static Float:originF[3]
	pev(ent, pev_origin, originF)
	
	// Make the explosion
	create_blast2(originF)
	
	// Fire nade explode sound
	static sound[64]
	ArrayGetString(grenade_fire, random_num(0, ArraySize(grenade_fire) - 1), sound, charsmax(sound))
	emit_sound(ent, CHAN_WEAPON, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	// Collisions
	static victim
	victim = -1
	
	while ((victim = engfunc(EngFunc_FindEntityInSphere, victim, originF, NADE_EXPLOSION_RADIUS)) != 0)
	{
		// Only effect alive zombies
		if (!is_user_valid_alive(victim) || g_class[victim] < ZOMBIE || g_nodamage[victim] || g_iNoFire[victim])
			continue;
		
		// Heat icon?
		if (get_pcvar_num(cvar_hudicons))
		{
			message_begin(MSG_ONE_UNRELIABLE, g_msgDamage, _, victim)
			write_byte(0) // damage save
			write_byte(0) // damage take
			write_long(DMG_BURN) // damage type
			write_coord(0) // x
			write_coord(0) // y
			write_coord(0) // z
			message_end()
		}
		
		if (g_class[victim] >= NEMESIS) // fire duration (nemesis is fire resistant)
			g_burning_duration[victim] += get_pcvar_num(cvar_fireduration)
		else
			g_burning_duration[victim] += get_pcvar_num(cvar_fireduration) * 5
		
		// Set burning task on victim if not present
		if (!task_exists(victim+TASK_BURN))
			set_task(0.2, "burning_flame", victim+TASK_BURN, _, _, "b")
	}
	
	// Get rid of the grenade
	engfunc(EngFunc_RemoveEntity, ent)
}
//Jump Granade Explosion
public jumping_explode ( Entity )
{
	if ( Entity < 0 )
		return
	       
	static Float:flOrigin [ 3 ];
	new attacker = pev(Entity, pev_owner);
	pev ( Entity, pev_origin, flOrigin )
	       
	engfunc ( EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, flOrigin, 0 )
	write_byte ( TE_SPRITE )
	engfunc ( EngFunc_WriteCoord, flOrigin [ 0 ] )
	engfunc ( EngFunc_WriteCoord, flOrigin [ 1 ] )
	engfunc ( EngFunc_WriteCoord, flOrigin [ 2 ] + 45.0 )
	write_short ( g_iExplo )
	write_byte ( 35 )
	write_byte ( 186 )
	message_end ( )
	       
	emit_sound ( Entity, CHAN_WEAPON, g_SoundBombExplode[random_num(0, sizeof g_SoundBombExplode-1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM )
       
	for ( new i = 1; i <= g_maxplayers; i++ )
	{
		if ( !is_user_alive( i ) || g_iNoJump[ i ] )
			continue
		                  
		new Float:flVictimOrigin [ 3 ]
		pev ( i, pev_origin, flVictimOrigin )
		           
		new Float:flDistance = get_distance_f ( flOrigin, flVictimOrigin )   
		           
		if ( flDistance <= get_pcvar_float(cvar_jump_radius) )
		{
			static Float:flSpeed
			flSpeed = get_pcvar_float ( cvar_speed )
			               
			static Float:flNewSpeed
			flNewSpeed = flSpeed * ( 1.0 - ( flDistance / get_pcvar_float(cvar_jump_radius) ) )
			               
			static Float:flVelocity [ 3 ];
			get_speed_vector ( flOrigin, flVictimOrigin, flNewSpeed, flVelocity );
			               
			set_pev ( i, pev_velocity, flVelocity );

			message_begin(MSG_ONE_UNRELIABLE, g_msgScreenShake, _, i)
			write_short(UNIT_SECOND*4) // amplitude             
			write_short(UNIT_SECOND*10) // duration
			write_short(UNIT_SECOND*10) // frequency
			message_end()	
			                
			if(get_user_health(i) > 10.0) 
				fakedamage(i, "knockback-bomb", 10.0,  DMG_BLAST);
			else 
				ExecuteHamB(Ham_Killed, i, attacker, 2) ;
		}
	}

	engfunc( EngFunc_RemoveEntity, Entity )
}       

// droga Granade Explosion
droga_explode(ent)
{        
    static Float:originF[3];
    pev(ent, pev_origin, originF);

    create_blast9(originF);
    
    static Float:originF2[3];
    static Float:distanceF;
    
    for(new victim = 1; victim <= g_maxplayers; victim++)
    {
        if(g_class[victim] < ZOMBIE || g_iNoDroga[victim])
            continue;
        
        pev(victim, pev_origin, originF2);
        distanceF = get_distance_f(originF, originF2);
        
        if (distanceF < get_pcvar_num(cvar_radiodroga))
        {
	        set_task(1.0, "movimiento", victim+TASK_DROGA, _, _, "a", get_pcvar_num(cvar_timedroga));
	        set_task(1.0, "droga_efect", victim+TASK_DROGA, _, _, "a", get_pcvar_num(cvar_timedroga));
	        client_cmd(victim, "spk %s", sound_drogado);
        }
    }
    engfunc( EngFunc_RemoveEntity, ent )
}

public movimiento(taskid)
{
	set_dhudmessage(250, 250, 250, -1.0, 0.17,  0, 6.0, 1.0);
	show_dhudmessage(ID_DROGA, "Estas Drogado...");

	message_begin(MSG_ONE, g_msgScreenFade, _, ID_DROGA);
	write_short((1<<12));
	write_short(0);
	write_short(0x0000) ;
	write_byte(180);
	write_byte(0);
	write_byte(0);
	write_byte(200);
	message_end();

	new Float:fVec[3];
	fVec[0] = random_float(50.0, 150.0);
	fVec[1] = random_float(50.0, 150.0);
	fVec[2] = random_float(50.0, 150.0);

	set_pev(ID_DROGA, pev_punchangle, fVec);
}

public droga_efect(taskid)
{
	new r = random(250);
	new g = random(250);
	new b = random(250);

	message_begin(MSG_ONE, g_msgScreenFade,{0,0,0}, ID_DROGA);
	write_short(1<<15);
	write_short(1<<13);
	write_short(1<<12); 
	write_byte( r ); 
	write_byte( g ); 
	write_byte( b ); 
	write_byte( 160 );
	message_end();
}
create_blast9(const Float:originF[3]) // le damos un nuevo efecto
{
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	engfunc(EngFunc_WriteCoord, originF[0]) // x axis
	engfunc(EngFunc_WriteCoord, originF[1]) // y axis
	engfunc(EngFunc_WriteCoord, originF[2]+385.0) // z axis
	write_short(g_exploSpr) // sprite
	write_byte(0) // 
	write_byte(0) // 
	write_byte(4) // vida
	write_byte(100) // ancho
	write_byte(0) // 
	write_byte(250) // rojo
	write_byte(0) // verde
	write_byte(250) // azul
	write_byte(200) // brillo
	write_byte(0) // velocidad
	message_end()

	// anillo del medio
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	engfunc(EngFunc_WriteCoord, originF[0]) // x axis
	engfunc(EngFunc_WriteCoord, originF[1]) // y axis
	engfunc(EngFunc_WriteCoord, originF[2]+470.0) // z axis
	write_short(g_exploSpr) 
	write_byte(0) 
	write_byte(0)
	write_byte(4) 
	write_byte(100) 
	write_byte(0) 
	write_byte(250) 
	write_byte(0) 
	write_byte(250) 
	write_byte(200) 
	write_byte(0)
	message_end()

	// anillo mas grande
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) 
	engfunc(EngFunc_WriteCoord, originF[0]) 
	engfunc(EngFunc_WriteCoord, originF[1]) 
	engfunc(EngFunc_WriteCoord, originF[2])
	engfunc(EngFunc_WriteCoord, originF[0]) 
	engfunc(EngFunc_WriteCoord, originF[1]) 
	engfunc(EngFunc_WriteCoord, originF[2]+555.0) 
	write_short(g_exploSpr) 
	write_byte(0) 
	write_byte(0) 
	write_byte(4) 
	write_byte(100) 
	write_byte(0) 
	write_byte(250) 
	write_byte(0) 
	write_byte(250) 
	write_byte(200) 
	write_byte(0) 
	message_end()
} 
// Frost Grenade Explosion
frost_explode(ent)
{
	// Get origin
	static Float:originF[3]
	pev(ent, pev_origin, originF)
	
	// Make the explosion
	create_blast3(originF)
	
	// Frost nade explode sound
	static sound[64]
	ArrayGetString(grenade_frost, random_num(0, ArraySize(grenade_frost) - 1), sound, charsmax(sound))
	emit_sound(ent, CHAN_WEAPON, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	// Collisions
	static victim
	victim = -1
	
	while ((victim = engfunc(EngFunc_FindEntityInSphere, victim, originF, NADE_EXPLOSION_RADIUS)) != 0)
	{
		// Only effect alive unfrozen zombies
		if (!is_user_valid_alive(victim) || g_class[victim] < ZOMBIE || g_frozen[victim] || g_nodamage[victim] || g_iNoFrost[victim])
			continue;
		
		// Nemesis shouldn't be frozen
		if (g_class[victim] >= NEMESIS)
		{
			// Get player's origin
			static origin2[3]
			get_user_origin(victim, origin2)
			
			// Broken glass sound
			ArrayGetString(grenade_frost_break, random_num(0, ArraySize(grenade_frost_break) - 1), sound, charsmax(sound))
			emit_sound(victim, CHAN_BODY, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
			
			// Glass shatter
			message_begin(MSG_PVS, SVC_TEMPENTITY, origin2)
			write_byte(TE_BREAKMODEL) // TE id
			write_coord(origin2[0]) // x
			write_coord(origin2[1]) // y
			write_coord(origin2[2]+24) // z
			write_coord(16) // size x
			write_coord(16) // size y
			write_coord(16) // size z
			write_coord(random_num(-50, 50)) // velocity x
			write_coord(random_num(-50, 50)) // velocity y
			write_coord(25) // velocity z
			write_byte(10) // random velocity
			write_short(g_glassSpr) // model
			write_byte(10) // count
			write_byte(25) // life
			write_byte(BREAK_GLASS) // flags
			message_end()
			
			continue;
		}
		
		// Freeze icon?
		if (get_pcvar_num(cvar_hudicons))
		{
			message_begin(MSG_ONE_UNRELIABLE, g_msgDamage, _, victim)
			write_byte(0) // damage save
			write_byte(0) // damage take
			write_long(DMG_DROWN) // damage type - DMG_FREEZE
			write_coord(0) // x
			write_coord(0) // y
			write_coord(0) // z
			message_end()
		}
		
		// Freeze sound
		ArrayGetString(grenade_frost_player, random_num(0, ArraySize(grenade_frost_player) - 1), sound, charsmax(sound))
		emit_sound(victim, CHAN_BODY, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
		
		// Add a blue tint to their screen
		message_begin(MSG_ONE, g_msgScreenFade, _, victim)
		write_short(0) // duration
		write_short(0) // hold time
		write_short(FFADE_STAYOUT) // fade type
		write_byte(0) // red
		write_byte(50) // green
		write_byte(200) // blue
		write_byte(100) // alpha
		message_end()
		
		// Set the frozen flag
		g_frozen[victim] = true
		
		// Save player's old gravity (bugfix)
		pev(victim, pev_gravity, g_frozen_gravity[victim])
		
		// Prevent from jumping
		if (pev(victim, pev_flags) & FL_ONGROUND)
			set_pev(victim, pev_gravity, 999999.9) // set really high
		else
			set_pev(victim, pev_gravity, 0.000001) // no gravity
		
		// Prevent from moving
		ExecuteHamB(Ham_Player_ResetMaxSpeed, victim)
		
		// Set a task to remove the freeze
		set_task(get_pcvar_float(cvar_freezeduration), "remove_freeze", victim)
	}
	
	// Get rid of the grenade
	engfunc(EngFunc_RemoveEntity, ent)
}
public freeze_player(victim)
{
	// Only effect alive unfrozen zombies
	if (!is_user_valid_alive(victim) || g_class[victim] < ZOMBIE || g_frozen[victim] || g_nodamage[victim])
		return;

	static sound[64];

	// Nemesis shouldn't be frozen
	if (g_class[victim] >= NEMESIS)
	{
		// Get player's origin
		static origin2[3]
		get_user_origin(victim, origin2)
		
		// Broken glass sound
		ArrayGetString(grenade_frost_break, random_num(0, ArraySize(grenade_frost_break) - 1), sound, charsmax(sound))
		emit_sound(victim, CHAN_BODY, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
		
		// Glass shatter
		message_begin(MSG_PVS, SVC_TEMPENTITY, origin2)
		write_byte(TE_BREAKMODEL) // TE id
		write_coord(origin2[0]) // x
		write_coord(origin2[1]) // y
		write_coord(origin2[2]+24) // z
		write_coord(16) // size x
		write_coord(16) // size y
		write_coord(16) // size z
		write_coord(random_num(-50, 50)) // velocity x
		write_coord(random_num(-50, 50)) // velocity y
		write_coord(25) // velocity z
		write_byte(10) // random velocity
		write_short(g_glassSpr) // model
		write_byte(10) // count
		write_byte(25) // life
		write_byte(BREAK_GLASS) // flags
		message_end()
		
		return;
	}
	
	// Freeze icon?
	if (get_pcvar_num(cvar_hudicons))
	{
		message_begin(MSG_ONE_UNRELIABLE, g_msgDamage, _, victim)
		write_byte(0) // damage save
		write_byte(0) // damage take
		write_long(DMG_DROWN) // damage type - DMG_FREEZE
		write_coord(0) // x
		write_coord(0) // y
		write_coord(0) // z
		message_end()
	}
	
	set_user_rendering(victim, kRenderFxGlowShell, 0, 100, 200, kRenderNormal, 25)
	
	// Freeze sound
	ArrayGetString(grenade_frost_player, random_num(0, ArraySize(grenade_frost_player) - 1), sound, charsmax(sound))
	emit_sound(victim, CHAN_BODY, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	// Add a blue tint to their screen
	message_begin(MSG_ONE, g_msgScreenFade, _, victim)
	write_short(0) // duration
	write_short(0) // hold time
	write_short(FFADE_STAYOUT) // fade type
	write_byte(0) // red
	write_byte(50) // green
	write_byte(200) // blue
	write_byte(100) // alpha
	message_end()
	
	// Prevent from jumping
	if (pev(victim, pev_flags) & FL_ONGROUND)
		set_pev(victim, pev_gravity, 999999.9) // set really high
	else
		set_pev(victim, pev_gravity, 0.000001) // no gravity
	
	// Set a task to remove the freeze
	g_frozen[victim] = true;
	set_task(get_pcvar_float(cvar_freezeduration), "remove_freeze", victim)
}
// Remove freeze task
public remove_freeze(id)
{
	// Not alive or not frozen anymore
	if (!g_isalive[id] || !g_frozen[id])
		return;
	
	// Unfreeze
	g_frozen[id] = false;

	// Restore gravity and maxspeed (bugfix)
	set_pev(id, pev_gravity, g_frozen_gravity[id])
	ExecuteHamB(Ham_Player_ResetMaxSpeed, id)
	
	// Restore gravity
	if (g_class[id] >= ZOMBIE)
	{
		if (g_class[id] == NEMESIS)
			set_pev(id, pev_gravity, get_pcvar_float(cvar_nemgravity))
		else if (g_class[id] == ALIEN)
			set_pev(id, pev_gravity, get_pcvar_float(cvar_aliengvt))
		else
			set_pev(id, pev_gravity, Float:ArrayGetCell(g_zclass_grav, g_zombieclass[id]))
	}
	else
	{
		if (g_class[id] >= SURVIVOR)
			set_pev(id, pev_gravity, get_pcvar_float(cvar_survgravity))
		else
		{
			if(g_humanclass[id] != ZCLASS_NONE)
				set_pev(id, pev_gravity, Float:ArrayGetCell(g_zclass_spd, g_humanclass[id]))
			else
				set_pev(id, pev_gravity, get_pcvar_float(cvar_humangravity))
		}
	}
	
	
	if (g_class[id] >= NEMESIS)
		set_user_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 25)
	else if (g_class[id] >= SURVIVOR && g_class[id] < ZOMBIE)
		set_user_rendering(id, kRenderFxGlowShell, 0, 0, 255, kRenderNormal, 25)
	else
		set_user_rendering(id)
	
	
	// Gradually remove screen's blue tint
	message_begin(MSG_ONE, g_msgScreenFade, _, id)
	write_short(UNIT_SECOND) // duration
	write_short(0) // hold time
	write_short(FFADE_IN) // fade type
	write_byte(0) // red
	write_byte(50) // green
	write_byte(200) // blue
	write_byte(100) // alpha
	message_end()
	
	// Broken glass sound
	static sound[64]
	ArrayGetString(grenade_frost_break, random_num(0, ArraySize(grenade_frost_break) - 1), sound, charsmax(sound))
	emit_sound(id, CHAN_BODY, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	// Get player's origin
	static origin2[3]
	get_user_origin(id, origin2)
	
	// Glass shatter
	message_begin(MSG_PVS, SVC_TEMPENTITY, origin2)
	write_byte(TE_BREAKMODEL) // TE id
	write_coord(origin2[0]) // x
	write_coord(origin2[1]) // y
	write_coord(origin2[2]+24) // z
	write_coord(16) // size x
	write_coord(16) // size y
	write_coord(16) // size z
	write_coord(random_num(-50, 50)) // velocity x
	write_coord(random_num(-50, 50)) // velocity y
	write_coord(25) // velocity z
	write_byte(10) // random velocity
	write_short(g_glassSpr) // model
	write_byte(10) // count
	write_byte(25) // life
	write_byte(BREAK_GLASS) // flags
	message_end()
	
	ExecuteForward(g_fwUserUnfrozen, g_fwDummyResult, id);
}

// Remove Stuff Task
public remove_stuff()
{
	static ent
	
	// Remove rotating doors
	if (get_pcvar_num(cvar_removedoors) > 0)
	{
		ent = -1;
		while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "func_door_rotating")) != 0)
			engfunc(EngFunc_SetOrigin, ent, Float:{8192.0 ,8192.0 ,8192.0})
	}
	
	// Remove all doors
	else if (get_pcvar_num(cvar_removedoors) > 1)
	{
		ent = -1;
		while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "func_door")) != 0)
			engfunc(EngFunc_SetOrigin, ent, Float:{8192.0 ,8192.0 ,8192.0})
	}
	
	// Triggered lights
	if (!get_pcvar_num(cvar_triggered))
	{
		ent = -1
		while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "light")) != 0)
		{
			dllfunc(DLLFunc_Use, ent, 0); // turn off the light
			set_pev(ent, pev_targetname, 0) // prevent it from being triggered
		}
	}
}

// Set Custom Weapon Models
replace_weapon_models(id, weaponid)
{
	if(g_class[id] < ZOMBIE && !g_iSkinsEnable[id])
		return;

	switch (weaponid)
	{
		case CSW_KNIFE: // Custom knife models
		{
			if (g_class[id] >= ZOMBIE /*&& get_pcvar_num(cvar_modes)*/)
			{
				if (g_class[id] == NEMESIS || g_class[id] == BOSS) // Nemesis
				{
					set_pev(id, pev_viewmodel2, V_KNIFE_NEMESIS);
					set_pev(id, pev_weaponmodel2, "");
				}
				else if (g_class[id] == ALIEN) // Nemesis
				{
					set_pev(id, pev_viewmodel2, KnifeAlien);
					set_pev(id, pev_weaponmodel2, "");
				}
				else //ZOMBIES
				{
					static buffer2[300], knife[300];
					ArrayGetString(g_zclass_knife, g_zombieclass[id], buffer2, charsmax(buffer2));
					formatex(knife, charsmax(knife), "models/zombie_plague/%s", buffer2);

					set_pev(id, pev_viewmodel2, knife);
					set_pev(id, pev_weaponmodel2, "");
				}
			}
			else
			{
				if (g_class[id] == NINJA) 
			    	set_pev(id, pev_viewmodel2, KnifeNinja);
			}
		}
		case CSW_M249:
		{
			if(g_class[id] == SURVIVOR)
			{
				set_pev(id, pev_viewmodel2, szM4CHINE);
			}
		}
		case CSW_HEGRENADE: // Infection bomb or fire grenade
		{
			if (g_class[id] >= ZOMBIE)
				set_pev(id, pev_viewmodel2, GRENADE_INFECT);
			else
			{
				if(g_iHe[id])
					set_pev(id, pev_viewmodel2, g_vChain);
				else
					set_pev(id, pev_viewmodel2, GRENADE_FIRE);
				
			}
		}
		case CSW_FLASHBANG: // Frost grenade
		{
			if(g_iDroga[id])
				set_pev(id, pev_viewmodel2, grenade_droga);
			else
				set_pev(id, pev_viewmodel2, GRENADE_FROST);
		}
		case CSW_SMOKEGRENADE: // Flare grenade
		{
			if(g_class[id] >= ZOMBIE)
			{
				if (g_iJumpingNadeCount[ id ])
				{
					set_pev(id, pev_viewmodel2, g_szJump_v);
					set_pev (id, pev_weaponmodel2, g_szJump_p);
				}
			}
			else
			{
				if(g_iPipe[id])
				{
					set_pev(id, pev_viewmodel2, g_vmodel);
					set_pev(id, pev_weaponmodel2, g_pmodel);
				} 
				else
				{
					set_pev(id, pev_viewmodel2, model_grenade);
				}
			}
				
		}
	}
}

// Reset Player Vars
reset_vars(id, resetall)
{
	g_class[id] = HUMAN;
	g_frozen[id] = false
	g_iBalasEspeciales[id] = 0;
	g_nodamage[id] = false
	g_respawn_as_zombie[id] = false
	g_nvision[id] = false
	g_nvisionenabled[id] = false
	g_iCategoria[id] = 0;
	g_burning_duration[id] = 0
	g_bBalas[id] = 0;
	g_bMask[id] = 0;
	
	if (resetall)
	{
		if( get_pcvar_num( cvar_event ) )
			g_ammopacks[id] = 20000;
		else
			g_ammopacks[id] = get_pcvar_num( cvar_startammopacks );

		g_zombieclass[id] = ZCLASS_NONE
		g_zombieclassnext[id] = ZCLASS_NONE
		g_humanclassnext[id] = ZCLASS_NONE
		g_damagedealt[id] = 0
		g_iNVsion[id] = g_iHud[id] =g_iDamage[id] = g_iExp[id] = g_iReset[id] = 0; 
		g_iRango[id] = 0; 
		g_iLevel[id] = 1;
	}
}

// Set spectators nightvision
public spec_nvision(id)
{
	// Not connected, alive, or bot
	if (!g_isconnected[id] || g_isalive[id] || g_isbot[id])
		return;
	
	// Give Night Vision?
	if (get_pcvar_num(cvar_nvggive))
	{
		g_nvision[id] = true
		
		// Turn on Night Vision automatically?
		if (get_pcvar_num(cvar_nvggive) == 1)
		{
			g_nvisionenabled[id] = true
			
			// Custom nvg?
			if (get_pcvar_num(cvar_customnvg))
			{
				remove_task(id+TASK_NVISION)
				off(id)
				set_task(0.1, "set_user_nvision", id+TASK_NVISION, _, _, "b")
			}
			
		}
	}
}

// Show HUD Task
public ShowHUD(taskid)
{
	static id
	id = ID_SHOWHUD;
	
	// Player died?
	if (!g_isalive[id])
	{
		// Get spectating target
		id = pev(id, PEV_SPEC_TARGET)
		
		// Target not alive
		if (!g_isalive[id]) return;
	}
	static rangee, lvl; rangee = g_iRango[id] >= charsmax(rango) ? charsmax(rango) : g_iRango[id];
	lvl = g_iLevel[id] >= MAX_LEVEL ? MAX_LEVEL-1 : g_iLevel[id]-1;
	static CountParty, PartyMsg[256], Players[32], id2;

	CountParty = 0
	PartyMsg[0] = 0

	if(!g_touched[id] && g_class[id] < ZOMBIE)
		g_currencyTime[id] = get_gametime() - g_fTiempo[id];

	get_party_index(id, Players)
	for(new i; i < g_PartyData[id][Amount_In_Party]; i++) {
	    
	    id2 = Players[i]
	    
	    if(CountParty)
	        add(PartyMsg, charsmax(PartyMsg), "^n")
	    
	    format(PartyMsg, charsmax(PartyMsg), "%s%s <%s> L: %d - RR: %d", strlen(PartyMsg) ? PartyMsg : "Miembros del Party^n", g_PartyData[id2][UserName], 
	    	g_class[id2] < ZOMBIE ? "Humano" : "Zombie", g_iLevel[id2], g_iReset[id2]);
	    
	    CountParty++
	}
	// Format classname
	static class[32];
	
	if (g_class[id] >= ZOMBIE) // zombies
	{
		if (g_class[id] == NEMESIS)
			formatex(class, charsmax(class), "Nemesis (Zombie)")
		else if (g_class[id] == ALIEN)
			formatex(class, charsmax(class), "Alien (Zombie)")
		else if (g_class[id] == BOSS)
			formatex(class, charsmax(class), "BOSS (Zombie)")
		else
			copy(class, charsmax(class), g_zombie_classname[id])
	}
	else // humans
	{
		if (g_class[id] == WESKER)
			formatex(class, charsmax(class), "Wesker (Humano)")
		else if (g_class[id] == SURVIVOR)
			formatex(class, charsmax(class), "Survivor (Humano)")
		else if (g_class[id] == SIRIO)
			formatex(class, charsmax(class), "Niño Sirio (Humano)")
		else if (g_class[id] == SNIPER)
			formatex(class, charsmax(class), "Sniper (Humano)")
		else if (g_class[id] == NINJA)
			formatex(class, charsmax(class), "Ninja (Humano)")
		else
		{
			if(g_humanclass[id] != ZCLASS_NONE)
				copy(class, charsmax(class), g_human_classname[id]);
			else
				copy(class, charsmax(class), rango[rangee][range_name]);
		}
	}
	
	// Spectating someone else?
	if (id != ID_SHOWHUD)
	{
		// Show name, health, class, and ammo packs
		set_hudmessage(255, 255, 255, HUD_SPECT_X, HUD_SPECT_Y, 0, 6.0, 1.1, 0.0, 0.0, -1)
		ShowSyncHudMsg(ID_SHOWHUD, g_MsgSync2, "%L %s^nHP: %d - %L %s - %L %d", ID_SHOWHUD, "SPECTATING", g_playername[id], pev(id, pev_health), ID_SHOWHUD, "CLASS_CLASS", class, ID_SHOWHUD, "AMMO_PACKS1", g_ammopacks[id])
	}
	else
	{
		// Show health, class and ammo packs
		set_hudmessage(g_ColorHud[g_iHud[id]][hudColor][0], g_ColorHud[g_iHud[id]][hudColor][1], g_ColorHud[g_iHud[id]][hudColor][2], HUD_STATS_X, HUD_STATS_Y, 0, 6.0, 1.1, 0.0, 0.0, -1)
		ShowSyncHudMsg(ID_SHOWHUD, g_MsgSync2, "Vida: %d - Chaleco: %d^nClase: %s^nExperiencia: %d/%d [ %i%% ]^nNivel: %d/%d || Reset: %d^nDamage: %d/%d^nAmmo packs: %d^n[Hora Feliz] [%s]^n^n%s", 
			get_user_health(id), get_user_armor(id), class, g_iExp[id], RequiredExp[lvl], porcentaje(float(g_iExp[id]), float(RequiredExp[lvl])), g_iLevel[id], MAX_LEVEL, g_iReset[id], g_iDamage[id], g_iDefaultDamage, g_ammopacks[id], g_bHappyTime ? "ON" : "OFF", PartyMsg);
	}

	set_dhudmessage( 125, 125, 125, -1.0, 0.0, 1, 0.0, 1.0 );
	show_dhudmessage( 0, "[ ZB: %d ] (%d) [ HM: %d]", g_scorezombies, (g_scorezombies+g_scorehumans), g_scorehumans );
	//show_dhudmessage( 0, "[Zombies] [ROUND] [Humans]^n %d^t^t^t^t^t^t^t%d^t^t^t^t^t^t^t%d", g_scorezombies, (g_scorezombies+g_scorehumans), g_scorehumans );
}

// Play idle zombie sounds
public zombie_play_idle(taskid)
{
	// Round ended/new one starting
	if (g_endround || g_newround)
		return;
	
	static sound[64]
	
	// Last zombie?
	if (g_class[ID_BLOOD] == LAST_ZOMBIE)
	{
		ArrayGetString(zombie_idle_last, random_num(0, ArraySize(zombie_idle_last) - 1), sound, charsmax(sound))
		emit_sound(ID_BLOOD, CHAN_VOICE, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	else
	{
		ArrayGetString(zombie_idle, random_num(0, ArraySize(zombie_idle) - 1), sound, charsmax(sound))
		emit_sound(ID_BLOOD, CHAN_VOICE, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
}

// Madness Over Task
public madness_over(taskid)
{
	g_nodamage[ID_BLOOD] = false
}

// Place user at a random spawn
do_random_spawn(id, regularspawns = 0)
{
	static hull, sp_index, i
	
	// Get whether the player is crouching
	hull = (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN
	
	// Use regular spawns?
	if (!regularspawns)
	{
		// No spawns?
		if (!g_spawnCount)
			return;
		
		// Choose random spawn to start looping at
		sp_index = random_num(0, g_spawnCount - 1)
		
		// Try to find a clear spawn
		for (i = sp_index + 1; /*no condition*/; i++)
		{
			// Start over when we reach the end
			if (i >= g_spawnCount) i = 0
			
			// Free spawn space?
			if (is_hull_vacant(g_spawns[i], hull))
			{
				// Engfunc_SetOrigin is used so ent's mins and maxs get updated instantly
				engfunc(EngFunc_SetOrigin, id, g_spawns[i])
				break;
			}
			
			// Loop completed, no free space found
			if (i == sp_index) break;
		}
	}
	else
	{
		// No spawns?
		if (!g_spawnCount2)
			return;
		
		// Choose random spawn to start looping at
		sp_index = random_num(0, g_spawnCount2 - 1)
		
		// Try to find a clear spawn
		for (i = sp_index + 1; /*no condition*/; i++)
		{
			// Start over when we reach the end
			if (i >= g_spawnCount2) i = 0
			
			// Free spawn space?
			if (is_hull_vacant(g_spawns2[i], hull))
			{
				// Engfunc_SetOrigin is used so ent's mins and maxs get updated instantly
				engfunc(EngFunc_SetOrigin, id, g_spawns2[i])
				break;
			}
			
			// Loop completed, no free space found
			if (i == sp_index) break;
		}
	}
}

// Get Zombies -returns alive zombies number-
fnGetZombies()
{
	static iZombies, id
	iZombies = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (g_isalive[id] && g_class[id] >= ZOMBIE)
			iZombies++
	}
	
	return iZombies;
}

// Get Humans -returns alive humans number-
fnGetHumans()
{
	static iHumans, id
	iHumans = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (g_isalive[id] && g_class[id] < ZOMBIE)
			iHumans++
	}
	
	return iHumans;
}

// Get Nemesis -returns alive nemesis number-
fnGetNemesis()
{
	static iNemesis, id
	iNemesis = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (g_isalive[id] && g_class[id] == NEMESIS)
			iNemesis++
	}
	
	return iNemesis;
}

// Get Aliens -returns alive nemesis number-
fnGetAliens()
{
	static iAliens, id
	iAliens = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (g_isalive[id] && g_class[id] == ALIEN)
			iAliens++
	}
	
	return iAliens;
}

// Get Survivors -returns alive survivors number-
fnGetSurvivors()
{
	static iSurvivors, id
	iSurvivors = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (g_isalive[id] && g_class[id] == SURVIVOR)
			iSurvivors++
	}
	
	return iSurvivors;
}

// Get Alive -returns alive players number-
fnGetAlive()
{
	static iAlive, id
	iAlive = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (g_isalive[id])
			iAlive++
	}
	
	return iAlive;
}

// Get Random Alive -returns index of alive player number n -
fnGetRandomAlive(n)
{
	static iAlive, id
	iAlive = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (g_isalive[id])
			iAlive++
		
		if (iAlive == n)
			return id;
	}
	
	return -1;
}

// Get Playing -returns number of users playing-
fnGetPlaying()
{
	static iPlaying, id, team
	iPlaying = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (g_isconnected[id])
		{
			team = fm_cs_get_user_team(id)
			
			if (team != FM_CS_TEAM_SPECTATOR && team != FM_CS_TEAM_UNASSIGNED)
				iPlaying++
		}
	}
	
	return iPlaying;
}

// Get CTs -returns number of CTs connected-
fnGetCTs()
{
	static iCTs, id
	iCTs = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (g_isconnected[id])
		{			
			if (fm_cs_get_user_team(id) == FM_CS_TEAM_CT)
				iCTs++
		}
	}
	
	return iCTs;
}

// Get Ts -returns number of Ts connected-
fnGetTs()
{
	static iTs, id
	iTs = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (g_isconnected[id])
		{			
			if (fm_cs_get_user_team(id) == FM_CS_TEAM_T)
				iTs++
		}
	}
	
	return iTs;
}

// Get Alive CTs -returns number of CTs alive-
fnGetAliveCTs()
{
	static iCTs, id
	iCTs = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (g_isalive[id])
		{			
			if (fm_cs_get_user_team(id) == FM_CS_TEAM_CT)
				iCTs++
		}
	}
	
	return iCTs;
}

// Get Alive Ts -returns number of Ts alive-
fnGetAliveTs()
{
	static iTs, id
	iTs = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (g_isalive[id])
		{			
			if (fm_cs_get_user_team(id) == FM_CS_TEAM_T)
				iTs++
		}
	}
	
	return iTs;
}

// Last Zombie Check -check for last zombie and set its flag-
fnCheckLastZombie()
{
	static id
	for (id = 1; id <= g_maxplayers; id++)
	{
		// Last zombie
		if (g_isalive[id] && g_class[id] >= ZOMBIE && g_class[id] < NEMESIS && fnGetZombies() == 1)
		{
			if (g_class[id] != LAST_ZOMBIE)
			{
				// Last zombie forward
				ExecuteForward(g_fwUserLastZombie, g_fwDummyResult, id);
			}
			g_class[id] = LAST_ZOMBIE;
		}
		/*else
			g_class[id] = ZOMBIE;*/
		
		// Last human
		if (g_isalive[id] && g_class[id] >= HUMAN && g_class[id] < SURVIVOR && fnGetHumans() == 1)
		{
			if (g_class[id] != LAST_HUMAN)
			{
				// Last human forward
				ExecuteForward(g_fwUserLastHuman, g_fwDummyResult, id);
				
				// Reward extra hp
				set_user_health(id, pev(id, pev_health) + get_pcvar_num(cvar_humanlasthp))
			}
			g_class[id] = LAST_HUMAN;
		}
		/*else
			g_class[id] = HUMAN;*/
	}
}

// Checks if a player is allowed to be zombie
allowed_zombie(id)
{
	if ((g_class[id] == NEMESIS && g_class[id] < NEMESIS) || g_endround || !g_isalive[id] || task_exists(TASK_WELCOMEMSG) || (!g_newround && g_class[id] < ZOMBIE && fnGetHumans() == 1))
		return false;
	
	return true;
}

// Checks if a player is allowed to be human
allowed_human(id)
{
	if ((g_class[id] == HUMAN && g_class[id] < SURVIVOR) || g_endround || !g_isalive[id] || task_exists(TASK_WELCOMEMSG) || (!g_newround && g_class[id] >= ZOMBIE && fnGetZombies() == 1))
		return false;
	
	return true;
}

// Checks if a player is allowed to be nemesis
allowed_nemesis(id)
{
	if (g_endround || g_class[id] == NEMESIS || !g_isalive[id] || task_exists(TASK_WELCOMEMSG) || (!g_newround && g_class[id] < ZOMBIE && fnGetHumans() == 1))
		return false;
	
	return true;
}

// Checks if a player is allowed to respawn
allowed_respawn(id)
{
	static team
	team = fm_cs_get_user_team(id)
	
	if (g_endround || team == FM_CS_TEAM_SPECTATOR || team == FM_CS_TEAM_UNASSIGNED || g_isalive[id])
		return false;
	
	return true;
}

// Checks if swarm mode is allowed
allowed_swarm()
{
	if (g_endround || !g_newround || task_exists(TASK_WELCOMEMSG))
		return false;
	
	return true;
}

// Checks if multi infection mode is allowed
allowed_multi()
{
	if (g_endround || !g_newround || task_exists(TASK_WELCOMEMSG) || floatround(fnGetAlive()*get_pcvar_float(cvar_multiratio), floatround_ceil) < 2 || floatround(fnGetAlive()*get_pcvar_float(cvar_multiratio), floatround_ceil) >= fnGetAlive())
		return false;
	
	return true;
}

// Checks if plague mode is allowed
allowed_plague()
{
	if (g_endround || !g_newround || task_exists(TASK_WELCOMEMSG) || floatround((fnGetAlive()-(get_pcvar_num(cvar_plaguenemnum)+get_pcvar_num(cvar_plaguesurvnum)))*get_pcvar_float(cvar_plagueratio), floatround_ceil) < 1
	|| fnGetAlive()-(get_pcvar_num(cvar_plaguesurvnum)+get_pcvar_num(cvar_plaguenemnum)+floatround((fnGetAlive()-(get_pcvar_num(cvar_plaguenemnum)+get_pcvar_num(cvar_plaguesurvnum)))*get_pcvar_float(cvar_plagueratio), floatround_ceil)) < 1)
		return false;
	
	return true;
}

allowed_arma()
{
    if (g_endround || !g_newround || !get_pcvar_num(cvar_mutilador) || task_exists(TASK_WELCOMEMSG) || fnGetAlive() < get_pcvar_num(cvar_mutiladorminplayer))
        return false;
    
    return true;
} 

// Checks if a player is allowed to be survivor
allowed_mode(id, class) 
{
    if (g_endround || g_class[id] == class || !g_isalive[id] || task_exists(TASK_WELCOMEMSG) || (!g_newround && g_class[id] >= ZOMBIE && fnGetZombies() == 1))
        return false; 
    
    return true;
}

// Checks if a player is allowed to be alien
allowed_alien(id)
{
	if (g_endround || g_class[id] == ALIEN || !g_isalive[id] || task_exists(TASK_WELCOMEMSG) || (!g_newround && g_class[id] < ZOMBIE && fnGetHumans() == 1))
		return false;
	
	return true;
}

public command_onplayer(id, player, command, cost)
{
	if(g_ammopacks[id] >= cost)
	{
		switch(command)
		{
			case 0:{
				// New round?
				if (g_newround)
				{
					// Set as first zombie
					remove_task(TASK_MAKEZOMBIE)
					make_a_zombie(MODE_INFECTION, player)
				}
				else
				{
					// Just infect
					zombieme(player, 0, 0, 0, 0)
				}
				zp_colored_print(0, "^x04%s^x01 El Admin^x04 %s^x01 convirtio a^x04 %s^x01 en ^x04Zombie", g_szPrefix, g_playername[id], g_playername[player] );
			}
			case 1:{
				humanme(player, 0, 0)
			}
			case 2:{
				// New round?
				if (g_newround)
				{
					// Set as first survivor
					remove_task(TASK_MAKEZOMBIE)
					make_a_zombie(MODE_SURVIVOR, player)
				}
				else
				{
					// Turn player into a Survivor
					humanme(player, 1, 0)
				}
				zp_colored_print(0, "^x04%s^x01 El Admin^x04 %s^x01 convirtio a^x04 %s^x01 en ^x04Survivor", g_szPrefix, g_playername[id], g_playername[player] );
			}
			case 3:
			{
				// New round?
				if (g_newround)
				{
					// Set as first nemesis
					remove_task(TASK_MAKEZOMBIE)
					make_a_zombie(MODE_NEMESIS, player)
				}
				else
				{
					// Turn player into a Nemesis
					zombieme(player, 0, 1, 0, 0)
				}
				zp_colored_print(0, "^x04%s^x01 El Admin^x04 %s^x01 convirtio a^x04 %s^x01 en ^x04Nemesis", g_szPrefix, g_playername[id], g_playername[player] );
			}
			case 4:{
				// Respawn as zombie?
				if (get_pcvar_num(cvar_deathmatch) == 2 || (get_pcvar_num(cvar_deathmatch) == 3 && random_num(0, 1)) || (get_pcvar_num(cvar_deathmatch) == 4 && fnGetZombies() < fnGetAlive()/2))
					g_respawn_as_zombie[player] = true
				
				// Override respawn as zombie setting on nemesis and survivor rounds
				if (g_currentmode == MODE_SURVIVOR) g_respawn_as_zombie[player] = true
				else if (g_currentmode == MODE_NEMESIS) g_respawn_as_zombie[player] = false
				
				respawn_player_manually(player);
				g_iCategoria[player] = 0;
				g_bAnterior[player] = false;
				
				zp_colored_print(0, "^x04%s^x01 El Admin^x04 %s^x01 ha revivido a^x04 %s^x01", g_szPrefix, g_playername[id], g_playername[player] );
			}
			case 5:
			{
				if (g_newround) 
				{
					remove_task(TASK_MAKEZOMBIE)
					make_a_zombie(MODE_SNIPER, player)
				}
				else 
					humanme(player, 2, 0)

				zp_colored_print(0, "^x04%s^x01 El Admin^x04 %s^x01 convirtio a^x04 %s^x01 en ^x04Sniper", g_szPrefix, g_playername[id], g_playername[player] );
			}
			case 6:
			{
				if (g_newround) 
				{
					remove_task(TASK_MAKEZOMBIE);
					make_a_zombie(MODE_WESKER, player);
				}
				else 
					humanme(player, 3, 0)

				zp_colored_print(0, "^x04%s^x01 El Admin^x04 %s^x01 convirtio a^x04 %s^x01 en ^x04Wesker", g_szPrefix, g_playername[id], g_playername[player] );
			}
			case 7:
			{
			if (g_newround) 
			{
				remove_task(TASK_MAKEZOMBIE);
				make_a_zombie(MODE_SIRIO, player);
			}
			else 
				humanme(player, 4, 0);

			zp_colored_print(0, "^x04%s^x01 El Admin^x04 %s^x01 convirtio a^x04 %s^x01 en un ^x04Ninio Sirio", g_szPrefix, g_playername[id], g_playername[player] );
			}
			case 8:
			{
				// New round?
				if (g_newround)
				{
					// Set as first alien
					remove_task(TASK_MAKEZOMBIE);
					make_a_zombie(MODE_ALIEN, player);
				}
				else
				{
					// Turn player into a alien
					zombieme(player, 0, 2, 0, 0)
				}
				zp_colored_print(0, "^x04%s^x01 El Admin^x04 %s^x01 convirtio a^x04 %s^x01 en^x04 Alien", g_szPrefix, g_playername[id], g_playername[player] );
			}
			case 9:
			{
				// New round?
				if (g_newround)
				{
					// Set as first alien
					remove_task(TASK_MAKEZOMBIE);
					make_a_zombie(MODE_NINJA, player);
				}
				else
					humanme(player, 5, 0);

				zp_colored_print(0, "^x04%s^x01 El Admin^x04 %s^x01 convirtio a^x04 %s^x01 en^x04 Ninja", g_szPrefix, g_playername[id], g_playername[player] );
			}

		}
		g_ammopacks[id] -= cost;
	}
}
command_modes(id, command, cost){
	if(g_ammopacks[id] >= cost)
	{
		switch(command)
		{
			case 0:
			{
				// Call Swarm Mode
				remove_task(TASK_MAKEZOMBIE)
				make_a_zombie(MODE_SWARM, 0)
				zp_colored_print(0, "^x04%s^x01 El Admin^x04 %s^x01 ejecutado el modo ^x04SWARM", g_szPrefix, g_playername[id]);
			}
			case 1:
			{
				// Call Multi Infection
				remove_task(TASK_MAKEZOMBIE)
				make_a_zombie(MODE_MULTI, 0)
				zp_colored_print(0, "^x04%s^x01 El Admin^x04 %s^x01 ejecutado el modo ^x04INFECCIÓN MULTIPLE", g_szPrefix, g_playername[id]);
			}
			case 2:
			{
				// Call Plague Mode
				remove_task(TASK_MAKEZOMBIE)
				make_a_zombie(MODE_PLAGUE, 0)
				zp_colored_print(0, "^x04%s^x01 El Admin^x04 %s^x01 ejecutado el modo ^x04PLAGUE", g_szPrefix, g_playername[id]);
			}
			case 3:
			{
				remove_task(TASK_MAKEZOMBIE);
				make_a_zombie(MODE_MUTILADOR, 0);
				zp_colored_print(0, "^x04%s^x01 El Admin^x04 %s^x01 ejecutado el modo ^x04MUTILADOR", g_szPrefix, g_playername[id]);
			}
		}
		g_ammopacks[id] -= cost;
	}
}


/*================================================================================
 [Custom Natives]
=================================================================================*/
public native_get_user_class(id)
    return g_class[id];

public native_get_user_sniper(id)
    return g_class[id] == SURVIVOR ? true : false;
public native_get_round_sniper()
    return g_currentmode == MODE_SNIPER ? true : false;

    public native_get_user_wesker(id)
    return g_class[id] == WESKER ? true : false;
public native_get_round_wesker()
    return g_currentmode == MODE_WESKER ? true : false;

// Native: zp_get_user_zombie
public native_get_user_zombie(id)
{
	return g_class[id] >= ZOMBIE ? true : false;
}

// Native: zp_get_user_nemesis
public native_get_user_nemesis(id)
{
	return g_class[id] == NEMESIS ? true : false;
}
public set_unfrozen(id, value)
	g_iNoFrost[id] = value;

public handler_ghost(id, value)
	g_iGhost[id] = value;

public handler_fisher(id, value)
	g_iFisher[id] = value;

public handler_chain(id, value)
	g_iHe[id] += value;

public handler_get_nojump(id, value)
	return g_iNoJump[id];

public handler_skins_enable(id)
	return g_iSkinsEnable[id];

public handler_set_nojump(id, value)
	g_iNoJump[id] = value;

public handler_boost(id)
{
	g_has_speed_boost[id] = true
	client_print(id, print_chat, "[ZP] Speed boost ACTIVADO!")
	
	// Set the restore speed task
	set_task(get_pcvar_float(cvar_boost_duration), "restore_maxspeed", id+TASK_SPEED_BOOST);
	
	// Update player's maxspeed
	ExecuteHamB(Ham_Player_ResetMaxSpeed, id);
}

public handler_jump(id, value)
	g_iJumpClass[id] = value;

public handler_jump2(id, value)
	g_iJumpClass2[id]  = value;

public handler_no_droga(id, value)
	g_iNoDroga[id] = value;

public set_nofire(id, value)
	g_iNoFire[id] = value;

public set_nopipe(id, value)
	g_iNoPipe[id] = value;

// Native: zp_get_user_survivor
public native_get_user_survivor(id)
{
	return g_class[id] == SURVIVOR ? true : false;
}

public native_get_user_first_zombie(id)
{
	return g_class[id] == FIRST_ZOMBIE ? true : false;
}

// Native: zp_get_user_last_zombie
public native_get_user_last_zombie(id)
{
	return g_class[id] == LAST_ZOMBIE ? true : false;
}

// Native: zp_get_user_last_human
public native_get_user_last_human(id)
{
	return g_class[id] == LAST_HUMAN ? true : false;
}

// Native: zp_get_user_zombie_class
public native_get_user_human_class(id)
{
	return g_humanclass[id];
}

// Native: zp_get_user_zombie_class
public native_get_user_zombie_class(id)
{
	return g_zombieclass[id];
}

// Native: zp_get_user_next_class
public native_get_user_next_class(id)
{
	return g_zombieclassnext[id];
}

// Native: zp_set_user_zombie_class
public native_set_user_zombie_class(id, classid)
{
	if (classid < 0 || classid >= g_zclass_i)
		return 0;
	
	g_zombieclassnext[id] = classid
	return 1;
}

// Native: zp_get_user_ammo_packs
public native_get_user_ammo_packs(id)
{
	return g_ammopacks[id];
}

// Native: zp_set_user_ammo_packs
public native_set_user_ammo_packs(id, amount)
{
	g_ammopacks[id] = amount;
}

// Native: zp_get_zombie_maxhealth
public native_get_zombie_maxhealth(id)
{
	// ZP disabled
	if (!g_pluginenabled)
		return -1;
	
	if (g_class[id] == ZOMBIE && g_class[id] < NEMESIS)
	{
		if (g_class[id] == FIRST_ZOMBIE)
			return floatround(float(ArrayGetCell(g_zclass_hp, g_zombieclass[id])) * get_pcvar_float(cvar_zombiefirsthp));
		else
			return ArrayGetCell(g_zclass_hp, g_zombieclass[id]);
	}
	return -1;
}

// Native: zp_get_user_nightvision
public native_get_user_nightvision(id)
{
	return g_nvision[id];
}

// Native: zp_set_user_nightvision
public native_set_user_nightvision(id, set)
{
	// ZP disabled
	if (!g_pluginenabled)
		return;
	
	if (set)
	{
		g_nvision[id] = true
		
		if (!g_isbot[id])
		{
			g_nvisionenabled[id] = true
			
			// Custom nvg?
			if (get_pcvar_num(cvar_customnvg))
			{
				remove_task(id+TASK_NVISION)
				off(id)
				set_task(0.1, "set_user_nvision", id+TASK_NVISION, _, _, "b")
			}
		}
		
	}
	else
	{
		// Turn off NVG for bots
		if (g_isbot[id]) cs_set_user_nvg(id, 0);
		if (get_pcvar_num(cvar_customnvg)){ 
			remove_task(id+TASK_NVISION); 
			off(id);
		}
		g_nvision[id] = false
		g_nvisionenabled[id] = false
	}
}

// Native: zp_infect_user
public native_infect_user(id, infector, silent, rewards)
{
	// ZP disabled
	if (!g_pluginenabled)
		return -1;
	
	// Not allowed to be zombie
	if (!allowed_zombie(id))
		return 0;
	
	// New round?
	if (g_newround)
	{
		// Set as first zombie
		remove_task(TASK_MAKEZOMBIE)
		make_a_zombie(MODE_INFECTION, id)
	}
	else
	{
		// Just infect (plus some checks)
		zombieme(id, is_user_valid_alive(infector) ? infector : 0, 0, (silent == 1) ? 1 : 0, (rewards == 1) ? 1 : 0)
	}
	
	return 1;
}

// Native: zp_disinfect_user
public native_disinfect_user(id, silent)
{
	// ZP disabled
	if (!g_pluginenabled)
		return -1;
	
	// Not allowed to be human
	if (!allowed_human(id))
		return 0;
	
	// Turn to human
	humanme(id, 0, (silent == 1) ? 1 : 0)
	return 1;
}

// Native: zp_make_user_nemesis
public native_make_user_nemesis(id)
{
	// ZP disabled
	if (!g_pluginenabled)
		return -1;
	
	// Not allowed to be nemesis
	if (!allowed_nemesis(id))
		return 0;
	
	// New round?
	if (g_newround)
	{
		// Set as first nemesis
		remove_task(TASK_MAKEZOMBIE)
		make_a_zombie(MODE_NEMESIS, id)
	}
	else
	{
		// Turn player into a Nemesis
		zombieme(id, 0, 1, 0, 0)
	}
	
	return 1;
}

// Native: zp_make_user_zombie
public native_make_user_zombie(id)
{
	// ZP disabled
	if (!g_pluginenabled)
		return -1;
	
	// Not allowed to be nemesis
	if (!allowed_zombie(id))
		return 0;
	
	g_class[ id ] = ZOMBIE;
	// New round?
	if (g_newround)
	{
		// Set as first nemesis
		remove_task(TASK_MAKEZOMBIE)
		make_a_zombie(MODE_SWARM, id)
	}
	else
	{
		// Turn player into a zombie
		zombieme(id, 0, 0, 1, 0)
	}
	
	return 1;
}

// Native: zp_make_user_survivor
public native_make_user_survivor(id)
{
	// ZP disabled
	if (!g_pluginenabled)
		return -1;
	
	// Not allowed to be survivor
	if (!allowed_mode(id, SURVIVOR))
		return 0;
	
	// New round?
	if (g_newround)
	{
		// Set as first survivor
		remove_task(TASK_MAKEZOMBIE)
		make_a_zombie(MODE_SURVIVOR, id)
	}
	else
	{
		// Turn player into a Survivor
		humanme(id, 1, 0)
	}
	
	return 1;
}

// Native: zp_respawn_user
public native_respawn_user(id, team)
{
	// ZP disabled
	if (!g_pluginenabled)
		return -1;
	
	// Invalid player
	if (!is_user_valid_connected(id))
		return 0;
	
	// Respawn not allowed
	if (!allowed_respawn(id))
		return 0;
	
	// Respawn as zombie?
	g_respawn_as_zombie[id] = (team == ZP_TEAM_ZOMBIE) ? true : false
	
	// Respawnish!
	respawn_player_manually(id)
	return 1;
}

// Native: zp_force_buy_extra_item
public native_force_buy_extra_item(id, itemid, ignorecost)
{
	// ZP disabled
	if (!g_pluginenabled)
		return -1;
	
	if (itemid < 0 || itemid >= g_extraitem_i)
		return 0;
	
	buy_extra_item(id, itemid, ignorecost)
	return 1;
}

// Native: zp_has_round_started
public native_has_round_started()
{
	if (g_newround) return 0; // not started
	if (g_modestarted) return 1; // started
	return 2; // starting
}

// Native: zp_is_nemesis_round
public native_is_nemesis_round()
{
	return g_currentmode == MODE_NEMESIS ? true : false;
}

// Native: zp_is_survivor_round
public native_is_survivor_round()
{
	return g_currentmode == MODE_SURVIVOR ? true : false;
}

// Native: zp_is_swarm_round
public native_is_swarm_round()
{
	return g_currentmode == MODE_SWARM ? true : false;
}

// Native: zp_is_plague_round
public native_is_plague_round()
{
	return g_currentmode == MODE_PLAGUE ? true : false;
}

// Native: zp_get_zombie_count
public native_get_zombie_count()
{
	return fnGetZombies();
}

// Native: zp_get_human_count
public native_get_human_count()
{
	return fnGetHumans();
}

// Native: zp_get_nemesis_count
public native_get_nemesis_count()
{
	return fnGetNemesis();
}

// Native: zp_get_survivor_count
public native_get_survivor_count()
{
	return fnGetSurvivors();
}

// Native: zp_register_extra_item
public native_register_extra_item(const name[], cost, level, team)
{
	// ZP disabled
	if (!g_pluginenabled)
		return -1;
	
	// Arrays not yet initialized
	if (!g_arrays_created)
		return -1;
	
	// For backwards compatibility
	if (team == ZP_TEAM_ANY)
		team = ZP_TEAM_ZOMBIE|ZP_TEAM_HUMAN
	
	// Strings passed byref
	param_convert(1)
	
	// Add the item
	ArrayPushString(g_extraitem_name, name)
	ArrayPushCell(g_extraitem_cost, cost)
	ArrayPushCell(g_extraitem_level, level)
	ArrayPushCell(g_extraitem_team, team)
	
	// Increase registered items counter
	g_extraitem_i++
	
	// Return id under which we registered the item
	return g_extraitem_i-1;
}

// Function: zp_register_extra_item (to be used within this plugin only)
native_register_extra_item2(const name[], cost, level, team)
{
	// Add the item
	ArrayPushString(g_extraitem_name, name)
	ArrayPushCell(g_extraitem_cost, cost)
	ArrayPushCell(g_extraitem_level, level)
	ArrayPushCell(g_extraitem_team, team)
	
	// Increase registered items counter
	g_extraitem_i++
}

// Native: zp_register_zombie_class
public native_register_zombie_class(const type, const name[], const info[], const model[], const knife[], level, reset, adm, hp, chaleco, speed, Float:gravity, Float:knockback)
{
	if (!g_pluginenabled)
		return -1;
	
	if (!g_arrays_created)
		return -1;
	
	param_convert(2);
	param_convert(3);
	param_convert(4);
	param_convert(5);
	
	ArrayPushCell(g_zclass_type, type);
	ArrayPushString(g_zclass_name, name);//2
	ArrayPushString(g_zclass_info, info);//3
	ArrayPushString(g_zclass_model, model);//4
	ArrayPushString(g_zclass_knife, knife);//5
	ArrayPushCell(g_zclass_level, level);
	ArrayPushCell(g_zclass_reset, reset); 
	ArrayPushCell(g_zclass_admin, adm); 
	ArrayPushCell(g_zclass_hp, hp);
	ArrayPushCell(g_zclass_chaleco, chaleco);
	ArrayPushCell(g_zclass_spd, speed);
	ArrayPushCell(g_zclass_grav, gravity);
	ArrayPushCell(g_zclass_kb, knockback);

	static buffer[300], knife[300];
	ArrayGetString(g_zclass_model, g_zclass_i, buffer, charsmax(buffer))
	precache_player_model(buffer);

	ArrayGetString(g_zclass_knife, g_zclass_i, buffer, charsmax(buffer));
	if(!equal(buffer, "default"))
	{
		formatex(knife, charsmax(knife), "models/zombie_plague/%s", buffer);
		precache_model(knife);
	}
		
	g_zclass_i++;
	
	return g_zclass_i-1;
}

// Native: zp_get_extra_item_id
public native_get_extra_item_id(const name[])
{
	// ZP disabled
	if (!g_pluginenabled)
		return -1;
	
	// Strings passed byref
	param_convert(1)
	
	// Loop through every item
	static i, item_name[32]
	for (i = 0; i < g_extraitem_i; i++)
	{
		ArrayGetString(g_extraitem_name, i, item_name, charsmax(item_name))
		
		// Check if this is the item to retrieve
		if (equali(name, item_name))
			return i;
	}
	
	return -1;
}

// Native: zp_get_zombie_class_id
public native_get_zombie_class_id(const name[])
{
	// ZP disabled
	if (!g_pluginenabled)
		return -1;
	
	// Strings passed byref
	param_convert(1)
	
	// Loop through every class
	static i, class_name[32]
	for (i = 0; i < g_zclass_i; i++)
	{
		ArrayGetString(g_zclass_name, i, class_name, charsmax(class_name))
		
		// Check if this is the class to retrieve
		if (equali(name, class_name))
			return i;
	}
	
	return -1;
}

/*================================================================================
 [Custom Messages]
=================================================================================*/

// Custom Night Vision
public set_user_nvision(taskid)
{
	message_begin(MSG_ONE, g_msgScreenFade, _, ID_NVISION)
	write_short(0) // duration
	write_short(0) // hold time
	write_short(0x0004) // fade type
	
	write_byte(g_ColorNVsion[g_iNVsion[ID_NVISION]][nvisionColor][0]) // r
	write_byte(g_ColorNVsion[g_iNVsion[ID_NVISION]][nvisionColor][1]) // g
	write_byte(g_ColorNVsion[g_iNVsion[ID_NVISION]][nvisionColor][2]) // b

	write_byte(70)
	message_end()
	set_player_light(ID_NVISION, "z")
}

// Infection special effects
infection_effects(id)
{
	// Screen fade? (unless frozen)
	if (!g_frozen[id] && get_pcvar_num(cvar_infectionscreenfade))
	{
		message_begin(MSG_ONE, g_msgScreenFade, _, id)
		write_short(UNIT_SECOND) // duration
		write_short(0) // hold time
		write_short(FFADE_IN) // fade type
		write_byte(g_ColorNVsion[g_iNVsion[id]][nvisionColor][0]) // r
		write_byte(g_ColorNVsion[g_iNVsion[id]][nvisionColor][1]) // g
		write_byte(g_ColorNVsion[g_iNVsion[id]][nvisionColor][2]) // b
		
		write_byte (255) // alpha
		message_end()
	}
	
	// Screen shake?
	if (get_pcvar_num(cvar_infectionscreenshake))
	{
		message_begin(MSG_ONE_UNRELIABLE, g_msgScreenShake, _, id)
		write_short(UNIT_SECOND*4) // amplitude
		write_short(UNIT_SECOND*2) // duration
		write_short(UNIT_SECOND*10) // frequency
		message_end()
	}
	
	// Infection icon?
	if (get_pcvar_num(cvar_hudicons))
	{
		message_begin(MSG_ONE_UNRELIABLE, g_msgDamage, _, id)
		write_byte(0) // damage save
		write_byte(0) // damage take
		write_long(DMG_NERVEGAS) // damage type - DMG_RADIATION
		write_coord(0) // x
		write_coord(0) // y
		write_coord(0) // z
		message_end()
	}
	
	// Get player's origin
	static origin[3]
	get_user_origin(id, origin)
	
	// Tracers?
	if (get_pcvar_num(cvar_infectiontracers))
	{
		message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
		write_byte(TE_IMPLOSION) // TE id
		write_coord(origin[0]) // x
		write_coord(origin[1]) // y
		write_coord(origin[2]) // z
		write_byte(128) // radius
		write_byte(20) // count
		write_byte(3) // duration
		message_end()
	}
	
	// Particle burst?
	if (get_pcvar_num(cvar_infectionparticles))
	{
		message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
		write_byte(TE_PARTICLEBURST) // TE id
		write_coord(origin[0]) // x
		write_coord(origin[1]) // y
		write_coord(origin[2]) // z
		write_short(50) // radius
		write_byte(70) // color
		write_byte(3) // duration (will be randomized a bit)
		message_end()
	}
	
	// Light sparkle?
	if (get_pcvar_num(cvar_infectionsparkle))
	{
		message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
		write_byte(TE_DLIGHT) // TE id
		write_coord(origin[0]) // x
		write_coord(origin[1]) // y
		write_coord(origin[2]) // z
		write_byte(20) // radius
		write_byte(g_ColorNVsion[g_iNVsion[id]][nvisionColor][0]) // r
		write_byte(g_ColorNVsion[g_iNVsion[id]][nvisionColor][1]) // g
		write_byte(g_ColorNVsion[g_iNVsion[id]][nvisionColor][2]) // b
		write_byte(2) // life
		write_byte(0) // decay rate
		message_end()
	}
}

// Burning Flames
public burning_flame(taskid)
{
	// Get player origin and flags
	static origin[3], flags
	get_user_origin(ID_BURN, origin)
	flags = pev(ID_BURN, pev_flags)
	
	// Madness mode - in water - burning stopped
	if (g_nodamage[ID_BURN] || (flags & FL_INWATER) || g_burning_duration[ID_BURN] < 1)
	{
		// Smoke sprite
		message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
		write_byte(TE_SMOKE) // TE id
		write_coord(origin[0]) // x
		write_coord(origin[1]) // y
		write_coord(origin[2]-50) // z
		write_short(g_smokeSpr) // sprite
		write_byte(random_num(15, 20)) // scale
		write_byte(random_num(10, 20)) // framerate
		message_end()
		
		// Task not needed anymore
		remove_task(taskid);
		return;
	}
	
	// Randomly play burning zombie scream sounds (not for nemesis)
	if (g_class[ID_BURN] < NEMESIS && !random_num(0, 20))
	{
		static sound[64]
		ArrayGetString(grenade_fire_player, random_num(0, ArraySize(grenade_fire_player) - 1), sound, charsmax(sound))
		emit_sound(ID_BURN, CHAN_VOICE, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	
	// Fire slow down, unless nemesis
	if (g_class[ID_BURN] < NEMESIS && (flags & FL_ONGROUND) && get_pcvar_float(cvar_fireslowdown) > 0.0)
	{
		static Float:velocity[3]
		pev(ID_BURN, pev_velocity, velocity)
		xs_vec_mul_scalar(velocity, get_pcvar_float(cvar_fireslowdown), velocity)
		set_pev(ID_BURN, pev_velocity, velocity)
	}
	
	// Get player's health
	static health
	health = pev(ID_BURN, pev_health)
	
	// Take damage from the fire
	if (health - floatround(get_pcvar_float(cvar_firedamage), floatround_ceil) > 0)
		set_user_health(ID_BURN, health - floatround(get_pcvar_float(cvar_firedamage), floatround_ceil))
	
	// Flame sprite
	message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
	write_byte(TE_SPRITE) // TE id
	write_coord(origin[0]+random_num(-5, 5)) // x
	write_coord(origin[1]+random_num(-5, 5)) // y
	write_coord(origin[2]+random_num(-10, 10)) // z
	write_short(g_flameSpr) // sprite
	write_byte(random_num(5, 10)) // scale
	write_byte(200) // brightness
	message_end()
	
	// Decrease burning duration counter
	g_burning_duration[ID_BURN]--
}

// Infection Bomb: Green Blast
create_blast(const Float:originF[3])
{
	// Smallest ring
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	engfunc(EngFunc_WriteCoord, originF[0]) // x axis
	engfunc(EngFunc_WriteCoord, originF[1]) // y axis
	engfunc(EngFunc_WriteCoord, originF[2]+385.0) // z axis
	write_short(g_exploSpr) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(0) // red
	write_byte(200) // green
	write_byte(0) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
	
	// Medium ring
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	engfunc(EngFunc_WriteCoord, originF[0]) // x axis
	engfunc(EngFunc_WriteCoord, originF[1]) // y axis
	engfunc(EngFunc_WriteCoord, originF[2]+470.0) // z axis
	write_short(g_exploSpr) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(0) // red
	write_byte(200) // green
	write_byte(0) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
	
	// Largest ring
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	engfunc(EngFunc_WriteCoord, originF[0]) // x axis
	engfunc(EngFunc_WriteCoord, originF[1]) // y axis
	engfunc(EngFunc_WriteCoord, originF[2]+555.0) // z axis
	write_short(g_exploSpr) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(0) // red
	write_byte(200) // green
	write_byte(0) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
}

// Fire Grenade: Fire Blast
create_blast2(const Float:originF[3])
{
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte (TE_SPRITE) // TE ID
	engfunc(EngFunc_WriteCoord, originF[0]) // Position X
	engfunc(EngFunc_WriteCoord, originF[1]) // Y
	engfunc(EngFunc_WriteCoord, originF[2] + 50.0) // Z
	write_short(g_fireexp) // Sprite index
	write_byte(20) // Size of sprite
	write_byte(200) // Low For Light | More For Dark !
	message_end()

	message_begin (MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte( TE_SPRITETRAIL ) // Throws a shower of sprites or models
	engfunc(EngFunc_WriteCoord, originF[ 0 ]) // start pos
	engfunc(EngFunc_WriteCoord, originF[ 1 ])
	engfunc(EngFunc_WriteCoord, originF[ 2 ] + 200.0)
	engfunc(EngFunc_WriteCoord, originF[ 0 ]) // velocity
	engfunc(EngFunc_WriteCoord, originF[ 1 ])
	engfunc(EngFunc_WriteCoord, originF[ 2 ] + 30.0)
	write_short(g_fire_gibs) // spr
	write_byte(60) // (count)
	write_byte(random_num(27,30)) // (life in 0.1's)
	write_byte(2) // byte (scale in 0.1's)
	write_byte(50) // (velocity along vector in 10's)
	write_byte(10) // (randomness of velocity in 10's)
	message_end()
	//end efec

	// Smallest ring
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	engfunc(EngFunc_WriteCoord, originF[0]) // x axis
	engfunc(EngFunc_WriteCoord, originF[1]) // y axis
	engfunc(EngFunc_WriteCoord, originF[2]+385.0) // z axis
	write_short(g_exploSpr) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(200) // red
	write_byte(100) // green
	write_byte(0) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
	
	// Medium ring
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	engfunc(EngFunc_WriteCoord, originF[0]) // x axis
	engfunc(EngFunc_WriteCoord, originF[1]) // y axis
	engfunc(EngFunc_WriteCoord, originF[2]+470.0) // z axis
	write_short(g_exploSpr) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(200) // red
	write_byte(50) // green
	write_byte(0) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
	
	// Largest ring
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	engfunc(EngFunc_WriteCoord, originF[0]) // x axis
	engfunc(EngFunc_WriteCoord, originF[1]) // y axis
	engfunc(EngFunc_WriteCoord, originF[2]+555.0) // z axis
	write_short(g_exploSpr) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(200) // red
	write_byte(0) // green
	write_byte(0) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
}

// Frost Grenade: Freeze Blast
create_blast3(const Float:originF[3])
{
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte (TE_SPRITE) // TE ID
	engfunc(EngFunc_WriteCoord, originF[0]) // Position X
	engfunc(EngFunc_WriteCoord, originF[1]) // Y
	engfunc(EngFunc_WriteCoord, originF[2] + 50.0) // Z
	write_short(g_frostexp) // Sprite index
	write_byte(20) // Size of sprite
	write_byte(200) // Low For Light | More For Dark !
	message_end()

	message_begin (MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte( TE_SPRITETRAIL ) // Throws a shower of sprites or models
	engfunc(EngFunc_WriteCoord, originF[ 0 ]) // start pos
	engfunc(EngFunc_WriteCoord, originF[ 1 ])
	engfunc(EngFunc_WriteCoord, originF[ 2 ] + 200.0)
	engfunc(EngFunc_WriteCoord, originF[ 0 ]) // velocity
	engfunc(EngFunc_WriteCoord, originF[ 1 ])
	engfunc(EngFunc_WriteCoord, originF[ 2 ] + 30.0)
	write_short(g_frost_gibs) // spr
	write_byte(60) // (count)
	write_byte(random_num(27,30)) // (life in 0.1's)
	write_byte(2) // byte (scale in 0.1's)
	write_byte(50) // (velocity along vector in 10's)
	write_byte(10) // (randomness of velocity in 10's)
	message_end() 
	//end efec
	// Smallest ring
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	engfunc(EngFunc_WriteCoord, originF[0]) // x axis
	engfunc(EngFunc_WriteCoord, originF[1]) // y axis
	engfunc(EngFunc_WriteCoord, originF[2]+385.0) // z axis
	write_short(g_exploSpr) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(0) // red
	write_byte(100) // green
	write_byte(200) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
	
	// Medium ring
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	engfunc(EngFunc_WriteCoord, originF[0]) // x axis
	engfunc(EngFunc_WriteCoord, originF[1]) // y axis
	engfunc(EngFunc_WriteCoord, originF[2]+470.0) // z axis
	write_short(g_exploSpr) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(0) // red
	write_byte(100) // green
	write_byte(200) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
	
	// Largest ring
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	engfunc(EngFunc_WriteCoord, originF[0]) // x axis
	engfunc(EngFunc_WriteCoord, originF[1]) // y axis
	engfunc(EngFunc_WriteCoord, originF[2]+555.0) // z axis
	write_short(g_exploSpr) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(0) // red
	write_byte(100) // green
	write_byte(200) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
}

// Fix Dead Attrib on scoreboard
FixDeadAttrib(id)
{
	message_begin(MSG_BROADCAST, g_msgScoreAttrib)
	write_byte(id) // id
	write_byte(0) // attrib
	message_end()
}

// Send Death Message for infections
SendDeathMsg(attacker, victim)
{
	message_begin(MSG_BROADCAST, g_msgDeathMsg)
	write_byte(attacker) // killer
	write_byte(victim) // victim
	write_byte(1) // headshot flag
	write_string("infection") // killer's weapon
	message_end()
}

// Update Player Frags and Deaths
UpdateFrags(attacker, victim, frags, deaths, scoreboard)
{
	// Set attacker frags
	set_pev(attacker, pev_frags, float(pev(attacker, pev_frags) + frags))
	
	if(victim != -1)
		fm_cs_set_user_deaths(victim, cs_get_user_deaths(victim) + deaths)
	
	// Update scoreboard with attacker and victim info
	if (scoreboard)
	{
		message_begin(MSG_BROADCAST, g_msgScoreInfo)
		write_byte(attacker) // id
		write_short(pev(attacker, pev_frags)) // frags
		write_short(cs_get_user_deaths(attacker)) // deaths
		write_short(0) // class?
		write_short(fm_cs_get_user_team(attacker)) // team
		message_end()
		
		message_begin(MSG_BROADCAST, g_msgScoreInfo)
		write_byte(victim) // id
		write_short(pev(victim, pev_frags)) // frags
		write_short(cs_get_user_deaths(victim)) // deaths
		write_short(0) // class?
		write_short(fm_cs_get_user_team(victim)) // team
		message_end()
	}
}

// Remove Player Frags (when Nemesis/Survivor ignore_frags cvar is enabled)
RemoveFrags(attacker, victim)
{
	// Remove attacker frags
	set_pev(attacker, pev_frags, float(pev(attacker, pev_frags) - 1))
	
	// Remove victim deaths
	fm_cs_set_user_deaths(victim, cs_get_user_deaths(victim) - 1)
}

// Plays a sound on clients
PlaySound(const sound[]) 
{
    if (equal(sound[strlen(sound)-4], ".mp3"))
        client_cmd(0, "mp3 play ^"%s^"", sound);
    else
        client_cmd(0, "spk ^"%s^"", sound);
    
} 

// Prints a colored message to target (use 0 for everyone), supports ML formatting.
// Note: I still need to make something like gungame's LANG_PLAYER_C to avoid unintended
// argument replacement when a function passes -1 (it will be considered a LANG_PLAYER)
zp_colored_print(target, const message[], any:...)
{
	static buffer[512], i, argscount
	argscount = numargs()
	
	// Send to everyone
	if (!target)
	{
		static player
		for (player = 1; player <= g_maxplayers; player++)
		{
			// Not connected
			if (!g_isconnected[player])
				continue;
			
			// Remember changed arguments
			static changed[5], changedcount // [5] = max LANG_PLAYER occurencies
			changedcount = 0
			
			// Replace LANG_PLAYER with player id
			for (i = 2; i < argscount; i++)
			{
				if (getarg(i) == LANG_PLAYER)
				{
					setarg(i, 0, player)
					changed[changedcount] = i
					changedcount++
				}
			}
			
			// Format message for player
			vformat(buffer, charsmax(buffer), message, 3)
			
			// Send it
			message_begin(MSG_ONE_UNRELIABLE, g_msgSayText, _, player)
			write_byte(player)
			write_string(buffer)
			message_end()
			
			// Replace back player id's with LANG_PLAYER
			for (i = 0; i < changedcount; i++)
				setarg(changed[i], 0, LANG_PLAYER)
		}
	}
	// Send to specific target
	else
	{
		// Format message for player
		vformat(buffer, charsmax(buffer), message, 3)
		
		// Send it
		message_begin(MSG_ONE, g_msgSayText, _, target)
		write_byte(target)
		write_string(buffer)
		message_end()
	}
}

/*================================================================================
 [Stocks]
=================================================================================*/

// Set an entity's key value (from fakemeta_util)
stock fm_set_kvd(entity, const key[], const value[], const classname[])
{
	set_kvd(0, KV_ClassName, classname)
	set_kvd(0, KV_KeyName, key)
	set_kvd(0, KV_Value, value)
	set_kvd(0, KV_fHandled, 0)

	dllfunc(DLLFunc_KeyValue, entity, 0)
}

// Get entity's speed (from fakemeta_util)
stock fm_get_speed(entity)
{
	static Float:velocity[3]
	pev(entity, pev_velocity, velocity)
	
	return floatround(vector_length(velocity));
}

// Get entity's aim origins (from fakemeta_util)
stock fm_get_aim_origin(id, Float:origin[3])
{
	static Float:origin1F[3], Float:origin2F[3]
	pev(id, pev_origin, origin1F)
	pev(id, pev_view_ofs, origin2F)
	xs_vec_add(origin1F, origin2F, origin1F)

	pev(id, pev_v_angle, origin2F);
	engfunc(EngFunc_MakeVectors, origin2F)
	global_get(glb_v_forward, origin2F)
	xs_vec_mul_scalar(origin2F, 9999.0, origin2F)
	xs_vec_add(origin1F, origin2F, origin2F)

	engfunc(EngFunc_TraceLine, origin1F, origin2F, 0, id, 0)
	get_tr2(0, TR_vecEndPos, origin)
}

// Find entity by its owner (from fakemeta_util)
stock fm_find_ent_by_owner(entity, const classname[], owner)
{
	while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", classname)) && pev(entity, pev_owner) != owner) { /* keep looping */ }
	return entity;
}

// Collect random spawn points
stock load_spawns()
{
	// Check for CSDM spawns of the current map
	new cfgdir[32], mapname[32], filepath[100], linedata[64]
	get_configsdir(cfgdir, charsmax(cfgdir))
	get_mapname(mapname, charsmax(mapname))
	formatex(filepath, charsmax(filepath), "%s/csdm/%s.spawns.cfg", cfgdir, mapname)
	
	// Load CSDM spawns if present
	if (file_exists(filepath))
	{
		new csdmdata[10][6], file = fopen(filepath,"rt")
		
		while (file && !feof(file))
		{
			fgets(file, linedata, charsmax(linedata))
			
			// invalid spawn
			if(!linedata[0] || str_count(linedata,' ') < 2) continue;
			
			// get spawn point data
			parse(linedata,csdmdata[0],5,csdmdata[1],5,csdmdata[2],5,csdmdata[3],5,csdmdata[4],5,csdmdata[5],5,csdmdata[6],5,csdmdata[7],5,csdmdata[8],5,csdmdata[9],5)
			
			// origin
			g_spawns[g_spawnCount][0] = floatstr(csdmdata[0])
			g_spawns[g_spawnCount][1] = floatstr(csdmdata[1])
			g_spawns[g_spawnCount][2] = floatstr(csdmdata[2])
			
			// increase spawn count
			g_spawnCount++
			if (g_spawnCount >= sizeof g_spawns) break;
		}
		if (file) fclose(file)
	}
	else
	{
		// Collect regular spawns
		collect_spawns_ent("info_player_start")
		collect_spawns_ent("info_player_deathmatch")
	}
	
	// Collect regular spawns for non-random spawning unstuck
	collect_spawns_ent2("info_player_start")
	collect_spawns_ent2("info_player_deathmatch")
}

// Collect spawn points from entity origins
stock collect_spawns_ent(const classname[])
{
	new ent = -1
	while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", classname)) != 0)
	{
		// get origin
		new Float:originF[3]
		pev(ent, pev_origin, originF)
		g_spawns[g_spawnCount][0] = originF[0]
		g_spawns[g_spawnCount][1] = originF[1]
		g_spawns[g_spawnCount][2] = originF[2]
		
		// increase spawn count
		g_spawnCount++
		if (g_spawnCount >= sizeof g_spawns) break;
	}
}

// Collect spawn points from entity origins
stock collect_spawns_ent2(const classname[])
{
	new ent = -1
	while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", classname)) != 0)
	{
		// get origin
		new Float:originF[3]
		pev(ent, pev_origin, originF)
		g_spawns2[g_spawnCount2][0] = originF[0]
		g_spawns2[g_spawnCount2][1] = originF[1]
		g_spawns2[g_spawnCount2][2] = originF[2]
		
		// increase spawn count
		g_spawnCount2++
		if (g_spawnCount2 >= sizeof g_spawns2) break;
	}
}

// Drop primary/secondary weapons
stock drop_weapons(id, dropwhat)
{
	// Get user weapons
	static weapons[32], num, i, weaponid
	num = 0 // reset passed weapons count (bugfix)
	get_user_weapons(id, weapons, num)
	
	// Loop through them and drop primaries or secondaries
	for (i = 0; i < num; i++)
	{
		// Prevent re-indexing the array
		weaponid = weapons[i]
		
		if ((dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM)) || (dropwhat == 2 && ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM)))
		{
			// Get weapon entity
			static wname[32], weapon_ent
			get_weaponname(weaponid, wname, charsmax(wname))
			weapon_ent = fm_find_ent_by_owner(-1, wname, id)
			
			// Hack: store weapon bpammo on PEV_ADDITIONAL_AMMO
			set_pev(weapon_ent, PEV_ADDITIONAL_AMMO, cs_get_user_bpammo(id, weaponid))
			
			// Player drops the weapon and looses his bpammo
			engclient_cmd(id, "drop", wname)
			cs_set_user_bpammo(id, weaponid, 0)
		}
	}
}

// Stock by (probably) Twilight Suzuka -counts number of chars in a string
stock str_count(const str[], searchchar)
{
	new count, i, len = strlen(str)
	
	for (i = 0; i <= len; i++)
	{
		if(str[i] == searchchar)
			count++
	}
	
	return count;
}

// Checks if a space is vacant (credits to VEN)
stock is_hull_vacant(Float:origin[3], hull)
{
	engfunc(EngFunc_TraceHull, origin, origin, 0, hull, 0, 0)
	
	if (!get_tr2(0, TR_StartSolid) && !get_tr2(0, TR_AllSolid) && get_tr2(0, TR_InOpen))
		return true;
	
	return false;
}

// Check if a player is stuck (credits to VEN)
stock is_player_stuck(id)
{
	static Float:originF[3]
	pev(id, pev_origin, originF)
	
	engfunc(EngFunc_TraceHull, originF, originF, 0, (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN, id, 0)
	
	if (get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid) || !get_tr2(0, TR_InOpen))
		return true;
	
	return false;
}

// Simplified get_weaponid (CS only)
stock cs_weapon_name_to_id(const weapon[])
{
	static i
	for (i = 0; i < sizeof WEAPONENTNAMES; i++)
	{
		if (equal(weapon, WEAPONENTNAMES[i]))
			return i;
	}
	
	return 0;
}

// Get User Current Weapon Entity
stock fm_cs_get_current_weapon_ent(id)
{
	return get_pdata_cbase(id, OFFSET_ACTIVE_ITEM, OFFSET_LINUX);
}

// Get Weapon Entity's Owner
stock fm_cs_get_weapon_ent_owner(ent)
{
	return get_pdata_cbase(ent, OFFSET_WEAPONOWNER, OFFSET_LINUX_WEAPONS);
}

// Set User Deaths
stock fm_cs_set_user_deaths(id, value)
{
	set_pdata_int(id, OFFSET_CSDEATHS, value, OFFSET_LINUX)
}

// Get User Team
stock fm_cs_get_user_team(id)
{
	return get_pdata_int(id, OFFSET_CSTEAMS, OFFSET_LINUX);
}

// Set a Player's Team
stock fm_cs_set_user_team(id, team)
{
	set_pdata_int(id, OFFSET_CSTEAMS, team, OFFSET_LINUX)
}

// Set User Flashlight Batteries
stock fm_cs_set_user_batteries(id, value)
{
	set_pdata_int(id, OFFSET_FLASHLIGHT_BATTERY, value, OFFSET_LINUX)
}

// Update Player's Team on all clients (adding needed delays)
stock fm_user_team_update(id)
{
	static Float:current_time
	current_time = get_gametime()
	
	if (current_time - g_teams_targettime >= 0.1)
	{
		set_task(0.1, "fm_cs_set_user_team_msg", id+TASK_TEAM)
		g_teams_targettime = current_time + 0.1
	}
	else
	{
		set_task((g_teams_targettime + 0.1) - current_time, "fm_cs_set_user_team_msg", id+TASK_TEAM)
		g_teams_targettime = g_teams_targettime + 0.1
	}
}

// Send User Team Message
public fm_cs_set_user_team_msg(taskid)
{
	// Note to self: this next message can now be received by other plugins
	
	// Set the switching team flag
	g_switchingteam = true
	
	// Tell everyone my new team
	emessage_begin(MSG_ALL, g_msgTeamInfo)
	ewrite_byte(ID_TEAM) // player
	ewrite_string(CS_TEAM_NAMES[fm_cs_get_user_team(ID_TEAM)]) // team
	emessage_end()
	
	// Done switching team
	g_switchingteam = false
}
public off(id)
{
	message_begin(MSG_ONE, g_msgScreenFade, {0,0,0}, id)
	write_short(1<<10)
	write_short(1<<10)
	write_short(0x0000)
	//g_ColorNVsion[item][nvisionName]
	// Nemesis / Madness / Spectator in nemesis round
	write_byte(g_ColorNVsion[g_iNVsion[id]][nvisionColor][0]) // r
	write_byte(g_ColorNVsion[g_iNVsion[id]][nvisionColor][1]) // g
	write_byte(g_ColorNVsion[g_iNVsion[id]][nvisionColor][2]) // b

	write_byte(0)
	message_end()

	static lighting[2]
	get_pcvar_string(cvar_lighting, lighting, charsmax(lighting))
	strtolower(lighting)

	set_player_light(id, lighting);
}
stock set_player_light(id, const LightStyle[])
{
	//cambiar si cae MSG_ONE_UNRELIABLE 
    message_begin(MSG_ONE, SVC_LIGHTSTYLE, .player = id)
    write_byte(0)
    write_string(LightStyle)
    message_end()
} 
SetExp(index, iExp)
{
	if( fnGetPlaying()-1 < 2 )
	{
		zp_colored_print(index, "^x04%s ^x01Necesitas^x04 3 ^x01Players para ganar^x04 EXP. ", g_szPrefix);
		return;    
	}
	if(!is_user_connected(index) || g_iLevel[index] > MAX_LEVEL) 
		return;        

	static iLevel; iLevel = g_iLevel[index];
	static iRango; iRango = g_iRango[index];

	g_iExp[index] += (iExp*g_iHappyMulti)*g_iMultiplicador[index][ 0 ];
	g_temExp[index] += (iExp*g_iHappyMulti)*g_iMultiplicador[index][ 0 ];
	zp_colored_print(index, "^x04%s ^x01Ganaste^x04 %d ^x01de^x04 EXPERIENCIA.", g_szPrefix, iExp);
	while(g_iExp[index] >= RequiredExp[g_iLevel[index] >= MAX_LEVEL ? MAX_LEVEL-1 : g_iLevel[index]-1] && g_iLevel[index] < MAX_LEVEL+1)
	{ 
		++g_iLevel[index];
	}

	if(g_iLevel[index] > iLevel) zp_colored_print(index, "^x04%s ^x01Felicidades! Subiste al nivel ^x04%d", g_szPrefix, g_iLevel[index]);

	while(g_iLevel[index] >= rango[g_iRango[index] >= charsmax(rango) ? charsmax(rango) : g_iRango[index]][range_level] && g_iRango[index] < charsmax(rango)) 
		++g_iRango[index];

	if(g_iRango[index] > iRango) zp_colored_print(index, "^x04%s ^x01Felicidades! Subiste al Rango ^x04%s", g_szPrefix, rango[g_iRango[index]][range_name]);

	FuncReset(index);
}

public FuncReset(index)
{
    if(g_iLevel[index] <= MAX_LEVEL)
    	return PLUGIN_HANDLED;
    

    ++g_iReset[index];
    g_iExp[index] = 0;
    g_iLevel[index] = 1;
    g_iRango[index] = 0;

    zp_colored_print(index, "^x04%s ^x01Felicidades! ^x04Reseteaste ^x01tu cuenta, ahora eres reset ^x04%d", g_szPrefix, g_iReset[index]);
    return PLUGIN_HANDLED;
}
RefreshHH()
{
    g_bHappyTime = false;
    g_iDefaultDamage = DEFAULT_DAMAGE;

    if(!get_pcvar_num(cvar_modes))
    	g_iDefaultDamage = DEFAULT_DAMAGE*2;

    g_iHappyMulti = 1;

    static i, current_hour[3], szDay[5], iActive; iActive = 0;
    get_time("%H", current_hour, 2);

    for( i = 0 ; i < sizeof _HappyHour ; ++i )
    {
        if(equal(_HappyHour[i][HH_HOUR], current_hour))
        {
            g_bHappyTime = true;
            g_iHappyMulti = _HappyHour[i][HH_MULTI];
            g_iDefaultDamage = _HappyHour[i][HH_DAMAGE];

            iActive = 1;

            zp_colored_print(0, "^x04 %s^x01 HORA FELIZ^x04 ACTIVA!^x01 Multiplicador: ^x04%d + ARMAS FREE PARA TODOS!", g_szPrefix, g_iHappyMulti);
            zp_colored_print(0, "^x04 %s^x01 HORA FELIZ^x04 ACTIVA!^x01 Multiplicador: ^x04%d + ARMAS FREE PARA TODOS!", g_szPrefix, g_iHappyMulti);
            break;
        }
    }
    get_time( "%a", szDay, 4 );
    if( equal( szDay, "Sun" ) && !iActive && !get_pcvar_num(cvar_event) || get_pcvar_num(cvar_event) && !iActive )
    {
		g_bHappyTime = true;
		g_iHappyMulti = 3;
		zp_colored_print(0, "^x04 %s^x01 HORA FELIZ TODO EL DIA^x04!^x01 Multiplicador: ^x04%d + ARMAS FREE PARA TODOS!", g_szPrefix, g_iHappyMulti)
		zp_colored_print(0, "^x04 %s^x01 HORA FELIZ TODO EL DIA^x04!^x01 Multiplicador: ^x04%d + ARMAS FREE PARA TODOS!", g_szPrefix, g_iHappyMulti)
    }
}
public show_menu_buy1(id)
{
	if( !is_user_alive(id) || !is_user_connected(id) )
		return;
	
	if (g_class[id] >= SURVIVOR) 
		return;
	
	strip_user_weapons(id);
	give_item(id, "weapon_knife");
	
	cmd_Menu_guns(id)
}

public cmd_Menu_guns(id)
{
	if( g_bAutoSeleccion[id] || g_bAnterior[id] || g_class[id] >= SURVIVOR )
		return PLUGIN_HANDLED;

	//ArraySortEx( g_aArray, "orderWeapons" );
	new szItem[ 40 ];
	new menu[1024], len;

	len = 0;

	len += formatex(menu[len], sizeof menu - 1 - len, "\rArmamento^n^n");
	//error
	if (g_Prim > 0) {
		// ArrayGetString(g_szName, g_iSelected[id][PRIMARIA], szItem, charsmax(szItem) );
		ArrayGetArray(g_aArray, g_iSelected[id][PRIMARIA], weaponOrder);
		copy(szItem, charsmax(szItem), weaponOrder[Weapon_Name]);
		len += formatex(menu[len], sizeof menu - 1 - len, "\r1. \wPrimary [\y%s\w]^n", g_iSelected[id][PRIMARIA] <= -1 ? "None" : szItem);
	} else {
		len += formatex(menu[len], sizeof menu - 1 - len, "\r1. \wNo hay armas primarias Cargadas..^n");
	}

	if (g_Sec > 0) {
		// ArrayGetString(g_szName, g_iSelected[id][SECUNDARIA], szItem, charsmax(szItem) );
		ArrayGetArray(g_aArray, g_iSelected[id][SECUNDARIA], weaponOrder);
		copy(szItem, charsmax(szItem), weaponOrder[Weapon_Name]);
		len += formatex(menu[len], sizeof menu - 1 - len, "\r2. \wSecundary [\y%s\w]^n", g_iSelected[id][SECUNDARIA] <= -1 ? "None" : szItem);
	} else {
		len += formatex(menu[len], sizeof menu - 1 - len, "\r2. \wNo hay armas secundarias Cargadas..^n");
	}

	if (g_Knife > 0) {
		// ArrayGetString(g_szName,g_iSelected[id][KNIFE], szItem, charsmax(szItem) );
		ArrayGetArray(g_aArray, g_iSelected[id][KNIFE], weaponOrder);
		copy(szItem, charsmax(szItem), weaponOrder[Weapon_Name]);
		len += formatex(menu[len], sizeof menu - 1 - len, "\r3. \wKnifes [\y%s\w]^n", g_iSelected[id][KNIFE] <= -1 ? "None" : szItem);
	} else {
		len += formatex(menu[len], sizeof menu - 1 - len, "\r3. \wNo hay Knifes Cargados..^n");
	}
		
	len += formatex(menu[len], sizeof menu - 1 - len, "\r4. \wGrenades [\y%s\w]^n", Granadas[g_iGranada[id]][granada_nombre]);


	len += formatex(menu[len], sizeof menu - 1 - len, "^n\r5. \rArmarse^n");
	len += formatex(menu[len], sizeof menu - 1 - len, "\r6. \wAuto-Seleccion^n^n");

	len += formatex(menu[len], sizeof menu - 1 - len, "\r0.\wSalir");

	show_menu(id, KEYSMENU, menu, -1, "Menu Armas");
	return PLUGIN_HANDLED;
}

public handlerMenu(id, item)
{
	if ( item == 9 || g_bAutoSeleccion[id] || g_bAnterior[id] || g_class[id] >= SURVIVOR )
	{
		return PLUGIN_HANDLED;
	}
	switch(item)
	{
		
		case 0:
		{
			menu_armas( id, PRIMARIA );
		}
		case 1:
		{
			menu_armas( id, SECUNDARIA );
		}
		case 2:
		{
			menu_armas( id, KNIFE );
		}
		case 3:
		{
			show_menu_grenades(id);
		}
		case 4:
		{
			if(g_iSelected[id][PRIMARIA] <= -1 || g_iSelected[id][SECUNDARIA] <= -1 || g_iSelected[id][KNIFE] <= -1 || g_bAnterior[id])
			{
				client_print(id, print_center, "No haz elegido armas anteriormente");
				return PLUGIN_HANDLED;
			}
			g_bAnterior[id] = true;
			Anteriores(id);
		}
		case 5:
		{
			if(g_iSelected[id][PRIMARIA] <= -1 || g_iSelected[id][SECUNDARIA] <= -1 || g_iSelected[id][KNIFE] <= -1 )
			{
				client_print(id, print_center, "No haz elegido armas anteriormente");
				return PLUGIN_HANDLED;
			}
			
			g_bAutoSeleccion[id] = true;
			Anteriores(id)
			client_print(id, print_center, "La Auto-Selecci? ha sido Activada.");
		}
	}
	return PLUGIN_HANDLED;
}

public orderWeapons(Array:g_aArray, elem1[], elem2[]) {
	new iTemp1 = (elem1[ Weapon_Reset ] * MAX_LEVEL) + elem1[ Weapon_Level ];
	new iTemp2 = (elem2[ Weapon_Reset ] * MAX_LEVEL) + elem2[ Weapon_Level ];

	if( iTemp1 > iTemp2 )
	    return 1;

	if( iTemp1 < iTemp2 )
	    return -1;

	return 0;
}

public menu_armas( id, item )
{
	//ArraySortEx( g_aArray, "orderWeapons" )

	new menu = menu_create( "Menu Armas", "handler_skins" );
	static Item[ 30 ], g_isLen[80], admin, level, reset, cat;
	
	for( new i = 0; i < gTotalItems; i++ )
	{
		ArrayGetArray( g_aArray, i, weaponOrder );
		formatex( Item, charsmax( Item ), "%d", i );
		cat = weaponOrder[Weapon_Category];
		admin = weaponOrder[Weapon_Admin];
		reset = weaponOrder[Weapon_Reset];
		level = weaponOrder[Weapon_Level];
			
		console_print(id, "%s | [ L:%d-R:%d ]", weaponOrder[Weapon_Name], level, reset)

		if( item != cat ) 
			continue;
		
		if( admin == ADMIN_ALL )
		{
			if( g_iLevel[id] >= level && g_iReset[id] == reset || g_iReset[id] > reset || g_bHappyTime && reset <= 0)
			{
				formatex(g_isLen, charsmax(g_isLen), "%s", weaponOrder[Weapon_Name]);
			}
			else
			{
				formatex(g_isLen, charsmax(g_isLen), "\d%s | \y[ \rL:%d\y-\rR:%d \y]", weaponOrder[Weapon_Name], level, reset);
			}
		}
		else
		{
			if( get_user_flags(id) & admin || get_pcvar_num( cvar_event ) )
			{
				if( g_iLevel[id] >= level && g_iReset[id] == reset || g_iReset[id] > reset || g_bHappyTime && reset <= 0 )
				{
					formatex(g_isLen, charsmax(g_isLen), "%s | \y[ \rL:%d\y-\rR:%d \y]", weaponOrder[Weapon_Name], level, reset);
				}
				else
				{
					formatex(g_isLen, charsmax(g_isLen), "\d%s | \y[ \rL:%d\y-\rR:%d \y]", weaponOrder[Weapon_Name], level, reset);
				}
			}
			else
			{
				formatex(g_isLen, charsmax(g_isLen), "\d%s | ADMIN: \y[ \rL:%d\y-\rR:%d \y]", weaponOrder[Weapon_Name], level, reset);
			}
		}
		menu_additem(menu, g_isLen, Item);
	}
	
	menu_display( id, menu );
	return PLUGIN_HANDLED;
} 
public handler_skins( id, menu, item ) 
{
	if( item == MENU_EXIT || !(0 <= item < gTotalItems) || !is_user_alive(id) || g_class[id] >= SURVIVOR ) 
	{
		menu_destroy( menu );
		return PLUGIN_HANDLED;
	}
	new szData[ 20 ], Item[ 400 ];
	new item_access, item_callback;
	menu_item_getinfo( menu, item, item_access, szData,charsmax( szData ), Item, charsmax(Item), item_callback );
	
	new reset, level, item2 = str_to_num( szData );
	// ArraySortEx( g_aArray, "orderWeapons" );
	ArrayGetArray( g_aArray, item2, weaponOrder );
	
	new admin = weaponOrder[Weapon_Admin];//ArrayGetCell( g_iTipo, item2 );

	new szItem[32]; copy(szItem, charsmax(szItem), weaponOrder[Weapon_Name]);//ArrayGetString(g_szName, item2, szItem, charsmax(szItem) );
	new szAdmin[32]; copy(szAdmin, charsmax(szAdmin), weaponOrder[Weapon_AdminType]);//ArrayGetString(g_szTipo, item2, szAdmin, charsmax(szAdmin) );
	new cat = weaponOrder[Weapon_Category];//ArrayGetCell( g_iCat, item2 );
	reset = weaponOrder[Weapon_Reset]; // ArrayGetCell( g_aReset, item2 );
	level = weaponOrder[Weapon_Level]; // ArrayGetCell( g_aLevel, item2 );
	
	if( !g_bHappyTime && g_iLevel[id] < level && g_iReset[id] == reset || g_iReset[id] < reset  )
	{
		zp_colored_print(id, "^x04LEVEL o RESET ^x01insuficiente");
		menu_armas( id, cat );
		return PLUGIN_HANDLED;
	}
	
	if( admin == ADMIN_ALL )
	{
		//obtenerArmas(id, item2, cat);
		g_iSelected[id][cat] = item2;
	}
	else 
	{
		if( get_user_flags(id) & admin || get_pcvar_num( cvar_event ) )
		{
			//obtenerArmas(id, item2, cat);
			g_iSelected[id][cat] = item2;
		}
		else
		{
			zp_colored_print(id, "^x04%s ^x01Compra un ^x04ADMIN^x01 para ese ^x04ITEM^x01", g_szPrefix);
			menu_armas( id, cat );
		}
	}
	cmd_Menu_guns(id);
	return PLUGIN_HANDLED;
}

public Anteriores(id)
{
	if(g_iSelected[id][PRIMARIA] <= -1 || g_iSelected[id][SECUNDARIA] <= -1 || g_iSelected[id][KNIFE] <= -1)
		return;
	//strip_user_weapons(id);
	get_grenades(id, g_iGranada[id]);
	obtenerArmas(id, g_iSelected[id][PRIMARIA], PRIMARIA);
	obtenerArmas(id, g_iSelected[id][SECUNDARIA], SECUNDARIA);
	obtenerArmas(id, g_iSelected[id][KNIFE], KNIFE);
}

public force_give_weapon(plugin, params) {
	static szItem[120], cat;

	new szNombre[32]; get_string(2, szNombre, charsmax(szNombre));
	//ArraySortEx( g_aArray, "orderWeapons" );
	for( new i = 0; i < gTotalItems; i++ )
	{
		// ArrayGetString(g_szName, i, szItem, charsmax(szItem) );
		ArrayGetArray(g_aArray, i, weaponOrder);
		copy(szItem, charsmax(szItem), weaponOrder[Weapon_Name]);
		if (equali(szNombre, szItem)) {
			cat = weaponOrder[Weapon_Category]; //ArrayGetCell( g_iCat, i );

			getWeapons(get_param(1), i, cat);
			break;
		}
		
	}
}

public getWeapons(id, aItem, cat) {
	if(!is_user_alive(id) || !is_user_connected(id) || g_class[id] >= SURVIVOR)
		return;

	new ret; ArrayGetArray(g_aArray, aItem, weaponOrder);
	
	ExecuteForward(fw_Item_Selected, ret, id, weaponOrder[Weapon_Pos]);
	
	if ( ret == PLUGIN_HANDLED )
		client_print(id, print_chat, "No puedes comprarlo ahora.");
	else
	{
		new szItemName[32];
		// ArrayGetString(g_szName, aItem, szItemName, charsmax(szItemName));
		copy(szItemName, charsmax(szItemName), weaponOrder[Weapon_Name]);
		zp_colored_print(id, "Has comprado: ^x04%s^x01", szItemName);
	}
}

public obtenerArmas(id, aItem, cat)
{
	if(!is_user_alive(id) || !is_user_connected(id) || g_class[id] >= SURVIVOR)
		return;
	g_iCategoria[id] = cat;
	g_iSelected[id][cat] = aItem;
	
	new ret; ArrayGetArray(g_aArray, aItem, weaponOrder);
	ExecuteForward(fw_Item_Selected, ret, id, weaponOrder[Weapon_Pos]);
	
	if ( ret == PLUGIN_HANDLED )
		client_print(id, print_chat, "No puedes comprarlo ahora.");
	else
	{
		new szItemName[32];
		// ArrayGetString(g_szName, aItem, szItemName, charsmax(szItemName));
		copy(szItemName, charsmax(szItemName), weaponOrder[Weapon_Name]);
		zp_colored_print(id, "Has comprado: ^x04%s^x01", szItemName);
	}
}
public chooseview(id)
{
    new menu[192] 
    new keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3;
    format(menu, 191, "Menu de camaras^n^n1. Tercera persona^n2. Desde arriba^n3. Primera persona^n^n0. Salir") ;
    show_menu(id, keys, menu)     ; 
    return PLUGIN_CONTINUE;
}

public setview(id, key, menu)
{
	if(!get_pcvar_num(cvar_modes))
		return PLUGIN_HANDLED;
	if(key == 0) 
	{
		set_view(id, CAMERA_3RDPERSON);
		return PLUGIN_HANDLED;
	}

	if(key == 1) 
	{
		set_view(id, CAMERA_TOPDOWN);
		return PLUGIN_HANDLED;
	}

	if(key == 2) 
	{
		set_view(id, CAMERA_NONE);
		return PLUGIN_HANDLED;
	}
	return PLUGIN_HANDLED	
} 
public show_menu_grenades(id) 
{    
	new menu = menu_create("\wMenu de bombas", "menu_bombas_handler") 

	new len[1024];
	for (new i = 0; i < sizeof Granadas; i++) 
	{
		if(g_iLevel[id] >= Granadas[i][granada_nivel]) 
			formatex(len, sizeof len - 1, "\w%s\y" , Granadas[i][granada_nombre])
		else 
			formatex(len, sizeof len - 1, "\d%s \r(Nivel: %d)" , Granadas[i][granada_nombre] , Granadas[i][granada_nivel])
		
		menu_additem(menu, len);
	}

	menu_setprop(menu, MPROP_BACKNAME, "\yAtras") 
	menu_setprop(menu, MPROP_NEXTNAME, "\ySiguiente") 
	menu_setprop(menu, MPROP_EXITNAME, "\ySalir") 
	menu_display(id, menu, 0) 
}

public menu_bombas_handler(id, menu, item) 
{
	if(item == MENU_EXIT || !is_user_connected(id)) 
	{ 
	    menu_destroy(menu) 
	    return PLUGIN_HANDLED 
	} 

	if(g_iLevel[id] < Granadas[item][granada_nivel]) 
	{    
	    zp_colored_print(id, "Para este pack tu nivel debe ser:^x04 %d.", Granadas[item][granada_nivel]);
	    show_menu_grenades(id);
	    return PLUGIN_HANDLED;
	}
	g_iGranada[id] = item;
	cmd_Menu_guns(id);
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public get_grenades(id, item)
{
	if(!is_user_alive(id))
		return;

	new HE = 0, FLASH = 0, SMOKE = 0;
	
	//flash = frost/droga, smoke = campo/pipe
	if(Granadas[item][cantidad_bubble] > 0)
		SMOKE += Granadas[item][cantidad_bubble];
	
	if(Granadas[item][cantidad_pipe] > 0)
	{
		SMOKE += Granadas[item][cantidad_pipe];
		g_iPipe[id] = Granadas[item][cantidad_pipe];
	}

	if(Granadas[item][cantidad_fire] > 0)
		HE += Granadas[item][cantidad_fire];

	if(Granadas[item][cantidad_chain] > 0)
	{
		HE += Granadas[item][cantidad_chain];
		g_iHe[id] = Granadas[item][cantidad_chain];
	}

	if(Granadas[item][cantidad_frost] > 0)
		FLASH += Granadas[item][cantidad_frost];

	if(Granadas[item][cantidad_droga] > 0)
	{
		FLASH += Granadas[item][cantidad_droga];
		g_iDroga[id] = Granadas[item][cantidad_droga];
	}

	if(HE > 0)
	{
		give_item(id, "weapon_hegrenade")
		cs_set_user_bpammo(id, CSW_HEGRENADE, HE);
	}
		
	if(FLASH > 0)
	{
		give_item(id, "weapon_flashbang")
		cs_set_user_bpammo(id, CSW_FLASHBANG, FLASH);
	}
		
	if(SMOKE > 0)
	{
		give_item(id, "weapon_smokegrenade")
		cs_set_user_bpammo(id, CSW_SMOKEGRENADE, SMOKE);
	}		
}
public register_arma(plugin, params)
{
	if (get_param(4) == PRIMARIA) {
		++g_Prim;
	}
	if (get_param(4) == SECUNDARIA) {
		++g_Sec;
	}
	if (get_param(4) == KNIFE) {
		++g_Knife;
	}

	get_string(1, weaponOrder[Weapon_Name], charsmax(weaponOrder[Weapon_Name]));
	weaponOrder[Weapon_Level] = get_param(2);
	weaponOrder[Weapon_Reset] = get_param(3);
	weaponOrder[Weapon_Category] = get_param(4);
	weaponOrder[Weapon_Admin] = get_param(5);
	weaponOrder[Weapon_Pos] = gTotalItems;
	get_string(6, weaponOrder[Weapon_AdminType], charsmax(weaponOrder[Weapon_AdminType]));

	ArrayPushArray(g_aArray, weaponOrder);

	ArraySortEx(g_aArray, "orderWeapons");

	++gTotalItems;
	
	return gTotalItems-1;
}
public guardar_datos( id ) 
{
	if(!advacc_user_logged(id) || g_iStatus[ id ] != LOGUEADO)
		return;

	new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];
	iData[ 0 ] = id;
	iData[ 1 ] = GUARDAR_DATOS;
	
	formatex( szQuery, charsmax( szQuery ), "UPDATE %s SET level='%d', reset='%d', exp='%d', rango='%d', ammopacks='%d', hud='%d', nvision='%d', hat='%d', escapes='%d' WHERE id_cuenta='%d'", 
		szTable, g_iLevel[ id ], g_iReset[ id ], g_iExp[ id ], g_iRango[ id ], g_ammopacks[ id ], g_iHud[ id ], g_iNVsion[ id ], g_iHat[ id ], g_iEscapes[ id ], g_id[ id ] );
	SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
}

public offSkins( id )
{
	if(!advacc_user_logged(id) || g_iStatus[ id ] != LOGUEADO)
		return;

	g_iSkinsEnable[ id ] = !g_iSkinsEnable[ id ];

	client_print(id, print_center, "%sctivaste las skins de tu armas.", g_iSkinsEnable[ id ] ? "Desa" : "a");
}

public amx_activar( id )
{
	if(!advacc_user_logged(id) || g_iStatus[ id ] != LOGUEADO)
		return PLUGIN_HANDLED;

	new iBuffer[ 128 ], 
	Query[ 256 ], 
	iData[ 2 ]; 

	iData[ 0 ] = id; 
	iData[ 1 ] = ACTIVAR_CODE;

	read_args( iBuffer, charsmax(iBuffer) );
	remove_quotes( iBuffer );

	formatex( Query , charsmax( Query ) , "SELECT * FROM %s WHERE Code=^"%s^"", szTableCodes, iBuffer );
	SQL_ThreadQuery(g_hTuple, "DataHandler", Query, iData, 2 );

	return PLUGIN_HANDLED;
}

public checkRank( id )
{
	if(!advacc_user_logged(id) || g_iStatus[ id ] != LOGUEADO)
		return;

	new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];
	
	iData[ 0 ] = id;
	iData[ 1 ] = SQL_RANK;
	formatex( szQuery, charsmax( szQuery ), "SELECT (COUNT(*) + 1) FROM `%s` WHERE `reset` > '%d' OR (`reset` = '%d' AND `level` > '%d')", szTable, g_iReset[ id ], g_iReset[ id ], g_iLevel[ id ] );
	SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
	
}
public menu_cordenada(id)
{
	if(!is_user_admin(id))
		return PLUGIN_HANDLED;

	new menu = menu_create("Menu Admin", "handler_cordenada");

	if(get_user_flags(id) & ADMIN_RCON) menu_additem(menu, "Crear Coordenada");
	else menu_additem(menu, "\dCrear Coordenada");

	menu_additem(menu, "cargar meta")

	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public handler_cordenada(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	switch(item)
	{
		case 0:
		{
			if(get_user_flags(id) & ADMIN_RCON)
			{
				new iOrigin[3], Float:fOrigin[3], szMapa[35]; 

				get_user_origin(id, iOrigin);
				get_mapname(szMapa, 34);

				IVecFVec(iOrigin, fOrigin); 
				SaveEnt(fOrigin);
			}
			else client_print_color(id, print_team_blue, "No tienes acceso a esta opcion");
		}
		case 1:
		{
			new szQuery[ MAX_MENU_LENGTH ], iData[ 1 ], szMapName[40]; get_mapname(szMapName, 39);
				
			iData[ 0 ] = BUSCAR_META;

			formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE MapName=^"%s^"", g_szTableMaps, szMapName );
			SQL_ThreadQuery( g_hTuple, "DataHandlerServer", szQuery, iData, sizeof(iData) );
		}
	}
	return PLUGIN_HANDLED;
}
SaveEnt(const Float:Origin[3])
{
	static szCoordenada[90], szMapName[40], szQuery[ MAX_MENU_LENGTH ], iData[ 1 ]; get_mapname(szMapName, 39);
	formatex(szCoordenada, charsmax(szCoordenada),  "%.2f %.2f %.2f", Origin[0], Origin[1], Origin[2]);

	iData[ 0 ] = CREAR_META;

	formatex( szQuery, charsmax( szQuery ), "INSERT INTO %s (MapName, Coordenada) VALUES (^"%s^", ^"%s^")", g_szTableMaps, szMapName, szCoordenada );
	SQL_ThreadQuery( g_hTuple, "DataHandlerServer", szQuery, iData, sizeof(iData) );
}
public get_BestRecord()
{
	static szQuery[ MAX_MENU_LENGTH ], szMapName[40], iData[ 1 ]; get_mapname(szMapName, 39);
	iData[ 0 ] = BEST_RECORD;

	formatex( szQuery, charsmax( szQuery ), "SELECT Pj, Record FROM %s INNER JOIN zp_cuentas ON zp_cuentas.id = id_user WHERE MapName = ^"%s^" ORDER BY Record ASC LIMIT 1 ", 
		g_szTableRecord, szMapName );

	//client_print_color(0, print_team_blue, "%s", szQuery)
	SQL_ThreadQuery( g_hTuple, "DataHandlerServer", szQuery, iData, sizeof(iData) );
}
public DataHandlerServer( failstate, Handle:Query, error[ ], error2, data[ ], datasize, Float:flTime ) 
{
	switch( failstate ) 
	{
		case TQUERY_CONNECT_FAILED: 
		{
			log_to_file( "SQL_ZE_LOG.txt", "Error en la conexion al MySQL [%i]: %s", error2, error );
			return;
		}
		case TQUERY_QUERY_FAILED:
		log_to_file( "SQL_ZE_LOG.txt", "Error en la consulta al MySQL [%i]: %s", error2, error );
	}
	switch( data[ 0 ] ) 
	{
		case CREAR_META:
		{
			if( failstate < TQUERY_SUCCESS ) 
			{
				console_print( 0, "Error al crear una meta: %s.", error );
			}
			else
			{
				new szQuery[ MAX_MENU_LENGTH ], iData[ 1 ], szMapName[40]; get_mapname(szMapName, 39);
				
				iData[ 0 ] = BUSCAR_META;

				formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE MapName=^"%s^"", g_szTableMaps, szMapName );
				SQL_ThreadQuery( g_hTuple, "DataHandlerServer", szQuery, iData, sizeof(iData) );
			}
		}
		case BUSCAR_META:
		{
			if( SQL_NumResults( Query ) )
			{
				static Float:iPoss[3], szData[40], szData1[40], szData2[40], szData3[40];

				SQL_ReadResult( Query, 2, szData, charsmax(szData) );
				parse( szData, szData1, charsmax(szData1), szData2, charsmax(szData2), szData3, charsmax(szData3));

				iPoss[ 0 ] = str_to_float( szData1 );
				iPoss[ 1 ] = str_to_float( szData2 );
				iPoss[ 2 ] = str_to_float( szData3 );

				CreateEnt( iPoss );
			}
		}
		case BEST_RECORD:
		{
			if( SQL_NumResults( Query ) )
			{
				SQL_ReadResult( Query, 0, g_szNameRecord, charsmax(g_szNameRecord) );
				SQL_ReadResult( Query, 1, _:g_fTimeRecord );
				zp_colored_print(0, "^x04 %s^x01 El ^x4Record^x01 en este mapa es de^x04 %s^x1 Con ^x04%f ^x1segundos.", 
					g_szPrefix, g_szNameRecord, g_fTimeRecord);
			}
			else
			{
				zp_colored_print(0, "^x4%s ^x1No hay ^x4Records ^x1 en este mapa", g_szPrefix);
			}
		}
	}
}
CreateEnt(const Float:Origin[3])
{
	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))    
	if(!ent) 
		return PLUGIN_HANDLED;
	
	engfunc(EngFunc_SetModel, ent, MODEL_meta);
	set_pev(ent, pev_solid, SOLID_TRIGGER);
	set_pev(ent, pev_classname, g_szEnt);
	engfunc(EngFunc_SetSize, ent, Float:{-150.0, -1.0, -150.0}, Float:{150.0, 1.0, 150.0});
	set_rendering(ent, kRenderFxGlowShell, 125, 125, 125, kRenderNormal, 16);
	set_pev(ent, pev_mins, Float:{-150.0, -1.0, -150.0});
	set_pev(ent, pev_maxs, Float:{150.0, 1.0, 150.0});
	engfunc(EngFunc_SetOrigin, ent, Origin);

	return PLUGIN_HANDLED;
}
public DataHandler( failstate, Handle:Query, error[ ], error2, data[ ], datasize, Float:flTime ) 
{
	switch( failstate ) 
	{
		case TQUERY_CONNECT_FAILED: 
		{
			log_to_file( "SQL_LOG_TQ.txt", "Error en la conexion al MySQL [%i]: %s", error2, error );
			return;
		}
		case TQUERY_QUERY_FAILED:
		log_to_file( "SQL_LOG_TQ.txt", "Error en la consulta al MySQL [%i]: %s", error2, error );
	}
	
	new id = data[ 0 ];
	
	if( !is_user_connected( id ) )
		return;
	
	switch( data[ 1 ] ) 
	{
		case LOGUEAR_USUARIO: 
		{
			if( SQL_NumResults( Query ) )
			{
				g_iLevel[ id ] = SQL_ReadResult( Query, 1 );
				g_iReset[ id ] = SQL_ReadResult( Query, 2 );
				g_iExp[ id ] = SQL_ReadResult( Query, 3 );
				g_iRango[ id ] = SQL_ReadResult( Query, 4 );
				g_ammopacks[ id ] = SQL_ReadResult( Query, 5 );
				g_iHud[ id ] = SQL_ReadResult( Query, 6 );
				g_iNVsion[ id ] = SQL_ReadResult( Query, 7 );
				//hat 8
				//zombies kills 9
				g_iEscapes[ id ] = SQL_ReadResult( Query, 10 );

				// Set the custom HUD display task
				set_task(1.0, "ShowHUD", id+TASK_SHOWHUD, _, _, "b");
				ForceJoinTeam(id);

				new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ], szMapName[40]; get_mapname(szMapName, 39);
				
				iData[ 0 ] = id;
				iData[ 1 ] = CARGAR_RECORD;
				
				formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE id_user = %d AND MapName = ^"%s^"", g_szTableRecord, g_id[ id ], szMapName );
				SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, sizeof(iData) );

				client_print_color(id, print_team_blue, "Tu ID es %d pueden usarla para referenciarte con ella.", g_id[ id ]);
				client_print_color(id, print_team_blue, "Tu ID es %d pueden usarla para referenciarte con ella.", g_id[ id ]);
				client_print_color(id, print_team_blue, "Tu ID es %d pueden usarla para referenciarte con ella.", g_id[ id ]);
				client_print_color(id, print_team_blue, "Tu ID es %d pueden usarla para referenciarte con ella.", g_id[ id ]);
				client_print_color(id, print_team_blue, "Tu ID es %d pueden usarla para referenciarte con ella.", g_id[ id ]);
				
				g_iStatus[ id ] = LOGUEADO;
			}
			else
			{
				new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];
				
				iData[ 0 ] = id;
				iData[ 1 ] = REGISTRAR_USUARIO;
				
				formatex( szQuery, charsmax( szQuery ), "INSERT INTO %s (id_cuenta, level, reset, exp, rango, ammopacks, hud, nvision, hat, kill_zombies, escapes) VALUES (%d, %d, %d, %d, %d, %d, %d, %d, %d, 0, %d)", 
					szTable, g_id[ id ], g_iLevel[ id ], g_iReset[ id ], g_iExp[ id ], g_iRango[ id ], g_ammopacks[ id ], g_iHud[ id ], g_iNVsion[ id ], g_iHat[ id ], g_iEscapes[ id ] );
				SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
			}
		}
		case REGISTRAR_USUARIO: 
		{
			if( failstate < TQUERY_SUCCESS ) 
			{
				console_print( id, "Error al crear un usuario: %s.", error );
			}
			else
			{
				new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];
				
				iData[ 0 ] = id;
				iData[ 1 ] = LOGUEAR_USUARIO;

				formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE id_cuenta='%d'", szTable, g_id[ id ] );
				SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
			}
		}
		case GUARDAR_DATOS:
		{
			if( failstate < TQUERY_SUCCESS )
				console_print( id, "Error en el guardado de datos." );
			else
			console_print( id, "Datos guardados." );
		}
		case SQL_RANK:
		{
			if( SQL_NumResults( Query ) )
				zp_colored_print( id,  "^4%s^1 Tu Rank es ^4%i", g_szPrefix, SQL_ReadResult( Query, 0 ) );
		}
		case INSERTAR_RECORD:
		{
			if( failstate < TQUERY_SUCCESS ) 
			{
				console_print( id, "Error al crear un RECORD: %s.", error );
			}
		}
		case CARGAR_RECORD:
		{
			if(SQL_NumResults(Query))
			{
				SQL_ReadResult(Query, 3, _:g_fRecord[id]);
			}
			else
			{
				new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ], szMapName[40]; get_mapname(szMapName, charsmax(szMapName));
				
				iData[ 0 ] = id;
				iData[ 1 ] = INSERTAR_RECORD;
				
				formatex( szQuery, charsmax( szQuery ), "INSERT INTO %s (id_user, MapName, Record) VALUES (%d, ^"%s^", %f)", g_szTableRecord, g_id[ id ], szMapName, g_fRecord[id] );
				SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, sizeof(iData) );
			}
		}
		case ACTIVAR_CODE: 
        {
            if( SQL_NumResults(Query) ) 
            {
                if( SQL_ReadResult( Query, 4 ) >= 1 )
                {
                    zp_colored_print( id , "Ya usaron este ^x04codigo!" );
                    return;
                }
                
                new szBuffer[ 200 ], 
                sum = SQL_ReadResult( Query, 3 );
                
                new Code[ 190 ]; 
                SQL_ReadResult(Query, 1, Code, charsmax( Code ) );
                g_ammopacks[id] += sum;
                guardar_datos(id);
                
                zp_colored_print( 0 , "^x01 El player^x04 %s^x01 Activo un code de^x04 %d^x01 ammopacks", g_playername[ id ], sum );
                zp_colored_print( 0 , "^x01 para obtener uno Compra el tuyo en: ^x01[ ^4%s ^1]", iWeb);
                
                client_print(id, print_console, "//                        [ ze_code system by Hypnotize ]                        \\");
                client_print(id, print_console, "Gracias por preferinos, recuerda visitar %s para mas info.", iWeb);
                client_print(id, print_console, "Activaste un code de [ %d ] Ammopacks !", sum);
                client_print(id, print_console, "Codigo: [ %s ] | Premio: [ %d ]", Code, sum);
                client_print(id, print_console, "Activado por: %s", g_playername[ id ]);
                client_print(id, print_console, "//                        [ ze_code system by Hypnotize ]                        \\");
                
                new iData[ 2 ]; 
                
                iData[ 0 ] = id; 
                iData[ 1 ] = GUARDAR_DATOS;
                
                formatex( szBuffer, 255, "UPDATE %s SET usado=1, Pj=^"%s^" WHERE Code=^"%s^"", szTableCodes, g_playername[ id ], Code );
                
                SQL_ThreadQuery(g_hTuple, "DataHandler", szBuffer, iData, 2 );                                                                
            }
            else
            zp_colored_print( id, "^x04code^x01 no ^x04encontrado");
        }
	}
}
public cmdParty(id) 
{
    if(g_PartyData[id][In_Party])
        show_party_info_menu(id)
    else
        show_party_menu(id)
    
    return PLUGIN_HANDLED
}

public show_party_menu(id) 
{
    
    new iMenu = menu_create("\wMenu Party:","party_menu"), BlockParty[50]
    
    menu_additem(iMenu, "\wCrear Party", "0")
    
    formatex(BlockParty, charsmax(BlockParty), "\wBloquear Invitaciones De Party: \r%s",g_PartyData[id][Block_Party] ? "Si" : "No")
    
    menu_additem(iMenu, BlockParty, "1")
    
    menu_setprop(iMenu, MPROP_EXITNAME, "Salir")
    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    
    menu_display(id, iMenu, 0)
}

public show_party_info_menu(id) {
    
    new iMenu = menu_create("\wMenu Party:","party_info_menu")
    
    menu_additem(iMenu, "\wAgregar Integrante", .callback = g_MenuCallback[MASTER])
    menu_additem(iMenu, "\wExpulsar Integrande", .callback = g_MenuCallback[MASTER])
    menu_additem(iMenu, "\wDestruir \rParty", .callback = g_MenuCallback[MASTER])
    menu_additem(iMenu, "\wSalir del \rParty", .callback = g_MenuCallback[USER])
    
    menu_setprop(iMenu, MPROP_EXITNAME, "Salir")
    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    
    menu_display(id, iMenu)
}

public show_party_add_menu(id) {
    
    new iMenu = menu_create(g_PartyData[id][In_Party] ? "\rAgregar Integrante:" : "\rCrear Party:", "party_create_menu"), Poss[3], Name[32]
    
    for(new i = 1; i <= g_maxplayers; i++) {
        
        if(!is_available_to_party(i) || id == i)
            continue;
            
        get_user_name(i, Name, charsmax(Name))
        num_to_str(i, Poss, charsmax(Poss))
        menu_additem(iMenu, Name, Poss)
    }
    
    menu_setprop(iMenu, MPROP_EXITNAME, "Salir")
    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    
    menu_display(id, iMenu)
}

public show_party_kick_menu(id) {
    
    new iMenu = menu_create("\rKick Party Menu:","party_kick_menu"), Players[32], Poss[3], user
    
    get_party_index(id, Players)
    
    for(new i; i < g_PartyData[id][Amount_In_Party]; i++) {
        user = Players[i]
        num_to_str(user, Poss, charsmax(Poss))
        menu_additem(iMenu, g_PartyData[user][UserName], Poss)
    }
    
    menu_setprop(iMenu, MPROP_EXITNAME, "Salir")
    
    menu_display(id, iMenu)
}

public show_party_invite_menu(id2, MasterId) {
    
    new MenuTitle[128], iMenu, Str_MasterId[3]
    
    set_player_party_name(MasterId)
    set_player_party_name(id2)
    
    client_print(MasterId, print_chat, "%s Solicitud enviada a %s", g_szPrefix, g_PartyData[id2][UserName])
    
    formatex(MenuTitle, charsmax(MenuTitle), "%s te mando una invitacion para %s Party", g_PartyData[MasterId][UserName], g_PartyData[MasterId][In_Party] ? "unirte al" : "crear un")
    
    new UserTaskArgs[3]
    
    UserTaskArgs[0] = iMenu = menu_create( MenuTitle , "party_invite_menu")
    UserTaskArgs[1] = MasterId
    
    num_to_str(MasterId, Str_MasterId, charsmax(Str_MasterId))
    
    menu_additem( iMenu , "Aceptar", Str_MasterId)
    menu_additem( iMenu , "Rechazar", Str_MasterId)
    
    if(is_user_bot(id2) && get_pcvar_num(cvar_allow_bots)) {
        party_invite_menu(id2, iMenu, 0)
        return
    }
    
    menu_setprop(iMenu, MPROP_EXIT, MEXIT_NEVER)
    
    menu_display(id2, iMenu)
    
    remove_task_acept(id2)
    
    set_task(get_pcvar_float(cvar_time_acept), "Time_Acept", id2+TASK_ACEPT, UserTaskArgs, 2)
}
    

public party_menu(id, menu, item) {
    
    if(item == MENU_EXIT) {
        menu_destroy(menu)
        return
    }
    
    if(item) {
        g_PartyData[id][Block_Party] = g_PartyData[id][Block_Party] ? false : true
        show_party_menu(id)
    }
    else
        show_party_add_menu(id)
    
    menu_destroy(menu)
    
}

public party_create_menu(id, menu, item) {
    
    if(item == MENU_EXIT) {
        menu_destroy(menu)
        return
    }
    
    new iKey[6], iAccess, iCallback, id2
    
    menu_item_getinfo(menu, item, iAccess, iKey, charsmax(iKey), _, _, iCallback)
    
    id2 = str_to_num(iKey)
    
    if(!is_available_to_party(id2))
        return
    
    show_party_invite_menu(id2, id)
    
    menu_destroy(menu)
}

public party_invite_menu(id, menu, item) {
    
    if(item == MENU_EXIT) {
        menu_destroy(menu)
        remove_task_acept(id)
        return
    }
    
    new iKey[6], iAccess, iCallback, id_master
    
    menu_item_getinfo(menu, item, iAccess, iKey, charsmax(iKey), _, _, iCallback)
    
    id_master = str_to_num(iKey)
    
    switch(item) {
        case 0: {
                        
            if(!g_PartyData[id_master][In_Party]) {
                create_party(id_master, id)
            }
            else {
                if(g_PartyData[id_master][Amount_In_Party] == get_pcvar_num(cvar_max_players)) {
                
                    client_print(id, print_chat, "%s Ya se alcanzo el numero maximo de integrantes en la party", g_szPrefix)
                    client_print(id_master, print_chat, "%s Ya alcanzaste el numero maximo de integrantes en la party", g_szPrefix)
                
                    remove_task_acept(id)
    
                    menu_destroy(menu)
                    return
                }
                
                add_party_user(id_master, id)
            }
            
            client_print(id_master, print_chat, "%s %s fue agregado al Party", g_szPrefix, g_PartyData[id][UserName])
        }
        case 1: client_print(id_master, print_chat, "%s %s cancelo la invitacion de Party", g_szPrefix, g_PartyData[id][UserName])
    }
    
    remove_task_acept(id)
    
    menu_destroy(menu)
}

public party_kick_menu(id, menu, item) {
    
    if(item == MENU_EXIT) {
        menu_destroy(menu)
        return
    }
    
    new iKey[6], iAccess, iCallback, id2
    
    menu_item_getinfo(menu, item, iAccess, iKey, charsmax(iKey), _, _, iCallback)
    
    id2 = str_to_num(iKey)
    
    if(is_user_connected(id2))
        g_PartyData[id][Amount_In_Party] > 1 ? destoy_party(id) : remove_party_user(id2)
    
    menu_destroy(menu)
}

public party_info_menu(id, menu,item) {
    
    if(item == MENU_EXIT) {
        menu_destroy(menu)
        return
    }
    
    switch(item) {
        case 0: {
            if(g_PartyData[id][Amount_In_Party] < get_pcvar_num(cvar_max_players))
                show_party_add_menu(id)
            else
                client_print(id, print_chat, "%s Ya alcanzaste el numero maximo de integrantes en la party", g_szPrefix)
        }
        case 1: show_party_kick_menu(id)
        case 2: destoy_party(id)
        case 3: remove_party_user(id)
    }
    
    menu_destroy(menu)
}
public Time_Acept(UserTaskArgs[], taskid) {
    
    taskid -= TASK_ACEPT;
    
    if(!g_PartyData[taskid][In_Party]) {
        
        client_print(UserTaskArgs[1], print_chat, "%s %s cancelo la invitacion de party", g_szPrefix, g_PartyData[taskid][UserName])
        menu_destroy(UserTaskArgs[0])
        show_menu(taskid, 0, "^n", 1)
    }
}

stock create_party(master, guest) {
    
    set_party_member(master, master)
    set_party_member(master, guest)
    set_party_member(guest, master)
    set_party_member(guest, guest)
    
    set_party_vars(master, Start_Amount)
    set_party_vars(guest, ++g_PartyData[master][Amount_In_Party])
}

stock add_party_user(master, guest) {
    
    new Players[32], member, amount = g_PartyData[master][Amount_In_Party]
        
    get_party_index(master, Players)
    
    for(new i; i < amount; i++) {
        
        member = Players[i]
        
        set_party_member(guest, member)
        set_party_member(member, guest)
        g_PartyData[member][Amount_In_Party]++
        
    }
    
    set_party_member(guest, guest)
    set_party_vars(guest, amount+1)    
}

stock set_party_member(id, id2)
    ArrayPushCell(Party_Ids[id], id2)

stock set_party_vars(id, amount) {
    
    g_PartyData[id][In_Party] = true
    g_PartyData[id][Position] = amount-1
    g_PartyData[id][Amount_In_Party] = amount
    
}

stock destoy_party(id) {
    
    new Players[32], id2, Amount = g_PartyData[id][Amount_In_Party]
    get_party_index(id, Players)
    
    for(new i; i < Amount; i++) {
        id2 = Players[i]
        clear_party_user(id2)
        client_print(id2, print_chat, "%s La party fue destruida", g_szPrefix)
        
        remove_task(id2+TASK_FINISH_COMBO)
        set_task(1.0, "finish_combo", id2+TASK_FINISH_COMBO)    
    }
}

stock remove_party_user(user) {
    
    new Players[32], id, Amount = g_PartyData[user][Amount_In_Party]
    
    get_party_index(user, Players)
    
    clear_party_user(user)
    
    for(new i; i < Amount; i++) {
    
        id = Players[i]
        
        if(id != user) {
            ArrayClear(Party_Ids[id])
            
            for(new z; z < Amount; z++)                    
                if(Players[z] != user)
                    set_party_member(id, Players[z])
                
            g_PartyData[id][Position] = i
            g_PartyData[id][Amount_In_Party] = Amount-1
            client_print(id, print_chat, "%s %s salio del party", g_szPrefix, g_PartyData[user][UserName])
        }
    }
}

stock clear_party_user(id) {
    ArrayClear(Party_Ids[id])
    g_PartyData[id][In_Party] = false
    g_PartyData[id][Position] = NONE
    g_PartyData[id][Amount_In_Party] = NONE
    
    // COMBOLAS
    remove_task(id+TASK_FINISH_COMBO);
    g_damagedealt[id] = 0;
    g_iComboPartyHits[id] = 0;
    g_iComboPartyAP[id] = 0;
    iComboTime[id] = 0.0;
    ClearSyncHud(id, g_MsgSyncParty);
}

stock remove_task_acept(id)
    if(task_exists(id+TASK_ACEPT))
        remove_task(id+TASK_ACEPT)
    

stock set_player_party_name(id) {
    
    if(g_PartyData[id][UserName][0])
        return 0
    
    get_user_name(id, g_PartyData[id][UserName], charsmax(g_PartyData[][UserName]))
    
    return 1
}

stock is_available_to_party(id) {
    
    if(!is_user_connected(id) || g_PartyData[id][In_Party] || g_PartyData[id][Block_Party])
        return false
    
    return true
}        
    
stock get_party_index(id, players[]) {
    
    for(new i; i < g_PartyData[id][Amount_In_Party]; i++)
        players[i] = ArrayGetCell(Party_Ids[id], i)
    
    return players[0] ? 1 : 0
}

public check_master(id)
    return g_PartyData[id][Position] ? ITEM_DISABLED : ITEM_ENABLED
    
public check_user(id)
    return g_PartyData[id][Position] ? ITEM_ENABLED : ITEM_DISABLED

ShowPartyCombo(iPartyID, iAttacker, Float:fDamage)
{
    if(iPartyID == iAttacker){
        set_hudmessage(0, 255, 0, fHudX, fHudY, 0, 3.0, 3.0, 0.01, 0.01);
        ShowSyncHudMsg(iPartyID, g_MsgSyncParty, "Combo Party - Ammopacks: %d^nHits: %d - Daño: %2.f", g_iComboPartyAP[iPartyID], g_iComboPartyHits[iPartyID], fDamage);
    }
    else{
        set_hudmessage(0, 255, 0, fHudX, fHudY, 0, 3.0, 3.0, 0.01, 0.01);
        ShowSyncHudMsg(iPartyID, g_MsgSyncParty, "Combo Party - Ammopacks: %d - Hits: %d", g_iComboPartyAP[iPartyID], g_iComboPartyHits[iPartyID]);
    }

    remove_task(iPartyID+TASK_FINISH_COMBO);
    set_task(10.0, "finish_combo", iPartyID+TASK_FINISH_COMBO);
}

public finish_combo(taskid){
    static id; id = ID_FINISH_COMBO;
    
    static recibidos; recibidos = ( g_iComboPartyAP[id] / g_PartyData[ id ][ Amount_In_Party ])

    if(recibidos < 0) recibidos = 0;

    g_ammopacks[id] += (recibidos * g_iMultiplicador[id][ 1 ] * g_steamBonus[id]);    
    g_tempApps[id] += (recibidos * g_iMultiplicador[id][ 1 ]);
    zp_colored_print(id, "^x04[PARTY]^x01 Ammopacks:^x03 %d con %d^x01 Hits en^x03 %d Personas", recibidos, g_iComboPartyHits[id], g_PartyData[ id ][ Amount_In_Party ]);

    g_damagedealt[id] = 0;
    g_iComboPartyHits[id] = 0;
    g_iComboPartyAP[id] = 0;
    iComboTime[id] = 0.0;
    ClearSyncHud(id, g_MsgSyncParty);
}

public clcmd_say(id)
{
	if( g_iStatus[ id ] != LOGUEADO )
		return PLUGIN_HANDLED;
		
	static said[191], class[90], iRango_player;
	read_args(said, charsmax(said));
	remove_quotes(said);
	replace_all(said, charsmax(said), "%", " ");
	replace_all(said, charsmax(said), "#", " ");

	if (!ValidMessage(said, 1)) return PLUGIN_CONTINUE;
	iRango_player = g_iRango[id] >= charsmax(rango) ? charsmax(rango) : g_iRango[id];

	xResult = regex_match(said, PATTERN_IP, xReturnValue, xError, 63)

	if(xResult)
	{
		zp_colored_print(id, "^x4%s ^x1Tu mensaje fue considerado como SPAM.", g_szPrefix);
		return PLUGIN_HANDLED;
	}

	static color[11], prefix[91];
	get_user_team(id, color, charsmax(color));
	if(g_class[id] >= ZOMBIE) formatex(class, charsmax(class), "%s", g_zombie_classname[id])
	else
	{
		if(g_humanclass[id] != ZCLASS_NONE)
			formatex(class, charsmax(class), "%s", g_human_classname[id]);
		else
			formatex(class, charsmax(class), "%s", rango[iRango_player][range_name]);
	}
	
	formatex(prefix, charsmax(prefix), "%s ^x04%s^x01 [ R ^x04%d^x01 - L ^x04%d^x01 ]^x03 %s", g_isalive[id] ? "^x01" : "^x01*MUERTO* ", g_szTag[id], g_iReset[id], g_iLevel[id], g_playername[id])
	
	if(is_user_admin(id)) format(said, charsmax(said), "^x04%s", said)
	format(said, charsmax(said), "%s^x01 :  %s", prefix, said)
	
	static i, team[11] 
	for (i = 1; i <= g_maxplayers; i++) 
	{
		if (!g_isconnected[i]) 
			continue;
			
		if (is_user_admin(i) || g_isalive[id] && g_isalive[i] || !g_isalive[id] && !g_isalive[i] || g_isalive[id] && !g_isalive[i] || !g_isalive[id] && g_isalive[i])
		{
			get_user_team(i, team, charsmax(team))
			changeTeamInfo(i, color)
			writeMessage(i, said)
			changeTeamInfo(i, team)
		}
	}
	return PLUGIN_HANDLED_MAIN;
}
public changeTeamInfo(player, team[])
{
	message_begin(MSG_ONE, g_msgTeamInfo, _, player)
	write_byte(player)
	write_string(team)
	message_end()
}

public writeMessage(player, message[])
{
	message_begin(MSG_ONE, g_msgSayText, {0, 0, 0}, player)
	write_byte(player)
	write_string(message)
	message_end()
}


public FwdHamWeaponReload( const iWeapon )
	if( get_pdata_int( iWeapon, m_fInReload, 4 ) ) // m_fInReload is set to TRUE in DefaultReload( )
		DoRadio( get_pdata_cbase( iWeapon, m_pPlayer, 4 ) );

public FwdHamShotgunReload( const iWeapon ) 
{
	if( get_pdata_int( iWeapon, m_fInSpecialReload, 4 ) != 1 )
		return;
	
	// The first set of m_fInSpecialReload to 1. m_flTimeWeaponIdle remains 0.55 set from Reload( )
	new Float:flTimeWeaponIdle = get_pdata_float( iWeapon, m_flTimeWeaponIdle, 4 );
	
	if( flTimeWeaponIdle != 0.55 )
		return;
	
	DoRadio( get_pdata_cbase( iWeapon, m_pPlayer, 4 ) );
}
public get_rdnWeapon(id, cat)
{
	//ArraySortEx( g_aArray, "orderWeapons" );
	static i, num;
	for( i = 0; i < gTotalItems; i++ )
	{
		if(!is_user_connected(id))
			continue;

		ArrayGetArray(g_aArray, i, weaponOrder);
			
		if(weaponOrder[Weapon_Category] == cat)
		{
			num = i;
			break;
		}
	}
	return num;
}
DoRadio( const id ) 
{
	new iClip, iWeapon  = get_user_weapon( id, iClip );
	new Float:flPercent = floatmul( float( iClip ) / g_iMaxClip[ iWeapon ], 100.0 );
	new Float:flCvar    = get_pcvar_float( g_pPercent );
	
	if( flPercent > flCvar )
		return;
	
	new szSound[ 32 ];
	copy( szSound, 31, SOUNDS[ random( sizeof( SOUNDS ) ) ] );
	emit_sound(id, CHAN_VOICE, szSound, 0.5, ATTN_NORM, 0, PITCH_NORM);
}
stock ValidMessage(text[], maxcount) 
{
	static len, i, count
	len = strlen(text)
	count = 0
	
	if (!len)
		return false;
    
	for (i = 0; i < len; i++) 
	{
		if (text[i] != ' ') 
		{
			count++
			if (count >= maxcount)
				return true;
		}
	}
	return false;
} 
stock get_speed_vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= num
	new_velocity[1] *= num
	new_velocity[2] *= num
	       
	return 1;
}
stock precache_player_model( const modelname[] )
{
	static longname[128]; // Precache normal type model 
	formatex(longname, charsmax(longname), "models/player/%s/%s.mdl", modelname, modelname); 
	precache_generic(longname); 
	 
	// Check TFiles inquiries 
	copy(longname[strlen(longname)-4], charsmax(longname) - (strlen(longname)-4), "T.mdl") ;
	if (file_exists(longname)) precache_generic(longname); 
}

public ForceJoinTeam(index)
{
	if( get_user_team(index) == 1 || get_user_team(index) == 2)
	{
		return;
	}

	static teammsg_block, teammsg_block_vgui, restore, vgui, msg_showmenu, msg_vguimenu;
	
	if( !msg_showmenu) msg_showmenu = get_user_msgid( "ShowMenu");
	
	if( !msg_vguimenu) msg_vguimenu = get_user_msgid("VGUIMenu");
	
	restore = get_pdata_int(index, 510); vgui = restore & (1<<0);
	
	if (vgui) set_pdata_int(index, 510, restore & ~(1<<0));
	
	teammsg_block = get_msg_block( msg_showmenu); teammsg_block_vgui = get_msg_block( msg_vguimenu );
	
	set_msg_block( msg_showmenu , BLOCK_ONCE); set_msg_block( msg_vguimenu , BLOCK_ONCE);
	engclient_cmd(index, "jointeam", "5"); 
	engclient_cmd(index, "joinclass", "5");
	set_msg_block( msg_showmenu, teammsg_block); set_msg_block( msg_vguimenu, teammsg_block_vgui);

	//set_task(5.0, "my_id", index);
	if (vgui) set_pdata_int(index, 510, restore);	
}

public my_id(id) {
	if (!is_user_connected(id)) {
		return PLUGIN_HANDLED;
	}
	client_print( id, print_chat, "%s TU ID DE CUENTA ES %d.", g_szPrefix, g_id[ id ]);
	client_print( id, print_chat, "%s TU ID DE CUENTA ES %d.", g_szPrefix, g_id[ id ]);
	client_print( id, print_chat, "%s TU ID DE CUENTA ES %d.", g_szPrefix, g_id[ id ]);
	client_print( id, print_chat, "%s TU ID DE CUENTA ES %d.", g_szPrefix, g_id[ id ]);
	client_print( id, print_chat, "%s TU ID DE CUENTA ES %d.", g_szPrefix, g_id[ id ]);
	return PLUGIN_HANDLED;
}

stock add_point(number)
{ 
    new count, i, str[29], str2[35], len
    num_to_str(number, str, charsmax(str))
    len = strlen(str)
    
    for (i = 0; i < len; i++)
    {
        if (i != 0 && ((len - i) %3 == 0))
        {
            add(str2, charsmax(str2), ".", 1)
            count++
            add(str2[i+count], 1, str[i], 1)
        }
        else
            add(str2[i+count], 1, str[i], 1)
    }

    return str2;
} 