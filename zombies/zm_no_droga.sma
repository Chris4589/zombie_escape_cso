#include <amxmodx>
#include <fakemeta>
#include <zombieplague>

new const zclass_name[] = { "Psycho" }
new const zclass_info[] = { "Anti droga" }
new const zclass4_model[] = { "ev_psycho_host" }

const zclass_health = 7000
const zclass_speed = 270
const Float:zclass_gravity = 0.7
const Float:zclass_knockback = 1.0

new g_zclass_jump;

public plugin_precache()
{
	register_plugin("[ ZP ] Zombie Jumper x2", "1.0", "Hypnotize");
	g_zclass_jump = zp_register_class(CLASS_ZOMBIE, zclass_name, zclass_info, zclass4_model, "v_claw_psycho.mdl", 11, 1, ADMIN_ALL, zclass_health, 0, zclass_speed, zclass_gravity, zclass_knockback);
}


public zp_user_infected_post(id, infector, nemesis)
{
    zp_no_droga(id, 0);
    
    if(zp_get_user_zombie_class(id) == g_zclass_jump && zp_get_class(id) < NEMESIS)
    	zp_no_droga(id, 1);
}

public zp_user_humanized_post(id, survivor)
	zp_no_droga(id, 0);
