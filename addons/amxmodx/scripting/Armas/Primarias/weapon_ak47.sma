/* Script generated by Pawn Studio */

#include <amxmodx>
#include <fun>
#include <cstrike>

enum{ PRIMARIA=1, SECUNDARIA, KNIFE, ESPECIALES, MAX_ARMS };
native zp_arma(const name[], level, reset, categoria, admin, const adm_tipo[]);
forward dar_arma(id, item);

new g_item;

public plugin_init()
{
	register_plugin("Weapon", "0.1", "Hypnotize")
	// Add your own code here
	g_item = zp_arma("AK-47", 4, 0, PRIMARIA, ADMIN_ALL, "");
}

public dar_arma(id, item)
{
	if( g_item != item )
		return;

	give_item(id, "weapon_ak47");
	cs_set_user_bpammo(id, CSW_AK47, 99);
	return;
}	