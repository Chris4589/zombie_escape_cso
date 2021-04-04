/**
 *
 * Название: Flying Zombie
 * Автор: vk.com/solkept
 * Зомби перестройка [2019]
 * MADE IN - CS-FADE.RU
 *
 */
 
#include amxmodx
#include fakemeta
#include hamsandwich
#include <zombieplague>
#include fun

new const g_iTaskCooldown				= 61677775;
new const g_iTaskDownhillEnd			= 71871379;
new const g_iTaskDownhillStart			= 71891738;
new const g_iTaskFlyEnd					= 23783758;
new const g_iTaskFlyIdle				= 27869755;
new const g_iTaskFlySound				= 27611333;
new const g_iTaskFlyStart				= 68468633;
new const g_iTaskSpeedEnd				= 79791555;

new const Float:g_flCooldownSpeed		= 20.0; //Длительность кулдауна разгона
new const Float:g_flDurationSpeed		= 4.0; //Длительность разгона
new const Float:g_flFastRun				= 400.0; // Скорость разгона

new const Float:g_flCooldownFly			= 30.0; //Длительность кулдауна полета
new const Float:g_flDurationFly			= 10.0; //Длительность полета

new const Float:g_flDurationDownhill	= 1.0; //Длительность спуска
new const Float:g_flDownhillSpeedY		= -140.0; //Скорость полета вниз при спуске
new const g_iDownhillSpeed				= 500; //Скорость полета при спуске
new const g_iDownhillEndSpeed			= 300; //Скорость в конце спуска

new const g_iHudRed						= 255; //Цвета в худе
new const g_iHudBlue					= 0;
new const g_iHudGreen					= 0;

new const Float:g_flHudX				= 0.8; //Позиция худа
new const Float:g_flHudY				= 0.7;

new const g_iClassHealth 			= 7000;
new const g_iClassSpeed				= 260;
new const Float:g_flClassGravity 	= 0.85;
new const Float:g_flClassKnockback	= 0.3;

new const pain_sound1[] = "xman2030/fly/flyzombie_hurt1.wav";
new const pain_sound2[] = "xman2030/fly/flyzombie_hurt2.wav";

new const death_sound1[] = "xman2030/fly/flyzombie_death1.wav";
new const death_sound2[] = "xman2030/fly/flyzombie_death2.wav";

enum _:FlyingSounds {

	FlyStart = 0,
	FlyIdle,
	DownhillStart,
	Pressure

};

new const g_szFlyingSounds[FlyingSounds][] = {

	"xman2030/flying_zombie/flyzombie_fly_start.wav",
	"xman2030/flying_zombie/flyzombie_fly_idle.wav",
	"xman2030/flying_zombie/flyzombie_downhill_start.wav",
	"xman2030/flying_zombie/flyzombie_pressure.wav"

};

new const g_szClassInfo[][] = {

	"Flying Zombie",
	"Ability - G",
	"flyingzombie", // Модель
	"v_knife_flyingzombie1.mdl", // Лапы
	"models/xman2030/v_zombibomb_flyingzombi1.mdl" // Jump Bomb

};

new g_iClassFlying, g_msgScreenFade, g_msgScreenShake;
new bool:g_bInFly[33], bool:g_bInDownhill[33], bool:g_bInSpeed[33], Float:g_flUserTimeFly[33], Float:g_flUserTimeSpeed[33];

public plugin_init() {
	
	
	RegisterHam(Ham_TakeDamage, "player", "CPlayer__TakeDamage");

	register_forward(FM_EmitSound, "fw_EmitSound");


	register_plugin("[ZP Class] Flying Zombie", "0.1", "ONYX");
	
	register_clcmd("drop", "ClCmd_Ability");
	register_forward(FM_CmdStart , "FakeMeta_CmdStart");
	
	RegisterHam(Ham_Spawn, 				"player", 				"Ham_PlayerSpawn_Post", 		true);
	RegisterHam(Ham_Item_Deploy, 		"weapon_smokegrenade", 	"Ham_GrenadeDeploy_Post", 		true);
	RegisterHam(Ham_Killed, 			"player", 				"Ham_PlayerKilled_Post", 		true);
	RegisterHam(Ham_Item_PreFrame, 		"player", 				"Ham_PlayerResetMaxSpeed_Post", true);
	RegisterHam(Ham_Player_PreThink,	"player", 				"Ham_PlayerPreThink");
	
	g_msgScreenFade 	= get_user_msgid("ScreenFade");
	g_msgScreenShake 	= get_user_msgid("ScreenShake");

}

public plugin_precache() {
	
	
	precache_sound(pain_sound1[0]);
	precache_sound(pain_sound2[0]);

	precache_sound(death_sound1[0]);
	precache_sound(death_sound2[0]);
	//zp_register_class
	g_iClassFlying = zp_register_class(CLASS_ZOMBIE, g_szClassInfo[0], g_szClassInfo[1], g_szClassInfo[2], g_szClassInfo[3], 12, 5, ADMIN_ALL,
		g_iClassHealth, 0, g_iClassSpeed, g_flClassGravity, g_flClassKnockback);
	
	engfunc(EngFunc_PrecacheModel, g_szClassInfo[4]);
	for(new i = 0, j = sizeof g_szFlyingSounds; i < j; i++) engfunc(EngFunc_PrecacheSound, g_szFlyingSounds[i]);
	
}

///Регестрируем звуки (xman2030)
public CPlayer__TakeDamage(id, iVictim, iInflictor, iAttacker, Float:flDamage, bitsDamage) 
{ 
if (zp_get_user_zombie_class(id) == g_iClassFlying && zp_get_user_zombie(id) && !zp_get_user_nemesis(id) && !zp_get_user_survivor(id)) 
{ 
new rand = random_num(1,2) 
switch(rand) 
{ 
case 1: emit_sound(id, CHAN_WEAPON, pain_sound1[0], 1.0, ATTN_NORM, 0, PITCH_LOW);
case 2: emit_sound(id, CHAN_WEAPON, pain_sound2[0], 1.0, ATTN_NORM, 0, PITCH_LOW);
} 
} 
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch) 
{ 
if(!is_user_connected(id)) 
return FMRES_HANDLED; 

if(!zp_get_user_zombie(id)) 
return FMRES_HANDLED; 

if(zp_get_user_next_class(id) != g_iClassFlying) 
return FMRES_HANDLED; 

if (sample[0] == 'h' && sample[1] == 'o' && sample[2] == 's' && sample[3] == 't' && sample[4] == 'a' && sample[5] == 'g' && sample[6] == 'e') 
return FMRES_SUPERCEDE; 


if(zp_get_user_zombie(id) && zp_get_user_zombie_class(id) == g_iClassFlying && !zp_get_user_nemesis(id)) 
{ 
if (sample[7] == 'd' && ((sample[8] == 'i' && sample[9] == 'e') || (sample[8] == 'e' && sample[9] == 'a'))) 
{ 
new rand = random_num(1,2) 
switch(rand) 
{ 
case 1: emit_sound(id, CHAN_WEAPON, death_sound1[0], 1.0, ATTN_NORM, 0, PITCH_LOW); 
case 2: emit_sound(id, CHAN_WEAPON, death_sound2[0], 1.0, ATTN_NORM, 0, PITCH_LOW);
} 
}
return FMRES_IGNORED;
}
return FMRES_IGNORED
}


public ClCmd_Ability(iPlayer) {

	if((zp_get_user_zombie_class(iPlayer) == g_iClassFlying) && (zp_get_user_zombie(iPlayer)) && (!zp_get_user_nemesis(iPlayer)) && !g_bInSpeed[iPlayer] && is_user_alive(iPlayer)) {
	
		if(g_bInFly[iPlayer] && !g_bInDownhill[iPlayer]) abilityDownhill(iPlayer);
		else if((get_gametime() - g_flUserTimeFly[iPlayer] > g_flCooldownFly) && !g_bInDownhill[iPlayer] && !g_bInFly[iPlayer]) abilityFly(iPlayer);
		else return PLUGIN_CONTINUE;
		
		return PLUGIN_HANDLED;
	
	}
	return PLUGIN_CONTINUE;

}

public FakeMeta_CmdStart(iPlayer, UC_Handle, iSeed) {

	if((zp_get_user_zombie_class(iPlayer) == g_iClassFlying) && (zp_get_user_zombie(iPlayer)) && (!zp_get_user_nemesis(iPlayer)) && (get_gametime() - g_flUserTimeSpeed[iPlayer] > g_flCooldownSpeed) && is_user_alive(iPlayer)) {
		
		new iButtons = get_uc(UC_Handle, UC_Buttons);
		new iOldButtons = pev(iPlayer, pev_oldbuttons); 
		
		if(iButtons & IN_RELOAD && !(iOldButtons & IN_RELOAD) && !g_bInFly[iPlayer] && !g_bInDownhill[iPlayer] && !g_bInSpeed[iPlayer]) {
		
			g_bInSpeed[iPlayer] = true;
			
			new Float:flSpeed;
			pev(iPlayer, pev_maxspeed, flSpeed);
			
			new iParams[2];
			iParams[0] = iPlayer; iParams[1] = floatround(flSpeed);
			
			set_task(g_flDurationSpeed, "task_SpeedEnd", g_iTaskSpeedEnd + iPlayer, iParams, sizeof iParams);
			set_pev(iPlayer, pev_maxspeed, g_flFastRun);
			
			set_user_rendering(iPlayer, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 16);
			emit_sound(iPlayer, CHAN_STREAM, g_szFlyingSounds[Pressure], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
			UTIL_ScreenFade(iPlayer, 12, 12, 255, 0, 0, 100, 2);
		
		}
	
	}

}

public task_SpeedEnd(iParams[]) {

	new iPlayer = iParams[0];
	new Float:flSpeed = float(iParams[1]);
	
	g_bInSpeed[iPlayer] = false;
	set_pev(iPlayer, pev_maxspeed, flSpeed);
	
	if(is_user_alive(iPlayer)) {
	
		UTIL_ScreenFade(iPlayer, 12, 8, 255, 255, 255, 0, 1);
		set_user_rendering(iPlayer);
		
	}
	
	g_flUserTimeSpeed[iPlayer] = get_gametime();
	if(!task_exists(g_iTaskCooldown + iPlayer)) set_task(1.0, "taskShowCooldown", g_iTaskCooldown + iPlayer, _, _, "b");

}

abilityDownhill(iPlayer) {
	
	emit_sound(iPlayer, CHAN_STREAM, g_szFlyingSounds[DownhillStart], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	
	g_bInFly[iPlayer] = false;
	g_bInDownhill[iPlayer] = true;
	
	UTIL_ScreenFade(iPlayer, 12, 12, 0, 0, 0, 100, 1);
	UTIL_PlayAnimation(iPlayer, 0.3, 1.0, 147);
	
	set_task(0.3, "task_DownhillStart", g_iTaskDownhillStart + iPlayer);
	if(task_exists(g_iTaskFlyStart + iPlayer)) remove_task(g_iTaskFlyStart + iPlayer);
	if(task_exists(g_iTaskFlyIdle + iPlayer)) remove_task(g_iTaskFlyIdle + iPlayer);
	if(task_exists(g_iTaskFlyEnd + iPlayer)) remove_task(g_iTaskFlyEnd + iPlayer);
	if(task_exists(g_iTaskFlySound + iPlayer)) remove_task(g_iTaskFlySound + iPlayer);

}

public task_DownhillStart(iPlayer) {

	iPlayer -= g_iTaskDownhillStart;
	if(is_user_alive(iPlayer)) {
	
		UTIL_PlayAnimation(iPlayer, g_flDurationDownhill, 0.2, 148);
		set_task(g_flDurationDownhill, "task_DownhillEnd", g_iTaskDownhillEnd + iPlayer);
	}
	
}

public task_DownhillEnd(iPlayer) {

	iPlayer -= g_iTaskDownhillEnd;
	g_bInDownhill[iPlayer] = false;
	
	if(is_user_alive(iPlayer)) {
	
		UTIL_PlayAnimation(iPlayer, 0.2, 1.0, 148);
	
		new Float:vecVelocity[3]; velocity_by_aim(iPlayer, g_iDownhillEndSpeed, vecVelocity);
		vecVelocity[2] = -30.0; set_pev(iPlayer, pev_velocity, vecVelocity);
	}
	
	g_flUserTimeFly[iPlayer] = get_gametime();
	if(!task_exists(g_iTaskCooldown + iPlayer)) set_task(1.0, "taskShowCooldown", g_iTaskCooldown + iPlayer, _, _, "b");

}

abilityFly(iPlayer) {

	UTIL_PlayAnimation(iPlayer, 0.3, 1.0, 143);
	set_task(0.3, "task_FlyStart", g_iTaskFlyStart + iPlayer);

}

public task_FlyStart(iPlayer) {

	iPlayer -= g_iTaskFlyStart;
	if(is_user_alive(iPlayer)) {
	
		new Float:vecVelocity[3]; pev(iPlayer, pev_velocity, vecVelocity);
		vecVelocity[2] = 500.0; set_pev(iPlayer, pev_velocity, vecVelocity);
		
		UTIL_PlayAnimation(iPlayer, 0.6, 1.0, 144);
		CreateEffects(iPlayer);
		
		set_task(0.7, "task_FlyIdle", g_iTaskFlyIdle + iPlayer);
		emit_sound(iPlayer, CHAN_STREAM, g_szFlyingSounds[FlyStart], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
		
	
	}

}

public task_FlyIdle(iPlayer) {

	iPlayer -= g_iTaskFlyIdle;
	g_bInFly[iPlayer] = true;
	
	if(is_user_alive(iPlayer)) {
	
		UTIL_PlayAnimation(iPlayer, 10.0, 1.5, 146);
		set_task(g_flDurationFly, "task_FlyEnd", g_iTaskFlyEnd + iPlayer);
		set_task(0.7, "task_FlySound", g_iTaskFlySound + iPlayer, _, _, "a", floatround(g_flDurationFly / 0.7));
	
	}

}

public task_FlySound(iPlayer) {

	iPlayer -= g_iTaskFlySound;
	emit_sound(iPlayer, CHAN_STREAM, g_szFlyingSounds[FlyIdle], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

}

public task_FlyEnd(iPlayer) {

	iPlayer -= g_iTaskFlyEnd;
	g_bInFly[iPlayer] = false;
	if(is_user_alive(iPlayer)) UTIL_PlayAnimation(iPlayer, 0.3, 1.0, 145);
	
	g_flUserTimeFly[iPlayer] = get_gametime();
	if(!task_exists(g_iTaskCooldown + iPlayer)) set_task(1.0, "taskShowCooldown", g_iTaskCooldown + iPlayer, _, _, "b");

}

public taskShowCooldown(iPlayer) {

	iPlayer -= g_iTaskCooldown;
	new bool:bFly = (get_gametime() - g_flUserTimeFly[iPlayer] > g_flCooldownFly);
	new bool:bSpeed = (get_gametime() - g_flUserTimeSpeed[iPlayer] > g_flCooldownSpeed);
	if(bFly && bSpeed) {
	
		if(task_exists(g_iTaskCooldown + iPlayer)) remove_task(g_iTaskCooldown + iPlayer);
		return PLUGIN_HANDLED;
		
	}
	
	new szMessage[192];
	if(!bFly) format(szMessage, charsmax(szMessage), "%s^nVuelo: %d", szMessage, floatround(g_flCooldownFly - (get_gametime() - g_flUserTimeFly[iPlayer])));
	if(!bSpeed) format(szMessage, charsmax(szMessage), "%s^nOverclocking: %d", szMessage, floatround(g_flCooldownSpeed - (get_gametime() - g_flUserTimeSpeed[iPlayer])));
	
	set_hudmessage(g_iHudRed, g_iHudGreen, g_iHudBlue, g_flHudX, g_flHudY, 0, _, 1.0, 0.2, 0.5, -1);
	show_hudmessage(iPlayer, szMessage);
	
	return PLUGIN_HANDLED;

}

public Ham_GrenadeDeploy_Post(iEnt) {

	new iPlayer = get_pdata_cbase(iEnt, 41, 4);
	if(!zp_get_user_zombie(iPlayer) || zp_get_user_zombie_class(iPlayer) != g_iClassFlying) return HAM_IGNORED;

	set_pev(iPlayer, pev_viewmodel2, g_szClassInfo[4]);
	return HAM_HANDLED;
	
}

public Ham_PlayerSpawn_Post(iPlayer) ResetVariables(iPlayer);
public Ham_PlayerKilled_Post(iVictim, iAttaker, iShouldgib) ResetVariables(iVictim);

public Ham_PlayerResetMaxSpeed_Post(iPlayer) {

	if(!is_user_alive(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_nemesis(iPlayer)) return HAM_IGNORED;
	if(zp_get_user_zombie_class(iPlayer) != g_iClassFlying) return HAM_IGNORED;
	
	if(g_bInSpeed[iPlayer]) set_pev(iPlayer, pev_maxspeed, g_flFastRun);
	return HAM_IGNORED;
	
}

public Ham_PlayerPreThink(iPlayer) {

	if(g_bInFly[iPlayer]) {
	
		new Float:vecVelocity[3];
		velocity_by_aim(iPlayer, 200, vecVelocity);
		vecVelocity[2] = 0.0;
		set_pev(iPlayer, pev_velocity, vecVelocity);
	
	} else if(g_bInDownhill[iPlayer]) {
	
		new Float:vecVelocity[3];
		velocity_by_aim(iPlayer, g_iDownhillSpeed, vecVelocity);
		vecVelocity[2] = g_flDownhillSpeedY;
		set_pev(iPlayer, pev_velocity, vecVelocity);
	
	}

}

public zp_user_infected_post(iPlayer, iInfector) {

	if(zp_get_user_zombie_class(iPlayer) == g_iClassFlying && !zp_get_user_nemesis(iPlayer)) {
		
		ResetVariables(iPlayer);
		UTIL_SayText(iPlayer, "!g[SVL] !yTus habilidades: !gVuelo y aceleración!y. Activación !g[G] y [R]!y. Enfriarse !g[%d] и [%d]", floatround(g_flCooldownFly), floatround(g_flCooldownSpeed));
	
	}
	
}

public zp_user_infected_pre(id) { 
    if(!(get_user_flags(id) & ADMIN_LEVEL_G)) { 
        if (zp_get_user_next_class(id) == g_iClassFlying) { 
    zp_set_user_zombie_class(id, 0) 
    client_print(id, print_center, "No eres un átomo!" ) 
    client_print(id, print_chat, "Se selecciona otra clase, puede comprar en SVL!" ) 
   }
  }  
 }

CreateEffects(iPlayer) {

	new Float:vecOrigin[3]; pev(iPlayer, pev_origin, vecOrigin);
	new iOrigin[3]; FVecIVec(vecOrigin, iOrigin);
	
	UTIL_CreateLavaSplash(iPlayer, iOrigin);
	UTIL_CreateTeleport(iPlayer, iOrigin);
	
	UTIL_ScreenShake(iPlayer, (1<<12), (1<<24), (1<<12));
	UTIL_ScreenFade(iPlayer, 12, 8, 0, 0, 0, 120, 4);

}

ResetVariables(iPlayer) {

	g_bInFly[iPlayer] = false;
	g_bInDownhill[iPlayer] = false;
	g_bInSpeed[iPlayer] = false;
	g_flUserTimeFly[iPlayer] = 0.0;
	g_flUserTimeSpeed[iPlayer] = 0.0;
	
	if(is_user_alive(iPlayer)) set_user_rendering(iPlayer);
	if(task_exists(g_iTaskCooldown + iPlayer)) remove_task(g_iTaskCooldown + iPlayer);
	if(task_exists(g_iTaskCooldown + iPlayer)) remove_task(g_iTaskCooldown + iPlayer);

}

stock UTIL_CreateLavaSplash(iPlayer, iOrigin[3]) {

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY, _, iPlayer);
	write_byte(TE_LAVASPLASH);
	write_coord(iOrigin[0]);
	write_coord(iOrigin[1]);
	write_coord(iOrigin[2]);
	message_end();

}

stock UTIL_CreateTeleport(iPlayer, iOrigin[3]) {

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY, _, iPlayer);
	write_byte(TE_TELEPORT);
	write_coord(iOrigin[0]);
	write_coord(iOrigin[1]);
	write_coord(iOrigin[2]);
	message_end();

}

stock UTIL_ScreenShake(iPlayer, iDuration, iAmplitude, iFrequency) {
	
	message_begin(MSG_ONE, g_msgScreenShake, _, iPlayer);
	write_short(iAmplitude);
	write_short(iDuration);
	write_short(iFrequency);
	message_end();

}

stock UTIL_ScreenFade(iPlayer, iDuration, iHold, iRed, iGreen, iBlue, iAlpha, iFlag) {

	if(!is_user_connected(iPlayer)) return PLUGIN_HANDLED;
	
	message_begin(MSG_ONE, g_msgScreenFade, _, iPlayer);
	write_short(1<<iDuration);
	write_short(1<<iHold);
	write_short(1<<iFlag);
	write_byte(iRed);
	write_byte(iGreen);
	write_byte(iBlue);
	write_byte(iAlpha);
	message_end();
	
	return PLUGIN_HANDLED;

}

stock UTIL_PlayAnimation(iPlayer, Float:flTime, Float:flFramerate, iSequence) {

	set_pev(iPlayer, pev_animtime, flTime);
	set_pev(iPlayer, pev_framerate, flFramerate);
	set_pev(iPlayer, pev_sequence, iSequence);
	set_pev(iPlayer, pev_gaitsequence, iSequence);

}

stock UTIL_SayText(pPlayer, const szMessage[], any:...) {

	new szBuffer[190];
	
	if(numargs() > 2) vformat(szBuffer, charsmax(szBuffer), szMessage, 3);
	else copy(szBuffer, charsmax(szBuffer), szMessage);
	
	while(replace(szBuffer, charsmax(szBuffer), "!y", "^1")) {}
	while(replace(szBuffer, charsmax(szBuffer), "!t", "^3")) {}
	while(replace(szBuffer, charsmax(szBuffer), "!g", "^4")) {}
	
	switch(pPlayer) {
	
		case 0: {
		
			for(new iPlayer = 1; iPlayer <= get_maxplayers(); iPlayer++) {
			
				if(!is_user_connected(iPlayer)) continue;
				engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, 76, {0.0, 0.0, 0.0}, iPlayer);
				write_byte(iPlayer);
				write_string(szBuffer);
				message_end();
				
			}
			
		}
		default: {
		
			engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, 76, {0.0, 0.0, 0.0}, pPlayer);
			write_byte(pPlayer);
			write_string(szBuffer);
			message_end();
			
		}
		
	}
	
}