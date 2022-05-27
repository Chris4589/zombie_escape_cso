#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <zombie_escape_v1>
#include <amxmisc>
#include <print_center_fx>

#define PREFIX "[ZE]"

// Variables
new bool:g_bButtonUsed = false


// Default Values
new const szButtonEnt[][] = 
{
	"grescate_amazonas",
	"tren_escape",
	"escape_assault",
	"tetikleme",
	"gemoroy",
	"a1",
	"llamado_escape",
	"carrex",
	"manager",
	"rescate_jp",
	"mario_escape_final_001",
	"ascensor_escape",
	"multi",
	"escape_final",
	"heli",
	"msilo",
	"trem_ati",
	"heli_escape",
	"heli1",
	"final",
	"tren",
	"mm2",
	"final_camp",
	"mm_rescate",
	"rescate_amazonas",
	"multi_effects",
	"zzz",
	"koniec",
	"mut",
	"Vertolet",
	"Franqeeto",
	"manager_escape"
}

new sonido[] = "button_no.wav"

new Array:g_szButtonName


new bool:g_Revive,cvar_time, count_down

new fw_archivement_buton

public plugin_init ()
{
	register_plugin("button code robado 8v", "1.0", "Randro")
	RegisterHam(Ham_Use, "func_button", "Fw_ButtonUsed_Pre", 0)
	RegisterHam(Ham_Use, "func_button", "Fw_ButtonUsed_Post", 1)

	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")

	cvar_time = register_cvar("time_button", "45");

	fw_archivement_buton = CreateMultiForward("archivement_butom", ET_STOP, FP_CELL)
}

public plugin_precache()
{
	g_szButtonName = ArrayCreate(51, 1)

	new iIndex

	if (ArraySize(g_szButtonName) == 0)
	{
		for (iIndex = 0; iIndex < sizeof szButtonEnt; iIndex++)
			ArrayPushString(g_szButtonName, szButtonEnt[iIndex])
	}

	precache_sound(sonido)
}


public plugin_natives()
	register_native("active_button", "handler_active", 1);

public handler_active()
	return g_Revive;

public event_round_start() 
{
	count_down = get_pcvar_num(cvar_time);
	regresiva()
	g_bButtonUsed = false
}


public Fw_ButtonUsed_Pre(iEnt, id)
{
	new szTargetName[51], szCallerName[32]
	
	pev(iEnt, pev_target, szTargetName, charsmax(szTargetName))
	
	for (new iIndex = 0; iIndex < ArraySize(g_szButtonName); iIndex++)
	{
		new szButtonName[51]
		ArrayGetString(g_szButtonName, iIndex, szButtonName, charsmax(szButtonName))
		
		if (equal(szTargetName, szButtonName) && !g_bButtonUsed)
		{
			if(count_down >= 1)
			{
				client_print(id, print_center, "Debes esperar %d para activar el boton!!", count_down)
				client_cmd(id, "spk sound/button_no.wav")
				return HAM_SUPERCEDE;
				
			}
			else 
			{			
				get_user_name(id, szCallerName, charsmax(szCallerName))
				chatcolor(0, "^4%s ^3%s ^1ha activado el boton del escape corran todos!!!", PREFIX, szCallerName)
				g_bButtonUsed = true
				g_Revive = true;
				new ret
				ExecuteForward(fw_archivement_buton, ret, id)
			}
		}
	}
	return HAM_IGNORED;
}

public Fw_ButtonUsed_Post(iEnt, iCallerID)
{
	new szTargetName[51]; pev(iEnt, pev_target, szTargetName, charsmax(szTargetName))
	console_print(iCallerID,"Button Name: %s", szTargetName)
}

public regresiva()
{
	
	if( count_down <= 0 )
		return;

	set_task( 1.0, "regresiva2", 1231 )

}

public regresiva2()
{
	count_down--

	regresiva()
}

stock chatcolor(id, const input[], any:...)
{
    static szMsg[191], msgSayText;
    
    if (!msgSayText)
        msgSayText = get_user_msgid("SayText");

    replace_all(szMsg, 190, "!g", "^4");
    replace_all(szMsg, 190, "!y", "^1");
    replace_all(szMsg, 190, "!team", "^3");
    
    vformat(szMsg, 190, input, 3);
    
    message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, msgSayText, .player = id);
    write_byte(id ? id : 33);
    write_string(szMsg);
    message_end();
}