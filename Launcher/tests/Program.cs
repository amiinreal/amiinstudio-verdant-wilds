using Amiin;
using System.Security.Cryptography;
using System.Text.Json;
var package=new Package("0.2.0","https://example.com/build.zip",new string('a',64),100,"Game.exe");
var manifest=new Manifest("preview",2,"test",package,package);
void Check(bool pass,string message){if(!pass)throw new Exception(message);Console.WriteLine("PASS "+message);}
void Reject(Action action,string message){try{action();}catch{Console.WriteLine("PASS "+message);return;}throw new Exception(message);}
Check(Updates.ActionFor(manifest,"0.1.0","0.1.0")=="launcher","launcher must update before outdated game");
Check(Updates.ActionFor(manifest,"0.2.0","0.1.0")=="game","game updates without changing launcher");
Check(Updates.ActionFor(manifest,"0.2.0","0.2.0")=="play","matching versions can play");
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
Console.WriteLine("UPDATE_CHECKS_COMPLETE");
