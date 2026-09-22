using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace Amiin.Services;

/// <summary>Thin JSON/bearer-token client for the Amiin Online API. Carries over the exact
/// request/error-handling behavior of the original launcher (HTTPS enforcement lives in
/// <see cref="Updates.SafeUrl"/>, called before every request).</summary>
public class ApiService
{
    private readonly AppState _state;
    public ApiService(AppState state) => _state = state;

    public async Task<JsonElement> Send(string path, object? body = null, string? bearer = null)
    {
        if (_state.Config is null) throw new Exception("Online service is not configured yet.");
        using var request = new HttpRequestMessage(body is null ? HttpMethod.Get : HttpMethod.Post,
            Updates.SafeUrl(_state.Config.api.TrimEnd('/') + path, _state.Config.development));
        var token = bearer ?? _state.Token;
        if (!string.IsNullOrEmpty(token)) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (body is not null) request.Content = new StringContent(JsonSerializer.Serialize(body), Encoding.UTF8, "application/json");
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(120));
        using var response = await Updates.Http.SendAsync(request, timeout.Token);
        var raw = await response.Content.ReadAsStringAsync(timeout.Token);
        JsonElement result;
        try { result = JsonDocument.Parse(raw).RootElement.Clone(); }
        catch { throw new Exception("Service is waking up or unavailable. Try again in a minute."); }
        if (!response.IsSuccessStatusCode) throw new Exception(FriendlyDetail(result));
        return result;
    }

    // FastAPI validation errors return `detail` as an array of {msg,...} objects, not a
    // string -- without this, the raw JSON array would be shown to the user verbatim.
    private static string FriendlyDetail(JsonElement result)
    {
        if (!result.TryGetProperty("detail", out var detail)) return "Service request failed.";
        if (detail.ValueKind == JsonValueKind.String) return detail.GetString()!;
        if (detail.ValueKind == JsonValueKind.Array)
        {
            var messages = new List<string>();
            foreach (var item in detail.EnumerateArray())
                if (item.TryGetProperty("msg", out var msg))
                    messages.Add(msg.GetString()!.Replace("String should have at least", "Needs at least").Replace("String should have at most", "Needs at most"));
            return messages.Count > 0 ? string.Join(" ", messages.Distinct()) : "Check the form and try again.";
        }
        return "Service request failed.";
    }
}
