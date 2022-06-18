/*================================================
	Name: Traps
	Description: Catch the humans.
	Author: Dias + Hypnotize
	For: Zombie Escape 1.0b

	CREATE TABLE IF NOT EXISTS zp_traps
	(
		id INT AUTO_INCREMENT PRIMARY KEY,
		Coordenada VARCHAR(80) NOT NULL,
		Map VARCHAR(80) NOT NULL
	);

	select Coordenada from zp_traps where Map = ^"%s^"

================================================*/

#include <amxmodx>
#include <reapi>
#include <sqlx>
#include <engine>
#include <zombieplague>
#include <accsys>

#define is_valid_alive(%0) (1 <= %0 <= MAX_PLAYERS && is_user_alive(%0))

new bool:g_iPlayerTrapped[ 33 ];

new const g_szTrapEnt[ ] = "trap";
new const g_szModelTrap[ ] = "models/zombie_plague/ass_hole.mdl";
new Float:g_cur_origin[3], Float:g_cur_angles[3], currentMap[50];
new Float:g_fTime[ 33 ], Float:gravity[33], Float:Speed[33];

new Float:cvar_trap_time;
new Handle:g_hTuple;
new modelIndex_Trap;

forward zp_speed_reset(id);

enum 
{
	CREATE_TRAP,
	FIND_TRAP
}

public stock g_szPlugin[ ] = "[ ZE ] Traps";
public stock g_szVersion[ ] = "1.0b";
public stock g_szAuthor[ ] = "Dias + Hypnotize";

public plugin_init( )
{
	register_plugin(
        .plugin_name = g_szPlugin, 
        .version = g_szVersion, 
        .author = g_szAuthor
    );

	register_touch( g_szTrapEnt, "player", "fw_touch" );
	
	register_event( "HLTV", "event_round_start", "a", "1=0", "2=0" );
	// RegisterHam(Ham_Player_ResetMaxSpeed, "player", "fw_ResetMaxSpeed_Post", 1)
	RegisterHookChain( RG_CBasePlayer_PreThink, "fw_ResetMaxSpeed_Post", .post = false );

	bind_pcvar_float(
        create_cvar(
            .name = "ze_trap_time",
            .string = "3.0"
        ), cvar_trap_time
	);
	register_clcmd("say /traps", "f_Menu");

	get_mapname(currentMap, charsmax(currentMap));
	MySQL_Init( );
}

public MySQL_Init( )
{
	g_hTuple = advacc_guardado_get_handle( );
	
	if( !g_hTuple ) 
	{
		log_to_file( "SQL_ERROR.txt", "No se pudo conectar con la base de datos." );
		return pause( "a" );
	} else {
		new szQuery[ MAX_MENU_LENGTH ], iData[ 1 ];

		iData[ 0 ] = FIND_TRAP;

		formatex( szQuery, charsmax( szQuery ), "select Coordenada from zp_traps where Map = ^"%s^"",
			currentMap );
		SQL_ThreadQuery( g_hTuple, "DataHandlerTraps", szQuery, iData, 1 );
	}

	return PLUGIN_CONTINUE;
}

public plugin_precache( )
	modelIndex_Trap = precache_model( g_szModelTrap );

public client_putinserver(id)
	g_iPlayerTrapped[ id ] = false;
public event_round_start( ) {
	remove_task(8985122);
	for( new i = 1; i <= MAX_PLAYERS; ++i )
		g_iPlayerTrapped[ i ] = false;
}

public create_trap( Float:Origin[ 3 ], Float:Angles[ 3 ] )
{
	Origin[2] += 45.0;
	Origin[1] += 15.0;
	Origin[0] += 15.0;

	new trap = rg_create_entity( "info_target" );
	set_entvar( trap, var_origin, Origin );
	
	set_entvar( trap, var_takedamage, 0.0 );
	
	set_entvar( trap, var_classname, g_szTrapEnt );
	set_entvar( trap, var_model, g_szModelTrap );
	set_entvar( trap, var_solid, 1 );
	set_entvar( trap, var_modelindex, modelIndex_Trap );
	// set_entvar( trap, var_angles, Angles);
	
	set_entvar( trap, var_controller, 125 );//*4

	new Float:size_max[ 3 ] = { 5.0,5.0,5.0 };
	new Float:size_min[ 3 ] = { -5.0,-5.0,-5.0 };
	new Float:size[3];

	set_entvar( trap, var_mins, size_min );
	set_entvar( trap, var_maxs, size_max );
	math_mins_maxs( size_max, size_min, size );
	set_entvar( trap, var_size, size );
	
	set_entvar( trap, var_animtime, 2.0 );
	set_entvar( trap, var_framerate, 1.0 );
	set_entvar( trap, var_sequence, 0 );
	
	drop_to_floor( trap );

	// SetTouch( trap, "fw_touch" );
}

public zp_user_humanized_post( id, Survivor ) {
	if (is_user_connected(id)) {
		gravity[id] = get_entvar( id, var_speed );
		Speed[id] = get_entvar( id, var_gravity );
	}
}

public fw_touch( ent, id )
{
	if( !is_entity( ent ) || !is_valid_alive( id ) || g_fTime[ id ] > get_gametime() )
		return;
	
	if( zp_get_class( id ) < ZOMBIE && !g_iPlayerTrapped[ id ] )
	{
		g_fTime[ id ] = get_gametime() + 15.0;

		console_print(id, "tocaste una trap");
		new params[ 2 ]//, ent = rg_find_ent_by_class( 0, g_szTrapEnt );
		set_entvar( ent, var_sequence, 1 );

		gravity[id] = get_entvar( id, var_speed );
		Speed[id] = get_entvar( id, var_gravity );
		client_print_color(id, print_team_default, "31s %f - 31g %f", Speed[id], gravity[id] );

		params[ 0 ] = id;
		params[ 1 ] = ent;

		set_entvar( id, var_maxspeed, 70.0 );
		set_entvar( id, var_gravity, 800.0 );
		
		g_iPlayerTrapped[ id ] = true;
		set_task( cvar_trap_time, "remove_trap", 8985122, params, sizeof( params ) );
	}
}

public remove_trap( params[ ] )
{
	static id; id = params[ 0 ]; 

	if( !is_valid_alive( id ) )
		return;

	if (is_valid_ent(params[ 1 ])) {
		set_entvar( params[ 1 ], var_sequence, 0 );
	}

	set_entvar( id, var_maxspeed, Speed[id] );
	set_entvar( id, var_speed, gravity[id] );
	rg_reset_maxspeed(id);

	g_iPlayerTrapped[ id ] = false;
}

public fw_ResetMaxSpeed_Post( id )
{
	if( is_valid_alive( id ) && g_iPlayerTrapped[ id ] )
	{
		set_entvar( id, var_speed, 70.0 );
		set_entvar( id, var_gravity, 800.0 );
	} else {
		set_entvar( id, var_speed, gravity[id] );
		set_entvar( id, var_gravity, Speed[id] );
	}
}

public DataHandlerTraps( failstate, Handle:Query, error[ ], error2, data[ ], datasize, Float:flTime ) 
{
	switch( failstate ) 
	{
		case TQUERY_CONNECT_FAILED: 
		{
			log_to_file( "SQL_QUARKS_LOG.txt", "Error en la conexion al MySQL [%i]: %s", error2, error );
			return;
		}
		case TQUERY_QUERY_FAILED:
		log_to_file( "SQL_QUARKS_LOG.txt", "Error en la consulta al MySQL [%i]: %s", error2, error );
	}
	switch( data[ 0 ] ) 
	{
		case CREATE_TRAP:
		{
			if( failstate < TQUERY_SUCCESS ) 
			{
				console_print( 0, "Error al crear una trampa: %s.", error );
			}
		}
		case FIND_TRAP:
		{
			if( SQL_NumResults( Query ) )
			{
				while( SQL_MoreResults( Query ) )
                {
					new Positions[50], Float:Origin[3], Float:Angles[3];
					new Origin1[20], Origin2[20], Origin3[20],
					Angles1[20], Angles2[20], Angles3[20];
					SQL_ReadResult(Query, 0, Positions, charsmax(Positions));
					parse(Positions, Origin1, charsmax(Origin1), Origin2, charsmax(Origin2), Origin3, charsmax(Origin3),
					Angles1, charsmax(Angles1), Angles2, charsmax(Angles2), Angles3, charsmax(Angles3));

					Origin[0] = str_to_float(Origin1);
					Origin[1] = str_to_float(Origin2);
					Origin[2] = str_to_float(Origin3);

					Angles[0] = str_to_float(Angles1);
					Angles[1] = str_to_float(Angles2);
					Angles[2] = str_to_float(Angles3);

					create_trap(Origin, Angles);

					SQL_NextRow( Query );
                }
			}
		}
	}
}

public f_Menu(id)
{
	if(~get_user_flags( id ) & ADMIN_RCON)
	return PLUGIN_HANDLED;
	
	new menu = menu_create( "Registrar traps","hn_poner" );
	
	menu_additem( menu, "Registrar Zona" );
	menu_additem( menu, "Guardar Zona" );
	
	menu_display( id, menu );
	return PLUGIN_HANDLED;
}

public hn_poner( id, menu, item )
{
	if ( item == MENU_EXIT || ~get_user_flags( id ) & ADMIN_RCON )
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
	new szQuery[ MAX_MENU_LENGTH ], iData[ 1 ], szMapName[40]; get_mapname(szMapName, 39);
				
	iData[ 0 ] = CREATE_TRAP;

	formatex( szQuery, charsmax( szQuery ), "INSERT INTO zp_traps (Coordenada, Map) VALUES (^"%s^", ^"%s^")",
		iCoordenada, currentMap );
	SQL_ThreadQuery( g_hTuple, "DataHandlerTraps", szQuery, iData, sizeof(iData) );
}
public get_origin(id) 
{ 
	get_entvar(id, var_origin, g_cur_origin);
	get_entvar(id, var_angles, g_cur_angles);

	SaveEnt(g_cur_origin, g_cur_angles);
	
	client_print(id, print_chat, "[trap-NPC] La trap nacera aca"); 
} 
math_mins_maxs(const Float:mins[3], const Float:maxs[3], Float:size[3])
{
    size[0] = (xs_fsign(mins[0]) * mins[0]) + maxs[0];
    size[1] = (xs_fsign(mins[1]) * mins[1]) + maxs[1];
    size[2] = (xs_fsign(mins[2]) * mins[2]) + maxs[2];
}
stock xs_fsign(Float:num)
{
    return (num < 0.0) ? -1 : ((num == 0.0) ? 0 : 1);
}
