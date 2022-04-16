#include <amxmodx>
#include <fakemeta>
#include <engine>

#define PLUGIN "Precache Manager"
#define VERSION "1.0"
#define AUTHOR "Sneaky.amxx"

new const g_szPrecacheList[ ][ ] =
{
    "sprites/WXplo1.spr",
	//"sprites/steam1.spr",
	//"sprites/bubble.spr",
	//"sprites/blood.spr",
	//"sprites/smokepuff.spr",
	//"sprites/eexplo.spr",
	"sprites/fexplo.spr",
	"sprites/fexplo1.spr",
	"sprites/b-tele1.spr",
	"sprites/c-tele1.spr",
	"sprites/ledglow.spr",
	"sprites/laserdot.spr",
	"sprites/explode1.spr",
    "models/player/arctic/arctic.mdl",
    "models/player/gsg9/gsg9.mdl",
    "models/player/guerilla/guerilla.mdl",
    //"models/player/leet/leet.mdl",
    "models/player/sas/sas.mdl",
    "models/shield/p_shield_deagle.mdl",
    "models/shield/p_shield_flashbang.mdl",
    "models/shield/p_shield_hegrenade.mdl",
    "models/shield/p_shield_glock18.mdl",
    "models/shield/p_shield_p228.mdl",
    "models/shield/p_shield_smokegrenade.mdl",
    "models/shield/p_shield_usp.mdl",
    "models/shield/p_shield_fiveseven.mdl",
    "models/shield/p_shield_knife.mdl",
    "models/shield/v_shield_deagle.mdl",
    "models/shield/v_shield_flashbang.mdl",
    "models/shield/v_shield_hegrenade.mdl",
    "models/shield/v_shield_glock18.mdl",
    "models/shield/v_shield_p228.mdl",
    "models/shield/v_shield_smokegrenade.mdl",
    "models/shield/v_shield_usp.mdl",
    "models/shield/v_shield_fiveseven.mdl",
    "models/shield/v_shield_knife.mdl",
    "models/hostage.mdl",
    "models/w_battery.mdl",
    "models/w_thighpack.mdl",
    "models/w_antidote.mdl", 
    "models/w_security.mdl",
    "models/w_longjump.mdl",
    "models/w_backpack.mdl",
    "models/v_backpack.mdl",
    "models/p_backpack.mdl"
}

new const UnPrecache_SoundList[ ][] =
{
	"items/suitcharge1.wav",
	"items/suitchargeno1.wav",
	"items/suitchargeok1.wav",
	"common/wpn_hudoff.wav",
	"common/wpn_hudon.wav",
	"common/wpn_moveselect.wav",
	"common/wpn_select.wav",
	"common/wpn_denyselect.wav",
	"items/9mmclip1.wav",
	"items/gunpickup2.wav",
	"player/geiger6.wav",
	"player/geiger5.wav",
	"player/geiger4.wav",
	"player/geiger3.wav",
	"player/geiger2.wav",
	"player/geiger1.wav  ",
	"weapons/bullet_hit1.wav",
	"weapons/bullet_hit2.wav",
	"items/weapondrop1.wav",
	"weapons/generic_reload.wav",
	"sprites/smoke.spr",
	"buttons/bell1.wav",
	"buttons/blip1.wav",
	"buttons/blip2.wav",
	"buttons/button11.wav",
	"buttons/latchunlocked2.wav",
	"buttons/lightswitch2.wav",
	"ambience/quail1.wav",
	"events/tutor_msg.wav",
	"events/enemy_died.wav",
	"events/friend_died.wav",
	"events/task_complete.wav",
	"weapons/awp_deploy.wav ",
	"weapons/awp_clipin.wav",
	"weapons/awp_clipout.wav",
	"weapons/ak47_clipout.wav",
	"weapons/ak47_clipin.wav",
	"weapons/ak47_boltpull.wav",
	"weapons/aug_clipout.wav",
	"weapons/aug_clipin.wav",
	"weapons/aug_boltpull.wav",
	"weapons/aug_boltslap.wav",
	"weapons/aug_forearm.wav",
	"weapons/c4_click.wav",
	"weapons/c4_beep1.wav",
	"weapons/c4_beep2.wav",
	"weapons/c4_beep3.wav",
	"weapons/c4_beep4.wav",
	"weapons/c4_beep5.wav",
	"weapons/c4_explode1.wav",
	"weapons/c4_plant.wav",
	"weapons/c4_disarm.wav",
	"weapons/boltpull1.wav",
	"weapons/c4_disarmed.wav",
	"weapons/elite_reloadstart.wav",
	"weapons/elite_leftclipin.wav",
	"weapons/elite_clipout.wav",
	"weapons/elite_sliderelease.wav",
	"weapons/elite_rightclipin.wav",
	"weapons/elite_deploy.wav",
	"weapons/famas_clipout.wav",
	"weapons/famas-burst.wav",
	"weapons/famas_clipin.wav",
	"weapons/famas_boltpull.wav",
	"weapons/famas_boltslap.wav",
	"weapons/famas_forearm.wav",
	"weapons/g3sg1_slide.wav",
	"weapons/g3sg1_clipin.wav",
	"weapons/g3sg1_clipout.wav",
	"weapons/galil_clipout.wav",
	"weapons/galil_clipin.wav",
	"weapons/galil_boltpull.wav",
	"weapons/m4a1_clipin.wav",
	"weapons/m4a1_clipout.wav",
	"weapons/m4a1_boltpull.wav",
	"weapons/m4a1_deploy.wav",
	"weapons/m4a1_silencer_on.wav",
	"weapons/m4a1_silencer_off.wav",
	"weapons/m249_boxout.wav",
	"weapons/m249_boxin.wav",
	"weapons/m249_chain.wav",
	"weapons/m249_coverup.wav",
	"weapons/m249_coverdown.wav",
	"weapons/mac10_clipout.wav",
	"weapons/mac10_clipin.wav",
	"weapons/mac10_boltpull.wav",
	"weapons/mp5_clipout.wav",
	"weapons/mp5_clipin.wav",
	"weapons/mp5_slideback.wav",
	"weapons/p90_clipout.wav",
	"weapons/p90_clipin.wav",
	"weapons/p90_boltpull.wav",
	"weapons/p90_cliprelease.wav",
	"weapons/p228_clipout.wav",
	"weapons/p228_clipin.wav",
	"weapons/p228_sliderelease.wav",
	"weapons/de_clipout.wav",
    "weapons/de_clipin.wav",
    "weapons/de_deploy.wav",
	"weapons/p228_slidepull.wav",
	"weapons/scout_bolt.wav",
	"weapons/scout_clipin.wav",
	"weapons/scout_clipout.wav",
	"weapons/sg550_boltpull.wav",
	"weapons/sg550_clipin.wav",
	"weapons/sg550_clipout.wav",
	"weapons/sg552_clipout.wav",
	"weapons/sg552_clipin.wav",
	"weapons/sg552_boltpull.wav",
	"weapons/m3_insertshell.wav",
    "weapons/m3_pump.wav",
	"weapons/ump45_clipout.wav",
	"weapons/ump45_clipin.wav",
	"weapons/ump45_boltslap.wav",
	"weapons/fiveseven_clipout.wav",
    "weapons/fiveseven_clipin.wav",
    "weapons/fiveseven_sliderelease.wav",
    "weapons/fiveseven_slidepull.wav",
	"weapons/usp_unsil-1.wav",
	"weapons/usp_clipout.wav",
	"weapons/usp_clipin.wav",
	"weapons/usp_silencer_on.wav",
	"weapons/usp_silencer_off.wav",
	"weapons/usp_sliderelease.wav",
	"weapons/usp_slideback.wav",
 	"weapons/xbow_hit1.wav",
	"common/npc_step1.wav",
    "common/npc_step2.wav",
    "common/npc_step3.wav",
    "common/npc_step4.wav",
    "radio/locknload.wav",
    "radio/letsgo.wav",
    "radio/moveout.wav",
    "radio/com_go.wav",
    "radio/rescued.wav",
    "radio/rounddraw.wav",
	"items/nvg_on.wav",
    "items/nvg_off.wav",
    "items/equip_nvg.wav",
    "weapons/boltup.wav",
    "weapons/boltdown.wav",
    "weapons/clipout1.wav",
    "weapons/clipin1.wav",
    "weapons/sliderelease1.wav",
    "weapons/slideback1.wav",
    "weapons/357_cock1.wav",
    "weapons/pinpull.wav",
    "weapons/hegrenade-1.wav",
    "weapons/hegrenade-2.wav"
}

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_forward(FM_EmitSound, "OnFw__EmitSound");
}

public plugin_precache()
{
	register_forward(FM_PrecacheModel, "fw_PrecacheModel")
	register_forward(FM_PrecacheSound, "fw_PrecacheSound")
}

public OnFw__EmitSound(const id, const channel, const sample[], const Float:volume, const Float:attn, const flags, const pitch)
{
    for(new i = 0; i < sizeof(UnPrecache_SoundList); ++i)
    {
        if(equal(sample, UnPrecache_SoundList[i]))
            return FMRES_SUPERCEDE;
    }

    return FMRES_IGNORED;
}

public fw_PrecacheModel(const Model[])
{
	for( new i = 0; i < sizeof g_szPrecacheList; i++ )
    {
        if( containi( Model, g_szPrecacheList[ i ] ) != -1 )
        {
            forward_return( FMV_CELL, 0 );
            return FMRES_SUPERCEDE;
        }
    }
	return FMRES_IGNORED;
}


public fw_PrecacheSound(const Sound[])
{
	if(Sound[0] == 'h' && Sound[1] == 'o') 
		return FMRES_SUPERCEDE
	for(new i = 0; i < sizeof(UnPrecache_SoundList); i++)
	{
		if(equal(Sound, UnPrecache_SoundList[i]))
			return FMRES_SUPERCEDE
	}
	return FMRES_HANDLED
}
