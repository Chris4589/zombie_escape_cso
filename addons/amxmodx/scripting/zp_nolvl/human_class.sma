#include <amxmodx>
#include <zombieplague>

new const hclass1_name[] = { "Soldado" }
new const hclass1_info[] = { "100HP" }
new const hclass1_model[] = { "alice2" }
const hclass1_health = 100
const hclass1_speed = 330
const Float:hclass1_gravity = 1.0
const Float:hclass1_knockback = 1.0

new const hclass2_name[] = { "Teniente" }
new const hclass2_info[] = { "200HP" }
new const hclass2_model[] = { "choijiyoon2" }
const hclass2_health = 200
const hclass2_speed = 340
const Float:hclass2_gravity = 1.0

new const hclass3_name[] = { "Idol" }
new const hclass3_info[] = { "Jump+250HP" }
new const hclass3_model[] = { "idolgirl" }
const hclass3_health = 250
const hclass3_speed = 350
const Float:hclass3_gravity = 0.5

new const hclass4_name[] = { "Yuri" }
new const hclass4_info[] = { "HP+300 Speed++" }
new const hclass4_model[] = { "yuri2" }
const hclass4_health = 300
const hclass4_speed = 340
const Float:hclass4_gravity = 1.0

new const hclass5_name[] = { "Pirate" }
new const hclass5_info[] = { "HP+400" }
new const hclass5_model[] = { "pirategirl2" }
const hclass5_health = 400
const hclass5_speed = 340
const Float:hclass5_gravity = 1.0

new const hclass6_name[] = { "Natasha" }
new const hclass6_info[] = { "HP+500" }
new const hclass6_model[] = { "cso_player" }
const hclass6_health = 500
const hclass6_speed = 340
const Float:hclass6_gravity = 1.0

public plugin_precache()
{
	register_plugin("[ZP] Default Human Classes", "4.3", "Hypnotize")
	
	zp_register_class(CLASS_HUMAN, hclass1_name, hclass1_info, hclass1_model, "default",1,  0,ADMIN_ALL, hclass1_health, 15, hclass1_speed, hclass1_gravity, hclass1_knockback)
	zp_register_class(CLASS_HUMAN, hclass2_name, hclass2_info, hclass2_model, "default",5,  0,ADMIN_ALL, hclass2_health, 30, hclass2_speed, hclass2_gravity, hclass1_knockback)
	zp_register_class(CLASS_HUMAN, hclass3_name, hclass3_info, hclass3_model, "default",9,  0,ADMIN_ALL, hclass3_health, 45, hclass3_speed, hclass3_gravity, hclass1_knockback)
	zp_register_class(CLASS_HUMAN, hclass4_name, hclass4_info, hclass4_model, "default",12, 0, ADMIN_ALL, hclass4_health, 45, hclass4_speed, hclass4_gravity, hclass1_knockback)
	zp_register_class(CLASS_HUMAN, hclass5_name, hclass5_info, hclass5_model, "default",17, 0, ADMIN_ALL, hclass5_health, 45, hclass5_speed, hclass5_gravity, hclass1_knockback)
	zp_register_class(CLASS_HUMAN, hclass6_name, hclass6_info, hclass6_model, "default",22, 0, ADMIN_ALL, hclass6_health, 45, hclass6_speed, hclass6_gravity, hclass1_knockback)
}