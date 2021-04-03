#include <amxmodx>
#include <zombieplague>

new const hclass1_name[] = { "Mei Deathrun" }
new const hclass1_info[] = { "Run with G" }
new const hclass1_model[] = { "cso_mei" }
const hclass1_health = 180
const hclass1_speed = 355
const Float:hclass1_gravity = 0.9
const Float:hclass1_knockback = 1.0

new g_iMei;

public plugin_precache()
{
	register_plugin("[ZP] Human: Mei;", "4.3", "Hypnotize")
	register_clcmd("drop", "cmdRun");
	g_iMei = zp_register_class(CLASS_HUMAN, hclass1_name, hclass1_info, hclass1_model, "default", 1, 2, ADMIN_ALL, hclass1_health, 65, hclass1_speed, hclass1_gravity, hclass1_knockback)
}
public cmdRun(id)
{
	if(zp_get_user_human_class(id) == g_iMei && zp_get_class(id) < SURVIVOR)
	{
		zp_set_boost(id);
	}
}
public zp_user_humanized_post(id, survivor)
{
	if(zp_get_user_human_class(id) == g_iMei && zp_get_class(id) < SURVIVOR)
	{
		client_print(id, print_chat, "Presiona G para sacar tu HABILIDAD");
		client_print(id, print_chat, "Presiona G para sacar tu HABILIDAD");
		client_print(id, print_chat, "Presiona G para sacar tu HABILIDAD");
	}
}
