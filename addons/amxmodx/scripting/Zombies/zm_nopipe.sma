#include <amxmodx>
#include <zombieplague>

new const zclass1_name[] = { "Chinesse Pipe" }
new const zclass1_info[] = { "Anti Pipe" }
new const zclass1_model[] = { "ev_china" }
new const zclass1_clawmodel[] = { "v_claw_china.mdl" }
const zclass1_health = 7000
const zclass1_speed = 300
const Float:zclass1_gravity = 1.0
const Float:zclass1_knockback = 3.0

new nopipe;

public plugin_precache()
{
	register_plugin("[ZP] Zombie No Pipe", "4.3", "Hypnotize");
	nopipe = zp_register_class(CLASS_ZOMBIE, zclass1_name, zclass1_info, zclass1_model, zclass1_clawmodel, 8, 1, ADMIN_ALL, zclass1_health, 0, zclass1_speed, zclass1_gravity, zclass1_knockback)
}
public zp_user_infected_post(id, infector, nemesis)
{
	zp_set_nopipe(id, 0);
	if(zp_get_class(id) >= ZOMBIE && zp_get_class(id) < NEMESIS && zp_get_user_zombie_class(id) == nopipe)
		zp_set_nopipe(id, 1);
}

public zp_user_humanized_post(id, survivor)
	zp_set_nopipe(id, 0);