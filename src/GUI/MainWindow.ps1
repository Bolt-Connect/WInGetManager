#Requires -Version 5.1

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

$ScriptRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
Import-Module "$ScriptRoot\src\Core\Logging.psm1"      -Force
Import-Module "$ScriptRoot\src\Core\Config.psm1"       -Force
Import-Module "$ScriptRoot\src\Core\I18n.psm1"         -Force
Import-Module "$ScriptRoot\src\Core\WinGet-Core.psm1"  -Force

$cfg = Get-AppConfig
try {
    $lang = if ($cfg.Language) { $cfg.Language } else { 'auto' }
    Initialize-I18n -Language $lang
} catch {}
Initialize-Logging -LogDirectory (Join-Path $ScriptRoot $cfg.LogDirectory) `
                   -MinLevel $cfg.LogLevel `
                   -RetentionDays $cfg.LogRetentionDays `
                   -MaxSizeMB $cfg.MaxLogFileSizeMB

try {
    Initialize-WinGetCore -WinGetPath $cfg.WinGetPath
} catch {
    # winget/App Installer is missing. Instead of a dead-end error, offer to open
    # the Microsoft Store so the user can install it in one click.
    $answer = [System.Windows.MessageBox]::Show(
        (Get-Text 'Dialog.WinGetMissingPrompt'),
        (Get-Text 'Status.WinGetMissing'),
        'YesNo', 'Warning')
    if ($answer -eq 'Yes') {
        # ms-windows-store:// opens the Store app directly; fall back to the web page.
        try { Start-Process 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1' }
        catch { try { Start-Process 'https://apps.microsoft.com/detail/9nblggh4nns1' } catch {} }
    }
    exit 1
}

# ---------------------------------------------------------------------------
# Observable log collection (gedeeld met Logging module)
# ---------------------------------------------------------------------------

$LogCollection = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
Set-LogObservable $LogCollection

# ---------------------------------------------------------------------------
# XAML definitie
# ---------------------------------------------------------------------------
# Theme palettes
# ---------------------------------------------------------------------------

$Script:Themes = @{
    Dark = @{
        BgPrimary    = '#1A1B26'   # iets dieper
        BgSecondary  = '#24283B'
        BgCard       = '#2F3349'   # iets lichter voor contrast
        BorderColor  = '#3B4261'
        TextMuted    = '#7A88B0'   # iets helderder zodat muted-text leesbaar blijft
        TextPrimary  = '#E5E9F0'   # crispier wit
        AccentBlue   = '#4FA3FF'   # vivid blauw
        AccentGreen  = '#4ADE80'   # vivid groen
        AccentRed    = '#FF6B7A'   # vivid rood
        AccentYellow = '#FFD23F'   # vivid geel
        ErrorBg      = '#3F1820'
        WarnBg       = '#3F310B'
    }
    Light = @{
        BgPrimary    = '#F3F3F3'
        BgSecondary  = '#FFFFFF'
        BgCard       = '#FAFAFA'
        BorderColor  = '#D0D0D0'
        TextMuted    = '#707070'
        TextPrimary  = '#1F1F1F'
        AccentBlue   = '#0078D4'
        AccentGreen  = '#107C10'
        AccentRed    = '#C50F1F'
        AccentYellow = '#9A6700'
        ErrorBg      = '#FDE7E9'
        WarnBg       = '#FFF8C5'
    }
}

function Get-WindowsTheme {
    try {
        $val = Get-ItemPropertyValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -ErrorAction Stop
        if ($val -eq 1) { return 'Light' } else { return 'Dark' }
    } catch { return 'Dark' }
}

function Resolve-ActiveTheme {
    param([string]$Preference)
    if ($Preference -eq 'Auto' -or -not $Preference) { return Get-WindowsTheme }
    if ($Script:Themes.ContainsKey($Preference)) { return $Preference }
    return 'Dark'
}

function Apply-ThemeColors {
    param([string]$xamlText, [string]$ThemeName)
    $colors = $Script:Themes[$ThemeName]
    # Mapping van dark-palette hexcodes (zoals in XAML) naar nieuwe waarden
    $map = @{
        '#1E1E2E' = $colors.BgPrimary
        '#2A2A3E' = $colors.BgSecondary
        '#313149' = $colors.BgCard
        '#45475A' = $colors.BorderColor
        '#6C7086' = $colors.TextMuted
        '#CDD6F4' = $colors.TextPrimary
        '#89B4FA' = $colors.AccentBlue
        '#A6E3A1' = $colors.AccentGreen
        '#F38BA8' = $colors.AccentRed
        '#F9E2AF' = $colors.AccentYellow
        '#3D1A1F' = $colors.ErrorBg
        '#3D320A' = $colors.WarnBg
    }
    foreach ($from in $map.Keys) { $xamlText = $xamlText.Replace($from, $map[$from]) }
    return $xamlText
}

# ---------------------------------------------------------------------------

$ActiveTheme = Resolve-ActiveTheme -Preference $cfg.Theme

[xml]$Xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WinGet Manager" Height="750" Width="1200"
        MinHeight="600" MinWidth="900"
        WindowStartupLocation="CenterScreen"
        Background="#1E1E2E">
    <Window.Resources>
        <!-- Kleuren -->
        <SolidColorBrush x:Key="BgPrimary"    Color="#1E1E2E"/>
        <SolidColorBrush x:Key="BgSecondary"  Color="#2A2A3E"/>
        <SolidColorBrush x:Key="BgCard"       Color="#313149"/>
        <SolidColorBrush x:Key="AccentBlue"   Color="#89B4FA"/>
        <SolidColorBrush x:Key="AccentGreen"  Color="#A6E3A1"/>
        <SolidColorBrush x:Key="AccentRed"    Color="#F38BA8"/>
        <SolidColorBrush x:Key="AccentYellow" Color="#F9E2AF"/>
        <SolidColorBrush x:Key="TextPrimary"  Color="#CDD6F4"/>
        <SolidColorBrush x:Key="TextMuted"    Color="#6C7086"/>
        <SolidColorBrush x:Key="BorderColor"  Color="#45475A"/>

        <!-- Button basis stijl -->
        <Style x:Key="BtnBase" TargetType="Button">
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="16,8"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" CornerRadius="6"
                                Background="{TemplateBinding Background}"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Opacity" Value="0.85"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Opacity" Value="0.7"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Opacity" Value="0.4"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="BtnBlue"   BasedOn="{StaticResource BtnBase}" TargetType="Button">
            <Setter Property="Background" Value="#89B4FA"/>
            <Setter Property="Foreground" Value="#1E1E2E"/>
        </Style>
        <Style x:Key="BtnGreen"  BasedOn="{StaticResource BtnBase}" TargetType="Button">
            <Setter Property="Background" Value="#A6E3A1"/>
            <Setter Property="Foreground" Value="#1E1E2E"/>
        </Style>
        <Style x:Key="BtnRed"    BasedOn="{StaticResource BtnBase}" TargetType="Button">
            <Setter Property="Background" Value="#F38BA8"/>
            <Setter Property="Foreground" Value="#1E1E2E"/>
        </Style>
        <Style x:Key="BtnYellow" BasedOn="{StaticResource BtnBase}" TargetType="Button">
            <Setter Property="Background" Value="#F9E2AF"/>
            <Setter Property="Foreground" Value="#1E1E2E"/>
        </Style>
        <Style x:Key="BtnGhost"  BasedOn="{StaticResource BtnBase}" TargetType="Button">
            <Setter Property="Background" Value="#313149"/>
            <Setter Property="Foreground" Value="#CDD6F4"/>
        </Style>

        <!-- TextBox -->
        <Style TargetType="TextBox">
            <Setter Property="Background"    Value="#313149"/>
            <Setter Property="Foreground"    Value="#CDD6F4"/>
            <Setter Property="CaretBrush"    Value="#89B4FA"/>
            <Setter Property="BorderBrush"   Value="#45475A"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding"       Value="14,9"/>
            <Setter Property="FontSize"      Value="13"/>
            <Setter Property="MinHeight"     Value="38"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6">
                            <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- DataGrid (clean, geen borders, subtiele row-separator) -->
        <Style TargetType="DataGrid">
            <Setter Property="Background"               Value="Transparent"/>
            <Setter Property="Foreground"               Value="#CDD6F4"/>
            <Setter Property="BorderThickness"          Value="0"/>
            <Setter Property="RowBackground"            Value="Transparent"/>
            <Setter Property="AlternatingRowBackground" Value="Transparent"/>
            <Setter Property="HorizontalGridLinesBrush" Value="#45475A"/>
            <Setter Property="GridLinesVisibility"      Value="Horizontal"/>
            <Setter Property="SelectionMode"            Value="Extended"/>
            <Setter Property="CanUserResizeRows"        Value="False"/>
            <Setter Property="AutoGenerateColumns"      Value="False"/>
            <Setter Property="HeadersVisibility"        Value="Column"/>
        </Style>
        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Background"     Value="Transparent"/>
            <Setter Property="Foreground"     Value="#6C7086"/>
            <Setter Property="FontWeight"     Value="SemiBold"/>
            <Setter Property="FontSize"       Value="11"/>
            <Setter Property="Padding"        Value="10,10"/>
            <Setter Property="BorderBrush"    Value="#45475A"/>
            <Setter Property="BorderThickness" Value="0,0,0,1"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
        </Style>
        <Style TargetType="DataGridRow">
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="MinHeight"  Value="38"/>
            <Style.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#45475A"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="DataGridCell">
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="DataGridCell">
                        <Border Background="{TemplateBinding Background}"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Tab (minimal, geen kaders/achtergrond — alleen onderstreping bij actief) -->
        <Style TargetType="TabControl">
            <Setter Property="Background"      Value="Transparent"/>
            <Setter Property="BorderBrush"     Value="#45475A"/>
            <Setter Property="BorderThickness" Value="0,0,0,1"/>
            <Setter Property="Padding"         Value="0"/>
        </Style>
        <Style TargetType="TabItem">
            <Setter Property="Background"   Value="Transparent"/>
            <Setter Property="Foreground"   Value="#6C7086"/>
            <Setter Property="FontSize"     Value="13"/>
            <Setter Property="Padding"      Value="20,12"/>
            <Setter Property="BorderBrush"  Value="Transparent"/>
            <Setter Property="Margin"       Value="0,0,4,-1"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border x:Name="border" Background="Transparent"
                                BorderBrush="Transparent"
                                BorderThickness="0,0,0,2" Padding="{TemplateBinding Padding}">
                            <ContentPresenter x:Name="content"
                                ContentSource="Header"
                                HorizontalAlignment="Center"
                                VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="border"  Property="BorderBrush" Value="#89B4FA"/>
                                <Setter TargetName="content" Property="TextElement.Foreground" Value="#CDD6F4"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="content" Property="TextElement.Foreground" Value="#CDD6F4"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Label -->
        <Style TargetType="Label">
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="FontSize"   Value="13"/>
        </Style>

        <!-- ComboBox -->
        <Style TargetType="ComboBox">
            <Setter Property="Background"   Value="#313149"/>
            <Setter Property="Foreground"   Value="#CDD6F4"/>
            <Setter Property="BorderBrush"  Value="#45475A"/>
            <Setter Property="Padding"      Value="8,4"/>
            <Setter Property="FontSize"     Value="13"/>
        </Style>

        <!-- ComboBoxItem (anders blijft tekst onzichtbaar in dark mode) -->
        <Style TargetType="ComboBoxItem">
            <Setter Property="Background"   Value="#313149"/>
            <Setter Property="Foreground"   Value="#CDD6F4"/>
            <Setter Property="Padding"      Value="8,6"/>
            <Setter Property="FontSize"     Value="13"/>
            <Style.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter Property="Background" Value="#45475A"/>
                    <Setter Property="Foreground" Value="#CDD6F4"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#45475A"/>
                    <Setter Property="Foreground" Value="#CDD6F4"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- CheckBox -->
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="FontSize"   Value="13"/>
        </Style>

        <!-- ProgressBar -->
        <Style TargetType="ProgressBar">
            <Setter Property="Background"  Value="#313149"/>
            <Setter Property="Foreground"  Value="#89B4FA"/>
            <Setter Property="BorderBrush" Value="#45475A"/>
            <Setter Property="Height"      Value="6"/>
        </Style>

        <!-- ScrollBar -->
        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="#2A2A3E"/>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="56"/>   <!-- Header balk -->
            <RowDefinition Height="*"/>    <!-- Inhoud -->
            <RowDefinition Height="32"/>   <!-- Statusbalk -->
        </Grid.RowDefinitions>

        <!-- ── Header ──────────────────────────────────────────────────── -->
        <Border Grid.Row="0" Background="#1E1E2E" BorderBrush="#45475A" BorderThickness="0,0,0,1">
            <Grid Margin="20,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <!-- Monitor logo (XAML vorm van het site-logo)
                         Achtergrond gebruikt #313149 -> BgCard, dat is donker in dark theme
                         en bijna onzichtbaar (lichtgrijs op witte header) in light theme. -->
                    <Viewbox Width="28" Height="28" Margin="0,0,12,0" VerticalAlignment="Center">
                        <Grid Width="56" Height="56">
                            <Rectangle Fill="#313149" RadiusX="10" RadiusY="10"/>
                            <Rectangle Stroke="#89B4FA" StrokeThickness="3"
                                       RadiusX="4" RadiusY="4"
                                       Width="46" Height="30"
                                       HorizontalAlignment="Left" VerticalAlignment="Top"
                                       Margin="5,8,0,0"/>
                            <Line Stroke="#89B4FA" StrokeThickness="3"
                                  StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                                  X1="28" Y1="38" X2="28" Y2="48"/>
                            <Line Stroke="#89B4FA" StrokeThickness="3"
                                  StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                                  X1="18" Y1="48" X2="38" Y2="48"/>
                        </Grid>
                    </Viewbox>
                    <TextBlock Text="WinGet Manager" FontSize="18" FontWeight="Bold"
                               Foreground="#CDD6F4" VerticalAlignment="Center"/>
                    <Border Background="#89B4FA" CornerRadius="4" Margin="12,0,0,0" Padding="6,2"
                            VerticalAlignment="Center">
                        <TextBlock x:Name="TxtAppVersion" Text="v1.0.0" FontSize="11"
                                   Foreground="#1E1E2E" FontWeight="SemiBold"/>
                    </Border>
                    <Border Background="#F9E2AF" CornerRadius="4" Margin="6,0,0,0" Padding="6,2"
                            VerticalAlignment="Center">
                        <TextBlock Text="BETA" FontSize="11" Foreground="#1E1E2E" FontWeight="Bold"/>
                    </Border>
                    <Border x:Name="AdminBadge" Background="#F38BA8" CornerRadius="4"
                            Margin="6,0,0,0" Padding="6,2" VerticalAlignment="Center" Visibility="Collapsed">
                        <TextBlock Text="ADMIN" FontSize="11" Foreground="#1E1E2E" FontWeight="Bold"/>
                    </Border>
                </StackPanel>

                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <Button x:Name="BtnCheckUpdates" Content="{{Header.CheckUpdates}}"
                            Style="{StaticResource BtnGhost}"/>
                    <Button x:Name="BtnSelfUpdate"   Content="{{Header.SelfUpdate}}"
                            Margin="8,0,0,0" Style="{StaticResource BtnYellow}"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- ── Tabbladen ─────────────────────────────────────────────── -->
        <TabControl x:Name="MainTabs" Grid.Row="1" Margin="0">

            <!-- ─ Tab 1: Zoeken & Installeren ─ -->
            <TabItem x:Name="TabSearch" Header="{{Tab.Search}}">
                <Grid Margin="20">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <!-- Zoekbalk -->
                    <Grid Grid.Row="0" Margin="0,0,0,16">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="140"/>
                            <ColumnDefinition Width="120"/>
                            <ColumnDefinition Width="100"/>
                        </Grid.ColumnDefinitions>
                        <Grid Grid.Column="0" Margin="0,0,8,0">
                            <TextBox x:Name="TxtSearch" Text="" Tag="{{Search.Placeholder}}" FontSize="14"
                                     Padding="40,9,14,9"/>
                            <TextBlock Text="🔍" FontSize="14" Foreground="#6C7086"
                                       HorizontalAlignment="Left" VerticalAlignment="Center"
                                       Margin="14,0,0,0" IsHitTestVisible="False"/>
                        </Grid>
                        <ComboBox x:Name="CmbSearchSource" Grid.Column="1" Margin="0,0,8,0">
                            <ComboBoxItem Content="{{Source.AllSources}}" Tag="" IsSelected="True"/>
                            <ComboBoxItem Content="winget" Tag="winget"/>
                            <ComboBoxItem Content="msstore" Tag="msstore"/>
                        </ComboBox>
                        <Button x:Name="BtnSearch" Grid.Column="2" Content="{{Btn.Search}}"
                                Style="{StaticResource BtnBlue}" Margin="0,0,8,0"/>
                        <Button x:Name="BtnClearSearch" Grid.Column="3" Content="{{Btn.Clear}}"
                                Style="{StaticResource BtnGhost}"/>
                    </Grid>

                    <!-- Resultatenlijst + empty state overlay -->
                    <Grid Grid.Row="1">
                        <DataGrid x:Name="GridSearch" IsReadOnly="True"
                                  SelectionMode="Single" CanUserSortColumns="True">
                            <DataGrid.Columns>
                                <DataGridTextColumn Header="{{Col.Name}}"    Binding="{Binding Name}"    Width="250"/>
                                <DataGridTextColumn Header="{{Col.Id}}"      Binding="{Binding Id}"      Width="250"/>
                                <DataGridTextColumn Header="{{Col.Version}}" Binding="{Binding Version}" Width="100"/>
                                <DataGridTextColumn Header="{{Col.Source}}"  Binding="{Binding Source}"  Width="100"/>
                            </DataGrid.Columns>
                        </DataGrid>
                        <TextBlock x:Name="EmptySearch"
                                   Text="{{Search.Empty}}"
                                   Foreground="#6C7086" FontSize="14"
                                   HorizontalAlignment="Center" VerticalAlignment="Center"
                                   IsHitTestVisible="False"/>
                    </Grid>

                    <!-- Actieknoppen -->
                    <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,12,0,0" HorizontalAlignment="Right">
                        <Button x:Name="BtnInstallSelected" Content="{{Btn.Install}}"
                                Style="{StaticResource BtnGreen}" Margin="0,0,8,0" IsEnabled="False"/>
                        <Button x:Name="BtnShowDetails" Content="{{Btn.Details}}"
                                Style="{StaticResource BtnGhost}" IsEnabled="False"/>
                    </StackPanel>
                </Grid>
            </TabItem>

            <!-- ─ Tab 2: Geïnstalleerd ─ -->
            <TabItem x:Name="TabInstalled">
                <TabItem.Header>
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="{{Tab.Installed}}" VerticalAlignment="Center"/>
                        <Border x:Name="BadgeInstalled" Background="#89B4FA" CornerRadius="10"
                                Padding="7,1" Margin="8,0,0,0" VerticalAlignment="Center"
                                Visibility="Collapsed">
                            <TextBlock x:Name="BadgeInstalledText" Text="0" FontSize="10"
                                       FontWeight="SemiBold" Foreground="#1E1E2E"/>
                        </Border>
                    </StackPanel>
                </TabItem.Header>
                <Grid Margin="20">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <Grid Grid.Row="0" Margin="0,0,0,16">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="130"/>
                        </Grid.ColumnDefinitions>
                        <Grid Margin="0,0,8,0">
                            <TextBox x:Name="TxtFilterInstalled" Tag="{{Installed.FilterPlaceholder}}" Padding="40,9,14,9"/>
                            <TextBlock Text="🔍" FontSize="14" Foreground="#6C7086"
                                       HorizontalAlignment="Left" VerticalAlignment="Center"
                                       Margin="14,0,0,0" IsHitTestVisible="False"/>
                        </Grid>
                        <Button x:Name="BtnRefreshInstalled" Grid.Column="1"
                                Content="{{Btn.Refresh}}" Style="{StaticResource BtnBlue}"/>
                    </Grid>

                    <Grid Grid.Row="1">
                        <DataGrid x:Name="GridInstalled" IsReadOnly="True" CanUserSortColumns="True"
                                  SelectionMode="Extended">
                            <DataGrid.Columns>
                                <DataGridTextColumn Header="{{Col.Name}}"        Binding="{Binding Name}"             Width="200"/>
                                <DataGridTextColumn Header="{{Col.Id}}"          Binding="{Binding Id}"               Width="220"/>
                                <DataGridTextColumn Header="{{Col.Version}}"     Binding="{Binding Version}"          Width="100"/>
                                <DataGridTextColumn Header="{{Col.Available}}"   Binding="{Binding AvailableVersion}" Width="100"/>
                                <DataGridTextColumn Header="{{Col.Source}}"      Binding="{Binding Source}"           Width="90"/>
                                <DataGridTemplateColumn Header="{{Col.Status}}" Width="120">
                                    <DataGridTemplateColumn.CellTemplate>
                                        <DataTemplate>
                                            <Border CornerRadius="3" Padding="8,3" HorizontalAlignment="Left"
                                                    VerticalAlignment="Center">
                                                <Border.Style>
                                                    <Style TargetType="Border">
                                                        <Setter Property="Background" Value="#313149"/>
                                                        <Style.Triggers>
                                                            <DataTrigger Binding="{Binding HasUpdate}" Value="True">
                                                                <Setter Property="Background" Value="#3D320A"/>
                                                            </DataTrigger>
                                                        </Style.Triggers>
                                                    </Style>
                                                </Border.Style>
                                                <TextBlock Text="{Binding StatusText}" FontSize="11" FontWeight="SemiBold">
                                                    <TextBlock.Style>
                                                        <Style TargetType="TextBlock">
                                                            <Setter Property="Foreground" Value="#6C7086"/>
                                                            <Style.Triggers>
                                                                <DataTrigger Binding="{Binding HasUpdate}" Value="True">
                                                                    <Setter Property="Foreground" Value="#A6E3A1"/>
                                                                </DataTrigger>
                                                            </Style.Triggers>
                                                        </Style>
                                                    </TextBlock.Style>
                                                </TextBlock>
                                            </Border>
                                        </DataTemplate>
                                    </DataGridTemplateColumn.CellTemplate>
                                </DataGridTemplateColumn>
                            </DataGrid.Columns>
                        </DataGrid>
                        <TextBlock x:Name="EmptyInstalled"
                                   Text="{{Installed.Loading}}"
                                   Foreground="#6C7086" FontSize="14"
                                   HorizontalAlignment="Center" VerticalAlignment="Center"
                                   IsHitTestVisible="False"/>
                    </Grid>

                    <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,12,0,0" HorizontalAlignment="Right">
                        <TextBlock x:Name="TxtInstalledCount" Foreground="#6C7086" FontSize="12"
                                   VerticalAlignment="Center" Margin="0,0,16,0"/>
                        <Button x:Name="BtnUninstallSelected" Content="{{Btn.Uninstall}}"
                                Style="{StaticResource BtnRed}" Margin="0,0,8,0" IsEnabled="False"/>
                        <Button x:Name="BtnUpdateSelectedInstalled" Content="{{Btn.UpdateSelectedInst}}"
                                Style="{StaticResource BtnGreen}" IsEnabled="False"/>
                    </StackPanel>
                </Grid>
            </TabItem>

            <!-- ─ Tab 3: Updates ─ -->
            <TabItem x:Name="TabUpdates">
                <TabItem.Header>
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="{{Tab.Updates}}" VerticalAlignment="Center"/>
                        <Border x:Name="BadgeUpdates" Background="#A6E3A1" CornerRadius="10"
                                Padding="7,1" Margin="8,0,0,0" VerticalAlignment="Center"
                                Visibility="Collapsed">
                            <TextBlock x:Name="BadgeUpdatesText" Text="0" FontSize="10"
                                       FontWeight="SemiBold" Foreground="#1E1E2E"/>
                        </Border>
                    </StackPanel>
                </TabItem.Header>
                <Grid Margin="20">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <!-- Badge samenvatting -->
                    <Border Grid.Row="0" Background="#313149" CornerRadius="8" Padding="16,10" Margin="0,0,0,16">
                        <StackPanel Orientation="Horizontal">
                            <StackPanel>
                                <TextBlock Text="{{Updates.AvailableLabel}}" Foreground="#6C7086" FontSize="11"/>
                                <TextBlock x:Name="TxtUpdateCount" Text="–" Foreground="#89B4FA"
                                           FontSize="24" FontWeight="Bold"/>
                            </StackPanel>
                            <StackPanel>
                                <TextBlock Text="{{Updates.WinGetVersion}}" Foreground="#6C7086" FontSize="11"/>
                                <TextBlock x:Name="TxtWinGetVersion" Text="–" Foreground="#A6E3A1"
                                           FontSize="24" FontWeight="Bold"/>
                            </StackPanel>
                        </StackPanel>
                    </Border>

                    <Grid Grid.Row="1">
                        <DataGrid x:Name="GridUpdates" CanUserSortColumns="True"
                                  SelectionMode="Extended">
                            <DataGrid.Columns>
                                <DataGridCheckBoxColumn Header="" Binding="{Binding Selected, UpdateSourceTrigger=PropertyChanged, Mode=TwoWay}"
                                                        Width="36"/>
                                <DataGridTextColumn Header="{{Col.Name}}"        Binding="{Binding Name}"             Width="230" IsReadOnly="True"/>
                                <DataGridTextColumn Header="{{Col.Id}}"          Binding="{Binding Id}"               Width="220" IsReadOnly="True"/>
                                <DataGridTextColumn Header="{{Col.Current}}"     Binding="{Binding Version}"          Width="110" IsReadOnly="True"/>
                                <DataGridTextColumn Header="{{Col.Available}}"   Binding="{Binding AvailableVersion}" Width="110" IsReadOnly="True"/>
                                <DataGridTextColumn Header="{{Col.Source}}"      Binding="{Binding Source}"           Width="100" IsReadOnly="True"/>
                            </DataGrid.Columns>
                        </DataGrid>
                        <TextBlock x:Name="EmptyUpdates"
                                   Text="{{Updates.AllUpToDate}}"
                                   Foreground="#A6E3A1" FontSize="14"
                                   HorizontalAlignment="Center" VerticalAlignment="Center"
                                   IsHitTestVisible="False" Visibility="Collapsed"/>
                    </Grid>

                    <!-- Voortgangsbalk -->
                    <ProgressBar x:Name="UpdateProgress" Grid.Row="2" Margin="0,12,0,0"
                                 Visibility="Collapsed" IsIndeterminate="True"/>

                    <StackPanel Grid.Row="3" Orientation="Horizontal" Margin="0,12,0,0" HorizontalAlignment="Right">
                        <Button x:Name="BtnRefreshUpdates" Content="{{Btn.Refresh}}"
                                Style="{StaticResource BtnGhost}" Margin="0,0,8,0"/>
                        <Button x:Name="BtnUpdateSelected" Content="{{Btn.UpdateSelected}}"
                                Style="{StaticResource BtnGreen}" Margin="0,0,8,0" IsEnabled="False"/>
                        <Button x:Name="BtnUpdateAll" Content="{{Btn.UpdateAll}}"
                                Style="{StaticResource BtnBlue}"/>
                    </StackPanel>
                </Grid>
            </TabItem>

            <!-- ─ Tab 4: Import / Export ─ -->
            <TabItem Header="{{Tab.ImportExport}}">
                <Grid Margin="30">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="20"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <!-- Export -->
                    <Border Grid.Column="0" Background="#313149" CornerRadius="12" Padding="24">
                        <StackPanel>
                            <TextBlock Text="{{Section.Export}}" FontSize="16" FontWeight="SemiBold"
                                       Foreground="#89B4FA" Margin="0,0,0,12"/>
                            <TextBlock TextWrapping="Wrap" Foreground="#6C7086" Margin="0,0,0,20"
                                       Text="{{Export.Description}}"/>
                            <Label Content="{{Export.FileLabel}}"/>
                            <Grid Margin="0,4,0,16">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBox x:Name="TxtExportPath" Margin="0,0,8,0"
                                         Text="C:\backup\packages.json"/>
                                <Button x:Name="BtnBrowseExport" Grid.Column="1"
                                        Content="..." Style="{StaticResource BtnGhost}" Padding="12,6"/>
                            </Grid>
                            <Button x:Name="BtnExport" Content="{{Btn.ExportNow}}"
                                    Style="{StaticResource BtnGreen}" HorizontalAlignment="Left"/>
                        </StackPanel>
                    </Border>

                    <!-- Import -->
                    <Border Grid.Column="2" Background="#313149" CornerRadius="12" Padding="24">
                        <StackPanel>
                            <TextBlock Text="{{Section.Import}}" FontSize="16" FontWeight="SemiBold"
                                       Foreground="#89B4FA" Margin="0,0,0,12"/>
                            <TextBlock TextWrapping="Wrap" Foreground="#6C7086" Margin="0,0,0,20"
                                       Text="{{Import.Description}}"/>
                            <Label Content="{{Import.FileLabel}}"/>
                            <Grid Margin="0,4,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBox x:Name="TxtImportPath" Margin="0,0,8,0"/>
                                <Button x:Name="BtnBrowseImport" Grid.Column="1"
                                        Content="..." Style="{StaticResource BtnGhost}" Padding="12,6"/>
                            </Grid>
                            <CheckBox x:Name="ChkIgnoreUnavailable" Content="{{Import.IgnoreUnavailable}}"
                                      IsChecked="True" Margin="0,4,0,16" Foreground="#CDD6F4"/>
                            <Button x:Name="BtnImport" Content="{{Btn.ImportNow}}"
                                    Style="{StaticResource BtnBlue}" HorizontalAlignment="Left"/>
                        </StackPanel>
                    </Border>
                </Grid>
            </TabItem>

            <!-- ─ Tab 5: Bronnen ─ -->
            <TabItem x:Name="TabSources">
                <TabItem.Header>
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="{{Tab.Sources}}" VerticalAlignment="Center"/>
                        <Border x:Name="BadgeSources" Background="#89B4FA" CornerRadius="10"
                                Padding="7,1" Margin="8,0,0,0" VerticalAlignment="Center"
                                Visibility="Collapsed">
                            <TextBlock x:Name="BadgeSourcesText" Text="0" FontSize="10"
                                       FontWeight="SemiBold" Foreground="#1E1E2E"/>
                        </Border>
                    </StackPanel>
                </TabItem.Header>
                <Grid Margin="20">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <Border Grid.Row="0" Background="#313149" CornerRadius="8" Padding="16,12" Margin="0,0,0,16">
                        <StackPanel>
                            <TextBlock FontSize="13" Foreground="#CDD6F4" TextWrapping="Wrap">
                                <Run Text="{{Sources.IntroBold}}" FontWeight="SemiBold"/>
                                <Run Text="{{Sources.IntroDefault}}"/>
                            </TextBlock>
                            <TextBlock FontSize="12" Foreground="#6C7086" TextWrapping="Wrap" Margin="0,6,0,0">
                                <Run Text="• "/>
                                <Run Text="winget" FontWeight="SemiBold" Foreground="#89B4FA"/>
                                <Run Text="{{Sources.WingetDesc}}"/>
                            </TextBlock>
                            <TextBlock FontSize="12" Foreground="#6C7086" TextWrapping="Wrap">
                                <Run Text="• "/>
                                <Run Text="msstore" FontWeight="SemiBold" Foreground="#89B4FA"/>
                                <Run Text="{{Sources.MsstoreDesc}}"/>
                            </TextBlock>
                            <TextBlock FontSize="12" Foreground="#6C7086" TextWrapping="Wrap">
                                <Run Text="• "/>
                                <Run Text="local" FontWeight="SemiBold" Foreground="#FAB387"/>
                                <Run Text="{{Sources.LocalDesc}}"/>
                            </TextBlock>
                            <TextBlock FontSize="12" Foreground="#6C7086" TextWrapping="Wrap" Margin="0,8,0,0">
                                <Run Text="{{Sources.Outro}}"/>
                            </TextBlock>
                        </StackPanel>
                    </Border>

                    <Grid Grid.Row="1">
                        <DataGrid x:Name="GridSources" IsReadOnly="True">
                            <DataGrid.Columns>
                                <DataGridTextColumn Header="{{Col.Name}}" Binding="{Binding Name}" Width="150"/>
                                <DataGridTextColumn Header="{{Col.Url}}"  Binding="{Binding Url}"  Width="*"/>
                                <DataGridTextColumn Header="{{Col.Type}}" Binding="{Binding Type}" Width="180"/>
                            </DataGrid.Columns>
                        </DataGrid>
                        <TextBlock x:Name="EmptySources"
                                   Text="{{Sources.None}}"
                                   Foreground="#6C7086" FontSize="14"
                                   HorizontalAlignment="Center" VerticalAlignment="Center"
                                   IsHitTestVisible="False" Visibility="Collapsed"/>
                    </Grid>

                    <!-- Nieuwe bron toevoegen -->
                    <Border Grid.Row="2" Background="#313149" CornerRadius="8"
                            Padding="16" Margin="0,16,0,0">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="160"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="160"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Label Grid.Column="0" Content="{{Field.Name}}" VerticalAlignment="Center"/>
                            <TextBox x:Name="TxtSourceName" Grid.Column="1" Margin="4,0,12,0"/>
                            <Label Grid.Column="2" Content="{{Field.Url}}" VerticalAlignment="Center"/>
                            <TextBox x:Name="TxtSourceUrl" Grid.Column="3" Margin="4,0,12,0"/>
                            <Label Grid.Column="4" Content="{{Field.Type}}" VerticalAlignment="Center"/>
                            <ComboBox x:Name="CmbSourceType" Grid.Column="5" Margin="4,0,12,0">
                                <ComboBoxItem Content="Microsoft.Rest" IsSelected="True"/>
                                <ComboBoxItem Content="Microsoft.PreIndexed.Package"/>
                            </ComboBox>
                            <Button x:Name="BtnAddSource" Grid.Column="6" Content="{{Btn.Add}}"
                                    Style="{StaticResource BtnGreen}"/>
                        </Grid>
                    </Border>

                    <StackPanel Grid.Row="3" Orientation="Horizontal" Margin="0,12,0,0" HorizontalAlignment="Right">
                        <Button x:Name="BtnRefreshSources" Content="{{Btn.Refresh}}"
                                Style="{StaticResource BtnGhost}" Margin="0,0,8,0"/>
                        <Button x:Name="BtnRemoveSource" Content="{{Btn.RemoveSource}}"
                                Style="{StaticResource BtnRed}" Margin="0,0,8,0" IsEnabled="False"/>
                        <Button x:Name="BtnResetSources" Content="{{Btn.ResetSources}}"
                                Style="{StaticResource BtnYellow}"/>
                    </StackPanel>
                </Grid>
            </TabItem>

            <!-- ─ Tab 6: Logs ─ -->
            <TabItem Header="{{Tab.Logs}}">
                <Grid Margin="20">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,12">
                        <ComboBox x:Name="CmbLogFilter" Width="120" Margin="0,0,8,0">
                            <ComboBoxItem Content="{{Logs.LevelAll}}" Tag="" IsSelected="True"/>
                            <ComboBoxItem Content="DEBUG" Tag="DEBUG"/>
                            <ComboBoxItem Content="INFO"  Tag="INFO"/>
                            <ComboBoxItem Content="WARN"  Tag="WARN"/>
                            <ComboBoxItem Content="ERROR" Tag="ERROR"/>
                        </ComboBox>
                        <Button x:Name="BtnClearLogs" Content="{{Btn.ClearLogs}}"
                                Style="{StaticResource BtnGhost}" Margin="0,0,8,0"/>
                        <Button x:Name="BtnOpenLogFile" Content="{{Btn.OpenLogFile}}"
                                Style="{StaticResource BtnGhost}"/>
                        <TextBlock x:Name="TxtLogPath" Foreground="#6C7086" FontSize="11"
                                   VerticalAlignment="Center" Margin="16,0,0,0"/>
                    </StackPanel>

                    <DataGrid x:Name="GridLogs" Grid.Row="1" IsReadOnly="True"
                              CanUserSortColumns="False" FontFamily="Consolas" FontSize="12"
                              AutoGenerateColumns="False">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="{{Col.Timestamp}}"  Binding="{Binding Timestamp, Mode=OneWay}" Width="180"/>
                            <DataGridTextColumn Header="{{Col.Level}}"      Binding="{Binding Level, Mode=OneWay}"     Width="70"/>
                            <DataGridTextColumn Header="{{Col.Source}}"     Binding="{Binding Source, Mode=OneWay}"    Width="120"/>
                            <DataGridTextColumn Header="{{Col.Message}}"    Binding="{Binding Message, Mode=OneWay}"   Width="*"/>
                        </DataGrid.Columns>
                        <DataGrid.RowStyle>
                            <Style TargetType="DataGridRow">
                                <Style.Triggers>
                                    <DataTrigger Binding="{Binding Level}" Value="ERROR">
                                        <Setter Property="Background" Value="#3D1A1F"/>
                                        <Setter Property="Foreground" Value="#F38BA8"/>
                                    </DataTrigger>
                                    <DataTrigger Binding="{Binding Level}" Value="WARN">
                                        <Setter Property="Background" Value="#3D320A"/>
                                        <Setter Property="Foreground" Value="#F9E2AF"/>
                                    </DataTrigger>
                                    <DataTrigger Binding="{Binding Level}" Value="DEBUG">
                                        <Setter Property="Foreground" Value="#6C7086"/>
                                    </DataTrigger>
                                </Style.Triggers>
                            </Style>
                        </DataGrid.RowStyle>
                    </DataGrid>
                </Grid>
            </TabItem>

            <!-- ─ Tab 7: Settings (gear glyph from Segoe Fluent Icons / Segoe MDL2 Assets fallback) ─ -->
            <TabItem>
                <TabItem.Header>
                    <TextBlock>
                        <Run FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="14" Text="&#xE713;"/>
                        <Run Text="  {{Tab.Settings}}"/>
                    </TextBlock>
                </TabItem.Header>
                <ScrollViewer Margin="20" VerticalScrollBarVisibility="Auto">
                    <StackPanel MaxWidth="600" HorizontalAlignment="Left">

                        <TextBlock Text="{{Settings.Logging}}" FontSize="15" FontWeight="SemiBold"
                                   Foreground="#89B4FA" Margin="0,0,0,12"/>

                        <Grid Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="200"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Label Content="{{Settings.LogDir}}" VerticalAlignment="Center"/>
                            <TextBox x:Name="TxtSettingsLogDir" Grid.Column="1"/>
                        </Grid>
                        <Grid Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="200"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Label Content="{{Settings.MinLevel}}" VerticalAlignment="Center"/>
                            <ComboBox x:Name="CmbSettingsLogLevel" Grid.Column="1">
                                <ComboBoxItem Content="DEBUG"/>
                                <ComboBoxItem Content="INFO" IsSelected="True"/>
                                <ComboBoxItem Content="WARN"/>
                                <ComboBoxItem Content="ERROR"/>
                            </ComboBox>
                        </Grid>
                        <Grid Margin="0,0,0,24">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="200"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Label Content="{{Settings.RetentionDays}}" VerticalAlignment="Center"/>
                            <TextBox x:Name="TxtSettingsRetention" Grid.Column="1" Text="30"/>
                        </Grid>

                        <TextBlock Text="{{Settings.Behavior}}" FontSize="15" FontWeight="SemiBold"
                                   Foreground="#89B4FA" Margin="0,0,0,12"/>

                        <Grid Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="200"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Label Content="{{Settings.DefaultScope}}" VerticalAlignment="Center"/>
                            <ComboBox x:Name="CmbSettingsScope" Grid.Column="1">
                                <ComboBoxItem Content="user" IsSelected="True"/>
                                <ComboBoxItem Content="machine"/>
                            </ComboBox>
                        </Grid>

                        <Grid Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="200"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Label Content="{{Settings.Theme}}" VerticalAlignment="Center"/>
                            <ComboBox x:Name="CmbSettingsTheme" Grid.Column="1">
                                <ComboBoxItem Content="{{Theme.Auto}}" IsSelected="True"/>
                                <ComboBoxItem Content="{{Theme.Dark}}"/>
                                <ComboBoxItem Content="{{Theme.Light}}"/>
                            </ComboBox>
                        </Grid>

                        <Grid Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="200"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Label Content="{{Settings.LanguageLabel}}" VerticalAlignment="Center"/>
                            <ComboBox x:Name="CmbSettingsLanguage" Grid.Column="1">
                                <ComboBoxItem Content="{{Language.Auto}}"    Tag="auto" IsSelected="True"/>
                                <ComboBoxItem Content="{{Language.Dutch}}"   Tag="nl-NL"/>
                                <ComboBoxItem Content="{{Language.English}}" Tag="en-US"/>
                            </ComboBox>
                        </Grid>

                        <CheckBox x:Name="ChkAutoUpdateCheck"
                                  Content="{{Settings.AutoUpdateCheck}}"
                                  IsChecked="True" Margin="0,4,0,4"/>
                        <CheckBox x:Name="ChkConfirmUninstall"
                                  Content="{{Settings.ConfirmUninstall}}"
                                  IsChecked="True" Margin="0,4,0,4"/>
                        <CheckBox x:Name="ChkConfirmUpdate"
                                  Content="{{Settings.ConfirmUpdate}}"
                                  IsChecked="False" Margin="0,4,0,24"/>

                        <TextBlock Text="{{Settings.SelfUpdate}}" FontSize="15" FontWeight="SemiBold"
                                   Foreground="#89B4FA" Margin="0,0,0,12"/>

                        <Grid Margin="0,0,0,24">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="200"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Label Content="{{Settings.UpdateUrl}}" VerticalAlignment="Center"/>
                            <TextBox x:Name="TxtSettingsUpdateUrl" Grid.Column="1"/>
                        </Grid>

                        <StackPanel Orientation="Horizontal" Margin="0,0,0,32">
                            <Button x:Name="BtnSaveSettings" Content="{{Btn.Save}}"
                                    Style="{StaticResource BtnGreen}" Margin="0,0,8,0"/>
                            <Button x:Name="BtnResetSettings" Content="{{Btn.ResetDefaults}}"
                                    Style="{StaticResource BtnGhost}"/>
                        </StackPanel>

                        <TextBlock Text="{{Settings.Shortcuts}}" FontSize="15" FontWeight="SemiBold"
                                   Foreground="#89B4FA" Margin="0,0,0,12"/>

                        <Border Background="#313149" CornerRadius="8" Padding="16">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="160"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="Auto"/>
                                </Grid.RowDefinitions>

                                <TextBlock Grid.Row="0" Grid.Column="0" Text="F5"        Foreground="#F9E2AF" FontFamily="Consolas" FontSize="13" Margin="0,0,0,6"/>
                                <TextBlock Grid.Row="0" Grid.Column="1" Text="{{Shortcut.RefreshTab}}"             Foreground="#CDD6F4" FontSize="13" Margin="0,0,0,6"/>

                                <TextBlock Grid.Row="1" Grid.Column="0" Text="Ctrl + F"  Foreground="#F9E2AF" FontFamily="Consolas" FontSize="13" Margin="0,0,0,6"/>
                                <TextBlock Grid.Row="1" Grid.Column="1" Text="{{Shortcut.JumpSearch}}"            Foreground="#CDD6F4" FontSize="13" Margin="0,0,0,6"/>

                                <TextBlock Grid.Row="2" Grid.Column="0" Text="Ctrl + R"  Foreground="#F9E2AF" FontFamily="Consolas" FontSize="13" Margin="0,0,0,6"/>
                                <TextBlock Grid.Row="2" Grid.Column="1" Text="{{Shortcut.OpenUpdates}}"           Foreground="#CDD6F4" FontSize="13" Margin="0,0,0,6"/>

                                <TextBlock Grid.Row="3" Grid.Column="0" Text="Ctrl + L"  Foreground="#F9E2AF" FontFamily="Consolas" FontSize="13" Margin="0,0,0,6"/>
                                <TextBlock Grid.Row="3" Grid.Column="1" Text="{{Shortcut.OpenLogs}}"              Foreground="#CDD6F4" FontSize="13" Margin="0,0,0,6"/>

                                <TextBlock Grid.Row="4" Grid.Column="0" Text="Ctrl + W"  Foreground="#F9E2AF" FontFamily="Consolas" FontSize="13" Margin="0,0,0,6"/>
                                <TextBlock Grid.Row="4" Grid.Column="1" Text="{{Shortcut.Close}}"                 Foreground="#CDD6F4" FontSize="13" Margin="0,0,0,6"/>

                                <TextBlock Grid.Row="5" Grid.Column="0" Text="Esc"       Foreground="#F9E2AF" FontFamily="Consolas" FontSize="13" Margin="0,0,0,6"/>
                                <TextBlock Grid.Row="5" Grid.Column="1" Text="{{Shortcut.ClearSearch}}"           Foreground="#CDD6F4" FontSize="13" Margin="0,0,0,6"/>

                                <TextBlock Grid.Row="6" Grid.Column="0" Text="Enter"     Foreground="#F9E2AF" FontFamily="Consolas" FontSize="13"/>
                                <TextBlock Grid.Row="6" Grid.Column="1" Text="{{Shortcut.EnterSearch}}" Foreground="#CDD6F4" FontSize="13"/>
                            </Grid>
                        </Border>

                        <TextBlock Text="{{Settings.MultiSelectTip}}"
                                   Foreground="#6C7086" FontSize="11" Margin="0,8,0,0" FontStyle="Italic"/>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

        </TabControl>

        <!-- ── Statusbalk ────────────────────────────────────────────── -->
        <Border Grid.Row="2" Background="#1E1E2E" BorderBrush="#45475A" BorderThickness="0,1,0,0">
            <Grid Margin="16,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="180"/>
                </Grid.ColumnDefinitions>

                <TextBlock x:Name="TxtStatus" Text="{{Status.Ready}}" Foreground="#6C7086"
                           FontSize="12" VerticalAlignment="Center"/>
                <ProgressBar x:Name="StatusProgress" Grid.Column="1"
                             Width="150" Height="4" Margin="0,0,16,0"
                             Visibility="Collapsed" IsIndeterminate="True"/>
                <TextBlock x:Name="TxtWinGetVersionStatus" Grid.Column="2"
                           FontSize="11" Foreground="#6C7086" VerticalAlignment="Center"
                           HorizontalAlignment="Right"/>
            </Grid>
        </Border>

    </Grid>
</Window>
'@

# ---------------------------------------------------------------------------
# Window laden
# ---------------------------------------------------------------------------

# Theme altijd toepassen (ook Dark, want palette kan vibranter zijn dan XAML-base)
$xamlString = $Xaml.OuterXml
# i18n eerst: vervang {{Key}} placeholders door vertaalde strings
$xamlString = Apply-Translations -Text $xamlString
$xamlString = Apply-ThemeColors -xamlText $xamlString -ThemeName $ActiveTheme
[xml]$ThemedXaml = $xamlString
$Reader = [System.Xml.XmlNodeReader]::new($ThemedXaml)
$Window = [System.Windows.Markup.XamlReader]::Load($Reader)

# Geef het Window's Dispatcher mee aan logging zodat background-thread logs
# thread-safe in de ObservableCollection terechtkomen
Set-LogObservable -Collection $LogCollection -Dispatcher $Window.Dispatcher

# Helpers voor control-lookup
function Get-Control { param($name) $Window.FindName($name) }

$TxtSearch               = Get-Control 'TxtSearch'
$CmbSearchSource         = Get-Control 'CmbSearchSource'
$BtnSearch               = Get-Control 'BtnSearch'
$BtnClearSearch          = Get-Control 'BtnClearSearch'
$GridSearch              = Get-Control 'GridSearch'
$BtnInstallSelected      = Get-Control 'BtnInstallSelected'
$BtnShowDetails          = Get-Control 'BtnShowDetails'

$TxtFilterInstalled      = Get-Control 'TxtFilterInstalled'
$BtnRefreshInstalled     = Get-Control 'BtnRefreshInstalled'
$GridInstalled           = Get-Control 'GridInstalled'
$TxtInstalledCount       = Get-Control 'TxtInstalledCount'
$BtnUninstallSelected    = Get-Control 'BtnUninstallSelected'
$BtnUpdateSelectedInstalled = Get-Control 'BtnUpdateSelectedInstalled'

$GridUpdates             = Get-Control 'GridUpdates'
$TxtUpdateCount          = Get-Control 'TxtUpdateCount'
$TxtWinGetVersion        = Get-Control 'TxtWinGetVersion'
$UpdateProgress          = Get-Control 'UpdateProgress'
$BtnRefreshUpdates       = Get-Control 'BtnRefreshUpdates'
$BtnUpdateSelected       = Get-Control 'BtnUpdateSelected'
$BtnUpdateAll            = Get-Control 'BtnUpdateAll'

$TxtExportPath           = Get-Control 'TxtExportPath'
$BtnBrowseExport         = Get-Control 'BtnBrowseExport'
$BtnExport               = Get-Control 'BtnExport'
$TxtImportPath           = Get-Control 'TxtImportPath'
$BtnBrowseImport         = Get-Control 'BtnBrowseImport'
$ChkIgnoreUnavailable    = Get-Control 'ChkIgnoreUnavailable'
$BtnImport               = Get-Control 'BtnImport'

$GridSources             = Get-Control 'GridSources'
$TxtSourceName           = Get-Control 'TxtSourceName'
$TxtSourceUrl            = Get-Control 'TxtSourceUrl'
$CmbSourceType           = Get-Control 'CmbSourceType'
$BtnAddSource            = Get-Control 'BtnAddSource'
$BtnRefreshSources       = Get-Control 'BtnRefreshSources'
$BtnRemoveSource         = Get-Control 'BtnRemoveSource'
$BtnResetSources         = Get-Control 'BtnResetSources'

$GridLogs                = Get-Control 'GridLogs'
$CmbLogFilter            = Get-Control 'CmbLogFilter'
$BtnClearLogs            = Get-Control 'BtnClearLogs'
$BtnOpenLogFile          = Get-Control 'BtnOpenLogFile'
$TxtLogPath              = Get-Control 'TxtLogPath'

$TxtSettingsLogDir       = Get-Control 'TxtSettingsLogDir'
$CmbSettingsLogLevel     = Get-Control 'CmbSettingsLogLevel'
$TxtSettingsRetention    = Get-Control 'TxtSettingsRetention'
$CmbSettingsScope        = Get-Control 'CmbSettingsScope'
$CmbSettingsTheme        = Get-Control 'CmbSettingsTheme'
$CmbSettingsLanguage     = Get-Control 'CmbSettingsLanguage'
$ChkAutoUpdateCheck      = Get-Control 'ChkAutoUpdateCheck'
$ChkConfirmUninstall     = Get-Control 'ChkConfirmUninstall'
$ChkConfirmUpdate        = Get-Control 'ChkConfirmUpdate'
$TxtSettingsUpdateUrl    = Get-Control 'TxtSettingsUpdateUrl'
$BtnSaveSettings         = Get-Control 'BtnSaveSettings'
$BtnResetSettings        = Get-Control 'BtnResetSettings'

$TxtStatus               = Get-Control 'TxtStatus'
$StatusProgress          = Get-Control 'StatusProgress'
$TxtWinGetVersionStatus  = Get-Control 'TxtWinGetVersionStatus'
$TxtAppVersion           = Get-Control 'TxtAppVersion'
$AdminBadge              = Get-Control 'AdminBadge'
$BtnCheckUpdates         = Get-Control 'BtnCheckUpdates'
$BtnSelfUpdate           = Get-Control 'BtnSelfUpdate'
$MainTabs                = Get-Control 'MainTabs'
$TabSearch               = Get-Control 'TabSearch'
$TabInstalled            = Get-Control 'TabInstalled'
$TabUpdates              = Get-Control 'TabUpdates'
$TabSources              = Get-Control 'TabSources'
$EmptySearch             = Get-Control 'EmptySearch'
$EmptyInstalled          = Get-Control 'EmptyInstalled'
$EmptyUpdates            = Get-Control 'EmptyUpdates'
$EmptySources            = Get-Control 'EmptySources'
$BadgeInstalled          = Get-Control 'BadgeInstalled'
$BadgeInstalledText      = Get-Control 'BadgeInstalledText'
$BadgeUpdates            = Get-Control 'BadgeUpdates'
$BadgeUpdatesText        = Get-Control 'BadgeUpdatesText'
$BadgeSources            = Get-Control 'BadgeSources'
$BadgeSourcesText        = Get-Control 'BadgeSourcesText'

# ---------------------------------------------------------------------------
# Hulpfuncties UI-thread
# ---------------------------------------------------------------------------

function Set-Status {
    param([string]$Text, [bool]$Busy = $false)
    $Window.Dispatcher.Invoke([action]{
        $TxtStatus.Text = $Text
        $StatusProgress.Visibility = if ($Busy) { 'Visible' } else { 'Collapsed' }
    })
}

function Set-UIEnabled {
    param([bool]$Enabled)
    $Window.Dispatcher.Invoke([action]{
        $Window.IsEnabled = $Enabled
    })
}

function Show-Info  { param($msg) [System.Windows.MessageBox]::Show($msg, (Get-Text 'Dialog.Title.Info'),    "OK",    "Information") | Out-Null }
function Show-Error { param($msg) [System.Windows.MessageBox]::Show($msg, (Get-Text 'Dialog.Title.Error'),   "OK",    "Error")       | Out-Null }
function Ask-Confirm { param($msg) ([System.Windows.MessageBox]::Show($msg, (Get-Text 'Dialog.Title.Confirm'), "YesNo", "Question")) -eq 'Yes' }

# ---------------------------------------------------------------------------
# UAC visibility helpers
# ---------------------------------------------------------------------------
# When Start-Process -Verb RunAs triggers UAC, Windows decides whether to
# show the consent dialog on the secure desktop (on top) or as a flashing
# taskbar button. The deciding factor is whether the calling process is the
# foreground window AND has "permission" to grant foreground rights.
#
# Win32 magic:
#   - AllowSetForegroundWindow(ASFW_ANY) lets ANY process steal foreground next
#   - SetForegroundWindow on our window first ensures we ARE the foreground
#   - After UAC completes, call $Window.Activate() to refocus our app

if (-not ('WinGetMgr.UacHelper' -as [type])) {
    Add-Type -Namespace WinGetMgr -Name UacHelper -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true)]
public static extern bool AllowSetForegroundWindow(uint dwProcessId);
[DllImport("user32.dll", SetLastError = true)]
public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll", SetLastError = true)]
public static extern bool FlashWindow(IntPtr hWnd, bool bInvert);
public const uint ASFW_ANY = 0xFFFFFFFF;
'@
}

# Call right before Start-Process -Verb RunAs to maximize chance of UAC showing on top
function Prepare-UacForeground {
    try {
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($Window)).Handle
        if ($hwnd -ne [IntPtr]::Zero) {
            $Window.Activate() | Out-Null
            [void][WinGetMgr.UacHelper]::SetForegroundWindow($hwnd)
        }
        [void][WinGetMgr.UacHelper]::AllowSetForegroundWindow([WinGetMgr.UacHelper]::ASFW_ANY)
    } catch {
        Write-Log "Prepare-UacForeground failed: $_" -Level WARN -Source GUI
    }
}

# Call after Start-Process -Verb RunAs completes so our window gets focus back
function Restore-AppForeground {
    try {
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($Window)).Handle
        if ($hwnd -ne [IntPtr]::Zero) {
            $Window.Activate() | Out-Null
            [void][WinGetMgr.UacHelper]::SetForegroundWindow($hwnd)
            # Flash taskbar briefly to draw attention if window is minimized
            [void][WinGetMgr.UacHelper]::FlashWindow($hwnd, $true)
        }
    } catch {}
}

# Confirmation met optionele "Niet meer vragen"-checkbox die naar config schrijft
function Ask-ConfirmEx {
    param(
        [string]$Message,
        [string]$Title,
        [string]$ConfigKeyToDisable
    )
    if (-not $Title) { $Title = Get-Text 'Dialog.Title.Confirm' }

    # Snelpad: gebruiker heeft eerder "niet meer vragen" aangevinkt
    if ($ConfigKeyToDisable -and $cfg.$ConfigKeyToDisable -eq $false) {
        return $true
    }

    # Pas thema + vertaling toe op de dialog-XAML
    [xml]$dlgXaml = Apply-ThemeColors -ThemeName $ActiveTheme -xamlText (Apply-Translations -Text @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" Height="220" Width="480" ShowInTaskbar="False"
        WindowStartupLocation="CenterOwner" ResizeMode="NoResize"
        Background="#1E1E2E">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock x:Name="TxtMsg" Grid.Row="0" Foreground="#CDD6F4"
                   FontSize="13" TextWrapping="Wrap" VerticalAlignment="Top"/>
        <CheckBox x:Name="ChkSkip" Grid.Row="1" Foreground="#6C7086" FontSize="12"
                  Content="{{Dialog.DontAskAgain}}" Margin="0,16,0,0"/>
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,16,0,0">
            <Button x:Name="BtnYes" Content="{{Btn.Yes}}" Width="90" Height="32" Margin="0,0,8,0"
                    Background="#89B4FA" Foreground="#1E1E2E" BorderThickness="0" Cursor="Hand"/>
            <Button x:Name="BtnNo" Content="{{Btn.No}}" Width="90" Height="32"
                    Background="#313149" Foreground="#CDD6F4" BorderThickness="0" Cursor="Hand"/>
        </StackPanel>
    </Grid>
</Window>
"@)

    $dlg = [System.Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($dlgXaml))
    $dlg.Owner = $Window
    $dlg.FindName('TxtMsg').Text = $Message
    $chk = $dlg.FindName('ChkSkip')

    # Verberg checkbox als er geen config-key is
    if (-not $ConfigKeyToDisable) { $chk.Visibility = 'Collapsed' }

    $script:_dlgResult = $false
    $dlg.FindName('BtnYes').Add_Click({ $script:_dlgResult = $true; $dlg.Close() })
    $dlg.FindName('BtnNo').Add_Click({ $script:_dlgResult = $false; $dlg.Close() })
    $dlg.Add_PreviewKeyDown({
        if ($_.Key -eq 'Escape') { $script:_dlgResult = $false; $dlg.Close() }
        if ($_.Key -eq 'Return') { $script:_dlgResult = $true; $dlg.Close() }
    })

    [void]$dlg.ShowDialog()

    if ($ConfigKeyToDisable -and $script:_dlgResult -and $chk.IsChecked) {
        try {
            Set-ConfigValue -Key $ConfigKeyToDisable -Value $false
            $script:cfg = Get-AppConfig
            Write-Log "Config '$ConfigKeyToDisable' disabled on request" -Source GUI
        } catch {
            Write-Log "Config update failed: $_" -Level WARN -Source GUI
        }
    }

    return $script:_dlgResult
}

# --- WinGet exit codes -> menselijke teksten + actie suggesties -------------
$Script:WinGetErrors = @{
    -1978335212 = @{ Msg = (Get-Text 'Err.NoUpdatesAvailable'); Action = 'none' }
    -1978335189 = @{ Msg = (Get-Text 'Err.PackageNotFound'); Action = 'none' }
    -1978335188 = @{ Msg = (Get-Text 'Err.MultiplePackages'); Action = 'none' }
    -1978335162 = @{ Msg = (Get-Text 'Err.AgreementNotAccepted'); Action = 'none' }
    -1978334969 = @{ Msg = (Get-Text 'Err.NeedsAdmin'); Action = 'elevate' }
    -1978334964 = @{ Msg = (Get-Text 'Err.AppRunning'); Action = 'kill' }
    -1978334960 = @{ Msg = (Get-Text 'Err.HashMismatch'); Action = 'retry' }
    -1978335211 = @{ Msg = (Get-Text 'Err.NoInternet'); Action = 'retry' }
    -1978334968 = @{ Msg = (Get-Text 'Err.DiskFull'); Action = 'none' }
}

function Get-WinGetErrorInfo {
    param([int]$ExitCode)
    if ($Script:WinGetErrors.ContainsKey($ExitCode)) {
        return $Script:WinGetErrors[$ExitCode]
    }
    return @{ Msg = "WinGet exitcode $ExitCode"; Action = 'none' }
}

# Vind processen die waarschijnlijk bij dit pakket horen
function Find-RelatedProcesses {
    param(
        [string]$PackageId,
        [string]$PackageName
    )

    # Mogelijke namen afleiden: deel na laatste punt + naam zonder spaties
    $candidates = New-Object System.Collections.Generic.HashSet[string]
    if ($PackageId) {
        $parts = $PackageId.Split('.')
        $last  = $parts[-1]
        if ($last) { [void]$candidates.Add($last.ToLower()) }
        # ook publisher proberen
        if ($parts.Count -gt 1) { [void]$candidates.Add($parts[0].ToLower()) }
    }
    if ($PackageName) {
        [void]$candidates.Add(($PackageName -replace '\s','').ToLower())
        # eerste woord
        $first = ($PackageName -split '\s+')[0]
        if ($first) { [void]$candidates.Add($first.ToLower()) }
    }

    $processes = Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $procName = $_.ProcessName.ToLower()
        foreach ($c in $candidates) {
            if ($c.Length -ge 4 -and ($procName -like "*$c*")) { return $true }
        }
        return $false
    }
    return @($processes | Select-Object -Unique ProcessName, Id)
}

# Start een winget-commando in achtergrond-runspace zodat de GUI niet bevriest
function Start-WinGetWork {
    param(
        [Parameter(Mandatory)][string[]]$WinGetArgs,
        [string]$BusyMessage,
        [Parameter(Mandatory)][scriptblock]$OnDone,  # ($exitCode, $output) on UI-thread
        [switch]$Elevated                            # If set, run winget elevated via UAC
    )

    if (-not $BusyMessage) { $BusyMessage = Get-Text 'Status.WorkingOn' -FormatArgs @($WinGetArgs[0]) }
    Set-Status $BusyMessage $true
    $Window.IsEnabled = $false

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript({
        param($a, $elev)
        if ($elev) {
            # Start elevated via UAC prompt; -Wait blocks until winget finishes.
            # Output is not captured for elevated runs (child process has its own
            # console). We only need the exit code.
            $joined = $a -join ' '
            try {
                $p = Start-Process -FilePath 'winget' -ArgumentList $joined `
                      -Verb RunAs -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
                return [PSCustomObject]@{ ExitCode = $p.ExitCode; Output = '' }
            } catch {
                # User cancelled UAC, or elevation otherwise failed
                # 1223 = ERROR_CANCELLED (user declined UAC)
                return [PSCustomObject]@{ ExitCode = 1223; Output = "$_" }
            }
        } else {
            $output = & winget @a 2>&1 | Out-String
            return [PSCustomObject]@{ ExitCode = $LASTEXITCODE; Output = $output }
        }
    }).AddArgument($WinGetArgs).AddArgument([bool]$Elevated)
    # Ensure UAC consent dialog shows on top instead of as a flashing taskbar button
    if ($Elevated) { Prepare-UacForeground }
    $handle = $ps.BeginInvoke()

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(300)

    $tickHandler = {
        if ($handle.IsCompleted) {
            $timer.Stop()
            $exit = -1; $output = ''
            try {
                $r = $ps.EndInvoke($handle) | Select-Object -First 1
                if ($r) { $exit = [int]$r.ExitCode; $output = "$($r.Output)" }
            } catch {
                Write-Log "Async error: $_" -Level ERROR -Source GUI
            } finally {
                $ps.Dispose(); $rs.Dispose()
            }
            # Log what winget actually returned. Without this the async path (used by
            # install/update/uninstall) leaves no trace, which makes a "succeeded but
            # nothing happened" report impossible to diagnose afterwards.
            Write-Log "winget exit $exit for: $($WinGetArgs -join ' ')" `
                      -Level $(if ($exit -eq 0) { 'INFO' } else { 'WARN' }) -Source GUI
            if ($exit -ne 0 -and $output) {
                $tail = ($output -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 5) -join ' | '
                if ($tail) { Write-Log "winget output: $tail" -Level WARN -Source GUI }
            }
            $Window.IsEnabled = $true
            # Refocus our window after elevated child finishes (UAC tends to steal focus)
            if ($Elevated) { Restore-AppForeground }
            try { & $OnDone $exit $output } catch { Write-Log "OnDone error: $_" -Level ERROR -Source GUI }
        }
    }.GetNewClosure()

    $timer.Add_Tick($tickHandler)
    $timer.Start()
}

function Run-Async {
    param([scriptblock]$Work, [scriptblock]$OnDone = {})
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.ThreadOptions  = 'ReuseThread'
    $rs.Open()

    $rs.SessionStateProxy.SetVariable('ScriptRoot',     $ScriptRoot)
    $rs.SessionStateProxy.SetVariable('Dispatcher',     $Window.Dispatcher)
    $rs.SessionStateProxy.SetVariable('LogCollection',  $LogCollection)
    $rs.SessionStateProxy.SetVariable('cfg',            $cfg)

    $ps = [powershell]::Create()
    $ps.Runspace = $rs

    $init = {
        Import-Module "$ScriptRoot\src\Core\Logging.psm1"     -Force
        Import-Module "$ScriptRoot\src\Core\Config.psm1"      -Force
        Import-Module "$ScriptRoot\src\Core\I18n.psm1"        -Force
        Import-Module "$ScriptRoot\src\Core\WinGet-Core.psm1" -Force
        Initialize-WinGetCore -WinGetPath $cfg.WinGetPath
        Set-LogObservable $LogCollection
    }
    $null = $ps.AddScript($init).AddScript($Work)
    $handle = $ps.BeginInvoke()

    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(200)
    $timer.Add_Tick({
        if ($handle.IsCompleted) {
            $timer.Stop()
            try   { $ps.EndInvoke($handle) }
            catch { Write-Log "Async error: $_" -Level ERROR -Source GUI }
            $ps.Dispose(); $rs.Dispose()
            $Window.Dispatcher.Invoke($OnDone)
        }
    })
    $timer.Start()
}

# ---------------------------------------------------------------------------
# Initialisatie UI-waarden
# ---------------------------------------------------------------------------

$TxtAppVersion.Text           = "v$(Get-AppVersion)"
$TxtWinGetVersionStatus.Text  = "WinGet v$(Get-WinGetVersion)"
$TxtLogPath.Text              = Get-LogPath

if (Test-IsAdmin) { $AdminBadge.Visibility = 'Visible' }

# Instellingen laden
$TxtSettingsLogDir.Text      = $cfg.LogDirectory
$TxtSettingsRetention.Text   = $cfg.LogRetentionDays
$TxtSettingsUpdateUrl.Text   = $cfg.SelfUpdateUrl
$ChkAutoUpdateCheck.IsChecked   = [bool]$cfg.AutoUpdateCheckOnStart
$ChkConfirmUninstall.IsChecked  = [bool]$cfg.ConfirmUninstall
$ChkConfirmUpdate.IsChecked     = [bool]$cfg.ConfirmUpdate

# Selecteer juiste ComboBox items
foreach ($item in $CmbSettingsLogLevel.Items) {
    if ($item.Content -eq $cfg.LogLevel) { $CmbSettingsLogLevel.SelectedItem = $item; break }
}
foreach ($item in $CmbSettingsScope.Items) {
    if ($item.Content -eq $cfg.DefaultScope) { $CmbSettingsScope.SelectedItem = $item; break }
}
$themePref = if ($cfg.Theme) { $cfg.Theme } else { 'Auto' }
foreach ($item in $CmbSettingsTheme.Items) {
    if ($item.Content -eq $themePref) { $CmbSettingsTheme.SelectedItem = $item; break }
}
# Taal: selecteer op basis van Tag (auto/nl-NL/en-US)
$langPref = if ($cfg.Language) { $cfg.Language } else { 'auto' }
foreach ($item in $CmbSettingsLanguage.Items) {
    if ($item.Tag -eq $langPref) { $CmbSettingsLanguage.SelectedItem = $item; break }
}

# Log binding + initiele startup-entries direct in collection
# (Write-Log werkt na deze regel ook gewoon voor alle latere events)
$GridLogs.ItemsSource = $LogCollection

# Voeg startup-info direct toe aan de collection - garandeert zichtbaarheid
foreach ($entry in @(
    @{ Lvl='INFO'; Src='GUI';        Msg="WinGet Manager v$(Get-AppVersion) started" }
    @{ Lvl='INFO'; Src='WinGetCore'; Msg="WinGet version: $(Get-WinGetVersion)" }
    @{ Lvl='INFO'; Src='GUI';        Msg="Theme: $ActiveTheme | Admin: $(Test-IsAdmin)" }
)) {
    $LogCollection.Add([PSCustomObject]@{
        Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')
        Level     = $entry.Lvl
        Source    = $entry.Src
        Message   = $entry.Msg
    })
}

Write-Log "GUI loaded" -Source GUI

# ---------------------------------------------------------------------------
# Zoekfunctionaliteit
# ---------------------------------------------------------------------------

# Search-as-you-type: debounce + async runspace per zoekopdracht
$Script:SearchDebounce = $null

function Invoke-LiveSearch {
    $query = $TxtSearch.Text.Trim()
    if (-not $query -or $query.Length -lt 2) {
        $GridSearch.ItemsSource = $null
        Set-Status (Get-Text 'Status.TypeMore')
        return
    }

    # Source filter uses .Tag (language-neutral): '' = all, 'winget', 'msstore'
    $src = if ($CmbSearchSource.SelectedItem) { $CmbSearchSource.SelectedItem.Tag } else { $null }
    if (-not $src) { $src = $null }

    Set-Status (Get-Text 'Status.Searching' -FormatArgs @($query)) $true

    # Lokale runspace - via closure gebonden aan deze specifieke zoekopdracht
    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript({
        param($q, $s)
        $a = @('search', $q, '--count', 50, '--accept-source-agreements', '--disable-interactivity')
        if ($s) { $a += @('--source', $s) }
        $output = & winget @a 2>&1 | Out-String
        return [PSCustomObject]@{ Output = $output; Query = $q }
    }).AddArgument($query).AddArgument($src)
    $handle = $ps.BeginInvoke()

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(200)
    $timer.Add_Tick({
        if (-not $handle.IsCompleted) { return }
        $timer.Stop()
        try {
            $r = $ps.EndInvoke($handle) | Select-Object -First 1

            # Negeer stale results als gebruiker inmiddels iets anders typt
            $current = $TxtSearch.Text.Trim()
            if ($r -and $r.Query -eq $current) {
                $lines = $r.Output -split "`r?`n"
                $results = @(Parse-PackageText $lines)
                $GridSearch.ItemsSource = $results
                Set-Status (Get-Text 'Status.SearchResults' -FormatArgs @($results.Count, $r.Query))
                if ($results.Count -eq 0) {
                    $EmptySearch.Text = Get-Text 'Search.NoResults' -FormatArgs @($r.Query)
                    $EmptySearch.Visibility = 'Visible'
                } else {
                    $EmptySearch.Visibility = 'Collapsed'
                }
            }
        } catch {
            Write-Log "Live search error: $_" -Level WARN -Source GUI
        } finally {
            try { $ps.Dispose() } catch {}
            try { $rs.Dispose() } catch {}
        }
    }.GetNewClosure())
    $timer.Start()
}

# TextChanged: debounce 400ms tussen toetsaanslagen
$TxtSearch.Add_TextChanged({
    # Reset empty-state bij elke wijziging
    if ($TxtSearch.Text.Trim().Length -lt 2) {
        $EmptySearch.Text = Get-Text 'Search.Empty'
        $EmptySearch.Visibility = 'Visible'
        $GridSearch.ItemsSource = $null
    }
    if ($Script:SearchDebounce) { $Script:SearchDebounce.Stop() }

    if (-not $TxtSearch.Text.Trim()) {
        $GridSearch.ItemsSource = $null
        Set-Status (Get-Text 'Status.Ready')
        return
    }

    if (-not $Script:SearchDebounce) {
        $Script:SearchDebounce = New-Object System.Windows.Threading.DispatcherTimer
        $Script:SearchDebounce.Interval = [TimeSpan]::FromMilliseconds(400)
        $Script:SearchDebounce.Add_Tick({
            $Script:SearchDebounce.Stop()
            Invoke-LiveSearch
        })
    }
    $Script:SearchDebounce.Start()
})

# Enter forceert directe search (bypass debounce)
$TxtSearch.Add_KeyDown({
    if ($_.Key -eq 'Return') {
        if ($Script:SearchDebounce) { $Script:SearchDebounce.Stop() }
        Invoke-LiveSearch
    }
})

# Search button doet hetzelfde als Enter
$BtnSearch.Add_Click({
    if ($Script:SearchDebounce) { $Script:SearchDebounce.Stop() }
    Invoke-LiveSearch
})

# Bron veranderen: live opnieuw zoeken als er een query is
$CmbSearchSource.Add_SelectionChanged({
    if ($TxtSearch.Text.Trim().Length -ge 2) { Invoke-LiveSearch }
})

$BtnClearSearch.Add_Click({
    if ($Script:SearchDebounce) { $Script:SearchDebounce.Stop() }
    $TxtSearch.Text = ''
    $GridSearch.ItemsSource = $null
    Set-Status (Get-Text 'Status.Ready')
})

$GridSearch.Add_SelectionChanged({
    $BtnInstallSelected.IsEnabled = $GridSearch.SelectedItem -ne $null
    $BtnShowDetails.IsEnabled     = $GridSearch.SelectedItem -ne $null
})

$BtnInstallSelected.Add_Click({
    $pkg = $GridSearch.SelectedItem
    if (-not $pkg) { return }
    if (-not (Ask-Confirm (Get-Text 'Dialog.ConfirmInstall' -FormatArgs @($pkg.Name, $pkg.Id)))) { return }

    $name = $pkg.Name; $id = $pkg.Id
    # Note: do NOT use `$args` here — it's a PowerShell automatic variable
    # (sender/event-args in scriptblocks) that PS resets to @() on every block entry.
    $cmdArgs = @('install','--id',$id,'--exact','--scope',$cfg.DefaultScope,
                 '--silent','--accept-source-agreements','--accept-package-agreements','--disable-interactivity')

    # Mirrors the update flow: retry elevated when winget reports it needs admin.
    # Without this, installing a machine-scope package (e.g. an MSI/wix installer
    # like paint.net) never prompts for UAC and quietly does nothing.
    $doInstall = $null
    $doInstall = {
        param([bool]$Elevated = $false)
        $workArgs = @{
            WinGetArgs  = $cmdArgs
            BusyMessage = (Get-Text 'Busy.Installing' -FormatArgs @($name))
        }
        if ($Elevated) { $workArgs.Elevated = $true }
        Start-WinGetWork @workArgs -OnDone {
            param($exit, $output)
            if ($exit -eq 0) {
                Refresh-Installed
                # Never claim success on the exit code alone: winget can return 0
                # without actually installing anything. Confirm the package really
                # shows up in the installed list before telling the user it worked.
                if (Test-PackageInstalled $id) {
                    Show-Info (Get-Text 'Dialog.InstallSuccess' -FormatArgs @($name))
                    Set-Status (Get-Text 'Status.InstallSuccess')
                } else {
                    Write-Log "Install of $id returned exit 0 but the package is not in the installed list" -Level WARN -Source GUI
                    Show-Error (Get-Text 'Dialog.InstallNotVerified' -FormatArgs @($name))
                    Set-Status (Get-Text 'Status.InstallFailed')
                }
                return
            }
            # User dismissed the UAC prompt
            if ($Elevated -and $exit -eq 1223) {
                Set-Status (Get-Text 'Status.InstallCancelled')
                return
            }
            $info = Get-WinGetErrorInfo $exit
            if ($info.Action -eq 'elevate' -and -not $Elevated) {
                if (Ask-Confirm (Get-Text 'Dialog.RequiresAdmin' -FormatArgs @($name))) {
                    Write-Log "Retrying install with elevation for $name" -Source GUI
                    & $doInstall -Elevated $true
                    return
                }
                Set-Status (Get-Text 'Status.InstallCancelled')
                return
            }
            Show-Error (Get-Text 'Dialog.InstallFailed' -FormatArgs @($info.Msg))
            Set-Status (Get-Text 'Status.InstallFailed')
        }.GetNewClosure()
    }.GetNewClosure()

    & $doInstall
})

$BtnShowDetails.Add_Click({
    $pkg = $GridSearch.SelectedItem
    if (-not $pkg) { return }
    Set-Status (Get-Text 'Status.FetchingDetails') $true
    try {
        $info = Get-WinGetPackageInfo -Id $pkg.Id
        $msg  = Get-Text 'Details.Format' -FormatArgs @($info.Name, $info.Id, $info.Version, $info.Publisher, $info.Source)
        [System.Windows.MessageBox]::Show($msg, (Get-Text 'Dialog.Title.Details'), "OK", "Information") | Out-Null
        Set-Status (Get-Text 'Status.Ready')
    } catch {
        Set-Status (Get-Text 'Status.DetailsError')
    }
})

# ---------------------------------------------------------------------------
# Geïnstalleerde packages
# ---------------------------------------------------------------------------

$Script:AllInstalled = @()

function Test-PackageInstalled {
    <#
        Returns $true when $Id appears in the currently loaded Installed grid.
        Call this AFTER Refresh-Installed so the list reflects reality. Used to
        verify an install actually landed, because a winget exit code of 0 does
        not by itself prove anything was installed.
    #>
    param([Parameter(Mandatory)][string]$Id)
    $items = $GridInstalled.ItemsSource
    if (-not $items) { return $false }
    foreach ($item in $items) {
        if ($item.Id -and $item.Id -eq $Id) { return $true }
    }
    return $false
}

function Refresh-Installed {
    Set-Status (Get-Text 'Status.LoadingInstalledPkgs') $true
    $GridInstalled.ItemsSource = $null
    try {
        $installed = Get-WinGetInstalled
        $updates   = @()
        try { $updates = Get-WinGetUpdates } catch { Write-Log "Failed to fetch updates: $_" -Level WARN -Source GUI }

        # Index updates op Id voor snelle lookup
        $updateMap = @{}
        foreach ($u in $updates) {
            if ($u.Id) { $updateMap[$u.Id] = $u }
        }

        # Enrich installed packages with AvailableVersion, HasUpdate flag, and status text.
        # Status logic:
        #   - HasUpdate         → "↑ Update"
        #   - Source winget/msstore (verifiable, no update found) → "Up-to-date"
        #   - Source local/'' (ARP — not checkable through winget)  → "Unknown"
        # We can't honestly claim "Up-to-date" for local/ARP packages because winget
        # never queries their upstream — they may well have updates available outside
        # winget's view.
        $merged = foreach ($pkg in $installed) {
            $avail = ''
            $hasUpdate = $false
            if ($pkg.Id -and $updateMap.ContainsKey($pkg.Id)) {
                $avail = $updateMap[$pkg.Id].AvailableVersion
                if ($avail -and $avail -ne $pkg.Version) { $hasUpdate = $true }
            }
            $statusText = if ($hasUpdate) {
                Get-Text 'Status.UpdateAvailable'
            } elseif ($pkg.Source -in @('winget','msstore')) {
                Get-Text 'Status.UpToDate'
            } else {
                Get-Text 'Status.Unknown'
            }
            [PSCustomObject]@{
                Name             = $pkg.Name
                Id               = $pkg.Id
                Version          = $pkg.Version
                AvailableVersion = $avail
                Source           = $pkg.Source
                HasUpdate        = $hasUpdate
                StatusText       = $statusText
            }
        }

        # Sorteer: items met update beschikbaar bovenaan, daarna alfabetisch op naam
        $Script:AllInstalled = @($merged | Where-Object { $_ } | Sort-Object @{ Expression = 'HasUpdate'; Descending = $true }, Name)
        Apply-InstalledFilter
        $count = $Script:AllInstalled.Count
        $upgradable = @($Script:AllInstalled | Where-Object { $_.HasUpdate }).Count
        $TxtInstalledCount.Text = Get-Text 'Status.InstalledCount' -FormatArgs @($count, $upgradable)
        if ($count -gt 0) {
            $BadgeInstalledText.Text = "$count"
            $BadgeInstalled.Visibility = 'Visible'
        } else {
            $BadgeInstalled.Visibility = 'Collapsed'
        }
        if ($count -eq 0) {
            $EmptyInstalled.Text = Get-Text 'Status.NoPackagesFound'
            $EmptyInstalled.Visibility = 'Visible'
        } else {
            $EmptyInstalled.Visibility = 'Collapsed'
        }
        Write-Log "Installed loaded: $count ($upgradable with update)" -Source GUI
        Set-Status (Get-Text 'Status.Ready')
    } catch {
        Set-Status (Get-Text 'Status.Error')
        Show-Error (Get-Text 'Dialog.LoadFailed' -FormatArgs @("$_"))
        Write-Log "Loading installed failed: $_" -Level ERROR -Source GUI
    }
}

function Apply-InstalledFilter {
    $filter = $TxtFilterInstalled.Text.Trim().ToLower()
    if (-not $filter) {
        $GridInstalled.ItemsSource = @($Script:AllInstalled)
    } else {
        $GridInstalled.ItemsSource = @($Script:AllInstalled | Where-Object {
            $_.Name -like "*$filter*" -or $_.Id -like "*$filter*"
        })
    }
}

$BtnRefreshInstalled.Add_Click({ Refresh-Installed })
$TxtFilterInstalled.Add_TextChanged({ Apply-InstalledFilter })

$GridInstalled.Add_SelectionChanged({
    $items = @($GridInstalled.SelectedItems)
    $count = $items.Count
    $BtnUninstallSelected.IsEnabled = ($count -gt 0)

    # Update-knop: actief als minstens 1 geselecteerd item een update heeft
    $hasUpgradeable = $items | Where-Object { $_.HasUpdate } | Select-Object -First 1
    $BtnUpdateSelectedInstalled.IsEnabled = ($null -ne $hasUpgradeable)

    if ($count -gt 1) {
        $BtnUninstallSelected.Content = Get-Text 'Btn.UninstallWithCount' -FormatArgs @($count)
        $upgradeCount = @($items | Where-Object { $_.HasUpdate }).Count
        if ($upgradeCount -gt 0) {
            $BtnUpdateSelectedInstalled.Content = "⬆ Update geselecteerde ($upgradeCount)"
        } else {
            $BtnUpdateSelectedInstalled.Content = Get-Text 'Btn.UpdateSelectedInst'
        }
    } else {
        $BtnUninstallSelected.Content = Get-Text 'Btn.Uninstall'
        $BtnUpdateSelectedInstalled.Content = Get-Text 'Btn.UpdateSelectedInst'
    }
})

$BtnUninstallSelected.Add_Click({
    $selected = @($GridInstalled.SelectedItems)
    if ($selected.Count -eq 0) { return }

    if ($selected.Count -eq 1) {
        $pkg = $selected[0]
        if ($cfg.ConfirmUninstall) {
            if (-not (Ask-ConfirmEx -Message (Get-Text 'Dialog.ConfirmUninstallSingle' -FormatArgs @($pkg.Name)) `
                                    -Title (Get-Text 'Title.UninstallPackage') `
                                    -ConfigKeyToDisable 'ConfirmUninstall')) { return }
        }
        Start-SingleUninstall -PackageId $pkg.Id -PackageName $pkg.Name
    } else {
        $names = ($selected | ForEach-Object { "  - $($_.Name)" }) -join "`n"
        if (-not (Ask-ConfirmEx -Message (Get-Text 'Dialog.ConfirmBulkUninstall' -FormatArgs @($selected.Count, $names)) `
                                -Title (Get-Text 'Title.BulkUninstall') `
                                -ConfigKeyToDisable 'ConfirmUninstall')) { return }
        Start-BulkUninstall -Packages $selected
    }
})

function Start-SingleUninstall {
    param([string]$PackageId, [string]$PackageName)

    $cmdArgs = @('uninstall','--id',$PackageId,'--exact','--silent','--disable-interactivity')

    $doUninstall = $null
    $doUninstall = {
        param([bool]$AfterKill = $false)
        Start-WinGetWork -WinGetArgs $cmdArgs -BusyMessage (Get-Text 'Busy.Uninstalling' -FormatArgs @($PackageName)) -OnDone {
            param($exit, $output)
            if ($exit -eq 0) {
                Set-Status (Get-Text 'Status.Uninstalled')
                Refresh-Installed
                return
            }
            $info = Get-WinGetErrorInfo $exit
            if ($info.Action -eq 'kill' -and -not $AfterKill) {
                $procs = Find-RelatedProcesses -PackageId $PackageId -PackageName $PackageName
                if ($procs.Count -gt 0) {
                    $procList = ($procs | ForEach-Object { "$($_.ProcessName) (PID $($_.Id))" }) -join "`n  - "
                    if (Ask-Confirm (Get-Text 'Dialog.UninstallStillRunning' -FormatArgs @($PackageName, $procList))) {
                        $procs | ForEach-Object { try { Stop-Process -Id $_.Id -Force -ErrorAction Stop } catch {} }
                        Start-Sleep -Seconds 2
                        & $doUninstall -AfterKill $true
                        return
                    }
                }
            }
            Show-Error (Get-Text 'Dialog.UninstallFailed' -FormatArgs @($PackageName, $info.Msg))
            Set-Status (Get-Text 'Status.Failed')
        }.GetNewClosure()
    }.GetNewClosure()

    & $doUninstall
}

function Start-BulkUninstall {
    param([array]$Packages)

    $UpdateProgress.Visibility = 'Visible'
    $Window.IsEnabled = $false

    $progress = [hashtable]::Synchronized(@{
        Current = 0; Total = $Packages.Count; CurrentName = ''; Done = $false
        Ok = 0; Fail = 0; FailedNames = @()
        NeedsAdmin = @()
        Failures   = @()   # [PSCustomObject]@{Id, Name, Exit} - logged on the UI thread
    })

    $pkgInfo = @($Packages | ForEach-Object { [PSCustomObject]@{ Id = $_.Id; Name = $_.Name } })

    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('progress', $progress)
    $rs.SessionStateProxy.SetVariable('packages', $pkgInfo)

    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript({
        foreach ($pkg in $packages) {
            $progress.Current++
            $progress.CurrentName = $pkg.Name
            $a = @('uninstall','--id',$pkg.Id,'--exact','--silent','--disable-interactivity')
            $null = & winget @a 2>&1
            $ec = $LASTEXITCODE
            if ($ec -eq 0) { $progress.Ok++ }
            else {
                $progress.Fail++; $progress.FailedNames += $pkg.Name
                $progress.Failures += [PSCustomObject]@{ Id = $pkg.Id; Name = $pkg.Name; Exit = $ec }
                if ($ec -eq -1978334969) {
                    $progress.NeedsAdmin += [PSCustomObject]@{ Id = $pkg.Id; Name = $pkg.Name }
                }
            }
        }
        $progress.Done = $true
    })
    $handle = $ps.BeginInvoke()

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(400)
    $timer.Add_Tick({
        if ($progress.Current -gt 0 -and -not $progress.Done) {
            $TxtStatus.Text = Get-Text 'Status.Uninstalling' -FormatArgs @($progress.Current, $progress.Total, $progress.CurrentName)
        }
        if ($progress.Done) {
            $timer.Stop()
            try { $ps.EndInvoke($handle) | Out-Null } catch {}
            $ps.Dispose(); $rs.Dispose()
            $UpdateProgress.Visibility = 'Collapsed'
            $Window.IsEnabled = $true
            Refresh-Installed
            $msg = Get-Text 'BulkResult.Uninstall' -FormatArgs @($progress.Ok, $progress.Fail)
            Set-Status $msg

            # Log the outcome (Write-Log is unavailable inside the runspace, so the
            # per-package exit codes are collected there and written out here).
            Write-Log "Bulk uninstall finished: $($progress.Ok) ok, $($progress.Fail) failed (of $($progress.Total))" -Source GUI
            foreach ($f in $progress.Failures) {
                Write-Log "Bulk uninstall failed: $($f.Name) [$($f.Id)] exit $($f.Exit)" -Level WARN -Source GUI
            }

            if ($progress.NeedsAdmin.Count -gt 0) {
                $names = ($progress.NeedsAdmin | ForEach-Object { $_.Name }) -join "`n  - "
                if (Ask-Confirm (Get-Text 'Dialog.BulkNeedsAdmin' -FormatArgs @($progress.NeedsAdmin.Count, $names))) {
                    Set-Status (Get-Text 'Status.RetryingElevated') $true
                    $Window.IsEnabled = $false
                    Start-ElevatedWinGetBatch -PackageIds ($progress.NeedsAdmin | ForEach-Object { $_.Id }) -Operation 'uninstall' -OnDone {
                        param($okCount, $failCount, $cancelled)
                        $Window.IsEnabled = $true
                        Refresh-Installed
                        if ($cancelled) {
                            Set-Status (Get-Text 'Status.UpdateCancelled')
                        } else {
                            Set-Status (Get-Text 'BulkResult.Uninstall' -FormatArgs @($okCount, $failCount))
                        }
                    }
                    return
                }
            }

            if ($progress.Fail -gt 0) {
                Show-Info (Get-Text 'Dialog.SomeFailed' -FormatArgs @($msg, ($progress.FailedNames -join ', ')))
            }
        }
    }.GetNewClosure())
    $timer.Start()
}

$BtnUpdateSelectedInstalled.Add_Click({
    $selected = @($GridInstalled.SelectedItems | Where-Object { $_.HasUpdate })
    if ($selected.Count -eq 0) {
        Show-Info (Get-Text 'Dialog.NoUpdatesForSelection')
        return
    }
    if ($selected.Count -eq 1) {
        if ($cfg.ConfirmUpdate) {
            if (-not (Ask-ConfirmEx -Message (Get-Text 'Dialog.ConfirmUpdateSinglePkg' -FormatArgs @($selected[0].Name, $selected[0].AvailableVersion)) `
                                    -Title (Get-Text 'Title.UpdatePackage') `
                                    -ConfigKeyToDisable 'ConfirmUpdate')) { return }
        }
        Start-SingleUpdate -PackageId $selected[0].Id -PackageName $selected[0].Name
    } else {
        $names = ($selected | ForEach-Object { "  - $($_.Name)" }) -join "`n"
        if ($cfg.ConfirmUpdate) {
            if (-not (Ask-ConfirmEx -Message (Get-Text 'Dialog.ConfirmUpdateMultiple' -FormatArgs @($selected.Count, $names)) `
                                    -Title (Get-Text 'Title.BulkUpdate') `
                                    -ConfigKeyToDisable 'ConfirmUpdate')) { return }
        } else {
            if (-not (Ask-Confirm (Get-Text 'Dialog.ConfirmUpdateMultiple' -FormatArgs @($selected.Count, $names)))) { return }
        }
        Start-BulkUpdate -Packages $selected
    }
})

function Start-SingleUpdate {
    param([string]$PackageId, [string]$PackageName)

    $cmdArgs = @('upgrade','--id',$PackageId,'--exact','--silent',
                 '--accept-source-agreements','--accept-package-agreements','--disable-interactivity')

    $doUpdate = $null
    $doUpdate = {
        param([bool]$AfterKill = $false, [bool]$Elevated = $false)
        $workArgs = @{
            WinGetArgs  = $cmdArgs
            BusyMessage = (Get-Text 'Busy.Updating' -FormatArgs @($PackageName))
        }
        if ($Elevated) { $workArgs.Elevated = $true }
        Start-WinGetWork @workArgs -OnDone {
            param($exit, $output)
            if ($exit -eq 0) {
                Set-Status (Get-Text 'Status.UpdateSuccessName' -FormatArgs @($PackageName))
                Refresh-Installed
                return
            }
            # User cancelled UAC prompt
            if ($Elevated -and $exit -eq 1223) {
                Set-Status (Get-Text 'Status.UpdateCancelled')
                return
            }
            $info = Get-WinGetErrorInfo $exit
            if ($info.Action -eq 'kill' -and -not $AfterKill) {
                $procs = Find-RelatedProcesses -PackageId $PackageId -PackageName $PackageName
                if ($procs.Count -gt 0) {
                    $procList = ($procs | ForEach-Object { "$($_.ProcessName) (PID $($_.Id))" }) -join "`n  - "
                    if (Ask-Confirm (Get-Text 'Dialog.UpdateStillRunning' -FormatArgs @($PackageName, $procList))) {
                        Write-Log "Closing and retrying: $($procs.Count) processes for $PackageName" -Source GUI
                        $procs | ForEach-Object { try { Stop-Process -Id $_.Id -Force -ErrorAction Stop } catch {} }
                        Start-Sleep -Seconds 2
                        & $doUpdate -AfterKill $true -Elevated $Elevated
                        return
                    }
                }
            } elseif ($info.Action -eq 'elevate' -and -not $Elevated) {
                # Auto-offer elevation via UAC. User confirms → retry with -Verb RunAs.
                if (Ask-Confirm (Get-Text 'Dialog.RequiresAdmin' -FormatArgs @($PackageName))) {
                    Write-Log "Retrying update with elevation for $PackageName" -Source GUI
                    & $doUpdate -AfterKill $AfterKill -Elevated $true
                    return
                }
                Set-Status (Get-Text 'Status.UpdateCancelled')
                return
            }
            Show-Error (Get-Text 'Dialog.UpdateFailedDetailed' -FormatArgs @($PackageName, $info.Msg))
            Set-Status (Get-Text 'Status.UpdateFailedShort')
        }.GetNewClosure()
    }.GetNewClosure()

    & $doUpdate
}

# ---------------------------------------------------------------------------
# Updates tab
# ---------------------------------------------------------------------------

$Script:UpdateablePackages = @()

function Refresh-Updates {
    Set-Status (Get-Text 'Status.CheckingUpdates') $true
    $TxtUpdateCount.Text = "..."
    $GridUpdates.ItemsSource = $null
    try {
        $raw = Get-WinGetUpdates
        $Script:UpdateablePackages = @($raw | ForEach-Object {
            $_ | Add-Member -NotePropertyName Selected -NotePropertyValue $false -PassThru
        })
        $GridUpdates.ItemsSource = @($Script:UpdateablePackages)
        $count = $Script:UpdateablePackages.Count
        $TxtUpdateCount.Text     = $count
        $TxtWinGetVersion.Text   = Get-WinGetVersion
        $BtnUpdateSelected.IsEnabled = $count -gt 0
        if ($count -gt 0) {
            $BadgeUpdatesText.Text = "$count"
            $BadgeUpdates.Visibility = 'Visible'
        } else {
            $BadgeUpdates.Visibility = 'Collapsed'
        }
        if ($count -eq 0) {
            $EmptyUpdates.Visibility = 'Visible'
        } else {
            $EmptyUpdates.Visibility = 'Collapsed'
        }
        Set-Status (Get-Text 'Status.UpdatesFound' -FormatArgs @($count))
        Write-Log "Updates: $count" -Source GUI
    } catch {
        Set-Status (Get-Text 'Status.CheckError')
        $TxtUpdateCount.Text = "!"
        Write-Log "Update check error: $_" -Level ERROR -Source GUI
    }
}

$BtnRefreshUpdates.Add_Click({ Refresh-Updates })

$BtnUpdateAll.Add_Click({
    $count = $Script:UpdateablePackages.Count
    if ($count -eq 0) { Show-Info (Get-Text 'Dialog.NoUpdatesAvailable'); return }
    if ($cfg.ConfirmUpdate) {
        if (-not (Ask-ConfirmEx -Message (Get-Text 'Dialog.ConfirmUpdateAll' -FormatArgs @($count)) `
                                -Title (Get-Text 'Title.UpdateAll') `
                                -ConfigKeyToDisable 'ConfirmUpdate')) { return }
    } else {
        if (-not (Ask-Confirm (Get-Text 'Dialog.ConfirmUpdateAll' -FormatArgs @($count)))) { return }
    }
    Start-BulkUpdate -Packages $Script:UpdateablePackages
})

$BtnUpdateSelected.Add_Click({
    $selected = @($Script:UpdateablePackages | Where-Object { $_.Selected })
    # Fallback: if no checkboxes ticked but a row is row-selected (highlighted
    # blue), use that row. Convenient for the common case of 1 update.
    if ($selected.Count -eq 0 -and $GridUpdates.SelectedItem) {
        $selected = @($GridUpdates.SelectedItem)
    }
    if ($selected.Count -eq 0) {
        Show-Info (Get-Text 'Dialog.SelectFirst')
        return
    }
    if ($cfg.ConfirmUpdate) {
        if (-not (Ask-ConfirmEx -Message (Get-Text 'Dialog.ConfirmUpdateSelected' -FormatArgs @($selected.Count)) `
                                -Title (Get-Text 'Title.UpdateSelection') `
                                -ConfigKeyToDisable 'ConfirmUpdate')) { return }
    } else {
        if (-not (Ask-Confirm (Get-Text 'Dialog.ConfirmUpdateSelected' -FormatArgs @($selected.Count)))) { return }
    }
    Start-BulkUpdate -Packages $selected
})

# Gemeenschappelijke helper: update meerdere packages met live progress
function Start-BulkUpdate {
    param(
        [array]$Packages,
        [switch]$Elevated   # internal: set when re-entering with admin rights
    )

    $total = $Packages.Count
    if ($total -eq 0) { return }

    $UpdateProgress.Visibility = 'Visible'
    $Window.IsEnabled = $false
    Set-Status (Get-Text $(if ($Elevated) { 'Status.RetryingElevated' } else { 'Status.Preparing' })) $true

    # Synchronized hashtable: shared between runspace and UI-thread.
    # NeedsAdmin tracks packages that returned the "elevation required" exit code
    # so we can offer a single batched UAC retry at the end.
    $progress = [hashtable]::Synchronized(@{
        Current     = 0
        Total       = $total
        CurrentName = ''
        Done        = $false
        Ok          = 0
        Fail        = 0
        FailedNames = @()
        NeedsAdmin  = @()    # array of [PSCustomObject]@{Id, Name} that failed with -1978334969
        # Per-package exit codes for failures. Write-Log does not exist inside the
        # runspace, so we collect here and log from the UI thread when the batch ends.
        Failures    = @()    # array of [PSCustomObject]@{Id, Name, Exit}
    })

    $pkgInfo = @($Packages | ForEach-Object {
        [PSCustomObject]@{ Id = $_.Id; Name = $_.Name }
    })

    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('progress', $progress)
    $rs.SessionStateProxy.SetVariable('packages', $pkgInfo)
    $rs.SessionStateProxy.SetVariable('useElevated', [bool]$Elevated)

    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript({
        foreach ($pkg in $packages) {
            $progress.Current++
            $progress.CurrentName = $pkg.Name
            $a = @('upgrade','--id',$pkg.Id,'--exact','--silent',
                   '--accept-source-agreements','--accept-package-agreements','--disable-interactivity')
            if ($useElevated) {
                # Single UAC prompt has already been accepted at the start of this
                # elevated batch (the runspace itself is unelevated, but we spawn
                # winget elevated per package). To get ONE prompt total, we instead
                # spawn one elevated cmd that loops through all packages.
                # But that's done by the caller — at runspace level we just call winget normally.
                $null = & winget @a 2>&1
            } else {
                $null = & winget @a 2>&1
            }
            $ec = $LASTEXITCODE
            if ($ec -eq 0) {
                $progress.Ok++
            } else {
                $progress.Fail++
                $progress.FailedNames += $pkg.Name
                $progress.Failures += [PSCustomObject]@{ Id = $pkg.Id; Name = $pkg.Name; Exit = $ec }
                if ($ec -eq -1978334969) {
                    $progress.NeedsAdmin += [PSCustomObject]@{ Id = $pkg.Id; Name = $pkg.Name }
                }
            }
        }
        $progress.Done = $true
    })
    $handle = $ps.BeginInvoke()

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(400)
    $timer.Add_Tick({
        if ($progress.Current -gt 0 -and -not $progress.Done) {
            $TxtStatus.Text = Get-Text 'Status.UpdatingProgress' -FormatArgs @($progress.Current, $progress.Total, $progress.CurrentName)
        }
        if ($progress.Done) {
            $timer.Stop()
            try { $ps.EndInvoke($handle) | Out-Null } catch {}
            $ps.Dispose(); $rs.Dispose()
            $UpdateProgress.Visibility = 'Collapsed'
            $Window.IsEnabled = $true
            Refresh-Updates
            Refresh-Installed
            $msg = Get-Text 'BulkResult.Update'    -FormatArgs @($progress.Ok, $progress.Fail)
            Set-Status $msg

            # Log the outcome. Without this a "3 of 12 failed" result leaves no
            # record of WHICH packages failed or why.
            Write-Log "Bulk update finished: $($progress.Ok) ok, $($progress.Fail) failed (of $($progress.Total))" -Source GUI
            foreach ($f in $progress.Failures) {
                Write-Log "Bulk update failed: $($f.Name) [$($f.Id)] exit $($f.Exit)" -Level WARN -Source GUI
            }

            # If some failed with "needs admin", offer one batched UAC retry.
            # We skip this branch if we're already in the elevated run.
            if (-not $Elevated -and $progress.NeedsAdmin.Count -gt 0) {
                $names = ($progress.NeedsAdmin | ForEach-Object { $_.Name }) -join "`n  - "
                if (Ask-Confirm (Get-Text 'Dialog.BulkNeedsAdmin' -FormatArgs @($progress.NeedsAdmin.Count, $names))) {
                    # Single UAC prompt: launch one elevated winget per package via
                    # a runspace; Windows merges them since they're spawned in quick
                    # succession from the elevated parent of `runas`. Simpler approach:
                    # spawn one elevated cmd that runs winget for each package in sequence.
                    Set-Status (Get-Text 'Status.RetryingElevated') $true
                    $Window.IsEnabled = $false
                    Start-ElevatedWinGetBatch -PackageIds ($progress.NeedsAdmin | ForEach-Object { $_.Id }) -Operation 'upgrade' -OnDone {
                        param($okCount, $failCount, $cancelled)
                        $Window.IsEnabled = $true
                        Refresh-Updates
                        Refresh-Installed
                        if ($cancelled) {
                            Set-Status (Get-Text 'Status.UpdateCancelled')
                        } else {
                            Set-Status (Get-Text 'BulkResult.Update' -FormatArgs @($okCount, $failCount))
                        }
                    }
                    return
                }
            }

            if ($progress.Fail -gt 0) {
                $failed = $progress.FailedNames -join ", "
                Show-Info (Get-Text 'Dialog.SomeFailed' -FormatArgs @($msg, $failed))
            }
        }
    }.GetNewClosure())
    $timer.Start()
}

# Run a list of package IDs through one elevated winget batch (one UAC prompt).
# Uses cmd.exe so we can chain multiple `winget upgrade` calls in one elevated session.
function Start-ElevatedWinGetBatch {
    param(
        [Parameter(Mandatory)][string[]]$PackageIds,
        [ValidateSet('upgrade','uninstall')][string]$Operation = 'upgrade',
        [Parameter(Mandatory)][scriptblock]$OnDone   # ($okCount, $failCount, $cancelled) on UI thread
    )

    if (-not $PackageIds -or $PackageIds.Count -eq 0) {
        & $OnDone 0 0 $false; return
    }

    # Each line writes its exit code to a marker file, so we can count successes after.
    $resultFile = [System.IO.Path]::GetTempFileName()
    $opArgs = if ($Operation -eq 'upgrade') {
        '--exact --silent --accept-source-agreements --accept-package-agreements --disable-interactivity'
    } else {
        '--exact --silent --disable-interactivity'
    }
    # Build a single cmd-line that runs all the winget commands and logs results.
    # Each line appends "OK <id>" or "FAIL <id> <exitcode>" to $resultFile.
    $lines = foreach ($id in $PackageIds) {
        # Note: cmd's %errorlevel% expands at runtime
        "winget $Operation --id `"$id`" $opArgs && echo OK $id>>`"$resultFile`" || echo FAIL $id %errorlevel%>>`"$resultFile`""
    }
    $cmdLine = '/d /c "MODE CON: COLS=250 LINES=3000 >nul 2>&1 & ' + ($lines -join ' & ') + '"'

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript({
        param($cmd, $marker)
        try {
            $p = Start-Process -FilePath 'cmd.exe' -ArgumentList $cmd `
                  -Verb RunAs -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
            return [PSCustomObject]@{ Cancelled = $false; ExitCode = $p.ExitCode }
        } catch {
            # User cancelled UAC
            return [PSCustomObject]@{ Cancelled = $true; ExitCode = 1223 }
        }
    }).AddArgument($cmdLine).AddArgument($resultFile)
    # Make UAC consent dialog show on top
    Prepare-UacForeground
    $handle = $ps.BeginInvoke()

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)
    $timer.Add_Tick({
        if ($handle.IsCompleted) {
            $timer.Stop()
            $result = $null
            try { $result = $ps.EndInvoke($handle) | Select-Object -First 1 } catch {}
            $ps.Dispose(); $rs.Dispose()
            $okCount = 0; $failCount = 0
            $cancelled = if ($result) { $result.Cancelled } else { $true }
            if (Test-Path $resultFile) {
                foreach ($l in Get-Content $resultFile) {
                    if ($l -match '^OK ')   { $okCount++ }
                    if ($l -match '^FAIL ') { $failCount++ }
                }
                Remove-Item $resultFile -Force -ErrorAction SilentlyContinue
            }
            # Refocus our window after elevated batch completes
            Restore-AppForeground
            try { & $OnDone $okCount $failCount $cancelled } catch { Write-Log "Batch OnDone error: $_" -Level ERROR -Source GUI }
        }
    }.GetNewClosure())
    $timer.Start()
}

# ---------------------------------------------------------------------------
# Import / Export
# ---------------------------------------------------------------------------

$BtnBrowseExport.Add_Click({
    $dlg = [Microsoft.Win32.SaveFileDialog]::new()
    $dlg.Filter        = "JSON bestanden (*.json)|*.json"
    $dlg.DefaultExt    = "json"
    $dlg.FileName      = "winget-packages-$(Get-Date -Format 'yyyy-MM-dd')"
    if ($dlg.ShowDialog()) { $TxtExportPath.Text = $dlg.FileName }
})

$BtnBrowseImport.Add_Click({
    $dlg = [Microsoft.Win32.OpenFileDialog]::new()
    $dlg.Filter = "JSON bestanden (*.json)|*.json"
    if ($dlg.ShowDialog()) { $TxtImportPath.Text = $dlg.FileName }
})

$BtnExport.Add_Click({
    $path = $TxtExportPath.Text.Trim()
    if (-not $path) { Show-Info (Get-Text 'Dialog.NoExportPath'); return }
    Set-Status (Get-Text 'Status.Exporting') $true
    try {
        $ok = Export-WinGetPackages -OutputPath $path
        if ($ok) { Show-Info (Get-Text 'Dialog.ExportSuccess' -FormatArgs @($path)) } else { Show-Error (Get-Text 'Dialog.ExportFailed') }
        Set-Status $(if($ok){(Get-Text 'Status.ExportSuccess')}else{(Get-Text 'Status.ExportFailed')})
    } catch {
        Show-Error (Get-Text 'Dialog.GenericError' -FormatArgs @("$_"))
        Set-Status (Get-Text 'Status.Error')
    }
})

$BtnImport.Add_Click({
    $path = $TxtImportPath.Text.Trim()
    if (-not $path -or -not (Test-Path $path)) { Show-Info (Get-Text 'Dialog.SelectImportFile'); return }
    if (-not (Ask-Confirm (Get-Text 'Dialog.ConfirmImport' -FormatArgs @($path)))) { return }
    Set-Status (Get-Text 'Status.Importing') $true
    try {
        $ok = Import-WinGetPackages -InputPath $path -IgnoreUnavailable:$ChkIgnoreUnavailable.IsChecked
        if ($ok) { Show-Info (Get-Text 'Dialog.ImportSuccess') } else { Show-Error (Get-Text 'Dialog.ImportFailed') }
        Set-Status $(if($ok){(Get-Text 'Status.ImportSuccess')}else{(Get-Text 'Status.ImportWithErrors')})
    } catch {
        Show-Error (Get-Text 'Dialog.GenericError' -FormatArgs @("$_"))
        Set-Status (Get-Text 'Status.Error')
    }
})

# ---------------------------------------------------------------------------
# Bronnen
# ---------------------------------------------------------------------------

function Refresh-Sources {
    $GridSources.ItemsSource = $null
    try {
        $sources = @(Get-WinGetSources)
        $GridSources.ItemsSource = $sources
        $count = $sources.Count
        if ($count -gt 0) {
            $BadgeSourcesText.Text = "$count"
            $BadgeSources.Visibility = 'Visible'
        } else {
            $BadgeSources.Visibility = 'Collapsed'
        }
        if ($count -eq 0) {
            $EmptySources.Visibility = 'Visible'
        } else {
            $EmptySources.Visibility = 'Collapsed'
        }
        Set-Status (Get-Text 'Status.SourcesLoaded')
    } catch {
        Write-Log "Loading sources failed: $_" -Level ERROR -Source GUI
    }
}

$BtnRefreshSources.Add_Click({ Refresh-Sources })

$GridSources.Add_SelectionChanged({
    $BtnRemoveSource.IsEnabled = $GridSources.SelectedItem -ne $null
})

$BtnAddSource.Add_Click({
    $name = $TxtSourceName.Text.Trim()
    $url  = $TxtSourceUrl.Text.Trim()
    $type = $CmbSourceType.SelectedItem.Content
    if (-not $name -or -not $url) { Show-Info (Get-Text 'Dialog.NameUrlRequired'); return }
    Set-Status (Get-Text 'Status.AddingSource') $true
    try {
        $ok = Add-WinGetSource -Name $name -Url $url -Type $type
        if ($ok) {
            $TxtSourceName.Text = ''; $TxtSourceUrl.Text = ''
            Refresh-Sources
        } else {
            Show-Error (Get-Text 'Dialog.AddSourceFailed')
        }
        Set-Status $(if($ok){(Get-Text 'Status.SourceAdded')}else{(Get-Text 'Status.Failed')})
    } catch {
        Show-Error (Get-Text 'Dialog.GenericError' -FormatArgs @("$_")); Set-Status (Get-Text 'Status.Error')
    }
})

$BtnRemoveSource.Add_Click({
    $src = $GridSources.SelectedItem
    if (-not $src) { return }
    if (-not (Ask-Confirm (Get-Text 'Dialog.ConfirmRemoveSource' -FormatArgs @($src.Name)))) { return }
    try {
        $ok = Remove-WinGetSource -Name $src.Name
        if ($ok) { Refresh-Sources } else { Show-Error (Get-Text 'Dialog.RemoveSourceFailed') }
    } catch {
        Show-Error (Get-Text 'Dialog.GenericError' -FormatArgs @("$_"))
    }
})

$BtnResetSources.Add_Click({
    if (-not (Ask-Confirm (Get-Text 'Dialog.ConfirmResetSources'))) { return }
    try {
        $ok = Reset-WinGetSources
        if ($ok) { Refresh-Sources; Show-Info (Get-Text 'Dialog.SourcesReset') } else { Show-Error (Get-Text 'Dialog.ResetFailed') }
    } catch {
        Show-Error (Get-Text 'Dialog.GenericError' -FormatArgs @("$_"))
    }
})

# ---------------------------------------------------------------------------
# Logs
# ---------------------------------------------------------------------------

$CmbLogFilter.Add_SelectionChanged({
    # Use .Tag (language-neutral): '' = all, 'DEBUG'/'INFO'/'WARN'/'ERROR' = filter
    $filter = if ($CmbLogFilter.SelectedItem) { $CmbLogFilter.SelectedItem.Tag } else { '' }
    if (-not $filter) {
        $GridLogs.ItemsSource = $LogCollection
    } else {
        $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($LogCollection)
        $view.Filter = [Predicate[object]]{ param($item) $item.Level -eq $filter }
        $GridLogs.ItemsSource = $view
    }
})

$BtnClearLogs.Add_Click({
    if (Ask-Confirm (Get-Text 'Dialog.ConfirmClearLogs')) {
        $LogCollection.Clear()
    }
})

$BtnOpenLogFile.Add_Click({
    $logPath = Get-LogPath
    if ($logPath -and (Test-Path $logPath)) {
        Start-Process notepad.exe -ArgumentList $logPath
    } else {
        Show-Info (Get-Text 'Dialog.LogFileNotFound' -FormatArgs @($logPath))
    }
})

# Auto-scroll logs
$LogCollection.Add_CollectionChanged({
    if ($GridLogs.Items.Count -gt 0) {
        try { $GridLogs.ScrollIntoView($GridLogs.Items[$GridLogs.Items.Count - 1]) } catch {}
    }
})

# ---------------------------------------------------------------------------
# Instellingen opslaan
# ---------------------------------------------------------------------------

$BtnSaveSettings.Add_Click({
    try {
        Set-ConfigValue -Key 'LogDirectory'           -Value $TxtSettingsLogDir.Text.Trim()
        Set-ConfigValue -Key 'LogLevel'               -Value $CmbSettingsLogLevel.SelectedItem.Content
        Set-ConfigValue -Key 'LogRetentionDays'       -Value ([int]$TxtSettingsRetention.Text)
        Set-ConfigValue -Key 'DefaultScope'           -Value $CmbSettingsScope.SelectedItem.Content
        $newTheme = $CmbSettingsTheme.SelectedItem.Content
        Set-ConfigValue -Key 'Theme'                  -Value $newTheme
        Set-ConfigValue -Key 'AutoUpdateCheckOnStart' -Value $ChkAutoUpdateCheck.IsChecked
        Set-ConfigValue -Key 'ConfirmUninstall'       -Value $ChkConfirmUninstall.IsChecked
        Set-ConfigValue -Key 'ConfirmUpdate'          -Value $ChkConfirmUpdate.IsChecked
        Set-ConfigValue -Key 'SelfUpdateUrl'          -Value $TxtSettingsUpdateUrl.Text.Trim()

        # Taal: opslaan op basis van .Tag (auto/nl-NL/en-US)
        $oldLang = if ($cfg.Language) { $cfg.Language } else { 'auto' }
        $newLang = if ($CmbSettingsLanguage.SelectedItem) { $CmbSettingsLanguage.SelectedItem.Tag } else { $oldLang }
        Set-ConfigValue -Key 'Language' -Value $newLang

        $script:cfg = Get-AppConfig

        # Detecteer theme-wijziging en bied herstart aan
        $newActiveTheme = Resolve-ActiveTheme -Preference $newTheme
        $themeChanged = $newActiveTheme -ne $ActiveTheme
        $langChanged  = $newLang -ne $oldLang

        if ($themeChanged -or $langChanged) {
            $reason = if ($langChanged -and $themeChanged) {
                (Get-Text 'Restart.LanguageAndTheme')
            } elseif ($langChanged) {
                (Get-Text 'Restart.LanguageChanged')
            } else {
                (Get-Text 'Restart.ThemeChanged')
            }
            Write-Log "$reason  Restart offered." -Source GUI
            if (Ask-Confirm (Get-Text 'Dialog.ConfirmRestart' -FormatArgs @($reason))) {
                $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
                Start-Process -FilePath $exePath
                $Window.Close()
                return
            }
        }

        Show-Info (Get-Text 'Dialog.SettingsSaved')
        Write-Log "Settings saved" -Source GUI
    } catch {
        Show-Error (Get-Text 'Dialog.SaveFailed' -FormatArgs @("$_"))
    }
})

$BtnResetSettings.Add_Click({
    if (Ask-Confirm (Get-Text 'Dialog.ConfirmResetSettings')) {
        $defaultJson = Join-Path $ScriptRoot 'config\settings.json'
        Initialize-Config -ConfigPath $defaultJson
        $script:cfg = Get-AppConfig
        Show-Info (Get-Text 'Dialog.SettingsReset')
    }
})

# ---------------------------------------------------------------------------
# Header knoppen
# ---------------------------------------------------------------------------

$BtnCheckUpdates.Add_Click({ Refresh-Updates; (Get-Control 'MainTabs').SelectedIndex = 2 })

$BtnSelfUpdate.Add_Click({
    if (-not $cfg.SelfUpdateUrl) {
        Show-Info (Get-Text 'Dialog.NoUpdateUrl')
        return
    }

    Set-Status (Get-Text 'Status.CheckingAppUpdate') $true
    try {
        $info = Get-LatestAppVersion -Url $cfg.SelfUpdateUrl
        if (-not $info) {
            Show-Error (Get-Text 'Dialog.VersionCheckFailed')
            Set-Status (Get-Text 'Status.AppCheckFailed')
            return
        }

        $current = Get-AppVersion
        $latest  = $info.Version
        if ([version]$latest -le [version]$current) {
            Show-Info (Get-Text 'Dialog.AppUpToDate' -FormatArgs @($current))
            Set-Status (Get-Text 'Status.UpToDateShort')
            return
        }

        $whatsNew = ($info.Body -split "`n" | Select-Object -First 8) -join "`n"
        $msg = Get-Text 'Dialog.SelfUpdatePrompt' -FormatArgs @($latest, $current, $whatsNew)
        if (-not (Ask-Confirm $msg)) {
            Set-Status (Get-Text 'Status.UpdateCancelled')
            return
        }

        Set-Status (Get-Text 'Status.DownloadingApp' -FormatArgs @($latest)) $true
        $result = Update-App -Url $cfg.SelfUpdateUrl -OnProgress {
            param($stage, $version)
            $Window.Dispatcher.Invoke([action]{
                $TxtStatus.Text = switch ($stage) {
                    'download'  { Get-Text 'Status.DownloadingApp' -FormatArgs @($version) }
                    'launching' { Get-Text 'Status.UpdateReady' }
                    default     { Get-Text 'Status.WorkingOn' -FormatArgs @($stage) }
                }
            })
        }

        if ($result.Updated) {
            Show-Info (Get-Text 'Dialog.AppUpdateInstalled' -FormatArgs @($result.Latest))
            $Window.Close()
        } elseif ($result.Reason -eq 'requires_admin') {
            # System-wide install: we can't write to Program Files without admin.
            # Offer to open the download page so user can run the new Setup.exe manually.
            $downloadUrl = if ($result.SetupUrl) { $result.SetupUrl } else { $result.ReleaseUrl }
            $msg = Get-Text 'Dialog.UpdateRequiresAdmin' -FormatArgs @($result.Latest)
            $answer = [System.Windows.MessageBox]::Show($msg, (Get-Text 'Dialog.Title.Info'), 'YesNo', 'Information')
            if ($answer -eq 'Yes' -and $downloadUrl) {
                # Defense-in-depth: Start-Process executes any string, so confirm the URL
                # is a trusted HTTPS github.com link before handing it to the shell.
                if (Test-TrustedUpdateUrl $downloadUrl) {
                    try { Start-Process $downloadUrl } catch { Write-Log "Failed to open URL: $_" -Level WARN -Source GUI }
                } else {
                    Write-Log "Refused to open untrusted update URL: $downloadUrl" -Level WARN -Source GUI
                }
            }
            Set-Status (Get-Text 'Status.UpdateAvailableHint' -FormatArgs @($result.Latest))
        } else {
            $reasonMsg = switch ($result.Reason) {
                'up_to_date'       { Get-Text 'Update.UpToDate' }
                'no_asset'         { Get-Text 'Update.NoAsset' }
                'download_failed'  { Get-Text 'Update.DownloadFailed' }
                'corrupt_download' { Get-Text 'Update.CorruptDownload' }
                'invalid_exe'      { Get-Text 'Update.InvalidExe' }
                'checksum_mismatch'{ Get-Text 'Update.ChecksumMismatch' }
                'invalid_version'  { Get-Text 'Update.InvalidVersion' }
                'untrusted_url'    { Get-Text 'Update.UntrustedUrl' }
                'not_exe_runtime'  { Get-Text 'Update.NotExeRuntime' }
                default            { Get-Text 'Update.UnknownReason' -FormatArgs @($result.Reason) }
            }
            Show-Error (Get-Text 'Dialog.AppUpdateFailed' -FormatArgs @($reasonMsg))
            Set-Status (Get-Text 'Status.UpdateFailedShort')
        }
    } catch {
        Show-Error (Get-Text 'Dialog.AppUpdateError' -FormatArgs @("$_"))
        Set-Status (Get-Text 'Status.Error')
    }
})

# ---------------------------------------------------------------------------
# Opstarten: data laden
# ---------------------------------------------------------------------------

$Window.Add_Loaded({
    Write-Log "Window loaded, starting initialization" -Source GUI

    $TxtWinGetVersionStatus.Text = "WinGet v$(Get-WinGetVersion)"

    Refresh-Installed
    Refresh-Sources

    if ($cfg.AutoUpdateCheckOnStart) {
        Refresh-Updates
    }

    # Achtergrond-check op nieuwe app-versie (alleen melden, niet automatisch installeren)
    if ($cfg.SelfUpdateUrl -and $cfg.AutoUpdateCheckOnStart) {
        $rs = [runspacefactory]::CreateRunspace()
        $rs.Open()
        $rs.SessionStateProxy.SetVariable('url',     $cfg.SelfUpdateUrl)
        $rs.SessionStateProxy.SetVariable('current', (Get-AppVersion))
        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        [void]$ps.AddScript({
            try {
                $data = Invoke-RestMethod -Uri $url -TimeoutSec 8 -Headers @{
                    'User-Agent' = "WinGetManager/$current"
                    'Accept'     = 'application/vnd.github+json'
                }
                $latest = ($data.tag_name -replace '^v','').Trim()
                if ($latest -and ([version]$latest -gt [version]$current)) {
                    return $latest
                }
            } catch {}
            return $null
        })
        $handle = $ps.BeginInvoke()
        $checkTimer = New-Object System.Windows.Threading.DispatcherTimer
        $checkTimer.Interval = [TimeSpan]::FromMilliseconds(500)
        $checkTimer.Add_Tick({
            if ($handle.IsCompleted) {
                $checkTimer.Stop()
                try {
                    $result = $ps.EndInvoke($handle) | Select-Object -First 1
                    if ($result) {
                        Write-Log "Update available: v$result" -Source GUI
                        $TxtStatus.Text = Get-Text 'Status.UpdateAvailableHint' -FormatArgs @($result)
                        $BtnSelfUpdate.Background = [System.Windows.Media.Brushes]::Orange
                    }
                } catch {}
                try { $ps.Dispose(); $rs.Dispose() } catch {}
            }
        }.GetNewClosure())
        $checkTimer.Start()
    }
})

# ---------------------------------------------------------------------------
# Toon venster
# ---------------------------------------------------------------------------

# Window-icoon instellen (voor titelbalk + taakbalk)
# Drie strategieen, vallen terug bij falen:
# 1. Embedded resource in lopende EXE (PS2EXE - werkt in distributie)
# 2. assets/icon.ico naast script of EXE (PS1 dev mode)
# 3. Stille fallback - geen icoon, app werkt nog steeds
try {
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $iconSet = $false

    if ($exePath -and $exePath -match '\.exe$' -and (Test-Path $exePath)) {
        try {
            Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
            $extracted = [System.Drawing.Icon]::ExtractAssociatedIcon($exePath)
            if ($extracted) {
                $Window.Icon = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon(
                    $extracted.Handle,
                    [System.Windows.Int32Rect]::Empty,
                    [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
                $iconSet = $true
            }
        } catch { }
    }

    if (-not $iconSet) {
        $iconCandidate = Join-Path $ScriptRoot 'assets\icon.ico'
        if (Test-Path $iconCandidate) {
            $iconUri = New-Object System.Uri ((Resolve-Path $iconCandidate).Path)
            $Window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create($iconUri)
        }
    }
} catch {
    Write-Log "Loading icon failed: $_" -Level WARN -Source GUI
}

# ---------------------------------------------------------------------------
# Keyboard shortcuts
# ---------------------------------------------------------------------------

$keyHandler = {
    try {
        # In WPF event handlers van PowerShell: $args[0]=sender, $args[1]=KeyEventArgs
        if ($args.Count -lt 2) { return }
        $e   = $args[1]
        $key = $e.Key
        $mods = [System.Windows.Input.Keyboard]::Modifiers
        $ctrl = ($mods -band [System.Windows.Input.ModifierKeys]::Control) -ne 0

        Write-Log "Keypress: $key (ctrl=$ctrl)" -Level DEBUG -Source GUI

        $tabs = $Window.FindName('MainTabs')
        if (-not $tabs) { return }

        # 0=Zoeken 1=Geinstalleerd 2=Updates 3=Import/Export 4=Bronnen 5=Logs 6=Settings

        if ($key -eq 'F5') {
            $btn = switch ($tabs.SelectedIndex) {
                0 { $BtnSearch }
                1 { $BtnRefreshInstalled }
                2 { $BtnRefreshUpdates }
                4 { $BtnRefreshSources }
            }
            if ($btn) {
                # Flash de knop 250ms geel zodat F5-actie duidelijk zichtbaar is
                $origBg = $btn.Background
                $btn.Background = [System.Windows.Media.Brushes]::Gold
                $flashTimer = New-Object System.Windows.Threading.DispatcherTimer
                $flashTimer.Interval = [TimeSpan]::FromMilliseconds(250)
                $flashTimer.Add_Tick({
                    $btn.Background = $origBg
                    $flashTimer.Stop()
                }.GetNewClosure())
                $flashTimer.Start()

                # Trigger de daadwerkelijke click-actie
                $clickEvent = [System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent)
                $btn.RaiseEvent($clickEvent)
            }
            $e.Handled = $true
            return
        }

        if ($key -eq 'Escape') {
            if ($tabs.SelectedIndex -eq 0 -and $TxtSearch.Text) {
                $TxtSearch.Text = ''
                $e.Handled = $true
            }
            return
        }

        if ($ctrl) {
            switch ($key) {
                'F' { $tabs.SelectedIndex = 0; $TxtSearch.Focus() | Out-Null; $TxtSearch.SelectAll(); $e.Handled = $true }
                'R' { $tabs.SelectedIndex = 2; Refresh-Updates; $e.Handled = $true }
                'L' { $tabs.SelectedIndex = 5; $e.Handled = $true }
                'W' { $Window.Close(); $e.Handled = $true }
            }
        }
    } catch {
        Write-Log "Keyboard shortcut error: $_" -Level WARN -Source GUI
    }
}

# Registreer met AddHandler ipv. Add_PreviewKeyDown - vangt ook events die al door
# child controls zijn 'gehandeld' (anders eet TextBox/DataGrid bv. F5/Ctrl+W op)
$Window.AddHandler(
    [System.Windows.UIElement]::PreviewKeyDownEvent,
    [System.Windows.Input.KeyEventHandler]$keyHandler,
    $true   # handledEventsToo
)

Write-Log "Starting WinGet Manager GUI" -Source GUI
$null = $Window.ShowDialog()
Write-Log "GUI closed" -Source GUI

# SIG # Begin signature block
# MIIFggYJKoZIhvcNAQcCoIIFczCCBW8CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU1YjBt7USKSwxKtUCXFyb2SPx
# 5QygggMWMIIDEjCCAfqgAwIBAgIQERy/5noS0YNDQ+ns6effbDANBgkqhkiG9w0B
# AQsFADAhMR8wHQYDVQQDDBZXaW5HZXRNYW5hZ2VyIExvY2FsRGV2MB4XDTI2MDUw
# NTE2NDgxOVoXDTM2MDUwNTE2NTgxOVowITEfMB0GA1UEAwwWV2luR2V0TWFuYWdl
# ciBMb2NhbERldjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJ807LAn
# KDnHe2OML2epBu8NQPQJcoungebjGrM9Sls7qYoaHxPzIwAn5O6NcjyPeBT27nFl
# eQD5HRtffpch5eH8G6weLo/GMmx6z9xWXYEuCqWbzaqcoyYcBTcbwvuz5rOHVxe1
# h4V577zRq5fMxI4oHkneX1/nc36IQznorEvflz86FAw3TwodaT4E7Gw/xH7EQ1MO
# UCwCpsZDdKvZdSrEzgpnFmHqbhjCsOBQLVVoYud0syXosGBQt9JwwaZvp3mQvoJu
# rch0yTuMCIlc46dkecMF4k6xxnXWSifCG+/qqJwYesgRdshr7BqRfXfhJBifREJe
# P6a2k+5RSuScq6kCAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoG
# CCsGAQUFBwMDMB0GA1UdDgQWBBTB/nzy91KscDO0MblJ8J7M61u28DANBgkqhkiG
# 9w0BAQsFAAOCAQEAUfMEGcqt3OmRMubGOQ7UP9GnMDHV6V74QDFa5Za2hcLCH14s
# J08tg9/3ahctk+0iXuLp/+UOT1pfMPDblQQ7QhLegc9PF0BJH+3DEMr0x7IXnquF
# BSzMgkvAFHUXwGmLOeatJjC1ryMk379hqIIt1eBx6852ye/ID0A3H42Od7v+Y2si
# AFPxSLu8NoLuuhzlsKqdY4lhRZ5vbflD3WGPxC92A747x9uRGCO5QipXSVJVviFL
# D1ZlACyUIRdpH4Ex3x+hfjr7rkJm63KiG9u3S0GYwZ5uU3x3RjA/h6e5F0lscWJa
# blzdQy335fx0Y5i2hoCBRue8IfYWbXy69JWQFDGCAdYwggHSAgEBMDUwITEfMB0G
# A1UEAwwWV2luR2V0TWFuYWdlciBMb2NhbERldgIQERy/5noS0YNDQ+ns6effbDAJ
# BgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0B
# CQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAj
# BgkqhkiG9w0BCQQxFgQUoC1y7LFE61Mqe9b7FlMU/NbwGokwDQYJKoZIhvcNAQEB
# BQAEggEAPUYiKq6X9S1ucd9lKHmTz2QZ10g1mKV52hI2m6d67kSewGmauT3Xd6dj
# rGAOMvdiDsNWUk1tHsDrl8KX528QfwDdJ3/z2Pl+DfH5y0BYJ1mIKYIle87puOEd
# Ij+NKg3T9O7+YoDf6PvrnsyGM1oHdUooM//DoMOn9siDFY00DTTJWkwrDDyifziC
# 7mDH8LiA2FxRvHvoFRwSobRsVdcCY/fTqlmGak97Ta+hoXuy0cKErATCS94zbpXt
# kosRpXKPXdOM6g8VLAkZTlUxank6PLOZHHoaUZAN4FxZZtG33UW+71+4tLKO/nQX
# EmD2rRFbUPwrjpyNcB4GBmAnWBkKvQ==
# SIG # End signature block
