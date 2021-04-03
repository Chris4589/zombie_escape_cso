/*================================================================================
	
	-----------------------------------
	-*- [ZP] Default Zombie Classes -*-
	-----------------------------------
	
	~~~~~~~~~~~~~~~
	- Description -
	~~~~~~~~~~~~~~~
	
	This plugin adds the default zombie classes to Zombie Plague.
	Feel free to modify their attributes to your liking.
	
	Note: If zombie classes are disabled, the first registered class
	will be used for all players (by default, Classic Zombie).
	
================================================================================*/

#include <amxmodx>
#include <fakemeta>
#include <zombieplague>

/*================================================================================
 [Plugin Customization]
=================================================================================*/

// Classic Zombie Attributes
new const zclass1_name[] = { "Healer" }
new const zclass1_info[] = { "=Balanced=" }
new const zclass1_model[] = { "healer" }
new const zclass1_clawmodel[] = { "v_claw_psycho.mdl" }
const zclass1_health = 9000
const zclass1_speed = 300
const Float:zclass1_gravity = 1.0
const Float:zclass1_knockback = 3.0

// Raptor Zombie Attributes
new const zclass2_name[] = { "Raptor Speed" }
new const zclass2_info[] = { "HP-- Speed++ Knockback++" }
new const zclass2_model[] = { "speed" }
new const zclass2_clawmodel[] = { "v_claw_voodoo.mdl" }
const zclass2_health = 7200
const zclass2_speed = 320
const Float:zclass2_gravity = 1.0
const Float:zclass2_knockback = 3.0

// Poison Zombie Attributes
new const zclass3_name[] = { "Jump Zombie" }
new const zclass3_info[] = { "HP- Jump+ Knockback+" }
new const zclass3_model[] = { "jump" }
new const zclass3_clawmodel[] = { "v_knife_tank_zombi.mdl" }
const zclass3_health = 8200
const zclass3_speed = 300
const Float:zclass3_gravity = 0.75
const Float:zclass3_knockback = 3.0

// Big Zombie Attributes
new const zclass4_name[] = { "Big Zombie" }
new const zclass4_info[] = { "HP++ Speed- Knockback--" }
new const zclass4_model[] = { "big" }
new const zclass4_clawmodel[] = { "v_claw_heavy.mdl" }
const zclass4_health = 7700
const zclass4_speed = 300
const Float:zclass4_gravity = 1.0
const Float:zclass4_knockback = 3.0

// Leech Zombie Attributes
new const zclass5_name[] = { "Leech Zombie" }
new const zclass5_info[] = { "HP- Knockback+ Leech++" }
new const zclass5_model[] = { "climb" }
new const zclass5_clawmodel[] = { "zp_v_knife_poison.mdl" }
const zclass5_health = 7300
const zclass5_speed = 300
const Float:zclass5_gravity = 1.0
const Float:zclass5_knockback = 3.0
const zclass5_infecthp = 200 // extra hp for infections

/*============================================================================*/

// Class IDs
new g_zclass_leech

// Zombie Classes MUST be registered on plugin_precache
public plugin_precache()
{
	register_plugin("[ZP] Default Zombie Classes", "4.3", "MeRcyLeZZ")
	
	// Register all classes
	zp_register_class(CLASS_ZOMBIE, zclass1_name, zclass1_info, zclass1_model, zclass1_clawmodel, 0, 0, ADMIN_ALL, zclass1_health, 0, zclass1_speed, zclass1_gravity, zclass1_knockback)
	zp_register_class(CLASS_ZOMBIE, zclass2_name, zclass2_info, zclass2_model, zclass2_clawmodel, 0, 0, ADMIN_ALL, zclass2_health, 0, zclass2_speed, zclass2_gravity, zclass2_knockback)
	zp_register_class(CLASS_ZOMBIE, zclass3_name, zclass3_info, zclass3_model, zclass3_clawmodel, 0, 0, ADMIN_ALL, zclass3_health, 0, zclass3_speed, zclass3_gravity, zclass3_knockback)
	zp_register_class(CLASS_ZOMBIE, zclass4_name, zclass4_info, zclass4_model, zclass4_clawmodel, 0, 0, ADMIN_ALL, zclass4_health, 0, zclass4_speed, zclass4_gravity, zclass4_knockback)
	g_zclass_leech = zp_register_class(CLASS_ZOMBIE, zclass5_name, zclass5_info, zclass5_model, zclass5_clawmodel, 0, 0, ADMIN_ALL, zclass5_health, 0, zclass5_speed, zclass5_gravity, zclass5_knockback)
}

// User Infected forward
public zp_user_infected_post(id, infector)
{
	// If attacker is a leech zombie, gets extra hp
	if (zp_get_user_zombie_class(infector) == g_zclass_leech)
		set_pev(infector, pev_health, float(pev(infector, pev_health) + zclass5_infecthp))
}
