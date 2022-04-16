#include < amxmodx >
#include < cstrike >
#include < engine >
#include <fakemeta_util>
#include < fun >
#include < hamsandwich >
#include < zombieplague >

#define Plugin    "[ZP] Extra Item: Jump Bomb"
#define Version    "1.2"
#define Author    "Zombie-rus"

// Модели гранаты
new const g_ViewModel [ ] = "models/cz/v_zombibomb.mdl"
new const g_PlayerModel [ ] = "models/cz/p_zombibomb.mdl"
new const g_WorldModel [ ] = "models/cz/w_zombibomb.mdl"

//Звуки покупки
new const g_SoundGrenadeBuy [ ] [ ] = { "items/gunpickup2.wav" }
new const g_SoundAmmoPurchase [ ] [ ] = { "items/9mmclip1.wav" }

//Звук взрыва
new const g_SoundBombExplode [ ] [ ] = { "nst_zombie/zombi_bomb_exp.wav" }

//Не изменять! Звуки прописаны в модели.
new const frogbomb_sound [ ] = { "nst_zombie/zombi_bomb_deploy.wav" }
new const frogbomb_sound_idle [ ] = { "nst_zombie/zombi_bomb_idle_4.wav" }

new const g_szItemName [ ] = "JumpBomb" // Имя айтема

new const g_iItemPrice = 300 // Стоимость за 1 бомбу

#define MAXCARRY    5 // Лимит гранат
#define RADIUS        300.0 // Радиус взрыва

#define MAXPLAYERS        32
#define pev_nade_type        pev_flTimeStepSound
#define NADE_TYPE_JUMPING    26517
#define AMMOID_SM        13

new g_iExplo, anti;
new g_iNadeID

new g_iJumpingNadeCount [ MAXPLAYERS+1 ]
new g_iCurrentWeapon [ MAXPLAYERS+1 ]

new cvar_speed
new iconstatus
new grenade_icons[33][32]

new g_msgScreenShake

new g_MaxPlayers
new g_msgAmmoPickup

const UNIT_SECOND = (1<<12)


public plugin_precache ( )
{
	precache_model ( g_ViewModel )
	precache_model ( g_PlayerModel )
	precache_model ( g_WorldModel )
	        
	precache_sound ( frogbomb_sound )
	precache_sound ( frogbomb_sound_idle )
			
	new i
	for ( i = 0; i < sizeof g_SoundGrenadeBuy; i++ )
	precache_sound ( g_SoundGrenadeBuy [ i ] )
	for ( i = 0; i < sizeof g_SoundAmmoPurchase; i++ )
	precache_sound ( g_SoundAmmoPurchase [ i ] )
	for ( i = 0; i < sizeof g_SoundBombExplode; i++ )
	precache_sound ( g_SoundBombExplode [ i ] )

	g_iExplo = precache_model ( "sprites/zombiebomb_exp.spr" ) // Спрайт взрыва
}

public plugin_init ( )
{
	register_plugin ( Plugin, Version, Author )

	g_iNadeID = zp_register_extra_item( g_szItemName, g_iItemPrice, 0, ZP_TEAM_ZOMBIE )
	anti = zp_register_extra_item( "Anti-Jump", 300, 0, ZP_TEAM_HUMAN )

	register_event ( "CurWeapon", "EV_CurWeapon", "be", "1=1" )
	register_event ( "HLTV", "EV_NewRound", "a", "1=0", "2=0" )
	register_event ( "DeathMsg", "EV_DeathMsg", "a" )

	register_forward ( FM_SetModel, "fw_SetModel" )
	RegisterHam ( Ham_Think, "grenade", "fw_ThinkGrenade" )
	g_msgScreenShake = get_user_msgid("ScreenShake")

	cvar_speed = register_cvar ( "zp_zombiebomb_knockback", "600" )

	g_msgAmmoPickup = get_user_msgid ( "AmmoPickup" )

	g_MaxPlayers = get_maxplayers ( )
	register_event("CurWeapon", "grenade_icon", "be", "1=1")
	register_event("DeathMsg", "event_death", "a")
	iconstatus = get_user_msgid("StatusIcon")
}



public getBomb(id)
{
	id -= 12344;

	if(zp_get_class(id) >= NEMESIS || !is_user_alive(id))
		return;

	give_item ( id, "weapon_smokegrenade" )
	client_print ( id, print_chat, "[ZP] Compraste una JumpBomb" )
	emit_sound ( id, CHAN_ITEM, g_SoundGrenadeBuy[random_num(0, sizeof g_SoundGrenadeBuy-1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM )
	             
	AmmoPickup ( id, AMMOID_SM, 1 )
	             
	g_iJumpingNadeCount [ id ] = 1
}

public client_connect ( id )
{
    g_iJumpingNadeCount [ id ] = 0
}

public zp_extra_item_selected ( id, Item )
{
	if ( Item == g_iNadeID )
	{
		if ( g_iJumpingNadeCount [ id ] >= MAXCARRY )
		{
			client_print ( id, print_chat, "[ZP] Ya alcanzaste el limite de jumps bombs" )
			return ZP_PLUGIN_HANDLED
		}        
		new iBpAmmo = cs_get_user_bpammo ( id, CSW_SMOKEGRENADE )
	          
		if ( g_iJumpingNadeCount [ id ] >= 1 )
		{
			cs_set_user_bpammo ( id, CSW_SMOKEGRENADE, iBpAmmo+1 )
			             
			emit_sound ( id, CHAN_ITEM, g_SoundAmmoPurchase[random_num(0, sizeof g_SoundAmmoPurchase-1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM )
			             
			AmmoPickup ( id, AMMOID_SM, 1 )
			             
			g_iJumpingNadeCount [ id ]++
		}
		else
		{
			give_item ( id, "weapon_smokegrenade" )
			client_print ( id, print_chat, "[ZP] Compraste una JumpBomb" )
			emit_sound ( id, CHAN_ITEM, g_SoundGrenadeBuy[random_num(0, sizeof g_SoundGrenadeBuy-1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM )
			             
			AmmoPickup ( id, AMMOID_SM, 1 )
			             
			g_iJumpingNadeCount [ id ] = 1
		}
	}
	if(anti == Item)
	{
		zp_set_no_jump(id, 1);
		client_print ( id, print_chat, "[ZP] Compraste Anti JumpBomb" )
		//emit_sound ( id, CHAN_ITEM, g_SoundGrenadeBuy[random_num(0, sizeof g_SoundGrenadeBuy-1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM )	  
	}
	return PLUGIN_CONTINUE
}
public zp_user_infected_post(id, infector, nemesis)
{
	zp_set_no_jump(id, 0);
}
public zp_user_humanized_post ( id, Survivor )
{
	g_iJumpingNadeCount [ id ] = 0
	if ( Survivor )
	{
		g_iJumpingNadeCount [ Survivor ] = 0
	}
}

public EV_CurWeapon ( id )
{
	if ( !is_user_alive ( id ) || !zp_get_user_zombie ( id ) )
	return PLUGIN_CONTINUE

	g_iCurrentWeapon [ id ] = read_data ( 2 );

	if ( g_iJumpingNadeCount [ id ] > 0 && g_iCurrentWeapon [ id ] == CSW_SMOKEGRENADE )
	{
		set_pev(id, pev_viewmodel2, g_ViewModel)
		set_pev ( id, pev_weaponmodel2, g_PlayerModel )
	}
	return PLUGIN_CONTINUE
}

public EV_NewRound ( )
{
	for(new i = 1; i <= g_MaxPlayers; ++i)
		remove_task(i+12344);
		
	arrayset ( g_iJumpingNadeCount, 0, 33 )
}

public EV_DeathMsg ( )
{
	new iVictim = read_data ( 2 )
	       
	if ( !is_user_connected ( iVictim ) )
	return
	       
	g_iJumpingNadeCount [ iVictim ] = 0
	zp_set_no_jump(iVictim, 0);
}

public fw_SetModel ( Entity, const Model [ ] )
{
	if ( Entity < 0 )
		return FMRES_IGNORED
	       
	if ( pev ( Entity, pev_dmgtime ) == 0.0 )
		return FMRES_IGNORED
	       
	new iOwner = entity_get_edict ( Entity, EV_ENT_owner )   
	       
	if ( g_iJumpingNadeCount [ iOwner ] >= 1 && equal ( Model [ 7 ], "w_sm", 4 ) )
	{
		// Reset any other nade
		set_pev ( Entity, pev_nade_type, 0 )
		           
		set_pev ( Entity, pev_nade_type, NADE_TYPE_JUMPING )
		            
		g_iJumpingNadeCount [ iOwner ]--
		entity_set_model ( Entity, g_WorldModel )
		            
		fm_set_rendering(Entity, kRenderFxHologram, 255, 165, 0, kRenderNormal, 16) //kRenderFxGlowShell
					
		return FMRES_SUPERCEDE    
	}
	return FMRES_IGNORED
}

public fw_ThinkGrenade ( Entity )
{
	if ( !pev_valid ( Entity ) )
	return HAM_IGNORED
	       
	static Float:dmg_time
	pev ( Entity, pev_dmgtime, dmg_time )
	       
	if ( dmg_time > get_gametime ( ) )
	return HAM_IGNORED
	       
	if ( pev ( Entity, pev_nade_type ) == NADE_TYPE_JUMPING )
	{
		jumping_explode ( Entity )
		return HAM_SUPERCEDE
	}
	return HAM_IGNORED
}

public jumping_explode ( Entity )
{
	if ( Entity < 0 )
		return
	       
	static Float:flOrigin [ 3 ]
	pev ( Entity, pev_origin, flOrigin )
	       
	engfunc ( EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, flOrigin, 0 )
	write_byte ( TE_SPRITE )
	engfunc ( EngFunc_WriteCoord, flOrigin [ 0 ] )
	engfunc ( EngFunc_WriteCoord, flOrigin [ 1 ] )
	engfunc ( EngFunc_WriteCoord, flOrigin [ 2 ] + 45.0 )
	write_short ( g_iExplo )
	write_byte ( 35 )
	write_byte ( 186 )
	message_end ( )
	       
	//new iOwner = entity_get_edict ( Entity, EV_ENT_owner )
	       
	emit_sound ( Entity, CHAN_WEAPON, g_SoundBombExplode[random_num(0, sizeof g_SoundBombExplode-1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM )
	       
	for ( new i = 1; i <= g_MaxPlayers; i++ )
	{
		if ( !is_user_alive( i ) || zp_get_no_jump( i ) )
			continue
		                  
		new Float:flVictimOrigin [ 3 ]
		pev ( i, pev_origin, flVictimOrigin )
		           
		new Float:flDistance = get_distance_f ( flOrigin, flVictimOrigin )   
		           
		if ( flDistance <= RADIUS )
		{
			static Float:flSpeed
			flSpeed = get_pcvar_float ( cvar_speed )
			               
			static Float:flNewSpeed
			flNewSpeed = flSpeed * ( 1.0 - ( flDistance / RADIUS ) )
			               
			static Float:flVelocity [ 3 ]
			get_speed_vector ( flOrigin, flVictimOrigin, flNewSpeed, flVelocity )
			               
			set_pev ( i, pev_velocity,flVelocity )

			message_begin(MSG_ONE_UNRELIABLE, g_msgScreenShake, _, i)
			write_short(UNIT_SECOND*4) // amplitude             
			write_short(UNIT_SECOND*10) // duration
			write_short(UNIT_SECOND*10) // frequency
			message_end()	
			                
			fm_fakedamage(i, "knockback-bomb", 10.0,  DMG_BLAST);
		}
	}

	engfunc ( EngFunc_RemoveEntity, Entity )
}       

public AmmoPickup ( id, AmmoID, AmmoAmount )
{
	message_begin ( MSG_ONE, g_msgAmmoPickup, _, id )
	write_byte ( AmmoID )
	write_byte ( AmmoAmount )
	message_end ( )
}

stock get_speed_vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= num
	new_velocity[1] *= num
	new_velocity[2] *= num
	       
	return 1;
}

public grenade_icon(id) 
{
	remove_grenade_icon(id)
		
	if(is_user_bot(id))
		return
		
	static igrenade, grenade_sprite[16], grenade_color[3]
	igrenade = get_user_weapon(id)
	
	switch(igrenade) 
	{
		case CSW_SMOKEGRENADE:
		{
			if(!is_user_alive(id) || zp_get_user_zombie(id)) {
				grenade_sprite = "dmg_gas"
				grenade_color = {255, 165, 0} 
			}
			else
			{
				grenade_sprite = ""
				grenade_color = {0, 0, 0} 
			}
		}
		default: return
	}
	grenade_icons[id] = grenade_sprite
		
	// show grenade icons
	message_begin(MSG_ONE,iconstatus,{0,0,0},id)
	write_byte(1) // status (0=hide, 1=show, 2=flash)
	write_string(grenade_icons[id]) // sprite name
	write_byte(grenade_color[0]) // red
	write_byte(grenade_color[1]) // green
	write_byte(grenade_color[2]) // blue
	message_end()
		
	return
}

public remove_grenade_icon(id) 
{
	// remove grenade icons
	message_begin(MSG_ONE,iconstatus,{0,0,0},id)
	write_byte(0) // status (0=hide, 1=show, 2=flash)
	write_string(grenade_icons[id]) // sprite name
	message_end()
}

public event_death() 
{
	new id = read_data(2)
		
	if(!is_user_bot(id))
		remove_grenade_icon(id)
}