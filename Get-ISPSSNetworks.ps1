
function Get-AWSRegion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, HelpMessage='Please provide the subdomain')]
        [ValidateNotNullOrEmpty()]
        [string]$subdomain

    )

    begin {
        try {
            $ispss_vault_address = "vault-$($subdomain).privilegecloud.cyberark.cloud"
            $ip = ([System.Net.Dns]::GetHostAddresses($ispss_vault_address)).IpAddressToString
        }
        catch {
            throw "Tenant not in ISPSS (Shared Services)"
        }
    }

    process {
        $awsIpRanges = Get-Content -Path "aws-ip-ranges.json" | ConvertFrom-Json
        # Loop through each prefix in the JSON file
        foreach ($prefix in $awsIpRanges.prefixes) {
            $networkAddress, $prefixLength = $prefix.ip_prefix -split '/'

            # Convert the network address and IP address to byte arrays
            $networkAddressBytes = [System.Net.IPAddress]::Parse($networkAddress).GetAddressBytes()
            $ipBytes = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()

            # Reverse the byte arrays
            [array]::Reverse($networkAddressBytes)
            [array]::Reverse($ipBytes)

            # Convert the reversed byte arrays to 32-bit integers
            $networkAddressInt = [System.BitConverter]::ToUInt32($networkAddressBytes, 0)
            $ipInt = [System.BitConverter]::ToUInt32($ipBytes, 0)

            # Calculate the network mask from the prefix length
            $networkMask = -bnot ([Math]::Pow(2, 32 - $prefixLength) - 1)

            # Check if the IP address is in the CIDR block
            if (($networkAddressInt -band $networkMask) -eq ($ipInt -band $networkMask)) {
                return $prefix.region
            }
        }
    }

    end {

    }
}

function Set-Template {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, HelpMessage='Please provide the template path')]
        [ValidateNotNullOrEmpty()]
        [string]$template,

        [Parameter(Mandatory=$true, HelpMessage='Please provide the array of place holders')]
        [ValidateNotNullOrEmpty()]
        [array]$placeholders,

        [Parameter(Mandatory=$true, HelpMessage='Please provide the array of placeholder values')]
        [ValidateNotNullOrEmpty()]
        [array]$placeholderValues,

        [Parameter(Mandatory=$true, HelpMessage='Please provide the output file full path')]
        [ValidateNotNullOrEmpty()]
        [string]$outputFilePath
    )

    begin {
        $templateData = Get-Content -Path $template -Raw
    }

    process {
        for($i = 0; $i -lt $placeholders.Count; $i++){
            $templateData = $templateData -replace $placeholders[$i], $placeholderValues[$i]
        }

    }

    end {
        Write-Host $template
        $templateData | Set-Content -Path $outputFilePath
    }
}

if(-not (Test-Path "$PSScriptRoot\aws-ip-ranges.json")){
    Invoke-WebRequest -Uri "https://ip-ranges.amazonaws.com/ip-ranges.json" -OutFile "aws-ip-ranges.json"
}
$subdomain = Read-Host "Enter the subdomain"
try {
    $identityTenantBaseUrl= Invoke-WebRequest "https://$($subdomain).cyberark.cloud" -MaximumRedirection 0  -ErrorAction SilentlyContinue
    $identityTenantUrl = ([System.Uri]$identityTenantBaseUrl.headers.Location).Host
    $identityTenantId =  $identityTenantUrl.Split(".")[0]
    Write-Output "Identity Tenant id is $($identityTenantId)"
}
catch {
    Write-Error "Incorrect Subdomain"
}
$AWSRegion = Get-AWSRegion -subdomain $subdomain
Write-Output "AWS region is $($AWSRegion)"
$IdentitySysinfo = Invoke-WebRequest "https://$($identityTenantUrl)/sysinfo/version"
$Identitypod = ($IdentitySysinfo.Content|ConvertFrom-Json).Result.Name.Split(".")[0]
Set-Template -template "$PSScriptRoot\network_template.txt" -placeholders @("<Subdomain>","<tenant-id>","<AWSRegion>","<IdentityPod>") -placeholderValues @($subdomain,$identityTenantId,$AWSRegion,$Identitypod) -outputFilePath "$PSScriptRoot\network_requirements.txt"
Start-Process "$PSScriptRoot\network_requirements.txt"

