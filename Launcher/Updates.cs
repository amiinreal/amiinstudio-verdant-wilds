using System.IO;
using System.IO.Compression;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Amiin;

public record Package(string version, string url, string sha256, long size, string entry);
public record GameEntry(string id, string title, string tagline, int protocol, Package package);
public record Manifest(string channel, long revision, string notes, Package launcher, List<GameEntry> games);
public record Envelope(string payload, string signature);
public record Configuration(string api, string publicKey, bool development = false);

public static class Updates
{
    public const string Version = "0.3.6";
    public static readonly string Root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AmiinStudio");
    public static readonly JsonSerializerOptions Json = new() { PropertyNameCaseInsensitive = true };
    public static readonly HttpClient Http = new(new HttpClientHandler { AllowAutoRedirect = true }) { Timeout = TimeSpan.FromMinutes(20) };
    public static void SafeName(string value)
    {
        if (!Regex.IsMatch(value, "^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$") || value.Contains("..")) throw new Exception("Invalid release name.");
    }
    public static Uri SafeUrl(string value, bool development)
    {
        var uri = new Uri(value);
        if (uri.Scheme != "https" && !(development && uri.Scheme == "http" && uri.Host == "127.0.0.1"))
            throw new Exception("Downloads and accounts require HTTPS.");
        if (!string.IsNullOrEmpty(uri.UserInfo)) throw new Exception("Invalid download URL.");
        return uri;
    }
    public static Manifest Verify(string envelope, string key, string channel)
    {
        var signed = JsonSerializer.Deserialize<Envelope>(envelope, Json) ?? throw new Exception("Missing release.");
        var raw = Convert.FromBase64String(signed.payload);
        using var rsa = RSA.Create(); rsa.ImportFromPem(key);
        if (!rsa.VerifyData(raw, Convert.FromBase64String(signed.signature), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1))
            throw new Exception("Release signature is invalid. Nothing was installed.");
        var manifest = JsonSerializer.Deserialize<Manifest>(raw, Json) ?? throw new Exception("Invalid manifest.");
        if (manifest.channel != channel || manifest.revision < 1 || manifest.games.Count == 0) throw new Exception("Wrong release channel.");
        SafeName(channel); SafeName(manifest.launcher.version);
        foreach (var entry in manifest.games) SafeName(entry.package.version);
        return manifest;
    }
    public static string ActionFor(Manifest release, string launcherVersion, GameEntry selected, string? installedGameVersion)
        => release.launcher.version != launcherVersion ? "launcher" : selected.package.version != installedGameVersion ? "game" : "play";

    public static async Task<string> Install(Package package, string kind, string channel, bool dev, IProgress<(double,string)> progress, string slot = "", CancellationToken cancellationToken = default, Func<bool>? isPaused = null)
    {
        SafeName(package.version); SafeName(channel); if (slot.Length > 0) SafeName(slot);
        if (kind != "launcher" && kind != "game") throw new Exception("Invalid package type.");
        if (package.size <= 0 || package.size > 16L * 1024 * 1024 * 1024 || !Regex.IsMatch(package.sha256, "^[a-fA-F0-9]{64}$")) throw new Exception("Invalid package metadata.");
        var folder = slot.Length > 0 ? Path.Combine(Root, kind, channel, slot) : Path.Combine(Root, kind, channel);
        Directory.CreateDirectory(folder);
        var destination = Path.Combine(folder, package.version + "-" + package.sha256[..12]);
        var archive = Path.Combine(folder, Guid.NewGuid()+".download");
        var stage = Path.Combine(folder, Guid.NewGuid()+".staging");
        try
        {
            using var response = await Http.GetAsync(SafeUrl(package.url, dev), HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            response.EnsureSuccessStatusCode();
            SafeUrl(response.RequestMessage!.RequestUri!.AbsoluteUri, dev);
            await using (var input = await response.Content.ReadAsStreamAsync(cancellationToken))
            await using (var output = new FileStream(archive, FileMode.CreateNew))
            {
                using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
                var buffer = new byte[262144]; long total = 0; int count;
                while (true)
                {
                    // Not reading from the socket while paused lets TCP backpressure actually
                    // stop the transfer, rather than just pretending to via a UI flag.
                    while (isPaused != null && isPaused()) await Task.Delay(200, cancellationToken);
                    count = await input.ReadAsync(buffer, cancellationToken);
                    if (count <= 0) break;
                    total += count;
                    if (total > package.size) throw new Exception("Download exceeded its signed size.");
                    hash.AppendData(buffer, 0, count); await output.WriteAsync(buffer.AsMemory(0,count), cancellationToken);
                    progress.Report((70d * total/package.size, $"Downloading {kind} · {total/1048576d:F1} / {package.size/1048576d:F1} MB"));
                }
                if (total != package.size || !Convert.ToHexString(hash.GetHashAndReset()).Equals(package.sha256, StringComparison.OrdinalIgnoreCase))
                    throw new Exception("Download failed integrity verification. Your installed version is safe.");
            }
            Directory.CreateDirectory(stage);
            using (var zip = ZipFile.OpenRead(archive))
            {
                long expanded = 0; int processed = 0;
                foreach (var item in zip.Entries)
                {
                    expanded += item.Length;
                    if (expanded > 32L*1024*1024*1024 || zip.Entries.Count > 100000) throw new Exception("Archive exceeds installation limits.");
                    var path = SafeEntry(stage, item.FullName);
                    if (((item.ExternalAttributes >> 16) & 0xF000) == 0xA000) throw new Exception("Symbolic links are not permitted.");
                    if (item.FullName.EndsWith('/')) { Directory.CreateDirectory(path); continue; }
                    Directory.CreateDirectory(Path.GetDirectoryName(path)!); item.ExtractToFile(path, false);
                    progress.Report((70 + 29d * ++processed/zip.Entries.Count, $"Installing {kind}…"));
                }
            }
            var entry = SafeEntry(stage, package.entry);
            if (!File.Exists(entry) || !entry.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) throw new Exception("Release executable is missing.");
            await File.WriteAllTextAsync(Path.Combine(stage,"installed.json"), JsonSerializer.Serialize(package));
            // Never overwrite a running version; valid existing installations are reused.
            if (!Directory.Exists(destination)) Directory.Move(stage,destination);
            else Directory.Delete(stage,true);
            AtomicText(Path.Combine(folder,"active.txt"),Path.GetFileName(destination));
            progress.Report((100,"Ready"));
            return SafeEntry(destination,package.entry);
        }
        finally
        {
            if (File.Exists(archive)) File.Delete(archive);
            if (Directory.Exists(stage)) Directory.Delete(stage,true);
        }
    }
    public static string SafeEntry(string root, string name)
    {
        if (Path.IsPathRooted(name) || name.Contains(':') || name.Split('/','\\').Any(p => p == ".." || p.EndsWith(' ') || p.EndsWith('.')))
            throw new Exception("Unsafe archive path.");
        var full = Path.GetFullPath(Path.Combine(root,name));
        if (!full.StartsWith(Path.GetFullPath(root)+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase)) throw new Exception("Archive escaped its installation directory.");
        return full;
    }
    public static void AtomicText(string path, string value)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path+".tmp",value); File.Move(path+".tmp",path,true);
    }
    public static (Package?,string?) Installed(string kind,string channel,string slot = "")
    {
        var parent = slot.Length > 0 ? Path.Combine(Root,kind,channel,slot) : Path.Combine(Root,kind,channel); var pointer=Path.Combine(parent,"active.txt");
        if (!File.Exists(pointer)) return (null,null);
        var folder=File.ReadAllText(pointer).Trim(); SafeName(folder);
        var path=Path.Combine(parent,folder);
        var record=Path.Combine(path,"installed.json");
        if (!File.Exists(record)) return (null,null);
        var package=JsonSerializer.Deserialize<Package>(File.ReadAllText(record),Json)!;
        var executable=SafeEntry(path,package.entry);
        return File.Exists(executable) ? (package,executable) : (null,null);
    }
}
