#include <amxmodx>
#include <fakemeta_util>
#include <hamsandwich>
#include <zombie_escape_v1>

#define PDATA_SAFE 2
#define MAX_CLIENTS 32
#define TASKID_WAIT_HUD 3600
#define TASKID_REMOVE_GRAVITY 3700

#define linux_diff_weapon 4
#define m_pPlayer 41

#define get_bit(%1,%2) ((%1 & (1 << (%2 & 31))) ? 1 : 0)
#define set_bit(%1,%2) %1 |= (1 << (%2 & 31))
#define reset_bit(%1,%2) %1 &= ~(1 << (%2 & 31))

/* ~ [ Zombie Class Setting's ] ~ */
new const ZM_CLASS_NAME[] = "Voodoo"
new const ZM_CLASS_INFO[] = "Heal Totem > G"
new const ZM_CLASS_MODEL[] = "x_shaman"
new const ZM_CLASS_CLAW[] = "v_knife_shaman.mdl"
new const ZM_CLASS_BOMB[] = "models/x/v_zbomb_shaman.mdl"
const ZM_CLASS_HEALTH = 2300;
const ZM_CLASS_SPEED = 237;
const Float: ZM_CLASS_GRAVITY = 0.88;
const Float: ZM_CLASS_KNOCKBACK = 1.0;
const Float: ZM_CLASS_WAIT_TOTEM = 30.0;

/* ~ [ Entity ] ~ */
new const ENTITY_TOTEM_CLASSNAME[] = "ent_totem";
new const ENTITY_TOTEM_MODEL[] = "models/x/Totem.mdl";
const Float: ENTITY_TOTEM_ALIVE = 10.0;
const Float: ENTITY_TOTEM_NEXTTHINK = 1.0; // Во сколько раз будет хилить
const Float: ENTITY_TOTEM_HEAL_AMOUNT = 300.0; // Сколько HP восстановит за 1 раз

new gl_iszAllocString_InfoTarget,
	gl_iszAllocString_Totem,
	gl_iszModelIndex_ShockWave,

	Float: gl_flTotemWait[MAX_CLIENTS + 1],
	gl_iUserBody[MAX_CLIENTS + 1],
	gl_iBitUserHasTotem,

	gl_iMsgID_ScreenFade,
	gl_iMaxPlayers,
	gl_iZClassID;

public plugin_init()
{
	register_plugin("[ZP] Class: x-Voodoo", "2019 | 1.0", "xUnicorn (t3rkecorejz)");

	register_event("HLTV", "EV_RoundStart", "a", "1=0", "2=0");

	new const GRENADES_ENTITY[][] = { "weapon_hegrenade", "weapon_flashbang", "weapon_smokegrenade" };
	for(new i = 0; i < sizeof GRENADES_ENTITY; i++)
		RegisterHam(Ham_Item_Deploy, GRENADES_ENTITY[i], "CGrenade__Deploy_Post", true);

	RegisterHam(Ham_Think, "info_target", "CEntity__Think_Pre", false);

	register_clcmd("drop", "Command__UseAbility");

	gl_iMsgID_ScreenFade = get_user_msgid("ScreenFade");
	gl_iMaxPlayers = get_maxplayers();
}

public plugin_precache()
{
	// Models
	engfunc(EngFunc_PrecacheModel, ZM_CLASS_BOMB);
	engfunc(EngFunc_PrecacheModel, ENTITY_TOTEM_MODEL);

	/// Sounds
	UTIL_PrecacheSoundsFromModel(ZM_CLASS_BOMB);

	// Model Index
	gl_iszModelIndex_ShockWave = engfunc(EngFunc_PrecacheModel, "sprites/shockwave.spr");

	// Alloc String
	gl_iszAllocString_InfoTarget = engfunc(EngFunc_AllocString, "info_target");
	gl_iszAllocString_Totem = engfunc(EngFunc_AllocString, ENTITY_TOTEM_CLASSNAME);

	// Other
	gl_iZClassID = zp_register_class(CLASS_ZOMBIE, ZM_CLASS_NAME, ZM_CLASS_INFO, ZM_CLASS_MODEL, 
	ZM_CLASS_CLAW, 13, 0, ADMIN_ALL, ZM_CLASS_HEALTH, 0, ZM_CLASS_SPEED, ZM_CLASS_GRAVITY, ZM_CLASS_KNOCKBACK);
}

public client_putinserver(iPlayer) Reset_Value(iPlayer);
public client_disconnect(iPlayer) Reset_Value(iPlayer);
public zp_user_infected_post(iPlayer, iInfector)
{
	Reset_Value(iPlayer);

	gl_iUserBody[iPlayer] = pev(iPlayer, pev_body);
	set_pev(iPlayer, pev_body, gl_iUserBody[iPlayer] + 2);
}
public zp_user_humanized_pre(iPlayer) Reset_Value(iPlayer);
public EV_RoundStart()
{
	new iEntity = FM_NULLENT;
	while((iEntity = engfunc(EngFunc_FindEntityByString, iEntity, "classname", ENTITY_TOTEM_CLASSNAME)))
	{
		if(pev_valid(iEntity))
			set_pev(iEntity, pev_flags, FL_KILLME);
	}

	for(new iPlayer = 1; iPlayer <= gl_iMaxPlayers; iPlayer++) 
	{
		if(!is_user_connected(iPlayer)) continue;

		Reset_Value(iPlayer);
	}
}

Reset_Value(iPlayer)
{
	reset_bit(gl_iBitUserHasTotem, iPlayer);

	gl_flTotemWait[iPlayer] = 0.0;
	gl_iUserBody[iPlayer] = 0;

	if(task_exists(iPlayer + TASKID_WAIT_HUD))
		remove_task(iPlayer + TASKID_WAIT_HUD);
}

public Command__UseAbility(iPlayer)
{
	if(!is_user_alive(iPlayer) || !zp_get_user_zombie(iPlayer) || zp_get_user_nemesis(iPlayer)) return PLUGIN_CONTINUE;
	if(zp_get_user_zombie_class(iPlayer) != gl_iZClassID) return PLUGIN_CONTINUE;
	if(get_bit(gl_iBitUserHasTotem, iPlayer)) return PLUGIN_CONTINUE;

	new Float: flGameTime = get_gametime();
	if(gl_flTotemWait[iPlayer] <= flGameTime)
	{
		set_bit(gl_iBitUserHasTotem, iPlayer);
		Create_Totem(iPlayer);
		set_pev(iPlayer, pev_body, gl_iUserBody[iPlayer]);

		if(task_exists(iPlayer + TASKID_WAIT_HUD))
			remove_task(iPlayer + TASKID_WAIT_HUD);

		set_task(1.0, "CTask__CreateWaitHud", iPlayer + TASKID_WAIT_HUD, _, _, .flags = "b");
	}

	return PLUGIN_CONTINUE;
}

public CGrenade__Deploy_Post(iItem)
{
	new iPlayer = get_pdata_cbase(iItem, m_pPlayer, linux_diff_weapon);
	if(!zp_get_user_zombie(iPlayer) || zp_get_user_nemesis(iPlayer)) return;

	if(zp_get_user_zombie_class(iPlayer) == gl_iZClassID)
		set_pev(iPlayer, pev_viewmodel2, ZM_CLASS_BOMB);
}

public CEntity__Think_Pre(iEntity)
{
	if(!pev_valid(iEntity) || pev_valid(iEntity) != PDATA_SAFE) return HAM_IGNORED;
	if(pev(iEntity, pev_classname) == gl_iszAllocString_Totem)
	{
		new Float: flGameTime = get_gametime();
		new Float: flTotemAlive; pev(iEntity, pev_fuser4, flTotemAlive);
		new iOwner = pev(iEntity, pev_owner);

		if(flTotemAlive <= flGameTime)
		{
			reset_bit(gl_iBitUserHasTotem, iOwner);
			gl_flTotemWait[iOwner] = flGameTime + ZM_CLASS_WAIT_TOTEM;

			set_pev(iEntity, pev_flags, FL_KILLME);
			return HAM_IGNORED;
		}

		new Float: vecOrigin[3]; pev(iEntity, pev_origin, vecOrigin);

		// https://github.com/baso88/SC_AngelScript/wiki/TE_BEAMCYLINDER
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
		write_byte(TE_BEAMCYLINDER);
		engfunc(EngFunc_WriteCoord, vecOrigin[0]);
		engfunc(EngFunc_WriteCoord, vecOrigin[1]);
		engfunc(EngFunc_WriteCoord, vecOrigin[2] + 10.0);
		engfunc(EngFunc_WriteCoord, vecOrigin[0]);
		engfunc(EngFunc_WriteCoord, vecOrigin[1]);
		engfunc(EngFunc_WriteCoord, vecOrigin[2] + 200.0);
		write_short(gl_iszModelIndex_ShockWave); // Model Index
		write_byte(0); // Start frame
		write_byte(0); // Framerate
		write_byte(8); // Life
		write_byte(10); // Width
		write_byte(0); // Noise
		write_byte(0); // Red
		write_byte(200); // Green
		write_byte(0); // Blue
		write_byte(200); // Alpha
		write_byte(0); // Speed
		message_end();

		new iVictim = FM_NULLENT;
		while((iVictim = engfunc(EngFunc_FindEntityInSphere, iVictim, vecOrigin, 150.0)) > 0)
		{
			if(!is_user_alive(iVictim)) continue;
			if(!zp_get_user_zombie(iVictim) || zp_get_user_nemesis(iVictim)) continue;

			set_pev(iVictim, pev_health, pev(iVictim, pev_health) + ENTITY_TOTEM_HEAL_AMOUNT);
			UTIL_ScreenFade(iVictim, (1<<10) * 2, (1<<10) * 2, 0x0000, 0, 200, 0, 70);
		}

		set_pev(iEntity, pev_nextthink, flGameTime + ENTITY_TOTEM_NEXTTHINK);
	}

	return HAM_IGNORED;
}

public Create_Totem(iPlayer)
{
	new iEntity = engfunc(EngFunc_CreateNamedEntity, gl_iszAllocString_InfoTarget);
	if(!iEntity) return FM_NULLENT;

	new Float: flGameTime = get_gametime();
	new Float: vecOrigin[3]; pev(iPlayer, pev_origin, vecOrigin);
	new Float: vecViewOfs[3]; pev(iPlayer, pev_view_ofs, vecViewOfs);
	new Float: vecAngles[3]; pev(iPlayer, pev_angles, vecAngles);
	new Float: vecForward[3]; angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecForward);
	new Float: vecAnglesEntity[3]; vecAnglesEntity[1] = vecAngles[1] - 180.0;

	new Float: vecEnd[3];
	vecEnd[0] = vecOrigin[0] + vecViewOfs[0] + vecForward[0] * 100.0;
	vecEnd[1] = vecOrigin[1] + vecViewOfs[1] + vecForward[1] * 100.0;
	vecEnd[2] = vecOrigin[2] + vecViewOfs[2] + vecForward[2] * 100.0;

	{
		new iTrace = create_tr2();

		engfunc(EngFunc_TraceLine, vecOrigin, vecEnd, DONT_IGNORE_MONSTERS, iPlayer, iTrace);
		get_tr2(iTrace, TR_vecEndPos, vecEnd);

		free_tr2(iTrace);
	}

	engfunc(EngFunc_SetModel, iEntity, ENTITY_TOTEM_MODEL);
	engfunc(EngFunc_SetOrigin, iEntity, vecEnd);

	set_pev_string(iEntity, pev_classname, gl_iszAllocString_Totem);
	set_pev(iEntity, pev_movetype, MOVETYPE_TOSS);
	set_pev(iEntity, pev_solid, SOLID_BBOX);
	set_pev(iEntity, pev_owner, iPlayer);
	set_pev(iEntity, pev_nextthink, flGameTime + ENTITY_TOTEM_NEXTTHINK);
	set_pev(iEntity, pev_fuser4, flGameTime + (ENTITY_TOTEM_ALIVE + 0.5));
	set_pev(iEntity, pev_angles, vecAnglesEntity);

	set_entity_anim(iEntity, 0);

	engfunc(EngFunc_DropToFloor, iEntity);

	return iEntity;
}

public CTask__CreateWaitHud(iTask)
{
	new iPlayer = iTask - TASKID_WAIT_HUD;

	if(is_user_alive(iPlayer))
	{
		if(!zp_get_user_zombie(iPlayer) || zp_get_user_nemesis(iPlayer))
		{
			remove_task(iTask);
			return;
		}

		new szText[256];
		new Float: flGameTime = get_gametime();

		if(get_bit(gl_iBitUserHasTotem, iPlayer))
		{
			new iEntity = fm_find_ent_by_owner(-1, ENTITY_TOTEM_CLASSNAME, iPlayer);
			if(iEntity || pev_valid(iEntity))
				formatex(szText, charsmax(szText), "El tótem desaparecerá en %d segundos..", floatround(pev(iEntity, pev_fuser4) - flGameTime));
		}
		else
		{
			if(gl_flTotemWait[iPlayer] > flGameTime)
				formatex(szText, charsmax(szText), "(G) Tótem curativo: [%02d]", floatround(gl_flTotemWait[iPlayer] - flGameTime));
			else
			{
				set_pev(iPlayer, pev_body, gl_iUserBody[iPlayer] + 2);

				remove_task(iTask);
				return;
			}
		}

		set_hudmessage(250, 180, 30, 0.75, 0.92, 0, 1.0, 1.1, 0.0, 0.0, -1);
		show_hudmessage(iPlayer, "%s", szText);
	}
	else remove_task(iTask);
}

/* ~ [ Stocks ] ~ */
stock set_entity_anim(iEntity, iSequence)
{
	set_pev(iEntity, pev_frame, 1.0);
	set_pev(iEntity, pev_framerate, 1.0);
	set_pev(iEntity, pev_animtime, get_gametime());
	set_pev(iEntity, pev_sequence, iSequence);
}

stock UTIL_PrecacheSoundsFromModel(const szModelPath[])
{
	new iFile;
	
	if((iFile = fopen(szModelPath, "rt")))
	{
		new szSoundPath[64];
		
		new iNumSeq, iSeqIndex;
		new iEvent, iNumEvents, iEventIndex;
		
		fseek(iFile, 164, SEEK_SET);
		fread(iFile, iNumSeq, BLOCK_INT);
		fread(iFile, iSeqIndex, BLOCK_INT);
		
		for(new k, i = 0; i < iNumSeq; i++)
		{
			fseek(iFile, iSeqIndex + 48 + 176 * i, SEEK_SET);
			fread(iFile, iNumEvents, BLOCK_INT);
			fread(iFile, iEventIndex, BLOCK_INT);
			fseek(iFile, iEventIndex + 176 * i, SEEK_SET);
			
			for(k = 0; k < iNumEvents; k++)
			{
				fseek(iFile, iEventIndex + 4 + 76 * k, SEEK_SET);
				fread(iFile, iEvent, BLOCK_INT);
				fseek(iFile, 4, SEEK_CUR);
				
				if(iEvent != 5004)
					continue;
				
				fread_blocks(iFile, szSoundPath, 64, BLOCK_CHAR);
				
				if(strlen(szSoundPath))
				{
					strtolower(szSoundPath);
					engfunc(EngFunc_PrecacheSound, szSoundPath);
				}
			}
		}
	}
	
	fclose(iFile);
}

stock UTIL_ScreenFade(iPlayer, iDuration, iHoldTime, iFlags, iRed, iGreen, iBlue, iAlpha, iReliable = 0)
{
	if(!iPlayer)
		message_begin(iReliable ? MSG_ALL : MSG_BROADCAST, gl_iMsgID_ScreenFade);
	else message_begin(iReliable ? MSG_ONE : MSG_ONE_UNRELIABLE, gl_iMsgID_ScreenFade, _, iPlayer);

	write_short(iDuration);
	write_short(iHoldTime);
	write_short(iFlags);
	write_byte(iRed);
	write_byte(iGreen);
	write_byte(iBlue);
	write_byte(iAlpha);
	message_end();
}
