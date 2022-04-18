#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <zombie_escape_v1>

new const hclass_name[] = "Cheewy" // name
new const hclass_info[] = "Doble Salto" // description
new const hclass_model[] = "ze_hjump" // model

const hclass_health = 300 // health
const hclass_speed = 310 // speed

const Float:hclass_gravity = 0.7 // gravity
const Float:hclass_knockback = 2.0 // knockback

new g_doble_jump;

public plugin_precache()
{
    register_plugin("[ ZP ] Human Jumper x2","1.0", "Hypnotize");
    g_doble_jump = zp_register_class(CLASS_HUMAN, hclass_name, hclass_info, hclass_model, "default", 20, 0, ADMIN_ALL, hclass_health, 60, hclass_speed, hclass_gravity, hclass_knockback);
}
/*
public zp_user_infected_post(id, infector, nemesis)
    zp_doble_salto(id, 0);

*/
public zp_user_humanized_post(id, survivor)
{
    //zp_doble_salto(id, 0);

    if( zp_get_user_human_class(id) == g_doble_jump && zp_get_class(id) < SURVIVOR)
    {
        zp_doble_salto(id, 1);//2 doble jump
        client_print(id, print_chat, "tenes doble salto");
    }
}