#include <amxmodx> 
#include <amxmisc>
#include <fakemeta> 
#include <hamsandwich> 
#include <xs> 
#include <engine>
#include <zombieplague>
#include <print_center_fx>

#pragma semicolon 1

#define TIEMPO 15

#define OBERON_CLASSNAME "oberon" 
#define OBERON_HEALTH 30000.0

#define TASK_HOOKINGUP 123312312 
#define TASK_HOOKINGDOWN 123312313 

new const oberon_model[] = "models/oberon/zbs_bossl_big02.mdl"; 
new const oberon_knife_effect[] = "models/oberon/ef_knife.mdl"; 
new const oberon_hole_effect[] = "models/oberon/ef_hole.mdl"; 
new const oberon_bomb_model[] = "models/oberon/zbs_bossl_big02_bomb.mdl"; 

new const oberon_appear_sound[] = "oberon/appear.wav"; 
new const oberon_death_sound[] = "oberon/death.wav"; 
new const oberon_evolution_sound[] = "oberon/knife.wav";

new const oberon_attack_sound[8][] =  
{ 
	"oberon/attack1.wav", 
	"oberon/attack2.wav", 
	"oberon/attack3_jump.wav", 
	"oberon/attack3.wav", 
	"oberon/knife_attack1.wav", 
	"oberon/knife_attack2.wav", 
	"oberon/knife_attack3_jump.wav", 
	"oberon/knife_attack3.wav" 
};

new const oberon_hole_sound[] = "oberon/hole.wav"; 
new const oberon_bomb_sound[] = "oberon/attack_bomb.wav"; 

new oberon_model_id, g_reg, m_iBlood[2], exp_spr_id, g_IdEnt;
new Float:g_cur_origin[3], Float:g_cur_angles[3];
new g_doing_other, g_attacking3, Float:g_attacking3_origin[3]; 

new g_szPath[ 256 ];
new g_szMap[ 90 ]; 
new g_szRuta[ 300 ]; 
new g_iSaved = 0;
new g_bCargado = false, g_bTocado = false;
new g_iTiempo;

public plugin_init() 
{ 
	g_iSaved = 0;
	g_bCargado = false;
	g_bTocado = false;

	register_plugin( "[NG OBERON-NPC] Oberon", "1.0", "Dias" ); 

	register_think( OBERON_CLASSNAME, "fw_think" );
	register_touch( OBERON_CLASSNAME, "player", "fw_touch" ); 
	register_touch( "trigger_multiple", "player", "funcion_touch" ); 
	
	register_event( "HLTV", "event_RoundStart", "a", "1=0", "2=0" );
	
	register_clcmd( "say /boss", "f_Menu" );

	register_clcmd("oberon_test", "get_origin");
	register_clcmd("oberon_spawn", "create_oberon");

	get_mapname( g_szMap, charsmax( g_szMap ) );
	get_configsdir( g_szPath, charsmax( g_szPath ) );
	formatex( g_szRuta, charsmax( g_szRuta ), "%s/%s_BOSS.ini", g_szPath, g_szMap );

	ReadPos( );
} 

public plugin_precache( ) 
{ 
	oberon_model_id = precache_model( oberon_model ); 
	precache_model( oberon_knife_effect ); 
	precache_model( oberon_hole_effect ); 
	precache_model( oberon_bomb_model ); 
	
	precache_sound( oberon_appear_sound ); 
	precache_sound( oberon_death_sound ); 
	precache_sound( oberon_evolution_sound ); 

	for( new i = 0; i < sizeof(oberon_attack_sound); i++ ) 
		precache_sound( oberon_attack_sound[ i ] ); 
	
	precache_sound( oberon_hole_sound ); 
	precache_sound( oberon_bomb_sound ); 
	
	m_iBlood[0] = precache_model("sprites/blood.spr"); 
	m_iBlood[1] = precache_model("sprites/bloodspray.spr");     
	exp_spr_id = precache_model("sprites/zerogxplode.spr"); 
	
	g_iTiempo = TIEMPO;
} 

public funcion_touch( touched, toucher ) 
{
	new szTarget[ 20 ];
	entity_get_string( touched, EV_SZ_targetname, szTarget, charsmax( szTarget ) );
	
	if( !touched || !is_valid_ent( touched ) || !is_user_alive( toucher ) )
		return PLUGIN_HANDLED;
	
	if( equal( szTarget, "oberon" ) && g_bCargado && !g_bTocado )
	{
		g_bTocado = true;
		set_task( 1.0, "fnConteo", 5678, _, _, "b" );
	}
	return PLUGIN_CONTINUE;
}


public fnConteo( )
{	
	client_print(0, print_center, "..:::> Defend in %i Seconds <:::..", g_iTiempo );
	--g_iTiempo;
	
	if( g_iTiempo <= 0 )
	{
		create_oberon( );
		remove_task( 5678 );
		return;
	}
}
stock remove_entity_by_classname(const classname[])
{
    new ent = -1;
    while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", classname)))
    {
        //if(pev(ent, pev_spawnflags) == 1)
        //changed this line...this will work now
        if(pev(ent, pev_spawnflags) != 1)
        	engfunc(EngFunc_RemoveEntity, ent);
    }
} 
public event_RoundStart() 
{ 
	remove_task( 5678 );
	remove_task(512512);
	//remove_task(oberon+2012);
	g_bTocado = false;
	g_iTiempo = TIEMPO;
	
	remove_entity_by_classname("hole_hook");
	remove_entity_by_classname(OBERON_CLASSNAME); 
	if(task_exists(g_IdEnt+666)) remove_task(g_IdEnt+666);
	remove_task(TASK_HOOKINGDOWN);
	remove_task(TASK_HOOKINGUP);

	set_cvar_num("mp_roundtime", 7);

	server_cmd("zp_mutilador_enable 0");
	server_cmd("zp_alien_enabled 0");
	server_cmd("zp_ninja_enabled 0");
	server_cmd("zp_sirio_enabled 0");
	server_cmd("zp_sniper_enabled 0");

	server_cmd("zp_wesker_enabled 0");
	server_cmd("zp_surv_enabled 0");
} 
public f_Menu( id )
{
	if( ~get_user_flags( id ) & ADMIN_RCON || g_iSaved > 0 )
	return PLUGIN_HANDLED;
	
	new menu = menu_create( "Registrar BOSS","hn_poner" );
	
	menu_additem( menu, "Registrar Zona" );
	menu_additem( menu, "Guardar Zona" );
	
	menu_display( id, menu );
	return PLUGIN_HANDLED;
}

public hn_poner( id, menu, item )
{
	if ( item == MENU_EXIT || ~get_user_flags( id ) & ADMIN_RCON || g_iSaved > 0 )
	{
		menu_destroy( menu );
		return PLUGIN_HANDLED;
	}
	switch( item )
	{
		case 0: get_origin( id );
		case 1: SaveEnt( g_cur_origin, g_cur_angles );
	}
	f_Menu( id );
	return PLUGIN_HANDLED;  
} 
SaveEnt( Float:Origin[ 3 ], Float:Angles[ 3 ] )
{
	new iCoordenada[ 100 ]; 
	formatex( iCoordenada, charsmax( iCoordenada ),  "%.1f %.1f %.1f %.1f %.1f %.1f", Origin[ 0 ], Origin[ 1 ], Origin[ 2 ], Angles[ 0 ], Angles[ 1 ], Angles[ 2 ]);
	new szText[ 800 ];
	
	if( !file_exists( g_szRuta ) ) 
	{
		log_amx("Archivo '%s' No existe, pero lo creamos.", g_szRuta );
		write_file( g_szRuta, "; Archivo creado automaticamente" );
		formatex( szText, charsmax(szText), "; El mapa es %s:", g_szMap ); 
		write_file( g_szRuta, szText );
		write_file( g_szRuta, "; Las Coordenadas son:" );
		write_file( g_szRuta, "; --------------------------------" );
	}
	write_file( g_szRuta, iCoordenada );
}
public get_origin(id) 
{ 
	pev(id, pev_origin, g_cur_origin);
	pev(id, pev_angles, g_cur_angles); 
	
	client_print(id, print_chat, "[NG OBERON-NPC] El oberon nacera aqui!!!"); 
} 

public create_oberon() 
{
	new ent = create_entity("info_target"); 
	
	entity_set_origin(ent, g_cur_origin); 
	entity_set_vector(ent, EV_VEC_angles, g_cur_angles); 
	
	entity_set_float(ent, EV_FL_takedamage, 1.0); 
	entity_set_float(ent, EV_FL_health, OBERON_HEALTH + 1000.0); 
	
	entity_set_string(ent,EV_SZ_classname, OBERON_CLASSNAME); 
	entity_set_model(ent, oberon_model); 
	entity_set_int(ent, EV_INT_solid, SOLID_SLIDEBOX); 
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_PUSHSTEP); 
	entity_set_float(ent, EV_FL_friction, 1.0);
	entity_set_float(ent, EV_FL_animtime, 2.0);
	entity_set_float(ent, EV_FL_framerate, 1.0);
	entity_set_float(ent, EV_VEC_velocity, 450.0);//speed
	entity_set_float(ent, EV_FL_maxspeed, 500.0);//max speed

	entity_set_int(ent, EV_INT_flags, FL_MONSTER|FL_MONSTERCLIP);
	entity_set_int(ent, EV_INT_fixangle, 1);
	
	new Float:maxs[3] = {100.0, 100.0, 100.0} ;
	new Float:mins[3] = {-100.0, -100.0, -30.0} ;
	entity_set_size(ent, mins, maxs); 
	entity_set_int(ent, EV_INT_modelindex, oberon_model_id); 
	
	set_entity_anim(ent, 1); 
	
	set_pev(ent, pev_iuser4, 0); 
	
	entity_set_float(ent, EV_FL_nextthink, halflife_time() + 0.01);

	if(task_exists(g_IdEnt+666)) remove_task(g_IdEnt+666);

	set_task(18.0, "do_random_skill", ent+666, _, _, "b"); 
	
	if(!g_reg) 
	{ 
		RegisterHamFromEntity(Ham_TakeDamage, ent, "fw_takedmg", 1); 
		g_reg = 1; 
	}     

	g_IdEnt = ent;
	
	g_doing_other = 0; 
	
	drop_to_floor(ent); 
	emit_sound(ent, CHAN_BODY, oberon_appear_sound, 1.0, ATTN_NORM, 0, PITCH_NORM) ;
	return PLUGIN_HANDLED;
}
 
public fw_think(ent) 
{ 
	if(!is_valid_ent(ent))
		return PLUGIN_CONTINUE;

	if(pev(ent, pev_iuser4) == 1)
		return PLUGIN_CONTINUE;

	if(g_doing_other)
		return PLUGIN_CONTINUE;
        
	static victim; 
	static Float:Origin[3], Float:VicOrigin[3], Float:distance; 
	
	victim = FindClosesEnemy(ent); 
	pev(ent, pev_origin, Origin); 
	pev(victim, pev_origin, VicOrigin); 
	
	distance = get_distance_f(Origin, VicOrigin); 
	
	if(is_user_alive(victim) && zp_get_class(victim) < ZOMBIE) 
	{ 
		if(distance <= 300.0) 
		{ 
			if(!is_valid_ent(ent)) 
				return PLUGIN_CONTINUE; 

			//client_print(0, print_center, "think");    
			
			new Float:Ent_Origin[3], Float:Vic_Origin[3]; 
			
			pev(ent, pev_origin, Ent_Origin); 
			pev(victim, pev_origin, Vic_Origin);             
			
			npc_turntotarget(ent, Ent_Origin, victim, Vic_Origin); 
			
			if( random_num( 1, 2 )  == 1 ) 
			{ 
				set_entity_anim(ent, 14); //atacke garra
				entity_set_aim(ent, victim); 
				emit_sound(ent, CHAN_BODY, oberon_attack_sound[4], 1.0, ATTN_NORM, 0, PITCH_NORM); 
				
				set_task(1.0, "do_takedmg", ent);//baja hp a la gente en su rango
				
				entity_set_float(ent, EV_FL_nextthink, get_gametime() + 1.0); 
			} 
			else 
			{ 
				set_entity_anim(ent, 15);  //atacke garra2
				entity_set_aim(ent, victim);    
				emit_sound(ent, CHAN_BODY, oberon_attack_sound[5], 1.0, ATTN_NORM, 0, PITCH_NORM); 
				
				set_task(0.5, "do_takedmg", ent); //baja hp a la gente en su rango           
				
				entity_set_float(ent, EV_FL_nextthink, get_gametime() + 0.01); 
			} 
		} 
		else //esta caminando
		{ 
			static moving_anim; 
			moving_anim = 13; 
			       
			if(pev(ent, pev_sequence) != moving_anim) 
			{ 
				entity_set_float(ent, EV_FL_animtime, get_gametime()); 
				entity_set_float(ent, EV_FL_framerate, 1.0); 
				entity_set_int(ent, EV_INT_sequence, moving_anim); 
			} 
			
			new Float:Ent_Origin[3], Float:Vic_Origin[3];  
			
			pev(ent, pev_origin, Ent_Origin);  
			pev(victim, pev_origin, Vic_Origin);  
			
			npc_turntotarget(ent, Ent_Origin, victim, Vic_Origin);  
			hook_ent(ent, victim, 490.0);  
			
			entity_set_float(ent, EV_FL_nextthink, get_gametime() + 0.2);  
		} 
	} 
	else 
	{ 
		if(pev(ent, pev_sequence) != 12) 
			set_entity_anim(ent, 12);      
		
		entity_set_float(ent, EV_FL_nextthink, get_gametime() + 1.0);  
	}     
	
	return PLUGIN_CONTINUE;  
} 

public do_random_skill(ent) 
{ 
	ent -= 666;

	if(!pev_valid(ent)) 
		return PLUGIN_HANDLED;  

	if(pev(ent, pev_iuser4) == 1)
		return PLUGIN_HANDLED;
	
	if(pev(ent, pev_health) - 1000.0 <= 0.0) 
		return PLUGIN_HANDLED;  
	
	g_doing_other = 1; 
	
	switch( random_num( 0, 100 ) ) 
	{ 
		case 0..37: do_attack3(ent);
		//case 38..68: do_hole(ent);
		case 69..100: do_bomb(ent);      
	}     
	
	return PLUGIN_CONTINUE; 
} 

public do_bomb(oberon) 
{ 
	if(!is_valid_ent(oberon))
		return;

	g_doing_other = 1 ;
	
	set_entity_anim(oberon, 18); 
	
	set_task(3.0, "do_skill_bomb", oberon+2015/*, _, _, "b"*/); 
	set_task(10.0, "stop_skill_bomb", oberon); 
} 

public stop_skill_bomb(oberon) 
{ 
	if(!is_valid_ent(oberon))
		return;

	remove_task(oberon+2015); 
	
	set_entity_anim(oberon, 12); 
	entity_set_float(oberon, EV_FL_nextthink, halflife_time() + 0.01);
	set_task(2.0, "reset_think", oberon); 
} 

public do_skill_bomb(oberon) 
{ 
	oberon -= 2015;

	if(!is_valid_ent(oberon))
		return;

	static Float:StartOrigin[3], Float:TempOrigin[6][3], Float:VicOrigin[6][3], Float:Random1; 
	
	pev(oberon, pev_origin, StartOrigin); 
	emit_sound(oberon, CHAN_BODY, oberon_bomb_sound, 1.0, ATTN_NORM, 0, PITCH_NORM); 
	
	// 1st Bomb 
	Random1 = random_float(120.0, 600.0); 
	VicOrigin[0][0] = StartOrigin[0] + Random1; 
	VicOrigin[0][1] = StartOrigin[1]; 
	VicOrigin[0][2] = StartOrigin[2]; 
	
	TempOrigin[0][0] = VicOrigin[0][0] - (Random1 / 2.0); 
	TempOrigin[0][1] = VicOrigin[0][1]; 
	TempOrigin[0][2] = VicOrigin[0][2] + 500.0; 
	
	// 2nd Bomb 
	Random1 = random_float(100.0, 500.0); 
	VicOrigin[1][0] = StartOrigin[0]; 
	VicOrigin[1][1] = StartOrigin[1] + Random1; 
	VicOrigin[1][2] = StartOrigin[2]; 
	
	TempOrigin[1][0] = VicOrigin[1][0]; 
	TempOrigin[1][1] = VicOrigin[1][1] - (Random1 / 2.0); 
	TempOrigin[1][2] = VicOrigin[1][2] + 500.0;     
	
	// 3rd Bomb 
	Random1 = random_float(100.0, 500.0); 
	VicOrigin[2][0] = StartOrigin[0] - Random1; 
	VicOrigin[2][1] = StartOrigin[1]; 
	VicOrigin[2][2] = StartOrigin[2]; 
	
	TempOrigin[2][0] = VicOrigin[2][0] - (Random1 / 2.0); 
	TempOrigin[2][1] = VicOrigin[2][1]; 
	TempOrigin[2][2] = VicOrigin[2][2] + 500.0;     
	
	// 4th Bomb 
	VicOrigin[3][0] = StartOrigin[0]; 
	VicOrigin[3][1] = StartOrigin[1] - Random1; 
	VicOrigin[3][2] = StartOrigin[2]; 
	
	TempOrigin[3][0] = VicOrigin[3][0]; 
	TempOrigin[3][1] = VicOrigin[3][1] - (Random1 / 2.0); 
	TempOrigin[3][2] = VicOrigin[3][2] + 500.0; 
	
	// 5th Bomb 
	VicOrigin[4][0] = StartOrigin[0] + Random1; 
	VicOrigin[4][1] = StartOrigin[1] + Random1; 
	VicOrigin[4][2] = StartOrigin[2]; 
	
	TempOrigin[4][0] = VicOrigin[4][0] - (Random1 / 2.0); 
	TempOrigin[4][1] = VicOrigin[4][1] - (Random1 / 2.0); 
	TempOrigin[4][2] = VicOrigin[4][2] + 500.0; 
	
	// 6th Bomb 
	VicOrigin[5][0] = StartOrigin[0] + Random1; 
	VicOrigin[5][1] = StartOrigin[1] - Random1; 
	VicOrigin[5][2] = StartOrigin[2]; 
	
	TempOrigin[5][0] = VicOrigin[5][0] + (Random1 / 2.0); 
	TempOrigin[5][1] = VicOrigin[5][1] - (Random1 / 2.0); 
	TempOrigin[5][2] = VicOrigin[5][2] + 500.0;     
	
	for(new i = 0; i < 6; i++) 
		make_bomb(StartOrigin, TempOrigin[i], VicOrigin[i]);   
}

public make_bomb(Float:StartOrigin[3], Float:TempOrigin[3], Float:VicOrigin[3]) 
{ 
	new ent = create_entity("info_target"); 

	if(!is_valid_ent(ent))
		return;
	
	StartOrigin[2] += 30.0; 
	
	entity_set_origin(ent, StartOrigin); 
	
	entity_set_string(ent,EV_SZ_classname, "oberon_bomb"); 
	entity_set_model(ent, oberon_bomb_model); 
	entity_set_int(ent, EV_INT_solid, SOLID_NOT); 
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_BOUNCE); 
	
	new Float:maxs[3] = {10.0,10.0,10.0}; 
	new Float:mins[3] = {-10.0,-10.0,-5.0}; 
	entity_set_size(ent, mins, maxs); 
	
	entity_set_float(ent, EV_FL_animtime, get_gametime()); 
	entity_set_float(ent, EV_FL_framerate, 1.0);     
	entity_set_int(ent, EV_INT_sequence, 0);         
	
	static arg[4], arg2[4]; 
	
	arg[0] = ent; 
	arg[1] = floatround(TempOrigin[0]); 
	arg[2] = floatround(TempOrigin[1]); 
	arg[3] = floatround(TempOrigin[2]); 
	
	arg2[0] = ent; 
	arg2[1] = floatround(VicOrigin[0]); 
	arg2[2] = floatround(VicOrigin[1]); 
	arg2[3] = floatround(VicOrigin[2]);     
	
	set_task(0.01, "do_hook_bomb_up", TASK_HOOKINGUP, arg, sizeof(arg), "b"); 
	set_task(1.0, "do_hook_bomb_down", _, arg2, sizeof(arg2)); 
	set_task(2.0, "bomb_explode", ent); 
} 

public bomb_explode(ent) 
{ 
	if(!is_valid_ent(ent))
		return;

	remove_task(TASK_HOOKINGUP); 
	remove_task(TASK_HOOKINGDOWN); 
	
	static Float:Origin[3]; 
	pev(ent, pev_origin, Origin); 
	
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY); 
	write_byte(TE_EXPLOSION); 
	engfunc(EngFunc_WriteCoord, Origin[0]); 
	engfunc(EngFunc_WriteCoord, Origin[1]); 
	engfunc(EngFunc_WriteCoord, Origin[2]); 
	write_short(exp_spr_id);    // sprite index 
	write_byte(20);    // scale in 0.1's 
	write_byte(30);    // framerate 
	write_byte(0);    // flags 
	message_end();     
	
	for(new i = 1; i <= MAX_PLAYERS; i++) 
	{ 
		if(!is_user_alive(i) || zp_get_class(i) >= ZOMBIE)
			continue;

		if(is_valid_ent(ent) && entity_range(i, ent) <= 300.0) 
		{ 
			static Float:Damage; 
			Damage = random_float(10.0, 25.0); 
			
			Damage *= 1.5;
			
			if( Damage >= get_user_health( i ) )
				user_kill( i );
			else
				ExecuteHam(Ham_TakeDamage, i, 0, i, Damage, DMG_BLAST); 

			hit_screen(i); 
		} 
	}     
	
	remove_entity(ent);
} 

public do_hook_bomb_down(arg[4]) 
{ 
	if(!is_valid_ent(arg[0]))
		return;
	remove_task(TASK_HOOKINGUP); 
	set_task(0.01, "do_hook_bomb_down2", TASK_HOOKINGDOWN, arg, sizeof(arg), "b"); 
} 

public do_hook_bomb_down2(arg[4]) 
{ 
	if(!is_valid_ent(arg[0]))
		return;
	static ent, Float:VicOrigin[3]; 
	
	ent = arg[0];
	VicOrigin[0] = float(arg[1]); 
	VicOrigin[1] = float(arg[2]);
	VicOrigin[2] = float(arg[3]);    
	
	hook_ent2(ent, VicOrigin, 600.0); 
} 

public do_hook_bomb_up(arg[4]) 
{ 
	if(!is_valid_ent(arg[0]))
		return;
	static ent, Float:TempOrigin[3]; 
	
	ent = arg[0];
	TempOrigin[0] = float(arg[1]); 
	TempOrigin[1] = float(arg[2]); 
	TempOrigin[2] = float(arg[3]); 
	
	hook_ent2(ent, TempOrigin, 600.0); 
} 

public do_hole(oberon) 
{ 
	if(!is_valid_ent(oberon)) 
		return; 

	remove_task(512512);  

	set_entity_anim(oberon, 19);
	emit_sound(oberon, CHAN_BODY, oberon_hole_sound, 1.0, ATTN_NORM, 0, PITCH_NORM); 
	
	new ent = create_entity("info_target"); 
	
	static Float:Origin[3]; 
	pev(oberon, pev_origin, Origin); 
	
	Origin[2] -= 10.0; 
	
	entity_set_origin(ent, Origin); 
	
	entity_set_string(ent,EV_SZ_classname, "hole_hook"); 
	entity_set_model(ent, oberon_hole_effect); 
	entity_set_int(ent, EV_INT_solid, SOLID_NOT); 
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_NONE); //none
	
	new Float:maxs[3] = {1.0,1.0,1.0}; 
	new Float:mins[3] = {-1.0,-1.0,-1.0}; 
	entity_set_size(ent, mins, maxs); 
	
	entity_set_float(ent, EV_FL_animtime, get_gametime()); 
	entity_set_float(ent, EV_FL_framerate, 1.0);     
	entity_set_int(ent, EV_INT_sequence, 0);     
	
	set_pev(ent, pev_rendermode, kRenderTransAdd); 
	set_pev(ent, pev_renderamt, 255.0);     
	
	drop_to_floor(ent); 
	
	for(new i = 1; i <= MAX_PLAYERS; i++) 
	{ 
		if(!is_user_alive(i) || zp_get_class(i) >= ZOMBIE)
			continue;
			
		if(is_valid_ent(oberon) && entity_range(oberon, i) <= 1000.0) 
		{ 
			static arg[2]; 
			arg[0] = oberon; 
			arg[1] = i; 
			
			remove_task(512512);
			set_task(0.01, "do_hook_player", 512512, arg, sizeof(arg), "b"); 
		} 
	} 
	
	set_task(5.0, "stop_hook", oberon+2012);     
} 

public do_hook_player(arg[2]) 
{ 
	if(!is_valid_ent(arg[0]) || !is_user_alive(arg[1]))
		return;

	static Float:Origin[3], Float:Speed; 
	pev(arg[0], pev_origin, Origin); 
	
	Speed = (1000.0 / entity_range(arg[0], arg[1])) * 75.0; 
	
	hook_ent2(arg[1], Origin, Speed); 
} 

public stop_hook(oberon) 
{ 
	oberon -= 2012; 
	remove_task(oberon+2012);
	if(!is_valid_ent(oberon))
		return;
	
	static ent;
	ent = find_ent_by_class(-1, "hole_hook"); 
	
	remove_entity(ent); 
	remove_task(512512); 
	
	do_takedmg(oberon); 
	entity_set_float(oberon, EV_FL_nextthink, halflife_time() + 0.01);
	set_task(1.0, "reset_think", oberon); 
} 

public do_attack3(ent) 
{ 
	if(!is_valid_ent(ent))
		return;

	g_attacking3 = 1; 
	
	set_entity_anim(ent, 16); 
	
	emit_sound(ent, CHAN_BODY, oberon_attack_sound[6], 1.0, ATTN_NORM, 0, PITCH_NORM); 
	set_task(0.1, "attack3_jump", ent); 
} 

public attack3_jump(ent) 
{ 
	if( !is_valid_ent(ent) ) 
		return PLUGIN_HANDLED;
	
	set_task(0.01, "hookingup", ent+TASK_HOOKINGUP, _, _, "b"); 
	set_task(1.0, "hookingdown", ent+TASK_HOOKINGDOWN);     
	
	static Enemy; 
	Enemy = FindClosesEnemy(ent);     
	
	pev(Enemy, pev_origin, g_attacking3_origin); 
	return PLUGIN_HANDLED;
} 

public hookingup(ent) 
{ 
	ent -= TASK_HOOKINGUP;

	if( !is_valid_ent(ent) ) 
		return PLUGIN_HANDLED;
	
	static Float:Origin[3]; 
	pev(ent, pev_origin, Origin); 
	
	Origin[2] += 600.0; //1k
	
	hook_ent2(ent, Origin, 600.0); 
	
	static Enemy; 
	Enemy = FindClosesEnemy(ent);     
	
	new Float:Ent_Origin[3], Float:Vic_Origin[3]; 
	
	pev(ent, pev_origin, Ent_Origin); 
	pev(Enemy, pev_origin, Vic_Origin); 
	
	npc_turntotarget(ent, Ent_Origin, Enemy, Vic_Origin); 

	remove_task(ent+TASK_HOOKINGUP);   
	return PLUGIN_HANDLED;
} 

public hookingdown(ent) 
{ 
	ent -= TASK_HOOKINGDOWN; 

	if( !is_valid_ent(ent) ) 
		return;
	
	remove_task(ent+TASK_HOOKINGUP); 
	set_task(0.5, "set_func1", ent); 
	
	set_task(0.01, "hookingdown2", ent+TASK_HOOKINGDOWN, _, _, "b"); 
} 

public set_func1(ent) 
{ 
	if(is_valid_ent(ent))
		set_pev(ent, pev_iuser3, 1); 

	entity_set_float(ent, EV_FL_nextthink, halflife_time() + 0.01);
} 

public hookingdown2(ent) 
{ 
	ent -= TASK_HOOKINGDOWN; 
	
	if( !is_valid_ent(ent) ) 
		return PLUGIN_HANDLED;

	remove_task(ent+TASK_HOOKINGDOWN);
	
	static Enemy;
	Enemy = FindClosesEnemy(ent); 
	
	hook_ent2(ent, g_attacking3_origin, 600.0); 
	
	new Float:Ent_Origin[3], Float:Vic_Origin[3]; 
	
	pev(ent, pev_origin, Ent_Origin); 
	pev(Enemy, pev_origin, Vic_Origin); 
	
	npc_turntotarget(ent, Ent_Origin, Enemy, Vic_Origin);
	return PLUGIN_HANDLED;
} 

public fw_touch(ent, touch) 
{ 
	if(!is_valid_ent(ent) || ent != g_IdEnt ) 
		return FMRES_IGNORED; 

	if( pev(ent, pev_iuser4) == 1 ) 
		return FMRES_IGNORED; 
	
	if(g_attacking3 && pev(ent, pev_iuser3) == 1) 
	{ 
		remove_task(ent+TASK_HOOKINGDOWN); 
		
		if(is_user_alive(touch) && zp_get_class(touch) < ZOMBIE) 
			user_kill(touch); 
		
		g_attacking3 = 0 ;
		set_pev(ent, pev_iuser3, 0); 
		
		set_task(0.75, "reset_think", ent); 
		
		for(new i = 1; i <= MAX_PLAYERS; i++) 
		{ 
			if(zp_get_class(i) >= ZOMBIE)
				continue;

			if(is_user_alive(i) && entity_range(ent, i) <= 300.0) 
			{ 
				hit_screen(i); 

				
				static Float:Damage; 
				Damage = random_float(10.0, 25.0) * 1.5; 

				if( Damage >= get_user_health( i ) )
					user_kill( i );
				else
					ExecuteHam(Ham_TakeDamage, i, 0, i, Damage, DMG_BLAST); 
			} 
		}     
		
		emit_sound(ent, CHAN_BODY, oberon_attack_sound[7], 1.0, ATTN_NORM, 0, PITCH_NORM);         
		
		drop_to_floor(ent); 
	} 
	
	return FMRES_HANDLED; 
} 

public do_takedmg(ent2) 
{ 
	if(!is_valid_ent(ent2))
		return;

	new ent = create_entity("info_target"); 
	
	static Float:Origin[3], Float:Angles[3]; 
	pev(ent2, pev_origin, Origin); 
	pev(ent2, pev_angles, Angles); 
	
	entity_set_origin(ent, Origin); 
	entity_set_vector(ent, EV_VEC_angles, Angles); 
	
	entity_set_string(ent,EV_SZ_classname, "knife_effect"); 
	entity_set_model(ent, oberon_knife_effect); 
	entity_set_int(ent, EV_INT_solid, SOLID_NOT); 
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_NONE); //MOVETYPE_NONE
	
	new Float:maxs[3] = {40.0, 40.0, 1.0}; 
	new Float:mins[3] = {-40.0, -40.0, -1.0}; 
	entity_set_size(ent, mins, maxs); 
	
	drop_to_floor(ent); 
	
	set_task(0.5, "remove_knife_effect", ent); 
	
	
	for(new i = 1; i <= MAX_PLAYERS; i++) 
	{ 
		if(zp_get_class(i) >= ZOMBIE)
			continue;

		if(is_user_alive(i) && entity_range(ent2, i) <= 400.0) 
		{ 
			hit_screen(i); 

			//client_print(0, print_center, "garrazo"); 
			
			static Float:Damage; 
			Damage = random_float(7.5, 15.0); 
			
			Damage *= 2.0; 
			
			if( Damage >= get_user_health( i ) )
				user_kill( i );
			else
				ExecuteHam(Ham_TakeDamage, i, 0, i, Damage, DMG_BLAST); 
		} 
	}     
} 

public remove_knife_effect(ent) 
{ 
	if(!is_valid_ent(ent))
		return;

	remove_entity(ent); 
} 


public fw_takedmg(victim, inflictor, attacker, Float:damage, damagebits) 
{ 
	if( pev(victim, pev_health) - 1000.0 > 0.0 && victim == g_IdEnt )
	{
		static Float:Origin[3]; 
		fm_get_aimorigin(attacker, Origin); 

		client_print(attacker, print_center, "Vida Del Oberon: %i", floatround(pev(victim, pev_health) - 1000.0)); 

		create_blood(Origin); 
	}	
	else if( pev(victim, pev_health) - 1000.0 <= 0.0 && victim == g_IdEnt )
	{
		set_pev( victim, pev_iuser4, 1 );
		set_entity_anim(victim, 20); 
		set_task(4.0, "move_entity", victim); 
		entity_set_int(victim, EV_INT_solid, SOLID_NOT); 
		entity_set_float(victim, EV_FL_takedamage, 0.0); 

		emit_sound(victim, CHAN_BODY, oberon_death_sound, 1.0, ATTN_NORM, 0, PITCH_NORM); 

		remove_task( victim+666 );
		remove_task( victim+TASK_HOOKINGUP );
		remove_task( victim+TASK_HOOKINGDOWN );

		fnRemoveENT( );
	}
} 

public move_entity(ent) 
{ 
    static Float:Origin[3] ;
     
    Origin[0] = 4290.0;
    Origin[1] = 4290.0 ;
    Origin[2] = 4290.0 ;
     
    set_pev(ent, pev_origin, Origin) ;
    entity_set_float(ent, EV_FL_nextthink, halflife_time() + 99999999.0) ;
} 


stock set_entity_anim(ent, anim) 
{ 
	if(is_valid_ent(ent))
	{
		entity_set_float(ent, EV_FL_animtime, get_gametime()); 
		entity_set_float(ent, EV_FL_framerate, 1.0); 
		entity_set_int(ent, EV_INT_sequence, anim);   
	}
	  
} 

stock create_blood(const Float:origin[3]) 
{ 
	// Show some blood :) 
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);  
	write_byte(TE_BLOODSPRITE); 
	engfunc(EngFunc_WriteCoord, origin[0]); 
	engfunc(EngFunc_WriteCoord, origin[1]); 
	engfunc(EngFunc_WriteCoord, origin[2]); 
	write_short(m_iBlood[1]); 
	write_short(m_iBlood[0]); 
	write_byte(75); 
	write_byte(5); 
	message_end(); 
} 

stock fm_get_aimorigin(index, Float:origin[3]) 
{ 
	new Float:start[3], Float:view_ofs[3]; 
	pev(index, pev_origin, start); 
	pev(index, pev_view_ofs, view_ofs); 
	xs_vec_add(start, view_ofs, start); 
	
	new Float:dest[3]; 
	pev(index, pev_v_angle, dest); 
	engfunc(EngFunc_MakeVectors, dest); 
	global_get(glb_v_forward, dest); 
	xs_vec_mul_scalar(dest, 9999.0, dest); 
	xs_vec_add(start, dest, dest); 
	
	engfunc(EngFunc_TraceLine, start, dest, 0, index, 0); 
	get_tr2(0, TR_vecEndPos, origin); 
	
	return 1; 
}   

public FindClosesEnemy(entid) 
{ 
	new Float:Dist; 
	new Float:maxdistance=4000.0;
	new indexid=0;     
	for(new i=1; i <= MAX_PLAYERS;i++)
	{ 
		if(is_user_alive(i) && is_valid_ent(i) && can_see_fm(entid, i) && zp_get_class(i) < ZOMBIE) 
		{ 
			Dist = entity_range(entid, i); 
			if(Dist <= maxdistance) 
			{ 
				maxdistance=Dist; 
				indexid=i; 
				
				return indexid; 
			} 
		}     
	}     
	return 0; 
} 

public npc_turntotarget(ent, Float:Ent_Origin[3], target, Float:Vic_Origin[3])  
{ 
	if(target)  
	{ 
		new Float:newAngle[3]; 
		entity_get_vector(ent, EV_VEC_angles, newAngle); 
		new Float:x = Vic_Origin[0] - Ent_Origin[0]; 
		new Float:z = Vic_Origin[1] - Ent_Origin[1]; 
		
		new Float:radians = floatatan(z/x, radian); 
		newAngle[1] = radians * (180 / 3.14); 
		if (Vic_Origin[0] < Ent_Origin[0]) 
			newAngle[1] -= 180.0; 
		
		entity_set_vector(ent, EV_VEC_angles, newAngle); 
	} 
} 

public bool:can_see_fm(entindex1, entindex2) 
{ 
	if (!entindex1 || !entindex2) 
		return false; 
	
	if (pev_valid(entindex1) && pev_valid(entindex1)) 
	{ 
		new flags = pev(entindex1, pev_flags); 
		if (flags & EF_NODRAW || flags & FL_NOTARGET) 
			return false; 
		 
		new Float:lookerOrig[3]; 
		new Float:targetBaseOrig[3]; 
		new Float:targetOrig[3]; 
		new Float:temp[3]; 
		
		pev(entindex1, pev_origin, lookerOrig); 
		pev(entindex1, pev_view_ofs, temp); 
		lookerOrig[0] += temp[0]; 
		lookerOrig[1] += temp[1]; 
		lookerOrig[2] += temp[2]; 
		
		pev(entindex2, pev_origin, targetBaseOrig); 
		pev(entindex2, pev_view_ofs, temp); 
		targetOrig[0] = targetBaseOrig [0] + temp[0]; 
		targetOrig[1] = targetBaseOrig [1] + temp[1]; 
		targetOrig[2] = targetBaseOrig [2] + temp[2]; 
		
		engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0); //  checks the had of seen player 
		if (get_tr2(0, TraceResult:TR_InOpen) && get_tr2(0, TraceResult:TR_InWater)) 
			return false; 
		else  
		{ 
			new Float:flFraction; 
			get_tr2(0, TraceResult:TR_flFraction, flFraction); 
			if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2)) 
				return true; 
			else 
			{ 
				targetOrig[0] = targetBaseOrig [0]; 
				targetOrig[1] = targetBaseOrig [1]; 
				targetOrig[2] = targetBaseOrig [2]; 
				engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0); //  checks the body of seen player 
				get_tr2(0, TraceResult:TR_flFraction, flFraction); 
				if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2)) 
					return true;
				else 
				{ 
					targetOrig[0] = targetBaseOrig [0]; 
					targetOrig[1] = targetBaseOrig [1]; 
					targetOrig[2] = targetBaseOrig [2] - 17.0; 
					engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0); //  checks the legs of seen player 
					get_tr2(0, TraceResult:TR_flFraction, flFraction); 
					if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2)) 
						return true;
				} 
			} 
		} 
	} 
	return false;
} 

public hook_ent(ent, victim, Float:speed) 
{ 
	if(!is_valid_ent(ent))
		return;

	static Float:fl_Velocity[3]; 
	static Float:VicOrigin[3], Float:EntOrigin[3]; 
	
	pev(ent, pev_origin, EntOrigin); 
	pev(victim, pev_origin, VicOrigin); 
	
	static Float:distance_f; 
	distance_f = get_distance_f(EntOrigin, VicOrigin); 
	
	if (distance_f > 60.0) 
	{ 
		new Float:fl_Time = distance_f / speed; 
		
		fl_Velocity[0] = (VicOrigin[0] - EntOrigin[0]) / fl_Time; 
		fl_Velocity[1] = (VicOrigin[1] - EntOrigin[1]) / fl_Time; 
		fl_Velocity[2] = (VicOrigin[2] - EntOrigin[2]) / fl_Time;
	} 
	else 
	{ 
		fl_Velocity[0] = 0.0; 
		fl_Velocity[1] = 0.0; 
		fl_Velocity[2] = 0.0; 
	} 
	
	entity_set_vector(ent, EV_VEC_velocity, fl_Velocity); 
} 

public hook_ent2(ent, Float:VicOrigin[3], Float:speed) 
{ 
	if( !is_valid_ent(ent) ) 
		return PLUGIN_HANDLED;
	
	static Float:fl_Velocity[3]; 
	static Float:EntOrigin[3]; 
	
	pev(ent, pev_origin, EntOrigin); 
	
	static Float:distance_f; 
	distance_f = get_distance_f(EntOrigin, VicOrigin); 
	
	if (distance_f > 60.0) 
	{ 
		new Float:fl_Time = distance_f / speed; 
		
		fl_Velocity[0] = (VicOrigin[0] - EntOrigin[0]) / fl_Time; 
		fl_Velocity[1] = (VicOrigin[1] - EntOrigin[1]) / fl_Time; 
		fl_Velocity[2] = (VicOrigin[2] - EntOrigin[2]) / fl_Time; 
	} 
	else 
	{ 
		fl_Velocity[0] = 0.0; 
		fl_Velocity[1] = 0.0; 
		fl_Velocity[2] = 0.0; 
	} 
	
	entity_set_vector(ent, EV_VEC_velocity, fl_Velocity); 
	entity_set_float(ent, EV_FL_nextthink, halflife_time() + 0.01); 
	return PLUGIN_HANDLED;
} 

public hit_screen(id) 
{ 
	message_begin(MSG_ONE, get_user_msgid("ScreenShake"),{0,0,0}, id); 
	write_short(1<<14);
	write_short(1<<13); 
	write_short(1<<13); 
	message_end();     
} 

public reset_think(ent) 
{ 
	if(!is_valid_ent(ent))
		return;

	g_doing_other = 0;  
	entity_set_float(ent, EV_FL_nextthink, get_gametime() + 0.01);  
} 


public fnRemoveENT()
{
	new iEnt = -1;
    
	while( ( iEnt = find_ent_by_tname( iEnt, "puerta_milf1" ) ) != 0 )
		force_use( iEnt, iEnt );

	iEnt =- 1;
    
	while( ( iEnt = find_ent_by_tname( iEnt, "puerta_milf" ) ) != 0 )
		force_use( iEnt, iEnt );

	client_print_color( 0, print_team_blue, "^x03/***************************************\");
	client_print_color( 0, print_team_blue, "^x03------^x04Los zombies se han liberado^x03------"); 
	client_print_color( 0, print_team_blue, "^x03/***************************************\");
}
public ReadPos( )
{
	if( !file_exists( g_szRuta ) ) 
	{
		log_amx("[ AMXX ] Archivo '%s' NO Existe.", g_szRuta );
		return;
	}
	new szDat[ 40 ], szDat2[ 40 ], szDat3[ 40 ], szDat4[ 40 ], szDat5[ 40 ], szDat6[ 40 ];
	new szLine[ 700 ], iContador = 0;
	
	new file; file = fopen( g_szRuta, "r" );
	while( file && !feof( file ) )
	{
		fgets( file, szLine, charsmax( szLine ) );
		
		if( szLine[ 0 ] == ';' || szLine[ 0 ] == '/' && szLine[ 1 ] == '/' || !szLine[ 0 ] )
			continue;
		
		parse( szLine, szDat, charsmax( szDat ), szDat2, charsmax( szDat2 ), szDat3, charsmax( szDat3 ), szDat4, charsmax( szDat4 ), szDat5, charsmax( szDat5 ), szDat6, charsmax( szDat6 ) );
		
		if( iContador < 1 )
		{
			g_cur_origin[ 0 ] = str_to_float( szDat );
			g_cur_origin[ 1 ] = str_to_float( szDat2 );
			g_cur_origin[ 2 ] = str_to_float( szDat3 );
			
			g_cur_angles[ 0 ] = str_to_float( szDat4 );
			g_cur_angles[ 1 ] = str_to_float( szDat5 );
			g_cur_angles[ 2 ] = str_to_float( szDat6 );
			
			g_bCargado= true;
		}
		++iContador;
	}
	g_iSaved = iContador;
	fclose( file );
}

entity_set_aim(ent, player) 
{
	if(!is_valid_ent(ent))
		return;

	static Float:origin[3], Float:ent_origin[3], Float:angles[3]; 
	entity_get_vector(player, EV_VEC_origin, origin); 
	entity_get_vector(ent, EV_VEC_origin, ent_origin); 
    
	xs_vec_sub(origin, ent_origin, origin); 
	xs_vec_normalize(origin, origin); 

	vector_to_angle(origin, angles); 
    
	angles[0] = 0.0; 
    
	entity_set_vector(ent, EV_VEC_angles, angles); 
	set_velocity(ent, angles); 
}

set_velocity(ent, Float:angles[3]) 
{
	if(!is_valid_ent(ent))
		return;

	static Float: Direction[3]; 
	angle_vector(angles, ANGLEVECTOR_FORWARD, Direction);  
	new Float:f_vAngles[3]; 
	entity_get_vector(ent, EV_VEC_angles, f_vAngles); 
	
	engfunc(EngFunc_WalkMove, ent, f_vAngles[1], 1.0, WALKMOVE_NORMAL);
	xs_vec_mul_scalar(Direction, entity_get_float(ent, EV_FL_speed), Direction); 
	
	entity_set_vector(ent, EV_VEC_velocity, Direction); 
}