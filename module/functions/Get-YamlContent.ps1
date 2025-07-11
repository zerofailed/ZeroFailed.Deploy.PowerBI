function Get-YamlContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    try {
        $content = Get-Content -Path $Path -Raw
        $yaml = ConvertFrom-Yaml $content
        return $yaml
    }
    catch {
        throw "Error processing YAML file '$Path': $_"
    }
}