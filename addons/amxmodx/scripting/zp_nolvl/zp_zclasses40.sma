#include <amxmodx>
#include <fakemeta>
#include <zombieplague>

new const zclass1_name[] = { "Classic 1" }
new const zclass1_info[] = { "Balanceado" }
new const zclass1_model[] = { "classic1" }
new const zclass1_clawmodel[] = { "clasic_claws.mdl" }
const zclass1_health = 3200
const zclass1_speed = 300
const Float:zclass1_gravity = 1.0
const Float:zclass1_knockback = 3.0

new const zclass2_name[] = { "Classic 2" }
new const zclass2_info[] = { "HP++ Speed++ Knockback++" }
new const zclass2_model[] = { "classic2" }
new const zclass2_clawmodel[] = { "clasic_claws.mdl" }
const zclass2_health = 3600
const zclass2_speed = 320
const Float:zclass2_gravity = 1.0
const Float:zclass2_knockback = 3.0

new const zclass3_name[] = { "HeadCrab" }
new const zclass3_info[] = { "HP++ Jump+ Knockback+" }
new const zclass3_model[] = { "headcrab" }
new const zclass3_clawmodel[] = { "clasic_claws.mdl" }
const zclass3_health = 4200
const zclass3_speed = 300
const Float:zclass3_gravity = 0.75
const Float:zclass3_knockback = 3.0

new const zclass4_name[] = { "Gonome Zombie" }
new const zclass4_info[] = { "HP++ Speed- Knockback--" }
new const zclass4_model[] = { "gonome" }
new const zclass4_clawmodel[] = { "clasic_claws.mdl" }
const zclass4_health = 4800
const zclass4_speed = 300
const Float:zclass4_gravity = 1.0
const Float:zclass4_knockback = 3.0

new const zclass5_name[] = { "Hunter Zombie" }
new const zclass5_info[] = { "HP++ Knockback+" }
new const zclass5_model[] = { "hunter" }
new const zclass5_clawmodel[] = { "clasic_claws.mdl" }
const zclass5_health = 5300
const zclass5_speed = 300
const Float:zclass5_gravity = 1.0
const Float:zclass5_knockback = 3.0


new const zclass6_name[] = { "Fat Zombie" }
new const zclass6_info[] = { "HP++ Knockback--" }
new const zclass6_model[] = { "fat" }
new const zclass6_clawmodel[] = { "clasic_claws.mdl" }
const zclass6_health = 6500
const zclass6_speed = 300
const Float:zclass6_gravity = 1.0
const Float:zclass6_knockback = 2.0


new const zclass7_name[] = { "Assasin Zombie" }
new const zclass7_info[] = { "HP++ Knockback--" }
new const zclass7_model[] = { "assasin" }
new const zclass7_clawmodel[] = { "clasic_claws.mdl" }
const zclass7_health = 8200
const zclass7_speed = 300
const Float:zclass7_gravity = 1.0
const Float:zclass7_knockback = 1.0

public plugin_precache()
{
	register_plugin("[ ZP ] Zombie Classes", "4.3", "Hypnotize");
	
	zp_register_class(CLASS_ZOMBIE, zclass1_name, zclass1_info, zclass1_model, zclass1_clawmodel, 1, 0, ADMIN_ALL, zclass1_health, 0, zclass1_speed, zclass1_gravity, zclass1_knockback)
	zp_register_class(CLASS_ZOMBIE, zclass2_name, zclass2_info, zclass2_model, zclass2_clawmodel, 5, 0, ADMIN_ALL, zclass2_health, 0, zclass2_speed, zclass2_gravity, zclass2_knockback)
	zp_register_class(CLASS_ZOMBIE, zclass3_name, zclass3_info, zclass3_model, zclass3_clawmodel, 8, 0, ADMIN_ALL, zclass3_health, 0, zclass3_speed, zclass3_gravity, zclass3_knockback)
	zp_register_class(CLASS_ZOMBIE, zclass4_name, zclass4_info, zclass4_model, zclass4_clawmodel, 14, 0, ADMIN_ALL, zclass4_health, 0, zclass4_speed, zclass4_gravity, zclass4_knockback)
	zp_register_class(CLASS_ZOMBIE, zclass5_name, zclass5_info, zclass5_model, zclass5_clawmodel, 18, 0, ADMIN_ALL, zclass5_health, 0, zclass5_speed, zclass5_gravity, zclass5_knockback)
	zp_register_class(CLASS_ZOMBIE, zclass6_name, zclass6_info, zclass6_model, zclass6_clawmodel, 22, 0, ADMIN_ALL, zclass6_health, 0, zclass6_speed, zclass6_gravity, zclass6_knockback)
	zp_register_class(CLASS_ZOMBIE, zclass7_name, zclass7_info, zclass7_model, zclass7_clawmodel, 25, 0, ADMIN_ALL, zclass7_health, 0, zclass7_speed, zclass7_gravity, zclass7_knockback)
}
