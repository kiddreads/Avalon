using System.Text.Json.Serialization;

namespace Ryujinx.Ava.Common.Models.GitLab
{
    public class GitLabReleasesJsonResponse
    {
        [JsonPropertyName("name")]
        public string Name { get; set; }
        
        [JsonPropertyName("tag_name")]
        public string TagName { get; set; }
        
        [JsonPropertyName("assets")]
        public GitLabReleaseAssetJsonResponse Assets { get; set; }
    }
    
    [JsonSerializable(typeof(GitLabReleasesJsonResponse), GenerationMode = JsonSourceGenerationMode.Metadata)]
    public partial class GitLabReleasesJsonSerializerContext : JsonSerializerContext;
}
