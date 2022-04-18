#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>
#include <zombie_escape_v1>

new const hclass_name[] = "Cheto" // name
new const hclass_info[] = "Chain++" // description
new const hclass_model[] = "ze_cheto" // model

const hclass_health = 300 // health
const hclass_speed = 310 // speed

const Float:hclass_gravity = 0.8 // gravity
const Float:hclass_knockback = 2.0 // knockback

new g_aspirante, g_Used[33];

public plugin_precache()
{
    register_plugin("[ ZP ] Human: Aspirante Sirio","1.0", "Hypnotize");
    register_logevent("logevent_round_start",2, "1=Round_Start")
    g_aspirante = zp_register_class(CLASS_HUMAN, hclass_name, hclass_info, hclass_model, "default", 15, 0, ADMIN_ALL, hclass_health, 60, hclass_speed, hclass_gravity, hclass_knockback);
}

public client_putinserver(id)
	g_Used[id] = 0;

public logevent_round_start()
	for(new i; i <= 32 ; ++i)
		g_Used[i] = 0;

public dar_arma(id, item)
{
	if(!is_user_alive(id) || zp_get_class(id) >= SURVIVOR || g_Used[id])
		return;

	if(zp_get_user_human_class(id) != g_aspirante)
		return;

	if (user_has_weapon(id, CSW_HEGRENADE))
		cs_set_user_bpammo(id, CSW_HEGRENADE, cs_get_user_bpammo(id, CSW_HEGRENADE) + 3);
	else
	{
		give_item(id, "weapon_hegrenade");
		cs_set_user_bpammo(id, CSW_HEGRENADE, 3);
	}
	zp_set_chain(id, 3);
	g_Used[id] = 1;
	client_print_color(id, print_team_grey, "3+ Chains por aspirar a sirio.")
}