#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <zombie_escape_v1>

new const hclass_name[] = "Petty Jumper" // name
new const hclass_info[] = "Triple Salto" // description
new const hclass_model[] = "ze_petty" // model

const hclass_health = 500 // health
const hclass_speed = 300 // speed

const Float:hclass_gravity = 0.8 // gravity
const Float:hclass_knockback = 2.0 // knockback

new g_hclass_jump;

public plugin_precache()
{
    register_plugin("[ ZP ] Human Jumper x3","1.0", "Hypnotize");
    g_hclass_jump = zp_register_class(CLASS_HUMAN, hclass_name, hclass_info, hclass_model, "default", 10, 1, ADMIN_LEVEL_A, hclass_health, 60, hclass_speed, hclass_gravity, hclass_knockback);
}
/*
public zp_user_infected_post(id, infector, nemesis)
    zp_triple_salto(id, 0);
*/
public zp_user_humanized_post(id, survivor)
{
    //zp_triple_salto(id, 0);

    if( zp_get_user_human_class(id) == g_hclass_jump && zp_get_class(id) < SURVIVOR )
        zp_triple_salto(id, 1);//2 triple jump
}