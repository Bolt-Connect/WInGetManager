#Requires -Version 5.1
<#
.SYNOPSIS
    Internationalization (i18n) voor WinGet Manager.
.DESCRIPTION
    Beheert vertalingen voor NL en EN. Strings staan als hashtables in deze module
    zodat ze meebundelen in de PS2EXE-build zonder externe resource-files.

    Gebruik:
        Initialize-I18n -Language 'nl-NL'      # of 'en-US' of 'auto'
        Get-Text 'Tab.Search'                  # → "Zoeken" / "Search"
        Apply-Translations -Xaml $xamlString   # vervangt {{Key.Name}} placeholders

    Toevoegen van een nieuwe string:
        1. Voeg key toe aan beide $Strings hashtables hieronder
        2. Gebruik {{Key.Name}} in XAML, of Get-Text 'Key.Name' in code
#>

$Script:CurrentLanguage = 'nl-NL'
$Script:FallbackLanguage = 'en-US'

# ---------------------------------------------------------------------------
# Vertaaldictionaries — KEYS in PascalCase met punt-notatie voor scope.
# ---------------------------------------------------------------------------

$Script:Strings = @{
    'nl-NL' = @{
        # --- Header / generiek ---
        'App.Name'                = 'WinGet Manager'
        'App.Beta'                = 'BETA'
        'App.Admin'               = 'ADMIN'
        'Header.CheckUpdates'     = '🔄 Controleer updates'
        'Header.SelfUpdate'       = '⬆ App updaten'

        # --- Tabs ---
        'Tab.Search'              = '🔍  Zoeken'
        'Tab.Installed'           = '📦  Geïnstalleerd'
        'Tab.Updates'             = '⬆  Updates'
        'Tab.ImportExport'        = '📂  Import/Export'
        'Tab.Sources'             = '🔗  Bronnen'
        'Tab.Logs'                = '📋  Logs'
        'Tab.Settings'            = 'Instellingen'

        # --- Knoppen (algemeen) ---
        'Btn.Search'              = '🔍 Zoeken'
        'Btn.Clear'               = '✕ Wissen'
        'Btn.Refresh'             = '↺ Vernieuwen'
        'Btn.Install'             = '⬇ Installeren'
        'Btn.Uninstall'           = '🗑 Verwijderen'
        'Btn.RemoveSource'        = '🗑 Verwijder bron'
        'Btn.UninstallWithCount'  = '🗑 Verwijder ({0})'
        'Busy.Uninstalling'       = 'Verwijderen: {0}...'
        'Busy.Installing'         = 'Installeren: {0}...'
        'Busy.Updating'           = 'Updaten: {0}...'
        'Dialog.ConfirmUninstallSingle' = 'Verwijder ''{0}''?'
        'Btn.Update'              = '⬆ Updaten'
        'Btn.UpdateSelected'      = '⬆ Selectie updaten'
        'Btn.UpdateSelectedInst'  = '⬆ Update geselecteerde'
        'Btn.UpdateAll'           = '🚀 Alles updaten'
        'Btn.Details'             = 'ℹ Details'
        'Btn.Save'                = '💾 Opslaan'
        'Btn.ResetDefaults'       = '↩ Standaard herstellen'
        'Btn.ResetSources'        = '↩ Reset standaard'
        'Btn.Add'                 = '➕ Toevoegen'
        'Btn.Cancel'              = 'Annuleren'
        'Btn.OK'                  = 'OK'
        'Btn.Yes'                 = 'Ja'
        'Btn.No'                  = 'Nee'

        # --- Kolomheaders ---
        'Col.Name'                = 'NAAM'
        'Col.Id'                  = 'ID'
        'Col.Version'             = 'VERSIE'
        'Col.Current'             = 'HUIDIG'
        'Col.Available'           = 'BESCHIKBAAR'
        'Col.Source'              = 'BRON'
        'Col.Status'              = 'STATUS'
        'Col.Url'                 = 'URL'
        'Col.Type'                = 'TYPE'
        'Col.Timestamp'           = 'TIJDSTIP'
        'Col.Level'               = 'LEVEL'
        'Col.Message'             = 'BERICHT'

        # --- Statuslabels ---
        'Status.Ready'            = 'Gereed'
        'Status.UpToDate'         = 'Up-to-date'
        'Status.Unknown'          = '— Onbekend'
        'Status.UpdateAvailable'  = '↑ Update'
        'Status.UpdatesFound'     = '{0} update(s) gevonden'
        'Status.InstalledCount'   = '{0} packages, {1} updatebaar'
        'Status.NoPackagesFound'  = '📦  Geen packages gevonden'
        'Status.LoadingInstalled' = '📦  Geïnstalleerd laden...'
        'Status.Uninstalling'     = 'Verwijderen ({0}/{1}): {2}'
        'Status.UpdatingProgress' = 'Updaten ({0}/{1}): {2}'
        'Status.DownloadingApp'   = 'Downloaden v{0}...'
        'Status.UpdateReady'      = 'Update klaar, herstarten...'
        'Status.WorkingOn'        = 'Bezig: {0}'
        'Status.UpdateAvailableHint' = 'v{0} beschikbaar - klik ''App updaten'' bovenin'
        'Status.UpToDateApp'      = 'App is up-to-date'
        'Status.WinGetMissing'    = 'WinGet niet gevonden'
        'Status.TypeMore'         = 'Typ minimaal 2 tekens'
        'Status.Searching'        = 'Zoeken: {0}...'
        'Status.SearchResults'    = '{0} resultaten voor ''{1}'''
        'Status.InstallSuccess'   = 'Installatie geslaagd'
        'Status.InstallFailed'    = 'Installatie mislukt'
        'Status.InstallCancelled' = 'Installatie geannuleerd'
        'Status.FetchingDetails'  = 'Details ophalen...'
        'Status.DetailsError'     = 'Fout bij details'
        'Status.LoadingInstalledPkgs' = 'Geïnstalleerde packages laden...'
        'Status.Error'            = 'Fout'
        'Status.Uninstalled'      = 'Verwijderd'
        'Status.Failed'           = 'Mislukt'
        'Status.UpdateSuccessName'= 'Update van {0} geslaagd'
        'Status.UpdateFailedShort'= 'Update mislukt'
        'Status.CheckingUpdates'  = 'Updates controleren...'
        'Status.CheckError'       = 'Fout bij controleren'
        'Status.Preparing'        = 'Voorbereiden...'
        'Status.Exporting'        = 'Exporteren...'
        'Status.Importing'        = 'Importeren...'
        'Status.SourcesLoaded'    = 'Bronnen geladen'
        'Status.AddingSource'     = 'Bron toevoegen...'
        'Status.CheckingAppUpdate'= 'Controleren op app-update...'
        'Status.AppCheckFailed'   = 'Update-check mislukt'
        'Status.UpdateCancelled'  = 'Update geannuleerd'
        'Status.UpToDateShort'    = 'Up-to-date'

        # --- Dialog titels (messagebox titlebars) ---
        'Dialog.Title.Info'       = 'Info'
        'Dialog.Title.Error'      = 'Fout'
        'Dialog.Title.Confirm'    = 'Bevestig'
        'Dialog.Title.Details'    = 'Package-details'

        # --- Dialog teksten ---
        'Dialog.ConfirmInstall'   = 'Installeer ''{0}'' ({1})?'
        'Dialog.InstallSuccess'   = '''{0}'' succesvol geïnstalleerd.'
        'Dialog.InstallFailed'    = 'Installatie mislukt: {0}'
        'Dialog.InstallNotVerified' = '''{0}'' meldde succes, maar het pakket staat niet in de lijst met geïnstalleerde programma''s.

Waarschijnlijk is de installatie niet echt uitgevoerd. Probeer het opnieuw, eventueel met administrator-rechten.'
        'Dialog.LoadFailed'       = 'Laden mislukt: {0}'
        'Dialog.UninstallStillRunning' = 'Verwijderen mislukt: {0} draait nog.

  - {1}

Processen sluiten en opnieuw proberen?'
        'Dialog.UninstallFailed'  = 'Verwijderen van {0} mislukt: {1}'
        'Dialog.SomeFailed'       = '{0}

Mislukt: {1}'
        'Dialog.NoUpdatesForSelection' = 'Geen geselecteerde packages hebben een update beschikbaar.'
        'Dialog.ConfirmUpdateSinglePkg' = 'Update ''{0}'' naar v{1}?'
        'Dialog.ConfirmUpdateMultiple' = '{0} packages updaten?

{1}'
        'Dialog.UpdateStillRunning' = 'Update mislukt: {0} draait nog.

  - {1}

Processen sluiten en opnieuw proberen?'
        'Dialog.RequiresAdmin'    = '{0} vereist administrator-rechten.

Nu opnieuw proberen met admin-rechten? (Windows toont een UAC-prompt.)'
        'Dialog.BulkNeedsAdmin'   = '{0} package(s) zijn mislukt omdat ze administrator-rechten vereisen:

  - {1}

Nu opnieuw proberen met admin-rechten? (Windows toont één UAC-prompt voor alle.)'
        'Status.RetryingElevated' = 'Opnieuw proberen met admin-rechten...'
        'Dialog.UpdateFailedDetailed' = 'Update van {0} mislukt: {1}'
        'Dialog.NoUpdatesAvailable' = 'Geen updates beschikbaar.'
        'Dialog.ConfirmUpdateAll' = 'Alle {0} packages updaten?'
        'Dialog.SelectFirst'      = 'Selecteer eerst packages via het selectievakje.'
        'Dialog.ConfirmUpdateSelected' = '{0} geselecteerde package(s) updaten?'
        'Dialog.NoExportPath'     = 'Geef een exportpad op.'
        'Dialog.ExportSuccess'    = 'Export geslaagd naar:
{0}'
        'Dialog.ExportFailed'     = 'Export mislukt.'
        'Dialog.SelectImportFile' = 'Geldig importbestand selecteren.'
        'Dialog.ConfirmImport'    = 'Alle packages uit ''{0}'' installeren?'
        'Dialog.ImportSuccess'    = 'Import geslaagd.'
        'Dialog.ImportFailed'     = 'Import mislukt (sommige packages konden niet worden geïnstalleerd).'
        'Dialog.GenericError'     = 'Fout: {0}'
        'Dialog.NameUrlRequired'  = 'Naam en URL zijn verplicht.'
        'Dialog.AddSourceFailed'  = 'Bron toevoegen mislukt (vereist administrator-rechten).'
        'Dialog.ConfirmRemoveSource' = 'Bron ''{0}'' verwijderen?'
        'Dialog.RemoveSourceFailed' = 'Verwijderen mislukt (administrator vereist).'
        'Dialog.ConfirmResetSources' = 'Alle bronnen resetten naar standaard (vereist administrator)?'
        'Dialog.SourcesReset'     = 'Bronnen gereset.'
        'Dialog.ResetFailed'      = 'Reset mislukt.'
        'Dialog.ConfirmClearLogs' = 'Alle logregels verwijderen uit het scherm?'
        'Dialog.LogFileNotFound'  = 'Logbestand niet gevonden: {0}'
        'Dialog.ConfirmRestart'   = '{0}  App nu herstarten om de wijziging toe te passen?'
        'Dialog.SettingsSaved'    = 'Instellingen opgeslagen.'
        'Dialog.SaveFailed'       = 'Opslaan mislukt: {0}'
        'Dialog.ConfirmResetSettings' = 'Standaardinstellingen herstellen?'
        'Dialog.SettingsReset'    = 'Standaardinstellingen hersteld. Herstart de app om alle wijzigingen toe te passen.'
        'Dialog.NoUpdateUrl'      = 'Geen update-URL geconfigureerd. Stel ''SelfUpdateUrl'' in onder Instellingen.'
        'Dialog.VersionCheckFailed' = 'Kan geen versie-info ophalen. Controleer je internetverbinding.'
        'Dialog.AppUpToDate'      = 'App is al up-to-date (v{0}).'
        'Dialog.AppUpdateInstalled' = 'Update geïnstalleerd! De app wordt nu opnieuw gestart met v{0}.'
        'Dialog.AppUpdateFailed'  = 'Update mislukt: {0}'
        'Dialog.AppUpdateError'   = 'Fout bij update: {0}'
        'Dialog.UpdateRequiresAdmin' = 'Update naar v{0} beschikbaar, maar WinGet Manager is system-wide geïnstalleerd (Program Files) en kan zichzelf niet bijwerken zonder administrator-rechten.

Wilt u de download-pagina openen om de nieuwe Setup.exe handmatig te downloaden?'
        'Dialog.DontAskAgain'     = 'Niet meer vragen voor deze actie'

        # --- Restart-reason regels (Save Settings) ---
        'Restart.LanguageAndTheme'= 'Taal en thema zijn gewijzigd.'
        'Restart.LanguageChanged' = 'De taal is gewijzigd.'
        'Restart.ThemeChanged'    = 'Het thema is gewijzigd.'

        # --- Self-update reden regels ---
        'Update.UpToDate'         = 'App is al up-to-date.'
        'Update.NoAsset'          = 'Update niet gevonden in deze release.'
        'Update.DownloadFailed'   = 'Download mislukt - check internetverbinding.'
        'Update.CorruptDownload'  = 'Download was beschadigd, probeer opnieuw.'
        'Update.InvalidExe'       = 'Download is geen geldige executable - mogelijk corrupt of gemanipuleerd.'
        'Update.UntrustedUrl'     = 'Update-URL is niet vertrouwd. Alleen github.com URLs worden toegestaan.'
        'Update.NotExeRuntime'    = 'Self-update werkt alleen vanuit de .exe distributie.'
        'Update.InvalidVersion'   = 'versienummer van de release kon niet worden gelezen.'
        'Update.ChecksumMismatch' = 'controlesom komt niet overeen - de download is beschadigd of gewijzigd. Update afgebroken.'
        'Update.UnknownReason'    = 'Onbekende reden: {0}'

        # --- WinGet-ontbreekt onboarding ---
        'Dialog.WinGetMissingPrompt' = 'WinGet (App Installer) is niet gevonden op dit systeem. WinGet Manager heeft dit nodig om pakketten te beheren.

De Microsoft Store openen om App Installer te installeren?'

        # --- Core throws (fatal errors) ---
        'Throw.WinGetNotFound'    = 'WinGet niet gevonden. Installeer App Installer via de Microsoft Store.'

        # --- Ask-ConfirmEx titels ---
        'Title.UninstallPackage'  = 'Pakket verwijderen'
        'Title.BulkUninstall'     = 'Bulk verwijderen'
        'Title.UpdatePackage'     = 'Pakket updaten'
        'Title.BulkUpdate'        = 'Bulk updaten'
        'Title.UpdateAll'         = 'Alles updaten'
        'Title.UpdateSelection'   = 'Selectie updaten'
        'Title.AppUpdate'         = 'App update'

        # --- WinGet exit-code messages (Msg veld) ---
        'Err.NoUpdatesAvailable'  = 'Geen updates beschikbaar'
        'Err.PackageNotFound'     = 'Geen pakketten gevonden voor deze ID'
        'Err.HashMismatch'        = 'Hashverificatie mislukt - download corrupt'
        'Err.MultiplePackages'    = 'Meerdere pakketten gevonden, ID is niet uniek'
        'Err.AgreementNotAccepted'= 'Pakketovereenkomst niet geaccepteerd'
        'Err.NeedsAdmin'          = 'Onvoldoende rechten - update vereist administrator'
        'Err.AppRunning'          = 'App draait nog en kan niet worden bijgewerkt'
        'Err.NoInternet'          = 'Internet niet beschikbaar'
        'Err.DiskFull'            = 'Schijf vol'

        # --- Extra dialog teksten (batch 2) ---
        'Dialog.ConfirmBulkUninstall' = '{0} packages verwijderen?

{1}'
        'Dialog.SilentUninstallPrompt' = 'Weet u zeker dat u ''{0}'' wilt verwijderen? (j/n)'
        'Dialog.ConfirmSelfUpdate'    = 'Een nieuwe versie is beschikbaar: v{0} (jij hebt v{1}).

Nu downloaden en bijwerken? De app wordt automatisch herstart.'
        'Search.NoResults'        = '🔍  Geen resultaten voor ''{0}'''
        'Details.Format'          = 'Naam:    {0}
ID:      {1}
Versie:  {2}
Uitgever: {3}
Bron:    {4}'
        'BulkResult.Uninstall'    = 'Klaar: {0} verwijderd, {1} mislukt'
        'BulkResult.Update'       = 'Klaar: {0} geslaagd, {1} mislukt'

        # --- Inline Set-Status statussen (batch 2) ---
        'Status.ExportSuccess'    = 'Export geslaagd'
        'Status.ExportFailed'     = 'Export mislukt'
        'Status.ImportSuccess'    = 'Import geslaagd'
        'Status.ImportWithErrors' = 'Import klaar (met fouten)'
        'Status.SourceAdded'      = 'Bron toegevoegd'

        # --- Sources-tab beschrijving (Run blocks) ---
        'Sources.IntroBold'       = 'Bronnen zijn de pakketten-repos die WinGet gebruikt. '
        'Sources.IntroDefault'    = 'Standaard staan er twee:'
        'Sources.WingetDesc'      = ' — Microsofts officiele community-repo (~6000 apps zoals Firefox, Chrome, VSCode)'
        'Sources.MsstoreDesc'     = ' — Microsoft Store apps (Spotify, WhatsApp, Netflix, etc.)'
        'Sources.LocalDesc'       = ' — niet echt een bron; verschijnt in de BRON-kolom voor apps die buiten WinGet zijn geïnstalleerd (bijv. via .exe installer of MSI). WinGet kan deze niet updaten of verwijderen via deze GUI.'
        'Sources.Outro'           = 'Hier kun je een eigen bron toevoegen (bijvoorbeeld een corporate-repo), bestaande bronnen verwijderen, of resetten naar de standaard.'

        # --- Config warnings ---
        'Config.LoadFailed'       = 'Config laden mislukt ({0}): {1}  — standaardwaarden gebruikt.'
        'Config.SaveFailed'       = 'Config opslaan mislukt: {0}'
        'Dialog.SelfUpdatePrompt' = 'Nieuwe versie beschikbaar: v{0}

Huidige versie: v{1}

Wat is er nieuw:
{2}

Nu downloaden en bijwerken? De app wordt automatisch herstart.'

        # --- Zoek tab ---
        'Search.Placeholder'      = 'Zoek packages...'
        'Search.Empty'            = '🔍  Typ minimaal 2 tekens om te zoeken'
        'Source.AllSources'       = 'Alle bronnen'

        # --- Installed tab ---
        'Installed.FilterPlaceholder' = 'Filter op naam of ID...'
        'Installed.Loading'       = '📦  Bezig met laden...'

        # --- Updates tab ---
        'Updates.AvailableLabel'  = 'Beschikbare updates'
        'Updates.WinGetVersion'   = 'WinGet versie'
        'Updates.AllUpToDate'     = '✓  Alle packages zijn up-to-date 🎉'

        # --- Import/Export ---
        'Section.Export'          = '📤  Exporteren'
        'Section.Import'          = '📥  Importeren'
        'Export.Description'      = 'Sla alle geïnstalleerde packages op in een JSON-bestand. Handig als back-up of om op een andere computer te installeren.'
        'Import.Description'      = 'Installeer alle packages uit een bestaand JSON-exportbestand. Niet-beschikbare packages worden overgeslagen indien gewenst.'
        'Export.FileLabel'        = 'Exportbestand:'
        'Import.FileLabel'        = 'Importbestand:'
        'Import.IgnoreUnavailable'= 'Niet-beschikbare packages overslaan'
        'Btn.ExportNow'           = '⬇ Nu exporteren'
        'Btn.ImportNow'           = '⬆ Nu importeren'

        # --- Sources tab ---
        'Sources.None'            = '🔗  Geen bronnen geconfigureerd'
        'Field.Name'              = 'Naam:'
        'Field.Url'               = 'URL:'
        'Field.Type'              = 'Type:'

        # --- Logs ---
        'Logs.LevelAll'           = 'Alle'
        'Btn.ClearLogs'           = '🗑 Wissen'
        'Btn.OpenLogFile'         = '📁 Open logbestand'

        # --- Settings secties ---
        'Settings.Logging'        = 'Logging'
        'Settings.Behavior'       = 'Gedrag'
        'Settings.SelfUpdate'     = 'Zelf-update'
        'Settings.Shortcuts'      = 'Sneltoetsen'
        'Settings.Language'       = 'Taal'
        'Settings.LogDir'         = 'Log-map:'
        'Settings.MinLevel'       = 'Minimaal niveau:'
        'Settings.RetentionDays'  = 'Bewaarperiode (dagen):'
        'Settings.DefaultScope'   = 'Standaard scope:'
        'Settings.Theme'          = 'Thema:'
        'Settings.UpdateUrl'      = 'Update URL:'
        'Settings.LanguageLabel'  = 'Taal:'
        'Settings.AutoUpdateCheck'= 'Controleer updates bij opstarten'
        'Settings.ConfirmUninstall'='Bevestiging vragen bij verwijderen'
        'Settings.ConfirmUpdate'  = 'Bevestiging vragen bij updaten'
        'Settings.MultiSelectTip' = 'Tip: Ctrl/Shift-klik in Geïnstalleerd voor multi-select bulk-acties.'

        # --- Theme keuzes (ComboBox items) ---
        'Theme.Auto'              = 'Auto'
        'Theme.Dark'              = 'Dark'
        'Theme.Light'              = 'Light'

        # --- Language keuzes ---
        'Language.Auto'           = 'Automatisch (systeem)'
        'Language.Dutch'          = 'Nederlands'
        'Language.English'        = 'English'

        # --- Sneltoetsen omschrijvingen ---
        'Shortcut.RefreshTab'     = 'Vernieuw huidige tab'
        'Shortcut.JumpSearch'     = 'Spring naar Zoeken-tab'
        'Shortcut.OpenUpdates'    = 'Open Updates-tab en check'
        'Shortcut.OpenLogs'       = 'Open Logs-tab'
        'Shortcut.Close'          = 'Sluit de app'
        'Shortcut.ClearSearch'    = 'Wis zoekveld op Zoeken-tab'
        'Shortcut.EnterSearch'    = 'In zoekveld: directe zoekactie (skip 400ms wachten)'

        # --- Berichten / dialogen ---
        'Msg.WinGetNotFound'      = 'WinGet niet gevonden'
        'Msg.Loading'             = 'Bezig met laden...'
        'Msg.NoResults'           = 'Geen resultaten'
        'Msg.ConfirmUninstall'    = 'Weet je zeker dat je {0} wilt verwijderen?'
        'Msg.ConfirmUpdate'       = 'Weet je zeker dat je {0} wilt updaten?'
        'Msg.UpdateComplete'      = 'Update voltooid'
        'Msg.UpdateFailed'        = 'Update mislukt'
        'Msg.RestartRequired'     = 'Herstart vereist'
        'Msg.LanguageChanged'     = 'Taal gewijzigd naar {0}. Herstart de app om de wijziging volledig door te voeren.'
        'Msg.LanguageChangedTitle'= 'Taal gewijzigd'
    }

    'en-US' = @{
        # --- Header / generic ---
        'App.Name'                = 'WinGet Manager'
        'App.Beta'                = 'BETA'
        'App.Admin'               = 'ADMIN'
        'Header.CheckUpdates'     = '🔄 Check updates'
        'Header.SelfUpdate'       = '⬆ Update app'

        # --- Tabs ---
        'Tab.Search'              = '🔍  Search'
        'Tab.Installed'           = '📦  Installed'
        'Tab.Updates'             = '⬆  Updates'
        'Tab.ImportExport'        = '📂  Import/Export'
        'Tab.Sources'             = '🔗  Sources'
        'Tab.Logs'                = '📋  Logs'
        'Tab.Settings'            = 'Settings'

        # --- Buttons (general) ---
        'Btn.Search'              = '🔍 Search'
        'Btn.Clear'               = '✕ Clear'
        'Btn.Refresh'             = '↺ Refresh'
        'Btn.Install'             = '⬇ Install'
        'Btn.Uninstall'           = '🗑 Uninstall'
        'Btn.RemoveSource'        = '🗑 Remove source'
        'Btn.UninstallWithCount'  = '🗑 Uninstall ({0})'
        'Busy.Uninstalling'       = 'Uninstalling: {0}...'
        'Busy.Installing'         = 'Installing: {0}...'
        'Busy.Updating'           = 'Updating: {0}...'
        'Dialog.ConfirmUninstallSingle' = 'Uninstall ''{0}''?'
        'Btn.Update'              = '⬆ Update'
        'Btn.UpdateSelected'      = '⬆ Update selection'
        'Btn.UpdateSelectedInst'  = '⬆ Update selected'
        'Btn.UpdateAll'           = '🚀 Update all'
        'Btn.Details'             = 'ℹ Details'
        'Btn.Save'                = '💾 Save'
        'Btn.ResetDefaults'       = '↩ Restore defaults'
        'Btn.ResetSources'        = '↩ Reset to defaults'
        'Btn.Add'                 = '➕ Add'
        'Btn.Cancel'              = 'Cancel'
        'Btn.OK'                  = 'OK'
        'Btn.Yes'                 = 'Yes'
        'Btn.No'                  = 'No'

        # --- Column headers ---
        'Col.Name'                = 'NAME'
        'Col.Id'                  = 'ID'
        'Col.Version'             = 'VERSION'
        'Col.Current'             = 'CURRENT'
        'Col.Available'           = 'AVAILABLE'
        'Col.Source'              = 'SOURCE'
        'Col.Status'              = 'STATUS'
        'Col.Url'                 = 'URL'
        'Col.Type'                = 'TYPE'
        'Col.Timestamp'           = 'TIMESTAMP'
        'Col.Level'               = 'LEVEL'
        'Col.Message'             = 'MESSAGE'

        # --- Status labels ---
        'Status.Ready'            = 'Ready'
        'Status.UpToDate'         = 'Up-to-date'
        'Status.Unknown'          = '— Unknown'
        'Status.UpdateAvailable'  = '↑ Update'
        'Status.UpdatesFound'     = '{0} update(s) found'
        'Status.InstalledCount'   = '{0} packages, {1} updatable'
        'Status.NoPackagesFound'  = '📦  No packages found'
        'Status.LoadingInstalled' = '📦  Loading installed...'
        'Status.Uninstalling'     = 'Uninstalling ({0}/{1}): {2}'
        'Status.UpdatingProgress' = 'Updating ({0}/{1}): {2}'
        'Status.DownloadingApp'   = 'Downloading v{0}...'
        'Status.UpdateReady'      = 'Update ready, restarting...'
        'Status.WorkingOn'        = 'Working: {0}'
        'Status.UpdateAvailableHint' = 'v{0} available - click ''Update app'' at the top'
        'Status.UpToDateApp'      = 'App is up-to-date'
        'Status.WinGetMissing'    = 'WinGet not found'
        'Status.TypeMore'         = 'Type at least 2 characters'
        'Status.Searching'        = 'Searching: {0}...'
        'Status.SearchResults'    = '{0} results for ''{1}'''
        'Status.InstallSuccess'   = 'Install succeeded'
        'Status.InstallFailed'    = 'Install failed'
        'Status.InstallCancelled' = 'Installation cancelled'
        'Status.FetchingDetails'  = 'Fetching details...'
        'Status.DetailsError'     = 'Error fetching details'
        'Status.LoadingInstalledPkgs' = 'Loading installed packages...'
        'Status.Error'            = 'Error'
        'Status.Uninstalled'      = 'Uninstalled'
        'Status.Failed'           = 'Failed'
        'Status.UpdateSuccessName'= 'Update of {0} succeeded'
        'Status.UpdateFailedShort'= 'Update failed'
        'Status.CheckingUpdates'  = 'Checking for updates...'
        'Status.CheckError'       = 'Error checking'
        'Status.Preparing'        = 'Preparing...'
        'Status.Exporting'        = 'Exporting...'
        'Status.Importing'        = 'Importing...'
        'Status.SourcesLoaded'    = 'Sources loaded'
        'Status.AddingSource'     = 'Adding source...'
        'Status.CheckingAppUpdate'= 'Checking for app update...'
        'Status.AppCheckFailed'   = 'Update check failed'
        'Status.UpdateCancelled'  = 'Update cancelled'
        'Status.UpToDateShort'    = 'Up-to-date'

        # --- Dialog titles (messagebox titlebars) ---
        'Dialog.Title.Info'       = 'Info'
        'Dialog.Title.Error'      = 'Error'
        'Dialog.Title.Confirm'    = 'Confirm'
        'Dialog.Title.Details'    = 'Package details'

        # --- Dialog texts ---
        'Dialog.ConfirmInstall'   = 'Install ''{0}'' ({1})?'
        'Dialog.InstallSuccess'   = '''{0}'' installed successfully.'
        'Dialog.InstallFailed'    = 'Install failed: {0}'
        'Dialog.InstallNotVerified' = '''{0}'' reported success, but the package does not appear in the list of installed programs.

The installation most likely did not actually run. Please try again, if needed with administrator rights.'
        'Dialog.LoadFailed'       = 'Load failed: {0}'
        'Dialog.UninstallStillRunning' = 'Uninstall failed: {0} is still running.

  - {1}

Close processes and retry?'
        'Dialog.UninstallFailed'  = 'Uninstall of {0} failed: {1}'
        'Dialog.SomeFailed'       = '{0}

Failed: {1}'
        'Dialog.NoUpdatesForSelection' = 'None of the selected packages have an update available.'
        'Dialog.ConfirmUpdateSinglePkg' = 'Update ''{0}'' to v{1}?'
        'Dialog.ConfirmUpdateMultiple' = 'Update {0} packages?

{1}'
        'Dialog.UpdateStillRunning' = 'Update failed: {0} is still running.

  - {1}

Close processes and retry?'
        'Dialog.RequiresAdmin'    = '{0} requires administrator rights.

Retry now with admin rights? (Windows will show a UAC prompt.)'
        'Dialog.BulkNeedsAdmin'   = '{0} package(s) failed because they require administrator rights:

  - {1}

Retry these with admin rights now? (Windows will show one UAC prompt for all.)'
        'Status.RetryingElevated' = 'Retrying with admin rights...'
        'Dialog.UpdateFailedDetailed' = 'Update of {0} failed: {1}'
        'Dialog.NoUpdatesAvailable' = 'No updates available.'
        'Dialog.ConfirmUpdateAll' = 'Update all {0} packages?'
        'Dialog.SelectFirst'      = 'Select packages via the checkbox first.'
        'Dialog.ConfirmUpdateSelected' = 'Update {0} selected package(s)?'
        'Dialog.NoExportPath'     = 'Please provide an export path.'
        'Dialog.ExportSuccess'    = 'Export succeeded to:
{0}'
        'Dialog.ExportFailed'     = 'Export failed.'
        'Dialog.SelectImportFile' = 'Select a valid import file.'
        'Dialog.ConfirmImport'    = 'Install all packages from ''{0}''?'
        'Dialog.ImportSuccess'    = 'Import succeeded.'
        'Dialog.ImportFailed'     = 'Import failed (some packages could not be installed).'
        'Dialog.GenericError'     = 'Error: {0}'
        'Dialog.NameUrlRequired'  = 'Name and URL are required.'
        'Dialog.AddSourceFailed'  = 'Adding source failed (administrator rights required).'
        'Dialog.ConfirmRemoveSource' = 'Remove source ''{0}''?'
        'Dialog.RemoveSourceFailed' = 'Remove failed (administrator required).'
        'Dialog.ConfirmResetSources' = 'Reset all sources to defaults (requires administrator)?'
        'Dialog.SourcesReset'     = 'Sources reset.'
        'Dialog.ResetFailed'      = 'Reset failed.'
        'Dialog.ConfirmClearLogs' = 'Clear all log entries from the screen?'
        'Dialog.LogFileNotFound'  = 'Log file not found: {0}'
        'Dialog.ConfirmRestart'   = '{0}  Restart the app now to apply the change?'
        'Dialog.SettingsSaved'    = 'Settings saved.'
        'Dialog.SaveFailed'       = 'Save failed: {0}'
        'Dialog.ConfirmResetSettings' = 'Restore default settings?'
        'Dialog.SettingsReset'    = 'Default settings restored. Restart the app to apply all changes.'
        'Dialog.NoUpdateUrl'      = 'No update URL configured. Set ''SelfUpdateUrl'' under Settings.'
        'Dialog.VersionCheckFailed' = 'Could not fetch version info. Check your internet connection.'
        'Dialog.AppUpToDate'      = 'App is already up-to-date (v{0}).'
        'Dialog.AppUpdateInstalled' = 'Update installed! The app will now restart with v{0}.'
        'Dialog.AppUpdateFailed'  = 'Update failed: {0}'
        'Dialog.AppUpdateError'   = 'Error during update: {0}'
        'Dialog.UpdateRequiresAdmin' = 'Update to v{0} available, but WinGet Manager is installed system-wide (Program Files) and cannot update itself without administrator rights.

Open the download page to manually download the new Setup.exe?'
        'Dialog.DontAskAgain'     = 'Don''t ask again for this action'

        # --- Restart reason strings (Save Settings) ---
        'Restart.LanguageAndTheme'= 'Language and theme have changed.'
        'Restart.LanguageChanged' = 'The language has changed.'
        'Restart.ThemeChanged'    = 'The theme has changed.'

        # --- Self-update reason strings ---
        'Update.UpToDate'         = 'App is already up-to-date.'
        'Update.NoAsset'          = 'Update not found in this release.'
        'Update.DownloadFailed'   = 'Download failed - check your internet connection.'
        'Update.CorruptDownload'  = 'Download was corrupted, please try again.'
        'Update.InvalidExe'       = 'Download is not a valid executable - possibly corrupt or tampered with.'
        'Update.UntrustedUrl'     = 'Update URL is not trusted. Only github.com URLs are allowed.'
        'Update.NotExeRuntime'    = 'Self-update only works from the .exe distribution.'
        'Update.InvalidVersion'   = 'could not read the version number of the release.'
        'Update.ChecksumMismatch' = 'checksum does not match - the download is corrupt or tampered with. Update aborted.'
        'Update.UnknownReason'    = 'Unknown reason: {0}'

        # --- WinGet-missing onboarding ---
        'Dialog.WinGetMissingPrompt' = 'WinGet (App Installer) was not found on this system. WinGet Manager needs it to manage packages.

Open the Microsoft Store to install App Installer?'

        # --- Core throws (fatal errors) ---
        'Throw.WinGetNotFound'    = 'WinGet not found. Install App Installer via the Microsoft Store.'

        # --- Ask-ConfirmEx titles ---
        'Title.UninstallPackage'  = 'Uninstall package'
        'Title.BulkUninstall'     = 'Bulk uninstall'
        'Title.UpdatePackage'     = 'Update package'
        'Title.BulkUpdate'        = 'Bulk update'
        'Title.UpdateAll'         = 'Update all'
        'Title.UpdateSelection'   = 'Update selection'
        'Title.AppUpdate'         = 'App update'

        # --- WinGet exit-code messages (Msg field) ---
        'Err.NoUpdatesAvailable'  = 'No updates available'
        'Err.PackageNotFound'     = 'No packages found for this ID'
        'Err.HashMismatch'        = 'Hash verification failed - download corrupted'
        'Err.MultiplePackages'    = 'Multiple packages found, ID is not unique'
        'Err.AgreementNotAccepted'= 'Package agreement not accepted'
        'Err.NeedsAdmin'          = 'Insufficient rights - update requires administrator'
        'Err.AppRunning'          = 'App is still running and cannot be updated'
        'Err.NoInternet'          = 'No internet available'
        'Err.DiskFull'            = 'Disk full'

        # --- Extra dialog texts (batch 2) ---
        'Dialog.ConfirmBulkUninstall' = 'Uninstall {0} packages?

{1}'
        'Dialog.SilentUninstallPrompt' = 'Are you sure you want to uninstall ''{0}''? (y/n)'
        'Dialog.ConfirmSelfUpdate'    = 'A new version is available: v{0} (you have v{1}).

Download and update now? The app will restart automatically.'
        'Search.NoResults'        = '🔍  No results for ''{0}'''
        'Details.Format'          = 'Name:      {0}
ID:        {1}
Version:   {2}
Publisher: {3}
Source:    {4}'
        'BulkResult.Uninstall'    = 'Done: {0} uninstalled, {1} failed'
        'BulkResult.Update'       = 'Done: {0} succeeded, {1} failed'

        # --- Inline Set-Status statuses (batch 2) ---
        'Status.ExportSuccess'    = 'Export succeeded'
        'Status.ExportFailed'     = 'Export failed'
        'Status.ImportSuccess'    = 'Import succeeded'
        'Status.ImportWithErrors' = 'Import done (with errors)'
        'Status.SourceAdded'      = 'Source added'

        # --- Sources tab description (Run blocks) ---
        'Sources.IntroBold'       = 'Sources are the package repos WinGet uses. '
        'Sources.IntroDefault'    = 'There are two defaults:'
        'Sources.WingetDesc'      = ' — Microsoft''s official community repo (~6000 apps like Firefox, Chrome, VSCode)'
        'Sources.MsstoreDesc'     = ' — Microsoft Store apps (Spotify, WhatsApp, Netflix, etc.)'
        'Sources.LocalDesc'       = ' — not actually a source; shows in the SOURCE column for apps installed outside WinGet (e.g. via .exe installer or MSI). WinGet can''t update or remove these via this GUI.'
        'Sources.Outro'           = 'Here you can add your own source (e.g. a corporate repo), remove existing sources, or reset to defaults.'

        # --- Config warnings ---
        'Config.LoadFailed'       = 'Config load failed ({0}): {1}  — using defaults.'
        'Config.SaveFailed'       = 'Config save failed: {0}'
        'Dialog.SelfUpdatePrompt' = 'New version available: v{0}

Current version: v{1}

What''s new:
{2}

Download and update now? The app will restart automatically.'

        # --- Search tab ---
        'Search.Placeholder'      = 'Search packages...'
        'Search.Empty'            = '🔍  Type at least 2 characters to search'
        'Source.AllSources'       = 'All sources'

        # --- Installed tab ---
        'Installed.FilterPlaceholder' = 'Filter by name or ID...'
        'Installed.Loading'       = '📦  Loading...'

        # --- Updates tab ---
        'Updates.AvailableLabel'  = 'Available updates'
        'Updates.WinGetVersion'   = 'WinGet version'
        'Updates.AllUpToDate'     = '✓  All packages are up-to-date 🎉'

        # --- Import/Export ---
        'Section.Export'          = '📤  Export'
        'Section.Import'          = '📥  Import'
        'Export.Description'      = 'Save all installed packages to a JSON file. Useful as a backup or to install on another computer.'
        'Import.Description'      = 'Install all packages from an existing JSON export file. Unavailable packages can be skipped if desired.'
        'Export.FileLabel'        = 'Export file:'
        'Import.FileLabel'        = 'Import file:'
        'Import.IgnoreUnavailable'= 'Skip unavailable packages'
        'Btn.ExportNow'           = '⬇ Export now'
        'Btn.ImportNow'           = '⬆ Import now'

        # --- Sources tab ---
        'Sources.None'            = '🔗  No sources configured'
        'Field.Name'              = 'Name:'
        'Field.Url'               = 'URL:'
        'Field.Type'              = 'Type:'

        # --- Logs ---
        'Logs.LevelAll'           = 'All'
        'Btn.ClearLogs'           = '🗑 Clear'
        'Btn.OpenLogFile'         = '📁 Open log file'

        # --- Settings sections ---
        'Settings.Logging'        = 'Logging'
        'Settings.Behavior'       = 'Behavior'
        'Settings.SelfUpdate'     = 'Self-update'
        'Settings.Shortcuts'      = 'Keyboard shortcuts'
        'Settings.Language'       = 'Language'
        'Settings.LogDir'         = 'Log folder:'
        'Settings.MinLevel'       = 'Minimum level:'
        'Settings.RetentionDays'  = 'Retention (days):'
        'Settings.DefaultScope'   = 'Default scope:'
        'Settings.Theme'          = 'Theme:'
        'Settings.UpdateUrl'      = 'Update URL:'
        'Settings.LanguageLabel'  = 'Language:'
        'Settings.AutoUpdateCheck'= 'Check for updates at startup'
        'Settings.ConfirmUninstall'='Ask for confirmation before uninstalling'
        'Settings.ConfirmUpdate'  = 'Ask for confirmation before updating'
        'Settings.MultiSelectTip' = 'Tip: Ctrl/Shift-click in Installed for multi-select bulk actions.'

        # --- Theme choices (ComboBox items) ---
        'Theme.Auto'              = 'Auto'
        'Theme.Dark'              = 'Dark'
        'Theme.Light'              = 'Light'

        # --- Language choices ---
        'Language.Auto'           = 'Automatic (system)'
        'Language.Dutch'          = 'Nederlands'
        'Language.English'        = 'English'

        # --- Keyboard shortcut descriptions ---
        'Shortcut.RefreshTab'     = 'Refresh current tab'
        'Shortcut.JumpSearch'     = 'Jump to Search tab'
        'Shortcut.OpenUpdates'    = 'Open Updates tab and check'
        'Shortcut.OpenLogs'       = 'Open Logs tab'
        'Shortcut.Close'          = 'Close the app'
        'Shortcut.ClearSearch'    = 'Clear search field on Search tab'
        'Shortcut.EnterSearch'    = 'In search field: instant search (skip 400ms wait)'

        # --- Messages / dialogs ---
        'Msg.WinGetNotFound'      = 'WinGet not found'
        'Msg.Loading'             = 'Loading...'
        'Msg.NoResults'           = 'No results'
        'Msg.ConfirmUninstall'    = 'Are you sure you want to uninstall {0}?'
        'Msg.ConfirmUpdate'       = 'Are you sure you want to update {0}?'
        'Msg.UpdateComplete'      = 'Update complete'
        'Msg.UpdateFailed'        = 'Update failed'
        'Msg.RestartRequired'     = 'Restart required'
        'Msg.LanguageChanged'     = 'Language changed to {0}. Restart the app to fully apply the change.'
        'Msg.LanguageChangedTitle'= 'Language changed'
    }
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

function Initialize-I18n {
    <#
    .SYNOPSIS
        Stel de actieve UI-taal in. 'auto' detecteert via CurrentUICulture.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Language
    )

    if ($Language -eq 'auto' -or [string]::IsNullOrWhiteSpace($Language)) {
        $detected = [System.Globalization.CultureInfo]::CurrentUICulture.Name
        if     ($detected -like 'nl-*') { $Language = 'nl-NL' }
        elseif ($detected -like 'en-*') { $Language = 'en-US' }
        else                            { $Language = 'en-US' }
    }

    if (-not $Script:Strings.ContainsKey($Language)) {
        Write-Warning "I18n: taal '$Language' niet beschikbaar, val terug op '$Script:FallbackLanguage'."
        $Language = $Script:FallbackLanguage
    }

    $Script:CurrentLanguage = $Language
}

function Get-CurrentLanguage {
    return $Script:CurrentLanguage
}

function Get-AvailableLanguages {
    return @($Script:Strings.Keys | Sort-Object)
}

function Get-Text {
    <#
    .SYNOPSIS
        Haalt vertaalde string op voor de actieve taal.
    .PARAMETER Key
        Sleutel zoals 'Tab.Search'.
    .PARAMETER FormatArgs
        Optionele format-argumenten voor strings met {0}, {1} placeholders.
    .EXAMPLE
        Get-Text 'Msg.ConfirmUninstall' -FormatArgs @('Firefox')
    #>
    param(
        [Parameter(Mandatory)][string]$Key,
        [object[]]$FormatArgs
    )

    $dict = $Script:Strings[$Script:CurrentLanguage]
    $text = $null
    if ($dict -and $dict.ContainsKey($Key)) {
        $text = $dict[$Key]
    } elseif ($Script:Strings[$Script:FallbackLanguage].ContainsKey($Key)) {
        $text = $Script:Strings[$Script:FallbackLanguage][$Key]
    } else {
        return "[$Key]"
    }

    # NB: don't use `if ($FormatArgs -and ...)` — `@(0) -and ...` evaluates to
    # $false in PowerShell because a single-element array unwraps to the scalar
    # 0, which is falsy. Check $null and Count explicitly instead.
    if ($null -ne $FormatArgs -and $FormatArgs.Count -gt 0) {
        try { $text = [string]::Format($text, $FormatArgs) } catch {}
    }
    return $text
}

function Apply-Translations {
    <#
    .SYNOPSIS
        Vervangt alle {{Key.Name}} placeholders in een XAML/string door vertalingen.
    .DESCRIPTION
        Gebruik vóór [Windows.Markup.XamlReader]::Parse zodat WPF de string
        ziet als gelokaliseerd. Ook bruikbaar op andere strings.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)][string]$Text
    )
    process {
        return [regex]::Replace($Text, '\{\{([A-Za-z][A-Za-z0-9_.]*)\}\}', {
            param($m)
            Get-Text -Key $m.Groups[1].Value
        })
    }
}

function Get-I18nStrings {
    # Returns the raw per-language string table. Used by the key-parity test
    # (tests/Test-I18nParity.ps1) to assert nl-NL and en-US stay in sync.
    return $Script:Strings
}

Export-ModuleMember -Function Initialize-I18n, Get-CurrentLanguage, Get-AvailableLanguages, Get-Text, Apply-Translations, Get-I18nStrings
