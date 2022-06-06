#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <sqlx>
#include <fakemeta>
#include <cstrike>
#include <print_center_fx>

#define use_reapi

//#define experience

#if !defined use_reapi
	stock is_user_steam_2( i )
	{
		new value = false; 
		
		static szAuthid[ 9 ]; get_user_authid( i, szAuthid, 8 );

		if( equali( "STEAM_0:", szAuthid) || equali( "STEAM_1:", szAuthid ))
			value = true;

		return value;	
	}

#else

#define is_user_steam_2(%1) is_user_steam(%1)

#endif


/*

	CREATE TABLE zp_cuentas 
	(
		id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY ,
		Pj varchar(34) NOT NULL UNIQUE KEY, 
		Password varchar(34) NOT NULL,
		status_steam int(10) NOT NULL DEFAULT '0',
		steam_id varchar(40) NOT NULL,
		LastServer varchar(40) NOT NULL DEFAULT 'none',
		Online int(2) NOT NULL DEFAULT '0',
		coins int(20) NOT NULL DEFAULT '0',
		tiempo float(20) NOT NULL DEFAULT '0',
		tiempo_total float(20) NOT NULL DEFAULT '0'
	);

*/


#if defined experience

enum _:exp_data
{
	menu_data[33],
	exp,
	horas
}


new const menu_exp[][exp_data] =
{
	{"1 Hora",    50,     1},
	{"2 Horas",   110,    2},
	{"5 Horas",   287,    5},
	{"10 Horas",  600,   10},
	{"20 Horas",  1250,  20},
	{"50 Horas",  3250,  50},
	{"100 Horas", 6750,  100} 
}

new segundos, minutos, hrs, dias;

native zp_set_exp(id, value)

#endif

#define PREFIX "[CEA]"


enum
{
	REGISTRAR_CUENTA,
	LOGUEAR_CUENTA,
	CARGAR_DATOS,
	IS_REGISTER,
	GUARDAR_DATOS,
	TOTAL_CUENTAS,
	SET_OFFLINE,
	CARGAR_NICK
};

enum
{
	DESCONECTADO = 0,
	REGISTRADO,
	LOGUEADO,
	MAX_STATUS
}

//No cambiar autor por más que lo uses para otro modo, no seas rata, no importa si lo reescribes media ves te bases en este
new const PluginName[] = "System Account";
new const PluginVersion[] = "1.1";
new const PluginAuthor[] = "Hypnotize";
//No cambiar autor por más que lo uses para otro modo, no seas rata, no importa si lo reescribes media ves te bases en este

//apartado para escribir el nombre del creador del mod
//area modificable
new const ModName[] = "Zombie Plague";//nombre del mod
new const ModAuthor[] = "Hypnotize"; //acá pones tu nombre si lo usaste para un modo tuyo
new const ModVersion[] = "1.0b";//versión del modo
new const g_szForo[] = "petardas.com";
//apartado para escribir el nombre del creador del mod
//area modificable

new const g_szTabla[ ] = "zp_cuentas";
new const g_szPrefijo[ ] = "[ CEA ]";

new const MYSQL_HOST[] = "127.0.0.1";
new const MYSQL_USER[] = "root";
new const MYSQL_PASS[] = "Chris4589@";
new const MYSQL_DATEBASE[] = "counter_strike";

new Handle:g_hTuple;

new g_fwLogin;
new g_iTotalRegister;
new g_estado[ 33 ];
new g_id[ 33 ];
new g_points[33];
new g_szPassword[ 33 ][ 34 ];
new g_szPlayerName[ 33 ][ 33 ], g_szSteam[ 33 ][ 34 ], g_szSteamDB[ 33 ][ 34 ];
new g_iData[ 33 ], g_iStatus_steam[ 33 ], g_online[33], g_otherConexion[33];

const m_iVGUI = 510;
const TIEMPO_LOGUEO = 35465;

new g_iTime[ 33 ];
new server[ 30 ];

new cvar_type;

#define DEFAULT_DAMAGE 900

new bool:happyTime, happyMultiplier, happyDamage;

enum _:__HappyData { happy_hour[3], happy_damage, happy_multiplier };

new const _HappyHour[][__HappyData] =
{
	{ "06", 900, 2 },
	{ "07", 900, 2 },
	{ "14", 900, 2 },
	{ "15", 900, 2 },
	{ "16", 900, 2 },
	{ "19", 900, 2 },
	{ "20", 900, 2 },
	{ "22", 900, 2 },
	{ "23", 900, 2 }

};


new Float:g_PlayedTime[33];
new Float:g_pGameTime[33];
new Float:g_TotalTime[33];


new szName[32]
static Name[32], Old[32]

public plugin_init()  
{
	register_plugin( 
		PluginName, 
		PluginVersion, 
		PluginAuthor 
	);

	register_clcmd("CREAR_PASSWORD", "register_account");
	register_clcmd("LOGUEAR_PASSWORD", "login_account");

	register_clcmd("say /hh", "checkhapy");
	register_clcmd("say hh", "checkhapy");
	register_clcmd("say /register", "cl_cmdregister");
	register_clcmd("say /horarios", "menuHorarios");

	register_forward(FM_ClientUserInfoChanged, "fw_ClientUserInfoChanged");

	RegisterHookChain( RG_CBasePlayer_RoundRespawn, "fw_respawn_post", true );

	RegisterHookChain(RG_ShowVGUIMenu, "message_VGUImenu");
	RegisterHookChain(RG_ShowMenu, "message_showmenu");
	RegisterHookChain(RG_HandleMenu_ChooseTeam, "message_showmenu");

	register_logevent("EventRoundEnd", 2, "1=Round_End");
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	
	g_fwLogin = CreateMultiForward("advacc_guardado_login_success", ET_IGNORE, FP_CELL);
	
	cvar_type = register_cvar("sys_type", "0");

	g_iTotalRegister = 0;

	get_user_ip( 0, server, 29 );

	Mysql_init( );

	happyDamage = DEFAULT_DAMAGE

	register_clcmd( "say /time", "cmdTime" );
	//register_clcmd( "say /toptime", "top_time" );
	#if defined experience
	register_clcmd( "say /exp", "exp_menu" );
	#endif
}

public checkhapy(id)
{
        new hours_hh, mins_hh, secs_hh, hora[6], hour[3], mins[3], secs[3];
        get_time("%H %M %S", hora, 10);
        parse(hora, hour, 2, mins, 2, secs, 2);

        
        new happyhour;
        for(new i=0; i < sizeof _HappyHour; i++)
        {

            if(equal(_HappyHour[i][happy_hour], "00"))
                happyhour = 24;
            else
                happyhour = str_to_num(_HappyHour[i][happy_hour]);
            if(str_to_num(hour) < happyhour)
            {
                hours_hh = (happyhour - str_to_num(hour));
                if(str_to_num(mins) < 60)
					mins_hh = (60-str_to_num(mins));

		if(str_to_num(secs) < 60)
		{
			secs_hh = (60-str_to_num(secs));
		}
											        
		break;
            }
        }
	new szDay[5]
	get_time( "%a", szDay, 4 );
	if(equal( szDay, "Sun" ))
	{
		happyMultiplier = 2;
		client_print_color(0, print_team_blue, "HORA FELIZ TODO EL DIA^x04!^x01 Multiplicador: ^x04%d!", happyMultiplier);
	}
	else
	{	
		static i;
		if(happyTime)
		{
			client_print_color(id, print_team_default, "^3HORA FELIZ ^4activada ^3Ganas x%d ^4Exp",_HappyHour[i][happy_multiplier])
		}
		else
		{
			client_print_color(id, print_team_default, "^4Faltan:^3 %d hora%s, %d minuto%s %d Segundos ^4para la Hora Feliz",hours_hh-1, ((hours_hh-1) != 1 ? "s":""), mins_hh, mins_hh != 1 ? "s":"", secs_hh );
		}
	}
}

public plugin_natives()
{
	register_native("is_registered", "native_register", 1);
	//register_native("is_logged", "native_logged", 1);
	register_native("advacc_user_logged" , "native_logged", 1);
	//register_native("show_login_menu", "native_login", 1);
	register_native("open_cuenta_menu", "native_login", 1);
	register_native("is_player_load", "native_data", 1);
	register_native("advacc_guardado_get_handle", "handler_connection", 1);
	register_native("advacc_guardado_id", "_sm_guardado_id");

	register_native("set_user_coins", "native_set_coins", 1);
	register_native("get_user_coins", "native_get_coins", 1);
	register_native("isHappyHour", "native_ishh", 1);
	register_native("happyMultiplier", "native_hhmultiplier", 1);
	register_native("happyDamage", "native_hhDmg", 1);
}

public native_data(id) {
	return g_iData[id];
}
public native_hhDmg() {
	return happyDamage;
}

public native_ishh() {
	return happyTime;
}

public native_hhmultiplier() {
	return happyMultiplier;
}

public native_set_coins(id, cant) {
	g_points[id] = cant;
}

public native_get_coins(id) {
	return g_points[id];
}

public _sm_guardado_id(iPlugin, iParams) return g_id[ get_param(1) ];

public Handle:handler_connection()
	return g_hTuple;

public native_login(id)
	return show_login_menu(id);

public native_register(id)
	return g_estado[ id ] == REGISTRADO ? true : false;

public native_logged(id)
	return g_estado[ id ] == LOGUEADO ? true : false;

public EventRoundEnd() {
	for(new id=1; id <= MAX_PLAYERS; id++)
	{
		if (!g_estado[ id ]) {
			continue;
		}
		save_data(id);
	}
}

public message_VGUImenu( const id, VGUIMenu: iMenu, const iBitsSlots, const szOldMenu[], const bool: bForceOldMenu )
{
	if( iMenu != VGUI_Menu_Team || g_estado[ id ] >= LOGUEADO || !g_iData[id] && g_estado[ id ] == DESCONECTADO )
		return HC_CONTINUE;

	SetHookChainReturn(ATYPE_INTEGER, false);
	return HC_SUPERCEDE;
}

public message_showmenu( iMsgid, iDest, id ) 
{
	if( g_estado[ iMsgid ] >= LOGUEADO || !g_iData[iMsgid] && g_estado[ iMsgid ] == DESCONECTADO )
		return HC_CONTINUE;

	SetHookChainReturn(ATYPE_INTEGER, false);
	return HC_SUPERCEDE;
}

public cl_cmdregister(id) {
	if (g_estado[ id ] == DESCONECTADO && !g_iData[id]) {
		g_iData[id] = 1;
		check_register( id );
	}
}

public show_login_menu( id ) 
{
	if(!is_user_connected(id))
		return PLUGIN_HANDLED;

	if(!g_iData[id])
	{
		client_print(id, print_chat, "Espera un momento, tus datos están siendo buscados..");
		client_print(id, print_chat, "Espera un momento, tus datos están siendo buscados..");
		client_print(id, print_chat, "Espera un momento, tus datos están siendo buscados..");
		return PLUGIN_HANDLED;
	}

	static menu, info[200]; 

	formatex(info, charsmax(info), "\wBIENVENIDOS AL \y%s \r(%s)\w^n\wCreador: \r%s", ModName, ModVersion, ModAuthor);
	menu = menu_create(info, "menu_login" );
	
	if(g_estado[ id ] >= REGISTRADO)
		menu_additem( menu, "\dCreate an account" );
	else
		menu_additem( menu, "\wCreate an account" );

	if(g_estado[ id ] >= REGISTRADO)
		menu_additem( menu, "\wLogin" );
	else
		menu_additem( menu, "\dLogin" );
	
	formatex(info, charsmax(info), "^n\wRegistered Accounts\w: \y#%d", g_iTotalRegister);
	menu_addtext(menu, info);

	formatex(info, charsmax(info), "^n\wForum\r: \y%s", g_szForo);
	menu_addtext(menu, info);

	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public menu_login( id, menu, item ) 
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	switch( item ) 
	{
		case 0: 
		{
			if(g_estado[ id ] >= REGISTRADO)
				client_print(id, print_center, "%s Esta Cuenta ya esta registrada.", g_szPrefijo);
			else
				client_cmd( id, "messagemode CREAR_PASSWORD" );
		}
		case 1:
		{
			if(g_estado[ id ] >= REGISTRADO)
				client_cmd( id, "messagemode LOGUEAR_PASSWORD" );
			else
				client_print(id, print_center, "%s Tu cuenta aun no existe.", g_szPrefijo);
		}
	}
	return PLUGIN_HANDLED;
}

public register_account( id ) 
{
	read_args( g_szPassword[ id ], charsmax( g_szPassword[ ] ) );
	remove_quotes( g_szPassword[ id ] );
	trim( g_szPassword[ id ] );
	//hash_string( g_szPassword[ id ], Hash_Md5, g_szPassword[ id ], charsmax( g_szPassword[] ) );
	
	new szQuery[ 256 ], iData[ 2 ], szSteam[ 40 ];
	
	iData[ 0 ] = id;
	iData[ 1 ] = REGISTRAR_CUENTA;

	get_user_authid( id, szSteam, charsmax( szSteam ) );

	g_iStatus_steam[ id ] = is_user_steam_2( id ) ? 1 : 0;

	formatex( szQuery, charsmax( szQuery ), "INSERT INTO %s (Pj, Password, status_steam, steam_id, LastServer, Online, coins, tiempo, tiempo_total) VALUES (^"%s^", ^"%s^", %d, ^"%s^", 'none', 0, 0, 0, 0)", g_szTabla, g_szPlayerName[ id ], g_szPassword[ id ], g_iStatus_steam[ id ], szSteam );
	SQL_ThreadQuery(g_hTuple, "DataHandler", szQuery, iData, 2);
	
	return PLUGIN_HANDLED;
}
public login_account( id ) 
{
	read_args( g_szPassword[ id ], charsmax( g_szPassword[ ] ) );
	remove_quotes( g_szPassword[ id ] );
	trim( g_szPassword[ id ] );
	//hash_string( g_szPassword[ id ], Hash_Md5, g_szPassword[ id ], charsmax( g_szPassword[] ) );
	
	new szQuery[ 128 ], iData[ 2 ];
	
	iData[ 0 ] = id;
	iData[ 1 ] = LOGUEAR_CUENTA;
	
	formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE Pj=^"%s^" AND Password=^"%s^"", g_szTabla, g_szPlayerName[ id ], g_szPassword[ id ] );
	SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
	
	return PLUGIN_HANDLED;
}
public DataHandlerServer( failstate, Handle:Query, error[ ], error2, data[ ], datasize, Float:time ) 
{
	switch( failstate ) 
	{
		case TQUERY_CONNECT_FAILED: 
		{
			log_to_file( "SQL_CUENTAS_LOG.txt", "Error en la conexion al MySQL [%i]: %s", error2, error );
			return;
		}
		case TQUERY_QUERY_FAILED:
			log_to_file( "SQL_CUENTAS_LOG.txt", "Error en la consulta al MySQL ACCSYS [%i]: %s", error2, error );
	}
	switch( data[ 0 ] ) 
	{
		case TOTAL_CUENTAS:
		{
			if(SQL_NumResults( Query ))
			{
				g_iTotalRegister = SQL_ReadResult( Query, 0 );
			}
		}
		case SET_OFFLINE: {
			if( failstate < TQUERY_SUCCESS )
				console_print( 0, "Error Actualizando de datos." );
			else
			console_print( 0, "Actualizado" );
		}
	}
}
public DataHandler( failstate, Handle:Query, error[ ], error2, data[ ], datasize, Float:time ) 
{
	new id = data[ 0 ];
	
	if( !is_user_connected( id ) )
		return;

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
	
	switch( data[ 1 ] ) 
	{
		case REGISTRAR_CUENTA: 
		{
			if( failstate < TQUERY_SUCCESS ) 
			{
				if( containi( error, "Pj" ) != -1 )
					client_print( id, print_chat, "%s El nombre de personaje esta en uso.", g_szPrefijo );
				else
					client_print( id, print_chat, "%s Error al crear la cuenta. Intente nuevamente.", g_szPrefijo );
				
				client_cmd( id, "spk buttons/button10.wav" );
				
				show_login_menu( id );
			}
			else 
			{
				client_print( id, print_chat, "%s Tu cuenta ha sido creada correctamente.", g_szPrefijo );
				
				new szQuery[ 128 ], iData[ 2 ];
				
				iData[ 0 ] = id;
				iData[ 1 ] = CARGAR_DATOS;

				g_estado[ id ] = REGISTRADO;
				
				formatex( szQuery, charsmax( szQuery ), "SELECT id FROM %s WHERE Pj=^"%s^"", g_szTabla, g_szPlayerName[ id ] );
				SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
			}
			
		}
		case LOGUEAR_CUENTA: 
		{
			if( SQL_NumResults( Query ) ) 
			{
				g_id[ id ] = SQL_ReadResult( Query, 0 );
				g_iStatus_steam[ id ] = SQL_ReadResult( Query, 3 );
				
				if (SQL_ReadResult( Query, 6 )) {
					g_otherConexion[id] = 1;
					server_cmd("kick #%d ^"NO PUEDES CONECTARTE 2 VECES!^"", get_user_userid( id ));
					return;
				}
				g_points[id] = SQL_ReadResult( Query, 7 );


				SQL_ReadResult(Query, 8, float:g_PlayedTime[id]);

				SQL_ReadResult(Query, 9, float:g_TotalTime[id]);

				SQL_ReadResult( Query, 1, g_szPlayerName[ id ], charsmax( g_szPlayerName[ ] ) );

				if(is_user_steam_2(id))
				{
					client_cmd(id, "name %s", g_szPlayerName[id])
				}					
				
				new iRet; ExecuteForward(g_fwLogin, iRet, id/*, g_id[ id ]*/);
			
				func_login_success( id );
			}
			else 
			{
				client_print( id, print_chat, "%s Usuario o ContraseÃ± incorrecta.", g_szPrefijo );
				client_cmd( id, "spk buttons/button10.wav" );
				
				show_login_menu( id );
			}
		}
		case CARGAR_DATOS: 
		{
			if( SQL_NumResults( Query ) ) 
			{
				g_id[ id ] = SQL_ReadResult( Query, 0 );
				g_iStatus_steam[ id ] = is_user_steam_2( id ) ? 1 : 0;
					
				new iRet; ExecuteForward(g_fwLogin, iRet, id/*, g_id[ id ]*/);

				func_login_success( id );
			}
			else 
			{
				client_print( id, print_chat, "%s Error al cargar los datos, intente nuevamente.", g_szPrefijo );
				show_login_menu( id );
			}
		}
		case IS_REGISTER:
		{
			if( SQL_NumResults( Query ) )
			{
				g_estado[ id ] = REGISTRADO;
				g_iStatus_steam[ id ] = SQL_ReadResult( Query, 3 );
				SQL_ReadResult( Query, 4, g_szSteamDB[ id ], charsmax( g_szSteamDB[ ] ) );
			}
			else
			{
				g_estado[ id ] = DESCONECTADO;
			}

			if( g_estado[ id ] == REGISTRADO )
			{
				if( is_user_steam_2( id ) )
				{
					g_iData[ id ] = 1;
					if( g_iStatus_steam[ id ] )
					{
						if( equal( g_szSteamDB[ id ], g_szSteam[ id ] ) )
						{
							//autolog
							new szQuery[ 128 ], iData[ 2 ];
	
							iData[ 0 ] = id;
							iData[ 1 ] = LOGUEAR_CUENTA;
							
							formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE steam_id=^"%s^"", g_szTabla, g_szSteam[ id ] );
							SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
							console_print( 0, "AUTOLOG");
						}
						else
						{
							//entraste con otro steam
							client_print_color( id, print_team_blue, "Entraste con otro steam!");
							client_print_color( id, print_team_blue, "Entraste con otro steam!");
							client_print_color( id, print_team_blue, "Entraste con otro steam!");
							console_print( 0, "OTRO STEAM LOG");
							server_cmd("kick #%d ^"ENTRASTE CON OTRO STEAM!^"",  get_user_userid(id));
						}
					}
					else if(g_iData[id])
					{
						set_task(0.8, "show_login_menu", id);
						set_task(1.0, "logueo_cuenta", TIEMPO_LOGUEO+id, _, _, "b");
						console_print( 0, "LOGIN STATUS 0");
					}
				}
				else//idlan
				{
					g_iData[ id ] = 1;
					if( g_iStatus_steam[ id ] )
					{
						//es steam entro en no steam
						client_print_color( id, print_team_blue, "Entraste con otro steam!");
						client_print_color( id, print_team_blue, "Entraste con otro steam!");
						client_print_color( id, print_team_blue, "Entraste con otro steam!");

						console_print( 0, "NO STEAM / STEAM");
					}
					else
					{
						set_task(0.8, "show_login_menu", id);
						set_task(1.0, "logueo_cuenta", TIEMPO_LOGUEO+id, _, _, "b");
						console_print( 0, "LOGIN NO-STEAM");
					}
					
				}
			}
			else if(g_iData[id])//no registrado
			{
				set_task(0.8, "show_login_menu", id);
				set_task(1.0, "logueo_cuenta", TIEMPO_LOGUEO+id, _, _, "b");
			}
		}
		case GUARDAR_DATOS:
		{
			if( failstate < TQUERY_SUCCESS )
				console_print( id, "Error en el guardado de datos." );
			else
			console_print( id, "Datos guardados." );
		}
		case CARGAR_NICK:
		{
			if( SQL_NumResults( Query ) ) 
				SQL_ReadResult(Query, 1, szName, charsmax(szName))
		}
	}
}

public logueo_cuenta( taskid )
{
	static id; 
	id = taskid - TIEMPO_LOGUEO;

	if( g_iTime[id] <= 0 )
	{
		remove_task(TIEMPO_LOGUEO+id);
		server_cmd("kick #%d",  get_user_userid(id));
		return;
	}

	client_print(id, print_center, "Tienes %d segundos para loguearte", g_iTime[id]);

	g_iTime[id]--;
}

public func_login_success( id ) 
{
	if( is_user_connected(id) )
	{
		if (get_pcvar_num(cvar_type)) rg_join_team( id, rg_get_join_team_priority( ) );

		g_estado[ id ] = LOGUEADO;
		g_online[id] = 1;
		save_data(id);
		
		set_user_info( id, "name", g_szPlayerName[ id ] );

		remove_task(TIEMPO_LOGUEO+id);
	}
		
}

public fw_respawn_post( id )
{
	if( !is_user_connected( id ) ) 
		return;

	if( is_user_steam_2( id ) && !g_iStatus_steam[ id ] )
	{
		new szQuery[ MAX_MOTD_LENGTH ], iData[ 2 ];

		iData[ 0 ] = id;
		iData[ 1 ] = GUARDAR_DATOS;

		formatex( szQuery, charsmax( szQuery ), "UPDATE %s SET status_steam = 1, steam_id=^"%s^" WHERE id = '%d'", g_szTabla, g_szSteam[ id ], g_id[ id ] );
		SQL_ThreadQuery(g_hTuple, "DataHandler", szQuery, iData, 2);
	}	
}

public save_data(id) {

	if (g_otherConexion[id] || !g_estado[id]) {
		return;
	}

	new szQuery[ MAX_MOTD_LENGTH ], iData[ 2 ];

	iData[ 0 ] = id;
	iData[ 1 ] = GUARDAR_DATOS;

	formatex( szQuery, charsmax( szQuery ), "UPDATE %s SET Online = '%d', LastServer=^"%s^", coins = '%d', tiempo = '%f', tiempo_total = '%f' WHERE id = '%d'", 
		g_szTabla, g_online[id], server, g_points[ id ], g_PlayedTime[id], g_TotalTime[id], g_id[ id ] );
	SQL_ThreadQuery(g_hTuple, "DataHandler", szQuery, iData, 2);
}

public menuHorarios(index) {
	new i, szBuffer[1024], len, szTime[10]; len = 0;
	len += formatex(szBuffer[len], charsmax(szBuffer)-len, 
	"<head><style>\
	table {font-family:arial, sans-serif;border-collapse:collapse;width:100%;}\
	td, th {border:1px solid #dddddd;text-align:center;padding:8px;}\
	tr:nth-child(even) {background-color:#dddddd;color:#000;}\
	body {color:#FFF;background:#000;}\
	</style>\
	</head><body>\
	<center><h2>Horarios/Ganancias Happy Hour</h2>\
	<table>\
	<tr><th>Hora</th><th>Damage</th><th>Multiplicador</th></tr>");

	for( i = 0 ; i < sizeof _HappyHour ; ++i )
	{
		len += formatex(szBuffer[len], charsmax(szBuffer)-len, 
		"<tr><td>%s</td><td>%d</td><td>x%d</td></tr>", _HappyHour[i][happy_hour], _HappyHour[i][happy_damage], _HappyHour[i][happy_multiplier]);
	}

	get_time("%H:%M", szTime, 9);
	len += formatex(szBuffer[len], charsmax(szBuffer)-len, "</table><div>NOTA: Los multiplicadores se suman a tu multiplicador personal<br>Hora del servidor: %s</div></body>", szTime);

	show_motd(index, szBuffer, "Happy Hour");
}

public fw_ClientUserInfoChanged(id, buffer) 
{
	if (!is_user_connected(id)) 
		return FMRES_IGNORED;

	if(task_exists(id+1500))
	return FMRES_SUPERCEDE
    
	get_user_name(id, Name, charsmax(Name));
	get_user_info(id, "name", Old, charsmax(Old))

	if (equal(Old, Name)) 
 		return FMRES_IGNORED;

	new szQuery[ MAX_MOTD_LENGTH ], iData[ 2 ];

	iData[ 0 ] = id;
	iData[ 1 ] = CARGAR_NICK;

	formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE Pj=^"%s^"", g_szTabla, Old);
	SQL_ThreadQuery(g_hTuple, "DataHandler", szQuery, iData, 2);

	set_task(1.0, "change_nick", id);

	return FMRES_SUPERCEDE;
  
}

public change_nick(id)
{

    if(is_user_steam_2(id) && g_iData[id])
    {	  	
    	if(equal(Old, szName))
    	{
    		chatcolor(id, "^4[%s] ^1Nick en Uso", PREFIX)
    		set_user_info(id, "name", Name);
    		client_cmd( id, "spk buttons/button10.wav" );
    		set_task(0.5, "nick_change", id+1500)
    		return FMRES_SUPERCEDE;
    	}
    	else 
    	{
			new szQuery[ MAX_MOTD_LENGTH ], iData[ 2 ];
			iData[ 0 ] = id;
			iData[ 1 ] = GUARDAR_DATOS;

			formatex( szQuery, charsmax( szQuery ), "UPDATE %s SET Pj=^"%s^" WHERE id = '%d'", g_szTabla, Old, g_id[ id ] );
			SQL_ThreadQuery(g_hTuple, "DataHandler", szQuery, iData, 2)
			set_user_info(id, "name", Old);
			chatcolor(0, "^3[%s] ^4%s ^1Cambio su nombre a ^4%s", PREFIX, Name, Old)
			set_task(0.5, "nick_change", id+1500)
			return FMRES_IGNORED;
    	}		
    }
    else
    {
    	set_user_info(id, "name", g_szPlayerName[ id ]);
    	return FMRES_IGNORED;
    }
    
}

public nick_change(id)
	return

public client_putinserver( id )
{
	if( is_user_bot( id ) )
		return PLUGIN_CONTINUE;

	get_user_name( id, g_szPlayerName[ id ], charsmax( g_szPlayerName[ ] ) );
	get_user_authid( id, g_szSteam[ id ], charsmax( g_szSteam[ ] ) );

	g_iData[id] = 0;
	g_iTime[ id ] = 60;
	g_online[id] = 0;
	g_TotalTime[id] = 0.0;
	g_PlayedTime[id] = 0.0;
	//g_points[id] = 0;
	g_otherConexion[id] = 0;
	g_pGameTime[id] = get_gametime();
	check_register( id );

	set_task(3.0, "cmdMenu", id)
	return PLUGIN_CONTINUE;
}

public check_register( id )
{
	new szQuery[ 256 ], iData[ 2 ];
	
	iData[ 0 ] = id;
	iData[ 1 ] = IS_REGISTER;
	
	if(is_user_steam_2(id))
	{
		formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE steam_id = ^"%s^"", g_szTabla, g_szSteam[ id ]);
	}
	else
		formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE Pj = ^"%s^"", g_szTabla, g_szPlayerName[ id ]);
	
	SQL_ThreadQuery(g_hTuple, "DataHandler", szQuery, iData, 2);
}

public client_disconnected(  id ) 
{
	g_PlayedTime[id] += get_gametime() - g_pGameTime[id];
	g_TotalTime[id] += get_gametime() - g_pGameTime[id];
	if( g_estado[ id ] ) 
	{
		if (!g_otherConexion[id]) {
			g_online[id] = 0;
			save_data(id);
		}

		g_estado[ id ] = DESCONECTADO;	
	}
	g_szPassword[ id ][ 0 ] = EOS;

	remove_task(TIEMPO_LOGUEO+id);
	remove_task(id)
}

public offline() {
	new szQuery[ 256 ], iData[ 1 ];
	
	iData[ 0 ] = SET_OFFLINE;

	formatex( szQuery, charsmax( szQuery ), "UPDATE %s SET Online='0', LastServer='none' WHERE LastServer=^"%s^"", 
	g_szTabla, server);
	SQL_ThreadQuery(g_hTuple, "DataHandlerServer", szQuery, iData, 2);
}

public Mysql_init()
{
	g_hTuple = SQL_MakeDbTuple( MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DATEBASE );
	
	if( !g_hTuple ) 
	{
		log_to_file( "SQL_ERROR.txt", "No se pudo conectar con la base de datos." );
		return pause( "a" );
	}

	offline();

	new szQuery[ 256 ], iData[ 1 ];
	
	iData[ 0 ] = TOTAL_CUENTAS;
	
	formatex( szQuery, charsmax( szQuery ), "SELECT COUNT(*) FROM %s", g_szTabla);
	SQL_ThreadQuery(g_hTuple, "DataHandlerServer", szQuery, iData, 2);
	return PLUGIN_CONTINUE;
}

public event_round_start() {
	checkHH();
}

public checkHH() {
	happyTime = false;
	happyMultiplier = 1;

	static i, current_hour[3], szDay[5]; get_time("%H", current_hour, 2);
	for( i = 0 ; i < sizeof _HappyHour ; ++i )
	{
		if(equal(_HappyHour[i][happy_hour], current_hour))
		{
			happyTime = true;
			happyDamage = _HappyHour[i][happy_damage];
			happyMultiplier = _HappyHour[i][happy_multiplier];
			client_print_color(0, print_team_blue, "HORA FELIZ^x04 ACTIVA!^x01 Multiplicador: ^x04%d", happyMultiplier);
			break;
		}
	}

	get_time( "%a", szDay, 4 );
	if(equal( szDay, "Sun" ))
	{
		happyTime = true;
		happyMultiplier = 2;
		client_print_color(0, print_team_blue, "HORA FELIZ TODO EL DIA^x04!^x01 Multiplicador: ^x04%d!", happyMultiplier);
	}
}

public plugin_end()
	SQL_FreeHandle( g_hTuple );


public cmdMenu(id)
{
	if (g_estado[ id ] != DESCONECTADO && g_iData[id])
		return;

	new gMenu = menu_create("\rCrearte una Cuenta", "handlerMenu")
    
	menu_additem(gMenu, "\wCrear Cuenta", "1")
	menu_additem(gMenu, "\dEntrar como Invitado", "2")
	menu_display(id, gMenu, 0)
}

public handlerMenu(id, menu, item)
{
	if (g_estado[ id ] != DESCONECTADO && g_iData[id])
		return PLUGIN_HANDLED;

	if ( item == MENU_EXIT )
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED;
	}

	switch(item)
	{
		case 0:
		{
			cl_cmdregister(id)
		}
		case 1:
		{
			client_print(id, print_chat, "Create una cuenta para poder guardar tu Experiencia. Escribe /register") 
			static CsTeams:team
			team = cs_get_user_team(id)
			if (team == CS_TEAM_SPECTATOR || team == CS_TEAM_UNASSIGNED)
			{
				rg_join_team(id, TEAM_TERRORIST)
			}
		}
	}
	return PLUGIN_HANDLED;
} 

public cmdTime(id)
{
	new days, hours, mins, segs;

	g_PlayedTime[id] += get_gametime() - g_pGameTime[id];
	g_TotalTime[id] += get_gametime() - g_pGameTime[id];
	g_pGameTime[id] = get_gametime();
    
	segs = floatround(g_TotalTime[id]);
    
	mins = segs/60;
	hours = mins/60;
	days = hours/24;
	segs = segs-mins*60;
	mins = mins-hours*60;
	hours = hours-days*24;
    
	client_print(id, print_chat, "Haz Jugado: %i Dia%s %i Horas %i Minutos y %i segundos", days, days == 1? "":"s", hours, mins, segs);


//client_print(id, print_chat, "Haz Jugado: %i Dia%s con %s%i:%s%i:%s%i", days, days == 1? "":"s", hours > 9? "":"0", hours, mins > 9? "":"0", mins, segs > 9? "":"0", segs);


}


#if defined experience
public exp_menu(id)
{

	g_PlayedTime[id] += get_gametime() - g_pGameTime[id];

	segundos = floatround(g_PlayedTime[id]);
	minutos = segundos/60;
	hrs = minutos/60;
	dias = hrs/24;
	segundos = segundos-minutos*60;
	minutos = minutos-hrs*60;
	hrs = hrs-dias*24;

	new menu = menu_create( fmt("\r[Zombie Escape] \wTus Horas Canjeables: \r%d \wHoras", hrs), "handler_exp" )

	static g_isLen[80]
	

	for(new i = 0; i < sizeof(menu_exp); i++)
	{	
		if(hrs >= menu_exp[i][horas])
			formatex(g_isLen, charsmax(g_isLen), "\w%s \r- \y%d", menu_exp[i][menu_data], menu_exp[i][exp]);
				else
					formatex(g_isLen, charsmax(g_isLen), "\d%s - %d", menu_exp[i][menu_data], menu_exp[i][exp]);
		
		menu_additem(menu, g_isLen, "")
	}
	menu_display( id, menu);
	return PLUGIN_HANDLED;
}

public handler_exp( id, menu, item)
{
	if( item == MENU_EXIT) 
	{
		menu_destroy( menu );
		return PLUGIN_HANDLED;
	}
	
	if(hrs >= menu_exp[item][horas])
	{
		g_PlayedTime[id] -= menu_exp[item][horas]*60*60;
		zp_set_exp(id, menu_exp[item][exp])
	}
	else
		client_print(id, print_chat, "No tienes Horas suficientes")
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

#endif

public top_time(id)
	show_motd(id, "http://45.58.56.30/zombie_escape/top_tiempo.php", "Top Jugadores Viciados")

stock chatcolor(id, const input[], any:...)
{
    static szMsg[191], msgSayText;
    
    if (!msgSayText)
        msgSayText = get_user_msgid("SayText");

    replace_all(szMsg, 190, "!g", "^4");
    replace_all(szMsg, 190, "!y", "^1");
    replace_all(szMsg, 190, "!team", "^3");
    
    vformat(szMsg, 190, input, 3);
    
    message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, msgSayText, .player = id);
    write_byte(id ? id : 33);
    write_string(szMsg);
    message_end();
}

