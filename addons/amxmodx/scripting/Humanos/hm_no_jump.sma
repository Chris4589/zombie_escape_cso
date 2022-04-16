#include <amxmodx>
#include <zombieplague>

new const hclass3_name[] = { "Cristian NJ" }
new const hclass3_info[] = { "Anti JumpBomb" }
new const hclass3_model[] = { "cso_cristian" }
const hclass3_health = 300
const hclass3_speed = 360
const Float:hclass3_gravity = 0.5

new g_iJumper;

public plugin_precache()
{
	register_plugin("[ZP] Human: No jump", "4.3", "Hypnotize")
	
	g_iJumper =zp_register_class(CLASS_HUMAN, hclass3_name, hclass3_info, hclass3_model, "default", 1, 7, ADMIN_ALL, hclass3_health, 45, hclass3_speed, hclass3_gravity, 0.0)
}
public zp_user_humanized_post(id, survivor)
{
	zp_set_no_jump(id, 0);
	if( zp_get_user_human_class(id) == g_iJumper && zp_get_class(id) < SURVIVOR )
		zp_set_no_jump(id, 1);
}

public zp_user_infected_post(id, infector, nemesis)
	zp_set_no_jump(id, 0);