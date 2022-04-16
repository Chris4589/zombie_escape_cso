#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <zombieplague>

#define PLUGIN_VERSION "1.0c"

new health_add
new health_max

new nKiller
new nKiller_hp
new nHp_add
new nHp_max
new g_vampire;

new const hclass1_name[] = { "Choijiyoon Vampire" }
new const hclass1_info[] = { "Recupera HP al matar" }
new const hclass1_model[] = { "cso_sat" }
const hclass1_health = 200
const hclass1_speed = 320
const Float:hclass1_gravity = 0.8
const Float:hclass1_knockback = 1.0

public plugin_init()
{
   register_plugin("Vampire Human", PLUGIN_VERSION, "ConnorMcLeod")

   health_add = register_cvar("amx_vampire_hp", "10")
   health_max = register_cvar("amx_vampire_max_hp", "650")

   register_event("DeathMsg", "hook_death", "a", "1>0")  
}
public plugin_precache()
{
   g_vampire = zp_register_class(CLASS_HUMAN, hclass1_name, hclass1_info, hclass1_model, "default", 8, 0, ADMIN_ALL, hclass1_health, 80, hclass1_speed, hclass1_gravity, hclass1_knockback)
}

public hook_death()
{
   // Killer id
   nKiller = read_data(1);

   if(zp_get_user_human_class(nKiller) != g_vampire || zp_get_class(nKiller) > SURVIVOR || !is_user_alive(nKiller))
      return;

   nHp_add = get_pcvar_num (health_add);

   nHp_max = get_pcvar_num (health_max);

   // Updating Killer HP
   nKiller_hp = get_user_health(nKiller);
   nKiller_hp += nHp_add;

   // Maximum HP check
   if (nKiller_hp > nHp_max) nKiller_hp = nHp_max;

   set_user_health(nKiller, nKiller_hp);

   // Hud message "Healed +15/+40 hp"
   set_hudmessage(255, 255, 2, 0.40, 0.06, 0, -1.0, 5.0, 2.0);
   show_hudmessage(nKiller, "--[ VIDA +%d ]--", nHp_add);

   // Screen fading
   message_begin(MSG_ONE, get_user_msgid("ScreenFade"), {0,0,0}, nKiller);
   write_short(1<<10);
   write_short(1<<10);
   write_short(0x0000);
   write_byte(255);
   write_byte(0);
   write_byte(0);
   write_byte(75);
   message_end();
   
} 