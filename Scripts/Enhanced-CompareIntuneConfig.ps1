# Intune Configuration Profile Comparison Tool - Enhanced Successor Policy Creator
<#
## Overview
This enhanced PowerShell script provides an intelligent system to compare Intune configuration profiles and create true successor policies that consolidate the best of both profiles with user-guided conflict resolution.

## Key Features

### 1. Intelligent Profile Analysis
- Compares two Intune configuration profiles
- Identifies matching, unique, and conflicting settings
- Provides clear categorization for decision making

### 2. Smart Conflict Resolution
- Detects settings that exist in both profiles with different values
- Presents conflicts to user with clear value comparison
- Allows user to choose source value, destination value, or exclude setting
- Example conflict: "Cortana above lock" - Source: Allow, Destination: Block

### 3. True Successor Policy Creation
- Creates a net-new policy that intelligently combines both profiles
- Includes ALL unique settings from both source and destination
- Includes ALL matching settings (identical in both profiles)  
- Includes user-resolved conflict settings with chosen values
- Excludes only the conflicts the user chose to skip

### 4. Interactive Menu System
- Lists all available configuration profiles
- Shows profile details (ID, platforms, technologies)
- Allows easy selection of source and destination profiles
- No need to manually input GUIDs

### 5. Comprehensive Reporting (CSV Output)
The script generates a detailed CSV file with:
- **Category**: Setting classification (MATCHING, SOURCE_ONLY, DESTINATION_ONLY, CONFLICT)
- **ConflictType**: Human-readable description of the difference
- **SettingDefinitionId**: Unique identifier for the setting
- **SettingName**: Human-readable setting name
- **Action**: What was done with this setting in the successor policy
- **SettingValue**: The actual value chosen for the successor policy
- **Details**: Complete JSON representation of the setting

### 6. Successor Policy (JSON Output)
Creates a ready-to-import JSON file containing:
- A completely new policy that consolidates both profiles
- ALL unique settings from both source AND destination profiles
- ALL matching settings (identical in both profiles)
- User-resolved conflict settings with chosen values
- Intelligent naming and description with creation timestamp
- Ready for direct import into Intune

### 7. Microsoft Graph Module Checking
- Automatically checks if required Microsoft Graph modules are installed
- Prompts to install missing modules if needed
- Required modules:
  - Microsoft.Graph.Authentication
  - Microsoft.Graph.DeviceManagement

### 8. Enhanced Authentication
- Connects to Microsoft Graph with proper scopes
- Supports different environments (Global, USGov, USGovDoD)
- Automatic disconnection on completion

## Usage Examples

### Interactive Mode (Recommended)
```powershell
# Run the enhanced interactive script
.\Enhanced-CompareIntuneConfig.ps1

# Run with specific environment
.\Enhanced-CompareIntuneConfig.ps1 -Environment USGov

# Run with custom output path
.\Enhanced-CompareIntuneConfig.ps1 -OutputPath "C:\Reports"
```

### Manual Mode (Direct Function Call)
```powershell
# Source the script first
. .\Enhanced-CompareIntuneConfig.ps1

# Then call the function directly
$result = Compare-IntuneConfigurationProfileSettings -SourceConfigurationId "your-source-id" -DestinationConfigurationId "your-destination-id"

# Export results manually (includes conflict resolution prompts)
Export-ComparisonResults -ComparisonResult $result -SourceProfileName "Source Profile" -DestinationProfileName "Dest Profile" -OutputPath "C:\Reports"
```

## Output Files
### CSV Detailed Report File
File: `ConfigProfile_Comparison_YYYYMMDD_HHMMSS_DetailedReport.csv`

Example content showing the new categorization:
```csv
Category,ConflictType,SettingDefinitionId,SettingName,Action,SettingValue
MATCHING,Identical Configuration,device_vendor_msft_policy_config_defender_allowfullscanonmappednetworkdrives,Allow Full Scan On Mapped Network Drives,Added to successor policy,Block
SOURCE_ONLY,Only in Source,device_vendor_msft_policy_config_cortana_allowcortanaabovelock,Allow Cortana Above Lock,Added to successor policy,Allow
DESTINATION_ONLY,Only in Destination,device_vendor_msft_policy_config_defender_enablenetworkprotection,Enable Network Protection,Added to successor policy,Enable
CONFLICT,Different Values,device_vendor_msft_policy_config_cortana_allowsearch,Allow Search,Use source value: Allow,Allow
```

### JSON Successor Policy File
File: `ConfigProfile_Comparison_YYYYMMDD_HHMMSS_SuccessorPolicy.json`

Example structure showing intelligent consolidation:
```json
{
  "@odata.type": "#microsoft.graph.deviceManagementConfigurationPolicy",
  "name": "Successor_SourceProfile_and_DestProfile_20250808_143022",
  "description": "SUCCESSOR POLICY: Consolidated from 'SourceProfile' and 'DestProfile' on 2025-08-08 14:30. POLICY COMPOSITION: - Total Settings: 45 - Matching Settings: 20 - Source-only Settings: 10 - Destination-only Settings: 12 - Total Conflicts Found: 3 - Conflicts Resolved: 2 - Conflicts Excluded: 1. This successor policy combines the best of both profiles with user-resolved conflicts.",
  "platforms": "windows10",
  "technologies": "mdm",
  "settings": [
    // All matching settings from both profiles
    // All unique settings from source profile  
    // All unique settings from destination profile
    // User-resolved conflict settings with chosen values
  ]
}
```

## Conflict Resolution Example

When conflicts are detected, the user sees:
```
CONFLICT: Allow Cortana Above Lock
Setting ID: device_vendor_msft_policy_config_cortana_allowcortanaabovelock

1. Source (SecurityProfile): Allow
2. Destination (UserExperienceProfile): Block  
3. Skip this setting (exclude from successor policy)

Choose option (1/2/3): 1
✓ Using source value for Allow Cortana Above Lock
```

## Prerequisites
- PowerShell 5.1 or later
- Internet connection for module installation
- Appropriate Intune permissions:
  - DeviceManagementConfiguration.Read.All
  - DeviceManagementConfiguration.ReadWrite.All (for enhanced features)

## Troubleshooting

### Module Installation Issues
If you encounter module installation issues:
```powershell
# Install manually with elevated privileges
Install-Module Microsoft.Graph.Authentication -Scope AllUsers -Force
Install-Module Microsoft.Graph.DeviceManagement -Scope AllUsers -Force
```

### Authentication Issues
- Ensure you have proper permissions in Azure AD
- Check that your account has Intune Administrator role
- Verify the correct environment is selected

### Profile Not Found
- Ensure the configuration profiles exist in your tenant
- Check that you're connected to the correct environment
- Verify the profile IDs are correct

## Tips
1. Run the interactive version for easier profile selection
2. Use descriptive output paths for better organization
3. Review the CSV conflicts file to understand differences
4. Test the consolidated JSON policy in a test environment first
5. Keep backups of original policies before making changes

## Support
For issues with the Microsoft Graph modules, refer to:
- [Microsoft Graph PowerShell SDK documentation](https://docs.microsoft.com/en-us/powershell/microsoftgraph/)
- [Microsoft Graph API documentation](https://docs.microsoft.com/en-us/graph/api/overview)

.PARAMETER Environment
    The environment to connect to. Valid values are Global, USGov, USGovDoD. Default is Global.
 
.PARAMETER OutputPath
    The path where output files (CSV and JSON) will be saved. Default is current directory.
#>

param(
    [ValidateSet("Global", "USGov", "USGovDoD")]
    [string]$Environment = "Global",
    [string]$OutputPath = $PSScriptRoot
)

#region Helper Functions

function Get-PowerShellEnvironmentInfo {
    <#
    .SYNOPSIS
        Gets information about the current PowerShell environment for optimal menu experience.
    #>
    
    $envInfo = [PSCustomObject]@{
        PSVersion = $PSVersionTable.PSVersion
        PSEdition = $PSVersionTable.PSEdition
        Platform = $PSVersionTable.Platform
        OS = $PSVersionTable.OS
        IsWindows = $true
        IsLinux = $false
        IsMacOS = $false
        SupportsGridView = $false
        SupportsGraphicalTools = $false
        SupportsConsoleGuiTools = $false
    }
    
    # Determine platform (PowerShell 6+ has platform variables)
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $envInfo.IsWindows = $IsWindows
        $envInfo.IsLinux = $IsLinux
        $envInfo.IsMacOS = $IsMacOS
    }
    
    # Check Out-GridView support (traditional)
    if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {
        $envInfo.SupportsGridView = $true
    }
    
    # Check ConsoleGuiTools support (modern cross-platform)
    if (Get-Command Out-ConsoleGridView -ErrorAction SilentlyContinue) {
        $envInfo.SupportsConsoleGuiTools = $true
    }
    
    # Check if GraphicalTools can be installed (PowerShell 7+ on Windows)
    if ($envInfo.PSVersion.Major -ge 7 -and $envInfo.IsWindows) {
        $envInfo.SupportsGraphicalTools = $true
    }
    
    return $envInfo
}

function Test-MicrosoftGraphModule {
    <#
    .SYNOPSIS
        Checks if Microsoft Graph PowerShell modules are installed and installs them if needed.
    #>
    
    Write-Host "Checking Microsoft Graph PowerShell modules..." -ForegroundColor Yellow
    
    $requiredModules = @(
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph.DeviceManagement"
    )
    
    # Optional modules for enhanced UI experience
    $optionalModules = @()
    
    # Add ConsoleGuiTools for modern cross-platform terminal UI
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $optionalModules += "Microsoft.PowerShell.ConsoleGuiTools"
    }
    
    $missingModules = @()
    $missingOptionalModules = @()
    
    # Check required modules
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -Name $module -ListAvailable)) {
            $missingModules += $module
        }
    }
    
    # Check optional modules
    foreach ($module in $optionalModules) {
        if (-not (Get-Module -Name $module -ListAvailable)) {
            $missingOptionalModules += $module
        }
    }
    
    # Install missing required modules
    if ($missingModules.Count -gt 0) {
        Write-Host "Missing required modules: $($missingModules -join ', ')" -ForegroundColor Red
        $install = Read-Host "Would you like to install the missing modules? (Y/N)"
        
        if ($install -eq 'Y' -or $install -eq 'y') {
            Write-Host "Installing Microsoft Graph modules..." -ForegroundColor Yellow
            
            foreach ($module in $missingModules) {
                try {
                    Write-Host "Installing $module..." -ForegroundColor Yellow
                    
                    # Try different installation methods for maximum compatibility
                    try {
                        Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -Repository PSGallery
                    }
                    catch {
                        # Fallback: try with -SkipPublisherCheck
                        Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
                    }
                    
                    Write-Host "Successfully installed $module" -ForegroundColor Green
                }
                catch {
                    Write-Error "Failed to install $module`: $_"
                    Write-Host "You may need to run PowerShell as Administrator or manually install the module." -ForegroundColor Yellow
                    return $false
                }
            }
        }
        else {
            Write-Host "Cannot proceed without required modules." -ForegroundColor Red
            return $false
        }
    }
    else {
        Write-Host "All required Microsoft Graph modules are installed." -ForegroundColor Green
    }
    
    # Offer to install optional modules for better experience
    if ($missingOptionalModules.Count -gt 0) {
        Write-Host "`nOptional modules available for enhanced experience:" -ForegroundColor Cyan
        foreach ($module in $missingOptionalModules) {
            if ($module -eq "Microsoft.PowerShell.ConsoleGuiTools") {
                Write-Host "- ConsoleGuiTools (modern cross-platform terminal UI)" -ForegroundColor Gray
            }
        }
        
        $installOptional = Read-Host "Install optional modules for better menu experience? (Y/N)"
        if ($installOptional -eq 'Y' -or $installOptional -eq 'y') {
            foreach ($module in $missingOptionalModules) {
                try {
                    Write-Host "Installing $module..." -ForegroundColor Yellow
                    
                    # Special handling for ConsoleGuiTools installation
                    if ($module -eq "Microsoft.PowerShell.ConsoleGuiTools") {
                        # Try different installation approaches for ConsoleGuiTools
                        try {
                            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -Repository PSGallery
                        }
                        catch {
                            # Alternative: try installing from PowerShell Gallery with explicit repository
                            Write-Host "Trying alternative installation method..." -ForegroundColor Yellow
                            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -AllowPrerelease -Repository PSGallery
                        }
                    }
                    
                    Write-Host "Successfully installed $module" -ForegroundColor Green
                }
                catch {
                    Write-Warning "Failed to install optional module $module`: $_"
                    
                    # Provide specific guidance for ConsoleGuiTools
                    if ($module -eq "Microsoft.PowerShell.ConsoleGuiTools") {
                        Write-Host "To manually install ConsoleGuiTools, try:" -ForegroundColor Yellow
                        Write-Host "Install-Module Microsoft.PowerShell.ConsoleGuiTools -AllowPrerelease" -ForegroundColor Gray
                    }
                    
                    Write-Host "Continuing without this module..." -ForegroundColor Yellow
                }
            }
        }
    }
    
    # Import the modules
    try {
        Write-Host "Importing Microsoft Graph modules..." -ForegroundColor Yellow
        foreach ($module in $requiredModules) {
            Import-Module -Name $module -Force
            Write-Host "Successfully imported $module" -ForegroundColor Green
        }
        
        # Try to import optional modules if available
        foreach ($module in $optionalModules) {
            if (Get-Module -Name $module -ListAvailable) {
                try {
                    Import-Module -Name $module -Force
                    Write-Host "Successfully imported optional module $module" -ForegroundColor Green
                }
                catch {
                    Write-Warning "Could not import optional module $module`: $_"
                }
            }
        }
    }
    catch {
        Write-Error "Failed to import modules: $_"
        return $false
    }
    
    return $true
}

function Initialize-GraphConnection {
    <#
    .SYNOPSIS
        Initializes connection to Microsoft Graph with required scopes.
    #>
    param(
        [string]$Environment = "Global"
    )
    
    try {
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
        
        $scopes = @(
            "DeviceManagementConfiguration.Read.All",
            "DeviceManagementConfiguration.ReadWrite.All"
        )
        
        # Set the environment
        switch ($Environment) {
            "USGov" { 
                Connect-MgGraph -Scopes $scopes -Environment USGov
            }
            "USGovDoD" { 
                Connect-MgGraph -Scopes $scopes -Environment USGovDoD
            }
            default { 
                Connect-MgGraph -Scopes $scopes
            }
        }
        
        $context = Get-MgContext
        if ($context) {
            Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
            Write-Host "Account: $($context.Account)" -ForegroundColor Gray
            Write-Host "Environment: $($context.Environment)" -ForegroundColor Gray
            return $true
        }
        else {
            Write-Error "Failed to establish Graph connection"
            return $false
        }
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph: $_"
        return $false
    }
}

function Show-ConfigurationProfileMenu {
    <#
    .SYNOPSIS
        Displays an interactive menu of configuration profiles for user selection using the best available UI.
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Profiles,
        [Parameter(Mandatory)]
        [string]$Title
    )
    
    # Prepare profile data for display
    $profilesForDisplay = @()
    for ($i = 0; $i -lt $Profiles.Count; $i++) {
        $profile = $Profiles[$i]
        $platforms = if ($profile.Platforms) { $profile.Platforms -join ", " } else { "Unknown" }
        $technologies = if ($profile.Technologies) { $profile.Technologies -join ", " } else { "Unknown" }
        
        # Handle different possible name properties
        $profileName = "Unknown"
        if ($profile.DisplayName) {
            $profileName = $profile.DisplayName
        } elseif ($profile.Name) {
            $profileName = $profile.Name
        } elseif ($profile.displayName) {
            $profileName = $profile.displayName
        } elseif ($profile.name) {
            $profileName = $profile.name
        }
        
        $profilesForDisplay += [PSCustomObject]@{
            Index = $i + 1
            Name = $profileName
            ID = $profile.Id
            Platforms = $platforms
            Technologies = $technologies
            Created = if ($profile.CreatedDateTime) { 
                try { 
                    [DateTime]::Parse($profile.CreatedDateTime).ToString("yyyy-MM-dd HH:mm") 
                } catch { 
                    $profile.CreatedDateTime 
                }
            } else { "Unknown" }
            Modified = if ($profile.LastModifiedDateTime) { 
                try { 
                    [DateTime]::Parse($profile.LastModifiedDateTime).ToString("yyyy-MM-dd HH:mm") 
                } catch { 
                    $profile.LastModifiedDateTime 
                }
            } else { "Unknown" }
        }
    }
    
    # Determine the best UI method to use (priority order)
    $uiMethod = "console"  # Default fallback
    
    # 1. First choice: ConsoleGuiTools (modern, cross-platform, terminal-based)
    if (Get-Command Out-ConsoleGridView -ErrorAction SilentlyContinue) {
        $uiMethod = "consolegui"
    }
    # 2. Second choice: Traditional GridView (Windows GUI-based)
    elseif (Get-Command Out-GridView -ErrorAction SilentlyContinue) {
        $uiMethod = "gridview"
    }
    # 3. Check if we can install ConsoleGuiTools for better experience
    elseif ($PSVersionTable.PSVersion.Major -ge 7) {
        if (-not (Get-Module -Name Microsoft.PowerShell.ConsoleGuiTools -ListAvailable)) {
            Write-Host "`n$Title" -ForegroundColor Cyan
            Write-Host "ConsoleGuiTools not detected. This provides a much better menu experience!" -ForegroundColor Yellow
            $installConsoleGui = Read-Host "Install ConsoleGuiTools for modern terminal UI? (Y/N)"
            if ($installConsoleGui -eq 'Y' -or $installConsoleGui -eq 'y') {
                try {
                    Write-Host "Installing Microsoft.PowerShell.ConsoleGuiTools..." -ForegroundColor Yellow
                    Install-Module -Name Microsoft.PowerShell.ConsoleGuiTools -Scope CurrentUser -Force -AllowClobber
                    Import-Module -Name Microsoft.PowerShell.ConsoleGuiTools -Force
                    $uiMethod = "consolegui"
                    Write-Host "Successfully installed ConsoleGuiTools!" -ForegroundColor Green
                }
                catch {
                    Write-Warning "Failed to install ConsoleGuiTools: $_"
                    Write-Host "Falling back to enhanced console menu..." -ForegroundColor Yellow
                }
            }
        }
        else {
            Import-Module -Name Microsoft.PowerShell.ConsoleGuiTools -Force
            $uiMethod = "consolegui"
        }
    }
    
    # Execute the appropriate UI method
    switch ($uiMethod) {
        "consolegui" {
            Write-Host "`n$Title" -ForegroundColor Cyan
            Write-Host "Opening modern terminal-based selection interface..." -ForegroundColor Yellow
            
            try {
                # Use Out-ConsoleGridView with enhanced display
                $selectedProfile = $profilesForDisplay | Out-ConsoleGridView -Title $Title
                
                if (-not $selectedProfile) {
                    return $null
                }
                
                # Return the original profile object
                return $Profiles[$selectedProfile.Index - 1]
            }
            catch {
                Write-Warning "ConsoleGuiTools failed: $_"
                Write-Host "Falling back to enhanced console menu..." -ForegroundColor Yellow
                # Fall through to console method
            }
        }
        
        "gridview" {
            Write-Host "`n$Title" -ForegroundColor Cyan
            Write-Host "Opening traditional GridView window..." -ForegroundColor Yellow
            
            try {
                $selectedProfile = $profilesForDisplay | Out-GridView -Title $Title -PassThru
                
                if (-not $selectedProfile) {
                    return $null
                }
                
                # Return the original profile object
                return $Profiles[$selectedProfile.Index - 1]
            }
            catch {
                Write-Warning "GridView failed: $_"
                Write-Host "Falling back to enhanced console menu..." -ForegroundColor Yellow
                # Fall through to console method
            }
        }
    }
    
    # Enhanced console menu with search and pagination (fallback)
    $pageSize = 10
    $currentPage = 0
    $searchTerm = ""
    $filteredProfiles = $profilesForDisplay
    
    while ($true) {
        Clear-Host
        Write-Host "`n===================================================" -ForegroundColor Cyan
        Write-Host "  $Title" -ForegroundColor Cyan
        Write-Host "===================================================" -ForegroundColor Cyan
        Write-Host "UI Mode: Enhanced Console (install ConsoleGuiTools for better experience)" -ForegroundColor Gray
        Write-Host ""
        
        if ($searchTerm) {
            Write-Host "Search filter: '$searchTerm' (showing $($filteredProfiles.Count) of $($profilesForDisplay.Count) profiles)" -ForegroundColor Yellow
        }
        else {
            Write-Host "Showing all $($profilesForDisplay.Count) profiles" -ForegroundColor Gray
        }
        
        # Calculate pagination
        $totalPages = [Math]::Ceiling($filteredProfiles.Count / $pageSize)
        $startIndex = $currentPage * $pageSize
        $endIndex = [Math]::Min($startIndex + $pageSize - 1, $filteredProfiles.Count - 1)
        
        if ($totalPages -gt 1) {
            Write-Host "Page $($currentPage + 1) of $totalPages (items $($startIndex + 1)-$($endIndex + 1))" -ForegroundColor Gray
        }
        
        Write-Host ""
        
        # Display current page of profiles
        for ($i = $startIndex; $i -le $endIndex; $i++) {
            if ($i -lt $filteredProfiles.Count) {
                $profile = $filteredProfiles[$i]
                $displayIndex = $i - $startIndex + 1
                
                Write-Host "$displayIndex. $($profile.Name)" -ForegroundColor White
                Write-Host "   ID: $($profile.ID)" -ForegroundColor Gray
                Write-Host "   Platforms: $($profile.Platforms)" -ForegroundColor Gray
                Write-Host "   Technologies: $($profile.Technologies)" -ForegroundColor Gray
                Write-Host "   Created: $($profile.Created) | Modified: $($profile.Modified)" -ForegroundColor DarkGray
                Write-Host ""
            }
        }
        
        # Menu options
        Write-Host "Navigation Options:" -ForegroundColor Cyan
        if ($totalPages -gt 1) {
            if ($currentPage -gt 0) { Write-Host "P. Previous page" -ForegroundColor Yellow }
            if ($currentPage -lt $totalPages - 1) { Write-Host "N. Next page" -ForegroundColor Yellow }
        }
        Write-Host "S. Search/Filter profiles" -ForegroundColor Yellow
        if ($searchTerm) { Write-Host "C. Clear search filter" -ForegroundColor Yellow }
        Write-Host "I. Install ConsoleGuiTools for better UI" -ForegroundColor Green
        Write-Host "0. Exit" -ForegroundColor Red
        Write-Host ""
        
        if ($filteredProfiles.Count -eq 0) {
            Write-Host "No profiles match your search criteria." -ForegroundColor Red
            $selection = Read-Host "Enter option (S to search, C to clear filter, I to install ConsoleGuiTools, 0 to exit)"
        }
        else {
            $maxSelection = [Math]::Min($pageSize, $filteredProfiles.Count - $startIndex)
            $selection = Read-Host "Select profile (1-$maxSelection) or option"
        }
        
        # Handle selection
        switch ($selection.ToUpper()) {
            'P' {
                if ($currentPage -gt 0) { $currentPage-- }
            }
            'N' {
                if ($currentPage -lt $totalPages - 1) { $currentPage++ }
            }
            'S' {
                $newSearchTerm = Read-Host "Enter search term (name, platform, or technology)"
                if ($newSearchTerm) {
                    $searchTerm = $newSearchTerm
                    $filteredProfiles = $profilesForDisplay | Where-Object {
                        $_.Name -like "*$searchTerm*" -or 
                        $_.Platforms -like "*$searchTerm*" -or 
                        $_.Technologies -like "*$searchTerm*"
                    }
                    $currentPage = 0
                }
            }
            'C' {
                $searchTerm = ""
                $filteredProfiles = $profilesForDisplay
                $currentPage = 0
            }
            'I' {
                if ($PSVersionTable.PSVersion.Major -ge 7) {
                    Write-Host "Installing ConsoleGuiTools..." -ForegroundColor Yellow
                    try {
                        Install-Module -Name Microsoft.PowerShell.ConsoleGuiTools -Scope CurrentUser -Force -AllowClobber
                        Import-Module -Name Microsoft.PowerShell.ConsoleGuiTools -Force
                        Write-Host "ConsoleGuiTools installed! Restart the script to use the enhanced UI." -ForegroundColor Green
                        Read-Host "Press Enter to continue with current menu"
                    }
                    catch {
                        Write-Warning "Failed to install ConsoleGuiTools: $_"
                        Read-Host "Press Enter to continue"
                    }
                }
                else {
                    Write-Host "ConsoleGuiTools requires PowerShell 7+. Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
                    Read-Host "Press Enter to continue"
                }
            }
            '0' {
                return $null
            }
            default {
                $selectionInt = 0
                if ([int]::TryParse($selection, [ref]$selectionInt)) {
                    $actualIndex = $startIndex + $selectionInt - 1
                    if ($selectionInt -ge 1 -and $actualIndex -lt $filteredProfiles.Count) {
                        $selectedProfile = $filteredProfiles[$actualIndex]
                        # Return the original profile object
                        return $Profiles[$selectedProfile.Index - 1]
                    }
                }
                Write-Host "Invalid selection. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Get-AllConfigurationProfiles {
    <#
    .SYNOPSIS
        Retrieves all Intune configuration profiles.
    #>
    
    try {
        Write-Host "Retrieving configuration profiles..." -ForegroundColor Yellow
        
        # Get configuration policies using Microsoft Graph
        # Try different cmdlets as the exact name may vary by module version
        $profiles = @()
        
        # Try the most common cmdlet first
        try {
            $profiles = Get-MgDeviceManagementConfigurationPolicy -All -ErrorAction Stop
        }
        catch {
            Write-Host "Trying alternative cmdlet..." -ForegroundColor Yellow
            try {
                # Alternative cmdlet name
                $profiles = Get-MgDeviceManagementDeviceConfigurationPolicy -All -ErrorAction Stop
            }
            catch {
                # If both fail, try using Invoke-MgGraphRequest directly
                Write-Host "Using direct Graph API call..." -ForegroundColor Yellow
                $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" -Method GET
                $profiles = $response.value
                
                # Get additional pages if they exist
                while ($response.'@odata.nextLink') {
                    $response = Invoke-MgGraphRequest -Uri $response.'@odata.nextLink' -Method GET
                    $profiles += $response.value
                }
            }
        }
        
        if ($profiles.Count -eq 0) {
            Write-Host "No configuration profiles found." -ForegroundColor Yellow
            return @()
        }
        
        Write-Host "Found $($profiles.Count) configuration profiles." -ForegroundColor Green
        return $profiles
    }
    catch {
        Write-Error "Failed to retrieve configuration profiles: $_"
        return @()
    }
}

function Get-ConfigurationProfileSettings {
    <#
    .SYNOPSIS
        Retrieves settings for a specific configuration profile.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProfileId
    )
    
    try {
        Write-Host "Retrieving settings for profile $ProfileId..." -ForegroundColor Yellow
        
        # Get the settings for the configuration profile using direct Graph API call
        try {
            # Try the cmdlet first
            $settings = Get-MgDeviceManagementConfigurationPolicySetting -DeviceManagementConfigurationPolicyId $ProfileId -All -ErrorAction Stop
        }
        catch {
            # If cmdlet fails, use direct Graph API call
            Write-Host "Using direct Graph API call for settings..." -ForegroundColor Yellow
            $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$ProfileId/settings" -Method GET
            $settings = $response.value
            
            # Get additional pages if they exist
            while ($response.'@odata.nextLink') {
                $response = Invoke-MgGraphRequest -Uri $response.'@odata.nextLink' -Method GET
                $settings += $response.value
            }
        }
        
        return $settings
    }
    catch {
        Write-Error "Failed to retrieve settings for profile $ProfileId`: $_"
        return @()
    }
}

function Resolve-SettingConflicts {
    <#
    .SYNOPSIS
        Handles conflict resolution for settings that exist in both profiles with different values.
    #>
    param(
        [Parameter(Mandatory)]
        [array]$ConflictingSettings,
        [Parameter(Mandatory)]
        [string]$SourceProfileName,
        [Parameter(Mandatory)]
        [string]$DestinationProfileName
    )
    
    $resolvedSettings = @()
    $conflictChoices = @()
    
    if ($ConflictingSettings.Count -eq 0) {
        return @{
            ResolvedSettings = @()
            ConflictChoices = @()
        }
    }
    
    Write-Host "`n===================================================" -ForegroundColor Red
    Write-Host "  CONFIGURATION CONFLICTS DETECTED" -ForegroundColor Red
    Write-Host "===================================================" -ForegroundColor Red
    Write-Host "The following settings have different values in both profiles." -ForegroundColor Yellow
    Write-Host "You need to choose which value to use in the successor policy." -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($conflict in $ConflictingSettings) {
        $settingId = $conflict.SourceSetting.settingInstance.settingDefinitionId
        $settingName = if ($settingId) {
            ($settingId -split '_')[-1] -replace '~', ' > '
        } else { "Unknown Setting" }
        
        # Extract values for comparison
        $sourceValue = Get-SettingDisplayValue -Setting $conflict.SourceSetting
        $destinationValue = Get-SettingDisplayValue -Setting $conflict.DestinationSetting
        
        Write-Host "CONFLICT: $settingName" -ForegroundColor Cyan
        Write-Host "Setting ID: $settingId" -ForegroundColor Gray
        Write-Host ""
        Write-Host "1. Source ($SourceProfileName): $sourceValue" -ForegroundColor Green
        Write-Host "2. Destination ($DestinationProfileName): $destinationValue" -ForegroundColor Yellow
        Write-Host "3. Skip this setting (exclude from successor policy)" -ForegroundColor Red
        Write-Host ""
        
        do {
            $choice = Read-Host "Choose option (1/2/3)"
        } while ($choice -notin @('1', '2', '3'))
        
        $conflictChoice = [PSCustomObject]@{
            SettingId = $settingId
            SettingName = $settingName
            SourceValue = $sourceValue
            DestinationValue = $destinationValue
            Choice = $choice
            ChosenSetting = $null
            Action = ""
        }
        
        switch ($choice) {
            '1' {
                $resolvedSettings += $conflict.SourceSetting
                $conflictChoice.ChosenSetting = "Source"
                $conflictChoice.Action = "Use source value: $sourceValue"
                Write-Host "✓ Using source value for $settingName" -ForegroundColor Green
            }
            '2' {
                $resolvedSettings += $conflict.DestinationSetting
                $conflictChoice.ChosenSetting = "Destination"
                $conflictChoice.Action = "Use destination value: $destinationValue"
                Write-Host "✓ Using destination value for $settingName" -ForegroundColor Green
            }
            '3' {
                $conflictChoice.ChosenSetting = "Skipped"
                $conflictChoice.Action = "Excluded from successor policy"
                Write-Host "✓ Skipping $settingName (will not be included)" -ForegroundColor Yellow
            }
        }
        
        $conflictChoices += $conflictChoice
        Write-Host ""
    }
    
    Write-Host "Conflict resolution completed!" -ForegroundColor Green
    Write-Host "Resolved conflicts: $($resolvedSettings.Count) of $($ConflictingSettings.Count)" -ForegroundColor Cyan
    Write-Host ""
    
    return @{
        ResolvedSettings = $resolvedSettings
        ConflictChoices = $conflictChoices
    }
}

function Get-SettingDisplayValue {
    <#
    .SYNOPSIS
        Extracts a human-readable value from a setting for display purposes.
    #>
    param(
        [Parameter(Mandatory)]
        [object]$Setting
    )
    
    try {
        $settingInstance = $Setting.settingInstance
        
        if ($settingInstance.choiceSettingValue) {
            $value = $settingInstance.choiceSettingValue.value
            if ($settingInstance.choiceSettingValue.children) {
                $childValues = $settingInstance.choiceSettingValue.children | ForEach-Object {
                    if ($_.choiceSettingValue) { $_.choiceSettingValue.value }
                    elseif ($_.simpleSettingValue) { $_.simpleSettingValue.value }
                }
                if ($childValues) {
                    $value += " (with: $($childValues -join ', '))"
                }
            }
            return $value
        }
        elseif ($settingInstance.simpleSettingValue) {
            return $settingInstance.simpleSettingValue.value
        }
        elseif ($settingInstance.groupSettingValue) {
            $groupValues = $settingInstance.groupSettingValue.children | ForEach-Object {
                if ($_.choiceSettingValue) { $_.choiceSettingValue.value }
                elseif ($_.simpleSettingValue) { $_.simpleSettingValue.value }
            }
            return "Group: ($($groupValues -join ', '))"
        }
        else {
            return "Complex setting (JSON)"
        }
    }
    catch {
        return "Unable to parse value"
    }
}

function Export-ComparisonResults {
    <#
    .SYNOPSIS
        Exports comparison results to CSV and JSON files with enhanced details and optional Intune import.
    #>
    param(
        [Parameter(Mandatory)]
        [object]$ComparisonResult,
        [Parameter(Mandatory)]
        [string]$SourceProfileName,
        [Parameter(Mandatory)]
        [string]$DestinationProfileName,
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [Parameter(Mandatory)]
        [string]$SourceProfileId,
        [Parameter(Mandatory)]
        [string]$DestinationProfileId,
        [Parameter(Mandatory)]
        [object]$SourceProfile,
        [Parameter(Mandatory)]
        [object]$DestinationProfile
    )
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $baseFileName = "ConfigProfile_Comparison_$timestamp"
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    # Handle conflicts and create successor policy
    Write-Host "`n===================================================" -ForegroundColor Cyan
    Write-Host "  SUCCESSOR POLICY CREATION" -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    
    # Resolve conflicts if any exist
    $conflictResolution = $null
    if ($ComparisonResult.conflicts -and $ComparisonResult.conflicts.Count -gt 0) {
        $conflictResolution = Resolve-SettingConflicts -ConflictingSettings $ComparisonResult.conflicts -SourceProfileName $SourceProfileName -DestinationProfileName $DestinationProfileName
    }
    
    # Create the successor policy settings
    $successorSettings = @()
    
    # Add all matching settings (no conflicts)
    foreach ($setting in $ComparisonResult.settingsMatch) {
        # Create clean setting object without temporary properties
        $cleanSetting = [PSCustomObject]@{
            "@odata.type" = $setting."@odata.type"
            settingInstance = $setting.settingInstance
        }
        $successorSettings += $cleanSetting
    }
    
    # Add all unique settings from source
    foreach ($setting in $ComparisonResult.sourceOnlySettings) {
        # Create clean setting object without temporary properties
        $cleanSetting = [PSCustomObject]@{
            "@odata.type" = $setting."@odata.type"
            settingInstance = $setting.settingInstance
        }
        $successorSettings += $cleanSetting
    }
    
    # Add all unique settings from destination
    foreach ($setting in $ComparisonResult.destinationOnlySettings) {
        # Create clean setting object without temporary properties
        $cleanSetting = [PSCustomObject]@{
            "@odata.type" = $setting."@odata.type"
            settingInstance = $setting.settingInstance
        }
        $successorSettings += $cleanSetting
    }
    
    # Add resolved conflict settings
    if ($conflictResolution -and $conflictResolution.ResolvedSettings) {
        foreach ($setting in $conflictResolution.ResolvedSettings) {
            # Create clean setting object without temporary properties
            $cleanSetting = [PSCustomObject]@{
                "@odata.type" = $setting."@odata.type"
                settingInstance = $setting.settingInstance
            }
            $successorSettings += $cleanSetting
        }
    }
    
    Write-Host "Successor Policy Content:" -ForegroundColor Yellow
    Write-Host "- Matching settings: $($ComparisonResult.settingsMatch.Count)" -ForegroundColor Green
    Write-Host "- Source-only settings: $($ComparisonResult.sourceOnlySettings.Count)" -ForegroundColor Cyan
    Write-Host "- Destination-only settings: $($ComparisonResult.destinationOnlySettings.Count)" -ForegroundColor Cyan
    if ($conflictResolution) {
        Write-Host "- Resolved conflicts: $($conflictResolution.ResolvedSettings.Count) of $($ComparisonResult.conflicts.Count)" -ForegroundColor Yellow
        Write-Host "- Excluded conflicts: $(($ComparisonResult.conflicts.Count) - ($conflictResolution.ResolvedSettings.Count))" -ForegroundColor Red
    }
    Write-Host "- Total settings in successor: $($successorSettings.Count)" -ForegroundColor White
    Write-Host ""
    
    # Create enhanced comparison report
    $reportData = @()
    
    # Header information
    $reportData += [PSCustomObject]@{
        Category = "COMPARISON_INFO"
        ConflictType = "Comparison Summary"
        SettingDefinitionId = ""
        SettingName = ""
        SourceProfile = $SourceProfileName
        SourceProfileId = $SourceProfileId
        DestinationProfile = $DestinationProfileName
        DestinationProfileId = $DestinationProfileId
        Action = "Comparison performed on $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
        Details = "Matching: $($ComparisonResult.settingsMatch.Count), Source-only: $($ComparisonResult.sourceOnlySettings.Count), Destination-only: $($ComparisonResult.destinationOnlySettings.Count), Conflicts: $(if ($ComparisonResult.conflicts) { $ComparisonResult.conflicts.Count } else { 0 })"
        SettingValue = ""
    }
    
    # Empty row for separation
    $reportData += [PSCustomObject]@{
        Category = ""
        ConflictType = ""
        SettingDefinitionId = ""
        SettingName = ""
        SourceProfile = ""
        SourceProfileId = ""
        DestinationProfile = ""
        DestinationProfileId = ""
        Action = ""
        Details = ""
        SettingValue = ""
    }
    
    # Add source-only settings
    foreach ($setting in $ComparisonResult.sourceOnlySettings) {
        $settingName = if ($setting.settingInstance.settingDefinitionId) {
            ($setting.settingInstance.settingDefinitionId -split '_')[-1] -replace '~', ' > '
        } else { "Unknown" }
        
        $settingValue = Get-SettingDisplayValue -Setting $setting
        
        $reportData += [PSCustomObject]@{
            Category = "SOURCE_ONLY"
            ConflictType = "Only in Source"
            SettingDefinitionId = $setting.settingInstance.settingDefinitionId
            SettingName = $settingName
            SourceProfile = $SourceProfileName
            SourceProfileId = $SourceProfileId
            DestinationProfile = $DestinationProfileName
            DestinationProfileId = $DestinationProfileId
            Action = "Added to successor policy"
            Details = ($setting.settingInstance | ConvertTo-Json -Depth 5 -Compress)
            SettingValue = $settingValue
        }
    }
    
    # Add destination-only settings
    foreach ($setting in $ComparisonResult.destinationOnlySettings) {
        $settingName = if ($setting.settingInstance.settingDefinitionId) {
            ($setting.settingInstance.settingDefinitionId -split '_')[-1] -replace '~', ' > '
        } else { "Unknown" }
        
        $settingValue = Get-SettingDisplayValue -Setting $setting
        
        $reportData += [PSCustomObject]@{
            Category = "DESTINATION_ONLY"
            ConflictType = "Only in Destination"
            SettingDefinitionId = $setting.settingInstance.settingDefinitionId
            SettingName = $settingName
            SourceProfile = $SourceProfileName
            SourceProfileId = $SourceProfileId
            DestinationProfile = $DestinationProfileName
            DestinationProfileId = $DestinationProfileId
            Action = "Added to successor policy"
            Details = ($setting.settingInstance | ConvertTo-Json -Depth 5 -Compress)
            SettingValue = $settingValue
        }
    }
    
    # Add conflicts and their resolutions
    if ($ComparisonResult.conflicts -and $ComparisonResult.conflicts.Count -gt 0) {
        foreach ($conflict in $ComparisonResult.conflicts) {
            $settingId = $conflict.SourceSetting.settingInstance.settingDefinitionId
            $settingName = if ($settingId) {
                ($settingId -split '_')[-1] -replace '~', ' > '
            } else { "Unknown" }
            
            $sourceValue = Get-SettingDisplayValue -Setting $conflict.SourceSetting
            $destinationValue = Get-SettingDisplayValue -Setting $conflict.DestinationSetting
            
            # Find the resolution choice
            $resolution = $conflictResolution.ConflictChoices | Where-Object { $_.SettingId -eq $settingId }
            $action = if ($resolution) { $resolution.Action } else { "Not resolved" }
            
            $reportData += [PSCustomObject]@{
                Category = "CONFLICT"
                ConflictType = "Different Values"
                SettingDefinitionId = $settingId
                SettingName = $settingName
                SourceProfile = $SourceProfileName
                SourceProfileId = $SourceProfileId
                DestinationProfile = $DestinationProfileName
                DestinationProfileId = $DestinationProfileId
                Action = $action
                Details = "Source: $sourceValue | Destination: $destinationValue"
                SettingValue = if ($resolution -and $resolution.ChosenSetting -eq "Source") { $sourceValue } elseif ($resolution -and $resolution.ChosenSetting -eq "Destination") { $destinationValue } else { "Excluded" }
            }
        }
    }
    
    # Add separator for matching settings
    $reportData += [PSCustomObject]@{
        Category = ""
        ConflictType = ""
        SettingDefinitionId = ""
        SettingName = ""
        SourceProfile = ""
        SourceProfileId = ""
        DestinationProfile = ""
        DestinationProfileId = ""
        Action = ""
        Details = ""
        SettingValue = ""
    }
    
    # Add matching settings (no conflicts)
    foreach ($setting in $ComparisonResult.settingsMatch) {
        $settingName = if ($setting.settingInstance.settingDefinitionId) {
            ($setting.settingInstance.settingDefinitionId -split '_')[-1] -replace '~', ' > '
        } else { "Unknown" }
        
        $settingValue = Get-SettingDisplayValue -Setting $setting
        
        $reportData += [PSCustomObject]@{
            Category = "MATCHING"
            ConflictType = "Identical Configuration"
            SettingDefinitionId = $setting.settingInstance.settingDefinitionId
            SettingName = $settingName
            SourceProfile = $SourceProfileName
            SourceProfileId = $SourceProfileId
            DestinationProfile = $DestinationProfileName
            DestinationProfileId = $DestinationProfileId
            Action = "Added to successor policy"
            Details = ($setting.settingInstance | ConvertTo-Json -Depth 5 -Compress)
            SettingValue = $settingValue
        }
    }
    
    # Export enhanced CSV report
    $csvPath = Join-Path $OutputPath "$baseFileName`_DetailedReport.csv"
    $reportData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "Detailed comparison report exported to: $csvPath" -ForegroundColor Green
    
    # Create consolidated successor policy
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    
    # Get actual profile names from the profile objects
    $actualSourceName = "Unknown"
    if ($SourceProfile.DisplayName) {
        $actualSourceName = $SourceProfile.DisplayName
    } elseif ($SourceProfile.Name) {
        $actualSourceName = $SourceProfile.Name
    } elseif ($SourceProfile.displayName) {
        $actualSourceName = $SourceProfile.displayName
    } elseif ($SourceProfile.name) {
        $actualSourceName = $SourceProfile.name
    }
    
    $actualDestinationName = "Unknown"
    if ($DestinationProfile.DisplayName) {
        $actualDestinationName = $DestinationProfile.DisplayName
    } elseif ($DestinationProfile.Name) {
        $actualDestinationName = $DestinationProfile.Name
    } elseif ($DestinationProfile.displayName) {
        $actualDestinationName = $DestinationProfile.displayName
    } elseif ($DestinationProfile.name) {
        $actualDestinationName = $DestinationProfile.name
    }
    
    $uniquePolicyName = "Successor_$actualSourceName`_and_$actualDestinationName`_$timestamp"
    
    # Create description
    $totalSettings = $successorSettings.Count
    $conflictCount = if ($ComparisonResult.conflicts) { $ComparisonResult.conflicts.Count } else { 0 }
    $resolvedConflicts = if ($conflictResolution) { $conflictResolution.ResolvedSettings.Count } else { 0 }
    
    $description = @"
SUCCESSOR POLICY: Consolidated from '$actualSourceName' and '$actualDestinationName' on $((Get-Date).ToString('yyyy-MM-dd HH:mm')).

POLICY COMPOSITION:
- Total Settings: $totalSettings
- Matching Settings: $($ComparisonResult.settingsMatch.Count)
- Source-only Settings: $($ComparisonResult.sourceOnlySettings.Count)
- Destination-only Settings: $($ComparisonResult.destinationOnlySettings.Count)
- Total Conflicts Found: $conflictCount
- Conflicts Resolved: $resolvedConflicts
- Conflicts Excluded: $($conflictCount - $resolvedConflicts)

This successor policy combines the best of both profiles with user-resolved conflicts. All unique settings from both profiles are included, matching settings are preserved, and conflicts were resolved through user selection.

Generated by Intune Config Profile Comparison Tool.
"@
    
    # Trim description if it exceeds 1700 characters
    if ($description.Length -gt 1700) {
        $description = $description.Substring(0, 1697) + "..."
    }
    
    $consolidatedPolicy = @{
        "@odata.type" = "#microsoft.graph.deviceManagementConfigurationPolicy"
        name = $uniquePolicyName
        description = $description
        platforms = "windows10"
        technologies = "mdm"
        settings = $successorSettings
    }
    
    # Export successor policy JSON
    $jsonPath = Join-Path $OutputPath "$baseFileName`_SuccessorPolicy.json"
    $consolidatedPolicy | ConvertTo-Json -Depth 50 | Out-File -FilePath $jsonPath -Encoding UTF8
    Write-Host "Successor policy exported to: $jsonPath" -ForegroundColor Green
    
    # Display successor policy summary
    Write-Host "`n===================================================" -ForegroundColor Cyan
    Write-Host "  SUCCESSOR POLICY READY" -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "Policy Name: $uniquePolicyName" -ForegroundColor White
    Write-Host "Total Settings: $totalSettings" -ForegroundColor White
    Write-Host "Description Length: $($description.Length)/1700 characters" -ForegroundColor Gray
    Write-Host "JSON File: $jsonPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "SUCCESSOR POLICY COMPOSITION:" -ForegroundColor Yellow
    Write-Host "- Matching settings from both profiles: $($ComparisonResult.settingsMatch.Count)" -ForegroundColor Green
    Write-Host "- Source-only settings: $($ComparisonResult.sourceOnlySettings.Count)" -ForegroundColor Cyan
    Write-Host "- Destination-only settings: $($ComparisonResult.destinationOnlySettings.Count)" -ForegroundColor Cyan
    if ($conflictResolution) {
        Write-Host "- Resolved conflicts: $($conflictResolution.ResolvedSettings.Count)" -ForegroundColor Yellow
        Write-Host "- Excluded conflicts: $(($ComparisonResult.conflicts.Count) - ($conflictResolution.ResolvedSettings.Count))" -ForegroundColor Red
    } else {
        Write-Host "- No conflicts found" -ForegroundColor Green
    }
    Write-Host ""
    
    # Ask user about importing into Intune
    Write-Host "IMPORT OPTIONS:" -ForegroundColor Cyan
    Write-Host "1. Import into Intune now (creates policy but not assigned)" -ForegroundColor Green
    Write-Host "2. Save JSON only (manual import later)" -ForegroundColor Yellow
    Write-Host "3. Skip import (comparison complete)" -ForegroundColor Gray
    Write-Host ""
    
    $importChoice = Read-Host "Choose option (1/2/3)"
    
    $newPolicyId = $null
    $importStatus = "Not imported"
    
    switch ($importChoice) {
        "1" {
            try {
                Write-Host "`nImporting consolidated policy into Intune..." -ForegroundColor Yellow
                
                # Create the policy using Microsoft Graph
                try {
                    $newPolicy = New-MgDeviceManagementConfigurationPolicy -BodyParameter $consolidatedPolicy
                    $newPolicyId = $newPolicy.Id
                    $importStatus = "Successfully imported"
                    Write-Host "✓ Successfully created new policy in Intune!" -ForegroundColor Green
                    Write-Host "✓ New Policy ID: $newPolicyId" -ForegroundColor Green
                    Write-Host "✓ Policy Name: $uniquePolicyName" -ForegroundColor Green
                }
                catch {
                    # Try using direct Graph API call if cmdlet fails
                    Write-Host "Trying direct Graph API call..." -ForegroundColor Yellow
                    $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" -Method POST -Body ($consolidatedPolicy | ConvertTo-Json -Depth 50)
                    $newPolicyId = $response.id
                    $importStatus = "Successfully imported"
                    Write-Host "✓ Successfully created new policy in Intune!" -ForegroundColor Green
                    Write-Host "✓ New Policy ID: $newPolicyId" -ForegroundColor Green
                    Write-Host "✓ Policy Name: $uniquePolicyName" -ForegroundColor Green
                }
                
                Write-Host "`nIMPORTANT NEXT STEPS:" -ForegroundColor Yellow
                Write-Host "1. The new policy has been created but is NOT assigned to any groups" -ForegroundColor Yellow
                Write-Host "2. Review the policy in Intune portal before assigning" -ForegroundColor Yellow
                Write-Host "3. Test in a pilot group before full deployment" -ForegroundColor Yellow
                Write-Host "4. Manually review conflicting settings that were excluded" -ForegroundColor Yellow
                
            }
            catch {
                $importStatus = "Failed to import"
                Write-Error "Failed to import policy into Intune: $_"
                Write-Host "The JSON file has been saved and can be imported manually." -ForegroundColor Yellow
            }
        }
        "2" {
            $importStatus = "JSON saved for manual import"
            Write-Host "`n✓ Policy JSON saved successfully!" -ForegroundColor Green
            Write-Host "You can manually import this policy later through:" -ForegroundColor Yellow
            Write-Host "- Intune portal > Devices > Configuration profiles > Import" -ForegroundColor Gray
            Write-Host "- PowerShell using: New-MgDeviceManagementConfigurationPolicy" -ForegroundColor Gray
        }
        "3" {
            $importStatus = "Import skipped by user"
            Write-Host "`n✓ Comparison completed!" -ForegroundColor Green
            Write-Host "JSON file saved for future reference: $jsonPath" -ForegroundColor Gray
        }
        default {
            $importStatus = "Invalid choice - import skipped"
            Write-Host "`nInvalid choice. Policy JSON saved but not imported." -ForegroundColor Yellow
            Write-Host "File location: $jsonPath" -ForegroundColor Gray
        }
    }
    
    # Summary report
    Write-Host "`nComparison Summary:" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    Write-Host "Matching Settings: $($ComparisonResult.settingsMatch.Count)" -ForegroundColor Green
    Write-Host "Source-only Settings: $($ComparisonResult.sourceOnlySettings.Count)" -ForegroundColor Cyan
    Write-Host "Destination-only Settings: $($ComparisonResult.destinationOnlySettings.Count)" -ForegroundColor Cyan
    if ($ComparisonResult.conflicts) {
        Write-Host "Configuration Conflicts: $($ComparisonResult.conflicts.Count)" -ForegroundColor Red
        if ($conflictResolution) {
            Write-Host "Conflicts Resolved: $($conflictResolution.ResolvedSettings.Count)" -ForegroundColor Yellow
            Write-Host "Conflicts Excluded: $(($ComparisonResult.conflicts.Count) - ($conflictResolution.ResolvedSettings.Count))" -ForegroundColor Red
        }
    } else {
        Write-Host "Configuration Conflicts: 0" -ForegroundColor Green
    }
    Write-Host "Total Settings in Successor: $totalSettings" -ForegroundColor White
    
    return @{
        DetailedReportFile = $csvPath
        SuccessorPolicyFile = $jsonPath
        NewPolicyId = $newPolicyId
        NewPolicyName = $uniquePolicyName
        ConflictResolution = $conflictResolution
        Summary = @{
            MatchingSettings = $ComparisonResult.settingsMatch.Count
            SourceOnlySettings = $ComparisonResult.sourceOnlySettings.Count
            DestinationOnlySettings = $ComparisonResult.destinationOnlySettings.Count
            TotalConflicts = if ($ComparisonResult.conflicts) { $ComparisonResult.conflicts.Count } else { 0 }
            ResolvedConflicts = if ($conflictResolution) { $conflictResolution.ResolvedSettings.Count } else { 0 }
            SuccessorSettingsTotal = $totalSettings
        }
    }
}

#endregion

#region Original Compare Function (Enhanced)

function Compare-IntuneConfigurationProfileSettings {
    <#
    .SYNOPSIS
        Compares two Intune configuration profiles and identifies matching, unique, and conflicting settings.
     
    .DESCRIPTION
        Compares two Intune configuration profiles and returns detailed comparison results with proper categorization
        of settings for creating a successor policy that intelligently merges both profiles.
     
    .PARAMETER SourceConfigurationId
        The id of the source configuration profile to compare.
     
    .PARAMETER DestinationConfigurationId
        The id of the destination configuration profile to compare.
     
    .EXAMPLE
        Compare-IntuneConfigurationProfileSettings -SourceConfigurationId "00000000-0000-0000-0000-000000000000" -DestinationConfigurationId "11111111-1111-1111-1111-111111111111"
    #>
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$SourceConfigurationId,
        [Parameter(Mandatory, Position=1)]
        [string]$DestinationConfigurationId
    )

    try {
        # Get the source and destination configurations
        Write-Host "Retrieving source configuration profile..." -ForegroundColor Yellow
        try {
            $sourceConfiguration = Get-MgDeviceManagementConfigurationPolicy -DeviceManagementConfigurationPolicyId $SourceConfigurationId -ErrorAction Stop
        }
        catch {
            # Try direct Graph API call
            $sourceConfiguration = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$SourceConfigurationId" -Method GET
        }
        
        Write-Host "Retrieving destination configuration profile..." -ForegroundColor Yellow
        try {
            $destinationConfiguration = Get-MgDeviceManagementConfigurationPolicy -DeviceManagementConfigurationPolicyId $DestinationConfigurationId -ErrorAction Stop
        }
        catch {
            # Try direct Graph API call
            $destinationConfiguration = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$DestinationConfigurationId" -Method GET
        }

        if (-not $sourceConfiguration) {
            Write-Error "Source configuration profile not found: $SourceConfigurationId"
            return
        }

        if (-not $destinationConfiguration) {
            Write-Error "Destination configuration profile not found: $DestinationConfigurationId"
            return
        }

        # Check that the technologies match
        if ($sourceConfiguration.Technologies -ne $destinationConfiguration.Technologies) {
            Write-Host "Technologies do not match. Source: $($sourceConfiguration.Technologies -join ', '), Destination: $($destinationConfiguration.Technologies -join ', ')" -ForegroundColor Red
            $continue = Read-Host "Continue anyway? (Y/N)"
            if ($continue -ne 'Y' -and $continue -ne 'y') {
                return
            }
        }

        # Check that the platforms match
        if ($sourceConfiguration.Platforms -ne $destinationConfiguration.Platforms) {
            Write-Host "Platforms do not match. Source: $($sourceConfiguration.Platforms -join ', '), Destination: $($destinationConfiguration.Platforms -join ', ')" -ForegroundColor Red
            $continue = Read-Host "Continue anyway? (Y/N)"
            if ($continue -ne 'Y' -and $continue -ne 'y') {
                return
            }
        }

        # Get the settings from both configurations
        $sourceSettings = Get-ConfigurationProfileSettings -ProfileId $SourceConfigurationId
        $destinationSettings = Get-ConfigurationProfileSettings -ProfileId $DestinationConfigurationId

        if (-not $sourceSettings) {
            Write-Warning "No settings found in source configuration profile"
            $sourceSettings = @()
        }

        if (-not $destinationSettings) {
            Write-Warning "No settings found in destination configuration profile"
            $destinationSettings = @()
        }

        Write-Host "Analyzing settings..." -ForegroundColor Yellow
        Write-Host "Source settings: $($sourceSettings.Count)" -ForegroundColor Gray
        Write-Host "Destination settings: $($destinationSettings.Count)" -ForegroundColor Gray

        # Normalize settings for comparison
        $normalizedSourceSettings = @()
        $normalizedDestinationSettings = @()

        # Normalize source settings
        foreach ($setting in $sourceSettings) {
            $normalizedSetting = [PSCustomObject]@{
                "@odata.type" = "#microsoft.graph.deviceManagementConfigurationSetting"  
                settingInstance = if ($setting.SettingInstance) { $setting.SettingInstance } else { $setting.settingInstance }
            }
            # Store the definition ID separately for comparison but don't include it in the setting object
            $definitionId = if ($setting.SettingInstance) { $setting.SettingInstance.SettingDefinitionId } else { $setting.settingInstance.settingDefinitionId }
            Add-Member -InputObject $normalizedSetting -NotePropertyName "_definitionId" -NotePropertyValue $definitionId
            $normalizedSourceSettings += $normalizedSetting
        }

        # Normalize destination settings
        foreach ($setting in $destinationSettings) {
            $normalizedSetting = [PSCustomObject]@{
                "@odata.type" = "#microsoft.graph.deviceManagementConfigurationSetting"  
                settingInstance = if ($setting.SettingInstance) { $setting.SettingInstance } else { $setting.settingInstance }
            }
            # Store the definition ID separately for comparison but don't include it in the setting object
            $definitionId = if ($setting.SettingInstance) { $setting.SettingInstance.SettingDefinitionId } else { $setting.settingInstance.settingDefinitionId }
            Add-Member -InputObject $normalizedSetting -NotePropertyName "_definitionId" -NotePropertyValue $definitionId
            $normalizedDestinationSettings += $normalizedSetting
        }

        # Create lookup dictionaries
        $sourceSettingsLookup = @{}
        $destinationSettingsLookup = @{}

        foreach ($setting in $normalizedSourceSettings) {
            $sourceSettingsLookup[$setting._definitionId] = $setting
        }

        foreach ($setting in $normalizedDestinationSettings) {
            $destinationSettingsLookup[$setting._definitionId] = $setting
        }

        # Get all unique setting definition IDs
        $allSettingIds = @()
        $allSettingIds += $sourceSettingsLookup.Keys
        $allSettingIds += $destinationSettingsLookup.Keys
        $allSettingIds = $allSettingIds | Select-Object -Unique

        # Categorize settings
        $settingsMatch = @()          # Settings that exist in both profiles with identical values
        $sourceOnlySettings = @()     # Settings that exist only in source profile
        $destinationOnlySettings = @() # Settings that exist only in destination profile
        $conflicts = @()              # Settings that exist in both profiles but with different values

        Write-Host "Categorizing settings..." -ForegroundColor Yellow

        foreach ($settingId in $allSettingIds) {
            $inSource = $sourceSettingsLookup.ContainsKey($settingId)
            $inDestination = $destinationSettingsLookup.ContainsKey($settingId)

            if ($inSource -and $inDestination) {
                # Setting exists in both - check if they match
                $sourceSetting = $sourceSettingsLookup[$settingId]
                $destinationSetting = $destinationSettingsLookup[$settingId]

                # Compare the actual setting values
                $sourceJson = $sourceSetting.settingInstance | ConvertTo-Json -Depth 50 -Compress
                $destinationJson = $destinationSetting.settingInstance | ConvertTo-Json -Depth 50 -Compress

                if ($sourceJson -eq $destinationJson) {
                    # Identical settings
                    $settingsMatch += $sourceSetting
                } else {
                    # Conflicting settings
                    $conflict = [PSCustomObject]@{
                        SettingDefinitionId = $settingId
                        SourceSetting = $sourceSetting
                        DestinationSetting = $destinationSetting
                    }
                    $conflicts += $conflict
                }
            }
            elseif ($inSource) {
                # Setting only in source
                $sourceOnlySettings += $sourceSettingsLookup[$settingId]
            }
            elseif ($inDestination) {
                # Setting only in destination
                $destinationOnlySettings += $destinationSettingsLookup[$settingId]
            }
        }

        Write-Host "Analysis complete!" -ForegroundColor Green
        Write-Host "- Matching settings: $($settingsMatch.Count)" -ForegroundColor Green
        Write-Host "- Source-only settings: $($sourceOnlySettings.Count)" -ForegroundColor Cyan  
        Write-Host "- Destination-only settings: $($destinationOnlySettings.Count)" -ForegroundColor Cyan
        Write-Host "- Conflicting settings: $($conflicts.Count)" -ForegroundColor Red

        $result = [PSCustomObject]@{
            settingsMatch = $settingsMatch
            sourceOnlySettings = $sourceOnlySettings
            destinationOnlySettings = $destinationOnlySettings
            conflicts = $conflicts
        }
        
        return $result
    }
    catch {
        Write-Error "Error comparing configuration profiles: $_"
        return $null
    }
}
        $sourceSettings = Get-ConfigurationProfileSettings -ProfileId $SourceConfigurationId
        $destinationSettings = Get-ConfigurationProfileSettings -ProfileId $DestinationConfigurationId

        if (-not $sourceSettings) {
            Write-Warning "No settings found in source configuration profile"
            $sourceSettings = @()
        }

        if (-not $destinationSettings) {
            Write-Warning "No settings found in destination configuration profile"
            $destinationSettings = @()
        }



#endregion

#region Main Interactive Menu

function Start-InteractiveComparison {
    <#
    .SYNOPSIS
        Starts the interactive configuration profile comparison process.
    #>
    
    # Get environment information
    $envInfo = Get-PowerShellEnvironmentInfo
    
    Write-Host "`n===================================================" -ForegroundColor Cyan
    Write-Host "  Intune Configuration Profile Comparison Tool" -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($envInfo.PSVersion) ($($envInfo.PSEdition))" -ForegroundColor Gray
    Write-Host "Platform: $($envInfo.Platform)" -ForegroundColor Gray
    
    if ($envInfo.SupportsGridView) {
        Write-Host "UI Mode: Enhanced (GridView available)" -ForegroundColor Green
    } elseif ($envInfo.SupportsGraphicalTools) {
        Write-Host "UI Mode: Enhanced (GraphicalTools can be installed)" -ForegroundColor Yellow
    } else {
        Write-Host "UI Mode: Console (Enhanced console menus)" -ForegroundColor Cyan
    }
    Write-Host ""
    
    # Check and install required modules
    if (-not (Test-MicrosoftGraphModule)) {
        Write-Host "Required modules are not available. Exiting." -ForegroundColor Red
        return
    }
    
    # Connect to Microsoft Graph
    if (-not (Initialize-GraphConnection -Environment $Environment)) {
        Write-Host "Failed to connect to Microsoft Graph. Exiting." -ForegroundColor Red
        return
    }
    
    # Get all configuration profiles
    $allProfiles = Get-AllConfigurationProfiles
    
    if ($allProfiles.Count -eq 0) {
        Write-Host "No configuration profiles found. Exiting." -ForegroundColor Red
        return
    }
    
    # Select source profile
    $sourceProfile = Show-ConfigurationProfileMenu -Profiles $allProfiles -Title "Select SOURCE Configuration Profile"
    if (-not $sourceProfile) {
        Write-Host "No source profile selected. Exiting." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nSelected SOURCE profile: $($sourceProfile.DisplayName -or $sourceProfile.Name -or $sourceProfile.displayName -or $sourceProfile.name -or 'Unknown')" -ForegroundColor Green
    
    # Debug: Show profile properties
    Write-Host "DEBUG - Source profile ID: '$($sourceProfile.Id)'" -ForegroundColor Gray
    Write-Host "DEBUG - Source profile id: '$($sourceProfile.id)'" -ForegroundColor Gray
    Write-Host "DEBUG - Source profile properties: $($sourceProfile | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name | Where-Object { $_ -like '*id*' -or $_ -like '*Id*' })" -ForegroundColor Gray
    
    # Select destination profile  
    $destinationProfile = Show-ConfigurationProfileMenu -Profiles $allProfiles -Title "Select DESTINATION Configuration Profile"
    if (-not $destinationProfile) {
        Write-Host "No destination profile selected. Exiting." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nSelected DESTINATION profile: $($destinationProfile.DisplayName -or $destinationProfile.Name -or $destinationProfile.displayName -or $destinationProfile.name -or 'Unknown')" -ForegroundColor Green
    
    # Debug: Show profile properties
    Write-Host "DEBUG - Destination profile ID: '$($destinationProfile.Id)'" -ForegroundColor Gray
    Write-Host "DEBUG - Destination profile id: '$($destinationProfile.id)'" -ForegroundColor Gray
    Write-Host "DEBUG - Destination profile properties: $($destinationProfile | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name | Where-Object { $_ -like '*id*' -or $_ -like '*Id*' })" -ForegroundColor Gray
    
    # Confirm the comparison
    $sourceProfileName = $sourceProfile.DisplayName -or $sourceProfile.Name -or $sourceProfile.displayName -or $sourceProfile.name -or 'Unknown'
    $destinationProfileName = $destinationProfile.DisplayName -or $destinationProfile.Name -or $destinationProfile.displayName -or $destinationProfile.name -or 'Unknown'
    
    Write-Host "`nComparison Details:" -ForegroundColor Cyan
    $sourceDisplayId = if (-not [string]::IsNullOrWhiteSpace($sourceProfile.Id)) { $sourceProfile.Id } elseif (-not [string]::IsNullOrWhiteSpace($sourceProfile.id)) { $sourceProfile.id } else { "Unknown" }
    $destinationDisplayId = if (-not [string]::IsNullOrWhiteSpace($destinationProfile.Id)) { $destinationProfile.Id } elseif (-not [string]::IsNullOrWhiteSpace($destinationProfile.id)) { $destinationProfile.id } else { "Unknown" }
    Write-Host "Source: $sourceProfileName (ID: $sourceDisplayId)" -ForegroundColor White
    Write-Host "Destination: $destinationProfileName (ID: $destinationDisplayId)" -ForegroundColor White
    Write-Host "Output Path: $OutputPath" -ForegroundColor White
    
    $confirm = Read-Host "`nProceed with comparison? (Y/N)"
    if ($confirm -ne 'Y' -and $confirm -ne 'y') {
        Write-Host "Comparison cancelled." -ForegroundColor Yellow
        return
    }
    
    # Perform the comparison
    Write-Host "`nStarting comparison..." -ForegroundColor Yellow
    
    # Get the actual profile IDs - handle both uppercase and lowercase property names
    $sourceId = $null
    if (-not [string]::IsNullOrWhiteSpace($sourceProfile.Id)) {
        $sourceId = $sourceProfile.Id
    } elseif (-not [string]::IsNullOrWhiteSpace($sourceProfile.id)) {
        $sourceId = $sourceProfile.id
    }
    
    $destinationId = $null
    if (-not [string]::IsNullOrWhiteSpace($destinationProfile.Id)) {
        $destinationId = $destinationProfile.Id
    } elseif (-not [string]::IsNullOrWhiteSpace($destinationProfile.id)) {
        $destinationId = $destinationProfile.id
    }
    
    Write-Host "Using source ID: '$sourceId'" -ForegroundColor Gray
    Write-Host "Using destination ID: '$destinationId'" -ForegroundColor Gray
    
    if ([string]::IsNullOrWhiteSpace($sourceId) -or [string]::IsNullOrWhiteSpace($destinationId)) {
        Write-Error "Failed to get profile IDs. Source ID: '$sourceId', Destination ID: '$destinationId'"
        Write-Host "DEBUG - Available source properties:" -ForegroundColor Red
        $sourceProfile | Get-Member -MemberType Properties | Select-Object Name, Definition | Format-Table -AutoSize
        Write-Host "DEBUG - Available destination properties:" -ForegroundColor Red
        $destinationProfile | Get-Member -MemberType Properties | Select-Object Name, Definition | Format-Table -AutoSize
        return
    }
    
    $comparisonResult = Compare-IntuneConfigurationProfileSettings -SourceConfigurationId $sourceId -DestinationConfigurationId $destinationId
    
    if (-not $comparisonResult) {
        Write-Host "Comparison failed." -ForegroundColor Red
        return
    }
    
    # Export results
    Write-Host "`nExporting results..." -ForegroundColor Yellow
    $exportResult = Export-ComparisonResults -ComparisonResult $comparisonResult -SourceProfileName $sourceProfileName -DestinationProfileName $destinationProfileName -OutputPath $OutputPath -SourceProfileId $sourceProfile.Id -DestinationProfileId $destinationProfile.Id -SourceProfile $sourceProfile -DestinationProfile $destinationProfile
    
    Write-Host "`nComparison completed successfully!" -ForegroundColor Green
    
    Write-Host "Detailed report file: $($exportResult.DetailedReportFile)" -ForegroundColor Yellow
    Write-Host "Successor policy file: $($exportResult.SuccessorPolicyFile)" -ForegroundColor Yellow
    
    if ($exportResult.NewPolicyId) {
        Write-Host "`nNEW SUCCESSOR POLICY CREATED:" -ForegroundColor Green
        Write-Host "Policy Name: $($exportResult.NewPolicyName)" -ForegroundColor Green
        Write-Host "Policy ID: $($exportResult.NewPolicyId)" -ForegroundColor Green
        Write-Host "Status: Ready for assignment in Intune" -ForegroundColor Green
    }
    
    # Display final summary
    Write-Host "`nFINAL SUMMARY:" -ForegroundColor Cyan
    Write-Host "=============" -ForegroundColor Cyan
    if ($exportResult.ConflictResolution -and $exportResult.ConflictResolution.ConflictChoices) {
        Write-Host "Conflicts resolved through user choice:" -ForegroundColor Yellow
        foreach ($choice in $exportResult.ConflictResolution.ConflictChoices) {
            $statusColor = switch ($choice.ChosenSetting) {
                "Source" { "Green" }
                "Destination" { "Yellow" }
                "Skipped" { "Red" }
                default { "Gray" }
            }
            Write-Host "  - $($choice.SettingName): $($choice.Action)" -ForegroundColor $statusColor
        }
    }
    Write-Host "The successor policy is a true consolidation of both profiles with your conflict resolutions." -ForegroundColor Green
}

#endregion

# Main execution
try {
    Start-InteractiveComparison
}
catch {
    Write-Error "An unexpected error occurred: $_"
}
finally {
    # Disconnect from Graph
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-Host "`nDisconnected from Microsoft Graph." -ForegroundColor Gray
    }
    catch {
        # Ignore disconnect errors
    }
}
