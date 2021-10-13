#include <amxmodx>
#include <fakemeta>

new g_pKeyValue;

public plugin_precache( )
{
    g_pKeyValue = register_forward( FM_KeyValue, "OnKeyValue_Pre", false );
}

public plugin_init( )
{
    register_plugin( "Trigger Hurt Damage Fix", "1.0", "Manu" );
    
    unregister_forward( FM_KeyValue, g_pKeyValue, false );
}

public OnKeyValue_Pre( iEnt, pHandle )
{
    if ( !pev_valid( iEnt ) )
    {
        return FMRES_IGNORED;
    }
    
    new szValue[ 32 ];
    
    get_kvd( pHandle, KV_ClassName, szValue, charsmax( szValue ) );
    
    if ( !equal( szValue, "trigger_hurt" ) )
    {
        return FMRES_IGNORED;
    }
    
    get_kvd( pHandle, KV_KeyName, szValue, charsmax( szValue ) );
    
    if ( !equal( szValue, "dmg" ) )
    {
        return FMRES_IGNORED;
    }
    
    get_kvd( pHandle, KV_Value, szValue, charsmax( szValue ) );
    
    if ( str_to_num( szValue ) < 1000 )
    {
        return FMRES_IGNORED;
    }
    
    set_kvd( pHandle, KV_Value, "999999" );
    
    return FMRES_IGNORED;
}