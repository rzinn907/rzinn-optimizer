#Requires -Version 5.1
<#
    Painel-PC-Fraco.ps1
    -------------------------------------------------------------
    Painel grafico (janela arrastavel, sem moldura padrao) para:
      1) Criar um Ponto de Restauracao do Windows antes de tudo
      2) Aplicar as 29 politicas de otimizacao (via Registro)
      3) Reverter as politicas aplicadas (volta para "Nao configurado")
      4) Abrir a ferramenta nativa de Restauracao do Sistema (rstrui.exe)
         caso algo saia errado e voce queira voltar tudo de vez.

    Funciona em qualquer idioma do Windows, pois usa o Registro
    diretamente (nao depende do texto do gpedit.msc).

    Requer Administrador -- o script se reabre elevado automaticamente.
#>

# ============================================================
#  AUTO-ELEVACAO (reabre como Administrador se necessario)
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
#  LISTA COMPLETA DE POLITICAS (29 itens, fieis ao PDF)
# ============================================================
$policies = @(
    # -- Telemetria e Diagnostico --
    @{ Cat='Telemetria';  Desc='Permitir Dados de Diagnostico = Desabilitado';                     Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name='AllowTelemetry'; Value=0 }
    @{ Cat='Telemetria';  Desc='Desativar Telemetria de Aplicativos = Habilitado';                 Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name='AITEnable'; Value=0 }
    @{ Cat='Telemetria';  Desc='Desativar Mecanismo de Compatibilidade de Apps = Habilitado';      Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name='DisablePcaUI'; Value=1 }
    @{ Cat='Telemetria';  Desc='Desativar Auxiliar de Compatibilidade de Programa = Habilitado';   Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name='DisablePCA'; Value=1 }
    @{ Cat='Telemetria';  Desc='Desativar Coletor de Inventario = Habilitado';                     Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name='DisableInventory'; Value=1 }
    @{ Cat='Telemetria';  Desc='Desativar Mecanismo SwitchBack = Habilitado';                      Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name='DisableEngine'; Value=1 }
    @{ Cat='Telemetria';  Desc='Desativar o Gravador de Passos = Habilitado';                      Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name='DisableUAR'; Value=1 }
    @{ Cat='Telemetria';  Desc='Desabilitar Relatorio de Erros do Windows = Habilitado';           Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'; Name='Disabled'; Value=1 }
    @{ Cat='Telemetria';  Desc='Desabilitar log do Relatorio de Erros = Habilitado';               Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'; Name='LoggingDisabled'; Value=1 }

    # -- Nuvem, Conta e Sincronizacao --
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

    # -- IA, Voz e Pesquisa --
    @{ Cat='IA/Pesquisa'; Desc='Permitir Atualizacao Automatica de Dados de Fala = Desativado';    Path='HKLM:\SOFTWARE\Policies\Microsoft\Speech'; Name='AllowSpeechModelUpdate'; Value=0 }
    @{ Cat='IA/Pesquisa'; Desc='Desabilitar Click to Do = Habilitado';                             Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name='DisableClickToDo'; Value=1 }
    @{ Cat='IA/Pesquisa'; Desc='Desabilitar pesquisa agentica de Configuracoes = Habilitado';      Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name='DisableSettingsAgenticSearch'; Value=1 }
    @{ Cat='IA/Pesquisa'; Desc='Info. compartilhadas na pesquisa = Anonimas [legado Win 8.1]';    Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name='ConnectedSearchPrivacy'; Value=3 }

    # -- Explorador de Arquivos e Menu Iniciar --
    @{ Cat='Explorer';    Desc='Desativar insights de conta/recentes/favoritos = Habilitado';      Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name='DisableGraphRecentItems'; Value=1 }
    @{ Cat='Explorer';    Desc='Nao manter historico de docs recentes (Maquina) = Habilitado';     Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name='NoRecentDocsHistory'; Value=1 }
    @{ Cat='Explorer';    Desc='Nao manter historico de docs recentes (Usuario) = Habilitado';     Path='HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name='NoRecentDocsHistory'; Value=1 }
    @{ Cat='Explorer';    Desc='Desabilitar o Quadro de Widgets = Habilitado';                     Path='HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name='AllowNewsAndInterests'; Value=0 }

    # -- Servicos, Local e Dispositivo --
    @{ Cat='Servicos';    Desc='Desativar servico Instalacao por Push = Habilitado';               Path='HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'; Name='DisablePushToInstall'; Value=1 }
    @{ Cat='Servicos';    Desc='Desativar fornecedor de local do Windows = Habilitado';            Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'; Name='DisableWindowsLocationProvider'; Value=1 }
    @{ Cat='Servicos';    Desc='Ativar/Desativar Localizar Meu Dispositivo = Desativado';           Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\FindMyDevice'; Name='LocationSyncEnabled'; Value=0 }
    @{ Cat='Servicos';    Desc='Apps acessarem movimentos em 2o plano = Forcar Negacao';            Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name='LetAppsAccessMotion'; Value=2 }
    @{ Cat='Servicos';    Desc='Apps executarem em 2o plano = Forcar Negacao';                      Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name='LetAppsRunInBackground'; Value=2 }

    # -- Store e Windows Update --
    @{ Cat='Update';      Desc='Desabilitar Download/Instalacao Automatica (Store) = Habilitado';  Path='HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'; Name='AutoDownload'; Value=2 }
    @{ Cat='Update';      Desc='Configurar Atualizacoes Automaticas = Habilitado (Notificar antes)'; Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name='NoAutoUpdate'; Value=0 }
    @{ Cat='Update';      Desc='Configurar Atualizacoes Automaticas - Opcao 2';                    Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name='AUOptions'; Value=2 }
    @{ Cat='Update';      Desc='Notificacao de atualizacao = Habilitado (so avisos de reinicio)';  Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\UX\Settings'; Name='SetUpdateNotificationLevel'; Value=1 }

    # -- Microsoft Edge --
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
    if (Test-Path $p.Path) {
        Remove-ItemProperty -Path $p.Path -Name $p.Name -ErrorAction SilentlyContinue
    }
}

function New-SystemRestorePoint {
    Enable-ComputerRestore -Drive "$($env:SystemDrive)\" -ErrorAction SilentlyContinue
    try {
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Name 'SystemRestorePointCreationFrequency' -Value 0 -Force -ErrorAction SilentlyContinue
    } catch { }
    Checkpoint-Computer -Description "Antes de Otimizar PC Fraco" -RestorePointType MODIFY_SETTINGS
}

# ============================================================
#  JANELA (PAINEL ARRASTAVEL, SEM MOLDURA)
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Otimizador de PC Fraco"
$form.FormBorderStyle = 'None'
$form.Size = New-Object System.Drawing.Size(720, 580)
$form.StartPosition = 'CenterScreen'
$form.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 24)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# --- Barra de titulo (arrastavel) ---
$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Size = New-Object System.Drawing.Size(720, 42)
$titleBar.Location = New-Object System.Drawing.Point(0, 0)
$titleBar.BackColor = [System.Drawing.Color]::FromArgb(150, 20, 20)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "  OTIMIZADOR DE PC FRACO  -  Politicas de Grupo via Registro"
$titleLabel.ForeColor = [System.Drawing.Color]::White
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$titleLabel.AutoSize = $false
$titleLabel.Size = New-Object System.Drawing.Size(620, 42)
$titleLabel.Location = New-Object System.Drawing.Point(0, 0)
$titleLabel.TextAlign = 'MiddleLeft'
$titleLabel.BackColor = [System.Drawing.Color]::Transparent

$closeBtn = New-Object System.Windows.Forms.Label
$closeBtn.Text = "X"
$closeBtn.ForeColor = [System.Drawing.Color]::White
$closeBtn.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$closeBtn.Size = New-Object System.Drawing.Size(42, 42)
$closeBtn.Location = New-Object System.Drawing.Point(678, 0)
$closeBtn.TextAlign = 'MiddleCenter'
$closeBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$closeBtn.Add_MouseEnter({ $closeBtn.BackColor = [System.Drawing.Color]::FromArgb(200, 30, 30) })
$closeBtn.Add_MouseLeave({ $closeBtn.BackColor = [System.Drawing.Color]::Transparent })
$closeBtn.Add_Click({ $form.Close() })

$titleBar.Controls.Add($titleLabel)
$titleBar.Controls.Add($closeBtn)
$form.Controls.Add($titleBar)

# --- Logica de arrastar a janela pela barra de titulo ---
$script:dragging = $false
$script:dragCursor = New-Object System.Drawing.Point
$script:dragForm   = New-Object System.Drawing.Point

$dragDown = {
    $script:dragging = $true
    $script:dragCursor = [System.Windows.Forms.Cursor]::Position
    $script:dragForm   = $form.Location
}
$dragMove = {
    if ($script:dragging) {
        $cur = [System.Windows.Forms.Cursor]::Position
        $dx = $cur.X - $script:dragCursor.X
        $dy = $cur.Y - $script:dragCursor.Y
        $form.Location = New-Object System.Drawing.Point(($script:dragForm.X + $dx), ($script:dragForm.Y + $dy))
    }
}
$dragUp = { $script:dragging = $false }

$titleBar.Add_MouseDown($dragDown)
$titleBar.Add_MouseMove($dragMove)
$titleBar.Add_MouseUp($dragUp)
$titleLabel.Add_MouseDown($dragDown)
$titleLabel.Add_MouseMove($dragMove)
$titleLabel.Add_MouseUp($dragUp)

# --- Painel de botoes ---
$panelBtns = New-Object System.Windows.Forms.Panel
$panelBtns.Location = New-Object System.Drawing.Point(20, 55)
$panelBtns.Size = New-Object System.Drawing.Size(680, 50)

function New-ActionButton {
    param($text, $x, $color)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Size = New-Object System.Drawing.Size(160, 42)
    $b.Location = New-Object System.Drawing.Point($x, 0)
    $b.BackColor = $color
    $b.ForeColor = [System.Drawing.Color]::White
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 0
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $b
}

$btnRestore     = New-ActionButton "1. Ponto de Restauracao"  0   ([System.Drawing.Color]::FromArgb(60,60,70))
$btnApply       = New-ActionButton "2. Aplicar Otimizacoes"   170 ([System.Drawing.Color]::FromArgb(30,140,70))
$btnRevert      = New-ActionButton "3. Reverter Tudo"         340 ([System.Drawing.Color]::FromArgb(170,60,40))
$btnOpenRestore = New-ActionButton "Abrir Restauracao Windows" 510 ([System.Drawing.Color]::FromArgb(60,60,70))
$btnOpenRestore.Size = New-Object System.Drawing.Size(170, 42)

$panelBtns.Controls.AddRange(@($btnRestore, $btnApply, $btnRevert, $btnOpenRestore))
$form.Controls.Add($panelBtns)

# --- Barra de progresso ---
$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(20, 115)
$progress.Size = New-Object System.Drawing.Size(680, 22)
$progress.Style = 'Continuous'
$form.Controls.Add($progress)

# --- Log (caixa de texto) ---
$rtb = New-Object System.Windows.Forms.RichTextBox
$rtb.Location = New-Object System.Drawing.Point(20, 148)
$rtb.Size = New-Object System.Drawing.Size(680, 400)
$rtb.BackColor = [System.Drawing.Color]::FromArgb(10, 10, 12)
$rtb.ForeColor = [System.Drawing.Color]::Gainsboro
$rtb.Font = New-Object System.Drawing.Font("Consolas", 9)
$rtb.ReadOnly = $true
$rtb.BorderStyle = 'None'
$form.Controls.Add($rtb)

function Write-Log {
    param([string]$Text, [System.Drawing.Color]$Color = [System.Drawing.Color]::Gainsboro)
    $rtb.SelectionStart = $rtb.TextLength
    $rtb.SelectionLength = 0
    $rtb.SelectionColor = $Color
    $rtb.AppendText("$Text`r`n")
    $rtb.ScrollToCaret()
}

Write-Log "Painel carregado. $($policies.Count) politicas disponiveis." ([System.Drawing.Color]::Yellow)
Write-Log "Recomendado: clique em '1. Ponto de Restauracao' antes de aplicar." ([System.Drawing.Color]::Gray)

# ============================================================
#  ACOES DOS BOTOES
# ============================================================
$btnRestore.Add_Click({
    $btnRestore.Enabled = $false
    Write-Log "" 
    Write-Log ">> Criando Ponto de Restauracao do Sistema..." ([System.Drawing.Color]::Cyan)
    [System.Windows.Forms.Application]::DoEvents()
    try {
        New-SystemRestorePoint
        Write-Log "Ponto de restauracao criado com sucesso!" ([System.Drawing.Color]::LightGreen)
    } catch {
        Write-Log "Falha ao criar ponto de restauracao: $($_.Exception.Message)" ([System.Drawing.Color]::OrangeRed)
        Write-Log "(Pode ser que a Protecao do Sistema esteja desativada no disco C:)" ([System.Drawing.Color]::Gray)
    }
    $btnRestore.Enabled = $true
})

$btnApply.Add_Click({
    $btnApply.Enabled = $false
    $progress.Maximum = $policies.Count
    $progress.Value = 0
    Write-Log ""
    Write-Log ">> Aplicando $($policies.Count) politicas..." ([System.Drawing.Color]::Cyan)
    foreach ($p in $policies) {
        try {
            Apply-OnePolicy -p $p
            Write-Log "[OK] $($p.Desc)" ([System.Drawing.Color]::LightGreen)
        } catch {
            Write-Log "[FALHOU] $($p.Desc) -> $($_.Exception.Message)" ([System.Drawing.Color]::OrangeRed)
        }
        $progress.Value++
        [System.Windows.Forms.Application]::DoEvents()
    }
    gpupdate /force | Out-Null
    Write-Log "Concluido! Reinicie o PC para efeito completo." ([System.Drawing.Color]::Yellow)
    $btnApply.Enabled = $true
})

$btnRevert.Add_Click({
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Isso vai remover todas as politicas aplicadas por este painel, voltando-as para 'Nao configurado'.`n`nContinuar?",
        "Confirmar Reversao",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $btnRevert.Enabled = $false
    $progress.Maximum = $policies.Count
    $progress.Value = 0
    Write-Log ""
    Write-Log ">> Revertendo $($policies.Count) politicas..." ([System.Drawing.Color]::Cyan)
    foreach ($p in $policies) {
        try {
            Revert-OnePolicy -p $p
            Write-Log "[REVERTIDO] $($p.Desc)" ([System.Drawing.Color]::Orange)
        } catch {
            Write-Log "[ERRO] $($p.Desc) -> $($_.Exception.Message)" ([System.Drawing.Color]::OrangeRed)
        }
        $progress.Value++
        [System.Windows.Forms.Application]::DoEvents()
    }
    gpupdate /force | Out-Null
    Write-Log "Reversao concluida. Reinicie o PC para efeito completo." ([System.Drawing.Color]::Yellow)
    $btnRevert.Enabled = $true
})

$btnOpenRestore.Add_Click({
    Write-Log ""
    Write-Log ">> Abrindo a Restauracao do Sistema do Windows (rstrui.exe)..." ([System.Drawing.Color]::Cyan)
    try {
        Start-Process "rstrui.exe"
    } catch {
        Write-Log "Nao foi possivel abrir: $($_.Exception.Message)" ([System.Drawing.Color]::OrangeRed)
    }
})

# ============================================================
#  EXIBIR
# ============================================================
[System.Windows.Forms.Application]::Run($form)
