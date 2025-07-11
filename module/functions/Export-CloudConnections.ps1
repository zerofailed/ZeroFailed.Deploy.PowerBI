function Export-CloudConnections {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        
        [Parameter()]
        [string]$OutputPath
    )

    $connections = Resolve-CloudConnections -ConfigPath $ConfigPath

    if ($OutputPath) {
        $connections | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath
    }
    else {
        return $connections
    }
}