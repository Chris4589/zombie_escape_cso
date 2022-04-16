#pragma compress 1

#include amxmodx
#include fakemeta_util
#include hamsandwich
#include xs
#include zombieplague

/* ~ [ Offsets ] ~ */
// Linux extra offsets
#define linux_diff_weapon 4
#define linux_diff_player 5

// CBasePlayerItem
#define m_pPlayer 41

// CBasePlayerWeapon
#define m_flTimeWeaponIdle 48

// CBaseMonster
#define m_LastHitGroup 75
#define m_flNextAttack 83

// CBasePlayer
#define m_flPainShock 108
#define m_pActiveItem 373

/* ~ [ Hands Animations ] ~ */
#define ANIM_TIME_SKILL_TO_SHOOT		30/30.0
#define ANIM_TIME_SKILL_GUARD			75/30.0
#define ANIM_TIME_SKILL_TO_IDLE			31/30.0

enum {
	ANIM_SKILL_START = 8,
	ANIM_SKILL_GUARD1,
	ANIM_SKILL_GUARD2,
	ANIM_SKILL_GUARD3,
	ANIM_SKILL_GUARD4,
	ANIM_SKILL_GUARD5,
	ANIM_SKILL_TO_SHOOT,
	ANIM_SKILL_TO_IDLE
};

/* ~ [ ZClass Settings ] ~ */
#define ZCLASS_NAME						"Yaksha"
#define ZCLASS_INFO						"[Charge] -> G | [Recovery] -> T"
#define ZCLASS_MODEL 					"akshazombi_origin_fix"
#define ZCLASS_CLAWMODEL				"v_knife_zombiaksha_fx.mdl"
#define ZCLASS_BOMBMODEL				"models/zombie_plague/v_zombibomb_aksha_fix.mdl"
#define ZCLASS_HEALTH					5000
#define ZCLASS_SPEED					250	
#define ZCLASS_GRAVITY 					0.75
#define ZCLASS_KNOCKBACK				0.50

enum {
	CHARGE_NONE = 0, // Поглощение готово к использованию
	CHARGE_START, // Поглощение начинается
	CHARGE_ACTIVE, // Поглощает урон
	CHARGE_READY, // Готов к высвобождению энергии
	CHARGE_END // Окончание Поглощения, перезарядка
}

#define FLAME_CLASSNAME					"aksha_fireball"
#define FLAME_MODEL						"sprites/zp43fix5a/ef_aksha_fireball.spr" // Модель огненного шара
#define FLAME_SPRITE_EF					"sprites/zp43fix5a/ef_aksha_fireballdestroy.spr" // Эффект от огненного шара
#define FLAME_SPRITE_EXP				"sprites/zp43fix5a/ef_aksha_fireballexplosion.spr" // Эффект взрыва
#define FLAME_RADIUS					240 // Радиус нанесения урона огненного шара
#define FLAME_DAMAGE					random_num(175, 350) // Урон огненного шара
#define FLAME_DMGTYPE					DMG_NEVERGIB | DMG_SLASH // Тип урона огненного шара

#define CHARGE_RESET					15 // Время перезарядки -> Поглощение

#define RECOVERY_CLASSNAME				"aksha_recovery"
#define RECOVERY_MODEL					"sprites/zp43fix5a/zbt_heal.spr"
#define RECOVERY_HEALTH					2000 // Сколько восстановить здоровья
#define RECOVERY_RESET					15 // Время перезарядки -> Восстановление

#define ANIMATION_SKILL_START			"skill_start" // Начало анимации -> Поглощение
#define ANIMATION_SKILL_LOOP			"skill_loop" // Анимация -> Поглощение
#define ANIMATION_SKILL_SHOOT			"skill_end_toshot" // Анимация высвобождения энергии
#define ANIMATION_SKILL_IDLE			"skill_end_toidle" // Анимация если высвобождение не готово

#define TASKID_RECOVERYRESET			198192031
#define TASKID_CHARGERESET				19819152
#define TASKID_CHARGE					19819157
#define TASKID_DISCHARGE				198191514
#define TASKID_BLOCKVELOCITY			198191519

new const DAMAGE_CHARGE[] = { 255, 510, 765, 1020, 1275 }; // Урон для смены рук при поглащении, при достижении последнего уровня поглощения открывается способность -> Высвобождение [G]
new const ABILITY_SOUNDS[][] = {
	"zp43fix5a/zombi/akshazombi_skill_shoot.wav",	// 0
	"zp43fix5a/zombi/akshazombi_skill_exp.wav",			// 1
	"zp43fix5a/zombi/zombi_heal_heavy.wav",				// 2
	"zp43fix5a/zombi/charge_start.wav"					// 3
};
new const WEAPON_NAMES[][] = { "weapon_hegrenade", "weapon_smokegrenade", "weapon_flashbang" };

new g_iZClassID,
	g_iCharge[33][3],

	g_iszModelIndex_Effect,
	g_iszModelIndex_Explosion,
	g_iszModelIndex_ShockWave;

public plugin_init() {
	// https://cso.fandom.com/wiki/Yaksha
	register_plugin("[CSO Like] ZClass: Yaksha", "0.2 | 30.08.2019", "inf");

	register_clcmd("drop",						"Command_Charge"); // Поглощение -> G

	RegisterHam(Ham_Player_ImpulseCommands,		"player",				"CPlayer__ImpulseCommands", false); // Восстановление -> T
	RegisterHam(Ham_Think,						"env_sprite", 			"CEntity__Think", false);
	RegisterHam(Ham_Think,						"info_target", 			"CEntity__Think", false);
	RegisterHam(Ham_Touch,						"info_target", 			"CEntity__Touch", false);
	for(new i = 0; i < sizeof WEAPON_NAMES; i++) RegisterHam(Ham_Item_Deploy,	WEAPON_NAMES[i],	"CWeapon__Deploy", true);
	RegisterHam(Ham_TraceAttack,				"player",				"CPlayer__TraceAttack", true);
}

public plugin_precache() {
	g_iZClassID = zp_register_class(CLASS_ZOMBIE, ZCLASS_NAME, ZCLASS_INFO, ZCLASS_MODEL, 
	ZCLASS_CLAWMODEL, 13, 0, ADMIN_ALL, ZCLASS_HEALTH, 0, ZCLASS_SPEED, ZCLASS_GRAVITY, ZCLASS_KNOCKBACK);
	
	// Precache models
	engfunc(EngFunc_PrecacheModel, ZCLASS_BOMBMODEL);
	engfunc(EngFunc_PrecacheModel, FLAME_MODEL);
	engfunc(EngFunc_PrecacheModel, RECOVERY_MODEL);

	// Precache sounds
	for(new i = 0; i < sizeof ABILITY_SOUNDS; i++) engfunc(EngFunc_PrecacheSound, ABILITY_SOUNDS[i]);
	UTIL_PrecacheSoundsFromModel("models/zombie_plague/v_knife_zombiaksha_fx.mdl"); // ZCLASS_CLAWMODEL
	UTIL_PrecacheSoundsFromModel(ZCLASS_BOMBMODEL);

	// Other
	g_iszModelIndex_Effect = engfunc(EngFunc_PrecacheModel, FLAME_SPRITE_EF);
	g_iszModelIndex_Explosion = engfunc(EngFunc_PrecacheModel, FLAME_SPRITE_EXP);
	g_iszModelIndex_ShockWave = engfunc(EngFunc_PrecacheModel, "sprites/shockwave.spr");
}

public client_putinserver(iPlayer) ResetValues(iPlayer);

public zp_user_infected_post(iPlayer) {
	if(!zp_get_user_nemesis(iPlayer) && zp_get_user_zombie_class(iPlayer) == g_iZClassID) {
		ResetValues(iPlayer);
		UTIL_ColorChat(iPlayer, "!y[!gYaksha!y] !yCapacidad: !g[Absorción] !y-> !gG !y| !g[Восстановление] !y-> !gT");
	}
}

public zp_user_humanized_post(iPlayer) if(zp_get_user_zombie_class(iPlayer) == g_iZClassID) ResetValues(iPlayer);

public ResetValues(iPlayer) {
	g_iCharge[iPlayer][0] = CHARGE_NONE;
	g_iCharge[iPlayer][1] = 0;
	g_iCharge[iPlayer][2] = 0;

	if(task_exists(iPlayer + TASKID_CHARGERESET)) remove_task(iPlayer + TASKID_CHARGERESET);
	if(task_exists(iPlayer + TASKID_RECOVERYRESET)) remove_task(iPlayer + TASKID_RECOVERYRESET);
	if(task_exists(iPlayer + TASKID_CHARGE)) remove_task(iPlayer + TASKID_CHARGE);
	if(task_exists(iPlayer + TASKID_DISCHARGE)) remove_task(iPlayer + TASKID_DISCHARGE);
	if(task_exists(iPlayer + TASKID_BLOCKVELOCITY)) remove_task(iPlayer + TASKID_BLOCKVELOCITY);
}

public Command_Charge(iPlayer) {
	if(!is_user_alive(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_nemesis(iPlayer)
	|| zp_get_user_zombie_class(iPlayer) != g_iZClassID || get_user_weapon(iPlayer) != CSW_KNIFE) return PLUGIN_CONTINUE;
	if(pev(iPlayer, pev_flags) & FL_INWATER) {
		UTIL_ColorChat(iPlayer, "!y[!gAbsorción!y] !yNo se puede utilizar en !gAgua!y!");

		return PLUGIN_HANDLED;
	}

	if(g_iCharge[iPlayer][0] == CHARGE_NONE) {
		g_iCharge[iPlayer][0] = CHARGE_START;

		set_task(13/30.0, "CTaskID__Charge", iPlayer + TASKID_CHARGE);
		set_task(0.1, "CTaskID__BlockVelocity", iPlayer + TASKID_BLOCKVELOCITY, _, _, "b");

		fm_set_rendering(iPlayer, kRenderFxGlowShell, 255, 69, 0, kRenderNormal, 8);

		UTIL_SendWeaponAnim(iPlayer, ANIM_SKILL_START, 99.0);
		UTIL_PlayerAnimation(iPlayer, ANIMATION_SKILL_START, 0.5);
		emit_sound(iPlayer, CHAN_WEAPON, ABILITY_SOUNDS[3], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	}
	else if(g_iCharge[iPlayer][0] == CHARGE_ACTIVE && pev(iPlayer, pev_weaponanim) == ANIM_SKILL_GUARD5) {
		if(task_exists(iPlayer + TASKID_DISCHARGE)) remove_task(iPlayer + TASKID_DISCHARGE);

		g_iCharge[iPlayer][0] = CHARGE_READY;
		DischargeFlame(iPlayer);

		set_task(ANIM_TIME_SKILL_TO_SHOOT, "CTaskID__Discharge", iPlayer + TASKID_DISCHARGE);

		UTIL_SendWeaponAnim(iPlayer, ANIM_SKILL_TO_SHOOT, ANIM_TIME_SKILL_TO_SHOOT);
		UTIL_PlayerAnimation(iPlayer, ANIMATION_SKILL_SHOOT, 1.0);

		emit_sound(iPlayer, CHAN_ITEM, ABILITY_SOUNDS[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	}

	return PLUGIN_HANDLED;
}

public CPlayer__ImpulseCommands(iPlayer) {
	if(!is_user_alive(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_nemesis(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID)
		return HAM_IGNORED;

	if(pev(iPlayer, pev_impulse) == 201) {
		if(task_exists(iPlayer + TASKID_RECOVERYRESET) || pev(iPlayer, pev_health) >= zp_get_zombie_maxhealth(iPlayer)) {
			UTIL_ColorChat(iPlayer, task_exists(iPlayer + TASKID_RECOVERYRESET) ? "!y[!gRecuperación!y] !yRecargas de habilidad..." : "!y[!gRecuperación!y] !yTienes máxima salud!");

			return HAM_IGNORED;
		}
		else {
			set_task(float(RECOVERY_RESET), "CTaskID__RecoveryReset", iPlayer + TASKID_RECOVERYRESET);

			set_pev(iPlayer, pev_health, pev(iPlayer, pev_health) >= float(zp_get_zombie_maxhealth(iPlayer) - RECOVERY_HEALTH) ? float(zp_get_zombie_maxhealth(iPlayer)) : pev(iPlayer, pev_health) + float(RECOVERY_HEALTH));
			RecoveryHealth(iPlayer);
			UTIL_ColorChat(iPlayer, "!y[!gRecuperación!y] !yRecargar: !g%d !yseg.", RECOVERY_RESET);
		}
	}

	return HAM_IGNORED;
}

public CEntity__Think(iEntity) {
	if(pev_valid(iEntity) != 2) return HAM_IGNORED;

	if(pev(iEntity, pev_classname) == engfunc(EngFunc_AllocString, RECOVERY_CLASSNAME)) {
		new iOwner = pev(iEntity, pev_owner);

		static Float: flFuser3; pev(iEntity, pev_fuser3, flFuser3);

		if(!is_user_alive(iOwner) || !zp_get_user_zombie(iOwner) || flFuser3 <= get_gametime()) {
			set_pev(iEntity, pev_flags, FL_KILLME);

			return HAM_IGNORED;
		}

		static Float: vecOrigin[3]; pev(iOwner, pev_origin, vecOrigin);

		vecOrigin[2] += 50.0;

		engfunc(EngFunc_SetOrigin, iEntity, vecOrigin);
		set_pev(iEntity, pev_nextthink, get_gametime() + 0.01);
	}

	if(pev(iEntity, pev_classname) == engfunc(EngFunc_AllocString, FLAME_CLASSNAME)) {
		new iOwner = pev(iEntity, pev_owner);

		if(!is_user_connected(iOwner)) {
			set_pev(iEntity, pev_flags, FL_KILLME);

			return HAM_IGNORED;
		}

		static Float: flFuser1; pev(iEntity, pev_fuser1, flFuser1);

		if(flFuser1 <= get_gametime() && pev(iEntity, pev_gravity) == -1.0) set_pev(iEntity, pev_gravity, 1.0);

		static Float: vecOrigin[3]; pev(iEntity, pev_origin, vecOrigin);

		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
		write_byte(TE_EXPLOSION);
		engfunc(EngFunc_WriteCoord, vecOrigin[0]);
		engfunc(EngFunc_WriteCoord, vecOrigin[1]);
		engfunc(EngFunc_WriteCoord, vecOrigin[2]);
		write_short(g_iszModelIndex_Effect);
		write_byte(random_num(2, 5)); // Scale
		write_byte(60); // Framerate
		write_byte(TE_EXPLFLAG_NOSOUND | TE_EXPLFLAG_NOPARTICLES); // Flags
		message_end();

		set_pev(iEntity, pev_nextthink, get_gametime() + random_float(0.02, 0.03));
	}

	return HAM_IGNORED;
}

public CEntity__Touch(iEntity, iTouch) {
	if(pev_valid(iEntity) != 2) return HAM_IGNORED;

	if(pev(iEntity, pev_classname) == engfunc(EngFunc_AllocString, FLAME_CLASSNAME)) {
		new iOwner = pev(iEntity, pev_owner);

		if(iTouch == iOwner) return HAM_SUPERCEDE;

		if(!is_user_connected(iOwner)) {
			set_pev(iEntity, pev_flags, FL_KILLME);

			return HAM_IGNORED;
		}

		iTouch = FM_NULLENT;

		static Float: vecOrigin[3]; pev(iEntity, pev_origin, vecOrigin);

		while((iTouch = engfunc(EngFunc_FindEntityInSphere, iTouch, vecOrigin, float(FLAME_RADIUS))) != 0) {
			if(pev(iTouch, pev_takedamage) == DAMAGE_NO) continue;
			if(is_user_alive(iTouch)) if(zp_get_user_zombie(iTouch)) continue;
			else if(pev(iTouch, pev_solid) == SOLID_BSP) if(pev(iTouch, pev_spawnflags) & SF_BREAK_TRIGGER_ONLY) continue;

			ExecuteHamB(Ham_TakeDamage, iTouch, iEntity, iOwner, float(FLAME_DAMAGE), FLAME_DMGTYPE);

			if(is_user_alive(iTouch) && !zp_get_user_zombie(iTouch)) {
				UTIL_BloodDrips(iTouch, FLAME_DAMAGE);
				set_pdata_int(iTouch, m_LastHitGroup, HIT_CHEST, linux_diff_player);
				set_pdata_float(iTouch, m_flPainShock, 0.1, linux_diff_player);

				message_begin(MSG_ONE, get_user_msgid("ScreenFade"), _, iTouch);
				write_short(1<<12); // Duration. Note: Duration and HoldTime is in special units. 1 second is equal to (1<<12) i.e. 4096 units.
				write_short(1<<12); // HoldTime
				write_short(0x0000); // Flags
				write_byte(255); // Red
				write_byte(69); // Green
				write_byte(0); // Blue
				write_byte(100); // Alpha
				message_end();

				message_begin(MSG_ONE, get_user_msgid("ScreenShake"), _, iTouch);
				write_short(1<<16); // Amplitude
				write_short(1<<14); // Duration
				write_short(1<<14); // Frequency
				message_end();
			}
		}

		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
		write_byte(TE_EXPLOSION);
		engfunc(EngFunc_WriteCoord, vecOrigin[0]);
		engfunc(EngFunc_WriteCoord, vecOrigin[1]);
		engfunc(EngFunc_WriteCoord, vecOrigin[2] + 30.0);
		write_short(g_iszModelIndex_Explosion);
		write_byte(15); // Scale
		write_byte(25); // Framerate
		write_byte(TE_EXPLFLAG_NOSOUND); // Flags
		message_end();

		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
		write_byte(TE_BEAMCYLINDER);
		engfunc(EngFunc_WriteCoord, vecOrigin[0]);
		engfunc(EngFunc_WriteCoord, vecOrigin[1]);
		engfunc(EngFunc_WriteCoord, vecOrigin[2] + 10.0);
		engfunc(EngFunc_WriteCoord, vecOrigin[0]);
		engfunc(EngFunc_WriteCoord, vecOrigin[1]);
		engfunc(EngFunc_WriteCoord, vecOrigin[2] + float(FLAME_RADIUS));
		write_short(g_iszModelIndex_ShockWave); // sprite index
		write_byte(0); // starting frame
		write_byte(0); // frame rate in 0.1's
		write_byte(20); // life in 0.1's
		write_byte(20); // line width in 0.1's
		write_byte(0); // noise amplitude in 0.01's
		write_byte(255); // red
		write_byte(69); // green
		write_byte(0); // blue
		write_byte(255); // brightness
		write_byte(0); // scroll speed in 0.1's
		message_end();

		emit_sound(iEntity, CHAN_ITEM, ABILITY_SOUNDS[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

		set_pev(iEntity, pev_flags, FL_KILLME);
	}

	return HAM_IGNORED;
}

public CWeapon__Deploy(iItem) {
	static iPlayer; iPlayer = get_pdata_cbase(iItem, m_pPlayer, linux_diff_weapon);

	if(!zp_get_user_zombie(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID) return;

	if(g_iCharge[iPlayer][0] != 0 && !(task_exists(iPlayer + TASKID_CHARGERESET))) {
		if(task_exists(iPlayer + TASKID_CHARGE)) remove_task(iPlayer + TASKID_CHARGE);
		if(task_exists(iPlayer + TASKID_DISCHARGE)) remove_task(iPlayer + TASKID_DISCHARGE);
		if(task_exists(iPlayer + TASKID_BLOCKVELOCITY)) remove_task(iPlayer + TASKID_BLOCKVELOCITY);

		g_iCharge[iPlayer][0] = CHARGE_END;

		set_task(float(CHARGE_RESET), "CTaskID__ChargeReset", iPlayer + TASKID_CHARGERESET);

		fm_set_rendering(iPlayer, kRenderFxNone);
		UTIL_ColorChat(iPlayer, "!y[!gAbsorción!y] !yRecargar: !g%d !yseg.", CHARGE_RESET);
	}

	set_pev(iPlayer, pev_viewmodel2, ZCLASS_BOMBMODEL);
}

public CPlayer__TraceAttack(iVictim, iAttacker, Float: flDamage, Float: vecDirection[3], iTrace) {
	if(!is_user_alive(iAttacker) || zp_get_user_zombie(iAttacker) || zp_get_user_nemesis(iVictim)
	|| !zp_get_user_zombie(iVictim) || zp_get_user_zombie_class(iVictim) != g_iZClassID || g_iCharge[iVictim][0] != 2) return HAM_IGNORED;

	set_pev(iVictim, pev_punchangle, { 0.0, 0.0, 0.0 });

	g_iCharge[iVictim][1] += floatround(flDamage);

	static Float: vecEndPos[3]; get_tr2(iTrace, TR_vecEndPos, vecEndPos);

	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecEndPos, 0);
	write_byte(TE_SPARKS);
	engfunc(EngFunc_WriteCoord, vecEndPos[0]);
	engfunc(EngFunc_WriteCoord, vecEndPos[1]);
	engfunc(EngFunc_WriteCoord, vecEndPos[2]);
	message_end();

	if(g_iCharge[iVictim][1] >= DAMAGE_CHARGE[g_iCharge[iVictim][2]] && pev(iVictim, pev_weaponanim) < ANIM_SKILL_GUARD5) {
		g_iCharge[iVictim][2] += 1;
		UTIL_SendWeaponAnim(iVictim, ANIM_SKILL_GUARD1 + g_iCharge[iVictim][2], ANIM_TIME_SKILL_GUARD);

		if(pev(iVictim, pev_weaponanim) == ANIM_SKILL_GUARD5) UTIL_ColorChat(iVictim, "!y[!gAbsorción!y] !yHaga clic en !yG !ypara liberar energía.")
	}

	return HAM_IGNORED;
}

public CTaskID__Charge(iPlayer) {
	iPlayer -= TASKID_CHARGE;

	if(!is_user_alive(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_nemesis(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID)
		return;

	g_iCharge[iPlayer][0] = CHARGE_ACTIVE;

	set_task(3.0, "CTaskID__Discharge", iPlayer + TASKID_DISCHARGE);

	UTIL_SendWeaponAnim(iPlayer, ANIM_SKILL_GUARD1, 99.0);
	UTIL_PlayerAnimation(iPlayer, ANIMATION_SKILL_LOOP, 0.80);
}

public CTaskID__Discharge(iPlayer) {
	iPlayer -= TASKID_DISCHARGE;

	if(!is_user_alive(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_nemesis(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID)
		return;

	if(task_exists(iPlayer + TASKID_BLOCKVELOCITY)) remove_task(iPlayer + TASKID_BLOCKVELOCITY);

	set_task(float(CHARGE_RESET), "CTaskID__ChargeReset", iPlayer + TASKID_CHARGERESET);

	if(g_iCharge[iPlayer][0] == CHARGE_ACTIVE) {
		UTIL_SendWeaponAnim(iPlayer, ANIM_SKILL_TO_IDLE, ANIM_TIME_SKILL_TO_IDLE);
		UTIL_PlayerAnimation(iPlayer, ANIMATION_SKILL_IDLE, 1.0);
	}

	g_iCharge[iPlayer][0] = CHARGE_END;

	fm_set_rendering(iPlayer, kRenderFxNone);
	UTIL_ColorChat(iPlayer, "!y[!gAbsorción!y] !yRecargar: !g%d !yseg.", CHARGE_RESET);
}

public CTaskID__ChargeReset(iPlayer) {
	iPlayer -= TASKID_CHARGERESET;

	if(!is_user_alive(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_nemesis(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID)
		return;

	g_iCharge[iPlayer][0] = CHARGE_NONE;
	g_iCharge[iPlayer][1] = 0;
	g_iCharge[iPlayer][2] = 0;
	UTIL_ColorChat(iPlayer, "!y[!gAbsorción!y] !yCapacidad: !gListo!");
}

public CTaskID__RecoveryReset(iPlayer) {
	iPlayer -= TASKID_RECOVERYRESET;

	if(!is_user_alive(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_nemesis(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID)
		return;

	UTIL_ColorChat(iPlayer, "!y[!gRecuperación!y] !yCapacidad: !gListo!");
}

public CTaskID__BlockVelocity(iPlayer) {
	iPlayer -= TASKID_BLOCKVELOCITY;

	if(!is_user_alive(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_nemesis(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID) {
		if(task_exists(iPlayer + TASKID_BLOCKVELOCITY)) remove_task(iPlayer + TASKID_BLOCKVELOCITY);

		return;
	}

	set_pev(iPlayer, pev_velocity, { 0.0, 0.0, 0.0 });
}

public DischargeFlame(iPlayer) {
	new iEntity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));

	static Float: vecVelocity[3]; velocity_by_aim(iPlayer, 500, vecVelocity);
	static Float: vecStart[3]; UTIL_GetPosition(iPlayer, 10.0, 0.0, 15.0, vecStart);

	set_pev(iEntity, pev_classname, FLAME_CLASSNAME);
	set_pev(iEntity, pev_owner, iPlayer);
	set_pev(iEntity, pev_solid, SOLID_TRIGGER);
	set_pev(iEntity, pev_movetype, MOVETYPE_TOSS);
	set_pev(iEntity, pev_gravity, -1.0);
	set_pev(iEntity, pev_velocity, vecVelocity);
	set_pev(iEntity, pev_frame, 0.0);
	set_pev(iEntity, pev_scale, 0.3);
	set_pev(iEntity, pev_rendermode, kRenderTransAdd);
	set_pev(iEntity, pev_renderamt, 255.0);

	engfunc(EngFunc_SetModel, iEntity, FLAME_MODEL);
	engfunc(EngFunc_SetSize, iEntity, { -1.0, -1.0, -1.0 }, { 1.0, 1.0, 1.0 });
	engfunc(EngFunc_SetOrigin, iEntity, vecStart);

	set_pev(iEntity, pev_fuser1, get_gametime() + 0.3);
	set_pev(iEntity, pev_nextthink, get_gametime());
}

public RecoveryHealth(iPlayer) {
	new iEntity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"));

	static Float: vecOrigin[3]; pev(iPlayer, pev_origin, vecOrigin);

	vecOrigin[2] += 50.0;

	set_pev(iEntity, pev_classname, RECOVERY_CLASSNAME);
	set_pev(iEntity, pev_owner, iPlayer);
	set_pev(iEntity, pev_frame, 0.0);
	set_pev(iEntity, pev_framerate, 10.0);
	set_pev(iEntity, pev_animtime, get_gametime());
	set_pev(iEntity, pev_rendermode, kRenderTransAdd);
	set_pev(iEntity, pev_renderamt, 255.0);

	engfunc(EngFunc_SetModel, iEntity, RECOVERY_MODEL);
	engfunc(EngFunc_SetOrigin, iEntity, vecOrigin);

	dllfunc(DLLFunc_Spawn, iEntity);

	set_pev(iEntity, pev_fuser3, get_gametime() + 19/10.0);
	set_pev(iEntity, pev_nextthink, get_gametime());

	message_begin(MSG_ONE, get_user_msgid("ScreenFade"), _, iPlayer);
	write_short(1<<12); // Duration. Note: Duration and HoldTime is in special units. 1 second is equal to (1<<12) i.e. 4096 units.
	write_short(1<<12); // HoldTime
	write_short(0x0000); // Flags
	write_byte(255); // Red
	write_byte(69); // Green
	write_byte(0); // Blue
	write_byte(50); // Alpha
	message_end();

	emit_sound(iPlayer, CHAN_ITEM, ABILITY_SOUNDS[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

stock UTIL_PlayerAnimation(const iPlayer, const szAnim[], Float: flFramerate) {
	new iAnimDesired, Float: flFrameRate, Float: flGroundSpeed, bool: bLoops;
		
	if((iAnimDesired = lookup_sequence(iPlayer, szAnim, flFrameRate, bLoops, flGroundSpeed)) == -1) iAnimDesired = 0;

	set_pev(iPlayer, pev_frame, 0.0);
	set_pev(iPlayer, pev_framerate, flFramerate);
	set_pev(iPlayer, pev_animtime, get_gametime());
	set_pev(iPlayer, pev_sequence, iAnimDesired);
	
	set_pdata_int(iPlayer, 40, bLoops, linux_diff_weapon);
	set_pdata_int(iPlayer, 39, 0, linux_diff_weapon);
	
	set_pdata_float(iPlayer, 36, flFrameRate, linux_diff_weapon);
	set_pdata_float(iPlayer, 37, flGroundSpeed, linux_diff_weapon);
	set_pdata_float(iPlayer, 38, get_gametime(), linux_diff_weapon);
	
	set_pdata_int(iPlayer, 73, 28, linux_diff_player);
	set_pdata_int(iPlayer, 74, 28, linux_diff_player);
	set_pdata_float(iPlayer, 220, get_gametime(), linux_diff_player);
}
stock UTIL_GetPosition(iPlayer, Float: flForward, Float: flRight, Float: flUp, Float: vecStart[]) {
	new Float: vecOrigin[3], Float: vecAngle[3], Float: vecForward[3], Float: vecRight[3], Float: vecUp[3];

	pev(iPlayer, pev_origin, vecOrigin);
	pev(iPlayer, pev_view_ofs, vecUp);
	xs_vec_add(vecOrigin, vecUp, vecOrigin);
	pev(iPlayer, pev_angles, vecAngle);

	angle_vector(vecAngle, ANGLEVECTOR_FORWARD, vecForward);
	angle_vector(vecAngle, ANGLEVECTOR_RIGHT, vecRight);
	angle_vector(vecAngle, ANGLEVECTOR_UP, vecUp);

	vecStart[0] = vecOrigin[0] + vecForward[0] * flForward + vecRight[0] * flRight + vecUp[0] * flUp;
	vecStart[1] = vecOrigin[1] + vecForward[1] * flForward + vecRight[1] * flRight + vecUp[1] * flUp;
	vecStart[2] = vecOrigin[2] + vecForward[2] * flForward + vecRight[2] * flRight + vecUp[2] * flUp;
}
stock UTIL_BloodDrips(iVictim, iAmount) {
	static Float: vecOrigin[3]; pev(iVictim, pev_origin, vecOrigin);

	if(iAmount > 255) iAmount = 255;
	
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
	write_byte(TE_BLOODSPRITE);
	engfunc(EngFunc_WriteCoord, vecOrigin[0]);
	engfunc(EngFunc_WriteCoord, vecOrigin[1]);
	engfunc(EngFunc_WriteCoord, vecOrigin[2]);
	write_short(engfunc(EngFunc_PrecacheModel, "sprites/bloodspray.spr"));
	write_short(engfunc(EngFunc_PrecacheModel, "sprites/blood.spr"));
	write_byte(ExecuteHamB(Ham_BloodColor, iVictim));
	write_byte(min(max(3, iAmount / 10), 16));
	message_end();
}
stock UTIL_SendWeaponAnim(iPlayer, iAnim, Float: flTime) {
	set_pev(iPlayer, pev_weaponanim, iAnim);

	message_begin(MSG_ONE, SVC_WEAPONANIM, _, iPlayer);
	write_byte(iAnim);
	write_byte(0);
	message_end();

	static iItem; iItem = get_pdata_cbase(iPlayer, m_pActiveItem, linux_diff_player);

	set_pdata_float(iPlayer, m_flNextAttack, flTime, linux_diff_player);
	set_pdata_float(iItem, m_flTimeWeaponIdle, flTime, linux_diff_weapon);
}
stock UTIL_ColorChat(iPlayer, const Text[], any:...) {
	new iMsg[128]; vformat(iMsg, charsmax(iMsg), Text, 3);

	replace_all(iMsg, charsmax(iMsg), "!y", "^x01");
	replace_all(iMsg, charsmax(iMsg), "!t", "^x03");
	replace_all(iMsg, charsmax(iMsg), "!g", "^x04");

	message_begin(MSG_ONE, get_user_msgid("SayText"), _, iPlayer);
	write_byte(iPlayer);
	write_string(iMsg);
	message_end();
}
stock UTIL_PrecacheSoundsFromModel(const szModelPath[]) {
	new iFile;
	
	if((iFile = fopen(szModelPath, "rt"))) {
		new szSoundPath[64];
		
		new iNumSeq, iSeqIndex;
		new iEvent, iNumEvents, iEventIndex;
		
		fseek(iFile, 164, SEEK_SET);
		fread(iFile, iNumSeq, BLOCK_INT);
		fread(iFile, iSeqIndex, BLOCK_INT);
		
		for(new k, i = 0; i < iNumSeq; i++) {
			fseek(iFile, iSeqIndex + 48 + 176 * i, SEEK_SET);
			fread(iFile, iNumEvents, BLOCK_INT);
			fread(iFile, iEventIndex, BLOCK_INT);
			fseek(iFile, iEventIndex + 176 * i, SEEK_SET);
			
			for(k = 0; k < iNumEvents; k++) {
				fseek(iFile, iEventIndex + 4 + 76 * k, SEEK_SET);
				fread(iFile, iEvent, BLOCK_INT);
				fseek(iFile, 4, SEEK_CUR);
				
				if(iEvent != 5004) continue;
				
				fread_blocks(iFile, szSoundPath, 64, BLOCK_CHAR);
				
				if(strlen(szSoundPath)) {
					strtolower(szSoundPath);
					engfunc(EngFunc_PrecacheSound, szSoundPath);
				}
			}
		}
	}
	
	fclose(iFile);
}