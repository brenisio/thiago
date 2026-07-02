# Servidor local do Board Nulla (PowerShell puro — não precisa instalar nada).
# Serve o index.html e salva/le o estado em banco.json na mesma pasta.
# Encerrar: feche esta janela.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$port = 8791
$statePath = Join-Path $root "banco.json"

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
try {
  $listener.Start()
} catch {
  Write-Host ""
  Write-Host "Nao consegui abrir a porta $port."
  Write-Host "Provavelmente o Board ja esta aberto em outra janela. Feche-a e tente de novo."
  Read-Host "Pressione Enter para sair"
  exit 1
}

Start-Process "http://localhost:$port/index.html"
Write-Host ""
Write-Host "  Board Nulla rodando em  http://localhost:$port/"
Write-Host "  (mantenha esta janela aberta enquanto usar; feche-a para encerrar)"
Write-Host ""

$mime = @{
  ".html" = "text/html; charset=utf-8"
  ".js"   = "application/javascript; charset=utf-8"
  ".json" = "application/json; charset=utf-8"
  ".css"  = "text/css; charset=utf-8"
  ".xlsx" = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$rootFull  = [System.IO.Path]::GetFullPath($root)

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $req = $ctx.Request
  $res = $ctx.Response
  try {
    $path = $req.Url.AbsolutePath

    if ($path -eq "/api/state" -and $req.HttpMethod -eq "GET") {
      # devolve o banco.json (ou {} se ainda nao existe)
      if (Test-Path $statePath) { $bytes = [System.IO.File]::ReadAllBytes($statePath) }
      else { $bytes = [System.Text.Encoding]::UTF8.GetBytes("{}") }
      $res.ContentType = "application/json; charset=utf-8"
      $res.OutputStream.Write($bytes, 0, $bytes.Length)
    }
    elseif ($path -eq "/api/state" -and $req.HttpMethod -eq "POST") {
      # grava o estado enviado pelo navegador
      $reader = New-Object System.IO.StreamReader($req.InputStream, $req.ContentEncoding)
      $body = $reader.ReadToEnd()
      $reader.Close()
      [System.IO.File]::WriteAllText($statePath, $body, $utf8NoBom)
      $res.StatusCode = 204
    }
    else {
      # arquivos estaticos (index.html, xlsx.full.min.js, etc.)
      if ($path -eq "/") { $path = "/index.html" }
      $rel  = $path.TrimStart("/")
      $full = [System.IO.Path]::GetFullPath((Join-Path $root $rel))
      if (-not $full.StartsWith($rootFull)) {        # bloqueia path traversal
        $res.StatusCode = 403
      } elseif (Test-Path $full -PathType Leaf) {
        $ext = [System.IO.Path]::GetExtension($full).ToLower()
        if ($mime.ContainsKey($ext)) { $res.ContentType = $mime[$ext] }
        $bytes = [System.IO.File]::ReadAllBytes($full)
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
      } else {
        $res.StatusCode = 404
      }
    }
  } catch {
    try { $res.StatusCode = 500 } catch {}
  } finally {
    $res.Close()
  }
}
