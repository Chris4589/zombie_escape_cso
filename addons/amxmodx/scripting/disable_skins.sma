#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <zombie_escape_v1>

const OFFSET_WEAPONOWNER = 41
const OFFSET_LINUX_WEAPONS = 4 // weapon offsets are only 4 steps higher on Linux

new const WEAPONENTNAMES[][] = { "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
			"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
			"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
			"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
			"weapon_ak47", "weapon_knife", "weapon_p90" }

public plugin_init()
{
	register_plugin("Disable Skins Humans", "1.0", "Hypnotize");

	for (new i = 1; i < sizeof WEAPONENTNAMES; i++)
		if (WEAPONENTNAMES[i][0]) RegisterHam(Ham_Item_Deploy, WEAPONENTNAMES[i], "fw_Item_Deploy_Post", 1)
}

public fw_Item_Deploy_Post(weapon_ent)
{
	static id
	id = fm_cs_get_weapon_ent_owner(weapon_ent)

	if(zp_get_class(id) < ZOMBIE && !enable_skins(id))
		return;
}
// Get Weapon Entity's Owner
stock fm_cs_get_weapon_ent_owner(ent)
{
	return get_pdata_cbase(ent, OFFSET_WEAPONOWNER, OFFSET_LINUX_WEAPONS);
}