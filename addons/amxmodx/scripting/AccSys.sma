/* ==================================================
		LIBRERIAS
=================================================== */	
#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <screenfade_util>
#include <fakemeta>
#include <reapi_reunion>


/* =============== ^^^^^^ ========================= */
/* ==================================================
		Vars, enums, const;
=================================================== */

new const __Plugin[][] = { "Advanced Account System" , "2.0" , "kikizon + Valls" };

new const MYSQL_HOST[] = "45.58.56.30";
new const MYSQL_USER[] = "svlmexico";
new const MYSQL_PASS[] = "obidiotapia";
new const MYSQL_DATABASE[] = "global_svl_mexico.sql"; // <- NO EDITAR ESTA LINEA
new const MYSQL_TABLE[] = "svl_accounts"; // <- NO EDITAR ESTA LINEA

const MAX_ATTEMPS = 3; // Despues de x intentos fallidos al logearse, da kick
const SECONDS = 60; // Despues de x.x segundos desde que se muestra el menu de logeo, da kick

const TASK_KICK = 111215;
const TASK_MENU = 114875;

#define ID_MENU ( task_id - TASK_MENU )

enum
{
	MSG_SHOWMENU = 0, MSG_VGUIMENU,
	SQL_REGISTER_USER = 0, SQL_LOGIN_USER, SQL_LOAD_DATA_NEW, SQL_LOAD_DATA, SQL_SAVE_DATA, SQL_REF, ANTIBUG01, SQL_ACCOUNTS, SQL_AUTOLOGIN, SQL_CHANGE_PASS, SQLX_BANUSER,
	TYPE_ERROR_MSG = 0 , TYPE_INFO_MSG,
	AL_OFF = 0, AL_STEAMID, AL_IP,
	IP = 0, STEAMID
};

new Handle:gTuple, gForward_1, gForward_2, gStatus[33], gServerIP[30],
gAttemps[ 33 ], gmenu[33], gUser[33][34], gPass[33][34], gPName[33][32],
gId[33], gMsg[2], g_ForwardResult, gBlind[33], gSeconds[33], 
gTotalAccounts, cvar_autojoin, gAutoLogin[33], gIp[33][45], gAuthid[33][45],
gChangepass[33][34], waiting[33], gLinked[33][128];


new g_bInvite[ 33 ];

public plugin_natives()
{
	register_native("advacc_guardado_id", "_sm_guardado_id");
	register_native("advacc_user_logged" , "_sm_guardado_loged");
	register_native("advacc_guardado_get_handle", "_sm_guardado_handle");
	register_native("advacc_get_table", "native_get_table", 1 );
	register_native("advacc_get_accounts", "native_get_accounts", 1);
	register_native("advacc_get_linked", "native_get_linked", 1);
	register_native("open_cuenta_menu", "show_login_menu", 1);
	register_native("advacc_autologin_ip", "autologin_ip", 1);
	register_native("advacc_autologin_steam", "autologin_steam", 1);
}

public native_get_accounts() return gTotalAccounts;

public native_get_linked(index, szBuffer[], len)
{
	param_convert(2);
	copy(szBuffer, len, gLinked[index]);
}

public native_get_table( szBuffer[], len )
{
	param_convert(1);
	copy( szBuffer, len, MYSQL_TABLE);
}

public _sm_guardado_id(iPlugin, iParams) return gId[ get_param(1) ];

public _sm_guardado_loged( iPlugin, iParams ) return gStatus[ get_param(1) ];

public Handle:_sm_guardado_handle( iPlugin, iParams ) return gTuple;

//public plugin_precache() Reg_SQL();

public plugin_init() 
{
	register_plugin( __Plugin[ 0x0000 ] , __Plugin[ 0x0001 ] , __Plugin[ 0x0002 ] );
	
	register_clcmd( "CREATE_USERNAME" , "reg_usuario" );
	register_clcmd( "CREATE_PASSWORD" , "reg_password" );
	register_clcmd( "LOGIN_USERNAME" , "log_usuario" );
	register_clcmd( "LOGIN_PASSWORD" , "log_password" );
	register_clcmd( "CURRENT_PASSWORD" , "clcmdChangePass_actual" );
	register_clcmd( "NEW_PASSWORD", "clcmdChangePass_nueva" );
	register_clcmd( "say /cuenta", "show_login_menu" ) ;
	register_clcmd( "chooseteam" , "clcmd_changeteam" );
	register_clcmd( "jointeam" , "clcmd_changeteam" );

	register_concmd("amx_ref", "cmdRef", _, "amx_ref <id_ref>")

	register_concmd("acc_ban", "command_ban", ADMIN_BAN, "acc_ban <nombre> <tiempo (en minutos o 0 permanente)> <razon>");

	cvar_autojoin = register_cvar( "advacc_autojoin", "0" );
	
	gMsg[ MSG_SHOWMENU ] = get_user_msgid( "ShowMenu" );
	gMsg[ MSG_VGUIMENU ] = get_user_msgid( "VGUIMenu" );

	register_message(gMsg[MSG_VGUIMENU], "message_VGUImenu");
	register_message(gMsg[MSG_SHOWMENU], "message_VGUImenu");
	
	gForward_1 = CreateMultiForward("advacc_guardado_login_success", ET_IGNORE, FP_CELL);
	gForward_2 = CreateMultiForward("advacc_guardado_first_login", ET_IGNORE, FP_CELL );
	
	get_user_ip( 0, gServerIP, 29 );

	Reg_SQL();

	set_task( 3.0 , "FixBug01" );

	register_dictionary("accsys.txt");
}
public cmdRef(id, level, cid) { 
	if (g_bInvite[ id ] || !is_user_connected(id)) {
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

	if (gId[id] == idRef)
	{ 
		console_print(id, "No puedes referirte a ti mismo PENDEJO!");
		return PLUGIN_HANDLED; 
	}

	new iData[ 2 ], szQuery[ 512 ]; 

	iData[ 1 ] = id; 
	iData[ 0 ] = SQL_REF;

	formatex( szQuery, 511, "UPDATE %s SET ref = ref+1 WHERE id='%d'", MYSQL_TABLE, idRef );
	SQL_ThreadQuery( gTuple, "DataHandler", szQuery, iData, 2 );

	return PLUGIN_HANDLED; 
} 

public is_number(const str[]){

	for(new i = 0; i < strlen(str) ; ++i)
	{
		if(!isdigit(str[i]))
			return false;
	}

	return true;
}


public autologin_ip(index)
{
	AutoLogin_Switch(index, IP)
}

public autologin_steam(index)
{
	AutoLogin_Switch(index, STEAMID)
}

public client_putinserver(index)
{
	if (is_user_bot(index)) {
		return PLUGIN_CONTINUE;
	}
	gId[index] = 0;
	gmenu[index] = -1;
	get_user_name( index, gPName[ index ], 31 );

	if( !is_user_bot(index) )
	{
		waiting[index] = 1;
		gStatus[ index ] = gId[index] = gAttemps[index] = gSeconds[index] = 0;

		get_user_authid(index, gAuthid[index], 44 );
		get_user_ip(index, gIp[index], 44, 1 );		

		CheckForAutoLogin(index);
	}
	else 
	{
		gStatus[index] = 1;
		waiting[index] = 0;

		get_user_name( index, gPName[ index ], 31 );
		func_login_success( index );
	}
}

CheckForAutoLogin(index)
{
	new iData[ 2 ], szQuery[ 512 ]; 

	/*get_user_info(index, "__ls", szBuffer, 31 );
	
	if( szBuffer[0] )
	{		
		decrypt(szBuffer, szBuffer, 31, 10 );
		
		iData[ 0 ] = SQL_LOGIN_USER;
		iData[ 1 ] = index;
		
		formatex( szQuery, 127, "SELECT * FROM %s WHERE Usuario=^"%s^"",  MYSQL_TABLE, szBuffer );
		SQL_ThreadQuery( gTuple, "DataHandler", szQuery, iData, 2 );
		
		gStatus[index] = 1;

		return;
	}*/

	iData[ 1 ] = index; iData[ 0 ] = SQL_AUTOLOGIN;
	
	formatex( szQuery, 511, "SELECT AutoLogin, Authid, Ip FROM %s WHERE Authid=^"%s^" OR Ip=^"%s^"", MYSQL_TABLE, gAuthid[index], gIp[index] );
	SQL_ThreadQuery( gTuple, "DataHandler", szQuery, iData, 2 );	
}

public client_disconnected( index )
{
	if( gStatus[ index ] && !is_user_bot(index)) 
	{
		gStatus[ index ] = 0;
		func_SaveData( index );
	}
	
	gUser[ index ][ 0 ] = '^0';
	gPass[ index ][ 0 ] = '^0';
	gBlind[index] = gAttemps[index] = 0;

	remove_task(index+TASK_KICK);
}

public client_infochanged( index ) 
{
	if( !gStatus[ index ] )
		return PLUGIN_CONTINUE;
	
	static name[ 32 ];
	get_user_info( index, "name", name, 31 );
	
	if( !equal( gPName[ index ], name ) ) 
	{
		set_user_info( index, "name", gPName[ index ] );	
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public message_VGUImenu(msgid, dest, index) 
{
	if(!gStatus[index])
	{
		if( !waiting[index] )		
			set_task( 0.1, "show_login_menu", index+TASK_MENU );		
		
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public clcmd_changeteam( index ) 
{	
	if( !gStatus[ index ])
	{
		if(!waiting[index])
			show_login_menu( index );
		
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public reg_usuario( index ) 
{			
	read_args( gUser[ index ], 33 );
	remove_quotes( gUser[ index ] );
	trim( gUser[ index ] );
	
	if( !Valid( index, gUser[index]))
	{
		gUser[index][0] = EOS;
		client_cmd( index, "messagemode ^"CREATE_USERNAME^"" );
		return PLUGIN_HANDLED;
	}
	
	client_cmd( index, "messagemode ^"CREATE_PASSWORD^"" );
	ShowMsg( index ,TYPE_INFO_MSG,  "MSG_NEW_PW" );
	
	return PLUGIN_HANDLED;
}

public reg_password( index ) 
{
	read_args( gPass[ index ], 33 );
	remove_quotes( gPass[ index ] );
	trim( gPass[ index ] );
	
	if( !Valid( index, gPass[index]))
	{
		gPass[index][0] = EOS;
		client_cmd( index, "messagemode ^"CREATE_PASSWORD^"" );		
		return PLUGIN_HANDLED;
	}

	new szQuery[ 256 ], iData[ 2 ]; iData[ 1 ] = index; iData[ 0 ] = SQL_REGISTER_USER;
	get_user_name( index, gPName[ index ], 31 );

	formatex( szQuery, charsmax( szQuery ), "INSERT INTO %s (Usuario, Password, Nick, Suspended) VALUES (^"%s^", ^"%s^", ^"%s^", '0')",
	MYSQL_TABLE, gUser[ index ], gPass[ index ], gPName[index] );
	SQL_ThreadQuery(gTuple, "DataHandler", szQuery, iData, 2);

	return PLUGIN_HANDLED;
}

public log_usuario( index ) 
{	
	read_args( gUser[ index ], 33 );
	remove_quotes( gUser[ index ] );
	trim( gUser[ index ] );
	
	if( !Valid( index , gUser[index] ))
	{
		gUser[index][0] = EOS;
		client_cmd( index, "messagemode ^"LOGIN_USERNAME^"" );
		return PLUGIN_HANDLED;
	}
	
	client_cmd( index, "messagemode ^"LOGIN_PASSWORD^"" );
	ShowMsg( index , TYPE_INFO_MSG, "MSG_PW" );
	return PLUGIN_HANDLED;
}

public log_password( index ) 
{	
	read_args( gPass[ index ], 33 );
	remove_quotes( gPass[ index ] );
	trim( gPass[ index ] );
	
	if( !Valid( index , gPass[index] ))
	{
		gPass[index][0] = EOS;
		client_cmd( index, "messagemode ^"LOGIN_PASSWORD^"" );
		return PLUGIN_HANDLED;
	}
	
	new szQuery[ 128 ], iData[ 2 ]; iData[ 1 ] = index; iData[ 0 ] = SQL_LOGIN_USER ;
	
	formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE Usuario=^"%s^" AND Password=^"%s^"", 
	MYSQL_TABLE, gUser[ index ], gPass[ index ] );
	SQL_ThreadQuery( gTuple, "DataHandler", szQuery, iData, 2 );
	
	return PLUGIN_HANDLED;
}

public func_login_success( index )
{
	//set_user_info( index, "name", gPName[ index ] );

	show_menu( index, 0, "^n", 1 );
	func_SaveData( index );

	if( get_pcvar_num(cvar_autojoin) == 1 && !waiting[index])
	{
		client_print( index , print_center , "%L", LANG_PLAYER, "LOADING" );
		set_task( 2.0, "ForceJoinTeam", index );
	}

	gStatus[ index ] = 1;
	waiting[ index ] = 0;
	ExecuteForward(gForward_1, g_ForwardResult, index);
}

public ForceJoinTeam(index)
{
	static teammsg_block, teammsg_block_vgui, restore, vgui, msg_showmenu, msg_vguimenu;
	
	if( !msg_showmenu) msg_showmenu = get_user_msgid( "ShowMenu");
	
	if( !msg_vguimenu) msg_vguimenu = get_user_msgid("VGUIMenu");
	
	restore = get_pdata_int(index, 510); vgui = restore & (1<<0);
	
	if (vgui) set_pdata_int(index, 510, restore & ~(1<<0));
	
	teammsg_block = get_msg_block( msg_showmenu); teammsg_block_vgui = get_msg_block( msg_vguimenu );
	
	set_msg_block( msg_showmenu , BLOCK_ONCE); set_msg_block( msg_vguimenu , BLOCK_ONCE);
	engclient_cmd(index, "jointeam", "5"); engclient_cmd(index, "joinclass", "1");
	set_msg_block( msg_showmenu, teammsg_block); set_msg_block( msg_vguimenu, teammsg_block_vgui);
	
	if (vgui) set_pdata_int(index, 510, restore);
}

public func_SaveData(index) 
{
	if( is_user_bot(index) || !is_user_connected(index)) return;

	new szQuery[ 512 ], iData[ 2 ]; iData[ 1 ] = index; iData[ 0 ] = SQL_SAVE_DATA;    
	formatex(szQuery, charsmax(szQuery), "UPDATE %s SET Online='%d', LastServer='%s', Authid=^"%s^", Ip=^"%s^", AutoLogin='%d' WHERE id='%d'", 
	MYSQL_TABLE, gStatus[index], gServerIP, gAuthid[index], gIp[index], gAutoLogin[index], gId[index])
    
	SQL_ThreadQuery(gTuple, "DataHandler", szQuery, iData, 2);    
}

public func_LoadData(index) 
{
	if( is_user_bot(index)) return;

	new szQuery[128], iData[2]; iData[1] = index; iData[0] = SQL_LOAD_DATA;    
	formatex(szQuery, charsmax(szQuery), "SELECT id FROM %s WHERE Usuario=^"%s^"", MYSQL_TABLE, gUser[index]);

	SQL_ThreadQuery(gTuple, "DataHandler", szQuery, iData, 2);    
}

public FixBug01()
{
	new szQuery[256], iData[2]; iData[0] = ANTIBUG01;
	
	formatex( szQuery, charsmax( szQuery ), "UPDATE %s SET Online='0', LastServer='-' WHERE LastServer='%s'", MYSQL_TABLE, gServerIP );	
	SQL_ThreadQuery( gTuple, "DataHandler", szQuery, iData, 1 );
}

stock Valid( index, const String[] )
{
	new i, len = strlen(String);
	
	if( !len )
	{
		ShowMsg( index , TYPE_ERROR_MSG, "MSG_MIN_STR" );
		return false;
	}
	
	if( len > 33 )
	{
		ShowMsg( index , TYPE_ERROR_MSG, "MSG_MAX_STR" );
		return false;
	}
	
	if( containi( String, " " ) != -1 )
	{
		ShowMsg( index, TYPE_ERROR_MSG, "MSG_SPACE_STR" );
		return false;
	}
	
	for( i = 0 ; i < len ; ++i )
	{
		if( !isdigit(String[i]) && !isalpha(String[i]))
		{
			ShowMsg( index ,TYPE_ERROR_MSG, "MSG_ALNUM_STR" );
			return false;
		}
	}
	
	return true;
}

stock ShowMsg( index , type, const String[])
{
	set_dhudmessage(0, 0, 0, -1.00, -1.00, 0, 0.00, 0.00, 0.00, 0.00);	
	
	static i, colors[3], Float:posX, Float:posY;
	for (i = 0; i < 8; ++i)  show_dhudmessage(index, "");
	
	switch( type )
	{
		case TYPE_ERROR_MSG:
		{
			colors = { 220, 5, 5 };
			posX = -1.0;
			posY = 0.0;
		}
		case TYPE_INFO_MSG:
		{
			colors = { 5, 220, 5 };
			posX = 0.0;
			posY = 0.11;
		}
		default:
		{
			colors = { 220, 220, 220 };
			posX = 0.0;
			posY = 0.11;
		}
	}
	
	set_dhudmessage(colors[0], colors[1], colors[2], posX, posY, 1 );
	show_dhudmessage(index, "%L", LANG_PLAYER, String);
}

public KickPlayer( task_id )
{
	static index; index = task_id - TASK_KICK;

	if( gStatus[index] || is_user_bot(index) )
	{
		remove_task( task_id );
		return;
	}

	++gSeconds[index];
	client_print( index , print_center , "%L", LANG_PLAYER, "LOGINTIME", (SECONDS-gSeconds[index]) );
	
	if( gSeconds[index] >= SECONDS )
	{
		server_cmd("kick #%d ^"%L^"", get_user_userid( index ), LANG_PLAYER, "TIME_SUPE" );
		remove_task( task_id );
	}
}

public show_login_menu( task_id ) 
{	
	static index, szBuffer[512], szLinked[128]; index = ( task_id > TASK_MENU ? ID_MENU : task_id );

	if( waiting[index] ) return PLUGIN_HANDLED;

	if( !gBlind[ index ] && !gStatus[index] )
	{
		UTIL_FadeToBlack(index); //BHOP
		set_task( 1.0 , "KickPlayer" , index+TASK_KICK, .flags="b" );
		gBlind[ index ] = true;
	}

	if( gStatus[index] == 1)
	{
		if( strlen(gLinked[index]) )
			formatex(szLinked, 127, "%L", LANG_PLAYER, "VINC_ACCOUNT", gLinked[index]);
		else
			formatex(szLinked, 127, "%L", LANG_PLAYER, "NOT_VINC");
	}
	else if (!gStatus[index])
	{
		szLinked[0] = EOS;
	}

	formatex( szBuffer, 511, 
	"\r| -- [ \wSVL-Mexico \r] -- |^n\
	\y%L^n\
	%s\
	\d%L^n^n\
	\d• \y%L", LANG_PLAYER, "GLOBAL_MSG", szLinked, LANG_PLAYER, "TOTAL_MSG", add_point(gTotalAccounts), LANG_PLAYER, "FIRSTTIME_MSG");
	
	gmenu[index] = menu_create( szBuffer , "menu_login");

	formatex(szBuffer, 511, "\%s%L^n", gStatus[index] ? "d":"w", LANG_PLAYER, "CREATE_ACCOUNT");
	menu_additem( gmenu[index] , szBuffer , "" );

	formatex(szBuffer, 511, "\d• \y%L^n", LANG_PLAYER, "BACK_MSG");
	menu_addtext( gmenu[index] , szBuffer, 0 );

	formatex(szBuffer, 511, "\%s%L", gStatus[index]?"d":"w", LANG_PLAYER, "LOGIN_MSG");
	menu_additem( gmenu[index] , szBuffer , "" );

	formatex(szBuffer, 511, "\%s%L", gStatus[index]?"w":"d", LANG_PLAYER, "CHANGEPASS_MSG");
	menu_additem( gmenu[index] , szBuffer , "" );

	formatex(szBuffer, 511, "\%s%L", gStatus[index]?"w":"d", LANG_PLAYER, "AUTOLOGIN_MSG");
	menu_additem( gmenu[index] , szBuffer, "" );
	
	if( !gStatus[index] )
		menu_setprop( gmenu[index], MPROP_EXIT, MEXIT_NEVER);

	menu_display( index , gmenu[index] );
	
	return PLUGIN_HANDLED;
}

public menu_login(index,menu,key)
{
	switch( key ) 
	{
		case 0:
		{
			if( gStatus[index]) return PLUGIN_HANDLED;

			ShowMsg(index, TYPE_INFO_MSG, "MSG_NEW_USER" ); 
			client_cmd( index, "messagemode ^"CREATE_USERNAME^"" );
		}
		case 1: 
		{
			if( gStatus[index]) return PLUGIN_HANDLED;

			ShowMsg(index, TYPE_INFO_MSG, "MSG_USER" );
			client_cmd( index, "messagemode ^"LOGIN_USERNAME^"" );
		}
		case 2:
		{
			if( !gStatus[index ])
			{
				client_print(index, print_center, "%L", LANG_PLAYER, "NEED_BE_LOGED" );
				show_login_menu(index);
				return PLUGIN_HANDLED;
			}

			ChangePassMenu(index);
		}
		case 3:
		{
			if( !gStatus[index])
			{
				client_print( index , print_center, "%L", LANG_PLAYER, "NEED_BE_LOGED" );
				show_login_menu(index);
				return PLUGIN_HANDLED;
			}

			AutoLoginMenu(index);
		}
		
		case MENU_EXIT: { menu_destroy(menu); return PLUGIN_HANDLED; }
	}
	
	//menu_destroy(menu);
	//gmenu[index] = 0;
	return PLUGIN_HANDLED;
}

ChangePassMenu(index)
{
	new menu, szBuffer[128];
	formatex(szBuffer, 127, "\y[SVL-Mexico] \w%L", LANG_PLAYER, "CHANGEPASS_MENU" );
	menu = menu_create( szBuffer, "menu_changepass" );

	formatex(szBuffer, 127, "%L", LANG_PLAYER, "CHANGEPASS_MENU2" );
	menu_additem( menu , szBuffer , "" );

	menu_display( index , menu );
}

public menu_changepass( index , menu , item )
{
	if( item != MENU_EXIT && !item )
	{
		ShowMsg( index , TYPE_INFO_MSG, "CURRENT_PASS_MSG" );
		client_cmd(index, "messagemode ^"CURRENT_PASSWORD^"");
	}

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}


public clcmdChangePass_actual(index)
{
	read_args( gChangepass[ index ], 33 ); remove_quotes( gChangepass[ index ] ); trim( gChangepass[ index ] );
	
	if( !Valid( index, gChangepass[index]))
	{
		gPass[index][0] = EOS;
		client_cmd( index, "messagemode ^"CURRENT_PASSWORD^"" );		
		return PLUGIN_HANDLED;
	}

	new iData[2], szBuffer[128]; iData[0] = SQL_CHANGE_PASS; iData[1] = index;
	formatex( szBuffer, 127, "SELECT Password FROM %s WHERE Usuario=^"%s^"", MYSQL_TABLE, gUser[index] );
	SQL_ThreadQuery(gTuple, "DataHandler", szBuffer, iData, 2);

	return PLUGIN_HANDLED;
}

public clcmdChangePass_nueva(index)
{
	read_args( gChangepass[ index ], 33 ); remove_quotes( gChangepass[ index ] ); trim( gChangepass[ index ] );
	
	if( !Valid( index, gChangepass[index]))
	{
		gPass[index][0] = EOS;
		client_cmd( index, "messagemode ^"NEW_PASSWORD^"" );		
		return PLUGIN_HANDLED;
	}

	ConfirmChangePass(index);

	return PLUGIN_HANDLED;
}

ConfirmChangePass(index)
{
	new menu, szBuffer[128];
	formatex(szBuffer, 127, "%L", LANG_PLAYER, "CONFIRM_CHANGEPASS", gChangepass[index] );
	menu = menu_create( szBuffer, "menu_confirm_changepass" );

	formatex(szBuffer, 127, "%L", LANG_PLAYER, "CONFIRM_CHANGEPASS2");
	menu_additem(menu, szBuffer, "" );

	formatex(szBuffer, 127, "%L", LANG_PLAYER, "CONFIRM_CHANGEPASS3");
	menu_additem(menu, szBuffer, "" );

	menu_display( index , menu );
}

public menu_confirm_changepass(index,menu,item)
{
	if( item != MENU_EXIT && !item )
	{
		new iData[2], szBuffer[128]; iData[0] = SQL_SAVE_DATA; iData[1] = index;
		formatex( szBuffer, 127, "UPDATE %s SET Password=^"%s^" WHERE Usuario=^"%s^"", MYSQL_TABLE, gChangepass[index], gUser[index] );
		SQL_ThreadQuery(gTuple, "DataHandler", szBuffer, iData, 2);

		client_print(index, print_center, "%L", LANG_PLAYER, "CHANGEPASS_CONFIRMED" );
	}

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

AutoLoginMenu( index )
{
	static szBuffer[512], menu;/*, szCrypt[32];
	encrypt(gUser[index], szCrypt, 31, 10);

	console_print(index, "^n[ America Gaming ]^n^n Copia y pega en tu config.cfg, ubicada en la carpeta cstrike.");
	console_print(index, " Si obtienes algun error o no funciona intenta borrar algun otro setinfo 'custom^n");
	console_print(index, "setinfo ^"__ls^" ^"%s^"^n^n[ America Gaming ]^n", szCrypt );
	*/
	formatex( szBuffer, 511, "\y[ SVL-Mexico ]^n^n \y• %L:", LANG_PLAYER, "CONFIG_AUTOLOGIN" );
	menu = menu_create(szBuffer, "menu_autologin" );

	if( gAutoLogin[index] == AL_STEAMID )
		formatex( szBuffer, 511, "\%s%L", gAutoLogin[index] == AL_IP ? "d" : "w",LANG_PLAYER, "STEAMID_AUTOLOGIN2");
	else
		formatex( szBuffer, 511, "\%s%L", gAutoLogin[index] == AL_IP ? "d" : "w",LANG_PLAYER, "STEAMID_AUTOLOGIN1");

	menu_additem(menu, szBuffer, "" );

	if(gAutoLogin[index] == AL_IP)
		formatex( szBuffer, 511, "\%s%L", gAutoLogin[index] == AL_STEAMID ? "d" : "w", LANG_PLAYER, "IP_AUTOLOGIN2");
	else 
		formatex( szBuffer, 511, "\%s%L", gAutoLogin[index] == AL_STEAMID ? "d" : "w", LANG_PLAYER, "IP_AUTOLOGIN1");
	
	menu_additem(menu, szBuffer, "" );
	
	/*formatex( szBuffer , 511 , "^n• \yOtro forma de autologueo:^n^n\
	\wAl final de tu archivo config.cfg colocar:^n\
	\rsetinfo ^"__ls^" ^"%s^" \d(Mas info en consola)", szCrypt );
	menu_addtext( menu , szBuffer, 0);*/

	menu_display( index , menu );
}

public menu_autologin( index , menu , item )
{
	if( item != MENU_EXIT )
	{
		if( item )//ip
		{
			AutoLogin_Switch(index, IP)
		}
		else 
		{
			AutoLogin_Switch(index, STEAMID)
		}
	}

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public AutoLogin_Switch(index, type)
{
	switch(type)
	{
		case IP:
		{
			if( gAutoLogin[index] == AL_IP )
			{
				gAutoLogin[index] = AL_OFF;
				client_print(index, print_center, "%L", LANG_PLAYER, "AL_IP_DE" );
			}
			else 
			{
				if( gAutoLogin[index] != AL_OFF )
				{
					client_print(index, print_center, "%L", LANG_PLAYER, "AL_IP_DE2" );
					client_cmd( index, "spk buttons/button10.wav" );
				}
				else 
				{
					gAutoLogin[ index ] = AL_IP;
					client_print( index , print_center, "%L", LANG_PLAYER, "AL_IP_A");
				}
			}
		}
		case STEAMID:
		{
			if( (contain(gAuthid[index], "LAN") != -1) || (contain(gAuthid[index], "VALVE") != -1) )
			{
				client_print( index , print_center, "%L", LANG_PLAYER, "AL_STEAMID_NEED");
				client_cmd( index, "spk buttons/button10.wav" );
				return PLUGIN_HANDLED;
			}

			if( gAutoLogin[index] == AL_STEAMID )
			{
				gAutoLogin[index] = AL_OFF;
				client_print(index, print_center, "%L", LANG_PLAYER, "AL_STEAMID_DE" );
			}
			else 
			{
				if( gAutoLogin[index] != AL_OFF )
				{
					client_print(index, print_center, "%L", LANG_PLAYER, "AL_STEAMID_DE2" );
					client_cmd( index, "spk buttons/button10.wav" );
				}
				else 
				{
					gAutoLogin[ index ] = AL_STEAMID;
					client_print(index, print_center, "%L", LANG_PLAYER, "AL_STEAMID_A" );
				}
			}
		}		
	}
	return PLUGIN_HANDLED;
}

public DataHandler(failstate, Handle:Query, error[ ], error2, data[ ], datasize, Float:time) 
{    
	static iData; iData = data[0];
    
	switch(failstate) 
	{        
		case TQUERY_CONNECT_FAILED: 
		{            
			log_to_file("SQL_LOG.txt", "[%s] Error en la conexion al MySQL [%i][%d]: %s", __Plugin[ 0 ], error2, iData, error);
			return;            
		}        
		case TQUERY_QUERY_FAILED:
			log_to_file("SQL_LOG.txt", "[%s] Error en la consulta al MySQL [%i][%d]: %s", __Plugin[ 0 ], error2, iData, error );
	}

	if( datasize == 1 )
	{
		switch( iData )
		{
			case ANTIBUG01:
			{
				if( failstate < TQUERY_SUCCESS ) log_amx( "[SVL-Mexico] Error en el FixBug." );
				else log_amx( "[SVL-Mexico] FixBug ejecutado correctamente." );		
			}
			case SQL_ACCOUNTS:
			{
				if( failstate < TQUERY_SUCCESS ) log_amx( "[SVL-Mexico] Error al cargar el total de cuentas");
				else
				{
					if( SQL_NumResults(Query) )
					{
						gTotalAccounts = SQL_ReadResult( Query, 0 );
						log_amx( "[SVL-Mexico] Total de cuentas registradas: %d", gTotalAccounts);
					}
					else
						log_amx( "[SVL-Mexico] No se obtienen resultados total de cuentas.");
				}
			}
		}

		return;
	}
    
	new index = datasize == 2 ? data[1] : 0; 
	if(!is_user_connected(index)) return;
	if(!is_user_connected(index) && iData != SQL_AUTOLOGIN ) return;
    
	switch(iData) 
	{        
		case SQL_REGISTER_USER: 
		{
			if( failstate < TQUERY_SUCCESS ) 
			{
				if( containi( error, "Usuario" ) != -1 )
					client_print( index, print_center, "%L", LANG_PLAYER, "ERROR_USER_EXISTS");
				else if( containi( error, "Nick" ) != -1 )
					client_print( index, print_center, "%L", LANG_PLAYER, "ERROR_NICK_EXISTS");
				else
					client_print( index, print_center, "%L", LANG_PLAYER, "ERROR_DESCONOCIDO");
				
				++gAttemps[ index ];
				
				if( gAttemps[ index ] >= MAX_ATTEMPS )
					server_cmd("kick #%d ^"%L^"", get_user_userid( index ), LANG_PLAYER, "MAX_TRYS");
				
				client_cmd( index, "spk buttons/button10.wav" );
				show_login_menu( index );
			}
			else
			{
				func_LoadData(index );
			}				
		}
		case SQL_LOGIN_USER: 
		{
			if( SQL_NumResults( Query ) ) 
			{
				new rslt = SQL_ReadResult(Query,4);
				if( rslt == 1 )
				{
					client_cmd( index, "spk buttons/button10.wav" );
					client_print( index , print_chat, "%L", LANG_PLAYER, "ACTIVE_ACCOUNT" );
					show_login_menu( index );
					return;
				}

				new suspended = SQL_ReadResult(Query, 6);
				if( suspended == 1 )
				{
					new iTime = SQL_ReadResult(Query, 10), iBanDate = SQL_ReadResult(Query, 11);
					if(iTime == 0 || iTime+iBanDate < get_systime())
					{
						client_cmd( index, "spk buttons/button10.wav" );
						server_cmd("kick #%i ^"Tienes una suspencion activa^"", get_user_userid(index));
						return;
					}
					else 
					{
						new szBuffer[128], iData[2]; iData[0] = index; iData[1] = SQL_SAVE_DATA;
						formatex(szBuffer, charsmax(szBuffer), "UPDATE %s SET Suspended=0 WHERE Usuario=^"%s^";", MYSQL_TABLE, gUser[index]);
						SQL_ThreadQuery(gTuple, "DataHandler", szBuffer, iData, 2);
					}
				}
			
				gId[ index ] = SQL_ReadResult( Query, 0 );
				SQL_ReadResult( Query, 1, gUser[index], 33);
				SQL_ReadResult( Query, 2, gPass[index], 33);
				//if(!is_user_steam(index)) SQL_ReadResult( Query, 3, gPName[ index ], 31);

				g_bInvite[ index ]  = SQL_ReadResult( Query, 15 );

				SQL_ReadResult(Query, 10, gLinked[index], 127);
				func_login_success(index);
			}
			else 
			{
				client_print( index, print_chat, "%L", LANG_PLAYER, "USERPASS_WRONG" );
				client_cmd( index, "spk buttons/button10.wav" );				
				show_login_menu( index );
				++gAttemps[ index ];
				
				if( gAttemps[ index ] >= MAX_ATTEMPS )
					server_cmd("kick #%d ^"%L^"", get_user_userid( index ), LANG_PLAYER, "MAX_TRYS");
			}          
		}        
		case SQL_LOAD_DATA: 
		{            
			if( SQL_NumResults( Query ) ) 
			{
				gId[ index ] = SQL_ReadResult( Query, 0 );					
				++gTotalAccounts;
				ExecuteForward(gForward_2, g_ForwardResult, index);

				set_task(0.2, "func_login_success", index);
			}
			else 
			{
				client_print( index, print_center, "%L", LANG_PLAYER, "LOAD_ERROR");

				set_task(2.5, "reshow", index)
			}                			
		}
		case SQL_AUTOLOGIN:
		{	
			if( SQL_NumResults(Query))
			{
				new szAuthid[45], szIp[45];
				gAutoLogin[index] = SQL_ReadResult(Query, 0);
				SQL_ReadResult(Query, 1, szAuthid, 44 );
				SQL_ReadResult(Query, 2, szIp, 44 );

				if(gAutoLogin[index] == AL_STEAMID && equal(gAuthid[index], szAuthid))
				{
					static szQuery[128], szData[2]; szData[ 0 ] = SQL_LOGIN_USER; szData[1] = index;
		
					formatex( szQuery, 127, "SELECT * FROM %s WHERE Authid=^"%s^"",  MYSQL_TABLE, szAuthid );
					SQL_ThreadQuery( gTuple, "DataHandler", szQuery, szData, 2 );
					gStatus[index] = 1;
					return;
				}
				
				if(gAutoLogin[index] == AL_IP && equal(gIp[index], szIp))
				{					
					static szQuery[128], szData[2]; szData[ 0 ] = SQL_LOGIN_USER ;	szData[1] = index;
		
					formatex( szQuery, 127, "SELECT * FROM %s WHERE Ip=^"%s^"",  MYSQL_TABLE, szIp );
					SQL_ThreadQuery( gTuple, "DataHandler", szQuery, szData, 2 );
					gStatus[index] = 1;
					return;
				}
				
				
				waiting[index] = 0;
				//show_login_menu(index);
				set_task(2.0, "show_login_menu", index);
			}
			else 
			{				
				waiting[index] = 0;
				//show_login_menu(index);
				set_task(2.0, "show_login_menu", index);
			}
		}
		case SQL_SAVE_DATA:
		{
			if( failstate < TQUERY_SUCCESS )
				console_print( index, "%L", LANG_PLAYER, "SAVE_ERROR");
			else
				console_print( index, "%L", LANG_PLAYER, "SAVE_SUCCESS");
		}
		case SQL_REF:
		{
			if( failstate < TQUERY_SUCCESS )
				console_print( index, "%L", LANG_PLAYER, "SAVE_ERROR");
			else{
				g_bInvite[ index ] = 1;

				new iData[ 2 ], szQuery[ 512 ]; 

				iData[ 1 ] = index; 
				iData[ 0 ] = SQL_SAVE_DATA;

				formatex( szQuery, 511, "UPDATE %s SET bRef = '%d' WHERE id='%d'", 
					MYSQL_TABLE, g_bInvite[ index ], gId[index] );
				SQL_ThreadQuery( gTuple, "DataHandler", szQuery, iData, 2 );
			}
		}
		case SQL_CHANGE_PASS:
		{
			new pass[34];
			SQL_ReadResult(Query, 0, pass, 33);

			if( !equal(pass, gChangepass[index] ) )
			{
				client_cmd( index, "spk buttons/button10.wav" );
				ShowMsg(index, TYPE_ERROR_MSG, "PASS_NOT_EQUAL");
				return;
			}

			gChangepass[index][0] = EOS;

			client_cmd(index, "messagemode ^"NEW_PASSWORD^"" );
			ShowMsg(index, TYPE_INFO_MSG, "TIPE_NEW_PASS" );
		}
		case SQLX_BANUSER:
		{
			server_cmd("kick #%i ^"Fuiste baneado, revisa tu consola^"", get_user_userid(index));
		}
	}
}

public reshow(index)
{
	if( gmenu[index] == -1 )
		show_login_menu(index);
}

stock add_point(number)
{ 
	new count, i, str[29], str2[35], len
	num_to_str(number, str, charsmax(str))
	len = strlen(str)
	
	for (i = 0; i < len; i++)
	{
		if (i != 0 && ((len - i) %3 == 0))
		{
			add(str2, charsmax(str2), ".", 1)
			count++
			add(str2[i+count], 1, str[i], 1)
		}
		else
			add(str2[i+count], 1, str[i], 1)
	}

	return str2;
}

public command_ban(index, level, cid)
{
	if(~get_user_flags(index) & level) return PLUGIN_HANDLED;

	new arg1[32], iPlayer; read_argv(1, arg1, 31);
	iPlayer = cmd_target(index, arg1, CMDTARGET_OBEY_IMMUNITY | CMDTARGET_NO_BOTS | CMDTARGET_ALLOW_SELF);

	if(!iPlayer) return PLUGIN_HANDLED;

	if(!gId[iPlayer])
	{
		console_print(index, "[BAN] El jugador no inicio sesion");	
		return PLUGIN_HANDLED;
	}

	new szReason[64];
	read_argv(3, szReason, charsmax(szReason));
	if( !strlen(szReason) )
	{
		console_print(index, "[BAN] Ingresa una razon valida!");
		return PLUGIN_HANDLED;
	}

	new szMinutes[11];
	read_argv(2, szMinutes, charsmax(szMinutes));
	new iMinutes = str_to_num(szMinutes);
	new iSeconds = (iMinutes*60);
	new szAdmin[32], szBanned[32], szBantime[64];
	get_user_name(index, szAdmin, 31); get_user_name(iPlayer, szBanned, 31);

	if(iMinutes) formatex(szBantime, charsmax(szBantime), "%d minutos", iMinutes);
	else formatex(szBantime, charsmax(szBantime), "Permanente");

	console_print(iPlayer, "Fuiste baneado por: %s^nRazon: %s^nTiempo: %s", szAdmin, szReason, szBantime);

	new szBuffer[128], iData[2]; iData[0] = iPlayer; iData[1] = SQLX_BANUSER;
	formatex(szBuffer, charsmax(szBuffer), "UPDATE %s SET Suspended'1', bantime='%d', bandate='%d', banadmin=^"%s^" WHERE Nick=^"%s^";",
	MYSQL_TABLE, iSeconds, get_systime(), szAdmin, szBanned);
	SQL_ThreadQuery(gTuple, "DataHandler", szBuffer, iData, 2);

	client_print_color(0, print_team_default, "^3[BAN] ^1El admin ^4%s ^1suspendio a ^4%s ^1- Tiempo: ^4%s ^1- Razon: ^4%s", szAdmin, szBanned, szBantime, szReason);
	return PLUGIN_HANDLED;
}

/*stock table_find_char(character)
{
    for(new i; table[i]; i++) if(table[i] == character) return i
    
    return -1
}

stock generate_key(string[])
{
    new int[1]
    for(new i; i < 4 && string[i]; i++) int{i} = string[i]
    
    return 1+int[0]%255
}

stock encrypt(string[], out[], len, numkey)
{
    new charid, i
    for(i=0; string[i] && i <= len;i++)
    {
        charid = table_find_char(string[i])
        if(charid == -1) out[i] = string[i]
        else out[i] = table[(charid+numkey)%charsmax(table)]
    }
}

stock decrypt(encrypted[], out[], len, numkey)
{
    new charid, i
    for(i=0; encrypted[i] && i <= len;i++)
    {
        charid = table_find_char(encrypted[i])
        if(charid == -1) out[i] = encrypted[i]
        else out[i] = table[(charid-numkey)%charsmax(table)]
    }
}*/

Reg_SQL()
{
	gTuple = SQL_MakeDbTuple( MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DATABASE );
	
	if(!gTuple)
	{
		log_to_file("SQL_LOG.txt", "No se pudo conectar con la base de datos.");
		return pause("a");
	}
	
	new szQuery[1012];
	formatex(szQuery, 1011, 
	"CREATE TABLE IF NOT EXISTS %s \
	(id int(10) NOT NULL AUTO_INCREMENT PRIMARY KEY,\
	Usuario varchar(34) NOT NULL UNIQUE KEY, \
	Password varchar(34) NOT NULL, \
	Nick varchar(32) NOT NULL UNIQUE KEY,\
	Online int(2) NOT NULL DEFAULT '0', \
	LastServer varchar(30) NOT NULL,\
	Suspended int(2) NOT NULL,\
	Authid varchar(45) NOT NULL,\
	Ip varchar(45) NOT NULL,\
	AutoLogin int(2) NOT NULL DEFAULT '0',\
	bantime int(11) NOT NULL,\
	bandate int(11) NOT NULL,\
	banadmin varchar(33) NOT NULL,\
	Linked varchar(128),\
	ref int(33) NOT NULL DEFAULT '0',\
	bRef int(1) NOT NULL DEFAULT '0'\
	);", MYSQL_TABLE );
	SQL_ThreadQuery(gTuple, "DataHandler", szQuery);

	set_task(1.5, "LLLL");
	
	return PLUGIN_CONTINUE;
}

public LLLL()
{
	new szQuery[1012], iData[2];
	iData[ 0 ] = SQL_ACCOUNTS;
	formatex(szQuery, 1011, "SELECT COUNT(*) FROM %s", MYSQL_TABLE);
	SQL_ThreadQuery(gTuple, "DataHandler", szQuery, iData, 1 );

	set_task( 3.0 , "FixBug01" );
}

public plugin_end() SQL_FreeHandle(gTuple);

