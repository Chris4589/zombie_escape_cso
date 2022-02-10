#include <amxmodx>
#include <sqlx>
#include <accsys>

/*
	CREATE TABLE IF NOT EXISTS referencias
	( 
		id_cuenta INT PRIMARY KEY NOT NULL,
		bRef int(10) NOT NULL DEFAULT '0',
		ref int(10) NOT NULL DEFAULT '0'
	)
*/

new const szTable[] = "referencias";

new Handle:g_hTuple;
new g_bInvite[ 33 ];
new g_id[ 33 ];

enum
{
	REGISTRAR_USUARIO,
	LOGUEAR_USUARIO,
	GUARDAR_DATOS,
	SQL_REF,
	SQL_SAVE_DATA
};

new g_iStatus[33];
enum
{
	NO_LOGUEADO = 0,
	LOGUEADO
}

public advacc_guardado_login_success( id )
{
	if( is_user_connected( id ) )
	{
		new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];

		g_id[ id ] = advacc_guardado_id( id );

		iData[ 0 ] = id;
		iData[ 1 ] = LOGUEAR_USUARIO;

		formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE id_cuenta='%d'", szTable, g_id[ id ] );
		SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
	}
}

public plugin_init() {
	register_plugin("ref amx", "1.0", "Hypnotize");
	register_concmd("amx_ref", "cmdRef", _, "amx_ref <id_ref>");

	MySQL_Init();
}

public client_disconnected(id)
{
	if( g_iStatus[ id ] == LOGUEADO )
	{
		g_iStatus[ id ] = NO_LOGUEADO;
	}
}
public client_putinserver(id)
{
	g_iStatus[id] = NO_LOGUEADO;
	g_bInvite[id] = 0;
}

public cmdRef(id, level, cid) { 
	if (g_bInvite[ id ] || !is_user_connected(id) || g_iStatus[ id ] != LOGUEADO) {
		console_print(id, "Ya usaste este comando crack");
		return PLUGIN_HANDLED;
	}

	static arg[32] 
	read_argv(1, arg, sizeof arg - 1) 

	if (!strlen(arg))
	{ 
		console_print(id, "no hay ID");
		return PLUGIN_HANDLED; 
	}

	if (!is_number(arg))
	{ 
		console_print(id, "id-ref invalida");
		return PLUGIN_HANDLED; 
	}

	new idRef = str_to_num(arg);

	if (g_id[id] == idRef)
	{ 
		console_print(id, "No puedes referirte a ti mismo PENDEJO!");
		return PLUGIN_HANDLED; 
	}

	new iData[ 2 ], szQuery[ 512 ]; 

	iData[ 1 ] = SQL_REF; 
	iData[ 0 ] = id;

	formatex( szQuery, 511, "UPDATE %s SET ref = ref+1 WHERE id_cuenta='%d'", szTable, idRef );
	SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );

	return PLUGIN_HANDLED; 
}

public MySQL_Init()
{
	g_hTuple = advacc_guardado_get_handle( );
	
	if( !g_hTuple ) 
	{
		log_to_file( "SQL_ERROR.txt", "No se pudo conectar con la base de datos." );
		return pause( "a" );
	}

	return PLUGIN_CONTINUE;
}


public DataHandler( failstate, Handle:Query, error[ ], error2, data[ ], datasize, Float:flTime ) 
{
	switch( failstate ) 
	{
		case TQUERY_CONNECT_FAILED: 
		{
			log_to_file( "SQL_LOG_TQ.txt", "Error en la conexion al MySQL [%i]: %s", error2, error );
			return;
		}
		case TQUERY_QUERY_FAILED:
		log_to_file( "SQL_LOG_TQ.txt", "Error en la consulta al MySQL [%i]: %s", error2, error );
	}
	
	new id = data[ 0 ];
	
	if( !is_user_connected( id ) )
		return;
	
	switch( data[ 1 ] ) 
	{
		case LOGUEAR_USUARIO: 
		{
			if( SQL_NumResults( Query ) )
			{
				g_bInvite[ id ] = SQL_ReadResult( Query, 1 );

				g_iStatus[ id ] = LOGUEADO;
			}
			else
			{
				new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];
				
				iData[ 0 ] = id;
				iData[ 1 ] = REGISTRAR_USUARIO;
				
				formatex( szQuery, charsmax( szQuery ), "INSERT INTO %s (id_cuenta, bRef, ref) VALUES (%d, 0, 0)", 
					szTable, g_id[ id ]);
				SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
			}
		}
		case REGISTRAR_USUARIO: 
		{
			if( failstate < TQUERY_SUCCESS ) 
			{
				console_print( id, "Error al crear un usuario: %s.", error );
			}
			else
			{
				g_bInvite[id] = 0;
			}
		}
		case SQL_REF:
		{
			if( failstate < TQUERY_SUCCESS ) {
				console_print( id, "error al tratar de referenciar");
			}
			else {
				g_bInvite[ id ] = 1;

				new iData[ 2 ], szQuery[ MAX_MENU_LENGTH ]; 

				iData[ 1 ] = id; 
				iData[ 0 ] = SQL_SAVE_DATA;

				formatex( szQuery, charsmax(szQuery), "UPDATE %s SET bRef = '%d' WHERE id_cuenta='%d'", 
					szTable, g_bInvite[ id ], g_id[id] );
				SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
			}
		}
		case SQL_SAVE_DATA:
		{
			if( failstate < TQUERY_SUCCESS )
				console_print( id, "err ref");
			else
				console_print( id, "se guardo");
		}
	}
}

public is_number(const str[]){

	for(new i = 0; i < strlen(str) ; ++i)
	{
		if(!isdigit(str[i]))
			return false;
	}

	return true;
}