
#include amxmodx
#include fakemeta
#include hamsandwich
#include zombieplague
#include xs

new g_iClassId, g_stridBombV, g_iBitUserImplose, g_iUserBallId[ 33 ], Float: g_fUserReloadUltimate[ 33 ],
	g_pSpriteLgtning, g_pSpriteLaserBeam, g_pSpritePointer, g_iMaxPlayers;

#define CLASS_NAME 				"Darkness Revenant"
#define CLASS_INFO 				"[E - Blackhole]"
#define CLASS_MODEL 			"b7_15471_rev_crystal"
#define CLASS_CLAW_MODEL		"v_b7_15471_rev_crystal.mdl"
#define CLASS_BALL_MODEL 		"models/zombie_plague/w_blackhole.mdl"
#define CLASS_BLACKHOLE_MODEL 	"models/zombie_plague/blackhole.mdl"
#define CLASS_SND_SHOCK			"weapons/electro4.wav"
#define CLASS_SND_BANG			"zombie_plague/bang.wav"
#define CLASS_SPR_POINTER		"sprites/zombie_plague/pointer_hook.spr"

#define CLASS_HEALTH		7000
#define CLASS_SPEED			310
#define CLASS_GRAVITY		0.8
#define CLASS_KNOCKBACK		0.5
#define CLASS_ULTIMATE_TIME 60

#define CLASS_FLAGS			ADMIN_LEVEL_D

#define TaskId_BlackHole	92851925

#define HookHamUpdateItem(%1) \
	RegisterHam(Ham_Item_Deploy,%1,"fwd_ItemDeploy_Grenade_Post",true); \
	RegisterHam(Ham_Item_AttachToPlayer,%1,"fwd_ItemDeploy_Grenade_Post",true)

#define WriteCoord(%1) engfunc(EngFunc_WriteCoord,%1[0]);engfunc(EngFunc_WriteCoord,%1[1]);engfunc(EngFunc_WriteCoord,%1[2])
#define PushSound(%1,%2) emit_sound(%1,CHAN_STATIC,%2,VOL_NORM,ATTN_NORM,0,PITCH_NORM)
#define StopSound(%1,%2) emit_sound(%1,CHAN_STATIC,%2,VOL_NORM,ATTN_NORM,SND_STOP,PITCH_NORM)
#define fakeDamage(%1,%2,%3) ExecuteHamB(Ham_TakeDamage,%1,0,%2,%3,DMG_SLASH)
#define findPlayerInRadius(%1,%2,%3) (%1=engfunc(EngFunc_FindEntityInSphere,%1,%2,%3))
#define precacheModelBuffer(%1) formatex(szBuffer,charsmax(szBuffer),%1);engfunc(EngFunc_PrecacheModel,szBuffer)

public plugin_precache() { 
	new szBuffer[ 64 ]; 
	precacheModelBuffer( "models/player/%s/%s.mdl", CLASS_MODEL, CLASS_MODEL );
	precacheModelBuffer( "models/zombie_plague/%s", CLASS_CLAW_MODEL );

	engfunc( EngFunc_PrecacheModel, CLASS_BALL_MODEL );
	engfunc( EngFunc_PrecacheModel, CLASS_BLACKHOLE_MODEL );

	engfunc( EngFunc_PrecacheSound, CLASS_SND_BANG );
	engfunc( EngFunc_PrecacheSound, CLASS_SND_SHOCK );

	g_stridBombV = engfunc( EngFunc_AllocString, szBuffer );
	g_pSpriteLgtning = engfunc( EngFunc_PrecacheModel, "sprites/lgtning.spr" );
	g_pSpriteLaserBeam = engfunc( EngFunc_PrecacheModel, "sprites/laserbeam.spr" ); 
	g_pSpritePointer = engfunc( EngFunc_PrecacheModel, CLASS_SPR_POINTER ); 

	g_iClassId = zp_register_class(CLASS_ZOMBIE, CLASS_NAME, CLASS_INFO, CLASS_MODEL, CLASS_CLAW_MODEL, 
	0, 0, ADMIN_ALL, CLASS_HEALTH, 0, CLASS_SPEED, CLASS_GRAVITY, CLASS_KNOCKBACK);
}

public plugin_init() {
	register_plugin( "[ZP] Class Zombie: Darkness Revenant", "2.1BETA", "ToJI9IHGaa" );
	HookHamUpdateItem( "weapon_hegrenade" );
	HookHamUpdateItem( "weapon_smokegrenade" );
	HookHamUpdateItem( "weapon_flashbang" );
	RegisterHam( Ham_Touch, "info_target", "fwd_TouchEntity", false );
	RegisterHam( Ham_Player_Duck, "player", "fwd_PlayerDuck", false ) 
	register_forward( FM_CmdStart, "FakeMeta_CmdStart" );
	register_forward( FM_PlayerPreThink, "FakeMeta_PlayerThink", true );
	register_forward( FM_Think, "FakeMeta_Think", false );
	register_logevent( "LogEvent_RoundEnd", 2, "1=Round_End" );	
	g_iMaxPlayers = get_maxplayers();
}

public LogEvent_RoundEnd() {
	for( new iPlayer = 1; iPlayer <= g_iMaxPlayers; iPlayer++ ) {
		if( !is_user_connected( iPlayer ) )
			continue;

		if( TaskId_BlackHole + iPlayer ) {
			remove_task( TaskId_BlackHole + iPlayer );
			UTIL_BarTime( iPlayer, 0 );
		}
		if( pev_valid( g_iUserBallId[ iPlayer ] ) ) {
			StopSound( g_iUserBallId[ iPlayer ], CLASS_SND_SHOCK );
			engfunc( EngFunc_RemoveEntity, g_iUserBallId[ iPlayer ] );
			g_iUserBallId[ iPlayer ] = 0;
		}
	}
}

public FakeMeta_Think( iEntity ) {
	if( !pev_valid( iEntity ) || pev( iEntity, pev_impulse ) != 9899 || pev( iEntity, pev_iuser1 ) != 99 )
		return FMRES_IGNORED;

	new Float: vecOrigin[ 3 ], iVictim, Float: vecUserOrigin[ 3 ], 
		Float: vecVelocity[ 3 ], Float: flY, Float: flX, iOwner = pev( iEntity, pev_owner ); 

	pev( iEntity, pev_origin, vecOrigin );
	while( findPlayerInRadius( iVictim, vecOrigin, 256.0 ) ) {
		if ( !( iVictim <= 0 <= g_iMaxPlayers ) || !is_user_alive( iVictim ) )
			continue;

		pev( iVictim, pev_origin, vecUserOrigin );
		if( get_distance_f( vecUserOrigin, vecOrigin ) > 32.0 ) {
			vecVelocity[ 0 ] = ( vecOrigin[ 0 ] - vecUserOrigin[ 0 ] ) * 3.0;
			vecVelocity[ 1 ] = ( vecOrigin[ 1 ] - vecUserOrigin[ 1 ] ) * 3.0;
			vecVelocity[ 2 ] = ( vecOrigin[ 2 ] - vecUserOrigin[ 2 ] ) * 3.0;
			flY = 	vecVelocity[ 0 ] * vecVelocity[ 0 ] + 
					vecVelocity[ 1 ] * vecVelocity[ 1 ] + 
					vecVelocity[ 2 ] * vecVelocity[ 2 ];

			flX = ( 5 * 70.0 ) / floatsqroot( flY );
			vecVelocity[ 0 ] *= flX;
			vecVelocity[ 1 ] *= flX;
			vecVelocity[ 2 ] *= flX;

			if( zp_get_user_zombie( iVictim ) ) {
				vecVelocity[ 0 ] *= -1.0;
				vecVelocity[ 1 ] *= -1.0;
				vecVelocity[ 2 ] *= -1.0;
			}

			set_pev( iVictim, pev_velocity, vecVelocity );
			pev( iVictim, pev_origin, vecUserOrigin );
			if( get_distance_f( vecUserOrigin, vecOrigin ) < 50.0 )
				fakeDamage( iVictim, iOwner, 1.0 );
		} else if( !zp_get_user_zombie( iVictim ) )
			fakeDamage( iVictim, iOwner, 1.0 );
	}

	static Float: fTimeTime; pev( iEntity, pev_fuser1, fTimeTime );
	if( get_gametime() > fTimeTime ) {
		CREATE_TAREXPLOSION( vecOrigin );
		while( findPlayerInRadius( iVictim, vecOrigin, 128.0 ) ) {
			if ( ( iVictim <= 0 && iVictim > g_iMaxPlayers ) || !is_user_alive( iVictim ) )
				continue;

			pev( iVictim, pev_origin, vecUserOrigin );
			UTIL_Knockback( vecOrigin, vecUserOrigin, 2000.0, vecVelocity );
			CREATE_BEAMFOLLOW( iVictim, g_pSpritePointer, 5, 10, 171, 39, 150, 150 );
			set_pev( iVictim, pev_velocity, vecVelocity );
			CREATE_KILLBEAM( iVictim );
			UTIL_ScreenFade( iVictim, _, _, _, 171, 39, 150 );
		}
		PushSound( iEntity, CLASS_SND_BANG );
		engfunc( EngFunc_RemoveEntity, iEntity );
		if( is_user_connected( iOwner ) )
			g_iUserBallId[ iOwner ] = 0;
		return FMRES_IGNORED;
	} else {
		pev( iEntity, pev_fuser2, fTimeTime );
		if( get_gametime() > fTimeTime ) {
			set_pev( iEntity, pev_fuser2, get_gametime() + 3.0 );
			PushSound( iEntity, CLASS_SND_SHOCK );
		}
	}

	set_pev( iEntity, pev_nextthink, get_gametime() + 0.5 );
	return FMRES_IGNORED;
}

public FakeMeta_PlayerThink( pId ) {
	if( g_iBitUserImplose & ( 1<<pId ) ) {
		if( !zp_get_user_zombie( pId ) || zp_get_user_zombie_class( pId ) != g_iClassId || !is_user_alive( pId ) ) {
			g_iBitUserImplose &= ~( 1<<pId );
			return;
		}
		new Float: vecOrigin[ 3 ], iHealth; 
		pev( pId, pev_origin, vecOrigin ); vecOrigin[ 2 ] += 16.0;
		UTIL_Implosion( vecOrigin, 45, random( 5 ) + 5, 1 );		
		UTIL_ScreenShake( pId, ( 1<<12 ), ( 1<<10 ), ( 1<<12 ) );
		iHealth = pev( pId, pev_health );
		if( iHealth > 50.0 )
			set_pev( pId, pev_health, iHealth - random_float( 1.0, 5.0 ) );
	}
}

public FakeMeta_CmdStart( pId, pUC_Handle, iSeed ) { 
	if( !zp_get_user_zombie( pId ) || zp_get_user_zombie_class( pId ) != g_iClassId || !is_user_alive( pId ) )
		return FMRES_IGNORED;

	if( get_uc( pUC_Handle, UC_Buttons ) & IN_USE ) {
		if( task_exists( TaskId_BlackHole + pId ) )
			return FMRES_IGNORED;

		static Float: fGameTime; fGameTime = get_gametime();
		if( fGameTime > g_fUserReloadUltimate[ pId ] ) {
			client_print( pId, print_center, "Ha comenzado el proceso de acumulación y transformación de vitalidad en Agujero Negro.." );
			set_task( 10.0, "task_zombie_blackhole_push", pId + TaskId_BlackHole  );
			PushSound( pId, CLASS_SND_SHOCK );
			UTIL_BarTime( pId, 10 );
			g_iBitUserImplose |= ( 1<<pId );
		} else 
			client_print( pId, print_center, "Recargar %d segundos!", floatround( g_fUserReloadUltimate[ pId ] - fGameTime ) );
	} else {
		if( ~pev( pId, pev_flags ) & FL_DUCKING && ~pev( pId, pev_oldbuttons ) & IN_DUCK )
			set_pev( pId, pev_view_ofs, { 0.0, 0.0, 33.0 } );

		if( ~pev( pId, pev_oldbuttons ) & IN_USE ) {
			if( task_exists( pId + TaskId_BlackHole ) ) {
				UTIL_BarTime( pId, 0 );
				remove_task( pId + TaskId_BlackHole );
				g_iBitUserImplose &= ~( 1<<pId );
				StopSound( pId, CLASS_SND_SHOCK );
			}
		}
	}

	return FMRES_IGNORED; 
}

public task_zombie_blackhole_push( pId ) {
	pId -= TaskId_BlackHole;
	if( !zp_get_user_zombie( pId ) || zp_get_user_zombie_class( pId ) != g_iClassId || !is_user_alive( pId ) )
		return;

	client_cmd( pId, "weapon_knife" );
	ExecuteHamB( Ham_TakeDamage, pId, 0, 0, random_float( 300.0, 900.0 ), DMG_SHOCK );
	g_iBitUserImplose &= ~( 1<<pId );
	new Float: vecOrigin[ 3 ], iEntity; 
	pev( pId, pev_origin, vecOrigin );
	engfunc( EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0 );
	write_byte( TE_EXPLOSION2 );
	WriteCoord( vecOrigin );
	write_byte( 0 );
	write_byte( 127 );
	message_end();

	while( findPlayerInRadius( iEntity, vecOrigin, 128.0 ) ) {
		if( is_user_alive( iEntity ) ) 
			UTIL_ScreenFade( iEntity, _, _, _, 171, 39, 70 );
	}

	PushBall( vecOrigin, pId );
	g_fUserReloadUltimate[ pId ] = get_gametime() + CLASS_ULTIMATE_TIME.0;
}

public CreateThunder( pId ) {
	new Float: vecOrigin[ 2 ][ 3 ], Float: fBufferOrigin[ 3 ]; 
	pev( pId, pev_origin, vecOrigin[ 0 ] );
	vecOrigin[ 0 ][ 2 ] += 2.0;
	pev( pId, pev_origin, vecOrigin[ 1 ] );

	vecOrigin[ 1 ][ 0 ] += 140.0;
	get_true_line_distange( vecOrigin[ 0 ], vecOrigin[ 1 ], vecOrigin[ 1 ] );
	vecOrigin[ 0 ][ 2 ] += 13.0;
	fBufferOrigin[ 0 ] = vecOrigin[ 1 ][ 0 ];
	fBufferOrigin[ 1 ] = vecOrigin[ 1 ][ 1 ];
	fBufferOrigin[ 2 ] = vecOrigin[ 1 ][ 2 ] - 999.0;
	get_true_line_distange( vecOrigin[ 1 ], fBufferOrigin, vecOrigin[ 1 ] );
	CREATE_SPRITETRAIL( vecOrigin[ 0 ], vecOrigin[ 1 ], g_pSpriteLgtning, 100, 40, 15, { 171, 39, 70, 255 } );
	vecOrigin[ 0 ][ 2 ] -= 13.0;

	pev( pId, pev_origin, vecOrigin[ 1 ] );
	vecOrigin[ 1 ][ 0 ] -= 140.0;
	get_true_line_distange( vecOrigin[ 0 ], vecOrigin[ 1 ], vecOrigin[ 1 ] );
	vecOrigin[ 0 ][ 2 ] += 13.0;
	fBufferOrigin[ 0 ] = vecOrigin[ 1 ][ 0 ];
	fBufferOrigin[ 1 ] = vecOrigin[ 1 ][ 1 ];
	fBufferOrigin[ 2 ] = vecOrigin[ 1 ][ 2 ] - 999.0;
	get_true_line_distange( vecOrigin[ 1 ], fBufferOrigin, vecOrigin[ 1 ] );
	CREATE_SPRITETRAIL( vecOrigin[ 0 ], vecOrigin[ 1 ], g_pSpriteLgtning, 100, 40, 15, { 171, 39, 70, 255 } );
	vecOrigin[ 0 ][ 2 ] -= 13.0;

	pev( pId, pev_origin, vecOrigin[ 1 ] );
	vecOrigin[ 1 ][ 1 ] += 140.0;
	get_true_line_distange( vecOrigin[ 0 ], vecOrigin[ 1 ], vecOrigin[ 1 ] );
	vecOrigin[ 0 ][ 2 ] += 13.0;
	fBufferOrigin[ 0 ] = vecOrigin[ 1 ][ 0 ];
	fBufferOrigin[ 1 ] = vecOrigin[ 1 ][ 1 ];
	fBufferOrigin[ 2 ] = vecOrigin[ 1 ][ 2 ] - 999.0;
	get_true_line_distange( vecOrigin[ 1 ], fBufferOrigin, vecOrigin[ 1 ] );
	CREATE_SPRITETRAIL( vecOrigin[ 0 ], vecOrigin[ 1 ], g_pSpriteLgtning, 100, 40, 15, { 171, 39, 70, 255 } );
	vecOrigin[ 0 ][ 2 ] -= 13.0;

	pev( pId, pev_origin, vecOrigin[ 1 ] );
	vecOrigin[ 1 ][ 1 ] -= 140.0;
	get_true_line_distange( vecOrigin[ 0 ], vecOrigin[ 1 ], vecOrigin[ 1 ] );
	vecOrigin[ 0 ][ 2 ] += 13.0;
	fBufferOrigin[ 0 ] = vecOrigin[ 1 ][ 0 ];
	fBufferOrigin[ 1 ] = vecOrigin[ 1 ][ 1 ];
	fBufferOrigin[ 2 ] = vecOrigin[ 1 ][ 2 ] - 999.0;
	get_true_line_distange( vecOrigin[ 1 ], fBufferOrigin, vecOrigin[ 1 ] );
	CREATE_SPRITETRAIL( vecOrigin[ 0 ], vecOrigin[ 1 ], g_pSpriteLgtning, 100, 40, 15, { 171, 39, 70, 255 } );
	vecOrigin[ 0 ][ 2 ] -= 13.0;
}

public PushBall( Float: vecOrigin[ 3 ], pId ) {
	static Float: vecConvertOrigin[ 3 ], 
	Float: glbvecForward[ 3 ], Float: glbvecRight[ 3 ], Float: glbvecUp[ 3 ], 
	Float: vecGunPosition[ 3 ], Float: fPlayerViewOffset[ 3 ]; 

	global_get( glb_v_forward, glbvecForward ); 
	global_get( glb_v_right, glbvecRight ); 
	global_get( glb_v_up, glbvecUp ); 

	pev( pId, pev_origin, vecOrigin ); 
	pev( pId, pev_view_ofs, fPlayerViewOffset ); 
	xs_vec_add(vecOrigin, fPlayerViewOffset, vecGunPosition ); 

	xs_vec_mul_scalar( glbvecForward, 13.0, glbvecForward ); 
	xs_vec_mul_scalar( glbvecRight, 0.0, glbvecRight ); 
	xs_vec_mul_scalar( glbvecUp, 5.0, glbvecUp ); 

	xs_vec_add( vecGunPosition, glbvecForward, vecConvertOrigin ); 
	xs_vec_add( vecConvertOrigin, glbvecRight, vecConvertOrigin ); 
	xs_vec_add( vecConvertOrigin, glbvecUp, vecConvertOrigin ); 

	new Float: fVelocity[ 3 ], Float:fUserAngle[ 3 ]; 
	pev( pId, pev_angles, fUserAngle );

	if( pev_valid( g_iUserBallId[ pId ] ) && pev( g_iUserBallId[ pId ], pev_impulse ) == 9899 ) {
		engfunc( EngFunc_RemoveEntity, g_iUserBallId[ pId ] );
		StopSound( g_iUserBallId[ pId ], CLASS_SND_SHOCK );
	}

	static stridInfoTarget ; new iBallId;
	if( stridInfoTarget || ( stridInfoTarget = engfunc( EngFunc_AllocString, "info_target" ) ) )
		iBallId = engfunc( EngFunc_CreateNamedEntity, stridInfoTarget ); 

	if( !pev_valid( iBallId ) ) 
		return PLUGIN_HANDLED; 

	g_iUserBallId[ pId ] = iBallId;
	set_pev( iBallId, pev_impulse, 9899 );
	set_pev( iBallId, pev_classname, "ent_Blackhole" ); 
	engfunc( EngFunc_SetModel, iBallId, CLASS_BALL_MODEL ); 
	set_pev( iBallId, pev_origin, vecConvertOrigin ); 
	set_pev( iBallId, pev_angles, fUserAngle ); 
	engfunc( EngFunc_SetSize, iBallId, Float: { -1.0, -1.0, -1.0 }, Float: { 1.0, 1.0, 1.0 } );
	set_pev( iBallId, pev_solid, SOLID_SLIDEBOX );
	set_pev( iBallId, pev_movetype, MOVETYPE_BOUNCEMISSILE );
	set_pev( iBallId, pev_owner, pId ); 
	set_pev( iBallId, pev_effects, EF_BRIGHTLIGHT ); 
	velocity_by_aim( pId, 800, fVelocity );
	set_pev( iBallId, pev_velocity, fVelocity ); 
	fm_set_user_rendering( iBallId, kRenderFxGlowShell, 171, 39, 70, kRenderNormal, 16 ); 
	CREATE_BEAMFOLLOW( iBallId, g_pSpriteLaserBeam, 10, 3, 171, 39, 70, 255 );
	PushSound( iBallId, CLASS_SND_SHOCK );

	UTIL_PlayPlayerAnimation( pId, 10 ); 
	UTIL_PlayWeaponAnimation( pId, 8 ); 

	set_pev( iBallId, pev_nextthink, get_gametime() + 0.1 );
	return iBallId;
}

public fwd_PlayerDuck( pId ) {
	if( !zp_get_user_zombie( pId ) )
		return;

	if( zp_get_user_zombie_class( pId ) == g_iClassId ) { 
		if( pev( pId, pev_button ) & IN_DUCK || pev( pId, pev_flags) & (FL_DUCKING | FL_ONGROUND) ) 
			set_pev( pId, pev_view_ofs, { 0.0, 0.0, 20.0 } );
    }
} 

public fwd_TouchEntity( iEntity, iToucher ) {
	if( !pev_valid( iEntity ) || pev( iEntity, pev_iuser1 ) == 99 )
		return;

	if( pev( iEntity, pev_impulse ) != 9899 )
		return;

	new szClassName[ 35 ]; pev( iEntity, pev_classname, szClassName, charsmax( szClassName ) );
	if( !equal( szClassName, "ent_Blackhole" ) )
		return;

	CreateThunder( iEntity );
	engfunc( EngFunc_SetModel, iEntity, CLASS_BLACKHOLE_MODEL ); 
	set_pev( iEntity, pev_velocity, { 0.0, 0.0, 0.1 } );
	set_pev( iEntity, pev_movetype, MOVETYPE_NONE );
	set_pev( iEntity, pev_iuser1, 99 );
	set_pev( iEntity, pev_sequence, 0 );
	set_pev( iEntity, pev_framerate, 1.0 );
	set_pev( iEntity, pev_solid, SOLID_BBOX );
	engfunc( EngFunc_SetSize, iEntity, Float: { -10.0, -10.0, -10.0 }, Float: { 10.0, 10.0, 10.0 } );
	set_pev( iEntity, pev_fuser1, get_gametime() + 10.0 );
	set_pev( iEntity, pev_fuser2, get_gametime() + 3.0 );
	set_pev( iEntity, pev_nextthink, get_gametime() + 0.5 );
}

public fwd_ItemDeploy_Grenade_Post( iEntity ) {
	new pId = pev( iEntity, pev_owner );
	if( is_user_alive( pId ) && zp_get_user_zombie( pId ) && zp_get_user_zombie_class( pId ) == g_iClassId ) {
		set_pev( pId, pev_view_ofs, { 0.0, 0.0, 33.0 } );
		set_pev_string( pId, pev_viewmodel2, g_stridBombV );
	}
}

public zp_user_humanized_pre( pId, bSurvivor ) {
	if( pev_valid( g_iUserBallId[ pId ] ) ) {
		StopSound( g_iUserBallId[ pId ], CLASS_SND_SHOCK );
		engfunc( EngFunc_RemoveEntity, g_iUserBallId[ pId ] );
		g_iUserBallId[ pId ] = 0;
	}
	if( zp_get_user_zombie_class( pId ) == g_iClassId )
		set_pev( pId, pev_view_ofs, { 0.0, 0.0, 17.0 } );
}

public zp_user_infected_pre( pId, iAttacker, bNemesis ) {
	if( zp_get_user_next_class( pId ) != g_iClassId )
		return;

	if( ~get_user_flags( pId ) & CLASS_FLAGS ) {
		zp_set_user_zombie_class( pId, 0 );
		UTIL_SayText( pId, "No access to ^4Darkness Revenant^1." );
	} else {
		client_print( pId, print_console, "Class by g3cKpunTop" );
		UTIL_SayText( pId, "Tu habilidad ^4^"Blackhole^" ^1 por carta ^4<E>^1." );
		set_pev( pId, pev_view_ofs, { 0.0, 0.0, 33.0 } );
	}
}

stock UTIL_SayText( pPlayer, const szMessage[], any:... ) {
	if( pPlayer <= 0 || !is_user_connected( pPlayer ) )
		return;

	new szBuffer[ 190 ], iLen = formatex( szBuffer, charsmax( szBuffer ), "^1[^4ZE^1] " );
	if( numargs() > 2 ) 
		vformat( szBuffer[ iLen ], charsmax( szBuffer ), szMessage, 3 );
	else 
		copy( szBuffer[ iLen ], charsmax( szBuffer ), szMessage );
	
	while( replace( szBuffer, charsmax( szBuffer ), "!y", "^1" ) ) {}
	while( replace( szBuffer, charsmax( szBuffer ), "!t", "^3" ) ) {}
	while( replace( szBuffer, charsmax( szBuffer ), "!g", "^4" ) ) {}

	engfunc( EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, 76, { 0.0, 0.0, 0.0 }, pPlayer );
	write_byte( pPlayer );
	write_string( szBuffer );
	message_end();
}

stock fm_set_user_rendering( pPlayer, iRenderFx, iRed, iGreen, iBlue, iRenderMode, iRenderAmt ) {
	new Float: flRenderColor[ 3 ];
	flRenderColor[ 0 ] = float( iRed );
	flRenderColor[ 1 ] = float( iGreen );
	flRenderColor[ 2 ] = float( iBlue );
	set_pev( pPlayer, pev_renderfx, iRenderFx );
	set_pev( pPlayer, pev_rendercolor, flRenderColor );
	set_pev( pPlayer, pev_rendermode, iRenderMode );
	set_pev( pPlayer, pev_renderamt, float( iRenderAmt ) );
}

stock UTIL_BarTime( pId, iTime ) {
	engfunc( EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, 108, { 0.0, 0.0, 0.0 }, pId );
	write_short( iTime );
	message_end();
}

stock UTIL_Implosion( const Float: vecOrigin[ 3 ], iRadius, iCount, iLife ) {
	engfunc( EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0 );
	write_byte( TE_IMPLOSION );
	WriteCoord( vecOrigin );
	write_byte( iRadius );
	write_byte( iCount );
	write_byte( iLife );
	message_end();
}

stock CREATE_KILLBEAM( pEntity ) {
	message_begin( MSG_ALL, SVC_TEMPENTITY );
	write_byte( TE_KILLBEAM );
	write_short( pEntity );
	message_end();
}

stock CREATE_BEAMFOLLOW( pEntity, pSptite, iLife, iWidth, iRed, iGreen, iBlue, iAlpha ) {
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
	write_byte( TE_BEAMFOLLOW );
	write_short( pEntity );
	write_short( pSptite );
	write_byte( iLife ); // 0.1's
	write_byte( iWidth );
	write_byte( iRed );
	write_byte( iGreen );
	write_byte( iBlue );
	write_byte( iAlpha );
	message_end();
}

stock CREATE_SPRITETRAIL( Float: vecOriginStart[ 3 ], Float: vecOriginEnd[ 3 ], pSprite, iLife, iWidth, iAmplitude, iRGBA[ 4 ] ) {
	engfunc( EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOriginStart, 0 );
	write_byte( TE_BEAMPOINTS );
	WriteCoord( vecOriginStart );
	WriteCoord( vecOriginEnd );
	write_short( pSprite );
	write_byte( 0 );
	write_byte( 0 );
	write_byte( iLife ); // 0.1's
	write_byte( iWidth );
	write_byte( iAmplitude );
	write_byte( iRGBA[ 0 ] );
	write_byte( iRGBA[ 1 ] );
	write_byte( iRGBA[ 2 ] );
	write_byte( iRGBA[ 3 ] );
	write_byte( 1 );
	message_end(); 
}

stock get_true_line_distange( const Float: fStart[ 3 ], const Float: fEnd[ 3 ], Float: fOrigin[ 3 ] ) {
	new hTraceId;
	engfunc( EngFunc_TraceLine, fStart, fEnd, (IGNORE_MONSTERS|IGNORE_GLASS), 0, hTraceId ); 
	get_tr2( hTraceId, TR_vecEndPos, fOrigin ); 
	free_tr2( hTraceId );
}

stock UTIL_ScreenFade( pPlayer, iDuration = ( 1<<12 ), iHoldTime = ( 1<<12 ), iFlags = 0, iRed = 255, iGreen = 255, iBlue = 255, iAlpha = 200 ) {
	engfunc( EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, 98, { 0.0, 0.0, 0.0 }, pPlayer );
	write_short( iDuration );
	write_short( iHoldTime );
	write_short( iFlags );
	write_byte( iRed );
	write_byte( iGreen );
	write_byte( iBlue );
	write_byte( iAlpha );
	message_end();
}

stock UTIL_PlayWeaponAnimation( pPlayer, const iAnimation ) { 
	set_pev( pPlayer, pev_weaponanim, iAnimation );
	engfunc( EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, { 0.0, 0.0, 0.0 }, pPlayer );
	write_byte( iAnimation );
	write_byte( 0 );
	message_end();
} 

stock UTIL_PlayPlayerAnimation( pPlayer, iAnimation, Float:fFrame = 1.0, Float:fFrameRate = 1.0 ) { 
    set_pev( pPlayer, pev_sequence, iAnimation ); 
    set_pev( pPlayer, pev_gaitsequence, 1 ); 
    set_pev( pPlayer, pev_frame, fFrame ) 
    set_pev( pPlayer, pev_framerate, fFrameRate ); 
}

stock UTIL_ScreenShake( pPlayer, iAmplitude, iDuration, iFrequency ) {
	if( !is_user_alive( pPlayer ) )
		return;

	engfunc( EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, 97, { 0.0, 0.0, 0.0 }, pPlayer );
	write_short( iAmplitude );
	write_short( iDuration );
	write_short( iFrequency );
	message_end();
}

stock UTIL_Knockback( const Float: a[ 3 ],const Float: b[ 3 ], Float: fSpeed, Float: fVel[ 3 ] ) {
	fVel[ 0 ] = b[ 0 ] - a[ 0 ]; fVel[ 1 ] = b[ 1 ] - a[ 1 ]; fVel[ 2 ] = b[ 2 ] - a[ 2 ];
	new Float: fRage = floatsqroot( fSpeed * fSpeed / ( fVel[ 0 ] * fVel[ 0 ] + fVel[ 1 ] * fVel[ 1 ] + fVel[ 2 ] * fVel[ 2 ] ) );
	fVel[ 0 ] *= fRage; fVel[ 1 ] *= fRage; fVel[ 2 ] *= fRage;
}

stock CREATE_TAREXPLOSION( Float: vecOrigin[ 3 ] ) {
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
	write_byte( TE_TAREXPLOSION );
	WriteCoord( vecOrigin );
	message_end();
}