#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
    name = "RNK Rankings",
    author = "RNK",
    description = "Ranking proprio por pontuacao, faca e no-scope",
    version = "0.1.0",
    url = ""
};

ConVar gCvarKillPoints;
ConVar gCvarKnifeBonus;
ConVar gCvarNoScopeBonus;
ConVar gCvarDeathPenalty;
ConVar gCvarTopSize;

KeyValues gStatsKv;
char gStatsPath[PLATFORM_MAX_PATH];

public void OnPluginStart()
{
    gCvarKillPoints = CreateConVar("sm_rnk_rank_kill_points", "10", "Pontos base por kill.", FCVAR_NOTIFY, true, 0.0);
    gCvarKnifeBonus = CreateConVar("sm_rnk_rank_knife_bonus", "15", "Bonus de pontos por kill de faca.", FCVAR_NOTIFY, true, 0.0);
    gCvarNoScopeBonus = CreateConVar("sm_rnk_rank_noscope_bonus", "20", "Bonus de pontos por no-scope.", FCVAR_NOTIFY, true, 0.0);
    gCvarDeathPenalty = CreateConVar("sm_rnk_rank_death_penalty", "2", "Pontos perdidos por morte.", FCVAR_NOTIFY, true, 0.0);
    gCvarTopSize = CreateConVar("sm_rnk_rank_top_size", "5", "Quantidade de posicoes exibidas no top.", FCVAR_NOTIFY, true, 3.0, true, 10.0);

    AutoExecConfig(true, "rnk_rankings");

    RegConsoleCmd("sm_rank", Command_Rank);
    RegConsoleCmd("sm_ranking", Command_Rank);
    RegConsoleCmd("sm_topscore", Command_TopScore);
    RegConsoleCmd("sm_topknife", Command_TopKnife);
    RegConsoleCmd("sm_topnoscope", Command_TopNoScope);
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_SayTeam, "say_team");

    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);

    BuildPath(Path_SM, gStatsPath, sizeof(gStatsPath), "data/rnk_rankings.txt");
    LoadStats();
}

public void OnClientAuthorized(int client, const char[] auth)
{
    if (!IsValidPlayableClient(client))
    {
        return;
    }

    EnsureClientRecord(client);
    SaveStats();
}

public void OnClientDisconnect(int client)
{
    if (!HasClientSteamId(client))
    {
        return;
    }

    UpdateClientName(client);
    SaveStats();
}

public void OnMapEnd()
{
    SaveStats();
}

public Action Command_Rank(int client, int args)
{
    if (!IsValidPlayableClient(client))
    {
        ReplyToCommand(client, "[RNK] Comando disponivel apenas para jogadores.");
        return Plugin_Handled;
    }

    EnsureClientRecord(client);

    char steamId[32];
    GetClientSteamId(client, steamId, sizeof(steamId));

    int score = GetClientStat(steamId, "score");
    int knifeKills = GetClientStat(steamId, "knife_kills");
    int noScopeKills = GetClientStat(steamId, "noscope_kills");

    int scoreRank = GetRankForStat(steamId, "score");
    int knifeRank = GetRankForStat(steamId, "knife_kills");
    int noScopeRank = GetRankForStat(steamId, "noscope_kills");

    PrintToChat(client, "\x04[RNK]\x01 Sua pontuacao: \x03%d\x01 (rank \x03#%d\x01)", score, scoreRank);
    PrintToChat(client, "\x04[RNK]\x01 Faca: \x03%d\x01 (rank \x03#%d\x01) | No-scope: \x03%d\x01 (rank \x03#%d\x01)", knifeKills, knifeRank, noScopeKills, noScopeRank);
    return Plugin_Handled;
}

public Action Command_TopScore(int client, int args)
{
    PrintTopList(client, "score", "TOP Pontuacao");
    return Plugin_Handled;
}

public Action Command_TopKnife(int client, int args)
{
    PrintTopList(client, "knife_kills", "TOP Faca");
    return Plugin_Handled;
}

public Action Command_TopNoScope(int client, int args)
{
    PrintTopList(client, "noscope_kills", "TOP No-scope");
    return Plugin_Handled;
}

public Action Command_Say(int client, const char[] command, int argc)
{
    return HandleRankChat(client, false);
}

public Action Command_SayTeam(int client, const char[] command, int argc)
{
    return HandleRankChat(client, true);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    char weapon[64];
    event.GetString("weapon", weapon, sizeof(weapon));

    if (IsValidPlayableClient(victim))
    {
        EnsureClientRecord(victim);
        UpdateClientName(victim);
        AddToClientStat(victim, "deaths", 1);
        AddToClientStat(victim, "score", -gCvarDeathPenalty.IntValue);
    }

    if (!IsValidPlayableClient(attacker) || attacker == victim)
    {
        SaveStats();
        return;
    }

    EnsureClientRecord(attacker);
    UpdateClientName(attacker);
    AddToClientStat(attacker, "kills", 1);
    AddToClientStat(attacker, "score", gCvarKillPoints.IntValue);

    bool isKnifeKill = IsKnifeKill(weapon);
    bool isNoScopeKill = IsNoScopeKill(attacker, weapon);

    if (isKnifeKill)
    {
        AddToClientStat(attacker, "knife_kills", 1);
        AddToClientStat(attacker, "score", gCvarKnifeBonus.IntValue);
        PrintToChat(attacker, "\x04[RNK]\x01 Kill de faca: \x03+%d\x01 pontos.", gCvarKnifeBonus.IntValue);
    }

    if (isNoScopeKill)
    {
        AddToClientStat(attacker, "noscope_kills", 1);
        AddToClientStat(attacker, "score", gCvarNoScopeBonus.IntValue);
        PrintToChat(attacker, "\x04[RNK]\x01 No-scope: \x03+%d\x01 pontos.", gCvarNoScopeBonus.IntValue);
    }

    SaveStats();
}

void LoadStats()
{
    delete gStatsKv;
    gStatsKv = new KeyValues("RNKRankings");

    if (FileExists(gStatsPath))
    {
        gStatsKv.ImportFromFile(gStatsPath);
    }
    else
    {
        SaveStats();
    }
}

void SaveStats()
{
    if (gStatsKv != null)
    {
        gStatsKv.Rewind();
        gStatsKv.ExportToFile(gStatsPath);
    }
}

void EnsureClientRecord(int client)
{
    char steamId[32];
    char name[64];

    GetClientSteamId(client, steamId, sizeof(steamId));
    if (steamId[0] == '\0')
    {
        return;
    }

    GetClientName(client, name, sizeof(name));

    gStatsKv.Rewind();
    if (!gStatsKv.JumpToKey(steamId, true))
    {
        return;
    }

    gStatsKv.SetString("name", name);

    EnsureStatKey("score");
    EnsureStatKey("kills");
    EnsureStatKey("deaths");
    EnsureStatKey("knife_kills");
    EnsureStatKey("noscope_kills");

    gStatsKv.Rewind();
}

void UpdateClientName(int client)
{
    char steamId[32];
    char name[64];

    GetClientSteamId(client, steamId, sizeof(steamId));
    if (steamId[0] == '\0')
    {
        return;
    }

    GetClientName(client, name, sizeof(name));

    gStatsKv.Rewind();
    if (gStatsKv.JumpToKey(steamId, false))
    {
        gStatsKv.SetString("name", name);
        gStatsKv.Rewind();
    }
}

void EnsureStatKey(const char[] key)
{
    char currentValue[16];
    gStatsKv.GetString(key, currentValue, sizeof(currentValue), "__missing__");

    if (StrEqual(currentValue, "__missing__", false))
    {
        gStatsKv.SetNum(key, 0);
    }
}

void AddToClientStat(int client, const char[] key, int delta)
{
    char steamId[32];
    GetClientSteamId(client, steamId, sizeof(steamId));
    if (steamId[0] == '\0')
    {
        return;
    }

    gStatsKv.Rewind();
    if (!gStatsKv.JumpToKey(steamId, true))
    {
        return;
    }

    int value = gStatsKv.GetNum(key, 0) + delta;
    if (StrEqual(key, "score") && value < 0)
    {
        value = 0;
    }

    gStatsKv.SetNum(key, value);
    gStatsKv.Rewind();
}

int GetClientStat(const char[] steamId, const char[] key)
{
    if (steamId[0] == '\0')
    {
        return 0;
    }

    gStatsKv.Rewind();
    if (!gStatsKv.JumpToKey(steamId, false))
    {
        return 0;
    }

    int value = gStatsKv.GetNum(key, 0);
    gStatsKv.Rewind();
    return value;
}

int GetRankForStat(const char[] steamId, const char[] key)
{
    int rank = 1;
    int currentValue = GetClientStat(steamId, key);

    gStatsKv.Rewind();
    if (gStatsKv.GotoFirstSubKey(false))
    {
        do
        {
            char currentSection[64];
            gStatsKv.GetSectionName(currentSection, sizeof(currentSection));

            if (!StrEqual(currentSection, steamId, false) && gStatsKv.GetNum(key, 0) > currentValue)
            {
                rank++;
            }
        }
        while (gStatsKv.GotoNextKey(false));
    }

    gStatsKv.Rewind();
    return rank;
}

void PrintTopList(int client, const char[] key, const char[] title)
{
    int topSize = gCvarTopSize.IntValue;
    int topValues[10];
    char topNames[10][64];

    for (int i = 0; i < topSize; i++)
    {
        topValues[i] = -1;
        strcopy(topNames[i], sizeof(topNames[]), "---");
    }

    gStatsKv.Rewind();
    if (gStatsKv.GotoFirstSubKey(false))
    {
        do
        {
            int value = gStatsKv.GetNum(key, 0);
            char name[64];
            gStatsKv.GetString("name", name, sizeof(name), "Sem nome");

            for (int i = 0; i < topSize; i++)
            {
                if (value <= topValues[i])
                {
                    continue;
                }

                for (int shift = topSize - 1; shift > i; shift--)
                {
                    topValues[shift] = topValues[shift - 1];
                    strcopy(topNames[shift], sizeof(topNames[]), topNames[shift - 1]);
                }

                topValues[i] = value;
                strcopy(topNames[i], sizeof(topNames[]), name);
                break;
            }
        }
        while (gStatsKv.GotoNextKey(false));
    }

    gStatsKv.Rewind();

    PrintRankMessage(client, "\x04[RNK]\x01 %s", title);
    for (int i = 0; i < topSize; i++)
    {
        if (topValues[i] < 0)
        {
            continue;
        }

        PrintRankMessage(client, "\x04[RNK]\x01 #%d \x03%s\x01 - \x03%d", i + 1, topNames[i], topValues[i]);
    }
}

Action HandleRankChat(int client, bool teamOnly)
{
    if (!IsValidPlayableClient(client))
    {
        return Plugin_Continue;
    }

    char message[192];
    GetCmdArgString(message, sizeof(message));
    StripQuotes(message);
    TrimString(message);

    if (message[0] == '\0')
    {
        return Plugin_Handled;
    }

    if (message[0] == '@')
    {
        return Plugin_Continue;
    }

    EnsureClientRecord(client);
    UpdateClientName(client);

    char steamId[32];
    char rankLabel[32];
    char name[64];
    char adminLabel[16];

    GetClientSteamId(client, steamId, sizeof(steamId));
    GetClientName(client, name, sizeof(name));
    BuildChatRankLabel(steamId, rankLabel, sizeof(rankLabel));
    BuildAdminLabel(client, adminLabel, sizeof(adminLabel));

    bool isAlive = IsPlayerAlive(client);
    int team = GetClientTeam(client);

    if (teamOnly)
    {
        for (int target = 1; target <= MaxClients; target++)
        {
            if (!IsClientInGame(target) || IsFakeClient(target) || GetClientTeam(target) != team)
            {
                continue;
            }

            if (!isAlive)
            {
                PrintToChat(target, "\x01*DEAD* (Time) \x04%s\x01%s %s: %s", rankLabel, adminLabel, name, message);
            }
            else
            {
                PrintToChat(target, "\x01(Time) \x04%s\x01%s %s: %s", rankLabel, adminLabel, name, message);
            }
        }

        return Plugin_Handled;
    }

    if (!isAlive)
    {
        PrintToChatAll("\x01*DEAD* \x04%s\x01%s %s: %s", rankLabel, adminLabel, name, message);
    }
    else
    {
        PrintToChatAll("\x04%s\x01%s %s: %s", rankLabel, adminLabel, name, message);
    }

    return Plugin_Handled;
}

void BuildChatRankLabel(const char[] steamId, char[] buffer, int maxlen)
{
    int rank = GetRankForStat(steamId, "score");
    if (rank <= 10)
    {
        Format(buffer, maxlen, "[TOP %d]", rank);
        return;
    }

    Format(buffer, maxlen, "[RANK %d]", rank);
}

void BuildAdminLabel(int client, char[] buffer, int maxlen)
{
    if (CheckCommandAccess(client, "rnk_admin_tag", ADMFLAG_GENERIC, false))
    {
        Format(buffer, maxlen, " [Admin]");
        return;
    }

    buffer[0] = '\0';
}

bool IsKnifeKill(const char[] weapon)
{
    return StrContains(weapon, "knife", false) != -1;
}

bool IsNoScopeKill(int client, const char[] weapon)
{
    if (!IsSniperWeapon(weapon))
    {
        return false;
    }

    // CSS nao tem m_bIsScoped — FOV 0 significa sem zoom (padrao do servidor)
    int fov = GetEntProp(client, Prop_Send, "m_nFOV");
    return fov == 0 || fov >= 90;
}

bool IsSniperWeapon(const char[] weapon)
{
    return StrEqual(weapon, "awp", false)
        || StrEqual(weapon, "scout", false)
        || StrEqual(weapon, "g3sg1", false)
        || StrEqual(weapon, "sg550", false);
}

bool IsValidPlayableClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}

bool HasClientSteamId(int client)
{
    char steamId[32];
    return GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId), true);
}

void GetClientSteamId(int client, char[] steamId, int maxlen)
{
    if (!GetClientAuthId(client, AuthId_Steam2, steamId, maxlen, true))
    {
        steamId[0] = '\0';
    }
}

void PrintRankMessage(int client, const char[] format, any ...)
{
    char buffer[192];
    VFormat(buffer, sizeof(buffer), format, 3);

    if (client > 0 && client <= MaxClients)
    {
        PrintToChat(client, "%s", buffer);
        return;
    }

    PrintToServer("%s", buffer);
}
