<#
.SYNOPSIS
Connect to Proxmox server

.DESCRIPTION
Connect to Proxmox server

.PARAMETER Server
Server name or IP address

.PARAMETER Credentials
Username and password, username formated as user@pam, user@pve, or user@yourdomain

.PARAMETER BypassSSLCheck
Used for bypassing Invoke-RestMethod built in SSL checker

.EXAMPLE
Connect-PveServer -Server "192.168.128.115" -Credentials (Get-Credential -Username "root@pam") -BypassSSLCheck

.NOTES
This must be used before any other cmdlets are used
#>
function Connect-PveServer {
    [CmdletBinding()]
    param (
        [Alias("Host", "PveServer")]
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String]
        $Server,
        [Parameter(Position = 1)]
        [pscredential]
        $Credentials,
        [Switch]
        $BypassSSLCheck
    )

    begin {
        # Check if ticket already exists and if it is expired
        if ($null -eq $Script:PveTickets) {
            if (-not ($Credentials)) {
                $Credential = Get-Credential -Message "Proxmox Username and password, user@pam, user@pve, or user@domain"
            }

            $UserName = $Credential.UserName
            $Password = $Credential.GetNetworkCredential().Password
            $Body = @{
                username = $UserName
                password = $Password
            }
        }
        elseif ((Get-Date).Ticks -ge $Script:PveTickets.Expire) {
            # Check if ticket expired and assign the username and ticket
            $Body = @{
                username = $Script:PveTickets.UserName
                password = $Script:PveTickets.Ticket
            }
        }
        else {
            Write-Verbose "Ticket not expired"
            Write-Warning "Connected to server $($Script:PveTickets.Server)"
        }
        # if (-not $Script:PveTickets) {
        #     $Script:PveTickets = New-Object -TypeName PSCustomObject
        # }
        if ($BypassSSLCheck -or $Script:PveTickets.BypassSSLCheck) {
            # Trust all certs as we don't use an internal CA
            # Don't use this if you do use an internal CA or are using an external CA
            #$Script:PveTickets.BypassSSLCheck = $true
            $CertificatePolicy = GetCertificatePolicy
            SetCertificatePolicy -Func (GetTrustAllCertsPolicy)
        }
    }

    process {
        $Url = "https://$($Server):8006/api2/json/access/ticket"
        $response = Invoke-RestMethod -Method Post -Uri $Url -Body $Body
        if ($response) {
            # Create variable to work with as we have a ticket for future auth
            $NewServer = @{ }
            $NewServer.Server = $Server
            $NewServer.UserName = $UserName
            $NewServer.Ticket = $response.data.ticket
            $NewServer.CSRFPreventionToken = $response.data.CSRFPreventionToken
            $NewServer.Expire = (Get-Date).AddHours(2).Ticks
            $NewServer.BypassSSLCheck = $false
            if ($BypassSSLCheck) {
                $NewServer.BypassSSLCheck = $true
            }
            if ($Script:PveTickets.Server -contains $Server) {
                $Script:PveTickets = $Script:PveTickets | ForEach-Object {
                    if ($_.Server -notlike $Server) { $_ }
                }
            }
            $Script:PveTickets += New-Object PSObject -Property $NewServer
        }
        else {
            Write-Warning "Not able to connect to server: $Server\n Response: $response"
        }
    }

    end {
        if ($BypassSSLCheck -or $Script:PveTickets.BypassSSLCheck) {
            SetCertificatePolicy -Func ($CertificatePolicy)
        }
    }
}

Export-ModuleMember -Function @(
    'Connect-PveServer'
) -Variable @(
    'PveTickets'
)