using System.IO;
using System.Text.Json;

namespace Amiin.Services;

/// <summary>Persists a session token to disk when "Remember me" is checked, so the launcher
/// can skip the login screen on the next start. The token itself is exactly as sensitive as
/// any other bearer token this launcher already handles in memory; this just extends its
/// lifetime to disk, scoped to the current Windows user account's profile folder.</summary>
public static class RememberedSession
{
    private static string Path => System.IO.Path.Combine(Updates.Root, "remember.json");

    public static void Save(string token, string username)
    {
        try
        {
            Directory.CreateDirectory(Updates.Root);
            Updates.AtomicText(Path, JsonSerializer.Serialize(new { token, username }));
        }
        catch { /* best-effort; worst case the user just has to sign in again */ }
    }

    public static (string Token, string Username)? Load()
    {
        try
        {
            if (!File.Exists(Path)) return null;
            using var doc = JsonDocument.Parse(File.ReadAllText(Path));
            var token = doc.RootElement.GetProperty("token").GetString();
            var username = doc.RootElement.GetProperty("username").GetString();
            if (string.IsNullOrEmpty(token) || string.IsNullOrEmpty(username)) return null;
            return (token, username);
        }
        catch { return null; }
    }

    public static void Clear()
    {
        try { if (File.Exists(Path)) File.Delete(Path); } catch { /* ignore */ }
    }
}
