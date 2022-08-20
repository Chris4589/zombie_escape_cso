/* Script generated by Pawn Studio */

#include <amxmodx>
#include <fun>
#include <cstrike>
#include <hamsandwich>
#include <reapi>

#define is_valid_player_alive(%0) (1 <= %0 <= MAX_PLAYERS && is_user_alive(%0))
#define rg_get_weapon_id(%0) get_member(get_member(get_member(%0, m_pPlayer), m_pActiveItem), m_iId)

enum{ PRIMARIA=1, SECUNDARIA, KNIFE, ESPECIALES, MAX_ARMS };
native zp_arma(const name[], level, reset, categoria, admin, const adm_tipo[]);
forward dar_arma(id, item);
//native enable_skins(id)

#define MODEL_V "models/zp/v_zp_aug.mdl"
#define MODEL_P "models/zp/p_zp_aug.mdl"

#define NOMBRE "AUG"
#define CATEGORIA PRIMARIA
#define CSW CSW_AUG
#define weapon "weapon_aug"

new g_item, bool:g_hasgun[33];
new g_maxplayers;


public plugin_init()
{
	register_plugin("Weapon", "0.1", "Hypnotize")
	// Add your own code here
	g_item = zp_arma(NOMBRE, 3, 0, CATEGORIA, ADMIN_ALL, "");

	RegisterHookChain( RG_CBasePlayerWeapon_DefaultDeploy,  "@fw_Deploy_Pre",  .post = false );
	RegisterHam(Ham_Spawn, "player", "fw_playerspawn_post", 1)
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0")

	g_maxplayers = get_maxplayers() 
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
}


public fw_playerspawn_post(id)
{
	g_hasgun[id] = false;
}


@fw_Deploy_Pre( const entity, sViewModel[], sWeaponModel[], iAnim, sAnimExt[], skiplocal )
{
	if( !is_entity( entity ) )
        return HC_CONTINUE;

   	new id = get_member( entity, m_pPlayer )
   	if(!g_hasgun[id])
		return HC_CONTINUE;
    
	if( is_valid_player_alive( id ) && rg_get_weapon_id(entity) == CSW)
	{

		SetHookChainArg(2, ATYPE_STRING, MODEL_V)
		SetHookChainArg(3, ATYPE_STRING, MODEL_P)
        	
    }
        
	return HC_CONTINUE;
}

public dar_arma(id, item)
{
	if( g_item != item )
		return;
	g_hasgun[id] = true;
	give_item(id, weapon);
	cs_set_user_bpammo(id, CSW, 99);
	return;
}	

public Event_NewRound()
{
	for (new id = 1; id <= g_maxplayers; id++)
	{
		g_hasgun[id] = false;
	}
}

public zp_user_infected_pre(id, infector, nemesis)
{
	g_hasgun[id] = false;
}

public zp_user_humanized_pre(id, survivor)
{
	g_hasgun[id] = false;
}