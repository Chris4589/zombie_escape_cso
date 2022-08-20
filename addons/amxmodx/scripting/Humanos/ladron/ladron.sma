#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <fakemeta_util>
#include <zombie_escape_v1>

native zp_set_drop(id, cant)

new g_pick;
new const hclass1_name[] = { "Ladron" }
new const hclass1_info[] = { "E para Robar arma del Suelo" }
new const hclass1_model[] = { "ladron" }
const hclass1_health = 100
const hclass1_speed = 350
const Float:hclass1_gravity = 1.0
const Float:hclass1_knockback = 1.0

#define MSG_SHOW_MIN_TIME 0.1

new is_glowing[33]

new last_ent[33],can_touch[33]
new onoff,dist,glow,glow_color

new red,green,blue

public plugin_init() {
	register_plugin("Human Weapon Pickup","0.9","Sh!nE & Randro v:")
	
	onoff = register_cvar("amx_rwpickup","1")
	dist = register_cvar("amx_rwp_distance","31")
	glow = register_cvar("amx_rwp_glow","1")
	glow_color = register_cvar("amx_rwp_glow_color","75 0 255")
	
	register_logevent("round_start",2,"1=Round_Start")
	
	register_forward(FM_CmdStart,"cmd_start")
	
	RegisterHam(Ham_Touch,"weaponbox","touch_weapon")
	RegisterHam(Ham_Touch,"armoury_entity","touch_weapon")
	RegisterHam(Ham_Touch,"weapon_shield","touch_weapon")
	
	register_forward(FM_AddToFullPack,"addtofullpack",1)

	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
}


public plugin_precache()
g_pick = zp_register_class(CLASS_HUMAN, hclass1_name, hclass1_info, hclass1_model, "default", 0,  4, ADMIN_ALL, hclass1_health, 15, hclass1_speed, hclass1_gravity, hclass1_knockback)
    

public round_start() {
	new temp_rgb[12],temp_rgb2[3][4]
	get_pcvar_string(glow_color,temp_rgb,11)
	
	parse(temp_rgb,temp_rgb2[0],3,temp_rgb2[1],3,temp_rgb2[2],3)

	red=str_to_num(temp_rgb2[0])
	green=str_to_num(temp_rgb2[1])
	blue=str_to_num(temp_rgb2[2])
}

public addtofullpack(es_handle,e,ent,id,hostflags,player,pSet) {
	if(!is_user_alive(id) || !get_pcvar_num(onoff) || !get_pcvar_num(glow) || (id==ent) || is_user_bot(id) || zp_get_class(id) >= SURVIVOR) return FMRES_IGNORED
	
	if(is_glowing[id]==ent) {
		new rgb[3]
		
		rgb[0]=red
		rgb[1]=green
		rgb[2]=blue
		
		set_es(es_handle,ES_RenderMode,kRenderNormal)
		set_es(es_handle,ES_RenderFx,kRenderFxGlowShell)
		set_es(es_handle,ES_RenderAmt,16)
		set_es(es_handle,ES_RenderColor,rgb)
	}
	return FMRES_IGNORED
}

public cmd_start(id,uc_handle,random_seed) {
	if(!is_user_alive(id) || !get_pcvar_num(onoff) || is_user_bot(id)) return FMRES_IGNORED

	if(zp_get_user_human_class(id) != g_pick || zp_get_class(id) > SURVIVOR)
	 return FMRES_IGNORED;
	
	static buttons
	buttons=get_uc(uc_handle,UC_Buttons)
	
	new ent = get_aim_origin_ent(id)
	
	if(ent!=last_ent[id]) {
		is_glowing[id]=0
		last_ent[id]=ent
	}
	
	if(!ent) {
		remove_task(id)
		return FMRES_IGNORED
	}
	
	is_glowing[id]=ent
	
	if(!task_exists(id)) set_task(MSG_SHOW_MIN_TIME,"show_pickup",id,_,_,"b")
	
	if(buttons & IN_USE) {
		can_touch[id]=ent
		dllfunc(DLLFunc_Touch,ent,id)
	}
	else if(!(buttons & IN_USE)) can_touch[id]=0
		
	return FMRES_IGNORED
}

public show_pickup(id) {
	set_hudmessage(red,green,blue,-1.0,0.88,0,6.0,MSG_SHOW_MIN_TIME)
	show_hudmessage(id,"Preciona E para agarrar")
}

public client_disconnected(id) {
	is_glowing[id]=0
	last_ent[id]=0
	can_touch[id]=0
	
	remove_task(id)
}	

public touch_weapon(ent,id) {
	if(!is_user_alive(id) || !get_pcvar_num(onoff) || is_user_bot(id)) return HAM_IGNORED
	
	if(can_touch[id]==ent) {
		can_touch[id]=0
		return HAM_IGNORED
	}
	return HAM_SUPERCEDE
}

stock get_aim_origin_ent(id) {
	new ent=-1
	static Float:origin[2][3]
	
	pev(id,pev_origin,origin[0])
	fm_get_aim_origin(id,origin[1])
	
	if(get_distance_f(origin[0],origin[1]) > float(get_pcvar_num(dist))) return 0
	
	while((ent = engfunc(EngFunc_FindEntityInSphere,ent,origin[1],5.0))) {
		static classname[33]
		pev(ent,pev_classname,classname,32)
		
		if(equal(classname,"weaponbox") || equal(classname,"armoury_entity") || equal(classname,"weapon_shield")) return ent
	}
	return 0
}

public fw_PlayerSpawn_Post(id)
{
	if(zp_get_user_human_class(id) == g_pick)
	{
		zp_set_drop(id, 1);
	}
	else
		zp_set_drop(id, 0)

}


public zp_user_humanized_post(id, survivor)
{
	if(zp_get_user_human_class(id) == g_pick)
	{
		zp_set_drop(id, 1)
	}
	else
		zp_set_drop(id, 0)
}


	