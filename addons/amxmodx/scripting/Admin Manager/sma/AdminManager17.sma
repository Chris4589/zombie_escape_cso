/*	CHANGELOG:
		1.0 [16/11/2019] - Creación de plugin.
		1.1 [18/11/2019] - Se agregaron cvars para establecer limite de tiempo de para expulsar al administrador y des/activar hooksay
		1.2 [05/12/2019] - Se modificaron algunas cosas, se agregaron natives y se agregó hook say team + una cvar del mismo.
		1.3 [03/04/2020] - Se agregó el uso de bits y se mejoraron/cambiaron algunas cosas.
		1.4 [18/05/2020] - Se removió el sistema de password vía messagemode ahora es vía setinfo y se acomodaron algunas cosas.
		1.5 [21/05/2020] - Se actualizó el sistema de cargado de administradores.
		1.6 [02/01/2021] - Se corrigió el bug que no cargaba los administradores y se removió código innecesario.
		1.7 [31/08/2021] - Se corrigió un bug que no cargaba todos los administradores/Se agregó para que el plugin funcione con el amx apagado y un comando para recargar la lista de administradores in-game.

	PERFIL AMX-ES: https://amxmodx-es.com/Skylar
	PERFIL STEAM: https://steamcommunity.com/id/JTribbiani/
*/

#include <amxmodx>
#include <amxmisc>
#include <AdminManager_DefinesEnums>
#include <fakemeta>
#include <unixtime>

new const szPlugin[ ][ ] = { "Admin Manager", "1.7", "Sky^^" };
new const szPrefix[ ] = "[Zombie Escape]";

/* ======================================================== */

#define NAME_FILE "admin_manager.ini"
#define MAX_ADMINS 100

new g_AdminData[ MAX_ADMINS ][ ADMIN_DATA ], g_UserData[ MAX_PLAYERS + 1 ][ USER_DATA ];
new g_AdminID[ MAX_PLAYERS + 1 ];
new g_Cvars[ CVARS ], g_bIsBit[ USER_BITS ];
new g_AdminCount;

/* ======================================================== */

public plugin_init( ) {
	plugin_load_admins( );

	register_plugin( szPlugin[ 0 ], szPlugin[ 1 ], szPlugin[ 2 ] );
	//register_forward( FM_ClientUserInfoChanged, "forward_ClientUserInfoChanged" );

	register_clcmd( "say /admins", "clcmd_Admins" );
	register_clcmd( "say /mi_admin", "clcmd_MyAdmin" );
	register_concmd( "am_reload_admins", "concmd_ReloadAdmins", ADMIN_RCON );

	g_Cvars[ CVAR_PASSWORD_FIELD ] = register_cvar( "am_password_field", "_pw", FCVAR_PROTECTED );
}
public plugin_natives( ) {
	register_native( "am_is_admin", "native_IsAdmin", 1 );
	register_native( "am_is_punished", "native_IsPunished" );
	register_native( "am_get_type", "native_GetType" );
}
public plugin_cfg( ) {
	if( is_plugin_loaded( "Pause Plugins" ) != -1 )
		server_cmd( "amx_pausecfg add ^"%s^"", szPlugin );
}
plugin_load_admins( ) {
	new szConfigDir[ 64 ]; get_configsdir( szConfigDir, charsmax( szConfigDir ) );
	format( szConfigDir, charsmax( szConfigDir ), "%s/%s", szConfigDir, NAME_FILE );

	if( !file_exists( szConfigDir ) ) {
		log_amx( "%s El archivo '%s' no existe.", szPrefix, NAME_FILE );
		return;
	}

	new szTypes[ 32 ][ 32 ], szFlags[ 32 ][ 32 ];
	new iTypes = 0, iSection = 0, i;
	
	static szLineData[ 1024 ], szKey[ 960 ], szValue[ 960 ];

	new szFile = fopen( szConfigDir, "rt" );
	new iLine;

	if( szFile ) {
		static szAuth[ MAX_PLAYER_AUTHID_LENGTH ], szPw[ MAX_PLAYER_PW_LENGTH ], szType[ MAX_PLAYER_TYPE_LENGTH ],
		szDate[ MAX_PLAYER_DATE_LENGTH ], szPunish[ MAX_PLAYER_DATE_LENGTH ], szReason[ MAX_PLAYER_REASON_LENGTH ];

		while( !feof( szFile ) ) {
			fgets( szFile, szLineData, charsmax( szLineData ) );
			trim( szLineData );
			iLine++;

			if( !szLineData[ 0 ] || szLineData[ 0 ] == ';' ) continue;

			if( szLineData[ 0 ] == '[' ) {
				iSection++;
				continue;
			}

			if( iSection == 1 ) {
				iTypes++;

				strtok( szLineData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=' );
				trim( szKey ); trim( szValue );

				copy( szTypes[ iTypes ], charsmax( szTypes[ ] ), szKey );
				copy( szFlags[ iTypes ], charsmax( szFlags[ ] ), szValue );
			}

			if( iSection == 2 ) {
				parse( szLineData, szAuth, charsmax( szAuth ), szPw, charsmax( szPw ), szType, charsmax( szType ), szDate, charsmax( szDate ), szPunish, charsmax( szPunish ),
				szReason, charsmax( szReason ) );

				replace_all( szDate, charsmax( szDate ), "/", " " );
				replace_all( szPunish, charsmax( szPunish ), "/", " " );
			
				new szDay[ 3 ], szMonth[ 3 ], szYear[ 5 ];
				parse( szDate, szDay, charsmax( szDay ), szMonth, charsmax( szMonth ), szYear, charsmax( szYear ) );

				new szD[ 3 ], szM[ 3 ], szY[ 5 ];
				parse( szPunish, szD, charsmax( szD ), szM, charsmax( szM ), szY, charsmax( szY ) );

				i = 0;
				while( i++ < iTypes ) {
					if( equal( szType, szTypes[ i ] )/* == 1*/ ) {
						g_AdminCount++;

						g_AdminData[ g_AdminCount ][ ADMIN_AUTH ] = EOS;
						g_AdminData[ g_AdminCount ][ ADMIN_PW ] = EOS;
						g_AdminData[ g_AdminCount ][ ADMIN_TYPE ] = EOS;
						g_AdminData[ g_AdminCount ][ ADMIN_FLAGS ] = EOS

						copy( g_AdminData[ g_AdminCount ][ ADMIN_AUTH ], charsmax( g_AdminData[ ][ ADMIN_AUTH ] ), szAuth );
						copy( g_AdminData[ g_AdminCount ][ ADMIN_PW ], charsmax( g_AdminData[ ][ ADMIN_PW ] ), szPw );
						copy( g_AdminData[ g_AdminCount ][ ADMIN_TYPE ], charsmax( g_AdminData[ ][ ADMIN_TYPE ] ), szTypes[ i ] );
						copy( g_AdminData[ g_AdminCount ][ ADMIN_FLAGS ], charsmax( g_AdminData[ ][ ADMIN_FLAGS ] ), szFlags[ i ] );

						if( contain( szAuth, "STEAM" ) != -1 ) {
							if( !equali( szPw, "" ) ) g_AdminData[ g_AdminCount ][ ADMIN_STEAM ] = true;
							else g_AdminData[ g_AdminCount ][ ADMIN_STEAM ] = false;
						}
					}
				}

				if( !equal( szDate, "PERMANENTE" ) && get_systime( ) >= TimeToUnix( str_to_num( szYear ), str_to_num( szMonth ), str_to_num( szDay ), 0, 0, 0, UT_TIMEZONE_SERVER ) ) {
					formatex( szLineData, charsmax( szLineData ), ";^"%s^" ^"%s^" ^"%s^" - VENCIDO", szAuth, szPw, szType );
					write_file( szConfigDir, szLineData, iLine - 1 );
				} else {
					replace_all( szDate, charsmax( szDate ), " ", "/" );
					copy( g_AdminData[ g_AdminCount ][ ADMIN_EXPIRATION ], charsmax( g_AdminData[ ][ ADMIN_EXPIRATION ] ), szDate );
				}

				if( !equal( szReason, "" ) && !equal( szPunish, "" ) && get_systime( ) < TimeToUnix( str_to_num( szY ), str_to_num( szM ), str_to_num( szD ), 0, 0, 0, UT_TIMEZONE_SERVER ) ) {
					replace_all( szPunish, charsmax( szPunish ), " ", "/" );
					g_AdminData[ g_AdminCount ][ ADMIN_PUNISH ] = true;
					copy( g_AdminData[ g_AdminCount ][ ADMIN_PUNISHED ], charsmax( g_AdminData[ ][ ADMIN_PUNISHED ] ), szPunish );
					copy( g_AdminData[ g_AdminCount ][ ADMIN_PUNISH_REASON ], charsmax( g_AdminData[ ][ ADMIN_PUNISH_REASON ] ), szReason );
				} else if( !equal( szReason, "" ) && !equal( szPunish, "" ) && get_systime( ) >= TimeToUnix( str_to_num( szY ), str_to_num( szM ), str_to_num( szD ), 0, 0, 0, UT_TIMEZONE_SERVER ) ) {
					formatex( szLineData, charsmax( szLineData ), "^"%s^" ^"%s^" ^"%s^" ^"%s^" ^"^" ^"^"", szAuth, szPw, szType, szDate );
					write_file( szConfigDir, szLineData, iLine - 1 );
					g_AdminData[ g_AdminCount ][ ADMIN_PUNISH ] = false;
				}
			}
		}

		fclose( szFile );
	} else fclose( szFile );

	if( g_AdminCount == 1 ) log_amx( "%s Se cargó un administrador.", szPrefix );
	else log_amx( "%s Se cargaron %d administradores.", szPrefix, g_AdminCount );
}

/* ======================================================== */

public client_putinserver( id ) {
	get_user_name( id, g_UserData[ id ][ USER_NAME ], charsmax( g_UserData[ ][ USER_NAME ] ) );
	get_user_authid( id, g_UserData[ id ][ USER_STEAM ], charsmax( g_UserData[ ][ USER_STEAM ] ) );
	set_bit( g_bIsBit[ IS_CONNECTED ], id );

	new szPwField[ MAX_PLAYER_PW_LENGTH ];
	get_pcvar_string( g_Cvars[ CVAR_PASSWORD_FIELD ], szPwField, charsmax( szPwField ) );
	get_user_info( id, szPwField, g_UserData[ id ][ USER_PW ], charsmax( g_UserData[ ][ USER_PW ] ) );
	
	fn_ResetVars( id );
	fn_GetIdAdmin( id );
}
public client_disconnected( id ) clear_bit( g_bIsBit[ IS_CONNECTED ], id );

public forward_ClientUserInfoChanged( id, buffer ) {
	if( !get_bit( g_bIsBit[ IS_CONNECTED ], id ) ) return FMRES_IGNORED;

	static szNewName[ MAX_NAME_LENGTH ];
	get_user_info( id, "name", szNewName, charsmax( szNewName ) );

	if( equal( g_UserData[ id ][ USER_NAME ], szNewName ) ) return FMRES_IGNORED;

	set_user_info( id, "name", g_UserData[ id ][ USER_NAME ] );
	client_print_color( id, print_team_default, "^3%s^1 Tenes que salir del servidor para cambiarte el nick.", szPrefix );
	return FMRES_IGNORED;
} 

/* ======================================================== */

public fn_ResetVars( id ) {
	if( !get_bit( g_bIsBit[ IS_CONNECTED ], id ) ) return;

	remove_user_flags( id );
	set_user_flags( id, read_flags( "z" ) );

	g_AdminID[ id ] = -1;
	clear_bit( g_bIsBit[ IS_ADMIN ], id );
}
public fn_GetIdAdmin( id ) {
	if( !get_bit( g_bIsBit[ IS_CONNECTED ], id ) ) return;

	new i;
	while( i < g_AdminCount ) {
		i++;

		if( equal( g_UserData[ id ][ USER_NAME ], g_AdminData[ i ][ ADMIN_AUTH ] ) ) {
			if( equali( g_UserData[ id ][ USER_PW ], g_AdminData[ i ][ ADMIN_PW ] ) ) {
				g_AdminID[ id ] = i;
				set_bit( g_bIsBit[ IS_ADMIN ], id );

				if( !g_AdminData[ i ][ ADMIN_PUNISH ] ) {
					remove_user_flags( id, read_flags( "z" ) );
					set_user_flags( id, read_flags( g_AdminData[ i ][ ADMIN_FLAGS ] ) );
				}
			} else server_cmd( "kick #%d ^"Password incorrecta^"", get_user_userid( id ) );
		} else if( equal( g_UserData[ id ][ USER_STEAM ], g_AdminData[ i ][ ADMIN_AUTH ] ) ) {
			if( g_AdminData[ i ][ ADMIN_STEAM ] ) {
				if( equali( g_UserData[ id ][ USER_PW ], g_AdminData[ i ][ ADMIN_PW ] ) ) {
					g_AdminID[ id ] = i;
					set_bit( g_bIsBit[ IS_ADMIN ], id );

					if( !g_AdminData[ i ][ ADMIN_PUNISH ] ) {
						remove_user_flags( id, read_flags( "z" ) );
						set_user_flags( id, read_flags( g_AdminData[ i ][ ADMIN_FLAGS ] ) );
					}
				} else server_cmd( "kick #%d ^"Password incorrecta^"", get_user_userid( id ) );
			} else {
				g_AdminID[ id ] = i;
				set_bit( g_bIsBit[ IS_ADMIN ], id );

				if( !g_AdminData[ i ][ ADMIN_PUNISH ] ) {
					remove_user_flags( id, read_flags( "z" ) );
					set_user_flags( id, read_flags( g_AdminData[ i ][ ADMIN_FLAGS ] ) );
				}
			}
		}
	}
}

public clcmd_MyAdmin( id ) {
	if( !get_bit( g_bIsBit[ IS_ADMIN ], id ) ) return PLUGIN_HANDLED;

	new text[ 300 ], vencimiento[ 100 ], punished[ 100 ];
	if( equal( g_AdminData[ g_AdminID[ id ] ][ ADMIN_EXPIRATION ], "PERMANENTE" ) )
		formatex( vencimiento, charsmax( vencimiento ), "Permanente" );
	else formatex( vencimiento, charsmax( vencimiento ), "%s", g_AdminData[ g_AdminID[ id ] ][ ADMIN_EXPIRATION ] );
	if( g_AdminData[ g_AdminID[ id ] ][ ADMIN_PUNISH ] ) {
		if( !equal( g_AdminData[ g_AdminID[ id ] ][ ADMIN_PUNISHED ], "" ) && !equal( g_AdminData[ g_AdminID[ id ] ][ ADMIN_PUNISH_REASON ], "" ) )
			formatex( punished, charsmax( punished ), "^n^n\d•\w Suspendido hasta el:\y %s^n\d•\w Razón: \y%s", g_AdminData[ g_AdminID[ id ] ][ ADMIN_PUNISHED ], g_AdminData[ g_AdminID[ id ] ][ ADMIN_PUNISH_REASON ] );
	} else formatex( punished, charsmax( punished ), "" );

	formatex( text, charsmax( text ), "\yInformación del admin^n^n\d•\w Admin Key:\y %s^n\d•\w Admin Tipo:\y %s^n\d•\w Admin Vencimiento:\y %s%s", g_AdminData[ g_AdminID[ id ] ][ ADMIN_AUTH ], g_AdminData[ g_AdminID[ id ] ][ ADMIN_TYPE ], vencimiento, punished );
	new menu = menu_create( text, "clcmd_HandMyAdmin" );

	menu_additem( menu, "Salir", "1" );
	menu_setprop( menu, MPROP_EXIT, MEXIT_NEVER );
	menu_display( id, menu, 0 );

	return PLUGIN_HANDLED;
}
public clcmd_HandMyAdmin( id, menu, item ) {
	if( item == 0 ) menu_destroy( menu );

	return PLUGIN_HANDLED;
}

public clcmd_Admins( id ) {
	new menu = menu_create( "\yAdministradores conectados", "clcmd_HandAdmins" );
	new text[ 100 ], i = 1;

	while( i <= get_maxplayers( ) ) {
		if( get_bit( g_bIsBit[ IS_CONNECTED ], i ) && get_bit( g_bIsBit[ IS_ADMIN ], i ) ) {
			formatex( text, charsmax( text ), "%s \y(%s)%s", g_UserData[ i ][ USER_NAME ], g_AdminData[ g_AdminID[ i ] ][ ADMIN_TYPE ], g_AdminData[ g_AdminID[ i ] ][ ADMIN_PUNISH ] ? " \r[SUSPENDIDO]" : "" );
			menu_additem( menu, text );
		}
		i++;
	}

	menu_setprop( menu, MPROP_NEXTNAME, "Siguiente" );
	menu_setprop( menu, MPROP_BACKNAME, "Atras" );
	menu_setprop( menu, MPROP_EXITNAME, "Salir" );
	menu_display( id, menu, 0 );

	return PLUGIN_HANDLED;
}
public clcmd_HandAdmins( id, menu, item ) {
	if( item == MENU_EXIT ) {
		menu_destroy( menu );
		return PLUGIN_HANDLED;
	}

	clcmd_Admins( id );
	return PLUGIN_HANDLED;
}
public concmd_ReloadAdmins( id, level, cid ) {
	if( !cmd_access( id, level, cid, 1 ) )
		return PLUGIN_HANDLED;

	g_AdminCount = 0;
	plugin_load_admins( );

	client_print( id, print_console, "%s Lista de administradores actualizada. Administradores cargados: %d", szPrefix, g_AdminCount );
	log_amx( "%s Lista de administradores actualizada. Administradores cargados: %d", szPrefix, g_AdminCount );

	return PLUGIN_HANDLED;
}

/* ======================================================== */

public native_IsAdmin( id ) return get_bit( g_bIsBit[ IS_ADMIN ], id );
public native_IsPunished( id ) return g_AdminData[ g_AdminID[ id ] ][ ADMIN_PUNISH ];
public native_GetType( iPlugin, iParams ) {
	if( iParams != 3 ) return PLUGIN_CONTINUE;

	new id = get_param( 1 );

	if( !( 1 <= id <= MAX_PLAYERS ) || !get_bit( g_bIsBit[ IS_ADMIN ], id ) ) return PLUGIN_CONTINUE;
	
	return set_string( 2, g_AdminData[ g_AdminID[ id ] ][ ADMIN_TYPE ], get_param( 3 ) );
}

/* ======================================================== */