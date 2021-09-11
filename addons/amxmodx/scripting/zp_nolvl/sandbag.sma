#include <amxmodx> 
#include <amxmisc> 
#include <fakemeta> 
#include <hamsandwich> 
#include <engine> 
#include <xs> 
#include <fun> 
#include <zombieplague> 

// The sizes of models 
#define PALLET_MINS Float:{ -27.260000, -22.280001, -22.290001 } 
#define PALLET_MAXS Float:{  27.340000,  26.629999,  29.020000 } 


// from fakemeta util by VEN 
#define fm_find_ent_by_class(%1,%2) engfunc(EngFunc_FindEntityByString, %1, "classname", %2) 
#define fm_remove_entity(%1) engfunc(EngFunc_RemoveEntity, %1) 
// this is mine 
#define fm_drop_to_floor(%1) engfunc(EngFunc_DropToFloor,%1) 

#define fm_get_user_noclip(%1) (pev(%1, pev_movetype) == MOVETYPE_NOCLIP) 

enum (<<= 1)
{
    g_iEnumBitEntDefault = 1,
    g_iEnumBitEntCustom,
    g_iEnumBitEntMdlBrush,
    g_iEnumBitEntMdlStudio,
    g_iEnumBitEntRendered
}

new const g_szEntClassNamesSpawn[][] =
{
    "func_wall"/*,
    "player",
    "hostage_entity"*/
}

new const g_szEntClassNames[][] =
{
    "amxx_pallets"/*,
    "player",
    "hostage_entity",
    "func_breakable"*/
}

// cvars 
new pnumplugin, remove_nrnd, maxpallets, phealth; 

new g_bEntRegistered[sizeof g_szEntClassNames];

// num of pallets with bags 
new palletscout = 0; 

/* Models for pallets with bags . 
  Are available 2 models, will be set a random of them  */ 
new g_models[][] = 
{ 
    "models/pallet_with_bags2.mdl", 
    "models/pallet_with_bags.mdl" 
} 

new stuck[33] 
new g_bolsas[33]; 
new cvar[3] 

new const Float:size[][3] = { 
    {0.0, 0.0, 1.0}, {0.0, 0.0, -1.0}, {0.0, 1.0, 0.0}, {0.0, -1.0, 0.0}, {1.0, 0.0, 0.0}, {-1.0, 0.0, 0.0}, {-1.0, 1.0, 1.0}, {1.0, 1.0, 1.0}, {1.0, -1.0, 1.0}, {1.0, 1.0, -1.0}, {-1.0, -1.0, 1.0}, {1.0, -1.0, -1.0}, {-1.0, 1.0, -1.0}, {-1.0, -1.0, -1.0}, 
    {0.0, 0.0, 2.0}, {0.0, 0.0, -2.0}, {0.0, 2.0, 0.0}, {0.0, -2.0, 0.0}, {2.0, 0.0, 0.0}, {-2.0, 0.0, 0.0}, {-2.0, 2.0, 2.0}, {2.0, 2.0, 2.0}, {2.0, -2.0, 2.0}, {2.0, 2.0, -2.0}, {-2.0, -2.0, 2.0}, {2.0, -2.0, -2.0}, {-2.0, 2.0, -2.0}, {-2.0, -2.0, -2.0}, 
    {0.0, 0.0, 3.0}, {0.0, 0.0, -3.0}, {0.0, 3.0, 0.0}, {0.0, -3.0, 0.0}, {3.0, 0.0, 0.0}, {-3.0, 0.0, 0.0}, {-3.0, 3.0, 3.0}, {3.0, 3.0, 3.0}, {3.0, -3.0, 3.0}, {3.0, 3.0, -3.0}, {-3.0, -3.0, 3.0}, {3.0, -3.0, -3.0}, {-3.0, 3.0, -3.0}, {-3.0, -3.0, -3.0}, 
    {0.0, 0.0, 4.0}, {0.0, 0.0, -4.0}, {0.0, 4.0, 0.0}, {0.0, -4.0, 0.0}, {4.0, 0.0, 0.0}, {-4.0, 0.0, 0.0}, {-4.0, 4.0, 4.0}, {4.0, 4.0, 4.0}, {4.0, -4.0, 4.0}, {4.0, 4.0, -4.0}, {-4.0, -4.0, 4.0}, {4.0, -4.0, -4.0}, {-4.0, 4.0, -4.0}, {-4.0, -4.0, -4.0}, 
    {0.0, 0.0, 5.0}, {0.0, 0.0, -5.0}, {0.0, 5.0, 0.0}, {0.0, -5.0, 0.0}, {5.0, 0.0, 0.0}, {-5.0, 0.0, 0.0}, {-5.0, 5.0, 5.0}, {5.0, 5.0, 5.0}, {5.0, -5.0, 5.0}, {5.0, 5.0, -5.0}, {-5.0, -5.0, 5.0}, {5.0, -5.0, -5.0}, {-5.0, 5.0, -5.0}, {-5.0, -5.0, -5.0} 
} 


new ZPSTUCK 

/************************************************************* 
************************* AMXX PLUGIN ************************* 
**************************************************************/ 


public plugin_init()  
{ 
    /* Register the plugin */ 
     
    register_plugin("[RoD|*] Extra: SandBags", "1.1", "LARP") 
    set_task(0.1,"checkstuck",0,"",0,"b") 
    //g_itemid_bolsas = zp_register_extra_item(g_item_name, g_item_bolsas, ZP_TEAM_HUMAN) 
    
    /* Register the cvars */ 
    ZPSTUCK = register_cvar("zp_pb_stuck","1") 
    pnumplugin = register_cvar("zp_pb_enable","1"); // 1 = ON ; 0 = OFF 
    remove_nrnd = register_cvar("zp_pb_remround","1"); 
    maxpallets = register_cvar("zp_pb_limit","1"); // max number of pallets with bags 
    phealth = register_cvar("zp_pb_health","600"); // set the health to a pallet with bags 
     
    /* Game Events */ 
    register_event("HLTV","event_newround", "a","1=0", "2=0"); // it's called every on new round 
     
    /* This is for menuz: */ 
    register_menucmd(register_menuid("\ySand Bags:"), 1023, "menu_command" ); 
    register_clcmd("say /sb","show_the_menu"); 
    register_clcmd("say_team /sb","show_the_menu"); 
      
    //RegisterHam(Ham_TakeDamage,"func_wall","fw_TakeDamage");  
    //cvar[0] = register_cvar("zp_autounstuck","1") 
    cvar[1] = register_cvar("zp_pb_stuckeffects","1") 
    cvar[2] = register_cvar("zp_pb_stuckwait","7") 
    
    for (new i; i < sizeof g_szEntClassNamesSpawn; i++)
    {
        RegisterHam(Ham_TakeDamage, g_szEntClassNamesSpawn[i], "fwHamTakeDamageEntPre")
        RegisterHam(Ham_TakeDamage, g_szEntClassNamesSpawn[i], "fwHamTakeDamageEntPost", 1)
    }
    
    RegisterHam(Ham_TakeDamage,"func_wall","fw_TakeDamage"); 

     
} 
//Here is what I am tryin to make just owner and zombie to be able to destroy sandbags 
public fw_TakeDamage(victim, inflictor, attacker, Float:damage, damage_type) 
{ 
    //Victim is not lasermine. 
    new sz_classname[32] 
    entity_get_string( victim , EV_SZ_classname , sz_classname, 31 ) 
    if( !equali(sz_classname,"amxx_pallets") ) 
        return HAM_IGNORED; 
     
    //Attacker is zombie 
    if( zp_get_user_zombie( attacker ) )  
        return HAM_IGNORED; 
     
    //Block Damage 
    return HAM_SUPERCEDE; 
} 

public plugin_precache() 
{ 
    register_forward(FM_Spawn, "fwFmSpawnEntPost", 1);
    for(new i;i < sizeof g_models;i++) 
        engfunc(EngFunc_PrecacheModel,g_models[i]); 
}

public show_the_menu(id,level,cid) 
{ 

    // check if the plugin cvar is turned off 
    if( ! get_pcvar_num( pnumplugin ) ) 
        return PLUGIN_HANDLED; 
         
         
    // check if user isn't alive 
    if( ! is_user_alive( id ) ) 
    { 
        client_print( id, print_chat, "" ); //msg muerto 
        return PLUGIN_HANDLED; 
    } 
             
    if ( !zp_get_user_zombie(id) ) 
    {         
        new szMenuBody[256]; 
        new keys; 
         
        new nLen = format( szMenuBody, 255, "\ySand Bags:^n" ); 
        nLen += format( szMenuBody[nLen], 255-nLen, "^n\w1. Place a Sandbags" ); 
        //nLen += format( szMenuBody[nLen], 255-nLen, "^n\w2. Remove a pallet with bags" ); 
        nLen += format( szMenuBody[nLen], 255-nLen, "^n^n\w0. Exit" ); 

        keys = (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<9) 

        show_menu( id, keys, szMenuBody, -1 ); 

        // depends what you want, if is continue will appear on chat what the admin sayd 
        return PLUGIN_HANDLED; 
    } 
    client_print(id, print_chat, "[ZP] The zombies can not use this command!") 
    return PLUGIN_HANDLED; 
} 


public menu_command(id,key,level,cid) 
{ 
     
    switch( key ) 
    { 
        // place a pallet with bags 
        case 0:  
        { 
            if ( !zp_get_user_zombie(id) ) 
            { 
                new money = g_bolsas[id] 
                if ( money < 1 ) 
                { 
                    client_print(id, print_chat, "[ZP] You do not have to place sandbags!") 
                    return PLUGIN_CONTINUE 
                } 
                g_bolsas[id]-= 1 
                place_palletwbags(id); 
                show_the_menu(id,level,cid); 
                return PLUGIN_CONTINUE     
            } 
            client_print(id, print_chat, "[ZP] The zombies can not use this!!") 
            return PLUGIN_CONTINUE     
        } 
         
             
    } 
     
    return PLUGIN_HANDLED; 
} 



public place_palletwbags(id) 
{ 
     
    // create a new entity  
    new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_wall")); 
     
     
    // set a name to the entity 
    set_pev(ent,pev_classname,"amxx_pallets"); 

     
    // set model         
    engfunc(EngFunc_SetModel,ent,g_models[random(sizeof g_models)]); 
     
    // register a new var. for origin 
    static Float:xorigin[3]; 
    get_user_hitpoint(id,xorigin); 
     
     
    // check if user is aiming at the air  
    if(engfunc(EngFunc_PointContents,xorigin) == CONTENTS_SKY) 
    { 
        client_print(id,print_chat,"[ZP] You can not put sandbags in the sky!"); 
        return PLUGIN_HANDLED; 
    } 
     
     
    // set sizes 
    static Float:p_mins[3], Float:p_maxs[3]; 
    p_mins = PALLET_MINS; 
    p_maxs = PALLET_MAXS; 
    engfunc(EngFunc_SetSize, ent, p_mins, p_maxs); 
    set_pev(ent, pev_mins, p_mins); 
    set_pev(ent, pev_maxs, p_maxs ); 
    set_pev(ent, pev_absmin, p_mins); 
    set_pev(ent, pev_absmax, p_maxs ); 

     
    // set the rock of origin where is user placed 
    engfunc(EngFunc_SetOrigin, ent, xorigin); 
     
     
    // make the rock solid 
    set_pev(ent,pev_solid,SOLID_BBOX); // touch on edge, block 
     
    // set the movetype 
    set_pev(ent,pev_movetype,MOVETYPE_FLY); // no gravity, but still collides with stuff 
     
    // now the damage stuff, to set to take it or no 
    // if you set the cvar "pallets_wbags_health" 0, you can't destroy a pallet with bags 
    // else, if you want to make it destroyable, just set the health > 0 and will be 
    // destroyable. 
    new Float:p_cvar_health = get_pcvar_float(phealth); 
    switch(p_cvar_health) 
    { 
        case 0.0 : 
        { 
        set_pev(ent,pev_takedamage,DAMAGE_NO); 
        } 
         
        default : 
        { 
        set_pev(ent,pev_health,p_cvar_health); 
        set_pev(ent,pev_takedamage,DAMAGE_YES); 
        } 
    } 
     
             
    static Float:rvec[3]; 
    pev(id,pev_v_angle,rvec); 
         
    rvec[0] = 0.0; 
         
    set_pev(ent,pev_angles,rvec); 
         
    // drop entity to floor 
    fm_drop_to_floor(ent); 
    
    set_pev(ent, pev_owner, id);
         
    // num .. 
    palletscout++; 
         
    // confirm message 
    client_print(id, print_chat, "[ZP] You have placed a Sandbags, you have %i remaining", g_bolsas[id]) 
        
    return PLUGIN_HANDLED; 
} 
     
/* ==================================================== 
get_user_hitpoin stock . Was maked by P34nut, and is  
like get_user_aiming but is with floats and better :o 
====================================================*/     
stock get_user_hitpoint(id, Float:hOrigin[3])  
{ 
    if ( ! is_user_alive( id )) 
        return 0; 
     
    new Float:fOrigin[3], Float:fvAngle[3], Float:fvOffset[3], Float:fvOrigin[3], Float:feOrigin[3]; 
    new Float:fTemp[3]; 
     
    pev(id, pev_origin, fOrigin); 
    pev(id, pev_v_angle, fvAngle); 
    pev(id, pev_view_ofs, fvOffset); 
     
    xs_vec_add(fOrigin, fvOffset, fvOrigin); 
     
    engfunc(EngFunc_AngleVectors, fvAngle, feOrigin, fTemp, fTemp); 
     
    xs_vec_mul_scalar(feOrigin, 9999.9, feOrigin); 
    xs_vec_add(fvOrigin, feOrigin, feOrigin); 
     
    engfunc(EngFunc_TraceLine, fvOrigin, feOrigin, 0, id); 
    global_get(glb_trace_endpos, hOrigin); 
     
    return 1; 
}  

public event_newround()
{
    if( get_pcvar_num ( remove_nrnd ) == 1)
        remove_allpalletswbags();
      
    for ( new id; id <= 32; id++) dar_sandbag(id);
}


/* ==================================================== 
This is a stock to help for remove all pallets with 
bags placed . Is called on new round if the cvar 
"pallets_wbags_nroundrem" is set 1. 
====================================================*/ 
stock remove_allpalletswbags() 
{ 
    new pallets = -1; 
    while((pallets = fm_find_ent_by_class(pallets, "amxx_pallets"))) 
        remove_entity(pallets); 
         
    palletscout = 0; 
} 

public checkstuck() { 
    if ( get_pcvar_num(ZPSTUCK) == 1 ) 
    { 
        static players[32], pnum, player 
        get_players(players, pnum) 
        static Float:origin[3] 
        static Float:mins[3], hull 
        static Float:vec[3] 
        static o,i 
        
        for(i=0; i<pnum; i++){ 
            player = players[i] 
            
            if (is_user_connected(player) && is_user_alive(player)) { 
                pev(player, pev_origin, origin) 
                hull = pev(player, pev_flags) & FL_DUCKING ? HULL_HEAD : HULL_HUMAN 
                
                if (!is_hull_vacant(origin, hull,player) && !fm_get_user_noclip(player) && !(pev(player,pev_solid) & SOLID_NOT)) { 
                    ++stuck[player] 
                    
                    if(stuck[player] >= get_pcvar_num(cvar[2])) { 
                        pev(player, pev_mins, mins) 
                        vec[2] = origin[2] 
                            
                        for (o=0; o < sizeof size; ++o) { 
                            vec[0] = origin[0] - mins[0] * size[o][0] 
                            vec[1] = origin[1] - mins[1] * size[o][1] 
                            vec[2] = origin[2] - mins[2] * size[o][2] 
                                
                            if (is_hull_vacant(vec, hull,player)) { 
                                engfunc(EngFunc_SetOrigin, player, vec) 
                                effects(player) 
                                set_pev(player,pev_velocity,{0.0,0.0,0.0}) 
                                o = sizeof size 
                            } 
                        } 
                    } 
                } 
            }
            else 
            { 
                stuck[player] = 0 
            } 
        }    
    } 
} 

stock bool:is_hull_vacant(const Float:origin[3], hull,id) { 
    static tr 
    engfunc(EngFunc_TraceHull, origin, origin, 0, hull, id, tr) 
    if (!get_tr2(tr, TR_StartSolid) || !get_tr2(tr, TR_AllSolid)) //get_tr2(tr, TR_InOpen)) 
        return true 
     
    return false 
} 

public effects(id) { 
    
    if(get_pcvar_num(cvar[1])) { 
        set_hudmessage(255,150,50, -1.0, 0.65, 0, 6.0, 1.5,0.1,0.7) // HUDMESSAGE 
        show_hudmessage(id,"Automatic Unstuck!") // HUDMESSAGE 
        message_begin(MSG_ONE_UNRELIABLE,105,{0,0,0},id )       
        write_short(1<<10)   // fade lasts this long duration 
        write_short(1<<10)   // fade lasts this long hold time 
        write_short(1<<1)   // fade type (in / out) 
        write_byte(20)            // fade red 
        write_byte(255)    // fade green 
        write_byte(255)        // fade blue 
        write_byte(255)    // fade alpha 
        message_end() 
        client_cmd(id,"spk fvox/blip.wav") 
    } 
} 

public dar_sandbag(id) 
{   
    if (!is_user_alive(id))
        return;

    g_bolsas[id]+= 1 
    client_print(id, print_chat, "[ZP] You have %i sandbags, to use type 'say / sb'", g_bolsas[id]) 
}  


ftEntCheckCustom(const iEntID)
{
    new iEntFlags = pev(iEntID, pev_euser4);
    
    if (!(iEntFlags & g_iEnumBitEntDefault) && !(iEntFlags & g_iEnumBitEntCustom))
    {
        static szEntClassname[32];
        pev(iEntID, pev_classname, szEntClassname, charsmax(szEntClassname))
        
/*        ftD7Log(g_szLogFile, _, _, "[ftEntCheckCustom] EntID: %d. Classname: ^"%s^".", iEntID, szEntClassname)
        */
        for (new i; i < sizeof g_szEntClassNames; i++)
            if (equali(szEntClassname, g_szEntClassNames[i]))
            {
                iEntFlags &= ~g_iEnumBitEntDefault;
                iEntFlags |= g_iEnumBitEntCustom;
                
                if (!g_bEntRegistered[i])
                {
                    RegisterHamFromEntity(Ham_Spawn, iEntID, "fwHamSpawnEntPost", 1)
                    RegisterHamFromEntity(Ham_CS_Restart, iEntID, "fwHamRestartEntPost", 1)
                    
                    g_bEntRegistered[i] = true;
                }
                
                break;
            }
            else if (i == sizeof g_szEntClassNames - 1)
            {
                iEntFlags &= ~g_iEnumBitEntCustom;
                iEntFlags |= g_iEnumBitEntDefault;
            }
        
        set_pev(iEntID, pev_euser4, iEntFlags)
    }
    
//    ftD7Log(g_szLogFile, _, _, "[ftEntCheckCustom] EntID: %d. Flags: %d.", iEntID, iEntFlags)
    
    if ((iEntFlags & g_iEnumBitEntCustom) && !(iEntFlags & g_iEnumBitEntRendered))
/*        i = pev(iEntID, pev_rendermode);
        
        if ((i == kRenderNormal || i == kRenderTransTexture) && pev(iEntID, pev_renderfx) == kRenderFxNone)
        {
        
        }
        */
        ftSetRender(iEntID)
    
    return iEntFlags;
}

public fwHamSpawnEntPost(const iEntID)
{
    if (ftEntCheckCustom(iEntID) & g_iEnumBitEntDefault/* || ftEntCheckMaxHP(iEntID) <= 0.0*/)
        return;
    
    static szEntClassname[32];
    pev(iEntID, pev_classname, szEntClassname, charsmax(szEntClassname))
    
//    ftD7Log(g_szLogFile, _, _, "[Ham_Spawn] EntID: %d. Classname: ^"%s^".", iEntID, szEntClassname)
    
    set_pev(iEntID, pev_rendercolor, { 0.0, 255.0, 0.0 })
}

public fwHamRestartEntPost(const iEntID)
{
    if (ftEntCheckCustom(iEntID) & g_iEnumBitEntDefault/* || ftEntCheckMaxHP(iEntID) <= 0.0*/)
        return;
    
    static szEntClassname[32];
    pev(iEntID, pev_classname, szEntClassname, charsmax(szEntClassname))
    
//    ftD7Log(g_szLogFile, _, _, "[Ham_CS_Restart] EntID: %d. Classname: ^"%s^".", iEntID, szEntClassname)
    
    set_pev(iEntID, pev_rendercolor, { 0.0, 255.0, 0.0 })
}

ftSetRender(const iEntID)
{
    static szEntInfo[2];
    
    pev(iEntID, pev_model, szEntInfo, charsmax(szEntInfo))
    
    szEntInfo[1] = pev(iEntID, pev_euser4);
    
    // If the first character of the entity model is '*',
    // then it's a brush(non-studio) model
    if (szEntInfo[0] == '*')
    {
//        ftD7Log(g_szLogFile, _, _, "[ftSetRender] EntID: %d. Initializing render for brush model.", iEntID)
//        
        szEntInfo[1] &= ~g_iEnumBitEntMdlStudio;
        szEntInfo[1] |= g_iEnumBitEntMdlBrush;
        
        set_pev(iEntID, pev_rendermode, kRenderTransColor);
        set_pev(iEntID, pev_renderamt, 128.0)
    }
    else
    {
        szEntInfo[1] &= ~g_iEnumBitEntMdlBrush;
        szEntInfo[1] |= g_iEnumBitEntMdlStudio;
        
        new Float:fEntRenderAmt;
        pev(iEntID, pev_renderamt, fEntRenderAmt)
        
//        ftD7Log(g_szLogFile, _, _, "[ftSetRender] EntID: %d. Initializing render for studio model. Renderamt: %f.", iEntID, fEntRenderAmt)
        
        set_pev(iEntID, pev_renderfx, kRenderFxGlowShell)
        
        if (fEntRenderAmt == 0.0)
            set_pev(iEntID, pev_renderamt, 5.0)
    }
    
    szEntInfo[1] |= g_iEnumBitEntRendered;
    
    set_pev(iEntID, pev_euser4, szEntInfo[1])
}

Float:ftEntCheckMaxHP(const iEntID)
{
    new Float:fHealth;
    pev(iEntID, pev_max_health, fHealth)
    
//    ftD7Log(g_szLogFile, _, _, "[ftEntCheckMaxHP] MaxHP: %f.", fHealth)
    
    if (fHealth != 0.0)
        return fHealth;
    
    pev(iEntID, pev_health, fHealth)
    
//    ftD7Log(g_szLogFile, _, _, "[ftEntCheckMaxHP] HP: %f.", fHealth)
    
    if (fHealth <= 0.0)
        return fHealth;
    
    set_pev(iEntID, pev_max_health, fHealth)
    
    return fHealth;
}

public fwFmSpawnEntPost(const iEntID)
{
    if (!pev_valid(iEntID))
        return;
    
//    ftD7Log(g_szLogFile, _, _, "[FM_Spawn] EntID: %d.", iEntID)
    
    if (ftEntCheckCustom(iEntID) & g_iEnumBitEntDefault || ftEntCheckMaxHP(iEntID) <= 0.0)
        return;
    
    set_pev(iEntID, pev_rendercolor, { 0.0, 255.0, 0.0 })
}

public fwHamTakeDamageEntPre(const iEntID, const iInflictorID, const iAttackerID, const Float:fDamage, const iDamageType)
{
//    ftD7Log(g_szLogFile, _, _, "[Ham_TakeDamage Pre] EntID: %d.", iEntID)
    
    if (!ftEntCheckCustom(iEntID))
        return;
    
    ftEntCheckMaxHP(iEntID)
}

public fwHamTakeDamageEntPost(const iEntID, const iInflictorID, const iAttackerID, const Float:fDamage, const iDamageType)
{
/*    if (pev(iEntID, pev_takedamage) == DAMAGE_NO)
        return;
    */
//    ftD7Log(g_szLogFile, _, _, "[Ham_TakeDamage Post] EntID: %d.", iEntID)
    
    if (!ftEntCheckCustom(iEntID))
        return;
    
    new Float:fHealth;
    pev(iEntID, pev_health, fHealth)
    
//    ftD7Log(g_szLogFile, _, _, "[Ham_TakeDamage Post] HP: %f.", fHealth)
    
    if (fHealth <= 0.0)
    {
        set_pev(iEntID, pev_euser4, 0)
        
        return;
    }
    
    new Float:fHealthMax;
    pev(iEntID, pev_max_health, fHealthMax)
    
//    ftD7Log(g_szLogFile, _, _, "[Ham_TakeDamage Post] MaxHP: %f.", fHealthMax)
    
    // Entity didn't take damage
    if (fHealth == fHealthMax)
        return;
    
    ComputeColor(iEntID, fHealth * 100.0 / fHealthMax)
}

ComputeColor(const iEntID, const Float:fPercentage)
{
    if (fPercentage < 0.0)
        return;
    
    static Float:fColorAmounts[3];
    
    fColorAmounts[1] = 255.0 * fPercentage / 100.0; // green
    fColorAmounts[0] = 255.0 - fColorAmounts[1]; // red
    fColorAmounts[2] = 0.0; // blue
    
//    ftD7Log(g_szLogFile, _, _, "[ComputeColor] EntID: %d. Percentage: %.2f. Red: %f. Green: %f.", iEntID, fPercentage, fColorAmounts[0], fColorAmounts[1])
    
    set_pev(iEntID, pev_rendercolor, fColorAmounts)
/*    
    if (pev(iEntID, pev_euser4) & g_iEnumBitEntMdlStudio)
        set_pev(iEntID, pev_renderamt, fColorAmounts[1])*/
} 