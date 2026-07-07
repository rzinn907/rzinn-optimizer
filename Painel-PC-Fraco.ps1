#Requires -Version 5.1
<#
    Painel-PC-Fraco-Premium.ps1
    -------------------------------------------------------------
    Painel grafico premium (janela arredondada, arrastavel, com
    gradiente e cards) para:
      1) Criar Ponto de Restauracao do Windows (com correcao
         automatica do erro "Falha de carregamento de provedor")
      2) Aplicar 41 chaves de registro de otimizacao (24 paginas do PDF)
      3) Reverter tudo (volta para "Nao configurado")
      4) Abrir a Restauracao do Sistema nativa (rstrui.exe)

    Funciona em qualquer idioma do Windows (usa o Registro direto).
    Requer Administrador -- o script se reabre elevado automaticamente.
#>

# ============================================================
#  AUTO-ELEVACAO
# ============================================================
function Test-Admin {
    return ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains 'S-1-5-32-544')
}
if (-not (Test-Admin)) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    try { [System.Diagnostics.Process]::Start($psi) | Out-Null } catch { }
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================
#  PALETA DE CORES (tema premium escuro)
# ============================================================
$Col = @{
    BgWindow    = [System.Drawing.Color]::FromArgb(255, 16, 17, 21)
    BgSidebar   = [System.Drawing.Color]::FromArgb(255, 21, 22, 28)
    BgCard      = [System.Drawing.Color]::FromArgb(255, 27, 29, 36)
    BgCardHover = [System.Drawing.Color]::FromArgb(255, 36, 38, 48)
    BgLog       = [System.Drawing.Color]::FromArgb(255, 10, 11, 14)
    HeaderA     = [System.Drawing.Color]::FromArgb(255, 210, 45, 55)
    HeaderB     = [System.Drawing.Color]::FromArgb(255, 90, 15, 25)
    Accent      = [System.Drawing.Color]::FromArgb(255, 235, 60, 70)
    Success     = [System.Drawing.Color]::FromArgb(255, 52, 211, 153)
    Warning     = [System.Drawing.Color]::FromArgb(255, 251, 191, 36)
    TextPrimary = [System.Drawing.Color]::FromArgb(255, 245, 245, 247)
    TextMuted   = [System.Drawing.Color]::FromArgb(255, 150, 154, 165)
}

# ============================================================
#  LISTA COMPLETA DE POLITICAS (41 chaves, fieis as 24 paginas do PDF)
# ============================================================
$policies = @(
    @{ Cat='Telemetria';  Desc='Permitir Dados de Diagnostico = Desabilitado';                     Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name='AllowTelemetry'; Value=0 }
    @{ Cat='Telemetria';  Desc='Desativar Telemetria de Aplicativos = Habilitado';                 Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name='AITEnable'; Value=0 }
    @{ Cat='Telemetria';  Desc='Desativar Mecanismo de Compatibilidade de Apps = Habilitado';      Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name='DisablePcaUI'; Value=1 }
    @{ Cat='Telemetria';  Desc='Desativar Auxiliar de Compatibilidade de Programa = Habilitado';   Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name='DisablePCA'; Value=1 }
    @{ Cat='Telemetria';  Desc='Desativar Coletor de Inventario = Habilitado';                     Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name='DisableInventory'; Value=1 }
    @{ Cat='Telemetria';  Desc='Desativar Mecanismo SwitchBack = Habilitado';                      Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name='DisableEngine'; Value=1 }
    @{ Cat='Telemetria';  Desc='Desativar o Gravador de Passos = Habilitado';                      Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name='DisableUAR'; Value=1 }
    @{ Cat='Telemetria';  Desc='Desabilitar Relatorio de Erros do Windows = Habilitado';           Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'; Name='Disabled'; Value=1 }
    @{ Cat='Telemetria';  Desc='Desabilitar log do Relatorio de Erros = Habilitado';               Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'; Name='LoggingDisabled'; Value=1 }
    @{ Cat='Nuvem';       Desc='Desativar conteudo otimizado em nuvem = Habilitado';               Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableCloudOptimizedContent'; Value=1 }
    @{ Cat='Nuvem';       Desc='Desligar conteudo de conta consumidor na nuvem = Habilitado';      Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableConsumerAccountStateContent'; Value=1 }
    @{ Cat='Nuvem';       Desc='Nao mostrar dicas do Windows = Habilitado';                        Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableSoftLanding'; Value=1 }
    @{ Cat='Nuvem';       Desc='Desativar experiencias do cliente da Microsoft = Habilitado';      Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableWindowsConsumerFeatures'; Value=1 }
    @{ Cat='Nuvem';       Desc='Nao sincronizar configuracoes = Habilitado';                       Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name='DisableSettingSync'; Value=2 }
    @{ Cat='Nuvem';       Desc='Nao sincronizar - bloquear usuario = Habilitado';                  Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name='DisableSettingSyncUserOverride'; Value=1 }
    @{ Cat='Nuvem';       Desc='Desligar a ID de anuncio = Habilitado';                            Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; Name='DisabledByGroupPolicy'; Value=1 }
    @{ Cat='Nuvem';       Desc='Permitir upload de Atividades do Usuario = Desativado';            Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='UploadUserActivities'; Value=0 }
    @{ Cat='Nuvem';       Desc='Sincronizacao Area de Transferencia entre dispositivos = Desativado'; Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='AllowCrossDeviceClipboard'; Value=0 }
    @{ Cat='Nuvem';       Desc='Permitir publicacao das Atividades do Usuario = Desativado';       Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='PublishUserActivities'; Value=0 }
    @{ Cat='Nuvem';       Desc='Habilita o Feed de Atividades = Desativado';                       Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='EnableActivityFeed'; Value=0 }
    @{ Cat='IA/Pesquisa'; Desc='Permitir Atualizacao Automatica de Dados de Fala = Desativado';    Path='HKLM:\SOFTWARE\Policies\Microsoft\Speech'; Name='AllowSpeechModelUpdate'; Value=0 }
    @{ Cat='IA/Pesquisa'; Desc='Desabilitar Click to Do = Habilitado';                             Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name='DisableClickToDo'; Value=1 }
    @{ Cat='IA/Pesquisa'; Desc='Desabilitar pesquisa agentica de Configuracoes = Habilitado';      Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name='DisableSettingsAgenticSearch'; Value=1 }
    @{ Cat='IA/Pesquisa'; Desc='Info. compartilhadas na pesquisa = Anonimas [legado Win 8.1]';    Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name='ConnectedSearchPrivacy'; Value=3 }
    @{ Cat='Explorer';    Desc='Desativar insights de conta/recentes/favoritos = Habilitado';      Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name='DisableGraphRecentItems'; Value=1 }
    @{ Cat='Explorer';    Desc='Nao manter historico de docs recentes (Maquina) = Habilitado';     Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name='NoRecentDocsHistory'; Value=1 }
    @{ Cat='Explorer';    Desc='Nao manter historico de docs recentes (Usuario) = Habilitado';     Path='HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name='NoRecentDocsHistory'; Value=1 }
    @{ Cat='Explorer';    Desc='Permitir widgets = Desativado';                                    Path='HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name='AllowNewsAndInterests'; Value=0 }
    @{ Cat='Explorer';    Desc='Desabilitar Widgets na Tela de Bloqueio = Habilitado';             Path='HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name='DisableWidgetsOnLockScreen'; Value=1 }
    @{ Cat='Explorer';    Desc='Desabilitar o Quadro de Widgets = Habilitado';                     Path='HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name='DisableWidgetsBoard'; Value=1 }
    @{ Cat='Servicos';    Desc='Desativar servico Instalacao por Push = Habilitado';               Path='HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'; Name='DisablePushToInstall'; Value=1 }
    @{ Cat='Servicos';    Desc='Desativar fornecedor de local do Windows = Habilitado';            Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'; Name='DisableWindowsLocationProvider'; Value=1 }
    @{ Cat='Servicos';    Desc='Ativar/Desativar Localizar Meu Dispositivo = Desativado';           Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\FindMyDevice'; Name='LocationSyncEnabled'; Value=0 }
    @{ Cat='Servicos';    Desc='Apps acessarem movimentos em 2o plano = Forcar Negacao';            Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name='LetAppsAccessMotion'; Value=2 }
    @{ Cat='Servicos';    Desc='Apps executarem em 2o plano = Forcar Negacao';                      Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name='LetAppsRunInBackground'; Value=2 }
    @{ Cat='Update';      Desc='Desabilitar Download/Instalacao Automatica (Store) = Habilitado';  Path='HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'; Name='AutoDownload'; Value=2 }
    @{ Cat='Update';      Desc='Configurar Atualizacoes Automaticas = Habilitado (Notificar antes)'; Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name='NoAutoUpdate'; Value=0 }
    @{ Cat='Update';      Desc='Configurar Atualizacoes Automaticas - Opcao 2';                    Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name='AUOptions'; Value=2 }
    @{ Cat='Update';      Desc='Notificacao de atualizacao = Habilitado (so avisos de reinicio)';  Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\UX\Settings'; Name='SetUpdateNotificationLevel'; Value=1 }
    @{ Cat='Edge';        Desc='Permitir Edge iniciar/carregar pagina na inicializacao = Habilitado'; Path='HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name='StartupBoostEnabled'; Value=1 }
    @{ Cat='Edge';        Desc='Permitir pre-inicializacao do Edge = Habilitado';                  Path='HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name='Preload'; Value=1 }
)

# ============================================================
#  FUNCOES DE APLICAR / REVERTER / RESTAURACAO
# ============================================================
function Apply-OnePolicy {
    param($p)
    if (-not (Test-Path $p.Path)) { New-Item -Path $p.Path -Force | Out-Null }
    New-ItemProperty -Path $p.Path -Name $p.Name -Value $p.Value -PropertyType DWord -Force | Out-Null
}

function Revert-OnePolicy {
    param($p)
    if (Test-Path $p.Path) { Remove-ItemProperty -Path $p.Path -Name $p.Name -ErrorAction SilentlyContinue }
}

# Corrige o erro classico "Falha de carregamento de provedor" do Checkpoint-Computer:
# ele depende dos servicos VSS (Copia de Sombra de Volume) e swprv (Provedor de
# Copia de Sombra de Software da Microsoft) estarem em execucao.
function New-SystemRestorePoint {
    param([scriptblock]$Log)

    & $Log "Habilitando Protecao do Sistema na unidade $($env:SystemDrive)..." 'info'
    try { Enable-ComputerRestore -Drive "$($env:SystemDrive)\" -ErrorAction SilentlyContinue } catch { }

    try {
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' `
            -Name 'SystemRestorePointCreationFrequency' -Value 0 -Force -ErrorAction SilentlyContinue
    } catch { }

    & $Log "Iniciando servicos necessarios (VSS e Provedor de Sombra)..." 'info'
    foreach ($svc in @('VSS', 'swprv')) {
        try {
            $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($s -and $s.Status -ne 'Running') { Start-Service -Name $svc -ErrorAction SilentlyContinue }
        } catch { }
    }
    Start-Sleep -Seconds 2

    $tentativas = 0
    $ultimoErro = $null
    while ($tentativas -lt 2) {
        $tentativas++
        try {
            Checkpoint-Computer -Description "Antes de Otimizar PC Fraco" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
            return $true
        } catch {
            $ultimoErro = $_
            & $Log "Tentativa $tentativas falhou, tentando novamente..." 'warn'
            Start-Sleep -Seconds 3
        }
    }

    throw $ultimoErro
}

# ============================================================
#  HELPERS VISUAIS (cantos arredondados, gradiente, etc.)
# ============================================================
function Get-RoundedPath {
    param([System.Drawing.Rectangle]$Rect, [int]$Radius)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $Radius * 2
    if ($d -gt $Rect.Width)  { $d = $Rect.Width }
    if ($d -gt $Rect.Height) { $d = $Rect.Height }
    $path.AddArc($Rect.X, $Rect.Y, $d, $d, 180, 90)
    $path.AddArc($Rect.Right - $d, $Rect.Y, $d, $d, 270, 90)
    $path.AddArc($Rect.Right - $d, $Rect.Bottom - $d, $d, $d, 0, 90)
    $path.AddArc($Rect.X, $Rect.Bottom - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function Set-RoundedRegion {
    param($Control, [int]$Radius)
    $rect = New-Object System.Drawing.Rectangle(0, 0, $Control.Width, $Control.Height)
    $Control.Region = New-Object System.Drawing.Region((Get-RoundedPath -Rect $rect -Radius $Radius))
}

# ============================================================
#  JANELA PRINCIPAL
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Otimizador de PC Fraco - Premium"
$form.FormBorderStyle = 'None'
$form.Size = New-Object System.Drawing.Size(880, 620)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $Col.BgWindow
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Add_Shown({ Set-RoundedRegion -Control $form -Radius 22 })
$form.Add_Resize({ Set-RoundedRegion -Control $form -Radius 22 })

# Borda fina ao redor de tudo
$borderPanel = New-Object System.Windows.Forms.Panel
$borderPanel.Dock = 'Fill'
$borderPanel.BackColor = [System.Drawing.Color]::FromArgb(255, 45, 46, 54)
$form.Controls.Add($borderPanel)

$innerRoot = New-Object System.Windows.Forms.Panel
$innerRoot.Location = New-Object System.Drawing.Point(1,1)
$innerRoot.Size = New-Object System.Drawing.Size(($form.Width-2), ($form.Height-2))
$innerRoot.BackColor = $Col.BgWindow
$borderPanel.Controls.Add($innerRoot)

# --- HEADER com gradiente ---
$header = New-Object System.Windows.Forms.Panel
$header.Size = New-Object System.Drawing.Size($innerRoot.Width, 74)
$header.Location = New-Object System.Drawing.Point(0,0)
$header.Add_Paint({
    param($s,$e)
    $rect = $s.ClientRectangle
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $Col.HeaderA, $Col.HeaderB, 0.0)
    $e.Graphics.FillRectangle($brush, $rect)
})
$innerRoot.Controls.Add($header)

# Badge com icone
$badge = New-Object System.Windows.Forms.Label
$badge.Text = [char]0x2699  # engrenagem
$badge.Font = New-Object System.Drawing.Font("Segoe UI Symbol", 20)
$badge.ForeColor = [System.Drawing.Color]::White
$badge.Size = New-Object System.Drawing.Size(50,50)
$badge.Location = New-Object System.Drawing.Point(18,12)
$badge.TextAlign = 'MiddleCenter'
$badge.BackColor = [System.Drawing.Color]::FromArgb(70,0,0,0)
$header.Controls.Add($badge)
$badge.Add_Paint({
    param($s,$e)
    $e.Graphics.SmoothingMode = 'AntiAlias'
    $rect = New-Object System.Drawing.Rectangle(0,0,($s.Width-1),($s.Height-1))
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60,255,255,255))
    $e.Graphics.FillEllipse($brush, $rect)
})

$titleLbl = New-Object System.Windows.Forms.Label
$titleLbl.Text = "OTIMIZADOR DE PC FRACO"
$titleLbl.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$titleLbl.ForeColor = [System.Drawing.Color]::White
$titleLbl.AutoSize = $false
$titleLbl.Size = New-Object System.Drawing.Size(500, 26)
$titleLbl.Location = New-Object System.Drawing.Point(80, 14)
$titleLbl.BackColor = [System.Drawing.Color]::Transparent
$header.Controls.Add($titleLbl)

$subtitleLbl = New-Object System.Windows.Forms.Label
$subtitleLbl.Text = "Painel de Politicas de Grupo via Registro  -  41 otimizacoes"
$subtitleLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$subtitleLbl.ForeColor = [System.Drawing.Color]::FromArgb(230,230,230)
$subtitleLbl.AutoSize = $false
$subtitleLbl.Size = New-Object System.Drawing.Size(500, 20)
$subtitleLbl.Location = New-Object System.Drawing.Point(80, 40)
$subtitleLbl.BackColor = [System.Drawing.Color]::Transparent
$header.Controls.Add($subtitleLbl)

# Botoes minimizar / fechar
function New-CapButton {
    param($text, $x)
    $b = New-Object System.Windows.Forms.Label
    $b.Text = $text
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $b.ForeColor = [System.Drawing.Color]::White
    $b.Size = New-Object System.Drawing.Size(44, 74)
    $b.Location = New-Object System.Drawing.Point($x, 0)
    $b.TextAlign = 'MiddleCenter'
    $b.BackColor = [System.Drawing.Color]::Transparent
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.Add_MouseEnter({ $b.BackColor = [System.Drawing.Color]::FromArgb(70,0,0,0) })
    $b.Add_MouseLeave({ $b.BackColor = [System.Drawing.Color]::Transparent })
    return $b
}
$closeBtn = New-CapButton ([char]0x2715) ($innerRoot.Width - 46)
$minBtn   = New-CapButton ([char]0x2212) ($innerRoot.Width - 90)
$closeBtn.Add_Click({ $form.Close() })
$minBtn.Add_Click({ $form.WindowState = 'Minimized' })
$header.Controls.Add($closeBtn)
$header.Controls.Add($minBtn)

# --- Arrastar pela barra de titulo ---
$script:dragging = $false
$script:dragCursor = New-Object System.Drawing.Point
$script:dragForm   = New-Object System.Drawing.Point
$dragDown = { $script:dragging = $true; $script:dragCursor = [System.Windows.Forms.Cursor]::Position; $script:dragForm = $form.Location }
$dragMove = {
    if ($script:dragging) {
        $cur = [System.Windows.Forms.Cursor]::Position
        $form.Location = New-Object System.Drawing.Point(($script:dragForm.X + $cur.X - $script:dragCursor.X), ($script:dragForm.Y + $cur.Y - $script:dragCursor.Y))
    }
}
$dragUp = { $script:dragging = $false }
foreach ($ctrl in @($header, $titleLbl, $subtitleLbl, $badge)) {
    $ctrl.Add_MouseDown($dragDown); $ctrl.Add_MouseMove($dragMove); $ctrl.Add_MouseUp($dragUp)
}

# --- SIDEBAR ---
$sidebar = New-Object System.Windows.Forms.Panel
$sidebar.Size = New-Object System.Drawing.Size(250, ($innerRoot.Height - 74 - 30))
$sidebar.Location = New-Object System.Drawing.Point(0, 74)
$sidebar.BackColor = $Col.BgSidebar
$innerRoot.Controls.Add($sidebar)

function New-NavCard {
    param([string]$Icon, [string]$Title, [string]$Subtitle, [int]$Y, [System.Drawing.Color]$Accent, [scriptblock]$Action)

    $card = New-Object System.Windows.Forms.Panel
    $card.Size = New-Object System.Drawing.Size(222, 78)
    $card.Location = New-Object System.Drawing.Point(14, $Y)
    $card.BackColor = $Col.BgCard
    $card.Cursor = [System.Windows.Forms.Cursors]::Hand

    $stripe = New-Object System.Windows.Forms.Panel
    $stripe.Size = New-Object System.Drawing.Size(4, 78)
    $stripe.Location = New-Object System.Drawing.Point(0,0)
    $stripe.BackColor = $Accent
    $card.Controls.Add($stripe)

    $iconLbl = New-Object System.Windows.Forms.Label
    $iconLbl.Text = $Icon
    $iconLbl.Font = New-Object System.Drawing.Font("Segoe UI Symbol", 18)
    $iconLbl.ForeColor = $Accent
    $iconLbl.Size = New-Object System.Drawing.Size(46, 46)
    $iconLbl.Location = New-Object System.Drawing.Point(14, 16)
    $iconLbl.TextAlign = 'MiddleCenter'
    $iconLbl.BackColor = [System.Drawing.Color]::Transparent
    $card.Controls.Add($iconLbl)

    $tLbl = New-Object System.Windows.Forms.Label
    $tLbl.Text = $Title
    $tLbl.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $tLbl.ForeColor = $Col.TextPrimary
    $tLbl.Size = New-Object System.Drawing.Size(155, 20)
    $tLbl.Location = New-Object System.Drawing.Point(66, 14)
    $tLbl.BackColor = [System.Drawing.Color]::Transparent
    $card.Controls.Add($tLbl)

    $sLbl = New-Object System.Windows.Forms.Label
    $sLbl.Text = $Subtitle
    $sLbl.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $sLbl.ForeColor = $Col.TextMuted
    $sLbl.Size = New-Object System.Drawing.Size(150, 40)
    $sLbl.Location = New-Object System.Drawing.Point(66, 34)
    $sLbl.BackColor = [System.Drawing.Color]::Transparent
    $card.Controls.Add($sLbl)

    $hoverIn  = { $card.BackColor = $Col.BgCardHover; $iconLbl.BackColor = [System.Drawing.Color]::Transparent }
    $hoverOut = { $card.BackColor = $Col.BgCard }
    foreach ($c in @($card, $iconLbl, $tLbl, $sLbl)) {
        $c.Add_MouseEnter($hoverIn)
        $c.Add_MouseLeave($hoverOut)
        $c.Add_Click($Action)
    }

    return $card
}

$sidebar.Controls.Add((New-NavCard -Icon ([char]0x1F4BE) -Title "1. Ponto de Restauracao" -Subtitle "Cria um checkpoint do Windows antes de tudo" -Y 20  -Accent $Col.TextMuted -Action { Invoke-CreateRestore }))
$sidebar.Controls.Add((New-NavCard -Icon ([char]0x2713)  -Title "2. Aplicar Otimizacoes"  -Subtitle "Aplica as 41 chaves de registro"           -Y 106 -Accent $Col.Success   -Action { Invoke-ApplyPolicies }))
$sidebar.Controls.Add((New-NavCard -Icon ([char]0x21BA)  -Title "3. Reverter Tudo"        -Subtitle "Volta tudo para 'Nao configurado'"          -Y 192 -Accent $Col.Accent    -Action { Invoke-RevertPolicies }))
$sidebar.Controls.Add((New-NavCard -Icon ([char]0x2699)  -Title "Restauracao do Windows"  -Subtitle "Abre a ferramenta nativa (rstrui.exe)"       -Y 278 -Accent $Col.TextMuted -Action { Invoke-OpenRestore }))

# --- AREA PRINCIPAL (progresso + log) ---
$mainArea = New-Object System.Windows.Forms.Panel
$mainArea.Size = New-Object System.Drawing.Size(($innerRoot.Width - 250), ($innerRoot.Height - 74 - 30))
$mainArea.Location = New-Object System.Drawing.Point(250, 74)
$mainArea.BackColor = $Col.BgWindow
$innerRoot.Controls.Add($mainArea)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Pronto."
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblStatus.ForeColor = $Col.TextMuted
$lblStatus.Size = New-Object System.Drawing.Size(500, 20)
$lblStatus.Location = New-Object System.Drawing.Point(20, 16)
$mainArea.Controls.Add($lblStatus)

# Barra de progresso customizada (arredondada)
$progressTrack = New-Object System.Windows.Forms.Panel
$progressTrack.Size = New-Object System.Drawing.Size(($mainArea.Width - 40), 10)
$progressTrack.Location = New-Object System.Drawing.Point(20, 40)
$progressTrack.BackColor = [System.Drawing.Color]::FromArgb(255, 40, 41, 48)
$mainArea.Controls.Add($progressTrack)
$progressTrack.Add_Paint({ param($s,$e) Set-RoundedRegion -Control $s -Radius 5 })

$progressFill = New-Object System.Windows.Forms.Panel
$progressFill.Size = New-Object System.Drawing.Size(4, 10)
$progressFill.Location = New-Object System.Drawing.Point(0,0)
$progressFill.BackColor = $Col.Accent
$progressTrack.Controls.Add($progressFill)

function Set-Progress {
    param([int]$Percent, [string]$Status)
    $w = [int]($progressTrack.Width * ($Percent / 100.0))
    if ($w -lt 4) { $w = 4 }
    $progressFill.Width = $w
    Set-RoundedRegion -Control $progressFill -Radius 5
    if ($Status) { $lblStatus.Text = $Status }
    [System.Windows.Forms.Application]::DoEvents()
}

# Card do log
$logCard = New-Object System.Windows.Forms.Panel
$logCard.Size = New-Object System.Drawing.Size(($mainArea.Width - 40), ($mainArea.Height - 70))
$logCard.Location = New-Object System.Drawing.Point(20, 62)
$logCard.BackColor = $Col.BgLog
$mainArea.Controls.Add($logCard)

$rtb = New-Object System.Windows.Forms.RichTextBox
$rtb.Location = New-Object System.Drawing.Point(10,10)
$rtb.Size = New-Object System.Drawing.Size(($logCard.Width - 20), ($logCard.Height - 20))
$rtb.BackColor = $Col.BgLog
$rtb.ForeColor = $Col.TextPrimary
$rtb.Font = New-Object System.Drawing.Font("Consolas", 9)
$rtb.ReadOnly = $true
$rtb.BorderStyle = 'None'
$logCard.Controls.Add($rtb)

function Write-Log {
    param([string]$Text, [string]$Kind = 'info')
    $color = switch ($Kind) {
        'ok'    { $Col.Success }
        'warn'  { $Col.Warning }
        'error' { $Col.Accent }
        'info'  { $Col.TextMuted }
        default { $Col.TextPrimary }
    }
    $rtb.SelectionStart = $rtb.TextLength
    $rtb.SelectionLength = 0
    $rtb.SelectionColor = $color
    $rtb.AppendText("$Text`r`n")
    $rtb.ScrollToCaret()
}

# --- FOOTER ---
$footer = New-Object System.Windows.Forms.Panel
$footer.Size = New-Object System.Drawing.Size($innerRoot.Width, 30)
$footer.Location = New-Object System.Drawing.Point(0, ($innerRoot.Height - 30))
$footer.BackColor = $Col.BgSidebar
$innerRoot.Controls.Add($footer)

$footerLbl = New-Object System.Windows.Forms.Label
$footerLbl.Text = "Feito para deixar seu PC voando"
$footerLbl.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$footerLbl.ForeColor = $Col.TextMuted
$footerLbl.Size = New-Object System.Drawing.Size(300, 20)
$footerLbl.Location = New-Object System.Drawing.Point(20, 5)
$footer.Controls.Add($footerLbl)

$verLbl = New-Object System.Windows.Forms.Label
$verLbl.Text = "v2.0 PREMIUM"
$verLbl.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$verLbl.ForeColor = $Col.Accent
$verLbl.Size = New-Object System.Drawing.Size(150, 20)
$verLbl.Location = New-Object System.Drawing.Point(($innerRoot.Width - 170), 5)
$verLbl.TextAlign = 'MiddleRight'
$footer.Controls.Add($verLbl)

Write-Log "Painel carregado. $($policies.Count) chaves de registro disponiveis." 'info'
Write-Log "Recomendado: clique em '1. Ponto de Restauracao' antes de aplicar." 'warn'

# ============================================================
#  ACOES
# ============================================================
function Invoke-CreateRestore {
    Set-Progress 0 "Criando ponto de restauracao..."
    Write-Log ""
    Write-Log ">> Criando Ponto de Restauracao do Sistema..." 'info'
    try {
        New-SystemRestorePoint -Log { param($t,$k) Write-Log $t $k }
        Write-Log "Ponto de restauracao criado com sucesso!" 'ok'
        Set-Progress 100 "Ponto de restauracao criado."
    } catch {
        Write-Log "Falha ao criar ponto de restauracao: $($_.Exception.Message)" 'error'
        Write-Log "Abrindo a ferramenta nativa do Windows para voce criar manualmente..." 'warn'
        try { Start-Process "systempropertiesprotection.exe" } catch { }
        Set-Progress 0 "Falha - use a ferramenta nativa."
    }
}

function Invoke-ApplyPolicies {
    Set-Progress 0 "Aplicando..."
    Write-Log ""
    Write-Log ">> Aplicando $($policies.Count) chaves de registro..." 'info'
    $i = 0
    foreach ($p in $policies) {
        $i++
        try {
            Apply-OnePolicy -p $p
            Write-Log "[OK] $($p.Desc)" 'ok'
        } catch {
            Write-Log "[FALHOU] $($p.Desc) -> $($_.Exception.Message)" 'error'
        }
        Set-Progress ([int](($i/$policies.Count)*100)) "Aplicando $i de $($policies.Count)..."
    }
    gpupdate /force | Out-Null
    Write-Log "Concluido! Reinicie o PC para efeito completo." 'warn'
    Set-Progress 100 "Concluido."
}

function Invoke-RevertPolicies {
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Isso vai remover todas as politicas aplicadas por este painel, voltando para 'Nao configurado'.`n`nContinuar?",
        "Confirmar Reversao", 'YesNo', 'Warning')
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    Set-Progress 0 "Revertendo..."
    Write-Log ""
    Write-Log ">> Revertendo $($policies.Count) chaves..." 'info'
    $i = 0
    foreach ($p in $policies) {
        $i++
        try {
            Revert-OnePolicy -p $p
            Write-Log "[REVERTIDO] $($p.Desc)" 'warn'
        } catch {
            Write-Log "[ERRO] $($p.Desc) -> $($_.Exception.Message)" 'error'
        }
        Set-Progress ([int](($i/$policies.Count)*100)) "Revertendo $i de $($policies.Count)..."
    }
    gpupdate /force | Out-Null
    Write-Log "Reversao concluida. Reinicie o PC para efeito completo." 'warn'
    Set-Progress 100 "Reversao concluida."
}

function Invoke-OpenRestore {
    Write-Log ""
    Write-Log ">> Abrindo a Restauracao do Sistema do Windows..." 'info'
    try { Start-Process "rstrui.exe" } catch { Write-Log "Nao foi possivel abrir: $($_.Exception.Message)" 'error' }
}

# ============================================================
#  EXIBIR
# ============================================================
[System.Windows.Forms.Application]::Run($form)
