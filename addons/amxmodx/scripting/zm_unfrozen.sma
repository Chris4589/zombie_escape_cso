#include <amxmodx>
#include <zombieplague>

new const zclass1_name[] = { "unfrozen zombie" }
new const zclass1_info[] = { "No te congelan" }
new const zclass1_model[] = { "cosspeed1_host" }
new const zclass1_clawmodel[] = { "v_knife_cosspeed1.mdl" }
const zclass1_health = 7000
const zclass1_speed = 300
const Float:zclass1_gravity = 1.0
const Float:zclass1_knockback = 3.0

new unfrost;

public plugin_precache()
{
	register_plugin("[ZP] Zombie UnFrozen", "4.3", "Hypnotize");
	unfrost = zp_register_class(CLASS_ZOMBIE, zclass1_name, zclass1_info, zclass1_model, zclass1_clawmodel, 5, 1, ADMIN_ALL, zclass1_health, 0, zclass1_speed, zclass1_gravity, zclass1_knockback)
}
public zp_user_infected_post(id, infector, nemesis)
{
	zp_set_unfrozen(id, 0);
	if(zp_get_class(id) >= ZOMBIE && zp_get_class(id) < NEMESIS && zp_get_user_zombie_class(id) == unfrost)
		zp_set_unfrozen(id, 1);
}

public zp_user_humanized_post(id, survivor)
	zp_set_unfrozen(id, 0);