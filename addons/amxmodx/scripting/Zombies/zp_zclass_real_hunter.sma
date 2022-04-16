/*================================================================================
	
	-----------------------------------
	-*- [ZP] Real Hunter L4D -*-
	-----------------------------------
	
	~~~~~~~~~~~~~~~
	- Description -
	~~~~~~~~~~~~~~~
	
	This zombie has long jumps as well as the popular game L4D2
        Well, this time the skill is good and better,
        to jump you have to press Ctrl + E and look where you want to jump.
	by Re.Act!ve
================================================================================*/

#include <amxmodx>
#include <fakemeta>
#include <cstrike>
#include <zombieplague>

/*================================================================================
 [Customizations]
=================================================================================*/

// Zombie Attributes
new const zclass_name[] = "Real Hunter"
new const zclass_info[] = "Speed & Ability"

const zclass_health = 1200
const zclass_speed = 292

const Float:zclass_gravity = 0.65
const Float:zclass_knockback = 1.0

new const leap_sound[] = { "zombie_plague/hunter_jump.wav" }
#define fm_get_user_button(%1) pev(%1, pev_button)	
#define fm_get_entity_flags(%1) pev(%1, pev_flags)
#define STR_T           32
/*================================================================================
 Customization ends here!
 Any edits will be your responsibility
=================================================================================*/

// Variables
new g_hunter

// Arrays
new Float:g_lastleaptime[33], Float:g_wall_time[33]

// Cvar pointers
new cvar_force, cvar_cooldown, cvar_wall,  g_wall_climb[33]
new Float:g_wallorigin[33][3]
// Plugin info.
#define PLUG_VERSION "0.1"
#define PLUG_AUTHOR "DJHD! & Re.Act!ve"

/*================================================================================
 [Init, CFG and Precache]
=================================================================================*/

public plugin_precache()
{
    // Register the new class and store ID for reference
    g_hunter = zp_register_zombie_class(zclass_name, zclass_info, 16, zclass_health, zclass_speed, zclass_gravity, zclass_knockback)
    
    // Sound
    precache_sound(leap_sound)
}

public plugin_init() 
{
    // Plugin Info
    register_plugin("[ZP] Zombie Class: Hunter L4D", PLUG_VERSION, PLUG_AUTHOR)
    
    // Forward
    register_forward(FM_PlayerPreThink, "fw_PlayerPreThink") 
    register_forward(FM_Touch, 		"fwd_touch")
    
    // Cvars
    cvar_force = register_cvar("zp_hunter_jump_force","800") 
    cvar_cooldown = register_cvar("zp_hunter_jump_cooldown","3.5")
    cvar_wall = register_cvar("zp_hunter_jump_wall_time","4.5")
    
    static szCvar[30]
    formatex(szCvar, charsmax(szCvar), "v%s by %s", PLUG_VERSION, PLUG_AUTHOR)
    register_cvar("zp_zclass_hunterl4d2", szCvar, FCVAR_SERVER|FCVAR_SPONLY)
}

/*================================================================================
 [Zombie Plague Forwards]
=================================================================================*/

public zp_user_infected_post(id, infector)
{
    // It's the selected zombie class
    if(zp_get_user_zombie_class(id) == g_hunter && !zp_get_user_nemesis(id))
    {    
        // Message
        client_print(id, print_chat, "[ZP] Para saltar, siéntese y haga clic ^"E^"")
        client_print(id, print_chat, "[ZP] A continuación, se puede subir a la pared durante unos segundos con la tecla C pulsada para poner en cuclillas")
    }
}

/*================================================================================
 [Main Forwards]
=================================================================================*/

public fw_PlayerPreThink(id)
{
    if (!is_user_alive(id))
        return
   
    if(is_user_connected(id))
    {
        if (allowed_hunterjump(id))
        {
            static Float:velocity[3]
            velocity_by_aim(id, get_pcvar_num(cvar_force), velocity)
            set_pev(id, pev_velocity, velocity)
            emit_sound(id, CHAN_STREAM, leap_sound, 1.0, ATTN_NORM, 0, PITCH_HIGH )
            g_wall_time[id] = get_gametime();
	    g_wall_climb[id] = get_pcvar_num(cvar_wall);
            // Set the current leap time
            g_lastleaptime[id] = get_gametime()
	    if(task_exists(id)) remove_task(id);
	    set_task(1.0, "ShowHUDstealthes", id, _, _, "a", g_wall_climb[id])
        }
	else
	{
	    new button = fm_get_user_button(id)
	    if((button & IN_DUCK) && (zp_get_user_zombie_class(id) == g_hunter) && (get_gametime() - g_lastleaptime[id]> 0.7))
	    wallclimb(id, button)
	}
    }
}

public ShowHUDstealthes(id)
{
	if(is_user_alive(id))
	{
		g_wall_climb[id] = g_wall_climb[id] - 1;
		set_hudmessage(200, 100, 0, 0.75, 0.92, 0, 1.0, 1.1, 0.0, 0.0, -1)
		show_hudmessage(id, "Время цепкости к стене: %d сек",g_wall_climb[id])

	}else{
		remove_task(id)
	}
}

public fwd_touch(id, world)
{
	if(!is_user_alive(id) || !is_user_connected(id) || zp_get_user_zombie_class(id) != g_hunter)
		return FMRES_IGNORED;

	new player = STR_T
	if (!player)
		return FMRES_IGNORED
		
	new classname[STR_T]
	pev(world, pev_classname, classname, (STR_T))
	
	if(equal(classname, "worldspawn") || equal(classname, "func_wall") || equal(classname, "func_breakable"))
		pev(id, pev_origin, g_wallorigin[id])

	return FMRES_IGNORED
}


/*================================================================================
 [Internal Functions]
=================================================================================*/

allowed_hunterjump(id)
{    
    if (!zp_get_user_zombie(id) && !zp_get_user_nemesis(id))
        return false

    if (zp_get_user_zombie_class(id) != g_hunter)
        return false
    
    static buttons
    buttons = pev(id, pev_button)
    
    // Not doing a longjump (added bot support)
    if (!(buttons & IN_USE) || !(buttons & IN_DUCK))
        return false
    
    static Float:cooldown
    cooldown = get_pcvar_float(cvar_cooldown)

    if (get_gametime() - g_lastleaptime[id] < cooldown)
        return false
        
    return true
}

public wallclimb(id, button)
{
	static Float:origin[3], Float:time
	pev(id, pev_origin, origin)
    	time = get_pcvar_float(cvar_wall)

	if(get_gametime() - g_wall_time[id] > time)
	return FMRES_IGNORED

	if(get_distance_f(origin, g_wallorigin[id]) > 20.0)
		return FMRES_IGNORED  // if not near wall
	
	if(fm_get_entity_flags(id) & FL_ONGROUND)
		return FMRES_IGNORED

	if(button & IN_FORWARD)
	{
		static Float:velocity[3]
		velocity_by_aim(id, 120, velocity)
		fm_set_user_velocity(id, velocity)
	}
	else if(button & IN_BACK)
	{
		static Float:velocity[3]
		velocity_by_aim(id, -120, velocity)
		fm_set_user_velocity(id, velocity)
	}
	else
	{
		static Float:velocity[3]
		velocity_by_aim(id, 0, velocity)
		fm_set_user_velocity(id, velocity)
	}

	return FMRES_IGNORED
}	

stock fm_set_user_velocity(entity, const Float:vector[3]) {
	set_pev(entity, pev_velocity, vector);

	return 1;
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang13322\\ f0\\ fs16 \n\\ par }
*/
