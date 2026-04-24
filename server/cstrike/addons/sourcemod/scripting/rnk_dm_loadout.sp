#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>

#define PRIMARY_COUNT 10
#define SECONDARY_COUNT 6

public Plugin myinfo =
{
    name = "RNK DM Loadout",
    author = "RNK",
    description = "Loadout e regras reais de Deathmatch para o RNK",
    version = "0.1.0",
    url = ""
};

ConVar gCvarSpawnHealth;
ConVar gCvarKillHealth;

Cookie gCookiePrimary;
Cookie gCookieSecondary;
Cookie gCookieLoadoutMode;

char gPrimaryWeapons[PRIMARY_COUNT][32] =
{
    "weapon_ak47",
    "weapon_m4a1",
    "weapon_awp",
    "weapon_scout",
    "weapon_famas",
    "weapon_galil",
    "weapon_aug",
    "weapon_sg552",
    "weapon_mp5navy",
    "weapon_p90"
};

char gPrimaryLabels[PRIMARY_COUNT][32] =
{
    "AK-47",
    "M4A1",
    "AWP",
    "Scout",
    "Famas",
    "Galil",
    "AUG",
    "SG552",
    "MP5",
    "P90"
};

char gSecondaryWeapons[SECONDARY_COUNT][32] =
{
    "weapon_deagle",
    "weapon_usp",
    "weapon_glock",
    "weapon_p228",
    "weapon_elite",
    "weapon_fiveseven"
};

char gSecondaryLabels[SECONDARY_COUNT][32] =
{
    "Desert Eagle",
    "USP",
    "Glock",
    "P228",
    "Dual Elites",
    "Five-Seven"
};

char gSelectedPrimary[MAXPLAYERS + 1][32];
char gSelectedSecondary[MAXPLAYERS + 1][32];
bool gHasChosenLoadout[MAXPLAYERS + 1];
bool gAlwaysUseSameLoadout[MAXPLAYERS + 1];

public void OnPluginStart()
{
    gCvarSpawnHealth = CreateConVar("sm_rnk_dm_spawn_health", "100", "Vida ao nascer no DM.", FCVAR_NOTIFY, true, 1.0, true, 200.0);
    gCvarKillHealth = CreateConVar("sm_rnk_dm_kill_health", "15", "Vida ganha por kill no DM.", FCVAR_NOTIFY, true, 0.0, true, 100.0);

    AutoExecConfig(true, "rnk_dm_loadout");

    gCookiePrimary = RegClientCookie("rnk_dm_primary", "Arma primaria RNK", CookieAccess_Public);
    gCookieSecondary = RegClientCookie("rnk_dm_secondary", "Arma secundaria RNK", CookieAccess_Public);
    gCookieLoadoutMode = RegClientCookie("rnk_dm_mode", "Modo de reaplicacao do loadout RNK", CookieAccess_Public);

    RegConsoleCmd("sm_guns", Command_GunsMenu);
    RegConsoleCmd("sm_gun", Command_GunsMenu);
    RegConsoleCmd("sm_weapons", Command_GunsMenu);

    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);

    CreateTimer(5.0, Timer_RemoveObjectives, _, TIMER_REPEAT);
    CreateTimer(0.2, Timer_InfiniteAmmo, _, TIMER_REPEAT);
}

public void OnMapStart()
{
    RemoveObjectives();
}

public void OnClientPutInServer(int client)
{
    gSelectedPrimary[client][0] = '\0';
    gSelectedSecondary[client][0] = '\0';
    gHasChosenLoadout[client] = false;
    gAlwaysUseSameLoadout[client] = false;
}

public void OnClientDisconnect(int client)
{
    gSelectedPrimary[client][0] = '\0';
    gSelectedSecondary[client][0] = '\0';
    gHasChosenLoadout[client] = false;
    gAlwaysUseSameLoadout[client] = false;
}

public void OnClientCookiesCached(int client)
{
    if (!IsValidHumanClient(client))
    {
        return;
    }

    GetClientCookie(client, gCookiePrimary, gSelectedPrimary[client], sizeof(gSelectedPrimary[]));
    GetClientCookie(client, gCookieSecondary, gSelectedSecondary[client], sizeof(gSelectedSecondary[]));
    
    char modeValue[8];
    GetClientCookie(client, gCookieLoadoutMode, modeValue, sizeof(modeValue));
    gAlwaysUseSameLoadout[client] = StringToInt(modeValue) != 0;

    EnsureDefaultLoadout(client);
}

public Action Command_GunsMenu(int client, int args)
{
    if (!IsValidHumanClient(client))
    {
        ReplyToCommand(client, "[RNK] Comando disponivel apenas para jogadores.");
        return Plugin_Handled;
    }

    OpenPrimaryMenu(client);
    return Plugin_Handled;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidHumanClient(client) || !IsPlayerAlive(client))
    {
        return;
    }

    EnsureDefaultLoadout(client);
    CreateTimer(0.15, Timer_ApplyLoadout, GetClientUserId(client));
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = client;

    if (IsValidHumanClient(client) && !gAlwaysUseSameLoadout[client])
    {
        CreateTimer(0.2, Timer_OpenDeathLoadoutMenu, GetClientUserId(client));
    }

    if (!IsValidHumanClient(attacker) || attacker == victim)
    {
        return;
    }

    int health = GetClientHealth(attacker) + gCvarKillHealth.IntValue;
    if (health > 100)
    {
        health = 100;
    }

    SetEntityHealth(attacker, health);
}

public Action Timer_ApplyLoadout(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidHumanClient(client) || !IsPlayerAlive(client))
    {
        return Plugin_Stop;
    }

    EquipPlayerLoadout(client);

    if (!gHasChosenLoadout[client])
    {
        gHasChosenLoadout[client] = true;
        PrintToChat(client, "\x04[RNK]\x01 Use \x03!guns\x01 para trocar suas armas.");
        OpenPrimaryMenu(client);
    }

    return Plugin_Stop;
}

public Action Timer_RemoveObjectives(Handle timer, any data)
{
    RemoveObjectives();
    return Plugin_Continue;
}

public Action Timer_OpenDeathLoadoutMenu(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidHumanClient(client))
    {
        return Plugin_Stop;
    }

    OpenDeathLoadoutMenu(client);
    return Plugin_Stop;
}

public Action Timer_InfiniteAmmo(Handle timer, any data)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsValidHumanClient(client) || !IsPlayerAlive(client))
        {
            continue;
        }

        RefillWeaponAmmo(client, 0);
        RefillWeaponAmmo(client, 1);
    }

    return Plugin_Continue;
}

void OpenPrimaryMenu(int client)
{
    Menu menu = new Menu(MenuHandler_PrimaryMenu);
    menu.SetTitle("RNK Deathmatch: Primaria");

    for (int i = 0; i < PRIMARY_COUNT; i++)
    {
        menu.AddItem(gPrimaryWeapons[i], gPrimaryLabels[i]);
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

void OpenDeathLoadoutMenu(int client)
{
    Menu menu = new Menu(MenuHandler_DeathLoadoutMenu);
    menu.SetTitle("RNK Deathmatch: Loadout ao morrer");
    menu.AddItem("reuse_once", "Usar o loadout anterior");
    menu.AddItem("choose_new", "Escolher um novo loadout");
    menu.AddItem("always_same", "Usar sempre o mesmo");
    menu.Display(client, 10);
}

int MenuHandler_DeathLoadoutMenu(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
        return 0;
    }

    if (action != MenuAction_Select)
    {
        return 0;
    }

    char choice[32];
    menu.GetItem(item, choice, sizeof(choice));

    if (StrEqual(choice, "reuse_once", false))
    {
        gAlwaysUseSameLoadout[client] = false;
        SetClientCookie(client, gCookieLoadoutMode, "0");
        PrintToChat(client, "\x04[RNK]\x01 No proximo respawn voce usara o loadout atual.");
        return 0;
    }

    if (StrEqual(choice, "choose_new", false))
    {
        gAlwaysUseSameLoadout[client] = false;
        SetClientCookie(client, gCookieLoadoutMode, "0");
        OpenPrimaryMenu(client);
        return 0;
    }

    if (StrEqual(choice, "always_same", false))
    {
        gAlwaysUseSameLoadout[client] = true;
        SetClientCookie(client, gCookieLoadoutMode, "1");
        PrintToChat(client, "\x04[RNK]\x01 Seu loadout atual agora sera reaplicado automaticamente.");
    }

    return 0;
}

int MenuHandler_PrimaryMenu(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
        return 0;
    }

    if (action != MenuAction_Select)
    {
        return 0;
    }

    menu.GetItem(item, gSelectedPrimary[client], sizeof(gSelectedPrimary[]));
    SetClientCookie(client, gCookiePrimary, gSelectedPrimary[client]);
    OpenSecondaryMenu(client);
    return 0;
}

void OpenSecondaryMenu(int client)
{
    Menu menu = new Menu(MenuHandler_SecondaryMenu);
    menu.SetTitle("RNK Deathmatch: Secundaria");

    for (int i = 0; i < SECONDARY_COUNT; i++)
    {
        menu.AddItem(gSecondaryWeapons[i], gSecondaryLabels[i]);
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_SecondaryMenu(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
        return 0;
    }

    if (action != MenuAction_Select)
    {
        return 0;
    }

    menu.GetItem(item, gSelectedSecondary[client], sizeof(gSelectedSecondary[]));
    SetClientCookie(client, gCookieSecondary, gSelectedSecondary[client]);
    gHasChosenLoadout[client] = true;

    if (IsPlayerAlive(client))
    {
        EquipPlayerLoadout(client);
    }

    if (gAlwaysUseSameLoadout[client])
    {
        PrintToChat(client, "\x04[RNK]\x01 Loadout atualizado com sucesso e mantido como padrao.");
    }
    else
    {
        PrintToChat(client, "\x04[RNK]\x01 Loadout atualizado com sucesso.");
    }
    return 0;
}

void EquipPlayerLoadout(int client)
{
    if (!IsValidHumanClient(client) || !IsPlayerAlive(client))
    {
        return;
    }

    StripWeaponsForDM(client);

    SetEntProp(client, Prop_Send, "m_ArmorValue", 100);
    SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);
    SetEntityHealth(client, gCvarSpawnHealth.IntValue);

    GivePlayerItem(client, "weapon_knife");
    GivePlayerItem(client, gSelectedSecondary[client]);
    GivePlayerItem(client, gSelectedPrimary[client]);

    int primary = WeaponFromClassname(client, gSelectedPrimary[client]);
    if (primary > MaxClients)
    {
        EquipPlayerWeapon(client, primary);
    }
}

void StripWeaponsForDM(int client)
{
    int weapon;

    while ((weapon = GetPlayerWeaponSlot(client, 0)) != -1)
    {
        RemovePlayerItem(client, weapon);
        AcceptEntityInput(weapon, "Kill");
    }

    while ((weapon = GetPlayerWeaponSlot(client, 1)) != -1)
    {
        RemovePlayerItem(client, weapon);
        AcceptEntityInput(weapon, "Kill");
    }

    while ((weapon = GetPlayerWeaponSlot(client, 2)) != -1)
    {
        RemovePlayerItem(client, weapon);
        AcceptEntityInput(weapon, "Kill");
    }

    while ((weapon = GetPlayerWeaponSlot(client, 3)) != -1)
    {
        RemovePlayerItem(client, weapon);
        AcceptEntityInput(weapon, "Kill");
    }

    while ((weapon = GetPlayerWeaponSlot(client, 4)) != -1)
    {
        RemovePlayerItem(client, weapon);
        AcceptEntityInput(weapon, "Kill");
    }
}

int WeaponFromClassname(int client, const char[] classname)
{
    for (int slot = 0; slot <= 4; slot++)
    {
        int weapon = GetPlayerWeaponSlot(client, slot);
        if (weapon <= MaxClients || !IsValidEdict(weapon))
        {
            continue;
        }

        char currentClass[64];
        GetEdictClassname(weapon, currentClass, sizeof(currentClass));
        if (StrEqual(currentClass, classname, false))
        {
            return weapon;
        }
    }

    return -1;
}

void EnsureDefaultLoadout(int client)
{
    if (gSelectedPrimary[client][0] == '\0')
    {
        strcopy(gSelectedPrimary[client], sizeof(gSelectedPrimary[]), "weapon_ak47");
    }

    if (gSelectedSecondary[client][0] == '\0')
    {
        strcopy(gSelectedSecondary[client], sizeof(gSelectedSecondary[]), "weapon_deagle");
    }
}

void RefillWeaponAmmo(int client, int slot)
{
    int weapon = GetPlayerWeaponSlot(client, slot);
    if (weapon <= MaxClients || !IsValidEdict(weapon))
    {
        return;
    }

    char classname[64];
    GetEdictClassname(weapon, classname, sizeof(classname));

    int maxClip = GetMaxClipForWeapon(classname);
    if (maxClip <= 0)
    {
        return;
    }

    SetEntProp(weapon, Prop_Send, "m_iClip1", maxClip);
}

int GetMaxClipForWeapon(const char[] classname)
{
    if (StrEqual(classname, "weapon_ak47", false) || StrEqual(classname, "weapon_m4a1", false)
        || StrEqual(classname, "weapon_aug", false) || StrEqual(classname, "weapon_sg552", false)
        || StrEqual(classname, "weapon_galil", false) || StrEqual(classname, "weapon_famas", false)
        || StrEqual(classname, "weapon_scout", false))
    {
        return 30;
    }

    if (StrEqual(classname, "weapon_awp", false))
    {
        return 10;
    }

    if (StrEqual(classname, "weapon_p90", false))
    {
        return 50;
    }

    if (StrEqual(classname, "weapon_mp5navy", false))
    {
        return 30;
    }

    if (StrEqual(classname, "weapon_deagle", false))
    {
        return 7;
    }

    if (StrEqual(classname, "weapon_usp", false))
    {
        return 12;
    }

    if (StrEqual(classname, "weapon_glock", false))
    {
        return 20;
    }

    if (StrEqual(classname, "weapon_p228", false))
    {
        return 13;
    }

    if (StrEqual(classname, "weapon_elite", false))
    {
        return 30;
    }

    if (StrEqual(classname, "weapon_fiveseven", false))
    {
        return 20;
    }

    return 0;
}

void RemoveObjectives()
{
    RemoveEntitiesByClassname("func_bomb_target");
    RemoveEntitiesByClassname("info_bomb_target");
    RemoveEntitiesByClassname("weapon_c4");
    RemoveEntitiesByClassname("func_hostage_rescue");
    RemoveEntitiesByClassname("info_hostage_rescue");
    RemoveEntitiesByClassname("hostage_entity");
    RemoveEntitiesByClassname("func_buyzone");
}

void RemoveEntitiesByClassname(const char[] classname)
{
    int entity = -1;
    while ((entity = FindEntityByClassname(entity, classname)) != -1)
    {
        AcceptEntityInput(entity, "Kill");
    }
}

bool IsValidHumanClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}
