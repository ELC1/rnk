#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
    name = "RNK Sync",
    author = "RNK",
    description = "Exporta ranking para JSON (enviado por script externo)",
    version = "0.1.0",
    url = ""
};

char gStatsPath[PLATFORM_MAX_PATH];
char gExportPath[PLATFORM_MAX_PATH];

public void OnPluginStart()
{
    AutoExecConfig(true, "rnk_sync");

    BuildPath(Path_SM, gStatsPath, sizeof(gStatsPath), "data/rnk_rankings.txt");
    BuildPath(Path_SM, gExportPath, sizeof(gExportPath), "data/rnk_export.json");

    RegAdminCmd("sm_rnk_export", Command_Export, ADMFLAG_GENERIC, "Exporta ranking para JSON.");
}

public void OnMapEnd()
{
    ExportJson();
}

public Action Command_Export(int client, int args)
{
    ExportJson();
    ReplyToCommand(client, "[RNK] Exportado para rnk_export.json");
    return Plugin_Handled;
}

void ExportJson()
{
    KeyValues kv = new KeyValues("RNKRankings");

    if (!FileExists(gStatsPath) || !kv.ImportFromFile(gStatsPath))
    {
        delete kv;
        return;
    }

    File f = OpenFile(gExportPath, "w");
    if (f == null)
    {
        delete kv;
        return;
    }

    f.WriteLine("[");

    bool first = true;
    kv.Rewind();

    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            char steamId[32];
            char name[128];
            kv.GetSectionName(steamId, sizeof(steamId));
            kv.GetString("name", name, sizeof(name), "Unknown");

            // Escape quotes in name
            ReplaceString(name, sizeof(name), "\\", "\\\\");
            ReplaceString(name, sizeof(name), "\"", "\\\"");

            int score        = kv.GetNum("score", 0);
            int kills        = kv.GetNum("kills", 0);
            int deaths       = kv.GetNum("deaths", 0);
            int knifeKills   = kv.GetNum("knife_kills", 0);
            int noscopeKills = kv.GetNum("noscope_kills", 0);

            char line[512];
            Format(line, sizeof(line),
                "%s  {\"steamId\":\"%s\",\"name\":\"%s\",\"score\":%d,\"kills\":%d,\"deaths\":%d,\"knifeKills\":%d,\"noscopeKills\":%d}",
                first ? "" : ",\n",
                steamId, name, score, kills, deaths, knifeKills, noscopeKills
            );

            f.WriteString(line, false);
            first = false;
        }
        while (kv.GotoNextKey(false));
    }

    f.WriteLine("\n]");
    delete f;
    delete kv;

    LogMessage("[RNK Sync] Exportado %s", gExportPath);
}
