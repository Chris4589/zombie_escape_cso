#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <cstrike>
#include <fun>
#include <zombie_escape_v1>

new g_iKnife[ 33 ], g_iMaxplayers, g_item, cvar_knife_dmg;

new const szKnife_v[] = "v_horse_axe";

public plugin_init()
{
	register_plugin("Knife Horse Axe", "1.0", "Hypnotize");
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "ham_KnifeDeployPost", true);
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage");
	register_logevent( "event_round_start", 2, "1=Round_Start" );

	cvar_knife_dmg = register_cvar("zp_knife_horse", "200")

	g_iMaxplayers = get_maxplayers();

	g_item = zp_arma( "Horse Axe", 10, 0, KNIFE, ADMIN_ALL, "" );
}
public dar_arma(id, item)
{
	if( g_item != item )
		return;

	g_iKnife[ id ] = 1;		
	give_item(id, "weapon_knife");
	engclient_cmd(id, "weapon_knife");
	return;
}	

public plugin_precache()
{
  	static buffer[128];
	
	formatex( buffer, charsmax( buffer ), "models/zombie_plague/%s.mdl", szKnife_v);
	precache_model(buffer);
}
public event_round_start()
{
	for(new i = 1; i <= g_iMaxplayers; ++i)
	{
		g_iKnife[ i ] = 0;
	}
}
public fw_TakeDamage(victim, inflictor, attacker, Float:damage, damage_type)
{
	if(!is_user_alive(attacker))
		return HAM_IGNORED
		
	if( attacker == victim )
		return HAM_IGNORED;

	if( get_user_team(attacker) == get_user_team(victim) )
		return HAM_IGNORED;

	if( zp_get_class(attacker) >= SURVIVOR )
		return HAM_IGNORED;

	if (!g_iKnife[attacker])
		return HAM_IGNORED;

	if(get_user_weapon(attacker) == CSW_KNIFE)
	{
		damage = get_pcvar_float(cvar_knife_dmg);
		SetHamParamFloat(4, damage);
	}
	return HAM_HANDLED;
}
public ham_KnifeDeployPost(wpn) 
{
    static id; id = get_weapon_ent_owner(wpn);
    
    if (!pev_valid(id) || !is_user_alive( id ) || !g_iKnife[ id ] || zp_get_class(id) >= ZOMBIE) 
    	return;
    
    static WeaponID; WeaponID = cs_get_weapon_id(wpn); 
    
    static buffer[128];
    
    if(WeaponID == CSW_KNIFE)
    {
        formatex( buffer, charsmax( buffer ), "models/zombie_plague/%s.mdl", szKnife_v);
        set_pev(id, pev_viewmodel2, buffer );
    }
}
stock get_weapon_ent_owner(ent)
{
    if (pev_valid(ent) != 2)
        return -1;
    
    return get_pdata_cbase(ent, 41, 4);
} 