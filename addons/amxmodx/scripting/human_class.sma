#include <amxmodx>
#include <zombieplague>

new const hclass1_name[] = { "Hatsune" }
new const hclass1_info[] = { "=Balanced=" }
new const hclass1_model[] = { "hatsuneMiku" }//cso_dorothy
const hclass1_health = 100
const hclass1_speed = 330
const Float:hclass1_gravity = 1.0
const Float:hclass1_knockback = 1.0

new const hclass2_name[] = { "Alice" }
new const hclass2_info[] = { "HP-- Speed++ Knockback++" }
new const hclass2_model[] = { "cso_flora" }
const hclass2_health = 200
const hclass2_speed = 340
const Float:hclass2_gravity = 1.0

new const hclass3_name[] = { "Girl++" }
new const hclass3_info[] = { "HP- Jump+ Knockback+" }
new const hclass3_model[] = { "cso_player" }
const hclass3_health = 300
const hclass3_speed = 350
const Float:hclass3_gravity = 0.5

public plugin_precache()
{
	register_plugin("[ZP] Default Human Classes", "4.3", "Hypnotize")
	
	zp_register_class(CLASS_HUMAN, hclass1_name, hclass1_info, hclass1_model, "default", 1, 0, ADMIN_ALL, hclass1_health, 15, hclass1_speed, hclass1_gravity, hclass1_knockback)
	zp_register_class(CLASS_HUMAN, hclass2_name, hclass2_info, hclass2_model, "default", 3, 0, ADMIN_ALL, hclass2_health, 30, hclass2_speed, hclass2_gravity, hclass1_knockback)
	zp_register_class(CLASS_HUMAN, hclass3_name, hclass3_info, hclass3_model, "default", 5, 0, ADMIN_ALL, hclass3_health, 45, hclass3_speed, hclass3_gravity, hclass1_knockback)
}