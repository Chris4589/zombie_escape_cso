#include <amxmodx>
#include <reapi>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <fun>

#define OBERON_CLASSNAME "oberon"
#define OBERON_HEALTH 100000

#define TASK_HOOKINGUP 123312312
#define TASK_HOOKINGDOWN 123312313

new const g_szModel_Obero[] = "models/oberon/zbs_bossl_big02.mdl";
new const g_szKnife_Oberon[] = "models/oberon/ef_knife.mdl";
new const g_szModel_Efect[] = "models/oberon/ef_hole.mdl";
new const g_szModel_Bomb[] = "models/oberon/zbs_bossl_big02_bomb.mdl";

new const g_szSound_Appear[] = "oberon/appear.wav";
new const g_szSound_Death[] = "oberon/death.wav";
new const g_szSound_evolution[] = "oberon/knife.wav";

new const g_szSound_Attack[8][] = 
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

new const g_szSound_Hole[] = "oberon/hole.wav";
new const g_szSound_Bomb[] = "oberon/attack_bomb.wav";

new modelIndex_oberon, modelIndex_bomb, modelIndex_efect, modelIndex_knife, m_iBlood[ 2 ], id_Spr;
new Float:g_cur_origin[3], Float:g_cur_angles[3], Float:g_cur_v_angle[3], reg = 0, g_iIdEnt;
new g_iEvolution, g_iEvoluting, g_iDoing_Other, g_iAttacking, Float:g_fAttacking_Origin[3];

public plugin_init( )
{
	register_plugin( "[Dias's NPC] Oberon", "1.0", "Dias" );
	
	register_event( "HLTV", "event_round_start", "a", "1=0", "2=0" );

	//register_touch( OBERON_CLASSNAME, "*", "npc_touch" );
	//register_think( OBERON_CLASSNAME, "npc_think" ); 

	register_touch( "trigger_multiple", "player", "funcion_touch" ); 
	
	register_clcmd( "say /origin", "get_origin" );
	register_clcmd( "say /create", "create_oberon" );

	register_clcmd( "say /fly", "ClientCommand_Fly" );
	register_clcmd( "say /open", "fnOpenDoor" );
}

public fnOpenDoor( id )
{
	show_motd(id, "http://divstarproject.com/zombie_escape/gg.html")
	new iEnt = -1;
    
	while( ( iEnt = find_ent_by_tname( iEnt, "puerta_milf1" ) ) != 0 )
		force_use( iEnt, iEnt );

	iEnt =- 1;
    
	while( ( iEnt = find_ent_by_tname( iEnt, "puerta_milf" ) ) != 0 )
		force_use( iEnt, iEnt );

	
	client_print(0 , print_chat, "SE ABRIO LA PUERTA");
}

public ClientCommand_Fly( iId )
{
    if( get_user_flags( iId ) & ADMIN_RCON )
    {
        set_user_noclip( iId, get_user_noclip( iId ) ? 0 : 1 ); 
        set_user_godmode( iId, set_user_godmode( iId ) ? 0 : 1 );
    }
    
    return PLUGIN_HANDLED;
}

public funcion_touch( touched, toucher ) 
{
	new szClass[ 20 ], szTarget[ 20 ];
	entity_get_string( touched, EV_SZ_classname, szClass, charsmax( szClass ) );
	entity_get_string( touched, EV_SZ_targetname, szTarget, charsmax( szTarget ) );
	
	//client_print( 0, print_center, "%s - %s", szClass, szTarget );
}

public plugin_precache()
{
	modelIndex_oberon = precache_model( g_szModel_Obero );
	modelIndex_knife = precache_model( g_szKnife_Oberon );
	modelIndex_efect = precache_model( g_szModel_Efect );
	modelIndex_bomb = precache_model( g_szModel_Bomb );
	
	precache_sound( g_szSound_Appear );
	precache_sound( g_szSound_Death );
	precache_sound( g_szSound_evolution );

	for( new i = 0; i < sizeof(g_szSound_Attack); i++ )
		precache_sound( g_szSound_Attack[ i ] );
	
	precache_sound( g_szSound_Hole );
	precache_sound( g_szSound_Bomb );
	
	m_iBlood[ 0 ] = precache_model( "sprites/blood.spr" );
	m_iBlood[ 1 ] = precache_model( "sprites/bloodspray.spr" );	
	id_Spr = precache_model( "sprites/zerogxplode.spr" );
}

public event_round_start( )
{
	new ent = -1;

	while( ( ent = rg_find_ent_by_class(-1, OBERON_CLASSNAME) ) )
	 	remove_entity( ent );
}

public get_origin(id)
{
	get_entvar(id, var_origin, g_cur_origin);
	get_entvar(id, var_angles, g_cur_angles);
	get_entvar(id, var_v_angle, g_cur_v_angle);
	
	client_print(id, print_chat, "[Dias's NPC] Saved Origin");
}

public create_oberon(id)
{
	new ent = rg_create_entity( "info_target" );

	if(!ent)
		return;
	
	set_entvar( ent, var_origin, g_cur_origin );
	set_entvar( ent, var_angles, g_cur_angles );
	//set_entvar(ent, var_angle, g_cur_v_angle );
	
	set_entvar( ent, var_takedamage, DAMAGE_YES );
	set_entvar( ent, var_health, float(OBERON_HEALTH + 1000) );

	client_print( 0, print_chat, "creio %f", float(OBERON_HEALTH + 1000))
	
	set_entvar( ent, var_classname, OBERON_CLASSNAME );
	set_entvar( ent, var_model, g_szModel_Obero );
	set_entvar( ent, var_solid, SOLID_SLIDEBOX );
	set_entvar( ent, var_movetype, MOVETYPE_STEP );
	
	new Float:maxs[ 3 ] = {100.0, 100.0, 100.0}
	new Float:mins[ 3 ] = {-100.0, -100.0, -30.0}
	new Float:size[ 3 ];

	set_entvar( ent, var_mins, mins );
	set_entvar( ent, var_maxs, maxs );
	math_mins_maxs( maxs, mins, size );
	set_entvar( ent, var_size, size );
	
	set_entvar( ent, var_modelindex, modelIndex_oberon );
	
	set_entity_anim( ent, 1 );
	
	set_entvar( ent, var_iuser4, 0 );
	
	set_entvar( ent, var_nextthink, halflife_time() + 6.0 );
	
	set_task( 5.0, "start_oberon", ent ); 
	set_task( 10.0, "do_random_skill", ent+66666, _, _, "b" );//remover +

	
	if(!reg)
	{
		SetTouch( ent, "npc_touch" );
		SetThink( ent, "npc_think" );
		RegisterHamFromEntity( Ham_TakeDamage, ent, "fw_takedmg", 1 );	
		//RegisterHamFromEntity( Ham_Think, ent, "npc_think" ); 
		reg = 1;
	}
	g_iIdEnt = ent;
	g_iEvolution = 0;
	g_iEvoluting = 0;
	g_iDoing_Other = 0;
	
	drop_to_floor( ent );
	emit_sound( ent, CHAN_BODY, g_szSound_Appear, 1.0, ATTN_NORM, 0, PITCH_NORM );
}

public start_oberon( ent ) 
{ 
	if( !is_valid_ent( ent ) )
		return;

	set_entity_anim( ent, 2 );
} 

public npc_think( ent )
{
	if( !is_entity( ent ) )
		return HAM_IGNORED;

	if( get_entvar( ent, var_iuser4 ) )
		return HAM_IGNORED;
		
	if( g_iEvoluting || g_iDoing_Other )
		return HAM_IGNORED;

	if( ( get_entvar( ent, var_health ) - 1000 ) <= 0 ) 
	{
		set_entvar( ent, var_iuser4, 1 );
		set_entity_anim( ent, 20 );

		static Float:Origin[ 3 ];
	
		Origin[ 0 ] = 4290.0;
		Origin[ 1 ] = 4290.0;
		Origin[ 2 ] = 4290.0;
		
		set_entvar( ent, var_origin, Origin );
		set_entvar( ent, var_nextthink, halflife_time() + 99999999.0 );
		set_entvar( ent, var_solid, SOLID_NOT );
		//set_entvar( ent, var_takedamage, 0.0 );
		
		emit_sound( ent, CHAN_BODY, g_szSound_Death, 1.0, ATTN_NORM, 0, PITCH_NORM );

		remove_task( ent+66666 );

		client_print( 0, print_center, "death npc %f", get_entvar( ent, var_health ) - 1000 );
		
		return HAM_IGNORED;
	}
	if( ( get_entvar( ent, var_health ) - 1000 <= OBERON_HEALTH / 2) && !g_iEvolution )
	{
		set_entity_anim( ent, 11 );
		g_iEvoluting = 1;
		set_entity_anim( ent, 12 );
		
		emit_sound( ent, CHAN_BODY, g_szSound_evolution, 1.0, ATTN_NORM, 0, PITCH_NORM );
		client_print( 0, print_center, "np/2 npc %f", (get_entvar( ent, var_health ) - 1000 <= OBERON_HEALTH / 2) );
		return HAM_IGNORED
	}	

	static victim;
	static Float:Origin[ 3 ], Float:VicOrigin[ 3 ];
	victim = FindClosesEnemy( ent );
	get_entvar( ent, var_origin, Origin );
	get_entvar( victim, var_origin, VicOrigin );
	
	
	if( is_user_alive( victim ) )
	{
		new Float:Ent_Origin[3], Float:Vic_Origin[3];
		if( get_distance_f( Origin, VicOrigin ) <= 250.0 )
		{
			get_entvar( ent, var_origin, Ent_Origin );
			get_entvar( victim, var_origin, Vic_Origin );
		
			npc_turntotarget( ent, Ent_Origin, victim, Vic_Origin );

			static Attack_Type, attack_anim, attack_sound;
			Attack_Type = random_num( 1, 2 );
			
			if( Attack_Type )
			{
				if(g_iEvolution)
				{
					attack_anim = 14;
					attack_sound = 4;
				} 
				else 
				{
					attack_anim = 6;
					attack_sound = 0;
				}
			}
			else
			{
				if(g_iEvolution)
				{
					attack_anim = 15
					attack_sound = 5
				} 
				else 
				{ 
					attack_anim = 7
					attack_sound = 1
				}
			}

			set_entity_anim( ent, attack_anim );
			emit_sound( ent, CHAN_BODY, g_szSound_Attack[attack_sound], 1.0, ATTN_NORM, 0, PITCH_NORM );
			
			set_task( 1.0, "do_takedmg", ent );
				
			set_entvar( ent, var_nextthink, get_gametime() + 3.0 );
		}
		else
		{
			static moving_anim;
			
			if(g_iEvolution)
				moving_anim = 13;
			else 
				moving_anim = 3;	

			if( get_entvar( ent, var_sequence ) != moving_anim )
			{
				set_entvar( ent, var_animtime, get_gametime() );
				set_entvar( ent, var_framerate, 1.0 );
				set_entvar( ent, var_sequence, moving_anim );
			}
				
			get_entvar( ent, var_origin, Ent_Origin );
			get_entvar( victim, var_origin, Vic_Origin );
		
			npc_turntotarget( ent, Ent_Origin, victim, Vic_Origin );

			hook_ent( ent, victim, 100.0 );
			
			set_entvar( ent, var_nextthink, get_gametime() + 0.1 );
		}
	}
	else 
	{
		static idle_anim;
		
		if(g_iEvolution)
			idle_anim = 12;
		else 
			idle_anim = 2;
			
		if( get_entvar( ent, var_sequence ) != idle_anim )
			set_entity_anim( ent, idle_anim );
			
		set_entvar( ent, var_nextthink, get_gametime() + 1.0 );
	}

	return HAM_HANDLED;
}

public do_random_skill( ent )
{
	ent -= 66666;

	if( !is_entity( ent ) )
		return PLUGIN_HANDLED
		
	if( g_iEvoluting )
		return PLUGIN_HANDLED
		
	if( get_entvar( ent, var_health ) - 1000 <= 0 )
	{
		client_print( 0, print_chat, "skill %f", get_entvar( ent, var_health ) - 1000 )
		return PLUGIN_HANDLED
	}
	
	g_iDoing_Other = 1;
	
	switch( random_num( 0, 100 ) )
	{
		case 0..37: 
			do_attack3( ent );
		case 38..72:
			do_hole( ent );
		case 73..100:
			do_bomb( ent );	
	}	
	return PLUGIN_CONTINUE;
}

public do_bomb( oberon )
{
	g_iDoing_Other = 1;
	
	static bomb_anim;
	if(g_iEvolution)
		bomb_anim = 18;
	else
		bomb_anim = 9;
		
	set_entity_anim( oberon, bomb_anim );
	
	set_task( 3.0, "do_skill_bomb", oberon+2015, _, _, "b" );
	set_task( 10.0, "stop_skill_bomb", oberon );
}

public stop_skill_bomb(oberon)
{
	remove_task(oberon+2015);

	if(!is_entity(oberon))
		return;
	
	static idle_anim;
	
	if( g_iEvolution )
		idle_anim = 12;
	else 
		idle_anim = 2;
		
	set_entity_anim( oberon, idle_anim );
	set_task(2.0, "reset_think", oberon) 
	//reset_think( oberon );
}

public do_skill_bomb(oberon)
{
	oberon -= 2015;
	static Float:StartOrigin[ 3 ], Float:TempOrigin[ 6 ][ 3 ], Float:VicOrigin[ 6 ][ 3 ], Float:Random1;
	
	get_entvar( oberon, var_origin, StartOrigin );
	emit_sound( oberon, CHAN_BODY, g_szSound_Bomb, 1.0, ATTN_NORM, 0, PITCH_NORM );
	
	// 1st Bomb
	Random1 = random_float(100.0, 500.0);
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
	TempOrigin[5][2] = VicOrigin[5][2] + 500.0	;
	
	for(new i = 0; i < 6; i++)
		make_bomb(StartOrigin, TempOrigin[i], VicOrigin[i]);
	
}

public make_bomb(Float:StartOrigin[3], Float:TempOrigin[3], Float:VicOrigin[3])
{
	new ent = rg_create_entity("info_target");

	if(!ent)
		return;
	
	StartOrigin[2] += 20.0;
	
	set_entvar(ent, var_origin, StartOrigin);
	
	set_entvar( ent,var_classname, "oberon_bomb" );
	set_entvar( ent, var_model, g_szModel_Bomb );
	set_entvar( ent, var_solid, SOLID_NOT );
	set_entvar( ent, var_movetype, MOVETYPE_BOUNCE );
	set_entvar( ent, var_modelindex, modelIndex_bomb );
	
	new Float:maxs[ 3 ] = {10.0,10.0,10.0};
	new Float:mins[ 3 ] = {-10.0,-10.0,-5.0};
	new Float:size[ 3 ];

	set_entvar( ent, var_mins, mins );
	set_entvar( ent, var_maxs, maxs );
	math_mins_maxs( maxs, mins, size );
	set_entvar( ent, var_size, size );
	
	set_entvar( ent, var_animtime, get_gametime() );
	set_entvar( ent, var_framerate, 1.0 );
	set_entvar( ent, var_sequence, 0 );		
	
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
	remove_task(TASK_HOOKINGUP);
	remove_task(TASK_HOOKINGDOWN);

	if( !is_entity( ent ) )
		return;
	
	static Float:Origin[3];
	get_entvar(ent, var_origin, Origin);
	
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY);
	write_byte(TE_EXPLOSION);
	engfunc(EngFunc_WriteCoord, Origin[0]);
	engfunc(EngFunc_WriteCoord, Origin[1]);
	engfunc(EngFunc_WriteCoord, Origin[2]);
	write_short(id_Spr);	// sprite index
	write_byte(20);	// scale in 0.1's
	write_byte(30);	// framerate
	write_byte(0);	// flags
	message_end();	
	
	for(new i = 1; i <= MAX_PLAYERS; i++)
	{
		if(is_user_alive(i) && entity_range(i, ent) <= 300.0) 
		{
			static Float:Damage;
			Damage = random_float(10.0, 30.0);
			
			if(g_iEvolution) Damage *= 2.0;
				
			ExecuteHam(Ham_TakeDamage, i, 0, i, Damage, DMG_BLAST);//NaN
			hit_screen(i);
		}
	}	
	
	remove_entity( ent );
}

public do_hook_bomb_down(arg[4])
{
	remove_task(TASK_HOOKINGUP);
	set_task(0.01, "do_hook_bomb_down2", TASK_HOOKINGDOWN, arg, sizeof(arg), "b");
}

public do_hook_bomb_down2(arg[4])
{
	static ent, Float:VicOrigin[3];
	
	ent = arg[0];
	VicOrigin[0] = float(arg[1]);
	VicOrigin[1] = float(arg[2]);
	VicOrigin[2] = float(arg[3]);	
	
	hook_ent2(ent, VicOrigin, 500.0);
}

public do_hook_bomb_up(arg[4])
{
	static ent, Float:TempOrigin[3];
	
	ent = arg[0];
	TempOrigin[0] = float(arg[1]);
	TempOrigin[1] = float(arg[2]);
	TempOrigin[2] = float(arg[3]);
	
	hook_ent2(ent, TempOrigin, 500.0);
}

public do_hole(oberon)
{
	static hole_anim;
	
	if(g_iEvolution)
		hole_anim = 19;
	else
		hole_anim = 10;
		
	set_entity_anim( oberon, hole_anim );
	emit_sound( oberon, CHAN_BODY, g_szSound_Hole, 1.0, ATTN_NORM, 0, PITCH_NORM );
	
	new ent = rg_create_entity( "info_target" );

	if(!ent)
		return;
	
	static Float:Origin[3];
	get_entvar( oberon, var_origin, Origin );
	
	Origin[2] -= 10.0;
	
	set_entvar( ent, var_origin, Origin );
	
	set_entvar( ent, var_classname, "hole_hook" );
	set_entvar( ent, var_model, g_szModel_Efect );
	set_entvar( ent, var_solid, SOLID_NOT );
	set_entvar( ent, var_movetype, MOVETYPE_NONE );
	set_entvar( ent, var_modelindex, modelIndex_efect );
	
	new Float:maxs[ 3 ] = {1.0,1.0,1.0};
	new Float:mins[ 3 ] = {-1.0,-1.0,-1.0};
	new Float:size[ 3 ];

	set_entvar( ent, var_mins, mins );
	set_entvar( ent, var_maxs, maxs );
	math_mins_maxs( maxs, mins, size );
	set_entvar( ent, var_size, size );
	
	set_entvar( ent, var_animtime, get_gametime() );
	set_entvar( ent, var_framerate, 1.0 );
	set_entvar( ent, var_sequence, 0 );	
	
	drop_to_floor( ent );
	
	for(new i = 1; i <= MAX_PLAYERS; i++)
	{
		if(is_user_alive(i) && entity_range(oberon, i) <= 1000.0)
		{
			static arg[2];
			arg[0] = oberon;
			arg[1] = i;
			
			set_task(0.01, "do_hook_player", 512512, arg, sizeof(arg), "b");
			//do_hook_player( arg );
		}
	}
	
	set_task(5.0, "stop_hook", oberon+2012)	;
}

public do_hook_player(arg[2])
{
	if(is_user_alive(arg[1]))
		return;

	static Float:Origin[3], Float:Speed;
	get_entvar(arg[0], var_origin, Origin);
	
	Speed = (1000.0 / entity_range(arg[0], arg[1])) * 75.0;
	
	hook_ent2(arg[1], Origin, Speed);
}

public stop_hook( oberon )
{
	oberon -= 2012;
	
	static ent;
	ent = rg_find_ent_by_class( -1, "hole_hook" );
	
	remove_entity( ent );
	remove_task( 512512 );
	
	do_takedmg( oberon );
	//reset_think( oberon );
	set_task(1.0, "reset_think", oberon) 
}

public do_attack3(ent)
{
	static attack3_anim, attack3_sound;
	
	if(g_iEvolution)
	{
		attack3_anim = 16;
		attack3_sound = 6;
	} 
	else 
	{
		attack3_anim = 8;
		attack3_sound = 2;
	}	
	
	g_iAttacking = 1;
	
	set_entity_anim( ent, attack3_anim );
	
	emit_sound( ent, CHAN_BODY, g_szSound_Attack[attack3_sound], 1.0, ATTN_NORM, 0, PITCH_NORM );
	//attack3_jump( ent );
	set_task(0.1, "attack3_jump", ent) 
}

public attack3_jump(ent)
{
	if( !is_entity(ent) ) 
		return;

	set_task(0.01, "hookingup", ent+TASK_HOOKINGUP, _, _, "b");
	set_task(1.0, "hookingdown", ent+TASK_HOOKINGDOWN);	

	static Enemy;
	Enemy = FindClosesEnemy(ent);	
	
	get_entvar(Enemy, var_origin, g_fAttacking_Origin);
}

public hookingup(ent)
{
	ent -= TASK_HOOKINGUP
	if( !is_entity( ent ) )
		return;
	
	static Float:Origin[3]
	get_entvar(ent, var_origin, Origin)
	
	Origin[2] += 1000.0
	
	hook_ent2(ent, Origin, 1000.0)
	
	static Enemy
	Enemy = FindClosesEnemy(ent)	
	
	new Float:Ent_Origin[3], Float:Vic_Origin[3]
	
	get_entvar(ent, var_origin, Ent_Origin)
	get_entvar(Enemy, var_origin, Vic_Origin)
	
	npc_turntotarget(ent, Ent_Origin, Enemy, Vic_Origin)	
}

public hookingdown(ent)
{
	ent -= TASK_HOOKINGDOWN
	if( !is_entity( ent ) )
		return;
	
	remove_task(ent+TASK_HOOKINGUP);
	set_entvar(ent, var_iuser3, 1);
	
	set_task(0.01, "hookingdown2", ent+TASK_HOOKINGDOWN, _, _, "b")
	//hookingdown2(ent);
}

public hookingdown2(ent)
{
	ent -= TASK_HOOKINGDOWN
	if( !is_entity( ent ) )
		return;

	static Enemy
	Enemy = FindClosesEnemy(ent)
	
	hook_ent2(ent, g_fAttacking_Origin, 1000.0)
	
	new Float:Ent_Origin[3], Float:Vic_Origin[3]
	
	get_entvar(ent, var_origin, Ent_Origin)
	get_entvar(Enemy, var_origin, Vic_Origin)
	
	npc_turntotarget(ent, Ent_Origin, Enemy, Vic_Origin)		
}

public npc_touch(ent, touch)
{
	if(!is_entity(ent))
		return FMRES_IGNORED;
		
	if( g_iAttacking && get_entvar( ent, var_iuser3 ) )
	{
		remove_task(ent+TASK_HOOKINGDOWN);
		
		if( is_user_alive( touch ) )
			user_kill(touch);
			
		g_iAttacking = 0;
		set_entvar( ent, var_iuser3, 0 );
		
		//reset_think( ent );
		set_task(0.75, "reset_think", ent) 
		
		for(new i = 1; i <= MAX_PLAYERS; i++)
		{
			if(is_user_alive(i) && entity_range(ent, i) <= 300.0)
			{
				hit_screen( i );
				
				static Float:Damage;
				Damage = random_float(10.0, 25.0);
				
				if(g_iEvolution)
					Damage *= 1.5;
				
				ExecuteHam(Ham_TakeDamage, i, 0, i, Damage, DMG_BLAST);//NaN
			}
		}	
		
		static attack3_sound;
		if(g_iEvolution)
			attack3_sound = 7;
		else
			attack3_sound = 3;
		
		emit_sound(ent, CHAN_BODY, g_szSound_Attack[attack3_sound], 1.0, ATTN_NORM, 0, PITCH_NORM);		
			
		drop_to_floor(ent);
	}
		
	return FMRES_HANDLED
}

public do_takedmg(ent2)
{
	if( !is_entity( ent2 ) )
		return;

	if(g_iEvolution)
	{
		new ent = rg_create_entity( "info_target" );

		if(!ent)
			return;
	
		static Float:Origin[ 3 ], Float:Angles[ 3 ];
		get_entvar( ent2, var_origin, Origin );
		get_entvar( ent2, var_angles, Angles );
		
		set_entvar( ent, var_origin, Origin );
		set_entvar( ent, var_angles, Angles );
		
		set_entvar( ent, var_classname, "knife_effect" );
		set_entvar( ent, var_model, g_szKnife_Oberon );
		set_entvar( ent, var_solid, SOLID_NOT );
		set_entvar( ent, var_movetype, MOVETYPE_NONE );
		set_entvar( ent, var_modelindex, modelIndex_knife );
		new Float:maxs[ 3 ] = {40.0, 40.0, 1.0};
		new Float:mins[ 3 ] = {-40.0, -40.0, -1.0};
		new Float:size[ 3 ];

		set_entvar( ent, var_mins, mins );
		set_entvar( ent, var_maxs, maxs );
		math_mins_maxs( maxs, mins, size );
		set_entvar( ent, var_size, size );
		
		drop_to_floor( ent );
		
		remove_entity( ent );
	}
	
	for(new i = 1; i <= MAX_PLAYERS; i++)
	{
		if(is_user_alive(i) && entity_range(ent2, i) <= 300.0)
		{
			hit_screen(i);
			
			static Float:Damage;
			Damage = random_float(7.5, 15.0);
			
			if(g_iEvolution)
				Damage *= 2.0;
			
			ExecuteHam(Ham_TakeDamage, i, 0, i, Damage, DMG_BLAST);//NaN
		}
	}	
}

public fw_takedmg(victim, inflictor, attacker, Float:damage, damagebits)
{
	if( victim == g_iIdEnt && ( is_user_alive( attacker ) && 1 <= attacker <= MAX_PLAYERS ) )
	{
		static Float:Origin[3];
		fm_get_aimorigin(attacker, Origin);
		
		client_print(attacker, print_center, "Vida restanta: [ %i ]", floatround(get_entvar(victim, var_health) - 1000));
		
		create_blood(Origin);	
	}
	
}

stock set_entity_anim(ent, anim)
{
	if( !is_entity( ent ) )
		return;

	set_entvar(ent, var_animtime, get_gametime());
	set_entvar(ent, var_framerate, 1.0);
	set_entvar(ent, var_sequence, anim)	;
}

stock create_blood(const Float:origin[3])
{
	// Show some blood :)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) ;
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
	get_entvar(index, var_origin, start);
	get_entvar(index, var_view_ofs, view_ofs); 
	xs_vec_add(start, view_ofs, start);
	
	new Float:dest[3];
	get_entvar(index, var_v_angle, dest);
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
	for( new i = 1; i<= MAX_PLAYERS; i++ )
	{
		if(is_user_alive(i) && is_entity(i) && can_see_fm(entid, i))
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
		set_entvar(ent, var_angles, newAngle);
		new Float:x = Vic_Origin[0] - Ent_Origin[0];
		new Float:z = Vic_Origin[1] - Ent_Origin[1];

		new Float:radians = floatatan(z/x, radian);
		newAngle[1] = radians * (180 / 3.14);
		if (Vic_Origin[0] < Ent_Origin[0])
			newAngle[1] -= 180.0;
        
		set_entvar(ent, var_angles, newAngle);
	}
}

public bool:can_see_fm(entindex1, entindex2)
{
	if (!entindex1 || !entindex2)
		return false;

	if ( is_entity(entindex1) && ( 1 <= entindex2 <= MAX_PLAYERS ) )
	{
		new flags = get_entvar(entindex1, var_flags);

		if (flags & EF_NODRAW || flags & FL_NOTARGET)
			return false;
		

		new Float:lookerOrig[3];
		new Float:targetBaseOrig[3];
		new Float:targetOrig[3];
		new Float:temp[3];

		get_entvar(entindex1, var_origin, lookerOrig);
		get_entvar(entindex1, var_view_ofs, temp);
		lookerOrig[0] += temp[0];
		lookerOrig[1] += temp[1];
		lookerOrig[2] += temp[2];

		get_entvar(entindex2, var_origin, targetBaseOrig);
		get_entvar(entindex2, var_view_ofs, temp);
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
	static Float:fl_Velocity[3];
	static Float:VicOrigin[3], Float:EntOrigin[3];

	get_entvar(ent, var_origin, EntOrigin);
	get_entvar(victim, var_origin, VicOrigin);
	
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

	set_entvar(ent, var_velocity, fl_Velocity);
}

public hook_ent2(ent, Float:VicOrigin[3], Float:speed)
{
	if( !is_entity( ent ) )
		return;

	static Float:fl_Velocity[3];
	static Float:EntOrigin[3];

	get_entvar(ent, var_origin, EntOrigin);
	
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

	set_entvar(ent, var_velocity, fl_Velocity)
}

public hit_screen(id)
{
	message_begin(MSG_ONE, get_user_msgid("ScreenShake"),{0,0,0}, id);
	write_short(1<<14);
	write_short(1<<13);
	write_short(1<<13);
	message_end()	;
}

public reset_think( ent )
{
	if( !is_entity( ent ) )
		return;

	g_iDoing_Other = 0;
	set_entvar( ent, var_nextthink, get_gametime() + 0.1 );
}
math_mins_maxs(const Float:mins[3], const Float:maxs[3], Float:size[3])
{
    size[0] = (xs_fsign(mins[0]) * mins[0]) + maxs[0];
    size[1] = (xs_fsign(mins[1]) * mins[1]) + maxs[1];
    size[2] = (xs_fsign(mins[2]) * mins[2]) + maxs[2];
}/*
stock xs_fsign(Float:num)
{
    return (num < 0.0) ? -1 : ((num == 0.0) ? 0 : 1);
}*/