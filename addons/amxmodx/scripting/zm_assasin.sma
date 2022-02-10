/* 
                [ZP] Class : Assassin Zombie
                  (Powerful zombie class)
                       by Fry!
                    
                    
    Description :
    
            This is one of powerful zombies. Cuz now you can chose between infect and kill humans.
            Press +Attack2 to kill people.
                
    Changelog :
    
            28/12/2009 - v1.0 - Public release            
*/

#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <zombieplague>

#define PLUGIN "[ZP] Class : Assassin Zombie"
#define VERSION "1.0"
#define AUTHOR "Fry!"

new const zclass_name[] = "Assassin Zombie"
new const zclass_info[] = "clic derecho mata, infectas izquierdo"
new const zclass_model[] = "zombie_source"
new const zclass_clawmodel[] = "v_knife_zombie.mdl"
const zclass_health = 2430
const zclass_speed = 220
const Float:zclass_gravity = 1.0
const Float:zclass_knockback = 3.0

new g_msgScoreAttrib
new g_zclass_assassin

public plugin_init() 
{
    register_plugin(PLUGIN, VERSION, AUTHOR)
    
    register_cvar("zp_zclass_assassin_zombie",VERSION,FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_UNLOGGED|FCVAR_SPONLY)
    
    g_msgScoreAttrib = get_user_msgid("ScoreAttrib")
    
    RegisterHam(Ham_TakeDamage, "player", "fw_PlayerTakeDamage")
}

public plugin_precache()
{
    g_zclass_assassin = zp_register_class(CLASS_ZOMBIE, zclass_name, zclass_info, zclass_model, zclass_clawmodel, 15, zclass_health, zclass_speed, zclass_gravity, zclass_knockback)
}

public zp_user_infected_post(player, infector)
{
    if (zp_get_user_zombie_class(player) == g_zclass_assassin)
    {
        client_print(player, print_chat, "[ZP] You are now Assassin Zombie")
        client_print(player, print_chat, "[ZP] You can chose between infect and kill people")
    }
}

public zp_user_infect_attempt(victim, infector, nemesis)
{
    if (is_user_alive(infector) && zp_get_user_zombie_class(infector) == g_zclass_assassin)
    {
        new button = pev(infector, pev_button)
        
        if (button & IN_ATTACK2)
        {
            ExecuteHamB(Ham_Killed, victim, infector, 0)
        }
        else 
            return PLUGIN_CONTINUE
        
        return ZP_PLUGIN_HANDLED
    }
    
    return PLUGIN_CONTINUE
}

public fw_PlayerTakeDamage(id, inflictor, attacker, Float:damage, damage_type)
{
    if (!is_user_alive(id) || !is_user_bot(id) || !zp_get_user_zombie(id))
        return HAM_IGNORED
    
    if (zp_get_user_zombie_class(id) != g_zclass_assassin)
        return HAM_IGNORED

    new attacker_name[32]
    new button = pev(attacker, pev_button)
    new GetMaxPlayers = get_maxplayers()
    new GetHumanCount = zp_get_human_count()
    
    get_user_name(attacker, attacker_name, 31)
    
    if (!zp_is_swarm_round() || !zp_is_plague_round() || !zp_is_survivor_round() || !zp_is_nemesis_round() || GetHumanCount == GetMaxPlayers)
    {
        if (button & IN_ATTACK2)
        {    
            if (zp_get_user_zombie_class(attacker) == g_zclass_assassin)
            {
                FixDeadAttrib(id)
                UpdateScoreBoard(id, attacker)
                client_print(id, print_chat, "[ZP] Hmm looks like %s didn't like you and decided to kill You!", attacker_name)
            
                return HAM_SUPERCEDE
            }
        }
    }
        
    return HAM_SUPERCEDE
}
    
public FixDeadAttrib(id)
{
    message_begin(MSG_BROADCAST, g_msgScoreAttrib)
    write_byte(id)
    write_byte(DEAD_DYING)
    message_end()
}

public UpdateScoreBoard(victim, attacker)
{
    new victim_frags = get_user_frags(victim) + 0
    new attacker_frags = get_user_frags(attacker) + 1
    new attacker_money = cs_get_user_money(attacker) + 0
    
    set_pev(victim, pev_frags, float(victim_frags))
    set_pev(attacker, pev_frags, float(attacker_frags))
    cs_set_user_money(attacker, attacker_money, 1)
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1049\\ f0\\ fs16 \n\\ par }
*/ 