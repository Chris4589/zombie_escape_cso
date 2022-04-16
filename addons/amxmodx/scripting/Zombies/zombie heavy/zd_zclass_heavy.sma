#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <zombieplague>

#define PLUGIN "[ZD] Zombie Class: Heavy"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

#define HUD_ADRENALINE_X -1.0
#define HUD_ADRENALINE_Y 0.83

#define TIME_INTERVAL 0.25
#define TASK_CHECKTIME 3125365

#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_zombieclass;
new g_HardeningSkill, g_StompSkill
new g_PlayerKey[33][2],  Float:CheckTime[33], Float:CheckTime2[33], Float:CheckTime3[33]
new g_MsgScreenShake, g_SkillHud, g_MaxPlayers

new HardeningDefense
new StompDestruction, StompRange
new g_ShockWave_SprID

// Auto Skill
#define AUTO_TIME random_float(15.0, 30.0)
#define TASK_AUTO 4965

#define is_user_valid_connected(%1) (1 <= %1 <= g_MaxPlayers && is_user_connected(%1))

new const zclass_name[] = { "Heavy" }
new const zclass_info[] = { "Clic derecho salto" }
new const zclass4_model[] = { "ze_heavy" }
new const zclass4_clawmodel[] = { "v_knife_z4heavy.mdl" }
const zclass_health = 8000
const zclass_speed = 250
const Float:zclass_gravity = 0.7
const Float:zclass_knockback = 0.0
const Float:g_CouldDown = 20.0;
new Float:g_ftimeHab[33];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_forward(FM_CmdStart, "fw_CmdStart")
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")

	HardeningDefense = register_cvar("zm_heavy_defense", "2.0")
	
	StompDestruction = register_cvar("zm_heavy_destruction", "750")
	StompRange = register_cvar("zm_heavy_range", "300")

	
	g_SkillHud = CreateHudSyncObj(3)
	g_MsgScreenShake = get_user_msgid("ScreenShake")
	g_MaxPlayers = get_maxplayers()

}

public plugin_precache()
{
	g_ShockWave_SprID = precache_model("sprites/shockwave.spr");
	g_zombieclass = zp_register_class(CLASS_ZOMBIE, zclass_name, zclass_info, zclass4_model, zclass4_clawmodel, 10, 1, ADMIN_ALL, 
		zclass_health, 0, zclass_speed, zclass_gravity, zclass_knockback)
}

public fw_PlayerSpawn_Post(id)
{
	if(!is_user_alive(id))
		return
		
	remove_task(id+TASK_AUTO)
}
public zp_user_humanized_post(id, survivor) Reset_Skill(id)
public zp_user_infected_post(id, infector, nemesis)
	g_ftimeHab[id] = 0.0;

public Reset_Skill(id)
{
	UnSet_BitVar(g_HardeningSkill, id)
	UnSet_BitVar(g_StompSkill, id)
	
	Reset_Key(id)
}

public AutoTime(id)
{
	id -= TASK_AUTO
	if(!is_user_alive(id))
		return
	if(!zp_get_user_zombie(id) || zp_get_class(id) >= NEMESIS)
		return
	if(zp_get_user_zombie_class(id) != g_zombieclass)
		return
	if(Get_BitVar(g_StompSkill, id))
		return

	if(g_ftimeHab[id] > get_gametime())
		return
	
	//tiempo

	Active_Stomp(id)
}

public fw_TakeDamage(Victim, Inflictor, Attacker, Float:Damage, DamageBits)
{
	if (Victim == Attacker || !is_user_valid_connected(Attacker))
		return HAM_IGNORED;

	if(!zp_get_user_zombie(Victim) || zp_get_user_zombie(Attacker))
		return HAM_IGNORED;

	if(zp_get_user_zombie_class(Victim) != g_zombieclass)
		return HAM_IGNORED;

	if(!Get_BitVar(g_HardeningSkill, Victim))
		return HAM_IGNORED
		
	Damage /= get_pcvar_float(HardeningDefense)
	
	SetHamParamFloat(4, Damage)
		
	return HAM_HANDLED
}

public client_PreThink(id)
{
	if(!is_user_alive(id))
		return
		
	static CurButton; CurButton = pev(id, pev_button)
	static OldButton; OldButton = pev(id, pev_oldbuttons)
	
	if((CurButton & IN_FORWARD)) 
	{
		if(!zp_get_user_zombie(id) || zp_get_class(id) >= NEMESIS)
			return
			
		if(zp_get_user_zombie_class(id) != g_zombieclass)
			return
		
		if(Get_BitVar(g_HardeningSkill, id) && (get_gametime() - 0.15 > CheckTime[id]))
		{
			//tiempo
			if(g_ftimeHab[id] > get_gametime())
			{
				Deactive_HardeningSkill(id)
				return
			}
			if((pev(id, pev_flags) & FL_DUCKING) || pev(id, pev_bInDuck) || !(pev(id, pev_flags) & FL_ONGROUND))
			{
				Deactive_HardeningSkill(id)
				return
			}

			// Handle Other
			g_ftimeHab[id] = get_gametime() + g_CouldDown;
			//tiempo resta
			CheckTime[id] = get_gametime()
		}	
			
		if(Get_BitVar(g_HardeningSkill, id) && (get_gametime() - 0.5 > CheckTime2[id]))
		{
			Set_WeaponAnim(id, 10)
			
			set_pev(id, pev_framerate, 2.0)
			set_pev(id, pev_sequence, 110)
			
			CheckTime2[id] = get_gametime()
		}
		
		if(OldButton & IN_FORWARD)
			return
		
		if(!task_exists(id+TASK_CHECKTIME))
		{
			g_PlayerKey[id][0] = 'w'
			
			remove_task(id+TASK_CHECKTIME)
			set_task(TIME_INTERVAL, "Recheck_Key", id+TASK_CHECKTIME)
		} else {
			g_PlayerKey[id][1] = 'w'
		}
	} else {
		if(OldButton & IN_FORWARD)
		{
			Deactive_HardeningSkill(id)
		}
		
		return
	}
	
	if(equali(g_PlayerKey[id], "ww"))
	{
		Reset_Key(id)
		Active_HardeningSkill(id)
	}

	return
}

public client_PostThink(id)
{
	if(!is_user_alive(id))
		return
	if(!Get_BitVar(g_StompSkill, id))
		return
	if(!zp_get_user_zombie(id))
		return

	if(zp_get_class(id) >= NEMESIS)
		return
		
	static Float:flFallVelocity; flFallVelocity = get_pdata_float(id, 251, 5)
        
	if(flFallVelocity && pev(id, pev_flags) & FL_ONGROUND)
	{
		set_pev(id, pev_framerate, 2.0)
		set_pev(id, pev_sequence, 113)
		Set_WeaponAnim(id, 7)
	
		UnSet_BitVar(g_StompSkill, id)
		
		Check_Destruction(id)
	}
}

public Check_Destruction(id)
{
	static Float:Origin[3]; pev(id, pev_origin, Origin)
	static Float:Punch[3], Float:Origin2[3], Float:Velocity[3]
	
	engfunc(EngFunc_MessageBegin, MSG_BROADCAST, SVC_TEMPENTITY, Origin)
	write_byte(TE_BEAMCYLINDER)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + get_pcvar_num(StompRange))
	write_short(g_ShockWave_SprID)
	write_byte(0) // Start Frame
	write_byte(20) // Framerate
	write_byte(4) // Live Time
	write_byte(25) // Width
	write_byte(10) // Noise
	write_byte(255) // R
	write_byte(85) // G
	write_byte(85) // B
	write_byte(255) // Bright
	write_byte(9) // Speed
	message_end()	
	
	new players[32], num
	get_players(players, num)

	for (new i=0;i<num;i++)
	{
		if(!is_user_alive(id) || !is_user_connected(id))
			continue
		if(entity_range(id, players[i]) > float(get_pcvar_num(StompRange)))
			continue
			
		// Shake Screen
		message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenShake, _, players[i])
		write_short(FixedUnsigned16(5.0, 1<<12)) //ammount
		write_short(FixedUnsigned16(5.0, 1<<12)) //lasts this long
		write_short(FixedUnsigned16(5.0, 1<<12)) //frequency
		message_end()
		
		if(zp_get_user_zombie(players[i]))
			continue
		
		// Punch Angles
		Punch[0] = random_float(-35.0, 35.0)
		Punch[1] = random_float(-35.0, 35.0)
		Punch[2] = random_float(-35.0, 35.0)
		
		set_pev(players[i], pev_punchangle, Punch)
		
		// Knockback
		get_position(players[i], -30.0, 0.0, 300.0, Origin2)
		Get_SpeedVector(Origin, Origin2, float(get_pcvar_num(StompDestruction)), Velocity)
		
		set_pev(players[i], pev_velocity, Velocity)
	}
}

public fw_CmdStart(id, UCHandle, Seed)
{
	if(!is_user_alive(id))
		return
	if(!zp_get_user_zombie(id))
		return
	if(zp_get_user_zombie_class(id) != g_zombieclass)
		return	
	
	static CurButton; CurButton = get_uc(UCHandle, UC_Buttons)
	
	if(get_gametime() - 1.0 > CheckTime3[id])
	{
		static Float:Time; Time = g_ftimeHab[id] > get_gametime() ? g_ftimeHab[id] - get_gametime() : 0.0;
			
		set_hudmessage(200, 200, 200, HUD_ADRENALINE_X, HUD_ADRENALINE_Y - 0.02, 0, 1.0, 1.0, 0.0, 0.0)
		ShowSyncHudMsg(id, g_SkillHud, "[Right Mouse] Quake in (%.1f)", Time)
	
		
		CheckTime3[id] = get_gametime()
	}
	
	if((CurButton & IN_ATTACK2))
	{
		CurButton &= ~IN_ATTACK2
		set_uc(UCHandle, UC_Buttons, CurButton)

		if(Get_BitVar(g_StompSkill, id))
		{
			set_pdata_float(id, 83, 0.5, 5)
			return
		}
		if(g_ftimeHab[id] > get_gametime())
		{
			set_pdata_float(id, 83, 0.5, 5)
			return
		}
		//tiempo
		
		if((pev(id, pev_flags) & FL_DUCKING) || pev(id, pev_bInDuck) || !(pev(id, pev_flags) & FL_ONGROUND))
		{
			set_pdata_float(id, 83, 0.5, 5)
			return
		}
		if(get_pdata_float(id, 83, 5) > 0.0)
			return
			
		Active_Stomp(id)
	}
}

public Reset_Key(id)
{
	g_PlayerKey[id][0] = 0
	g_PlayerKey[id][1] = 0
}

public Recheck_Key(id)
{
	id -= TASK_CHECKTIME
	
	if(!is_user_connected(id))
		return
		
	Reset_Key(id)
}

public Active_HardeningSkill(id)
{
	Set_BitVar(g_HardeningSkill, id)
	CheckTime2[id] = get_gametime()
	
	set_pev(id, pev_framerate, 2.0)
	set_pev(id, pev_sequence, 110)
	
	Set_WeaponAnim(id, 9)
}

public Deactive_HardeningSkill(id)
{
	if(!Get_BitVar(g_HardeningSkill, id))
		return
	
	UnSet_BitVar(g_HardeningSkill, id)

	// Reset Claw
	Set_WeaponAnim(id, 11)
}

public Active_Stomp(id)
{
	static Float:Origin1[3], Float:Origin2[3]
	pev(id, pev_origin, Origin1)

	Set_BitVar(g_StompSkill, id)
	//tiempo resta
	g_ftimeHab[id] = get_gametime() + g_CouldDown;

	// Climb Action
	Set_WeaponAnim(id, 4)
	set_pev(id, pev_sequence, 112)
	
	set_pdata_float(id, 83, 3.0, 5)
	
	get_position(id, 30.0, 0.0, 200.0, Origin2)
	static Float:Velocity[3]; Get_SpeedVector(Origin1, Origin2, 700.0, Velocity)
	
	set_pev(id, pev_velocity, Velocity)
}

stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id)
	write_byte(anim)
	write_byte(0)
	message_end()	
}

stock Get_SpeedVector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= (num * 2.0)
	new_velocity[1] *= (num * 2.0)
	new_velocity[2] *= (num / 2.0)
}  

stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(id, pev_origin, vOrigin)
	pev(id, pev_view_ofs, vUp) //for player
	xs_vec_add(vOrigin, vUp, vOrigin)
	pev(id, pev_v_angle, vAngle) // if normal entity ,use pev_angles
	
	vAngle[0] = 0.0
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD, vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT, vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP, vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}


stock FixedUnsigned16(Float:flValue, iScale)
{
	new iOutput;

	iOutput = floatround(flValue * iScale);

	if ( iOutput < 0 )
		iOutput = 0;

	if ( iOutput > 0xFFFF )
		iOutput = 0xFFFF;

	return iOutput;
}
