/*================================================================================

-----------------------------------
-*- [ZP] Hunter L4D -*-
-----------------------------------

~~~~~~~~~~~~~~~
- Description -
~~~~~~~~~~~~~~~

This zombie has long jumps as well as the popular game L4D2
Well, this time the skill is good and better,
to jump you have to press Ctrl + E and look where you want to jump.

================================================================================*/

#include <amxmodx>
#include <zombieplague>
#include <hamsandwich>
#include <fun>
#include <cstrike>
#include <amxmisc>
#include <fakemeta>

/*================================================================================
[Customizations]
=================================================================================*/
// Zombie Attributes
new const zclass_name[] = "Hunter Zombie"
new const zclass_info[] = "Control + E y saltas"
new const zclass_model[] = "hunterv2_zp"
new const zclass_clawmodel[] = "v_knife_zombie_hunter.mdl";
const zclass_health = 3000
const zclass_speed = 300
const Float:zclass_gravity = 0.6
const Float:zclass_knockback = 1.0

new const leap_sound[1][] = { "left_4_dead2/hunter_jump.wav"}

/*================================================================================
Customization ends here!
Any edits will be your responsibility
=================================================================================*/

// Variables
new g_hunter

// Arrays
new Float:g_lastleaptime[33]

// Cvar pointers
new cvar_force, cvar_cooldown

// Plugin info.
#define PLUG_VERSION "0.2"
#define PLUG_AUTHOR "DJHD!"

/*================================================================================
[Init, CFG and Precache]
=================================================================================*/

public plugin_precache()
{
    // Register the new class and store ID for reference
    
    g_hunter = zp_register_class(CLASS_ZOMBIE, zclass_name, zclass_info, zclass_model, zclass_clawmodel, 16, 0, ADMIN_ALL, zclass_health, 0, zclass_speed, zclass_gravity, zclass_knockback)
    
    // Sound
    static i
    for(i = 0; i < sizeof leap_sound; i++) 
        precache_sound(leap_sound[i])
}
public zp_user_infected_post(id, infector)
{
    // It's the selected zombie class
    if(zp_get_user_zombie_class(id) == g_hunter)
    {
        if(zp_get_class(id) > NEMESIS)
            return
        
        // Message
        client_print(id, print_chat, "[ZP] To use the super jump ability press - ^"CTRL + E^"")
    }
}
public plugin_init() 
{
    // Plugin Info
    register_plugin("[ZP] Zombie Class: Hunter L4D2 Zombie", PLUG_VERSION, PLUG_AUTHOR)

    // Forward
    register_forward(FM_PlayerPreThink, "fw_PlayerPreThink") 

    // Cvars
    cvar_force = register_cvar("zp_hunter_jump_force", "720") 
    cvar_cooldown = register_cvar("zp_hunter_jump_cooldown", "20")

    static szCvar[30]
    formatex(szCvar, charsmax(szCvar), "v%s by %s", PLUG_VERSION, PLUG_AUTHOR)
    register_cvar("zp_zclass_hunterl4d2", szCvar, FCVAR_SERVER|FCVAR_SPONLY)
}

/*================================================================================
[Zombie Plague Forwards]
=================================================================================*/


/*================================================================================
[Main Forwards]
=================================================================================*/


public test(id)
{
    static Float:velocity[3]
    velocity_by_aim(id, get_pcvar_num(cvar_force), velocity)
    set_pev(id, pev_velocity, velocity)
}

public fw_PlayerPreThink(id)
{
    if(!is_user_alive(id) || !zp_get_user_zombie(id))
        return

    if(zp_get_class(id) >= NEMESIS)
        return
    
    if(is_user_connected(id))
    {
        if (allowed_hunterjump(id))
        {
            static Float:velocity[3]
            velocity_by_aim(id, get_pcvar_num(cvar_force), velocity)
            set_pev(id, pev_velocity, velocity)
            
            emit_sound(id, CHAN_STREAM, leap_sound[random_num(0, sizeof leap_sound -1)], 1.0, ATTN_NORM, 0, PITCH_HIGH)
            
            // Set the current super jump time
            g_lastleaptime[id] = get_gametime()
        }
    }
}

/*================================================================================
[Internal Functions]
=================================================================================*/

allowed_hunterjump(id)
{    
    if (!zp_get_user_zombie(id))
        return false
    
    if (zp_get_user_zombie_class(id) != g_hunter || zp_get_class(id) >= NEMESIS)
        return false
    
    if (!((pev(id, pev_flags) & FL_ONGROUND) && (pev(id, pev_flags) & FL_DUCKING)))
        return false
    
    static buttons
    buttons = pev(id, pev_button)
    
    // Not doing a longjump (added bot support)
    if (!(buttons & IN_USE) && !is_user_bot(id))
        return false
    
    static Float:cooldown
    cooldown = get_pcvar_float(cvar_cooldown)
    
    if (get_gametime() - g_lastleaptime[id] < cooldown)
        return false
    
    return true
}


