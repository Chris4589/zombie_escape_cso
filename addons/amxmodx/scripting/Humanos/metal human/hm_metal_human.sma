#include <amxmodx>
#include <zombie_escape_v1>

new const hclass1_name[] = { "Metal Human" }
new const hclass1_info[] = { "+250 Armadura" }
new const hclass1_model[] = { "ze_mhuman" }
const hclass1_health = 200
const hclass1_speed = 340
const Float:hclass1_gravity = 0.75
const Float:hclass1_knockback = 1.0

public plugin_precache()
{
	register_plugin("[ZP] Human: Metal Human", "4.3", "Hypnotize")
	zp_register_class(CLASS_HUMAN, hclass1_name, hclass1_info, hclass1_model, "default", 0, 3, ADMIN_ALL, hclass1_health, 250, hclass1_speed, hclass1_gravity, hclass1_knockback)
}