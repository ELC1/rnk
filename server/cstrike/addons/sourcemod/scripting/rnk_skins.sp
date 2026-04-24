#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#define MAX_RNK_CHARACTER_SKINS 32
#define MAX_RNK_WEAPON_SKINS 64

public Plugin myinfo =
{
    name = "RNK Skins",
    author = "RNK",
    description = "Sistema proprio de skins de personagem, armas e facas",
    version = "0.1.0",
    url = ""
};

Cookie gCookieCharacterSkin;
Cookie gCookieWeaponSkin;
Cookie gCookieKnifeSkin;

char gCharacterIds[MAX_RNK_CHARACTER_SKINS][32];
char gCharacterNames[MAX_RNK_CHARACTER_SKINS][64];
char gCharacterModels[MAX_RNK_CHARACTER_SKINS][PLATFORM_MAX_PATH];
int gCharacterTeams[MAX_RNK_CHARACTER_SKINS];
int gCharacterCount;

char gWeaponSkinIds[MAX_RNK_WEAPON_SKINS][32];
char gWeaponSkinNames[MAX_RNK_WEAPON_SKINS][64];
char gWeaponSkinViewModels[MAX_RNK_WEAPON_SKINS][PLATFORM_MAX_PATH];
char gWeaponSkinWorldModels[MAX_RNK_WEAPON_SKINS][PLATFORM_MAX_PATH];
char gWeaponSkinWeapons[MAX_RNK_WEAPON_SKINS][256];
bool gWeaponSkinKnifeOnly[MAX_RNK_WEAPON_SKINS];
int gWeaponSkinCount;

char gSelectedCharacterSkin[MAXPLAYERS + 1][32];
char gSelectedWeaponSkin[MAXPLAYERS + 1][32];
char gSelectedKnifeSkin[MAXPLAYERS + 1][32];
int gLastWeaponEntRef[MAXPLAYERS + 1];

public void OnPluginStart()
{
    gCookieCharacterSkin = RegClientCookie("rnk_character_skin", "Skin de personagem RNK", CookieAccess_Public);
    gCookieWeaponSkin = RegClientCookie("rnk_weapon_skin", "Skin de arma RNK", CookieAccess_Public);
    gCookieKnifeSkin = RegClientCookie("rnk_knife_skin", "Skin de faca RNK", CookieAccess_Public);

    RegConsoleCmd("sm_skins", Command_SkinsMenu);
    RegConsoleCmd("sm_agents", Command_CharacterMenu);
    RegConsoleCmd("sm_charskins", Command_CharacterMenu);
    RegConsoleCmd("sm_weaponskins", Command_WeaponMenu);
    RegConsoleCmd("sm_knifeskins", Command_KnifeMenu);

    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);

    LoadCharacterSkins();
    LoadWeaponSkins();

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client))
        {
            SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
        }
    }
}

public void OnMapStart()
{
    LoadCharacterSkins();
    LoadWeaponSkins();
    PrecacheConfiguredAssets();
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
    gLastWeaponEntRef[client] = INVALID_ENT_REFERENCE;
}

public void OnClientDisconnect(int client)
{
    gSelectedCharacterSkin[client][0] = '\0';
    gSelectedWeaponSkin[client][0] = '\0';
    gSelectedKnifeSkin[client][0] = '\0';
    gLastWeaponEntRef[client] = INVALID_ENT_REFERENCE;
}

public void OnClientCookiesCached(int client)
{
    if (!IsValidHumanClient(client))
    {
        return;
    }

    GetClientCookie(client, gCookieCharacterSkin, gSelectedCharacterSkin[client], sizeof(gSelectedCharacterSkin[]));
    GetClientCookie(client, gCookieWeaponSkin, gSelectedWeaponSkin[client], sizeof(gSelectedWeaponSkin[]));
    GetClientCookie(client, gCookieKnifeSkin, gSelectedKnifeSkin[client], sizeof(gSelectedKnifeSkin[]));
}

public Action Command_SkinsMenu(int client, int args)
{
    if (!IsValidHumanClient(client))
    {
        ReplyToCommand(client, "[RNK] Comando disponivel apenas para jogadores.");
        return Plugin_Handled;
    }

    OpenMainSkinMenu(client);
    return Plugin_Handled;
}

public Action Command_CharacterMenu(int client, int args)
{
    if (!IsValidHumanClient(client))
    {
        ReplyToCommand(client, "[RNK] Comando disponivel apenas para jogadores.");
        return Plugin_Handled;
    }

    OpenCharacterMenu(client);
    return Plugin_Handled;
}

public Action Command_WeaponMenu(int client, int args)
{
    if (!IsValidHumanClient(client))
    {
        ReplyToCommand(client, "[RNK] Comando disponivel apenas para jogadores.");
        return Plugin_Handled;
    }

    OpenWeaponMenu(client);
    return Plugin_Handled;
}

public Action Command_KnifeMenu(int client, int args)
{
    if (!IsValidHumanClient(client))
    {
        ReplyToCommand(client, "[RNK] Comando disponivel apenas para jogadores.");
        return Plugin_Handled;
    }

    OpenKnifeMenu(client);
    return Plugin_Handled;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidHumanClient(client) || !IsPlayerAlive(client))
    {
        return;
    }

    CreateTimer(0.1, Timer_ApplySpawnSkins, GetClientUserId(client));
}

public Action Timer_ApplySpawnSkins(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidHumanClient(client) || !IsPlayerAlive(client))
    {
        return Plugin_Stop;
    }

    ApplyCharacterSkin(client);
    ApplyActiveWeaponSkin(client);
    return Plugin_Stop;
}

public void OnWeaponSwitchPost(int client, int weapon)
{
    if (!IsValidHumanClient(client) || !IsValidEdict(weapon))
    {
        return;
    }

    int entRef = EntIndexToEntRef(weapon);
    if (gLastWeaponEntRef[client] == entRef)
    {
        return;
    }

    gLastWeaponEntRef[client] = entRef;
    ApplyWeaponSkin(client, weapon);
}

void OpenMainSkinMenu(int client)
{
    Menu menu = new Menu(MenuHandler_MainSkins);
    menu.SetTitle("RNK Skins");
    menu.AddItem("characters", "Skins de personagem");
    menu.AddItem("weapons", "Skins de armas");
    menu.AddItem("knives", "Skins de facas");
    menu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_MainSkins(Menu menu, MenuAction action, int client, int item)
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

    char info[32];
    menu.GetItem(item, info, sizeof(info));

    if (StrEqual(info, "characters", false))
    {
        OpenCharacterMenu(client);
    }
    else if (StrEqual(info, "weapons", false))
    {
        OpenWeaponMenu(client);
    }
    else if (StrEqual(info, "knives", false))
    {
        OpenKnifeMenu(client);
    }

    return 0;
}

void OpenCharacterMenu(int client)
{
    Menu menu = new Menu(MenuHandler_CharacterSkins);
    menu.SetTitle("RNK Personagem");
    menu.AddItem("", "Padrao do jogo");

    int team = GetClientTeam(client);
    for (int i = 0; i < gCharacterCount; i++)
    {
        if (gCharacterTeams[i] != 0 && gCharacterTeams[i] != team)
        {
            continue;
        }

        menu.AddItem(gCharacterIds[i], gCharacterNames[i]);
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_CharacterSkins(Menu menu, MenuAction action, int client, int item)
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

    char skinId[32];
    menu.GetItem(item, skinId, sizeof(skinId));
    strcopy(gSelectedCharacterSkin[client], sizeof(gSelectedCharacterSkin[]), skinId);
    SetClientCookie(client, gCookieCharacterSkin, skinId);
    ApplyCharacterSkin(client);

    if (skinId[0] == '\0')
    {
        PrintToChat(client, "\x04[RNK]\x01 Skin de personagem resetada para o padrao.");
    }
    else
    {
        PrintToChat(client, "\x04[RNK]\x01 Skin de personagem atualizada.");
    }

    return 0;
}

void OpenWeaponMenu(int client)
{
    Menu menu = new Menu(MenuHandler_WeaponSkins);
    menu.SetTitle("RNK Armas");
    menu.AddItem("", "Padrao do jogo");

    for (int i = 0; i < gWeaponSkinCount; i++)
    {
        if (gWeaponSkinKnifeOnly[i])
        {
            continue;
        }

        menu.AddItem(gWeaponSkinIds[i], gWeaponSkinNames[i]);
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_WeaponSkins(Menu menu, MenuAction action, int client, int item)
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

    char skinId[32];
    menu.GetItem(item, skinId, sizeof(skinId));
    strcopy(gSelectedWeaponSkin[client], sizeof(gSelectedWeaponSkin[]), skinId);
    SetClientCookie(client, gCookieWeaponSkin, skinId);
    ApplyActiveWeaponSkin(client);

    if (skinId[0] == '\0')
    {
        PrintToChat(client, "\x04[RNK]\x01 Skin de arma resetada para o padrao.");
    }
    else
    {
        PrintToChat(client, "\x04[RNK]\x01 Skin de arma atualizada.");
    }

    return 0;
}

void OpenKnifeMenu(int client)
{
    Menu menu = new Menu(MenuHandler_KnifeSkins);
    menu.SetTitle("RNK Facas");
    menu.AddItem("", "Padrao do jogo");

    for (int i = 0; i < gWeaponSkinCount; i++)
    {
        if (!gWeaponSkinKnifeOnly[i])
        {
            continue;
        }

        menu.AddItem(gWeaponSkinIds[i], gWeaponSkinNames[i]);
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_KnifeSkins(Menu menu, MenuAction action, int client, int item)
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

    char skinId[32];
    menu.GetItem(item, skinId, sizeof(skinId));
    strcopy(gSelectedKnifeSkin[client], sizeof(gSelectedKnifeSkin[]), skinId);
    SetClientCookie(client, gCookieKnifeSkin, skinId);
    ApplyActiveWeaponSkin(client);

    if (skinId[0] == '\0')
    {
        PrintToChat(client, "\x04[RNK]\x01 Skin de faca resetada para o padrao.");
    }
    else
    {
        PrintToChat(client, "\x04[RNK]\x01 Skin de faca atualizada.");
    }

    return 0;
}

void ApplyCharacterSkin(int client)
{
    if (!IsValidHumanClient(client))
    {
        return;
    }

    int index = FindCharacterSkinIndex(gSelectedCharacterSkin[client]);
    if (index == -1)
    {
        return;
    }

    if (gCharacterTeams[index] != 0 && gCharacterTeams[index] != GetClientTeam(client))
    {
        return;
    }

    if (FileExistsOnServer(gCharacterModels[index]))
    {
        SetEntityModel(client, gCharacterModels[index]);
    }
}

void ApplyActiveWeaponSkin(int client)
{
    if (!IsValidHumanClient(client))
    {
        return;
    }

    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (weapon <= MaxClients || !IsValidEdict(weapon))
    {
        return;
    }

    ApplyWeaponSkin(client, weapon);
}

void ApplyWeaponSkin(int client, int weapon)
{
    char weaponClass[64];
    GetEdictClassname(weapon, weaponClass, sizeof(weaponClass));

    bool isKnife = StrEqual(weaponClass, "weapon_knife", false);
    int index = isKnife ? FindWeaponSkinIndex(gSelectedKnifeSkin[client]) : FindWeaponSkinIndex(gSelectedWeaponSkin[client]);
    if (index == -1)
    {
        return;
    }

    if (!WeaponMatchesSkin(index, weaponClass))
    {
        return;
    }

    if (gWeaponSkinWorldModels[index][0] != '\0' && FileExistsOnServer(gWeaponSkinWorldModels[index]))
    {
        SetEntityModel(weapon, gWeaponSkinWorldModels[index]);
    }

    if (gWeaponSkinViewModels[index][0] != '\0' && FileExistsOnServer(gWeaponSkinViewModels[index]))
    {
        int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
        if (viewModel > MaxClients && IsValidEdict(viewModel))
        {
            SetEntityModel(viewModel, gWeaponSkinViewModels[index]);
        }
    }
}

void LoadCharacterSkins()
{
    gCharacterCount = 0;

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/rnk_character_skins.cfg");

    KeyValues kv = new KeyValues("RNKCharacterSkins");
    if (!kv.ImportFromFile(path))
    {
        delete kv;
        return;
    }

    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            if (gCharacterCount >= MAX_RNK_CHARACTER_SKINS)
            {
                break;
            }

            kv.GetSectionName(gCharacterIds[gCharacterCount], sizeof(gCharacterIds[]));
            kv.GetString("name", gCharacterNames[gCharacterCount], sizeof(gCharacterNames[]), gCharacterIds[gCharacterCount]);
            kv.GetString("model", gCharacterModels[gCharacterCount], sizeof(gCharacterModels[]));
            gCharacterTeams[gCharacterCount] = kv.GetNum("team", 0);

            gCharacterCount++;
        }
        while (kv.GotoNextKey(false));
    }

    delete kv;
}

void LoadWeaponSkins()
{
    gWeaponSkinCount = 0;

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/rnk_weapon_skins.cfg");

    KeyValues kv = new KeyValues("RNKWeaponSkins");
    if (!kv.ImportFromFile(path))
    {
        delete kv;
        return;
    }

    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            if (gWeaponSkinCount >= MAX_RNK_WEAPON_SKINS)
            {
                break;
            }

            kv.GetSectionName(gWeaponSkinIds[gWeaponSkinCount], sizeof(gWeaponSkinIds[]));
            kv.GetString("name", gWeaponSkinNames[gWeaponSkinCount], sizeof(gWeaponSkinNames[]), gWeaponSkinIds[gWeaponSkinCount]);
            kv.GetString("view_model", gWeaponSkinViewModels[gWeaponSkinCount], sizeof(gWeaponSkinViewModels[]));
            kv.GetString("world_model", gWeaponSkinWorldModels[gWeaponSkinCount], sizeof(gWeaponSkinWorldModels[]));
            kv.GetString("weapons", gWeaponSkinWeapons[gWeaponSkinCount], sizeof(gWeaponSkinWeapons[]));
            gWeaponSkinKnifeOnly[gWeaponSkinCount] = kv.GetNum("knife_only", 0) != 0;

            gWeaponSkinCount++;
        }
        while (kv.GotoNextKey(false));
    }

    delete kv;
}

void PrecacheConfiguredAssets()
{
    for (int i = 0; i < gCharacterCount; i++)
    {
        if (FileExistsOnServer(gCharacterModels[i]))
        {
            PrecacheModel(gCharacterModels[i], true);
        }
    }

    for (int i = 0; i < gWeaponSkinCount; i++)
    {
        if (gWeaponSkinViewModels[i][0] != '\0' && FileExistsOnServer(gWeaponSkinViewModels[i]))
        {
            PrecacheModel(gWeaponSkinViewModels[i], true);
        }

        if (gWeaponSkinWorldModels[i][0] != '\0' && FileExistsOnServer(gWeaponSkinWorldModels[i]))
        {
            PrecacheModel(gWeaponSkinWorldModels[i], true);
        }
    }
}

int FindCharacterSkinIndex(const char[] skinId)
{
    if (skinId[0] == '\0')
    {
        return -1;
    }

    for (int i = 0; i < gCharacterCount; i++)
    {
        if (StrEqual(gCharacterIds[i], skinId, false))
        {
            return i;
        }
    }

    return -1;
}

int FindWeaponSkinIndex(const char[] skinId)
{
    if (skinId[0] == '\0')
    {
        return -1;
    }

    for (int i = 0; i < gWeaponSkinCount; i++)
    {
        if (StrEqual(gWeaponSkinIds[i], skinId, false))
        {
            return i;
        }
    }

    return -1;
}

bool WeaponMatchesSkin(int index, const char[] weaponClass)
{
    if (gWeaponSkinWeapons[index][0] == '\0')
    {
        return false;
    }

    char filters[256];
    strcopy(filters, sizeof(filters), gWeaponSkinWeapons[index]);

    char tokens[16][32];
    int count = ExplodeString(filters, ",", tokens, sizeof(tokens), sizeof(tokens[]));
    for (int i = 0; i < count; i++)
    {
        TrimString(tokens[i]);
        if (StrEqual(tokens[i], weaponClass, false))
        {
            return true;
        }
    }

    return false;
}

bool FileExistsOnServer(const char[] relativePath)
{
    if (relativePath[0] == '\0')
    {
        return false;
    }

    char fullPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, fullPath, sizeof(fullPath), "../../%s", relativePath);
    return FileExists(fullPath);
}

bool IsValidHumanClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}
