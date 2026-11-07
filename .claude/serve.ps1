$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8080/")
$listener.Start()
Write-Host "DomPlan preview: http://localhost:8080"

$types = @{
  ".html" = "text/html; charset=utf-8"
  ".css"  = "text/css; charset=utf-8"
  ".js"   = "text/javascript; charset=utf-8"
  ".png"  = "image/png"
  ".svg"  = "image/svg+xml"
  ".ico"  = "image/x-icon"
  ".json" = "application/json; charset=utf-8"
}

try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    try {
      $relative = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
      if ([string]::IsNullOrEmpty($relative)) { $relative = "index.html" }
      $path = [IO.Path]::GetFullPath((Join-Path $root $relative))
      if (-not $path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path $path -PathType Leaf)) {
        $context.Response.StatusCode = 404
        $context.Response.Close()
        continue
      }
      $ext = [IO.Path]::GetExtension($path)
      if ($types.ContainsKey($ext)) { $context.Response.ContentType = $types[$ext] }
      $bytes = [IO.File]::ReadAllBytes($path)
      $context.Response.ContentLength64 = $bytes.Length
      $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
      $context.Response.Close()
      Write-Host "$($context.Request.HttpMethod) /$relative"
    } catch {
      try { $context.Response.StatusCode = 500; $context.Response.Close() } catch {}
      Write-Warning $_
    }
  }
} finally {
  $listener.Stop()
}
