using System.Text.Json.Serialization;

namespace Ryujinx.Ava.Common.Models.GitLab
{
    public class GitLabReleaseAssetJsonResponse
    {
        [JsonPropertyName("links")]
        public GitLabReleaseAssetLinkJsonResponse[] Links { get; set; }

        public class GitLabReleaseAssetLinkJsonResponse
        {
            [JsonPropertyName("id")]
            public long Id { get; set; }
            [JsonPropertyName("name")]
            public string AssetName { get; set; }
            [JsonPropertyName("url")]
            public string Url { get; set; }
        }
    }
}
