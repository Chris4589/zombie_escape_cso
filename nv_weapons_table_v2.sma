/* 
*
* 	The Plugin is Made by N.O.V.A , It is a Private and Paid Job !!
* 	
*	Contacts:-
*
* 		Fb:- facebook.com/nova.gaming.cs
* 		Insta :-  instagram.com/_n_o_v_a_g_a_m_i_n_g
* 		Discord :- N.O.V.A#1790
* 		Youtube :- NOVA GAMING
*
*
*/

/*----------------------------------*/
/*           INCLUDES               */
/*----------------------------------*/

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fun>
#include <cstrike>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <zp43_armas>

/*----------------------------------*/
/*            DEFINES               */
/*----------------------------------*/

#define PLUGIN "[N:V] WEAPON:TABLE"
#define VERSION "24-11-21"
#define AUTHOR "N.O.V.A"

#define MAX_ITEMS 512
#define MAX_TABLES 5

/*----------------------------------*/
/*         ANTI-DECOMPILE           */
/*----------------------------------*/

#pragma compress 1
#pragma semicolon 1


/*----------------------------------*/
/*           MODE-SUPPORTS          */
/*----------------------------------*/

// Uncomment the Mod you are using and Comment the Others by "///"

//#define NORMAL_MOD
//#define ZOMBIE_ESCAPE_MOD
#define ZOMBIE_PLAUGE

//#define LEVEL_SYSTEM_ON

#if defined LEVEL_SYSTEM_ON
	
	#define nv_get_user_level(id)	ze_get_user_level(id)
	
#endif

#if defined NORMAL_MOD
	
	#define nv_get_user_money(%0)		cs_get_user_money(%0)
	#define nv_set_user_money(%0,%1)	cs_set_user_money(%0,%1)
	
#endif

#if defined ZOMBIE_ESCAPE_MOD

	// Natives
	native 	ze_is_user_zombie(id);
	native 	ze_get_escape_coins(id);
	native 	ze_set_escape_coins(id,ammount);
	native 	ze_force_buy_item(id, iItemid, bIgnoreCost);
	native 	ze_get_item_id(const szItemName[]);
	
	#define nv_get_user_money(%0)		ze_get_escape_coins(%0)
	#define nv_set_user_money(%0,%1)	ze_set_escape_coins(%0,%1)
	
#endif

#if defined ZOMBIE_PLAUGE

	// Natives
	native	zp_get_user_zombie(id);
	native	zp_get_user_ammo_packs(id);
	native	zp_set_user_ammo_packs(id,ammount);
	native 	zp_force_buy_extra_item(id, itemid, ignorecost = 0);
	native 	zp_get_extra_item_id(const name[]);

	#define nv_get_user_money(%0)		zp_get_user_ammo_packs(%0)
	#define nv_set_user_money(%0,%1)	zp_set_user_ammo_packs(%0,%1)
	
#endif



/*----------------------------------*/
/*             NEWS                 */
/*----------------------------------*/

new const CLASSNAME_PREVIEW_SOLID[] = "nv_weapon_table";
new const CLASSNAME_PREVIEW_PREVIEW[] = "nv_weapon_table_preview";
new const CLASSNAME_WEAPON_ENTITY[] = "nv_weapon_table_wpn_box";
new const MODEL_TABLE[] = "models/bynova/weapon_table.mdl";

const XTRA_OFS_WEAPON = 4;
const m_pNext = 42;
const XTRA_OFS_PLAYER = 5;
const m_rgpPlayerItems_Slot0 = 367;
const m_iId = 43;

new const primaryWeapons[][] = 
{
	"weapon_shield",
	"weapon_scout",
	"weapon_xm1014",
	"weapon_mac10",
	"weapon_aug",
	"weapon_ump45",
	"weapon_sg550",
	"weapon_galil",
	"weapon_famas",
	"weapon_awp",
	"weapon_mp5navy",
	"weapon_m249",
	"weapon_m3",
	"weapon_m4a1",
	"weapon_tmp",
	"weapon_g3sg1",
	"weapon_sg552",
	"weapon_ak47",
	"weapon_p90"
};
new const secondaryWeapons[][] = 
{
	"weapon_p228",
	"weapon_elite",
	"weapon_fiveseven",
	"weapon_usp",
	"weapon_glock18",
	"weapon_deagle"
};

enum _:EItemsData
{
	g_iExtraItemModel[128],
	g_iExtraItemName[128],
	g_iExtraItemCost,
	g_iExtraItemCtype,
	g_iExtraItemMode,
	g_iExtraItemIndex,
	g_iExtraItemLimit,
	g_iExtraItemLevel,
	g_iExtraItemFlag[10]
	
};
 
new g_pItemsData[ MAX_ITEMS ][ EItemsData ],g_spr;
new g_player_table[33],g_szConfigFile[128],g_Player_Ctype[33],g_iExtraItemsNum,g_ebutton,g_iCvar;
new keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0;
new Float:g_CoolDown[MAX_PLAYERS+1];
new Float:g_CoolDownId[MAX_PLAYERS+1];
new g_iLimit[MAX_ITEMS];

/*----------------------------------*/
/*         PLUGIN-FUNCTION          */
/*----------------------------------*/

public plugin_init()
{
	// Load Them Here Because Puting Them in precache Fxn Cause Crash Errors !!
	
	read_files();
	load_spawns();
	
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_cvar("[N:V] Weapon Table", VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED);
	g_iCvar = register_cvar("nv_table_max_number","5");
	
	RegisterHam(Ham_Spawn,"player","Fw_HamSpawn",1);
	register_forward(FM_PlayerPreThink, "Fw_PlayerPreThink");
	register_clcmd("say /planttable","cl_cmd");
	register_think(CLASSNAME_PREVIEW_PREVIEW,"think_ent");
	register_think(CLASSNAME_PREVIEW_SOLID,"think_solid_ent");
	register_menu("tablemenu", keys, "table_menu");
	
	
}

/*=-----------Precaches---------------=*/


public plugin_precache()
{
	precache_model(MODEL_TABLE);
	g_ebutton = precache_model("sprites/e_button_red.spr");
	g_spr = precache_model("sprites/equip_icon.spr");
	
	
	for(new i = 1; i <= g_iExtraItemsNum; i++)
	{
		precache_model(g_pItemsData[i][g_iExtraItemModel]);
	}
	
}


/*----------------------------------*/
/*           SPAWN-FUNCTION         */
/*----------------------------------*/

public client_connect(id) 
{
	g_CoolDown[id] = 0.0;
	g_CoolDownId[id] = 0.0;

}
public client_disconnected(id)
{
	g_CoolDown[id] = 0.0;
	g_CoolDownId[id] = 0.0;
}

public Reset_Limit(id)
{
	for(new i = 1; i <= g_iExtraItemsNum; i++)
	{
		g_iLimit[i] = 0;
	}
}
public Fw_HamSpawn(id)
{
	if(is_user_alive(id))
	{
		g_CoolDown[id] = 0.0;
		g_CoolDownId[id] = 0.0;
		Reset_Limit(id);
	}
}
public read_files()
{
	new szText[512];
	new iFile;

	iFile = fopen( "addons/amxmodx/configs/bynova/wpn_table.ini", "rt" );

	if(!iFile )
		set_fail_state("[N:V] wpn_table.ini File Not Found !");

	while( !feof( iFile ) )
	{
		fgets( iFile, szText, charsmax( szText ) );

		if( !strlen( szText ) || szText[ 0 ] == ';'  || ( szText[ 0 ] == '/' && szText[ 1 ] == '/' ) )
			continue;
	
		new szCost[ 32 ],szName[128],szModel[128],szCtype[32],szLevel[32],szFlag[32],szLimit[32];

		parse(szText,
		szCtype,31,
		szModel,charsmax(szModel), 
		szName, charsmax(szName), 
		szCost,31,
		szLimit,31,
		szLevel,31,
		szFlag,31,
		g_pItemsData[ g_iExtraItemsNum ][ g_iExtraItemMode ] , 128);
		
		g_pItemsData[ g_iExtraItemsNum ][ g_iExtraItemCtype ] = str_to_num(szCtype);
		g_pItemsData[ g_iExtraItemsNum ][ g_iExtraItemLimit ] = str_to_num(szLimit);
		g_pItemsData[ g_iExtraItemsNum ][ g_iExtraItemLevel ] = str_to_num(szLevel);
		g_pItemsData[ g_iExtraItemsNum ][ g_iExtraItemCost ] = str_to_num(szCost);
		
		copy(g_pItemsData[g_iExtraItemsNum][g_iExtraItemFlag],charsmax(g_pItemsData[][g_iExtraItemFlag]),szFlag);
		copy(g_pItemsData[g_iExtraItemsNum][g_iExtraItemName],charsmax(g_pItemsData[][g_iExtraItemName]),szName);
		copy(g_pItemsData[g_iExtraItemsNum][g_iExtraItemModel],charsmax(g_pItemsData[][g_iExtraItemModel]),szModel);
		g_iExtraItemsNum++;
	
	}
	
	fclose( iFile );
	

}

public load_spawns()
{
	new szMapName[32],sfile[128];
	get_mapname(szMapName, 31);
	get_localinfo("amxx_configsdir",sfile,charsmax(sfile));
	strtolower(szMapName);
	formatex(g_szConfigFile, 127, "%s/bynova/wpn_table",sfile);
	
	if(!dir_exists(g_szConfigFile)) 
	{
		log_amx("[N:V] Weapon Table Cannot Find Directory... Created it");
		mkdir(g_szConfigFile);
		format(g_szConfigFile, 127, "%s/%s.txt", g_szConfigFile, szMapName );
		return;
	}
	
	format(g_szConfigFile, 127, "%s/%s.txt", g_szConfigFile, szMapName);
	if(!file_exists(g_szConfigFile)) 
	{
		fopen(g_szConfigFile, "at");
		
	}
	
	new iFile = fopen( g_szConfigFile, "rt" );
	
	if(!iFile) return;
	
	new x[16], y[16], z[16], Angle[16],Type[15]; new szData[charsmax(x) + charsmax(y) + charsmax(z) + charsmax(Angle) + charsmax(Type)];
	
	new Float:vOrigin[3],Float:vAngle[3],c_type;
	
	while(!feof(iFile)) 
	{
		fgets(iFile, szData, charsmax(szData));
		trim(szData);
		
		if(!szData[0]) continue;
		
		parse(szData, x, 15, y, 15, z, 15,Angle,15,Type,15);
		
		vOrigin[0] = str_to_float(x);
		vOrigin[1] = str_to_float(y);
		vOrigin[2] = str_to_float(z);
		vAngle[1] = str_to_float(Angle);
		c_type = str_to_num(Type);
		
		Create_Solid(vOrigin,vAngle,c_type);
		
	}
	
	log_amx("[N:V] Wpn Table Directory Found...Activated");
	
	fclose(iFile);
}

/*=-------Save The Spawns---------=*/

public Save_Spawns(ent)
{
	new iFile = fopen(g_szConfigFile, "at");
	
	if(!iFile) return;
	
	
	new Float:vOrigin[3],Float:vAngle[3];
	pev(ent, pev_origin, vOrigin);
	pev(ent, pev_angles, vAngle);
	
	fprintf(iFile, "%f %f %f %f %d^n", vOrigin[0], vOrigin[1], vOrigin[2],vAngle[1],pev(ent,pev_iuser1));
	
	fclose(iFile);
}


public Fw_PlayerPreThink(id,uc_handle,seed)
{
	if(is_user_alive(id))
	{
		new PressButton; PressButton = pev(id, pev_button);
		new OldButton; OldButton = pev(id, pev_oldbuttons);
		new target , ent,body;
		get_user_aiming(id,target,body,150);
		while((ent = find_ent_by_class(ent,CLASSNAME_WEAPON_ENTITY)))
		{
			if(ent == target)
			{
				if(pev_valid(ent))
				{
					fm_set_rendering(ent , kRenderFxGlowShell, 255,0,0, kRenderNormal, 16);
					Create_E_Button(ent);
					
					if(g_CoolDownId[id] < get_gametime())
					{
						client_print(id,print_center,"--=== Press Button 'E' .. ==--");
						g_CoolDownId[id] = get_gametime() + 5.0;
					}
					
					if(!(OldButton & IN_USE) && PressButton & IN_USE)
					{
						if(is_target_capable(id))
						{
							Give_items(id,ent);
							
						}
					}
				}
			}
			else
			{
				fm_set_rendering(ent);
			}
		}
	}
		
}

public Give_items(id,ent)
{
	new i = pev(ent,pev_iuser2);
	
	static Float:flGameTime; flGameTime = get_gametime();
	
	if(g_CoolDown[id] > flGameTime)
	{
		client_print(id,print_center,"--=== You Are Buying Too Fast Wait.. ==--");
		return PLUGIN_HANDLED;
	}
	
	if(g_pItemsData[i][g_iExtraItemLimit] != 0)
	{
		if(g_iLimit[i] >= g_pItemsData[i][g_iExtraItemLimit])
		{
			client_print(id,print_center,"--=== Max Limits Reached.. ==--");
			return PLUGIN_HANDLED;
		}
	}
	
	#if defined LEVEL_SYSTEM_ON
	
	if(g_pItemsData[i][g_iExtraItemLevel] != 0)
	{
		if(nv_get_user_level(id) < g_pItemsData[i][g_iExtraItemLevel])
		{
			client_print(id,print_center,"--=== Not Available For Your Level.. ==--");
			return PLUGIN_HANDLED;
		}
	}
	
	#endif
	
	if(g_pItemsData[i][g_iExtraItemCost] != 0)
	{
		
		if(nv_get_user_money(id) < g_pItemsData[i][g_iExtraItemCost])
		{
			Nv_Chat(id,"^3[^4Weapons-Table^3] You Don't Have Enough Money ^4%d $.",g_pItemsData[i][g_iExtraItemCost]);
			return PLUGIN_HANDLED;
		}
	}
	
	if(g_pItemsData[i][g_iExtraItemFlag] != '0')
	{
		if(!(get_user_flags(id) & read_flags(g_pItemsData[i][g_iExtraItemFlag])))
		{
			Nv_Chat(id,"^3[^4Weapons-Table^3] You Don't Have Access To This Weapon");
			return PLUGIN_HANDLED;
		}
	}
	
	nv_set_user_money(id,nv_get_user_money(id) - g_pItemsData[i][g_iExtraItemCost]);
	g_CoolDown[id] = flGameTime + 1.0;
	g_iLimit[i] += 1;
	
	switch(g_pItemsData[i][ g_iExtraItemMode ])
	{
		#if defined ZOMBIE_PLAUGE
		
		case 'E': zp_weapons_force_buy( id, g_pItemsData[i][g_iExtraItemName]);
		
		#endif	
		
		#if defined ZOMBIE_ESCAPE_MOD
		
		case 'E': ze_force_buy_item( id, ze_get_item_id(g_pItemsData[i][g_iExtraItemName]),true);
		
		#endif
		
		case 'C': client_cmd(id,g_pItemsData[i][ g_iExtraItemName]);
		case 'D': 
		{
			for(new ie = 0; ie < sizeof primaryWeapons; ie++)
			{
				if(equal(primaryWeapons[ie],g_pItemsData[i][ g_iExtraItemName]))
				{
					StripWeapons(id,1);
				}
			}
			for(new ie = 0; ie < sizeof secondaryWeapons; ie++)
			{
				if(equali(secondaryWeapons[ie],g_pItemsData[i][ g_iExtraItemName]))
				{
					StripWeapons(id,2);
				}
			}
			
			give_item(id,g_pItemsData[i][ g_iExtraItemName]);
			cs_set_user_bpammo(id,get_weaponid(g_pItemsData[i][ g_iExtraItemName]),90);
		}
		
	}
	
	return PLUGIN_HANDLED;
}
/*----------------------------------*/
/*           CREATE-ENTITY          */
/*----------------------------------*/


public Create_Solid(const Float:vNewOrigin[3],Float:vAngle[3],c_type)
{
	
	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_breakable"));
	set_pev(ent, pev_classname, CLASSNAME_PREVIEW_SOLID);
	entity_set_model(ent, MODEL_TABLE);
	entity_set_size(ent,Float:{-2.0,-2.0,-2.0},Float:{5.0,5.0,5.0});
	set_pev(ent, pev_solid, SOLID_NOT);
	set_pev(ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(ent, pev_origin, vNewOrigin);
	set_pev(ent, pev_angles, vAngle);
	set_pev(ent, pev_iuser1, c_type);
	set_pev(ent,pev_nextthink,get_gametime() + 0.1);
	
	new i,iExtra;
	
	for(iExtra = 0;iExtra <= g_iExtraItemsNum ; iExtra++)
	{
		if(g_pItemsData[iExtra][g_iExtraItemCtype] != pev(ent,pev_iuser1))
			continue;
		
		Create_Fake_Weapon(i,iExtra,ent);
		i++;
	}
	
	return ent;
}


public Create_Fake_Weapon(i,Number,iEntity)
{
	new Float:Origin[3],Float:vAngle[3],Angle_Type[3052];
	pev(iEntity,pev_origin,Origin);
	pev(iEntity,pev_angles,vAngle);
	
	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
	set_pev(ent, pev_classname, CLASSNAME_WEAPON_ENTITY);
	entity_set_model(ent,g_pItemsData[Number][g_iExtraItemModel]);
	entity_set_size(ent,Float:{-2.0,-2.0,-2.0},Float:{5.0,5.0,5.0});
	set_pev(ent, pev_solid, SOLID_BBOX);
	set_pev(ent, pev_movetype, MOVETYPE_FLY);
	
	if(vAngle[1] == 0.0 || vAngle[1] == 180.0)
	{
		Angle_Type[ent] = 0;
	}
	else
	{
		Angle_Type[ent] = 1;
	}
	
	switch(i)
	{
		case 0:
		{ 
			Origin[2] += 40.0; 
		}
		case 1:
		{
			Origin[Angle_Type[ent]?0:1] += 40.0;
			Origin[2] += 40.0;
		}
		case 2:
		{
			Origin[Angle_Type[ent]?0:1] -= 40.0;
			Origin[2] += 40.0;
		}
		case 3:
		{
			Origin[Angle_Type[ent]?0:1] += 35.0;
			vAngle[1] += 90.0;
			Origin[2] += 15.0; 
		}
		case 4:
		{
			Origin[Angle_Type[ent]?0:1] -= 35.0;
			vAngle[1] += 90.0;
			Origin[2] += 15.0; 
		}
	}
	
	set_pev(ent, pev_origin, Origin);
	set_pev(ent, pev_iuser2, Number);
	set_pev(ent, pev_angles, vAngle);
	
	return ent;
}

public Create_Preview(id)
{
	// Engine
	
	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_breakable"));
	set_pev(ent, pev_classname, CLASSNAME_PREVIEW_PREVIEW);
	set_pev(ent, pev_solid, SOLID_NOT);
	set_pev(ent, pev_movetype, MOVETYPE_FLY);
	set_pev(ent,pev_iuser2,id);
	entity_set_model(ent, MODEL_TABLE);
	set_pev(ent,pev_nextthink,get_gametime() + 0.1);
	g_player_table[id] = ent;
	
}

public Create_E_Button(ent)
{
	 new start_[3],Float:start[3];
	 pev(ent,pev_origin,start);
	 FVecIVec(start, start_);

	 message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	 write_byte(TE_SPRITE);
	 write_coord(start_[0]);
	 write_coord(start_[1]);
	 write_coord(start_[2]+ 20);
	 write_short(g_ebutton);
	 write_byte(1) ;
	 write_byte(150) ;
	 message_end();
	
}

/*----------------------------------*/
/*             MENUS                */
/*----------------------------------*/

public cl_cmd(id)
{
	if(is_user_alive(id) && get_user_flags(id) & ADMIN_RCON)
	{
		remove_ent(g_player_table[id]);
		Create_Preview(id);
		clcmd_open_menu(id);
		g_Player_Ctype[id] = 0;
	}


}

public clcmd_open_menu(id)
{

	new menu[512], iLen;
	
	iLen = formatex(menu[iLen], charsmax(menu) - iLen, "\yWelcome To Table Menu^n^n");
	iLen += formatex(menu[iLen], charsmax(menu) - iLen, "^n\r[\y1\r]\w Set The Table");
	iLen += formatex(menu[iLen], charsmax(menu) - iLen, "^n\r[\y2\r]\w Rotate The Table in 45 Degree");
	iLen += formatex(menu[iLen], charsmax(menu) - iLen, "^n\r[\y3\r]\w Create Again The Preview");
	iLen += formatex(menu[iLen], charsmax(menu) - iLen, "^n\r[\y4\r]\w Change Table Type");
	iLen += formatex(menu[iLen], charsmax(menu) - iLen, "^n^n\r[\y5\r]\w Remove All Tables \y(\rIt Will Remove FILE\y)");  
  	iLen += formatex(menu[iLen], charsmax(menu) - iLen, "^n^n\r[\y0\r]\w Exit");
	
	show_menu(id, keys, menu, -1, "tablemenu");
}

public table_menu(id, key)
{
	if(key > 5) remove_ent(g_player_table[id]);
	
	switch(key)
	{
		case 0:
		{
			
			new Ent = g_player_table[id];
			new Float:xOrigin[3],Float:vAngle[3];
			if(pev_valid(Ent))
			{
				if(g_Player_Ctype[id] != 0)
				{
					pev(Ent,pev_angles,vAngle);
					pev(Ent,pev_origin,xOrigin);
					new Spawn = Create_Solid(xOrigin,vAngle,g_Player_Ctype[id]);
					Save_Spawns(Spawn);
					client_print(id,print_center,"Successfully Created The table !!");
					remove_ent(Ent);
				}
				else
				{
					clcmd_open_menu(id);
					client_print(id,print_center,"Error !! Please Select Type Of Table.");
				}
			}
			else
			{
				client_print(id,print_center,"Error !! Cannot Find Preview");
			
			
			}
		}
		case 1:
		{
			clcmd_open_menu(id);
			new Ent = g_player_table[id];
			new Float:vAngle[3];
			if(pev_valid(Ent))
			{
				pev(Ent,pev_angles,vAngle);
				
				if(vAngle[1] < 180.0)
				{
					vAngle[1] += 90.0; 
				}
				else
				{
					vAngle[1] = 0.0; 
				}
				set_pev(Ent,pev_angles,vAngle);
				client_print(id,print_center,"Preview Has Been Rotated 90 Degree");
				
			}
			else
			{
				client_print(id,print_center,"Error !! Cannot Find Preview");
			
			}
		
		}
		case 2:
		{
			clcmd_open_menu(id);
			if(!pev_valid(g_player_table[id])) 
			{
				Create_Preview(id);
				client_print(id,print_center,"Preview Has Been Created !!");
			}
		}
		
		case 3:
		{
			clcmd_open_menu(id);
			if(g_Player_Ctype[id] < get_pcvar_num(g_iCvar))
			{
				g_Player_Ctype[id]++;
				client_print(id,print_center,"Table Type :- %d",g_Player_Ctype[id]);
			}
			else
			{
				g_Player_Ctype[id] = 0;
				client_print(id,print_center,"Table Type Reset To Zero");
			}
		}
		case 4:
		{
			clcmd_open_menu(id);
			new ent;
			while((ent = find_ent_by_class(ent,CLASSNAME_PREVIEW_SOLID)) != 0)
			{
				remove_ent(ent);
				client_print(id,print_center,"Removed All The tables");
			}
			while((ent = find_ent_by_class(ent,CLASSNAME_WEAPON_ENTITY)) != 0)
			{
				remove_ent(ent);
				client_print(id,print_center,"Removed All The Weapons");
			}
			
			if(file_exists(g_szConfigFile))
				delete_file(g_szConfigFile);
			
			
		}
		
		case 9:remove_ent(g_player_table[id]);

	}
}

/*----------------------------------*/
/*             THINKS               */
/*----------------------------------*/

public think_ent(ent)
{
	if(pev_valid(ent))
	{
		new id = pev(ent,pev_iuser2);
		new Float:xOrigin[3];
		if(is_user_alive(id))
		{
			get_user_hitpoint(id,xOrigin);
			entity_set_origin(ent, xOrigin);
			
		}
		else
		{
			remove_ent(ent);
			
		}
		
		if(pev_valid(ent)) set_pev(ent,pev_nextthink,get_gametime() + 0.1);
	
	}


}

public think_solid_ent(ent)
{
	if(pev_valid(ent))
	{
		static Float:Origin[3];
		pev(ent,pev_origin,Origin);
		te_sprite(Origin,g_spr,5,255);
		set_pev(ent,pev_nextthink,get_gametime() + 0.1);
	}
}
public remove_ent(ent)
{
	if(pev_valid(ent)) 
	{
		
		remove_entity(ent);
	}

}

/*----------------------------------*/
/*             STOCKS               */
/*----------------------------------*/

stock get_user_hitpoint(id, Float:hOrigin[3])  
{ 
	if (!is_user_alive(id)) 
	return 0; 
	
	new Float:fOrigin[3], Float:fvAngle[3], Float:fvOffset[3], Float:fvOrigin[3], Float:feOrigin[3]; 
	new Float:fTemp[3]; 
	
	pev(id, pev_origin, fOrigin); 
	pev(id, pev_v_angle, fvAngle); 
	pev(id, pev_view_ofs, fvOffset); 
	
	xs_vec_add(fOrigin, fvOffset, fvOrigin); 
	
	engfunc(EngFunc_AngleVectors, fvAngle, feOrigin, fTemp, fTemp); 
	
	xs_vec_mul_scalar(feOrigin, 9999.0, feOrigin); 
	xs_vec_add(fvOrigin, feOrigin, feOrigin); 
	
	engfunc(EngFunc_TraceLine, fvOrigin, feOrigin, 0, id); 
	global_get(glb_trace_endpos, hOrigin); 
	
	return 1; 
} 

public is_target_capable(id)
{
	if(is_user_alive(id))
	{
		
		#if defined ZOMBIE_ESCAPE_MOD
		if(ze_is_user_zombie(id))
			return false;
		
		#endif
		
		#if defined ZOMBIE_PLAUGE
		
		if(zp_get_user_zombie(id))
			return false;
			
		#endif
		
	}
	return true;
}

 
stock Nv_Chat(const id, const input[], any:...)
{
	new count = 1, players[32];
	static msg[191];
	vformat(msg, 190, input, 3);
       
	replace_all(msg, 190, "!g", "^4"); // Green Color
	replace_all(msg, 190, "!y", "^1"); // Default Color
	replace_all(msg, 190, "!team", "^3"); // Team Color
	replace_all(msg, 190, "!team2", "^0"); // Team2 Color
       
	if (id) players[0] = id; else get_players(players, count, "ch");
	{
		for (new i = 0; i < count; i++)
		{
			if (is_user_connected(players[i]))
			{
				message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, players[i]);
				write_byte(players[i]);
				write_string(msg);
				message_end();
			}
		}
	}
}
/*
stock create_icon_origin(id, ent, sprite) // By sontung0
{
	if (!pev_valid(ent)) return;
	
	new Float:fMyOrigin[3];
	entity_get_vector(id, EV_VEC_origin, fMyOrigin);
	
	new target = ent;
	new Float:fTargetOrigin[3];
	entity_get_vector(target, EV_VEC_origin, fTargetOrigin);
	fTargetOrigin[2] += 80.0;
	
	if (!is_in_viewcone(id, fTargetOrigin)) return;

	new Float:fMiddle[3], Float:fHitPoint[3];
	xs_vec_sub(fTargetOrigin, fMyOrigin, fMiddle);
	trace_line(-1, fMyOrigin, fTargetOrigin, fHitPoint);
							
	new Float:fWallOffset[3], Float:fDistanceToWall;
	fDistanceToWall = vector_distance(fMyOrigin, fHitPoint) - 1.0;
	normalize(fMiddle, fWallOffset, fDistanceToWall);
	
	new Float:fSpriteOffset[3];
	xs_vec_add(fWallOffset, fMyOrigin, fSpriteOffset);
	new Float:fScale;
	fScale = 0.01 * fDistanceToWall;
	
	new scale = floatround(fScale);
	scale = max(scale, 2);
	scale = min(scale, 6);
	scale = max(scale, 2);

	te_sprite(id, fSpriteOffset, sprite, scale, 200);
}
*/
stock te_sprite(Float:origin[3], sprite, scale, brightness) // By sontung0
{	
	message_begin_f(MSG_BROADCAST, SVC_TEMPENTITY,origin,0);
	write_byte(TE_SPRITE);
	write_coord_f(origin[0]);
	write_coord_f(origin[1]);
	write_coord_f(origin[2] + 80.0);
	write_short(sprite);
	write_byte(scale) ;
	write_byte(brightness);
	message_end();
}
stock normalize(Float:fIn[3], Float:fOut[3], Float:fMul) // By sontung0
{
	new Float:fLen = xs_vec_len(fIn);
	xs_vec_copy(fIn, fOut);
	
	fOut[0] /= fLen, fOut[1] /= fLen, fOut[2] /= fLen;
	fOut[0] *= fMul, fOut[1] *= fMul, fOut[2] *= fMul;
}

stock GetWeaponFromSlot( id , iSlot , &iEntity )
{
	if ( !( 1 <= iSlot <= 5 ) )
		return 0;
	
	iEntity = 0;
	const m_rgpPlayerItems_Slot0 = 367;
	const m_iId = 43;
	const XO_WEAPONS = 4;
	const XO_PLAYER = 5;
		
	iEntity = get_pdata_cbase( id , m_rgpPlayerItems_Slot0 + iSlot , XO_PLAYER );
	
	return ( iEntity > 0 ) ? get_pdata_int( iEntity , m_iId , XO_WEAPONS ) : 0;
} 
stock StripWeapons(id, Type, bool: bSwitchIfActive = true)
{
	new iReturn;
	
	if(is_user_alive(id))
	{
		new iEntity, iWeapon;
		while((iWeapon = GetWeaponFromSlot(id, Type, iEntity)) > 0)
			iReturn = ham_strip_user_weapon(id, iWeapon, Type, bSwitchIfActive);
	}
	
	return iReturn;
}

stock ham_strip_user_weapon(id, iCswId, iSlot = 0, bool:bSwitchIfActive = true)
{
	new iWeapon;
	if( !iSlot )
	{
		static const iWeaponsSlots[] = {
			-1,
			2, //CSW_P228
			-1,
			1, //CSW_SCOUT
			4, //CSW_HEGRENADE
			1, //CSW_XM1014
			5, //CSW_C4
			1, //CSW_MAC10
			1, //CSW_AUG
			4, //CSW_SMOKEGRENADE
			2, //CSW_ELITE
			2, //CSW_FIVESEVEN
			1, //CSW_UMP45
			1, //CSW_SG550
			1, //CSW_GALIL
			1, //CSW_FAMAS
			2, //CSW_USP
			2, //CSW_GLOCK18
			1, //CSW_AWP
			1, //CSW_MP5NAVY
			1, //CSW_M249
			1, //CSW_M3
			1, //CSW_M4A1
			1, //CSW_TMP
			1, //CSW_G3SG1
			4, //CSW_FLASHBANG
			2, //CSW_DEAGLE
			1, //CSW_SG552
			1, //CSW_AK47
			3, //CSW_KNIFE
			1 //CSW_P90
		};
		iSlot = iWeaponsSlots[iCswId];
	}

	const XTRA_OFS_PLAYER = 5;
	const m_rgpPlayerItems_Slot0 = 367;

	iWeapon = get_pdata_cbase(id, m_rgpPlayerItems_Slot0 + iSlot, XTRA_OFS_PLAYER);

	const XTRA_OFS_WEAPON = 4;
	const m_pNext = 42;
	const m_iId = 43;

	while( iWeapon > 0 )
	{
		if( get_pdata_int(iWeapon, m_iId, XTRA_OFS_WEAPON) == iCswId )
		{
			break;
		}
		iWeapon = get_pdata_cbase(iWeapon, m_pNext, XTRA_OFS_WEAPON);
	}

	if( iWeapon > 0 )
	{
		const m_pActiveItem = 373;
		if( bSwitchIfActive && get_pdata_cbase(id, m_pActiveItem, XTRA_OFS_PLAYER) == iWeapon )
		{
			ExecuteHamB(Ham_Weapon_RetireWeapon, iWeapon);
		}

		if( ExecuteHamB(Ham_RemovePlayerItem, id, iWeapon) )
		{
			user_has_weapon(id, iCswId, 0);
			ExecuteHamB(Ham_Item_Kill, iWeapon);
			return 1;
		}
	}

	return 0;
} 
