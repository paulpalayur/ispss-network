# ispss-network
This script generates the outbound network requirements for your ISPSS tenant.
## How To Run The Script
* This script can be executed from a user workstation if they can access https://ip-ranges.amazonaws.com/ip-ranges.json
* Download both Get-ISPSSNetworks.ps1 and network_template.txt
* Run the script .\Get-ISPSSNetworks.ps1
* When prompted for subdomain, provide the ISPSS subdomain
* Once the script is executed, it launches the text file with the required outbound rules for the following teannts - Privilege Cloud, CyberArk Identity and Connector Management
