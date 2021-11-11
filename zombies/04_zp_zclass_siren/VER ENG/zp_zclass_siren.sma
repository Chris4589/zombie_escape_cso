/*================================================================================

	[ZP] Zombie Class: KF Siren Zombie
	Copyright (C) 2010 by meTaLiCroSS, Viña del Mar, Chile
	
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.
	
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
	
	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
	
	In addition, as a special exception, the author gives permission to
	link the code of this program with the Half-Life Game Engine ("HL
	Engine") and Modified Game Libraries ("MODs") developed by Valve,
	L.L.C ("Valve"). You must obey the GNU General Public License in all
	respects for all of the code used other than the HL Engine and MODs
	from Valve. If you modify this file, you may extend this exception
	to your version of the file, but you are not obligated to do so. If
	you do not wish to do so, delete this exception statement from your
	version.

=================================================================================*/

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fun>
#include <xs>
#include <hamsandwich>
#include <zombieplague>

/*================================================================================
 [Customizations]
=================================================================================*/

// Zombie Attributes
new const zclass_name[] = "Siren Zombie" // name
new const zclass_info[] = "Scream Ability" // description
new const zclass_model[] = "kf_siren" // model
new const zclass_clawmodel[] = "v_siren_fakeclaws.mdl" // claw model
new const zclass_ring_sprite[] = "sprites/shockwave.spr" // ring sprite
new const zclass_screamsounds[][] = { "killing_floor/siren_scream.wav" } // scream sound

// Scream ring color		R	G	B
new zclass_ring_colors[3] = {	255,	0,	0	}

const zclass_health = 8000 // health
const zclass_speed = 300 // speed

const Float:zclass_gravity = 0.5 // gravity
const Float:zclass_knockback = 3.0

/*================================================================================
 Customization ends here! Yes, that's it. Editing anything beyond
 here is not officially supported. Proceed at your own risk...
=================================================================================*/

// Variables
new g_iSirenZID, g_iMaxPlayers, g_msgSayText, g_msgScreenFade, g_msgScreenShake,
g_msgBarTime, g_sprRing

// Arrays
new g_iPlayerTaskTimes[33]

// Cvar pointers
new cvar_screammode, cvar_duration, cvar_screamdmg, cvar_startime, cvar_reloadtime,
cvar_radius, cvar_damagemode, cvar_slowdown

// Cached cvars
new g_iCvar_ScreamMode, g_iCvar_ScreamDuration, g_iCvar_ScreamDmg, 
g_iCvar_ScreamStartTime, Float:g_flCvar_ReloadTime, Float:g_flCvar_Radius,
g_iCvar_DamageMode, Float:g_flCvar_ScreamSlowdown

// Bools
new bool:g_bIsConnected[33], bool:g_bIsAlive[33], bool:g_bInScreamProcess[33], 
bool:g_bCanDoScreams[33], bool:g_bKilledByScream[33], bool:g_bDoingScream[33], 
bool:g_bRoundEnding

// Some constants
const FFADE_IN = 		0x0000

const UNIT_SECOND = 		(1<<12)
const TASK_SCREAM =		37729
const TASK_RELOAD =		55598
const TASK_SCREAMDMG =		48289
const NADE_TYPE_INFECTION = 	1111

// Plug info.
#define PLUG_VERSION "0.2"
#define PLUG_AUTH "meTaLiCroSS"

// Macros
#define zp_get_grenade_type(%1)		(entity_get_int(%1, EV_INT_flTimeStepSound))
#define is_user_valid_alive(%1) 	(1 <= %1 <= g_iMaxPlayers && g_bIsAlive[%1])
#define is_user_valid_connected(%1) 	(1 <= %1 <= g_iMaxPlayers && g_bIsConnected[%1])

/*================================================================================
 [Init, CFG and Precache]
=================================================================================*/
new g_itemid;
new g_bSiren[33];
public plugin_init()
{
	// Plugin Info
	register_plugin("[ZP] Zombie Class: KF Siren Zombie", PLUG_VERSION, PLUG_AUTH)
		
	// Main events
	register_event("HLTV", "event_RoundStart", "a", "1=0", "2=0")
	
	// Main messages
	register_message(get_user_msgid("DeathMsg"), "message_DeathMsg")
	
	// Fakemeta Forwards
	register_forward(FM_CmdStart, "fw_CmdStart")
	
	// Hamsandwich Forward
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
	
	// Cvars
	cvar_screammode = register_cvar("zp_siren_mode", "0")
	cvar_duration = register_cvar("zp_siren_scream_duration", "3")
	cvar_screamdmg = register_cvar("zp_siren_scream_damage", "1")
	cvar_startime = register_cvar("zp_siren_scream_start_time", "1")
	cvar_reloadtime = register_cvar("zp_siren_scream_reload_time", "30.0")
	cvar_radius = register_cvar("zp_siren_scream_radius", "250.0")
	cvar_damagemode = register_cvar("zp_siren_damage_mode", "0")
	cvar_slowdown = register_cvar("zp_siren_damage_slowdown", "0.5")
	
	static szCvar[30]
	formatex(szCvar, charsmax(szCvar), "v%s by %s", PLUG_VERSION, PLUG_AUTH)
	register_cvar("zp_zclass_siren", szCvar, FCVAR_SERVER|FCVAR_SPONLY) 
	
	// Vars
	g_iMaxPlayers = get_maxplayers()
	g_msgBarTime = get_user_msgid("BarTime")
	g_msgSayText = get_user_msgid("SayText")
	g_msgScreenFade = get_user_msgid("ScreenFade")
	g_msgScreenShake = get_user_msgid("ScreenShake")

	g_itemid = zp_register_extra_item("Anti Siren", 150, 0, ZP_TEAM_HUMAN);
}

public plugin_cfg()
{
	// Cache some cvars
	cache_cvars()
}
public zp_extra_item_selected(player, itemid)
{
    if ( itemid == g_itemid )
    {
        g_bSiren[player] = true;
    }
}
public plugin_precache()
{
	// Register the new class and store ID for reference
	g_iSirenZID = zp_register_class( CLASS_ZOMBIE, zclass_name, zclass_info, zclass_model, zclass_clawmodel, 
		26, 0, ADMIN_ALL, zclass_health, 0, zclass_speed, zclass_gravity, zclass_knockback)	
	// Ring sprite
	g_sprRing = precache_model(zclass_ring_sprite)
	
	// Sounds
	static i
	for(i = 0; i < sizeof zclass_screamsounds; i++)
		precache_sound(zclass_screamsounds[i])
}

/*================================================================================
 [Main Events/Messages]
=================================================================================*/

public event_RoundStart()
{
	// Caching cvars
	cache_cvars()
	
	// Reset round end bar
	g_bRoundEnding = false
	for(new i = 1; i <=g_iMaxPlayers; ++i)
		g_bSiren[i] = false;
}

public message_DeathMsg(msg_id, msg_dest, id)
{
	static iAttacker, iVictim
	
	// Get attacker and victim
	iAttacker = get_msg_arg_int(1)
	iVictim = get_msg_arg_int(2)
	
	// Non-player attacker or self kill
	if(!is_user_connected(iAttacker) || iAttacker == iVictim)
		return PLUGIN_CONTINUE

	g_bSiren[iVictim] = false;
		
	// Killed by siren scream
	if(g_bKilledByScream[iVictim])
		set_msg_arg_string(4, "siren scream")
		
	return PLUGIN_CONTINUE
}

/*================================================================================
 [Main Forwards]
=================================================================================*/

public client_putinserver(id)
{
	// Updating bool
	g_bIsConnected[id] = true
}

public client_disconnect(id)
{
	// Updating bool
	g_bIsAlive[id] = false
	g_bIsConnected[id] = false
}

public fw_PlayerSpawn_Post(id)
{
	// Not alive...
	if(!is_user_alive(id))
		return HAM_IGNORED
		
	// Player is alive
	g_bIsAlive[id] = true
	
	// Reset player vars and tasks
	stop_scream_task(id)
	
	g_bCanDoScreams[id] = false
	g_bDoingScream[id] = false
	g_iPlayerTaskTimes[id] = 0
	
	remove_task(id+TASK_RELOAD)
	remove_task(id+TASK_SCREAMDMG)
	
	return HAM_IGNORED
}

public fw_PlayerKilled(victim, attacker, shouldgib)
{
	// Player victim
	if(is_user_valid_connected(victim))
	{
		// Victim is not alive
		g_bIsAlive[victim] = false
		
		// Reset player vars and tasks
		stop_scream_task(victim)
		
		g_bCanDoScreams[victim] = false
		g_bDoingScream[victim] = false
		g_iPlayerTaskTimes[victim] = 0
		
		remove_task(victim+TASK_RELOAD)
		remove_task(victim+TASK_SCREAMDMG)
		
		return HAM_HANDLED
	}
	
	return HAM_IGNORED
}

public fw_CmdStart(id, handle, random_seed)
{
	// Not alive
	if(!is_user_alive(id))
		return FMRES_IGNORED;
	
	// Isn't a zombie?
	if(!zp_get_user_zombie(id) || zp_get_class(id) >= NEMESIS)
		return FMRES_IGNORED;
		
	// Invalid class id
	if(zp_get_user_zombie_class(id) != g_iSirenZID)
		return FMRES_IGNORED;
		
	// Get user old and actual buttons
	static iInUseButton, iInUseOldButton
	iInUseButton = (get_uc(handle, UC_Buttons) & IN_USE)
	iInUseOldButton = (get_user_oldbutton(id) & IN_USE)
	
	// Pressing +use button
	if(iInUseButton)
	{
		// Last used button isn't +use, i need to
		// do this, because i call this "only" 1 time
		if(!iInUseOldButton && g_bCanDoScreams[id] && !g_bDoingScream[id] && !g_bRoundEnding)
		{
			// A bar appears in his screen
			message_begin(MSG_ONE, g_msgBarTime, _, id)
			write_byte(g_iCvar_ScreamStartTime) // time
			write_byte(0) // unknown
			message_end()
			
			// Update bool
			g_bInScreamProcess[id] = true
			
			// Next scream time
			set_task(g_iCvar_ScreamStartTime + 0.2, "task_do_scream", id+TASK_SCREAM)
			
			return FMRES_HANDLED
		}
	}
	else
	{
		// Last used button it's +use
		if(iInUseOldButton && g_bInScreamProcess[id])
		{
			// Stop scream main task
			stop_scream_task(id)
			
			return FMRES_HANDLED
		}
	}
	
	return FMRES_IGNORED
}

/*================================================================================
 [Tasks]
=================================================================================*/

public task_do_scream(id)
{
	// Normalize task
	id -= TASK_SCREAM
	
	// Do scream sound
	emit_sound(id, CHAN_STREAM, zclass_screamsounds[random_num(0, sizeof zclass_screamsounds - 1)], 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	// Block screams
	g_bCanDoScreams[id] = false
	
	// Reload task
	set_task(g_flCvar_ReloadTime, "task_reload_scream", id+TASK_RELOAD)
	
	// Now it's doing an scream
	g_bDoingScream[id] = true
	
	// Get his origin coords
	static iOrigin[3]
	get_user_origin(id, iOrigin)
	
	// Do a good effect, life the original Killing Floor.
	message_begin(MSG_PVS, SVC_TEMPENTITY, iOrigin) 
	write_byte(TE_LAVASPLASH)
	write_coord(iOrigin[0]) 
	write_coord(iOrigin[1]) 
	write_coord(iOrigin[2]) 
	message_end()
	
	// Scream damage task
	set_task(0.1, "task_scream_process", id+TASK_SCREAMDMG, _, _, "b")
}

public task_reload_scream(id)
{
	// Normalize taks
	id -= TASK_RELOAD
	
	// Can do screams again
	g_bCanDoScreams[id] = true
	
	// Message
	client_printcolor(id, "/g[ZP]/y Ready, you can do /gScreams/y again")
	client_printcolor(id, "/g[ZP]/y Remember, press the /g^"+use^"/y Button to do an /gScreams/y")
}

public task_scream_process(id)
{
	// Normalize task
	id -= TASK_SCREAMDMG
	
	// Time exceed
	if(g_iPlayerTaskTimes[id] >= (g_iCvar_ScreamDuration*10) || g_bRoundEnding)
	{
		// Remove player task
		remove_task(id+TASK_SCREAMDMG)
		
		// Reset task times count
		g_iPlayerTaskTimes[id] = 0
		
		// Update bool
		g_bDoingScream[id] = false
		
		return;
	}
	
	// Update player task time
	g_iPlayerTaskTimes[id]++
	
	// Get player origin
	static Float:flOrigin[3]
	entity_get_vector(id, EV_VEC_origin, flOrigin)
	
	// Collisions
	static iVictim
	iVictim = -1
	
	// Vector var
	static Float:flVictimOrigin[3]
	
	// A ring effect
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, flOrigin, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, flOrigin[0]) // x
	engfunc(EngFunc_WriteCoord, flOrigin[1]) // y
	engfunc(EngFunc_WriteCoord, flOrigin[2]) // z
	engfunc(EngFunc_WriteCoord, flOrigin[0]) // x axis
	engfunc(EngFunc_WriteCoord, flOrigin[1]) // y axis
	engfunc(EngFunc_WriteCoord, flOrigin[2] + g_flCvar_Radius) // z axis
	write_short(g_sprRing) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(10) // life
	write_byte(25) // width
	write_byte(0) // noise
	write_byte(zclass_ring_colors[0]) // red
	write_byte(zclass_ring_colors[1]) // green
	write_byte(zclass_ring_colors[2]) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
	
	// Screen effects for him self
	screen_effects(id)
	
	// Do scream effects
	while((iVictim = find_ent_in_sphere(iVictim, flOrigin, g_flCvar_Radius)) != 0)
	{
		// Non-player entity
		if(!is_user_valid_connected(iVictim))
		{
			// Validation check
			if(is_valid_ent(iVictim))
			{
				// Get entity classname
				static szClassname[33]
				entity_get_string(iVictim, EV_SZ_classname, szClassname, charsmax(szClassname))
				
				// It's a grenade, and isn't an Infection Bomb
				if(equal(szClassname, "grenade") && zp_get_grenade_type(iVictim) != NADE_TYPE_INFECTION)
				{
					// Get grenade origin
					entity_get_vector(iVictim, EV_VEC_origin, flVictimOrigin)
					
					// Do a good effect
					engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, flVictimOrigin, 0)
					write_byte(TE_PARTICLEBURST) // TE id
					engfunc(EngFunc_WriteCoord, flVictimOrigin[0]) // x
					engfunc(EngFunc_WriteCoord, flVictimOrigin[1]) // y
					engfunc(EngFunc_WriteCoord, flVictimOrigin[2]) // z
					write_short(45) // radius
					write_byte(108) // particle color
					write_byte(10) // duration * 10 will be randomized a bit
					message_end()
					
					// Remove it
					remove_entity(iVictim)
				}
				// If i don't check his solid type, it's used all the time.
				else if(equal(szClassname, "func_breakable") && entity_get_int(iVictim, EV_INT_solid) != SOLID_NOT)
				{
					// Destroy entity if he can
					force_use(id, iVictim)
				}
			}
			
			continue;
		}
			
		// Not alive, zombie or with Godmode
		if(!g_bIsAlive[iVictim] || zp_get_user_zombie(iVictim) || g_bSiren[iVictim] || get_user_godmode(iVictim))
			continue;
			
		// Screen effects for victims
		screen_effects(iVictim)
			
		// Get scream mode
		switch(g_iCvar_ScreamMode)
		{
			// Do damage
			case 0:
			{
				// Scream slowdown, first should be enabled
				if(g_flCvar_ScreamSlowdown > 0.0)
				{
					// Get his current velocity vector
					static Float:flVelocity[3]
					get_user_velocity(iVictim, flVelocity)
					
					// Multiply his velocity by a number
					xs_vec_mul_scalar(flVelocity, g_flCvar_ScreamSlowdown, flVelocity)
					
					// Set his new velocity vector
					set_user_velocity(iVictim, flVelocity)	
				}
				
				// Get damage result
				static iNewHealth
				iNewHealth = max(0, get_user_health(iVictim) - g_iCvar_ScreamDmg)
				
				// Does not has health
				if(!iNewHealth)
				{
					// Be infected when it's going to die
					if(g_iCvar_DamageMode /* == 1*/)
					{
						// Returns 1 on sucess...
						if(zp_infect_user(iVictim, id, 0, 1))
							continue
					}
	
					// Kill it
					scream_kill(iVictim, id)
					
					continue
				}
				
				// Do fake damage
				set_user_health(iVictim, iNewHealth)
			}
			
			// Instantly Infect
			case 1:
			{
				// Can be infected?
				if(!zp_infect_user(iVictim, id, 0, 1))
				{
					// Kill it
					scream_kill(iVictim, id)
				}
			}
			
			// Instantly Kill
			case 2:
			{
				// Kill it
				scream_kill(iVictim, id)
			}
		}
			
	}
}

/*================================================================================
 [Zombie Plague Forwards]
=================================================================================*/

public zp_user_infected_post(id, infector)
{
	if(zp_get_user_zombie(id))
		g_bSiren[id] = false;

	// It's the selected zombie class
	if(zp_get_user_zombie_class(id) == g_iSirenZID && !zp_get_user_nemesis(id))
	{
		// Array
		g_bCanDoScreams[id] = true
		
		// Message
		client_printcolor(id, "/g[ZP]/y You can do /gScreams/y pressing the /g^"+use^"/y Button")
	}
}

public zp_user_humanized_post(id)
{
	// Reset player vars and tasks
	stop_scream_task(id)
	
	g_bCanDoScreams[id] = false
	g_bDoingScream[id] = false
	g_iPlayerTaskTimes[id] = 0
	g_bSiren[id] = false

	remove_task(id+TASK_RELOAD)
	remove_task(id+TASK_SCREAMDMG)
}

public zp_round_ended(winteam)
{
	// Update bool
	g_bRoundEnding = true
	
	// Make a loop
	static id
	for(id = 1; id <= g_iMaxPlayers; id++)
	{
		// Valid connected
		if(is_user_valid_connected(id))
		{
			// Remove mainly tasks
			stop_scream_task(id)
			remove_task(id+TASK_RELOAD)
			g_bSiren[id] = false
		}
	}
}

/*================================================================================
 [Internal Functions]
=================================================================================*/

stop_scream_task(id)
{
	// Remove the task
	if(task_exists(id+TASK_SCREAM)) 
	{
		remove_task(id+TASK_SCREAM)
	
		// Remove screen's bar
		message_begin(MSG_ONE, g_msgBarTime, _, id)
		write_byte(0) // time
		write_byte(0) // unknown
		message_end()
		
		// Update bool
		g_bInScreamProcess[id] = false
	}
}

screen_effects(id)
{
	// Screen Fade
	message_begin(MSG_ONE_UNRELIABLE, g_msgScreenFade, _, id)
	write_short(UNIT_SECOND*1) // duration
	write_short(UNIT_SECOND*1) // hold time
	write_short(FFADE_IN) // fade type
	write_byte(200) // r
	write_byte(0) // g
	write_byte(0) // b
	write_byte(125) // alpha
	message_end()
	
	// Screen Shake
	message_begin(MSG_ONE_UNRELIABLE, g_msgScreenShake, _, id)
	write_short(UNIT_SECOND*5) // amplitude
	write_short(UNIT_SECOND*1) // duration
	write_short(UNIT_SECOND*5) // frequency
	message_end()
}

cache_cvars()
{
	g_iCvar_ScreamMode = get_pcvar_num(cvar_screammode)
	g_iCvar_ScreamDuration = get_pcvar_num(cvar_duration)
	g_iCvar_ScreamDmg = get_pcvar_num(cvar_screamdmg)
	g_iCvar_ScreamStartTime = get_pcvar_num(cvar_startime)
	g_iCvar_DamageMode = get_pcvar_num(cvar_damagemode)
	g_flCvar_ReloadTime = floatmax(g_iCvar_ScreamDuration+0.0, get_pcvar_float(cvar_reloadtime))
	g_flCvar_Radius = get_pcvar_float(cvar_radius)
	g_flCvar_ScreamSlowdown = get_pcvar_float(cvar_slowdown)
}

scream_kill(victim, attacker)
{
	// To use later in DeathMsg event
	g_bKilledByScream[victim] = true
	
	// Do kill
	ExecuteHamB(Ham_Killed, victim, attacker, GIB_NEVER)
	
	// We don't need this
	g_bKilledByScream[victim] = false
}

/*================================================================================
 [Stocks]
=================================================================================*/

stock client_printcolor(id, const input[], any:...)
{
	static iPlayersNum[32], iCount; iCount = 1
	static szMsg[191]
	
	vformat(szMsg, charsmax(szMsg), input, 3)
	
	replace_all(szMsg, 190, "/g", "^4") // green txt
	replace_all(szMsg, 190, "/y", "^1") // orange txt
	replace_all(szMsg, 190, "/ctr", "^3") // team txt
	replace_all(szMsg, 190, "/w", "^0") // team txt
	
	if(id) iPlayersNum[0] = id
	else get_players(iPlayersNum, iCount, "ch")
		
	for (new i = 0; i < iCount; i++)
	{
		if (g_bIsConnected[iPlayersNum[i]])
		{
			message_begin(MSG_ONE_UNRELIABLE, g_msgSayText, _, iPlayersNum[i])
			write_byte(iPlayersNum[i])
			write_string(szMsg)
			message_end()
		}
	}
}
