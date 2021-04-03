#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <zombieplague>

#if AMXX_VERSION_NUM > 182
#define client_disconnect client_disconnected
#endif
/*================================================================================
 [Customizations]
=================================================================================*/

// Rocket Launcher Model
new const nrl_gun_viewmodel[] = 		"models/zombie_plague/v_bazooka_cso.mdl"
new const nrl_gun_weaponmodel[] = 	"models/zombie_plague/p_bazooka_cso.mdl"

/*================================================================================

 "v_rpg.mdl" Sequence Nums
	
 Change the next lines IF YOU WANT to add support to the v_rpg.mdl model (default
 Half-Life RPG Model), don't forget to change the models:
	
	* Fire Sequence Num: 3
	* Draw Sequence Num: 5
	
=================================================================================*/

// View Model Animations
new const nrl_model_seq_fire = 8	// Model Fire Sequence Num
new const nrl_model_seq_draw = 3	// Model Draw Sequence Num

/*================================================================================

 *** This is optional ***
 
 If your model has a "Reload" Animation, you can put here his Sequence Num,
 whatever, you can disable it writing "-1".
 
 "v_rpg.mdl" Model Reload Sequence Num is "2"
 
=================================================================================*/

// Optional Reload Animation
new const nrl_model_seq_reload = -1

// Write here the aproximately num of the Reload Animation, 
// this can modify the launch fire rate. The "v_rpg.mdl" 
// aproximately reload animation time it's 2.0
const Float:nrl_reload_seq_time = 0.0

/*================================================================================
	
 By default, the Sequence Nums are from the v_stinger_frk14.mdl Model, change only
 if you want. Just in Case, here is the v_stinger_frk14.mdl Sequence Nums:
	
	* Fire Sequence Num: 8
	* Draw Sequence Num: 3
	* Reload Sequence Num: -1 (Null)
	
 The "Idle" Sequence is always the 0.

=================================================================================*/

// Admin Flag (to access to the admin privileges)
const ACCESS_FLAG = ADMIN_BAN 

// Customizable config file (into the configs folder)
//new const nrl_config_file[] = 		"zombieplague/zp_extension_nrl.cfg"

// Models
new const nrl_rocketmodel[] = 		"models/zombie_plague/rpgrocket.mdl" 	// Rocket Model

// Sprites
new const nrl_explosion_sprite[] = 	"sprites/zerogxplode.spr" 	// Explosion Sprite
new const nrl_ring_sprite[] = 		"sprites/shockwave.spr" 	// Ring Explosion Sprite
new const nrl_trail_sprite[] = 		"sprites/xbeam3.spr" 		// Rocket Follow Sprite

// Sounds
new const nrl_rocketlaunch_sound[][] = 	// Rocket Launch Sound
{ 
	"weapons/rocketfire1.wav" 
}

new const nrl_norockets_sound[][] = 	// When user doesn't have Rockets
{ 
	"weapons/dryfire1.wav" 
}

new const nrl_deploy_sound[][] = 	// Deploying user NRL
{
	"items/gunpickup3.wav"
}

new const nrl_explosion_sound[][] = 	// Rocket Explosion Sound
{
	"weapons/explode3.wav"
}

new const nrl_rocketfly_sound[][] = 	// Fly sound
{
	"weapons/rocket1.wav"
}

// Rocket Size
new Float:nrl_rocket_mins[] = 	{ 	-1.0,	-1.0,  	-1.0 	}
new Float:nrl_rocket_maxs[] = 	{ 	1.0, 	1.0, 	1.0 	}

// Colors (in RGB format)		R	G	B
new nrl_trail_colors[3] = 	{	255,	0,	0	}	// Rocket trail
new nrl_glow_colors[3] =	{	255,	0,	0	}	// Rocket glow
new nrl_dlight_colors[3] =	{	200,	200,	200	}	// Rocket dynamic light
new nrl_flare_colors[3] =	{	255,	0,	0	}	// Rocket flare
new nrl_ring_colors[3] =	{	200,	200,	200	}	// Rocket ring-explosion

/*================================================================================
 Customization ends here! Yes, that's it. Editing anything beyond
 here is not officially supported. Proceed at your own risk...
=================================================================================*/

// Booleans
new bool:g_bHasNRL[33] = { false, ... }, bool:g_bHoldingNRL[33] = { false, ... }, bool:g_bKilledByRocket[33] = { false, ... }, 
bool:g_bIsAlive[33] = { false, ... }, bool:g_bIsConnected[33] = { false, ... }, bool:g_bRoundEnding = false

// Arrays
new Float:g_flNextDeployTime[33] = { 0.0, ...}, Float:g_flNextLaunchTime[33] = { 0.0, ...}, 
g_iRocketAmount[33] = { 0, ...}, g_iCurrentWeapon[33] = { 0, ...}, g_szStatusText[33][32]

// Game vars
new g_sprExplosion, g_sprRing, g_sprTrail, g_iMaxPlayers

// Message IDs vars
new g_msgStatusText, g_msgAmmoPickup, g_msgScreenFade, g_msgScreenShake, g_msgCurWeapon, g_msgTextMsg;

// Some constants
const FFADE_IN = 		0x0000
const UNIT_SECOND = 		(1<<12)
const EV_ENT_FLARE = 		EV_ENT_euser3
const AMMOID_HEGRENADE = 	12
const IMPULSE_SPRAYLOGO = 	201

// Offsets
const m_pPlayer = 		41
const m_pActiveItem = 		373
const m_flTimeWeaponIdle = 	48

// Ring Z Axis addition
new Float:g_flRingZAxis_Add[3] = { 425.0 , 510.0, 595.0 }

// Cvar Pointers
new cvar_enable, cvar_bonushp, cvar_buyable, cvar_svvel, cvar_launchrate, cvar_launchpush, 
cvar_explo_radius, cvar_explo_damage, cvar_explo_rings, cvar_explo_dlight, cvar_damage_fade, cvar_damage_shake, 
cvar_rocket_vel, cvar_rocket_trail, cvar_rocket_glow, cvar_rocket_dlight, cvar_rocket_flare, cvar_rocket_grav,
cvar_player_rockets, cvar_player_apcost, cvar_player_rocketapcost, cvar_admin_features, cvar_admin_rockets, 
cvar_admin_apcost, cvar_admin_rocketapcost

// Cached Cvars
enum { iPlayers = 0, iAdmins }

new bool:g_bCvar_Enabled, bool:g_bCvar_GiveFree, bool:g_bCvar_AdminFeatures, 
g_iCvar_DefaultRockets[2], g_iCvar_APCost[2], g_iCvar_RocketAPCost[2]

// Plug info.
#define PLUG_VERSION "2.2"
#define PLUG_AUTH "meTaLiCroSS"

// Macros
#define is_user_valid_alive(%1) 	(1 <= %1 <= g_iMaxPlayers && g_bIsAlive[%1])
#define is_user_valid_connected(%1) 	(1 <= %1 <= g_iMaxPlayers && g_bIsConnected[%1])

/*================================================================================
 [Init, Precache and CFG]
=================================================================================*/

public plugin_init() 
{
	// Plugin Info
	register_plugin("[ZP] Extension: Nemesis Rocket Launcher", PLUG_VERSION, PLUG_AUTH)
	
	// Lang file
	//register_dictionary("zp_extension_nrl.txt")
	
	// Events
	register_event("CurWeapon", "event_CurWeapon", "be","1=1")	
	register_event("HLTV", "event_RoundStart", "a", "1=0", "2=0")
	
	// Messages
	register_message(get_user_msgid("DeathMsg"), "message_DeathMsg")
	
	// Fakemeta Forwards
	register_forward(FM_CmdStart, "fw_CmdStart")
	
	// Engine Forwards
	register_touch("nrl_rocket", "*", "fw_RocketTouch")
	
	// Ham Forwards
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "fw_Knife_Deploy_Post", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "fw_Knife_PrimaryAttack")
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "fw_Knife_SecondaryAttack")

	// CVARS - General
	cvar_enable = register_cvar("zp_nemesis_rocket_launcher", "1")
	cvar_bonushp = register_cvar("zp_nrl_health_bonus", "400")
	cvar_buyable = register_cvar("zp_nrl_give_free", "1")
	cvar_launchrate = register_cvar("zp_nrl_launch_rate", "2.0")
	cvar_launchpush = register_cvar("zp_nrl_launch_push_force", "60")
	
	// CVARS - Explosion
	cvar_explo_radius = register_cvar("zp_nrl_explo_radius", "500")
	cvar_explo_damage = register_cvar("zp_nrl_explo_maxdamage", "300")
	cvar_explo_rings = register_cvar("zp_nrl_explo_rings", "1")
	cvar_explo_dlight = register_cvar("zp_nrl_explo_dlight", "1")
	
	// CVARS - Damage
	cvar_damage_fade = register_cvar("zp_nrl_damage_screenfade", "1")
	cvar_damage_shake = register_cvar("zp_nrl_damage_screenshake", "1")
	
	// CVARS - Rocket
	cvar_rocket_vel = register_cvar("zp_nrl_rocket_speed", "1200")
	cvar_rocket_trail = register_cvar("zp_nrl_rocket_trail", "1")
	cvar_rocket_glow = register_cvar("zp_nrl_rocket_glow", "1")
	cvar_rocket_dlight = register_cvar("zp_nrl_rocket_dlight", "0")
	cvar_rocket_flare = register_cvar("zp_nrl_rocket_flare", "1")
	cvar_rocket_grav = register_cvar("zp_nrl_rocket_obeygravity", "0")
	
	// CVARS - Player Options
	cvar_player_rockets = register_cvar("zp_nrl_default_rockets", "2")
	cvar_player_apcost = register_cvar("zp_nrl_cost", "30")
	cvar_player_rocketapcost = register_cvar("zp_nrl_rocket_cost", "15")
	
	// CVARS - Admin Options
	cvar_admin_features = register_cvar("zp_nrl_admin_features_enable", "1")
	cvar_admin_rockets = register_cvar("zp_nrl_admin_default_rockets", "4")
	cvar_admin_apcost = register_cvar("zp_nrl_admin_cost", "20")
	cvar_admin_rocketapcost = register_cvar("zp_nrl_admin_rocket_cost", "8")
	
	// CVARS - Others
	cvar_svvel = get_cvar_pointer("sv_maxvelocity")
	
	static szCvar[30]
	formatex(szCvar, charsmax(szCvar), "v%s by %s", PLUG_VERSION, PLUG_AUTH)
	register_cvar("zp_extension_nrl", szCvar, FCVAR_SERVER|FCVAR_SPONLY)
	
	// Vars
	g_iMaxPlayers = get_maxplayers()
	
	// Message IDs
	g_msgCurWeapon = get_user_msgid("CurWeapon")
	g_msgAmmoPickup = get_user_msgid("AmmoPickup")
	g_msgStatusText = get_user_msgid("StatusText")
	g_msgScreenFade = get_user_msgid("ScreenFade")
	g_msgScreenShake = get_user_msgid("ScreenShake")
	g_msgTextMsg = get_user_msgid("TextMsg")
}

public plugin_precache()
{
	// Models
	precache_model(nrl_rocketmodel)
	precache_model(nrl_gun_viewmodel)
	precache_model(nrl_gun_weaponmodel)
	
	// Sounds
	static i
	for(i = 0; i < sizeof nrl_rocketlaunch_sound; i++)
		precache_sound(nrl_rocketlaunch_sound[i])
	for(i = 0; i < sizeof nrl_norockets_sound; i++)
		precache_sound(nrl_norockets_sound[i])
	for(i = 0; i < sizeof nrl_deploy_sound; i++)	
		precache_sound(nrl_deploy_sound[i])
	for(i = 0; i < sizeof nrl_explosion_sound; i++)	
		precache_sound(nrl_explosion_sound[i])
	for(i = 0; i < sizeof nrl_rocketfly_sound; i++)	
		precache_sound(nrl_rocketfly_sound[i])
	
	precache_sound("items/gunpickup2.wav")
	precache_sound("ambience/particle_suck2.wav")
	
	// Sprites
	g_sprRing = precache_model(nrl_ring_sprite)
	g_sprExplosion = precache_model(nrl_explosion_sprite)
	g_sprTrail = precache_model(nrl_trail_sprite)
	precache_model("sprites/animglow01.spr")
}

public plugin_cfg()
{
	// Now we can cache the cvars, because config file has read
	set_task(0.5, "cache_cvars")
}

/*================================================================================
 [Zombie Plague Forwards]
=================================================================================*/

public zp_user_infected_post(id, infector)
{
	set_user_nrlauncher(id, 0);
	// User is Nemesis
	if(zp_get_user_nemesis(id) && zp_is_nemesis_round())
	{
		// Plugin enabled
		if(g_bCvar_Enabled) 
		{
			// Check cvar
			if(g_bCvar_GiveFree) // Free
			{
				// Give gun
				set_user_nrlauncher(id, 1)
			}
		}
	}
	
}

public zp_user_humanized_post(id)
{
	// Reset Vars
	set_user_nrlauncher(id, 0)
}

public zp_round_ended(team)
{
	// Remove all the rockets in the map
	// remove_rockets_in_map()
	set_task(0.1, "remove_rockets_in_map")
	
	// Update var
	g_bRoundEnding = true
}

/*================================================================================
 [Public Functions]
=================================================================================*/

public reset_user_knife(id)
{
	if(!is_user_connected(id))
		return;
	// Latest version support
	ExecuteHamB(Ham_Item_Deploy, find_ent_by_owner(FM_NULLENT, "weapon_knife", id)) // v4.3 Support
	
	// Updating Model
	engclient_cmd(id, "weapon_knife")
	emessage_begin(MSG_ONE, g_msgCurWeapon, _, id)
	ewrite_byte(1) // active
	ewrite_byte(CSW_KNIFE) // weapon
	ewrite_byte(0) // clip
	emessage_end()
}

public cache_cvars()
{
	// Cache some cvars
	g_bCvar_Enabled = bool:get_pcvar_num(cvar_enable)
	g_bCvar_AdminFeatures = bool:get_pcvar_num(cvar_admin_features)
	g_bCvar_GiveFree = bool:get_pcvar_num(cvar_buyable)
	g_iCvar_DefaultRockets[iPlayers] = get_pcvar_num(cvar_player_rockets)
	g_iCvar_DefaultRockets[iAdmins] = get_pcvar_num(cvar_admin_rockets)
	g_iCvar_APCost[iPlayers] = get_pcvar_num(cvar_player_apcost)
	g_iCvar_APCost[iAdmins] = get_pcvar_num(cvar_admin_apcost)
	g_iCvar_RocketAPCost[iPlayers] = get_pcvar_num(cvar_player_rocketapcost)
	g_iCvar_RocketAPCost[iAdmins] = get_pcvar_num(cvar_admin_rocketapcost)
}

public status_text(id)
{
	// Format text
	formatex(g_szStatusText[id], charsmax(g_szStatusText[]), "Misiles %d", g_iRocketAmount[id])
	
	// Show
	message_begin(MSG_ONE, g_msgStatusText, _, id)
	write_byte(0)
	write_string((zp_get_user_nemesis(id) && g_bIsAlive[id] && g_bHoldingNRL[id] && g_iCurrentWeapon[id] == CSW_KNIFE) ? g_szStatusText[id] : "")
	message_end()
}
/*================================================================================
 [Tasks]
=================================================================================*/

public remove_rockets_in_map()
{
	// Remove Rockets, and a particle effect + sound is emited
	static iRocket 
	iRocket = FM_NULLENT
	
	// Make a loop searching for rockets
	while((iRocket = find_ent_by_class(FM_NULLENT, "nrl_rocket")) != 0)
	{
		// Get rocket origin
		static Float:flOrigin[3]
		entity_get_vector(iRocket, EV_VEC_origin, flOrigin)
		
		// Slow tracers
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, flOrigin, 0)
		write_byte(TE_IMPLOSION) // TE id
		engfunc(EngFunc_WriteCoord, flOrigin[0]) // x
		engfunc(EngFunc_WriteCoord, flOrigin[1]) // y
		engfunc(EngFunc_WriteCoord, flOrigin[2]) // z
		write_byte(200) // radius
		write_byte(40) // count
		write_byte(45) // duration
		message_end()
		
		// Faster particles
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, flOrigin, 0)
		write_byte(TE_PARTICLEBURST) // TE id
		engfunc(EngFunc_WriteCoord, flOrigin[0]) // x
		engfunc(EngFunc_WriteCoord, flOrigin[1]) // y
		engfunc(EngFunc_WriteCoord, flOrigin[2]) // z
		write_short(45) // radius
		write_byte(108) // particle color
		write_byte(10) // duration * 10 will be randomized a bit
		message_end()
		
		// Remove beam
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY, _, iRocket)
		write_byte(TE_KILLBEAM) // TE id
		write_short(iRocket) // entity
		message_end()
		
		// Sound
		emit_sound(iRocket, CHAN_WEAPON, "ambience/particle_suck2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		emit_sound(iRocket, CHAN_VOICE, "ambience/particle_suck2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		// Remove his flare
		remove_rocket_flare(iRocket)
		
		// Remove Entity
		remove_entity(iRocket)
	}
}

public do_reload_animation(id)
{
	// Validation check
	if(!g_bIsAlive[id] || g_iCurrentWeapon[id] != CSW_KNIFE || !zp_get_user_nemesis(id) || !g_bHasNRL[id])
		return
		
	// User is holding this gun
	if(g_bHoldingNRL[id])
	{
		// Play reload animation
		set_user_weaponanim(id, nrl_model_seq_reload)
	}
}

/*================================================================================
 [Main Events/Messages]
=================================================================================*/

public event_CurWeapon(id)
{	
	// Not alive...
	if(!g_bIsAlive[id])
		return PLUGIN_CONTINUE
		
	// Updating weapon array
	g_iCurrentWeapon[id] = read_data(2)
	
	// Not nemesis
	if(!zp_get_user_nemesis(id))
		return PLUGIN_CONTINUE
		
	// Doesn't have a NRL
	if(!g_bHasNRL[id])
		return PLUGIN_CONTINUE;
		
	// Weaponid is Knife
	if(g_iCurrentWeapon[id] == CSW_KNIFE)
	{
		// User is holding a Rocket Launcher
		if(g_bHoldingNRL[id])
		{
			entity_set_string(id, EV_SZ_viewmodel, nrl_gun_viewmodel)
			entity_set_string(id, EV_SZ_weaponmodel, nrl_gun_weaponmodel)
		}
	}
		
	return PLUGIN_CONTINUE
}

public event_RoundStart()
{
	// Remove all the rockets in the map (if exists anyone)
	remove_rockets_in_map()
	
	// Cache Cvars
	cache_cvars()
	
	// Update var
	g_bRoundEnding = false
}

public message_DeathMsg(msg_id, msg_dest, id)
{
	// Some vars
	static iAttacker, iVictim
	
	// Get attacker and victim
	iAttacker = get_msg_arg_int(1)
	iVictim = get_msg_arg_int(2)
	
	// Non-player attacker or self kill
	if(!is_user_connected(iAttacker) || iAttacker == iVictim)
		return PLUGIN_CONTINUE
		
	// Killed by an nrl_rocket
	if(g_bKilledByRocket[iVictim])
	{	
		// Change "world" with "nrl_rocket"
		set_msg_arg_string(4, "nrl_rocket")
	}
		
	return PLUGIN_CONTINUE
}

/*================================================================================
 [Main Forwards]
=================================================================================*/

public client_putinserver(id) 
{
	// Reset Vars
	set_user_nrlauncher(id, 0)
	
	// User is connected
	g_bIsConnected[id] = true
}
	
public client_disconnect(id) 
{
	// Reset Vars
	set_user_nrlauncher(id, 0)
	
	// Disconnected user is not alive and is not connected
	g_bIsAlive[id] = false
	g_bIsConnected[id] = false
}
	
public fw_CmdStart(id, handle, seed)
{
	// Valid alive, or isn't nemesis?
	if(!is_user_valid_alive(id) || !zp_get_user_nemesis(id))
		return FMRES_IGNORED;
		
	// Current weapon isn't knife?
	if(g_iCurrentWeapon[id] != CSW_KNIFE)
		return FMRES_IGNORED
		
	// Has this gun?
	if(!g_bHasNRL[id])
		return FMRES_IGNORED
		
	// Get buttons and game time
	static iButton, Float:flCurrentTime
	iButton = get_uc(handle, UC_Buttons)
	flCurrentTime = halflife_time()
	
	// User pressing +attack Button
	if(iButton & IN_ATTACK)
	{
		// Isn't holding NRL, or round is ending
		if(!g_bHoldingNRL[id] || g_bRoundEnding)
			return FMRES_IGNORED
		
		// Reset buttons
		iButton &= ~IN_ATTACK
		set_uc(handle, UC_Buttons, iButton)
		
		// Launch rate not over yet
		if(flCurrentTime > g_flNextLaunchTime[id])
		{	
			// Get launch rate float amount
			new Float:flLaunchRate = get_pcvar_float(cvar_launchrate)
			
			// Set next launch time
			g_flNextLaunchTime[id] = flCurrentTime + flLaunchRate
			
			// User have Rockets
			if(g_iRocketAmount[id] > 0)
			{
				// Launch a Rocket
				launch_nrl_rocket(id)
				g_iRocketAmount[id]--
				
				// Rocket launch push effect
				launch_push(id, get_pcvar_num(cvar_launchpush))
				
				// Get the aproximately idle time
				new Float:flAnimReloadTime = 1.5
				
				// Reload animation it's enabled and has rockets?
				if(nrl_model_seq_reload > -1 && g_iRocketAmount[id])
				{
					// Add the aproximately reload anim time
					flAnimReloadTime += nrl_reload_seq_time
					
					// Do reload animation in 1.5 seconds
					set_task(1.5, "do_reload_animation", id)
					
					// Launch rate can bug the reload animation
					if(flAnimReloadTime > flLaunchRate)
					{
						// Modify his next launch rate time
						g_flNextLaunchTime[id] = flCurrentTime + flAnimReloadTime
					}
				}
				
				// Call idle animation
				set_pdata_float(get_pdata_cbase(id, m_pActiveItem, 5), m_flTimeWeaponIdle, flAnimReloadTime, 4)
			}
			else
			{
				// Message
				_CenterMsgFix_PrintMsg(id, print_center, "No tienes Misiles");
				
				// Emit Sound
				emit_sound(id, CHAN_VOICE, nrl_norockets_sound[random_num(0, sizeof nrl_norockets_sound - 1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			}
		}
		
	}
	// User pressing +attack2 Button
	else if(iButton & IN_ATTACK2)
	{
		// Reset buttons
		iButton &= ~IN_ATTACK2
		set_uc(handle, UC_Buttons, iButton)
		
		// Deploy rate not over yet
		if(flCurrentTime > g_flNextDeployTime[id])
		{
			// To Knife / Rocket Launcher
			change_melee(id, g_bHoldingNRL[id])
			
			// Set next deploy time
			g_flNextDeployTime[id] = flCurrentTime + 1.0
		}
	}
	
	return FMRES_IGNORED;
}

public fw_RocketTouch(rocket, toucher)
{	
	// Valid entity
	if(is_valid_ent(rocket))
	{
		// Some vars
		static iVictim, iKills, iAttacker
		static Float:flDamage, Float:flMaxDamage, Float:flDistance, Float:flFadeAlpha, Float:flRadius, Float:flVictimHealth
		static Float:flEntityOrigin[3]
	
		// Radius
		flRadius = get_pcvar_float(cvar_explo_radius)
			
		// Max Damage
		flMaxDamage = get_pcvar_float(cvar_explo_damage)
		
		// Get entity origin
		entity_get_vector(rocket, EV_VEC_origin, flEntityOrigin)
		
		// Get attacker
		iAttacker = entity_get_edict(rocket, EV_ENT_owner)
	
		// Create Blast
		rocket_blast(rocket, flEntityOrigin)
	
		// Prepare vars
		iKills = 0
		iVictim = -1
		
		// Toucher entity is valid and isn't worldspawn?
		if((toucher > 0) && is_valid_ent(toucher))
		{
			// Get toucher classname
			static szTchClass[33]
			entity_get_string(toucher, EV_SZ_classname, szTchClass, charsmax(szTchClass))
	
			// Is a breakable entity?
			if(equal(szTchClass, "func_breakable"))
			{
				// Destroy entity
				force_use(rocket, toucher)
			}
		
			// Player entity
			else if(equal(szTchClass, "player") && is_user_valid_alive(toucher))
			{
				// An human, and not with Godmode
				if(!zp_get_user_zombie(toucher) && !zp_get_user_survivor(toucher) && entity_get_float(toucher, EV_FL_takedamage) != DAMAGE_NO)
				{
					// Victim have been killed by a nrl_rocket
					g_bKilledByRocket[toucher] = true
						
					// Instantly kill
					iKills++
					ExecuteHamB(Ham_Killed, toucher, iAttacker, 2)
					
					// We don't need this again
					g_bKilledByRocket[toucher] = false
				}
			}
		}
		
		// Process explosion
		while((iVictim = find_ent_in_sphere(iVictim, flEntityOrigin, flRadius)) != 0)
		{
			// Non-player entity
			if(!is_user_valid_connected(iVictim))
				continue;
				
			// Alive, zombie or with Godmode
			if(!g_bIsAlive[iVictim] || (zp_get_user_zombie(iVictim) && iVictim != iAttacker) || entity_get_float(iVictim, EV_FL_takedamage) == DAMAGE_NO)
				continue;
			
			// Get distance between Entity and Victim
			flDistance = entity_range(rocket, iVictim)
	
			// Process damage and Screenfade Alpha
			flDamage = floatradius(flMaxDamage, flRadius, flDistance)
			flFadeAlpha = floatradius(255.0, flRadius, flDistance)
			flVictimHealth = entity_get_float(iVictim, EV_FL_health)
			
			// Damage is more than 0
			if(flDamage > 0) 
			{
				// Be killed, or be damaged
				if(flVictimHealth <= flDamage) 
				{
					// Victim have been killed by a nrl_rocket
					g_bKilledByRocket[iVictim] = true
					
					// Instantly kill
					iKills++
					ExecuteHamB(Ham_Killed, iVictim, iAttacker, 2)
					
					// We don't need this again
					g_bKilledByRocket[iVictim] = false
				}	
				else
				{
					// Make damage (not using HamB)
					ExecuteHam(Ham_TakeDamage, iVictim, rocket, iAttacker, flDamage, DMG_BLAST)
					
					// Screenfade
					if(get_pcvar_num(cvar_damage_fade))
					{
						message_begin(MSG_ONE_UNRELIABLE, g_msgScreenFade, _, iVictim)
						write_short(UNIT_SECOND*1) // duration
						write_short(UNIT_SECOND*1) // hold time
						write_short(FFADE_IN) // fade type
						write_byte(200) // r
						write_byte(0) // g
						write_byte(0) // b
						write_byte(floatround(flFadeAlpha)) // alpha
						message_end()
					}
					
					// Screenshake
					if(get_pcvar_num(cvar_damage_shake))
					{
						message_begin(MSG_ONE_UNRELIABLE, g_msgScreenShake, _, iVictim)
						write_short(UNIT_SECOND*3) // amplitude
						write_short(UNIT_SECOND*1) // duration
						write_short(UNIT_SECOND*3) // frequency
						message_end() 
					}
				}
			}
		}
	
		// Valid connected, alive, more than 1 kill, and is nemesis.
		if(is_user_valid_connected(iAttacker) && g_bIsAlive[iAttacker] && iKills != 0 && zp_get_user_nemesis(iAttacker))
		{
			// Check Cvar
			if(get_pcvar_num(cvar_bonushp))
			{
				// Get health value
				static iMultValue
				iMultValue = iKills * get_pcvar_num(cvar_bonushp)
				
				// Give Health
				entity_set_float(iAttacker, EV_FL_health, entity_get_float(iAttacker, EV_FL_health) + iMultValue)
				
				// Get attacker Origin
				static iOrigin[3]
				get_user_origin(iAttacker, iOrigin)
				
				// Tracers
				message_begin(MSG_PVS, SVC_TEMPENTITY, iOrigin)
				write_byte(TE_IMPLOSION) // TE id
				write_coord(iOrigin[0]) // x
				write_coord(iOrigin[1])  // y
				write_coord(iOrigin[2])  // z
				write_byte(iKills * 100) // radius
				write_byte(iMultValue) // count
				write_byte(5) // duration
				message_end()
				
				// Message
				_CenterMsgFix_PrintMsg(iAttacker, print_center, "Muertos: %d, Vida Extra: %d", iKills, iMultValue)
			}		
		}
			
		// Remove rocket flare
		remove_rocket_flare(rocket)
		
		// Remove rocket
		remove_entity(rocket)
	}
}

public client_PreThink(id)
{
	// Appear Status Text with rocket num
	if(g_bIsAlive[id] && zp_get_user_nemesis(id) && g_bHasNRL[id] && g_bHoldingNRL[id])
		status_text(id)
}

public fw_PlayerKilled(victim, attacker, shouldgib)
{
	// Victim is not alive
	g_bIsAlive[victim] = false
	
	// Victim has holding the Rocket Launcher
	if(g_bHasNRL[victim]) 
	{
		// Only remove
		status_text(victim)
		
		// Reset Vars
		set_user_nrlauncher(victim, 0)
	}
}

public fw_Knife_Deploy_Post(knife)
{
	// Get Owner...
	static iPlayer 
	iPlayer = get_pdata_cbase(knife, m_pPlayer, 4)
	
	// Has our nrl
	if(is_user_valid_alive(iPlayer) && zp_get_user_nemesis(iPlayer) && g_bHoldingNRL[iPlayer])
	{
		// Send draw animation
		set_user_weaponanim(iPlayer, nrl_model_seq_draw)
		
		// Next launch time
		g_flNextLaunchTime[iPlayer] = halflife_time() + 1.5
		
		return HAM_HANDLED
	}
	
	return HAM_IGNORED
}

public fw_Knife_PrimaryAttack(knife)
{
	// Get Owner...
	static iPlayer 
	iPlayer = get_pdata_cbase(knife, m_pPlayer, 4)
	
	// Block knife Slash when user is holding the Rocket Launcher
	if(is_user_valid_alive(iPlayer) && zp_get_user_nemesis(iPlayer) && g_bHoldingNRL[iPlayer])
		return HAM_SUPERCEDE;
		
	return HAM_IGNORED
}

public fw_Knife_SecondaryAttack(knife)
{
	// Get Owner...
	static iPlayer 
	iPlayer = get_pdata_cbase(knife, m_pPlayer, 4)
	
	// Block secondary attack
	if(is_user_valid_alive(iPlayer) && zp_get_user_nemesis(iPlayer) && g_bHasNRL[iPlayer])
		return HAM_SUPERCEDE
		
	return HAM_IGNORED
}

public fw_PlayerSpawn_Post(id)
{
	// Not alive...
	if(!is_user_alive(id))
		return HAM_IGNORED
		
	// Player is alive
	g_bIsAlive[id] = true
	
	// Remove Rocket Launcher when user is spawned
	if(g_bHasNRL[id])
	{
		// Remove center text
		status_text(id)
		
		// Reset Vars
		set_user_nrlauncher(id, 0)
		
		// Attempt model to reset
		reset_user_knife(id)
	}
	
	return HAM_IGNORED
}

/*================================================================================
 [Internal Functions]
=================================================================================*/

get_nrl_defrockets(id)
{
	return g_bCvar_AdminFeatures ? (get_user_flags(id) & ACCESS_FLAG ? g_iCvar_DefaultRockets[iAdmins] : g_iCvar_DefaultRockets[iPlayers]) : g_iCvar_DefaultRockets[iPlayers]
}


launch_nrl_rocket(id)
{
	// Fire Effect
	entity_set_vector(id, EV_VEC_punchangle, Float:{ -10.5, 0.0, 0.0 })
	set_user_weaponanim(id, nrl_model_seq_fire) 
	
	// Some vars
	static Float:flOrigin[3], Float:flAngles[3], Float:flVelocity[3]
	
	// Get position from eyes (agreeing to rocket launcher model)
	get_user_eye_position(id, flOrigin)
	
	// Get View Angles
	entity_get_vector(id, EV_VEC_v_angle, flAngles)
	
	// Create the Entity
	new iEnt = create_entity("info_target")
	
	// Set Entity Classname
	entity_set_string(iEnt, EV_SZ_classname, "nrl_rocket")
	
	// Set Rocket Model
	entity_set_model(iEnt, nrl_rocketmodel)
	
	// Set Entity Size
	set_size(iEnt, nrl_rocket_mins, nrl_rocket_maxs)
	entity_set_vector(iEnt, EV_VEC_mins, nrl_rocket_mins)
	entity_set_vector(iEnt, EV_VEC_maxs, nrl_rocket_maxs)
	
	// Set Entity Origin
	entity_set_origin(iEnt, flOrigin)
	
	// Set Entity Angles (thanks to Arkshine)
	make_vector(flAngles)
	entity_set_vector(iEnt, EV_VEC_angles, flAngles)
	
	// Make a Solid Entity
	entity_set_int(iEnt, EV_INT_solid, SOLID_BBOX)
	
	// Set a Movetype
	entity_set_int(iEnt, EV_INT_movetype, get_pcvar_num(cvar_rocket_grav) ? MOVETYPE_TOSS : MOVETYPE_FLY)
	
	// Gravity
	entity_set_float(iEnt, EV_FL_gravity, 0.1) // Gravity works only if entity movetype is MOVETYPE_TOSS (and anothers)
	
	// Set Entity Owner (Launcher)
	entity_set_edict(iEnt, EV_ENT_owner, id)
	
	// Emit Launch Sound
	emit_sound(iEnt, CHAN_VOICE, nrl_rocketfly_sound[random_num(0, sizeof nrl_rocketfly_sound - 1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	emit_sound(iEnt, CHAN_WEAPON, nrl_rocketlaunch_sound[random_num(0, sizeof nrl_rocketlaunch_sound - 1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	// Get velocity result
	static iVelocityResult
	iVelocityResult = clamp(get_pcvar_num(cvar_rocket_vel), 50, get_pcvar_num(cvar_svvel))
	
	// Set Entity Velocity
	velocity_by_aim(id, iVelocityResult, flVelocity)
	entity_set_vector(iEnt, EV_VEC_velocity, flVelocity)
	
	// Glow
	if(get_pcvar_num(cvar_rocket_glow))
		set_rendering(iEnt, kRenderFxGlowShell, nrl_glow_colors[0], nrl_glow_colors[1], nrl_glow_colors[2], kRenderNormal, 50)
		
	// Flare
	if(get_pcvar_num(cvar_rocket_flare))
		entity_set_edict(iEnt, EV_ENT_FLARE, create_flare(iEnt, nrl_flare_colors))
	
	// Dynamic Light
	if(get_pcvar_num(cvar_rocket_dlight))
		entity_set_int(iEnt, EV_INT_effects, entity_get_int(iEnt, EV_INT_effects) | EF_BRIGHTLIGHT)	
		
	// Trail
	if(get_pcvar_num(cvar_rocket_trail))
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW) // TE id
		write_short(iEnt) // entity:attachment to follow
		write_short(g_sprTrail) // sprite index
		write_byte(30) // life in 0.1's
		write_byte(3) // line width in 0.1's
		write_byte(nrl_trail_colors[0]) // r
		write_byte(nrl_trail_colors[1]) // g
		write_byte(nrl_trail_colors[2]) // b
		write_byte(200) // brightness
		message_end()
	}
}

change_melee(id, bool:to_knife)
{
	// Update var
	g_bHoldingNRL[id] = !to_knife
	
	// Reset the User's knife (attempt model to reset)
	reset_user_knife(id)
	
	// Reset Status Text
	status_text(id)
	
	// Message
	_CenterMsgFix_PrintMsg(id, print_center, "%s", to_knife ? "Cambiado al Cuchillo" : "Cambiado al Lanza Misiles")
	
	// Sound
	emit_sound(id, CHAN_VOICE, nrl_deploy_sound[random_num(0, sizeof nrl_deploy_sound - 1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

create_flare(rocket, iRGB[3]) // Thanks to hlstriker for the code!
{
	// Entity
	new iEnt = create_entity("env_sprite")
	
	// Is a valid Entity
	if(!is_valid_ent(iEnt))
		return 0
		
	// Set Model
	entity_set_model(iEnt, "sprites/animglow01.spr")
	
	// Set Classname
	entity_set_string(iEnt, EV_SZ_classname, "nrl_rocket_flare")
	
	// Sprite Scale (size)
	entity_set_float(iEnt, EV_FL_scale, 0.7)
		
	// Entity Spawn Flags
	entity_set_int(iEnt, EV_INT_spawnflags, SF_SPRITE_STARTON)
	
	// Solid style
	entity_set_int(iEnt, EV_INT_solid, SOLID_NOT)
	
	// Entity Movetype
	entity_set_int(iEnt, EV_INT_movetype, MOVETYPE_FOLLOW)
	
	// Entity aiment
	entity_set_edict(iEnt, EV_ENT_aiment, rocket)
	
	// His owner
	entity_set_edict(iEnt, EV_ENT_owner, rocket)
	
	// Animation frame rate
	entity_set_float(iEnt, EV_FL_framerate, 25.0)
	
	// Color
	set_rendering(iEnt, kRenderFxNone, iRGB[0], iRGB[1], iRGB[2], kRenderTransAdd, 255)
	
	// Now the entity need to be spawned
	DispatchSpawn(iEnt)

	return iEnt
}

rocket_blast(entity, Float:flOrigin[3])
{
	// Explosion
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, flOrigin, 0)
	write_byte(TE_EXPLOSION) // TE id
	engfunc(EngFunc_WriteCoord, flOrigin[0]) // x
	engfunc(EngFunc_WriteCoord, flOrigin[1]) // y
	engfunc(EngFunc_WriteCoord, flOrigin[2]) // z
	write_short(g_sprExplosion)	// sprite index
	write_byte(120)	// scale in 0.1's	
	write_byte(10)	// framerate	
	write_byte(TE_EXPLFLAG_NOSOUND|TE_EXPLFLAG_NODLIGHTS) // flags
	message_end() 
	
	// Stop rocket fly sound with new explosion sound
	emit_sound(entity, CHAN_WEAPON, nrl_explosion_sound[random_num(0, sizeof nrl_explosion_sound - 1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	emit_sound(entity, CHAN_VOICE, nrl_explosion_sound[random_num(0, sizeof nrl_explosion_sound - 1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	// World Decal
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, flOrigin, 0)
	write_byte(TE_WORLDDECAL) // TE id
	engfunc(EngFunc_WriteCoord, flOrigin[0]) // x
	engfunc(EngFunc_WriteCoord, flOrigin[1]) // y
	engfunc(EngFunc_WriteCoord, flOrigin[2]) // z
	write_byte(random_num(46, 48)) // texture index of precached decal texture name
	message_end() 

	// Rings
	if(get_pcvar_num(cvar_explo_rings))
	{
		static j
		for(j = 0; j < 3; j++)
		{
			engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, flOrigin, 0)
			write_byte(TE_BEAMCYLINDER) // TE id
			engfunc(EngFunc_WriteCoord, flOrigin[0]) // x
			engfunc(EngFunc_WriteCoord, flOrigin[1]) // y
			engfunc(EngFunc_WriteCoord, flOrigin[2]) // z
			engfunc(EngFunc_WriteCoord, flOrigin[0]) // x axis
			engfunc(EngFunc_WriteCoord, flOrigin[1]) // y axis
			engfunc(EngFunc_WriteCoord, flOrigin[2] + g_flRingZAxis_Add[j]) // z axis
			write_short(g_sprRing) // sprite
			write_byte(0) // startframe
			write_byte(0) // framerate
			write_byte(4) // life
			write_byte(60) // width
			write_byte(0) // noise
			write_byte(nrl_ring_colors[0]) // red
			write_byte(nrl_ring_colors[1]) // green
			write_byte(nrl_ring_colors[2]) // blue
			write_byte(200) // brightness
			write_byte(0) // speed
			message_end()
		}
	}
	
	// Colored Dynamic Light
	if(get_pcvar_num(cvar_explo_dlight))
	{
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, flOrigin, 0)
		write_byte(TE_DLIGHT) // TE id
		engfunc(EngFunc_WriteCoord, flOrigin[0]) // x
		engfunc(EngFunc_WriteCoord, flOrigin[1]) // y
		engfunc(EngFunc_WriteCoord, flOrigin[2]) // z
		write_byte(50) // radius
		write_byte(nrl_dlight_colors[0]) // red
		write_byte(nrl_dlight_colors[1]) // green
		write_byte(nrl_dlight_colors[2]) // blue
		write_byte(10) // life
		write_byte(45) // decay rate
		message_end()
	}
}

remove_rocket_flare(iRocket)
{
	new iFlare = entity_get_edict(iRocket, EV_ENT_FLARE)
		
	if(is_valid_ent(iFlare)) 
		remove_entity(iFlare)
		
	return FMRES_HANDLED
}

/*================================================================================
 [Stocks]
=================================================================================*/

stock get_user_eye_position(id, Float:flOrigin[3])
{
	static Float:flViewOffs[3]
	entity_get_vector(id, EV_VEC_view_ofs, flViewOffs)
	entity_get_vector(id, EV_VEC_origin, flOrigin)
	xs_vec_add(flOrigin, flViewOffs, flOrigin)
}

stock make_vector(Float:flVec[3])
{
	flVec[0] -= 30.0
	engfunc(EngFunc_MakeVectors, flVec)
	flVec[0] = -(flVec[0] + 30.0)
}

stock set_user_weaponanim(id, iAnim)
{
	entity_set_int(id, EV_INT_weaponanim, iAnim)
	message_begin(MSG_ONE, SVC_WEAPONANIM, _, id)
	write_byte(iAnim)
	write_byte(entity_get_int(id, EV_INT_body))
	message_end()
}

stock set_user_nrlauncher(id, active)
{
	if(!active)
	{
		g_bHasNRL[id] = false
		g_bHoldingNRL[id] = false
		g_iRocketAmount[id] = 0
	}
	else
	{
		g_bHasNRL[id] = true
		g_bHoldingNRL[id] = false
		g_iRocketAmount[id] = get_nrl_defrockets(id)
		
		message_begin(MSG_ONE_UNRELIABLE, g_msgAmmoPickup, _, id)
		write_byte(AMMOID_HEGRENADE) // ammo id
		write_byte(g_iRocketAmount[id]) // ammo amount
		message_end()
		
		emit_sound(id, CHAN_ITEM, "items/gunpickup2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
}

stock launch_push(id, velamount)
{
	static Float:flNewVelocity[3], Float:flCurrentVelocity[3]
	
	velocity_by_aim(id, -velamount, flNewVelocity)
	
	get_user_velocity(id, flCurrentVelocity)
	xs_vec_add(flNewVelocity, flCurrentVelocity, flNewVelocity)
	
	set_user_velocity(id, flNewVelocity)	
}



stock Float:floatradius(Float:flMaxAmount, Float:flRadius, Float:flDistance)
{
	return floatsub(flMaxAmount, floatmul(floatdiv(flMaxAmount, flRadius), flDistance))
}
public _CenterMsgFix_PrintMsg(pPlayer, iMsgType, const szMessage[], any:...) 
{
    new pPlayers[MAX_PLAYERS], iPlCount, msg[191]

    if(pPlayer) 
    {
        iPlCount = 1
        pPlayers[0] = pPlayer
    }
    else
        get_players_ex(pPlayers, iPlCount, GetPlayers_ExcludeBots|GetPlayers_ExcludeHLTV)
    

    for(new i; i < iPlCount; i++) 
    {
        pPlayer = pPlayers[i]
        SetGlobalTransTarget(pPlayer)
        vformat(msg, charsmax(msg), szMessage, 4)

        message_begin(MSG_ONE_UNRELIABLE, g_msgTextMsg, .player = pPlayer)
        write_byte(iMsgType)
        write_string(msg)
        message_end()
    }
}