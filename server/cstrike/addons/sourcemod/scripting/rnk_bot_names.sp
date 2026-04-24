#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define MAX_RNK_BOT_NAMES 128

public Plugin myinfo =
{
    name = "RNK Bot Names",
    author = "RNK",
    description = "Renomeia bots com nomes de usuarios",
    version = "0.1.0",
    url = ""
};

char gBotNames[MAX_RNK_BOT_NAMES][64];
bool gBotNameInUse[MAX_RNK_BOT_NAMES];
int gBotNameCount;
int gBotAssignedName[MAXPLAYERS + 1];

public void OnPluginStart()
{
    LoadBotNames();

    AddCommandListener(Listener_BotSay, "say");
    AddCommandListener(Listener_BotSay, "say_team");

    for (int client = 1; client <= MaxClients; client++)
    {
        gBotAssignedName[client] = -1;
        if (IsClientInGame(client) && IsFakeClient(client))
        {
            AssignBotName(client);
        }
    }
}

public Action Listener_BotSay(int client, const char[] command, int argc)
{
    if (client >= 1 && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client))
        return Plugin_Stop;
    return Plugin_Continue;
}

public void OnMapStart()
{
    LoadBotNames();
}

public void OnClientPutInServer(int client)
{
    gBotAssignedName[client] = -1;

    if (IsFakeClient(client))
    {
        CreateTimer(0.5, Timer_AssignBotName, GetClientUserId(client));
    }
}

public void OnClientDisconnect(int client)
{
    if (gBotAssignedName[client] >= 0 && gBotAssignedName[client] < gBotNameCount)
    {
        gBotNameInUse[gBotAssignedName[client]] = false;
    }

    gBotAssignedName[client] = -1;
}

public Action Timer_AssignBotName(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client <= 0 || !IsClientInGame(client) || !IsFakeClient(client))
    {
        return Plugin_Stop;
    }

    AssignBotName(client);
    return Plugin_Stop;
}

void LoadBotNames()
{
    gBotNameCount = 0;

    for (int i = 0; i < MAX_RNK_BOT_NAMES; i++)
    {
        gBotNameInUse[i] = false;
        gBotNames[i][0] = '\0';
    }

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/rnk_bot_names.cfg");

    KeyValues kv = new KeyValues("RNKBotNames");
    if (!kv.ImportFromFile(path))
    {
        delete kv;
        return;
    }

    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            if (gBotNameCount >= MAX_RNK_BOT_NAMES)
            {
                break;
            }

            kv.GetString("name", gBotNames[gBotNameCount], sizeof(gBotNames[]));
            if (gBotNames[gBotNameCount][0] != '\0')
            {
                gBotNameCount++;
            }
        }
        while (kv.GotoNextKey(false));
    }

    delete kv;

    for (int client = 1; client <= MaxClients; client++)
    {
        gBotAssignedName[client] = -1;
    }
}

void AssignBotName(int client)
{
    if (gBotNameCount <= 0)
    {
        return;
    }

    if (gBotAssignedName[client] >= 0 && gBotAssignedName[client] < gBotNameCount)
    {
        return;
    }

    int index = FindAvailableBotName();
    if (index == -1)
    {
        index = GetRandomInt(0, gBotNameCount - 1);
    }

    gBotAssignedName[client] = index;
    gBotNameInUse[index] = true;
    SetClientName(client, gBotNames[index]);
}

int FindAvailableBotName()
{
    for (int i = 0; i < gBotNameCount; i++)
    {
        if (!gBotNameInUse[i])
        {
            return i;
        }
    }

    return -1;
}
