#include amxmodx
#include fakemeta_util
#include hamsandwich
#include <zombieplague>

/* ~ [ Macroses ] ~ */
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
#define m_flLastAttackTime 220
#define m_pActiveItem 373
#define m_szAnimExtention 492

/* ~ [ ZClass Setting's ] ~ */
#define ZCLASS_NAME						"Arachne"
#define ZCLASS_INFO						"\y[ Hook | Bomb \y]"
#define ZCLASS_MODEL 					"zombi_spider"
#define ZCLASS_CLAWMODEL				"v_knife_zombispider.mdl"
#define ZCLASS_BOMBMODEL				"models/zombie_plague/v_zombibomb_spider.mdl"
#define ZCLASS_HEALTH					1800
#define ZCLASS_SPEED					260	
#define ZCLASS_GRAVITY 					0.65
#define ZCLASS_KNOCKBACK				1.0

/* ~ [ Tightrope Setting's ] ~ */
#define TIGHTROPE_CLASSNAME				"Tightrope" // Класснейм паутины
#define TIGHTROPE_MODEL					TIGHTROPE_SPRITE // Модель паутины ( Может быть любая... всё равно renderamt = 0.0)
#define TIGHTROPE_SOUND_START			"inf142/zombie/arachne/spider_skill2_start.wav" // Звук выпуска паутины
#define TIGHTROPE_SOUND_SUCCES			"inf142/zombie/arachne/spider_succes.wav" // Звук когда паутина коснулась
#define TIGHTROPE_SPRITE				"sprites/inf142/zb5_spider_effect_web.spr" // Спрайт от игрока до паутины (Beam / Trail)
#define TIGHTROPE_VELOCITY				1300 // Скорость паутины
#define TIGHTROPE_SPEED					750 // Скорость притягивания
#define TIGHTROPE_COOLDOWN				5 // Перезарядка способности
#define TIGHTROPE_ANIMATION 			112 // Анимация полёта (skill_loop), чтобы не сбивалась анимка...
new const TIGHTROPE_ANIMATIONS[][] =	{ "skill_shoot", "skill_loop" };

/* ~ [ Spiderweb Bomb Setting's ] ~ */
#define WEBBOMB_CLASSNAME				"Spiderweb Bomb" // Класснейм бомбы
#define WEBBOMB_MODEL					"models/inf142/zombie/arachne/zb5_za_webbomb.mdl" // Модель бомбы
#define WEBBOMB_SOUND					"inf142/zombie/arachne/spider_skill1.wav" // Звук кидания бомбы
#define WEBBOMB_DAMAGE					20 // dmg
#define WEBBOMB_RADIUS					240 // radius
#define WEBBOMB_VELOCITY				1000 // Скорость бомбы
#define WEBBOMB_COOLDOWN				2 // Перезарядка способности

/* ~ [ Web Trap Setting's ] ~ */
#define WEBTRAP_CLASSNAME				"Web Trap" // Класснейм ловушки
#define WEBTRAP_MODEL					"models/inf142/zombie/arachne/zb5_za_webtrap.mdl" // Модель ловушки
#define WEBTRAP_SLOWMOVE				random_float(0.90, 0.95) // замедление
#define WEBTRAP_TIME					5.0 // через сколько секунд удалить ловушку

/* ~ [ Task's ] ~ */
#define TASKID_TIGHTROPE				260720201458
#define TASKID_WEBBOMB					260720202117

enum _: e_Abilitys {
	Tightrope = 0,
	WebBomb
};

/* ~ [ Param's ] ~ */
new g_iZClassID,

	g_iTimer[33][e_Abilitys],

	g_iMsgID_SayText,

	g_iszAllocString_InfoTarget,
	g_iszAllocString_Tightrope,
	g_iszAllocString_WebBomb,
	g_iszAllocString_WebTrap,
	g_iszAllocString_ModelView,

	g_iszModelIndex_Tightrope;


new const szWeaponNames[][] = { "weapon_smokegrenade" , "weapon_hegrenade" };

/* ~ [ AMX Mod X ] ~ */
public plugin_init() {
	register_plugin("[CSO Like] ZClass: Arachne", "1.0", "CS-SELL.COM");

	// Message's
	g_iMsgID_SayText = get_user_msgid("SayText");

	// Ham's
	for(new i = 0; i < sizeof szWeaponNames; i++) RegisterHam(Ham_Item_Deploy,		szWeaponNames[i],	"CKnife__Deploy", true);
	RegisterHam(Ham_Item_PostFrame,		"weapon_knife",		"CKnife__PostFrame", false);
	RegisterHam(Ham_Touch,				"info_target",		"CEntity__Touch", false);
	RegisterHam(Ham_Think,				"info_target",		"CEntity__Think", false);

	// Other
	register_clcmd("drop",				"CPlayer__WebBomb");
}

public plugin_precache() {
	// Precache models
	engfunc(EngFunc_PrecacheModel, TIGHTROPE_MODEL);
	engfunc(EngFunc_PrecacheModel, WEBBOMB_MODEL);
	engfunc(EngFunc_PrecacheModel, WEBTRAP_MODEL);
	engfunc(EngFunc_PrecacheModel, ZCLASS_BOMBMODEL);

	// Precache sounds
	engfunc(EngFunc_PrecacheSound, TIGHTROPE_SOUND_START);
	engfunc(EngFunc_PrecacheSound, TIGHTROPE_SOUND_SUCCES);
	engfunc(EngFunc_PrecacheSound, WEBBOMB_SOUND);

	// Alloc String
	g_iszAllocString_InfoTarget = engfunc(EngFunc_AllocString, "info_target");
	g_iszAllocString_Tightrope = engfunc(EngFunc_AllocString, TIGHTROPE_CLASSNAME);
	g_iszAllocString_WebBomb = engfunc(EngFunc_AllocString, WEBBOMB_CLASSNAME);
	g_iszAllocString_WebTrap = engfunc(EngFunc_AllocString, WEBTRAP_CLASSNAME);
	g_iszAllocString_ModelView = engfunc(EngFunc_AllocString, ZCLASS_BOMBMODEL);

	// Model Index
	g_iszModelIndex_Tightrope = engfunc(EngFunc_PrecacheModel, TIGHTROPE_SPRITE);

	// Registering a zombie class
	g_iZClassID = zp_register_class(CLASS_ZOMBIE, ZCLASS_NAME, ZCLASS_INFO, ZCLASS_MODEL, ZCLASS_CLAWMODEL, 
		15, 2, ADMIN_ALL, ZCLASS_HEALTH, 0, ZCLASS_SPEED, ZCLASS_GRAVITY, ZCLASS_KNOCKBACK);
}

public client_putinserver(iPlayer) ResetValues(iPlayer);

/* ~ [ Zombie Plague ] ~ */
public zp_user_infected_post(iPlayer) {
	if(!zp_get_user_nemesis(iPlayer) && zp_get_user_zombie_class(iPlayer) == g_iZClassID) {
		ResetValues(iPlayer);
		UTIL_ColorChat(iPlayer, "!y[!gArachne!y] Tu habilidad [!gHook -> R | Bomb -> G!y]");
	}
}
public zp_user_humanized_post(iPlayer) if(zp_get_user_zombie_class(iPlayer) == g_iZClassID) ResetValues(iPlayer);

public CPlayer__WebBomb(iPlayer) {
	if(!is_user_alive(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_nemesis(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID)
		return PLUGIN_CONTINUE;

	if(!g_iTimer[iPlayer][WebBomb]) {
		g_iTimer[iPlayer][WebBomb] = WEBBOMB_COOLDOWN;

		set_task(1.0, "CTaskID__WebBomb", iPlayer + TASKID_WEBBOMB, _, _, "b");

		CEntity__WebBomb(iPlayer);

		UTIL_SendWeaponAnim(iPlayer, 8, 31/30.0);
		emit_sound(iPlayer, CHAN_AUTO, WEBBOMB_SOUND, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	}

	return PLUGIN_HANDLED;
}

/* ~ [ HamSandWich ] ~ */
public CKnife__Deploy(iItem) {
	static iPlayer; iPlayer = get_pdata_cbase(iItem, m_pPlayer, linux_diff_weapon);

	if(!zp_get_user_zombie(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID) return;

	set_pev_string(iPlayer, pev_viewmodel2, g_iszAllocString_ModelView);
}

public CKnife__PostFrame(iItem) {
	static iPlayer; iPlayer = get_pdata_cbase(iItem, m_pPlayer, linux_diff_weapon);

	if(zp_get_user_nemesis(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID
	|| g_iTimer[iPlayer][Tightrope]) return HAM_IGNORED;

	if(pev(iPlayer, pev_button) & IN_RELOAD) {
		g_iTimer[iPlayer][Tightrope] = TIGHTROPE_COOLDOWN;

		set_task(1.0, "CTaskID__Tightrope", iPlayer + TASKID_TIGHTROPE, _, _, "b");

		CEntity__Tightrope(iPlayer);

		UTIL_PlayerAnimation(iPlayer, TIGHTROPE_ANIMATIONS[0]);
		UTIL_SendWeaponAnim(iPlayer, 9, 21/1.0);
		emit_sound(iPlayer, CHAN_AUTO, TIGHTROPE_SOUND_START, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	}

	return HAM_IGNORED;
}

public CEntity__Touch(iEntity, iTouch) {
	if(pev_valid(iEntity) != 2) return HAM_IGNORED;

	if(pev(iEntity, pev_classname) == g_iszAllocString_Tightrope) {
		static iOwner; iOwner = pev(iEntity, pev_owner);

		if(!is_user_alive(iOwner) || !zp_get_user_zombie(iOwner) || zp_get_user_nemesis(iOwner)) {
			UTIL_KillBeam(iOwner);
			set_pev(iEntity, pev_flags, FL_KILLME);

			return HAM_IGNORED;
		}

		if(iTouch == iOwner) return HAM_SUPERCEDE;
		if(is_user_alive(iTouch)) {
			UTIL_KillBeam(iOwner);
			UTIL_SendWeaponAnim(iOwner, 11, 20/30.0);

			set_pev(iEntity, pev_flags, FL_KILLME);

			return HAM_IGNORED;
		}

		if(pev(iEntity, pev_solid) != SOLID_NOT) {
			UTIL_SendWeaponAnim(iOwner, 10, 90/30.0);
			emit_sound(iOwner, CHAN_AUTO, TIGHTROPE_SOUND_SUCCES, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

			UTIL_PlayerAnimation(iOwner, TIGHTROPE_ANIMATIONS[1]);
			fm_set_rendering(iOwner, kRenderFxGlowShell, random_num(100, 125), 0, 0, kRenderNormal, 1);

			set_pev(iEntity, pev_solid, SOLID_NOT);
			set_pev(iEntity, pev_movetype, MOVETYPE_NONE);
			set_pev(iEntity, pev_dmgtime, get_gametime() + 80/30.0);
			set_pev(iEntity, pev_nextthink, get_gametime());
		}
	}

	if(pev(iEntity, pev_classname) == g_iszAllocString_WebBomb) {
		static iOwner; iOwner = pev(iEntity, pev_owner);
		static Float: vecOrigin[3]; pev(iEntity, pev_origin, vecOrigin);

		if(!is_user_connected(iOwner) || engfunc(EngFunc_PointContents, vecOrigin) == CONTENTS_SKY) {
			set_pev(iEntity, pev_flags, FL_KILLME);

			return HAM_IGNORED;
		}

		if(iTouch == iOwner) return HAM_SUPERCEDE;

		iTouch = FM_NULLENT;

		while((iTouch = engfunc(EngFunc_FindEntityInSphere, iTouch, vecOrigin, float(WEBBOMB_RADIUS))) != 0) {
			if(pev(iTouch, pev_takedamage) == DAMAGE_NO) continue;
			if(!is_user_alive(iTouch) || zp_get_user_zombie(iTouch)) continue;

			if(pev(iTouch, pev_health) - float(WEBBOMB_DAMAGE) <= float(WEBBOMB_DAMAGE)) ExecuteHamB(Ham_Killed, iTouch, iOwner, 0);
			else set_pev(iTouch, pev_health, pev(iTouch, pev_health) - float(WEBBOMB_DAMAGE));
		}

		CEntity__WebTrap(vecOrigin);

		set_pev(iEntity, pev_flags, FL_KILLME);
	}

	if(pev(iEntity, pev_classname) == g_iszAllocString_WebTrap) {
		if(iTouch) {
			if(is_user_alive(iTouch))
				if(!zp_get_user_zombie(iTouch)) {
					static Float: vecVelocity[3]; pev(iTouch, pev_velocity, vecVelocity);

					vecVelocity[0] *= WEBTRAP_SLOWMOVE;
					vecVelocity[1] *= WEBTRAP_SLOWMOVE;

					set_pev(iTouch, pev_velocity, vecVelocity);
				}
		}
	}

	return HAM_IGNORED;
}

public CEntity__Think(iEntity) {
	if(pev_valid(iEntity) != 2) return HAM_IGNORED;

	if(pev(iEntity, pev_classname) == g_iszAllocString_Tightrope) {
		static iOwner; iOwner = pev(iEntity, pev_owner);

		if(!is_user_alive(iOwner) || !zp_get_user_zombie(iOwner) || zp_get_user_nemesis(iOwner)) {
			UTIL_KillBeam(iOwner);
			set_pev(iEntity, pev_flags, FL_KILLME);

			return HAM_IGNORED;
		}

		static Float: vecOrigin[3]; pev(iOwner, pev_origin, vecOrigin);
		static Float: vecEntOrigin[3]; pev(iEntity, pev_origin, vecEntOrigin);
		static Float: flDistance; flDistance = get_distance_f(vecEntOrigin, vecOrigin);
		static Float: flDmgTime; pev(iEntity, pev_dmgtime, flDmgTime);

		if(flDistance <= 40.0 || flDmgTime <= get_gametime()) {
			UTIL_KillBeam(iOwner);
			fm_set_rendering(iOwner);

			set_pev(iEntity, pev_flags, FL_KILLME);

			return HAM_IGNORED;
		}
		if(pev(iOwner, pev_sequence) != TIGHTROPE_ANIMATION || pev(iOwner, pev_gaitsequence) != TIGHTROPE_ANIMATION) UTIL_PlayerAnimation(iOwner, TIGHTROPE_ANIMATIONS[1]);

		static Float: vecVelocity[3];

		vecVelocity[0] = (vecEntOrigin[0] - vecOrigin[0]) * (float(TIGHTROPE_SPEED) / flDistance);
		vecVelocity[1] = (vecEntOrigin[1] - vecOrigin[1]) * (float(TIGHTROPE_SPEED) / flDistance);
		vecVelocity[2] = (vecEntOrigin[2] - vecOrigin[2]) * (float(TIGHTROPE_SPEED) / flDistance);

		set_pev(iOwner, pev_velocity, vecVelocity);
		set_pev(iEntity, pev_nextthink, get_gametime());
	}

	if(pev(iEntity, pev_classname) == g_iszAllocString_WebTrap) set_pev(iEntity, pev_flags, FL_KILLME);

	return HAM_IGNORED;
}

/* ~ [ Task's ] ~ */
public CTaskID__Tightrope(iPlayer) {
	iPlayer -= TASKID_TIGHTROPE;

	if(!is_user_alive(iPlayer) || zp_get_user_nemesis(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID
	|| g_iTimer[iPlayer][Tightrope] <= 1) {
		if(task_exists(iPlayer + TASKID_TIGHTROPE)) remove_task(iPlayer + TASKID_TIGHTROPE);

		g_iTimer[iPlayer][Tightrope] = 0;

		return;
	}

	g_iTimer[iPlayer][Tightrope] -= 1;

	set_hudmessage(128, 128, 0, 0.72, 0.90, 0, 6.0, 0.9);
	show_hudmessage(iPlayer, "[Hook: recharge %d sec.]", g_iTimer[iPlayer][Tightrope]);
}

public CTaskID__WebBomb(iPlayer) {
	iPlayer -= TASKID_WEBBOMB;

	if(!is_user_alive(iPlayer) || zp_get_user_nemesis(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iZClassID
	|| g_iTimer[iPlayer][WebBomb] <= 1) {
		if(task_exists(iPlayer + TASKID_WEBBOMB)) remove_task(iPlayer + TASKID_WEBBOMB);

		g_iTimer[iPlayer][WebBomb] = 0;

		return;
	}

	g_iTimer[iPlayer][WebBomb] -= 1;

	set_hudmessage(128, 128, 0, 0.72, 0.925, 0, 6.0, 0.9);
	show_hudmessage(iPlayer, "[Bomb: recharge %d sec.]", g_iTimer[iPlayer][WebBomb]);
}

/* ~ [ Other ] ~ */
public ResetValues(iPlayer) {
	g_iTimer[iPlayer][Tightrope] = 0;
	g_iTimer[iPlayer][WebBomb] = 0;

	if(task_exists(iPlayer + TASKID_TIGHTROPE)) remove_task(iPlayer + TASKID_TIGHTROPE);
	if(task_exists(iPlayer + TASKID_WEBBOMB)) remove_task(iPlayer + TASKID_WEBBOMB);
}

public CEntity__Tightrope(iPlayer) {
	static iTightrope; iTightrope = fm_find_ent_by_owner(-1, TIGHTROPE_CLASSNAME, iPlayer);

	if(pev_valid(iTightrope)) set_pev(iTightrope, pev_flags, FL_KILLME);

	new iEntity = engfunc(EngFunc_CreateNamedEntity, g_iszAllocString_InfoTarget);

	static Float: vecOrigin[3]; pev(iPlayer, pev_origin, vecOrigin);
	static Float: vecViewOfs[3]; pev(iPlayer, pev_view_ofs, vecViewOfs);
	static Float: vecVelocity[3]; velocity_by_aim(iPlayer, TIGHTROPE_VELOCITY, vecVelocity);

	vecOrigin[0] += vecViewOfs[0];
	vecOrigin[1] += vecViewOfs[1];
	vecOrigin[2] += vecViewOfs[2];

	set_pev_string(iEntity, pev_classname, g_iszAllocString_Tightrope);
	set_pev(iEntity, pev_owner, iPlayer);
	set_pev(iEntity, pev_solid, SOLID_TRIGGER);
	set_pev(iEntity, pev_movetype, MOVETYPE_FLY);
	set_pev(iEntity, pev_velocity, vecVelocity);
	set_pev(iEntity, pev_renderfx, kRenderFxNone);
	set_pev(iEntity, pev_rendermode, kRenderTransAdd);
	set_pev(iEntity, pev_renderamt, 0.0);

	engfunc(EngFunc_SetModel, iEntity, TIGHTROPE_MODEL);
	engfunc(EngFunc_SetSize, iEntity, Float: { -1.0, -1.0, -1.0 }, { 1.0, 1.0, 1.0 });
	engfunc(EngFunc_SetOrigin, iEntity, vecOrigin);

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMENTS);				// TE_BEAMENTS
	write_short(iEntity);			// start entity
	write_short(iPlayer);			// end entity
	write_short(g_iszModelIndex_Tightrope);			// sprite index
	write_byte(0);				// start frame
	write_byte(0);				// framerate
	write_byte(999999999);				// life
	write_byte(random_num(50, 75));				// width
	write_byte(random_num(0, 1));				// noise
	write_byte(255);			// r
	write_byte(255);			// g
	write_byte(255);			// b
	write_byte(255);				// brightness
	write_byte(100);				// speed
	message_end();
}

public CEntity__WebBomb(iPlayer) {
	new iEntity = engfunc(EngFunc_CreateNamedEntity, g_iszAllocString_InfoTarget);

	static Float: vecOrigin[3]; pev(iPlayer, pev_origin, vecOrigin);
	static Float: vecViewOfs[3]; pev(iPlayer, pev_view_ofs, vecViewOfs);
	static Float: vecVelocity[3]; velocity_by_aim(iPlayer, WEBBOMB_VELOCITY, vecVelocity);

	vecOrigin[0] += vecViewOfs[0];
	vecOrigin[1] += vecViewOfs[1];
	vecOrigin[2] += vecViewOfs[2];

	set_pev_string(iEntity, pev_classname, g_iszAllocString_WebBomb);
	set_pev(iEntity, pev_owner, iPlayer);
	set_pev(iEntity, pev_solid, SOLID_TRIGGER);
	set_pev(iEntity, pev_movetype, MOVETYPE_TOSS);
	set_pev(iEntity, pev_velocity, vecVelocity);
	set_pev(iEntity, pev_gravity, 0.75);

	engfunc(EngFunc_SetModel, iEntity, WEBBOMB_MODEL);
	engfunc(EngFunc_SetOrigin, iEntity, vecOrigin);
}

public CEntity__WebTrap(Float: vecOrigin[3]) {
	new iEntity = engfunc(EngFunc_CreateNamedEntity, g_iszAllocString_InfoTarget);

	set_pev_string(iEntity, pev_classname, g_iszAllocString_WebTrap);
	set_pev(iEntity, pev_solid, SOLID_TRIGGER);
	set_pev(iEntity, pev_movetype, MOVETYPE_TOSS);
	set_pev(iEntity, pev_gravity, 100.0);

	engfunc(EngFunc_SetModel, iEntity, WEBTRAP_MODEL);
	engfunc(EngFunc_SetSize, iEntity, Float: { -149.690002, -148.229996, -0.190000 }, { 150.240005, 151.000000, 2.570000 });
	engfunc(EngFunc_SetOrigin, iEntity, vecOrigin);

	set_pev(iEntity, pev_nextthink, get_gametime() + WEBTRAP_TIME);
}

/* ~ [ Stock's ] ~ */
stock UTIL_PlayerAnimation(const iPlayer, const szAnim[]) {
	new iAnimDesired, Float: flFrameRate, Float: flGroundSpeed, bool: bLoops;

	if((iAnimDesired = lookup_sequence(iPlayer, szAnim, flFrameRate, bLoops, flGroundSpeed)) == -1) iAnimDesired = 0;

	set_pev(iPlayer, pev_sequence, iAnimDesired);
	set_pev(iPlayer, pev_gaitsequence, iAnimDesired);
	set_pev(iPlayer, pev_frame, 1.0);
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
stock UTIL_KillBeam(iPlayer) {
	message_begin(MSG_ALL, SVC_TEMPENTITY);
	write_byte(TE_KILLBEAM); // TE
	write_short(iPlayer); // Target
	message_end();
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