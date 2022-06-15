#if defined _AdminManager_DefinesEnums_included
	#endinput
#endif
#define _AdminManager_DefinesEnums_included

#if AMXX_VERSION_NUM < 183
	#define MAX_AUTHID_LENGTH 64
	#define MAX_NAME_LENGTH 32
	#define MAX_PLAYERS 32
	#define client_disconected client_disconnect
	#define print_team_default 0

	stock client_print_color( index, fakevar, const input[ ], any:... ) {
		#pragma unused fakevar
		static szMsg[ 191 ], g_iMsgSayText;
		if( !g_iMsgSayText ) g_iMsgSayText = get_user_msgid( "SayText" );

		vformat(szMsg, 190, input, 3);

		message_begin( index ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, g_iMsgSayText, .player = index );
		write_byte( index ? index : 33 );
		write_string( szMsg );
		message_end( );
	}
#endif

#define MAX_PLAYER_NAME_LENGTH 64
#define MAX_PLAYER_AUTHID_LENGTH 64
#define MAX_PLAYER_PW_LENGTH 64
#define MAX_PLAYER_TYPE_LENGTH 64
#define MAX_PLAYER_DATE_LENGTH 64
#define MAX_PLAYER_REASON_LENGTH 64
#define set_bit(%1,%2) ( %1 |= ( 1 << ( %2 & 31 ) ) ) 
#define get_bit(%1,%2) ( %1 & ( 1 << ( %2 & 31 ) ) ) 
#define clear_bit(%1,%2) ( %1 &= ~ ( 1 << ( %2 & 31 ) ) ) 

enum _:ADMIN_DATA {
	ADMIN_AUTH[ MAX_PLAYER_AUTHID_LENGTH ], ADMIN_PW[ MAX_PLAYER_PW_LENGTH ], ADMIN_TYPE[ MAX_PLAYER_TYPE_LENGTH ], ADMIN_FLAGS[ MAX_PLAYER_TYPE_LENGTH ],
	ADMIN_EXPIRATION[ MAX_PLAYER_DATE_LENGTH ], ADMIN_PUNISHED[ MAX_PLAYER_DATE_LENGTH ], ADMIN_PUNISH_REASON[ MAX_PLAYER_REASON_LENGTH ],
	ADMIN_STEAM, ADMIN_PUNISH
};
enum _:USER_DATA { USER_NAME[ MAX_PLAYER_NAME_LENGTH ], USER_STEAM[ MAX_PLAYER_AUTHID_LENGTH ], USER_PW[ MAX_PLAYER_PW_LENGTH ] };
enum _:CVARS { CVAR_PASSWORD_FIELD };
enum _:USER_BITS { IS_ADMIN, IS_CONNECTED };