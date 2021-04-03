/* Sublime AMXX Editor v3.0.0-beta */

#include <amxmodx>
#include <amxmisc>
// #include <engine>
#include <hamsandwich>
#include <reapi>
#include <xs>
#include <engine>

new const szPluginInfo[][] = { "[Zombie Escape] Show Buttons", "v1.1", "totopizza" };

#define ACCESS_MENU ADMIN_CFG

#define BUTTONS_FOLDER "buttons"

#define TAG "^x04[ZE]^x03"

new g_szButtonsFile[128];
enum { A_BUTTON=1, THE_BUTTON, ESCAPE_BUTTON }

new const szButtonClasses[][] = {
	"ha activado un boton",
	"ha activado el boton",
	"ha activado el boton del escape corran todos!!!"
};

new g_iButtons, g_iButton_Selected[33];
public plugin_init()
{
	register_plugin(szPluginInfo[0], szPluginInfo[1], szPluginInfo[2])
	register_clcmd("say /buttons", "clcmd_ShowButtonMenu", ACCESS_MENU, "Registra los botones del mapa");

	new configsdir[128], mapname[64];

	get_configsdir(configsdir, charsmax(configsdir));
	formatex(configsdir, charsmax(configsdir), "%s/%s", configsdir, BUTTONS_FOLDER);

	if(!dir_exists(configsdir))
	{
		mkdir(configsdir);
	}

	get_mapname(mapname, charsmax(mapname));
	formatex(g_szButtonsFile, charsmax(g_szButtonsFile), "%s/%s.buttons", configsdir, mapname);

	LoadMapButtonsFile();

	RegisterHam(Ham_Use, "func_rot_button", "fw_HamUse_Pre", false);
	RegisterHam(Ham_Use, "func_button", "fw_HamUse_Pre", false);
}


public fw_HamUse_Pre(iButton, id, useType, Float:value)
{
	if(g_iButtons)
	{
		new iButtonType; iButtonType = get_entvar(iButton, var_iuser1);
		if(iButtonType != 0)
		{
			if(get_entvar(iButton, var_ltime) >= get_entvar(iButton, var_nextthink))
			{
				new playername[32];
				get_user_name(id, playername, 31);

				if(iButtonType == THE_BUTTON)
				{
					client_print_color(0, id, "%s %s^x04 %s #%d", TAG, playername, szButtonClasses[iButtonType-1], get_entvar(iButton, var_iuser2));
				}
				else {
					client_print_color(0, id, "%s %s^x04 %s", TAG, playername, szButtonClasses[iButtonType-1]);
				}
			}
		}
	}
}

public clcmd_ShowButtonMenu(id, level)
{
	if(!access(id, level))
	{
		client_print_color(id, id, "^x03[CONFIG]^x01 No tienes acceso para configurar los botones del mapa!");
		return PLUGIN_HANDLED;
	}

	new szText[64];

	formatex(szText, charsmax(szText), "\r[ShowButtons]\y Menú de configuración^n\dBotones registrados: %s%d", g_iButtons ? "\y":"\r", g_iButtons);
	new menu = menu_create(szText, "opc_showbuttons");
	menu_additem(menu, "Registrar el botón apuntado");
	menu_additem(menu, "Editar el botón apuntado");


	menu_additem(menu, "Guardar botones");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public opc_showbuttons(id, menu, item)
{
	menu_destroy(menu);

	if(item == MENU_EXIT)
		return PLUGIN_HANDLED;

	new iButton = -1, iButtonType,  iButtonNumber;
	switch(item)
	{
		case 0,1:
		{
			//new fake;
			//get_user_aiming(id, iButton, fake);

			new iClassButton = FindButtonByAim(id, iButton);

			if(iClassButton != -1)
			{
				iButtonType = get_entvar(iButton, var_iuser1);
				if(item == 0 && iButtonType != 0)
				{
					client_print_color(id, id, "^x03[CONFIG]^x01 El botón apuntado ya está registrado.");
					clcmd_ShowButtonMenu(id, ACCESS_MENU);
					return PLUGIN_HANDLED;
				}
				else if(item == 1 && iButtonType == 0)
				{
					client_print_color(id, id, "^x03[CONFIG]^x01 El botón apuntado no está registrado.");
					clcmd_ShowButtonMenu(id, ACCESS_MENU);
					return PLUGIN_HANDLED;
				}

				g_iButton_Selected[id] = iButton;

				new menu;

				new szText[74];
				if(item == 0)
				{
					formatex(szText, charsmax(szText), "\r[ShowButtons] \yRegistrar el botón como:^n\dEntidad: %s", iClassButton ? "func_rot_button":"func_button");
					menu = menu_create(szText, "opc_register_button");
				}
				else
				{
					formatex(szText, charsmax(szText), "\r[ShowButtons] \yEditar el botón como:^n\dEntidad: %s", iClassButton ? "func_rot_button":"func_button");
					menu = menu_create(szText, "opc_edit_button");
				}

				
				iButtonNumber = get_entvar(iButton, var_iuser2);
				for(new i=1; i <= sizeof szButtonClasses; i++)
				{
					if(i == THE_BUTTON)
					{
						formatex(szText, charsmax(szText), "%s #%d", szButtonClasses[i-1], item == 1 ? iButtonNumber : (g_iButtons+1));
					}
					else
					{
						formatex(szText, charsmax(szText), "%s", szButtonClasses[i-1]);
					}

					if(iButtonType == i)
						add(szText, charsmax(szText), " \y[X]");

					menu_additem(menu, szText, "");
				}
				menu_display(id, menu);
			}
			else {
				client_print_color(id, id, "^x03[CONFIG]^x01 Debes apuntar a un botón válido (^4func_button^x01 ó^x04 func_rot_button^x01).");
				clcmd_ShowButtonMenu(id, ACCESS_MENU);
				return PLUGIN_HANDLED;
			}
		}
		case 2: {

			new iFile = fopen(g_szButtonsFile, "wt");
			if(iFile)
			{
				new classname[16];
				new Float:fOrigin[3];
				while((iButton = find_ent_by_class(iButton, "func_button")))
				{
					get_entvar(iButton, var_classname, classname, 15);
					
					if((iButtonType = get_entvar(iButton, var_iuser1)) == 0)
					{
						continue;
					}

					get_brush_entity_origin(iButton, fOrigin)

					iButtonNumber = get_entvar(iButton, var_iuser2);

					//console_print(id, "%d %s %f %f %f", iButton, classname, fOrigin[0], fOrigin[1], fOrigin[2]);

					fprintf(iFile, "%f %f %f %d %d^n", fOrigin[0], fOrigin[1], fOrigin[2], iButtonType, iButtonNumber);
				}

				iButton = -1;
				while((iButton = find_ent_by_class(iButton, "func_rot_button")))
				{
					get_entvar(iButton, var_classname, classname, 15);
					if((iButtonType = entity_get_int(iButton, EV_INT_iuser1)) == 0)
					{
						continue;
					}

					get_brush_entity_origin(iButton, fOrigin)
					iButtonNumber = get_entvar(iButton, var_iuser2);

					//console_print(id, "%d %s %f %f %f", iButton, classname, fOrigin[0], fOrigin[1], fOrigin[2]);

					fprintf(iFile, "%f %f %f %d %d^n", fOrigin[0], fOrigin[1], fOrigin[2], iButtonType, iButtonNumber);
				}

				fclose(iFile);

				client_print_color(id, id, "^x03[CONFIG]^x01 Los botones han sido guardados (%d).", g_iButtons);
			}
			else {
				//write_file(g_szButtonsFile, "", 0);
				client_print_color(id, id, "^x03[CONFIG]^x01 Ocurrió un error al intentar guardar los botones!");
			}

			clcmd_ShowButtonMenu(id, ACCESS_MENU);
			return PLUGIN_HANDLED;
		}
	}

	return PLUGIN_HANDLED;
}

public opc_register_button(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		clcmd_ShowButtonMenu(id, ACCESS_MENU);
		return PLUGIN_HANDLED;
	}

	g_iButtons++;
	set_entvar(g_iButton_Selected[id], var_iuser1, ++item);
	set_entvar(g_iButton_Selected[id], var_iuser2, g_iButtons)
	if(item == THE_BUTTON)
	{
		client_print_color(id, id, "^x03[CONFIG]^x01 Botón registrado como:^x04 %s #%d.", szButtonClasses[item-1], g_iButtons);
	}
	else	
	{
		client_print_color(id, id, "^x03[CONFIG]^x01 Botón registrado como:^x04 %s.", szButtonClasses[item-1]);
	}

	menu_destroy(menu);

	clcmd_ShowButtonMenu(id, ACCESS_MENU);

	return PLUGIN_HANDLED;
}

public opc_edit_button(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		clcmd_ShowButtonMenu(id, ACCESS_MENU);
		return PLUGIN_HANDLED;
	}

	set_entvar(g_iButton_Selected[id], var_iuser1, ++item);

	if(item == THE_BUTTON )
	{
		client_print_color(id, id, "^x03[CONFIG]^x01 Botón editado como:^x04 %s #%d.", szButtonClasses[item-1], get_entvar(g_iButton_Selected[id], var_iuser2));
	}
	else
	{
		client_print_color(id, id, "^x03[CONFIG]^x01 Botón editado como:^x04 %s.", szButtonClasses[item-1]);
	}


	menu_destroy(menu);

	clcmd_ShowButtonMenu(id, ACCESS_MENU);

	return PLUGIN_HANDLED;
}


LoadMapButtonsFile()
{
	if(!file_exists(g_szButtonsFile))
		return PLUGIN_HANDLED;

	new szLine[64], iFile;

	iFile = fopen(g_szButtonsFile, "rt");

	new szOrigin[3][45], Float:fOrigin[3];
	new szButtonType[4], szButtonNumber[3], iButton = -1;

	new classname[16];
	while(iFile && !feof(iFile))
	{
		fgets(iFile, szLine, charsmax(szLine));

		if(!szLine[0] || szLine[0] == ';')
		{
			continue;
		}

		parse(szLine, 
			szOrigin[0], charsmax(szOrigin[]),
			szOrigin[1], charsmax(szOrigin[]),
			szOrigin[2], charsmax(szOrigin[]),
			szButtonType, charsmax(szButtonType),
			szButtonNumber, charsmax(szButtonNumber));

		fOrigin[0] = str_to_float(szOrigin[0]);
		fOrigin[1] = str_to_float(szOrigin[1]);
		fOrigin[2] = str_to_float(szOrigin[2]);

		//server_print("==================^nOrigin: %f %f %f", fOrigin[0], fOrigin[1],fOrigin[2])
		while((iButton = find_ent_in_sphere(iButton, fOrigin, 25.0)) != 0)
		{
			get_entvar(iButton, var_classname, classname, 15);

			//server_print("%03d --- %s", iButton, classname);
			if(equal(classname, "func_button") || equal(classname, "func_rot_button"))
			{
				g_iButtons++;
				set_entvar(iButton, var_iuser1, str_to_num(szButtonType));
				set_entvar(iButton, var_iuser2, str_to_num(szButtonNumber));
				break;
			}			
		}
	}

	if(iFile)
	{
		fclose(iFile)
	}
	//server_print("==================^n^nBOTONES CARGADOS:%d^n^n==================", g_iButtons);

	return PLUGIN_HANDLED;
}

FindButtonByAim( const iId, &iButton=-1 )
{
	new Float:flEnd[ 3 ];
	new Float:flOrigin[ 3 ];
	new Float:flAngles[ 3 ];
	new Float:flViewOfs[ 3 ];
	
	get_entvar(iId, var_origin, flOrigin);
	get_entvar(iId, var_view_ofs, flViewOfs);
	get_entvar(iId, var_v_angle, flAngles);
	
	angle_vector( flAngles, ANGLEVECTOR_FORWARD, flAngles );
	
	xs_vec_add( flOrigin, flViewOfs, flOrigin );
	xs_vec_mul_scalar( flAngles, 999.0, flAngles );
	xs_vec_add( flOrigin, flAngles, flEnd );
	
	new Float:flAimOrigin[3];
	iButton = trace_line( iId, flOrigin, flEnd, flAimOrigin );
	
	if ( is_valid_ent( iButton ) )
	{
		new szClass[ 16 ];
		
		get_entvar( iButton, var_classname, szClass, charsmax( szClass ) );
	
		if ( equali( szClass, "func_button", 11 )  || equali( szClass, "func_rot_button", 15 ))
		{
			return szClass[5] == 'r' ? 1 : 0;
		}
		else
		{
			new iEnt[1];
			if(find_sphere_class(0, "func_rot_button", 0.01, iEnt, 1, flAimOrigin))
			{
				iButton = iEnt[0];
				return 1;
			}
		}
	}
	else
	{
		new iEnt[1];
		if(find_sphere_class(0, "func_rot_button", 0.01, iEnt, 1, flAimOrigin))
		{
			iButton = iEnt[0];
			return 1;
		}
	}
	return -1;
}