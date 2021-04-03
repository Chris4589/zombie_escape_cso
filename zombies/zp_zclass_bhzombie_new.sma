#include <amxmodx>
#include <fakemeta>
#include <zombieplague>

new g_zclass_bhzombie, g_hclass_bhhuman;
new g_hasBhop[33], bool:g_restorevel[33], Float:g_velocity[33][3]

new const zclass_name[] = { "BunnyHop Zombie" }
new const zclass_info[] = { "BunnyHop, Pain Shock Free" }
new const zclass4_model[] = { "jax" }

const zclass_health = 7000
const zclass_speed = 270
const Float:zclass_gravity = 0.7
const Float:zclass_knockback = 1.0

new const hclass_name[] = { "BunnyHop Human" }
new const hclass_info[] = { "BunnyHop" }
new const hclass4_model[] = { "cso_natasha" }
const hclass_health = 600
const hclass_speed = 320
const Float:hclass_gravity = 0.7
const Float:hclass_knockback = 0.0

public plugin_init()
{
	register_plugin("[ZP] Class : BunnyHop Zombie", "1.2", "fa†es™, fix LARS-BLOODLIKER")

	register_event( "DeathMsg", "event_player_death", "a" )

	register_forward(FM_PlayerPreThink, "fw_PlayerPreThink")
	register_forward(FM_PlayerPreThink, "fw_PlayerPreThink_Post", 1)
}

public plugin_precache()
{
	//zp_register_class(const type, const name[], const info[], const model[], const knife[], level, reset, adm, hp, chaleco, speed, Float:gravity, Float:knockback)
	//zp_register_class(const type, const name[], const info[], const model[], const knife[], level, hp, chaleco, speed, Float:gravity, Float:knockback)
	g_hclass_bhhuman = zp_register_class(CLASS_HUMAN, hclass_name, hclass_info, hclass4_model, "default", 16, 2, ADMIN_ALL, hclass_health, 50, hclass_speed, hclass_gravity, hclass_knockback);
	g_zclass_bhzombie = zp_register_class(CLASS_ZOMBIE, zclass_name, zclass_info, zclass4_model, "zp_v_knife_predator.mdl", 16, 2, ADMIN_BAN, zclass_health, 0, zclass_speed, zclass_gravity, zclass_knockback)
}
public zp_user_humanized_post(id, survivor)
{
	g_hasBhop[ id ] = false;

	if (zp_get_user_human_class(id) == g_hclass_bhhuman && !zp_get_user_survivor(id))
	{
		g_hasBhop[ id ] = true

		pev(id, pev_velocity, g_velocity[id])
	}
}
public zp_user_infected_post(id, infector)
{
	if (zp_get_user_zombie_class(id) == g_zclass_bhzombie)
	{
		g_hasBhop[ id ] = true

		pev(id, pev_velocity, g_velocity[id])
	}
}

public client_connect( id )
{
	g_hasBhop[ id ] = false
}

public client_disconnected( id )
{
	g_hasBhop[ id ] = false
}

public event_player_death()
{
	g_hasBhop[ read_data( 2 ) ] = false
}

public fw_PlayerPreThink(id)
{
	if(zp_get_class(id) >= SURVIVOR && zp_get_class(id) < ZOMBIE || zp_get_class(id) >= NEMESIS)
		return FMRES_IGNORED

	if(!is_user_alive(id))
		return FMRES_IGNORED

	if ( zp_get_user_zombie(id) && zp_get_user_zombie_class(id) != g_zclass_bhzombie || !zp_get_user_zombie(id) && zp_get_user_human_class(id) != g_hclass_bhhuman)
		return FMRES_IGNORED
	

	set_pev( id, pev_fuser2, 0.0 )
		
	if( pev( id, pev_button ) & IN_JUMP )
	{
		new szFlags = pev( id, pev_flags )

		if( !( szFlags & FL_WATERJUMP ) && pev( id, pev_waterlevel ) < 2 && szFlags & FL_ONGROUND )
		{
			new Float: szVelocity[ 3 ]
			pev( id, pev_velocity, szVelocity)
			szVelocity[ 2 ] += 250.0
			set_pev( id, pev_velocity, szVelocity )
			set_pev( id, pev_gaitsequence, 6 )
		}
	}

	if (pev(id, pev_flags) & FL_ONGROUND)
	{
		pev(id, pev_velocity, g_velocity[id])
        
		g_restorevel[id] = true
	}

        return FMRES_IGNORED
}

public fw_PlayerPreThink_Post(id)
{
	if(zp_get_class(id) >= SURVIVOR && zp_get_class(id) < ZOMBIE || zp_get_class(id) >= NEMESIS)
		return FMRES_IGNORED

	if ( zp_get_user_zombie(id) && zp_get_user_zombie_class(id) != g_zclass_bhzombie || !zp_get_user_zombie(id) && zp_get_user_human_class(id) != g_hclass_bhhuman )
	{
		return FMRES_IGNORED
	}
	
	if (g_restorevel[id])
	{
		g_restorevel[id] = false

		if (!(pev(id, pev_flags) & FL_ONTRAIN))
		{
			new groundent = pev(id, pev_groundentity)
			
			if (pev_valid(groundent) && (pev(groundent, pev_flags) & FL_CONVEYOR))
			{	
				static Float:vecTemp[3]
                
				pev(id, pev_basevelocity, vecTemp)
                
				g_velocity[id][0] += vecTemp[0]
				g_velocity[id][1] += vecTemp[1]
				g_velocity[id][2] += vecTemp[2]
			}                

			set_pev(id, pev_velocity, g_velocity[id])
            
			return FMRES_HANDLED
		}
	}

	return FMRES_IGNORED
}