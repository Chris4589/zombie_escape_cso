/*
/--------------[ZP] Zclass Pyramid Zombie----------------
/-This zombie class can not be hit in the head
/-More damage with knife (acording to cvar)
/-----------------------Have Fun!------------------------
*/

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich> 
#include <zombieplague>

// Zombie Attributes
new const zclass_name[] =  "Pyramid Zombie"  // name
new const zclass_info[] =  "No HS Efect"  // description
new const zclass_model[] =  "pyramid"  // model
new const zclass_clawmodel[] = { "v_knife_.mdl" }  // claw model
const zclass_health = 1250 // health
const zclass_speed = 250 // speed
const Float:zclass_gravity = 0.8 // gravity
const Float:zclass_knockback = 3.0

// New variables
new g_zclassid1, g_iMaxPlayers

// Registering cvars and fuctions
public plugin_init() 
{
    register_forward(FM_TraceLine, "fw_traceline", 1)
    g_iMaxPlayers = get_maxplayers()  
}

// Zombie Classes MUST be registered on plugin_precache
public plugin_precache()
{
    register_plugin("[ZP] Zombie Class: Pyramid Zombie", "1.0", "Zombiezzz") 

    // Register the new class and store ID for reference
    g_zclassid1 = zp_register_class(CLASS_ZOMBIE, zclass_name, zclass_info, zclass_model, zclass_clawmodel, 20, zclass_health, zclass_speed, zclass_gravity, zclass_knockback) 
}

// No Headshot to the zombie
public fw_traceline(Float:start[3], Float:end[3], id, trace)
{
    if(!is_user_alive(id) || zp_get_class(id) >= NEMESIS || zp_get_class(id) < ZOMBIE || zp_get_user_zombie_class(id) != g_zclassid1)
    return FMRES_IGNORED

    static iVictim
    iVictim = get_tr2(trace, TR_pHit)

    if(!(1 <= iVictim <= g_iMaxPlayers) || !is_user_alive(iVictim))
    return FMRES_IGNORED

    if(get_tr2(trace, TR_iHitgroup) != HIT_HEAD && (pev(id, pev_button) & IN_ATTACK))
    {
        set_tr2(trace, TR_flFraction, 1.0)
        return FMRES_SUPERCEDE
    }
    return FMRES_IGNORED
}

// This take effect when hte user is infected
public zp_user_infected_post ( id)
{
    if (zp_get_user_zombie_class(id) == g_zclassid1)
    {
        
        client_print(id, print_chat, "[ZP] Eres el zombie Pyramid No te afectan los HS.")
    }
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/ 