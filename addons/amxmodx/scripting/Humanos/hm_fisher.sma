#include <amxmodx>
#include <zombieplague>

new const hclass1_name[] = { "Sam Fisher" }
new const hclass1_info[] = { "Ve al ghost" }
new const hclass1_model[] = { "fisher_cso" }
const hclass1_health = 230//vida
const hclass1_speed = 340
const Float:hclass1_gravity = 1.0
const Float:hclass1_knockback = 1.0

new g_iFisher;

public plugin_precache()
{
	register_plugin("[ZP] Human: Fisher", "4.3", "Hypnotize")
	
	g_iFisher = zp_register_class(CLASS_HUMAN, hclass1_name, hclass1_info, hclass1_model, "default", 1, 3, ADMIN_ALL, hclass1_health, 130, hclass1_speed, hclass1_gravity, hclass1_knockback)
}

public zp_user_humanized_post(id, survivor)
{
	zp_set_fisher(id, 0);

	if( zp_get_user_human_class(id) == g_iFisher && zp_get_class(id) < SURVIVOR)
        zp_set_fisher(id, 1);
}

public zp_user_infected_post(id, infector, nemesis)
	zp_set_fisher(id, 0);