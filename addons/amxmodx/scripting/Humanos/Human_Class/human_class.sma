#include <amxmodx>
#include <zombie_escape_v1>

new const hclass1_name[] = { "Marco" }
new const hclass1_info[] = { "=Balanced=" }
new const hclass1_model[] = { "ze_marco" }//cso_dorothy
const hclass1_health = 100
const hclass1_speed = 330
const Float:hclass1_gravity = 1.0
const Float:hclass1_knockback = 1.0

new const hclass2_name[] = { "Michael" }
new const hclass2_info[] = { "HP-- Speed++ Knockback++" }
new const hclass2_model[] = { "ze_micol" }
const hclass2_health = 125
const hclass2_speed = 340
const Float:hclass2_gravity = 0.95

new const hclass3_name[] = { "Emma" }
new const hclass3_info[] = { "HP- Jump+ Knockback+" }
new const hclass3_model[] = { "ze_emma" }
const hclass3_health = 150
const hclass3_speed = 350
const Float:hclass3_gravity = 0.90

new const hclass4_name[] = { "Alien" }
new const hclass4_info[] = { "Jump++ HP+ Armor+" }
new const hclass4_model[] = { "ze_aliens" }
const hclass4_health = 150
const hclass4_speed = 350
const Float:hclass4_gravity = 0.90

public plugin_precache()
{
	register_plugin("[ZP] Default Human Classes", "4.3", "Hypnotize")
	
	zp_register_class(CLASS_HUMAN, hclass1_name, hclass1_info, hclass1_model, "default", 1, 0, ADMIN_ALL, hclass1_health, 15, hclass1_speed, hclass1_gravity, hclass1_knockback)
	zp_register_class(CLASS_HUMAN, hclass2_name, hclass2_info, hclass2_model, "default", 3, 0, ADMIN_ALL, hclass2_health, 30, hclass2_speed, hclass2_gravity, hclass1_knockback)
	zp_register_class(CLASS_HUMAN, hclass3_name, hclass3_info, hclass3_model, "default", 6, 0, ADMIN_ALL, hclass3_health, 45, hclass3_speed, hclass3_gravity, hclass1_knockback)
	zp_register_class(CLASS_HUMAN, hclass4_name, hclass4_info, hclass4_model, "default", 0, 1, ADMIN_ALL, hclass4_health, 100, hclass4_speed, hclass4_gravity, hclass1_knockback)
}