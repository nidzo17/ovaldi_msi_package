param ([switch] $schedule)

Function LoadConfig ($filename) {
    Get-Content ".\$filename" | foreach-object -begin {$config_dict=@{}} -process {
        $k = [regex]::split($_,'=') 
        if (($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True) `
        -and ($k[0].StartsWith("#") -ne $True)) {
            $config_dict.Add($k[0], $k[1])
        } 
    }
    return $config_dict
}

Function DownloadConfigFile {
    # NETBIOS domain
    $identifier=((gwmi WIN32_ComputerSystem).Domain)
    if(Test-Path \\$server_name\$remote_config_path\$identifier\config.ini) {
        Copy-Item -Path \\$server_name\$remote_config_path\$identifier\config.ini -Destination .\ovaldi_config.ini
        return
    }
    # ip address
    $identifier=Get-NetIPAddress
    if(Test-Path \\$server_name\$remote_config_path\$identifier\config.ini) {
        Copy-Item -Path \\$server_name\$remote_config_path\$identifier\config.ini -Destination .\ovaldi_config.ini
        return
    }
    # AD Domain
    $identifier=Get-ADDomain
    if(Test-Path \\server_name\$remote_config_path\$identifier\config.ini) {
        Copy-Item -Path \\server_name\$remote_config_path\$identifier\config.ini -Destination .\ovaldi_config.ini
        return
    }
}

Function DownloadDefinition ($source, $filename) {
    Write-Host “Downloading $source ...”
    $webclient = New-Object System.Net.WebClient
    $file = ".\oval_definitions\$filename.xml"
    $webclient.DownloadFile($source,$file)
    Write-Host “$filename Successfully downloaded”
    # or:
    #Copy-Item -Path \\$server_name\remote_definitions_path\$filename.xml -Destination .\oval_definitions\
}

# download specific definition and start ovaldi
Function CheckClasses {
    if ($ovaldi_config_dict.Get_Item("compilance") -eq 1) {
        # Copy-Item -Path \\$server_name\remote_definitions_path\compilance.xml -Destination .\oval_definitions\
        StartOvaldi compilance
        }
    if ($ovaldi_config_dict.Get_Item("inventory") -eq 1) {
        # Copy-Item -Path \\$server_name\remote_definitions_path\inventory.xml -Destination .\oval_definitions\
        StartOvaldi inventory
        }
    if ($ovaldi_config_dict.Get_Item("miscellaneous") -eq 1) {
        # Copy-Item -Path \\$server_name\remote_definitions_path\miscellaneous.xml -Destination .\oval_definitions\
        StartOvaldi miscellaneous
        }
    if ($ovaldi_config_dict.Get_Item("patch") -eq 1) {
        # Copy-Item -Path \\$server_name\remote_definitions_path\patch.xml -Destination .\oval_definitions\
        StartOvaldi patch
        }
    if ($ovaldi_config_dict.Get_Item("vulnerability") -eq 1) {
        # Copy-Item -Path \\$server_name\remote_definitions_path\vulnerability.xml -Destination .\oval_definitions\
        StartOvaldi vulnerability
        }
}
    
# start ovaldi and copy results to server
Function StartOvaldi ($definition) {
    & $ovaldi_path -m -o "$local_definitions_path\$definition.xml" -x "$local_results_path\$definition.html"
    #Copy-Item -Path "$local_results_path\$definition.html" -Destination "\\$server_name\remote_resuls_path\$definition.html"
    }

Function DownloadAll {
    DownloadDefinition "https://oval.mitre.org/rep-data/5.10/org.mitre.oval/c/platform/microsoft.windows.7.xml" "compilance"
    DownloadDefinition "https://oval.mitre.org/rep-data/5.10/org.mitre.oval/i/platform/microsoft.windows.7.xml" "inventory"
    DownloadDefinition "https://oval.mitre.org/rep-data/5.10/org.mitre.oval/m/oval.xml" "miscellaneous"
    DownloadDefinition "https://oval.mitre.org/rep-data/5.10/org.mitre.oval/p/platform/microsoft.windows.7.xml" "patch"
    DownloadDefinition "https://oval.mitre.org/rep-data/5.10/org.mitre.oval/v/platform/microsoft.windows.7.xml" "vulnerability"
    # Copy-Item -Path \\$server_name\remote_definitions_path\compilance.xml -Destination .\oval_definitions\
    # Copy-Item -Path \\$server_name\remote_definitions_path\inventory.xml -Destination .\oval_definitions\
    # Copy-Item -Path \\$server_name\remote_definitions_path\miscellaneous.xml -Destination .\oval_definitions\
    # Copy-Item -Path \\$server_name\remote_definitions_path\patch.xml -Destination .\oval_definitions\
    # Copy-Item -Path \\$server_name\remote_definitions_path\vulnerability.xml -Destination .\oval_definitions\
}

if ($schedule) {

    $server_config_dict=LoadConfig "server_config.ini"
    $server_name=$server_config_dict.Get_Item("server_name")
    #DownloadConfigFile
    $ovaldi_config_dict=LoadConfig "ovaldi_config.ini"
    
    $schedule_type=$ovaldi_config_dict.Get_Item("schedule_type")
    $schedule_value=$ovaldi_config_dict.Get_Item("schedule_value")
    
    schtasks /create /sc $schedule_type /mo $schedule_value `
    /RU system /tn "ovaldi_$schedule_value$schedule_type" /tr "powershell -c $($myinvocation.mycommand.definition)" 

    Copy-Item -Path .\ovaldi_config.ini -Destination .\ovaldi_config_copy.ini
    return
}

# switch to directory where the script lives
pushd (split-path -parent $myinvocation.mycommand.definition)

$server_config_dict=LoadConfig "server_config.ini"
$server_name=$server_config_dict.Get_Item("server_name")
DownloadConfigFile
$ovaldi_config_dict=LoadConfig "ovaldi_config.ini"
$ovaldi_config_copy_dict=LoadConfig "ovaldi_config_copy.ini"

$schedule_type=$ovaldi_config_dict.Get_Item("schedule_type")
$schedule_value=$ovaldi_config_dict.Get_Item("schedule_value")
$past_schedule_type=$ovaldi_config_copy_dict.Get_Item("schedule_type")
$past_schedule_value=$ovaldi_config_copy_dict.Get_Item("schedule_value")

$ovaldi_path = ".\ovaldi-5.10.1.7\ovaldi.exe"
$local_results_path = $ovaldi_config_dict.Get_Item("local_results_path")
$local_definitions_path = $ovaldi_config_dict.Get_Item("local_definitions_path")
$remote_results_path = $ovaldi_config_dict.Get_Item("remote_results_path")
$remote_definitions_path = $ovaldi_config_dict.Get_Item("remote_definitions_path")

CheckClasses
Copy-Item -Path .\ovaldi_config.ini -Destination .\ovaldi_config_copy.ini

popd