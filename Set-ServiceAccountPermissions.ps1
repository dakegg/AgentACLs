<#
.SYNOPSIS
	  This command sets necessary service account permissions.

.DESCRIPTION
	  This command will set the correct service account permissions for MIM management agents for source AD forests, enabling Replicating Directory Changes permissions, Read Only for the entire directory and writeback of ConsistencyGuid, ExternalDirectoryObjectID and OtherHomePhone.
   
.PARAMETER Identity
	  UserPrincipalName, SID, ObjectGUID or SamAccountName of a user object in AD

.PARAMETER OU
	  Distinguished Name of the OU that should be the target of the command

.EXAMPLE
        Set-ADServiceAccountPermissions -Identity CN=John Smith,CN=Users,DC=Contoso,DC=com -OU CN=Users,DC=Contoso,DC=com

	Sets the correct permissions in the Users OU for the John Smith identity.

.INPUTS
	Identity, OU

.OUTPUTS
	Report of user permissions

.NOTES
	NAME:	Set-ServiceAccountPermissions.ps1
	AUTHOR:	Darryl Kegg
	DATE:	05 June, 2025
	EMAIL:	dkegg@microsoft.com

	VERSION HISTORY:
	1.0 05 June, 2025    Initial Version

THIS CODE AND ANY ASSOCIATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR
PURPOSE. THE ENTIRE RISK OF USE, INABILITY TO USE, OR RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
#>

#Requires -Version 3


[CmdletBinding(SupportsShouldProcess = $True)]
param
(
	[Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipeLineByPropertyName = $true)]
	[alias('objectSID')]
	[alias('objectGUID')]
	[alias('SamAccountName')]
	[alias('DistinguishedName')]
	[string]$Identity,
	[Parameter(Mandatory = $true, HelpMessage = "Full distinguished name of the target OU (e.g. CN=Users,DC=Contoso,DC=Com)")]
	[string]$OU
	# add param for AppliesTo and validate set User,Group,Contact,All
)

Begin
{

### Setting READ ONLY HERE FIRST

Import-Module ActiveDirectory

$forestRoot = (Get-ADForest).RootDomain

$UserSID = New-Object System.Security.Principal.SecurityIdentifier (Get-ADuser $Identity).SID

$forestRootDN = (Get-ADDomain -Identity $forestRoot).DistinguishedName

$acl = Get-ACL -Path "AD:$forestRootDN"

function New-ADDGuidMap
{
    <#
    .SYNOPSIS
        Creates a guid map for the delegation part
    .DESCRIPTION
        Creates a guid map for the delegation part
    .EXAMPLE
        PS C:\> New-ADDGuidMap
    .OUTPUTS
        Hashtable
    #>
    $rootdse = Get-ADRootDSE
    $guidmap = @{ }
    $GuidMapParams = @{
        SearchBase = ($rootdse.SchemaNamingContext)
        LDAPFilter = "(schemaidguid=*)"
        Properties = ("lDAPDisplayName", "schemaIDGUID")
    }
    Get-ADObject @GuidMapParams | ForEach-Object { $guidmap[$_.lDAPDisplayName] = [System.GUID]$_.schemaIDGUID }
    return $guidmap
}

$GuidMap = New-ADDGuidMap

$AccessRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $UserSID, "GenericRead", "Allow", "Descendents", $GuidMap["user"]

$acl.AddAccessRule($accessRule)
Set-ACL -Path "AD:$forestRootDN" -AclObject $acl

### SETTING REPLICATING DIRECTORY CHANGES HERE NEXT

$SAM = (get-aduser $usersid).samaccountname
$User = "$forestRoot\$sam"

$RootDSE = [ADSI]"LDAP://RootDSE"
$DefaultNamingContext = $RootDse.defaultNamingContext
$ConfigurationNamingContext = $RootDse.configurationNamingContext
$UserPrincipal = New-Object Security.Principal.NTAccount("$User")

DSACLS "$DefaultNamingContext" /G "$($UserPrincipal):CA;Replicating Directory Changes" | Out-Null
DSACLS "$ConfigurationNamingContext" /G "$($UserPrincipal):CA;Replicating Directory Changes" | Out-Null

DSACLS "$DefaultNamingContext" /G "$($UserPrincipal):CA;Replicating Directory Changes All" | Out-Null
DSACLS "$ConfigurationNamingContext" /G "$($UserPrincipal):CA;Replicating Directory Changes All" | Out-Null

### SETTING WRITEBACK PERMISSIONS NEXT

[String[]]$objectTypes = @(
    "contact",
    "group",
    "user"
);
 
[String[]]$WriteBackAttributes = @(
    "ms-ds-ConsistencyGuid;user",
    "msDS-ExternalDirectoryObjectID;user",
    "otherHomePhone;user"
);

foreach($objectClass in $objectTypes)
{
    Write-Host "Object type:" $objectClass;
    foreach($attribute in $WriteBackAttributes)
    {
        [String[]]$scopedAttrs = $attribute.Split(";", [StringSplitOptions]::None);
        [String]$attr = $scopedAttrs[0];
        [String]$ttype = $scopedAttrs[1];
 
        if( ($ttype.ToLower() -eq $objectClass.ToLower()) -or
            ($ttype.ToLower() -eq "all"))
        {
            Write-Host "`tWrite Property (WP) $attr on descendent user objects";
            [String]$cmd = "dsacls '$OU' /I:S /G '`"$User`":WP;$attr;$objectClass'";
            Invoke-Expression $cmd |Out-Null;

        }
    }
}

}