using Amiin;
using System.Security.Cryptography;
using System.Text.Json;
var package=new Package("0.2.0","https://example.com/build.zip",new string('a',64),100,"Game.exe");
var entry=new GameEntry("verdant-wilds","The Verdant Wilds","tagline",1,package);
var manifest=new Manifest("preview",2,"test",package,new List<GameEntry>{entry});
void Check(bool pass,string message){if(!pass)throw new Exception(message);Console.WriteLine("PASS "+message);}
void Reject(Action action,string message){try{action();}catch{Console.WriteLine("PASS "+message);return;}throw new Exception(message);}
Check(Updates.ActionFor(manifest,"0.1.0",entry,"0.1.0")=="launcher","launcher must update before outdated game");
Check(Updates.ActionFor(manifest,"0.2.0",entry,"0.1.0")=="game","game updates without changing launcher");
Check(Updates.ActionFor(manifest,"0.2.0",entry,"0.2.0")=="play","matching versions can play");
using var key=RSA.Create(3072);
var raw=JsonSerializer.SerializeToUtf8Bytes(manifest);
string Sign(byte[] bytes)=>JsonSerializer.Serialize(new Envelope(Convert.ToBase64String(bytes),Convert.ToBase64String(key.SignData(bytes,HashAlgorithmName.SHA256,RSASignaturePadding.Pkcs1))));
var signed=Sign(raw);
Check(Updates.Verify(signed,key.ExportSubjectPublicKeyInfoPem(),"preview").revision==2,"signed release verifies");
Reject(()=>Updates.Verify(signed,key.ExportSubjectPublicKeyInfoPem(),"public"),"test release cannot become public");
var envelope=JsonSerializer.Deserialize<Envelope>(signed)!;raw[10]^=1;
Reject(()=>Updates.Verify(JsonSerializer.Serialize(envelope with{payload=Convert.ToBase64String(raw)}),key.ExportSubjectPublicKeyInfoPem(),"preview"),"modified release signature rejected");
foreach(var bad in new[]{"../escape.exe","C:\\escape.exe","/escape.exe","folder/../../escape.exe","file.exe:stream"})Reject(()=>Updates.SafeEntry(Path.GetTempPath(),bad),"reject archive path "+bad);
Reject(()=>Updates.SafeUrl("http://example.com/build.zip",false),"non-HTTPS production download rejected");

if (args.Contains("--live-download"))
{
    // Exercises the real download+extract path against the actual production
    // release, bypassing the WPF UI (useful when the GUI can't be launched).
    var liveUrl = "https://github.com/amiinreal/amiinstudio-verdant-wilds-releases/releases/download/v0.2.0/launcher-0.2.0.zip";
    var livePackage = new Package("0.2.0", liveUrl, "", 0, "AmiinLauncher.exe");
    using var http = new HttpClient(new HttpClientHandler { AllowAutoRedirect = true });
    using var head = await http.GetAsync(liveUrl, HttpCompletionOption.ResponseHeadersRead);
    var size = head.Content.Headers.ContentLength ?? 0;
    var hasher = SHA256.Create();
    await using (var s = await head.Content.ReadAsStreamAsync()) await hasher.ComputeHashAsync(s);
    Console.WriteLine($"live asset size={size}");
    var realPackage = new Package("0.2.0-test", liveUrl, Convert.ToHexString(hasher.Hash!).ToLowerInvariant(), size, "AmiinLauncher.exe");
    try
    {
        var reporter = new Progress<(double, string)>(v => Console.WriteLine($"{v.Item1:F0}% {v.Item2}"));
        var installedPath = await Updates.Install(realPackage, "launcher", "diagnostic", false, reporter);
        Console.WriteLine("INSTALL_OK " + installedPath);
    }
    catch (Exception ex)
    {
        Console.WriteLine("INSTALL_FAILED " + ex.GetType().Name + ": " + ex.Message);
        Console.WriteLine(ex.StackTrace);
        throw;
    }
    finally { try { Directory.Delete(Path.Combine(Updates.Root, "launcher", "diagnostic"), true); } catch { } }
}

if (args.Contains("--live-flow"))
{
    // Reproduces UpdateAndPlay() end-to-end against the real production API,
    // to catch anything that only breaks with the real manifest/game package.
    using var http = new HttpClient(new HttpClientHandler { AllowAutoRedirect = true });
    var api = "https://amiin-online.onrender.com";
    var uname = "qa_" + Guid.NewGuid().ToString("N")[..8];
    var reg = await http.PostAsync(api + "/auth/register", new StringContent(JsonSerializer.Serialize(new { username = uname, password = "Correct-Horse-Cloud-97" }), System.Text.Encoding.UTF8, "application/json"));
    reg.EnsureSuccessStatusCode();
    var regBody = JsonDocument.Parse(await reg.Content.ReadAsStringAsync()).RootElement;
    var authToken = regBody.GetProperty("token").GetString()!;

    async Task<JsonElement> Get(string path)
    {
        using var req = new HttpRequestMessage(HttpMethod.Get, api + path);
        req.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", authToken);
        using var resp = await http.SendAsync(req);
        var raw = await resp.Content.ReadAsStringAsync();
        Console.WriteLine($"GET {path} -> {(int)resp.StatusCode}");
        resp.EnsureSuccessStatusCode();
        return JsonDocument.Parse(raw).RootElement.Clone();
    }

    try
    {
        var releaseEnvelope = await Get("/releases/public");
        Console.WriteLine("envelope fetched, keys: " + string.Join(",", releaseEnvelope.EnumerateObject().Select(p => p.Name)));
        var publicKeyPem = "-----BEGIN PUBLIC KEY-----\nMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAxlTj7cN40g0tLkeZ7l71\n801cPL0APkiJ5IkvYMVXyfw7XQ8CBk1/qwbc5kvGXJdJhRXzvqlcO0MvJ8RHWBCL\ncfwm01ijUIupx+XxaL4no8dp9imAiPoH5VgMtVsgSBXKW9aBaIW7Qg2gJW92N1mJ\n2g/Viz3585YZVMDj5l2FzJH3xUkeAq6Bd6bERWcYDL8NOVwT8gc8Zf91LebuD8HG\nspj61Lo5Yvc6vFwbwzTSjNi4UEnHkwsiT4XI67RPVII26rt+3ARQevrVV4MrkAkS\n9iOFa0fG++tjm5PrOx59FKmSJSYIGGasBW7XoqwW7x8r9iNl5ccXRuepm7SWIzyY\n3hPIY5JhDJatHMfmSJAz1FUWxGRKHPTSnxBm1vvLZ2owxv/uEz2tu7m7vnxm7vVp\noSLzW4JjqlQODxww80wNvEns6Rc8msCborsgI9W/U339xYbQm+aav5kkOtcHaYLa\nLe87pl5SSU8QcZ6oWtMsiqKFx1Q7LNnIN7B5rV2BNudVAgMBAAE=\n-----END PUBLIC KEY-----\n";
        var release = Updates.Verify(releaseEnvelope.GetRawText(), publicKeyPem, "public");
        Console.WriteLine("verified: launcher=" + release.launcher.version + " games=" + string.Join(",", release.games.Select(g => g.id + "@" + g.package.version)));
        var chosen = release.games.First(g => g.id == "verdant-wilds");
        var installed = Updates.Installed("game", "public", chosen.id);
        var action = Updates.ActionFor(release, "0.2.0", chosen, installed.Item1?.version);
        Console.WriteLine("action=" + action);
        if (action == "game")
        {
            var reporter = new Progress<(double, string)>(v => { if (v.Item1 is 0 or 100 or 70) Console.WriteLine($"{v.Item1:F0}% {v.Item2}"); });
            var gamePath = await Updates.Install(chosen.package, "game", "public", false, reporter, chosen.id);
            Console.WriteLine("GAME_INSTALL_OK " + gamePath);
            try { Directory.Delete(Path.Combine(Updates.Root, "game", "public"), true); } catch { }
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine("LIVE_FLOW_FAILED " + ex.GetType().Name + ": " + ex.Message);
        Console.WriteLine(ex.StackTrace);
        throw;
    }
}

Console.WriteLine("UPDATE_CHECKS_COMPLETE");
