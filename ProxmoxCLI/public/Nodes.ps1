<#
.SYNOPSIS
Retruns Nodes from currently connected Proxmox host

.DESCRIPTION
Retruns Nodes from currently connected Proxmox host or can return a specific Node.

.PARAMETER node
Node name

.EXAMPLE
Get-Node

.EXAMPLE
Get-Node -Node "pvehost1"

.EXAMPLE
$pvehost1 = Get-Node -Node "pvehost1"

.NOTES
The object(s) returned can be used to manipulate node(s)
#>
function Get-Node {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [String]
        $Node
    )

    # TODO - Expand this to return more information, probably in Node class.
    if ($Node) {
        return $Node | ForEach-Object {
            #[Node]::new($_)
            New-Object -TypeName "Node" -ArgumentList $_
        }
    }
    else {
        return Invoke-ProxmoxAPI -Resource "/nodes" | ForEach-Object {
            #[Node]::new($_.node)
            New-Object -TypeName "Node" -ArgumentList $_.node
        }
    }
}

<#
.SYNOPSIS
Retruns a Qemu from the specified Node

.DESCRIPTION
Retruns a Qemu from the specified Node

.PARAMETER vmid
The Qemu property called vmid

.PARAMETER Node
Name of node that the Qemu is running under

.EXAMPLE
Get-Qemu -vmid "101" -Node "pvehost1"

.EXAMPLE
$vm101 = Get-Qemu -vmid "101" -Node "pvehost1"

.NOTES
The object(s) returned can be used to manipulate qemu(s)
#>
function Get-Qemu {
    [CmdletBinding()]
    Param(
        [Parameter(mandatory = $false, ValueFromPipelineByPropertyName)]
        [String]
        $vmid,
        [Parameter(mandatory = $true)]
        [String]
        $Node
    )
    if ($vmid) {
        return [Qemu]::new($Node, $vmid)
    }
    else {
        return Get-Node -Node $Node | ForEach-Object {
            $VMList = $_.getQemu()
            $VMList | ForEach-Object {
                # Return Qemu object
                $_
            }
        }
    }

}

Export-ModuleMember -Function @('Get-Node', 'Get-Qemu')