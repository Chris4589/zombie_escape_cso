#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <hamsandwich>
#include <zombieplague>

new const hclass1_name[] = { "Gerrad Paratropper" }
new const hclass1_info[] = { "Paracaidas con E" }
new const hclass1_model[] = { "cso_gerrard" }
const hclass1_health = 300//vida
const hclass1_speed = 330//velocidad
const Float:hclass1_gravity = 0.6//gravedad
const Float:hclass1_knockback = 1.0

new const PARA_CLASS[] = { "parachute" };
new const PARA_MODEL[] = { "models/zombie_plague/parachute.mdl" }

new HamHook:_HamObjectCaps, HamHook:_HamSpawn;
new Float:g_flFallSpeed, g_paratropper;
new g_iPara_Ent[33];
new Float:g_fGravity[33][3];

public plugin_precache() 
{
    g_paratropper = zp_register_class(CLASS_HUMAN, hclass1_name, hclass1_info, hclass1_model, "default", 24, 0, ADMIN_ALL, 
        hclass1_health, 40/*chaleco*/, hclass1_speed, hclass1_gravity, hclass1_knockback)
    precache_model(PARA_MODEL)
}
public plugin_init() 
{
    register_plugin("[ZP] Gerrad Paratropper", "1.0b", "const author[]");
    _HamSpawn = RegisterHam(Ham_Spawn, "player", "CBasePlayer_PostSpawn", .Post=1)
    _HamObjectCaps = RegisterHam(Ham_ObjectCaps, "player", "Ham_ObjectCaps_Pre", .Post=0)
}
public plugin_cfg() 
{
    g_flFallSpeed = 50 * -1.0;
}
public Ham_ObjectCaps_Pre(id) 
{
    if( zp_get_class(id) >= SURVIVOR)
        return;

    if(!is_user_alive(id) || zp_get_user_human_class(id) != g_paratropper) 
        return;
    
    if((pev(id, pev_button) & IN_USE) 
    && !( pev(id, pev_flags) & FL_ONGROUND) 
    && !(pev(id, pev_movetype) == MOVETYPE_FLY))
    {
        if(g_iPara_Ent[id] <= 0) {
            g_iPara_Ent[id] = CreateParachute(id);
        }
        else 
        {
            ExecuteParachute(id);
        }
    }
    else 
    {
        RemoveParachute(id, g_iPara_Ent[id]);
    }
}
public CBasePlayer_PostSpawn(id) 
{
    if(g_iPara_Ent[id] > 0) 
        RemoveParachute(id, g_iPara_Ent[id]);
}
public plugin_pause() 
{
    DisableHamForward(_HamObjectCaps);
    DisableHamForward(_HamSpawn);
    
    new iPlayers[MAX_PLAYERS], iNum, i, Players;
    get_players(iPlayers, iNum);
    
    for(i = 0; i < iNum; i++) 
    {
        Players = iPlayers[i];
        if(g_iPara_Ent[Players] > 0) 
        {
            RemoveParachute(Players, g_iPara_Ent[Players]);
        }
    }
}
public plugin_unpause() 
{
    EnableHamForward(_HamObjectCaps);
    EnableHamForward(_HamSpawn);
}
CreateParachute(id) 
{
    new entid = create_entity("info_target");
    if(entid > 0) 
    {
        entity_set_string(entid, EV_SZ_classname, PARA_CLASS);
        entity_set_model(entid, PARA_MODEL);
        entity_set_int(entid, EV_INT_movetype, MOVETYPE_FOLLOW);
        entity_set_int(entid, EV_INT_solid, SOLID_NOT);
        entity_set_edict(entid, EV_ENT_aiment, id);
        entity_set_edict(entid, EV_ENT_owner, id);
        entity_set_int(entid, EV_INT_sequence, 0);
        entity_set_int(entid, EV_INT_gaitsequence, 1);
        entity_set_float(entid, EV_FL_frame, 0.0);
        entity_set_float(entid, EV_FL_fuser1, 0.0);
        
        return entid;
    }
    return 0;
}
ExecuteParachute(id) 
{
    if(!is_user_alive(id) || g_iPara_Ent[id] < 1 )
        return;

    new Float:velocity[3], Float:frame;

    entity_get_vector(id, EV_VEC_velocity, g_fGravity[id]);
    entity_get_vector(id, EV_VEC_velocity, velocity);
    //velocity[2] = (velocity[2] + 20.0  <  g_flFallSpeed) ? velocity[2] + 20.0 :  g_flFallSpeed;
    velocity[ 2 ] = floatmin( ( velocity[ 2 ] + 40.0 ), g_flFallSpeed ); 
    entity_set_vector(id, EV_VEC_velocity, velocity);

    if(entity_get_int(g_iPara_Ent[id], EV_INT_sequence) == 0) 
    {
        frame = entity_get_float(g_iPara_Ent[id], EV_FL_fuser1) + 1.0;
        entity_set_float(g_iPara_Ent[id], EV_FL_fuser1,frame);
        entity_set_float(g_iPara_Ent[id], EV_FL_frame,frame);

        if(frame > 100.0) 
        {
            entity_set_float(g_iPara_Ent[id], EV_FL_animtime, 0.0);
            entity_set_float(g_iPara_Ent[id], EV_FL_framerate, 0.4);
            entity_set_int(g_iPara_Ent[id], EV_INT_sequence, 1);
            entity_set_int(g_iPara_Ent[id], EV_INT_gaitsequence, 1);
            entity_set_float(g_iPara_Ent[id], EV_FL_frame, 0.0);
            entity_set_float(g_iPara_Ent[id], EV_FL_fuser1, 0.0);
        }
    }
}
RemoveParachute(id, entid) 
{
    if(!is_user_alive(id))
        return;

    if(is_valid_ent(entid)) 
        remove_entity(entid)
    
    g_iPara_Ent[id] = 0
    entity_set_vector(id, EV_VEC_velocity, g_fGravity[id]);
} 

public zp_user_infected_post(id, infector, nemesis)
{
    if(g_iPara_Ent[id] > 0) 
        RemoveParachute(id, g_iPara_Ent[id]);
}