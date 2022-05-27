#include <amxmodx>
#include <zombie_escape_v1>
#include <sqlx>
#include <accsys>
/*
CREATE TABLE logros_ze
    (
        id_cuenta INT PRIMARY KEY NOT NULL,
		button int(10) NOT NULL DEFAULT '0',
		kills int(10) NOT NULL DEFAULT '0',
		infect int(10) NOT NULL DEFAULT '0',
		frozen int(10) NOT NULL DEFAULT '0',
		chain int(10) NOT NULL DEFAULT '0',
		stamper int(10) NOT NULL DEFAULT '0',
		banshee int(10) NOT NULL DEFAULT '0',
		lusty int(10) NOT NULL DEFAULT '0'
    );*/

new const szTable[] = "logros_ze";

new g_id[ 33 ];
new Handle:g_hTuple;

native zp_set_exp(id, value)
enum
{
	REGISTRAR_USUARIO,
	LOGUEAR_USUARIO,
	GUARDAR_DATOS
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

#define MIN_PLAYERS 3

new g_maxplayers

forward archivement_butom(id)
forward archivement_frozen(id)
forward archivement_stamper(id)
forward archivement_banshee(id)
forward archivement_lusty(id)
forward archivement_menu(id)



const KEYSMENU = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0

new const logro_finish[] = "logro_finish.wav"
new const logro_avance[] = "logro_avance2.wav"

enum _:button
{
	button_desc[100],
	button_press,
	button_exp
}


new const logros_boton[][button] =
{
	{"Preciona 50 veces el boton de Escape",     50,     50},
	{"preciona 250 veces el Boton de Escape",    250,    100},
	{"Preciona 500 veces el boton de Escape",    500,   200},
	{"Preciona 1000 veces el boton de Escape",   1000,   500},
	{"Preciona 2500 veces el boton de Escape",   2500,  1000}
}

enum _:matados
{
	kills_desc[100],
	kills,
	kills_exp
}

new const logros_kills[][matados] =
{
	{"Mata 20 Zombies",    20,   50},
	{"Mata 100 Zombies",   100,  75},
	{"Mata 500 Zombies",    500,  150},
	{"Mata 1000 Zombies",    1250, 200},
	{"Mata 2500 Zombies",    2500, 350}
}

enum _:infeccion
{
	infect_desc[100],
	infect,
	infect_exp
}

new const logros_infect[][infeccion] =
{
	{"Infecta 25 Humanos",    25,   50},
	{"Infecta 75 Humanos",    75,  75},
	{"Infecta 250 Humanos",    250,  150},
	{"Infecta 750 Humanos",    750, 200},
	{"Infecta 2000 Humanos",    2000, 350}
}

enum _:congelacion
{
	frozen_desc[100],
	frozen,
	frozen_exp
}

new const logros_frozen[][congelacion] =
{
	{"Congela 25 Zombies",    25,   50},
	{"Congela 75 Zombies",   75,   75},
	{"Congela 250 Zombies",    250,   150},
	{"Congela 750 Zombies",    750,   200},
	{"Congela 2000 Zombies",   2000,  350}
}

enum _:chain_g
{
	chain_desc[100],
	chain,
	chain_exp
}

new const logros_chain[][chain_g] =
{
	{"Mata 5 Zombies con Granada Chain",      5,     50},
	{"Mata 20 Zombies con Granada Chain",     20,    75},
	{"Mata 75 Zombies con Granada Chain",     75,    150},
	{"Mata 150 Zombies con Granada Chain",    150,   300},
	{"Mata 250 Zombies con Granada Chain",    250,   500}
}

enum _:stamper_g
{
	stamper_desc[100],
	stamper,
	stamper_exp
}

new const logros_stamper[][stamper_g] =
{
	{"Relentiza 20 Humanos con Zombie Stamper",       20,     50},
	{"Relentiza 50 Humanos con Zombie Stamper",      50,     75},
	{"Relentiza 100 Humanos con Zombie Stamper",    100,    150},
	{"Relentiza 250 Humanos con Zombie Stamper",    250,    300},
	{"Relentiza 750 Humanos con Zombie Stamper",    750,    500}
}


enum _:banshee_g
{
	banshee_desc[100],
	banshee,
	banshee_exp
}

new const logros_banshee[][banshee_g] =
{
	{"Atrapa 20 Humanos con Zombie Banshee",       5,     50},
	{"Atrapa 50 Humanos con Zombie Banshee",      20,     75},
	{"Atrapa 100 Humanos con Zombie Banshee",    50,    150},
	{"Atrapa 250 Humanos con Zombie Banshee",    100,    300},
	{"Atrapa 750 Humanos con Zombie Banshee",    250,    500}
}
enum _:lusty_g
{
	lusty_desc[100],
	lusty,
	lusty_exp
}

new const logros_lusty[][lusty_g] =
{
	{"Contagia 20 Humanos Siendo Invisible",      20,     75},
	{"Atrapa 100 Humanos Siendo Invisible",    50,    150},
	{"Atrapa 250 Humanos Siendo Invisible",    100,    300},
	{"Atrapa 750 Humanos Siendo Invisible",    250,    500}
}


new const chain_grenade[] = "grenade"

new g_button[33], g_kills[33], g_infect[33], g_frozen[33], g_chain[33], g_stamper[33], g_banshee[33], g_lusty[33]



public plugin_init()
{
	register_plugin("Logros", "0.1", "Randro")

	register_event("DeathMsg", "event_death", "a")

	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")

	register_clcmd("say /logros", "menu_logros")
	//register_clcmd("say v", 	"logros_test")

	g_maxplayers = get_maxplayers()	

	MySQL_Init()
}

public plugin_precache()
{
	precache_sound(logro_avance)
	precache_sound(logro_finish)
}


/*****************************************************************************
----------------------------[Native Logros]------------------------------------
*****************************************************************************/
public archivement_butom(id)
{
	//if(zp_get_class(id) >= ZOMBIE) return;
	
	g_button[id]++
	check_button(id)
}
public zp_user_infected_post(id, infector, nemesis)
{
	//if(getUsers() <= MIN_PLAYERS) return;
	if(!infector)
		return;

	g_infect[infector]++
	chequear_infect(infector)
}

public archivement_frozen(id)
{
	//if(getUsers() <= MIN_PLAYERS) return;
	g_frozen[id]++
	chequear_frozen(id)
}
public archivement_stamper(id)
{
	//if(getUsers() <= MIN_PLAYERS) return;
	g_stamper[id]++
	chequear_stamper(id)
}
public archivement_banshee(id)
{
	//if(getUsers() <= MIN_PLAYERS) return;
	g_banshee[id]++
	chequear_banshee(id)
}
public archivement_lusty(id)
{
	//if(getUsers() <= MIN_PLAYERS) return;
	g_lusty[id]++
	chequear_lusty(id)
}
/************************************************************************************/

public event_death()
{
	static attacker, victim, weapon_name[10];
	attacker = read_data(1)
	victim = read_data(2)
	read_data(4, weapon_name, charsmax(weapon_name))
	
	if(attacker == victim || !is_user_connected(attacker) || !is_user_connected(victim) || getUsers() <= MIN_PLAYERS)
		return
	
	if(zp_get_class(victim) >= ZOMBIE)
	{
		g_kills[attacker]++
		chequear_kills(attacker)
	}

	if(HUMAN <= zp_get_class(attacker) < SURVIVOR && equal(weapon_name, chain_grenade))
	{
		g_chain[attacker]++
		chequear_chain(attacker)
	}
}

/*****************************************************************************
----------------------------[Logros Check]------------------------------------
*****************************************************************************/
public check_button(id)
{


	for(new i = 0; i < sizeof(logros_boton); i++)
	{
		if(g_button[id] == logros_boton[i][button_press])
		{
			new nick[32]
			get_user_name(id, nick, charsmax(nick))
			chatcolor(0, "^4[ZE]^3%s ^1Completó el Logro ^3%s", nick, logros_boton[i][button_desc])
			client_cmd(0, "spk sound/%s", logro_finish)
			zp_set_exp(id, logros_boton[i][button_exp])
		}
		
	}
	for(new i = 0; i < sizeof(logros_boton); i++)
	{
		if(g_button[id] < logros_boton[i][button_press])
		{
			chatcolor(id, "^4[ZE] ^1Avance de Logro: ^3%s ^4%d ^1de ^4%d",  logros_boton[i][button_desc], g_button[id], logros_boton[i][button_press])
			client_cmd(id, "spk sound/%s", logro_avance)
			break;
		}
		
	}
}

public chequear_kills(id)
{

	for(new i = 0; i < sizeof(logros_kills); i++)
	{
		if(g_kills[id] == logros_kills[i][kills])
		{
			new nick[32]
			get_user_name(id, nick, charsmax(nick))
			chatcolor(0, "^4[ZE]^3%s ^1Completó el Logro ^3%s", nick, logros_kills[i][kills_desc])
			client_cmd(0, "spk sound/%s", logro_finish)
			zp_set_exp(id, logros_kills[i][kills_exp])
		}
		
	}
	for(new i = 0; i < sizeof(logros_kills); i++)
	{
		if(g_kills[id] < logros_kills[i][kills])
		{
			chatcolor(id, "^4[ZE] ^1Avance de Logro: ^3%s ^4%d ^1de ^4%d",  logros_kills[i][kills_desc], g_kills[id], logros_kills[i][kills])
			client_cmd(id, "spk sound/%s", logro_avance)
			break;
		}
		
	}
}

public chequear_infect(id)
{

	for(new i = 0; i < sizeof(logros_infect); i++)
	{
		if(g_infect[id] == logros_infect[i][kills])
		{
			new nick[32]
			get_user_name(id, nick, charsmax(nick))
			chatcolor(0, "^4[ZE]^3%s ^1Completó el Logro ^3%s", nick, logros_infect[i][infect_desc])
			client_cmd(0, "spk sound/%s", logro_finish)
			zp_set_exp(id, logros_infect[i][infect_exp])
		}
		
	}
	for(new i = 0; i < sizeof(logros_infect); i++)
	{
		if(g_infect[id] < logros_infect[i][kills])
		{
			
			chatcolor(id, "^4[ZE] ^1Avance de Logro: ^3%s ^4%d ^1de ^4%d",  logros_infect[i][infect_desc], g_infect[id], logros_infect[i][infect])
			client_cmd(id, "spk sound/%s", logro_avance)
			break;
		}
		
	}
	
}
public chequear_frozen(id)
{

	for(new i = 0; i < sizeof(logros_frozen); i++)
	{
		if(g_frozen[id] == logros_frozen[i][frozen])
		{
			new nick[32]
			get_user_name(id, nick, charsmax(nick))
			chatcolor(0, "^4[ZE]^3%s ^1Completó el Logro ^3%s", nick, logros_frozen[i][frozen_desc])
			client_cmd(0, "spk sound/%s", logro_finish)
			zp_set_exp(id, logros_frozen[i][frozen_exp])
		}
		
	}
	for(new i = 0; i < sizeof(logros_frozen); i++)
	{
		if(g_frozen[id] < logros_frozen[i][frozen])
		{
			chatcolor(id, "^4[ZE] ^1Avance de Logro: ^3%s ^4%d ^1de ^4%d",  logros_frozen[i][frozen_desc], g_frozen[id], logros_frozen[i][frozen])
			client_cmd(id, "spk sound/%s", logro_avance)
			break;
		}
		
	}
	
}
public chequear_chain(id)
{

	for(new i = 0; i < sizeof(logros_chain); i++)
	{
		if(g_chain[id] == logros_chain[i][chain])
		{
			new nick[32]
			get_user_name(id, nick, charsmax(nick))
			chatcolor(0, "^4[ZE]^3%s ^1Completó el Logro ^3%s", nick, logros_chain[i][chain_desc])
			client_cmd(0, "spk sound/%s", logro_finish)
			zp_set_exp(id, logros_frozen[i][frozen_exp])
		}
		
	}
	for(new i = 0; i < sizeof(logros_chain); i++)
	{
		if(g_chain[id] < logros_chain[i][chain])
		{
			chatcolor(id, "^4[ZE] ^1Avance de Logro: ^3%s, ^4%d ^1de ^4%d",  logros_chain[i][chain_desc], g_chain[id], logros_chain[i][chain])
			client_cmd(id, "spk sound/%s", logro_avance)
			break;
		}		
	}
}

public chequear_stamper(id)
{

	for(new i = 0; i < sizeof(logros_stamper); i++)
	{
		if(g_stamper[id] == logros_stamper[i][stamper])
		{
			new nick[32]
			get_user_name(id, nick, charsmax(nick))
			chatcolor(0, "^4[ZE]^3%s ^1Completó el Logro ^3%s", nick, logros_stamper[i][stamper_desc])
			client_cmd(0, "spk sound/%s", logro_finish)
			zp_set_exp(id, logros_stamper[i][stamper_exp])
		}		
	}
	for(new i = 0; i < sizeof(logros_stamper); i++)
	{
		if(g_stamper[id] < logros_stamper[i][stamper])
		{
			chatcolor(id, "^4[ZE] ^1Avance de Logro: ^3%s ^4%d ^1de ^4%d",  logros_stamper[i][stamper_desc], g_stamper[id], logros_stamper[i][stamper])
			client_cmd(id, "spk sound/%s", logro_avance)
			break;
		}
	}
}

public chequear_banshee(id)
{

	for(new i = 0; i < sizeof(logros_banshee); i++)
	{
		if(g_banshee[id] == logros_banshee[i][banshee])
		{
			new nick[32]
			get_user_name(id, nick, charsmax(nick))
			chatcolor(0, "^4[ZE]^3%s ^1Completó el Logro ^3%s", nick, logros_banshee[i][banshee_desc])
			client_cmd(0, "spk sound/%s", logro_finish)
			zp_set_exp(id, logros_banshee[i][banshee_exp])
		}		
	}
	for(new i = 0; i < sizeof(logros_banshee); i++)
	{
		if(g_banshee[id] < logros_banshee[i][banshee])
		{
			chatcolor(id, "^4[ZE] ^1Avance de Logro: ^3%s ^4%d ^1de ^4%d",  logros_banshee[i][banshee_desc], g_banshee[id], logros_banshee[i][banshee])
			client_cmd(id, "spk sound/%s", logro_avance)
			break;
		}
	}
}

public chequear_lusty(id)
{

	for(new i = 0; i < sizeof(logros_lusty); i++)
	{
		if(g_lusty[id] == logros_lusty[i][lusty])
		{
			new nick[32]
			get_user_name(id, nick, charsmax(nick))
			chatcolor(0, "^4[ZE]^3%s ^1Completó el Logro ^3%s", nick, logros_lusty[i][lusty_desc])
			client_cmd(0, "spk sound/%s", logro_finish)
			zp_set_exp(id, logros_lusty[i][lusty_exp])
		}		
	}
	for(new i = 0; i < sizeof(logros_lusty); i++)
	{
		if(g_lusty[id] < logros_lusty[i][lusty])
		{
			chatcolor(id, "^4[ZE] ^1Avance de Logro: ^3%s ^4%d ^1de ^4%d",  logros_lusty[i][lusty_desc], g_lusty[id], logros_lusty[i][lusty])
			client_cmd(id, "spk sound/%s", logro_avance)
			break;
		}
	}
}
/*****************************************************************************
----------------------------[MENU LOGROS]------------------------------------
*****************************************************************************/

public archivement_menu(id)
	menu_logros(id)
public menu_logros(id)
{

	static menu[900]

	formatex(menu, charsmax(menu), "\rSistema de Logros")
	new gMenu = menu_create(menu, "handler_logros");
	
	formatex(menu, charsmax(menu), "Humanos")
	menu_additem(gMenu, menu, "");

	formatex(menu, charsmax(menu), "Zombies")
	menu_additem(gMenu, menu, "");
			
	menu_display(id, gMenu, 0);
	return PLUGIN_HANDLED;
}

public logros_humano(id)
{
	static menu[900]

	formatex(menu, charsmax(menu), "\rLogros Humano")
	new gMenu = menu_create(menu, "handler_humano");

	for(new i = 0; i < sizeof(logros_boton); i++)
	{
		if(g_button[id] < logros_boton[i][button_press])
		{
			formatex(menu, charsmax(menu), "El Primero en LLegar^n\d%s \r(%d de %d)", logros_boton[i][button_desc],g_button[id], logros_boton[i][button_press])
			menu_additem(gMenu, menu, "");
			break;
		}
		
	}
	for(new i = 0; i < sizeof(logros_kills); i++)
	{
		if(g_kills[id] < logros_kills[i][kills])
		{
			formatex(menu, charsmax(menu), "Aniquilador^n\d%s \r(%d de %d)", logros_kills[i][kills_desc],g_kills[id], logros_kills[i][kills])
			menu_additem(gMenu, menu, "");
			break;
		}
		
	}

	for(new i = 0; i < sizeof(logros_frozen); i++)
	{
		if(g_frozen[id] < logros_frozen[i][frozen])
		{
			formatex(menu, charsmax(menu), "Freezer^n\d%s \r(%d de %d)", logros_frozen[i][frozen_desc],g_frozen[id], logros_frozen[i][frozen])
			menu_additem(gMenu, menu, "");
			break;
		}
		
	}
	for(new i = 0; i < sizeof(logros_chain); i++)
	{
		if(g_chain[id] < logros_chain[i][chain])
		{
			formatex(menu, charsmax(menu), "Chain Man^n\d%s \r(%d de %d)", logros_chain[i][chain_desc],g_chain[id], logros_chain[i][chain])
			menu_additem(gMenu, menu, "");
			break;
		}
		
	}
  	
	menu_display(id, gMenu, 0);
	return PLUGIN_HANDLED;
}

public logros_zombie(id)
{

	static menu[900]

	formatex(menu, charsmax(menu), "\rLogros Zombies")
	new gMenu = menu_create(menu, "handler_zombie");

	for(new i = 0; i < sizeof(logros_infect); i++)
	{
		if(g_infect[id] < logros_infect[i][infect])
		{
			formatex(menu, charsmax(menu), "Infectador^n\d%s \r(%d de %d)", logros_infect[i][infect_desc], g_infect[id], logros_infect[i][infect])
			menu_additem(gMenu, menu, "");
			break;
		}	
	}
	for(new i = 0; i < sizeof(logros_stamper); i++)
	{
		if(g_stamper[id] < logros_stamper[i][infect])
		{
			formatex(menu, charsmax(menu), "Stamper^n\d%s \r(%d de %d)", logros_stamper[i][stamper_desc], g_stamper[id], logros_stamper[i][stamper])
			menu_additem(gMenu, menu, "");
			break;
		}
		
	}
	for(new i = 0; i < sizeof(logros_banshee); i++)
	{
		if(g_banshee[id] < logros_banshee[i][banshee])
		{
			formatex(menu, charsmax(menu), "The Witch^n\d%s \r(%d de %d)", logros_banshee[i][banshee_desc], g_banshee[id], logros_banshee[i][banshee])
			menu_additem(gMenu, menu, "");
			break;
		}
		
	}
	for(new i = 0; i < sizeof(logros_lusty); i++)
	{
		if(g_lusty[id] < logros_lusty[i][lusty])
		{
			formatex(menu, charsmax(menu), "Nadie Me Ve^n\d%s \r(%d de %d)", logros_lusty[i][lusty_desc], g_lusty[id], logros_lusty[i][lusty])
			menu_additem(gMenu, menu, "");
			break;
		}
		
	}
  	
	menu_display(id, gMenu, 0);
	return PLUGIN_HANDLED;
}

/****************************************************************************
----------------------------[HANDLER LOGROS]---------------------------------
****************************************************************************/
public handler_logros(id, menu, key)    
{
	if ( key == MENU_EXIT) 
	{
	    menu_destroy(menu);
	    return PLUGIN_HANDLED;
	}
	switch(key)
	{
		case 0:
			logros_humano(id)
		case 1:
			logros_zombie(id)
	}
	
	return PLUGIN_HANDLED;
}

public handler_humano(id, menu, key)    
{
	if ( key == MENU_EXIT) 
	{
	    menu_destroy(menu);
	    return PLUGIN_HANDLED;
	}

	
	return PLUGIN_HANDLED;
}

public handler_zombie(id, menu, key)    
{
	if ( key == MENU_EXIT) 
	{
	    menu_destroy(menu);
	    return PLUGIN_HANDLED;
	}

	
	return PLUGIN_HANDLED;
}

/***************************************************************/


public client_disconnected(id)
{

	if( g_iStatus[ id ] == LOGUEADO )
	{
		guardar_datos( id );
		g_iStatus[ id ] = NO_LOGUEADO;
	}
	
}

public client_putinserver(id)
	g_iStatus[id] = NO_LOGUEADO;


public guardar_datos( id ) 
{
	if(!advacc_user_logged(id) || g_iStatus[ id ] != LOGUEADO)
		return;

	new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];
	iData[ 0 ] = id;
	iData[ 1 ] = GUARDAR_DATOS;
	//aca es donde guardas tus datos, agregas "," coma y quieres guardar mas datos EJ ammopacks='%d', rango='%d'
	formatex( szQuery, charsmax( szQuery ), "UPDATE %s SET button='%d', kills='%d', infect='%d', frozen='%d', chain='%d', stamper='%d', banshee='%d', lusty='%d' WHERE id_cuenta='%d'", 
		szTable, g_button[ id ], g_kills[ id ], g_infect[ id ], g_frozen[ id ], g_chain[ id ], g_stamper[id], g_banshee[id], g_lusty[id], g_id[ id ] );
	SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
}

//en
public event_round_start(){
	for(new i = 1; i <= g_maxplayers; ++i) {
		if( !advacc_user_logged(i) || g_iStatus[ i ] != LOGUEADO )
				continue;

		guardar_datos( i );
	}
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
		log_to_file( "SQL_LOG_TQ.txt", "Error en la consulta al MySQL Logros [%i]: %s", error2, error );
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
				g_button[ id ] = SQL_ReadResult( Query, 1 );
				g_kills[ id ] = SQL_ReadResult( Query , 2 );
				g_infect[ id ] = SQL_ReadResult( Query , 3 );
				g_frozen[ id ] = SQL_ReadResult( Query , 4 );
				g_chain[ id ] = SQL_ReadResult( Query , 5 );
				g_stamper[id] = SQL_ReadResult( Query , 6 );
				g_banshee[id] = SQL_ReadResult( Query , 7 );
				g_lusty[id] = SQL_ReadResult( Query , 8 );


				client_print_color(id, print_team_blue, "Tu ID es %d pueden usarla para referenciarte con ella.", g_id[ id ]);
				client_print_color(id, print_team_blue, "Tu ID es %d pueden usarla para referenciarte con ella.", g_id[ id ]);
				client_print_color(id, print_team_blue, "Tu ID es %d pueden usarla para referenciarte con ella.", g_id[ id ]);
				client_print_color(id, print_team_blue, "Tu ID es %d pueden usarla para referenciarte con ella.", g_id[ id ]);
				client_print_color(id, print_team_blue, "Tu ID es %d pueden usarla para referenciarte con ella.", g_id[ id ]);
				
				g_iStatus[ id ] = LOGUEADO;
			}
			else
			{
				new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];
				
				iData[ 0 ] = id;
				iData[ 1 ] = REGISTRAR_USUARIO;
				
				formatex( szQuery, charsmax( szQuery ), "INSERT INTO %s (id_cuenta, button, kills, infect, frozen, chain, stamper, banshee, lusty) VALUES (%d, %d, %d, %d, %d, %d, %d, %d, %d)", 
					szTable, g_id[ id ], g_button[ id ], g_kills[ id ], g_infect[id], g_frozen[id], g_chain[id], g_stamper[id], g_banshee[id], g_lusty[id]);
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
				new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];
				
				iData[ 0 ] = id;
				iData[ 1 ] = LOGUEAR_USUARIO;

				formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE id_cuenta='%d'", szTable, g_id[ id ] );
				SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
			}
		}
		case GUARDAR_DATOS:
		{
			if( failstate < TQUERY_SUCCESS )
				console_print( id, "Error en el guardado de datos." );
			else
			console_print( id, "Datos guardados." );
		}
		
	}
}

//al final del plugin

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


public getUsers(){
	new conect = 0;
	for( new i = 0; i <= 32 ; ++i )
	{
		if(is_user_connected(i))
			++conect;
	}
	return conect;
}




/*

public menu_logros1(id)
{
	static menu[MAX_MENU_LENGTH], len;

	len = 0
	
	// Title
	len += formatex(menu[len], charsmax(menu) - len, "\rSistema de Logros^n^n");
	
	len += formatex(menu[len], charsmax(menu) - len, "\r1.\w El Primero en LLegar^n");
	if(g_button[id] <= logros_boton[0][button_press])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_boton[0][button_desc],g_button[id], logros_boton[0][button_press])
	}
	else if(logros_boton[0][button_press] < g_button[id] <= logros_boton[1][button_press])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_boton[1][button_desc],g_button[id], logros_boton[1][button_press])
	}
	else if(logros_boton[1][button_press] < g_button[id] <= logros_boton[2][button_press])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_boton[2][button_desc],g_button[id], logros_boton[2][button_press])
	}
	else if(logros_boton[2][button_press] < g_button[id] <= logros_boton[3][button_press])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_boton[3][button_desc],g_button[id], logros_boton[3][button_press])
	}
	else if(logros_boton[3][button_press] < g_button[id] <= logros_boton[4][button_press])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_boton[4][button_desc],g_button[id], logros_boton[4][button_press])
	}
	else if(g_button[id] >= logros_boton[4][button_press])
		len += formatex(menu[len], charsmax(menu) - len, "\d -\rCOMPLETADO^n")
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	
	len += formatex(menu[len], charsmax(menu) - len, "\r2.\w Aniquilador^n");
	if(g_kills[id] <= logros_kills[0][kills])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_kills[0][kills_desc],g_kills[id], logros_kills[0][kills])
	}
	else if(logros_kills[0][kills] < g_kills[id] <= logros_kills[1][kills])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_kills[1][kills_desc],g_kills[id], logros_kills[1][kills])
	}
	else if(logros_kills[1][kills] < g_kills[id] <= logros_kills[2][kills])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_kills[2][kills_desc],g_kills[id], logros_kills[2][kills])
	}
	else if(logros_kills[2][kills] < g_kills[id] <= logros_kills[3][kills])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_kills[3][kills_desc],g_kills[id], logros_kills[3][kills])
	}
	else if(logros_kills[3][kills] < g_kills[id] <= logros_kills[4][kills])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_kills[4][kills_desc],g_kills[id], logros_kills[4][kills])
	}
	else if(g_kills[id] >= logros_kills[4][kills])
		len += formatex(menu[len], charsmax(menu) - len, "\d -\r(COMPLETADO)^n")

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	

	len += formatex(menu[len], charsmax(menu) - len, "\r3.\w Infectador^n");
	if(g_infect[id] <= logros_infect[0][infect])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_infect[0][infect_desc],g_infect[id], logros_infect[0][infect])
	}
	else if(logros_infect[0][infect] < g_infect[id] <= logros_infect[1][infect])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_infect[1][infect_desc],g_infect[id], logros_infect[1][infect])
	}
	else if(logros_infect[1][infect] < g_infect[id] <= logros_infect[2][infect])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_infect[2][infect_desc],g_infect[id], logros_infect[2][infect])
	}
	else if(logros_infect[2][infect] < g_infect[id] <= logros_infect[3][infect])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_infect[3][infect_desc],g_infect[id], logros_infect[3][infect])
	}
	else if(logros_infect[3][infect] < g_infect[id] <= logros_infect[4][infect])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_infect[4][infect_desc],g_infect[id], logros_infect[4][infect])
	}
	else if( g_infect[id] >= logros_infect[4][infect])
		len += formatex(menu[len], charsmax(menu) - len, "\d -\rCOMPLETADO^n")

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	len += formatex(menu[len], charsmax(menu) - len, "\r4.\w Freezer^n");
	if(g_frozen[id] <= logros_frozen[0][frozen])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_frozen[0][frozen_desc],g_frozen[id], logros_frozen[0][frozen])
	}
	else if(logros_frozen[0][frozen] < g_frozen[id] <= logros_frozen[1][frozen])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_frozen[1][frozen_desc],g_frozen[id], logros_frozen[1][frozen])
	}
	else if(logros_frozen[1][frozen] < g_frozen[id] <= logros_frozen[2][frozen])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_frozen[2][frozen_desc],g_frozen[id], logros_frozen[2][frozen])
	}
	else if(logros_frozen[2][frozen] < g_frozen[id] <= logros_frozen[3][frozen])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_frozen[3][frozen_desc],g_frozen[id], logros_frozen[3][frozen])
	}
	else if(logros_frozen[3][frozen] < g_frozen[id] <= logros_frozen[4][frozen])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_frozen[4][frozen_desc],g_frozen[id], logros_frozen[4][frozen])
	}
	else if( g_frozen[id] >= logros_frozen[4][frozen])
		len += formatex(menu[len], charsmax(menu) - len, "\d -\rCOMPLETADO^n")

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	len += formatex(menu[len], charsmax(menu) - len, "\r5.\w Chain Man^n");
	if(g_chain[id] <= logros_chain[0][chain])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_chain[0][chain_desc],g_chain[id], logros_chain[0][chain])
	}
	else if(logros_chain[0][chain] < g_chain[id] <= logros_chain[1][chain])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_chain[1][chain_desc],g_chain[id], logros_chain[1][chain])
	}
	else if(logros_chain[1][chain] < g_chain[id] <= logros_chain[2][chain])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_chain[2][chain_desc],g_chain[id], logros_chain[2][chain])
	}
	else if(logros_chain[2][chain] < g_chain[id] <= logros_chain[3][chain])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_chain[3][chain_desc],g_chain[id], logros_chain[3][chain])
	}
	else if(logros_chain[3][chain] < g_chain[id] <= logros_chain[4][chain])
	{
		len += formatex(menu[len], charsmax(menu) - len, "\d -%s \r(%d de %d)^n", logros_chain[4][chain_desc],g_chain[id], logros_chain[4][chain])
	}
	else if( g_chain[id] >= logros_chain[4][chain])
		len += formatex(menu[len], charsmax(menu) - len, "\d -\rCOMPLETADO^n")
	
	
	show_menu(id, KEYSMENU, menu, -1, "Game Menu")
   
}



public menu_logros(id)
{

	static menu[900]

	formatex(menu, charsmax(menu), "\rSistema de Logros")
	new gMenu = menu_create(menu, "handler_logros");
	for(new i = 0; i < sizeof(logros_boton); i++)
	{
		if(g_button[id] < logros_boton[i][button_press])
		{
			formatex(menu, charsmax(menu), "El Primero en LLegar^n\d%s \r(%d de %d)", logros_boton[i][button_desc],g_button[id], logros_boton[i][button_press])
			menu_additem(gMenu, menu, "");
			break;
		}
		
	}
	for(new i = 0; i < sizeof(logros_kills); i++)
	{
		if(g_kills[id] < logros_kills[i][kills])
		{
			formatex(menu, charsmax(menu), "Aniquilador^n\d%s \r(%d de %d)", logros_kills[i][kills_desc],g_kills[id], logros_kills[i][kills])
			menu_additem(gMenu, menu, "");
			break;
		}
		
	}
	for(new i = 0; i < sizeof(logros_infect); i++)
	{
		if(g_infect[id] < logros_infect[i][infect])
		{
			formatex(menu, charsmax(menu), "Infectador^n\d%s \r(%d de %d)", logros_infect[i][infect_desc], g_infect[id], logros_infect[i][infect])
			menu_additem(gMenu, menu, "");
			break;
		}
		
	}

	for(new i = 0; i < sizeof(logros_chain); i++)
	{
		if(g_frozen[id] < logros_frozen[i][frozen])
		{
			formatex(menu, charsmax(menu), "Freezer^n\d%s \r(%d de %d)", logros_frozen[i][frozen_desc],g_frozen[id], logros_frozen[i][frozen])
			menu_additem(gMenu, menu, "");
			break;
		}
		
	}
	for(new i = 0; i < sizeof(logros_chain); i++)
	{
		if(g_chain[id] < logros_chain[i][chain])
		{
			formatex(menu, charsmax(menu), "Chain Man^n\d%s \r(%d de %d)", logros_chain[i][chain_desc],g_chain[id], logros_chain[i][chain])
			menu_additem(gMenu, menu, "");
			break;
		}
		
	}
  	

	menu_display(id, gMenu, 0);
	return PLUGIN_HANDLED;
}

public handler_logros(id, menu, key)    
{
	if ( key == MENU_EXIT) 
	{
	    menu_destroy(menu);
	    return PLUGIN_HANDLED;
	}

	
	return PLUGIN_HANDLED;
}
*/