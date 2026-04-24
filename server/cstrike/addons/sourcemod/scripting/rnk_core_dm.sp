#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

public Plugin myinfo =
{
    name = "RNK Core DM",
    author = "RNK",
    description = "Base propria do servidor RNK Deathmatch em de_dust2",
    version = "0.1.0",
    url = ""
};

ConVar gCvarRespawnDelay;
ConVar gCvarSpawnProtection;
ConVar gCvarCleanupInterval;
ConVar gCvarHSKill;

Handle gRespawnTimer[MAXPLAYERS + 1];
Handle gProtectionTimer[MAXPLAYERS + 1];
bool gSpawnProtected[MAXPLAYERS + 1];

int gSessionKills[MAXPLAYERS + 1];
int gSessionDeaths[MAXPLAYERS + 1];

public void OnPluginStart()
{
    gCvarRespawnDelay    = CreateConVar("sm_rnk_respawn_delay",    "1.5",  "Tempo para respawn automatico apos a morte.", FCVAR_NOTIFY, true, 0.1);
    gCvarSpawnProtection = CreateConVar("sm_rnk_spawn_protection", "2.0",  "Tempo de protecao ao nascer.", FCVAR_NOTIFY, true, 0.0);
    gCvarCleanupInterval = CreateConVar("sm_rnk_cleanup_interval", "15.0", "Intervalo para limpar armas dropadas.", FCVAR_NOTIFY, true, 5.0);
    gCvarHSKill          = CreateConVar("sm_rnk_hs_kill",          "1",    "Headshot mata com qualquer arma.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    AutoExecConfig(true, "rnk_core_dm");

    HookEvent("player_death",       Event_PlayerDeath,      EventHookMode_Post);
    HookEvent("player_spawn",       Event_PlayerSpawn,      EventHookMode_Post);
    HookEvent("round_end",          Event_RoundEnd,         EventHookMode_Post);
    CreateTimer(gCvarCleanupInterval.FloatValue, Timer_CleanupWeapons, _, TIMER_REPEAT);

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client))
        {
            SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
        }
    }
}

public void OnMapStart()
{
    char mapName[PLATFORM_MAX_PATH];
    GetCurrentMap(mapName, sizeof(mapName));

    if (!StrEqual(mapName, "de_dust2", false))
    {
        LogMessage("Mapa atual '%s' fora do padrao RNK. Recomendado: de_dust2.", mapName);
    }
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    ApplyNoBlock(client);
    gSessionKills[client]  = 0;
    gSessionDeaths[client] = 0;

    if (!IsFakeClient(client))
        CreateTimer(3.0, Timer_Welcome, GetClientUserId(client));
}

public void OnClientDisconnect(int client)
{
    delete gRespawnTimer[client];
    delete gProtectionTimer[client];
    gSpawnProtected[client] = false;
    gSessionKills[client]   = 0;
    gSessionDeaths[client]  = 0;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim   = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (IsValidPlayableClient(victim))
    {
        gSessionDeaths[victim]++;
        delete gRespawnTimer[victim];
        gRespawnTimer[victim] = CreateTimer(gCvarRespawnDelay.FloatValue, Timer_RespawnPlayer, GetClientUserId(victim));
    }

    if (IsValidPlayableClient(attacker) && attacker != victim)
        gSessionKills[attacker]++;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    // Coleta kills da sessao entre jogadores humanos
    int topClients[5];
    int topKills[5];

    for (int i = 0; i < 5; i++)
    {
        topClients[i] = -1;
        topKills[i]   = -1;
    }

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client))
            continue;

        int kills = gSessionKills[client];

        for (int i = 0; i < 5; i++)
        {
            if (kills > topKills[i])
            {
                for (int shift = 4; shift > i; shift--)
                {
                    topClients[shift] = topClients[shift - 1];
                    topKills[shift]   = topKills[shift - 1];
                }
                topClients[i] = client;
                topKills[i]   = kills;
                break;
            }
        }
    }

    bool hasAnyone = false;
    for (int i = 0; i < 5; i++)
    {
        if (topClients[i] != -1) { hasAnyone = true; break; }
    }

    if (!hasAnyone)
        return;

    PrintToChatAll("\x04[RNK]\x01 ══ \x05TOP KILLS DA RODADA\x01 ══");
    for (int i = 0; i < 5; i++)
    {
        if (topClients[i] == -1 || topKills[i] <= 0)
            continue;

        int c = topClients[i];
        char pname[64];
        GetClientName(c, pname, sizeof(pname));
        int deaths = gSessionDeaths[c];
        PrintToChatAll("\x04[RNK]\x01 \x05#%d\x01 \x03%s\x01 — \x05%d kills\x01 / %d mortes", i + 1, pname, topKills[i], deaths);
    }

    // Reseta contadores para proxima rodada
    for (int client = 1; client <= MaxClients; client++)
    {
        gSessionKills[client]  = 0;
        gSessionDeaths[client] = 0;
    }
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidPlayableClient(client) || !IsPlayerAlive(client))
    {
        return;
    }

    ApplyNoBlock(client);
    gSpawnProtected[client] = true;
    SetEntityRenderColor(client, 0, 180, 255, 180);

    delete gProtectionTimer[client];
    gProtectionTimer[client] = CreateTimer(gCvarSpawnProtection.FloatValue, Timer_DisableProtection, GetClientUserId(client));
}

public Action Timer_RespawnPlayer(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidPlayableClient(client) || IsPlayerAlive(client))
    {
        return Plugin_Stop;
    }

    CS_RespawnPlayer(client);
    gRespawnTimer[client] = null;
    return Plugin_Stop;
}

public Action Timer_DisableProtection(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidPlayableClient(client))
    {
        return Plugin_Stop;
    }

    gSpawnProtected[client] = false;
    SetEntityRenderColor(client, 255, 255, 255, 255);
    gProtectionTimer[client] = null;
    return Plugin_Stop;
}

public Action Timer_CleanupWeapons(Handle timer, any data)
{
    int entityCount = GetEntityCount();
    char className[64];

    for (int entity = MaxClients + 1; entity < entityCount; entity++)
    {
        if (!IsValidEdict(entity) || !IsValidEntity(entity))
        {
            continue;
        }

        GetEdictClassname(entity, className, sizeof(className));
        if (StrContains(className, "weapon_", false) != 0)
        {
            continue;
        }

        if (GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") == -1)
        {
            RemoveEdict(entity);
        }
    }

    return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
    if (!IsValidPlayableClient(victim))
        return Plugin_Continue;

    if (gSpawnProtected[victim])
    {
        damage = 0.0;
        return Plugin_Changed;
    }

    // Headshot instakill com qualquer arma
    if (gCvarHSKill.BoolValue && (damagetype & CS_DMG_HEADSHOT))
    {
        damage = float(GetClientHealth(victim) + 1);
        return Plugin_Changed;
    }

    return Plugin_Continue;
}

public Action Timer_Welcome(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client < 1 || !IsClientInGame(client))
        return Plugin_Stop;

    PrintToChat(client, "\x04[RNK]\x01 Bem-vindo ao \x05RNK | Servidor Deathmatch\x01!");
    PrintToChat(client, "\x04[RNK]\x01 \x03!guns\x01 - Trocar armas  \x03!rank\x01 - Seu ranking");
    PrintToChat(client, "\x04[RNK]\x01 \x03!topscore\x01 - Top geral  \x03!skins\x01 - Skins");
    return Plugin_Stop;
}

bool IsValidPlayableClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}

void ApplyNoBlock(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
    {
        return;
    }

    SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
}
