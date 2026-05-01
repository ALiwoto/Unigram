param(
  [string]$OutputPath = 'Telegram\Constants.Secret.cs'
)

$hasApiId = -not [string]::IsNullOrWhiteSpace($env:UNIGRAM_API_ID)
$hasApiHash = -not [string]::IsNullOrWhiteSpace($env:UNIGRAM_API_HASH)
$hasAppChannel = -not [string]::IsNullOrWhiteSpace($env:UNIGRAM_APP_CHANNEL)

$allProvided = $hasApiId -and $hasApiHash -and $hasAppChannel
$allMissing = (-not $hasApiId) -and (-not $hasApiHash) -and (-not $hasAppChannel)

if (-not $allProvided -and -not $allMissing) {
  throw 'UNIGRAM_API_ID, UNIGRAM_API_HASH, and UNIGRAM_APP_CHANNEL must be either all set or all omitted.'
}

if ($allProvided) {
  $apiId = 0
  if (-not [int]::TryParse($env:UNIGRAM_API_ID, [ref]$apiId)) {
    throw 'UNIGRAM_API_ID must be an integer.'
  }

  $apiHash = $env:UNIGRAM_API_HASH.Replace('"', '\"')
  $appChannel = $env:UNIGRAM_APP_CHANNEL.Replace('"', '\"')

  $content = @"
namespace Telegram
{
    public static partial class Constants
    {
        static Constants()
        {
            ApiId = $apiId;
            ApiHash = "$apiHash";
            AppChannel = "$appChannel";
        }
    }
}
"@
} else {
  $content = @"
using System;
using System.IO;
using System.Text.Json;
using Windows.Storage;

namespace Telegram
{
    public static partial class Constants
    {
        static Constants()
        {
            var localFolderPath = ApplicationData.Current.LocalFolder.Path;
            if (string.IsNullOrWhiteSpace(localFolderPath))
            {
                throw new InvalidOperationException("Unable to resolve the app LocalState folder.");
            }

            var apiJsonPath = Path.Combine(localFolderPath, "api.json");
            if (!File.Exists(apiJsonPath))
            {
                throw new FileNotFoundException("Expected Unigram API configuration at LocalState\\api.json.", apiJsonPath);
            }

            using var document = JsonDocument.Parse(File.ReadAllText(apiJsonPath));
            var root = document.RootElement;

            ApiId = root.GetProperty("ApiId").GetInt32();
            ApiHash = root.GetProperty("ApiHash").GetString() ?? throw new InvalidDataException("ApiHash cannot be null.");
            AppChannel = root.GetProperty("AppChannel").GetString() ?? throw new InvalidDataException("AppChannel cannot be null.");
        }
    }
}
"@
}

Set-Content -Path $OutputPath -Value $content -NoNewline
