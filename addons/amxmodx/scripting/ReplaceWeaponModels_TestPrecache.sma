#include <amxmodx>
#include <reapi>
#include <engine>
#include <fakemeta>
#include <hamsandwich>

enum _:weaponStruct
{
	weaponDefaultModels = 0,
	weaponCustomModels
};

enum _:weaponModelStruct
{
	weaponViewModel[64],
	weaponPlayerModel[64],
	weaponWorldModel[32]
};

new const WEAPONS_MODELS[weaponStruct][31][weaponModelStruct] =
{
	// DEFAULT MODELS (don't modify)
	{
		{ "", "", "" },
		{ "models/v_p228.mdl", 			"models/p_p228.mdl", 			"models/w_p228.mdl"			}, 			// CSW_P228
		{ "", "", "" },
		{ "models/v_scout.mdl", 		"models/p_scout.mdl", 			"models/w_scout.mdl" 		}, 			// CSW_SCOUT
		{ "models/v_hegrenade.mdl", 	"models/p_hegrenade.mdl", 		"models/w_hegrenade.mdl" 	},			// CSW_HEGRENADE
		{ "models/v_xm1014.mdl", 		"models/p_xm1014.mdl", 			"models/w_xm1014.mdl" 		}, 			// CSW_XM1014
		{ "", "", "" },
		{ "models/v_mac10.mdl", 		"models/p_mac10.mdl", 			"models/w_mac10.mdl" 		}, 			// CSW_MAC10
		{ "models/v_aug.mdl", 			"models/p_aug.mdl", 			"models/w_aug.mdl" 			}, 			// CSW_AUG
		{ "models/v_smokegrenade.mdl", 	"models/p_smokegrenade.mdl", 	"models/w_smokegrenade.mdl" },			// CSW_SMOKEGRENADE
		{ "models/v_elite.mdl", 		"models/p_elite.mdl", 			"models/w_elite.mdl" 		}, 			// CSW_ELITE
		{ "models/v_fiveseven.mdl", 	"models/p_fiveseven.mdl", 		"models/w_fiveseven.mdl" 	}, 			// CSW_FIVESEVEN
		{ "models/v_ump45.mdl", 		"models/p_ump45.mdl", 			"models/w_ump45.mdl" 		}, 			// CSW_UMP45
		{ "models/v_sg550.mdl", 		"models/p_sg550.mdl", 			"models/w_sg550.mdl"		},			// CSW_SG550
		{ "models/v_galil.mdl", 		"models/p_galil.mdl", 			"models/w_galil.mdl" 		}, 			// CSW_GALIL
		{ "models/v_famas.mdl", 		"models/p_famas.mdl", 			"models/w_famas.mdl" 		}, 			// CSW_FAMAS
		{ "models/v_usp.mdl", 			"models/p_usp.mdl", 			"models/w_usp.mdl" 			}, 			// CSW_USP
		{ "models/v_glock18.mdl", 		"models/p_glock18.mdl", 		"models/w_glock18.mdl" 		}, 			// CSW_GLOCK18
		{ "models/v_awp.mdl", 			"models/p_awp.mdl", 			"models/w_awp.mdl" 			},			// CSW_AWP
		{ "models/v_mp5.mdl", 			"models/p_mp5.mdl", 			"models/w_mp5.mdl" 			}, 			// CSW_MP5NAVY
		{ "models/v_m249.mdl",			"models/p_m249.mdl", 			"models/w_m249.mdl" 		},			// CSW_M249
		{ "models/v_m3.mdl", 			"models/p_m3.mdl", 				"models/w_m3.mdl" 			}, 			// CSW_M3
		{ "models/v_m4a1.mdl", 			"models/p_m4a1.mdl", 			"models/w_m4a1.mdl"			}, 			// CSW_M4A1
		{ "models/v_tmp.mdl", 			"models/p_tmp.mdl", 			"models/w_tmp.mdl" 			}, 			// CSW_TMP
		{ "models/v_g3sg1.mdl", 		"models/p_g3sg1.mdl", 			"models/w_g3sg1.mdl" 		},			// CSW_G3SG1
		{ "models/v_flashbang.mdl", 	"models/p_flashbang.mdl", 		"models/w_flashbang.mdl" 	},			// CSW_FLASHBANG
		{ "models/v_deagle.mdl", 		"models/p_deagle.mdl", 			"models/w_deagle.mdl" 		}, 			// CSW_DEAGLE
		{ "models/v_sg552.mdl", 		"models/p_sg552.mdl", 			"models/w_sg552.mdl" 		}, 			// CSW_SG552
		{ "models/v_ak47.mdl", 			"models/p_ak47.mdl", 			"models/w_ak47.mdl" 		}, 			// CSW_AK47
		{ "models/v_knife.mdl", 		"models/p_knife.mdl", 			"models/w_knife.mdl" 		},			// CSW_KNIFE
		{ "models/v_p90.mdl", 			"models/p_p90.mdl", 			"models/w_p90.mdl" 			}  			// CSW_P90
	},

	// CUSTOM MODELS
	{
		{ "", "", "" },
		{ "models/custom/v_p228.mdl", 			"models/custom/p_p228.mdl", 			"" }, 					// CSW_P228
		{ "", "", "" },
		{ "models/custom/v_scout.mdl", 			"models/custom/p_scout.mdl", 			"" }, 					// CSW_SCOUT
		{ "models/custom/v_hegrenade.mdl", 		"models/custom/p_hegrenade.mdl", 		"" },					// CSW_HEGRENADE
		{ "models/custom/v_xm1014.mdl", 		"models/custom/p_xm1014.mdl", 			"" }, 					// CSW_XM1014
		{ "", "", "" },
		{ "models/custom/v_mac10.mdl", 			"models/custom/p_mac10.mdl", 			"" }, 					// CSW_MAC10
		{ "models/custom/v_aug.mdl", 			"models/custom/p_aug.mdl", 				"" }, 					// CSW_AUG
		{ "models/custom/v_smokegrenade.mdl", 	"models/custom/p_smokegrenade.mdl", 	"" },					// CSW_SMOKEGRENADE
		{ "models/custom/v_elite.mdl", 			"models/custom/p_elite.mdl", 			"" }, 					// CSW_ELITE
		{ "models/custom/v_fiveseven.mdl", 		"models/custom/p_fiveseven.mdl", 		"" }, 					// CSW_FIVESEVEN
		{ "models/custom/v_ump45.mdl", 			"models/custom/p_ump45.mdl", 			"" }, 					// CSW_UMP45
		{ "models/custom/v_sg550.mdl", 			"models/custom/p_sg550.mdl", 			"" },					// CSW_SG550
		{ "models/custom/v_galil.mdl", 			"models/custom/p_galil.mdl", 			"" }, 					// CSW_GALIL
		{ "models/custom/v_famas.mdl", 			"models/custom/p_famas.mdl", 			"" }, 					// CSW_FAMAS
		{ "models/custom/v_usp.mdl", 			"models/custom/p_usp.mdl", 				"" }, 					// CSW_USP
		{ "models/custom/v_glock18.mdl", 		"models/custom/p_glock18.mdl", 			"" }, 					// CSW_GLOCK18
		{ "models/custom/v_awp.mdl", 			"models/custom/p_awp.mdl", 				"" },					// CSW_AWP
		{ "models/custom/v_mp5.mdl", 			"models/custom/p_mp5.mdl", 				"" }, 					// CSW_MP5NAVY
		{ "models/custom/v_m249.mdl",			"models/custom/p_m249.mdl", 			"" },					// CSW_M249
		{ "models/custom/v_m3.mdl", 			"models/custom/p_m3.mdl", 				"" }, 					// CSW_M3
		{ "models/custom/v_m4a1.mdl", 			"models/custom/p_m4a1.mdl", 			"" }, 					// CSW_M4A1
		{ "models/custom/v_tmp.mdl", 			"models/custom/p_tmp.mdl", 				"" }, 					// CSW_TMP
		{ "models/custom/v_g3sg1.mdl", 			"models/custom/p_g3sg1.mdl", 			"" },					// CSW_G3SG1
		{ "models/custom/v_flashbang.mdl", 		"models/custom/p_flashbang.mdl", 		"" },					// CSW_FLASHBANG
		{ "models/custom/v_deagle.mdl", 		"models/custom/p_deagle.mdl", 			"" }, 					// CSW_DEAGLE
		{ "models/custom/v_sg552.mdl", 			"models/custom/p_sg552.mdl", 			"" }, 					// CSW_SG552
		{ "models/custom/v_ak47.mdl", 			"models/custom/p_ak47.mdl", 			"" }, 					// CSW_AK47
		{ "models/custom/v_knife.mdl", 			"models/custom/p_knife.mdl", 			"" },					// CSW_KNIFE
		{ "models/custom/v_p90.mdl", 			"models/custom/p_p90.mdl", 				"" }  					// CSW_P90
	}
};

new const MODEL_WB[]						= "models/wb.mdl";

new const CLASSNAME_ENT_FAKE_WEAPON_MODEL[] = "entFakeWeaponModel";

public plugin_precache()
{
	new i;
	for(i = 1; i < 31; ++i)
	{
		if(WEAPONS_MODELS[weaponCustomModels][i][weaponViewModel][0])
			precache_model(WEAPONS_MODELS[weaponCustomModels][i][weaponViewModel]);

		if(WEAPONS_MODELS[weaponCustomModels][i][weaponPlayerModel][0])
			precache_model(WEAPONS_MODELS[weaponCustomModels][i][weaponPlayerModel]);
	}

	precache_model(MODEL_WB);

	register_forward(FM_PrecacheModel, "OnFw__PrecacheModel", false);
	register_forward(FM_SetModel, "OnFw_SetModel", false);

	RegisterHookChain(RG_CWeaponBox_SetModel, "CWeaponBox_SetModel", false);
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "CBasePlayerWeapon_DefaultDeploy", false);
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "CBasePlayerWeapon_DefaultDeploy_Post", true);
}

public plugin_init()
{
	register_event_ex("HLTV", "event__HLTV", RegisterEvent_Global, "1=0", "2=0");

	new i;
	new sWeapon[32];
	for(i = 1; i < 31; ++i)
	{
		if(i == 2 || !WEAPONS_MODELS[weaponCustomModels][i][weaponPlayerModel][0] || !get_weaponname(i, sWeapon, charsmax(sWeapon)))
			continue;

		RegisterHam(Ham_Item_AddToPlayer, sWeapon, "OnHam__Item_AddToPlayer", false);
	}

	RegisterHam(Ham_Think, "grenade", "OnHam__ThinkGrenade", false);

	register_think(CLASSNAME_ENT_FAKE_WEAPON_MODEL, "think__FakeWeaponModel");
}

public OnFw__PrecacheModel(const model[])
{
	new i;
	for(i = 1; i < 31; ++i)
	{
		if(!WEAPONS_MODELS[weaponCustomModels][i][weaponViewModel][0]) // Si no tiene un modelo V_ personalizado, usar el modelo V_ por defecto
			continue;
			
		if(equal(model, WEAPONS_MODELS[weaponDefaultModels][i][weaponViewModel]))
			return FMRES_SUPERCEDE;
	}

	for(i = 1; i < 31; ++i)
	{
		if(!WEAPONS_MODELS[weaponCustomModels][i][weaponPlayerModel][0]) // Si no tiene un modelo P_ personalizado, usar el modelo P_ por defecto
			continue;
			
		if(equal(model, WEAPONS_MODELS[weaponDefaultModels][i][weaponPlayerModel]))
			return FMRES_SUPERCEDE;
	}

	for(i = 1; i < 31; ++i)
	{
		if(!WEAPONS_MODELS[weaponCustomModels][i][weaponPlayerModel][0]) // Si no tiene un modelo P_ personalizado, usar el modelo W_ por defecto
			continue;
			
		if(equal(model, WEAPONS_MODELS[weaponDefaultModels][i][weaponWorldModel]))
			return FMRES_SUPERCEDE;
	}

	return FMRES_IGNORED;
}

public event__HLTV()
{
	new iEnt = find_ent_by_class(-1, CLASSNAME_ENT_FAKE_WEAPON_MODEL);
	while(is_valid_ent(iEnt))
	{
		remove_entity(iEnt);

		iEnt = find_ent_by_class(-1, CLASSNAME_ENT_FAKE_WEAPON_MODEL);
	}
}

public OnHam__Item_AddToPlayer(const __weaponEnt, const id)
{
	new iFakeWeaponModel = entity_get_int(__weaponEnt, EV_INT_iuser1);

	if(!iFakeWeaponModel || !is_valid_ent(iFakeWeaponModel))
		return;

	remove_entity(iFakeWeaponModel);
	entity_set_int(__weaponEnt, EV_INT_iuser1, 0);  // Fix
}

public OnHam__ThinkGrenade(const grenade)
{
	if(!is_valid_ent(grenade))
		return HAM_IGNORED;

	if(entity_get_float(grenade, EV_FL_dmgtime) > get_gametime())
		return HAM_IGNORED;

	new iFakeGrenadeModel = entity_get_int(grenade, EV_INT_iuser1);

	if(!iFakeGrenadeModel || !is_valid_ent(iFakeGrenadeModel))
		return HAM_IGNORED;

	remove_entity(iFakeGrenadeModel);
	entity_set_int(grenade, EV_INT_iuser1, 0); // Fix
	return HAM_IGNORED;
}

public OnFw_SetModel(const entity, const sModel[])
{
	new iWeaponId;
	for(iWeaponId = 1; iWeaponId < 31; ++iWeaponId)
	{
		if(iWeaponId && WEAPONS_MODELS[weaponCustomModels][iWeaponId][weaponPlayerModel][0] && equal(sModel, WEAPONS_MODELS[weaponDefaultModels][iWeaponId][weaponWorldModel]))
		{
			if((1<<iWeaponId) & CSW_ALL_GRENADES)
			{
				new sWeapon[32];
				get_weaponname(iWeaponId, sWeapon, charsmax(sWeapon));

				entity_set_model(entity, MODEL_WB);
				createFakeWeaponWorldModel(entity, 0.0, WEAPONS_MODELS[weaponCustomModels][iWeaponId][weaponPlayerModel], sWeapon);
			}

			return FMRES_SUPERCEDE;
		}
	}

	return FMRES_IGNORED;
}

public CWeaponBox_SetModel(const entity, const sModel[])
{
	new WeaponIdType:iWeaponId = rg_get_weaponbox_id(entity);

	if(iWeaponId && WEAPONS_MODELS[weaponCustomModels][_:iWeaponId][weaponPlayerModel][0])
	{
		new Float:flNextThink = 0.0;

		if(iWeaponId != WEAPON_HEGRENADE && iWeaponId != WEAPON_SMOKEGRENADE && iWeaponId != WEAPON_FLASHBANG) // Por las dudas lo dejo, pero en realidad no se llaman a las granadas en esta funcion (no se porque)
		{
			flNextThink = get_gametime() + 99999.0; // Para remover la entidad si esta sola en el suelo X tiempo en caso de necesitar, sino borrar estas referencias
			entity_set_float(entity, EV_FL_nextthink, flNextThink);
		}

		new sWeapon[32];
		get_weaponname(_:iWeaponId, sWeapon, charsmax(sWeapon));

		SetHookChainArg(2, ATYPE_STRING, MODEL_WB);
		createFakeWeaponWorldModel(entity, flNextThink, WEAPONS_MODELS[weaponCustomModels][_:iWeaponId][weaponPlayerModel], sWeapon);
	}
	
	return HC_CONTINUE;
}

public CBasePlayerWeapon_DefaultDeploy(const entity, sViewModel[], sWeaponModel[], iAnim, sAnimExt[], skiplocal)
{
	new i;
	for(i = 0; i < 31; ++i)
	{
		if(WEAPONS_MODELS[weaponCustomModels][i][weaponViewModel] && equal(sViewModel, WEAPONS_MODELS[weaponDefaultModels][i][weaponViewModel]))
		{
			SetHookChainArg(2, ATYPE_STRING, WEAPONS_MODELS[weaponCustomModels][i][weaponViewModel]);

			if(WEAPONS_MODELS[weaponCustomModels][i][weaponPlayerModel])
				SetHookChainArg(3, ATYPE_STRING, WEAPONS_MODELS[weaponCustomModels][i][weaponPlayerModel]);

			break;
		}
	}

	return HC_CONTINUE;
}

public CBasePlayerWeapon_DefaultDeploy_Post(const entity, sViewModel[], sWeaponModel[], iAnim, sAnimExt[], skiplocal)
{
	new i;
	for(i = 0; i < 31; ++i)
	{
		if(WEAPONS_MODELS[weaponCustomModels][i][weaponViewModel] && equal(sViewModel, WEAPONS_MODELS[weaponCustomModels][i][weaponViewModel]))
		{
			new id = get_member(entity, m_pPlayer);

			set_entvar(id, var_viewmodel, WEAPONS_MODELS[weaponCustomModels][i][weaponViewModel]);

			if(WEAPONS_MODELS[weaponCustomModels][i][weaponPlayerModel])
				set_entvar(id, var_weaponmodel, WEAPONS_MODELS[weaponCustomModels][i][weaponPlayerModel]);

			break;
		}
	}

	return HC_CONTINUE;
}

public think__FakeWeaponModel(const fakemodel)
{
	if(!is_valid_ent(fakemodel))
		return;

	remove_entity(fakemodel);
}

stock createFakeWeaponWorldModel(const weaponent, const Float:nextthink, const model[], const weapon[])
{
	new iModel = create_entity("info_target");
		
	if(is_valid_ent(iModel))
	{
		new Float:vecAngles[3];
		entity_get_vector(weaponent, EV_VEC_angles, vecAngles);
		vecAngles[0] = -5.0;
		vecAngles[2] = 15.0;
		entity_set_vector(weaponent, EV_VEC_angles, vecAngles);

		entity_set_string(iModel, EV_SZ_classname, CLASSNAME_ENT_FAKE_WEAPON_MODEL);
		entity_set_model(iModel, model);
		
		entity_set_int(iModel, EV_INT_solid, SOLID_NOT);
		entity_set_int(iModel, EV_INT_movetype, MOVETYPE_FOLLOW);

		entity_set_edict(iModel, EV_ENT_aiment, weaponent);

		entity_set_int(find_ent_by_owner(-1, weapon, weaponent), EV_INT_iuser1, iModel);
		entity_set_int(weaponent, EV_INT_iuser1, iModel); // Fix para las granadas (ThinkGrenade)

		if(nextthink)
			entity_set_float(iModel, EV_FL_nextthink, nextthink);
	}
}