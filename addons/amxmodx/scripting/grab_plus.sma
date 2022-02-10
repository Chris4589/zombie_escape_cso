/*
Grab+ v1.2.5
Copyright (C) 2011 Ian (Juan) Cammarata

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
--------------------------------------------------------------------------------

http://ian.cammarata.us/projects/grab_plus
?19 ?February, ?2011


Description:
This is a remake from scratch of SpaceDude's Jedi Force Grab plugin.  It has many additional features and optimizations, is less spammy, multilingual and requires fewer binds. 


Features:
Multilingual
Screenfade to indicate grab activity instead of chat spam.
Can grab players off a ladder.
Automatically choke by holding down +pull while at min distance.
Choke with use key.
Throw with drop.
Can't have mutliple admins grabbing the same player.
Auto drop on death.
Grab entities other than players, such as bombs, weapons, and hostages.


Commands:

+grab : Grab something for as long as you hold down the key.
grab_toggle : Same as +grab but toggles.
amx_grab <name> : Grab client by name or id and teleport them to you.  Use +grab or grab_toggle key to release.

+pull/+push (or invnext/invprev): Pulls/pushes the grabbed towards/away from you as you hold the button.

+use : Chokes the grabbed (it damages the grabbed with 5 (cvar: gp_choke_dmg) hp per 1.5 (cvar: gp_choke_time) seconds)
drop - Throws the grabbed with 1500 velocity. (cvar: gp_throw_force)


Cvars (First value is default):
gp_enabled <1|0> Enables all plugin functionality.
gp_players_only <0|1> Disables admins grabbing entities other than players.

gp_min_dist <90|...> Min distance between the grabber and grabbed.
gp_grab_force <8|...> Sets the amount of force used when grabbing players.
gp_throw_force <1500|...> Sets the power used when throwing players.
gp_speed <5|...> How fast the grabbed moves when using push and pull.

gp_choke_time <1.5|...> Time frequency for choking.
gp_choke_dmg <5|...> Amount of damage done with each choke.
gp_auto_choke <1|0> Enable/disable choking automatically with +pull command.

gp_screen_fade <1|0> Enables/disables screenfade when grabbing.
gp_glow <1|0> Enables/disables glowing for grabbed objects.

gp_glow_r <50|0-255> Sets red amount for glow and screenfade.
gp_glow_g <0|0-255> Sets green amount for glow and screenfade.
gp_glow_b <0|0-255> Sets blue amount for glow and screenfade.
gp_glow_a <0|0-255> Sets alpha for glow and screenfade.


Notes:
Make sure you place the grab_plus.txt file in addons\amxmodx\data\lang


Credits:
Thanks to vittu for contributing code (changed all engine/fun module stuff to fakemeta).
 
Thanks to all the coders who worked on the original Jedi Force Grab plugin for all their ideas:
SpaceDude
KCE
KRoTaL
BOB_SLAYER
kosmo111


Supported Languages:
1337 (100%) - Thanks to l337newb
Brazilian Portuguese (100%) - Thanks to Arion
Danish (100%) - Thanks to nellerbabz
Dutch (100%) - Thanks to BlackMilk
English (100%)
Finnish (100%) - Thanks to Pro Patria Finland
French (100%) - Thanks to connorr
German (100%) - Thanks to SchlumPF*
Russian (100%) - Thanks to `666
Spanish (100%) - Thanks to RenXO
Swedish (100%) - Thanks to Bend3r


Change Log:
Key (+ added | - removed | c changed | f fixed)

v1.2.5 (Feb 19, 2011)
f: Applied fix mailed to me on Allied Modders site several years ago.  (Maybe I should sign up for new mail notifications.)
Thanks to ConnorMcLeod

v1.2.4 (Feb 18, 2007)
f: Killing player with choke in some mods bugged out really bad.

v1.2.3 (Nov 21, 2007)
c: A few more small optimizations.
f: Bloodstream for choke wasn't aligned with player.
f: Bad message disconnect error when players were choked. ( stupid SVC_DAMAGE define )

v1.2.2 (Nov 16, 2007)
c: A few small code optimizations.

v1.2.1 (Nov 12, 2007)
f: Eliminated two run time warnings in the player prethink function.

v1.2 (Nov 06, 2007)
+: Cvars gp_screen_fade and gp_glow to enable/disable these features.
+: Cvar gp_glow_a controls to control alpha of screenfade and glow.
+: Cvar gp_auto_choke to enable/disable choking automatically with +pull command.
c: Removed dependency of engine and fun modules.  Thanks to vittu for doing most of the work.
c: Made cvar names more consistent by adding more underscores.
f: Fixed compile bug with amxx 1.8.0 (Compiles with 1.7.x as well).

v1.1 (Oct 16, 2007)
+: Grab a few types of entities other than players.
+: Cvar gp_players_only.

v1.0 (Oct 13, 2007)
!: Initial release

*/

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <zombieplague>

new const VERSION[ ] = "1.2.4b1"
new const TRKCVAR[ ] = "grab_plus_version"
#define ADMIN ADMIN_LEVEL_A

#define TSK_CHKE 50

#define SF_FADEOUT 0

new client_data[33][4]
#define GRABBED  0
#define GRABBER  1
#define GRAB_LEN 2
#define FLAGS    3

#define m_bitsDamageType 76

#define CDF_IN_PUSH   (1<<0)
#define CDF_IN_PULL   (1<<1)
#define CDF_NO_CHOKE  (1<<2)

//Cvar Pointers
new p_enabled, p_players_only
new p_throw_force, p_min_dist, p_speed, p_grab_force
new p_choke_time, p_choke_dmg, p_auto_choke
new p_glow_r, p_glow_b, p_glow_g, p_glow_a
new p_fade, p_glow

//Pseudo Constants
new MAXPLAYERS
new SVC_SCREENFADE, SVC_SCREENSHAKE, WTF_DAMAGE

public plugin_init( )
{
	register_plugin( "Grab+", VERSION, "Ian Cammarata" )
	register_cvar( TRKCVAR, VERSION, FCVAR_SERVER )
	set_cvar_string( TRKCVAR, VERSION )
	
	p_enabled = register_cvar( "gp_enabled", "1" )
	p_players_only = register_cvar( "gp_players_only", "1" )
	
	p_min_dist = register_cvar ( "gp_min_dist", "120" )
	p_throw_force = register_cvar( "gp_throw_force", "1500" )
	p_grab_force = register_cvar( "gp_grab_force", "8" )
	p_speed = register_cvar( "gp_speed", "10" )
	
	p_choke_time = register_cvar( "gp_choke_time", "1.5" )
	p_choke_dmg = register_cvar( "gp_choke_dmg", "5" )
	p_auto_choke = register_cvar( "gp_auto_choke", "1" )
	
	p_glow_r = register_cvar( "gp_glow_r", "50" )
	p_glow_g = register_cvar( "gp_glow_g", "0" )
	p_glow_b = register_cvar( "gp_glow_b", "0" )
	p_glow_a = register_cvar( "gp_glow_a", "200" )
	
	p_fade = register_cvar( "gp_screen_fade", "1" )
	p_glow = register_cvar( "gp_glow", "1" )
	
	register_clcmd( "amx_grab", "force_grab", ADMIN, "Grab client & teleport to you." )
	register_clcmd( "grab_toggle", "grab_toggle", ADMIN, "press once to grab and again to release" )
	register_clcmd( "+grab", "grab", ADMIN, "bind a key to +grab" )
	register_clcmd( "-grab", "unset_grabbed" )
	
	register_clcmd( "+push", "push", ADMIN, "bind a key to +push" )
	register_clcmd( "-push", "push" )
	register_clcmd( "+pull", "pull", ADMIN, "bind a key to +pull" )
	register_clcmd( "-pull", "pull" )
	register_clcmd( "push", "push2" )
	register_clcmd( "pull", "pull2" )
	
	register_clcmd( "drop" ,"throw" )
	
	register_event( "DeathMsg", "DeathMsg", "a" )
	
	register_forward( FM_PlayerPreThink, "fm_player_prethink" )
	
	register_dictionary( "grab_plus.txt" )
	
	MAXPLAYERS = get_maxplayers()
	
	SVC_SCREENFADE = get_user_msgid( "ScreenFade" )
	SVC_SCREENSHAKE = get_user_msgid( "ScreenShake" )
	WTF_DAMAGE = get_user_msgid( "Damage" )
}

public plugin_precache( )
{
	precache_sound( "player/PL_PAIN2.WAV" )
} 

public fm_player_prethink( id )
{
	new target
	//Search for a target
	if ( client_data[id][GRABBED] == -1 )
	{
		new Float:orig[3], Float:ret[3]
		get_view_pos( id, orig )
		ret = vel_by_aim( id, 9999 )
		
		ret[0] += orig[0]
		ret[1] += orig[1]
		ret[2] += orig[2]
		
		target = traceline( orig, ret, id, ret )
		
		if( 0 < target <= MAXPLAYERS )
		{
			if( is_grabbed( target, id ) ) return FMRES_IGNORED
			set_grabbed( id, target )
		}
		else if( !get_pcvar_num( p_players_only ) )
		{
			new movetype
			if( target && pev_valid( target ) )
			{
				movetype = pev( target, pev_movetype )
				if( !( movetype == MOVETYPE_WALK || movetype == MOVETYPE_STEP || movetype == MOVETYPE_TOSS ) )
					return FMRES_IGNORED
			}
			else
			{
				target = 0
				new ent = engfunc( EngFunc_FindEntityInSphere, -1, ret, 12.0 )
				while( !target && ent > 0 )
				{
					movetype = pev( ent, pev_movetype )
					if( ( movetype == MOVETYPE_WALK || movetype == MOVETYPE_STEP || movetype == MOVETYPE_TOSS )
							&& ent != id  )
						target = ent
					ent = engfunc( EngFunc_FindEntityInSphere, ent, ret, 12.0 )
				}
			}
			if( target )
			{
				if( is_grabbed( target, id ) ) return FMRES_IGNORED
				set_grabbed( id, target )
			}
		}
	}
	
	target = client_data[id][GRABBED]
	//If they've grabbed something
	if( target > 0 )
	{
		if( !pev_valid( target ) || ( pev( target, pev_health ) < 1 && pev( target, pev_max_health ) ) )
		{
			unset_grabbed( id )
			return FMRES_IGNORED
		}
		 
		//Use key choke
		if( pev( id, pev_button ) & IN_USE )
			do_choke( id )
		
		//Push and pull
		new cdf = client_data[id][FLAGS]
		if ( cdf & CDF_IN_PULL )
			do_pull( id )
		else if ( cdf & CDF_IN_PUSH )
			do_push( id )
		
		if( target > MAXPLAYERS ) grab_think( id )
	}
	
	//If they're grabbed
	target = client_data[id][GRABBER]
	if( target > 0 ) grab_think( target )
	
	return FMRES_IGNORED
}

public grab_think( id ) //id of the grabber
{
	new target = client_data[id][GRABBED]
	
	//Keep grabbed clients from sticking to ladders
	if( pev( target, pev_movetype ) == MOVETYPE_FLY && !(pev( target, pev_button ) & IN_JUMP ) ) client_cmd( target, "+jump;wait;-jump" )
	
	//Move targeted client
	new Float:tmpvec[3], Float:tmpvec2[3], Float:torig[3], Float:tvel[3]
	
	get_view_pos( id, tmpvec )
	
	tmpvec2 = vel_by_aim( id, client_data[id][GRAB_LEN] )
	
	torig = get_target_origin_f( target )
	
	new force = get_pcvar_num( p_grab_force )
	
	tvel[0] = ( ( tmpvec[0] + tmpvec2[0] ) - torig[0] ) * force
	tvel[1] = ( ( tmpvec[1] + tmpvec2[1] ) - torig[1] ) * force
	tvel[2] = ( ( tmpvec[2] + tmpvec2[2] ) - torig[2] ) * force
	
	set_pev( target, pev_velocity, tvel )
}

stock Float:get_target_origin_f( id )
{
	new Float:orig[3]
	pev( id, pev_origin, orig )
	
	//If grabbed is not a player, move origin to center
	if( id > MAXPLAYERS )
	{
		new Float:mins[3], Float:maxs[3]
		pev( id, pev_mins, mins )
		pev( id, pev_maxs, maxs )
		
		if( !mins[2] ) orig[2] += maxs[2] / 2
	}
	
	return orig
}

public grab_toggle( id, level, cid )
{
	if( !client_data[id][GRABBED] ) grab( id, level, cid )
	else unset_grabbed( id )
	
	return PLUGIN_HANDLED
}

public grab( id, level, cid )
{
	if( !cmd_access( id, level, cid, 1 ) || !get_pcvar_num( p_enabled ) || zp_get_class(id) >= ZOMBIE) 
		return PLUGIN_HANDLED
	
	if ( !client_data[id][GRABBED] ) client_data[id][GRABBED] = -1	
	screenfade_in( id )
	
	return PLUGIN_HANDLED
}

public screenfade_in( id )
{
	if( get_pcvar_num( p_fade ) )
	{
		message_begin( MSG_ONE, SVC_SCREENFADE, _, id )
		write_short( 10000 ) //duration
		write_short( 0 ) //hold
		write_short( SF_FADE_IN + SF_FADE_ONLYONE ) //flags
		write_byte( get_pcvar_num( p_glow_r ) ) //r
		write_byte( get_pcvar_num( p_glow_g ) ) //g
		write_byte( get_pcvar_num( p_glow_b ) ) //b
		write_byte( get_pcvar_num( p_glow_a ) / 2 ) //a
		message_end( )
	}
}

public throw( id )
{
	new target = client_data[id][GRABBED]
	if( target > 0 )
	{
		set_pev( target, pev_velocity, vel_by_aim( id, get_pcvar_num(p_throw_force) ) )
		unset_grabbed( id )
		return PLUGIN_HANDLED
	}

	return PLUGIN_CONTINUE
}

public unset_grabbed( id )
{
	new target = client_data[id][GRABBED]
	if( target > 0 && pev_valid( target ) )
	{
		set_pev( target, pev_renderfx, kRenderFxNone )
		set_pev( target, pev_rendercolor, {255.0, 255.0, 255.0} )
		set_pev( target, pev_rendermode, kRenderNormal )
		set_pev( target, pev_renderamt, 16.0 )
		
		if( 0 < target <= MAXPLAYERS )
			client_data[target][GRABBER] = 0
	}
	client_data[id][GRABBED] = 0
	
	if( get_pcvar_num( p_fade ) )
	{
		message_begin( MSG_ONE, SVC_SCREENFADE, _, id )
		write_short( 10000 ) //duration
		write_short( 0 ) //hold
		write_short( SF_FADEOUT ) //flags
		write_byte( get_pcvar_num( p_glow_r ) ) //r
		write_byte( get_pcvar_num( p_glow_g ) ) //g
		write_byte( get_pcvar_num( p_glow_b ) ) //b
		write_byte( get_pcvar_num( p_glow_a ) / 2 ) //a
		message_end( )
	}
}

//Grabs onto someone
public set_grabbed( id, target )
{
	if(zp_get_class(target) >= ZOMBIE)
		return;

	if( get_pcvar_num( p_glow ) )
	{
		new Float:color[3]
		color[0] = get_pcvar_float( p_glow_r )
		color[1] = get_pcvar_float( p_glow_g )
		color[2] = get_pcvar_float( p_glow_b )
		set_pev( target, pev_renderfx, kRenderFxGlowShell )
		set_pev( target, pev_rendercolor, color )
		set_pev( target, pev_rendermode, kRenderTransColor )
		set_pev( target, pev_renderamt, get_pcvar_float( p_glow_a ) )
	}
	
	if( 0 < target <= MAXPLAYERS )
		client_data[target][GRABBER] = id
	client_data[id][FLAGS] = 0
	client_data[id][GRABBED] = target
	new Float:torig[3], Float:orig[3]
	pev( target, pev_origin, torig )
	pev( id, pev_origin, orig )
	client_data[id][GRAB_LEN] = floatround( get_distance_f( torig, orig ) )
	if( client_data[id][GRAB_LEN] < get_pcvar_num( p_min_dist ) ) client_data[id][GRAB_LEN] = get_pcvar_num( p_min_dist )
}

public push( id )
{
	client_data[id][FLAGS] ^= CDF_IN_PUSH
	return PLUGIN_HANDLED
}

public pull( id )
{
	client_data[id][FLAGS] ^= CDF_IN_PULL
	return PLUGIN_HANDLED
}

public push2( id )
{
	if( client_data[id][GRABBED] > 0 )
	{
		do_push( id )
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

public pull2( id )
{
	if( client_data[id][GRABBED] > 0 )
	{
		do_pull( id )
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

public do_push( id )
	if( client_data[id][GRAB_LEN] < 9999 )
		client_data[id][GRAB_LEN] += get_pcvar_num( p_speed )

public do_pull( id )
{
	new mindist = get_pcvar_num( p_min_dist )
	new len = client_data[id][GRAB_LEN]
	
	if( len > mindist )
	{
		len -= get_pcvar_num( p_speed )
		if( len < mindist ) len = mindist
		client_data[id][GRAB_LEN] = len
	}
	else if( get_pcvar_num( p_auto_choke ) )
		do_choke( id )
}

public do_choke( id )
{
	new target = client_data[id][GRABBED]
	if( client_data[id][FLAGS] & CDF_NO_CHOKE || id == target || target > MAXPLAYERS) return
	
	new dmg = get_pcvar_num( p_choke_dmg )
	new vec[3]
	FVecIVec( get_target_origin_f( target ), vec )
	
	message_begin( MSG_ONE, SVC_SCREENSHAKE, _, target )
	write_short( 999999 ) //amount
	write_short( 9999 ) //duration
	write_short( 999 ) //frequency
	message_end( )
	
	message_begin( MSG_ONE, SVC_SCREENFADE, _, target )
	write_short( 9999 ) //duration
	write_short( 100 ) //hold
	write_short( SF_FADE_MODULATE ) //flags
	write_byte( get_pcvar_num( p_glow_r ) ) //r
	write_byte( get_pcvar_num( p_glow_g ) ) //g
	write_byte( get_pcvar_num( p_glow_b ) ) //b
	write_byte( 200 ) //a
	message_end( )
	
	message_begin( MSG_ONE, WTF_DAMAGE, _, target )
	write_byte( 0 ) //damage armor
	write_byte( dmg ) //damage health
	write_long( DMG_CRUSH ) //damage type
	write_coord( vec[0] ) //origin[x]
	write_coord( vec[1] ) //origin[y]
	write_coord( vec[2] ) //origin[z]
	message_end( )
		
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY )
	write_byte( TE_BLOODSTREAM )
	write_coord( vec[0] ) //pos.x
	write_coord( vec[1] ) //pos.y
	write_coord( vec[2] + 15 ) //pos.z
	write_coord( random_num( 0, 255 ) ) //vec.x
	write_coord( random_num( 0, 255 ) ) //vec.y
	write_coord( random_num( 0, 255 ) ) //vec.z
	write_byte( 70 ) //col index
	write_byte( random_num( 50, 250 ) ) //speed
	message_end( )
	
	//Thanks to ConnorMcLeod for making this block of code more proper
	new Float:health
	pev( target, pev_health , health)
	health -= dmg 
	if( health < 1 ) dllfunc( DLLFunc_ClientKill, target )
	else {
		set_pev( target, pev_health, health )
		set_pdata_int(target, m_bitsDamageType, DMG_CRUSH) // m_bitsDamageType = 76 // found by VEN
		set_pev(target, pev_dmg_take, dmg)
		set_pev(target, pev_dmg_inflictor, id)
	}
	
	client_data[id][FLAGS] ^= CDF_NO_CHOKE
	set_task( get_pcvar_float( p_choke_time ), "clear_no_choke", TSK_CHKE + id )
}

public clear_no_choke( tskid )
{
	new id = tskid - TSK_CHKE
	client_data[id][FLAGS] ^= CDF_NO_CHOKE
}

//Grabs the client and teleports them to the admin
public force_grab(id, level, cid)
{
	if( !cmd_access( id, level, cid, 1 ) || !get_pcvar_num( p_enabled ) ) return PLUGIN_HANDLED

	new arg[33]
	read_argv( 1, arg, 32 )

	new targetid = cmd_target( id, arg, 1 )
	
	if( is_grabbed( targetid, id ) ) return PLUGIN_HANDLED
	if( !is_user_alive( targetid ) )
	{
		client_print( id, print_console, "[AMXX] %L", id, "COULDNT" )
		return PLUGIN_HANDLED
	}
	
	//Safe to tp target to aim spot?
	new Float:tmpvec[3], Float:orig[3], Float:torig[3], Float:trace_ret[3]
	new bool:safe = false, i
	
	get_view_pos( id, orig )
	tmpvec = vel_by_aim( id, get_pcvar_num( p_min_dist ) )
	
	for( new j = 1; j < 11 && !safe; j++ )
	{
		torig[0] = orig[0] + tmpvec[i] * j
		torig[1] = orig[1] + tmpvec[i] * j
		torig[2] = orig[2] + tmpvec[i] * j
		
		traceline( tmpvec, torig, id, trace_ret )
		
		if( get_distance_f( trace_ret, torig ) ) break
		
		engfunc( EngFunc_TraceHull, torig, torig, 0, HULL_HUMAN, 0, 0 )
		if ( !get_tr2( 0, TR_StartSolid ) && !get_tr2( 0, TR_AllSolid ) && get_tr2( 0, TR_InOpen ) )
			safe = true
	}
	
	//Still not safe? Then find another safe spot somewhere around the grabber
	pev( id, pev_origin, orig )
	new try[3]
	orig[2] += 2
	while( try[2] < 3 && !safe )
	{
		for( i = 0; i < 3; i++ )
			switch( try[i] )
			{
				case 0 : torig[i] = orig[i] + ( i == 2 ? 80 : 40 )
				case 1 : torig[i] = orig[i]
				case 2 : torig[i] = orig[i] - ( i == 2 ? 80 : 40 )
			}
		
		traceline( tmpvec, torig, id, trace_ret )
		
		engfunc( EngFunc_TraceHull, torig, torig, 0, HULL_HUMAN, 0, 0 )
		if ( !get_tr2( 0, TR_StartSolid ) && !get_tr2( 0, TR_AllSolid ) && get_tr2( 0, TR_InOpen )
				&& !get_distance_f( trace_ret, torig ) ) safe = true
		
		try[0]++
		if( try[0] == 3 )
		{
			try[0] = 0
			try[1]++
			if( try[1] == 3 )
			{
				try[1] = 0
				try[2]++
			}
		}
	}
	
	if( safe )
	{
		set_pev( targetid, pev_origin, torig )
		set_grabbed( id, targetid )
		screenfade_in( id )	
	}
	else client_print( id, print_chat, "[AMXX] %L", id, "COULDNT" )

	return PLUGIN_HANDLED
}

public is_grabbed( target, grabber )
{
	for( new i = 1; i <= MAXPLAYERS; i++ )
		if( client_data[i][GRABBED] == target )
		{
			client_print( grabber, print_chat, "[AMXX] %L", grabber, "ALREADY" )
			unset_grabbed( grabber )
			return true
		}
	return false
}

public DeathMsg( )
	kill_grab( read_data( 2 ) )

public client_disconnected( id )
{
	kill_grab( id )
	return PLUGIN_CONTINUE
}

public kill_grab( id )
{
	//If given client has grabbed, or has a grabber, unset it
	if( client_data[id][GRABBED] )
		unset_grabbed( id )
	else if( client_data[id][GRABBER] )
		unset_grabbed( client_data[id][GRABBER] )
}

stock traceline( const Float:vStart[3], const Float:vEnd[3], const pIgnore, Float:vHitPos[3] )
{
	engfunc( EngFunc_TraceLine, vStart, vEnd, 0, pIgnore, 0 )
	get_tr2( 0, TR_vecEndPos, vHitPos )
	return get_tr2( 0, TR_pHit )
}

stock get_view_pos( const id, Float:vViewPos[3] )
{
	new Float:vOfs[3]
	pev( id, pev_origin, vViewPos )
	pev( id, pev_view_ofs, vOfs )		
	
	vViewPos[0] += vOfs[0]
	vViewPos[1] += vOfs[1]
	vViewPos[2] += vOfs[2]
}

stock Float:vel_by_aim( id, speed = 1 )
{
	new Float:v1[3], Float:vBlah[3]
	pev( id, pev_v_angle, v1 )
	engfunc( EngFunc_AngleVectors, v1, v1, vBlah, vBlah )
	
	v1[0] *= speed
	v1[1] *= speed
	v1[2] *= speed
	
	return v1
}
