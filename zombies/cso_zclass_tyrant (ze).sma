#pragma compress 1

#include amxmodx
#include fakemeta_util
#include hamsandwich
#include <zombieplague>

/* ~ [ Macroses ] ~ */
#define pev_attacker pev_iuser1
#define pev_action pev_iuser2
#define pev_victim pev_enemy
#define PDATA_SAFE 2
#define ACT_RANGE_ATTACK1 28

/* ~ [ Offset's ] ~ */
// Linux extra offsets
#define linux_diff_animating 4
#define linux_diff_weapon 4
#define linux_diff_player 5

// CBaseAnimating
#define m_flFrameRate 36
#define m_flGroundSpeed 37
#define m_flLastEventCheck 38
#define m_fSequenceFinished 39
#define m_fSequenceLoops 40

// CBasePlayerItem
#define m_pPlayer 41

// CBasePlayerWeapon
#define m_flNextPrimaryAttack 46
#define m_flNextSecondaryAttack 47
#define m_flTimeWeaponIdle 48

// CBaseMonster
#define m_Activity 73
#define m_IdealActivity 74

// CBasePlayer
#define m_flPainShock 108
#define m_flLastAttackTime 220
#define m_pActiveItem 373

/* ~ [ ZClass Setting's ] ~ */
#define ZCLASS_NAME						"Tyrant" // Имя
#define ZCLASS_INFO						"\y[ Charge | Hound \y]" // Инфо
#define ZCLASS_MODEL 					"zombi_meatwall_fix" // Модель
#define ZCLASS_CLAWMODEL				"v_knife_zombimeatwall.mdl" // Модель рук
#define ZCLASS_BOMBMODEL				"models/inf142/zombie/meatwall/v_zombibomb_meatwall.mdl" // Модель бомбы 
#define ZCLASS_HEALTH					1800 // Хп
#define ZCLASS_SPEED					250	// Скорость
#define ZCLASS_GRAVITY 					0.75 // Гравитация
#define ZCLASS_KNOCKBACK				0.10 // Отброс

/* ~ [ Furious Charge Setting's ] ~ */
#define CHARGE_SOUND_START				"inf142/zombie/meatwall/meatwallzombie_skill_dash_hold.wav" // Звук разгона
#define CHARGE_SOUND_END				"inf142/zombie/meatwall/meatwallzombie_skill_dash_finish.wav" // Звук окончания разгона
#define CHARGE_SPEED					550.0 // Скорость разгона
#define CHARGE_DAMAGE					random_float(5.0, 15.0) // Урон при ударе об человека
#define CHARGE_TIME						3 // Время способности должно быть меньше времени перезарядки!
#define CHARGE_COOLDOWN					15 // Время перезарядки способности

/* ~ [ Shock Wave Setting's ] ~ */
#define SHOCKWAVE_CLASSNAME				"meatwall_wave"
#define SHOCKWAVE_MODEL					"models/inf142/zombie/meatwall/ef_meatwall_wave.mdl" // Модель ударной волны
#define SHOCKWAVE_TIME					11/30.0 // Время через которое пройзодет ударная волна (удар по земле рукой)
#define SHOCKWAVE_RADIUS				240 // Радиус отброса
#define SHOCKWAVE_POWER					500.0 // Сила отброса
#define SHOCKWAVE_DAMAGE				random_float(5.0, 15.0) // Урон волны

/* ~ [ Egg Setting's ] ~ */
#define EGG_CLASSNAME					"meatwall_egg"
#define EGG_MODEL						"models/inf142/zombie/meatwall/meatwall_egg.mdl" // Модель яйца
#define EGG_SOUND_THROW					"inf142/zombie/meatwall/meatwallzombie_ref_shoot_egg.wav" // Звук выстрела яйца
#define EGG_SOUND_EXP					"inf142/zombie/meatwall/meatwallzombie_egg_crash.wav" // Звук взрыва яйца
#define EGG_SPRITE						"sprites/inf142/ef_meatwall_egg.spr" // Спрайт на месте появляния собаки
#define EGG_SPEED						1000 // Скорость полёта яйца

/* ~ [ Hound Setting's ] ~ */
#define HOUND_CLASSNAME					"meatwall_hound"
#define HOUND_MODEL						"models/inf142/zombie/meatwall/zombiedog.mdl" // Модель собаки
new const szHoundSounds[][] = {
	"inf142/zombie/meatwall/zombiedog_howls.wav", // 0
	"inf142/zombie/meatwall/zombiedog_attack1.wav", // 1
	"inf142/zombie/meatwall/zombiedog_skill1.wav", // 2
	"inf142/zombie/meatwall/zombiedog_hurt1.wav", // 3
	"inf142/zombie/meatwall/zombiedog_hurt2.wav", // 4
	"inf142/zombie/meatwall/zombiedog_death1.wav", // 5
	"inf142/zombie/meatwall/zombiedog_death2.wav" // 6
};
#define HOUND_COOLDOWN					15 // Время перезарядки способности
#define HOUND_APPEAR					41/30.0 // Время через которое собака начнет искать врага и т.д.. А до этого она бессмертна
#define HOUND_HEALTH					1000 // Хп собаки
#define HOUND_SPEED						310.0 // Скорость собаки
#define HOUND_DAMAGE					random_float(15.0, 45.0) // Урон собаки
#define HOUND_DMGTYPE					(DMG_NEVERGIB | DMG_SLASH) // Тип урон
#define HOUND_DIST_TARGET				666.0 // Дистанция поиска цели (Человека)
#define HOUND_DIST_ATTACK				70.0 // Дистанция атаки цели (Человека)

/* ~ [ Task's ] ~ */
#define TASKID_ABILITYSRELOAD			300720201601
#define TASKID_HOUNDTHROW				300820201538
#define TASKID_DASH						300720201657

/* ~ [ Enum's ] ~ */
enum _: e_TimerData {
	TIMER_CHARGE = 0,
	TIMER_HOUND
};

enum {
	ANIM_IDLE = 1,
	ANIM_WALK,
	ANIM_RUN,
	ANIM_APPEAR,
	ANIM_ATTACK = 8,
	ANIM_DEATH1 = 11,
	ANIM_DEATH2 = 15
};

enum {
	ACT_IDLE = 0,
	//ACT_WALK, // Скоро...
	ACT_RUN,
	ACT_ATTACK
};

/* ~ [ Param's ] ~ */
new g_iZClassID,

	g_iTimer[33][e_TimerData],

	g_iMaxPlayers,
	g_iMsgID_SayText,
	g_iMsgID_ScreenFade,
	g_iMsgID_ScreenShake,

	g_iszAllocString_InfoTarget,
	g_iszAllocString_ShockWave,
	g_iszAllocString_Egg,
	g_iszAllocString_Hound,
	g_iszAllocString_ModelView,

	g_iszModelIndex_ShockWave,
	g_iszModelIndex_Gibs,
	g_iszModelIndex_EggExplosion,
	g_iszModelIndex_Smoke,
	g_iszModelIndex_BloodSpray,
	g_iszModelIndex_Blood;

new const szWeaponNames[][] = { "weapon_smokegrenade" , "weapon_hegrenade" };

/* ~ [ AMX Mod X ] ~ */
public plugin_init() {
	// https://cso.fandom.com/wiki/Tyrant
	register_plugin("[CSO Like] ZClass: Tyrant", "1.0", "inf");

	// Message's
	g_iMaxPlayers = get_maxplayers();
	g_iMsgID_SayText = get_user_msgid("SayText");
	g_iMsgID_ScreenFade = get_user_msgid("ScreenFade");
	g_iMsgID_ScreenShake = get_user_msgid("ScreenShake");

	// Ham's
	for(new i = 0; i < sizeof szWeaponNames; i++) RegisterHam(Ham_Item_Deploy,		szWeaponNames[i],	"CKnife__Deploy", true);
	RegisterHam(Ham_Player_ImpulseCommands,		"player",			"CPlayer__ImpulseCommands", false);
	RegisterHam(Ham_Player_Jump,				"player",			"CPlayer__Jump", false);
	RegisterHam(Ham_Player_Duck,				"player",			"CPlayer__Duck", false);
	RegisterHam(Ham_Touch,						"player",			"CPlayer__Touch", false);
	RegisterHam(Ham_Item_PreFrame,				"player",			"CPlayer__PreFrame", true);

	// Entity's
	RegisterHam(Ham_TraceAttack,				"info_target",		"CEntity__TraceAttack", true);
	RegisterHam(Ham_TakeDamage,					"info_target",		"CEntity__TakeDamage", true);
	RegisterHam(Ham_Touch,						"info_target",		"CEntity__Touch", false);
	RegisterHam(Ham_Think,						"info_target",		"CEntity__Think", false);

	// Other
	register_clcmd("drop",						"CLCMD__AbilityCharge");
}

public plugin_precache() {
	// Precache Models
	engfunc(EngFunc_PrecacheModel, ZCLASS_BOMBMODEL);
	engfunc(EngFunc_PrecacheModel, SHOCKWAVE_MODEL);
	engfunc(EngFunc_PrecacheModel, EGG_MODEL);
	engfunc(EngFunc_PrecacheModel, HOUND_MODEL);

	// Precache Sounds
	engfunc(EngFunc_PrecacheSound, CHARGE_SOUND_START);
	engfunc(EngFunc_PrecacheSound, CHARGE_SOUND_END);
	engfunc(EngFunc_PrecacheSound, EGG_SOUND_THROW);
	engfunc(EngFunc_PrecacheSound, EGG_SOUND_EXP);
	for(new i = 0; i < sizeof szHoundSounds; i++) engfunc(EngFunc_PrecacheSound, szHoundSounds[i]);

	// Alloc String
	g_iszAllocString_InfoTarget = engfunc(EngFunc_AllocString, "info_target");
	g_iszAllocString_ShockWave = engfunc(EngFunc_AllocString, SHOCKWAVE_CLASSNAME);
	g_iszAllocString_Egg = engfunc(EngFunc_AllocString, EGG_CLASSNAME);
	g_iszAllocString_Hound = engfunc(EngFunc_AllocString, HOUND_CLASSNAME);
	g_iszAllocString_ModelView = engfunc(EngFunc_AllocString, ZCLASS_BOMBMODEL);

	// Model Index
	g_iszModelIndex_ShockWave = engfunc(EngFunc_PrecacheModel, "sprites/shockwave.spr");
	g_iszModelIndex_Gibs = engfunc(EngFunc_PrecacheModel, "models/rockgibs.mdl");
	g_iszModelIndex_EggExplosion = engfunc(EngFunc_PrecacheModel, EGG_SPRITE);
	g_iszModelIndex_Smoke = engfunc(EngFunc_PrecacheModel, "sprites/black_smoke1.spr");
	g_iszModelIndex_BloodSpray = engfunc(EngFunc_PrecacheModel, "sprites/bloodspray.spr");
	g_iszModelIndex_Blood = engfunc(EngFunc_PrecacheModel, "sprites/blood.spr");

	// Registering a zombie class
	g_iZClassID = zp_register_class(CLASS_ZOMBIE, ZCLASS_NAME, ZCLASS_INFO, ZCLASS_MODEL, ZCLASS_CLAWMODEL, 12, 5, ADMIN_ALL, 
		ZCLASS_HEALTH, 0, ZCLASS_SPEED, ZCLASS_GRAVITY, ZCLASS_KNOCKBACK);
}

public client_putinserver(iPlayer) ResetValues(iPlayer);

/* ~ [ Zombie Plague ] ~ */
public zp_user_infected_post(iPlayer) {
	if(!zp_get_user_nemesis(iPlayer) && zp_get_user_zombie_class(iPlayer) == g_iZClassID) {
		ResetValues(iPlayer);
		UTIL_ColorChat(iPlayer, "!y[!gTyrant!y] Your ability [!gCharge -> G | Hound -> R!y]");
	}
}
public zp_user_humanized_post(iPlayer) if(zp_get_user_zombie_class(iPlayer) == g_iZClassID) ResetValues(iPlayer);

public CLCMD__AbilityCharge(iPlayer) {
	if(!is_user_alive(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_nemesis(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID)
		return PLUGIN_CONTINUE;

	if(!(pev(iPlayer, pev_flags) & FL_ONGROUND) || pev(iPlayer, pev_flags) & FL_DUCKING || pev(iPlayer, pev_button) & IN_DUCK)
		return PLUGIN_HANDLED;

	if(!g_iTimer[iPlayer][TIMER_CHARGE]) {
		g_iTimer[iPlayer][TIMER_CHARGE] = CHARGE_COOLDOWN;

		if(!(task_exists(iPlayer + TASKID_ABILITYSRELOAD))) set_task(1.0, "CTaskID__AbilitysReload", iPlayer + TASKID_ABILITYSRELOAD, _, _, "b");
		set_task(13/30.0, "CTaskID__DashStart", iPlayer + TASKID_DASH);

		UTIL_SendWeaponAnim(iPlayer, 9, 16/30.0);
	}

	return PLUGIN_HANDLED;
}

/* ~ [ HamSandWich ] ~ */
public CKnife__Deploy(iItem) {
	static iPlayer; iPlayer = get_pdata_cbase(iItem, m_pPlayer, linux_diff_weapon);

	if(!zp_get_user_zombie(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID) return;

	set_pev_string(iPlayer, pev_viewmodel2, g_iszAllocString_ModelView);
}

public CPlayer__ImpulseCommands(iPlayer) {
	if(!is_user_alive(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_nemesis(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID)
		return HAM_IGNORED;

	if(pev(iPlayer, pev_impulse) == 201) {
		if(!g_iTimer[iPlayer][TIMER_HOUND]) {
			g_iTimer[iPlayer][TIMER_HOUND] = HOUND_COOLDOWN;

			if(!(task_exists(iPlayer + TASKID_ABILITYSRELOAD))) set_task(1.0, "CTaskID__AbilitysReload", iPlayer + TASKID_ABILITYSRELOAD, _, _, "b");
			set_task(8/30.0, "CTaskID__HoundThrow", iPlayer + TASKID_HOUNDTHROW);

			UTIL_SendWeaponAnim(iPlayer, 13, 11/30.0);
		}
	}

	return HAM_IGNORED;
}

public CPlayer__Jump(iPlayer) {
	if(!is_user_alive(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_nemesis(iPlayer)
	|| zp_get_user_zombie_class(iPlayer) != g_iZClassID || g_iTimer[iPlayer][TIMER_CHARGE] <= (CHARGE_COOLDOWN - CHARGE_TIME)) return HAM_IGNORED;

	set_pev(iPlayer, pev_oldbuttons, IN_JUMP);

	return HAM_IGNORED;
}

public CPlayer__Duck(iPlayer) {
	if(!is_user_alive(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_nemesis(iPlayer)
	|| zp_get_user_zombie_class(iPlayer) != g_iZClassID || g_iTimer[iPlayer][TIMER_CHARGE] <= (CHARGE_COOLDOWN - CHARGE_TIME)) return HAM_IGNORED;

	set_pev(iPlayer, pev_oldbuttons, IN_DUCK);

	return HAM_IGNORED;
}

public CPlayer__Touch(iPlayer, iTouch) {
	if(!is_user_alive(iPlayer) || !is_user_alive(iTouch) || iTouch == iPlayer || zp_get_user_nemesis(iPlayer)
	|| zp_get_user_zombie_class(iPlayer) != g_iZClassID || pev(iPlayer, pev_weaponanim) != 10) return HAM_IGNORED;

	if(iTouch) {
		if(zp_get_user_zombie(iTouch)) {
			if(task_exists(iPlayer + TASKID_DASH)) remove_task(iPlayer + TASKID_DASH);

			Create_ShockWave(iPlayer);

			return HAM_IGNORED;
		}
		else {
			UTIL_CreateFakeDamage(iTouch, iPlayer, CHARGE_DAMAGE);

			static Float: vecVelocity[3], Float: vecPunchAngle[3];

			vecVelocity[0] = random_float(500.0, 1000.0);
			vecVelocity[1] = random_float(500.0, 1000.0);
			vecVelocity[2] = random_float(260.0, 520.0);

			vecPunchAngle[0] = random_float(25.0, 50.0);
			vecPunchAngle[1] = random_float(25.0, 50.0);
			vecPunchAngle[2] = random_float(25.0, 50.0);

			set_pev(iTouch, pev_velocity, vecVelocity);
			set_pev(iTouch, pev_punchangle, vecPunchAngle);
		}
	}

	return HAM_IGNORED;
}

public CEntity__TraceAttack(iVictim, iAttacker, Float: flDamage, Float: vecDirection[3], iTrace) {
	if(!is_user_alive(iAttacker)) return HAM_IGNORED;

	if(pev(iVictim, pev_classname) == g_iszAllocString_Hound) {
		static Float: vecEndPos[3]; get_tr2(iTrace, TR_vecEndPos, vecEndPos);

		UTIL_BloodSprite(floatround(flDamage), vecEndPos);
		emit_sound(iVictim, CHAN_WEAPON, szHoundSounds[random_num(3, 4)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	}

	return HAM_IGNORED;
}

public CEntity__TakeDamage(iVictim, iWeapon, iAttacker, Float: flDamage, iDmgType) {
	if(!is_user_alive(iAttacker)) return HAM_IGNORED;

	if(pev(iVictim, pev_classname) == g_iszAllocString_Hound) {
		static Float: flHealth; pev(iVictim, pev_health, flHealth);

		if(pev(iVictim, pev_health) <= flDamage) {
			UTIL_PlayAnim(iVictim, random_num(14, 15));
			set_pev(iVictim, pev_velocity, { 0.0, 0.0, 0.0 });
			set_pev(iVictim, pev_solid, SOLID_NOT);
			set_pev(iVictim, pev_movetype, MOVETYPE_TOSS);
			set_pev(iVictim, pev_takedamage, DAMAGE_NO);
			set_pev(iVictim, pev_deadflag, DEAD_DYING);

			emit_sound(iVictim, CHAN_WEAPON, szHoundSounds[random_num(5, 6)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
			client_print(iAttacker, print_center, "Hound HP: 0");
		}
		else client_print(iAttacker, print_center, "Hound HP: %d", floatround(flHealth));
	}

	return HAM_IGNORED;
}

public CEntity__Touch(iEntity, iTouch) {
	if(pev_valid(iEntity) != PDATA_SAFE) return HAM_IGNORED;

	if(pev(iEntity, pev_classname) == g_iszAllocString_Egg) {
		static Float: vecOrigin[3]; pev(iEntity, pev_origin, vecOrigin);

		if(engfunc(EngFunc_PointContents, vecOrigin) == CONTENTS_SKY || engfunc(EngFunc_PointContents, vecOrigin) == CONTENTS_WATER) {
			set_pev(iEntity, pev_flags, FL_KILLME);

			return HAM_IGNORED;
		}

		static iOwner; iOwner = pev(iEntity, pev_owner);

		if(!is_user_connected(iOwner)) {
			set_pev(iEntity, pev_flags, FL_KILLME);

			return HAM_IGNORED;
		}

		if(iTouch == iOwner) return HAM_SUPERCEDE;

		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
		write_byte(TE_EXPLOSION);
		engfunc(EngFunc_WriteCoord, vecOrigin[0]);
		engfunc(EngFunc_WriteCoord, vecOrigin[1]);
		engfunc(EngFunc_WriteCoord, vecOrigin[2] - 10.0);
		write_short(g_iszModelIndex_EggExplosion); // Id Sprite
		write_byte(10); // Sprite size
		write_byte(15); // Sprite framerate
		write_byte(TE_EXPLFLAG_NOSOUND | TE_EXPLFLAG_NOPARTICLES); // Sprite flags
		message_end();

		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
		write_byte(TE_SMOKE);
		engfunc(EngFunc_WriteCoord, vecOrigin[0]);
		engfunc(EngFunc_WriteCoord, vecOrigin[1]);
		engfunc(EngFunc_WriteCoord, vecOrigin[2] - 10.0);
		write_short(g_iszModelIndex_Smoke); // Id Sprite
		write_byte(60); // Sprite size
		write_byte(15); // Sprite framerate
		message_end();

		Create_Hound(iOwner, vecOrigin);
		emit_sound(iEntity, CHAN_WEAPON, EGG_SOUND_EXP, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

		set_pev(iEntity, pev_flags, FL_KILLME);
	}

	return HAM_IGNORED;
}

public CEntity__Think(iEntity) {
	if(pev_valid(iEntity) != PDATA_SAFE) return HAM_IGNORED;

	if(pev(iEntity, pev_classname) == g_iszAllocString_ShockWave) {
		static iOwner; iOwner = pev(iEntity, pev_owner);

		if(!is_user_connected(iOwner) || pev(iEntity, pev_renderamt) >= 255.0) {
			ExecuteHamB(Ham_Item_PreFrame, iOwner);
			set_pev(iEntity, pev_flags, FL_KILLME);

			return HAM_IGNORED;
		}

		static iVictim; iVictim = FM_NULLENT;
		static Float: vecOrigin[3]; pev(iOwner, pev_origin, vecOrigin);

		while((iVictim = engfunc(EngFunc_FindEntityInSphere, iVictim, vecOrigin, float(SHOCKWAVE_RADIUS))) != 0) {
			if(!is_user_alive(iVictim) || zp_get_user_zombie(iVictim)) continue;

			UTIL_CreateFakeDamage(iVictim, iOwner, SHOCKWAVE_DAMAGE);

			static Float: vecVicOrigin[3]; pev(iVictim, pev_origin, vecVicOrigin);
			static Float: flDistance; flDistance = get_distance_f(vecOrigin, vecVicOrigin);
			static Float: vecVelocity[3], Float: vecPunchAngle[3];

			vecVelocity[0] = (vecVicOrigin[0] - vecOrigin[0]) * (SHOCKWAVE_POWER / flDistance);
			vecVelocity[1] = (vecVicOrigin[1] - vecOrigin[1]) * (SHOCKWAVE_POWER / flDistance);
			vecVelocity[2] = random_float(0.0, 520.0);

			vecPunchAngle[0] = random_float(-25.0, 25.0);
			vecPunchAngle[1] = random_float(-25.0, 25.0);
			vecPunchAngle[2] = random_float(-25.0, 25.0);

			set_pev(iVictim, pev_velocity, vecVelocity);
			set_pev(iVictim, pev_punchangle, vecPunchAngle);
		}

		set_pev(iEntity, pev_renderamt, 255.0);
		set_pev(iEntity, pev_sequence, 0);
		set_pev(iEntity, pev_frame, 0.0);
		set_pev(iEntity, pev_framerate, 0.35);
		set_pev(iEntity, pev_animtime, get_gametime());
		set_pev(iEntity, pev_nextthink, get_gametime() + (SHOCKWAVE_TIME * 1.25));

		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
		write_byte(TE_BEAMCYLINDER);
		engfunc(EngFunc_WriteCoord, vecOrigin[0]);
		engfunc(EngFunc_WriteCoord, vecOrigin[1]);
		engfunc(EngFunc_WriteCoord, vecOrigin[2]);
		engfunc(EngFunc_WriteCoord, vecOrigin[0]);
		engfunc(EngFunc_WriteCoord, vecOrigin[1]);
		engfunc(EngFunc_WriteCoord, vecOrigin[2] + float(SHOCKWAVE_RADIUS));
		write_short(g_iszModelIndex_ShockWave); // sprite index
		write_byte(0); // starting frame
		write_byte(0); // frame rate in 0.1's
		write_byte(10); // life in 0.1's
		write_byte(20); // line width in 0.1's
		write_byte(50); // noise amplitude in 0.01's
		write_byte(255); // red
		write_byte(0); // green
		write_byte(0); // blue
		write_byte(255); // brightness
		write_byte(9); // scroll speed in 0.1's
		message_end();

		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
		write_byte(TE_BREAKMODEL);
		engfunc(EngFunc_WriteCoord, vecOrigin[0]); 
		engfunc(EngFunc_WriteCoord, vecOrigin[1]);
		engfunc(EngFunc_WriteCoord, vecOrigin[2]);
		write_coord(random_num(50, 100));
		write_coord(random_num(50, 100));
		write_coord(random_num(50, 100));
		write_coord(0);
		write_coord(0);
		write_coord(0);
		write_byte(random_num(10, 15));
		write_short(g_iszModelIndex_Gibs);
		write_byte(random_num(50, 100));
		write_byte(30);
		write_byte(0x03);
		message_end();
	}

	if(pev(iEntity, pev_classname) == g_iszAllocString_Hound) {
		switch(pev(iEntity, pev_deadflag)) {
			case DEAD_DYING: {
				set_pev(iEntity, pev_deadflag, DEAD_DEAD);
				set_pev(iEntity, pev_nextthink, get_gametime() + 301/30.0);

				return HAM_IGNORED;
			}
			case DEAD_DEAD: {
				set_pev(iEntity, pev_flags, FL_KILLME);

				return HAM_IGNORED;
			}
		}

		if(pev(iEntity, pev_takedamage) == DAMAGE_NO) {
			set_pev(iEntity, pev_solid, SOLID_SLIDEBOX);
			set_pev(iEntity, pev_takedamage, DAMAGE_YES);	
		}

		static iVictim; iVictim = pev(iEntity, pev_victim);
		static Float: vecOrigin[3]; pev(iEntity, pev_origin, vecOrigin);

		switch(pev(iEntity, pev_action)) {
			case ACT_IDLE: {
				if(pev(iEntity, pev_sequence) != ANIM_IDLE) {
					UTIL_PlayAnim(iEntity, ANIM_IDLE);
					set_pev(iEntity, pev_velocity, { 0.01, 0.01, 0.01 });
				}

				set_pev(iEntity, pev_victim, fnGetRandomAlive(random_num(1, fnGetAlive())));

				if(is_user_connected(iVictim)) {
					if(!zp_get_user_zombie(iVictim)) {
						static Float: vecVicOrigin[3]; pev(iVictim, pev_origin, vecVicOrigin);
						static Float: flDistance; flDistance = get_distance_f(vecOrigin, vecVicOrigin);

						if(flDistance <= HOUND_DIST_TARGET) {
							set_pev(iEntity, pev_action, ACT_RUN);
							set_pev(iEntity, pev_nextthink, get_gametime() + random_float(0.3, 1.0));

							return HAM_IGNORED;
						}
					}
				}
			}
			case ACT_RUN: {
				if(is_user_alive(iVictim) && !zp_get_user_zombie(iVictim)) {
					static Float: vecVicOrigin[3]; pev(iVictim, pev_origin, vecVicOrigin);
					static Float: flDistance; flDistance = get_distance_f(vecOrigin, vecVicOrigin);

					if(flDistance >= HOUND_DIST_TARGET || flDistance <= HOUND_DIST_ATTACK) {
						set_pev(iEntity, pev_action, flDistance <= HOUND_DIST_ATTACK ? ACT_ATTACK : ACT_IDLE);
						set_pev(iEntity, pev_nextthink, get_gametime());

						return HAM_IGNORED;
					}
				}

				if(!is_user_alive(iVictim) || zp_get_user_zombie(iVictim)) {
					set_pev(iEntity, pev_action, ACT_IDLE);
					set_pev(iEntity, pev_nextthink, get_gametime());

					return HAM_IGNORED;
				}
				if(pev(iEntity, pev_sequence) != ANIM_RUN) UTIL_PlayAnim(iEntity, ANIM_RUN);

				UTIL_SetEntityVelocity(iEntity, iVictim, HOUND_SPEED);
			}
			case ACT_ATTACK: {
				if(pev(iEntity, pev_sequence) != ANIM_ATTACK) {
					UTIL_PlayAnim(iEntity, ANIM_ATTACK);
					emit_sound(iEntity, CHAN_WEAPON, szHoundSounds[random_num(1, 2)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
					set_pev(iEntity, pev_velocity, { 0.01, 0.01, 0.01 });

					static iHit; iHit = FM_NULLENT;
					static iAttacker; iAttacker = pev(iEntity, pev_attacker);
					static Float: vecStartOrigin[3]; UTIL_GetPosition(iEntity, 30.0, 0.0, 30.0, vecStartOrigin);

					while((iHit = engfunc(EngFunc_FindEntityInSphere, iHit, vecStartOrigin, 30.0)) != 0) {
						if(pev(iHit, pev_takedamage) == DAMAGE_NO) continue;
						if(!is_user_alive(iHit) || zp_get_user_zombie(iHit)) continue;

						static Float: vecEndPos[3]; pev(iHit, pev_origin, vecEndPos);
						static Float: vecPunchAngle[3];

						vecPunchAngle[0] = random_float(-25.0, 25.0);
						vecPunchAngle[1] = random_float(-25.0, 25.0);
						vecPunchAngle[2] = random_float(-25.0, 25.0);

						UTIL_CreateFakeDamage(iHit, iAttacker, HOUND_DAMAGE);
						UTIL_BloodSprite(floatround(HOUND_DAMAGE), vecEndPos);
						set_pev(iHit, pev_punchangle, vecPunchAngle);

						message_begin(MSG_ONE, g_iMsgID_ScreenFade, _, iHit);
						write_short(1<<12); // Duration. Note: Duration and HoldTime is in special units. 1 second is equal to (1<<12) i.e. 4096 units.
						write_short(1<<12); // HoldTime
						write_short(0x0000); // Flags
						write_byte(255); // Red
						write_byte(0); // Green
						write_byte(0); // Blue
						write_byte(random_num(100, 110)); // Alpha
						message_end();

						set_pdata_float(iHit, m_flPainShock, 0.1, linux_diff_player);
					}
				}

				set_pev(iEntity, pev_action, ACT_IDLE);
				set_pev(iEntity, pev_nextthink, get_gametime() + 71/30.0);

				return HAM_IGNORED;
			}
		}

		set_pev(iEntity, pev_nextthink, get_gametime());
	}

	return HAM_IGNORED;
}

public CPlayer__PreFrame(iPlayer) {
	if(!is_user_alive(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_nemesis(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID)
		return HAM_IGNORED;

	static iEntity; iEntity = fm_find_ent_by_owner(-1, SHOCKWAVE_CLASSNAME, iPlayer);

	if(pev_valid(iEntity)) set_pev(iPlayer, pev_maxspeed, float(ZCLASS_SPEED));
	else if(g_iTimer[iPlayer][TIMER_CHARGE] >= (CHARGE_COOLDOWN - CHARGE_TIME)) set_pev(iPlayer, pev_maxspeed, 0.1);

	return HAM_IGNORED;
}

/* ~ [ Task's ] ~ */
public CTaskID__DashStart(iPlayer) {
	iPlayer -= TASKID_DASH;

	if(!is_user_alive(iPlayer) || zp_get_user_nemesis(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID)
		return;

	if(!(pev(iPlayer, pev_flags) & FL_ONGROUND) || pev(iPlayer, pev_flags) & FL_DUCKING || pev(iPlayer, pev_button) & IN_DUCK) {
		ResetValues(iPlayer);

		return;
	}

	set_task(0.1, "CTaskID__DashLoop", iPlayer + TASKID_DASH, _, _, "b");

	set_pev(iPlayer, pev_dmgtime, get_gametime() + 13/30.0);

	ExecuteHamB(Ham_Item_PreFrame, iPlayer);

	UTIL_PlayerAnimation(iPlayer, "skill_dash");
	UTIL_SendWeaponAnim(iPlayer, 10, 999.9);
	emit_sound(iPlayer, CHAN_AUTO, CHARGE_SOUND_START, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

	message_begin(MSG_ONE, g_iMsgID_ScreenFade, _, iPlayer);
	write_short(1<<12); // Duration. Note: Duration and HoldTime is in special units. 1 second is equal to (1<<12) i.e. 4096 units.
	write_short(1<<12); // HoldTime
	write_short(0x0000); // Flags
	write_byte(255); // Red
	write_byte(0); // Green
	write_byte(0); // Blue
	write_byte(random_num(100, 110)); // Alpha
	message_end();

	message_begin(MSG_ONE, g_iMsgID_ScreenShake, _, iPlayer);
	write_short(1<<15); // Amplitude
	write_short(1<<14); // Duration
	write_short(1<<14); // Frequency
	message_end();
}

public CTaskID__DashLoop(iPlayer) {
	iPlayer -= TASKID_DASH;

	if(!is_user_alive(iPlayer) || zp_get_user_nemesis(iPlayer) || !zp_get_user_zombie(iPlayer)
	|| zp_get_user_zombie_class(iPlayer) != g_iZClassID || g_iTimer[iPlayer][TIMER_CHARGE] <= (CHARGE_COOLDOWN - CHARGE_TIME)) {
		if(task_exists(iPlayer + TASKID_DASH)) remove_task(iPlayer + TASKID_DASH);
		if(is_user_alive(iPlayer)) Create_ShockWave(iPlayer);

		return;
	}

	static Float: flDmgTime; pev(iPlayer, pev_dmgtime, flDmgTime);
	
	if(flDmgTime <= get_gametime()) {
		UTIL_PlayerAnimation(iPlayer, "skill_dash");
		set_pev(iPlayer, pev_dmgtime, get_gametime() + 13/30.0);
	}

	UTIL_SetPlayerVelocity(iPlayer, CHARGE_SPEED);
}

public CTaskID__AbilitysReload(iPlayer) {
	iPlayer -= TASKID_ABILITYSRELOAD;

	if(!is_user_alive(iPlayer) || zp_get_user_nemesis(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID) {
		ResetValues(iPlayer);

		return;
	}

	if(g_iTimer[iPlayer][TIMER_CHARGE] <= 0 && g_iTimer[iPlayer][TIMER_HOUND] <= 0) {
		if(task_exists(iPlayer + TASKID_ABILITYSRELOAD)) remove_task(iPlayer + TASKID_ABILITYSRELOAD);

		return;
	}

	g_iTimer[iPlayer][TIMER_CHARGE] = g_iTimer[iPlayer][TIMER_CHARGE] <= 0 ? 0 : g_iTimer[iPlayer][TIMER_CHARGE] - 1;
	g_iTimer[iPlayer][TIMER_HOUND] = g_iTimer[iPlayer][TIMER_HOUND] <= 0 ? 0 : g_iTimer[iPlayer][TIMER_HOUND] - 1;
	
	set_hudmessage(128, 128, 0, 0.72, 0.90, 0, 6.0, 0.9);

	if(g_iTimer[iPlayer][TIMER_CHARGE] > 0 && g_iTimer[iPlayer][TIMER_HOUND] > 0)
		show_hudmessage(iPlayer, "[Charge: %d sec. | Hound: %d sec.]", g_iTimer[iPlayer][TIMER_CHARGE], g_iTimer[iPlayer][TIMER_HOUND]);
	else if(g_iTimer[iPlayer][TIMER_CHARGE] > 0 && g_iTimer[iPlayer][TIMER_HOUND] <= 0)
		show_hudmessage(iPlayer, "[Charge: %d sec. | Hound: Ready.]", g_iTimer[iPlayer][TIMER_CHARGE]);
	else if(g_iTimer[iPlayer][TIMER_CHARGE] <= 0 && g_iTimer[iPlayer][TIMER_HOUND] > 0)
		show_hudmessage(iPlayer, "[Charge: Ready. | Hound: %d sec.]", g_iTimer[iPlayer][TIMER_HOUND]);
}

public CTaskID__HoundThrow(iPlayer) {
	iPlayer -= TASKID_HOUNDTHROW;

	if(!is_user_alive(iPlayer) || zp_get_user_nemesis(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID)
		return;

	Create_Egg(iPlayer);

	UTIL_PlayerAnimation(iPlayer, "skill_egg_shoot");
	UTIL_SendWeaponAnim(iPlayer, 14, 31/30.0);
	emit_sound(iPlayer, CHAN_AUTO, EGG_SOUND_THROW, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

/* ~ [ Other ] ~ */
public ResetValues(iPlayer) {
	g_iTimer[iPlayer][TIMER_CHARGE] = 0;
	g_iTimer[iPlayer][TIMER_HOUND] = 0;

	if(task_exists(iPlayer + TASKID_ABILITYSRELOAD)) remove_task(iPlayer + TASKID_ABILITYSRELOAD);
	if(task_exists(iPlayer + TASKID_DASH)) remove_task(iPlayer + TASKID_DASH);
}

public Create_ShockWave(iPlayer) {
	new iEntity = engfunc(EngFunc_CreateNamedEntity, g_iszAllocString_InfoTarget);

	static Float: vecOrigin[3]; pev(iPlayer, pev_origin, vecOrigin);
	
	set_pev_string(iEntity, pev_classname, g_iszAllocString_ShockWave);
	set_pev(iEntity, pev_owner, iPlayer);
	set_pev(iEntity, pev_renderfx, kRenderFxNone);
	set_pev(iEntity, pev_rendermode, kRenderTransAdd);
	set_pev(iEntity, pev_renderamt, 0.0);

	engfunc(EngFunc_SetModel, iEntity, SHOCKWAVE_MODEL);
	engfunc(EngFunc_SetOrigin, iEntity, vecOrigin);

	UTIL_PlayerAnimation(iPlayer, "skill_dash_finish");
	UTIL_SendWeaponAnim(iPlayer, 12, 40/30.0);
	emit_sound(iPlayer, CHAN_AUTO, CHARGE_SOUND_END, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

	set_pev(iPlayer, pev_velocity, { 0.0, 0.0, 0.0 });
	set_pev(iEntity, pev_nextthink, get_gametime() + SHOCKWAVE_TIME);
}

public Create_Egg(iPlayer) {
	new iEntity = engfunc(EngFunc_CreateNamedEntity, g_iszAllocString_InfoTarget);

	static Float: vecOrigin[3]; pev(iPlayer, pev_origin, vecOrigin);
	static Float: vecViewOfs[3]; pev(iPlayer, pev_view_ofs, vecViewOfs);
	static Float: vecAngles[3]; pev(iPlayer, pev_angles, vecAngles);
	static Float: vecVelocity[3]; velocity_by_aim(iPlayer, EGG_SPEED, vecVelocity);

	vecOrigin[0] += vecViewOfs[0];
	vecOrigin[1] += vecViewOfs[1];
	vecOrigin[2] += vecViewOfs[2];
	
	set_pev_string(iEntity, pev_classname, g_iszAllocString_Egg);
	set_pev(iEntity, pev_owner, iPlayer);
	set_pev(iEntity, pev_solid, SOLID_TRIGGER);
	set_pev(iEntity, pev_movetype, MOVETYPE_TOSS);
	set_pev(iEntity, pev_velocity, vecVelocity);
	engfunc(EngFunc_VecToAngles, vecVelocity, vecAngles);
	set_pev(iEntity, pev_angles, vecAngles);
	set_pev(iEntity, pev_gravity, 0.50);
	set_pev(iEntity, pev_sequence, 0);
	set_pev(iEntity, pev_frame, 0.0);
	set_pev(iEntity, pev_framerate, random_float(5.0, 15.0));
	set_pev(iEntity, pev_animtime, get_gametime());

	engfunc(EngFunc_SetModel, iEntity, EGG_MODEL);
	engfunc(EngFunc_SetOrigin, iEntity, vecOrigin);
	engfunc(EngFunc_SetSize, iEntity, Float: { -10.0, -10.0, 0.0 }, Float: { 10.0, 10.0, 0.0 }); // Желательно не менять
}

public Create_Hound(iPlayer, Float: vecOrigin[3]) {
	new iEntity = engfunc(EngFunc_CreateNamedEntity, g_iszAllocString_InfoTarget);
	
	static Float: vecAngles[3], Float: vecDirection[3];

	vecAngles[0] = 0.0;
	vecAngles[1] = random_float(-360.0, 360.0);
	vecAngles[2] = 0.0;

	set_pev_string(iEntity, pev_classname, g_iszAllocString_Hound);
	set_pev(iEntity, pev_attacker, iPlayer);
	set_pev(iEntity, pev_victim, -1);
	set_pev(iEntity, pev_deadflag, DEAD_NO);
	set_pev(iEntity, pev_solid, SOLID_NOT);
	set_pev(iEntity, pev_movetype, MOVETYPE_PUSHSTEP);
	set_pev(iEntity, pev_takedamage, DAMAGE_NO);
	set_pev(iEntity, pev_health, float(HOUND_HEALTH));

	engfunc(EngFunc_SetModel, iEntity, HOUND_MODEL);
	engfunc(EngFunc_SetOrigin, iEntity, vecOrigin);
	engfunc(EngFunc_SetSize, iEntity, Float: { -10.0, -10.0, 0.0 }, Float: { 10.0, 10.0, 30.0 });
	engfunc(EngFunc_DropToFloor, iEntity);

	set_pev(iEntity, pev_action, ACT_IDLE);
	UTIL_PlayAnim(iEntity, ANIM_APPEAR);

	angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecDirection);
	xs_vec_mul_scalar(vecDirection, 260.0, vecDirection);

	vecDirection[2] = 260.0;

	set_pev(iEntity, pev_angles, vecAngles);
	set_pev(iEntity, pev_velocity, vecDirection);
	set_pev(iEntity, pev_nextthink, get_gametime() + HOUND_APPEAR);

	emit_sound(iEntity, CHAN_WEAPON, szHoundSounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

/* ~ [ Stock's ] ~ */
stock fnGetAlive() {
	static iAlive, id
	iAlive = 0
	
	for (id = 1; id <= g_iMaxPlayers; id++)
	{
		if (is_user_alive(id))
			iAlive++
	}
	
	return iAlive;
}
stock fnGetRandomAlive(n) {
	static iAlive, id
	iAlive = 0
	
	for (id = 1; id <= g_iMaxPlayers; id++)
	{
		if (is_user_alive(id))
			iAlive++
		
		if (iAlive == n)
			return id;
	}
	
	return -1;
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
stock UTIL_BloodSprite(iAmount, Float: vecOrigin[3]) {
	if(iAmount > 255) iAmount = 255;

	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
	write_byte(TE_BLOODSPRITE);
	engfunc(EngFunc_WriteCoord, vecOrigin[0]);
	engfunc(EngFunc_WriteCoord, vecOrigin[1]);
	engfunc(EngFunc_WriteCoord, vecOrigin[2]);
	write_short(g_iszModelIndex_BloodSpray);
	write_short(g_iszModelIndex_Blood);
	write_byte(247);
	write_byte(min(max(3, iAmount / 10), 16));
	message_end();
}
stock UTIL_SetEntityVelocity(iEntity, iVictim, Float: flSpeed) {
	static Float: vecOrigin[3]; pev(iEntity, pev_origin, vecOrigin);
	static Float: vecVicOrigin[3]; pev(iVictim, pev_origin, vecVicOrigin);
	static Float: flDistance; flDistance = get_distance_f(vecOrigin, vecVicOrigin);
	static Float: vecVelocity[3];
	static Float: vecAngles[3];

	vecVelocity[0] = (vecVicOrigin[0] - vecOrigin[0]) * (flSpeed / flDistance);
	vecVelocity[1] = (vecVicOrigin[1] - vecOrigin[1]) * (flSpeed / flDistance);
	vecVelocity[2] = 0.0;

	vector_to_angle(vecVelocity, vecAngles);

	vecAngles[0] = 0.0;
	vecAngles[2] = 0.0;

	engfunc(EngFunc_DropToFloor, iEntity);

	set_pev(iEntity, pev_angles, vecAngles);
	set_pev(iEntity, pev_velocity, vecVelocity);
}
stock UTIL_PlayAnim(iIndex, iAnim, Float: flFramerate = 1.0) {
	set_pev(iIndex, pev_sequence, iAnim);
	set_pev(iIndex, pev_frame, 0.0);
	set_pev(iIndex, pev_framerate, flFramerate);
	set_pev(iIndex, pev_animtime, get_gametime());
}
stock UTIL_SetPlayerVelocity(iPlayer, Float: flSpeed) {
	static Float: vecAngles[3]; pev(iPlayer, pev_angles, vecAngles);
	static Float: vecDirection[3];

	vecAngles[0] = 0.0;
	vecAngles[2] = 0.0;

	angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecDirection);
	xs_vec_mul_scalar(vecDirection, flSpeed, vecDirection);

	engfunc(EngFunc_DropToFloor, iPlayer);

	set_pev(iPlayer, pev_angles, vecAngles);
	set_pev(iPlayer, pev_velocity, vecDirection);
}
stock UTIL_CreateFakeDamage(const iVictim, const iAttacker, Float: flDamage) {
	static Float: flDmg; flDmg = flDamage;

	if(pev(iVictim, pev_health) - flDmg <= flDmg) ExecuteHamB(Ham_Killed, iVictim, iAttacker, 0);
	else set_pev(iVictim, pev_health, pev(iVictim, pev_health) - flDmg);
}
stock UTIL_PlayerAnimation(const iPlayer, const szAnim[]) {
	new iAnimDesired, Float: flFrameRate, Float: flGroundSpeed, bool: bLoops;

	if((iAnimDesired = lookup_sequence(iPlayer, szAnim, flFrameRate, bLoops, flGroundSpeed)) == -1) iAnimDesired = 0;

	set_pev(iPlayer, pev_sequence, iAnimDesired);
	set_pev(iPlayer, pev_gaitsequence, iAnimDesired);
	set_pev(iPlayer, pev_frame, 0.0);
	set_pev(iPlayer, pev_framerate, 1.0);
	set_pev(iPlayer, pev_animtime, get_gametime());
	
	set_pdata_int(iPlayer, m_fSequenceLoops, bLoops, linux_diff_animating);
	set_pdata_int(iPlayer, m_fSequenceFinished, 0, linux_diff_animating);
	
	set_pdata_float(iPlayer, m_flFrameRate, flFrameRate, linux_diff_animating);
	set_pdata_float(iPlayer, m_flGroundSpeed, flGroundSpeed, linux_diff_animating);
	set_pdata_float(iPlayer, m_flLastEventCheck, get_gametime(), linux_diff_animating);
	
	set_pdata_int(iPlayer, m_Activity, ACT_RANGE_ATTACK1, linux_diff_player);
	set_pdata_int(iPlayer, m_IdealActivity, ACT_RANGE_ATTACK1, linux_diff_player);
	set_pdata_float(iPlayer, m_flLastAttackTime, get_gametime(), linux_diff_player);
}
stock UTIL_SendWeaponAnim(iPlayer, iAnim, Float: flTime) {
	set_pev(iPlayer, pev_weaponanim, iAnim);

	message_begin(MSG_ONE, SVC_WEAPONANIM, _, iPlayer);
	write_byte(iAnim);
	write_byte(0);
	message_end();

	static iItem; iItem = get_pdata_cbase(iPlayer, m_pActiveItem, linux_diff_player);

	set_pdata_float(iItem, m_flNextPrimaryAttack, flTime, linux_diff_weapon);
	set_pdata_float(iItem, m_flNextSecondaryAttack, flTime, linux_diff_weapon);
	set_pdata_float(iItem, m_flTimeWeaponIdle, flTime, linux_diff_weapon);
}
stock UTIL_ColorChat(iPlayer, const Text[], any:...) {
	static iMsg[128]; vformat(iMsg, charsmax(iMsg), Text, 3);

	replace_all(iMsg, charsmax(iMsg), "!y", "^x01");
	replace_all(iMsg, charsmax(iMsg), "!t", "^x03");
	replace_all(iMsg, charsmax(iMsg), "!g", "^x04");

	message_begin(MSG_ONE, g_iMsgID_SayText, _, iPlayer);
	write_byte(iPlayer);
	write_string(iMsg);
	message_end();
}