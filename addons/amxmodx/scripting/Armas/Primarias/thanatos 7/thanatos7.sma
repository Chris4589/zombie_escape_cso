#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <fun>
#include <hamsandwich>
#include <xs>
#include <cstrike>
#include <zombie_escape_v1>



#define PLUGIN "[CSO] Pri: Thanatos-7"
#define VERSION "1.0"
#define VERSION "1.0"
#define AUTHOR "Dev!l"

#define ENG_NULLENT        -1
#define EV_INT_WEAPONKEY    EV_INT_impulse

#define WEAPONKEY 754247

const USE_STOPPED = 0
const PDATA_SAFE = 2
const OFFSET_LINUX_WEAPONS = 4
const OFFSET_WEAPONOWNER = 41
const m_flNextAttack = 83
const m_szAnimExtention = 492

#define WEAP_LINUX_XTRA_OFF        4
#define m_flTimeWeaponIdle            48
#define m_iClip                    51
#define m_fInReload                54
#define PLAYER_LINUX_XTRA_OFF    5

#define RELOAD_TIME        4.5

new const v_model[] = "models/thanatos/v_thanatos7.mdl"
new const p_model[] = "models/thanatos/p_thanatos7.mdl"
//new const w_model[] = "models/cso/w_thanatos7.mdl"
new const SCYTHE_MODEL[] = "models/thanatos/thanatos7_scythe.mdl"

new const sound[10][] = 
{
    "weapons/thanatos7-1.wav",
    "weapons/thanatos7_bdraw.wav",
    "weapons/thanatos7_bidle2.wav",
    "weapons/thanatos7_clipin1.wav",
    "weapons/thanatos7_clipin2.wav",
    "weapons/thanatos7_clipout1.wav",
    "weapons/thanatos7_clipout2.wav",
    "weapons/thanatos7_draw.wav",
    "weapons/thanatos7_scythereload.wav",
    "weapons/thanatos7_scytheshoot.wav"
}

new const sprite[4][] = 
{
    "sprites/weapon_thanatos7.txt",
    "sprites/cso/640hud7.spr",
    "sprites/cso/640hud13.spr",
    "sprites/cso/640hud117.spr"
}

enum
{
    IDLE = 0,
    BIDLE,
    BIDLE2,
    SHOOT1,
    BSHOOT1,
    SHOOT2,
    BSHOOT2,
    RELOAD,
    BRELOAD,
    SCYTHESHOOT,
    SCYTHERELOAD,
    DRAW,
    BDRAW
}

#define write_coord_f(%1)    engfunc(EngFunc_WriteCoord,%1)

new const GUNSHOT_DECALS[] = { 41, 42, 43, 44, 45 }

new g_had_thanatos7[33], g_thanatos7_ammo[33], g_mode[33], g_reload[33]
new Float:cl_pushangle[33][3], g_clip_ammo[33], g_old_weapon[33]
new g_IsInPrimaryAttack, g_orig_event_thanatos7, g_thanatos7_TmpClip[33], Ent, gmsgWeaponList, g_MaxPlayers ,g_Msg_StatusIcon
new cvar_dmg_scythe, cvar_clip_thanatos7, cvar_thanatos7_ammo, cvar_recoil_thanatos7, cvar_dmg_thanatos7
new const WEAPONENTNAMES[][] = { "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
            "weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
            "weapon_mp5navy", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
            "weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
            "weapon_ak47", "weapon_knife", "weapon_p90" }
            
enum
{
    MODE_NOLMAL = 1,
    MODE_CHANGING_1,
    MODE_CHANGING_2,
    MODE_BOLT
}
new g_item

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)
    register_forward(FM_PlaybackEvent, "fwPlaybackEvent")
    register_forward(FM_CmdStart, "fw_CmdStart")
    register_forward(FM_SetModel, "fw_SetModel")
    register_touch("scythe", "*", "fw_Touch")
    register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
    register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
    
    RegisterHam(Ham_Use, "func_tank", "fw_UseStationary_Post", 1)
    RegisterHam(Ham_Use, "func_tankmortar", "fw_UseStationary_Post", 1)
    RegisterHam(Ham_Use, "func_tankrocket", "fw_UseStationary_Post", 1)
    RegisterHam(Ham_Use, "func_tanklaser", "fw_UseStationary_Post", 1)
    
    RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
    RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack")
    RegisterHam(Ham_TraceAttack, "func_breakable", "fw_TraceAttack", 1)
    RegisterHam(Ham_TraceAttack, "func_wall", "fw_TraceAttack", 1)
    RegisterHam(Ham_TraceAttack, "func_door", "fw_TraceAttack", 1)
    RegisterHam(Ham_TraceAttack, "func_door_rotating", "fw_TraceAttack", 1)
    RegisterHam(Ham_TraceAttack, "func_plat", "fw_TraceAttack", 1)
    RegisterHam(Ham_TraceAttack, "func_rotating", "fw_TraceAttack", 1)
    
    for (new i = 1; i < sizeof WEAPONENTNAMES; i++)
        if (WEAPONENTNAMES[i][0]) RegisterHam(Ham_Item_Deploy, WEAPONENTNAMES[i], "fw_Item_Deploy_Post", 1)
    
    RegisterHam(Ham_Item_AddToPlayer, "weapon_m249", "fw_AddToPlayer_Post", 1)
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_m249", "fw_PrimaryAttack")
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_m249", "fw_PrimaryAttack_Post", 1)
    RegisterHam(Ham_Item_PostFrame, "weapon_m249", "fw_ItemPostFrame")
    RegisterHam(Ham_Weapon_Reload, "weapon_m249", "fw_Reload")
    RegisterHam(Ham_Weapon_Reload, "weapon_m249", "fw_Reload_Post", 1)
    RegisterHam(Ham_Weapon_WeaponIdle, "weapon_m249", "fw_Idleanim", 1)
    RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
    RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn")
    
    cvar_recoil_thanatos7 = register_cvar("cso_thanatos7_recoil", "0.5")
    cvar_dmg_thanatos7 = register_cvar("cso_dmg_thanatos7", "60.0")
    cvar_dmg_scythe = register_cvar("cso_dmg_scythe", "55.0")
    cvar_clip_thanatos7 = register_cvar("cso_thanatos7_clipp", "45")
    cvar_thanatos7_ammo = register_cvar("cso_thanatos7_ammo", "240")
       
    gmsgWeaponList = get_user_msgid("WeaponList")
    g_Msg_StatusIcon = get_user_msgid("StatusIcon")
    g_MaxPlayers = get_maxplayers()
    
    register_clcmd("weapon_thanatos7", "hook_weapon")

    g_item = zp_arma("Thanatos-7", 0, 0, PRIMARIA, ADMIN_BAN, "GOLD")
}

public dar_arma(id, item_id)
{
    if(item_id != g_item || !is_user_alive(id))
    return;
    get_thanatos(id)
}

public plugin_natives() register_native("thanatos7", "get_thanatos", 1)

public plugin_precache()
{
    precache_model(v_model)
    precache_model(p_model)
    //precache_model(w_model)
    precache_model(SCYTHE_MODEL)
    
    for(new i = 0; i < sizeof(sound); i++) 
        precache_sound(sound[i])
        
    for(new i = 1; i < sizeof(sprite); i++)
        precache_model(sprite[i])
        
    register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public fw_PlayerSpawn(id)
{
    remove_thanatos7(id)
}

public zp_user_infected_post(id)
{
    remove_thanatos7(id)
}

public fw_PlayerKilled(id)
{
    remove_thanatos7(id)
}


public hook_weapon(id)
{
    engclient_cmd(id, "weapon_m249")
    return
}

public fw_PrecacheEvent_Post(type, const name[])
{
    if(equal("events/m249.sc", name))
        g_orig_event_thanatos7 = get_orig_retval()
}
/*
public zp_extra_item_selected(id, itemid)
{
    if(itemid == g_thanatos7) get_thanatos(id)
}
*/
public get_thanatos(id)
{
    if(!is_user_alive(id))
        return
        
    new iWep2 = give_item(id,"weapon_m249")
    if( iWep2 > 0 )
    {
        cs_set_weapon_ammo(iWep2, get_pcvar_num(cvar_clip_thanatos7))
        cs_set_user_bpammo (id, CSW_M249, get_pcvar_num(cvar_thanatos7_ammo))
        set_weapons_timeidle(id, CSW_M249, 2.0)
        set_player_nextattackx(id, 2.0)
        set_weapon_anim(id, DRAW)
    }
    g_had_thanatos7[id] = 1
    g_mode[id] = MODE_NOLMAL
    g_thanatos7_ammo[id] = 0
    g_reload[id] = 1
    update_specialammo(id, g_thanatos7_ammo[id], g_thanatos7_ammo[id] > 0 ? 1 : 0)
    
    message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
    write_string("weapon_thanatos7")
    write_byte(3)
    write_byte(200)
    write_byte(-1)
    write_byte(-1)
    write_byte(0)
    write_byte(4)
    write_byte(CSW_M249)
    write_byte(0)
    message_end()
}

public remove_thanatos7(id)
{
    update_specialammo(id, g_thanatos7_ammo[id], 0)
        
    g_had_thanatos7[id] = 0
    g_thanatos7_ammo[id] = 0
    g_reload[id] = 1
}

public fw_TraceAttack(iEnt, iAttacker, Float:flDamage, Float:fDir[3], ptr, iDamageType)
{
    if(!is_user_alive(iAttacker))
        return

    new g_currentweapon = get_user_weapon(iAttacker)

    if(g_currentweapon != CSW_M249 || !g_had_thanatos7[iAttacker])
        return
        
    SetHamParamFloat(3, get_pcvar_float(cvar_dmg_thanatos7))
    
    static Float:flEnd[3], Float:myOrigin[3]
    
    pev(iAttacker, pev_origin, myOrigin)
    get_tr2(ptr, TR_vecEndPos, flEnd)
        
    if(!is_user_alive(iEnt))
    {
        message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
        write_byte(TE_DECAL)
        write_coord_f(flEnd[0])
        write_coord_f(flEnd[1])
        write_coord_f(flEnd[2])
        write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
        write_short(iEnt)
        message_end()

        message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
        write_byte(TE_WORLDDECAL)
        write_coord_f(flEnd[0])
        write_coord_f(flEnd[1])
        write_coord_f(flEnd[2])
        write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
        message_end()
        
        message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
        write_byte(TE_GUNSHOTDECAL)
        write_coord_f(flEnd[0])
        write_coord_f(flEnd[1])
        write_coord_f(flEnd[2])
        write_short(iAttacker)
        write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
        message_end()
    }
}

public fw_UpdateClientData_Post(id, sendweapons, CD_Handle)
{
    if(!is_user_alive(id) || (get_user_weapon(id) != CSW_M249 || !g_had_thanatos7[id]))
        return FMRES_IGNORED
    
    set_cd(CD_Handle, CD_flNextAttack, halflife_time () + 0.001)
    
    return FMRES_HANDLED
}

public fw_SetModel(entity, model[])
{
    if(!is_valid_ent(entity))
        return FMRES_IGNORED
    
    static szClassName[33]
    entity_get_string(entity, EV_SZ_classname, szClassName, charsmax(szClassName))
        
    if(!equal(szClassName, "weaponbox"))
        return FMRES_IGNORED
    
    static iOwner
    
    iOwner = entity_get_edict(entity, EV_ENT_owner)
    
    if(equal(model, "models/w_m249.mdl"))
    {
        static iStoredAugID
    
        iStoredAugID = find_ent_by_owner(ENG_NULLENT, "weapon_m249", entity)

        if(!is_valid_ent(iStoredAugID))
            return FMRES_IGNORED
    
        if(g_had_thanatos7[iOwner])
        {
            g_had_thanatos7[iOwner] = 0
            
            entity_set_int(iStoredAugID, EV_INT_WEAPONKEY, WEAPONKEY)
            set_pev(iStoredAugID, pev_iuser4, g_thanatos7_ammo[iOwner])
            //entity_set_model(entity, w_model)
            
            return FMRES_SUPERCEDE
        }
    }
    return FMRES_IGNORED
}

public fw_UseStationary_Post(entity, caller, activator, use_type)
{
    if (use_type == USE_STOPPED && is_user_connected(caller))
        replace_weapon_models(caller, get_user_weapon(caller))
}

public fw_Item_Deploy_Post(weapon_ent)
{
    static owner
    owner = fm_cs_get_weapon_ent_owner(weapon_ent)
    
    static weaponid
    weaponid = cs_get_weapon_id(weapon_ent)
    
    replace_weapon_models(owner, weaponid)
}

public Event_CurWeapon(id)
{
    if(!is_user_alive(id))
        return
        
    if(get_user_weapon(id) != CSW_M249 && g_old_weapon[id] == CSW_M249) 
    {
        update_specialammo(id, g_thanatos7_ammo[id], 0)
    }
    g_old_weapon[id] = get_user_weapon(id)
        
    replace_weapon_models(id, read_data(2))
}

replace_weapon_models(id, weaponid)
{
    switch (weaponid)
    {
        case CSW_M249:
        {
            if(g_had_thanatos7[id])
            {
                set_pev(id, pev_viewmodel2, v_model)
                set_pev(id, pev_weaponmodel2, p_model)
                update_specialammo(id, g_thanatos7_ammo[id], g_thanatos7_ammo[id] > 0 ? 1 : 0)
                g_reload[id] = 1
                if(g_mode[id] == MODE_NOLMAL)
                {
                    if(g_old_weapon[id] != CSW_M249) 
                    {
                        set_weapon_anim(id, DRAW)
                        set_weapons_timeidle(id, CSW_M249, 2.0)
                        set_player_nextattackx(id, 2.0)

                        remove_task(id)
                        message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
                        write_string("weapon_thanatos7")
                        write_byte(3)
                        write_byte(200)
                        write_byte(-1)
                        write_byte(-1)
                        write_byte(0)
                        write_byte(4)
                        write_byte(CSW_M249)
                        write_byte(0)
                        message_end()
                    }
                }
                else if(g_mode[id] == MODE_BOLT && g_thanatos7_ammo[id] == 1)
                {
                    if(g_old_weapon[id] != CSW_M249) 
                    {
                        set_weapon_anim(id, BDRAW)
                        set_weapons_timeidle(id, CSW_M249, 2.0)
                        set_player_nextattackx(id, 2.0)
                        
                        remove_task(id)
                        message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
                        write_string("weapon_thanatos7")
                        write_byte(3)
                        write_byte(200)
                        write_byte(-1)
                        write_byte(-1)
                        write_byte(0)
                        write_byte(4)
                        write_byte(CSW_M249)
                        write_byte(0)
                        message_end()
                    }
                }
            }
        }
    }
    g_old_weapon[id] = get_user_weapon(id)
}

public fw_AddToPlayer_Post(weapon, id)
{
    if(!is_valid_ent(weapon) || !is_user_connected(id))
        return HAM_IGNORED
    
    if(entity_get_int(weapon, EV_INT_WEAPONKEY) == WEAPONKEY)
    {
        g_had_thanatos7[id] = 1
        g_thanatos7_ammo[id] = pev(weapon, pev_iuser4)
        
        message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
        write_string("weapon_thanatos7")
        write_byte(3)
        write_byte(200)
        write_byte(-1)
        write_byte(-1)
        write_byte(0)
        write_byte(4)
        write_byte(CSW_M249)
        write_byte(0)
        message_end()
    }
    else
    {
        message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
        write_string("weapon_m249")
        write_byte(3)
        write_byte(200)
        write_byte(-1)
        write_byte(-1)
        write_byte(0)
        write_byte(4)
        write_byte(CSW_M249)
        write_byte(0)
        message_end()
    }
    return HAM_IGNORED
}

public fw_PrimaryAttack(Weapon)
{
    new Player = get_pdata_cbase(Weapon, 41, 4)
    
    if (!g_had_thanatos7[Player])
        return
    
    g_IsInPrimaryAttack = 1
    pev(Player,pev_punchangle,cl_pushangle[Player])
    
    g_clip_ammo[Player] = cs_get_weapon_ammo(Weapon)
}

public fw_PrimaryAttack_Post(Weapon)
{
    g_IsInPrimaryAttack = 0
    new Player = get_pdata_cbase(Weapon, 41, 4)
    
    new szClip, szAmmo
    get_user_weapon(Player, szClip, szAmmo)
        
    if(g_had_thanatos7[Player])
    {
        if(szClip <= 0) emit_sound(Player, CHAN_WEAPON, sound[5], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
    }
    
    if(g_had_thanatos7[Player])
    {
        if (!g_clip_ammo[Player])
            return
            
        new Float:push[3]
        pev(Player,pev_punchangle,push)
        xs_vec_sub(push,cl_pushangle[Player],push)
        
        xs_vec_mul_scalar(push,get_pcvar_float(cvar_recoil_thanatos7),push)
        xs_vec_add(push,cl_pushangle[Player],push)
        set_pev(Player,pev_punchangle,push)
        emit_sound(Player, CHAN_WEAPON, sound[0], 1.0, ATTN_NORM, 0, PITCH_NORM)
        if(g_mode[Player] == MODE_NOLMAL)
        {    
            set_weapon_anim(Player, SHOOT1)
        }
        else if(g_mode[Player] == MODE_BOLT)
        {
            set_weapon_anim(Player, BSHOOT1)
        }
        
    }
}

public fw_CmdStart(id, uc_handle, seed)
{
    if(!is_user_alive(id) || !is_user_connected(id))
        return
    if(get_user_weapon(id) != CSW_M249 || !g_had_thanatos7[id])
        return
    
    static ent; ent = fm_get_user_weapon_entity(id, CSW_M249)
    if(!pev_valid(ent))
        return
        
    new szClip, szAmmo
    get_user_weapon(id, szClip, szAmmo)
    
    static CurButton
    CurButton = get_uc(uc_handle, UC_Buttons)
    
    if(CurButton & IN_ATTACK2 && szClip >= 1)
    {
        CurButton &= ~IN_ATTACK2
        set_uc(uc_handle, UC_Buttons, CurButton)
        
        if(get_pdata_float(ent, 46, 4) > 0.0 || get_pdata_float(ent, 47, 4) > 0.0) 
            return
            
        if(g_mode[id] == MODE_NOLMAL)
        {
            set_weapons_timeidle(id, CSW_M249, 4.0)
            set_player_nextattackx(id, 4.0)
            set_weapon_anim(id, SCYTHERELOAD)
            g_reload[id] = 0
            emit_sound(id, CHAN_WEAPON, sound[8], 1.0, ATTN_NORM, 0, PITCH_NORM)
            set_task(0.1, "change_mode", id)
            g_mode[id] = MODE_CHANGING_1
        
        }
        else if(g_mode[id] == MODE_BOLT)
        {
            if(g_thanatos7_ammo[id] == 0)
                return
                
            set_weapons_timeidle(id, CSW_M249, 4.0)
            set_player_nextattackx(id, 4.0)
            Scythe_Shoot(id)
            static Float:PunchAngles[3]
            PunchAngles[0] = -10.0
            update_specialammo(id, g_thanatos7_ammo[id], 0)
            g_thanatos7_ammo[id]--
            update_specialammo(id, g_thanatos7_ammo[id], g_thanatos7_ammo[id] > 0 ? 1 : 0)
            g_reload[id] = 0
            set_weapon_anim(id, SCYTHESHOOT)
            emit_sound(id, CHAN_WEAPON, sound[9], 1.0, ATTN_NORM, 0, PITCH_NORM)
            set_task(0.1, "change_mode", id)
            g_mode[id] = MODE_CHANGING_2
        }
    }
}

public change_mode(id)
{
    if(g_mode[id] == MODE_CHANGING_1)
    {
        g_mode[id] = MODE_NOLMAL
        set_task(3.5, "fil_scythe", id)
    }
    else if(g_mode[id] == MODE_CHANGING_2)
    {
        g_reload[id] = 1
        g_mode[id] = MODE_NOLMAL
    }
}

public fil_scythe(id)
{
    set_weapons_timeidle(id, CSW_M249, 0.5)
    set_player_nextattackx(id, 0.5)
    g_mode[id] = MODE_BOLT
    update_specialammo(id, g_thanatos7_ammo[id], 0)
    g_thanatos7_ammo[id]++
    update_specialammo(id, g_thanatos7_ammo[id], 1)
    reload_on(id)
}

public reload_on(id)
{
    g_reload[id] = 1
}

public Scythe_Shoot(id)
{
    static Float:StartOrigin[3], Float:TargetOrigin[3], Float:angles[3], Float:angles_fix[3]
    get_position(id, 2.0, 4.0, -1.0, StartOrigin)

    pev(id,pev_v_angle,angles)
    Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
    if(!pev_valid(Ent)) return
    angles_fix[0] = 360.0 - angles[0]
    angles_fix[1] = angles[1]
    angles_fix[2] = angles[2]
    set_pev(Ent, pev_movetype, MOVETYPE_FLY)
    set_pev(Ent, pev_owner, id)
    
    entity_set_string(Ent, EV_SZ_classname, "scythe")
    engfunc(EngFunc_SetModel, Ent, SCYTHE_MODEL)
    set_pev(Ent, pev_mins,{ -0.1, -0.1, -0.1 })
    set_pev(Ent, pev_maxs,{ 0.1, 0.1, 0.1 })
    set_pev(Ent, pev_origin, StartOrigin)
    set_pev(Ent, pev_angles, angles_fix)
    set_pev(Ent, pev_solid, SOLID_BBOX)
    set_pev(Ent, pev_frame, 0.0)
    set_entity_anim(Ent, 1)
    entity_set_float(Ent, EV_FL_nextthink, halflife_time() + 0.01)
    
    static Float:Velocity[3]
    fm_get_aim_origin(id, TargetOrigin)
    get_speed_vector(StartOrigin, TargetOrigin, 750.0, Velocity)
    set_pev(Ent, pev_velocity, Velocity)
}

public fw_Touch(Ent, Id)
{
    // If ent is valid
    if(!pev_valid(Ent))
        return
    if(pev(Ent, pev_movetype) == MOVETYPE_NONE)
        return
        
    set_pev(Ent, pev_movetype, MOVETYPE_NONE)
    set_pev(Ent, pev_solid, SOLID_NOT)
    set_entity_anim(Ent, 1)
    entity_set_float(Ent, EV_FL_nextthink, halflife_time() + 0.01)
    
    set_task(0.1, "action_scythe", Ent)
    set_task(9.0, "remove", Ent)
}

public remove(Ent)
{
    if(!pev_valid(Ent))
        return
        
    remove_entity(Ent)
}

public action_scythe(Ent)
{
    if(!pev_valid(Ent))
        return
        
    Damage_scythe(Ent)
}

public Damage_scythe(Ent)
{
    if(!pev_valid(Ent))
        return
    
    static id; id = pev(Ent, pev_owner)
    new Float:origin[3]
    pev(Ent, pev_origin, origin)
    
    // Alive...
    new a = FM_NULLENT
    // Get distance between victim and epicenter
    while((a = find_ent_in_sphere(a, origin, 80.0)) != 0)
    {
        if (id == a)
            continue
    
        if(pev(a, pev_takedamage) != DAMAGE_NO)
        {
            ExecuteHamB(Ham_TakeDamage, a, id, id, get_pcvar_float(cvar_dmg_scythe), DMG_BULLET)
        }
    }
    set_task(0.1, "action_scythe", Ent)
}
    
public fw_Idleanim(Weapon)
{
    new id = get_pdata_cbase(Weapon, 41, 4)
    g_reload[id] = 1

    if(!is_user_alive(id) || !g_had_thanatos7[id] || get_user_weapon(id) != CSW_M249)
        return HAM_IGNORED;
    
    if(g_mode[id] == MODE_NOLMAL && g_thanatos7_ammo[id] == 0 && get_pdata_float(Weapon, 48, 4) <= 0.25)
    {
        set_weapon_anim(id, IDLE)
        set_pdata_float(Weapon, 48, 20.0, 4)
        return HAM_SUPERCEDE;
    }
    
    if(g_mode[id] == MODE_BOLT && g_thanatos7_ammo[id] == 1 && get_pdata_float(Weapon, 48, 4) <= 0.25) 
    {
        set_weapon_anim(id, random_num(BIDLE, BIDLE2))
        set_pdata_float(Weapon, 48, 20.0, 4)
        return HAM_SUPERCEDE;
    }

    return HAM_IGNORED;
}

public update_ammo(id)
{
    if(!is_user_alive(id))
        return
    
    static weapon_ent; weapon_ent = fm_find_ent_by_owner(-1, "weapon_m249", id)
    if(pev_valid(weapon_ent)) cs_set_weapon_ammo(weapon_ent, 1)    
    
    cs_set_user_bpammo(id, CSW_M249, 0)
    
    engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), {0, 0, 0}, id)
    write_byte(1)
    write_byte(CSW_M249)
    write_byte(-1)
    message_end()
    
    message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("AmmoX"), _, id)
    write_byte(3)
    write_byte(g_thanatos7_ammo[id])
    message_end()
}

public update_specialammo(id, Ammo, On)
{
    static AmmoSprites[33]
    format(AmmoSprites, sizeof(AmmoSprites), "number_%d", Ammo)
      
    message_begin(MSG_ONE_UNRELIABLE, g_Msg_StatusIcon, {0,0,0}, id)
    write_byte(On)
    write_string(AmmoSprites)
    write_byte(42) // red
    write_byte(212) // green
    write_byte(255) // blue
    message_end()
}

public fw_ItemPostFrame( wpn )
{
    new id = pev(wpn, pev_owner)
    if(!is_user_connected(id))
        return HAM_IGNORED
    
    if(!g_had_thanatos7[id])
        return HAM_IGNORED
        
    if(g_reload[id] == 0)
        return HAM_IGNORED
                
    new Float:flNextAttack = get_pdata_float(id, m_flNextAttack, PLAYER_LINUX_XTRA_OFF)
    new iBpAmmo = cs_get_user_bpammo(id, CSW_M249)
    new iClip = get_pdata_int(wpn, m_iClip, WEAP_LINUX_XTRA_OFF)
    new fInReload = get_pdata_int(wpn, m_fInReload, WEAP_LINUX_XTRA_OFF)
    
    if(fInReload && flNextAttack <= 0.0)
    {
        new j = min(get_pcvar_num(cvar_clip_thanatos7) - iClip, iBpAmmo)
        set_pdata_int(wpn, m_iClip, iClip + j, WEAP_LINUX_XTRA_OFF)
        cs_set_user_bpammo(id, CSW_M249, iBpAmmo-j)
        set_pdata_int(wpn, m_fInReload, 0, WEAP_LINUX_XTRA_OFF)
        fInReload = 0
    }
    return HAM_IGNORED
}

public fw_Reload( wpn ) {
    new id = pev(wpn, pev_owner)
    if(!is_user_connected(id))
        return HAM_IGNORED
    
    if(!g_had_thanatos7[id])
        return HAM_IGNORED
        
    if(g_reload[id] == 0)
        return HAM_IGNORED
                
    g_thanatos7_TmpClip[id] = -1
    new iBpAmmo = cs_get_user_bpammo(id, CSW_M249)
    new iClip = get_pdata_int(wpn, m_iClip, WEAP_LINUX_XTRA_OFF)
    if(iBpAmmo <= 0)
        return HAM_SUPERCEDE
    
    if(iClip >= get_pcvar_num(cvar_clip_thanatos7))
        return HAM_SUPERCEDE
    
    g_thanatos7_TmpClip[id] = iClip
    return HAM_IGNORED
}

public fw_Reload_Post(weapon) {
    new id = pev(weapon, pev_owner)
    if(!is_user_connected(id))
        return HAM_IGNORED
        
    if(!g_had_thanatos7[id])
        return HAM_IGNORED
        
    if(g_thanatos7_TmpClip[id] == -1)
        return HAM_IGNORED
        
    if(g_reload[id] == 0)
        return HAM_IGNORED
        
    set_pdata_int(weapon, m_iClip, g_thanatos7_TmpClip[id], WEAP_LINUX_XTRA_OFF)
    set_pdata_float(weapon, m_flTimeWeaponIdle, RELOAD_TIME, WEAP_LINUX_XTRA_OFF)
    set_pdata_float(id, m_flNextAttack, RELOAD_TIME, PLAYER_LINUX_XTRA_OFF)
    set_pdata_int(weapon, m_fInReload, 1, WEAP_LINUX_XTRA_OFF)
    
    if(g_mode[id] == MODE_NOLMAL && g_thanatos7_ammo[id] == 0)
    {
        set_weapon_anim(id, RELOAD)
        set_pdata_float(weapon, 48, 20.0, 4)
    }
    else if(g_mode[id] == MODE_BOLT && g_thanatos7_ammo[id] == 1)
    {
        set_weapon_anim(id, BRELOAD)
        set_pdata_float(weapon, 48, 20.0, 4)
    }
    return HAM_IGNORED
}

public fwPlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
    if ((eventid != g_orig_event_thanatos7) || !g_IsInPrimaryAttack)
        return FMRES_IGNORED
    if (!(1 <= invoker <= g_MaxPlayers))
        return FMRES_IGNORED

    playback_event(flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
    
    return FMRES_SUPERCEDE
}

stock set_weapon_anim(id, anim)
{
    if(!is_user_alive(id))
        return
    
    set_pev(id, pev_weaponanim, anim)
    
    message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
    write_byte(anim)
    write_byte(pev(id, pev_body))
    message_end()
}

stock get_speed_vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
    new_velocity[0] = origin2[0] - origin1[0]
    new_velocity[1] = origin2[1] - origin1[1]
    new_velocity[2] = origin2[2] - origin1[2]
    static Float:num; num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
    new_velocity[0] *= num
    new_velocity[1] *= num
    new_velocity[2] *= num
    
    return 1;
}

stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
    static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
    
    pev(id, pev_origin, vOrigin)
    pev(id, pev_view_ofs, vUp) //for player
    xs_vec_add(vOrigin, vUp, vOrigin)
    pev(id, pev_v_angle, vAngle) // if normal entity ,use pev_angles
    
    angle_vector(vAngle, ANGLEVECTOR_FORWARD, vForward) //or use EngFunc_AngleVectors
    angle_vector(vAngle, ANGLEVECTOR_RIGHT, vRight)
    angle_vector(vAngle, ANGLEVECTOR_UP, vUp)
    
    vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
    vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
    vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

stock set_weapons_timeidle(id, WeaponId ,Float:TimeIdle)
{
    if(!is_user_alive(id))
        return
        
    static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId)
    if(!pev_valid(entwpn)) 
        return
        
    set_pdata_float(entwpn, 46, TimeIdle, OFFSET_LINUX_WEAPONS)
    set_pdata_float(entwpn, 47, TimeIdle, OFFSET_LINUX_WEAPONS)
    set_pdata_float(entwpn, 48, TimeIdle + 0.5, OFFSET_LINUX_WEAPONS)
}

stock set_player_nextattackx(id, Float:nexttime)
{
    if(!is_user_alive(id))
        return
        
    set_pdata_float(id, m_flNextAttack, nexttime, 5)
}

stock fm_cs_get_weapon_ent_owner(ent)
{
    return get_pdata_cbase(ent, OFFSET_WEAPONOWNER, OFFSET_LINUX_WEAPONS)
}

stock set_entity_anim(ent, anim)
{
    entity_set_float(ent, EV_FL_animtime, get_gametime())
    entity_set_float(ent, EV_FL_framerate, 1.0)
    entity_set_int(ent, EV_INT_sequence, anim)    
}