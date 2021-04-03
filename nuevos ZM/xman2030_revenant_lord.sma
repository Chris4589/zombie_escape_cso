#include <amxmodx>
#include <engine>
#include <fakemeta_util>
#include <hamsandwich>
#include <zombieplague>
#include <cstrike>
#include <fun>
#include <xs>
#include <fakemeta_util>

#define PLUGIN "Revenant Overlord"
#define VERSION "0.1"
#define AUTHOR "unnamed"

#define FireShpere_Classname "ZP_Povelitel_FireShpere"
#define FrostSphere_Classname "ZP_Povelitel_FrostSphere"

#define CDHudChannel 4


#define Shpere "models/xman2030/w_fire_ball.mdl"
#define Trail "sprites/xman2030/tok.spr"
#define Burn "sprites/xman2030/ef_red_flame.spr"

const Float:FireShpereExplodeRadius = 100.0
const Float:FireShpereExplodeDamage = 100.0
const Float:FireShpere_CD= 10.0
const Float:FireShpere_BurnTime = 3.0
const Float:BurnDamage = 25.0
const Float:BurnUpdate = 0.5

const Float:FrostSphereExplodeRadius = 100.0
const Float:FrostSphereExplodeDamage = 0.0
const Float:FrostSphere_CD= 10.0
const Float:FrostSphere_FreezeTime = 5.0

#define THROW_SKILL "xman2030/bloodhunter_throwa.wav"
#define TOUCH_SKILL "xman2030/zbs_attack_shockwave.wav"

new bool:Can_Use_Ability[32],Selected_Ability[32],Float:Ability_CD[32],Float:UpdateHud[32]
new bool:in_frost[32],Float:FrostTime[32]
new bool:in_burn[32],Float:BurnTime[32],BurnOwner[32],Float:BurnUpdateDamage[32]

new Msg_ScreenShake,Msg_ScreenFade,TrailSpriteIndex,BurnSprite
new g_has_Povelitel

#define CLASS_NAME 				"LORD Revenant"
	#define CLASS_INFO 				"[E - ]"
	#define CLASS_MODEL 			"b7_15471_rev_big"
	#define CLASS_CLAW_MODEL		"v_b7_15471_rev_big.mdl"
	#define CLASS_BLACKHOLE_MODEL 	"models/zombie_plague/blackhole.mdl"
	#define CLASS_SND_SHOCK			"weapons/electro4.wav"
	#define CLASS_SND_BANG			"zombie_plague/bang.wav"
	#define CLASS_SPR_POINTER		"sprites/zombie_plague/pointer_hook.spr"

	#define CLASS_HEALTH		7000
	#define CLASS_SPEED			310
	#define CLASS_GRAVITY		0.8
	#define CLASS_KNOCKBACK		0.5
	#define CLASS_ULTIMATE_TIME 60

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	Msg_ScreenShake = get_user_msgid("ScreenShake")
	Msg_ScreenFade = get_user_msgid("ScreenFade")

	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	RegisterHam(Ham_Touch, "info_target", "Ham_Touch_Pre")

	register_clcmd("drop","use_ability")
}

public plugin_precache()
{
	//g_has_Povelitel = zp_register_zombie_class("LORD", "\rOverlord", Model, Claw, 26000, 320, 0.6, 1.0);
	
	g_has_Povelitel = zp_register_class(CLASS_ZOMBIE, CLASS_NAME, CLASS_INFO, CLASS_MODEL, CLASS_CLAW_MODEL, 
		0, 0, ADMIN_ALL, CLASS_HEALTH, 0, CLASS_SPEED, CLASS_GRAVITY, CLASS_KNOCKBACK);

	engfunc(EngFunc_PrecacheSound, THROW_SKILL);
	engfunc(EngFunc_PrecacheSound, TOUCH_SKILL);

	precache_model(Shpere)
	TrailSpriteIndex=precache_model(Trail)
	BurnSprite=precache_model(Burn)
}

public use_ability(id)
{
	if(!is_user_connected(id))return
	if(!is_user_alive(id))return
	#if !defined TestingTime
	if(!zp_get_user_zombie(id))return
	if(zp_get_user_nemesis(id))return
	if(zp_get_user_zombie_class(id)!=g_has_Povelitel)return
	#endif
	if(!Can_Use_Ability[id-1])return
	new Float: gametime = get_gametime()
	switch(Selected_Ability[id-1])
	{
		case 0:throw_Shpere(id,1),Ability_CD[id-1]=gametime+FireShpere_CD,Can_Use_Ability[id-1]=false
		case 1:throw_Shpere(id,2),Ability_CD[id-1]=gametime+FrostSphere_CD,Can_Use_Ability[id-1]=false
	}

	emit_sound(id, CHAN_WEAPON, THROW_SKILL, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
//Ham
public Ham_Touch_Pre(ent,world)
{
	if(!pev_valid(ent))return HAM_IGNORED
	
	new Classname[32]
	pev(ent, pev_classname, Classname, sizeof(Classname))
	if(!equal(Classname, FireShpere_Classname)&&!equal(Classname, FrostSphere_Classname))return HAM_IGNORED
	
	new Float:Origin[3],id = pev(ent,pev_owner)
	
	pev(ent,pev_origin,Origin)
	new victim =-1,Float:Damage_Radius,Float:Damage,attacker
	switch(pev(ent,pev_iuser1))
	{
		case 1:Damage_Radius=FireShpereExplodeRadius,Damage=FireShpereExplodeDamage,Light(Origin,30,255,105,0,4),DrawRings(Origin,255,105,0)
		case 2:Damage_Radius=FrostSphereExplodeRadius,Damage=FrostSphereExplodeDamage,Light(Origin,30,0,105,255,4),DrawRings(Origin,0,55,255)
	}
	
	while((victim = engfunc(EngFunc_FindEntityInSphere, victim, Origin, Damage_Radius)) != 0) 
	{
		if(pev_valid(victim)&&pev(victim, pev_takedamage)!=DAMAGE_NO&&pev(victim, pev_solid)!=SOLID_NOT)
		{
			if(is_user_connected(victim))
			{
				#if defined TestingTime
				if(get_user_team(victim)!=get_user_team(id))
				#else
				if(!zp_get_user_zombie(victim))
				#endif
				{
					if(pev(victim,pev_armorvalue)<=0.0&&pev(victim,pev_health)<Damage)attacker=id;else attacker=0
					switch(pev(ent,pev_iuser1))
					{
						case 1:	ExecuteHamB(Ham_TakeDamage,victim, ent,attacker, Damage, DMG_BURN),ScreenFade(victim,6,1,{255,125,0},125,1),
							BurnTime[victim-1]=get_gametime()+FireShpere_BurnTime,in_burn[victim-1]=true,in_frost[victim-1]=false,BurnOwner[victim-1]=id
						case 2:	ExecuteHamB(Ham_TakeDamage,victim, ent,attacker, Damage, DMG_FREEZE),ScreenFade(victim,6,1,{0,0,255},125,1),
							FrostTime[victim-1]=get_gametime()+FrostSphere_FreezeTime,in_frost[victim-1]=true,in_burn[victim-1]=false,
							fm_set_rendering(victim, kRenderFxGlowShell, 0,105,255, kRenderNormal,15)
					}
					ScreenShake(victim, ((1<<12) * 3), ((2<<12) * 3))
				}
			}
			else ExecuteHamB(Ham_TakeDamage,victim, ent,id, Damage, DMG_BLAST)	//take damage entity
		}
	} 

	emit_sound(ent, CHAN_WEAPON, TOUCH_SKILL, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

	if(pev_valid(ent))engfunc(EngFunc_RemoveEntity, ent)

	return HAM_HANDLED
}

public remove_values(id)
{
	remove_task(id)
}

public zp_user_infected_pre(id) 
{ 
    	if(!(get_user_flags(id) & ADMIN_LEVEL_E)) 
	{ 
        	if(zp_get_user_next_class(id) == g_has_Povelitel) 
		{ 
            		zp_set_user_zombie_class(id, 0) 
	    		client_print(id, print_chat, "Esta clase es solo para Zeus")
        	}     
    	}	 
} 
			
//ZP
#if !defined TestingTime
public zp_user_infected_post(id,infector,nemesis)
{
	if(!zp_get_user_nemesis(id))Can_Use_Ability[id-1]=true
}

public fw_PlayerKilled(id, attacker, shouldgib) 
{
	remove_values(id)
}

public zp_user_humanized_post(id)
{
	Can_Use_Ability[id-1]=false,in_frost[id-1]=false,in_burn[id-1]=false
	remove_values(id)
}
#endif
//Standart Forwards
public client_connect(id)
{
	Can_Use_Ability[id-1]=false,Selected_Ability[id-1]=0
	remove_values(id)
}

public client_PreThink(id)
{
	if(!is_user_alive(id))return
	
	new Float:gametime = get_gametime()
	if(in_frost[id-1])
		#if defined TestingTime
		if(FrostTime[id-1]<gametime||!is_user_alive(id))
		#else
		if(FrostTime[id-1]<gametime||!is_user_alive(id)||zp_get_user_zombie(id))
		#endif
			fm_set_rendering(id),
			in_frost[id-1]=false
		else
			{set_pev(id,pev_velocity,{0.0,0.0,0.0});new Float:Origin[3];pev(id,pev_origin,Origin);Light(Origin,15,0,105,255,4);}
	if(in_burn[id-1])
		#if defined TestingTime
		if(BurnTime[id-1]<gametime||!is_user_alive(id))
		#else
		if(BurnTime[id-1]<gametime||!is_user_alive(id)||zp_get_user_zombie(id))
		#endif
			in_burn[id-1]=false
		else
			if(BurnUpdateDamage[id-1]<gametime)
			{
				if(pev(id,pev_armorvalue)<=0.0&&pev(id,pev_health)<BurnDamage)ExecuteHamB(Ham_TakeDamage,id, 0,BurnOwner[id-1], BurnDamage, DMG_BURN)
				else ExecuteHamB(Ham_TakeDamage,id, 0,0, BurnDamage, DMG_BURN)
				
				BurnUpdateDamage[id-1]=gametime+BurnUpdate
				
				new Float:Origin[3]
				pev(id,pev_origin,Origin)
				engfunc(EngFunc_MessageBegin, MSG_BROADCAST, SVC_TEMPENTITY, Origin, 0)
				write_byte(TE_SPRITE) // TE id
				engfunc(EngFunc_WriteCoord, Origin[0]+random_float(-5.0, 5.0)) // x
				engfunc(EngFunc_WriteCoord, Origin[1]+random_float(-5.0, 5.0)) // y
				engfunc(EngFunc_WriteCoord, Origin[2]+random_float(-10.0, 10.0)) // z
				write_short(BurnSprite) // sprite
				write_byte(random_num(5, 10)) // scale
				write_byte(200) // brightness
				message_end()
				Light(Origin,15,255,105,0,7)	
			}
	if(!is_user_alive(id))return
	#if !defined TestingTime
	if(!zp_get_user_zombie(id))return
	if(zp_get_user_nemesis(id))return
	if(zp_get_user_zombie_class(id)!=g_has_Povelitel)return
	#endif
	if(UpdateHud[id-1]<gametime)
	{
		new Text0[100], Text1[56],Text2[56]
		formatex(Text0, 99, "Presione [E] Cambiar atributo ^n Presione [G] Use^n^n")
		switch(Selected_Ability[id-1])
		{
			case 0:formatex(Text1, 55, "Elemento: fuego^n")
			case 1:formatex(Text1, 55, "Elemento: hielo^n")
		}
		if(!Can_Use_Ability[id-1])
		{
			if(Ability_CD[id-1]-gametime>0.0)formatex(Text2, 55, "Esperar: %..1f^n",Ability_CD[id-1]-gametime)
			else formatex(Text2, 55, "Elemento: Hecho^n"),Can_Use_Ability[id-1]=true
		}
		set_hudmessage(255,0,255,0.57,0.2,0,0.1,1.0,0.0,0.0,CDHudChannel)
		show_hudmessage(id,"%s%s%s",Text0,Text1,Text2)
		UpdateHud[id-1]=gametime+0.1
	}
	//Select Ability
	if((pev(id,pev_button)&IN_USE)&&!(pev(id,pev_oldbuttons)&IN_USE))
	{
		switch(Selected_Ability[id-1])
		{
			case 0:Selected_Ability[id-1]=1
			case 1:Selected_Ability[id-1]=0
		}
	}
	//Use ability
	if(Can_Use_Ability[id-1])
	if (pev(id,pev_impulse)==100)
	{
		switch(Selected_Ability[id-1])
		{
			case 0:throw_Shpere(id,1),Ability_CD[id-1]=gametime+FireShpere_CD,Can_Use_Ability[id-1]=false
			case 1:throw_Shpere(id,2),Ability_CD[id-1]=gametime+FrostSphere_CD,Can_Use_Ability[id-1]=false
		}
		
	}
}
//Public func
public throw_Shpere(id,type)
{
	set_pdata_float(id, 83, 0.7, 5)
	UTIL_PlayWeaponAnimation(id,5)
	
	new Float:StartOrigin[3],Float:EndOrigin[3]
	get_position(id,30.0,0.0,5.0,StartOrigin)
	fm_get_aim_origin(id,EndOrigin)
	
	new ient = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	engfunc(EngFunc_SetModel,ient, Shpere)
	engfunc(EngFunc_SetSize, ient, {-3.0,-3.0,-3.0}, {3.0,3.0,3.0})
	switch(type)
	{
		case 1:	set_pev(ient, pev_classname, FireShpere_Classname),
			fm_set_rendering(ient, kRenderFxGlowShell, 255,155,0, kRenderTransAlpha,25)
		case 2:	set_pev(ient, pev_classname, FrostSphere_Classname),
			fm_set_rendering(ient, kRenderFxGlowShell, 0,105,255, kRenderTransAlpha,25)
	}
	set_pev(ient, pev_movetype, MOVETYPE_FLY)
	set_pev(ient,pev_solid,SOLID_TRIGGER)
	set_pev(ient,pev_origin,StartOrigin)
	set_pev(ient,pev_owner,id)
	set_pev(ient, pev_nextthink, get_gametime() +0.01)		
	set_pev(ient,pev_iuser1,type)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(ient)
	write_short(TrailSpriteIndex)
	write_byte(15)
	write_byte(15)
	switch(type)
	{
		case 1:
		{
			write_byte(255)
			write_byte(155)
			write_byte(0)
		}
		case 2:
		{
			write_byte(0)
			write_byte(0)
			write_byte(255)
		}
	}
	write_byte(255)
	message_end()
	
	new Float:VECTOR[3],Float:VELOCITY[3]
	xs_vec_sub(EndOrigin, StartOrigin, VECTOR)
	xs_vec_normalize(VECTOR, VECTOR)
	xs_vec_mul_scalar(VECTOR, 1300.0, VELOCITY)
	set_pev(ient, pev_velocity, VELOCITY)
}
//Stocks
stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
	new Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	pev(id, pev_v_angle, vAngle);pev(id, pev_origin, vOrigin);pev(id, pev_view_ofs,vUp)
	xs_vec_add(vOrigin,vUp,vOrigin)
	angle_vector(vAngle,ANGLEVECTOR_FORWARD,vForward)
	angle_vector(vAngle,ANGLEVECTOR_RIGHT,vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP,vUp)
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}
stock DrawRings(Float:Origin[3],R,G,B)
{
	for(new i=0;i<4;i++)
	{
		message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
		write_byte( TE_BEAMTORUS );
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2]+3.0*i)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2]+100.0+10.0*i)
		write_short( TrailSpriteIndex ); // sprite
		write_byte( 0 ); // Starting frame
		write_byte( 0  ); // framerate * 0.1
		write_byte( 8-1*i ); // life * 0.1
		write_byte( 14 ); // width
		write_byte( 0 ); // noise
		write_byte( R ); // color r,g,b
		write_byte( G ); // color r,g,b
		write_byte( B); // color r,g,b
		write_byte( 255 ); // brightness
		write_byte( 0 ); // scroll speed
		message_end();  
	}	
}
stock Light(Float:Origin[3],RAD,R,G,B,Life)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_DLIGHT)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_byte(RAD)	//Radius
	write_byte(R)	// r
	write_byte(G)	// g
	write_byte(B)	// b
	write_byte(Life)	//Life
	write_byte(10)
	message_end() 
}
stock ScreenFade(id, Timer, FadeTime, Colors[3], Alpha, type)
{
	if(id) if(!is_user_connected(id)) return

	if (Timer > 0xFFFF) Timer = 0xFFFF
	if (FadeTime <= 0) FadeTime = 4
	
	message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST,Msg_ScreenFade, _, id);
	write_short(Timer * 1 << 12)
	write_short(FadeTime * 1 << 12)
	switch (type) {
		case 1: write_short(0x0000)		// IN ( FFADE_IN )
		case 2: write_short(0x0001)		// OUT ( FFADE_OUT )
		case 3: write_short(0x0002)		// MODULATE ( FFADE_MODULATE )
		case 4: write_short(0x0004)		// STAYOUT ( FFADE_STAYOUT )
		default: write_short(0x0001)
	}
	write_byte(Colors[0])
	write_byte(Colors[1])
	write_byte(Colors[2])
	write_byte(Alpha)
	message_end()
}
stock ScreenShake(id, duration, frequency)
{	
	message_begin(id ? MSG_ONE_UNRELIABLE : MSG_ALL, Msg_ScreenShake, _, id ? id : 0);
	write_short(1<<14)
	write_short(duration)
	write_short(frequency)
	message_end();
}
stock UTIL_PlayWeaponAnimation(const Player, const Sequence)
{
	set_pev(Player, pev_weaponanim, Sequence)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = Player)
	write_byte(Sequence)
	write_byte(pev(Player, pev_body))
	message_end()
}
