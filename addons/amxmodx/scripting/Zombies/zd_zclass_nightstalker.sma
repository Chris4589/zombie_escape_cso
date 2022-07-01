#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <zombie_escape_v1>

#define PLUGIN "[ZD] Zombie Class: Night Stalker"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

new const zclass_name[] = { "NightStakler" }
new const zclass_info[] = { "Salto elevado + invi" }
new const zclass4_model[] = { "z4_hide" }
const zclass_health = 10000
const zclass_speed = 250
const Float:zclass_gravity = 0.9
const Float:zclass_knockback = 0.0

new Float:g_ftimeHab[33];

#define HUD_ADRENALINE_X -1.0
#define HUD_ADRENALINE_Y 0.83

#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

#define TIME_INTERVAL 0.25
#define TASK_CHECKTIME 3125365

#define is_user_valid_connected(%1) (1 <= %1 <= g_MaxPlayers && is_user_connected(%1))

// Loaded Vars
new g_zombieclass

new g_InvisibleTime
new g_BerserkDefense
new g_DashJump, g_DashDashing, Float:g_CouldDown = 20.0

new Float:CheckTime[33], Float:CheckTime2[33], Float:CheckTime3[33], g_SkillHud

new g_Sprinting, g_PlayerKey[33][2], g_InvisiblePercent[33]
new g_Dashing, g_MaxPlayers;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_forward(FM_CmdStart, "fw_CmdStart")
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")	

	g_InvisibleTime = register_cvar("nightstalker_invisible", "3");
	g_BerserkDefense = register_cvar("nightstalker_defense", "1.5");
	g_DashJump = register_cvar("nightstalker_jump", "1400");
	g_DashDashing = register_cvar("nightstaker_dash", "900");

	g_MaxPlayers = get_maxplayers();

	g_SkillHud = CreateHudSyncObj(3)
}

public plugin_precache()
{
	g_zombieclass = zp_register_class(CLASS_ZOMBIE, zclass_name, zclass_info, zclass4_model, "v_knife_z4hide.mdl", 5, 1, ADMIN_LEVEL_A, 
		zclass_health, 0, zclass_speed, zclass_gravity, zclass_knockback)
}



public zp_user_humanized_post(id, survivor) Reset_Skill(id)
public zp_user_infected_post(id, infector, nemesis)
	g_ftimeHab[id] = 0.0;

public fw_TakeDamage(Victim, Inflictor, Attacker, Float:Damage, DamageBits)
{
	if (Victim == Attacker || !is_user_valid_connected(Attacker))
		return HAM_IGNORED;

	if(zp_get_user_zombie_class(Victim) != g_zombieclass)
		return HAM_IGNORED
	if(!Get_BitVar(g_Sprinting, Victim))
		return HAM_IGNORED
		
	Damage /= get_pcvar_float(g_BerserkDefense)
	SetHamParamFloat(4, Damage)
		
	return HAM_HANDLED
}

public Reset_Skill(id)
{
	UnSet_BitVar(g_Sprinting, id)
	UnSet_BitVar(g_Dashing, id)
	g_InvisiblePercent[id] = 0
	
	Reset_Key(id)
}

public client_PreThink(id)
{
	if(!is_user_alive(id))
		return
		
	static CurButton; CurButton = pev(id, pev_button)
	static OldButton; OldButton = pev(id, pev_oldbuttons)
	
	if((CurButton & IN_FORWARD)) 
	{
		if(!zp_get_user_zombie(id))
			return
		if(zp_get_user_zombie_class(id) != g_zombieclass)
			return
		if(zp_get_class(id) >= NEMESIS)
			return
		
		if(Get_BitVar(g_Sprinting, id) && (get_gametime() - 0.15 > CheckTime[id]))
		{
			if(g_ftimeHab[id] > get_gametime())
			{
				Deactive_SprintSkill(id)
				return
			}
			if((pev(id, pev_flags) & FL_DUCKING) || pev(id, pev_bInDuck) || !(pev(id, pev_flags) & FL_ONGROUND))
			{
				Deactive_SprintSkill(id)
				return
			}
			
			static Float:RenderAmt; pev(id, pev_renderamt, RenderAmt)
			if(RenderAmt > 0) 
			{
				RenderAmt -= ((255.0 / get_pcvar_float(g_InvisibleTime)) * 0.15)
				if(RenderAmt < 0.0) 
				{
					RenderAmt = 0.0
					//set_pev(id, pev_viewmodel2, g_InvisibleClawModel)
				}
				
				g_InvisiblePercent[id] = floatround(((255.0 - RenderAmt) / 255.0) * 100.0)
				set_pev(id, pev_renderamt, RenderAmt)
			}
			
			// Handle Other
			CheckTime[id] = get_gametime()
		}	
			
		if(Get_BitVar(g_Sprinting, id) && (get_gametime() - 0.5 > CheckTime2[id]))
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
			Deactive_SprintSkill(id)
		}
		
		return
	}
	
	if(equali(g_PlayerKey[id], "ww"))
	{
		Reset_Key(id)
		Active_SprintSkill(id)
	}

	return
}

public fw_CmdStart(id, UCHandle, Seed)
{
	if(!is_user_alive(id))
		return
	if(!zp_get_user_zombie(id))
		return
	if(zp_get_user_zombie_class(id) != g_zombieclass)
		return

	if(zp_get_class(id) >= NEMESIS)
		return

	static CurButton; CurButton = get_uc(UCHandle, UC_Buttons)
	
	if(get_gametime() - 1.0 > CheckTime3[id])
	{
		static Float:Time; Time = g_ftimeHab[id] > get_gametime() ? g_ftimeHab[id] - get_gametime() : 0.0;
		static Hud[512], SkillName[512]; 
		
		formatex(SkillName, sizeof(SkillName), "[Clic Derecho] Activo en: %.2f", Time)
		formatex(Hud, sizeof(Hud), "Porcentaje de Invisibilidad: %d", g_InvisiblePercent[id])
		
		formatex(Hud, sizeof(Hud), "%s^n%s", Hud, SkillName)

		set_hudmessage(200, 200, 200, HUD_ADRENALINE_X, HUD_ADRENALINE_Y - 0.04, 0, 1.0, 1.0, 0.0, 0.0)
		ShowSyncHudMsg(id, g_SkillHud, Hud)
		
		CheckTime3[id] = get_gametime()
	}	
	
	if((CurButton & IN_ATTACK2))
	{
		CurButton &= ~IN_ATTACK2
		set_uc(UCHandle, UC_Buttons, CurButton)

		if(Get_BitVar(g_Sprinting, id))
		{
			set_pdata_float(id, 83, 0.5, 5)
			return
		}
		if(g_ftimeHab[id] > get_gametime())
		{
			set_pdata_float(id, 83, 0.5, 5)
			return
		}
		if((pev(id, pev_flags) & FL_DUCKING) || pev(id, pev_bInDuck))
		{
			set_pdata_float(id, 83, 0.5, 5)
			return
		}
		if(get_pdata_float(id, 83, 5) > 0.0)
			return
			
		set_pdata_float(id, 83, 0.5, 5)
		Handle_Dashing(id)
	}
}

public Handle_Dashing(id)
{
	if((pev(id, pev_flags) & FL_ONGROUND)) // On Ground
	{
		static Float:Origin1[3], Float:Origin2[3]
		pev(id, pev_origin, Origin1)
	
		Set_BitVar(g_Dashing, id)
		
		// Climb Action
		Set_WeaponAnim(id, 6)
		set_pev(id, pev_framerate, 0.5)
		set_pev(id, pev_sequence, 112)
		
		set_pdata_float(id, 83, 0.5, 5)
		
		get_position(id, 0.0, 0.0, 200.0, Origin2)
		static Float:Velocity[3]; Get_SpeedVector(Origin1, Origin2, float(get_pcvar_num(g_DashJump)), Velocity)
		
		set_pev(id, pev_velocity, Velocity)
	} else { // In Air
		static Float:Origin1[3], Float:Origin2[3]
		pev(id, pev_origin, Origin1)
	
		Set_BitVar(g_Dashing, id)
		
		// Climb Action
		Set_WeaponAnim(id, 6)
		set_pev(id, pev_framerate, 0.5)
		set_pev(id, pev_sequence, 112)
		
		set_pdata_float(id, 83, 0.5, 5)
		
		get_position(id, 250.0, 0.0, 60.0, Origin2)
		static Float:Velocity[3]; Get_SpeedVector(Origin1, Origin2, float(get_pcvar_num(g_DashDashing)), Velocity)
		
		set_pev(id, pev_velocity, Velocity)
		g_ftimeHab[id] = get_gametime() + g_CouldDown;
	}
}

public client_PostThink(id)
{
	if(!is_user_alive(id))
		return
	if(!Get_BitVar(g_Dashing, id))
		return
	if(!zp_get_user_zombie(id))
		return
	if(zp_get_user_zombie_class(id) != g_zombieclass)
		return
			
	static Float:flFallVelocity; flFallVelocity = get_pdata_float(id, 251, 5)
        
	if(flFallVelocity && pev(id, pev_flags) & FL_ONGROUND)
	{
		set_pev(id, pev_framerate, 2.0)
		set_pev(id, pev_sequence, 113)
		Set_WeaponAnim(id, 7)

		UnSet_BitVar(g_Dashing, id)
	}
}

public Active_SprintSkill(id)
{
	Set_BitVar(g_Sprinting, id)
	CheckTime2[id] = get_gametime()
	
	set_pev(id, pev_framerate, 2.0)
	set_pev(id, pev_sequence, 110)
	
	Set_WeaponAnim(id, 9)
	
	set_pev(id, pev_rendermode, kRenderTransAlpha)
	set_pev(id, pev_renderfx, kRenderFxNone)
	set_pev(id, pev_renderamt, 255.0)	
}

public Deactive_SprintSkill(id)
{
	if(!Get_BitVar(g_Sprinting, id))
		return
	
	UnSet_BitVar(g_Sprinting, id)

	if(g_InvisiblePercent[id] > 0) g_ftimeHab[id] = get_gametime() + g_CouldDown;

	g_InvisiblePercent[id] = 0
	
	// Reset Claw
	set_pev(id, pev_rendermode, kRenderNormal)
	Set_WeaponAnim(id, 11)
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
