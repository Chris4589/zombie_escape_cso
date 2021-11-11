#include <amxmodx>
#include <reapi>

native remove_entity(iIndex);

new const g_szEntHat[ ] = "hat_ent";
new const g_szModelHat[ ] = "models/zombie_plague/neon_hat_gign.mdl"

new g_iHat[ 33 ], modelIndex_hat;

public plugin_precache( ) modelIndex_hat = precache_model( g_szModelHat );

public plugin_init( ) register_plugin( "Auto SetHat ( reAPI )", "0.1b", "Hypnotize" );

public client_putinserver( id )
{
    g_iHat[ id ] = -1;
    set_task( 4.0, "setHat", id+556356 );
} 

public setHat( id )
{
    id -= 556356;
    if ( !is_user_connected( id ) || is_user_bot( id ) )
        return;

    g_iHat[ id ] = rg_create_entity( "info_target" );

    if( !g_iHat[ id ] )
        return;

    set_entvar( g_iHat[ id ], var_movetype, MOVETYPE_FOLLOW );
    set_entvar( g_iHat[ id ], var_owner, id );
    set_entvar( g_iHat[ id ], var_classname, g_szEntHat );
    set_entvar( g_iHat[ id ], var_model, g_szModelHat );
    set_entvar( g_iHat[ id ], var_modelindex, modelIndex_hat );
    set_entvar( g_iHat[ id ], var_aiment, id );
    //set_entvar( g_iHat[ id ], var_body, 0 );//dando sub hats
}

public client_disconnected( id )
{
    if ( is_entity( g_iHat[ id ] ) && g_iHat[ id ] )
    {
        remove_entity( g_iHat[ id ] );
        g_iHat[ id ] = -1;
    }
    remove_task( id+556356 );
} 